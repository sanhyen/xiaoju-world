extends SceneTree
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
			result.append({"mesh":output,"key":key,"triangles":ids.size(),"source_triangle_ids":ids,"source_vertex_ids":original_vertices,"native_vertex_sha256":sha(vertices),"native_attribute_sha256":sha(attrs),"native_index_sha256":sha(native_indices),"aabb":part.aabb})
		for value in seen:
			if value!=1:return {"ok":false,"reason":"missing_triangle"}
		var before:=HashingContext.new();before.start(HashingContext.HASH_SHA256);var after:=HashingContext.new();after.start(HashingContext.HASH_SHA256)
		for i in indices.size():before.update(vertex_record(source,attributes,indices[i],info));after.update(vertex_record(source,attributes,representatives[i],info))
		var original_sha:String=before.finish().hex_encode();var reconstructed_sha:String=after.finish().hex_encode()
		if original_sha!=reconstructed_sha:return {"ok":false,"reason":"ordered_triangle_native_record_sha_changed"}
		return {"ok":true,"parts":result,"triangles":indices.size()/3,"source_vertices":info.count,"part_vertices":part_vertices,"source_indices":int(raw.get("index_count",0)),"part_indices":indices.size(),"ordered_source_sha256":original_sha,"ordered_reconstructed_sha256":reconstructed_sha,"layout":info,"source_vertex_bytes":source.size()+attributes.size()}
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
					var split:Dictionary=partition_surface(source,surface,node.global_transform)
					if not split.ok:failures.append({"cell":cell_id,"surface":surface,"failure":split});ok=false;break
					parts.append_array(split.parts);source_triangles+=int(split.triangles);source_bytes+=int(split.source_vertex_bytes)
					totals.source_vertices+=int(split.source_vertices);totals.part_vertices+=int(split.part_vertices);totals.source_indices+=int(split.source_indices);totals.part_indices+=int(split.part_indices);ordered_stream_proofs.append({"cell":str(cell_id),"surface":surface,"source":split.ordered_source_sha256,"reconstructed":split.ordered_reconstructed_sha256,"equal":split.ordered_source_sha256==split.ordered_reconstructed_sha256,"source_vertices":split.source_vertices,"part_vertices":split.part_vertices})
				if not ok:continue
				var nodes:Array=[]
				for i in parts.size():
					var part:Dictionary=parts[i];var proxy:=MeshInstance3D.new();proxy.name="TerrainPartition110_"+str(i);proxy.mesh=part.mesh
					for property in RENDER_PROPERTIES:proxy.set(property,node.get(property))
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

class FixtureStream extends RefCounted:
	var loaded:Dictionary={}
class FixtureWorld extends Node3D:
	var streamer=FixtureStream.new()
func _initialize():contracts.call_deferred()
func contracts():
	if DisplayServer.get_name()!="headless":push_error("CPU-only contract entry point; parent owns GPU comparison.");quit(2);return
	var world:=FixtureWorld.new();root.add_child(world)
	var ids:Array=["-3_-2","-3_-3","1_-1"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cells="):ids=Array(arg.trim_prefix("--cells=").split(","))
	var hashes:Dictionary={}
	for id in ids:
		var path:String="res://assets/world/stream_creative110/cell_"+str(id)+".scn";hashes[id]=FileAccess.get_sha256(path);var cell:Node=load(path).instantiate();world.add_child(cell);world.streamer.loaded[id]=cell
	var candidate:=Candidate.new();var setup:Dictionary=candidate.install(world);var checks:Array=[]
	checks.append({"id":"actual_cache_native_stream_and_triangle_contracts","passed":setup.ok and setup.totals.source_nodes==ids.size() and setup.totals.verified_native_parts==setup.totals.parts})
	var byte_conserved:bool=setup.ordered_triangle_native_record_sha256.all(func(item):return item.equal)
	checks.append({"id":"original_ordered_triangle_native_record_bytes_sha256_identical","passed":byte_conserved,"source_vertices":setup.totals.source_vertices,"result_vertices":setup.totals.part_vertices,"source_indices":setup.totals.source_indices,"result_indices":setup.totals.part_indices})
	var properties_ok:=true;var parent_visibility:=true;var source_unchanged:=true;var count:=0
	for entry in candidate.entries:
		for part in entry.parts:
			for property in Candidate.RENDER_PROPERTIES:properties_ok=properties_ok and part.get(property)==entry.node.get(property)
			count+=1
		source_unchanged=source_unchanged and entry.node.mesh==entry.source_mesh
	checks.append({"id":"original_render_settings_and_disabled_source_unchanged","passed":properties_ok and source_unchanged})
	candidate.enabled=true;candidate.update()
	for entry in candidate.entries:
		parent_visibility=parent_visibility and entry.node.mesh==null
		entry.node.visible=false
		for part in entry.parts:parent_visibility=parent_visibility and not part.is_visible_in_tree()
		entry.node.visible=true
	checks.append({"id":"original_parent_visibility_inherited_and_source_not_double_drawn","passed":parent_visibility})
	candidate.restore();var restore_ok:=true;var proxies:Array=[]
	for entry in candidate.entries:
		restore_ok=restore_ok and entry.node.mesh==entry.source_mesh
		for part in entry.parts:restore_ok=restore_ok and not part.visible;proxies.append(part)
	candidate.uninstall()
	for part in proxies:restore_ok=restore_ok and not is_instance_valid(part)
	checks.append({"id":"restore_exact_original_mesh_and_remove_only_new_render_nodes","passed":restore_ok})
	var report:Dictionary={"scope":"CPU-only actual-cache native-byte conservation and scene-state contracts; no GPU equivalence or speed claim","cells":ids,"input_sha256":hashes,"setup":setup,"checks":checks,"gpu_run":false,"normal_saves":"not loaded","known_limit":"Install partitions only currently loaded cells; freeze streaming in isolated A/B. Production integration is not authorized by this tool."}
	var file:=FileAccess.open("res://reports/creative110_terrain_partition_contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("TERRAIN_PARTITION110_CONTRACT ",JSON.stringify(report));world.free();quit(0 if checks.all(func(check):return check.passed) else 1)
