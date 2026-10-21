extends RefCounted
## Actual GPU frames and controller-driven walking; same absolute approach cameras as V1.1.
var main
var checks:Array=[]
var cameras:Array=[]
var intervals:Array=[]
var last_usec:=0
var collecting:=false
var label_name:String
var folder:String
var phase:="idle"
var phase_intervals:Dictionary={}

func sample(_delta:float):
	if not collecting:return
	var now:=Time.get_ticks_usec()
	if last_usec>0:
		var elapsed:float=(now-last_usec)/1000.0
		intervals.append(elapsed)
		if not phase_intervals.has(phase):phase_intervals[phase]=[]
		phase_intervals[phase].append(elapsed)
	last_usec=now

func check(name:String,ok:bool,details:Dictionary={}):
	checks.append({"test":name,"passed":ok,"detail":details});print("ENV_CHECK ",name," ",ok," ",JSON.stringify(details))

func capture(name:String,eye:Vector3,target:Vector3):
	main.watch_camera.position=eye;main.watch_camera.look_at(target);main.watch_camera.current=true
	if not await main.world.prepare_region(eye):check(name+"_region",false);return
	await main.get_tree().create_timer(0.45).timeout;await main.qa_frame()
	var path:String=folder+name+".png"
	var error:int=main.get_viewport().get_texture().get_image().save_png(path)
	cameras.append({"name":name,"eye":[eye.x,eye.y,eye.z],"target":[target.x,target.y,target.z],"fov":75,"time":0,"path":path,"write_error":error})
	check(name+"_png",error==OK)

func walk(point:Vector2):
	var p=main.player;p.automated_motion=true
	var end:=Time.get_ticks_msec()+24000
	while Time.get_ticks_msec()<end:
		await main.get_tree().physics_frame
		var direction:Vector2=point-Vector2(p.position.x,p.position.z)
		if direction.length()<0.7:p.automated_horizontal=Vector2.ZERO;p.automated_motion=false;check("walk_"+str(point),true,{"position":str(p.position)});return
		p.automated_horizontal=direction.normalized()*6.4
		p.yaw=atan2(-direction.x,-direction.y)
	p.automated_horizontal=Vector2.ZERO;p.automated_motion=false
	var collisions:Array=[]
	for i in p.get_slide_collision_count():
		var hit=p.get_slide_collision(i);collisions.append({"point":str(hit.get_position()),"normal":str(hit.get_normal())})
	check("walk_"+str(point),false,{"position":str(p.position),"collisions":collisions})

