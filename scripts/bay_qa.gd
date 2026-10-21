extends RefCounted
## One consolidated integration run. No normal save writes and no historical coordinate tour.
var m
var checks:Array=[]
var frame_ms:Array=[]
var last_usec:=0
var started:=0
var sampling:=false

func sample(delta:float):
	if not sampling:return
	var now:int=Time.get_ticks_usec()
	if last_usec>0:frame_ms.append((now-last_usec)/1000.0)
	last_usec=now

func check(id:String,ok:bool,detail:Variant=null):
	checks.append({"name":id,"passed":ok,"detail":detail});print("BAY_CHECK ",id," ",ok," ",detail)

func move_to(point:Vector3):
	m.player.enabled=false;m.player.stand_up()
	await m.world.prepare_region(point,75)
	m.player.position=m.world.safe_ground_position(point);m.player.velocity=Vector3.ZERO
	for i in 3:await m.get_tree().physics_frame

func run(target):
	m=target;started=Time.get_ticks_msec()
	await m.get_tree().create_timer(.5).timeout
	await m.start_game(false);m.player.program_driven=true;m.player.enabled=false
	if m.qa_mode.begins_with("bay_dual106"):
		await preload("res://scripts/bay_dual106_qa.gd").new().run(m,self);return
	if m.qa_mode in ["bay_redesign105","bay_redesign105_links","bay_redesign105_final","bay_redesign105_south"]:await preload("res://scripts/bay_redesign_qa.gd").new().run(m,self);return
	if m.qa_mode=="bay_sea104":await preload("res://scripts/bay_sea_qa.gd").new().run(m,self);return
	if m.qa_mode=="bay_audit103":await preload("res://scripts/bay_audit_qa.gd").new().run(m,self);return
	if m.qa_mode=="bay_completion101":await preload("res://scripts/bay_completion_qa.gd").new().run(m,self);return
	if m.qa_mode=="bay_final102":await preload("res://scripts/bay_final_qa.gd").new().run(m,self);return
	if m.qa_mode in ["bay_resume102","bay_road102"]:await preload("res://scripts/bay_resume_qa.gd").new().run(m,self);return
	if m.qa_mode=="bay_correct102":await preload("res://scripts/bay_corrected_qa.gd").new().run(m,self);return
	if m.qa_mode=="bay_smoke":
		check("normal_start",m.active_game and m.bay!=null and m.bay.boats!=null)
		await m.get_tree().create_timer(3).timeout;finish();return
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_095_bay_v1.json"))
	var ids:Array=m.world.interactions.map(func(v):return v.id)
	check("all_87_legacy_ids",legacy.protected_interaction_ids.all(func(id):return id in ids))
	var unique:Dictionary={}
	for id in ids:unique[id]=true
	check("unique_interaction_ids",ids.size()==unique.size(),ids.size())
	check("13_venues_8_zones",m.world.building_bounds.size()==13 and m.world.spec.zones.size()==8)
	if m.qa_mode in ["bay_final_links","bay_last_two","bay_stairs_final"]:
		sampling=true
		if m.qa_mode=="bay_final_links":
			var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="flower_house_access")[0]
			await move_to(m.world.layout.vector(road.points[0])+Vector3.UP*.4)
			var branch_ok:=true
			for i in range(1,road.points.size()):
				var p:Array=road.points[i]
				if not await walk(Vector2(p[0],p[2]),8):branch_ok=false;break
			check("final_flower_house_branch",branch_ok)
		if m.qa_mode!="bay_stairs_final":
			await move_to(m.world.layout.vector([256,2,427]));var hotel_ok:=true
			for entry in m.world.layout.config.island.hotel_walk.arrival:
				var p:Vector3=m.world.layout.vector(entry)
				if not await walk(Vector2(p.x,p.z),5):hotel_ok=false;break
			for i in 11:
				var p:Vector3=m.world.layout.hotel_walk_point(lerpf(-1.15,1.15,float(i)/10))
				if not await walk(Vector2(p.x,p.z),6):hotel_ok=false;break
			check("final_hotel_lobby_and_crescent",hotel_ok)
		else:
			await move_to(Vector3(315,3,310))
			var entry_ok:bool=await walk(Vector2(320,322),5)
			entry_ok=(await walk(Vector2(298,322),5)) and entry_ok
			entry_ok=(await walk(Vector2(298,328.3),4,.2)) and entry_ok
			check("final_main_dock_from_coast_path",entry_ok,str(m.player.position))
		await move_to(Vector3(276,-.4,432))
		var steps_ok:bool=await walk(Vector2(276,435.5),4,.15)
		steps_ok=(await walk(Vector2(279.5,435.5),4,.15)) and steps_ok
		steps_ok=(await walk(Vector2(279.5,434.5),4,.15)) and steps_ok
		steps_ok=(await walk(Vector2(281.87,434.5),4,.03)) and steps_ok
		m.player.velocity=Vector3.ZERO;m.player.automated_horizontal=Vector2.ZERO;m.player.automated_motion=true
		var last_tread:Vector3=m.player.position
		await m.get_tree().create_timer(1).timeout
		m.player.automated_motion=false
		check("final_outward_five_steps_to_water",steps_ok and m.player.is_on_floor() and m.player.position.y< -2.0 and Vector2(last_tread.x,last_tread.z).distance_to(Vector2(m.player.position.x,m.player.position.z))<.15 and m.world.layout.shallow_or_dry(m.player.position),{"before":str(last_tread),"after":str(m.player.position),"on_floor":m.player.is_on_floor(),"dry":m.world.layout.shallow_or_dry(m.player.position)})
		if m.qa_mode=="bay_stairs_final":sampling=false;finish();return
		if m.qa_mode=="bay_last_two":
			sampling=false
			await m.qa_capture("bay0100_hotel_finished",Vector3(310,24,493),Vector3(245,0,450))
			await m.qa_capture("bay0100_glass_finished",Vector3(276,2.8,426.05),Vector3(276,-4.0,426))
			finish();return
		await move_to(m.world.layout.vector(m.world.layout.config.docks[0]));m.player.enabled=true;m.player.program_driven=false
		var vehicles=m.bay.vehicles;var mounted:bool=vehicles.mount("bike",0);vehicles.testing=true;vehicles.test_input=Vector2(0,-1)
		var origin:Vector3=m.player.position;await m.get_tree().create_timer(1).timeout
		check("final_vehicle_sustained_reverse",mounted and vehicles.speed< -2.5 and m.player.position.distance_to(origin)>1.0,{"speed":vehicles.speed,"distance":m.player.position.distance_to(origin)})
		vehicles.speed=0;vehicles.dismount(true);vehicles.testing=false
		check("final_links_save",m.save_game(false));sampling=false
		await m.qa_capture("bay0100_island_delivery",Vector3(310,24,493),Vector3(245,0,450))
		finish();return
	if m.qa_mode=="bay_survey":
		await m.qa_capture("bay_overall",Vector3(470,145,490),Vector3(0,25,40))
		await m.qa_capture("bay_flower",Vector3(-265,31,-145),Vector3(-220,12,-184))
		await m.qa_capture("bay_island",Vector3(317,25,500),Vector3(247,0,450))
		await m.qa_capture("bay_cafe",Vector3(-113,6.7,253),Vector3(-114,5.5,244))
		finish();return
	if m.qa_mode=="bay_closeout":
		sampling=true
		for road in m.world.layout.config.roads:
			if road.id not in ["music_garden","flower_house_access","west_mountain"]:continue
			await move_to(m.world.layout.vector(road.points[0])+Vector3.UP*.4)
			var failures:Array=[]
			for i in range(1,mini(3,road.points.size()) if road.id=="west_mountain" else road.points.size()):
				var p:Array=road.points[i]
				if not await walk(Vector2(p[0],p[2]),Vector2(m.player.position.x-p[0],m.player.position.z-p[2]).length()/8+5):failures.append(i);break
			check("closeout_"+road.id,failures.is_empty(),failures)
		await new_connections(true)
		sampling=false
		await m.qa_capture("bay0100_island_final",Vector3(310,24,493),Vector3(245,0,450))
		await m.qa_capture("bay0100_villa_glass",Vector3(276,1.6,427.8),Vector3(276,-.8,425.7))
		finish();return
	sampling=true
	# Geometric water samples include bends and new bridge crossings, not only control points.
	var dry_samples:Array=[];var minimum:float=INF
	for r in m.world.layout.river_segments:
		if r.id!="navigation":continue
		for i in 16:
			var q:Vector3=r.a.lerp(r.c,float(i)/15)
			var depth:float=q.y-m.world.height_at(q.x,q.z);minimum=minf(minimum,depth)
			if depth<1.35:dry_samples.append([q.x,q.z,depth])
	check("navigation_minimum_depth",dry_samples.is_empty(),{"minimum":minimum,"failures":dry_samples})
	for item in ([] if m.qa_mode in ["bay_repair","bay_acceptance"] else m.world.spec.buildings):
		var desired:=Vector3(item.x,item.floor_y+.4,item.z+item.d*.5+1.4)
		await move_to(desired)
		var destination:=Vector2(item.x,item.z+item.d*.5-1.6)
		var ok:bool=await walk(destination,5)
		check(item.id+"_walk_door",ok and m.world.inside_building(m.player.position)==item.id,[m.player.position.x,m.player.position.y,m.player.position.z])
	# Four representative collider paths, including the full two mountain ascents.
	for road in m.world.layout.config.roads:
		if road.id not in (["coast_west","arts","east_mountain","music_garden","west_mountain","flower_path","tea_access","flower_dock_access"] if m.qa_mode in ["bay_repair","bay_acceptance"] else ["coast_east","mouth_bridge","coast_west","arts","east_mountain","music","music_garden","west_mountain","forest_cross","flower_path"]):continue
		await move_to(m.world.layout.vector(road.points[0])+Vector3.UP*.4)
		var failures:Array=[]
		for i in range(1,road.points.size()):
			var p:Array=road.points[i]
			if not await walk(Vector2(p[0],p[2]),maxf(6,Vector2(m.player.position.x-p[0],m.player.position.z-p[2]).length()/8+4)):
				failures.append(i);await move_to(m.world.layout.vector(p)+Vector3.UP*.5)
		check("walk_"+road.id,failures.is_empty(),failures)
	await systems()
	if m.qa_mode=="bay_acceptance":await new_connections()
	sampling=false
	if m.qa_mode=="bay_acceptance":
		await m.qa_capture("bay0100_island",Vector3(310,24,493),Vector3(245,0,450))
		await m.qa_capture("bay0100_flower",Vector3(-248,22,-148),Vector3(-224,13,-181))
		await m.qa_capture("bay0100_cafe",Vector3(-110,10.7,258),Vector3(-113,10,247))
	finish()

