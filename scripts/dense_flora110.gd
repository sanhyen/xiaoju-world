extends RefCounted
## Bake-time only. The original three giant flower batches retain every native record.
const SCHEMA=1
const PREFIX="dense_flora110_"
const TARGET_CELLS=["-3_-2","-3_-3"]
const CLUSTER_SIZE=Vector3(24,16,24)
const SPHERE_MINIMUM=2000
const BOX_MINIMUM=20000
var resource_audit_cache:Dictionary={}

func digest(value:Variant)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	hash.update(value if value is PackedByteArray else var_to_bytes(value))
	return hash.finish().hex_encode()

func raw_transform(data:PackedFloat32Array,at:int)->Transform3D:
	return Transform3D(Basis(Vector3(data[at],data[at+4],data[at+8]),Vector3(data[at+1],data[at+5],data[at+9]),Vector3(data[at+2],data[at+6],data[at+10])),Vector3(data[at+3],data[at+7],data[at+11]))

func stable_value(value:Variant)->Variant:
	if value is Resource:
		var id:int=value.get_instance_id()
		if resource_audit_cache.has(id):return resource_audit_cache[id]
		if not value.resource_path.is_empty() and not "::" in value.resource_path:
			var external:Array=[value.get_class(),value.resource_path];resource_audit_cache[id]=external;return external
		resource_audit_cache[id]=[value.get_class(),"recursive_reference"]
		var properties:Array=[]
		for item in value.get_property_list():
			if (int(item.usage)&PROPERTY_USAGE_STORAGE)!=0 and not str(item.name) in ["resource_path","resource_scene_unique_id"]:properties.append([str(item.name),stable_value(value.get(item.name))])
		properties.sort_custom(func(a,b):return a[0]<b[0])
		var result:Array=[value.get_class(),digest(properties)];resource_audit_cache[id]=result;return result
	if value is Dictionary:
		var keys:Array=value.keys();keys.sort_custom(func(a,b):return str(a)<str(b));var result:Array=[]
		for key in keys:result.append([stable_value(key),stable_value(value[key])])
		return result
	if value is Array:
		var result:Array=[]
		for item in value:result.append(stable_value(item))
		return result
	if value is RID:return "RID_is_not_persisted_state"
	if value is Object:return value.get_class()
	return value

func original_meta(node:Node)->Dictionary:
	var meta:Dictionary={}
	for key in node.get_meta_list():
		if not str(key).begins_with(PREFIX):meta[str(key)]=node.get_meta(key)
	return meta

func protected_state(cell:Node)->Dictionary:
	resource_audit_cache.clear();var records:Array=[];var labels:=0;var shapes:=0;var bodies:=0
	var nodes:Array=[cell];nodes.append_array(cell.find_children("*","",true,false))
	for node in nodes:
		# Only added render-cluster nodes are excluded. The original node and all
		# its original metadata remain part of this conservation signature.
		if int(node.get_meta(PREFIX+"part_index",0))>0:continue
		var row:Dictionary={"path":str(cell.get_path_to(node)),"class":node.get_class(),"metadata":stable_value(original_meta(node)),"process_mode":node.process_mode}
		if node is Node3D:row.transform=node.transform;row.visible=node.visible
		if node is CollisionObject3D:row.layer=node.collision_layer;row.mask=node.collision_mask;bodies+=1
		if node is CollisionShape3D:
			row.shape=stable_value(node.shape);row.disabled=node.disabled;shapes+=1
		if node is Label3D:
			var properties:Dictionary={}
			for item in node.get_property_list():
				if (int(item.usage)&PROPERTY_USAGE_STORAGE)!=0 and not str(item.name) in ["owner","unique_name_in_owner"]:properties[str(item.name)]=stable_value(node.get(item.name))
			row.label_properties=stable_value(properties);labels+=1
		records.append(row)
	records.sort_custom(func(a,b):return a.path<b.path)
	return {"sha256":digest(stable_value(records)),"original_nodes":records.size(),"labels":labels,"collision_shapes":shapes,"physics_objects":bodies}

