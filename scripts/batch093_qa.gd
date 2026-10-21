extends RefCounted
var main
var checks:Array=[]
var samples:Array=[]
var started:=0
var draw_probe=preload("res://scripts/render_coverage.gd").new()
var forced_draws:=0

func sample(delta:float):
	if started==0:return
	samples.append(delta*1000.0);draw_probe.sample()
	if Time.get_ticks_usec()-draw_probe.last_draw_usec>120000:
		RenderingServer.force_draw(false);forced_draws+=1

func check(title:String,passed:bool,detail:Dictionary={}):
	checks.append({"test":title,"passed":passed,"detail":detail});print("BATCH093 ",title," ",passed)

func ticks(count:int):
	for i in count:await main.get_tree().physics_frame

func key(code:int,pressed:bool,echo:bool=false):
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;event.echo=echo
	Input.parse_input_event(event);Input.flush_buffered_events()

func place(point:Vector2):
	main.player.enabled=false;main.player.velocity=Vector3.ZERO
	await main.world.prepare_region(main.world.surface(point.x,point.y))
	main.player.position=main.world.surface(point.x,point.y,0.45)
	main.player.automated_motion=true;main.player.automated_horizontal=Vector2.ZERO
	await ticks(40)
	main.player.automated_motion=false;main.player.reset_jump_state()
	main.player.camera.current=true;main.player.enabled=true

func walk(point:Vector2)->bool:
	main.player.enabled=false;main.player.automated_motion=true
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		var direction:Vector2=point-Vector2(main.player.position.x,main.player.position.z)
		if direction.length()<0.42:break
		main.player.automated_horizontal=direction.normalized()*7.2
		await ticks(1)
	main.player.automated_motion=false;main.player.automated_horizontal=Vector2.ZERO
	return point.distance_to(Vector2(main.player.position.x,main.player.position.z))<0.5

func capture(name:String,eye:Vector3,target:Vector3):
	main.player.enabled=false;main.hud.hide();main.watch_camera.position=eye;main.watch_camera.look_at(target);main.watch_camera.fov=75;main.watch_camera.current=true
	await main.world.prepare_region(target)
	await ticks(12)
	if await main.wait_for_viewport_draw():
		var error:int=main.get_viewport().get_texture().get_image().save_png(main.evidence_root+"screenshots/"+name+".png")
		check("capture_"+name,error==OK,{"eye":str(eye),"target":str(target),"fov":75,"time":main.state.time,"weather":main.state.weather})

