extends "res://scripts/nature_qa.gd"
var render_probe=preload("res://scripts/render_coverage.gd").new()

func sample(delta:float):
	super.sample(delta)
	if collecting:render_probe.sample()
## Six immutable views and actual walking: original beach ramps plus new connected garden.

func run(target):
	main=target;phase="coast_review"
	fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/coast_cameras.json"))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.set_time(0);main.watch_camera.fov=75
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	for camera in fixed_cameras:
		main.player.position=Vector3(camera.eye[0],camera.eye[1],camera.eye[2]);main.player.velocity=Vector3.ZERO
		await capture(camera.name,Vector3.ZERO,Vector3.ZERO)
	# Probe actual terrain triangle collision at designed banks; works for before and after.
	for point in [Vector2(-126.7,272.9),Vector2(-184.7,277.3),Vector2(56.7,273.3),Vector2(143.2,278.2),Vector2(-146,282.8)]:
		var y:float=w.height_at(point.x,point.y);var start:=Vector3(point.x,y+0.65,point.y)
		await w.prepare_region(start);await main.get_tree().physics_frame
		var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start-Vector3(0,1.25,0)))
		var difference:float=absf(hit.position.y-y) if not hit.is_empty() else 999.0
		check("coast_ground_"+str(point),difference<0.20,{"difference_m":difference,"height":y})
	main.player.position=w.surface(-105,293.001,0.5);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	collecting=true;render_probe.start()
	var route:Array[Vector2]=[Vector2(-105,293.001),Vector2(-113,285),Vector2(-133,285),Vector2(-146,286),Vector2(-159,290),Vector2(-162,296.47)]
	var passed:=true
	for point in route:
		if not await walk(point):passed=false;break
	if passed:
		route.reverse()
		for point in route:
			if not await walk(point):passed=false;break
	collecting=false;render_probe.stop()
	# Original three openings must remain usable with new dunes and planting beside them.
	for x in [-99,15,51]:
		var z:float=303+10*sin(x*0.015)
		main.player.position=w.surface(x,z,0.5);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		if await walk(Vector2(x,z+10)):await walk(Vector2(x,z))
	if not main.qa_mode.contains("before"):
		var action:Dictionary={}
		for record in w.interactions:
			if record.id=="N01_GARDEN_SEAT":action=record;break
		check("coast_garden_seat_present",not action.is_empty())
		if not action.is_empty():
			main.player.position=w.surface(-146,286,0.5);main.player.velocity=Vector3.ZERO
			await w.prepare_region(main.player.position)
			if await walk(Vector2(action.pos.x,action.pos.z)):
				var exit_position:Vector3=main.player.position
				main.activate(action);check("coast_garden_seat_usable",main.player.seated)
				await main.get_tree().create_timer(0.4).timeout
				main.player.stand_up();check("coast_garden_stand_returns_to_approach",not main.player.seated and main.player.position.distance_to(exit_position)<0.1)
				await walk(Vector2(-146,286))
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	var ids:Array=[]
	for action in w.interactions:ids.append(action.id)
	var missing:Array=[]
	for id in original.ids:
		if id not in ids:missing.append(id)
	check("coast_original_world_scope",missing.is_empty() and w.spec.zones.size()==8 and w.building_bounds.size()==13,{"missing_original_ids":missing,"current_ids":ids.size()})
	frames.sort();var total:=0.0;var slow:=0;var failures:=0
	for ms in frames:total+=ms;slow+=1 if ms>100 else 0
	for row in checks:failures+=0 if row.passed else 1
	var performance:={"frames":frames.size(),"average_fps":1000.0*frames.size()/maxf(total,0.001),"p95_ms":frames[int(frames.size()*0.95)],"p99_ms":frames[int(frames.size()*0.99)],"over100ms":slow,"resolution":[1920,1080],"scale":1.0,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"shadows":true,"scope":"new coastal loop roundtrip only; other checks have separate independent starts"}
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"performance":performance,"coast_counts":w.streamer.manifest.authored_counts.get("coast_v12",{}),"runtime":"editor_binary" if OS.has_feature("editor") else "export_release"}
	report.render_coverage=render_probe.report()
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COAST_TERMINAL ",JSON.stringify({"failures":failures,"performance":performance}));main.get_tree().quit(1 if failures else 0)
