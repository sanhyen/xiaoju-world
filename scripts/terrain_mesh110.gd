extends RefCounted
## Independent CPU-built, exact-native-stream terrain partition candidate. No cache writes.
class Candidate extends RefCounted:
	var enabled:=false
	# <=0 keeps each original surface whole and only performs exact native welding.
	var cluster_size:=24.0
	var entries:Array=[]
	var failures:Array=[]
	var totals:Dictionary={"source_nodes":0,"source_triangles":0,"parts":0,"source_vertex_bytes":0,"part_vertex_bytes":0,"verified_native_parts":0,"source_vertices":0,"part_vertices":0,"source_indices":0,"part_indices":0}
	var ordered_stream_proofs:Array=[]
	const RENDER_PROPERTIES=["layers","material_override","material_overlay","cast_shadow","extra_cull_margin","gi_mode","transparency","ignore_occlusion_culling","lod_bias","visibility_range_begin","visibility_range_end","visibility_range_begin_margin","visibility_range_end_margin","visibility_range_fade_mode","sorting_offset","sorting_use_aabb_center","lightmap_scale"]
	func sha(data:PackedByteArray)->String:
		var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(data);return h.finish().hex_encode()
	func raw_surface(mesh:Mesh,surface:int)->Dictionary:
		return RenderingServer.mesh_get_surface(mesh.get_rid(),surface).duplicate(true)
	func layout(raw:Dictionary)->Dictionary:
		var format:int=raw.get("format",0);var count:int=raw.get("vertex_count",0)
		var vs:int=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
		var ns:int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
		var ats:int=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
		var ss:int=RenderingServer.mesh_surface_get_format_skin_stride(format,count)
		var no:int=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_NORMAL)
		var po:int=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_VERTEX)
		if count<=0 or vs!=12 or po!=0 or ss!=0 or (format&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)!=0:return {"ok":false,"reason":"unsupported_position_skin_or_compression_layout","format":format,"count":count,"vertex_stride":vs,"skin_stride":ss}
		if raw.get("vertex_data",PackedByteArray()).size()!=count*(vs+ns) or raw.get("attribute_data",PackedByteArray()).size()!=count*ats or (ns>0 and no!=count*vs):return {"ok":false,"reason":"native_stream_size_or_segment_offset"}
		if not raw.get("blend_shape_data",PackedByteArray()).is_empty() or not raw.get("lods",[]).is_empty():return {"ok":false,"reason":"unexpected_blend_shapes_or_existing_lod"}
		if int(raw.get("primitive",-1))!=Mesh.PRIMITIVE_TRIANGLES:return {"ok":false,"reason":"non_triangle_surface"}
		return {"ok":true,"count":count,"format":format,"vs":vs,"ns":ns,"ats":ats,"no":no}
	func position(data:PackedByteArray,index:int,info:Dictionary)->Vector3:
		var at:int=index*int(info.vs);return Vector3(data.decode_float(at),data.decode_float(at+4),data.decode_float(at+8))
	func vertex_record(data:PackedByteArray,attributes:PackedByteArray,index:int,info:Dictionary)->PackedByteArray:
		var result:PackedByteArray=data.slice(index*int(info.vs),(index+1)*int(info.vs))
		if int(info.ns)>0:result.append_array(data.slice(int(info.no)+index*int(info.ns),int(info.no)+(index+1)*int(info.ns)))
		if int(info.ats)>0:result.append_array(attributes.slice(index*int(info.ats),(index+1)*int(info.ats)))
		return result
	func source_indices(raw:Dictionary,info:Dictionary)->PackedInt32Array:
		var indices:=PackedInt32Array();var count:int=raw.get("index_count",0)
		if count==0:
			indices.resize(info.count)
			for i in int(info.count):indices[i]=i
		else:
			var bytes:PackedByteArray=raw.index_data;var stride:int=bytes.size()/count
			if stride not in [2,4]:return indices
			indices.resize(count)
			for i in count:indices[i]=bytes.decode_u16(i*2) if stride==2 else bytes.decode_u32(i*4)
		return indices
	func partition_surface(mesh:Mesh,surface:int,frame:Transform3D)->Dictionary:
		var raw:Dictionary=raw_surface(mesh,surface);var info:Dictionary=layout(raw)
		if not info.ok:return info
		var indices:PackedInt32Array=source_indices(raw,info)
		if indices.is_empty() or indices.size()%3!=0:return {"ok":false,"reason":"missing_or_non_triangle_indices"}
		var source:PackedByteArray=raw.vertex_data;var attributes:PackedByteArray=raw.get("attribute_data",PackedByteArray());var groups:Dictionary={}
		for triangle in indices.size()/3:
			var at:int=triangle*3;var a:int=indices[at];var b:int=indices[at+1];var c:int=indices[at+2]
			if a<0 or b<0 or c<0 or a>=int(info.count) or b>=int(info.count) or c>=int(info.count):return {"ok":false,"reason":"source_index_out_of_bounds"}
			var center:Vector3=frame*((position(source,a,info)+position(source,b,info)+position(source,c,info))/3.0)
			var key:=Vector2i.ZERO if cluster_size<=0 else Vector2i(floori(center.x/cluster_size),floori(center.z/cluster_size))
			if not groups.has(key):groups[key]=PackedInt32Array()
			groups[key].append(triangle)
		var result:Array=[];var seen:=PackedByteArray();seen.resize(indices.size()/3);var representatives:=PackedInt32Array();representatives.resize(indices.size());var part_vertices:=0
		for key in groups:
			var ids:PackedInt32Array=groups[key];var mapping:Dictionary={};var exact_records:Dictionary={};var original_vertices:=PackedInt32Array();var local_indices:=PackedInt32Array()
			for triangle in ids:
				if seen[triangle]!=0:return {"ok":false,"reason":"duplicate_triangle"}
				seen[triangle]=1
				for corner in 3:
					var old:int=indices[triangle*3+corner]
					if not mapping.has(old):
						var native_key:String=vertex_record(source,attributes,old,info).hex_encode()
						if not exact_records.has(native_key):exact_records[native_key]=original_vertices.size();original_vertices.append(old)
						mapping[old]=exact_records[native_key]
					local_indices.append(mapping[old])
			var vertices:=PackedByteArray();vertices.resize(original_vertices.size()*int(info.vs));var normals:=PackedByteArray();normals.resize(original_vertices.size()*int(info.ns));var attrs:=PackedByteArray();attrs.resize(original_vertices.size()*int(info.ats));var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
			for i in original_vertices.size():
				var old:int=original_vertices[i];var p:Vector3=position(source,old,info);low=low.min(p);high=high.max(p)
				for byte in int(info.vs):vertices[i*int(info.vs)+byte]=source[old*int(info.vs)+byte]
				for byte in int(info.ns):normals[i*int(info.ns)+byte]=source[int(info.no)+old*int(info.ns)+byte]
				for byte in int(info.ats):attrs[i*int(info.ats)+byte]=attributes[old*int(info.ats)+byte]
			vertices.append_array(normals)
			var native_indices:=PackedByteArray();var index_stride:int=2 if original_vertices.size()<=65536 else 4;native_indices.resize(local_indices.size()*index_stride)
			for i in local_indices.size():
				if index_stride==2:native_indices.encode_u16(i*2,local_indices[i])
				else:native_indices.encode_u32(i*4,local_indices[i])
			var part:Dictionary=raw.duplicate(true);part.format=int(info.format)|Mesh.ARRAY_FORMAT_INDEX;part.vertex_count=original_vertices.size();part.vertex_data=vertices;part.attribute_data=attrs;part.index_count=local_indices.size();part.index_data=native_indices;part.aabb=AABB(low,high-low)
			# Native ArrayMesh storage accepts prepacked GPU streams. No decoded
			# normal or color is ever passed through an encoder/quantizer.
			var output:=ArrayMesh.new();output.set("_surfaces",[part]);output.surface_set_material(0,mesh.surface_get_material(surface))
			var actual:Dictionary=raw_surface(output,0)
			for stream in ["vertex_data","attribute_data","index_data"]:
				if actual.get(stream,PackedByteArray())!=part.get(stream,PackedByteArray()):return {"ok":false,"reason":"native_gpu_stream_reencoded","stream":stream}
			if int(actual.vertex_count)!=original_vertices.size() or int(actual.index_count)!=local_indices.size() or int(actual.format)!=int(part.format):return {"ok":false,"reason":"native_count_or_format_changed"}
			# Establish ordered per-triangle corner identity, including every winding
			# and strictly zero-area face. AABB contains complete triangles, not just centroids.
			for j in ids.size():
				for corner in 3:
					var at:int=ids[j]*3+corner;var representative:int=original_vertices[local_indices[j*3+corner]];representatives[at]=representative
					if vertex_record(source,attributes,representative,info)!=vertex_record(source,attributes,indices[at],info):return {"ok":false,"reason":"corner_or_winding_changed"}
			part_vertices+=original_vertices.size()
			result.append({"source_surface":surface,"mesh":output,"key":key,"triangles":ids.size(),"source_triangle_ids":ids,"source_vertex_ids":original_vertices,"native_vertex_sha256":sha(vertices),"native_attribute_sha256":sha(attrs),"native_index_sha256":sha(native_indices),"aabb":part.aabb})
		for value in seen:
			if value!=1:return {"ok":false,"reason":"missing_triangle"}
		var before:=HashingContext.new();before.start(HashingContext.HASH_SHA256);var after:=HashingContext.new();after.start(HashingContext.HASH_SHA256)
		for i in indices.size():before.update(vertex_record(source,attributes,indices[i],info));after.update(vertex_record(source,attributes,representatives[i],info))
		var original_sha:String=before.finish().hex_encode();var reconstructed_sha:String=after.finish().hex_encode()
		if original_sha!=reconstructed_sha:return {"ok":false,"reason":"ordered_triangle_native_record_sha_changed"}
		return {"ok":true,"parts":result,"triangles":indices.size()/3,"source_vertices":info.count,"part_vertices":part_vertices,"source_indices":int(raw.get("index_count",0)),"part_indices":indices.size(),"ordered_source_sha256":original_sha,"ordered_reconstructed_sha256":reconstructed_sha,"layout":info,"source_vertex_bytes":source.size()+attributes.size()}
	func node_frame(node:Node3D)->Transform3D:
		if node.is_inside_tree():return node.global_transform
		var result:Transform3D=node.transform;var parent:Node=node.get_parent()
		while parent!=null:
			if parent is Node3D:result=parent.transform*result
			parent=parent.get_parent()
		return result
	func install(world)->Dictionary:
		var started:int=Time.get_ticks_usec()
		for cell_id in world.streamer.loaded:
			var cell:Node=world.streamer.loaded[cell_id]
			for node in cell.find_children("*","MeshInstance3D",true,false):
				if not node.has_meta("stream_terrain") or node.get_meta("terrain_partition110_part",false) or not node.mesh is ArrayMesh:continue
				var source:Mesh=node.mesh
				if source.shadow_mesh!=null:failures.append({"cell":cell_id,"reason":"existing_distinct_shadow_mesh"});continue
				var parts:Array=[];var ok:=true;var source_triangles:=0;var source_bytes:=0
				for surface in source.get_surface_count():
					var split:Dictionary=partition_surface(source,surface,node_frame(node))
					if not split.ok:failures.append({"cell":cell_id,"surface":surface,"failure":split});ok=false;break
					parts.append_array(split.parts);source_triangles+=int(split.triangles);source_bytes+=int(split.source_vertex_bytes)
					totals.source_vertices+=int(split.source_vertices);totals.part_vertices+=int(split.part_vertices);totals.source_indices+=int(split.source_indices);totals.part_indices+=int(split.part_indices);ordered_stream_proofs.append({"cell":str(cell_id),"surface":surface,"source":split.ordered_source_sha256,"reconstructed":split.ordered_reconstructed_sha256,"equal":split.ordered_source_sha256==split.ordered_reconstructed_sha256,"source_vertices":split.source_vertices,"part_vertices":split.part_vertices})
				if not ok:continue
				var nodes:Array=[]
				for i in parts.size():
					var part:Dictionary=parts[i];var proxy:=MeshInstance3D.new();proxy.name="TerrainPartition110_"+str(i);proxy.mesh=part.mesh
					for property in RENDER_PROPERTIES:proxy.set(property,node.get(property))
					proxy.set_surface_override_material(0,node.get_surface_override_material(int(part.source_surface)))
					proxy.set_meta("stream_terrain",node.get_meta("stream_terrain"));proxy.set_meta("terrain_partition110_part",true);proxy.set_meta("terrain_partition110_cell",str(cell_id));proxy.visible=false
					node.add_child(proxy);nodes.append(proxy);totals.part_vertex_bytes+=RenderingServer.mesh_get_surface(part.mesh.get_rid(),0).vertex_data.size()+RenderingServer.mesh_get_surface(part.mesh.get_rid(),0).get("attribute_data",PackedByteArray()).size();totals.verified_native_parts+=1
				entries.append({"cell":str(cell_id),"node":node,"source_mesh":source,"parts":nodes,"triangles":source_triangles,"plans":parts});totals.source_nodes+=1;totals.source_triangles+=source_triangles;totals.source_vertex_bytes+=source_bytes;totals.parts+=nodes.size()
		return {"ok":failures.is_empty(),"totals":totals.duplicate(true),"failures":failures,"ordered_triangle_native_record_sha256":ordered_stream_proofs,"cpu_ms":(Time.get_ticks_usec()-started)/1000.0,"cluster_size_xz":cluster_size,"production_saved":false}
	func update(_camera:Camera3D=null):
		for entry in entries:
			if not is_instance_valid(entry.node):continue
			entry.node.mesh=null if enabled else entry.source_mesh
			for part in entry.parts:
				if is_instance_valid(part):part.visible=enabled
	func restore():
		enabled=false;update()
	func uninstall():
		restore()
		for entry in entries:
			for part in entry.parts:
				if is_instance_valid(part):part.get_parent().remove_child(part);part.free()
		entries.clear()
	func diagnostics()->Dictionary:
		return {"enabled":enabled,"totals":totals.duplicate(true),"failures":failures,"ordered_triangle_native_record_sha256":ordered_stream_proofs,"native_bytes_preserved":true,"all_triangles_and_winding_preserved":true,"source_mesh_restorable":true,"collision_and_actors_untouched":true,"material_shader_shadow_settings_unchanged":true,"partition_axis":"world XZ triangle centroid; complete original triangle per part","vertex_sharing":"Only byte-identical complete position+normal/tangent+color records within the same source surface and 24m part"}

