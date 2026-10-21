extends SceneTree
## Targeted isolated diagnosis, not normal-input or full-world acceptance.
const Cable=preload("res://.runtime/env_v12_workspace/overlay/scripts/creative_transport110.gd")
const Unit=preload("res://tests/creative110_transport.gd")
var m
var checks:Array=[]
var stages:Array=[]
var route_samples:Array=[]
var route_phase:=""
var route_last_usec:=0
var render_timing:=false
var camera_contracts:Array=[]
var expected_camera:Camera3D
var active_face_candidate

class SelectiveWorld extends Unit.FakeWorld:
	var allowed_center:=Vector3.INF
	func region_ready(point:Vector3)->bool:
		return not blocked and (not allowed_center.is_finite() or point.distance_to(allowed_center)<65.0)

class ProbeCable extends Cable:
	var legacy_foci:=false
	func anchor_points()->Array[Vector3]:
		if not legacy_foci:return super.anchor_points()
		var points:Array[Vector3]=[]
		if traveling:
			for cabin in cabins:points.append(cabin.global_position)
			var future:float=clampf(progress+signf(destination-progress)*CRUISE_MPS*8.0/total_length,0,1)
			points.append(lane_at(path,future,0));points.append(lane_at(path,1-future,1))
		return points

func _initialize():run.call_deferred()

func check(test:String,ok:bool,details:Dictionary={}):
	checks.append({"test":test,"passed":ok,"details":details})
	print("STREAM_LOGIC110 ",JSON.stringify(checks[-1]))

func run():
	if "--cylinder-inventory" in OS.get_cmdline_user_args():cylinder_inventory();return
	if "--far-inventory" in OS.get_cmdline_user_args():far_inventory();return
	if "--logic" in OS.get_cmdline_user_args():
		await logic_checks();return
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m)
	m.qa_mode="stream110_probe";m.store.directory="user://stream110_probe";m.store.import_directory=""
	await m.start_game(false)
	if not verify_player_camera("after_start"):return
	if "--box-faces" in OS.get_cmdline_user_args():await box_faces_probe();return
	if "--cluster16" in OS.get_cmdline_user_args():await cluster16_probe();return
	if "--box-shadow" in OS.get_cmdline_user_args():await box_shadow_probe();return
	if "--classify" in OS.get_cmdline_user_args():await classify_probe();return
	if "--far-classify" in OS.get_cmdline_user_args():await far_classify_probe();return
	if "--shader" in OS.get_cmdline_user_args() or "--shader-pure" in OS.get_cmdline_user_args():await shader_probe();return
	if "--cluster" in OS.get_cmdline_user_args():await cluster_probe();return
	if "--route" in OS.get_cmdline_user_args():await route_probe();return
	var old=m.transport;old.reset_session();m.remove_child(old);old.queue_free()
	m.transport=ProbeCable.new();m.add_child(m.transport);m.transport.setup(m)
	var route:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	var at:Vector3=m.world.layout.vector(route.points[0])+Vector3.UP*.1
	await m.world.prepare_region(at,75)
	m.player.position=m.world.safe_ground_position(at);m.player.velocity=Vector3.ZERO
	m.player.yaw=deg_to_rad(225);m.player.pitch=-.2;m.player.zoom=6;m.player.enabled=true
	m.player.automated_motion=true;m.player.automated_horizontal=Vector2.ZERO
	await physics_frame;await physics_frame
	var fixed_at:Vector3=m.player.position
	await stage("legacy_empty_cabin_foci",true,fixed_at)
	await stage("passenger_only_foci",false,fixed_at)
	await stage("legacy_empty_cabin_foci_repeat",true,fixed_at)
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"one stationary castle view; empty cabins continue; scripted diagnostic only","stages":stages,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":root.size,"normal_saves":"not used; separate APPDATA and user://stream110_probe"}
	write_json("res://reports/creative110_stream_perf_probe.json",report)
	print("STREAM_PERF110 ",JSON.stringify(report))
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func far_inventory():
	var far=load("res://assets/world/stream_creative110/far.scn").instantiate();root.add_child(far)
	var counts:Dictionary={};var tiny:=0;var total:=0;var tiny_high_poly:=0
	for node in far.find_children("*","MultiMeshInstance3D",true,false):
		var mm:MultiMesh=node.multimesh
		if mm==null:continue
		var key:String=mm.mesh.get_class();counts[key]=int(counts.get(key,0))+mm.instance_count;total+=mm.instance_count
		var bounds:AABB=mm.mesh.get_aabb()
		for i in mm.instance_count:
			var size:Vector3=(mm.get_instance_transform(i)*bounds).size.abs()
			if maxf(size.x,maxf(size.y,size.z))<=.6:
				tiny+=1
				if key!="BoxMesh":tiny_high_poly+=1
	print("FAR_INVENTORY110 ",JSON.stringify({"instances":total,"by_mesh":counts,"sub_60cm":tiny,"sub_60cm_nonbox":tiny_high_poly}))
	far.queue_free();quit()

