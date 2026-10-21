extends SceneTree
## Offline candidate only. Production geometry/materials are never changed by this script.
## Candidate keeps both source and shadow resources alive for a later isolated GUI comparison.
class Candidate extends RefCounted:
	var keep_alive:Dictionary={}

	func eligible_material(material:Material)->bool:
		if material is StandardMaterial3D:
			return material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not material.grow and not material.proximity_fade_enabled and material.distance_fade_mode==BaseMaterial3D.DISTANCE_FADE_DISABLED
		if material is ShaderMaterial and material.shader!=null:
			if material.shader.resource_path.get_file()!="voxel_surface.gdshader":return false
			var deformation:=RegEx.new();deformation.compile("\\b(VERTEX|POSITION|NORMAL)(\\.[xyzw]+)?\\s*([+*/-]?=)")
			return deformation.search(material.shader.code)==null and not "ALPHA" in material.shader.code and not "discard" in material.shader.code
		return material==null

	func build_shadow(box:BoxMesh)->Dictionary:
		if box.subdivide_width!=0 or box.subdivide_height!=0 or box.subdivide_depth!=0:return {"ok":false,"reason":"subdivided_box_not_in_candidate_scope"}
		var source:Array=box.get_mesh_arrays();var positions:PackedVector3Array=source[Mesh.ARRAY_VERTEX];var old_indices:PackedInt32Array=source[Mesh.ARRAY_INDEX]
		var unique:=PackedVector3Array();var remap:=PackedInt32Array();var ids:Dictionary={}
		for position in positions:
			if not ids.has(position):ids[position]=unique.size();unique.append(position)
			remap.append(ids[position])
		var indices:=PackedInt32Array()
		for i in old_indices:indices.append(remap[i])
		if unique.size()!=8 or old_indices.size()!=36:return {"ok":false,"reason":"unexpected_box_topology","vertices":unique.size(),"indices":old_indices.size()}
		var same_positions:=true
		for i in old_indices.size():same_positions=same_positions and positions[old_indices[i]]==unique[indices[i]]
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=unique;arrays[Mesh.ARRAY_INDEX]=indices
		var shadow:=ArrayMesh.new();shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return {"ok":same_positions,"mesh":shadow,"vertices_before":positions.size(),"vertices_after":unique.size(),"triangles_before":old_indices.size()/3,"triangles_after":indices.size()/3,"same_ordered_triangle_positions":same_positions,"same_aabb":box.get_aabb()==shadow.get_aabb()}

	func install(root_node:Node)->Dictionary:
		if not RenderingServer.has_method("mesh_set_shadow_mesh"):return {"ok":false,"reason":"binding_missing"}
		var groups:Dictionary={}
		for node in root_node.find_children("*","GeometryInstance3D",true,false):
			var mesh:Mesh=node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else node.mesh if node is MeshInstance3D else null
			if not mesh is BoxMesh:continue
			var id:int=mesh.get_instance_id()
			if not groups.has(id):groups[id]={"mesh":mesh,"safe":true,"users":0}
			var material:Material=node.get_active_material(0) if node is MeshInstance3D else node.material_override if node.material_override!=null else mesh.material
			groups[id].safe=bool(groups[id].safe) and eligible_material(material);groups[id].users+=1
		var installed:=0;var skipped:=0
		for id in groups:
			var group:Dictionary=groups[id]
			if not group.safe:skipped+=1;continue
			var built:Dictionary=build_shadow(group.mesh)
			if not built.ok:skipped+=1;continue
			RenderingServer.call("mesh_set_shadow_mesh",group.mesh.get_rid(),built.mesh.get_rid())
			keep_alive[id]={"source":group.mesh,"shadow":built.mesh};installed+=1
		return {"ok":true,"installed_shared_box_resources":installed,"skipped_unsafe_resources":skipped,"strong_reference_count":keep_alive.size()}

	func uninstall():
		for pair in keep_alive.values():RenderingServer.call("mesh_set_shadow_mesh",pair.source.get_rid(),RID())
		keep_alive.clear()

func _initialize():run.call_deferred()

func run():
	var candidate:=Candidate.new();var signatures:Array=[];var checks:Array=[]
	for method in ClassDB.class_get_method_list("RenderingServer"):
		if str(method.name)=="mesh_set_shadow_mesh":signatures.append(method)
	checks.append({"test":"rendering_server_binding_exists","passed":RenderingServer.has_method("mesh_set_shadow_mesh") and signatures.size()==1})
	var details:Array=[]
	for size in [Vector3.ONE,Vector3(.12,4.35,17.5),Vector3(12.7,.24,8.1)]:
		var box:=BoxMesh.new();box.size=size
		var result:Dictionary=candidate.build_shadow(box)
		checks.append({"test":"same_12_triangles_8_exact_positions_"+str(size),"passed":bool(result.ok) and result.same_ordered_triangle_positions and result.same_aabb and int(result.vertices_after)==8 and int(result.triangles_after)==12})
		result.erase("mesh");result["size"]=size;details.append(result)
	var fixture:=Node3D.new();root.add_child(fixture)
	var safe:=MeshInstance3D.new();safe.mesh=BoxMesh.new();safe.material_override=StandardMaterial3D.new();fixture.add_child(safe)
	var unsafe:=MeshInstance3D.new();unsafe.mesh=BoxMesh.new();var glass:=StandardMaterial3D.new();glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;unsafe.material_override=glass;fixture.add_child(unsafe)
	var mixed_mesh:=BoxMesh.new()
	for material in [safe.material_override,glass]:
		var user:=MeshInstance3D.new();user.mesh=mixed_mesh;user.set_surface_override_material(0,material);fixture.add_child(user)
	var install:Dictionary=candidate.install(fixture)
	checks.append({"test":"opaque_only_and_persistent_reference","passed":bool(install.ok) and int(install.installed_shared_box_resources)==1 and int(install.skipped_unsafe_resources)==2 and candidate.keep_alive.size()==1})
	var report:Dictionary={"engine":Engine.get_version_info(),"scope":"headless API/topology/material contract only; no GPU or pixel equivalence claimed","binding":signatures,"checks":checks,"details":details,"install":install,"normal_saves":"not used"}
	var file:=FileAccess.open("res://reports/creative110_box_shadow_contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOX_SHADOW_CONTRACT110 ",JSON.stringify({"checks":checks,"details":details,"install":install,"binding":signatures}))
	fixture.free();candidate.keep_alive.clear();quit(0 if checks.all(func(check):return check.passed) else 1)
