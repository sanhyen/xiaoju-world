extends SceneTree
## CPU-only inventory of the baked scenes used by the native 3.5% cable view.
## Does not start the game, save, bake, change render settings, or write cache scenes.
const FOLDER="res://assets/world/stream_creative110"
const LOADED_IDS=["-1_-1","-1_-2","-1_-3","-1_0","-2_-1","-2_-2","-2_-3","-2_-4","-2_0","-2_1","-3_-1","-3_-2","-3_-3","-3_-4","-3_0","-3_1","-4_-1","-4_-2","-4_-3","-4_-4","-4_0","-5_-1","-5_-2","-5_-3","-5_0"]
const EYE=Vector3(-287.3141,25.92199,-119.7905)
const ROT=Vector3(-.2,-.755625844,0)
var rows:Array=[]
var mesh_cache:Dictionary={}
var groups:Dictionary={}
var buffers:Dictionary={}
var skipped_types:Dictionary={}
var behind_only_nodes:=0

func raw_transform(data:PackedFloat32Array,offset:int)->Transform3D:
	return Transform3D(Basis(Vector3(data[offset],data[offset+4],data[offset+8]),Vector3(data[offset+1],data[offset+5],data[offset+9]),Vector3(data[offset+2],data[offset+6],data[offset+10])),Vector3(data[offset+3],data[offset+7],data[offset+11]))

func _initialize():run.call_deferred()

func mesh_details(mesh:Mesh)->Dictionary:
	var key:int=mesh.get_instance_id()
	if mesh_cache.has(key):return mesh_cache[key]
	var triangles:=0;var vertices:=0;var indexed:=0
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		var count:int=arrays[Mesh.ARRAY_VERTEX].size() if arrays[Mesh.ARRAY_VERTEX]!=null else 0
		var indices:int=arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else 0
		vertices+=count;indexed+=indices;triangles+=(indices if indices>0 else count)/3
	var detail:Dictionary={"class":mesh.get_class(),"triangles":triangles,"vertices":vertices,"indices":indexed,"resource":mesh.resource_path,"surface_count":mesh.get_surface_count()}
	if mesh is CylinderMesh:detail.parameters={"radial":mesh.radial_segments,"rings":mesh.rings,"top":mesh.top_radius,"bottom":mesh.bottom_radius,"height":mesh.height}
	if mesh is SphereMesh:detail.parameters={"radial":mesh.radial_segments,"rings":mesh.rings}
	if mesh is BoxMesh:detail.parameters={"size":mesh.size,"subdivide":[mesh.subdivide_width,mesh.subdivide_height,mesh.subdivide_depth]}
	mesh_cache[key]=detail;return detail

func camera_intersects(box:AABB)->bool:
	# Analytic perspective planes at the actual verified player camera. Conservative
	# whole-batch AABB rejection, not triangle or occlusion visibility.
	var inverse:=Basis.from_euler(ROT).inverse();var corners:Array=[]
	for i in 8:corners.append(inverse*(box.get_endpoint(i)-EYE))
	var tangent:float=tan(deg_to_rad(66)*.5);var horizontal:float=tangent*1920.0/1080.0
	for plane in 6:
		var outside:=true
		for p:Vector3 in corners:
			var distance:float=-p.z
			var pass_plane:bool=distance>=.2 if plane==0 else distance<=12000 if plane==1 else p.x<=distance*horizontal if plane==2 else -p.x<=distance*horizontal if plane==3 else p.y<=distance*tangent if plane==4 else -p.y<=distance*tangent
			if pass_plane:outside=false;break
		if outside:return false
	return true

func material_description(node:GeometryInstance3D,mesh:Mesh)->String:
	var material:Material=node.material_override
	if material==null and node is MeshInstance3D:material=node.get_active_material(0)
	if material==null:material=mesh.surface_get_material(0)
	if material is ShaderMaterial:return "shader:"+material.shader.resource_path.get_file()
	if material is StandardMaterial3D:return "standard:transparent="+str(material.transparency)+":cull="+str(material.cull_mode)
	return "null"

