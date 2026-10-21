extends SceneTree
const Model=preload("res://tools/flower_lod_model110.gd")
var model=Model.new()
func _initialize():run.call_deferred()
func transform_from_report(value:String)->Transform3D:
 var regex:=RegEx.new();regex.compile("-?[0-9]+(?:\\.[0-9]+)?(?:e[+-]?[0-9]+)?")
 var values:Array=[]
 for found in regex.search_all(value):values.append(float(found.get_string()))
 return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
func potentially_visible(bounds:AABB,camera:Camera3D)->bool:
 var space:AABB=camera.global_transform.affine_inverse()*bounds
 if space.position.z> -camera.near:return false
 if space.end.z>=-camera.near:return true
 var p:Projection=camera.get_camera_projection();var min_x:=INF;var max_x:=-INF;var min_y:=INF;var max_y:=-INF
 for i in 8:
  var v:Vector3=space.get_endpoint(i);var out:Vector4=p*Vector4(v.x,v.y,v.z,1)
  min_x=minf(min_x,out.x/out.w);max_x=maxf(max_x,out.x/out.w);min_y=minf(min_y,out.y/out.w);max_y=maxf(max_y,out.y/out.w)
 return not (min_x>1 or max_x< -1 or min_y>1 or max_y< -1)
func run():
 root.size=Vector2i(1920,1080)
 var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/creative110_backend_vulkan.json"))
 var parts:Array=[];var originals:=0
 for id in ["-3_-2","-3_-3"]:
  var cell=load("res://assets/world/stream_creative110/cell_"+id+".scn").instantiate();root.add_child(cell)
  var sources:Array=cell.get_meta("dense_flora110_sources",[])
  for node in cell.find_children("*","MultiMeshInstance3D",true,false):
   if not node.has_meta("dense_flora110_group"):continue
   var group:int=node.get_meta("dense_flora110_group");var source:Mesh=sources[group].mesh
   if not source is SphereMesh:continue
   var mm:MultiMesh=node.multimesh;var raw:PackedFloat32Array=mm.buffer;var stride:int=12+(4 if mm.use_colors else 0)+(4 if mm.use_custom_data else 0)
   if raw.size()!=stride*mm.instance_count:push_error("Missing serialized buffer");quit(1);return
   var scale:=0.0
   for at in range(0,raw.size(),stride):
    var basis:=Basis(Vector3(raw[at],raw[at+4],raw[at+8]),Vector3(raw[at+1],raw[at+5],raw[at+9]),Vector3(raw[at+2],raw[at+6],raw[at+10]))
    scale=maxf(scale,model.scale_bound(node.global_basis*basis))
   parts.append({"cell":id,"node":str(node.name),"instances":mm.instance_count,"maximum_world_scale":scale,"bounds":node.global_transform*mm.custom_aabb,"shadow":node.cast_shadow});originals+=mm.instance_count
  cell.free()
 var cases:Dictionary={};var local_error:=.08456098
 for name in ["castle","cable","home"]:
  var pose:Dictionary=reference.camera_poses[name];var camera:=Camera3D.new();root.add_child(camera);camera.global_transform=transform_from_report(pose.camera);camera.fov=66;camera.near=.2;camera.far=12000;camera.projection=int(pose.projection)
  if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:camera.size=float(pose.extent)
  var totals:Dictionary={"all_subbatches":parts.size(),"all_sphere_instances":originals,"eligible_subbatches":0,"eligible_instances":0,"potentially_visible_subbatches":0,"potentially_visible_instances":0,"visible_eligible_subbatches":0,"visible_eligible_instances":0,"main_pass_triangle_saving":0,"shadows_triangle_saving":0,"details":[]}
  for part in parts:
   var bound:Dictionary=model.projection_bound(part.bounds,camera,Vector2(1920,1080));var pixels:float=local_error*part.maximum_world_scale*float(bound.get("pixels_per_world_unit",INF))
   var visible:bool=potentially_visible(part.bounds,camera);var eligible:bool=bound.ok and pixels<=.249
   if eligible:totals.eligible_subbatches+=1;totals.eligible_instances+=int(part.instances)
   if visible:totals.potentially_visible_subbatches+=1;totals.potentially_visible_instances+=int(part.instances)
   if visible and eligible:totals.visible_eligible_subbatches+=1;totals.visible_eligible_instances+=int(part.instances);totals.main_pass_triangle_saving+=int(part.instances)*16
   totals.details.append({"cell":part.cell,"node":part.node,"instances":part.instances,"scale":part.maximum_world_scale,"error_px_bound":pixels,"potentially_visible":visible,"eligible":eligible})
  cases[name]=totals;camera.free()
 var report:Dictionary={"scope":"Offline actual 24m production flora subbatch counts, 1920x1080 actual reported camera transforms rounded to six decimals; no GPU/performance claim","candidate":"48 effective faces -> only certified convex32tri, 0.08456098 local error including numerical pad; 16/8 rejected","camera_source":"res://reports/creative110_backend_vulkan.json","pixel_budget":.25,"trigger_safety_margin":.001,"cases":cases,"shadow":"Full geometry retained. No reduction or unproved shadowtexel guarantee.","note":"Potentially visible is conservative AABB projection. Counts above are upper bounds on saved main-pass triangles, not measured speedup."}
 var file:=FileAccess.open("res://reports/creative110_flower_lod_trigger_counts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 for name in cases:var brief:Dictionary=cases[name].duplicate();brief.erase("details");print("FLOWER_LOD_TRIGGER110 ",name," ",JSON.stringify(brief))
 quit()
