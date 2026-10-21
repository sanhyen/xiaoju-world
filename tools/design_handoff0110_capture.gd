extends SceneTree
## Read-only photographic survey. Geometry, materials and collisions come from the shipped PCK.
var m
var output:=""
var limit:=0
var only:PackedStringArray=[]
var refresh:=false
var completed:=0
var jobs:Array=[]
var metadata:Array=[]

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--handoff-output="):output=arg.trim_prefix("--handoff-output=")
		if arg.begins_with("--handoff-limit="):limit=int(arg.trim_prefix("--handoff-limit="))
		if arg.begins_with("--handoff-only="):only=arg.trim_prefix("--handoff-only=").split(",")
		if arg=="--handoff-refresh":refresh=true
	if output.is_empty():quit(2);return
	run.call_deferred()

func serial(value):
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Vector2:return [value.x,value.y]
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[str(key)]=serial(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for item in value:result.append(serial(item))
		return result
	return value

func write_json(path:String,value):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Cannot write survey "+path);quit(3);return
	file.store_string(JSON.stringify(serial(value),"\t"));file.close()

func v(a:Array)->Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))

func job(id:String,name:String,kind:String,file:String,eye:Vector3,target:Vector3,anchor:Vector3,level:int=-1):
	jobs.append({"id":id,"name":name,"kind":kind,"file":file,"eye":eye,"target":target,"anchor":anchor,"floor_index":level})