func cylinder_inventory():
	var mesh:=CylinderMesh.new();mesh.radial_segments=12;mesh.top_radius=.5;mesh.bottom_radius=.36;mesh.height=1
	var before:Dictionary={"rings":mesh.rings,"triangles":mesh.get_faces().size()/3,"aabb":mesh.get_aabb()}
	var flat:CylinderMesh=mesh.duplicate();flat.rings=0
	var after:Dictionary={"rings":flat.rings,"triangles":flat.get_faces().size()/3,"aabb":flat.get_aabb(),"same_shape_parameters":flat.radial_segments==mesh.radial_segments and flat.top_radius==mesh.top_radius and flat.bottom_radius==mesh.bottom_radius and flat.height==mesh.height and flat.cap_top==mesh.cap_top and flat.cap_bottom==mesh.cap_bottom}
	var counts:Dictionary={}
	for id in ["-2_0","-2_-1","-1_0"]:
		var cell=load("res://assets/world/stream_creative110/cell_"+id+".scn").instantiate();root.add_child(cell)
		for node in cell.find_children("*","MeshInstance3D",true,false):
			if node.mesh is CylinderMesh:
				var key:String="direct_rings"+str(node.mesh.rings)+"_radial"+str(node.mesh.radial_segments)
				counts[key]=int(counts.get(key,0))+1
		for node in cell.find_children("*","MultiMeshInstance3D",true,false):
			if node.multimesh.mesh is CylinderMesh:
				var key:String="mm_rings"+str(node.multimesh.mesh.rings)+"_radial"+str(node.multimesh.mesh.radial_segments)
				counts[key]=int(counts.get(key,0))+node.multimesh.instance_count
		cell.free()
	var result:Dictionary={"default_12_segment_cylinder":before,"zero_height_ring_cylinder":after,"three_castle_cells_instance_counts":counts}
	write_json("res://reports/creative110_cylinder_inventory.json",result);print("CYLINDER_INVENTORY110 ",JSON.stringify(result));quit()

