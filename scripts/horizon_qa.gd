extends "res://scripts/nature_qa.gd"
var render_probe=preload("res://scripts/render_coverage.gd").new()

func sample(delta:float):
	super.sample(delta)
	if collecting:render_probe.sample()

func run(target):
	main=target;main.store.directory="user://qa_isolated/horizon_review"
	fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/horizon_076_cameras.json"))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=75
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	for view in fixed_cameras:
		main.set_time(int(view.time));await capture(view.name,Vector3.ZERO,Vector3.ZERO)
		cameras[-1].time=int(view.time)
	main.set_time(0)
	# Fixed view timing excludes shader warm-up, screenshots, and region setup.
	var summit:Dictionary=fixed_cameras[0]
	await main.qa_capture(main.qa_mode+"_summit_timing",Vector3(summit.eye[0],summit.eye[1],summit.eye[2]),Vector3(summit.target[0],summit.target[1],summit.target[2]))
	collecting=true;render_probe.start()
	await main.get_tree().create_timer(10.0).timeout
	collecting=false;render_probe.stop()
	# Independent route starts; no teleport between points in each route.
	main.watch_camera.current=false;main.player.camera.current=true
	main.player.position=w.surface(0,-330,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	if await walk(Vector2(0,-377)):await walk(Vector2(0,-330))
	for x in [-99,15,51]:
		var z:float=303+10*sin(x*0.015)
		main.player.position=w.surface(x,z,0.4);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		if await walk(Vector2(x,z+10)):await walk(Vector2(x,z))
	main.player.position=Vector3(0,0,350);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	var actions:Dictionary={}
	for action in w.interactions:actions[action.id]=action
	if await walk(Vector2(0,364)):
		check("pier_seat_present_reachable",actions.has("N02_SEAT") and main.player.position.distance_to(actions.N02_SEAT.pos)<1.5)
		if actions.has("N02_SEAT"):
			var before:Vector3=main.player.position
			main.activate(actions.N02_SEAT);check("pier_seat_works",main.player.seated)
			await main.get_tree().create_timer(0.4).timeout
			main.player.stand_up();check("pier_stand_returns",not main.player.seated and main.player.position.distance_to(before)<0.1)
			await walk(Vector2(0,350))
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	var missing:Array=[]
	for id in original.ids:
		if not actions.has(id):missing.append(id)
	check("original_scope",missing.is_empty() and w.spec.zones.size()==8 and w.building_bounds.size()==13,{"missing":missing,"current_ids":actions.size()})
	frames.sort();var total:=0.0;var slow:=0;var failures:=0
	for ms in frames:total+=ms;slow+=1 if ms>100 else 0
	for row in checks:failures+=0 if row.passed else 1
	var performance:={"frames":frames.size(),"average_fps":1000.0*frames.size()/maxf(total,0.001),"p95_ms":frames[int(frames.size()*0.95)] if not frames.is_empty() else null,"p99_ms":frames[int(frames.size()*0.99)] if not frames.is_empty() else null,"over100ms":slow,"resolution":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"scale":1.0,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"shadows":true,"scope":"10-second fixed summit view after warm-up; excludes route and screenshots, not full world tour or GPU timer"}
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"performance":performance,"render_coverage":render_probe.report(),"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","watch_far":main.watch_camera.far,"player_far":main.player.camera.far,"camera_count":fixed_cameras.size(),"scope":str(fixed_cameras.size())+" fixed daylight/dusk/night views; retained summit, beach ramps, pier walk and sitting; station-exit composition diagnosed separately; independent location starts"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