func run():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_title("小鞠世界 0110 · 只读地点摄影")
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m)
	m.qa_mode="design_handoff0110_readonly";m.store.directory="user://design_handoff0110_isolated";m.store.import_directory=""
	await m.start_game(false)
	m.player.enabled=false;m.player.set_physics_process(false);m.player.set_process_unhandled_input(false)
	m.set_process_unhandled_input(false);m.set_process_input(false)
	m.environment_controls.set_process(false);m.environment_controls.set_process_unhandled_input(false)
	m.set_process(false);m.ui.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	m.player.figure.visible=false
	m.watch_camera.fov=67.0;m.watch_camera.near=.08
	write_json(output+"/data/places-runtime.json",m.world.layout.creative_places)
	write_json(output+"/data/interactions-runtime.json",m.world.interactions)
	write_json(output+"/data/items-runtime.json",m.creative.items.defs)
	write_json(output+"/data/layout-runtime.json",m.world.layout.config)
	write_json(output+"/data/programs-runtime.json",m.programs)
	write_json(output+"/data/assets-runtime.json",m.assets)
	write_json(output+"/data/life-media-runtime.json",JSON.parse_string(FileAccess.get_file_as_string("res://data/life_media_bay.json")))
	var map=load("res://scripts/bay_map_view.gd").new()
	map.spec=m.world.spec;map.layout_reference=m.world.layout
	var map_places:Array=map.places();map.free()
	write_json(output+"/data/map-places-runtime.json",map_places)
	write_json(output+"/evidence/capture-environment.json",{"version":ProjectSettings.get_setting("application/config/version"),"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":get_root().size,"geometry":"Shipped XiaojuWorld.pck loaded by matching Godot engine; game data, materials and meshes unchanged","method":"Direct viewport photographic viewpoints; not a walk-through or collision acceptance","normal_saves":"Isolated APPDATA/LOCALAPPDATA; new empty state; normal progress never imported","user_data":OS.get_user_data_dir(),"time":"daytime clear weather","image_processing":"Raw JPEG viewport captures, no generated imagery"})
	var ids:Dictionary={}
	for p in m.world.layout.creative_places:
		ids[str(p.id)]=true
		var center:Vector3=v(p.center);var w:float=float(p.size[0]);var d:float=float(p.size[1]);var yaw:float=float(p.door_yaw)
		var turn:=Basis(Vector3.UP,yaw)
		var height:float=maxf(5.5,float(p.floors[-1])-float(p.floors[0])+5.0)
		var extent:float=maxf(w,d)
		var eye:Vector3=center+turn*Vector3(extent*.72,height*.72+extent*.38,extent*1.12)
		var target:Vector3=center+Vector3.UP*(height*.40)
		job(str(p.id),str(p.name),"exterior","images/places/"+str(p.id)+"/exterior.jpg",eye,target,v(p.door))
		for n in p.floors.size():
			var y:float=float(p.floors[n]);var focus:=Vector3(center.x,y,center.z)
			# Human-eye interior view. A separate higher viewpoint is useful for open platforms.
			var inner:Vector3=focus+turn*Vector3(w*.27,1.65,d*.25)
			var look:Vector3=focus+turn*Vector3(-w*.20,1.35,-d*.24)
			job(str(p.id),str(p.name),"floor","images/places/"+str(p.id)+"/floor-%02d.jpg"%(n+1),inner,look,focus,n)
	# Each non-building destination gets one location context photograph. Floor aliases share building photographs.
	for p in map_places:
		if ids.has(str(p.id)) or str(p.get("kind",""))=="upper":continue
		var x:float=float(p.get("x",0));var z:float=float(p.get("z",0));var focus:Vector3=m.world.surface(x,z,0)
		var anchor:Vector3=focus
		if p.get("safe") is Array and p.safe.size()==3:anchor=v(p.safe)+Vector3.UP*float(m.world.layout.config.sea_y)
		var kind:String=str(p.get("kind","place"))
		var distance:float=34 if kind in ["zone","island"] else 13
		var eye:Vector3=focus+Vector3(distance*.85,distance*.65,distance)
		job(str(p.id),str(p.name),"outdoor","images/outdoors/"+str(p.id)+".jpg",eye,focus+Vector3.UP*1.7,anchor)
	var regions:Array=[
		["WORLD_SOUTH","大陆与双岛总览",Vector3(880,780,1160),Vector3(0,25,10)],
		["EAST_TERRACES","晴岬叠台镇全景",Vector3(430,160,340),Vector3(240,15,115)],
		["CASTLE_COURT","城郭与庭院",Vector3(-35,75,135),Vector3(-113,21,25)],
		["PORTRAIT_AXIS","肖像与广场轴线",Vector3(27,13,135),Vector3(0,15,39)],
		["CORAL_ISLAND","珊瑚岛自然岸与水屋",Vector3(340,68,535),Vector3(228,0,450)],
		["FOREST_ISLAND","森林岛与树冠线路",Vector3(38,72,572),Vector3(-59,6,488)],
		["TWIN_WALKS","双岛与连接栈道",Vector3(280,195,670),Vector3(95,2,440)],
		["FLOWER_HILL","五彩花丘、秋千与风车",Vector3(-181,52,-120),Vector3(-225,10,-177)],
		["FARM_PASTURE","农田与羊猪牧场",Vector3(-227,52,330),Vector3(-290,3,265)],
		["CABLE_ROUTE","山地缆车与花丘",Vector3(-248,85,-106),Vector3(-174,52,-237)],
		["SUMMIT_VIEW","北山与峰顶路线",Vector3(48,128,-315),Vector3(-22,64,-389)],
		["Z09_ROCK","崖湾嵌岩聚落",Vector3(355,64,110),Vector3(288,13,24)],
		["MUSIC_STREET","音乐街与生活屋",Vector3(-29,53,286),Vector3(-111,4,203)],
		["ARTS_HILL","艺文山腰与主题房",Vector3(308,87,-151),Vector3(234,28,-246)],
		["RIVER_MOUTH","泻湖与河口桥",Vector3(370,35,380),Vector3(300,0,324)]
	]
	for r in regions:job(r[0],r[1],"region","images/regions/"+r[0]+".jpg",r[2],r[3],r[3])
	var override_path:String=output+"/evidence/photo-overrides.json"
	if FileAccess.file_exists(override_path):
		var overrides:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(override_path))
		for item in jobs:
			if not overrides.has(str(item.file)):continue
			var change:Dictionary=overrides[str(item.file)]
			for key in ["eye","target","anchor"]:
				if change.has(key):item[key]=v(change[key])
			item["photographic_note"]=str(change.get("note","Viewpoint adjusted to avoid foreground obstruction"))
	write_json(output+"/evidence/photo-jobs.json",jobs)
	for item in jobs:
		if not only.is_empty() and str(item.id) not in only and str(item.file) not in only:continue
		var path:String=output+"/"+str(item.file)
		if not refresh and FileAccess.file_exists(path) and FileAccess.file_exists(path+".json"):continue
		if limit>0 and completed>=limit:break
		await capture(item)
	write_json(output+"/data/resource-sources-runtime.json",m.creative.source_records)
	write_json(output+"/data/interactions-session-runtime.json",m.world.interactions)
	write_json(output+"/evidence/survey-last-run.json",{"completed":completed,"jobs":jobs.size(),"limit":limit,"only":only,"pid":OS.get_process_id(),"user_data":OS.get_user_data_dir()})
	m.world.set_observation_cutaway(Vector3.ZERO,false)
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func capture(item:Dictionary):
	var anchor:Vector3=item.anchor
	m.player.position=anchor+Vector3.UP*.12;m.player.velocity=Vector3.ZERO
	m.world.set_observation_cutaway(Vector3.ZERO,false)
	m.watch_camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	if str(item.id)=="WORLD_SOUTH":
		m.watch_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;m.watch_camera.size=1370
		m.world.streamer.wide_view_lod=true
	else:m.world.streamer.wide_view_lod=false
	m.watch_camera.position=item.eye;m.watch_camera.look_at(item.target);m.watch_camera.current=true
	var foci:Array[Vector3]=[anchor,item.eye,item.target];m.world.streamer.set_foci(foci)
	var ready:bool=await m.world.prepare_region(anchor,112.0)
	if not ready:push_error("Photographic region not ready "+str(item.id));quit(4);return
	for i in 14:await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	var path:String=output+"/"+str(item.file);DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error:Error=image.save_jpg(path,.92)
	if error!=OK:push_error("Photographic save failed "+path);quit(5);return
	var record:Dictionary=serial(item)
	record.merge({"captured_at":Time.get_datetime_string_from_system(),"width":image.get_width(),"height":image.get_height(),"version":"0.11.0","region_ready":ready,"floor_view":"Human-eye interior/platform; roof cutaway disabled" if str(item.kind)=="floor" else "Normal full exterior geometry"})
	write_json(path+".json",record)
	completed+=1
	write_json(output+"/evidence/progress.json",{"pid":OS.get_process_id(),"completed":completed,"of":jobs.size(),"id":item.id,"file":item.file})
	print("HANDOFF_PHOTO ",completed," ",item.file)
