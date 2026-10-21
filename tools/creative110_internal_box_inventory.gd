extends SceneTree
## Offline serialized-data inventory. Dummy transform getters are deliberately never used.
const Faces=preload("res://scripts/far_box_faces110.gd")
var helper=Faces.new()
func _initialize():run.call_deferred()
func material_kind(node:MultiMeshInstance3D,box:BoxMesh)->String:
 if node.material_overlay!=null:return "unsafe_overlay"
 var material:Material=node.material_override if node.material_override!=null else box.material
 if material is StandardMaterial3D:
  if material.next_pass!=null or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or material.cull_mode!=BaseMaterial3D.CULL_BACK or material.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or material.grow or material.get_flag(BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST):return "unsafe_standard"
  return "standard"
 if material is ShaderMaterial and material.next_pass==null and material.shader!=null and material.shader.resource_path=="res://assets/materials/voxel_surface.gdshader":return "voxel_surface_verified_no_vertex_or_alpha_write"
 return "unsafe_material"
func run():
 var layout=preload("res://scripts/world_layout.gd").new()
 var manifest=load("res://assets/world/stream_creative110/manifest.tres")
 var road:Dictionary=layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
 var records:Array=[];var batches:Array=[];var cells:Array=[];var invalid:Array=[];var totals:Dictionary={"all_mm_instances":0,"all_mm_triangles":0,"box_instances":0,"box_triangles":0,"safe_box_instances":0,"strict_axis_instances":0}
 var started:int=Time.get_ticks_msec()
 for rec in manifest.cells:
  var wanted:=false
  for point in road.points:
   var dx:float=maxf(absf(float(point[0])-rec.center.x)-48,0);var dz:float=maxf(absf(float(point[2])-rec.center.z)-48,0)
   if Vector2(dx,dz).length()<=184:wanted=true;break
  if not wanted:continue
  var source:PackedScene=ResourceLoader.load(rec.path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
  var cell:Node=source.instantiate();root.add_child(cell)
  var info:Dictionary={"id":rec.id,"path":rec.path,"sha256":FileAccess.get_sha256(rec.path),"all_instances":0,"all_triangles":0,"box_instances":0,"safe_axis_instances":0}
  for node in cell.find_children("*","MultiMeshInstance3D",true,false):
   var mm:MultiMesh=node.multimesh
   if mm==null or mm.mesh==null:continue
   var triangles:int=mm.mesh.get_faces().size()/3
   info.all_instances+=mm.instance_count;info.all_triangles+=triangles*mm.instance_count
   totals.all_mm_instances+=mm.instance_count;totals.all_mm_triangles+=triangles*mm.instance_count
   if not mm.mesh is BoxMesh:continue
   info.box_instances+=mm.instance_count;totals.box_instances+=mm.instance_count;totals.box_triangles+=triangles*mm.instance_count
   var box:BoxMesh=mm.mesh;var kind:String=material_kind(node,box)
   if kind.begins_with("unsafe") or not helper.unit_closed_box(box) or node.has_meta("stream_ref") or node.get_script()!=null or node.get_child_count()>0 or mm.transform_format!=MultiMesh.TRANSFORM_3D:continue
   if mm.visible_instance_count>=0 and mm.visible_instance_count<mm.instance_count:continue
   var stride:int=12+(4 if mm.use_colors else 0)+(4 if mm.use_custom_data else 0);var data:PackedFloat32Array=mm.buffer
   if data.size()!=mm.instance_count*stride:invalid.append({"cell":rec.id,"node":str(node.name),"count":mm.instance_count,"buffer_floats":data.size(),"stride":stride});continue
   totals.safe_box_instances+=mm.instance_count
   var batch:int=batches.size()
   batches.append({"cell":rec.id,"name":str(node.name),"count":mm.instance_count,"material":kind,"shadow":node.cast_shadow,"sha256":helper.record_hash(data),"bounds":str(mm.get_aabb())})
   for i in mm.instance_count:
    var at:int=i*stride
    var basis:=Basis(Vector3(data[at],data[at+4],data[at+8]),Vector3(data[at+1],data[at+5],data[at+9]),Vector3(data[at+2],data[at+6],data[at+10]))
    var transform:Transform3D=node.global_transform*Transform3D(basis,Vector3(data[at+3],data[at+7],data[at+11]))
    if not helper.positive_diagonal(transform.basis):continue
    var bounds:AABB=transform*box.get_aabb();var lo:Vector3=bounds.position;var hi:Vector3=bounds.end
    records.append([lo.x,lo.y,lo.z,hi.x,hi.y,hi.z,batch,i])
    totals.strict_axis_instances+=1;info.safe_axis_instances+=1
  cells.append(info);cell.free()
 var report:Dictionary={"scope":"Offline source scene serialized native-buffer inventory, no GPU or performance claim","route":road,"load_radius":184,"cells":cells,"batches":batches,"totals":totals,"invalid_buffers":invalid,"records_format":"minX,minY,minZ,maxX,maxY,maxZ,batchIndex,instanceIndex","records":records,"creative_places":layout.creative_places,"shader_sha256":FileAccess.get_sha256("res://assets/materials/voxel_surface.gdshader"),"elapsed_ms":Time.get_ticks_msec()-started}
 var file:=FileAccess.open("res://.runtime/creative110_internal_box_inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
 print("INTERNAL_BOX_INVENTORY110 ",JSON.stringify({"cells":cells.size(),"batches":batches.size(),"totals":totals,"invalid_buffers":invalid,"elapsed_ms":report.elapsed_ms}));quit(0 if invalid.is_empty() else 1)
