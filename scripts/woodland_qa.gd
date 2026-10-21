extends "res://scripts/nature_qa.gd"
var render_probe=preload("res://scripts/render_coverage.gd").new()

func sample(delta:float):
	super.sample(delta)
	if collecting:render_probe.sample()

func run(target):
	main=target;phase="woodland_review"
	var terrain_review:bool=main.qa_mode.contains("terrain_074")
	var camera_path:String="res://data/terrain_074_cameras.json" if terrain_review else "res://data/woodland_cameras.json"
	fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string(camera_path))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.set_time(0);main.watch_camera.fov=75
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	if ProjectSettings.get_setting("application/config/version").begins_with("0.9.1"):
		check_cliff_batch(w)
	for camera in fixed_cameras:await capture(camera.name,Vector3.ZERO,Vector3.ZERO)
	# These are real retained walking/rest positions, supplementing the older off-path
	# forest-floor camera, whose view is dominated by a nearby terrace side wall.
	if not terrain_review:
		await capture("west_rest_view",w.surface(-90,-293,1.75),Vector3(-130,50,-312))
		await capture("western_turn_view",w.surface(-100,-272,1.75),Vector3(-141,45,-300))
	main.player.position=w.surface(-160,-218,0.5);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	collecting=true;render_probe.start()
	for point in [Vector2(-100,-272),Vector2(0,-330),Vector2(0,-377),Vector2(0,-330),Vector2(85,-285),Vector2(175,-220)]:
		if not await walk(point):break
	collecting=false;render_probe.stop()
	# The two old off-route rest pockets must remain reachable in both directions.
	for point in [Vector2(-90,-293),Vector2(117,-265)]:
		var road:Vector2=w.nearest_road(point)
		main.player.position=w.surface(road.x,road.y,0.5);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		if await walk(point):await walk(road)
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	var ids:Array=[]
	for action in w.interactions:ids.append(action.id)
	var missing:Array=[]
	for id in original.ids:
		if id not in ids:missing.append(id)
	check("woodland_keeps_original_scope",missing.is_empty() and w.spec.zones.size()==8 and w.building_bounds.size()==13,{"missing_ids":missing,"current_ids":ids.size()})
	frames.sort();var total:=0.0;var slow:=0;var failures:=0
	for ms in frames:total+=ms;slow+=1 if ms>100 else 0
	for row in checks:failures+=0 if row.passed else 1
	var performance:={"frames":frames.size(),"average_fps":1000.0*frames.size()/maxf(total,0.001),"p95_ms":frames[int(frames.size()*0.95)] if not frames.is_empty() else null,"p99_ms":frames[int(frames.size()*0.99)] if not frames.is_empty() else null,"over100ms":slow,"resolution":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"scale":1.0,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"shadows":true,"scope":"western ascent, summit and eastern descent; rest-pocket starts are independent"}
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"performance":performance,"woodland":w.streamer.manifest.authored_counts.get("woodland_v12",{}),"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","render_coverage":render_probe.report()}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)

func check_cliff_batch(w):
	var counts:Dictionary=w.streamer.manifest.authored_counts
	var details:Dictionary=counts.get("cliff_details_091",{})
	check("actual_cliff_relief_baked",details.get("modules",0)>0 and details.get("records",[]).size()==details.get("modules",0),{"modules":details.get("modules",0),"groups":details.get("groups",[])})
	check("cliff_retains_all_previous_modules_and_collision",counts.boxes==120275+int(details.get("modules",0)) and counts.colliders==2853 and details.get("colliders_added",-1)==0)
	check("cliff_retains_all_previous_trees",counts.tree_families.values().reduce(func(sum,value):return sum+int(value),0)==1169)
	var bad:Array=[]
	for row in details.get("records",[]):
		var tile:Dictionary=w.terrain_art.tile(Vector2i(row.cell[0],row.cell[1]))
		var e:Array=row.edge
		var other:Dictionary=w.terrain_art.tile(Vector2i(row.cell[0]+e[2],row.cell[1]+e[3]))
		var high:float=minf(tile.heights[e[0]],tile.heights[e[1]])
		var low:float=maxf(other.heights[e[4]],other.heights[e[5]])
		var point:=Vector2(row.center[0],row.center[2])+Vector2(row.normal[0],row.normal[1])*0.9
		if absf(high-row.high)>0.01 or absf(low-row.low)>0.01 or row.center[1]<=low+0.35 or row.center[1]>=high-0.65 or row.embedded_depth<=0.1 or not w.clear_of_paths(point,2.5):bad.append(row)
	check("actual_relief_attached_to_unchanged_faces",bad.is_empty(),{"checked":details.get("records",[]).size(),"failed":bad.size()})
	check("cliff_design_data_matches_bake",w.streamer.manifest.source_hashes.get("res://data/cliff_details_091.json","")==FileAccess.get_sha256("res://data/cliff_details_091.json"))
	check("natural_rock_strata_shader_loaded",w.terrain_art.material.shader.code.contains("rock_resolved") and w.streamer.manifest.source_hashes.get("res://assets/materials/terrain_strata.gdshader","")==FileAccess.get_sha256("res://assets/materials/terrain_strata.gdshader"))