func _process(_delta:float)->bool:
	if active_face_candidate!=null and root.get_camera_3d()!=null:active_face_candidate.update(root.get_camera_3d())
	if route_phase.is_empty() or m==null:route_last_usec=0;return false
	var target:Camera3D=expected_camera if expected_camera!=null else m.player.camera
	if root.get_camera_3d()!=target or not target.current or m.watch_camera.current:
		verify_camera("during_"+route_phase,target);return false
	var now:int=Time.get_ticks_usec()
	if route_last_usec>0:
		var viewport_rid:RID=root.get_viewport_rid()
		route_samples.append({"phase":route_phase,"ms":(now-route_last_usec)/1000.0,"position":[m.player.position.x,m.player.position.y,m.player.position.z],"camera":[m.player.yaw,m.player.pitch,m.player.zoom],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) if render_timing else -1,"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid) if render_timing else -1,"loads":m.world.streamer.load_events,"unloads":m.world.streamer.unload_events,"loaded_cells":m.world.streamer.loaded.size(),"insertions":m.world.streamer.instantiate_ms.size()})
	route_last_usec=now;return false

func verify_player_camera(context:String)->bool:
	return verify_camera(context,m.player.camera)

func verify_camera(context:String,target:Camera3D)->bool:
	var current:Camera3D=root.get_camera_3d()
	var ok:bool=current==target and target.current and not m.watch_camera.current and m.qa_driver==null
	var record:Dictionary={"context":context,"ok":ok,"current_path":str(current.get_path()) if current!=null else "none","expected_path":str(target.get_path()),"player_camera_path":str(m.player.camera.get_path()),"current_is_player_camera":current==m.player.camera,"player_current":m.player.camera.current,"watch_current":m.watch_camera.current,"qa_driver_absent":m.qa_driver==null,"player_position":m.player.position,"camera_position":target.global_position,"camera_rotation":target.global_rotation,"camera_projection":target.projection,"ortho_size":target.size}
	camera_contracts.append(record)
	if not ok:
		write_json("res://reports/creative110_probe_camera_failure.json",record);push_error("Probe active-camera contract failed: "+JSON.stringify(record));quit(1)
	return ok

func cluster16_probe():
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);render_timing=true
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true
	await create_timer(2).timeout
	var cases:PackedStringArray=["castle","home"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-cases="):cases=arg.trim_prefix("--probe-cases=").split(",")
	var results:Array=[]
	for case_name in cases:
		if case_name=="home":
			m.world.streamer.set_process(true);m.environment_controls.enter();m.environment_controls.switch_mode()
			var home:=InputEventKey.new();home.pressed=true;home.physical_keycode=KEY_HOME;m.environment_controls.handle_input(home)
			expected_camera=m.environment_controls.camera
			await create_timer(2).timeout
		else:expected_camera=m.player.camera
		m.world.streamer.set_process(false)
		if not verify_camera(case_name+"_before_A",expected_camera):return
		var candidate=preload("res://tools/creative110_batch_cluster_probe.gd").Candidate.new()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--cluster-xz="):candidate.cluster_size.x=float(arg.trim_prefix("--cluster-xz="));candidate.cluster_size.z=candidate.cluster_size.x
			if arg.begins_with("--cluster-y="):candidate.cluster_size.y=float(arg.trim_prefix("--cluster-y="))
			if arg.begins_with("--cluster-min="):candidate.minimum_instances=int(arg.trim_prefix("--cluster-min="))
		await route_hold(case_name+"_original_A",120)
		var split:Dictionary=apply_cluster_world(candidate)
		var native:Dictionary=candidate.verify_native()
		await route_hold(case_name+"_cluster_B",180)
		candidate.restore();await route_hold(case_name+"_original_A_repeat",120)
		set_route_phase("")
		if not verify_camera(case_name+"_after_A_repeat",expected_camera):return
		var pixels:Array=await cluster_pixels(case_name,candidate)
		results.append({"case":case_name,"split":split,"native_buffer_contract":native,"pixel_captures":pixels})
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"only fallback: 16x8x16 dense Box batches near+far; full geometry/settings retained; A/B/A with final A control","cases":results,"camera_contracts":camera_contracts,"stages":route_statistics(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":root.size,"normal_saves":"isolated APPDATA"}
	write_json("res://reports/creative110_cluster16_perf_probe.json",report)
	print("CLUSTER16_PERF110 ",JSON.stringify(report))
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func apply_cluster_world(candidate)->Dictionary:
	var start:int=Time.get_ticks_usec();var parts:Array=[]
	parts.append(candidate.apply(m.world.streamer.far_root,"far"))
	for id in m.world.streamer.loaded:parts.append(candidate.apply(m.world.streamer.loaded[id],"near_"+str(id)))
	return {"parts":parts,"cpu_total_ms":(Time.get_ticks_usec()-start)/1000.0,"source_batches":candidate.total_source_batches,"clusters":candidate.total_clusters,"preserved_instances":candidate.total_instances,"cluster_size":candidate.cluster_size,"minimum_instances":candidate.minimum_instances}

func cluster_pixels(case_name:String,candidate)->Array:
	var layers:Array=[];var mask:int=1<<19;var camera:Camera3D=expected_camera;var old_mask:int=camera.cull_mask
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if not node is MeshInstance3D and not node is MultiMeshInstance3D:continue
		var material=node.material_override
		if material is ShaderMaterial and material.shader!=null and "TIME" in material.shader.code:continue
		layers.append([node,node.layers]);node.layers=mask
	camera.cull_mask=mask;m.hud.hide();paused=true
	var environment:Environment=m.environment.environment;var old_background:int=environment.background_mode;environment.background_mode=Environment.BG_COLOR
	var captures:Array=[];DirAccess.make_dir_recursive_absolute("res://.runtime/creative110_cluster16_pixels")
	for optimized in [false,true,false]:
		if optimized:apply_cluster_world(candidate)
		else:candidate.restore()
		for frame in 6:await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=root.get_texture().get_image();var data:PackedByteArray=image.get_data()
		var path:String="res://.runtime/creative110_cluster16_pixels/"+case_name+"_"+str(captures.size())+".rgb"
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(data);file.close()
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data)
		captures.append({"path":path,"sha256":hash.finish().hex_encode(),"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"bytes":data.size(),"optimized":optimized})
	paused=false;environment.background_mode=old_background;camera.cull_mask=old_mask;m.hud.show()
	for entry in layers:entry[0].layers=entry[1]
	candidate.restore();return captures

func box_shadow_probe():
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);render_timing=true
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true
	await create_timer(2).timeout;m.world.streamer.set_process(false)
	if not verify_player_camera("castle_before_A"):return
	var candidate=preload("res://tools/creative110_box_shadow_probe.gd").Candidate.new()
	await route_hold("box_shadow_original_A",120)
	var install:Dictionary=candidate.install(m.world)
	await route_hold("box_shadow_welded_B",180)
	candidate.uninstall();await route_hold("box_shadow_original_A_repeat",120)
	set_route_phase("")
	if not verify_player_camera("castle_after_A_repeat"):return
	var layers:Array=[];var mask:int=1<<19;var camera:Camera3D=m.player.camera;var old_mask:int=camera.cull_mask
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if not node is MeshInstance3D and not node is MultiMeshInstance3D:continue
		var material=node.material_override
		if material is ShaderMaterial and material.shader!=null and "TIME" in material.shader.code:continue
		layers.append([node,node.layers]);node.layers=mask
	camera.cull_mask=mask;m.hud.hide();paused=true
	var environment:Environment=m.environment.environment;var old_background:int=environment.background_mode;environment.background_mode=Environment.BG_COLOR
	var captures:Array=[];DirAccess.make_dir_recursive_absolute("res://.runtime/creative110_box_shadow_pixels")
	for optimized in [false,true,false]:
		if optimized:candidate.install(m.world)
		else:candidate.uninstall()
		for frame in 6:await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=root.get_texture().get_image();var data:PackedByteArray=image.get_data()
		var path:String="res://.runtime/creative110_box_shadow_pixels/"+str(captures.size())+".rgb"
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(data);file.close()
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data)
		captures.append({"path":path,"sha256":hash.finish().hex_encode(),"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"bytes":data.size(),"optimized":optimized})
	paused=false;environment.background_mode=old_background;camera.cull_mask=old_mask;m.hud.show()
	for entry in layers:entry[0].layers=entry[1]
	candidate.uninstall()
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"actual normal third-person castle camera; full normal shadow settings; A/B/A","camera_contracts":camera_contracts,"sun_shadow_bias":m.sun.shadow_bias,"sun_shadow_normal_bias":m.sun.shadow_normal_bias,"shadow_max_distance":m.sun.directional_shadow_max_distance,"install":install,"stages":route_statistics(),"pixel_scope":"frozen static world meshes with normal shadows; animated shader meshes/UI excluded by camera mask; flat sky background during pixels only","pixel_captures":captures,"gpu":RenderingServer.get_video_adapter_name(),"normal_saves":"isolated APPDATA"}
	write_json("res://reports/creative110_box_shadow_perf_probe.json",report)
	print("BOX_SHADOW_PERF110 ",JSON.stringify(report))
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func box_faces_probe():
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);render_timing=true
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true
	await create_timer(2).timeout
	var results:Array=[]
	for case_name in ["castle","home"]:
		if case_name=="home":
			m.world.streamer.set_process(true);m.environment_controls.enter();m.environment_controls.switch_mode()
			var home:=InputEventKey.new();home.pressed=true;home.physical_keycode=KEY_HOME;m.environment_controls.handle_input(home)
			expected_camera=m.environment_controls.camera;await create_timer(2).timeout
		else:expected_camera=m.player.camera
		m.world.streamer.set_process(false)
		if not verify_camera(case_name+"_before_faces_A",expected_camera):return
		var candidate=preload("res://tools/creative110_box_faces_probe.gd").Candidate.new()
		await route_hold(case_name+"_faces_original_A",120)
		var install:Dictionary=candidate.install(m.world.streamer.far_root,expected_camera);active_face_candidate=candidate
		var native:Dictionary=candidate.verify_native()
		await route_hold(case_name+"_faces_reduced_B",180)
		active_face_candidate=null;candidate.uninstall();await route_hold(case_name+"_faces_original_A_repeat",120)
		set_route_phase("")
		if not verify_camera(case_name+"_after_faces_A_repeat",expected_camera):return
		var pixels:Array=await box_faces_pixels(case_name,candidate)
		results.append({"case":case_name,"install":install,"native_buffer_contract":native,"pixel_captures":pixels})
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"far opaque closed axis-positive unit boxes; only guaranteed backface indices omitted; all visible faces/attributes/instances retained","cases":results,"camera_contracts":camera_contracts,"stages":route_statistics(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":root.size,"normal_saves":"isolated APPDATA"}
	write_json("res://reports/creative110_box_faces_perf_probe.json",report)
	print("BOX_FACES_PERF110 ",JSON.stringify(report))
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func box_faces_pixels(case_name:String,candidate)->Array:
	var layers:Array=[];var mask:int=1<<19;var camera:Camera3D=expected_camera;var old_mask:int=camera.cull_mask
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if not node is MeshInstance3D and not node is MultiMeshInstance3D:continue
		var material=node.material_override
		if material is ShaderMaterial and material.shader!=null and "TIME" in material.shader.code:continue
		layers.append([node,node.layers]);node.layers=mask
	camera.cull_mask=mask;m.hud.hide();paused=true
	var environment:Environment=m.environment.environment;var old_background:int=environment.background_mode;environment.background_mode=Environment.BG_COLOR
	var captures:Array=[];DirAccess.make_dir_recursive_absolute("res://.runtime/creative110_box_faces_pixels")
	for optimized in [false,true,false]:
		if optimized:candidate.install(m.world.streamer.far_root,camera)
		else:candidate.uninstall()
		for frame in 6:await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=root.get_texture().get_image();var data:PackedByteArray=image.get_data()
		var path:String="res://.runtime/creative110_box_faces_pixels/"+case_name+"_"+str(captures.size())+".rgb"
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(data);file.close()
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data)
		captures.append({"path":path,"sha256":hash.finish().hex_encode(),"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"bytes":data.size(),"optimized":optimized})
	paused=false;environment.background_mode=old_background;camera.cull_mask=old_mask;m.hud.show()
	for entry in layers:entry[0].layers=entry[1]
	candidate.uninstall();return captures

func route_probe():
	if RenderingServer.has_method("viewport_set_measure_render_time"):
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);render_timing=true
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[0])+Vector3.UP*.1);m.player.enabled=true
	for frame in 30:await process_frame
	var yaw:float=m.player.yaw;var pitch:float=m.player.pitch
	for index in road.points.size():
		set_route_phase("walk_"+str(index))
		var reached:bool=await qa.walk_to(m.world.layout.vector(road.points[index])+Vector3.UP*.1)
		print("STREAM_ROUTE_POINT ",index," ",reached," ",m.player.position)
	await route_hold("walk_end_static",120)
	set_route_phase("")
	var phases:Dictionary=route_statistics()
	var worst:String="";var worst_ms:=0.0
	for key in phases:
		if str(key).begins_with("walk_") and phases[key].frames>=30 and phases[key].mean_ms>worst_ms:worst=key;worst_ms=phases[key].mean_ms
	var worst_samples:Array=route_samples.filter(func(record):return record.phase==worst)
	var point:Array=worst_samples[int(worst_samples.size()/2)].position if not worst_samples.is_empty() else [m.player.position.x,m.player.position.y,m.player.position.z]
	await qa.move_to(Vector3(point[0],point[1],point[2]));m.player.enabled=true;m.player.yaw=yaw;m.player.pitch=pitch
	for frame in 30:await process_frame
	await route_hold("worst_same_camera_static",120)
	m.player.pitch=-.75;await route_hold("worst_look_down",120);m.player.pitch=pitch
	m.sun.shadow_enabled=false;await route_hold("worst_shadows_disabled_diagnostic",120)
	m.sun.shadow_enabled=true;m.sun.directional_shadow_max_distance=56;await route_hold("worst_shadow_distance_56_diagnostic",120)
	m.sun.directional_shadow_max_distance=110
	set_route_phase("")
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"actual player third-person camera on castle_main; diagnostic shadow variants are temporary only","route":road.points,"initial_camera":[yaw,pitch,m.player.zoom],"worst_route_phase":worst,"stages":route_statistics(),"samples":route_samples,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":root.size,"stream_insert_ms":m.world.streamer.instantiate_ms,"normal_saves":"isolated APPDATA"}
	write_json("res://reports/creative110_route_perf_probe.json",report)
	print("STREAM_ROUTE_PERF110 ",JSON.stringify({"initial_camera":report.initial_camera,"worst_route_phase":worst,"stages":report.stages}))
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func classify_probe():
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);render_timing=true
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true
	await create_timer(2).timeout
	var terrain:Array=[];var boxes:Array=[];var glass:Array=[];var geometry:Array=[]
	for node in m.world.streamer.find_children("*","GeometryInstance3D",true,false):
		if not node is MeshInstance3D and not node is MultiMeshInstance3D:continue
		var mat=node.material_override
		if mat==null and node is MeshInstance3D and node.mesh!=null and node.mesh.get_surface_count()>0:mat=node.mesh.surface_get_material(0)
		geometry.append({"name":str(node.name),"class":node.get_class(),"shadow":node.cast_shadow,"material":mat.shader.resource_path if mat is ShaderMaterial and mat.shader!=null else str(mat.get_class()) if mat!=null else "","instances":node.multimesh.instance_count if node is MultiMeshInstance3D else 1})
		if mat is ShaderMaterial and mat.shader!=null and mat.shader.resource_path.ends_with("terrain_strata.gdshader"):terrain.append([node,node.cast_shadow])
		elif node is MultiMeshInstance3D and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:boxes.append([node,node.cast_shadow])
		if mat is StandardMaterial3D and mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a<=.25:glass.append([node,mat])
	await route_hold("classify_baseline",90)
	for pair in terrain:pair[0].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await route_hold("terrain_shadow_off_diagnostic",90)
	for pair in terrain:pair[0].cast_shadow=pair[1]
	for pair in boxes:pair[0].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await route_hold("batch_shadow_off_diagnostic",90)
	for pair in boxes:pair[0].cast_shadow=pair[1]
	for pair in glass:
		var opaque=pair[1].duplicate();opaque.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED;opaque.albedo_color.a=1;pair[0].material_override=opaque
	await route_hold("glass_opaque_diagnostic",90)
	for pair in glass:pair[0].material_override=pair[1]
	RenderingServer.directional_shadow_atlas_set_size(2048,true)
	await route_hold("shadow_atlas_2048_diagnostic",90)
	RenderingServer.directional_shadow_atlas_set_size(4096,true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	await route_hold("shadow_filter_very_low_diagnostic",90)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	set_route_phase("")
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"temporary shadow/alpha classification, no settings persisted","stages":route_statistics(),"terrain_nodes":terrain.size(),"batch_nodes":boxes.size(),"glass_nodes":glass.size(),"geometry":geometry,"samples":route_samples,"gpu":RenderingServer.get_video_adapter_name(),"normal_saves":"isolated APPDATA"}
	write_json("res://reports/creative110_classify_perf_probe.json",report)
	print("STREAM_CLASSIFY_PERF110 ",JSON.stringify({"stages":report.stages,"terrain_nodes":terrain.size(),"batch_nodes":boxes.size(),"glass_nodes":glass.size()}))
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func far_classify_probe():
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);render_timing=true
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true
	await create_timer(2).timeout
	var far=m.world.streamer.far_root;var spheres:Array=[];var cylinders:Array=[];var counts:Dictionary={}
	for node in far.find_children("*","MultiMeshInstance3D",true,false):
		var mm:MultiMesh=node.multimesh
		if mm==null:continue
		var key:String=mm.mesh.get_class();counts[key]=int(counts.get(key,0))+mm.instance_count
		if mm.mesh is SphereMesh:spheres.append([node,mm.mesh])
		elif mm.mesh is CylinderMesh:cylinders.append([node,mm.mesh])
	await route_hold("far_baseline",90)
	far.hide();await route_hold("far_all_hidden_diagnostic",90);far.show()
	for pair in spheres:pair[0].hide()
	await route_hold("far_spheres_hidden_diagnostic",90)
	for pair in spheres:pair[0].show()
	for pair in cylinders:pair[0].hide()
	await route_hold("far_cylinders_hidden_diagnostic",90)
	for pair in cylinders:pair[0].show()
	for pair in spheres:
		var low:SphereMesh=pair[1].duplicate();low.radial_segments=6;low.rings=1;pair[0].multimesh.mesh=low
	await route_hold("far_sphere_6x1_lod_diagnostic",120)
	set_route_phase("")
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"temporary far category visibility and mesh LOD diagnosis only","far_instances":counts,"stages":route_statistics(),"samples":route_samples,"gpu":RenderingServer.get_video_adapter_name(),"normal_saves":"isolated APPDATA"}
	write_json("res://reports/creative110_far_classify_perf_probe.json",report)
	print("STREAM_FAR_CLASSIFY_PERF110 ",JSON.stringify({"far_instances":counts,"stages":report.stages}))
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func shader_probe():
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);render_timing=true
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true
	await create_timer(2).timeout;m.world.streamer.set_process(false)
	var terrain:Array=[];var voxel:Array=[]
	var terrain_shader:Shader=load("res://.runtime/env_v12_workspace/overlay/assets/materials/terrain_strata.gdshader")
	var voxel_shader:Shader=load("res://.runtime/env_v12_workspace/overlay/assets/materials/voxel_surface.gdshader")
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		var original=node.material_override
		if not original is ShaderMaterial or original.shader==null:continue
		var path:String=original.shader.resource_path
		if not path.ends_with("terrain_strata.gdshader") and not path.ends_with("voxel_surface.gdshader"):continue
		var optimized:ShaderMaterial=original.duplicate();optimized.shader=terrain_shader if path.ends_with("terrain_strata.gdshader") else voxel_shader
		var entry:Array=[node,original,optimized,node.layers]
		if path.ends_with("terrain_strata.gdshader"):terrain.append(entry)
		else:voxel.append(entry)
	await route_hold("shader_original",120)
	if "--shader-pure" in OS.get_cmdline_user_args():
		set_materials(terrain,true);set_materials(voxel,true);await create_timer(1).timeout
		await route_hold("shader_both_pure_branches",180)
		set_materials(terrain,false);set_materials(voxel,false);await route_hold("shader_original_repeat",120)
	else:
		set_materials(terrain,true);await create_timer(1).timeout;await route_hold("shader_terrain_optimized",120)
		set_materials(voxel,true);await create_timer(1).timeout;await route_hold("shader_both_optimized",120)
		set_materials(terrain,false);await route_hold("shader_voxel_optimized",120)
		set_materials(voxel,false);await route_hold("shader_original_repeat",120)
	set_route_phase("")
	var pixels:Array=[]
	pixels.append(await shader_pixels("terrain",terrain))
	pixels.append(await shader_pixels("voxel",voxel))
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"same actual player camera, shader calculation only; no geometry/settings change","stages":route_statistics(),"pixel_captures":pixels,"terrain_nodes":terrain.size(),"voxel_nodes":voxel.size(),"samples":route_samples,"gpu":RenderingServer.get_video_adapter_name(),"normal_saves":"isolated APPDATA"}
	write_json("res://reports/creative110_shader_pure_perf_probe.json" if "--shader-pure" in OS.get_cmdline_user_args() else "res://reports/creative110_shader_perf_probe.json",report)
	print("STREAM_SHADER_PERF110 ",JSON.stringify({"stages":report.stages,"pixel_captures":pixels,"terrain_nodes":terrain.size(),"voxel_nodes":voxel.size()}))
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func set_materials(entries:Array,optimized:bool):
	for entry in entries:entry[0].material_override=entry[2] if optimized else entry[1]

