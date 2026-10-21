extends RefCounted
## Fixed-camera evidence plus real controller movement along the preserved N07 access.
var main
var phase:="nature"
var frames:Array=[]
var collecting:=false
var last_usec:=0
var checks:Array=[]
var cameras:Array=[]
var ray_probes:Array=[]
var fixed_cameras:Array=[]

func sample(_delta:float):
	if not collecting:return
	var now:=Time.get_ticks_usec()
	if last_usec>0:frames.append((now-last_usec)/1000.0)
	last_usec=now

func check(name:String,ok:bool,details:Dictionary={}):
	checks.append({"test":name,"passed":ok,"details":details});print("NATURE_CHECK ",name," ",ok," ",JSON.stringify(details))

func capture(name:String,eye:Vector3,target:Vector3):
	for view in fixed_cameras:
		if view.name==name:
			eye=Vector3(view.eye[0],view.eye[1],view.eye[2]);target=Vector3(view.target[0],view.target[1],view.target[2]);break
	await main.qa_capture(main.qa_mode+"_"+name,eye,target)
	cameras.append({"name":name,"eye":[eye.x,eye.y,eye.z],"target":[target.x,target.y,target.z],"fov":main.watch_camera.fov,"sun_shadows":main.sun.shadow_enabled})
	check(name+"_capture",FileAccess.file_exists(main.evidence_root+"screenshots/"+main.qa_mode+"_"+name+".png"))

func walk(point:Vector2)->bool:
	var p=main.player;p.automated_motion=true
	var until:=Time.get_ticks_msec()+26000
	while Time.get_ticks_msec()<until:
		await main.get_tree().physics_frame
		var direction:Vector2=point-Vector2(p.position.x,p.position.z)
		if direction.length()<0.7:
			p.automated_horizontal=Vector2.ZERO;p.automated_motion=false
			check("walk_"+str(point),true,{"position":str(p.position)});return true
		p.automated_horizontal=direction.normalized()*6.4;p.yaw=atan2(-direction.x,-direction.y)
	p.automated_horizontal=Vector2.ZERO;p.automated_motion=false
	var collisions:Array=[]
	for i in p.get_slide_collision_count():
		var hit=p.get_slide_collision(i);var body=hit.get_collider()
		collisions.append({"point":str(hit.get_position()),"normal":str(hit.get_normal()),"body_position":str(body.global_position) if body is Node3D else str(body)})
	check("walk_"+str(point),false,{"position":str(p.position),"collisions":collisions});return false

func run(target):
	main=target
	fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/nature_cameras.json"))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.set_time(0);main.watch_camera.fov=75
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	main.player.position=w.surface(281,-275,0.5);await w.prepare_region(main.player.position)
	var deck_y:float=w.height_at(286,-302)
	var fall_y:float=w.land_height(325,-332)-11
	await capture("waterfall_front",Vector3(316,deck_y+2.2,-302),Vector3(325,fall_y,-331))
	await capture("waterfall_bank",w.surface(285,-308,2.4),Vector3(325,fall_y+3,-331))
	await capture("waterfall_crown",w.surface(287,-340,4.0),Vector3(325,fall_y+7,-331))
	await capture("waterfall_side_view",Vector3(302,w.height_at(287,-312)+3.9,-317),Vector3(325,fall_y,-331))
	await capture("river_road",w.surface(353,-246,2.8),w.surface(332,-246,0.9))
	for pixel in [Vector2(1400,360),Vector2(1260,250),Vector2(1040,440),Vector2(1230,450)]:
		var origin:Vector3=main.watch_camera.project_ray_origin(pixel)
		var ray:Vector3=main.watch_camera.project_ray_normal(pixel)
		var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+ray*400))
		if not hit.is_empty():ray_probes.append({"pixel":str(pixel),"position":str(hit.position),"normal":str(hit.normal),"collider":str(hit.collider.get_path())})
	main.sun.shadow_enabled=false
	await capture("river_road_no_shadow",w.surface(353,-246,2.8),w.surface(332,-246,0.9))
	main.sun.shadow_enabled=true
	# Independent start, then ordinary controller motion. No teleport between route points.
	main.player.position=w.surface(220,-170,0.5);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	collecting=true
	for point in [Vector2(281,-275),Vector2(284,-295.5),Vector2(286,-302),Vector2(300,-302),Vector2(315,-302),Vector2(300,-302),Vector2(286,-302),Vector2(287,-312),Vector2(302,-317),Vector2(287,-312),Vector2(286,-302),Vector2(284,-295.5),Vector2(281,-275),Vector2(220,-170)]:
		if not await walk(point):break
		if point==Vector2(302,-317):
			var from:=Vector3(303,w.height_at(287,-312)+2.08+0.65,-317)
			var guards:=0
			for direction in [Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
				var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+direction*3))
				if not hit.is_empty():guards+=1
			check("N07_side_platform_three_guards",guards==3,{"hits":guards})
	collecting=false
	check("N07_view_interaction_retained",w.interactions.any(func(action):return action.id=="N07_VIEW" and action.kind=="photo_mode"))
	frames.sort();var total:=0.0;var slow:=0;var failed:=0
	for ms in frames:total+=ms;slow+=1 if ms>100 else 0
	for row in checks:failed+=0 if row.passed else 1
	var performance:={"frames":frames.size(),"average_fps":1000.0*frames.size()/maxf(total,0.001),"p95_ms":frames[int(frames.size()*0.95)],"p99_ms":frames[int(frames.size()*0.99)],"over100ms":slow,"scope":"N07 real controller walk, independent start; not full world long test"}
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failed,"cameras":cameras,"ray_probes":ray_probes,"performance":performance,"waterfall_counts":w.streamer.manifest.authored_counts.get("waterfall_v12",{}),"runtime":"editor_binary" if OS.has_feature("editor") else "export_release"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NATURE_TERMINAL ",JSON.stringify(report));main.get_tree().quit(1 if failed else 0)
