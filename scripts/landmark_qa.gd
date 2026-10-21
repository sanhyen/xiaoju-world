extends "res://scripts/nature_qa.gd"
## L01 fixed-view evidence and physical access, separate from visual approval.

func find_portrait(node:Node)->MeshInstance3D:
	if node is MeshInstance3D and node.mesh is QuadMesh and node.global_position.distance_to(Vector3(0,10.5,39.44))<0.05:
		var mat=node.material_override
		if mat is StandardMaterial3D and mat.albedo_texture!=null and mat.albedo_texture.resource_path=="res://assets/media/portrait_01.jpg":return node
	for child in node.get_children():
		var found:=find_portrait(child)
		if found!=null:return found
	return null

func visible_boxes()->Array:
	var result:Array=[]
	for node in main.world.find_children("*","MultiMeshInstance3D",true,false):
		if not node.is_visible_in_tree() or not node.multimesh.mesh is BoxMesh:continue
		var mm:MultiMesh=node.multimesh
		var count:int=mm.instance_count if mm.visible_instance_count<0 else mini(mm.instance_count,mm.visible_instance_count)
		for i in count:
			var transform:Transform3D=node.global_transform*mm.get_instance_transform(i)
			if absf(transform.origin.x)>55 or transform.origin.z<38 or transform.origin.z>125:continue
			if absf(transform.basis.determinant())<0.000000001:continue
			result.append({"transform":transform,"inverse":transform.affine_inverse(),"local_box":mm.mesh.get_aabb(),"world_box":transform*mm.mesh.get_aabb(),"node":str(node.get_path()),"instance":i})
	return result

func check_visible_sightlines():
	# Lamps are rendered MultiMesh boxes without collision. Physics rays alone miss them.
	var boxes:=visible_boxes()
	for view in fixed_cameras:
		if view.name not in ["arrival","front","player_scale","left","right"]:continue
		var eye:=Vector3(view.eye[0],view.eye[1],view.eye[2])
		var obstructions:Array=[]
		for face in [Vector3(-1.25,12.9,39.51),Vector3(-0.7,13.5,39.51),Vector3(-0.15,14.1,39.51)]:
			for box in boxes:
				if box.world_box.intersects_segment(eye,face)==null:continue
				var local_hit:Variant=box.local_box.intersects_segment(box.inverse*eye,box.inverse*face)
				if local_hit==null:continue
				var center:Vector3=box.transform.origin
				obstructions.append({"node":box.node,"instance":box.instance,"center":[center.x,center.y,center.z]})
		check("rendered_face_clear_"+str(view.name),obstructions.is_empty(),{"hits":obstructions,"scope":"actual visible BoxMesh instances including non-colliding lamps; three face sample rays, screenshots remain required"})

func run(target):
	main=target;phase="landmark_review"
	fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/landmark_cameras.json"))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=65
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	main.player.position=Vector3(-2,0.2,52);main.player.velocity=Vector3.ZERO
	main.player.figure.rotation.y=PI
	await w.prepare_region(main.player.position)
	var portrait:=find_portrait(w)
	check("real_portrait_mesh_loaded",portrait!=null)
	if portrait!=null:
		var texture:Texture2D=portrait.material_override.albedo_texture
		var size:Vector2=portrait.mesh.size
		check("portrait_16m_proportional",absf(size.y-16)<0.001 and absf(size.x/size.y-float(texture.get_width())/texture.get_height())<0.0001,{"mesh_m":[size.x,size.y],"texture_px":[texture.get_width(),texture.get_height()]})
		check("portrait_faces_south",portrait.global_basis.z.dot(Vector3.BACK)>0.999)
		check("portrait_not_mirrored",portrait.global_basis.determinant()>0 and portrait.mesh.flip_faces==false)
		check("portrait_remains_unshaded",portrait.material_override.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED)
	for view in fixed_cameras:
		main.set_time(int(view.time))
		await capture(view.name,Vector3.ZERO,Vector3.ZERO)
		cameras[-1].time=int(view.time)
	main.set_time(0)
	check_visible_sightlines()
	# Trace toward the visible photo plane, stopping just before it. Exclude avatar.
	await w.prepare_region(Vector3(0,2,70))
	for x in [-5.0,0.0,5.0]:
		for y in [3.0,10.5,18.0]:
			var query:=PhysicsRayQueryParameters3D.create(Vector3(0,2,74),Vector3(x,y,39.50))
			query.exclude=[main.player.get_rid()]
			var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(query)
			check("photo_axis_clear_"+str(Vector2(x,y)),hit.is_empty(),{"hit":str(hit.get("position","none")),"scope":"solid obstacles only; foliage still requires screenshot review"})
	var actions:Dictionary={}
	for action in w.interactions:actions[action.id]=action
	check("original_landmark_actions",actions.has("L01") and actions.has("P01") and actions.has("Z04_REST"))
	if actions.has("L01"):
		main.activate(actions.L01)
		check("source_panel_opens",main.modal.visible and str(main.assets[0].asset_id)=="portrait_01")
		main.close_modal();main.player.enabled=false
	main.player.position=Vector3(0,0.3,120);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	for point in [Vector2(0,81),Vector2(0,69),Vector2(12,52),Vector2(12,32),Vector2(-12,32),Vector2(-12,52),Vector2(0,69)]:
		if not await walk(point):break
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var result:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","scope":"L01 image dimensions, fixed views and ordinary collision movement; screenshots require individual review, not full world acceptance"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
