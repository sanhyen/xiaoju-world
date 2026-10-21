extends RefCounted
## Bake-time axis/rotated partition; runtime only selects provably hidden box-face indices.
const SCHEMA=1
const ALL_FACES=63
const AXIS_TAG="far_box_faces110_axis"
const FULL_BOX_TAG="far_box_faces110_full_box"
const BOUNDS_TAG="far_box_faces110_bounds"
const BASIS_TAG="far_box_faces110_basis"
const RECORD_HASH_TAG="far_box_faces110_record_sha256"
const RECORD_COUNT_TAG="far_box_faces110_record_count"
const PARTITION_TAG="far_box_faces110_partition"
const MARGIN=.02
const DIRECTION_EPSILON=.0000001
var entries:Array=[]
var mesh_cache:Dictionary={}
var mask_changes:=0

func positive_diagonal(basis:Basis)->bool:
	return basis.x.x>0 and basis.y.y>0 and basis.z.z>0 and basis.x.y==0 and basis.x.z==0 and basis.y.x==0 and basis.y.z==0 and basis.z.x==0 and basis.z.y==0

func unit_closed_box(box:BoxMesh)->bool:
	return box.size==Vector3.ONE and not box.flip_faces and box.subdivide_width==0 and box.subdivide_height==0 and box.subdivide_depth==0

func safe_material(node:MultiMeshInstance3D,box:BoxMesh)->bool:
	var material:Material=node.material_override if node.material_override!=null else box.material
	return node.material_overlay==null and material is StandardMaterial3D and material.next_pass==null and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.cull_mode==BaseMaterial3D.CULL_BACK and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not material.grow

func face_bit(normal:Vector3)->int:
	if normal==Vector3.RIGHT:return 1
	if normal==Vector3.LEFT:return 2
	if normal==Vector3.UP:return 4
	if normal==Vector3.DOWN:return 8
	if normal==Vector3.BACK:return 16
	if normal==Vector3.FORWARD:return 32
	return 0

func geometric_normal(bit:int)->Vector3:
	for normal in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]:
		if face_bit(normal)==bit:return normal
	return Vector3.ZERO

func triangle_face(vertices:PackedVector3Array,indices:PackedInt32Array,at:int)->int:
	# Octahedrally decoded shading normals have small nonzero components. Use exact geometry.
	var a:Vector3=vertices[indices[at]];var b:Vector3=vertices[indices[at+1]];var c:Vector3=vertices[indices[at+2]]
	for axis in 3:
		if a[axis]==b[axis] and a[axis]==c[axis]:
			if a[axis]==.5:return 1<<(axis*2)
			if a[axis]==-.5:return 2<<(axis*2)
	return 0

func face_mask(bounds:AABB,eye:Vector3,orthographic:bool,backward:Vector3)->int:
	var mask:=ALL_FACES
	for axis in 3:
		var positive:int=1<<(axis*2);var negative:int=positive<<1
		if orthographic:
			if backward[axis]>DIRECTION_EPSILON:mask&=~negative
			elif backward[axis]< -DIRECTION_EPSILON:mask&=~positive
		else:
			if eye[axis]>bounds.end[axis]+MARGIN:mask&=~negative
			elif eye[axis]<bounds.position[axis]-MARGIN:mask&=~positive
	return mask

func face_mesh(box:BoxMesh,mask:int)->Mesh:
	if mask==ALL_FACES:return box
	var key:String=str(box.get_instance_id())+":"+str(mask)
	if mesh_cache.has(key):return mesh_cache[key]
	var arrays:Array=box.get_mesh_arrays();var old:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:=PackedInt32Array()
	for triangle in old.size()/3:
		var at:int=triangle*3;var bit:int=triangle_face(vertices,old,at)
		if bit==0 or (mask&bit)!=0:indices.append(old[at]);indices.append(old[at+1]);indices.append(old[at+2])
	var copy:Array=arrays.duplicate();copy[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copy);mesh.custom_aabb=box.get_aabb()
	mesh.surface_set_material(0,box.material)
	mesh_cache[key]=mesh;return mesh

