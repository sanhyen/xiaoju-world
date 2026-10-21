extends SceneTree
## Far-only, closed-box back-face index candidate. Not installed in production.
class Candidate extends RefCounted:
	const ALL_FACES=63
	var entries:Array=[]
	var created:Array=[]
	var mesh_cache:Dictionary={}
	var statistics:Dictionary={}
	var margin:=.02
	var direction_epsilon:=.0000001

	func positive_diagonal(basis:Basis)->bool:
		return basis.x.x>0 and basis.y.y>0 and basis.z.z>0 and basis.x.y==0 and basis.x.z==0 and basis.y.x==0 and basis.y.z==0 and basis.z.x==0 and basis.z.y==0

	func face_bit(normal:Vector3)->int:
		if normal==Vector3.RIGHT:return 1
		if normal==Vector3.LEFT:return 2
		if normal==Vector3.UP:return 4
		if normal==Vector3.DOWN:return 8
		if normal==Vector3.BACK:return 16
		if normal==Vector3.FORWARD:return 32
		return 0

	func triangle_face(vertices:PackedVector3Array,indices:PackedInt32Array,at:int)->int:
		# Decode geometry, not compressed shading normals (their zero components can drift ~1e-5).
		var a:Vector3=vertices[indices[at]];var b:Vector3=vertices[indices[at+1]];var c:Vector3=vertices[indices[at+2]]
		for axis in 3:
			if a[axis]==b[axis] and a[axis]==c[axis]:
				if a[axis]==.5:return 1<<(axis*2)
				if a[axis]==-.5:return 2<<(axis*2)
		return 0

	func geometric_normal(bit:int)->Vector3:
		for normal in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]:
			if face_bit(normal)==bit:return normal
		return Vector3.ZERO

	func face_mask(bounds:AABB,eye:Vector3,orthographic:bool,backward:Vector3)->int:
		var mask:=ALL_FACES
		for axis in 3:
			var positive:int=1<<(axis*2);var negative:int=positive<<1
			if orthographic:
				if backward[axis]>direction_epsilon:mask&=~negative
				elif backward[axis]< -direction_epsilon:mask&=~positive
			else:
				if eye[axis]>bounds.end[axis]+margin:mask&=~negative
				elif eye[axis]<bounds.position[axis]-margin:mask&=~positive
		return mask

	func face_mesh(box:BoxMesh,mask:int)->Mesh:
		if mask==ALL_FACES:return box
		var key:String=str(box.get_instance_id())+":"+str(mask)
		if mesh_cache.has(key):return mesh_cache[key]
		var arrays:Array=box.get_mesh_arrays();var source:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:=PackedInt32Array()
		for triangle in source.size()/3:
			var at:int=triangle*3;var bit:int=triangle_face(vertices,source,at)
			if bit==0 or (mask&bit)!=0:
				indices.append(source[at]);indices.append(source[at+1]);indices.append(source[at+2])
		var copy:Array=arrays.duplicate();copy[Mesh.ARRAY_INDEX]=indices
		var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copy);result.custom_aabb=box.get_aabb()
		mesh_cache[key]=result;return result

	func safe_material(node:MultiMeshInstance3D,box:BoxMesh)->bool:
		var material:Material=node.material_override if node.material_override!=null else box.material
		return material is StandardMaterial3D and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.cull_mode==BaseMaterial3D.CULL_BACK and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not material.grow

	func subset(source:MultiMesh,buffer:PackedFloat32Array,stride:int,ids:Array)->MultiMesh:
		var data:=PackedFloat32Array()
		for id in ids:data.append_array(buffer.slice(id*stride,(id+1)*stride))
		var result:=MultiMesh.new();result.transform_format=source.transform_format;result.use_colors=source.use_colors;result.use_custom_data=source.use_custom_data
		result.mesh=source.mesh;result.instance_count=ids.size();result.buffer=data
		# Retain the full original batch bounds, including the rotated group, for identical culling.
		result.custom_aabb=source.get_aabb();return result

	func install(far_root:Node,camera:Camera3D)->Dictionary:
		var start:int=Time.get_ticks_usec();var axis_total:=0;var rotated_total:=0;var skipped:=0
		for node in far_root.find_children("*","MultiMeshInstance3D",true,false):
			var source:MultiMesh=node.multimesh
			if source==null or not source.mesh is BoxMesh or source.transform_format!=MultiMesh.TRANSFORM_3D:continue
			var box:BoxMesh=source.mesh
			if box.size!=Vector3.ONE or box.flip_faces or box.subdivide_width!=0 or box.subdivide_height!=0 or box.subdivide_depth!=0 or node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not safe_material(node,box):skipped+=1;continue
			if source.visible_instance_count>=0 and source.visible_instance_count<source.instance_count:skipped+=1;continue
			var stride:int=12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0)
			var buffer:PackedFloat32Array=source.buffer
			if buffer.size()!=source.instance_count*stride:skipped+=1;continue
			var axis:Array=[];var rotated:Array=[]
			for i in source.instance_count:
				if positive_diagonal(node.global_basis*source.get_instance_transform(i).basis):axis.append(i)
				else:rotated.append(i)
			if axis.is_empty():skipped+=1;continue
			var bounds:AABB=node.global_transform*source.get_aabb()
			var state:Dictionary={"node":node,"source":source,"axis":axis,"rotated":rotated,"stride":stride,"bounds":bounds,"mask":-1,"rotated_node":null}
			node.multimesh=subset(source,buffer,stride,axis)
			if not rotated.is_empty():
				var other:MultiMeshInstance3D=node.duplicate(0);other.multimesh=subset(source,buffer,stride,rotated)
				node.get_parent().add_child(other);state.rotated_node=other;created.append(other)
			entries.append(state);axis_total+=axis.size();rotated_total+=rotated.size()
		update(camera)
		statistics={"groups":entries.size(),"axis_instances":axis_total,"rotated_instances_unchanged":rotated_total,"extra_batches":created.size(),"skipped_batches":skipped,"split_cpu_ms":(Time.get_ticks_usec()-start)/1000.0}
		return statistics

	func update(camera:Camera3D):
		var orthographic:bool=camera.projection==Camera3D.PROJECTION_ORTHOGONAL
		for entry in entries:
			var node:MultiMeshInstance3D=entry.node
			var mask:int=face_mask(entry.bounds,camera.global_position,orthographic,camera.global_basis.z)
			if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or camera.projection not in [Camera3D.PROJECTION_PERSPECTIVE,Camera3D.PROJECTION_ORTHOGONAL]:mask=ALL_FACES
			if mask==int(entry.mask):continue
			entry.mask=mask;node.multimesh.mesh=face_mesh(entry.source.mesh,mask)

	func verify_native()->Dictionary:
		var compared:=0;var failures:Array=[]
		for entry in entries:
			var original:PackedFloat32Array=entry.source.buffer
			for pair in [[entry.node,entry.axis],[entry.rotated_node,entry.rotated]]:
				if pair[1].is_empty():continue
				var expected:=PackedFloat32Array()
				for id in pair[1]:expected.append_array(original.slice(id*entry.stride,(id+1)*entry.stride))
				if pair[0].multimesh.buffer.to_byte_array()!=expected.to_byte_array():failures.append(str(pair[0].name))
				compared+=pair[0].multimesh.instance_count
		return {"passed":compared>0 and failures.is_empty(),"compared_records":compared,"failures":failures,"cached_face_meshes":mesh_cache.size()}

	func uninstall():
		for node in created:
			if is_instance_valid(node):node.get_parent().remove_child(node);node.queue_free()
		for entry in entries:
			if is_instance_valid(entry.node):entry.node.multimesh=entry.source
		created.clear();entries.clear()

