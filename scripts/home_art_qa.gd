extends RefCounted
## Fixed-camera, actual GPU evidence. Baseline and revised build share this driver.
var main
var results:Array=[]
var frame_ms:Array=[]
var last_usec:=0
var collecting:=false
var last_process_frame:=-1
var fixed_cameras:Array=[]

func sample(_delta:float=0.0):
	if not collecting:return
	var frame:=Engine.get_process_frames()
	if frame==last_process_frame:return
	last_process_frame=frame
	var now:=Time.get_ticks_usec()
	if last_usec>0:frame_ms.append((now-last_usec)/1000.0)
	last_usec=now

func walk(target:Vector2)->bool:
	var p=main.player;p.automated_motion=true
	var deadline:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		await main.get_tree().physics_frame
		var delta:=target-Vector2(p.position.x,p.position.z)
		if delta.length()<0.65:p.automated_horizontal=Vector2.ZERO;p.automated_motion=false;return true
		p.automated_horizontal=delta.normalized()*4.5
	p.automated_horizontal=Vector2.ZERO;p.automated_motion=false;return false

func run(target):
	main=target
	print("HOME_ART_BEGIN ",main.qa_mode)
	await main.start_game(false);main.player.enabled=false;main.menu.hide();main.hud.hide();main.set_time(0)
	print("HOME_ART_STARTED")
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0;main.watch_camera.fov=75
	var o:Vector3=main.world.surface(-237,-169,0.08)
	main.player.position=main.world.surface(-220,-150,0.6);await main.world.prepare_region(o)
	var views:Array=[
		["front",main.world.surface(-232,-149,2.1),main.world.surface(-237,-161,1.0),0],
		["approach",main.world.surface(-234,-151,1.65),o+Vector3(0,2.4,3),0],
		["threequarter",o+Vector3(16,6.2,16),o+Vector3(0,2.5,0),0],
		["through_window",o+Vector3(5.3,1.8,8.4),o+Vector3(3.8,1.3,-1.8),0],
		["interior",o+Vector3(0,2.0,3.7),o+Vector3(-1,1.5,-3.4),0],
		["collection",o+Vector3(2.7,1.8,-1.3),o+Vector3(0,2.1,-5.15),0],
		["outlook",o+Vector3(4.6,1.65,-0.5),o+Vector3(5.0,1.8,11.5),0],
		["dusk",o+Vector3(13,4.7,16),o+Vector3(0,2.0,1),1],
		["garden",main.world.surface(-249,-151,1.75),o+Vector3(-4,2,-2),0],
		["forest",main.world.surface(-270,-183,1.8),main.world.surface(-275,-220,8),0],
		["street",Vector3(-77,4,219),Vector3(-96,2.5,188),0],
		["plaza",Vector3(24,5,89),Vector3(0,9,40),0]
	]
	var label:String=main.qa_mode.trim_prefix("homeart_")
	if FileAccess.file_exists("res://data/art_house_cameras.json"):
		fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/art_house_cameras.json"))
	if not fixed_cameras.is_empty():
		views.clear()
		for camera in fixed_cameras:
			views.append([camera.name,Vector3(camera.eye[0],camera.eye[1],camera.eye[2]),Vector3(camera.target[0],camera.target[1],camera.target[2]),camera.time])
	var folder:String=main.evidence_root+"screenshots/visual_before_after/"+label+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	var cameras:Array=[]
	for row in views:
		main.set_time(row[3]);main.watch_camera.position=row[1];main.watch_camera.look_at(row[2]);main.watch_camera.current=true
		if not await main.world.prepare_region(row[1]):push_error("Home art camera region not ready");main.get_tree().quit(1);return
		await main.get_tree().create_timer(0.6).timeout;await main.qa_frame()
		var path:String=folder+row[0]+".png"
		var error:int=main.get_viewport().get_texture().get_image().save_png(path)
		cameras.append({"name":row[0],"eye":[row[1].x,row[1].y,row[1].z],"target":[row[2].x,row[2].y,row[2].z],"fov":75,"time":row[3],"path":path,"write_error":error})
		print("HOME_ART_CAPTURE ",row[0]," ",error)
	main.set_time(0);main.watch_camera.position=views[0][1];main.watch_camera.look_at(views[0][2]);main.watch_camera.current=true
	await main.world.prepare_region(o);await main.get_tree().create_timer(2).timeout
	main.player.position=main.world.surface(-220,-150,0.6)
	var external_driver:bool=main.qa_driver!=self
	if external_driver:main.get_tree().process_frame.connect(sample)
	collecting=true
	for point in [Vector2(-237,-148.5),Vector2(-237,-162),Vector2(-237,-168),Vector2(-232.8,-168),Vector2(-237,-168),Vector2(-237,-148.5)]:
		var passed:bool=await walk(point)
		results.append({"target":[point.x,point.y],"passed":passed,"position":str(main.player.position)})
		print("HOME_ART_WALK ",point," ",passed)
		if not passed:break
	await main.get_tree().create_timer(12).timeout;collecting=false
	if external_driver:main.get_tree().process_frame.disconnect(sample)
	frame_ms.sort();var total:=0.0;var over100:=0
	for value in frame_ms:
		total+=value
		if value>100:over100+=1
	var report:Dictionary={"label":label,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","cameras":cameras,"movement":results,"performance":{"frames":frame_ms.size(),"average_fps":1000.0*frame_ms.size()/maxf(total,0.001),"p95_ms":frame_ms[int(frame_ms.size()*0.95)],"p99_ms":frame_ms[int(frame_ms.size()*0.99)],"over100ms":over100,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"resolution":[main.get_viewport().size.x,main.get_viewport().size.y],"render_scale":main.get_viewport().scaling_3d_scale,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"shadows":main.sun.shadow_enabled},"scope":"GPU screenshots and local collision walking; wall-clock frame intervals with warmup; not full-world or 20-minute acceptance"}
	var file:=FileAccess.open(main.evidence_root+"reports/home_art_"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit()
