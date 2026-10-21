extends RefCounted
var main
var checks:Array=[]
var render_probe=preload("res://scripts/render_coverage.gd").new()
var collecting:=false
var forced_draw_mode:=false
var forced_draw_requests:=0

func sample(_delta:float):
	# main._process calls this interface for every installed QA driver.
	if collecting:
		render_probe.sample()
		# An occluded Windows QA window can process input/physics while skipping draws.
		# Request real rendering only after a measured callback gap; record every request.
		if Time.get_ticks_usec()-render_probe.last_draw_usec>120000:forced_draw_mode=true
		if forced_draw_mode:
			RenderingServer.force_draw(false)
			forced_draw_requests+=1

func check(name:String,passed:bool,detail:Dictionary={}):
	checks.append({"test":name,"passed":passed,"detail":detail})
	print("BATCH_SMOKE ",name," ",passed)

func walk(point:Vector2)->bool:
	var p=main.player
	p.automated_motion=true
	var deadline:=Time.get_ticks_msec()+6000
	while Time.get_ticks_msec()<deadline:
		var distance:=point-Vector2(p.position.x,p.position.z)
		if distance.length()<0.45:
			p.automated_horizontal=Vector2.ZERO;p.automated_motion=false
			return true
		p.automated_horizontal=distance.normalized()*5.5
		await main.get_tree().physics_frame
	p.automated_horizontal=Vector2.ZERO;p.automated_motion=false
	return false

