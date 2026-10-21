extends RefCounted
## Independent candidate only. No production hooks, instance changes or quality settings.
const PIXEL_BUDGET=.25
const NUMERICAL_PADDING=.00001
const TOPOLOGY_WELD=.000001
var bundles:Dictionary={}

func closest_triangle(point:Vector3,a:Vector3,b:Vector3,c:Vector3)->Vector3:
	var ab:Vector3=b-a;var ac:Vector3=c-a;var ap:Vector3=point-a
	var d1:float=ab.dot(ap);var d2:float=ac.dot(ap)
	if d1<=0 and d2<=0:return a
	var bp:Vector3=point-b;var d3:float=ab.dot(bp);var d4:float=ac.dot(bp)
	if d3>=0 and d4<=d3:return b
	var vc:float=d1*d4-d3*d2
	if vc<=0 and d1>=0 and d3<=0:return a+ab*(d1/(d1-d3))
	var cp:Vector3=point-c;var d5:float=ab.dot(cp);var d6:float=ac.dot(cp)
	if d6>=0 and d5<=d6:return c
	var vb:float=d5*d2-d1*d6
	if vb<=0 and d2>=0 and d6<=0:return a+ac*(d2/(d2-d6))
	var va:float=d3*d6-d5*d4
	if va<=0 and d4-d3>=0 and d5-d6>=0:return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)))
	var inverse:float=1.0/(va+vb+vc)
	return a+ab*(vb*inverse)+ac*(vc*inverse)

func strict_zero_indices(arrays:Array)->PackedInt32Array:
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var original:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var result:=PackedInt32Array()
	for at in range(0,original.size(),3):
		var a:Vector3=vertices[original[at]];var b:Vector3=vertices[original[at+1]];var c:Vector3=vertices[original[at+2]]
		var same_normal:bool=(a==b and normals[original[at]]==normals[original[at+1]]) or (b==c and normals[original[at+1]]==normals[original[at+2]]) or (c==a and normals[original[at+2]]==normals[original[at]])
		if (b-a).cross(c-a)==Vector3.ZERO and same_normal:continue
		result.append(original[at]);result.append(original[at+1]);result.append(original[at+2])
	return result

func shell_certificate(vertices:PackedVector3Array,indices:PackedInt32Array)->Dictionary:
	var unique:Dictionary={};var edges:Dictionary={};var triangles:Array=[];var failures:Array=[]
	for at in range(0,indices.size(),3):
		var a:Vector3=vertices[indices[at]];var b:Vector3=vertices[indices[at+1]];var c:Vector3=vertices[indices[at+2]]
		if (b-a).cross(c-a).length_squared()<.000000000000001:continue
		triangles.append([a,b,c])
		for v in [a,b,c]:unique[v.snapped(Vector3.ONE*TOPOLOGY_WELD)]=true
		for pair in [[a,b],[b,c],[c,a]]:
			var start:Vector3=pair[0].snapped(Vector3.ONE*TOPOLOGY_WELD);var end:Vector3=pair[1].snapped(Vector3.ONE*TOPOLOGY_WELD)
			var key:String=(str(start)+":"+str(end)) if str(start)<str(end) else (str(end)+":"+str(start))
			edges[key]=int(edges.get(key,0))+1
	var convex_residual:=0.0;var center:=Vector3.ZERO
	for point in unique:center+=point
	if not unique.is_empty():center/=unique.size()
	for triangle in triangles:
		var normal:Vector3=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
		if normal.dot(triangle[0]-center)<0:normal=-normal
		for point in unique:convex_residual=maxf(convex_residual,normal.dot(point-triangle[0]))
	var closed:bool=not edges.is_empty() and edges.values().all(func(count):return count==2)
	if not closed:failures.append("not_closed_after_micrometre_topology_match")
	if convex_residual>TOPOLOGY_WELD*4:failures.append("nonconvex_shell")
	var maximum_distance:=0.0
	if failures.is_empty():
		# Distance to a convex body is convex. Its maximum on the source convex
		# polytope occurs at a source vertex. The candidate uses source vertices,
		# so its hull is contained in the original hull in every viewing direction.
		for point in vertices:
			var distance:=INF
			for triangle in triangles:distance=minf(distance,point.distance_to(closest_triangle(point,triangle[0],triangle[1],triangle[2])))
			maximum_distance=maxf(maximum_distance,distance)
	return {"accepted":failures.is_empty(),"triangles":triangles.size(),"closed":closed,"convex_plane_residual":convex_residual,"maximum_source_vertex_distance":maximum_distance if failures.is_empty() else -1.0,"certified_local_error":maximum_distance+NUMERICAL_PADDING if failures.is_empty() else -1.0,"padding":NUMERICAL_PADDING,"topology_match_tolerance":TOPOLOGY_WELD,"failures":failures}

