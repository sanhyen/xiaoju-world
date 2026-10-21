extends SceneTree
const Model=preload("res://tools/flower_lod_model110.gd")
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1920,1080)
 var source:=SphereMesh.new();source.radius=.5;source.height=1;source.radial_segments=8;source.rings=3
 var model=Model.new();var full:Dictionary=model.build(source,true);var approximate:Dictionary=model.build(source,false)
 var report:Dictionary=full.duplicate();report.erase("mesh");report.erase("source")
 var camera:=Camera3D.new();root.add_child(camera);camera.fov=70;camera.make_current()
 var bound:=AABB(Vector3(-8,-5,-110),Vector3(16,10,20));var error:float=full.levels[0].certified_local_error
 var perspective:Dictionary=model.native_bias(bound,camera,Vector2(1920,1080),.25,Basis.IDENTITY)
 var actual_error:float=error*.25*perspective.projection.pixels_per_world_unit
 var engine_error:float=error*perspective.bias*perspective.projection.engine_focal_pixels/perspective.projection.engine_distance
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=150
 var orthographic:Dictionary=model.native_bias(bound,camera,Vector2(1920,1080),.25,Basis.IDENTITY)
 var ortho_error:float=error*.25*orthographic.projection.pixels_per_world_unit
 var ortho_engine:float=error*orthographic.bias*orthographic.projection.engine_focal_pixels
 var full_mesh:ArrayMesh=full.mesh;var shadow:Array=full_mesh.shadow_mesh.call("_get_surfaces")[0].lods
 var full_shadow:bool=shadow.size()==2
 for i in range(1,shadow.size(),2):
  var indices=shadow[i]
  full_shadow=full_shadow and ((indices is PackedInt32Array and indices.size()==144) or (indices is PackedByteArray and indices.size()==144*2))
 var checks:Array=[
  {"test":"only_closed_convex_32_level_accepted_16_and_8_rejected","passed":full.ok and full.levels.size()==3 and full.levels[0].accepted and not full.levels[1].accepted and not full.levels[2].accepted},
  {"test":"decoded_vertex_normal_tangent_uv_preserved_not_native_vbo_claim","passed":full.decoded_attributes_preserved and not full.native_vbo_bytes_verified},
  {"test":"same_source_shape_custom_aabb","passed":full_mesh.get_aabb()==source.get_aabb()},
  {"test":"full_48_effective_triangles_at_near_lod","passed":full.full_effective_triangles==48 and full_mesh.surface_get_array_index_len(0)==144},
  {"test":"full_shadow_reference_and_matching_full_geometry_lod_level","passed":full_mesh.shadow_mesh!=null and full_shadow},
  {"test":"perspective_bias_enforces_actual_quarter_pixel_test","passed":absf(engine_error-actual_error/Model.PIXEL_BUDGET)<.00001},
  {"test":"orthographic_bias_enforces_actual_quarter_pixel_test","passed":absf(ortho_engine-ortho_error/Model.PIXEL_BUDGET)<.00001},
  {"test":"orthogonal_nonuniform_scale_operator_bound","passed":is_equal_approx(model.scale_bound(Basis.IDENTITY.scaled(Vector3(.1,.3,.2))),.3)},
  {"test":"shadow_reduction_is_not_misreported_as_certified","passed":not approximate.shadow_error_certified}
 ]
 report["checks"]=checks;report["ok"]=full.ok and checks.all(func(check):return check.passed);report["scope"]="Offline actual engine API and geometry/projection certificates; not a native GPU or rendered shadow/pixel test";report["pixel_budget"]=Model.PIXEL_BUDGET
 report["projection_example"]={"perspective":perspective,"geometric_error_pixels":actual_error,"engine_error_pixels":engine_error,"orthographic":orthographic,"orthographic_error_pixels":ortho_error}
 report["shadow_lod_serialized_structure"]=shadow
 report["official_sources"]=["https://docs.godotengine.org/en/latest/tutorials/3d/mesh_lod.html","https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/storage_rd/mesh_storage.h","https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/renderer_rd/forward_mobile/render_forward_mobile.cpp"]
 var file:=FileAccess.open("res://reports/creative110_flower_lod_certificate.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 print("FLOWER_LOD_CERTIFICATE110 ",JSON.stringify({"ok":report.ok,"levels":full.levels,"checks":checks,"projection":report.projection_example}));camera.free();quit(0 if report.ok else 1)
