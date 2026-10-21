extends Node
## Real resource lifetime: far geometry stays, nearby PackedScenes and colliders are freed.
var folder:="res://assets/world/stream_r4"
var world
var manifest
var records:Dictionary={}
var loaded:Dictionary={}
var pending:Dictionary={}
var failures:Dictionary={}
var far_root:Node3D
var far_cells:Dictionary={}
var far_lod_schema:=0
var wide_view_lod:=false
const WIDE_VIEW_ORTHO_SIZE=320.0
var foci:Array[Vector3]=[Vector3(32,17,93)]
var urgent:Array[Vector3]=[]
var load_radius:=184.0
var unload_radius:=268.0
var requests_per_tick:=4
var update_elapsed:=0.0
var load_events:=0
var unload_events:=0
var peak_cells:=0
var instantiate_ms:Array=[]
var last_error:=""
var background_loading:=true
var far_box_faces=preload("res://scripts/far_box_faces110.gd").new()
var opaque_order=preload("res://scripts/opaque_order110.gd").new()

func shutdown():
	set_process(false)
	opaque_order.clear()
	if RenderingServer.frame_pre_draw.is_connected(update_far_box_faces):RenderingServer.frame_pre_draw.disconnect(update_far_box_faces)
	# Consume outstanding requests while RenderingServer is still alive, then release handles.
	if background_loading:
		for id in pending:
			var path:String=records[id].path
			var status:=ResourceLoader.load_threaded_get_status(path)
			if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:ResourceLoader.load_threaded_get(path)
	pending.clear();urgent.clear()

func _exit_tree():shutdown()

func _ready():
	if world.layout!=null:folder=world.layout.config.stream_folder
	background_loading=DisplayServer.get_name()!="headless"
	manifest=load(folder+"/manifest.tres")
	if manifest==null:last_error="世界资源清单缺失";push_error(last_error);return
	world.interactions=manifest.interactions.duplicate(true);world.building_bounds=manifest.building_bounds.duplicate(true);world.path_corridors=manifest.path_corridors.duplicate(true)
	preload("res://scripts/creative_registry110.gd").apply(world,manifest.authored_counts)
	for record in manifest.cells:records[record.id]=record
	var global_scene:PackedScene=load(folder+"/global.scn");add_child(global_scene.instantiate())
	var far_scene:PackedScene=load(folder+"/far.scn");far_root=far_scene.instantiate();add_child(far_root)
	far_lod_schema=int(far_root.get_meta("far_lod_schema",0))
	far_box_faces.bind(far_root)
	RenderingServer.frame_pre_draw.connect(update_far_box_faces)
	for id in records:
		var cell:Node3D=far_root.get_node_or_null("Far_"+id)
		if cell!=null:far_cells[id]=cell
	print("STREAM_READY ",records.size()," cells; detail is not resident")

func refresh_cell_visibility(id:String):
	# Physics and interactable resources remain resident while only distant rendering changes.
	if loaded.has(id):loaded[id].visible=not wide_view_lod
	var far:Node3D=far_cells.get(id)
	if far!=null:far.visible=wide_view_lod or not loaded.has(id)

func update_view_lod():
	var camera:Camera3D=get_viewport().get_camera_3d()
	# Old caches omit ordinary roofs, so they must never replace a loaded detailed scene.
	var requested:bool=far_lod_schema>=2 and camera!=null and camera.projection==Camera3D.PROJECTION_ORTHOGONAL and camera.size>=WIDE_VIEW_ORTHO_SIZE
	if requested==wide_view_lod:return
	wide_view_lod=requested
	for id in records:refresh_cell_visibility(id)

func distance_to_cell(point:Vector3,record:Dictionary)->float:
	var center:Vector3=record.center
	return Vector2(maxf(absf(point.x-center.x)-48,0),maxf(absf(point.z-center.z)-48,0)).length()

func wanted_distance(record:Dictionary)->float:
	var distance:=INF
	for point in foci:distance=minf(distance,distance_to_cell(point,record))
	for point in urgent:distance=minf(distance,distance_to_cell(point,record))
	return distance

func set_foci(points:Array):
	foci.clear()
	for point in points:
		if point is Vector3:foci.append(point)