func record_hash(buffer:PackedFloat32Array)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(buffer.to_byte_array());return hash.finish().hex_encode()

func record_subset(buffer:PackedFloat32Array,stride:int,ids:Array)->PackedFloat32Array:
	var result:=PackedFloat32Array()
	for id in ids:result.append_array(buffer.slice(id*stride,(id+1)*stride))
	return result

func make_partition(source:MultiMesh,records:PackedFloat32Array,bounds:AABB)->MultiMesh:
	var stride:int=12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0)
	var part:=MultiMesh.new();part.transform_format=source.transform_format;part.use_colors=source.use_colors;part.use_custom_data=source.use_custom_data
	part.mesh=source.mesh;part.instance_count=records.size()/stride;part.buffer=records;part.custom_aabb=bounds
	return part

func mark_partition(node:MultiMeshInstance3D,records:PackedFloat32Array,count:int,kind:String):
	node.set_meta(PARTITION_TAG,kind);node.set_meta(RECORD_HASH_TAG,record_hash(records));node.set_meta(RECORD_COUNT_TAG,count)
	node.set_meta("stream_instances",count)

func count_instances(root_node:Node)->int:
	var count:=0
	for node in root_node.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh!=null:count+=node.multimesh.instance_count
	return count

func bake_partition(far_root:Node)->Dictionary:
	if int(far_root.get_meta("far_box_faces110_schema",0))==SCHEMA:
		var existing:Dictionary=far_root.get_meta("far_box_faces110_counts",{}).duplicate(true)
		existing["already_prebaked"]=true;existing["persisted_contract"]=validate_prebaked(far_root);existing["ok"]=bool(existing.persisted_contract.ok)
		return existing
	var before:int=count_instances(far_root);var started:int=Time.get_ticks_usec()
	var groups:=0;var axis_total:=0;var rotated_total:=0;var added:=0;var skipped:=0;var failures:Array=[]
	for node in far_root.find_children("*","MultiMeshInstance3D",true,false):
		if node.has_meta(PARTITION_TAG):continue
		var source:MultiMesh=node.multimesh
		if source==null or not source.mesh is BoxMesh or source.transform_format!=MultiMesh.TRANSFORM_3D:continue
		var box:BoxMesh=source.mesh
		if not unit_closed_box(box) or not safe_material(node,box) or node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or node.has_meta("stream_ref") or node.get_script()!=null or node.get_child_count()>0:skipped+=1;continue
		if source.visible_instance_count>=0 and source.visible_instance_count<source.instance_count:skipped+=1;continue
		var stride:int=12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0)
		var buffer:PackedFloat32Array=source.buffer
		if buffer.size()!=source.instance_count*stride:failures.append(str(node.name)+":missing_native_buffer");continue
		var axis:Array=[];var rotated:Array=[]
		for i in source.instance_count:
			if positive_diagonal(node.global_basis*source.get_instance_transform(i).basis):axis.append(i)
			else:rotated.append(i)
		if axis.is_empty():skipped+=1;continue
		var bounds:AABB=source.get_aabb();var axis_records:PackedFloat32Array=record_subset(buffer,stride,axis)
		node.multimesh=make_partition(source,axis_records,bounds)
		node.set_meta(AXIS_TAG,SCHEMA);node.set_meta(FULL_BOX_TAG,box);node.set_meta(BOUNDS_TAG,bounds);node.set_meta(BASIS_TAG,node.global_basis)
		mark_partition(node,axis_records,axis.size(),"axis")
		if record_hash(node.multimesh.buffer)!=record_hash(axis_records):failures.append(str(node.name)+":axis_records_changed")
		if not rotated.is_empty():
			var other:MultiMeshInstance3D=node.duplicate(0);var rotated_records:PackedFloat32Array=record_subset(buffer,stride,rotated)
			other.multimesh=make_partition(source,rotated_records,bounds)
			for tag in [AXIS_TAG,FULL_BOX_TAG,BOUNDS_TAG,BASIS_TAG]:other.remove_meta(tag)
			mark_partition(other,rotated_records,rotated.size(),"rotated")
			node.get_parent().add_child(other);added+=1
			if record_hash(other.multimesh.buffer)!=record_hash(rotated_records):failures.append(str(other.name)+":rotated_records_changed")
		groups+=1;axis_total+=axis.size();rotated_total+=rotated.size()
	var after:int=count_instances(far_root)
	if before!=after:failures.append("total_instance_count_changed")
	var report:Dictionary={"schema":SCHEMA,"ok":failures.is_empty(),"groups":groups,"axis_instances":axis_total,"rotated_instances_unchanged":rotated_total,"extra_batches":added,"skipped_batches":skipped,"instances_before":before,"instances_after":after,"native_record_contract":failures.is_empty(),"failures":failures,"cpu_ms":(Time.get_ticks_usec()-started)/1000.0,"method":"prebaked axis/rotated groups; full box attributes and original batch bounds; runtime index masks only"}
	far_root.set_meta("far_box_faces110_schema",SCHEMA);far_root.set_meta("far_box_faces110_counts",report.duplicate(true))
	return report

