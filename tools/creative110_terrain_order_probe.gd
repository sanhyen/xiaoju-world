extends "res://tools/creative110_terrain_combined_probe.gd"
## Opaque draw-order cost only. Same shaders, geometry, shadows and color math.
var priorities:Dictionary={}
var flat_shader:Shader
func remember():
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if not node.has_meta("stream_terrain"):continue
		var mat=node.material_override
		if mat is ShaderMaterial and not priorities.has(mat.get_instance_id()):priorities[mat.get_instance_id()]={"material":mat,"priority":mat.render_priority,"shader":mat.shader}
func order(on:bool):
	for item in priorities.values():item.material.render_priority=120 if on else item.priority
func flatten(on:bool):
	for item in priorities.values():item.material.shader=flat_shader if on else item.shader
func pixels(label:String)->Dictionary:
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	var picture:Image=root.get_texture().get_image();var folder:="res://.runtime/creative110_terrain_order_pixels";DirAccess.make_dir_recursive_absolute(folder)
	var path:String=folder.path_join(label+".raw");var f:=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(picture.get_data());f.close()
	return {"path":path,"width":picture.get_width(),"height":picture.get_height(),"format":picture.get_format()}
func leg(name:String)->Dictionary:
	m.world.streamer.set_process(false);fixed_view=m.player.camera.global_transform;remember()
	var data:Dictionary={}
	order(false);data.original_A=await terrain_sample(name+"_order_A")
	order(true);data.terrain_last=await terrain_sample(name+"_terrain_last")
	if flat_shader!=null:
		flatten(true);data.terrain_last_flat=await terrain_sample(name+"_terrain_last_flat");flatten(false)
	order(false);data.original_A_repeat=await terrain_sample(name+"_order_A_repeat")
	m.process_mode=Node.PROCESS_MODE_DISABLED
	data.pixels={};data.pixels.original_A=await pixels(name+"_A")
	order(true);data.pixels.terrain_last=await pixels(name+"_last")
	if flat_shader!=null:
		flatten(true);data.pixels.terrain_last_flat=await pixels(name+"_last_flat");flatten(false)
	order(false);data.pixels.original_A_repeat=await pixels(name+"_A_repeat")
	m.process_mode=Node.PROCESS_MODE_INHERIT;m.world.streamer.set_process(true);return data
func run():
	if OS.get_cmdline_user_args().has("--flat"):flat_shader=load("res://tools/terrain_flat_constants110.gdshader")
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="terrain_order110_probe";m.store.directory="user://terrain_order110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080));m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1)
	m.player.yaw=1.04422919850175;m.player.pitch=-.2;m.player.zoom=6;m.player.enabled=true;m.player.automated_motion=true;m.player.automated_horizontal=Vector2.ZERO
	await m.world.prepare_region(m.player.global_position,184)
	for i in 90:await process_frame
	var results:Dictionary={"castle":await leg("castle")}
	m.player.automated_motion=false
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1)
	if not m.transport.board(0):push_error("No cable for draw order diagnosis");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[m.transport.rider].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184)
	for i in 90:await process_frame
	results.cable=await leg("cable")
	json("res://reports/creative110_terrain_order_probe.json",{"stages":results,"driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Temporary render_priority120 on opaque terrain materials only. Same original shaders/triangles/shadows; all restored, not saved","pid":OS.get_process_id()})
	print("TERRAIN_ORDER110 ",JSON.stringify(results));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