func walk(destination:Vector2,timeout:float,tolerance:float=.65)->bool:
	var deadline:int=Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<deadline:
		await m.get_tree().physics_frame
		var delta:Vector2=destination-Vector2(m.player.position.x,m.player.position.z)
		if delta.length()<tolerance:
			m.player.velocity.x=0;m.player.velocity.z=0;return true
		var d:Vector2=delta.normalized();var speed:float=minf(10.5,delta.length()*12);m.player.velocity=Vector3(d.x*speed,maxf(m.player.velocity.y-19.0/60,-20),d.y*speed)
		if m.player.is_on_floor():m.player.velocity.y=-.2
		m.player.move_character();m.player.yaw=atan2(-d.x,-d.y);m.player.figure.rotation.y=m.player.yaw
		if not m.world.region_ready(m.player.position):await m.world.prepare_region(m.player.position,75)
	print("BAY_WALK_FAILURE ",JSON.stringify({"target":[destination.x,destination.y],"position":[m.player.position.x,m.player.position.y,m.player.position.z],"remaining":Vector2(m.player.position.x,m.player.position.z).distance_to(destination),"water_edge_blocked":m.player.water_edge_blocked,"on_floor":m.player.is_on_floor()}))
	for i in m.player.get_slide_collision_count():
		var hit:KinematicCollision3D=m.player.get_slide_collision(i);var collider:CollisionObject3D=hit.get_collider()
		var owner:Node=collider.shape_owner_get_owner(collider.shape_find_owner(hit.get_collider_shape_index()))
		print("BAY_BLOCKING_SHAPE ",JSON.stringify({"position":str(owner.global_position) if owner is Node3D else "unknown","shape":str(owner.shape) if owner is CollisionShape3D else "unknown","normal":str(hit.get_normal())}))
	return false

