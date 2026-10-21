extends SceneTree
## Isolated A/B/A experiment. Source geometry, settings and normal saves are unchanged.
const EDGE_INSET=.02
const DEPTH_INSET=.01
var m
var samples:Array=[]
var phase:=""
var last_usec:=0
var measure:=false
var builder

class ConservativeOccluders extends RefCounted:
	var stats:Dictionary={"terrain_sources":0,"terrain_triangles":0,"wall_boxes":0,"wall_triangles":0,"occluder_nodes":0,"rejected_materials":0,"unmatched_boxes":0}
	var walls:Array=[]
	var all_nodes:Array=[]
	var unit_box:=BoxMesh.new()
	func _init():unit_box.size=Vector3.ONE
	func material_at(node:GeometryInstance3D,mesh:Mesh,surface:int)->Material:
		if node.material_override!=null:return node.material_override
		if node is MeshInstance3D:
			var material:Material=node.get_surface_override_material(surface)
			if material!=null:return material
		return mesh.surface_get_material(surface)
	func opaque(material:Material,terrain:bool=false)->bool:
		if material is BaseMaterial3D:return material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a>=.999
		if material is ShaderMaterial and material.shader!=null:
			var path:String=material.shader.resource_path.get_file()
			# These two project shaders write no ALPHA, discard or vertex displacement.
			return path=="terrain_strata.gdshader" if terrain else path=="voxel_surface.gdshader"
		return false
	func key(point:Vector3)->Vector3i:return Vector3i(roundi(point.x*100),roundi(point.y*100),roundi(point.z*100))
	func collision_index(cell:Node3D)->Dictionary:
		var result:Dictionary={}
		for node in cell.find_children("*","CollisionShape3D",true,false):
			if not node.shape is BoxShape3D:continue
			var xf:Transform3D=node.global_transform;xf.basis=xf.basis.scaled_local(node.shape.size)
			var at:Vector3i=key(xf.origin)
			if not result.has(at):result[at]=[]
			result[at].append(xf)
		return result
	func matched(xf:Transform3D,index:Dictionary)->bool:
		for actual in index.get(key(xf.origin),[]):
			if xf.origin.distance_to(actual.origin)>.006:continue
			if xf.basis.x.distance_to(actual.basis.x)<.006 and xf.basis.y.distance_to(actual.basis.y)<.006 and xf.basis.z.distance_to(actual.basis.z)<.006:return true
		return false
	func wall_shape(xf:Transform3D)->bool:
		var size:Vector3=xf.basis.get_scale().abs()
		return absf(xf.basis.y.normalized().y)>.999 and size.y>=1.25 and minf(size.x,size.z)>=.18 and minf(size.x,size.z)<=1.1 and maxf(size.x,size.z)>=3.0
	func add_triangle(vertices:PackedVector3Array,indices:PackedInt32Array,a:Vector3,c:Vector3,d:Vector3):
		var begin:int=vertices.size();vertices.append(a);vertices.append(c);vertices.append(d)
		indices.append(begin);indices.append(begin+1);indices.append(begin+2)
	func inset_triangle(a:Vector3,c:Vector3,d:Vector3)->PackedVector3Array:
		var area_twice:float=(c-a).cross(d-a).length()
		var ab:float=a.distance_to(c);var bc:float=c.distance_to(d);var ca:float=d.distance_to(a);var perimeter:float=ab+bc+ca
		if area_twice<.5 or perimeter<.001:return PackedVector3Array()
		var radius:float=area_twice/perimeter
		if radius<=.03:return PackedVector3Array()
		var center:Vector3=(a*bc+c*ca+d*ab)/perimeter
		var shrink:float=maxf(0.0,1.0-EDGE_INSET/radius)
		var normal:Vector3=(d-a).cross(c-a).normalized()
		return PackedVector3Array([center+(a-center)*shrink-normal*DEPTH_INSET,center+(c-center)*shrink-normal*DEPTH_INSET,center+(d-center)*shrink-normal*DEPTH_INSET])
	func install(host:Node3D,vertices:PackedVector3Array,indices:PackedInt32Array,kind:String):
		if indices.is_empty():return
		var resource:=ArrayOccluder3D.new();resource.set_arrays(vertices,indices)
		var node:=OccluderInstance3D.new();node.name="ConservativeOcclusion110_"+kind;node.occluder=resource;node.bake_mask=0
		host.add_child(node);node.set_meta("occlusion110_source",kind);all_nodes.append(node)
		if kind=="solid_wall":walls.append(node)
		stats.occluder_nodes+=1
	func terrain(host:MeshInstance3D):
		var mesh:Mesh=host.mesh;var inverse:Transform3D=host.global_transform.affine_inverse();var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
		for surface in mesh.get_surface_count():
			if not opaque(material_at(host,mesh,surface),true):stats.rejected_materials+=1;continue
			if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:continue
			var arrays:Array=mesh.surface_get_arrays(surface);var source:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var order:Variant=arrays[Mesh.ARRAY_INDEX]
			var indexed:bool=order is PackedInt32Array and not order.is_empty();var count:int=order.size() if indexed else source.size()
			for i in range(0,count-2,3):
				var a:Vector3=host.global_transform*source[int(order[i]) if indexed else i]
				var c:Vector3=host.global_transform*source[int(order[i+1]) if indexed else i+1]
				var d:Vector3=host.global_transform*source[int(order[i+2]) if indexed else i+2]
				# Submerged seabed is unnecessary for the above-water performance experiment.
				if minf(a.y,minf(c.y,d.y))< -2.32:continue
				var inset:PackedVector3Array=inset_triangle(a,c,d)
				if inset.is_empty():continue
				add_triangle(vertices,indices,inverse*inset[0],inverse*inset[1],inverse*inset[2]);stats.terrain_triangles+=1
		if not indices.is_empty():stats.terrain_sources+=1;install(host,vertices,indices,"terrain")
	func append_box(host:Node3D,xf:Transform3D,vertices:PackedVector3Array,indices:PackedInt32Array):
		var size:Vector3=xf.basis.get_scale().abs()-Vector3.ONE*(EDGE_INSET*2)
		if minf(size.x,minf(size.y,size.z))<=.02:return
		var basis:=Basis(xf.basis.x.normalized(),xf.basis.y.normalized(),xf.basis.z.normalized()).scaled_local(size)
		var frame:Transform3D=host.global_transform.affine_inverse()*Transform3D(basis,xf.origin)
		var faces:PackedVector3Array=unit_box.get_faces()
		for i in range(0,faces.size(),3):
			if frame.basis.determinant()<0:add_triangle(vertices,indices,frame*faces[i],frame*faces[i+2],frame*faces[i+1])
			else:add_triangle(vertices,indices,frame*faces[i],frame*faces[i+1],frame*faces[i+2])
		stats.wall_boxes+=1;stats.wall_triangles+=faces.size()/3
	func solid_walls(host:GeometryInstance3D,index:Dictionary):
		var mesh:Mesh=host.mesh if host is MeshInstance3D else host.multimesh.mesh
		if not mesh is BoxMesh or not opaque(material_at(host,mesh,0)):return
		var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
		var count:int=host.multimesh.instance_count if host is MultiMeshInstance3D else 1
		for i in count:
			var xf:Transform3D=host.global_transform
			if host is MultiMeshInstance3D:xf=xf*host.multimesh.get_instance_transform(i)
			xf.basis=xf.basis.scaled_local(mesh.size)
			if not wall_shape(xf):continue
			if not matched(xf,index):stats.unmatched_boxes+=1;continue
			append_box(host,xf,vertices,indices)
		install(host,vertices,indices,"solid_wall")
	func build_cell(cell:Node3D,with_walls:bool):
		var index:Dictionary=collision_index(cell) if with_walls else {}
		var sources:Array=cell.find_children("*","GeometryInstance3D",true,false)
		for node in sources:
			if node is MeshInstance3D and node.mesh!=null and node.has_meta("stream_terrain"):terrain(node)
			elif with_walls and (node is MeshInstance3D or node is MultiMeshInstance3D):
				if node is MeshInstance3D and node.mesh==null:continue
				if node is MultiMeshInstance3D and (node.multimesh==null or node.multimesh.mesh==null):continue
				solid_walls(node,index)
	func suppress_cutaway_walls(active:bool):
		# Cutaway can zero individual MultiMesh transforms without hiding their node.
		# Parent visibility alone is insufficient in that case, so walls fail open.
		for node in walls:
			if is_instance_valid(node):node.visible=not active

