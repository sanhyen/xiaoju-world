extends "res://scripts/nature_qa.gd"
## B03 source-mapped listening, artwork details, physical route and retained collection.
func run(target):
	main=target;main.store.directory="user://qa_isolated/records_review"
	var reading:bool=main.qa_mode.ends_with("read")
	await main.start_game(reading);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=70;main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	if reading:
		check("independent_process_restores_audio_collection",["sunset","wall_audio"].all(func(id):return id in main.state.photos))
		main.show_audio("wall_audio");await main.get_tree().create_timer(0.5).timeout
		check("restored_item_still_plays",main.audio_player.playing and main.audio_player.get_playback_position()>0.2)
		main.close_modal();check("restored_item_releases_on_exit",main.audio_player.stream==null)
	else:
		fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/records_cameras.json"))
		for view in fixed_cameras:
			main.set_time(int(view.time));await capture(view.name,Vector3.ZERO,Vector3.ZERO);cameras[-1].time=int(view.time)
		main.set_time(0)
		var w=main.world;var actions:Dictionary={}
		for action in w.interactions:actions[action.id]=action
		check("original_record_actions_retained",["B03_enter","B03_listen","B03_cover"].all(func(id):return actions.has(id)))
		main.player.position=w.surface(-97,202,0.4);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
		for point in [Vector2(-97,196),Vector2(-97,192),Vector2(-97,188),Vector2(-97,185.6)]:
			if not await walk(point):break
		if actions.has("B03_listen"):
			check("listening_console_reachable",main.player.position.distance_to(actions.B03_listen.pos)<1.5)
			main.activate(actions.B03_listen);await main.qa_frame()
			var entries:=0
			for node in main.modal.find_children("*","Button",true,false):
				if node.text.begins_with("试听 · "):entries+=1
			check("catalog_lists_two_real_audio_items",entries==2)
		for id in ["sunset","wall_audio"]:
			var record:Dictionary=main.program_for(id)
			main.show_program_selector("B03",true);await main.qa_frame()
			var selected:=false
			for node in main.modal.find_children("*","Button",true,false):
				if node.text=="试听 · "+str(record.get("display_title",record.title)):
					node.pressed.emit();selected=true;break
			check(id+"_selected_from_actual_catalog",selected)
			await main.get_tree().create_timer(0.5).timeout
			check(id+"_source_mapped_audio_advances",main.audio_player.playing and main.audio_player.get_playback_position()>0.2 and main.audio_player.stream.resource_path=="res://"+record.audio)
			await main.qa_frame()
			get_image_evidence("audio_"+id)
			for node in main.modal.find_children("*","Button",true,false):
				if node.text=="暂停 / 继续":node.pressed.emit();break
			var position:float=main.audio_player.get_playback_position();await main.get_tree().create_timer(0.2).timeout
			check(id+"_pause_holds_playhead",main.audio_player.stream_paused and absf(main.audio_player.get_playback_position()-position)<0.12)
			for node in main.modal.find_children("*","Button",true,false):
				if node.text=="收藏试听条目":node.pressed.emit();node.pressed.emit();break
			check(id+"_collection_idempotent",main.state.photos.count(id)==1)
			main.close_modal();main.player.enabled=false;main.hud.hide()
			check(id+"_exit_releases_audio",main.audio_player.stream==null and not main.audio_player.playing)
		await walk(Vector2(-92,184.5))
		if actions.has("B03_cover"):
			check("photo_details_reachable",main.player.position.distance_to(actions.B03_cover.pos)<1.5)
			# The right wall is portrait_07, index 6. This also catches the old index-5 mismatch.
			check("right_wall_details_match_actual_photo",int(actions.B03_cover.data.index)==6,{"actual_index":int(actions.B03_cover.data.index),"right_wall":"portrait_07"})
			main.activate(actions.B03_cover);await main.qa_frame()
			check("photo_details_open",main.modal.visible)
			var matched:=false
			for node in main.modal.find_children("*","TextureRect",true,false):
				if node.texture!=null and node.texture.resource_path=="res://"+str(main.assets[6].runtime_path):matched=true
			check("photo_panel_loads_correct_source_texture",matched)
			get_image_evidence("photo_details")
			main.close_modal();main.player.enabled=false;main.hud.hide()
		# Return around the front of the physical listening desk, not straight through its top.
		for point in [Vector2(-94.5,185.7),Vector2(-97,185.7),Vector2(-97,191),Vector2(-97,196),Vector2(-97,202)]:
			if not await walk(point):break
		check("listening_collection_saved",main.save_game(false))
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","scope":"fixed B03 views, actual controller route, audio start/pause/collection/release and separate readback; not full listening or human input acceptance"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)

func get_image_evidence(name:String):
	var result:int=main.get_viewport().get_texture().get_image().save_png(main.evidence_root+"screenshots/"+main.qa_mode+"_"+name+".png")
	check(name+"_ui_capture",result==OK)