func systems():
	# Normal control dispatch, inventory idempotence and visible results.
	m.player.enabled=true;m.player.program_driven=false
	var picked:Dictionary={}
	for action in m.world.interactions:
		if action.kind=="bay_pick" and action.data.material=="shell":picked=action;break
	m.bay.pick(picked);var before:int=m.state.inventory.shell;m.bay.pick(picked);check("pick_only_once",int(m.state.inventory.shell)==before)
	m.state.handheld="bouquet";m.bay.refresh_hand();check("visible_bouquet",is_instance_valid(m.bay.hand) and m.bay.hand.get_child_count()>5)
	var v:Dictionary=m.world.layout.venues.B09
	await move_to(Vector3(v.x,v.floor_y+.3,v.z+1));m.player.enabled=true
	m.bay.start_mix();await m.get_tree().create_timer(.7).timeout
	var positions:Array=[]
	for audio in m.bay.mix_players:positions.append(audio.get_playback_position())
	check("four_real_tracks_aligned",m.bay.mix_players.all(func(a):return a.playing and a.stream!=null) and positions.max()-positions.min()<.045,positions)
	m.bay.mix_enabled=false
	for audio in m.bay.mix_players:audio.stop()
	for kind in ["bike","scooter"]:
		var dock:Vector3=m.world.layout.vector(m.world.layout.config.docks[0]);await move_to(dock)
		m.player.enabled=true;m.player.program_driven=false
		check(kind+"_mount",m.bay.vehicles.mount(kind,0))
		m.bay.vehicles.testing=true;m.bay.vehicles.test_input=Vector2(0,1);var start:Vector3=m.player.position
		await m.get_tree().create_timer(1).timeout
		check(kind+"_physical_drive",m.player.position.distance_to(start)>1.0,m.player.position.distance_to(start))
		m.bay.vehicles.speed=0;check(kind+"_safe_dismount",m.bay.vehicles.dismount(true));m.bay.vehicles.testing=false
	# Sail the centre of every navigable reach in both directions. Movement is continuous.
	for boat_kind in ["flower","yacht"]:
		m.state.activities.boat_choice=boat_kind
		await move_to(m.bay.boats.shore_point())
		var boarded:bool=await m.bay.boats.board(0 if boat_kind=="flower" else 1);check(boat_kind+"_board",boarded)
		if not boarded:continue
		m.bay.boats.testing=true;m.player.program_driven=true;m.player.enabled=false
		var failures:Array=[]
		var river:Array=[]
		for record in m.world.layout.config.rivers:
			if record.id=="navigation":river=record.points
		if boat_kind=="yacht":river=river.duplicate();river.reverse()
		for i in range(1,river.size()):
			if not await sail_to(m.world.layout.vector(river[i]),60):failures.append(i);break
		check(boat_kind+("_continuous_downriver" if boat_kind=="flower" else "_continuous_upriver"),failures.is_empty(),failures)
		m.bay.boats.leave_for_travel();m.bay.boats.testing=false
	m.player.program_driven=false
	check("new_world_save",m.save_game(false))

