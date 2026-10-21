extends "res://scripts/nature_qa.gd"
var render_probe=preload("res://scripts/render_coverage.gd").new()

func sample(delta:float):
	super.sample(delta)
	if collecting:render_probe.sample()

func run(target):
	main=target;main.store.directory="user://qa_isolated/garden_review"
	fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/garden_077_cameras.json"))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=75
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	for view in fixed_cameras:
		main.set_time(int(view.time));await capture(view.name,Vector3.ZERO,Vector3.ZERO)
		cameras[-1].time=int(view.time)
	main.set_time(0)
	main.watch_camera.current=false;main.player.camera.current=true
	main.player.position=w.surface(-250,-80,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	collecting=true;last_usec=0;render_probe.start()
	var route_ok:=true
	for point in [Vector2(-205,-120),w.garden_loop_point(120)]:
		if not await walk(point):route_ok=false;break
	if route_ok:
		for degree in range(140,481,20):
			if not await walk(w.garden_loop_point(degree)):route_ok=false;break
	if route_ok:
		for point in [Vector2(-205,-120),Vector2(-250,-80)]:
			if not await walk(point):route_ok=false;break
	collecting=false;render_probe.stop()
	var coverage:Dictionary=render_probe.report()
	check("retained_garden_loop_complete",route_ok)
	check("retained_route_draw_coverage",coverage.duration_s>20.0 and coverage.process_coverage>=0.95 and coverage.second_coverage>=0.98 and coverage.max_no_draw_ms<1000.0,coverage)
	# 077 used a row; 080 deliberately retains the seven benches in three landscape groups.
	var seat_layout:Array=w.streamer.manifest.authored_counts.get("garden_seats_080",{}).get("layout",[])
	if seat_layout.is_empty():
		for i in 7:seat_layout.append({"x":-195.0+i*3,"z":-126.0,"yaw":PI/2,"ground_y":w.height_at(-195+i*3,-126),"legacy":true})
	check("seven_retained_garden_benches",seat_layout.size()==7)
	for i in seat_layout.size():
		var seat:Dictionary=seat_layout[i]
		var base:Vector3=w.surface(seat.x,seat.z,0.0 if seat.has("legacy") else 0.02)
		main.player.position=base+Basis(Vector3.UP,seat.yaw)*Vector3(0,0.4,1.25)
		await w.prepare_region(base)
		await main.get_tree().physics_frame
		await main.get_tree().physics_frame
		var basis:=Basis(Vector3.UP,seat.yaw)
		var ray:=PhysicsRayQueryParameters3D.create(base+basis*Vector3(0,0.30,0.65),base+basis*Vector3(0,0.30,-0.65))
		var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(ray)
		var retained:=false
		if not hit.is_empty():
			var body=hit.collider
			retained=body is Node3D and body.global_position.distance_to(base+Vector3(0,0.29,0))<0.05
		check("retained_garden_bench_"+str(i),retained)
	var actions:Dictionary={}
	for action in w.interactions:actions[action.id]=action
	if not main.qa_mode.contains("before_"):
		check("shade_seat_present",actions.has("N05_SHADE_SEAT"))
		main.player.position=w.surface(-205,-120,0.4);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		for point in [Vector2(-201,-111),Vector2(-203,-104),Vector2(-210.5,-104)]:
			if not await walk(point):break
		if actions.has("N05_SHADE_SEAT"):
			var reachable:bool=main.player.position.distance_to(actions.N05_SHADE_SEAT.pos)<1.6
			check("shade_seat_reachable",reachable)
			if reachable:
				var old:Vector3=main.player.position
				main.activate(actions.N05_SHADE_SEAT);check("shade_seat_works",main.player.seated)
				await main.get_tree().create_timer(0.4).timeout
				# Preserve a real seated-pose view; the fixed-camera set remains unchanged.
				await main.qa_capture(main.qa_mode+"_shade_seated",w.surface(-208,-100,2.3),w.surface(-212.8,-104,0.9))
				check("shade_seated_capture",FileAccess.file_exists(main.evidence_root+"screenshots/"+main.qa_mode+"_shade_seated.png"))
				main.player.stand_up();check("shade_seat_exit_restored",not main.player.seated and main.player.position.distance_to(old)<0.1)
				main.watch_camera.current=false;main.player.camera.current=true
				for point in [Vector2(-203,-104),Vector2(-201,-111),Vector2(-205,-120)]:
					if not await walk(point):break
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	var missing:Array=[]
	for id in original.ids:
		if not actions.has(id):missing.append(id)
	check("original_scope",missing.is_empty() and w.spec.zones.size()==8 and w.building_bounds.size()==13,{"missing":missing,"current_ids":actions.size()})
	var action_ids:Array=actions.keys();action_ids.sort()
	frames.sort();var total:=0.0;var slow:=0;var failures:=0
	for ms in frames:total+=ms;slow+=1 if ms>100 else 0
	for row in checks:failures+=0 if row.passed else 1
	var performance:={"frames":frames.size(),"average_fps":1000.0*frames.size()/maxf(total,0.001),"p95_ms":frames[int(frames.size()*0.95)] if not frames.is_empty() else null,"p99_ms":frames[int(frames.size()*0.99)] if not frames.is_empty() else null,"over100ms":slow,"resolution":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"scale":1.0,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"shadows":true,"scope":"Retained music-to-garden loop real-controller walk; excludes screenshots and new shade-seat probe; not full-world long tour"}
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"performance":performance,"render_coverage":coverage,"retained_route_complete":route_ok,"action_ids":action_ids,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","garden":w.streamer.manifest.authored_counts.get("garden_077",{}),"groves":w.streamer.manifest.authored_counts.get("lowland_v12",{}),"scope":"N05 garden and eight lowland transition groups; whole-world acceptance remains separate"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
