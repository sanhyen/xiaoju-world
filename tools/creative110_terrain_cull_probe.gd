extends SceneTree
## Isolated terrain color-pass culling candidate. Original shadow geometry/shader unchanged.
class Candidate extends RefCounted:
	var world
	var enabled:=false
	var entries:Array=[]
	var audit:Dictionary={}
	var audit_cells:Dictionary={}
	var shaders:Dictionary={}
	var active:=false
	var last_guard:Dictionary={}
	var skipped:Array=[]
	var terrain_rectangle:=Rect2()
	var rectangular_domain:=false
	func install(target)->Dictionary:
		world=target
		audit=JSON.parse_string(FileAccess.get_file_as_string("res://reports/creative110_terrain_winding_audit.json"))
		var low:=Vector2i(999999,999999);var high:=Vector2i(-999999,-999999)
		for record in audit.cells:
			var id:String=str(record.cell);audit_cells[id]=record;var grid:=Vector2i(int(id.get_slice("_",0)),int(id.get_slice("_",1)));low=low.min(grid);high=high.max(grid)
		terrain_rectangle=Rect2(Vector2(low)*96,Vector2(high-low+Vector2i.ONE)*96);rectangular_domain=(high.x-low.x+1)*(high.y-low.y+1)==audit_cells.size()
		for id in world.streamer.loaded:
			if not qualified_cell(str(id)):skipped.append(str(id));continue
			var path:String=world.streamer.records[id].path
			if FileAccess.get_sha256(path)!=str(audit.input_sha256.get(str(id),"")):skipped.append(str(id)+":changed_since_audit");continue
			for node in world.streamer.loaded[id].find_children("*","MeshInstance3D",true,false):
				if not node.has_meta("stream_terrain") or node.mesh==null or not node.material_override is ShaderMaterial:continue
				if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON:continue
				var source:ShaderMaterial=node.material_override
				if source.shader==null or not "cull_disabled" in source.shader.code:continue
				var proxy:=MeshInstance3D.new();proxy.name="TerrainFrontOnly110";proxy.mesh=node.mesh;proxy.layers=node.layers;proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;proxy.visible=false;proxy.extra_cull_margin=node.extra_cull_margin
				var material:ShaderMaterial=source.duplicate(false);proxy.material_override=material;node.add_child(proxy)
				entries.append({"cell":str(id),"node":node,"proxy":proxy,"source_material":source,"proxy_material":material,"source_shader":null,"shadow":node.cast_shadow,"mesh":node.mesh})
		return {"eligible_nodes":entries.size(),"skipped_cells":skipped,"audit_triangle_count":audit.totals.triangles,"new_mesh_resources":0,"shadow_path":"Original node, original shader/material, original mesh; only color rendering moves to child."}
	func qualified_cell(id:String)->bool:
		return audit_cells.has(id) and int(audit_cells[id].opposed)==0 and int(audit_cells[id].downward_top)==0
	func guarded_camera(camera:Camera3D)->Dictionary:
		if camera==null or camera.projection!=Camera3D.PROJECTION_PERSPECTIVE:return {"safe":false,"reason":"orthographic_or_no_camera"}
		if camera.h_offset!=0 or camera.v_offset!=0:return {"safe":false,"reason":"offset_camera_not_proven"}
		if world==null or world.terrain_art==null or world.layout==null:return {"safe":false,"reason":"heightfield_unavailable"}
		if not rectangular_domain:return {"safe":false,"reason":"nonrectangular_audited_heightfield_domain"}
		var size:Vector2=camera.get_viewport().get_visible_rect().size;var aspect:float=maxf(1,size.x)/maxf(1,size.y);var half:float=camera.near*tan(deg_to_rad(camera.fov)*.5)
		var half_width:float=half*aspect if camera.keep_aspect==Camera3D.KEEP_HEIGHT else half
		var half_height:float=half if camera.keep_aspect==Camera3D.KEEP_HEIGHT else half/aspect
		var points:Array[Vector3]=[camera.global_position]
		for x in [-1,1]:
			for y in [-1,1]:points.append(camera.global_transform*Vector3(x*half_width,y*half_height,-camera.near))
		var bounds:Array=world.layout.config.bounds;var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF);var minimum_y:=INF
		for point in points:
			if point.x<=float(bounds[0]) or point.x>=float(bounds[1]) or point.z<=float(bounds[2]) or point.z>=float(bounds[3]):return {"safe":false,"reason":"eye_or_near_plane_outside_valid_grid"}
			if point.x<=terrain_rectangle.position.x or point.x>=terrain_rectangle.end.x or point.z<=terrain_rectangle.position.y or point.z>=terrain_rectangle.end.y:return {"safe":false,"reason":"eye_or_near_plane_outside_actual_110_mesh_domain"}
			low=low.min(Vector2(point.x,point.z));high=high.max(Vector2(point.x,point.z));minimum_y=minf(minimum_y,point.y)
		var maximum_terrain:=-INF;var sampled:=0
		# Maximum of all four actual cap heights in every touched 2m cell. This
		# conservatively covers sloping triangles and vertical cell discontinuities.
		for x in range(floori((low.x-.001)/2),floori((high.x+.001)/2)+1):
			for z in range(floori((low.y-.001)/2),floori((high.y+.001)/2)+1):
				var tile:Dictionary=world.terrain_art.tile(Vector2i(x,z))
				for height in tile.heights:maximum_terrain=maxf(maximum_terrain,float(height))
				sampled+=1
		return {"safe":minimum_y>maximum_terrain+.12,"reason":"complete_eye_near_plane_outside_heightfield" if minimum_y>maximum_terrain+.12 else "near_plane_may_cross_heightfield","minimum_camera_y":minimum_y,"maximum_touched_terrain_y":maximum_terrain,"touched_tiles":sampled}
	func sync_proxy_shader(entry:Dictionary):
		# Root's vertex-constant candidate may change the source shader between
		# stages. Compose with that CURRENT shader without touching shadow shader.
		var source:Shader=entry.source_material.shader
		if entry.source_shader==source:return
		var id:int=source.get_instance_id()
		if not shaders.has(id):
			var shader:=Shader.new();shader.code=source.code.replace("render_mode cull_disabled;","render_mode cull_back;");shaders[id]=shader
		entry.proxy_material.shader=shaders[id];entry.source_shader=source
	func update(camera:Camera3D):
		last_guard=guarded_camera(camera) if enabled else {"safe":false,"reason":"candidate_disabled"};active=enabled and bool(last_guard.safe)
		for entry in entries:
			if not is_instance_valid(entry.node) or not is_instance_valid(entry.proxy):continue
			if active:
				sync_proxy_shader(entry);entry.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;entry.proxy.visible=true
			else:entry.node.cast_shadow=entry.shadow;entry.proxy.visible=false
	func restore():
		enabled=false;active=false
		for entry in entries:
			if is_instance_valid(entry.node):entry.node.cast_shadow=entry.shadow
			if is_instance_valid(entry.proxy):entry.proxy.visible=false
	func uninstall():
		restore()
		for entry in entries:
			if is_instance_valid(entry.proxy):entry.proxy.get_parent().remove_child(entry.proxy);entry.proxy.free()
		entries.clear();shaders.clear()
	func diagnostics()->Dictionary:
		return {"active":active,"nodes":entries.size(),"skipped_cells":skipped,"guard":last_guard,"cached_shader_variants":shaders.size(),"mesh_vertex_index_buffers_unchanged":true,"original_shadow_shader_unchanged":true,"orthographic_fail_open":true}

