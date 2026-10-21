extends SceneTree
## Candidate only: existing baked proxies replace distant render detail; gameplay stays resident.

class Candidate extends RefCounted:
	var streamer
	var world
	var enabled:=false
	var near_distance:=120.0
	var hysteresis:=4.0
	var cells:Dictionary={}
	var changes:=0
	var restored:=0
	var skipped_unsupported:=0
	func install(target)->Dictionary:
		streamer=target;world=target.world;cache_loaded()
		return {"cached_cells":cells.size(),"near_distance":near_distance,"hysteresis":hysteresis,"instances_created":0}
	static func box_distance(point:Vector3,box:AABB)->float:
		return Vector3(maxf(box.position.x-point.x,maxf(0,point.x-box.end.x)),maxf(box.position.y-point.y,maxf(0,point.y-box.end.y)),maxf(box.position.z-point.z,maxf(0,point.z-box.end.z))).length()
	static func overlaps_room(box:AABB,room:Rect2)->bool:
		return room.size.length_squared()>.001 and Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).intersects(room,true)
	func want_coarse(box:AABB,camera:Camera3D,focus:Vector3,room:Rect2,already:bool=false)->bool:
		if camera==null or (camera.projection==Camera3D.PROJECTION_ORTHOGONAL and camera.size>=320):return false
		if overlaps_room(box,room):return false
		if box_distance(camera.global_position,box)<=near_distance+(0.0 if already else hysteresis):return false
		if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:
			# The eye is high above the player in follow mode. Protect its ground
			# focus plus the complete projected viewport half-diagonal, not eye distance alone.
			var viewport:Vector2=camera.get_viewport().get_visible_rect().size
			var aspect:float=viewport.x/maxf(1.0,viewport.y)
			var extent:float=camera.size*.5*sqrt(1.0+aspect*aspect)
			if box_distance(focus,box)<=near_distance+extent:return false
		return true
	func terrain(node:Node)->bool:return node.has_meta("stream_terrain") or str(node.name).begins_with("FarStrata_") or str(node.name).begins_with("TerrainStrata_")
	func actor_owned(node:Node,cell:Node)->bool:
		var at:Node=node
		while at!=null and at!=cell:
			if at.get_script()!=null:return true
			if at.has_meta("stream_ref") and str(at.get_meta("stream_ref")).begins_with("prop:"):return true
			at=at.get_parent()
		return false
	func cache_loaded():
		for id in cells.keys():
			if not streamer.loaded.has(id) or not is_instance_valid(cells[id].root) or cells[id].root!=streamer.loaded[id]:
				restore_cell(cells[id]);cells.erase(id)
		for id in streamer.loaded:
			if cells.has(id):continue
			var cell:Node3D=streamer.loaded[id];var record:Dictionary=streamer.records[id]
			var center:Vector3=record.center
			# Include the entire 96m cell footprint and every actual geometry AABB,
			# including cross-boundary eaves, towers and terrain, before testing distance.
			var box:=AABB(Vector3(center.x-48,0,center.z-48),Vector3(96,0,96))
			var geometry:Array=[];var unsupported:=false
			for node in cell.find_children("*","GeometryInstance3D",true,false):
				if node.has_method("get_aabb"):box=box.merge(node.global_transform*node.get_aabb())
				if terrain(node) or actor_owned(node,cell):continue
				if node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED:unsupported=true
				geometry.append(node)
			var far:Node3D=streamer.far_cells.get(id)
			var far_terrain:Array=[]
			if far!=null:
				for node in far.find_children("*","GeometryInstance3D",true,false):
					if terrain(node):far_terrain.append(node)
			cells[id]={"id":id,"root":cell,"far":far,"box":box,"geometry":geometry,"far_terrain":far_terrain,"coarse":false,"snapshots":[],"terrain_snapshots":[],"unsupported":unsupported}
			if unsupported:skipped_unsupported+=1
	func protect_room(focus:Vector3)->Rect2:
		if world==null or world.layout==null:return Rect2()
		var place:Dictionary=world.layout.creative_at(focus)
		if not place.is_empty():return Rect2(Vector2(place.center[0]-place.size[0]*.5-2,place.center[2]-place.size[1]*.5-2),Vector2(place.size[0]+4,place.size[1]+4))
		var id:String=world.inside_building(focus)
		for item in world.building_bounds:
			if str(item.id)==id:return Rect2(Vector2(item.x-item.w*.5-2,item.z-item.d*.5-2),Vector2(item.w+4,item.d+4))
		return Rect2()
	func enter_cell(entry:Dictionary):
		if entry.coarse or entry.far==null or entry.unsupported:return
		entry.snapshots=[];entry.terrain_snapshots=[];entry.far_previous_visible=entry.far.visible
		for node in entry.geometry:
			if not is_instance_valid(node):continue
			entry.snapshots.append({"node":node,"visible":node.visible,"shadow":node.cast_shadow})
			if node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:node.visible=false
			else:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for node in entry.far_terrain:
			if is_instance_valid(node):entry.terrain_snapshots.append([node,node.visible]);node.visible=false
		entry.far.visible=true;entry.coarse=true;changes+=1
	func restore_cell(entry:Dictionary):
		if not entry.coarse:return
		for saved in entry.snapshots:
			if not is_instance_valid(saved.node):continue
			saved.node.cast_shadow=saved.shadow
			# Only cast-OFF detail was hidden. Static source visibility is restored exactly.
			if int(saved.shadow)==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:saved.node.visible=saved.visible
		for saved in entry.terrain_snapshots:
			if is_instance_valid(saved[0]):saved[0].visible=saved[1]
		if is_instance_valid(entry.far):
			entry.far.visible=bool(entry.far_previous_visible)
			if streamer.wide_view_lod or not streamer.loaded.has(entry.id):streamer.refresh_cell_visibility(entry.id)
		entry.snapshots.clear();entry.terrain_snapshots.clear();entry.coarse=false;restored+=1
	func update(camera:Camera3D,focus:Vector3,room:Rect2=Rect2()):
		cache_loaded()
		var wide:bool=camera!=null and camera.projection==Camera3D.PROJECTION_ORTHOGONAL and camera.size>=320
		if not enabled or wide or int(streamer.far_lod_schema)<2:
			for entry in cells.values():restore_cell(entry)
			return
		if room.size.length_squared()<.001:room=protect_room(focus)
		for entry in cells.values():
			if want_coarse(entry.box,camera,focus,room,entry.coarse):enter_cell(entry)
			else:restore_cell(entry)
	func restore():
		enabled=false
		for entry in cells.values():restore_cell(entry)
	func diagnostics()->Dictionary:
		var selected:Array=[];var kept_terrain:=0;var shadow_only:=0;var hidden_detail:=0
		for entry in cells.values():
			if not entry.coarse:continue
			selected.append(entry.id)
			for node in entry.root.find_children("*","GeometryInstance3D",true,false):
				if terrain(node) and node.visible:kept_terrain+=1
			for saved in entry.snapshots:
				if int(saved.shadow)==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:hidden_detail+=1
				else:shadow_only+=1
		return {"selected_cells":selected,"cached_cells":cells.size(),"near_terrain_nodes_kept":kept_terrain,"shadow_only_nodes":shadow_only,"hidden_shadowless_detail":hidden_detail,"transitions":changes,"restorations":restored,"unsupported_double_sided_cells":skipped_unsupported,"instances_created":0}

