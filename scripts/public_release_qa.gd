extends "res://scripts/design120_qa.gd"

func capture(name:String):
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var path:String=m.evidence_root+"screenshots/public_"+name+".png"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error:int=m.get_viewport().get_texture().get_image().save_png(path)
	record("screenshot_"+name,error==OK)

func finish():
	var failures:Array=results.filter(func(item):return not item.ok)
	var output:Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"checks":results,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":m.get_viewport().get_visible_rect().size,"profile":ProjectSettings.get_setting("application/config/name"),"scope":"Public media, preserved catalog, UI, local library and save/restore smoke; not full-world art or performance acceptance"}
	var file:=FileAccess.open(m.evidence_root+"reports/"+m.qa_mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"));file.close()
	print("PUBLIC_RELEASE_COMPLETE ",JSON.stringify({"checks":results.size(),"failed":failures.size(),"mode":m.qa_mode}))
	m.get_tree().quit(0 if failures.is_empty() else 1)

func run(main):
	m=main
	m.store.directory="user://save/open_v1"
	m.store.import_directory=""
	record("public_profile_is_separate",ProjectSettings.get_setting("application/config/name")=="小鞠世界 · 开源试玩版")
	record("public_save_directory",m.store.directory=="user://save/open_v1" and m.store.import_directory.is_empty())
	if m.qa_mode=="public_restore":
		await m.start_game(true)
		record("cold_restore_marker",m.state.get("public_release_marker","")=="public-smoke-1")
		record("cold_restore_collection","portrait_01" in m.state.photos)
		record("cold_restore_pb_page",int(m.state.pb_page)==1)
		finish()
		return
	await m.get_tree().create_timer(.3).timeout
	capture("menu")
	await m.start_game(false)
	record("new_game_starts",m.active_game and not m.transitioning)
	scope_contracts()
	var all_present:=true
	for item in m.assets:
		all_present=all_present and ResourceLoader.exists("res://"+str(item.runtime_path)) and str(item.get("rights",""))=="MIT"
	for item in m.programs:
		for key in ["video","audio","poster"]:
			if not str(item.get(key,"")).is_empty():all_present=all_present and ResourceLoader.exists("res://"+str(item[key]))
		record("demo_metadata_"+str(item.asset_id),str(item.rights)=="MIT" and absf(float(item.duration_s)-8)<.01)
	record("all_public_media_resources_present",all_present)
	m.show_photo(0)
	await m.get_tree().process_frame
	var textures:Array=m.modal.find_children("*","TextureRect",true,false)
	record("photo_view_has_texture",not textures.is_empty() and textures[0].texture!=null)
	capture("gallery")
	m.close_modal()
	m.show_pb(1)
	await m.get_tree().process_frame
	record("pb_spread_and_navigation",m.modal.find_child("PBSpread",true,false)!=null and m.modal.find_child("PBImageOpen_0",true,false)!=null)
	capture("pb")
	m.close_modal()
	m.show_map()
	await m.get_tree().process_frame
	record("map_opens",m.modal.visible and m.modal.get_child_count()>0)
	m.close_modal()
	var original:Vector3=m.player.position
	var moved:bool=await move_to(Vector3(0,8,80))
	record("plaza_stream_ready",moved)
	m.player.yaw=0;m.player.pitch=-.18;m.player.enabled=true
	await m.get_tree().create_timer(.4).timeout
	capture("world")
	record("return_to_spawn_stream_ready",await move_to(original))
	m.show_audio("sunset")
	await m.get_tree().create_timer(.6).timeout
	record("demo_audio_advances",m.audio_player.playing and m.audio_player.get_playback_position()>.1)
	m.close_modal()
	record("audio_stops_on_exit",not m.audio_player.playing)
	record("cinema_region_ready",await move_to(Vector3(252,15.8,-195)))
	await m.show_video("B06","sunset")
	await m.get_tree().create_timer(1.2).timeout
	record("demo_video_advances",m.video.is_playing() and m.video.stream_position>.3,{"position_s":m.video.stream_position})
	capture("cinema")
	await m.get_tree().create_timer(7.5).timeout
	record("demo_video_reaches_end",not m.video.is_playing())
	m.close_modal()
	record("video_decoder_stops_on_exit",not m.video.is_playing() and m.video.stream==null)
	var library_path:String=m.personal_directory()+"/library.json"
	record("library_path_is_local",m.personal_directory().ends_with("/UserMedia"))
	if FileAccess.file_exists(library_path):
		var library=JSON.parse_string(FileAccess.get_file_as_string(library_path))
		record("personal_import_index_readable",library is Array and library.size()==1)
		m.show_personal_library()
		await m.get_tree().process_frame
		record("personal_library_opens",m.modal.visible)
		m.close_modal()
	else:record("personal_import_index_readable",false,{"reason":"Fixture was not prepared by the release runner"})
	if not "portrait_01" in m.state.photos:m.state.photos.append("portrait_01")
	m.state.pb_page=1;m.state.public_release_marker="public-smoke-1"
	m.save_game(false)
	var restored:Dictionary=m.store.decode(m.store.directory+"/progress.json")
	record("saved_collection_and_marker",restored.get("public_release_marker","")=="public-smoke-1" and "portrait_01" in restored.get("photos",[]))
	finish()
