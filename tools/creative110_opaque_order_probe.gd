extends "res://tools/creative110_terrain_order_probe.gd"
## Front-to-back submission only; original materials, shader formulas and geometry.
var opaque:Dictionary={}
func remember():
	opaque.clear();var eye:Vector3=m.player.camera.global_position
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if node.has_meta("stream_terrain") or not node.is_visible_in_tree():continue
		if not node is MultiMeshInstance3D and not node is MeshInstance3D:continue
		var mat:Material=node.material_override
		if mat is StandardMaterial3D:
			if mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or mat.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or mat.next_pass!=null:continue
		elif mat is ShaderMaterial:
			if mat.shader==null or not mat.shader.resource_path.ends_with("voxel_surface.gdshader"):continue
		else:continue
		var box:AABB=node.global_transform*node.get_aabb();var nearest:Vector3=eye.clamp(box.position,box.end);var d:float=nearest.distance_to(eye);var id:int=mat.get_instance_id()
		if not opaque.has(id):opaque[id]={"material":mat,"original":mat.render_priority,"distance":d}
		else:opaque[id].distance=minf(opaque[id].distance,d)
func order(on:bool):
	for item in opaque.values():item.material.render_priority=clampi(-110+floori(item.distance/4),-110,100) if on else item.original
func pixels(label:String)->Dictionary:return await super.pixels("opaque_order_"+label)
func json(path:String,value):
	if path.ends_with("creative110_terrain_order_probe.json"):
		path="res://reports/creative110_opaque_order_probe.json";value.scope="Only opaque StandardMaterial3D and original voxel shader render_priority sorted front-to-back by nearest material user AABB. Transparent/emissive special shaders/terrain untouched; original shaders and all shadow settings unchanged. No resources saved."
		value.materials_sorted=opaque.size()
	super.json(path,value)