func build(sphere:SphereMesh,full_shadow:bool=true)->Dictionary:
	var cache_key:String=str(sphere.get_instance_id())+":"+str(full_shadow)
	if bundles.has(cache_key):return bundles[cache_key]
	if sphere.radial_segments!=8 or sphere.rings!=3 or sphere.radius!=.5 or sphere.height!=1 or sphere.is_hemisphere:return {"ok":false,"reason":"candidate_only_certifies_original_unit_Sphere8_rings3"}
	var arrays:Array=sphere.get_mesh_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var full:PackedInt32Array=strict_zero_indices(arrays)
	var base:Dictionary=shell_certificate(vertices,full)
	if not base.accepted:return {"ok":false,"reason":"source_shell_is_not_closed_convex","base":base}
	var importer:=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays);importer.generate_lods(0,0,[])
	var lods:Dictionary={};var shadow_lods:Dictionary={};var certificates:Array=[]
	for index in importer.get_surface_lod_count(0):
		var indices:PackedInt32Array=importer.get_surface_lod_indices(0,index)
		var proof:Dictionary=shell_certificate(vertices,indices)
		proof["importer_error_key"]=importer.get_surface_lod_size(0,index)
		if proof.accepted:
			var error:float=proof.certified_local_error
			lods[error]=indices;shadow_lods[error]=full
		certificates.append(proof)
	var copy:Array=arrays.duplicate();copy[Mesh.ARRAY_INDEX]=full
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copy,[],lods);mesh.custom_aabb=sphere.get_aabb();mesh.surface_set_material(0,sphere.material)
	if full_shadow:
		# Renderer selects the main surface's LOD index for the shadow surface.
		# Supply matching levels that all retain the exact original effective faces.
		# Godot requires every LOD index count to be less than its base count.
		# One repeated single vertex is strictly zero-area even after normal bias.
		var shadow_arrays:Array=copy.duplicate();var shadow_base:PackedInt32Array=full.duplicate()
		for i in 3:shadow_base.append(full[0])
		shadow_arrays[Mesh.ARRAY_INDEX]=shadow_base
		var shadow:=ArrayMesh.new();shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,shadow_arrays,[],shadow_lods);shadow.custom_aabb=sphere.get_aabb();mesh.shadow_mesh=shadow
	var same_attributes:=true;var actual:Array=mesh.surface_get_arrays(0)
	for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV]:same_attributes=same_attributes and actual[attribute]==arrays[attribute]
	var result:Dictionary={"ok":same_attributes and not lods.is_empty(),"mesh":mesh,"source":sphere,"raw_triangles":arrays[Mesh.ARRAY_INDEX].size()/3,"full_effective_triangles":full.size()/3,"source_shell":base,"levels":certificates,"decoded_attributes_preserved":same_attributes,"native_vbo_bytes_verified":false,"full_shadow_geometry_at_every_lod":full_shadow,"shadow_error_certified":false,"bounds":sphere.get_aabb()}
	bundles[cache_key]=result;return result

func scale_bound(basis:Basis)->float:
	# sqrt(||A^T A||_infinity) bounds the spectral norm and is exact for
	# orthogonal scaled axes. It also remains conservative with shear.
	var columns:Array=[basis.x,basis.y,basis.z];var maximum:=0.0
	for i in 3:
		var sum:=0.0
		for j in 3:sum+=absf(columns[i].dot(columns[j]))
		maximum=maxf(maximum,sum)
	return sqrt(maximum)

func projection_bound(world_bounds:AABB,camera:Camera3D,buffer_size:Vector2)->Dictionary:
	var projection:Projection=camera.get_camera_projection()
	var fx:float=absf(projection.x.x)*buffer_size.x*.5;var fy:float=absf(projection.y.y)*buffer_size.y*.5
	if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:return {"ok":true,"pixels_per_world_unit":maxf(fx,fy),"engine_distance":1.0,"engine_focal_pixels":fx}
	if camera.projection!=Camera3D.PROJECTION_PERSPECTIVE:return {"ok":false,"reason":"unsupported_projection"}
	var view_bounds:AABB=camera.global_transform.affine_inverse()*world_bounds
	var minimum_depth:float=-view_bounds.end.z
	if minimum_depth<=camera.near:return {"ok":false,"reason":"near_plane_or_behind_camera_requires_full_detail"}
	var max_x:float=maxf(absf(view_bounds.position.x),absf(view_bounds.end.x));var max_y:float=maxf(absf(view_bounds.position.y),absf(view_bounds.end.y))
	var lipschitz:float=maxf(fx,fy)/minimum_depth*sqrt(1.0+(max_x*max_x+max_y*max_y)/(minimum_depth*minimum_depth))
	var eye:Vector3=camera.global_position;var nearest:=Vector3(maxf(world_bounds.position.x,minf(world_bounds.end.x,eye.x)),maxf(world_bounds.position.y,minf(world_bounds.end.y,eye.y)),maxf(world_bounds.position.z,minf(world_bounds.end.z,eye.z)))
	return {"ok":true,"pixels_per_world_unit":lipschitz,"minimum_depth":minimum_depth,"engine_distance":eye.distance_to(nearest),"engine_focal_pixels":fx}

func native_bias(world_bounds:AABB,camera:Camera3D,buffer_size:Vector2,maximum_world_scale:float,node_basis:Basis,viewport_threshold:float=1.0)->Dictionary:
	var bound:Dictionary=projection_bound(world_bounds,camera,buffer_size)
	var node_scale:float=maxf(node_basis.x.length(),maxf(node_basis.y.length(),node_basis.z.length()))
	if not bound.ok or node_scale<=0 or viewport_threshold<=0:return {"ok":false,"bias":1000000000000.0,"reason":bound.get("reason","invalid_scale_or_threshold")}
	# Native test is error*node_scale*bias*focal/distance <= threshold_px.
	# This bias makes it equivalent to the conservative geometric projection
	# test error*maximum_world_scale*Lipschitz <= 0.25 physical render pixels.
	var bias:float=maximum_world_scale/node_scale*bound.pixels_per_world_unit*bound.engine_distance/bound.engine_focal_pixels*viewport_threshold/PIXEL_BUDGET
	return {"ok":true,"bias":maxf(bias,.000001),"projection":bound,"pixel_budget":PIXEL_BUDGET,"maximum_world_scale":maximum_world_scale}