class FixtureStream extends Node3D:
	var world=null
	var loaded:Dictionary={}
	var far_cells:Dictionary={}
	var records:Dictionary={}
	var wide_view_lod:=false
	var far_lod_schema:=2
	func refresh_cell_visibility(id:String):
		if loaded.has(id):loaded[id].visible=not wide_view_lod
		if far_cells.has(id):far_cells[id].visible=wide_view_lod or not loaded.has(id)

var m
var candidate:Candidate
var phase:=""
var last_usec:=0
var samples:Array=[]
var checks:Array=[]
var active_camera:Camera3D

func _initialize():run.call_deferred()
func write_json(path:String,data:Dictionary):
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
func check(id:String,passed:bool,details:Dictionary={}):checks.append({"id":id,"passed":passed,"details":details})

func self_test():
	var stream:=FixtureStream.new();root.add_child(stream)
	var near:=Node3D.new();stream.add_child(near);var far:=Node3D.new();stream.add_child(far)
	stream.loaded["0_0"]=near;stream.far_cells["0_0"]=far;stream.records["0_0"]={"center":Vector3(48,0,48)};stream.refresh_cell_visibility("0_0")
	var wall:=MeshInstance3D.new();wall.mesh=BoxMesh.new();near.add_child(wall);wall.position=Vector3(48,4,48)
	var detail:=MeshInstance3D.new();detail.mesh=BoxMesh.new();detail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;near.add_child(detail)
	var real_terrain:=MeshInstance3D.new();real_terrain.mesh=BoxMesh.new();real_terrain.set_meta("stream_terrain",true);near.add_child(real_terrain)
	var coarse_terrain:=MeshInstance3D.new();coarse_terrain.mesh=BoxMesh.new();coarse_terrain.set_meta("stream_terrain",true);far.add_child(coarse_terrain)
	var physical:=StaticBody3D.new();near.add_child(physical)
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(400,8,48)
	var item:=Candidate.new();item.install(stream);item.enabled=true;item.update(camera,Vector3(400,0,48))
	check("shadow_and_proxy_only",wall.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and not detail.visible and far.visible)
	check("actual_terrain_and_physics_retained",real_terrain.visible and not coarse_terrain.visible and physical.is_inside_tree() and near.visible)
	item.restore();check("all_original_properties_restore",wall.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON and detail.visible and coarse_terrain.visible and not far.visible)
	camera.position=Vector3(216,8,48);check("distance_uses_whole_cell_not_center",not item.want_coarse(AABB(Vector3.ZERO,Vector3(96,20,96)),camera,Vector3.ZERO,Rect2()))
	camera.position=Vector3(400,8,48);check("current_room_protected",not item.want_coarse(AABB(Vector3.ZERO,Vector3(96,20,96)),camera,Vector3.ZERO,Rect2(20,20,20,20)))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=42;camera.position=Vector3(400,300,400)
	check("follow_focus_plus_extent_protected",not item.want_coarse(AABB(Vector3.ZERO,Vector3(96,20,96)),camera,Vector3(100,4,48),Rect2()))
	camera.size=320;check("home_uses_existing_coarse_path",not item.want_coarse(AABB(Vector3.ZERO,Vector3(96,20,96)),camera,Vector3(500,0,500),Rect2()))
	var report:Dictionary={"scope":"CPU scene/property and selection contracts only; no GPU/FPS result","checks":checks};write_json("res://reports/creative110_render_lod_contract.json",report);print("RENDER_LOD110_CONTRACT ",JSON.stringify(report))
	stream.free();camera.free();quit(0 if checks.all(func(record):return record.passed) else 1)

