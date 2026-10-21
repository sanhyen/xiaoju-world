extends SceneTree
func _initialize():
 var report:Dictionary={"version":Engine.get_version_info(),"classes":{}}
 for cname in ["ImporterMesh","ArrayMesh","MultiMesh","MultiMeshInstance3D","GeometryInstance3D","Viewport"]:
  var methods:Array=[];var properties:Array=[]
  for m in ClassDB.class_get_method_list(cname,true):
   if "lod" in str(m.name).to_lower() or "surface" in str(m.name).to_lower() or (cname=="ImporterMesh" and m.name=="get_mesh"):methods.append(m)
  for p in ClassDB.class_get_property_list(cname,true):
   if "lod" in str(p.name).to_lower():properties.append(p)
  report.classes[cname]={"methods":methods,"properties":properties}
 var f:=FileAccess.open("res://reports/creative110_flower_lod_api.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
 print("FLOWER_LOD_API110 ",JSON.stringify(report));quit()