func _initialize():run.call_deferred()

func run():
	var candidate:=Candidate.new();var box:=BoxMesh.new();box.size=Vector3.ONE
	var arrays:Array=box.get_mesh_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var bounds:=AABB(Vector3(-16,-8,-16),Vector3(32,16,32));var all_faces_safe:=true;var visible_unchanged:=true;var tested:=0;var failures:Array=[]
	var instances:Array=[Transform3D(Basis.IDENTITY.scaled(Vector3(.8,2,1)),Vector3(-12,-5,-10)),Transform3D(Basis.IDENTITY.scaled(Vector3(2,.25,3)),Vector3(7,4,8)),Transform3D.IDENTITY]
	for orthographic in [false,true]:
		for eye in [Vector3(40,30,50),Vector3(-40,30,-50),Vector3(0,40,0),Vector3.ZERO,Vector3(16.01,0,0)]:
			var backward:Vector3=eye.normalized()
			var mask:int=candidate.face_mask(bounds,eye,orthographic,backward)
			for transform in instances:
				for triangle in indices.size()/3:
					var at:int=triangle*3;var bit:int=candidate.triangle_face(vertices,indices,at)
					var normal:Vector3=(transform.basis.inverse().transposed()*candidate.geometric_normal(bit)).normalized()
					var facing:float=normal.dot(backward if orthographic else eye-transform*vertices[indices[at]])
					var removed:bool=bit!=0 and (mask&bit)==0
					if removed and facing>=0 and failures.size()<8:failures.append({"ortho":orthographic,"eye":eye,"mask":mask,"normal":normal,"source_normal":normals[indices[at]],"vertex":transform*vertices[indices[at]],"facing":facing})
					all_faces_safe=all_faces_safe and (not removed or facing<0)
					visible_unchanged=visible_unchanged and (facing<0 or not removed);tested+=1
	var unchanged_attributes:=true
	for mask in [63,21,42,23,47]:
		var mesh:Mesh=candidate.face_mesh(box,mask)
		var result:Array=mesh.surface_get_arrays(0)
		for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV]:unchanged_attributes=unchanged_attributes and result[attribute]==arrays[attribute]
	var checks:Array=[
		{"test":"removed_triangles_are_strict_backfaces_for_all_instances","passed":all_faces_safe,"tested_triangles":tested},
		{"test":"all_original_frontfacing_triangles_retained","passed":visible_unchanged},
		{"test":"full_vertex_normal_tangent_uv_attributes_unchanged","passed":unchanged_attributes},
		{"test":"inside_eye_keeps_all_faces","passed":candidate.face_mask(bounds,Vector3.ZERO,false,Vector3.ZERO)==63},
		{"test":"zero_orthographic_components_keep_both_axis_faces","passed":(candidate.face_mask(bounds,Vector3.ZERO,true,Vector3.UP)&51)==51},
		{"test":"rotation_negative_scale_and_shear_rejected","passed":not candidate.positive_diagonal(Basis(Vector3.UP,.2)) and not candidate.positive_diagonal(Basis.IDENTITY.scaled(Vector3(-1,1,1))) and not candidate.positive_diagonal(Basis(Vector3(1,.01,0),Vector3.UP,Vector3.BACK))}
	]
	var report:Dictionary={"scope":"CPU geometry proof only; no GPU/production changes","checks":checks,"failures":failures,"margin_m":candidate.margin,"ortho_direction_epsilon":candidate.direction_epsilon}
	var file:=FileAccess.open("res://reports/creative110_box_faces_contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOX_FACES_CONTRACT110 ",JSON.stringify(report));quit(0 if checks.all(func(check):return check.passed) else 1)