func _initialize():run.call_deferred()

func write_json(path:String,data:Dictionary):
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()

func progress(value:String):
	phase=value;last_usec=0
	write_json("res://reports/creative110_occlusion_probe_progress.json",{"pid":OS.get_process_id(),"phase":value+"_sample" if not value.is_empty() else ""})

func _process(_delta:float)->bool:
	if phase.is_empty():last_usec=0;return false
	var now:int=Time.get_ticks_usec()
	if last_usec>0:
		var rid:RID=root.get_viewport_rid()
		samples.append({"phase":phase,"ms":(now-last_usec)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid) if measure else -1,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid) if measure else -1,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	last_usec=now;return false

func hold(value:String,count:int):
	for i in 24:await process_frame
	progress(value)
	for i in count:await process_frame
	progress("")

func statistics()->Dictionary:
	var result:Dictionary={}
	for sample in samples:
		if not result.has(sample.phase):result[sample.phase]={"frames":0,"ms":0.0,"gpu_ms":0.0,"render_cpu_ms":0.0,"draws":0.0,"objects":0.0,"primitives":0.0,"times":[]}
		var group:Dictionary=result[sample.phase];group.frames+=1;group.times.append(sample.ms)
		for field in ["ms","gpu_ms","render_cpu_ms","draws","objects","primitives"]:group[field]+=float(sample[field])
	for group in result.values():
		for field in ["ms","gpu_ms","render_cpu_ms","draws","objects","primitives"]:group[field]/=group.frames
		group.times.sort();group.p95_ms=group.times[mini(group.times.size()-1,int(group.times.size()*.95))];group.fps=1000.0/group.ms;group.erase("times")
	return result