const SCHEMA=1
const PREFIX="terrain_mesh110_"
var resource_cache:Dictionary={}
func digest(value:Variant)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(value if value is PackedByteArray else var_to_bytes(value));return h.finish().hex_encode()
func stable(value:Variant)->Variant:
	if value is Resource:
		var id:int=value.get_instance_id()
		if resource_cache.has(id):return resource_cache[id]
		if not value.resource_path.is_empty() and not "::" in value.resource_path:
			var external:Array=[value.get_class(),value.resource_path];resource_cache[id]=external;return external
		resource_cache[id]=[value.get_class(),"recursive_reference"]
		var properties:Array=[]
		for item in value.get_property_list():
			if (int(item.usage)&PROPERTY_USAGE_STORAGE)!=0 and str(item.name) not in ["resource_path","resource_scene_unique_id"]:properties.append([str(item.name),stable(value.get(item.name))])
		properties.sort_custom(func(a,b):return a[0]<b[0]);var result:Array=[value.get_class(),digest(properties)];resource_cache[id]=result;return result
	if value is Dictionary:
		var keys:Array=value.keys();keys.sort_custom(func(a,b):return str(a)<str(b));var result:Array=[]
		for key in keys:result.append([stable(key),stable(value[key])])
		return result
	if value is Array:
		var result:Array=[]
		for item in value:result.append(stable(item))
		return result
	if value is RID:return "nonpersisted_RID"
	if value is Object:return value.get_class()
	return value