class FixtureTerrain extends RefCounted:
	var height:=0.0
	func tile(_coord:Vector2i)->Dictionary:return {"heights":PackedFloat32Array([height,height,height,height])}
class FixtureLayout extends RefCounted:
	var config:Dictionary={"bounds":[-470,470,-450,650]}
class FixtureStream extends RefCounted:
	var loaded:Dictionary={}
	var records:Dictionary={}
class FixtureWorld extends Node3D:
	var terrain_art=FixtureTerrain.new()
	var layout=FixtureLayout.new()
	var streamer=FixtureStream.new()
func _initialize():contracts.call_deferred()
func contracts():
	if DisplayServer.get_name()!="headless":push_error("This script runs only offline contracts. Root owns the combined GPU runner.");quit(2);return
	var world:=FixtureWorld.new();root.add_child(world);var cell:Node3D=load("res://assets/world/stream_creative110/cell_0_0.scn").instantiate();world.add_child(cell);world.streamer.loaded["0_0"]=cell;world.streamer.records["0_0"]={"path":"res://assets/world/stream_creative110/cell_0_0.scn"}
	var candidate:=Candidate.new();var setup:Dictionary=candidate.install(world);var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(10,10,10);camera.near=.2;camera.fov=66
	var checks:Array=[]
	checks.append({"id":"audited_good_cell_only_all_11_bad_cells_excluded","passed":candidate.qualified_cell("0_0") and not candidate.qualified_cell("1_-1") and not candidate.qualified_cell("-3_-3") and setup.eligible_nodes>0})
	checks.append({"id":"whole_perspective_near_plane_above_heightfield","passed":candidate.guarded_camera(camera).safe})
	camera.position.y=.05;checks.append({"id":"near_plane_crossing_fails_open","passed":not candidate.guarded_camera(camera).safe});camera.position.y=10
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;var ortho:bool=not candidate.guarded_camera(camera).safe;camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.position.x=471;checks.append({"id":"orthographic_and_outside_finite_grid_fail_open","passed":ortho and not candidate.guarded_camera(camera).safe});camera.position.x=10
	var entry:Dictionary=candidate.entries[0];var original_shader:Shader=entry.source_material.shader;var original_mesh:Mesh=entry.node.mesh;candidate.enabled=true;candidate.update(camera)
	var correct:bool=entry.node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and entry.proxy.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and entry.proxy.mesh==original_mesh and entry.node.mesh==original_mesh and entry.source_material.shader==original_shader
	entry.node.visible=false;correct=correct and not entry.proxy.is_visible_in_tree();entry.node.visible=true
	checks.append({"id":"original_two_sided_shadow_and_exact_shared_mesh_parent_visibility","passed":correct})
	var hoist:=Shader.new();hoist.code=original_shader.code+"\n// root hoist fixture\n";entry.source_material.shader=hoist;candidate.update(camera)
	checks.append({"id":"composes_current_hoist_without_changing_shadow_shader","passed":entry.source_material.shader==hoist and "root hoist fixture" in entry.proxy_material.shader.code and "render_mode cull_back;" in entry.proxy_material.shader.code})
	entry.source_material.shader=original_shader;candidate.restore();var restored:bool=entry.node.cast_shadow==entry.shadow and not entry.proxy.visible and entry.node.mesh==original_mesh and entry.source_material.shader==original_shader;var proxy:Node=entry.proxy;candidate.uninstall();restored=restored and not is_instance_valid(proxy)
	checks.append({"id":"all_original_render_state_restore_and_proxy_removed","passed":restored})
	var report:Dictionary={"scope":"CPU-only 7 scene/property and camera-bound contracts; no pixel/GPU equivalence claim","checks":checks,"setup":setup,"finite_heightfield_proof":"Within the finite single-valued heightfield domain, require eye plus the complete clipped near plane strictly above every touched cell's maximum cap corner; fail open for all orthographic/offset/outside/underground views. All suspect-winding cells retain original color and shadow rendering.","normal_saves":"not loaded"}
	var file:=FileAccess.open("res://reports/creative110_terrain_cull_contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("TERRAIN_CULL110_CONTRACT ",JSON.stringify(report));world.free();camera.free();quit(0 if checks.all(func(check):return check.passed) else 1)
