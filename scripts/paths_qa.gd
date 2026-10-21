extends "res://scripts/nature_qa.gd"
var render_probe=preload("res://scripts/render_coverage.gd").new()

func sample(delta:float):
	super.sample(delta)
	if collecting:render_probe.sample()

func run(target):
	main=target;main.store.directory="user://qa_isolated/paths_review"
	var definitions:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/path_079_cameras.json"))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=75
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	for definition in definitions:
		var view:Dictionary=definition.duplicate(true)
		if view.get("relative_ground",false):
			view.eye[1]+=w.height_at(view.eye[0],view.eye[2])
			view.target[1]+=w.height_at(view.target[0],view.target[2])
		fixed_cameras.append(view)
	for view in fixed_cameras:
		main.set_time(int(view.time));await capture(view.name,Vector3.ZERO,Vector3.ZERO)
		cameras[-1].time=int(view.time)
	main.set_time(0)
	main.player.position=w.surface(255,232,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	main.watch_camera.current=false;main.player.camera.current=true
	collecting=true;render_probe.start()
	for point in [Vector2(135,248),Vector2(20,248),Vector2(20,251),Vector2(20,248),Vector2(-75,236),Vector2(-75,220),Vector2(-79,220),Vector2(-71,220),Vector2(-75,220),Vector2(-75,195),Vector2(-75,144),Vector2(-35,130),Vector2(0,120),Vector2(0,80)]:
		if not await walk(point):break
	collecting=false;render_probe.stop()
	var ids:Array=[]
	for action in w.interactions:ids.append(action.id)
	ids.sort()
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	var missing:Array=[]
	for id in original.ids:
		if id not in ids:missing.append(id)
	check("original_world_and_actions_retained",missing.is_empty() and w.spec.zones.size()==8 and w.building_bounds.size()==13,{"missing":missing,"current_ids":ids.size()})
	frames.sort();var total:=0.0;var slow:=0;var failures:=0
	for ms in frames:total+=ms;slow+=1 if ms>100 else 0
	for row in checks:failures+=0 if row.passed else 1
	var performance:={"frames":frames.size(),"average_fps":1000.0*frames.size()/maxf(total,0.001),"p95_ms":frames[int(frames.size()*0.95)] if not frames.is_empty() else null,"p99_ms":frames[int(frames.size()*0.99)] if not frames.is_empty() else null,"over100ms":slow,"resolution":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"scale":1.0,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"shadows":true,"scope":"Continuous retained station/coast to shops and plaza walk plus street-edge crossings; excludes capture and setup, no full-world or GPU-timer inference"}
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"action_ids":ids,"performance":performance,"render_coverage":render_probe.report(),"path_counts":w.streamer.manifest.authored_counts.get("paths_079",{}),"runtime":"editor_binary" if OS.has_feature("editor") else "export_release"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