func run(target):
	var start:=Time.get_ticks_msec()
	main=target
	main.store.directory="user://qa_isolated/"+main.qa_mode
	await main.get_tree().physics_frame
	await main.start_game(false)
	main.player.enabled=false;main.player.program_driven=true;main.player.ignore_focus_loss=true
	main.menu.hide()
	collecting=true;render_probe.start()
	var w=main.world
	var counts:Dictionary=w.streamer.manifest.authored_counts
	check("scope_eight_zones_thirteen_venues",w.spec.zones.size()==8 and w.building_bounds.size()==13)
	var ids:Array=[]
	for action in w.interactions:ids.append(action.id)
	var missing:Array=[]
	var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	for id in contract.ids:
		if not ids.has(id):missing.append(id)
	check("original_actions_retained",missing.is_empty() and ids.size()>=82,{"current_actions":ids.size(),"missing":missing})
	check("count_of_colliders_retained",counts.colliders==2853)
	check("summit_physical_pitched_roof_baked",counts.get("summit_080",{}).get("roof_type","")=="two physical gable planes")
	var seats:Dictionary=counts.get("garden_seats_080",{})
	check("seven_benches_three_groups",seats.get("benches",0)==7 and seats.get("groups",0)==3)
	for i in seats.get("layout",[]).size():
		var seat:Dictionary=seats.layout[i]
		var base:Vector3=w.surface(seat.x,seat.z,0.02)
		main.player.position=base+Basis(Vector3.UP,seat.yaw)*Vector3(0,0.4,1.25)
		main.player.velocity=Vector3.ZERO
		await w.prepare_region(base)
		await main.get_tree().physics_frame
		await main.get_tree().physics_frame
		var basis:=Basis(Vector3.UP,seat.yaw)
		var ray:=PhysicsRayQueryParameters3D.create(base+basis*Vector3(0,0.30,0.65),base+basis*Vector3(0,0.30,-0.65))
		var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(ray)
		check("bench_collider_"+str(i),not hit.is_empty() and hit.collider.global_position.distance_to(base+Vector3(0,0.29,0))<0.05,{"base":str(base),"hit":str(hit.position) if not hit.is_empty() else "none","body":str(hit.collider.global_position) if not hit.is_empty() else "none"})
		var query:=PhysicsShapeQueryParameters3D.new()
		var capsule:=CapsuleShape3D.new();capsule.radius=0.30;capsule.height=1.6
		query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,base+basis*Vector3(0,0.95,1.25))
		query.exclude=[main.player.get_rid()]
		var blocked:Array=w.get_world_3d().direct_space_state.intersect_shape(query,8)
		check("bench_front_approach_clear_"+str(i),blocked.is_empty(),{"bodies":str(blocked)})
		check("bench_clear_of_retained_routes_"+str(i),w.clear_of_paths(Vector2(seat.x,seat.z),1.85))
	# Exercise the existing activation and ordinary movement-key exit on all nine new seats.
	for id in ["N05_SEAT_01","N05_SEAT_02","N05_SEAT_03","N05_SEAT_04","N05_SEAT_05","N05_SEAT_06","N05_SEAT_07","N08_SEAT_W","N08_SEAT_E"]:
		var action:Dictionary={}
		for candidate in w.interactions:
			if candidate.id==id:action=candidate;break
		check(id+"_action_present",not action.is_empty())
		if action.is_empty():continue
		main.player.position=action.pos+Vector3(0,0.22,0);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		await main.get_tree().physics_frame;await main.get_tree().physics_frame
		var exit_position:Vector3=main.player.position
		main.activate(action)
		check(id+"_sits_at_authored_anchor",main.player.seated and main.player.position.distance_to(action.data.seat)<0.01)
		main.player.enabled=true;main.player.program_driven=false
		var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=true
		Input.parse_input_event(key);Input.flush_buffered_events()
		for tick in 12:
			await main.get_tree().physics_frame
			if not main.player.seated:break
		key=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=false
		Input.parse_input_event(key);Input.flush_buffered_events()
		await main.get_tree().process_frame
		check(id+"_ordinary_movement_stands_up",not main.player.seated and main.player.position.distance_to(exit_position)<0.5)
		main.player.stand_up() # Cleanup only after the real exit assertion; do not cascade one failure.
		main.player.enabled=false;main.player.program_driven=true;main.player.velocity=Vector3.ZERO
	var cover:Dictionary=counts.get("groundcover_081",{})
	var zones:Array=[]
	for patch in cover.get("patches",[]):
		if patch.actual>0 and not zones.has(patch.zone):zones.append(patch.zone)
	check("groundcover_has_actual_pockets_in_eight_zones",zones.size()==8,{"zones":zones,"clumps":cover.get("grass_clumps",0),"bare_soil":cover.get("bare_soil_patches",0)})
	check("groundcover_without_new_collision",cover.get("colliders_added",-1)==0)
	check("shared_paving_grid_baked",counts.get("paths_079",{}).get("paving_grid","")=="shared world XZ grid from081")
	main.player.position=w.surface(-237,-146.5,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	check("cottage_forecourt_walk",await walk(Vector2(-226,-146.5)))
	main.player.position=w.surface(-176.5,-133.5,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	check("east_seats_front_walk",await walk(Vector2(-173.5,-142.5)))
	main.player.position=w.surface(0,-365,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	check("summit_existing_ramp_walk",await walk(Vector2(0,-377)))
	check("summit_action_retained",ids.has("N08_TOP"))
	check("garden_narrow_paving_baked",counts.paths_079.get("garden_paved_routes",0)>0 and counts.paths_079.get("narrow_paved_routes",0)>0)
	check("summit_paving_and_attached_nameplate_baked",counts.summit_080.get("paving_joints",0)==21 and counts.summit_080.get("supported_nameplate",false))
	main.player.position=w.surface(w.garden_loop_point(100).x,w.garden_loop_point(100).y,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	for degree in [120,140,160,180]:
		check("garden_existing_arc_"+str(degree),await walk(w.garden_loop_point(degree)))
	if has_method("check_batch_extension"):await call("check_batch_extension",w,counts)
	collecting=false;render_probe.stop()
	var coverage:Dictionary=render_probe.report()
	check("render_callbacks_during_batch",coverage.duration_s>5.0 and coverage.process_coverage>=0.95 and coverage.second_coverage>=0.95,coverage)
	var failures:=0
	for item in checks:
		if not item.passed:failures+=1
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"duration_s":(Time.get_ticks_msec()-start)/1000.0,"renderer":RenderingServer.get_current_rendering_method(),"scope":"One targeted batch check: rendering, physical bench approach, nine actual sit/ordinary-key exits, summit ramp and cottage access. No repeated full regression or image review; no formal art or S1-S6 acceptance."}
	var f:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE)
	report.render_coverage=coverage
	report.forced_draw_requests=forced_draw_requests
	report.render_measurement_limit="Completed callbacks under QA's recorded redraw requests, not foreground-only GPU timing or human input acceptance."
	f.store_string(JSON.stringify(report,"\t"));f.close()
	print("BATCH_SMOKE_TERMINAL ",failures)
	main.get_tree().quit(1 if failures else 0)