func shader_pixels(label:String,entries:Array)->Dictionary:
	var camera:Camera3D=m.player.camera;var old_mask:int=camera.cull_mask
	var mask:int=1<<19;camera.cull_mask=mask;m.hud.hide()
	for entry in entries:entry[0].layers=mask
	var captures:Array=[]
	DirAccess.make_dir_recursive_absolute("res://.runtime/creative110_shader_pixels")
	for optimized in [false,true,false]:
		set_materials(entries,optimized)
		for frame in 5:await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=root.get_texture().get_image();var data:PackedByteArray=image.get_data()
		var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(data)
		var path:String="res://.runtime/creative110_shader_pixels/"+label+"_"+str(captures.size())+".rgba"
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(data);file.close()
		captures.append({"path":path,"sha256":context.finish().hex_encode(),"bytes":data.size(),"format":image.get_format(),"width":image.get_width(),"height":image.get_height(),"optimized":optimized})
	set_materials(entries,false)
	for entry in entries:entry[0].layers=entry[3]
	camera.cull_mask=old_mask;m.hud.show()
	return {"target":label,"scope":"target shader geometry isolated by camera layers; same camera, lights, meshes, shadows; no animated water","captures":captures}

func cluster_probe():
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);render_timing=true
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true
	await create_timer(2).timeout
	await route_hold("cluster_baseline",120)
	var optimizer=preload("res://.runtime/env_v12_workspace/overlay/scripts/world_stream.gd").new()
	var start:int=Time.get_ticks_usec()
	for cell in m.world.streamer.loaded.values():optimizer.cluster_dense_batches(cell)
	var split_ms:float=(Time.get_ticks_usec()-start)/1000.0
	await route_hold("cluster_32m",180)
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"same camera; all source instances retained; native culling bounds split only","stages":route_statistics(),"clusters":optimizer.spatial_clusters,"clustered_instances":optimizer.clustered_instances,"split_all_loaded_ms":split_ms,"samples":route_samples,"gpu":RenderingServer.get_video_adapter_name(),"normal_saves":"isolated APPDATA"}
	write_json("res://reports/creative110_cluster_perf_probe.json",report)
	print("STREAM_CLUSTER_PERF110 ",JSON.stringify({"stages":report.stages,"clusters":report.clusters,"clustered_instances":report.clustered_instances,"split_all_loaded_ms":split_ms}))
	optimizer.free();m.world.streamer.shutdown();m.queue_free();await process_frame;quit()

