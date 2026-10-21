extends SceneTree
func _initialize():
	for method in ClassDB.class_get_method_list("RenderingServer"):
		if str(method.name).begins_with("mesh_surface_get_format"):print("FORMAT_API ",JSON.stringify(method))
	var cell:Node=load("res://assets/world/stream_creative110/cell_-3_-2.scn").instantiate()
	for node in cell.find_children("*","MeshInstance3D",true,false):
		if not node.has_meta("stream_terrain"):continue
		var mesh:Mesh=node.mesh;var stored:Variant=mesh.get("_surfaces")
		print("STORED_TYPE ",typeof(stored)," count ",stored.size() if stored!=null else -1)
		for surface in mesh.get_surface_count():
			var raw:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
			print("RAW_KEYS ",raw.keys())
			if raw.is_empty() and stored!=null:raw=stored[surface]
			for key in raw:
				var value:Variant=raw[key];print("RAW ",key," type ",typeof(value)," value ",value.size() if value is PackedByteArray else value)
			var format:int=raw.get("format",0);var count:int=raw.get("vertex_count",0)
			for array in range(Mesh.ARRAY_MAX):print("OFFSET ",array," ",RenderingServer.mesh_surface_get_format_offset(format,count,array))
			print("STRIDE_VERTEX ",RenderingServer.mesh_surface_get_format_vertex_stride(format,count))
			print("STRIDE_NORMAL ",RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count))
			print("STRIDE_ATTRIBUTE ",RenderingServer.mesh_surface_get_format_attribute_stride(format,count))
			print("STRIDE_SKIN ",RenderingServer.mesh_surface_get_format_skin_stride(format,count))
			print("RAW_HEAD ",raw.vertex_data.slice(0,32).hex_encode()," FORMAT_INDEX ",Mesh.ARRAY_FORMAT_INDEX," COMPRESS ",Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
			print("SOURCE_PROPS ",node.get_property_list())
	cell.free();quit()
