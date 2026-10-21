extends "res://scripts/creative110_qa.gd"
var selected_parts:PackedStringArray=[]
var only_places:PackedStringArray=[]
func write_progress():
	if m==null:return
	var file:=FileAccess.open(m.evidence_root+"reports/design120_progress.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"pid":OS.get_process_id(),"phase":phase,"checks":results.size(),"failed":results.filter(func(r):return not r.ok).size(),"position":m.player.position}));file.close()
func selected(part:String)->bool:return selected_parts.is_empty() or part in selected_parts
func equivalent(a:Variant,b:Variant)->bool:
	if (a is int or a is float) and (b is int or b is float):return absf(float(a)-float(b))<.000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for index in a.size():
			if not equivalent(a[index],b[index]):return false
		return true
	return a==b
func run(main):
	m=main
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--part="):selected_parts=arg.trim_prefix("--part=").split(",")
		if arg.begins_with("--place="):only_places=arg.trim_prefix("--place=").split(",")
	await m.start_game(false);await m.get_tree().physics_frame
	write_runtime_catalog()
	if selected("scope"):scope_contracts()
	for p in m.world.layout.creative_places:
		if not only_places.is_empty() and str(p.id) not in only_places:continue
		if selected("entrances"):await entrance(p)
		if selected("floors"):await floors_probe(p)
		if selected("uppers"):
			if str(p.id).begins_with("CASTLE_") or str(p.id) in ["AZURE_VIEW","AZURE_WEAVE"]:await staircase(p)
			else:await authored_upper(p)
	if selected("systems"):
		await mode_checks();await item_integration();await migration_checks();await puzzle_and_map();await media_smoke()
	if selected("transport"):await cable_checks();await cable_downhill_checks();await water_checks()
	if not selected_parts.is_empty() and selected("cable_downhill"):await cable_downhill_checks()
	if selected("feedback"):await feedback_checks()
	if selected("visual"):await visuals()
	if selected("perf"):
		await performance_routes()
	var failures:Array=results.filter(func(r):return not r.ok);var name:String="all" if selected_parts.is_empty() else "_".join(selected_parts)
	var output:Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"at":Time.get_datetime_string_from_system(),"checks":results,"failures":failures,"parts":selected_parts,"places":only_places,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":m.get_viewport().get_visible_rect().size,"normal_saves":"isolated profile; original files never written","performance":sampled,"conditions":performance_conditions}
	var file:=FileAccess.open(m.evidence_root+"reports/design120_consolidated_"+name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close();print("DESIGN120_COMPLETE ",JSON.stringify({"checks":results.size(),"failed":failures.size()}));m.get_tree().quit(0 if failures.is_empty() else 1)
func media_smoke():
	phase="retained_media"
	await move_to(Vector3(252,15.8,-195))
	await m.show_video("B06","sunset");await m.get_tree().create_timer(1.3).timeout
	record("retained_cinema_plays_local_video",m.video.is_playing() and m.current_screen_id=="B06",{"position_s":m.video.stream_position})
	m.stop_media("design120_media_smoke");record("video_decoder_stops_on_exit",not m.video.is_playing());m.close_modal()
func write_runtime_catalog():
	var lines:Array=[]
	for segment in m.world.layout.segments:
		var samples:Array=[]
		var length:float=Vector2(segment.a.x-segment.c.x,segment.a.z-segment.c.z).length()
		var count:int=maxi(2,ceili(length/2.0))
		for i in count+1:
			var p:Vector3=segment.a.lerp(segment.c,float(i)/count)
			samples.append({"distance_m":length*i/count,"x":p.x,"z":p.z,"road_y":p.y,"ground_y":m.world.height_at(p.x,p.z)})
		lines.append({"id":segment.id,"a":segment.a,"c":segment.c,"width_m":segment.width,"bridge":segment.bridge,"slope":absf(segment.c.y-segment.a.y)/maxf(length,.001),"samples":samples})
	var file:=FileAccess.open(m.evidence_root+"reports/design120_runtime_catalog.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"places":m.world.layout.creative_places,"road_sections":lines,"source":"Actual loaded layout and height queries; engineering profiles, not additional physics acceptance"},"\t"));file.close()
func scope_contracts():
	phase="scope"
	var counts:Dictionary=m.world.streamer.manifest.authored_counts;var missing:Array=[];var actual:Dictionary={}
	for action in m.world.interactions:actual[str(action.id)]=true
	var protected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/protected_interactions_0110.json"))
	for id in protected.ids:
		if not actual.has(id):missing.append(id)
	record("protected_501_ids",missing.is_empty(),{"missing":missing,"total":actual.size()});record("unique_ids",actual.size()==m.world.interactions.size())
	var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creative_places110.json"));var rebuilt:Dictionary=counts.get("design120",{});missing=[]
	for p in expected.places:
		if not rebuilt.has(str(p.id)):missing.append(p.id)
	record("all_83_buildings_have_authored_changes",missing.is_empty() and rebuilt.size()==83,{"missing":missing,"records":rebuilt.size()})
	record("58_outdoor_contracts",counts.get("outdoors120",[]).size()==58)
	var total_floors:=0
	for p in m.world.layout.creative_places:total_floors+=p.floors.size()
	record("130_registered_floor_surfaces",total_floors==130,{"actual":total_floors})
	var map=preload("res://scripts/bay_map_view.gd").new();map.spec=m.world.spec;map.layout_reference=m.world.layout
	var actual_map:Dictionary={}
	for item in map.places():actual_map[item.id]=item
	var protected_map:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/protected_map_0110.json"));var changed:Array=[]
	for item in protected_map.places:
		if not actual_map.has(item.id) or str(actual_map[item.id].get("kind",""))!=str(item.kind) or str(actual_map[item.id].get("parent",""))!=str(item.parent):changed.append(item.id)
	record("278_original_map_entries",map.places().size()==278 and changed.is_empty(),{"actual":map.places().size(),"missing_or_reparented":changed});map.free()
	record("all_63_item_definitions",m.creative.items.defs.size()==63,{"actual":m.creative.items.defs.size()})
	var protected_items:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/protected_items_0110.json"));changed=[]
	for id in protected_items.defs:
		if not m.creative.items.defs.has(id):changed.append(id);continue
		for field in ["name","kind","category","cost","wall"]:
			if not equivalent(protected_items.defs[id].get(field),m.creative.items.defs[id].get(field)):changed.append(id+":"+field)
	record("original_item_ids_categories_and_costs",changed.is_empty(),{"changed":changed})
	var drift:Array=[]
	for path in m.world.streamer.manifest.source_hashes:
		if not OS.has_feature("editor") and str(path).begins_with("res://tools/"):continue
		if not OS.has_feature("editor") and str(path).ends_with(".gd"):
			if not ResourceLoader.exists(path):drift.append(path)
		elif FileAccess.get_sha256(path)!=m.world.streamer.manifest.source_hashes[path]:drift.append(path)
	record("bake_matches_all_sources",drift.is_empty(),{"drift":drift})
func puzzle_and_map():
	phase="puzzle_resume_and_map"
	var c=m.creative;var before:String=JSON.stringify(c.items.data().stacks)
	c.begin_puzzle("everyday");var first=c.puzzle;var initial:Array=first.values.duplicate();first.values[0]=posmod(int(first.values[0])+1,6);first.moves=4
	var changed:Array=first.values.duplicate();m.close_modal();await m.get_tree().process_frame
	c.begin_puzzle("everyday");record("puzzle_partial_operation_resumes",c.puzzle.values==changed and c.puzzle.moves==4)
	record("puzzle_return_does_not_spend_materials",before==JSON.stringify(c.items.data().stacks))
	var runs:int=int(c.items.data().lessons.get("everyday",{}).get("runs",0))
	for i in 3:
		var board=c.puzzle
		if not is_instance_valid(board):break
		board.values=board.goal.duplicate();board.rotations=board.target_rotations.duplicate();board.submit();await m.get_tree().process_frame
	record("three_round_success_records_once",int(c.items.data().lessons.everyday.runs)==runs+1)
	var completed:String=JSON.stringify(c.items.data().stacks);c.finish_puzzle("everyday",{});record("duplicate_completion_cannot_grant_again",JSON.stringify(c.items.data().stacks)==completed)
	m.close_modal()
	var panel=preload("res://scripts/bay_map_panel.gd").new();panel.build(m)
	panel.floor_plan.open({"id":"CASTLE_MAIN_FLOOR_2","parent":"CASTLE_MAIN"});await m.get_tree().process_frame
	record("floor_plan_opens_requested_floor",panel.floor_plan.visible and panel.floor_plan.level==2 and panel.floor_plan.place.id=="CASTLE_MAIN")
	var key:=InputEventKey.new();key.pressed=true;key.keycode=KEY_UP;panel.floor_plan._gui_input(key)
	record("floor_plan_switches_actual_floors",panel.floor_plan.level==3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(m.evidence_root+"screenshots/design120");m.get_viewport().get_texture().get_image().save_png(m.evidence_root+"screenshots/design120/floor_plan_castle.png");m.close_modal()
func visuals():
	phase="representative_visuals"
	m.player.figure.hide();m.ui.hide();m.watch_camera.fov=67;m.watch_camera.near=.08;m.set_time(0);m.environment_controls.set_weather(0)
	for id in ["B01","B04","B06","B07","H01","THEME_BLOSSOM","VILLA_0","CASTLE_MAIN","AZURE_WEAVE","H12","TREEHOUSE_4"]:
		for p in m.world.layout.creative_places:
			if str(p.id)!=id:continue
			var center:=Vector3(p.center[0],p.center[1],p.center[2]);var width:float=p.size[0];var depth:float=p.size[1];var turn:=Basis(Vector3.UP,float(p.door_yaw));var high:float=maxf(5.5,float(p.floors[-1])-float(p.floors[0])+5);var extent:float=maxf(width,depth)
			await shot("0120_"+id+"_exterior",center+turn*Vector3(extent*.72,high*.72+extent*.38,extent*1.12),center+Vector3.UP*(high*.4))
			await shot("0120_"+id+"_interior",center+turn*Vector3(width*.27,1.65,depth*.25),center+turn*Vector3(-width*.20,1.35,-depth*.24))
			var metadata:Dictionary=m.world.streamer.manifest.authored_counts
			var actual_origin:Vector3=metadata.design120[id].origin
			var wanted:String={"B01":"schedule","B04":"flowerbench","B06":"projector","B07":"folio","H01":"oven","THEME_BLOSSOM":"flowerbench","VILLA_0":"basin","CASTLE_MAIN":"schedule","AZURE_WEAVE":"loom","H12":"photo","TREEHOUSE_4":"telescope"}[id]
			var focus:Vector3=actual_origin;var nearest:=INF
			for device in metadata.design120_devices:
				if str(device.kind)!=wanted or absf(device.position.y-actual_origin.y)>.5:continue
				var distance:float=device.position.distance_to(actual_origin)
				if distance<nearest:nearest=distance;focus=device.position
			var local:Vector3=turn.inverse()*(focus-actual_origin)
			var toward_center:float=-signf(local.x)*minf(3,width*.22)
			if absf(toward_center)<.1:toward_center=2.0
			await shot("0120_"+id+"_workplace",focus+turn*Vector3(toward_center,2.1,4.5),focus+Vector3.UP*1.05)
	m.player.figure.show();m.ui.show()
func feedback_checks():
	phase="physical_workshop_feedback"
	var feedback=m.workshop_feedback;var linked:=0
	for key in m.creative.MODES:
		if key!="star" and not feedback.topic_place(key).is_empty():linked+=1
	var star_present:bool=m.world.interactions.any(func(action):return str(action.id)=="FOREST_STAR")
	record("18_topics_have_actual_world_workplaces",linked==17 and m.creative.MODES.size()==18 and star_present,{"dynamic_workplaces":linked,"total_topics":m.creative.MODES.size(),"original_star_instrument":star_present,"accounting":"17 new feedback stations plus the retained physical star instrument"})
	var place:Dictionary=feedback.topic_place("azure_water");await move_to(Vector3(place.center[0]+3,place.center[1]+.1,place.center[2]+1))
	m.creative.begin_puzzle("azure_water");feedback._process(.2)
	var station:Node3D=feedback.stations.get("azure_water");var water:Node3D=station.get_node_or_null("PoolWater0") if is_instance_valid(station) else null
	var before_y:float=water.position.y if is_instance_valid(water) else -99
	m.creative.puzzle.basins[0]=.8;feedback._process(.2);water=station.get_node_or_null("PoolWater0")
	record("valve_challenge_moves_actual_pool_surface",is_instance_valid(water) and water.position.y>before_y+.01,{"before_y":before_y,"after_y":water.position.y if is_instance_valid(water) else -99})
	m.close_modal();feedback._process(.2);water=station.get_node_or_null("PoolWater0")
	record("return_restores_last_completed_pool_state",is_instance_valid(water) and absf(water.position.y-(1.166+.45*.2))<.0001)
	m.creative.begin_puzzle("azure_water");record("pool_challenge_restores_unfinished_valves",absf(float(m.creative.puzzle.basins[0])-.8)<.001);m.close_modal()