func sail_to(target:Vector3,timeout:float)->bool:
	var boat=m.bay.boats;print("BAY_SAIL_TARGET ",target);var heartbeat:int=Time.get_ticks_msec();var deadline:int=Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<deadline:
		await m.get_tree().physics_frame
		var delta:Vector3=target-m.player.position
		if Vector2(delta.x,delta.z).length()<1.4:return true
		var wanted:float=atan2(-delta.x,-delta.z)
		var error:float=angle_difference(boat.heading,wanted)
		boat.test_input=Vector2(clampf(-error*2,-1,1),0 if absf(error)>.5 else 1)
		boat.drive(1.0/60)
		if Time.get_ticks_msec()-heartbeat>5000:
			heartbeat=Time.get_ticks_msec();print("BAY_SAIL_PROGRESS ",m.player.position," target ",target," speed ",boat.speed)
		if not m.world.region_ready(m.player.position):await m.world.prepare_region(m.player.position,75)
	print("BAY_SAIL_FAILED ",m.player.position," target ",target)
	return false

func new_connections(only_repairs:bool=false):
	# One end-to-end sea journey then physical access to the hotel, glass and reclining bed.
	m.state.activities.boat_choice="yacht"
	var boat=m.bay.boats
	await move_to(m.world.layout.vector(m.world.layout.config.boat_docks[1].land))
	var boarded:bool=await boat.board(1);check("sea_yacht_board",boarded)
	if boarded:
		boat.testing=true;m.player.program_driven=true;m.player.enabled=false
		var voyage_started:int=Time.get_ticks_msec();var arrived:=true
		for p in [Vector3(283,-2.4,385),Vector3(243,-2.4,401),m.world.layout.vector(m.world.layout.config.boat_docks[2].water)]:
			if not await sail_to(p,45):arrived=false;break
		check("sea_continuous_voyage",arrived,{"seconds":(Time.get_ticks_msec()-voyage_started)/1000.0})
		boat.speed=0;var landed:bool=await boat.dock() if arrived else false
		check("island_actual_docking",landed)
		if not landed:boat.leave_for_travel()
		boat.testing=false;m.player.program_driven=false
	var route_ok:=true
	await move_to(m.world.layout.vector([256,2,427]))
	for entry in m.world.layout.config.island.hotel_walk.get("arrival",[]):
		var p:Vector3=m.world.layout.vector(entry)
		if not await walk(Vector2(p.x,p.z),5):route_ok=false;break
	for i in 11:
		var point:Vector3=m.world.layout.hotel_walk_point(lerpf(-1.15,1.15,float(i)/10))
		if not await walk(Vector2(point.x,point.z),8):route_ok=false;break
	check("hotel_continuous_crescent_walk",route_ok)
	for i in 4:
		var x:float=276+(4 if i in [1,2] else 0);var z:float=426+i*15
		await move_to(m.world.layout.hotel_branch_start(z)+Vector3.UP*.4)
		var entered:bool=await walk(Vector2(x,z),5)
		check("villa_"+str(i)+"_side_door_and_glass_support",entered and absf(m.player.position.y+.8)<.35,[m.player.position.x,m.player.position.y,m.player.position.z])
		if i==0 and entered:
			var deck_ok:bool=await walk(Vector2(x,z+6),5)
			m.player.enabled=true
			var event:=InputEventKey.new();event.physical_keycode=KEY_X;event.pressed=true
			m.bay.handle_input(event)
			check("netbed_X_lie",deck_ok and m.player.seated and m.player.rest_pose=="lie")
			m.player.stand_up();m.player.enabled=false
			var steps_ok:bool=await walk(Vector2(x,z+8.5),4)
			steps_ok=(await walk(Vector2(x+3.5,z+8.5),4)) and steps_ok
			check("villa_five_step_water_access",(await walk(Vector2(x+5.6,z+8.5),4)) and steps_ok)
	if only_repairs:
		# Verify the changed dock heading and stopped pivot on the river mouth only.
		await move_to(m.world.layout.vector(m.world.layout.config.boat_docks[1].land))
		var aboard:bool=await boat.board(1);boat.testing=true;m.player.program_driven=true;m.player.enabled=false
		var upstream_ok:bool=aboard and (await sail_to(m.world.layout.vector([280,0,332]),30))
		upstream_ok=(await sail_to(m.world.layout.vector([265,.12,283]),30)) and upstream_ok
		check("yacht_stopped_pivot_and_upstream_mouth",upstream_ok)
		boat.leave_for_travel();boat.testing=false;m.player.program_driven=false
		m.state.activities.boat_choice="flower"
		await move_to(m.world.layout.vector(m.world.layout.config.boat_docks[0].land))
		var upper_boarded:bool=await boat.board(0);boat.testing=true;m.player.program_driven=true;m.player.enabled=false
		check("upper_flower_safe_departure",upper_boarded and (await sail_to(m.world.layout.vector([-165,.55,-170]),25)))
		boat.leave_for_travel();boat.testing=false;m.player.program_driven=false
		check("closeout_new_save",m.save_game(false));return
	# Stair ascent and open upper facade must work as one continuous walk.
	var cafe:Dictionary=m.world.layout.venues.B02
	await move_to(Vector3(cafe.x+6,cafe.floor_y+.4,cafe.z-6.5))
	var cafe_ok:bool=await walk(Vector2(cafe.x+6,cafe.z+6.4),6)
	cafe_ok=(await walk(Vector2(cafe.x,cafe.z+6.4),4)) and cafe_ok
	cafe_ok=(await walk(Vector2(cafe.x,cafe.z+10),4)) and cafe_ok
	check("cafe_stairs_to_open_upper_terrace",cafe_ok and m.player.position.y>cafe.floor_y+3.4)
	# Check playback ownership and decoder release together, including the outdoor screen switch.
	m.state.playlist=["sunset"];m.bay.next_song();await m.get_tree().create_timer(.5).timeout
	check("portable_playlist_plays",m.bay.music.playing and m.bay.music.get_playback_position()>.1)
	await m.show_video("B06","sunset");await m.get_tree().create_timer(.7).timeout;m.bay.update_audio()
	var decoder=m.video;var started_position:float=m.video.stream_position
	check("movie_takes_audio_ownership",m.video.is_playing() and m.bay.music.stream_paused)
	m.switch_cinema_screen();await m.get_tree().create_timer(.4).timeout
	check("outdoor_screen_same_decoder",m.video==decoder and m.current_screen_id=="B06_OUT" and m.video.stream_position>started_position)
	m.close_modal();m.bay.update_audio()
	check("close_movie_releases_decoder_and_resumes_playlist",m.video.stream==null and m.audio_player.stream==null and not m.bay.music.stream_paused)
	m.bay.music.stop();m.bay.music.stream=null
	check("new_connections_save",m.save_game(false))

func finish():
	frame_ms.sort();var average:float=0
	for t in frame_ms:average+=t
	var report:Dictionary={"mode":m.qa_mode,"checks":checks,"failures":checks.filter(func(c):return not c.passed).size(),"seconds":(Time.get_ticks_msec()-started)/1000.0,"runtime":"editor" if OS.has_feature("editor") else "export","scope":"integration physics and programmed systems; no claim of manual art acceptance","resolution":str(m.get_viewport().size),"samples":frame_ms.size()}
	if not frame_ms.is_empty():report.merge({"average_fps":1000.0/(average/frame_ms.size()),"p95_ms":frame_ms[int(frame_ms.size()*.95)]})
	var file:=FileAccess.open(m.evidence_root+"reports/"+m.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("BAY_QA_DONE ",JSON.stringify(report));m.get_tree().quit(1 if report.failures else 0)