func run(target):
	main=target;main.store.directory="user://qa_isolated/"+main.qa_mode
	await ticks(1);await main.start_game(false)
	main.player.ignore_focus_loss=true
	started=Time.get_ticks_msec();draw_probe.start()
	var w=main.world;var p=main.player;var controls=main.environment_controls
	check("eight_zones_thirteen_venues",w.spec.zones.size()==8 and w.building_bounds.size()==13)
	var ids:Array=[]
	for item in w.interactions:ids.append(item.id)
	var missing:Array=[]
	for id in JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json")).ids:
		if id not in ids:missing.append(id)
	check("legacy_interactions",missing.is_empty(),{"current":ids.size(),"missing":missing})
	var stale:Array=[]
	for path in w.streamer.manifest.source_hashes:
		if OS.has_feature("editor"):
			if FileAccess.get_sha256(path)!=w.streamer.manifest.source_hashes[path]:stale.append(path)
		elif not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):stale.append(path)
	check("bake_matches_sources" if OS.has_feature("editor") else "baked_runtime_resources_available",stale.is_empty(),{"stale":stale})
	check("twelve_venue_plinths",w.streamer.manifest.authored_counts.get("masonry_093",{}).size()==12)
	await place(Vector2(-237,-148.5))
	for point in [Vector2(-237,-157),Vector2(-237,-162),Vector2(-237,-165)]:check("home_entrance_"+str(point),await walk(point))
	await place(Vector2(-246,-174))
	for point in [Vector2(-256,-185),Vector2(-260,-191.4),Vector2(-266,-201),Vector2(-278,-211)]:check("forest_route_"+str(point),await walk(point),{"actual":str(p.position)})
	check("road_has_new_elevation",w.terrain_art.garden_road_relief(Vector2(-261,-193))>0.8)
	for point in [Vector2(-256,-185),Vector2(-261,-193),Vector2(-266,-201)]:
		var floor_y:float=w.height_at(point.x,point.y)
		var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,floor_y+1,point.y),Vector3(point.x,floor_y-1,point.y))
		query.exclude=[p.get_rid()]
		var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(query)
		check("road_collision_"+str(point),not hit.is_empty() and absf(hit.position.y-floor_y)<0.12,{"height":floor_y,"hit":str(hit.get("position","none"))})
	await place(Vector2(0,82));p.yaw=0
	key(KEY_W,true);await ticks(40)
	check("walk_speed",absf(Vector2(p.velocity.x,p.velocity.z).length()-7.2)<0.1)
	key(KEY_SHIFT,true);await ticks(40)
	check("run_ratio",absf(Vector2(p.velocity.x,p.velocity.z).length()-14.4)<0.1)
	key(KEY_SHIFT,false);key(KEY_W,false);await ticks(40)
	key(KEY_SPACE,true);await ticks(10)
	check("first_jump",p.jump_count==1 and not p.is_on_floor())
	key(KEY_SPACE,true,true);await ticks(3)
	check("held_echo_not_second_jump",p.jump_count==1)
	key(KEY_SPACE,false);await ticks(2);key(KEY_SPACE,true);await ticks(3)
	check("second_jump",p.jump_count==2 and p.velocity.y>4.0)
	key(KEY_SPACE,false);await ticks(2);key(KEY_SPACE,true);await ticks(3)
	check("third_jump_rejected",p.jump_count==2 and p.velocity.y<5.0)
	await ticks(100)
	check("holding_space_does_not_bounce",p.is_on_floor() and p.jump_count==0)
	key(KEY_SPACE,false)
	# UI transitions must not grant extra jumps while airborne.
	key(KEY_SPACE,true);await ticks(8);key(KEY_SPACE,false)
	controls.panel();main.close_modal();key(KEY_SPACE,true);await ticks(3)
	check("panel_does_not_recharge_air_jump",p.jump_count==2 and p.velocity.y<5.0)
	key(KEY_SPACE,false);await ticks(80)
	var before:Vector3=p.position;var yaw:float=p.yaw;var pitch:float=p.pitch
	key(KEY_O,true);key(KEY_O,false);await ticks(3)
	check("overview_normal_key",controls.overview and not p.enabled and controls.camera.current)
	key(KEY_W,true);await ticks(25);key(KEY_W,false)
	check("overview_pan_keeps_player",p.position.distance_to(before)<0.001 and controls.center.y< -25)
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	Input.parse_input_event(wheel);Input.flush_buffered_events();await ticks(3)
	check("overview_zoom",controls.extent<1040)
	await ticks(50)
	check("overview_stream_bounded",w.streamer.loaded.size()<60,{"loaded":w.streamer.loaded.size(),"total":w.streamer.records.size()})
	key(KEY_F6,true);key(KEY_F6,false);await ticks(3)
	check("environment_panel_normal_key",main.environment_panel_open and main.modal.visible)
	controls.set_weather(2);main.set_time(2)
	check("night_rain_combination",controls.weather==2 and main.state.time==2 and main.sun.light_energy<0.12)
	main.close_modal();check("panel_returns_to_overview",controls.overview and controls.camera.current and not p.enabled)
	key(KEY_O,true);key(KEY_O,false);await ticks(1)
	check("overview_restores_pose",not controls.overview and p.position.distance_to(before)<0.01 and p.yaw==yaw and p.pitch==pitch)
	main.audio_player.stream=load("res://assets/audio/wind.wav");main.audio_player.play()
	var stream=main.audio_player.stream
	controls.panel();controls.set_weather(1);main.close_modal()
	check("weather_preserves_media",main.audio_player.playing and main.audio_player.stream==stream)
	main.audio_player.stop()
	controls.set_weather(2);main.set_time(0);await ticks(20)
	check("outdoor_rain",controls.rain.visible and controls.rain_audio.playing)
	await place(Vector2(-237,-167));await ticks(20)
	check("indoor_shelter",not controls.rain.visible and controls.sheltered)
	check("weather_save",main.save_game(false) and int(main.store.read().get("weather",-1))==2)
	var legacy:Dictionary=main.state.duplicate(true);legacy.erase("weather")
	check("legacy_save_without_weather",main.store.write(legacy) and not main.store.read().is_empty())
	controls.set_weather(0);await ticks(100)
	check("sunny_stops_rain",not controls.rain.visible and not controls.rain_audio.playing)
	# Only four representative images, once for this construction batch.
	if main.qa_mode.ends_with("source"):
		await capture("batch093_home",Vector3(-221,8.403634,-153),Vector3(-237,4.703634,-169))
		await capture("batch093_forest",Vector3(-270,6.905393,-183),Vector3(-275,24.484009,-220))
		main.watch_camera.current=false;p.camera.current=true;main.hud.show();controls.enter();await ticks(12)
		if await main.wait_for_viewport_draw():main.get_viewport().get_texture().get_image().save_png(main.evidence_root+"screenshots/batch093_overview.png")
		controls.leave();await place(Vector2(-237,-149));controls.set_weather(2)
		await capture("batch093_rain",Vector3(-234,3.5,-149),Vector3(-237,4.7,-169))
	var coverage:Dictionary=draw_probe.report();draw_probe.stop()
	var failures:=0
	for item in checks:
		if not item.passed:failures+=1
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"duration_s":(Time.get_ticks_msec()-started)/1000.0,"render_coverage":coverage,"forced_draws":forced_draws,"scope":"Targeted construction/control smoke; injected engine input, not Windows keyboard or final art acceptance"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BATCH093_TERMINAL ",failures)
	main.get_tree().quit(1 if failures else 0)
