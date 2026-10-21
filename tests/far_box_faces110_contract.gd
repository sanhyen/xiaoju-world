extends SceneTree
const Production=preload("res://scripts/far_box_faces110.gd")
func _initialize():run.call_deferred()

func run():
	var candidate:=Production.new();var box:=BoxMesh.new();box.size=Vector3.ONE
	var arrays:Array=box.get_mesh_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var bounds:=AABB(Vector3(-16,-8,-16),Vector3(32,16,32));var all_faces_safe:=true;var visible_unchanged:=true;var tested:=0;var failures:Array=[]
	var instances:Array=[Transform3D(Basis.IDENTITY.scaled(Vector3(.8,2,1)),Vector3(-12,-5,-10)),Transform3D(Basis.IDENTITY.scaled(Vector3(2,.25,3)),Vector3(7,4,8)),Transform3D.IDENTITY]
	for orthographic in [false,true]:
		for eye in [Vector3(40,30,50),Vector3(-40,30,-50),Vector3(0,40,0),Vector3.ZERO,Vector3(16.01,0,0)]:
			var backward:Vector3=eye.normalized()
			var mask:int=candidate.face_mask(bounds,eye,orthographic,backward)
			for transform in instances:
				for triangle in indices.size()/3:
					var at:int=triangle*3;var bit:int=candidate.triangle_face(vertices,indices,at)
					var normal:Vector3=(transform.basis.inverse().transposed()*candidate.geometric_normal(bit)).normalized()
					var facing:float=normal.dot(backward if orthographic else eye-transform*vertices[indices[at]])
					var removed:bool=bit!=0 and (mask&bit)==0
					if removed and facing>=0 and failures.size()<8:failures.append({"ortho":orthographic,"eye":eye,"mask":mask,"normal":normal,"source_normal":normals[indices[at]],"vertex":transform*vertices[indices[at]],"facing":facing})
					all_faces_safe=all_faces_safe and (not removed or facing<0)
					visible_unchanged=visible_unchanged and (facing<0 or not removed);tested+=1
	var unchanged_attributes:=true
	for mask in range(1,64):
		var mesh:Mesh=candidate.face_mesh(box,mask)
		var result:Array=mesh.surface_get_arrays(0)
		for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV]:unchanged_attributes=unchanged_attributes and result[attribute]==arrays[attribute]
	var checks:Array=[
		{"test":"removed_triangles_are_strict_backfaces_for_all_instances","passed":all_faces_safe,"tested_triangles":tested},
		{"test":"all_original_frontfacing_triangles_retained","passed":visible_unchanged},
		{"test":"full_vertex_normal_tangent_uv_attributes_unchanged","passed":unchanged_attributes},
		{"test":"inside_eye_keeps_all_faces","passed":candidate.face_mask(bounds,Vector3.ZERO,false,Vector3.ZERO)==63},
		{"test":"zero_orthographic_components_keep_both_axis_faces","passed":(candidate.face_mask(bounds,Vector3.ZERO,true,Vector3.UP)&51)==51},
		{"test":"rotation_negative_scale_and_shear_rejected","passed":not candidate.positive_diagonal(Basis(Vector3.UP,.2)) and not candidate.positive_diagonal(Basis.IDENTITY.scaled(Vector3(-1,1,1))) and not candidate.positive_diagonal(Basis(Vector3(1,.01,0),Vector3.UP,Vector3.BACK))}
	]
	var report:Dictionary={"scope":"Production helper CPU geometry proof only; no GPU or native persistence claim","checks":checks,"failures":failures,"margin_m":Production.MARGIN,"ortho_direction_epsilon":Production.DIRECTION_EPSILON}
	var file:=FileAccess.open("res://reports/creative110_far_box_faces_production_contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOX_FACES_CONTRACT110 ",JSON.stringify(report));quit(0 if checks.all(func(check):return check.passed) else 1)
