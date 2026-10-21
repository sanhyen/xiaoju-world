extends "res://tools/creative110_terrain_combined_probe.gd"
## One affected cable view only, exact geometry/camera/shadows retained.
func run():
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="cable_occlusion110_probe";m.store.directory="user://cable_occlusion110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080));m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.enabled=true
	if not m.transport.board(0):push_error("No cable for surface cost probe");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[0].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184)
	for i in 120:await process_frame
	m.world.streamer.set_process(false);fixed_view=m.player.camera.global_transform
	var result:Dictionary={};root.use_occlusion_culling=false;result.baseline_A=await terrain_sample("cable_occlusion_A")
	var builder=preload("res://tools/creative110_occlusion_probe.gd").ConservativeOccluders.new();var started:int=Time.get_ticks_msec()
	for id in m.world.streamer.loaded:builder.build_cell(m.world.streamer.loaded[id],false)
	var build_ms:int=Time.get_ticks_msec()-started;root.use_occlusion_culling=true;result.terrain_occlusion=await terrain_sample("cable_terrain_occlusion")
	root.use_occlusion_culling=false;result.baseline_A_repeat=await terrain_sample("cable_occlusion_A_repeat")
	json("res://reports/creative110_cable_occlusion_probe.json",{"stages":result,"occluders":builder.stats,"build_ms":build_ms,"normal_saves":"isolated","scope":"Affected original camera with visible closed cabin; conservative inset terrain occluders only, all other conditions unchanged. No production state saved."})
	print("CABLE_OCCLUSION110 ",JSON.stringify(result));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