func eligible(node:MultiMeshInstance3D)->bool:
	var source:MultiMesh=node.multimesh
	if source==null or source.transform_format!=MultiMesh.TRANSFORM_3D or node.has_meta(PREFIX+"group"):return false
	if node.has_meta("stream_ref") or node.get_child_count()>0 or node.get_script()!=null:return false
	if source.visible_instance_count>=0 and source.visible_instance_count<source.instance_count:return false
	if source.mesh is SphereMesh:
		if source.instance_count<SPHERE_MINIMUM or source.mesh.radial_segments!=8 or source.mesh.rings!=3:return false
	elif source.mesh is BoxMesh:
		if source.instance_count<BOX_MINIMUM:return false
	else:return false
	var material:Material=node.material_override if node.material_override!=null else source.mesh.surface_get_material(0)
	return node.material_overlay==null and material is StandardMaterial3D and material.next_pass==null and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.cull_mode==BaseMaterial3D.CULL_BACK and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not material.grow

func attribute_streams(mesh:Mesh)->Dictionary:
	# Compare actual submitted vertex/attribute bytes, not a tolerance on normals
	# returned after Godot's packed-attribute decoding. Indices are the sole change.
	var surfaces:Array=[]
	for index in mesh.get_surface_count():
		var surface:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),index)
		if not surface.has("vertex_data"):return {"ok":false,"reason":"renderer_surface_data_unavailable"}
		var row:Dictionary={"format":surface.get("format",0),"vertex_count":surface.get("vertex_count",0)}
		for key in ["vertex_data","attribute_data","skin_data","blend_shape_data"]:
			if surface.has(key):row[key]=digest(surface[key])
		surfaces.append(row)
	return {"ok":true,"surfaces":surfaces,"sha256":digest(surfaces)}

func exact_pole_mesh(mesh:SphereMesh)->Dictionary:
	var output:=ArrayMesh.new();var surfaces:Array=[];var before:=0;var removed:=0
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var source:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if source.is_empty():return {"ok":false,"reason":"unexpected_nonindexed_sphere"}
		# ArrayMesh's native storage property accepts the renderer's exact surface
		# data. Retain every vertex/attribute byte; copy only surviving index bytes.
		# Decoding and re-encoding octahedral normals is deliberately avoided.
		var raw:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface).duplicate(true)
		var old_indices:PackedByteArray=raw.index_data;var index_width:int=old_indices.size()/int(raw.index_count)
		if index_width not in [2,4]:return {"ok":false,"reason":"unexpected_native_index_width"}
		var kept_bytes:=PackedByteArray();var kept_count:=0
		for triangle in source.size()/3:
			var at:int=triangle*3;var a:Vector3=vertices[source[at]];var b:Vector3=vertices[source[at+1]];var c:Vector3=vertices[source[at+2]];before+=1
			var duplicate:bool=(a==b and normals[source[at]]==normals[source[at+1]]) or (b==c and normals[source[at+1]]==normals[source[at+2]]) or (c==a and normals[source[at+2]]==normals[source[at]])
			if duplicate and (b-a).cross(c-a)==Vector3.ZERO:removed+=1
			else:kept_bytes.append_array(old_indices.slice(at*index_width,(at+3)*index_width));kept_count+=3
		raw.index_data=kept_bytes;raw.index_count=kept_count
		if mesh.surface_get_material(surface)!=null:raw.material=mesh.surface_get_material(surface)
		surfaces.append(raw)
	output.set("_surfaces",surfaces)
	output.custom_aabb=mesh.get_aabb()
	var original_attributes:Dictionary=attribute_streams(mesh);var optimized_attributes:Dictionary=attribute_streams(output)
	if not original_attributes.ok or not optimized_attributes.ok or original_attributes.sha256!=optimized_attributes.sha256:return {"ok":false,"reason":"sphere_vertex_attribute_stream_changed","source":original_attributes,"result":optimized_attributes}
	return {"ok":true,"mesh":output,"source_triangles":before,"removed":removed,"result_triangles":before-removed,"vertex_attribute_sha256":original_attributes.sha256,"normal_bias_proof":"Every removed face has strictly zero area and a duplicate position+normal vertex pair; normal-bias shadow displacement preserves that pair."}

