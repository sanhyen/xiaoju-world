extends "res://tools/creative110_terrain_order_probe.gd"
## Same texture formulas; zero-contribution skips and six fixed-material shader variants.
var original_materials:Dictionary={}
var specialized:Array=[]
var zero_weight:Shader
func remember():
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		var mat=node.material_override
		if not mat is ShaderMaterial or mat.shader==null or original_materials.has(mat.get_instance_id()):continue
		if not mat.shader.resource_path.ends_with("voxel_surface.gdshader"):continue
		var kind:int=int(mat.get_shader_parameter("surface_kind"))
		if kind<1 or kind>6:continue
		original_materials[mat.get_instance_id()]={"material":mat,"shader":mat.shader,"kind":kind}
func order(on:bool):
	for item in original_materials.values():
		item.material.shader=zero_weight if on else item.shader;item.material.set_shader_parameter("surface_kind",item.kind)
func flatten(on:bool):
	for item in original_materials.values():
		item.material.shader=specialized[item.kind-1] if on else zero_weight
		if not on:item.material.set_shader_parameter("surface_kind",item.kind)
func pixels(label:String)->Dictionary:return await super.pixels("voxel_"+label)
func json(path:String,value):
	if path.ends_with("creative110_terrain_order_probe.json"):
		path="res://reports/creative110_voxel_specialization_probe.json"
		value.scope="Original voxel shader A / zero-contribution skipping / same formulas with surface_kind compile-time constants / A. No production saves. Existing terrain draw order120 unchanged across all variants."
		value.material_count=original_materials.size()
	super.json(path,value)
func run():
	zero_weight=load("res://tools/voxel_surface_zero_weight110.gdshader");flat_shader=zero_weight
	for style in ["wood","plaster","slate","stone","fabric","thatch"]:specialized.append(load("res://tools/voxel_specialized110/"+style+".gdshader"))
	await super.run()
