extends SceneTree
## Three near-cell Box batches only; serialized native transforms, no scene mutation/GPU.
const CELLS=["-2_-1","-2_0","-1_0"]
const FOLDER="res://assets/world/stream_creative110"
func _initialize():run.call_deferred()
func raw_transform(data:PackedFloat32Array,at:int)->Transform3D:
	return Transform3D(Basis(Vector3(data[at],data[at+4],data[at+8]),Vector3(data[at+1],data[at+5],data[at+9]),Vector3(data[at+2],data[at+6],data[at+10])),Vector3(data[at+3],data[at+7],data[at+11]))
func material_kind(node:MultiMeshInstance3D,mesh:BoxMesh)->String:
	if node.material_overlay!=null:return "excluded_overlay"
	var material:Material=node.material_override if node.material_override!=null else mesh.material
	if material is StandardMaterial3D and material.next_pass==null and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not material.grow:return "standard_opaque"
	if material is ShaderMaterial and material.next_pass==null and material.shader!=null and material.shader.resource_path=="res://assets/materials/voxel_surface.gdshader":return "voxel_surface"
	return "excluded_material"
func run():
	if DisplayServer.get_name()!="headless":push_error("Offline inventory only.");quit(2);return
	var batches:Array=[];var inputs:Dictionary={}
	for id in CELLS:
		var path:String=FOLDER+"/cell_"+id+".scn";inputs[id]=FileAccess.get_sha256(path);var cell:Node=load(path).instantiate();root.add_child(cell)
		for node in cell.find_children("*","MultiMeshInstance3D",true,false):
			var mm:MultiMesh=node.multimesh
			if mm==null or not mm.mesh is BoxMesh or mm.transform_format!=MultiMesh.TRANSFORM_3D:continue
			var mesh:BoxMesh=mm.mesh;var stride:int=12+(4 if mm.use_colors else 0)+(4 if mm.use_custom_data else 0);var data:PackedFloat32Array=mm.buffer;var records:Array=[]
			if data.size()!=mm.instance_count*stride:push_error("Missing native records");quit(3);return
			for index in mm.instance_count:
				var transform:Transform3D=node.global_transform*raw_transform(data,index*stride);var bounds:AABB=transform*mesh.get_aabb();var p:Vector3=transform.origin;var a:Vector3=bounds.position;var b:Vector3=bounds.end
				records.append([p.x,p.y,p.z,a.x,a.y,a.z,b.x,b.y,b.z])
			var meta:Dictionary={}
			for key in node.get_meta_list():meta[str(key)]=str(node.get_meta(key))
			batches.append({"cell":id,"name":str(node.name),"count":mm.instance_count,"triangle_per_instance":mesh.get_faces().size()/3,"material":material_kind(node,mesh),"shadow":node.cast_shadow,"visible":node.visible,"margin":node.extra_cull_margin,"has_script":node.get_script()!=null,"children":node.get_child_count(),"has_ref":node.has_meta("stream_ref"),"metadata":meta,"records":records})
		cell.free()
	var result:Dictionary={"scope":"All actual Box transforms including rotated instances in exactly three near cells, CPU serialized records only","cells":CELLS,"input_sha256":inputs,"records_format":"originXYZ,minXYZ,maxXYZ","batches":batches}
	var file:=FileAccess.open("res://.runtime/creative110_castle_batch_inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close();print("CASTLE_BATCH_INVENTORY110 ",batches.size()," batches");quit()