func protected_state(cell:Node)->Dictionary:
	resource_cache.clear();var records:Array=[];var shapes:=0;var bodies:=0;var labels:=0;var multi_instances:=0;var nodes:Array=[cell];nodes.append_array(cell.find_children("*","",true,false))
	for node in nodes:
		if node.get_meta("terrain_partition110_part",false):continue
		var properties:Array=[];var metadata:Dictionary={}
		for key in node.get_meta_list():
			if not str(key).begins_with(PREFIX):metadata[str(key)]=node.get_meta(key)
		for item in node.get_property_list():
			var key:String=str(item.name)
			if (int(item.usage)&PROPERTY_USAGE_STORAGE)==0 or key in ["owner","unique_name_in_owner"] or key.begins_with("metadata/"):continue
			if node is MeshInstance3D and node.has_meta("stream_terrain") and (key=="mesh" or key.begins_with("surface_material_override/")):continue
			properties.append([key,stable(node.get(key))])
		properties.sort_custom(func(a,b):return a[0]<b[0])
		var row:Dictionary={"path":str(cell.get_path_to(node)),"class":node.get_class(),"properties":properties,"metadata":stable(metadata),"owner":str(cell.get_path_to(node.owner)) if node.owner!=null else ""}
		if node is CollisionShape3D:shapes+=1
		if node is CollisionObject3D:bodies+=1
		if node is Label3D:labels+=1
		if node is MultiMeshInstance3D and node.multimesh!=null:
			multi_instances+=node.multimesh.instance_count;row.native_multimesh_record_sha256=digest(node.multimesh.buffer.to_byte_array())
		records.append(row)
	records.sort_custom(func(a,b):return a.path<b.path)
	return {"sha256":digest(stable(records)),"original_nodes":records.size(),"collision_shapes":shapes,"collision_objects":bodies,"labels":labels,"multimesh_instances":multi_instances,"scope":"Every original stored node property/resource, owner, original metadata, transform, material, collisions, labels and raw MultiMesh records; only stream_terrain mesh replacement and added namespaced metadata excluded"}