func _process(delta:float):
	if manifest==null:return
	update_view_lod()
	# Scene-tree insertion is budgeted to one completed cell per rendered frame.
	for id in pending.keys():
		var path:String=records[id].path
		var status:=ResourceLoader.load_threaded_get_status(path) if background_loading else ResourceLoader.THREAD_LOAD_LOADED
		if status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			last_error="无法读取世界区域 "+id;failures[id]=last_error;pending.erase(id);push_error(last_error);continue
		if status!=ResourceLoader.THREAD_LOAD_LOADED:continue
		var scene:PackedScene=ResourceLoader.load_threaded_get(path) if background_loading else ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		pending.erase(id)
		if wanted_distance(records[id])>unload_radius:continue
		var start:=Time.get_ticks_usec()
		var cell:=scene.instantiate();add_child(cell);loaded[id]=cell
		world.bind_stream_nodes(cell,true)
		refresh_cell_visibility(id)
		opaque_order.bind_cell(cell,str(id))
		load_events+=1;peak_cells=maxi(peak_cells,loaded.size());instantiate_ms.append((Time.get_ticks_usec()-start)/1000.0)
		break
	update_elapsed+=delta
	if update_elapsed<0.12:return
	update_elapsed=0
	var candidates:Array=[]
	for id in records:
		var distance:=wanted_distance(records[id])
		if distance<=load_radius and not loaded.has(id) and not pending.has(id) and not failures.has(id):candidates.append([distance,id])
		elif distance>unload_radius and loaded.has(id):
			opaque_order.unbind_cell(str(id))
			var cell:Node=loaded[id];world.bind_stream_nodes(cell,false);remove_child(cell);cell.queue_free();loaded.erase(id);unload_events+=1
			refresh_cell_visibility(id)
	candidates.sort_custom(func(a,b):return a[0]<b[0])
	for index in mini(requests_per_tick,candidates.size()):
		var id:String=candidates[index][1]
		# Dummy/headless renderer has no thread-safe RID storage in the installed build.
		# Its diagnostic branch still loads/frees real scenes, once per frame, on the main thread.
		var error:=ResourceLoader.load_threaded_request(records[id].path,"PackedScene",false,ResourceLoader.CACHE_MODE_IGNORE) if background_loading else OK
		if error==OK:pending[id]=true
		else:last_error="区域加载请求失败 "+id;failures[id]=last_error;push_error(last_error)

func update_far_box_faces():
	# Observation/player cameras can move after this node's _process. Use the final camera pose.
	if is_inside_tree() and far_root!=null:
		var camera:Camera3D=get_viewport().get_camera_3d()
		far_box_faces.update(camera);opaque_order.update(camera)

func point_ready(point:Vector3)->bool:
	var id:="%d_%d"%[floori(point.x/96),floori(point.z/96)]
	return loaded.has(id)

func ready_near(point:Vector3,radius:float)->bool:
	for id in records:
		if distance_to_cell(point,records[id])<=radius and not loaded.has(id):return false
	return true

func prepare(point:Vector3,radius:float=110.0)->bool:
	if manifest==null:return false
	for id in failures.keys():
		if distance_to_cell(point,records[id])<=load_radius:failures.erase(id)
	urgent.append(point)
	var deadline:=Time.get_ticks_msec()+30000
	while not ready_near(point,radius):
		var relevant_failure:=false
		for id in failures:
			if distance_to_cell(point,records[id])<=radius:relevant_failure=true;break
		if Time.get_ticks_msec()>deadline or relevant_failure:
			urgent.erase(point);last_error="区域准备未完成，请重试";return false
		await get_tree().process_frame
	# Collision objects enter the physics server before control or teleport is enabled.
	await get_tree().physics_frame;await get_tree().physics_frame
	urgent.erase(point)
	return true

func diagnostics()->Dictionary:
	return {"total_cells":records.size(),"loaded_cells":loaded.size(),"pending_cells":pending.size(),"loaded_ids":loaded.keys(),"load_events":load_events,"unload_events":unload_events,"peak_cells":peak_cells,"load_radius":load_radius,"unload_radius":unload_radius,"errors":failures,"background_loading":background_loading,"far_lod_schema":far_lod_schema,"wide_view_lod":wide_view_lod,"far_lod_counts":far_root.get_meta("far_lod_counts",{}) if far_root!=null else {},"far_box_faces110":far_box_faces.diagnostics(),"static_memory_bytes":OS.get_static_memory_usage()}
