extends SceneTree
## Independent offline LOD candidate; no production or GPU changes.
func _initialize():run.call_deferred()
func run():
 var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=8;sphere.rings=3
 var arrays:Array=sphere.get_mesh_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var valid:=0
 for at in range(0,indices.size(),3):
  if (vertices[indices[at+1]]-vertices[indices[at]]).cross(vertices[indices[at+2]]-vertices[indices[at]]).length_squared()>1e-15:valid+=1
 var levels:Array=[]
 for angle in [0.0,25.0,60.0,180.0]:
  var importer:=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays);importer.generate_lods(angle,0,[])
  var report:Dictionary={"normal_merge_angle":angle,"lod_count":importer.get_surface_lod_count(0),"levels":[]}
  for i in importer.get_surface_lod_count(0):
   var lod:PackedInt32Array=importer.get_surface_lod_indices(0,i)
   report.levels.append({"size":importer.get_surface_lod_size(0,i),"indices":Array(lod),"triangles":lod.size()/3})
  var mesh:ArrayMesh=importer.get_mesh()
  report["source_vertex_array_preserved"]=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==vertices
  report["source_normals_preserved"]=mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]==arrays[Mesh.ARRAY_NORMAL]
  report["surface_dictionary_keys"]=mesh.call("_get_surfaces")[0].keys()
  levels.append(report)
 var report:Dictionary={"scope":"Independent offline API and simplification data only","source_vertices":Array(vertices).map(func(v):return [v.x,v.y,v.z]),"source_indices":Array(indices),"source_raw_triangles":indices.size()/3,"source_nondegenerate_triangles":valid,"levels":levels}
 var file:=FileAccess.open("res://reports/creative110_flower_lod_candidate.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 print("FLOWER_LOD_CANDIDATE110 ",JSON.stringify(report));quit()