func set_route_phase(value:String):
	route_phase=value;route_last_usec=0
	write_json("res://reports/creative110_stream_perf_probe_progress.json",{"pid":OS.get_process_id(),"phase":value+"_sample" if not value.is_empty() else ""})

func route_hold(value:String,frames:int):
	for warm in 8:await process_frame
	set_route_phase(value)
	for frame in frames:await process_frame
	set_route_phase("")

func route_statistics()->Dictionary:
	var groups:Dictionary={};var result:Dictionary={}
	for sample in route_samples:
		if not groups.has(sample.phase):groups[sample.phase]=[]
		groups[sample.phase].append(sample)
	for key in groups:
		var group:Array=groups[key];var record:Dictionary={"frames":group.size()};var times:Array=[]
		for metric in ["ms","draw_calls","objects","primitives","process_ms","physics_ms","render_cpu_ms","render_gpu_ms"]:
			var sum:float=0
			for sample in group:sum+=float(sample[metric])
			record["mean_"+metric]=sum/group.size()
		for sample in group:times.append(sample.ms)
		times.sort();record["average_fps"]=1000.0/record.mean_ms;record["p95_ms"]=times[int(times.size()*.95)]
		record["loads"]=group[-1].loads-group[0].loads;record["unloads"]=group[-1].unloads-group[0].unloads;record["loaded_cells"]=group[-1].loaded_cells
		result[key]=record
	return result

