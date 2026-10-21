extends SceneTree
var main
var results:Array=[]
func _initialize():run.call_deferred()
func check(name:String,passed:bool,detail:Dictionary={}):
	results.append({"test":name,"passed":passed,"detail":detail});print("PROGRAM_TEST ",name," ",passed)

func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	main.qa_mode="programs";main.store.directory="user://qa_isolated/programs"
	await main.start_game(false);main.player.enabled=false
	check("five_distinct_source_mapped_programs",main.programs.size()==5)
	for item in [["rehearsal","B08"],["wall_stage","B10"],["moon_episode8","B06"],["wall_audio","B06"],["sunset","B10"]]:
		await main.show_video(item[1],item[0]);await create_timer(1.1).timeout
		var position:float=main.video.stream_position
		check(item[0]+"_plays_on_real_screen",main.video.is_playing() and position>0.3 and is_instance_valid(main.watch_screen),{"position_s":position,"resource":main.video.stream.resource_path if main.video.stream!=null else ""})
		main.video.paused=true;await create_timer(0.3).timeout
		check(item[0]+"_pause_holds_playhead",absf(main.video.stream_position-position)<0.12)
		main.video.paused=false
		await main.qa_frame();root.get_texture().get_image().save_png("res://screenshots/art_v11_program_"+str(item[0])+".png")
		main.close_modal();main.player.enabled=false
		check(item[0]+"_exit_frees_stream",main.video.stream==null and main.watch_screen==null and main.video_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	for id in ["sunset","wall_audio"]:
		main.show_audio(id);await create_timer(0.6).timeout
		check(id+"_audio_advances",main.audio_player.playing and main.audio_player.get_playback_position()>0.2)
		main.close_modal();main.player.enabled=false
		check(id+"_audio_released",main.audio_player.stream==null and not main.audio_player.playing)
	main.show_program_selector("B08",false)
	var found:=false
	for node in main.modal.find_children("*","Button",true,false):
		if "彩排直拍" in node.text:found=true;break
	check("dance_catalog_has_actual_rehearsal",found)
	main.close_modal();main.player.enabled=false
	for name in ["Master","Music","Media","Environment","Interface"]:check(name+"_bus_exists",AudioServer.get_bus_index(name)>=0)
	main.settings.environment_volume=0;main.save_settings()
	check("environment_mute_does_not_mute_music",AudioServer.is_bus_mute(AudioServer.get_bus_index("Environment")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	main.settings.environment_volume=0.75;main.save_settings()
	check("media_players_are_on_distinct_buses",main.audio_player.bus=="Music" and main.video.bus=="Media" and main.interface_player.bus=="Interface")
	var loops:=true
	for sound in main.world.ambient_sources:loops=loops and sound.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD
	check("ambient_streams_loop_instead_of_ending",loops and main.world.ambient_sources.size()==6)
	main.show_settings();await create_timer(0.2).timeout;await main.qa_frame();root.get_texture().get_image().save_png("res://screenshots/art_v11_settings_mix.png")
	main.close_modal();main.player.enabled=false
	var failed:=0
	for row in results:if not row.passed:failed+=1
	var file:=FileAccess.open("res://reports/theme_programs.json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failed,"scope":"actual GPU program start/pause/exit and sound controls; sampled frames, not complete-video or listening acceptance"},"\t"));file.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