func _process(_delta:float)->bool:
	if m!=null and candidate!=null and active_camera!=null:candidate.update(active_camera,m.environment_controls.camera_target() if m.environment_controls.is_observing() else m.player.global_position)
	if phase.is_empty():last_usec=0;return false
	var now:int=Time.get_ticks_usec()
	if root.get_camera_3d()!=active_camera or m.watch_camera.current:push_error("LOD probe active camera changed");quit(4);return true
	if last_usec>0:
		var rid:RID=root.get_viewport_rid();samples.append({"phase":phase,"ms":(now-last_usec)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	last_usec=now;return false
func hold(label:String,count:int):
	for i in 90:await process_frame
	phase=label;last_usec=0;write_json("res://reports/creative110_render_lod_progress.json",{"pid":OS.get_process_id(),"phase":label+"_sample"})
	for i in count:await process_frame
	phase="";last_usec=0;write_json("res://reports/creative110_render_lod_progress.json",{"pid":OS.get_process_id(),"phase":""})
func statistics()->Dictionary:
	var groups:Dictionary={}
	for sample in samples:
		if not groups.has(sample.phase):groups[sample.phase]={"frames":0,"ms":0.0,"gpu_ms":0.0,"cpu_ms":0.0,"draws":0.0,"primitives":0.0}
		var group:Dictionary=groups[sample.phase];group.frames+=1
		for field in ["ms","gpu_ms","cpu_ms","draws","primitives"]:group[field]+=sample[field]
	for group in groups.values():
		for field in ["ms","gpu_ms","cpu_ms","draws","primitives"]:group[field]/=group.frames
		group.fps=1000.0/group.ms
	return groups
func run():
	if "--self-test" in OS.get_cmdline_user_args():self_test();return
	if DisplayServer.get_name()=="headless":push_error("Rendering LOD A/B requires a scheduled real GPU run");quit(2);return
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="render_lod110_probe";m.store.directory="user://render_lod110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080))
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true;m.player.automated_motion=true;m.player.automated_horizontal=Vector2.ZERO;m.player.camera.make_current()
	for i in 120:await process_frame
	m.world.streamer.set_process(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	candidate=Candidate.new();var setup:Dictionary=candidate.install(m.world.streamer)
	active_camera=m.player.camera
	await hold("castle_original_A",150);candidate.enabled=true;await hold("castle_lod_B",210)
	var castle:Dictionary=candidate.diagnostics();var b:Image=root.get_texture().get_image();candidate.restore();await hold("castle_original_A_repeat",150)
	var a:Image=root.get_texture().get_image()
	if "--shots" in OS.get_cmdline_user_args():a.save_png("res://screenshots/creative110/render_lod_castle_A.png");b.save_png("res://screenshots/creative110/render_lod_castle_B.png")
	# A separate actual follow camera checks the protected near footprint and cutaway.
	m.environment_controls.enter();for i in 60:await process_frame
	active_camera=m.environment_controls.camera;candidate.enabled=true;candidate.update(active_camera,m.environment_controls.camera_target())
	check("follow_near_protection",not candidate.want_coarse(candidate.cells["-2_0"].box,active_camera,m.environment_controls.camera_target(),candidate.protect_room(m.environment_controls.camera_target())) if candidate.cells.has("-2_0") else true)
	var follow:Dictionary=candidate.diagnostics();candidate.restore();m.environment_controls.leave();active_camera=m.player.camera
	var castle_view:Dictionary={"camera":active_camera.global_position,"player":m.player.position,"yaw":m.player.yaw,"pitch":m.player.pitch,"zoom":m.player.zoom}
	# Reproduce the native early-journey camera (standing window pose near 3.5%).
	# Only this isolated test cabin is held still so both variants see the same frame.
	m.world.streamer.set_process(true);m.transport.reset_session()
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.automated_motion=false;m.player.enabled=true
	if not m.transport.board(0):push_error("Cannot prepare the actual cable cabin for LOD comparison");quit(5);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[m.transport.rider].rotation.y
	await m.world.prepare_region(m.player.global_position,184)
	for i in 120:await process_frame
	m.world.streamer.set_process(false);active_camera=m.player.camera;active_camera.make_current()
	await hold("cable_original_A",150);candidate.enabled=true;await hold("cable_lod_B",210)
	var cable:Dictionary=candidate.diagnostics();var cable_b:Image=root.get_texture().get_image();candidate.restore();await hold("cable_original_A_repeat",150)
	if "--shots" in OS.get_cmdline_user_args():root.get_texture().get_image().save_png("res://screenshots/creative110/render_lod_cable_A.png");cable_b.save_png("res://screenshots/creative110/render_lod_cable_B.png")
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"same actual castle and early cable player cameras A/B/A; legal >120m rendering LOD with original shadows/2m terrain/physics; Home remains original coarse mode","viewport":root.size,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"castle_view":castle_view,"cable_view":{"camera":active_camera.global_position,"player":m.player.position,"progress":m.transport.progress,"pose":m.transport.pose,"yaw":m.player.yaw,"pitch":m.player.pitch},"player_camera_verified":root.get_camera_3d()==m.player.camera,"shadows":m.sun.shadow_enabled,"setup":setup,"castle_lod":castle,"cable_lod":cable,"follow_lod":follow,"checks":checks,"stages":statistics(),"normal_saves":"isolated APPDATA and user://render_lod110_probe"}
	write_json("res://reports/creative110_render_lod_probe.json",report);print("RENDER_LOD110_RESULT ",JSON.stringify(report));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