func stage(label:String,legacy:bool,at:Vector3):
	m.transport.legacy_foci=legacy;m.transport.progress=.12;m.transport.destination=1
	m.transport.traveling=true;m.transport.speed=4;m.transport.rider=-1;m.transport.update_cabins()
	m.player.position=at;m.player.velocity=Vector3.ZERO;m.autosave_timer=0
	write_json("res://reports/creative110_stream_perf_probe_progress.json",{"pid":OS.get_process_id(),"phase":label+"_warmup"})
	await create_timer(4).timeout
	# Equal motion, camera and world; the independent variable is the empty-cabin detail foci.
	var stream=m.world.streamer
	var before:Dictionary=stream.diagnostics();var before_insert:int=stream.instantiate_ms.size()
	write_json("res://reports/creative110_stream_perf_probe_progress.json",{"pid":OS.get_process_id(),"phase":label+"_sample"})
	var times:Array=[];var process_times:Array=[];var physics_times:Array=[];var counts:Array=[]
	var last:int=Time.get_ticks_usec()
	for frame in 240:
		await process_frame
		var now:int=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		counts.append(stream.loaded.size())
	var after:Dictionary=stream.diagnostics();var inserts:Array=stream.instantiate_ms.slice(before_insert)
	var sum_ms:float=0;var process_ms:float=0;var physics_ms:float=0
	for value in times:sum_ms+=float(value)
	for value in process_times:process_ms+=float(value)
	for value in physics_times:physics_ms+=float(value)
	times.sort();counts.sort();inserts.sort()
	var record:Dictionary={"phase":label,"frames":times.size(),"average_fps":1000.0/(sum_ms/times.size()),"p95_ms":times[int(times.size()*.95)],"process_ms":process_ms/process_times.size(),"physics_ms":physics_ms/physics_times.size(),"loaded_cells_median":counts[int(counts.size()/2.0)],"loaded_cells_before":before.loaded_cells,"loaded_cells_after":after.loaded_cells,"loads":after.load_events-before.load_events,"unloads":after.unload_events-before.unload_events,"insert_max_ms":inserts[-1] if not inserts.is_empty() else 0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"physics_pairs":Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),"cable_progress":m.transport.progress,"cable_moving":m.transport.traveling,"errors":after.errors}
	stages.append(record);print("STREAM_PERF_STAGE110 ",JSON.stringify(record))

