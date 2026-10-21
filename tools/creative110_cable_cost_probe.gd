extends "res://tools/creative110_backend_probe.gd"
## Rendering-cost isolation only. No diagnostic toggle is saved or adopted.
func sample_cost(label:String)->Dictionary:
	for i in 75:await process_frame
	var values:Array=[]
	json("res://reports/creative110_backend_progress.json",{"pid":OS.get_process_id(),"phase":label+"_sample"})
	var last:=Time.get_ticks_usec()
	for i in 150:
		await process_frame
		var now:=Time.get_ticks_usec();values.append({"ms":(now-last)/1000.0,"gpu":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)});last=now
	json("res://reports/creative110_backend_progress.json",{"pid":OS.get_process_id(),"phase":""})
	var result:Dictionary={"frames":values.size(),"ms":0.0,"gpu":0.0,"draws":0.0,"primitives":0.0}
	for value in values:
		for key in ["ms","gpu","draws","primitives"]:result[key]+=value[key]/values.size()
	result.fps=1000.0/result.ms;return result
func run():
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="cable_cost110_probe";m.store.directory="user://cable_cost110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080));m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.enabled=true
	if not m.transport.board(0):push_error("Cannot enter cable for cost isolation");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[m.transport.rider].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184)
	for id in m.world.streamer.loaded:flower_candidate.apply(m.world.streamer.loaded[id],str(id))
	for i in 90:await process_frame
	m.world.streamer.set_process(false);var results:Dictionary={};var camera:Transform3D=m.player.camera.global_transform
	results.baseline=await sample_cost("cost_full_quality")
	m.sun.shadow_enabled=false;results.no_shadows_diagnostic=await sample_cost("cost_no_shadows_diagnostic");m.sun.shadow_enabled=true
	var terrain:Array=[]
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if node.has_meta("stream_terrain") and node.visible:terrain.append(node);node.hide()
	results.no_terrain_diagnostic=await sample_cost("cost_no_terrain_diagnostic")
	for node in terrain:node.show()
	m.world.streamer.far_root.hide();results.no_far_diagnostic=await sample_cost("cost_no_far_diagnostic");m.world.streamer.far_root.show()
	results.baseline_repeat=await sample_cost("cost_full_quality_repeat")
	json("res://reports/creative110_cable_cost_probe.json",{"pid":OS.get_process_id(),"stages":results,"scope":"Temporary cost-isolation toggles only; all restored, no setting saved or quality reduction adopted","renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"fixed_camera":camera,"same_camera_after":camera.is_equal_approx(m.player.camera.global_transform),"normal_saves":"isolated APPDATA"})
	print("CABLE_COST110 ",JSON.stringify(results));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
