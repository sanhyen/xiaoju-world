extends "res://scripts/nature_qa.gd"
## Fixed views and actual upstairs use; independently prepared entrance/stair starts.
func run(target):
	main=target;phase="cafe_review"
	fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/cafe_cameras.json"))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.set_time(0);main.watch_camera.fov=75
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	for camera in fixed_cameras:
		await capture(camera.name,Vector3.ZERO,Vector3.ZERO)
	main.player.position=w.surface(-65,305,0.5);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	for point in [Vector2(-65,298),Vector2(-65,290),Vector2(-65,287),Vector2(-65,276)]:
		if not await walk(point):break
	main.player.position=w.surface(-59,281.7,0.5);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position)
	for point in [Vector2(-59,293.4),Vector2(-65,293.4),Vector2(-65,297.2)]:
		if not await walk(point):break
	check("cafe_terrace_remains_upstairs",main.player.position.y>3.2,{"position":str(main.player.position)})
	for action in w.interactions:
		if action.id=="B02_sea":
			main.activate(action);check("cafe_retained_seat_usable",main.player.seated)
			main.player.stand_up();check("cafe_retained_seat_exit",not main.player.seated);break
	# Glass must not let the player walk out of the upper floor after opening the wall.
	var y:float=w.surface(-65,287,0.08).y+5.2
	for side in [-1,1]:
		for z in [-4.7,0.0,4.7]:
			var from:=Vector3(-65+side*8.7,y,287+z)
			var to:=Vector3(-65+side*9.7,y,287+z)
			var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
			check("cafe_upper_boundary_"+str(side)+"_"+str(z),not hit.is_empty(),{"hit":str(hit.get("position",Vector3.ZERO))})
	var ids:Array=[]
	for action in w.interactions:ids.append(action.id)
	check("cafe_existing_actions_retained",["B02_enter","B02_sea","B02_card"].all(func(id):return id in ids))
	if not main.qa_mode.contains("before"):
		check("cafe_music_selector_present","B02_listen" in ids)
		for point in [Vector2(-65,293.4),Vector2(-62,293.4),Vector2(-62,286),Vector2(-66.5,286),Vector2(-69,285.7)]:
			if not await walk(point):break
		for action in w.interactions:
			if action.id!="B02_listen":continue
			check("cafe_music_reachable",main.player.position.distance_to(action.pos)<1.5)
			main.activate(action)
			var choices:Array=[]
			for node in main.modal.find_children("*","Button",true,false):
				if node.text.begins_with("试听 · "):choices.append(node)
			check("cafe_music_has_existing_local_choices",choices.size()>=2)
			if not choices.is_empty():
				choices[0].pressed.emit();await main.get_tree().create_timer(0.7).timeout
				check("cafe_music_choice_actually_plays",main.audio_player.playing and main.audio_player.get_playback_position()>0.2)
			main.close_modal();main.player.enabled=false
			check("cafe_music_exit_releases_stream",main.audio_player.stream==null and not main.audio_player.playing)
			break
		# Exercise the actual HUD/discovery update at the previously misclassified waterfall.
		main.player.position=w.surface(315,-302,0.5);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position);main.hud.show()
		await main.qa_capture(main.qa_mode+"_waterfall_zone_hud",Vector3(315,43,-294),Vector3(325,47,-331))
		check("waterfall_actual_HUD_is_Z08",main.current_zone=="Z08" and main.zone_label.text.begins_with("云间山林"),{"zone":main.current_zone,"text":main.zone_label.text})
		check("waterfall_zone_HUD_png",FileAccess.file_exists(main.evidence_root+"screenshots/"+main.qa_mode+"_waterfall_zone_hud.png"))
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","scope":"six actual views; front/rear entrance, stairs, terrace and upper boundary collision; no long-duration performance claim"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