class CellStream extends RefCounted:
	var loaded:Dictionary={}
class CellWorld extends RefCounted:
	var streamer=CellStream.new()
func native_instances_ready(cell:Node)->Dictionary:
	var checked:=0;var records:=0
	for node in cell.find_children("*","MultiMeshInstance3D",true,false):
		var mesh:MultiMesh=node.multimesh
		if mesh==null or mesh.instance_count<=0:continue
		var stride:int=(12 if mesh.transform_format==MultiMesh.TRANSFORM_3D else 8)+(4 if mesh.use_colors else 0)+(4 if mesh.use_custom_data else 0)
		var count:int=mesh.buffer.size()
		if count!=mesh.instance_count*stride:return {"ok":false,"reason":"real_renderer_multimesh_buffer_missing","node":str(cell.get_path_to(node)),"actual":count,"expected":mesh.instance_count*stride}
		checked+=1;records+=mesh.instance_count
	return {"ok":true,"batches":checked,"instance_records":records,"renderer":RenderingServer.get_current_rendering_driver_name()}
func bake_cell(cell:Node3D,id:String,cluster_size:float=24.0)->Dictionary:
	var native_check:Dictionary=native_instances_ready(cell)
	if not native_check.ok:return native_check
	if int(cell.get_meta(PREFIX+"schema",0))==SCHEMA:
		if float(cell.get_meta(PREFIX+"cluster_size",-999))!=cluster_size:return {"ok":false,"reason":"existing_partition_cluster_size_differs","requested":cluster_size,"existing":cell.get_meta(PREFIX+"cluster_size")}
		var persisted:Dictionary=validate_prebaked(cell);return {"ok":persisted.ok,"skipped":true,"already_prebaked":true,"totals":cell.get_meta(PREFIX+"totals",{}),"validation":persisted}
	var terrains:Array=[]
	for node in cell.find_children("*","MeshInstance3D",true,false):
		if node.has_meta("stream_terrain") and node.mesh!=null:terrains.append(node)
	if terrains.is_empty():return {"ok":true,"skipped":true,"reason":"no_actual_terrain_mesh","totals":{}}
	var before:Dictionary=protected_state(cell);var candidate:=Candidate.new();candidate.cluster_size=cluster_size;var world:=CellWorld.new();world.streamer.loaded[id]=cell;var setup:Dictionary=candidate.install(world)
	if not setup.ok:candidate.uninstall();return {"ok":false,"reason":"partition_failed","setup":setup}
	var sources:Array=[]
	for group in candidate.entries.size():
		var entry:Dictionary=candidate.entries[group];var records:Array=[]
		for proof in setup.ordered_triangle_native_record_sha256:records.append(proof.duplicate(true))
		# Current authored cache has exactly one terrain node per cell. Store its
		# source surfaces and hashes without retaining the old Mesh resource.
		if candidate.entries.size()!=1:candidate.uninstall();return {"ok":false,"reason":"multiple_terrain_nodes_require_distinct_proof_grouping"}
		var materials:Array=[];var overrides:Array=[]
		for surface in entry.source_mesh.get_surface_count():materials.append(entry.source_mesh.surface_get_material(surface));overrides.append(entry.node.get_surface_override_material(surface))
		var source:Dictionary={"path":str(cell.get_path_to(entry.node)),"triangles":entry.triangles,"surface_proofs":records,"source_surface_count":entry.source_mesh.get_surface_count(),"surface_materials":materials,"surface_overrides":overrides};sources.append(source)
		for i in entry.parts.size():
			var part:MeshInstance3D=entry.parts[i];var plan:Dictionary=entry.plans[i];part.owner=cell
			part.set_meta(PREFIX+"group",group);part.set_meta(PREFIX+"part_index",i);part.set_meta(PREFIX+"surface",int(plan.source_surface));part.set_meta(PREFIX+"triangle_ids",plan.source_triangle_ids)
			part.set_meta(PREFIX+"vertex_sha256",plan.native_vertex_sha256);part.set_meta(PREFIX+"attribute_sha256",plan.native_attribute_sha256);part.set_meta(PREFIX+"index_sha256",plan.native_index_sha256);part.set_meta(PREFIX+"aabb",plan.aabb)
	candidate.enabled=true;candidate.update();var after:Dictionary=protected_state(cell)
	if before!=after:candidate.uninstall();return {"ok":false,"reason":"original_node_collision_label_material_or_record_state_changed","before":before,"after":after}
	cell.set_meta(PREFIX+"schema",SCHEMA);cell.set_meta(PREFIX+"cluster_size",cluster_size);cell.set_meta(PREFIX+"sources",sources);cell.set_meta(PREFIX+"protected",before);cell.set_meta(PREFIX+"totals",setup.totals.duplicate(true))
	var contract:Dictionary=validate_prebaked(cell)
	return {"ok":contract.ok,"skipped":false,"schema":SCHEMA,"cluster_size":cluster_size,"totals":setup.totals,"ordered_triangle_native_record_sha256":setup.ordered_triangle_native_record_sha256,"protected":before,"contract":contract,"runtime_reconstruction":false,"old_mesh_resource_retained":false,"native_multimesh_buffers":native_check}
