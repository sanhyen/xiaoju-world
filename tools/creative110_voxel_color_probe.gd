extends "res://tools/creative110_terrain_order_probe.gd"
## Strict per-triangle COLOR audit before changing a shared voxel material.
var colors_materials:Dictionary={}
var vertex_shader:Shader
var audited_meshes:Dictionary={}
func constant_color(mesh:Mesh)->bool:
	if mesh==null:return false
	var id:int=mesh.get_instance_id()
	if audited_meshes.has(id):return audited_meshes[id]
	if not mesh is ArrayMesh and not mesh is PrimitiveMesh:audited_meshes[id]=false;return false
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:audited_meshes[id]=false;return false
		var a:Array=mesh.surface_get_arrays(surface);var colors=a[Mesh.ARRAY_COLOR]
		if colors==null or colors.is_empty():continue
		var indices=a[Mesh.ARRAY_INDEX];var count:int=indices.size() if indices!=null and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size()
		for triangle in count/3:
			var at:int=triangle*3;var i:int=indices[at] if indices!=null and not indices.is_empty() else at;var j:int=indices[at+1] if indices!=null and not indices.is_empty() else at+1;var k:int=indices[at+2] if indices!=null and not indices.is_empty() else at+2
			if colors[i]!=colors[j] or colors[i]!=colors[k]:audited_meshes[id]=false;return false
	audited_meshes[id]=true;return true
func remember():
	# Re-scan all loaded users, including previously-seen shared materials.
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		var mat=node.material_override
		if not mat is ShaderMaterial or mat.shader==null:continue
		var id:int=mat.get_instance_id()
		if not colors_materials.has(id):
			if not mat.shader.resource_path.ends_with("voxel_surface.gdshader"):continue
			colors_materials[id]={"material":mat,"shader":mat.shader,"safe":true,"users":0,"kind":int(mat.get_shader_parameter("surface_kind"))}
		var mesh:Mesh=node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else node.mesh if node is MeshInstance3D else null
		colors_materials[id].safe=colors_materials[id].safe and constant_color(mesh);colors_materials[id].users+=1
func order(on:bool):
	for item in colors_materials.values():
		item.material.shader=vertex_shader if on and item.safe else item.shader;item.material.set_shader_parameter("surface_kind",item.kind)
func pixels(label:String)->Dictionary:return await super.pixels("voxel_color_"+label)
func json(path:String,value):
	if path.ends_with("creative110_terrain_order_probe.json"):
		path="res://reports/creative110_voxel_color_probe.json";value.scope="Only move original RGB gamma conversion into vertex, flat per-triangle output. Shared materials audit all currently loaded users for exact triangle constant COLOR first; all other math unchanged; no production saves. Existing terrain order120 unchanged."
		var summary:Array=[]
		for item in colors_materials.values():summary.append({"kind":item.kind,"users":item.users,"safe":item.safe})
		value.material_audit=summary;value.audited_meshes=audited_meshes.size()
	super.json(path,value)
func run():
	vertex_shader=load("res://tools/voxel_vertex_color110.gdshader")
	await super.run()