func visit(node:Node,frame:Transform3D,shown:bool,scope:String,cell:String,path:String):
	if node is Node3D:frame=frame*node.transform;shown=shown and node.visible
	path+="/"+str(node.name)
	if node is GeometryInstance3D:
		var mesh:Mesh;var instances:=1;var aabb:=AABB();var mm:MultiMesh
		if node is MultiMeshInstance3D:
			mm=node.multimesh
			if mm!=null:
				mesh=mm.mesh;instances=mm.instance_count if mm.visible_instance_count<0 else mini(mm.instance_count,mm.visible_instance_count)
				# Dummy RenderingServer does not calculate MultiMesh bounds after loading.
				# Its serialized transform buffer is readable; derive the identical union.
				var local_bounds:AABB=mm.custom_aabb
				var source_buffer:PackedFloat32Array=mm.buffer
				var source_stride:int=12+(4 if mm.use_colors else 0)+(4 if mm.use_custom_data else 0)
				if local_bounds.size==Vector3.ZERO and mesh!=null:
					for index in instances:
						var instance_bounds:AABB=raw_transform(source_buffer,index*source_stride)*mesh.get_aabb()
						local_bounds=instance_bounds if index==0 else local_bounds.merge(instance_bounds)
				aabb=frame*local_bounds
		elif node is MeshInstance3D and node.mesh!=null:mesh=node.mesh;aabb=frame*mesh.get_aabb()
		if mesh!=null:
			var info:Dictionary=mesh_details(mesh)
			var terrain:bool=node.has_meta("stream_terrain") or str(node.name).begins_with("FarStrata_") or str(node.name).begins_with("TerrainStrata_")
			var kind:String="terrain" if terrain else "multimesh_"+info["class"] if mm!=null else "direct_"+info["class"]
			var in_view:bool=shown and camera_intersects(aabb)
			var shadow:bool=node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var key:String=scope+":"+kind
			if not groups.has(key):groups[key]={"nodes":0,"instances":0,"triangles":0,"visible_nodes":0,"visible_instances":0,"visible_triangles":0,"camera_batch_nodes":0,"camera_batch_instances":0,"camera_batch_triangles":0,"shadow_eligible_triangles":0,"shadow_eligible_instances":0}
			var group:Dictionary=groups[key];group.nodes+=1;group.instances+=instances;group.triangles+=info.triangles*instances
			if shown:group.visible_nodes+=1;group.visible_instances+=instances;group.visible_triangles+=info.triangles*instances
			if in_view:group.camera_batch_nodes+=1;group.camera_batch_instances+=instances;group.camera_batch_triangles+=info.triangles*instances
			if shown and shadow:group.shadow_eligible_triangles+=info.triangles*instances;group.shadow_eligible_instances+=instances
			var record:Dictionary={"scope":scope,"cell":cell,"path":path,"kind":kind,"class":info["class"],"instances":instances,"triangles_per_instance":info.triangles,"triangles":info.triangles*instances,"visible":shown,"camera_batch_visible":in_view,"shadow_mode":node.cast_shadow,"aabb":aabb,"material":material_description(node,mesh),"mesh_parameters":info.get("parameters",{}),"mesh_resource":info.resource}
			if mm!=null:
				var stride:int=(12 if mm.transform_format==MultiMesh.TRANSFORM_3D else 8)+(4 if mm.use_colors else 0)+(4 if mm.use_custom_data else 0)
				var buffer:PackedFloat32Array=mm.buffer
				record.buffer_floats=buffer.size();record.expected_floats=mm.instance_count*stride
				record.first_record=Array(buffer.slice(0,stride))
				buffers["ok" if buffer.size()==mm.instance_count*stride else "unavailable"]=int(buffers.get("ok" if buffer.size()==mm.instance_count*stride else "unavailable",0))+1
				if shown and info["class"]=="SphereMesh":
					var scales:Dictionary={};var duplicate:Dictionary={};var duplicate_instances:=0
					for index in instances:
						var transform:Transform3D=raw_transform(buffer,index*stride);var scale:Vector3=transform.basis.get_scale()
						var scale_key:String="%.3f,%.3f,%.3f"%[scale.x,scale.y,scale.z]
						scales[scale_key]=int(scales.get(scale_key,0))+1
						var transform_key:String=str(transform)+":"+str(buffer.slice(index*stride+12,(index+1)*stride))
						if duplicate.has(transform_key):duplicate_instances+=1
						else:duplicate[transform_key]=true
					record.scale_counts=scales;record.exact_duplicate_instances=duplicate_instances
			rows.append(record)
		else:skipped_types[node.get_class()]=int(skipped_types.get(node.get_class(),0))+1
	for child in node.get_children():visit(child,frame,shown,scope,cell,path)

