extends SceneTree
## Isolated giant-flower-batch candidate: no LOD, removed instances or changed shadows.
class Candidate extends RefCounted:
	var cluster_size:=Vector3(24,16,24)
	var sphere_minimum:=2000
	var box_minimum:=20000
	var originals:Array=[]
	var created:Array=[]
	var details:Array=[]
	var stripped_meshes:Dictionary={}
	var strip_zero_area:=true

	static func raw_transform(data:PackedFloat32Array,at:int)->Transform3D:
		return Transform3D(Basis(Vector3(data[at],data[at+4],data[at+8]),Vector3(data[at+1],data[at+5],data[at+9]),Vector3(data[at+2],data[at+6],data[at+10])),Vector3(data[at+3],data[at+7],data[at+11]))

	func eligible(node:MultiMeshInstance3D)->bool:
		var source:MultiMesh=node.multimesh
		if source==null or source.transform_format!=MultiMesh.TRANSFORM_3D or node.has_meta("flower_cluster110"):return false
		if node.get_script()!=null or node.get_child_count()>0 or node.has_meta("stream_ref"):return false
		if source.visible_instance_count>=0 and source.visible_instance_count<source.instance_count:return false
		if source.mesh is SphereMesh:
			if source.instance_count<sphere_minimum or source.mesh.radial_segments!=8 or source.mesh.rings!=3:return false
		elif source.mesh is BoxMesh:
			if source.instance_count<box_minimum:return false
		else:return false
		var material:Material=node.material_override if node.material_override!=null else source.mesh.surface_get_material(0)
		return material is StandardMaterial3D and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not material.grow

	func plan(buffer:PackedFloat32Array,stride:int,frame:Transform3D,mesh:Mesh)->Dictionary:
		if stride<12 or buffer.is_empty() or buffer.size()%stride!=0:return {"ok":false,"reason":"invalid_record_buffer"}
		var groups:Dictionary={};var count:int=buffer.size()/stride
		for i in count:
			var transform:Transform3D=raw_transform(buffer,i*stride);var point:Vector3=frame*transform.origin
			if not point.is_finite() or not transform.basis.is_finite():return {"ok":false,"reason":"nonfinite_transform"}
			var key:=Vector3i(floori(point.x/cluster_size.x),floori(point.y/cluster_size.y),floori(point.z/cluster_size.z))
			if not groups.has(key):groups[key]={"indices":[],"bounds":transform*mesh.get_aabb()}
			groups[key].indices.append(i);groups[key].bounds=groups[key].bounds.merge(transform*mesh.get_aabb())
		return {"ok":true,"count":count,"groups":groups,"stride":stride}

	func subset(buffer:PackedFloat32Array,stride:int,ids:Array)->PackedFloat32Array:
		var data:=PackedFloat32Array()
		for index in ids:data.append_array(buffer.slice(index*stride,(index+1)*stride))
		return data

	func exact_zero_mesh(mesh:Mesh)->Dictionary:
		var id:int=mesh.get_instance_id()
		if stripped_meshes.has(id):return stripped_meshes[id]
		var surfaces:Array=[];var removed:=0;var before:=0
		for surface in mesh.get_surface_count():
			var arrays:Array=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():for i in vertices.size():indices.append(i)
			var kept:=PackedInt32Array();var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for triangle in indices.size()/3:
				var at:int=triangle*3;var a:Vector3=vertices[indices[at]];var b:Vector3=vertices[indices[at+1]];var c:Vector3=vertices[indices[at+2]];before+=1
				# Strict zero plus an identical position/normal pair. A directional
				# normal-bias shadow transform preserves that duplicate vertex pair.
				# No epsilon and no potentially bias-expanded collinear face removal.
				var duplicate_normal:bool=(a==b and normals[indices[at]]==normals[indices[at+1]]) or (b==c and normals[indices[at+1]]==normals[indices[at+2]]) or (c==a and normals[indices[at+2]]==normals[indices[at]])
				if (b-a).cross(c-a)==Vector3.ZERO and duplicate_normal:removed+=1
				else:kept.append(indices[at]);kept.append(indices[at+1]);kept.append(indices[at+2])
			var copy:Array=arrays.duplicate();copy[Mesh.ARRAY_INDEX]=kept;surfaces.append(copy)
		var result:Mesh=mesh
		if removed>0:
			var optimized:=ArrayMesh.new()
			for surface in surfaces.size():optimized.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surfaces[surface]);optimized.surface_set_material(surface,mesh.surface_get_material(surface))
			optimized.custom_aabb=mesh.get_aabb();result=optimized
		var record:Dictionary={"mesh":result,"before":before,"removed_strict_zero":removed,"after":before-removed,"identical_position_and_normal_pair":true,"unchanged_if_no_zero":removed>0 or result==mesh}
		stripped_meshes[id]=record;return record

	func apply(cell:Node,scope:String)->Dictionary:
		var started:int=Time.get_ticks_usec();var sources:=0;var clusters:=0;var instances:=0;var zeros:=0
		for node in cell.find_children("*","MultiMeshInstance3D",true,false):
			if not eligible(node):continue
			var source:MultiMesh=node.multimesh;var stride:int=12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0);var buffer:PackedFloat32Array=source.buffer
			if buffer.size()!=source.instance_count*stride:continue
			# Native renderer must agree with raw buffer interpretation. The dummy
			# renderer returns identity transforms, so offline contracts use the data.
			if DisplayServer.get_name()!="headless" and (raw_transform(buffer,0)!=source.get_instance_transform(0) or raw_transform(buffer,(source.instance_count-1)*stride)!=source.get_instance_transform(source.instance_count-1)):continue
			var planned:Dictionary=plan(buffer,stride,node.global_transform,source.mesh)
			if not planned.ok or planned.groups.size()<2:continue
			var mesh:Mesh=source.mesh;var removed:=0
			if strip_zero_area and mesh is SphereMesh:
				var zero:Dictionary=exact_zero_mesh(mesh);mesh=zero.mesh;removed=int(zero.removed_strict_zero)
			var entry:Dictionary={"node":node,"source":source,"stride":stride,"buffer":buffer,"parts":[],"had_count":node.has_meta("stream_instances"),"old_count":node.get_meta("stream_instances",0),"source_visible":node.visible,"source_shadow":node.cast_shadow,"material":node.material_override,"mesh":mesh}
			originals.append(entry);var first:=true
			for group in planned.groups.values():
				var ids:Array=group.indices;var mm:=MultiMesh.new();mm.transform_format=source.transform_format;mm.use_colors=source.use_colors;mm.use_custom_data=source.use_custom_data;mm.mesh=mesh;mm.instance_count=ids.size();mm.buffer=subset(buffer,stride,ids)
				# Exact union of actual transformed source shapes, including every eave/
				# petal crossing a partition boundary. Never the bare 24m grid box.
				mm.custom_aabb=group.bounds
				var part:MultiMeshInstance3D=node if first else node.duplicate(0)
				part.multimesh=mm;part.set_meta("flower_cluster110",true);part.set_meta("stream_instances",ids.size())
				if not first:node.get_parent().add_child(part);created.append(part)
				entry.parts.append({"node":part,"indices":ids,"bounds":group.bounds});first=false
			sources+=1;clusters+=planned.groups.size();instances+=source.instance_count;zeros+=removed*source.instance_count
			details.append({"scope":scope,"path":str(node.get_path()),"class":source.mesh.get_class(),"instances":source.instance_count,"clusters":planned.groups.size(),"strict_zero_triangles_removed":removed*source.instance_count})
		return {"scope":scope,"source_batches":sources,"clusters":clusters,"instances_preserved":instances,"strict_zero_triangles_removed":zeros,"cpu_ms":(Time.get_ticks_usec()-started)/1000.0,"cluster_size":cluster_size}

	func verify()->Dictionary:
		var count:=0;var failures:Array=[]
		for entry in originals:
			var seen:Dictionary={};var reconstructed:=PackedFloat32Array();reconstructed.resize(entry.buffer.size())
			for part in entry.parts:
				var node:MultiMeshInstance3D=part.node;var data:PackedFloat32Array=node.multimesh.buffer
				if data.to_byte_array()!=subset(entry.buffer,entry.stride,part.indices).to_byte_array():failures.append("native_record_bytes:"+str(node.name))
				if node.multimesh.mesh!=entry.mesh or node.material_override!=entry.material or node.cast_shadow!=entry.source_shadow or node.visible!=entry.source_visible:failures.append("render_properties:"+str(node.name))
				for j in part.indices.size():
					var original:int=part.indices[j]
					if seen.has(original):failures.append("duplicate_instance")
					seen[original]=true
					for component in entry.stride:reconstructed[original*entry.stride+component]=data[j*entry.stride+component]
					var form:AABB=raw_transform(data,j*entry.stride)*entry.source.mesh.get_aabb()
					if not part.bounds.grow(.00001).encloses(form):failures.append("bounds_does_not_enclose_real_mesh")
			if seen.size()!=entry.source.instance_count or reconstructed.to_byte_array()!=entry.buffer.to_byte_array():failures.append("source_reconstruction")
			count+=seen.size()
		return {"passed":count>0 and failures.is_empty(),"compared_instances":count,"failures":failures,"scope":"exact transform/color/custom bytes, one instance once, source material/shadow/visibility, exact real-shape bounds"}

	func restore():
		for node in created:
			if is_instance_valid(node):node.get_parent().remove_child(node);node.queue_free()
		for entry in originals:
			if not is_instance_valid(entry.node):continue
			entry.node.multimesh=entry.source;entry.node.remove_meta("flower_cluster110")
			if entry.had_count:entry.node.set_meta("stream_instances",entry.old_count)
			else:entry.node.remove_meta("stream_instances")
		created.clear();originals.clear()

