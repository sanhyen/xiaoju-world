extends "res://scripts/nature_qa.gd"
var render_probe=preload("res://scripts/render_coverage.gd").new()
var forced_draw_requests:=0
var coast_cameras:Array=[]


func sample(delta:float):
	super.sample(delta)
	if collecting:
		render_probe.sample()
		if Time.get_ticks_usec()-render_probe.last_draw_usec>120000:
			RenderingServer.force_draw(false);forced_draw_requests+=1

func run(target):
	main=target;main.store.directory="user://qa_isolated/"+main.qa_mode
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=75;main.set_time(0)
	var final_coast:bool=main.qa_mode.contains("coast_final_092")
	var w=main.world;var counts:Dictionary=w.streamer.manifest.authored_counts
	check("eight_zones_thirteen_venues",w.spec.zones.size()==8 and w.building_bounds.size()==13)
	check("old_collision_count_retained",counts.colliders==2853)
	check("old_tree_count_retained",counts.tree_families.values().reduce(func(sum,value):return sum+int(value),0)==1169)
	var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	var missing:Array=[]
	for id in contract.ids:
		if not w.interactions.any(func(action):return action.id==id):missing.append(id)
	check("old_interactions_retained",missing.is_empty() and w.interactions.size()==87,{"missing":missing,"current":w.interactions.size()})
	var route_contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/preserved_routes_088.json"))
	var lost_routes:Array=[]
	for old in route_contract.corridors:
		var a:=Vector2(old.a[0],old.a[1]);var c:=Vector2(old.c[0],old.c[1])
		if not w.path_corridors.any(func(route):return route.a.distance_to(a)<0.001 and route.c.distance_to(c)<0.001 and absf(float(route.width)-float(old.width))<0.001):lost_routes.append(old)
	check("all_original_routes_retained",lost_routes.is_empty(),{"contract_routes":route_contract.corridors.size(),"current":w.path_corridors.size(),"missing":lost_routes.size()})
	for path in ["res://scripts/world.gd","res://scripts/landform_details.gd","res://data/landform_details_088.json","res://assets/materials/coastal_water.gdshader"]:
		var baked_sha:String=w.streamer.manifest.source_hashes.get(path,"")
		if not OS.has_feature("editor") and path.ends_with(".gd"):
			# Release exports remap GDScript to bytecode; .gd source bytes are unavailable.
			check("compiled_baked_script_present_"+path.get_file(),ResourceLoader.exists(path) and not baked_sha.is_empty(),{"baked_source_sha256":baked_sha,"source_file_visible":FileAccess.file_exists(path),"limit":"Source hash checked before export; Native verifies compiled resource and behavior, not inaccessible text bytes."})
		else:check("baked_current_"+path.get_file(),baked_sha==FileAccess.get_sha256(path),{"baked":baked_sha,"actual":FileAccess.get_sha256(path)})
	var details:Dictionary=counts.get("landform_details_088",{})
	check("new_rooted_landform_groups_baked",details.get("modules",0)>0 and details.get("rocks",0)>0 and details.get("ferns",0)>0 and details.get("grass_clumps",0)>0,details.duplicate().merged({"records":[],"groups":[]},true))
	check("landform_adds_no_colliders",details.get("colliders_added",-1)==0)
	var forest_groups:=0;var river_groups:=0;var shoulder_groups:=0;var empty:Array=[]
	for group in details.get("groups",[]):
		if group.actual==0:empty.append(group.id);continue
		match str(group.kind):
			"forest_floor":forest_groups+=1
			"riparian_shelf":river_groups+=1
			"mountain_road_shoulder":shoulder_groups+=1
	check("forest_river_and_shoulder_are_actual",forest_groups>0 and river_groups>0 and shoulder_groups>0,{"forest":forest_groups,"riparian":river_groups,"shoulders":shoulder_groups,"empty_candidates":empty})
	# Query real streamed collision below one representative of each new group.
	var groups_seen:Dictionary={};var rooted_failures:Array=[];var rooted_probes:=0
	for item in details.get("records",[]):
		if groups_seen.has(item.group):continue
		groups_seen[item.group]=true
		var point:=Vector3(item.x,item.ground_y,item.z)
		await w.prepare_region(point)
		var ray:=PhysicsRayQueryParameters3D.create(point+Vector3(0,0.10,0),point-Vector3(0,0.40,0));ray.exclude=[main.player.get_rid()]
		var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(ray)
		rooted_probes+=1
		if hit.is_empty() or absf(hit.position.y-point.y)>0.04:rooted_failures.append({"group":item.group,"point":str(point),"hit":str(hit.get("position",Vector3.ZERO))})
	check("new_groups_touch_real_ground",rooted_failures.is_empty(),{"probes":rooted_probes,"failures":rooted_failures})
	check("water_uses_explicit_horizon_blend",w.water_material!=null and w.water_material.shader.code.contains("grazing_haze") and w.water_material.shader.code.contains("fog_disabled"))
	var sky:ShaderMaterial=main.environment.environment.sky.sky_material
	check("sky_decodes_active_renderer",sky.get_shader_parameter("radiance_decode")== (2.0 if RenderingServer.get_current_rendering_method()=="mobile" else 1.0))
	# Source gathers the changed regional views; Native gathers only the new horizon.
	if OS.has_feature("editor"):
		fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/landform_088_cameras.json"))
		for view in fixed_cameras:await capture(view.name,Vector3.ZERO,Vector3.ZERO)
	for index in 3:
		main.set_time(index)
		check("shared_actual_horizon_palette_"+str(index),w.water_material.get_shader_parameter("horizon_tone")==sky.get_shader_parameter("horizon_color"))
		if OS.has_feature("editor") or index==0 or final_coast:
			await coast_capture("sea_"+str(index),Vector3(0,4.0,370),Vector3(0,2.5,2500),index)
		if final_coast:
			await coast_capture("beach_"+str(index),w.surface(216,322,2.4),Vector3(263,0,350),index)
			if index==0:
				await coast_capture("high_sea",Vector3(18,17,289),Vector3(0,0,800),index)
				await coast_capture("coast_relation",Vector3(-170,8.5,310),Vector3(-130,1,278),index)
	if final_coast:
		check("wide_horizon_transition_loaded",w.water_material.shader.code.contains("smoothstep(24.0,165.0,optical_distance)") and w.water_material.shader.code.contains("smoothstep(0.015,0.18,abs(sight.y))"))
		var fail_count:=0
		for row in checks:fail_count+=0 if row.passed else 1
		var current_report:={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":fail_count,"coast_cameras":coast_cameras,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","scope":"Final-coast local capture: three shared palettes, three low-sea and three diagonal-shore views, high sea and coast relation, current baked shader/old scope and retained ground attachment. No repeat routes, full-world performance, presentation FPS or human audio acceptance."}
		var out:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);out.store_string(JSON.stringify(current_report,"\t"));out.close()
		main.get_tree().quit(1 if fail_count else 0)
		return
	main.set_time(0);main.watch_camera.current=false;main.player.camera.current=true
	collecting=true;render_probe.start()
	# Independent route starts; all legs use the unchanged ordinary collision/controller path.
	for route in [[Vector2(-160,-218),Vector2(-100,-272),Vector2(-160,-218)],[Vector2(175,-220),Vector2(85,-285),Vector2(175,-220)]]:
		main.player.position=w.surface(route[0].x,route[0].y,0.5);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		for i in range(1,route.size()):
			if not await walk(route[i]):break
	# The retained near-water deck is above the numeric channel bed; start on its real deck.
	main.player.position=Vector3(297+18*sin(39*0.014),-0.35,39);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	for z in [51.0,65.0,51.0,39.0]:
		if not await walk(Vector2(297+18*sin(z*0.014),z)):break
	collecting=false;render_probe.stop()
	check("actual_drawing_during_routes",render_probe.report().second_coverage>0.95,render_probe.report())
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"landform":details,"cameras":cameras,"render_coverage":render_probe.report(),"forced_draw_requests":forced_draw_requests,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","scope":"One combined batch: actual ground/old scope/shader binding, changed region cameras, daytime-dusk-night horizon, western/eastern approach and retained near-water walk. No full-world performance or human-input/audio acceptance."}
	var f:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	main.get_tree().quit(1 if failures else 0)

func coast_capture(name:String,eye:Vector3,look:Vector3,index:int):
	await main.qa_capture(main.qa_mode+"_"+name,eye,look)
	coast_cameras.append({"name":main.qa_mode+"_"+name,"eye":[eye.x,eye.y,eye.z],"target":[look.x,look.y,look.z],"time":index,"fov":main.watch_camera.fov,"resolution":[main.get_viewport().size.x,main.get_viewport().size.y],"internal_scale":main.get_viewport().scaling_3d_scale,"sun_shadows":main.sun.shadow_enabled})
