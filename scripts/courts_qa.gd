extends "res://scripts/interiors_qa.gd"
## Retained N09/N10 places: fixed viewpoints, actual access and existing media/photo actions.
var render_probe=preload("res://scripts/render_coverage.gd").new()
func sample(delta:float):
	super.sample(delta)
	if collecting:render_probe.sample()

func run(target):
	main=target;main.store.directory="user://qa_isolated/courts_review"
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=70;main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	for item in JSON.parse_string(FileAccess.get_file_as_string("res://data/courts_075_cameras.json")):
		var origin:Vector3=w.surface(item.anchor[0],item.anchor[1])
		var view:Dictionary=item.duplicate(true)
		for key in ["eye","target"]:
			var p:Vector3=origin+Vector3(item[key][0],item[key][1],item[key][2]);view[key]=[p.x,p.y,p.z]
		fixed_cameras.append(view)
	for view in fixed_cameras:
		main.set_time(int(view.time));await capture(view.name,Vector3.ZERO,Vector3.ZERO);cameras[-1].time=int(view.time)
	main.set_time(0)
	var actions:Dictionary={}
	for action in w.interactions:actions[action.id]=action
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	var missing:Array=[]
	for id in original.ids:
		if not actions.has(id):missing.append(id)
	check("original_scope",missing.is_empty() and w.spec.zones.size()==8 and w.building_bounds.size()==13,{"missing":missing,"current_ids":actions.size()})
	main.player.position=w.surface(-226,145,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	collecting=true;render_probe.start()
	for point in [Vector2(-227,125),Vector2(-227,122),Vector2(-227,118),Vector2(-227,114),Vector2(-227,118),Vector2(-227,122)]:
		if not await walk(point):break
	check("stage_action_retained",actions.has("N09_STAGE"))
	if actions.has("N09_STAGE"):
		check("stage_action_reachable",main.player.position.distance_to(actions.N09_STAGE.pos)<1.5)
		main.activate(actions.N09_STAGE);await main.qa_frame();await snap("stage_programs")
		check("stage_program_menu",main.modal.visible and has_heading("试听曲目"))
		var played:=false
		for node in main.modal.find_children("*","Button",true,false):
			if node.text.begins_with("试听 · "):node.pressed.emit();played=true;break
		await main.get_tree().create_timer(0.6).timeout
		var position:float=main.audio_player.get_playback_position()
		await main.get_tree().create_timer(0.6).timeout
		check("stage_actual_audio_advances",played and main.audio_player.playing and main.audio_player.get_playback_position()>position)
		main.close_modal();main.player.enabled=false;main.hud.hide()
		check("stage_close_stops_audio",not main.audio_player.playing)
	if not main.qa_mode.contains("before"):
		await walk(Vector2(-232,122.9))
		check("stage_light_action_reachable",actions.has("N09_LIGHT") and main.player.position.distance_to(actions.N09_LIGHT.pos)<1.5)
		if actions.has("N09_LIGHT"):
			var lamps:Array=w.venue_lights.get("N09",[])
			main.set_time(2)
			var light_view:Dictionary=fixed_cameras.filter(func(view):return view.name=="stage_night")[0]
			var light_eye:=Vector3(light_view.eye[0],light_view.eye[1],light_view.eye[2])
			var light_target:=Vector3(light_view.target[0],light_view.target[1],light_view.target[2])
			for lamp in lamps:lamp.light_energy=0
			await main.qa_capture(main.qa_mode+"_stage_lights_off",light_eye,light_target)
			check("stage_off_capture_keeps_lights_off",lamps.size()==2 and lamps.all(func(lamp):return is_zero_approx(lamp.light_energy)))
			main.activate(actions.N09_LIGHT)
			check("stage_switch_changes_actual_lights",lamps.size()==2 and w.stage_presets.get("N09",-1)==1 and lamps[0].light_color.is_equal_approx(Color("c6acdf")) and is_equal_approx(lamps[0].light_energy,2.3))
			await main.qa_capture(main.qa_mode+"_stage_lights_color",light_eye,light_target)
			w.set_venue_lighting("N09",0)
			main.set_time(0);main.watch_camera.current=false;main.player.camera.current=true
		await walk(Vector2(-232,125));await walk(Vector2(-234,126.9))
		for i in 8:await main.get_tree().physics_frame
		var floor_query:=PhysicsRayQueryParameters3D.create(main.player.position+Vector3.UP*0.4,main.player.position-Vector3.UP*0.2)
		floor_query.exclude=[main.player.get_rid()]
		var floor_hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(floor_query)
		var capsule:CollisionShape3D=null
		for child in main.player.get_children():
			if child is CollisionShape3D and child.shape is CapsuleShape3D:capsule=child;break
		var bottom:float=main.player.position.y+capsule.position.y-capsule.shape.height/2 if capsule!=null else INF
		check("stage_front_audience_tier_accessible",main.player.is_on_floor() and not floor_hit.is_empty() and floor_hit.position.y>w.height_at(-234,126.9)+0.10 and absf(bottom-floor_hit.position.y)<0.035,{"origin_y":main.player.position.y,"capsule_bottom_y":bottom,"platform_hit":str(floor_hit.get("position",Vector3.ZERO))})
		await walk(Vector2(-232,125))
	for point in [Vector2(-227,125),Vector2(-226,145)]:
		if not await walk(point):break
	main.player.position=w.surface(212,-98,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	for point in [Vector2(195,-112),Vector2(185,-110),Vector2(180,-110)]:
		if not await walk(point):break
	check("court_action_retained",actions.has("N10_SET"))
	if actions.has("N10_SET"):
		check("court_action_reachable",main.player.position.distance_to(actions.N10_SET.pos)<1.5)
		main.player.yaw=0
		main.activate(actions.N10_SET);await main.qa_frame();await snap("court_photo_mode")
		check("court_enters_photo_mode",main.photo_mode and not main.hud.visible)
		main.close_modal();main.player.enabled=false;main.hud.hide()
	if not main.qa_mode.contains("before"):
		for point in [Vector2(185,-110),Vector2(185,-115),Vector2(176,-115),Vector2(194,-115),Vector2(195,-112),Vector2(202,-108.5)]:
			if not await walk(point):break
		var frame:Vector3=w.surface(185,-112)
		for x in [-3.9,3.9]:
			var window:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(frame+Vector3(x,1.4,-0.8),frame+Vector3(x,1.4,-2.5)))
			var sill:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(frame+Vector3(x,0.4,-0.8),frame+Vector3(x,0.4,-2.5)))
			check("court_window_void_and_sill_"+str(x),window.is_empty() and not sill.is_empty())
		check("court_archive_reachable",actions.has("N10_ARCHIVE") and main.player.position.distance_to(actions.N10_ARCHIVE.pos)<1.5)
		if actions.has("N10_ARCHIVE"):
			main.activate(actions.N10_ARCHIVE);await main.qa_frame();await snap("court_archive")
			check("court_archive_original_context",has_heading("光影庭院 · 原创布景"))
			check("court_archive_opens_local_programs",press("查看本地影像节目") and has_heading("场馆节目册"))
			await main.qa_frame();await snap("court_archive_programs")
			var local_choices:=0
			for node in main.modal.find_children("*","Button",true,false):
				if node.text.begins_with("观看 · "):local_choices+=1
			check("court_archive_has_real_program_choices",local_choices>0)
			press("返回");check("court_programs_return_to_original_context",has_heading("光影庭院 · 原创布景"))
			check("court_archive_source_entry",press("素材与来源") and has_heading("素材与关于"))
			press("返回");check("court_sources_return_to_original_context",has_heading("光影庭院 · 原创布景"))
			check("court_archive_photo_entry",press("进入庭院取景") and main.photo_mode and not main.modal.visible)
			main.close_modal();main.player.enabled=false;main.hud.hide()
		# Return along the new spur to its junction, rather than through the retained bench.
		await walk(Vector2(195,-112))
	for point in [Vector2(185,-110),Vector2(195,-112),Vector2(212,-98)]:
		if not await walk(point):break
	collecting=false;render_probe.stop();frames.sort()
	var total:=0.0;var slow:=0
	for ms in frames:total+=ms;slow+=1 if ms>100 else 0
	var performance:={"frames":frames.size(),"average_fps":1000.0*frames.size()/maxf(total,0.001),"p95_ms":frames[int(frames.size()*0.95)] if not frames.is_empty() else null,"p99_ms":frames[int(frames.size()*0.99)] if not frames.is_empty() else null,"over100ms":slow,"resolution":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"scale":1.0,"shadows":true,"scope":"Scripted stage and courtyard access, UI and light captures with two independent location starts; includes inter-location preparation, not a continuous world tour or GPU timer"}
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"scope":"8 fixed daylight/night views, actual stage ramp and court return, existing audio progression/stop and photo-mode entry; not long media or human input acceptance","runtime":"editor_binary" if OS.has_feature("editor") else "export_release"}
	report.performance=performance;report.render_coverage=render_probe.report()
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