func partition_plan(source:MultiMesh,frame:Transform3D)->Dictionary:
	var stride:int=12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0);var buffer:PackedFloat32Array=source.buffer
	if buffer.size()!=source.instance_count*stride:return {"ok":false,"reason":"missing_native_records"}
	if raw_transform(buffer,0)!=source.get_instance_transform(0) or raw_transform(buffer,(source.instance_count-1)*stride)!=source.get_instance_transform(source.instance_count-1):return {"ok":false,"reason":"native_record_format_disagrees"}
	var groups:Dictionary={}
	for index in source.instance_count:
		var transform:Transform3D=raw_transform(buffer,index*stride);var point:Vector3=frame*transform.origin
		if not point.is_finite() or not transform.basis.is_finite():return {"ok":false,"reason":"nonfinite_record"}
		var key:=Vector3i(floori(point.x/CLUSTER_SIZE.x),floori(point.y/CLUSTER_SIZE.y),floori(point.z/CLUSTER_SIZE.z));var bounds:AABB=transform*source.mesh.get_aabb()
		if not groups.has(key):groups[key]={"indices":[],"bounds":bounds}
		groups[key].indices.append(index);groups[key].bounds=groups[key].bounds.merge(bounds)
	return {"ok":true,"stride":stride,"buffer":buffer,"groups":groups}

func record_subset(buffer:PackedFloat32Array,stride:int,ids:Array)->PackedFloat32Array:
	var result:=PackedFloat32Array()
	for index in ids:result.append_array(buffer.slice(index*stride,(index+1)*stride))
	return result

func bake_cell(cell:Node3D,id:String)->Dictionary:
	if DisplayServer.get_name()=="headless":return {"ok":false,"reason":"real_renderer_required_for_bake"}
	if int(cell.get_meta(PREFIX+"schema",0))==SCHEMA:
		var existing:Dictionary=cell.get_meta(PREFIX+"counts",{}).duplicate(true);existing.already_prebaked=true;existing.persisted_contract=validate_prebaked(cell);existing.ok=existing.persisted_contract.ok;return existing
	if not id in TARGET_CELLS:return {"ok":true,"skipped":true,"cell":id}
	var before:Dictionary=protected_state(cell);var sources:Array=[];var groups_added:=0;var instances:=0;var removed_triangles:=0;var raw_triangles:=0;var result_triangles:=0;var started:int=Time.get_ticks_usec()
	for node in cell.find_children("*","MultiMeshInstance3D",true,false):
		if not eligible(node):continue
		var source:MultiMesh=node.multimesh;var plan:Dictionary=partition_plan(source,node.global_transform)
		if not plan.ok:return plan
		var mesh:Mesh=source.mesh;var original_triangles:int=mesh.get_faces().size()/3;var after_triangles:int=original_triangles
		var proof:Dictionary={"ok":true,"removed":0,"vertex_attribute_sha256":attribute_streams(mesh).get("sha256","")}
		if mesh is SphereMesh:
			proof=exact_pole_mesh(mesh)
			if not proof.ok:return proof
			mesh=proof.mesh;after_triangles=int(proof.result_triangles)
		var source_record:Dictionary={"node_path":str(cell.get_path_to(node)),"count":source.instance_count,"stride":plan.stride,"record_sha256":digest(plan.buffer.to_byte_array()),"mesh":source.mesh,"material":node.material_override,"shadow":node.cast_shadow,"visible":node.visible,"layers":node.layers,"original_metadata":original_meta(node),"raw_triangles":original_triangles,"result_triangles":after_triangles,"vertex_attribute_sha256":proof.vertex_attribute_sha256,"zero_area_proof":proof.get("normal_bias_proof","")}
		var group_id:int=sources.size();sources.append(source_record);var part_index:=0
		for group in plan.groups.values():
			var ids:Array=group.indices;var records:PackedFloat32Array=record_subset(plan.buffer,plan.stride,ids)
			var mm:=MultiMesh.new();mm.transform_format=source.transform_format;mm.use_colors=source.use_colors;mm.use_custom_data=source.use_custom_data;mm.mesh=mesh;mm.instance_count=ids.size();mm.buffer=records;mm.custom_aabb=group.bounds
			var part:MultiMeshInstance3D=node if part_index==0 else node.duplicate(0)
			part.multimesh=mm;part.set_meta(PREFIX+"group",group_id);part.set_meta(PREFIX+"part_index",part_index);part.set_meta(PREFIX+"indices",PackedInt32Array(ids));part.set_meta(PREFIX+"records_sha256",digest(records.to_byte_array()));part.set_meta(PREFIX+"part_instances",ids.size())
			# Preserve every original metadata key, including stream_instances. The
			# new part_instances field describes the new render-only partition.
			if part_index>0:node.get_parent().add_child(part)
			part_index+=1
		groups_added+=part_index;instances+=source.instance_count;removed_triangles+=(original_triangles-after_triangles)*source.instance_count;raw_triangles+=original_triangles*source.instance_count;result_triangles+=after_triangles*source.instance_count
	var expected_sources:int=2 if id=="-3_-2" else 1
	if sources.size()!=expected_sources:return {"ok":false,"reason":"expected_original_three_giant_batches_not_found","cell":id,"found":sources.size(),"expected":expected_sources}
	var after:Dictionary=protected_state(cell)
	if before!=after:return {"ok":false,"reason":"nonrender_or_original_metadata_changed","before":before,"after":after}
	var counts:Dictionary={"ok":true,"schema":SCHEMA,"cell":id,"source_batches":sources.size(),"result_batches":groups_added,"extra_batches":groups_added-sources.size(),"instances_before":instances,"instances_after":instances,"raw_source_triangles":raw_triangles,"result_triangles":result_triangles,"strict_zero_triangles_removed":removed_triangles,"protected":before,"cluster_size":CLUSTER_SIZE,"cpu_ms":(Time.get_ticks_usec()-started)/1000.0}
	cell.set_meta(PREFIX+"schema",SCHEMA);cell.set_meta(PREFIX+"sources",sources);cell.set_meta(PREFIX+"protected",before);cell.set_meta(PREFIX+"counts",counts.duplicate(true))
	var validation:Dictionary=validate_prebaked(cell)
	if not validation.ok:return {"ok":false,"reason":"post_partition_contract_failed","contract":validation}
	return counts