func inventory_scene(path:String,scope:String,cell:String,shown:bool=true):
	var packed:PackedScene=load(path);var scene:Node=packed.instantiate()
	visit(scene,Transform3D.IDENTITY,shown,scope,cell,"")
	scene.free()

func run():
	if DisplayServer.get_name()!="headless":push_error("Inventory is offline/headless only");quit(2);return
	var reference:Dictionary={};var reference_path:String="res://reports/creative110_flower_cluster_probe_variants.json"
	if FileAccess.file_exists(reference_path):reference=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	var native_ids:Array=reference.get("loaded_ids",[]).duplicate();native_ids.sort();var expected_ids:Array=LOADED_IDS.duplicate();expected_ids.sort()
	var loaded_evidence:String="25-cell set reconstructed from stream retention; full historical membership not captured."
	if native_ids==expected_ids:loaded_evidence="Verified identical to all 25 loaded IDs captured in the fixed native 3.5% cable flower-cluster GPU probe; each stage asserted the same camera/player pose."
	var input_hashes:Dictionary={}
	for id in LOADED_IDS:input_hashes[id]=FileAccess.get_sha256(FOLDER+"/cell_"+id+".scn")
	for file in ["global.scn","far.scn","manifest.tres"]:input_hashes[file]=FileAccess.get_sha256(FOLDER+"/"+file)
	for id in LOADED_IDS:inventory_scene(FOLDER+"/cell_"+id+".scn","near",id)
	inventory_scene(FOLDER+"/global.scn","global","")
	var far:Node=load(FOLDER+"/far.scn").instantiate();root.add_child(far)
	var camera:=Camera3D.new();root.add_child(camera);camera.transform=Transform3D(Basis.from_euler(ROT),EYE)
	var far_faces=load("res://scripts/far_box_faces110.gd").new();far_faces.bind(far);far_faces.update(camera)
	var far_diagnostics:Dictionary=far_faces.diagnostics()
	for cell in far.get_children():
		var id:String=str(cell.name).trim_prefix("Far_")
		visit(cell,Transform3D.IDENTITY,not id in LOADED_IDS,"far",id,"/"+str(far.name))
	far.free();camera.free()
	rows.sort_custom(func(a,b):return int(a.triangles)>int(b.triangles))
	var report:Dictionary={"scope":"CPU baked-resource inventory only. Camera counts are conservative whole-AABB frustum submission estimates. Shadow counts indicate original cast eligibility, not measured PSSM pass count or GPU time. Runtime cabins/avatar are not in these baked resources.","loaded_set_evidence":loaded_evidence,"reference_gpu_report":reference_path,"reference_gpu_backend":"D3D12 Mobile; prior to subsequent Vulkan default change","input_sha256":input_hashes,"loaded_ids":LOADED_IDS,"eye":EYE,"rotation":ROT,"far_backface_masks_applied":far_diagnostics,"groups":groups,"buffer_readability":buffers,"skipped_geometry_types":skipped_types,"rows":rows,"normal_saves":"not loaded, no gameplay scene started"}
	var file:=FileAccess.open("res://reports/creative110_cable_geometry_inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CABLE_GEOMETRY110 ",JSON.stringify({"groups":groups,"buffers":buffers,"top_nodes":rows.slice(0,15)}))
	quit()