var m
var samples:Array=[]
var phase:=""
var last_usec:=0
var active:Candidate
var locked_camera:=Transform3D.IDENTITY
var locked_player:=Vector3.ZERO
var stage_poses:Array=[]
func _initialize():run.call_deferred()
func write_json(path:String,data:Dictionary):
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
func _process(_delta:float)->bool:
	if phase.is_empty():last_usec=0;return false
	if root.get_camera_3d()!=m.player.camera or m.watch_camera.current:push_error("Flower cluster actual player camera changed");quit(4);return true
	if not m.player.camera.global_transform.is_equal_approx(locked_camera) or m.player.global_position.distance_to(locked_player)>.00001:push_error("Flower cluster fixed world pose changed");quit(6);return true
	var now:int=Time.get_ticks_usec()
	if last_usec>0:samples.append({"phase":phase,"ms":(now-last_usec)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	last_usec=now;return false
func hold(label:String,frames:int):
	for i in 90:await process_frame
	stage_poses.append({"phase":label,"player":m.player.global_position,"camera":m.player.camera.global_transform,"yaw":m.player.yaw,"pitch":m.player.pitch,"zoom":m.player.zoom})
	phase=label;last_usec=0;write_json("res://reports/creative110_flower_cluster_progress.json",{"pid":OS.get_process_id(),"phase":label+"_sample"})
	for i in frames:await process_frame
	phase="";last_usec=0;write_json("res://reports/creative110_flower_cluster_progress.json",{"pid":OS.get_process_id(),"phase":""})
func statistics()->Dictionary:
	var groups:Dictionary={}
	for row in samples:
		if not groups.has(row.phase):groups[row.phase]={"frames":0,"ms":0.0,"gpu_ms":0.0,"cpu_ms":0.0,"draws":0.0,"primitives":0.0}
		var group:Dictionary=groups[row.phase];group.frames+=1
		for key in ["ms","gpu_ms","cpu_ms","draws","primitives"]:group[key]+=row[key]
	for group in groups.values():
		for key in ["ms","gpu_ms","cpu_ms","draws","primitives"]:group[key]/=group.frames
		group.fps=1000.0/group.ms
	return groups
func apply_loaded(candidate:Candidate)->Array:
	var results:Array=[]
	for id in m.world.streamer.loaded:results.append(candidate.apply(m.world.streamer.loaded[id],str(id)))
	return results

func offline_contract():
	var holder:=Node3D.new();root.add_child(holder)
	var candidate:=Candidate.new();var parts:Array=[]
	for id in ["-3_-2","-3_-3"]:
		var cell:Node=load("res://assets/world/stream_creative110/cell_"+id+".scn").instantiate();holder.add_child(cell);parts.append(candidate.apply(cell,id))
	var contract:Dictionary=candidate.verify();var zeros:Array=[]
	for record in candidate.stripped_meshes.values():zeros.append({"before":record.before,"after":record.after,"removed_strict_zero":record.removed_strict_zero})
	var fixture:=SphereMesh.new();fixture.radial_segments=8;fixture.rings=3
	var report:Dictionary={"scope":"CPU-only actual baked flower buffers and resource geometry; no native pixel/FPS claims","parts":parts,"details":candidate.details,"contract":contract,"sphere_exact_zero_counts":zeros,"normal_saves":"not loaded"}
	write_json("res://reports/creative110_flower_cluster_contract.json",report);print("FLOWER_CLUSTER110_CONTRACT ",JSON.stringify(report))
	candidate.restore();holder.free();quit(0 if contract.passed else 1)

func run():
	if "--native" not in OS.get_cmdline_user_args():offline_contract();return
	if DisplayServer.get_name()=="headless":push_error("Native flower clustering needs coordinated real GPU");quit(2);return
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="flower_cluster110_probe";m.store.directory="user://flower_cluster110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080))
	m.player.set_process_unhandled_input(false)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true;m.player.automated_motion=true;m.player.automated_horizontal=Vector2.ZERO;m.player.camera.make_current()
	for i in 120:await process_frame
	# Retain the same castle->station stream history as the preceding LOD control.
	m.world.streamer.set_process(false);for i in 20:await process_frame
	m.world.streamer.set_process(true);m.transport.reset_session()
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.automated_motion=false;m.player.enabled=true
	if not m.transport.board(0):push_error("Cannot board the native cable for cluster A/B");quit(5);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[m.transport.rider].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184)
	for i in 180:await process_frame
	m.world.streamer.set_process(false);m.player.camera.make_current();m.player.set_physics_process(false);locked_camera=m.player.camera.global_transform;locked_player=m.player.global_position
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	active=Candidate.new();var variant_mode:bool="--variants" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cluster-xz="):active.cluster_size.x=float(arg.trim_prefix("--cluster-xz="));active.cluster_size.z=active.cluster_size.x
	await hold("cable_original_A",180 if variant_mode else 150)
	var split:Array=[];var contract:Dictionary={};var variants:Array=[]
	var a:Image=root.get_texture().get_image()
	if variant_mode:
		for size in [12,8]:
			active.cluster_size=Vector3(size,8,size);split=apply_loaded(active);contract=active.verify()
			await hold("cable_cluster_"+str(size),240)
			variants.append({"size":active.cluster_size,"split":split,"contract":contract})
			if "--shots" in OS.get_cmdline_user_args():root.get_texture().get_image().save_png("res://screenshots/creative110/flower_cluster_cable_"+str(size)+".png")
			active.restore()
	else:
		split=apply_loaded(active);contract=active.verify();await hold("cable_cluster_B",240)
		var b:Image=root.get_texture().get_image();active.restore();await hold("cable_original_A_repeat",150);a=root.get_texture().get_image()
		if "--shots" in OS.get_cmdline_user_args():b.save_png("res://screenshots/creative110/flower_cluster_cable_B.png")
	if "--shots" in OS.get_cmdline_user_args():a.save_png("res://screenshots/creative110/flower_cluster_cable_A.png")
	# Static A/B/A comparison keeps all normal shadows and identical game content.
	var layers:Array=[];var mask:int=1<<19;var camera:Camera3D=m.player.camera;var old_mask:int=camera.cull_mask
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if not node is MeshInstance3D and not node is MultiMeshInstance3D:continue
		var material:Material=node.material_override
		if material is ShaderMaterial and material.shader!=null and "TIME" in material.shader.code:continue
		layers.append([node,node.layers]);node.layers=mask
	camera.cull_mask=mask;m.hud.hide();paused=true
	var environment:Environment=m.environment.environment;var old_background:int=environment.background_mode;environment.background_mode=Environment.BG_COLOR
	var captures:Array=[];var pixel_folder:String="res://.runtime/creative110_flower_cluster_pixels"+("_variants" if variant_mode else "");DirAccess.make_dir_recursive_absolute(pixel_folder)
	for size in ([0,12,8,0] if variant_mode else [0,int(active.cluster_size.x),0]):
		active.restore()
		if size>0:active.cluster_size=Vector3(size,8 if variant_mode else 16,size);apply_loaded(active)
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=root.get_texture().get_image();var data:PackedByteArray=image.get_data();var path:String=pixel_folder+"/"+str(captures.size())+".rgb"
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(data);file.close();var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data)
		captures.append({"path":path,"sha256":hash.finish().hex_encode(),"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"cluster_xz":size})
	active.restore();paused=false;environment.background_mode=old_background;camera.cull_mask=old_mask;m.hud.show()
	for entry in layers:entry[0].layers=entry[1]
	var report:Dictionary={"scope":"actual early native cable camera, only >=2000 Sphere8/rings3 and >=20000 plain-material Box near batches spatially partitioned; all instances/materials/shadows/settings retained","gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":root.size,"camera":m.player.camera.global_transform,"player":m.player.global_position,"shadow":m.sun.shadow_enabled,"loaded_ids":m.world.streamer.loaded.keys(),"fixed_camera_asserted_every_sample":true,"stage_poses":stage_poses,"split":split,"contract":contract,"variants":variants,"details":active.details,"pixel_captures":captures,"stages":statistics(),"normal_saves":"isolated APPDATA and user://flower_cluster110_probe"}
	write_json("res://reports/creative110_flower_cluster_probe"+("_variants" if variant_mode else "")+".json",report);print("FLOWER_CLUSTER110_RESULT ",JSON.stringify(report));m.world.streamer.shutdown();m.queue_free();await process_frame;quit(0 if contract.passed else 1)
