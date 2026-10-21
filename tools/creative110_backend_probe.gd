extends SceneTree
## Isolated equal-quality backend comparison. Never changes project/saves/settings.
var m
var samples:Array=[]
var phase:=""
var previous:=0
var expected:Camera3D
var poses:Dictionary={}
var flower_candidate=preload("res://tools/creative110_flower_cluster_probe.gd").Candidate.new()
func _initialize():run.call_deferred()
func json(path:String,value):
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(value,"\t"));f.close()
func _process(_delta:float)->bool:
	if phase.is_empty():previous=0;return false
	if root.get_camera_3d()!=expected:push_error("Backend probe camera changed");quit(2);return true
	var now:=Time.get_ticks_usec()
	if previous>0:samples.append({"phase":phase,"ms":(now-previous)/1000.0,"gpu":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	previous=now;return false
func hold(label:String):
	for id in m.world.streamer.loaded:flower_candidate.apply(m.world.streamer.loaded[id],str(id))
	for i in 150:await process_frame
	poses[label]={"player":m.player.global_position,"yaw":m.player.yaw,"pitch":m.player.pitch,"zoom":m.player.zoom,"camera":expected.global_transform,"projection":expected.projection,"extent":expected.size}
	phase=label;previous=0;json("res://reports/creative110_backend_progress.json",{"pid":OS.get_process_id(),"phase":label+"_sample"})
	for i in 210:await process_frame
	phase="";previous=0;json("res://reports/creative110_backend_progress.json",{"pid":OS.get_process_id(),"phase":""})
func run():
	if DisplayServer.get_name()=="headless":quit(3);return
	if OS.get_cmdline_user_args().has("--mailbox"):DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MAILBOX)
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="backend110_probe";m.store.directory="user://backend110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080))
	if OS.get_cmdline_user_args().has("--no-mini"):
		m.hud.get_node("BayMiniMap").set_process(false);m.hud.get_node("BayMiniMap").hide()
	m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1)
	m.player.yaw=1.04422919850175;m.player.pitch=-.2;m.player.zoom=6.0
	m.player.enabled=true;m.player.automated_motion=true;m.player.automated_horizontal=Vector2.ZERO;m.player.camera.make_current();expected=m.player.camera
	await hold("castle")
	m.transport.reset_session();await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.automated_motion=false
	if not m.transport.board(0):push_error("Cannot enter cable");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[m.transport.rider].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184);expected=m.player.camera
	await hold("cable")
	m.environment_controls.enter();m.environment_controls.switch_mode();m.environment_controls.fit_world_view();expected=m.environment_controls.camera
	await hold("home")
	var groups:Dictionary={}
	for sample in samples:
		if not groups.has(sample.phase):groups[sample.phase]={"times":[],"gpu":0.0,"draws":0.0,"primitives":0.0}
		var group:Dictionary=groups[sample.phase];group.times.append(sample.ms)
		for key in ["gpu","draws","primitives"]:group[key]+=sample[key]
	for group in groups.values():
		var total:=0.0
		for value in group.times:total+=value
		for key in ["gpu","draws","primitives"]:group[key]/=group.times.size()
		group.times.sort();group.fps=1000.0*group.times.size()/total;group.p95_ms=group.times[int(group.times.size()*.95)];group.frames=group.times.size();group.erase("times")
	var driver:String=RenderingServer.get_current_rendering_driver_name()
	var report_suffix:String="_forward_plus" if RenderingServer.get_current_rendering_method()=="forward_plus" else ""
	if OS.get_cmdline_user_args().has("--mailbox"):report_suffix+="_mailbox"
	if OS.get_cmdline_user_args().has("--no-mini"):report_suffix+="_no_mini_diagnostic"
	json("res://reports/creative110_backend_"+driver+report_suffix+".json",{"pid":OS.get_process_id(),"backend":driver,"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":root.size,"msaa":root.msaa_3d,"shadow_enabled":m.sun.shadow_enabled,"shadow_distance":m.sun.directional_shadow_max_distance,"stages":groups,"camera_poses":poses,"mouse_camera_input_disabled_for_repeatable_diagnosis":true,"normal_saves":"isolated APPDATA"})
	print("BACKEND110 ",driver," ",JSON.stringify(groups));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
