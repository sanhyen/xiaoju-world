extends SceneTree
var main
var results:Array=[]

func _initialize():run.call_deferred()
func check(name:String,ok:bool):
	results.append({"test":name,"passed":ok});print("FEATURE ",name," ",ok)

func shot(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+name+".png")

func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	await process_frame;await process_frame
	main.qa_mode="features";main.store.directory="user://qa_isolated/features"
	await main.start_game(false);main.player.enabled=false
	main.player.position=Vector3(0,0.4,76)
	await main.world.prepare_region(main.player.position)
	main.watch_camera.position=Vector3(24,5,89);main.watch_camera.look_at(Vector3(0,9,40));main.watch_camera.current=true
	main.hud.hide();await create_timer(0.3).timeout
	await main.save_photo()
	check("photo_saved_to_isolated_directory",main.state.shots.size()==1 and FileAccess.file_exists(main.photo_directory()+"/"+main.state.shots[0]))
	main.show_pb(main.assets.size()+1);await create_timer(0.3).timeout
	check("player_photo_PB_page",main.state.pb_page==main.assets.size()+1)
	await shot("V14_pb_player_photo")
	main.close_modal();main.player.enabled=false
	check("12_distinct_gallery_assets",main.assets.size()==12)
	var gallery_actions:=0
	for a in main.world.interactions:
		if a.id.begins_with("B05_art"):gallery_actions+=1
	check("all_12_gallery_details_accessible",gallery_actions==12)
	main.hud.hide()
	var origin:Vector3=main.world.surface(173,-42)
	await main.qa_capture("V14_gallery_12",origin+Vector3(-0.5,3.1,5.7),origin+Vector3(0,2.7,-5))
	await main.show_video("B10");await create_timer(1.0).timeout
	check("stage_video_playing",main.video.is_playing() and main.video.stream_position>0.2)
	var first:Vector3=main.watch_camera.position
	for angle in [1,2,0]:
		main.viewing_angle=angle;main.set_viewing_angle()
		check("camera_"+str(angle),main.watch_camera.position!=first if angle!=0 else main.watch_camera.position==first)
	var oldtime=main.state.time
	var colors:Array=[]
	for preset in 3:
		main.world.set_venue_lighting("B10",preset);colors.append(main.world.venue_lights.B10[0].light_color)
	check("three_distinct_local_lighting_presets",colors[0]!=colors[1] and colors[1]!=colors[2] and main.state.time==oldtime)
	await create_timer(0.3).timeout;await shot("V13_theater_program")
	main.close_modal();main.player.enabled=false
	check("stage_media_released",main.video.stream==null)
	main.show_audio();main.audio_player.stream_paused=true;main.close_modal();main.show_audio()
	await create_timer(0.5).timeout
	check("new_audio_resets_pause",not main.audio_player.stream_paused and main.audio_player.get_playback_position()>0.2)
	main.close_modal();main.player.enabled=false
	check("feature_state_save",main.save_game(false))
	main.state.shots=[];await main.start_game(true);main.player.enabled=false
	check("PB_photo_index_restored",main.state.shots.size()==1)
	var seat:Dictionary={}
	for entry in main.world.interactions:
		if entry.id=="N02_SEAT":seat=entry;break
	main.player.position=seat.pos;await main.world.prepare_region(seat.pos);var standing:Vector3=main.player.position
	main.activate(seat);main.player.enabled=true
	await create_timer(0.2).timeout
	check("sit_uses_actual_bench",main.player.seated and main.player.position.distance_to(seat.data.seat)<0.02)
	var saved_ok:bool=main.save_game(false);var saved:Dictionary=main.store.read()
	check("seated_save_restores_clear_standing_point",saved_ok and Vector3(saved.position[0],saved.position[1],saved.position[2]).distance_to(standing)<0.02)
	var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=true;Input.parse_input_event(key)
	await create_timer(0.3).timeout
	key=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=false;Input.parse_input_event(key)
	check("physical_W_stands_and_walks",not main.player.seated and main.player.position.distance_to(standing)>0.15)
	main.player.enabled=false
	main.set_time(2);check("night_street_lights_on",main.world.night_lights.size()>0 and main.world.night_lights[0].light_energy>0)
	main.set_time(0);check("day_street_lights_off",main.world.night_lights[0].light_energy==0)
	main.player.position=Vector3(15,-1,364);await create_timer(0.2).timeout
	var recovery_deadline:=Time.get_ticks_msec()+5000
	while main.transitioning and Time.get_ticks_msec()<recovery_deadline:await process_frame
	check("deep_water_outside_pier_still_recovers",main.player.position.z<357 and not main.player.seated and main.world.region_ready(main.player.position))
	main.close_modal();main.player.enabled=true
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);main.player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check("automated_QA_ignores_focus_pause",not main.modal.visible and main.player.enabled)
	main.qa_mode="";main.player.ignore_focus_loss=false
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);main.player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check("normal_game_keeps_focus_pause",main.modal.visible and not main.player.enabled)
	main.qa_mode="features";main.close_modal();main.player.enabled=false
	await create_timer(0.8).timeout
	var forced_before:int=main.qa_forced_draws
	RenderingServer.render_loop_enabled=false
	await create_timer(0.2).timeout
	await main.qa_frame()
	RenderingServer.render_loop_enabled=true
	var captured:Image=root.get_texture().get_image()
	check("background_capture_forces_real_viewport",main.qa_forced_draws>forced_before and not captured.is_empty() and captured.get_width()==1920)
	captured.save_png("res://screenshots/r3_forced_viewport.png")
	var fail_count:=0
	for result in results:
		if not result.passed:fail_count+=1
	var f:=FileAccess.open("res://reports/visual_features.json",FileAccess.WRITE);f.store_string(JSON.stringify({"results":results,"failures":fail_count,"scope":"Actual Vulkan viewport, programmatic feature checks; does not prove every manual UI path or subjective audiovisual sync"},"\t"));f.close()
	main.stop_media();main.queue_free();await process_frame;await process_frame
	quit(1 if fail_count else 0)
