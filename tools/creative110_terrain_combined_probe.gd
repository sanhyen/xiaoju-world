extends "res://tools/creative110_cable_cost_probe.gd"
## Fixed normal camera A/B comparisons. Production source/scene resources are not saved.
var culler
var terrain_materials:Array=[]
var terrain_capture_nodes:Array=[]
var fixed_view:Transform3D
var optimized_shader:Shader
func set_variant(hoist:bool,cull:bool):
	culler.enabled=false;culler.update(m.player.camera)
	for item in terrain_materials:item.material.shader=optimized_shader if hoist else item.shader
	culler.enabled=cull;culler.update(m.player.camera)
func terrain_sample(label:String)->Dictionary:
	for i in 100:await process_frame
	var frames:Array=[];var last:=Time.get_ticks_usec()
	json("res://reports/creative110_backend_progress.json",{"pid":OS.get_process_id(),"phase":label+"_sample"})
	for i in 180:
		await process_frame
		if not fixed_view.is_equal_approx(m.player.camera.global_transform):push_error("Terrain diagnostic camera moved");quit(8);return {}
		var now:=Time.get_ticks_usec();frames.append({"ms":(now-last)/1000.0,"gpu":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"cpu":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)});last=now
	json("res://reports/creative110_backend_progress.json",{"pid":OS.get_process_id(),"phase":""})
	var result:Dictionary={"ms":0.0,"gpu":0.0,"cpu":0.0,"draws":0.0,"primitives":0.0,"frames":frames.size()};var times:Array=[]
	for value in frames:
		times.append(value.ms)
		for key in ["ms","gpu","cpu","draws","primitives"]:result[key]+=value[key]/frames.size()
	times.sort();result.p95_ms=times[int(times.size()*.95)];result.fps=1000.0/result.ms;return result
func capture_pixels(label:String,hoist:bool,cull:bool)->Dictionary:
	set_variant(hoist,cull)
	for item in terrain_capture_nodes:item.node.layers=1<<19
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	var shot:Image=root.get_texture().get_image();var data:PackedByteArray=shot.get_data();var folder:="res://.runtime/creative110_terrain_constants_pixels";DirAccess.make_dir_recursive_absolute(folder)
	var path:String=folder.path_join(label+".raw");var f:=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(data);f.close()
	return {"stage":label,"path":path,"width":shot.get_width(),"height":shot.get_height(),"format":shot.get_format(),"bytes":data.size()}
func run():
	if not ResourceLoader.exists("res://tools/creative110_terrain_cull_probe.gd"):push_error("Await frozen cull candidate before this single combined run");quit(2);return
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="terrain_combined110_probe";m.store.directory="user://terrain_combined110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080));m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.enabled=true
	if not m.transport.board(0):push_error("Cannot enter cable");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[m.transport.rider].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184)
	for i in 120:await process_frame
	m.world.streamer.set_process(false);fixed_view=m.player.camera.global_transform
	optimized_shader=load("res://tools/terrain_vertex_constants110.gdshader")
	var seen:Dictionary={}
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if not node.has_meta("stream_terrain"):continue
		var mat=node.material_override
		if not mat is ShaderMaterial or mat.shader==null or not mat.shader.resource_path.ends_with("terrain_strata.gdshader"):continue
		if not seen.has(mat.get_instance_id()):terrain_materials.append({"material":mat,"shader":mat.shader});seen[mat.get_instance_id()]=true
	culler=load("res://tools/creative110_terrain_cull_probe.gd").Candidate.new();culler.install(m.world)
	var result:Dictionary={}
	for entry in [["original_A",false,false],["vertex_constants",true,false],["terrain_front_cull",false,true],["combined",true,true],["original_A_repeat",false,false]]:
		set_variant(entry[1],entry[2]);result[entry[0]]=await terrain_sample(entry[0]);result[entry[0]]["culling"]=culler.diagnostics()
	var cull_diagnostics:Dictionary=culler.diagnostics()
	# Isolate actual terrain and its proxy children, keeping the original shadow scene.
	var old_mask:int=m.player.camera.cull_mask;var layer:int=1<<19;m.player.camera.cull_mask=layer;m.hud.hide();var nodes_seen:Dictionary={}
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if not node.has_meta("stream_terrain"):continue
		var all:Array=[node];all.append_array(node.find_children("*","GeometryInstance3D",true,false))
		for item in all:
			if nodes_seen.has(item.get_instance_id()):continue
			nodes_seen[item.get_instance_id()]=true;terrain_capture_nodes.append({"node":item,"layers":item.layers});item.layers=layer
	var images:Array=[]
	for entry in [["original_A",false,false],["vertex_constants",true,false],["terrain_front_cull",false,true],["combined",true,true],["original_A_repeat",false,false]]:images.append(await capture_pixels(entry[0],entry[1],entry[2]))
	set_variant(false,false)
	for item in terrain_capture_nodes:item.node.layers=item.layers
	m.player.camera.cull_mask=old_mask;m.hud.show();culler.uninstall()
	json("res://reports/creative110_terrain_combined_probe.json",{"pid":OS.get_process_id(),"driver":RenderingServer.get_current_rendering_driver_name(),"renderer":RenderingServer.get_current_rendering_method(),"fixed_camera":fixed_view,"same_camera_after":fixed_view.is_equal_approx(m.player.camera.global_transform),"stages":result,"pixel_captures":images,"culling":cull_diagnostics,"material_count":terrain_materials.size(),"scope":"Same actual cable camera; full resolution/AA/shadows and all world content retained; terrain constants and conservative front pass candidate only; no settings or resources saved","normal_saves":"isolated APPDATA"})
	print("TERRAIN_COMBINED110 ",JSON.stringify(result));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