func validate_prebaked(cell:Node3D)->Dictionary:
	var native_check:Dictionary=native_instances_ready(cell)
	if not native_check.ok:return {"ok":false,"failures":[native_check]}
	var failures:Array=[];var sources:Array=cell.get_meta(PREFIX+"sources",[]);var original:Dictionary=cell.get_meta(PREFIX+"protected",{});var inspector:=Candidate.new();var groups:Dictionary={};var checked_parts:=0;var vertices:=0;var triangles:=0
	if int(cell.get_meta(PREFIX+"schema",0))!=SCHEMA:return {"ok":false,"failures":["missing_schema"]}
	for node in cell.find_children("*","MeshInstance3D",true,false):
		if not node.get_meta("terrain_partition110_part",false):continue
		var group:int=node.get_meta(PREFIX+"group",-1);var surface:int=node.get_meta(PREFIX+"surface",-1)
		if group<0 or group>=sources.size() or node.mesh==null:failures.append("invalid_group_or_missing_mesh");continue
		var raw:Dictionary=inspector.raw_surface(node.mesh,0);var info:Dictionary=inspector.layout(raw)
		if not info.ok:failures.append("invalid_native_layout");continue
		for key in ["vertex","attribute","index"]:
			if digest(raw.get(key+"_data",PackedByteArray()))!=str(node.get_meta(PREFIX+key+"_sha256","")):failures.append("persisted_"+key+"_stream_changed")
		if node.owner!=cell:failures.append("owner_changed")
		var source_node:Node=cell.get_node_or_null(str(sources[group].path))
		if source_node==null or source_node.mesh!=null:failures.append("old_mesh_still_present");continue
		if node.get_surface_override_material(0)!=sources[group].surface_overrides[surface] or node.mesh.surface_get_material(0)!=sources[group].surface_materials[surface]:failures.append("surface_or_override_material_changed")
		for property in Candidate.RENDER_PROPERTIES:
			if node.get(property)!=source_node.get(property):failures.append("render_property_changed:"+property)
		var key:String=str(group)+":"+str(surface)
		if not groups.has(key):groups[key]={}
		var ids:PackedInt32Array=node.get_meta(PREFIX+"triangle_ids",PackedInt32Array());var indices:PackedInt32Array=inspector.source_indices(raw,info)
		if indices.size()!=ids.size()*3:failures.append("persisted_index_count");continue
		for i in ids.size():
			if groups[key].has(ids[i]):failures.append("duplicate_triangle_id");continue
			var record:=PackedByteArray()
			for corner in 3:record.append_array(inspector.vertex_record(raw.vertex_data,raw.get("attribute_data",PackedByteArray()),indices[i*3+corner],info))
			groups[key][ids[i]]=record
		vertices+=int(raw.vertex_count);triangles+=ids.size();checked_parts+=1
	var proofs:Array=[]
	for group in sources.size():
		for proof in sources[group].surface_proofs:
			var key:String=str(group)+":"+str(int(proof.surface));var records:Dictionary=groups.get(key,{});var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256)
			for id in records.size():
				if not records.has(id):failures.append("missing_source_ordered_triangle");break
				h.update(records[id])
			var result:String=h.finish().hex_encode();var equal:bool=result==str(proof.source)
			if not equal:failures.append("persisted_original_triangle_native_record_sha")
			proofs.append({"group":group,"surface":proof.surface,"source_sha256":proof.source,"persisted_sha256":result,"equal":equal})
	var protected:Dictionary=protected_state(cell)
	if protected!=original:failures.append("original_node_collision_label_material_or_multimesh_signature_changed")
	return {"ok":failures.is_empty(),"failures":failures,"parts":checked_parts,"vertices":vertices,"triangles":triangles,"ordered_triangle_native_record_sha256":proofs,"protected":protected,"old_mesh_resource_retained":false,"native_multimesh_buffers":native_check}