func write_json(path:String,data:Dictionary):
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()

func logic_checks():
	m=Unit.FakeMain.new();root.add_child(m)
	m.world=SelectiveWorld.new();m.add_child(m.world);m.world.layout=Unit.Layout.new()
	m.world.spec=m.world.layout.apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json")))
	m.player=Unit.FakePlayer.new();m.add_child(m.player)
	m.hud=Control.new();m.add_child(m.hud);m.modal=Control.new();m.add_child(m.modal);m.modal.hide()
	m.prompt=Label.new();m.hud.add_child(m.prompt)
	var c=Cable.new();m.add_child(c);c.setup(m);c.set_physics_process(false)
	c.progress=.1;c.destination=1;c.traveling=true;c.speed=4;c.rider=-1;c.update_cabins()
	m.world.blocked=true
	var old_progress:float=c.progress
	for frame in 30:c._physics_process(1.0/60)
	check("empty_cabins_continue_without_loaded_lane",c.progress>old_progress and not c.waiting_for_region and c.cabins[0].visible and c.cabins[1].visible)
	check("moving_empty_cabins_do_not_load_detail_cells",c.anchor_points().is_empty())
	check("both_empty_cabins_stay_on_authored_path",c.cabins[0].global_position.distance_to(Cable.lane_at(c.path,c.progress,0))<.001 and c.cabins[1].global_position.distance_to(Cable.lane_at(c.path,1-c.progress,1))<.001)
	m.world.blocked=false;c.rider=0
	var future:float=c.progress+Cable.CRUISE_MPS*8/c.total_length
	m.world.allowed_center=Cable.lane_at(c.path,future,0)
	var anchors:Array[Vector3]=c.anchor_points()
	check("occupied_cabin_keeps_current_and_8_second_prefetch",anchors.size()==2 and anchors[0].distance_to(c.cabins[0].global_position)<.001 and anchors[1].distance_to(m.world.allowed_center)<.001)
	old_progress=c.progress;c._physics_process(1.0/60)
	check("unloaded_opposite_empty_lane_does_not_block_passenger",not m.world.region_ready(Cable.lane_at(c.path,1-future,1)) and c.progress>old_progress)
	m.world.blocked=true;old_progress=c.progress;c._physics_process(1.0/60)
	check("occupied_cabin_never_enters_unready_region",c.progress==old_progress and c.waiting_for_region)
	c.rider=-1;m.modal.show();old_progress=c.progress;c._physics_process(.5)
	check("modal_still_pauses_empty_cabin_trip",c.progress==old_progress)
	var state:Dictionary=c.snapshot_state()
	check("empty_trip_save_keeps_motion_and_no_passenger",bool(state.traveling) and int(state.cabin)==-1 and float(state.progress)==c.progress)
	var failed:Array=checks.filter(func(item):return not item.passed)
	write_json("res://reports/creative110_stream_logic.json",{"checks":checks,"failures":failed,"normal_saves":"not used"})
	m.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
