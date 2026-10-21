extends RefCounted
var main
var results:Array=[]
var slow_frames:Array=[]
var started:=0
var phase:="startup"
var frame_times:Array=[]
var last_usec:=0
var checkpoint_elapsed:=0.0
var minimum_seconds:=1200.0
var render_probe=preload("res://scripts/qa_draw_controller.gd").new()
var forced_draw_mode:=false
var forced_draw_requests:=0

func _init(target):main=target
func check(name:String,passed:bool,detail:Dictionary={}):
	results.append({"test":name,"passed":passed,"detail":detail});print("TOUR_CHECK ",name," ",passed," ",JSON.stringify(detail))
	if not passed:
		var file:=FileAccess.open(main.evidence_root+"reports/acceptance_tour.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"status":"incomplete_failed","phase":phase,"duration_s":(Time.get_ticks_msec()-started)/1000.0,"results":results,"failures":1,"stream":main.world.streamer.diagnostics()},"\t"));file.flush();file.close()
		main.get_tree().quit(1)

func sample(delta:float):
	if started==0:return
	render_probe.sample()
	forced_draw_mode=render_probe.fallback_used
	forced_draw_requests=render_probe.requests
	var now:=Time.get_ticks_usec()
	if last_usec>0:
		var elapsed:float=(now-last_usec)/1000.0;frame_times.append(elapsed)
		if elapsed>100:slow_frames.append({"ms":elapsed,"phase":phase,"position":str(main.player.position),"elapsed_s":(Time.get_ticks_msec()-started)/1000.0})
	last_usec=now;checkpoint_elapsed+=delta
	if checkpoint_elapsed>5:
		checkpoint_elapsed=0
		var file:=FileAccess.open(main.evidence_root+"reports/tour_progress.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"phase":phase,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0,"position":str(main.player.position),"results":results.size(),"render_coverage":render_probe.report(),"stream":main.world.streamer.diagnostics()}));file.flush();file.close()

func walk(point:Vector2,speed:float=6.6)->bool:
	main.player.enabled=false;main.player.camera.current=true
	var remaining:float=Vector2(main.player.position.x,main.player.position.z).distance_to(point)
	var deadline:=Time.get_ticks_msec()+int((remaining/speed+10)*1000)
	while remaining>0.85 and Time.get_ticks_msec()<deadline:
		await main.get_tree().physics_frame
		var direction:Vector2=(point-Vector2(main.player.position.x,main.player.position.z)).normalized()
		main.player.automated_motion=true;main.player.automated_horizontal=direction*speed
		main.player.yaw=atan2(-direction.x,-direction.y);main.player.figure.rotation.y=main.player.yaw
		remaining=Vector2(main.player.position.x,main.player.position.z).distance_to(point)
	main.player.automated_motion=false;main.player.automated_horizontal=Vector2.ZERO
	var ok:=remaining<=0.85
	var collisions:Array=[]
	if not ok:
		for index in main.player.get_slide_collision_count():
			var hit=main.player.get_slide_collision(index);var body=hit.get_collider()
			collisions.append({"position":str(hit.get_position()),"normal":str(hit.get_normal()),"body_position":str(body.global_position) if body is Node3D else str(body)})
	check("walk_"+phase+"_"+str(point),ok,{"remaining":remaining,"position":str(main.player.position),"collisions":collisions})
	return ok

func route(points:Array):
	for point in points:
		if not await walk(Vector2(point[0],point[1])):
			# Stop this segment. It remains a failure; do not teleport past it and claim continuity.
			return false
	return true

func stamp(id:String):
	var original:Vector2=Vector2(main.player.position.x,main.player.position.z)
	if id=="Z02":
		# The central pier has guardrails; use the open east-side beach entrance.
		var entrance_z:float=303+10*sin(15*0.015)
		if not await route([[0,303],[15,entrance_z],[15,entrance_z+10],[15,325.5]]):return
	for action in main.world.interactions:
		if action.id==id:
			# The original lowland approaches already passed. The mountain stamp needs
			# its new spur in both directions, rather than a diagonal shortcut over terraces.
			if id=="Z08":
				for point in main.world.stamp_access_points(action.data):
					if not await walk(point):return
			if await walk(Vector2(action.pos.x,action.pos.z)):main.activate(action)
			check("stamp_"+id,id in main.state.stamps)
			if id=="Z08":
				var back:Array=main.world.stamp_access_points(action.data).duplicate();back.reverse()
				for point in back:
					if not await walk(point):return
				await walk(original)
			if id=="Z02":
				var entrance_z:float=303+10*sin(15*0.015)
				await route([[15,325.5],[15,entrance_z+10],[15,entrance_z],[0,303]])
			return

func capture(name:String):
	if not await main.qa_frame():check("capture_draw_"+name,false);return
	check("capture_"+name,main.get_viewport().get_texture().get_image().save_png(main.evidence_root+"screenshots/tour_"+name+".png")==OK)

func watch(venue:String,id:String):
	phase="video_"+id
	await main.show_video(venue,id)
	await main.get_tree().create_timer(2).timeout
	check(id+"_begins",main.video.is_playing() and main.video.stream_position>0.3)
	await capture(id)
	var record:Dictionary=main.program_for(id)
	var duration:float=float(record.get("duration_s",0))
	if duration<=0:check(id+"_known_actual_duration",false);return
	var deadline:=Time.get_ticks_msec()+int((duration+20)*1000)
	var furthest:float=main.video.stream_position
	while main.video.is_playing() and Time.get_ticks_msec()<deadline:
		await main.get_tree().create_timer(0.5).timeout
		furthest=maxf(furthest,main.video.stream_position)
	check(id+"_reaches_end",not main.video.is_playing() and furthest>=duration-2,{"duration_s":duration,"furthest_s":furthest})
	main.close_modal();main.player.enabled=false
	check(id+"_released",main.video.stream==null and main.watch_screen==null)

func listen(id:String):
	phase="audio_"+id;main.show_audio(id)
	await main.get_tree().create_timer(0.7).timeout
	check(id+"_audio_begins",main.audio_player.playing and main.audio_player.get_playback_position()>0.2)
	var duration:float=main.audio_player.stream.get_length() if main.audio_player.stream!=null else 0
	var deadline:=Time.get_ticks_msec()+int((duration+10)*1000);var furthest:float=main.audio_player.get_playback_position()
	while main.audio_player.playing and Time.get_ticks_msec()<deadline:
		await main.get_tree().create_timer(0.5).timeout;furthest=maxf(furthest,main.audio_player.get_playback_position())
	check(id+"_audio_end",not main.audio_player.playing and furthest>=duration-2,{"duration_s":duration,"furthest_s":furthest})
	main.close_modal();main.player.enabled=false

func run():
	main.store.directory="user://qa_isolated/acceptance_tour"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tour-seconds="):minimum_seconds=maxf(1200,float(argument.trim_prefix("--tour-seconds=")))
	var boot:=Time.get_ticks_msec();await main.start_game(false);main.player.enabled=false
	var startup_s:float=(Time.get_ticks_msec()-boot)/1000.0
	started=Time.get_ticks_msec()
	render_probe.start()
	phase="station";await stamp("Z01");await capture("station")
	phase="coast";await route([[260,194],[255,232],[135,248],[20,248],[0,303]])
	await stamp("Z02");await capture("coast")
	phase="cafe";await route([[0,303],[-65,305],[-65,298],[-65,290],[-65,287],[-65,276],[-75,265],[-75,236]])
	phase="shopping";await route([[-75,201],[-97,201],[-97,190]])
	await listen("wall_audio")
	await route([[-97,201],[-75,201]]);await stamp("Z03")
	await route([[-75,223],[-53,223],[-53,211],[-53,223],[-75,223],[-75,160],[-55,160],[-55,149]])
	main.show_souvenirs();main.claim_card("Z03");main.close_modal();main.player.enabled=false
	await route([[-55,160],[-75,160],[-75,144],[-35,130],[0,120],[0,80]])
	phase="plaza";await stamp("Z04");await capture("plaza")
	if not await main.save_photo():check("plaza_photo_saved",false,main.last_photo_capture);return
	check("plaza_photo_saved",true,main.last_photo_capture)
	phase="music";await route([[0,80],[-105,80],[-195,78],[-250,70],[-250,10]])
	await stamp("Z05");await route([[-250,10],[-250,30],[-291,30],[-291,17]])
	await watch("B10","wall_stage")
	phase="dance";await route([[-291,30],[-250,30],[-250,-22],[-232,-27],[-232,-34]])
	await watch("B08","rehearsal")
	phase="studio";await route([[-232,-27],[-250,-22],[-250,70],[-211,63],[-211,54]])
	await listen("sunset")
	phase="garden";await route([[-211,63],[-221,76],[-250,70],[-250,-80],[-205,-120]])
	await stamp("Z07");await route([[-220,-150],[-237,-148.5],[-237,-168]])
	main.claim_card("Z07");main.state.home_shot=str(main.state.shots[-1]).get_file();main.sync_home_memories();main.save_game(false)
	await capture("home")
	phase="mountain";await route([[-237,-148.5],[-220,-150],[-160,-218],[-100,-272],[0,-330],[0,-377]])
	await capture("summit");await route([[0,-330]]);await stamp("Z08")
	phase="river";await route([[0,-330],[85,-285],[175,-220],[220,-170]])
	phase="waterfall";await route([[281,-275],[284,-295.5],[286,-302],[300,-302],[315,-302]])
	main.player.yaw=0;await main.get_tree().create_timer(0.5).timeout;await capture("waterfall")
	await route([[300,-302],[286,-302],[284,-295.5],[281,-275],[220,-170]])
	phase="river";await route([[251,-170],[251,-128],[220,-112]])
	await route([[212,-98],[219,-67],[245,-64]]);await stamp("Z06")
	phase="gallery";await route([[245,-64],[218,-51],[185,-29],[173,-31],[173,-38]])
	main.state.gallery_preset=1;main.world.set_gallery_preset(1);main.show_photo(5);await main.get_tree().create_timer(1).timeout;main.close_modal();main.player.enabled=false
	phase="cinema";await route([[173,-31],[185,-29],[218,-51],[224,-61],[245,-63],[245,-78.3]])
	await watch("B06","moon_episode8");await watch("B06","sunset")
	phase="PB";await route([[245,-63],[219,-67],[212,-98],[222,-119],[225,-138],[225,-146]])
	main.show_pb(main.assets.size()+1);await main.get_tree().create_timer(1).timeout;await capture("PB");main.close_modal();main.player.enabled=false
	phase="return";await route([[225,-138],[220,-112],[200,-70],[160,0],[85,55],[0,80]])
	var loop:=0
	while (Time.get_ticks_msec()-started)/1000.0<minimum_seconds or loop<1:
		phase="repeat_ring_"+str(loop)
		await route([[0,80],[-105,80],[-195,78],[-250,70],[-250,10],[-250,-80],[-205,-120],[-220,-150],[-160,-218],[-100,-272],[0,-330],[0,-377],[0,-330],[85,-285],[175,-220],[220,-170],[251,-170],[251,-128],[220,-112],[200,-70],[160,0],[85,55],[0,80]])
		loop+=1
	phase="save_restore";check("tour_saved",main.save_game(false));var expected:Vector3=main.player.position
	await main.start_game(true);main.player.enabled=false
	# Normal resumed play settles after the safe spawn lift; QA input is isolated,
	# so keep physics gravity active instead of freezing the capsule in mid-air.
	main.player.automated_horizontal=Vector2.ZERO;main.player.automated_motion=true
	for tick in 40:await main.get_tree().physics_frame
	main.player.automated_motion=false
	check("tour_restores_position_and_memories",main.player.position.distance_to(expected)<0.1 and main.state.cards.has("Z07") and not main.state.home_shot.is_empty())
	check("all_eight_stamps_collected",main.state.stamps.size()==8)
	frame_times.sort();var total:=0.0
	for value in frame_times:total+=value
	var failed:=0
	for row in results:if not row.passed:failed+=1
	var duration_s:float=(Time.get_ticks_msec()-started)/1000.0
	var report:={"duration_s":duration_s,"startup_prepare_s":startup_s,"runtime":"export_release" if not OS.has_feature("editor") else "editor_binary","resolution":[main.get_viewport().size.x,main.get_viewport().size.y],"renderer":RenderingServer.get_current_rendering_method(),"render_scale":ProjectSettings.get_setting("rendering/scaling_3d/scale",1.0),"average_fps":1000.0/(total/frame_times.size()),"p95_ms":frame_times[int(frame_times.size()*0.95)],"p99_ms":frame_times[int(frame_times.size()*0.99)],"slow_frames":slow_frames,"results":results,"failures":failed,"stream":main.world.streamer.diagnostics(),"scope":"20+ minute actual rendered automated physics route, complete primary media and UI helpers; not human keyboard/mouse or subjective audio synchronization acceptance; screenshots and loading included"}
	render_probe.stop()
	report.render_coverage=render_probe.report()
	report.forced_draw_requests=forced_draw_requests
	report.forced_draw_mode=forced_draw_mode
	report.render_coverage_passed=report.render_coverage.second_coverage>=0.95 and report.render_coverage.process_coverage>=0.90
	report.scope="20+ minute automated physics route and main-loop timing; measured occlusion gaps trigger recorded real-draw requests, frame callbacks reported separately; natural callbacks plus conditional real draws recorded separately; not presentation/GPU timestamps, human input or subjective audio sync acceptance"
	var file:=FileAccess.open(main.evidence_root+"reports/acceptance_tour.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ACCEPTANCE_TOUR ",JSON.stringify({"duration_s":duration_s,"failures":failed,"results":results.size(),"fps":report.average_fps,"p95_ms":report.p95_ms,"p99_ms":report.p99_ms,"over100ms":slow_frames.size()}))
	main.get_tree().quit(1 if failed else 0)