func run(target):
	main=target;label_name=main.qa_mode.trim_prefix("environment_");folder=main.evidence_root+"screenshots/environment_v1_2/"+label_name+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true;main.menu.hide();main.hud.hide();main.set_time(0)
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0;main.watch_camera.fov=75
	var w=main.world
	main.player.position=w.surface(-220,-150,0.6);await w.prepare_region(main.player.position)
	var fixed:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/art_house_cameras.json"))
	for camera in fixed:
		if camera.name not in ["approach","threequarter"]:continue
		await capture(camera.name,Vector3(camera.eye[0],camera.eye[1],camera.eye[2]),Vector3(camera.target[0],camera.target[1],camera.target[2]))
	await capture("V03_strata_near",w.surface(-269,-213,2.7),w.surface(-278,-234,0.65))
	await capture("V04_hillside_far",w.surface(-181,-189,15),w.surface(-259,-268,8))
	await capture("V06_arrival_garden",w.surface(-226,-153,4.6),w.surface(-240,-158,0.85))
	await capture("V07_forest_edge",w.surface(-269,-203,2.4),w.surface(-286,-226,3.5))
	if str(w.terrain_art.config.coverage)=="world_ecologies":
		await capture("V08_river_strata",w.surface(278,-251,6.0),Vector3(307+18*sin(-277*0.014),w.land_height(309,-277)-1.5-w.river_drop(-277),-277))
		await capture("V09_summit",w.surface(0,-381,3.3),Vector3(-5,14,58))
		await capture("coast_wind_trees",w.surface(-92,300,2.7),w.surface(-80,281,3.1))
		if w.streamer.manifest.authored_counts.get("ecology_v12",{}).get("rock_nodes",0)>0:
			await capture("ecology_forest_floor",w.surface(-314,-244,2.2),w.surface(-302,-250,1.1))
			await capture("ecology_river_rocks",w.surface(353,-246,2.8),w.surface(332,-246,0.9))
			await capture("ecology_coast_ground",w.surface(-148,303,1.9),w.surface(-143,294,1.0))
	# Actual triangle geometry remains legible with foliage/shrub decoration hidden.
	var hidden:Array=[]
	for cell in w.streamer.loaded.values():
		for mesh in cell.find_children("*","MultiMeshInstance3D",true,false):
			mesh.hide();hidden.append(mesh)
	await capture("V03_geometry_without_vegetation",w.surface(-269,-213,2.7),w.surface(-278,-234,0.65))
	for mesh in hidden:
		if is_instance_valid(mesh):mesh.show()
	# Seven live prototypes, instantiated only for inspection, not counted as built world trees.
	var showcase:=Node3D.new();main.add_child(showcase)
	var builder=preload("res://scripts/builder.gd").new(showcase)
	var tree_art=preload("res://scripts/vegetation_art.gd").new()
	var origins:Array=[]
	for kind in 7:
		var p:=Vector3(-358+kind*13,110,-154)
		origins.append(p);tree_art.tree(builder,p,kind,1.0)
	builder.box(Vector3(-319,109.8,-154),Vector3(98,0.4,12),"98a671")
	builder.finish()
	check("seven_block_tree_resources",builder.tree_counts.size()==7,{"counts":builder.tree_counts,"scope":"QA-only inspection instances of the exported prototype source"})
	for kind in 7:await capture("V05_tree_T0"+str(kind+1),origins[kind]+Vector3(8,4.8,10),origins[kind]+Vector3(0,4,0))
	showcase.queue_free();await main.get_tree().process_frame
	# Collision heights must agree with actual loaded physics, including near risers.
	for point in [Vector2(-279.3,-219.4),Vector2(-284.4,-233.6),Vector2(-268.5,-247.7),Vector2(-300.4,-208.6),Vector2(-237,-157),Vector2(-220,-150)]:
		var y:float=w.height_at(point.x,point.y);var from:=Vector3(point.x,y+0.7,point.y)
		await w.prepare_region(from)
		var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,from-Vector3(0,1.5,0)))
		var difference:float=absf(hit.position.y-y) if not hit.is_empty() else 999.0
		check("ground_collision_"+str(point),not hit.is_empty() and difference<0.20,{"difference_m":difference})
	main.player.position=w.surface(-220,-150,0.5);main.player.velocity=Vector3.ZERO
	for camera in fixed:
		if camera.name=="approach":
			main.watch_camera.position=Vector3(camera.eye[0],camera.eye[1],camera.eye[2]);main.watch_camera.look_at(Vector3(camera.target[0],camera.target[1],camera.target[2]));main.watch_camera.current=true
	await w.prepare_region(main.player.position);await main.get_tree().create_timer(1.5).timeout
	phase="house_approach_static";collecting=true;await main.get_tree().create_timer(8).timeout
	phase="player_camera_walk";main.watch_camera.current=false;main.player.camera.current=true
	for point in [Vector2(-237,-148.5),Vector2(-237,-157),Vector2(-237,-162),Vector2(-237,-168),Vector2(-237,-162),Vector2(-237,-157),Vector2(-237,-148.5),Vector2(-237,-153.5),Vector2(-246,-160.8),Vector2(-246,-174),Vector2(-256,-185),Vector2(-266,-201),Vector2(-278,-211),Vector2(-266,-201),Vector2(-256,-185),Vector2(-246,-174)]:
		await walk(point)
		if not checks[-1].passed:break
	phase="forest_static"
	await capture("V07_walk_destination",main.player.position+Vector3(0,1.75,0),w.surface(-278,-229,3))
	await main.get_tree().create_timer(8).timeout;collecting=false
	intervals.sort();var total:=0.0;var over100:=0;var failures:=0
	for value in intervals:total+=value;over100+=1 if value>100 else 0
	for item in checks:failures+=0 if item.passed else 1
	var phases:Dictionary={}
	for name in phase_intervals:
		var times:Array=phase_intervals[name];times.sort();var sum:=0.0;var slow:=0
		for ms in times:sum+=ms;slow+=1 if ms>100 else 0
		phases[name]={"frames":times.size(),"average_fps":1000.0*times.size()/maxf(sum,0.001),"p95_ms":times[int(times.size()*0.95)],"p99_ms":times[int(times.size()*0.99)],"over100ms":slow}
	var performance:={"frames":intervals.size(),"average_fps":1000.0*intervals.size()/maxf(total,0.001),"p95_ms":intervals[int(intervals.size()*0.95)],"p99_ms":intervals[int(intervals.size()*0.99)],"over100ms":over100,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"resolution":[1920,1080],"render_scale":1.0,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"shadows":true,"phases":phases}
	# Independent starts verify each real spur and claim in the native package too.
	# These checks occur after performance collection and are not a continuous tour claim.
	for zone in w.spec.zones:
		var access:Array[Vector2]=w.stamp_access_points(zone)
		main.player.position=w.surface(access[0].x,access[0].y,0.5);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		for point in access:await walk(point)
		for action in w.interactions:
			if action.id==zone.id:main.activate(action);break
		check(zone.id+"_real_stamp_claim",zone.id in main.state.stamps)
		var returning:Array=access.slice(0,access.size()-1);returning.reverse()
		for point in returning:await walk(point)
		if zone.id in ["Z01","Z08"]:await capture(zone.id+"_stamp_access",main.player.position+Vector3(0,2.6,3.0),w.surface(zone.x+9,zone.z+14,1.1))
	failures=0
	for item in checks:failures+=0 if item.passed else 1
	var report:={"label":label_name,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","coverage":w.terrain_art.config.coverage,"checks":checks,"cameras":cameras,"failures":failures,"performance":performance,"scope":"actual GPU screenshots and controller walking; sample and seven prototype resources; not whole-world acceptance or human play"}
	var file:=FileAccess.open(main.evidence_root+"reports/environment_"+label_name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ENV_TERMINAL ",JSON.stringify({"failures":failures,"performance":performance}));main.get_tree().quit(1 if failures else 0)