func validate_prebaked(cell:Node3D)->Dictionary:
	if int(cell.get_meta(PREFIX+"schema",0))!=SCHEMA:return {"ok":false,"reason":"prebaked_schema_missing"}
	var sources:Array=cell.get_meta(PREFIX+"sources",[]);var failures:Array=[];var count:=0;var batches:=0;var indexed:Dictionary={}
	for node in cell.find_children("*","MultiMeshInstance3D",true,false):
		if not node.has_meta(PREFIX+"group"):continue
		var id:int=node.get_meta(PREFIX+"group");var indices:PackedInt32Array=node.get_meta(PREFIX+"indices",PackedInt32Array())
		if id<0 or id>=sources.size() or node.multimesh==null:failures.append("invalid_partition:"+str(node.name));continue
		if not indexed.has(id):indexed[id]=[]
		indexed[id].append([node,indices]);batches+=1
	for id in sources.size():
		var record:Dictionary=sources[id];var reconstructed:=PackedFloat32Array();reconstructed.resize(int(record.count)*int(record.stride));var seen:Dictionary={}
		for part in indexed.get(id,[]):
			var node:MultiMeshInstance3D=part[0];var ids:PackedInt32Array=part[1];var buffer:PackedFloat32Array=node.multimesh.buffer
			if node.multimesh.instance_count!=ids.size() or buffer.size()!=ids.size()*int(record.stride) or digest(buffer.to_byte_array())!=str(node.get_meta(PREFIX+"records_sha256","")):failures.append("persisted_native_record_bytes:"+str(node.name));continue
			if node.material_override!=record.material or node.cast_shadow!=record.shadow or node.visible!=record.visible or node.layers!=record.layers or original_meta(node)!=record.original_metadata:failures.append("render_or_original_metadata:"+str(node.name))
			var attributes:Dictionary=attribute_streams(node.multimesh.mesh)
			if not attributes.ok or attributes.get("sha256","")!=record.vertex_attribute_sha256:failures.append("vertex_attribute_stream:"+str(node.name))
			var bounds:AABB=node.multimesh.custom_aabb
			for i in ids.size():
				var original:int=ids[i]
				if original<0 or original>=int(record.count) or seen.has(original):failures.append("duplicate_or_invalid_record_id");continue
				seen[original]=true
				for component in int(record.stride):reconstructed[original*int(record.stride)+component]=buffer[i*int(record.stride)+component]
				if not bounds.grow(.00001).encloses(raw_transform(buffer,i*int(record.stride))*record.mesh.get_aabb()):failures.append("shape_outside_real_bounds")
		if seen.size()!=int(record.count) or digest(reconstructed.to_byte_array())!=record.record_sha256:failures.append("source_reconstruction:"+str(record.node_path))
		count+=seen.size()
	var protected:Dictionary=protected_state(cell)
	if protected!=cell.get_meta(PREFIX+"protected",{}):failures.append("collider_label_original_node_metadata_or_transform_changed")
	return {"ok":failures.is_empty(),"compared_instances":count,"source_batches":sources.size(),"render_batches":batches,"protected":protected,"failures":failures,"runtime_partitioning":false}