func validate_prebaked(far_root:Node)->Dictionary:
	var records:=0;var axis_batches:=0;var failures:Array=[]
	for node in far_root.find_children("*","MultiMeshInstance3D",true,false):
		if not node.has_meta(PARTITION_TAG):continue
		if node.multimesh==null or node.multimesh.instance_count!=int(node.get_meta(RECORD_COUNT_TAG,-1)) or record_hash(node.multimesh.buffer)!=str(node.get_meta(RECORD_HASH_TAG,"")):failures.append(str(node.name)+":persisted_records_changed")
		else:records+=node.multimesh.instance_count
		if node.has_meta(AXIS_TAG):
			axis_batches+=1
			if not node.get_meta(FULL_BOX_TAG) is BoxMesh or not unit_closed_box(node.get_meta(FULL_BOX_TAG)) or not safe_material(node,node.get_meta(FULL_BOX_TAG)) or node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:failures.append(str(node.name)+":unsafe_axis_group")
	return {"ok":failures.is_empty(),"compared_records":records,"axis_batches":axis_batches,"total_instances":count_instances(far_root),"failures":failures}

func bind(far_root:Node):
	entries.clear();mesh_cache.clear();mask_changes=0
	# Old caches stay full boxes. This scan never reads instance buffers or partitions at runtime.
	for node in far_root.find_children("*","MultiMeshInstance3D",true,false):
		if int(node.get_meta(AXIS_TAG,0))!=SCHEMA or node.multimesh==null:continue
		var box=node.get_meta(FULL_BOX_TAG,null)
		if not box is BoxMesh or not unit_closed_box(box):continue
		entries.append({"node":node,"box":box,"bounds":node.get_meta(BOUNDS_TAG,node.multimesh.get_aabb()),"basis":node.get_meta(BASIS_TAG,node.global_basis),"mask":-1,"mesh":box})

func update(camera:Camera3D):
	if camera==null:return
	var ortho:bool=camera.projection==Camera3D.PROJECTION_ORTHOGONAL
	for entry in entries:
		var node:MultiMeshInstance3D=entry.node
		if not is_instance_valid(node) or node.multimesh==null:continue
		var mask:=ALL_FACES
		if node.global_basis==entry.basis and unit_closed_box(entry.box) and safe_material(node,entry.box) and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and camera.projection in [Camera3D.PROJECTION_PERSPECTIVE,Camera3D.PROJECTION_ORTHOGONAL]:
			mask=face_mask(node.global_transform*entry.bounds,camera.global_position,ortho,camera.global_basis.z)
		if mask!=int(entry.mask):entry.mask=mask;entry.mesh=face_mesh(entry.box,mask);mask_changes+=1
		if node.multimesh.mesh!=entry.mesh:node.multimesh.mesh=entry.mesh

func diagnostics()->Dictionary:
	return {"schema":SCHEMA,"prebaked_axis_batches":entries.size(),"cached_face_meshes":mesh_cache.size(),"mask_changes":mask_changes,"runtime_partitioning":false}