func self_test():
	var helper:=ConservativeOccluders.new();var a:=Vector3(0,0,0);var c:=Vector3(2,0,0);var d:=Vector3(0,0,2)
	var inset:PackedVector3Array=helper.inset_triangle(a,c,d);var okay:bool=inset.size()==3
	for point in inset:okay=okay and point.x>0 and point.z>0 and point.x+point.z<2 and absf(point.y+DEPTH_INSET)<.00001
	var glass:=StandardMaterial3D.new();glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color=Color(1,1,1,.12)
	var solid:=StandardMaterial3D.new();okay=okay and not helper.opaque(glass) and helper.opaque(solid)
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array();helper.add_triangle(vertices,indices,Vector3.ZERO,Vector3.RIGHT,Vector3.BACK)
	var resource:=ArrayOccluder3D.new();resource.set_arrays(vertices,indices);okay=okay and resource.get_vertices().size()==3 and resource.get_indices().size()==3
	print("OCCLUSION110_SELFTEST ",JSON.stringify({"passed":okay,"inset_vertices":inset,"vertices":resource.get_vertices().size(),"indices":resource.get_indices().size(),"transparent_rejected":not helper.opaque(glass)}));quit(0 if okay else 1)

func run():
	if "--self-test" in OS.get_cmdline_user_args():self_test();return
	if DisplayServer.get_name()=="headless":push_error("The performance probe requires the real renderer; only --self-test is headless.");quit(2);return
	# Unknown nonempty QA names launch the legacy screenshot tour in Main._ready.
	# Complete _ready without one, then select isolated probe behavior explicitly.
	m=load("res://scenes/world/main.tscn").instantiate();m.qa_mode="";root.add_child(m)
	m.qa_mode="occlusion110_probe";m.store.directory="user://occlusion110_probe";m.store.import_directory=""
	DisplayServer.window_set_size(Vector2i(1920,1080))
	await m.start_game(false)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1);m.player.enabled=true;m.player.yaw=deg_to_rad(225);m.player.pitch=-.2;m.player.zoom=6
	m.player.automated_motion=true;m.player.automated_horizontal=Vector2.ZERO
	m.player.camera.make_current()
	for i in 40:await process_frame
	if root.get_camera_3d()!=m.player.camera:push_error("Probe camera is not the actual player camera.");quit(3);return
	# Freeze the exact scene, shader time and animation state for pixel-comparable A/B/A.
	var old_scale:float=Engine.time_scale;var old_mode:int=m.process_mode;var old_occlusion:bool=root.use_occlusion_culling
	m.process_mode=Node.PROCESS_MODE_DISABLED;Engine.time_scale=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);measure=true
	root.use_occlusion_culling=false
	await hold("baseline_A",100)
	var before:Image=root.get_texture().get_image()
	builder=ConservativeOccluders.new();var started:int=Time.get_ticks_usec()
	for cell in m.world.streamer.loaded.values():builder.build_cell(cell,true)
	# Far cells contain their own real lower-detail terrain; never use invented hill envelopes.
	for cell in m.world.streamer.far_cells.values():builder.build_cell(cell,false)
	builder.suppress_cutaway_walls(not m.world.observation_key.is_empty())
	var build_ms:float=(Time.get_ticks_usec()-started)/1000.0
	root.use_occlusion_culling=true
	await hold("occlusion_B",150)
	var occluded:Image=root.get_texture().get_image()
	root.use_occlusion_culling=false
	await hold("baseline_A_repeat",100)
	var repeat:Image=root.get_texture().get_image()
	var difference_ab:float=before.compute_image_metrics(occluded,false).get("root_mean_squared",-1.0)
	var difference_aa:float=before.compute_image_metrics(repeat,false).get("root_mean_squared",-1.0)
	if "--shots" in OS.get_cmdline_user_args():
		before.save_png("res://screenshots/creative110/occlusion_A.png");occluded.save_png("res://screenshots/creative110/occlusion_B.png");repeat.save_png("res://screenshots/creative110/occlusion_A_repeat.png")
	var report:Dictionary={"pid":OS.get_process_id(),"scope":"one frozen castle end view; A/B/A exact same content, shadows, camera and 1080p; not full-world gameplay acceptance","viewport":root.size,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"position":m.player.position,"camera":[m.player.yaw,m.player.pitch,m.player.zoom],"actual_camera_position":root.get_camera_3d().global_position,"player_camera_verified":root.get_camera_3d()==m.player.camera,"build_ms":build_ms,"occluders":builder.stats,"stages":statistics(),"pixel_rmse_AB":difference_ab,"pixel_rmse_AA":difference_aa,"samples":samples,"normal_saves":"isolated APPDATA and separate user://occlusion110_probe"}
	write_json("res://reports/creative110_occlusion_probe.json",report)
	print("OCCLUSION110_RESULT ",JSON.stringify({"stages":report.stages,"occluders":builder.stats,"build_ms":build_ms,"pixel_rmse_AB":difference_ab,"pixel_rmse_AA":difference_aa}))
	root.use_occlusion_culling=old_occlusion;Engine.time_scale=old_scale;m.process_mode=old_mode
	m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
