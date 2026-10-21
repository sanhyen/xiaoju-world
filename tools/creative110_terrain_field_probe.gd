extends "res://tools/creative110_terrain_combined_probe.gd"
## Texture lookup candidate only, with full normal-world timing and frozen pixel legs.
var field_texture:ImageTexture
var meta:Dictionary
var material_ids:Dictionary={}
func materials_refresh():
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if not node.has_meta("stream_terrain"):continue
		var mat=node.material_override
		if not mat is ShaderMaterial or mat.shader==null or material_ids.has(mat.get_instance_id()):continue
		if not mat.shader.resource_path.ends_with("terrain_strata.gdshader"):continue
		terrain_materials.append({"material":mat,"shader":mat.shader});material_ids[mat.get_instance_id()]=true
func field_apply(on:bool):
	for item in terrain_materials:
		item.material.shader=optimized_shader if on else item.shader
		if on:
			item.material.set_shader_parameter("terrain_field110",field_texture)
			item.material.set_shader_parameter("terrain_field_size110",Vector2(meta.width,meta.height))
func field_pixels(label:String,on:bool)->Dictionary:
	field_apply(on)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var picture:Image=root.get_texture().get_image();var data:=picture.get_data();var folder:="res://.runtime/creative110_terrain_field_pixels";DirAccess.make_dir_recursive_absolute(folder)
	var uri:String=folder.path_join(label+".raw");var f:=FileAccess.open(uri,FileAccess.WRITE);f.store_buffer(data);f.close()
	return {"stage":label,"path":uri,"width":picture.get_width(),"height":picture.get_height(),"format":picture.get_format(),"bytes":data.size(),"camera":root.get_camera_3d().global_transform}
func pixel_leg(label:String)->Array:
	var nodes:Array=[];var camera:Camera3D=root.get_camera_3d();var mask:int=camera.cull_mask;camera.cull_mask=1<<19;m.hud.hide()
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if node.has_meta("stream_terrain"):nodes.append({"node":node,"layers":node.layers});node.layers=1<<19
	m.process_mode=Node.PROCESS_MODE_DISABLED
	var result:Array=[]
	for pair in [["original_A",false],["lookup",true],["original_A_repeat",false]]:result.append(await field_pixels(label+"_"+pair[0],pair[1]))
	field_apply(false)
	for saved in nodes:saved.node.layers=saved.layers
	camera.cull_mask=mask;m.hud.show();m.process_mode=Node.PROCESS_MODE_INHERIT;return result
func run():
	var metadata_uri:="res://reports/creative110_terrain_field_lut.json"
	if not FileAccess.file_exists(metadata_uri):push_error("Await frozen LUT data and error certificate");quit(2);return
	meta=JSON.parse_string(FileAccess.get_file_as_string(metadata_uri))
	var lut_uri:String=str(meta.path);if not lut_uri.begins_with("res://"):lut_uri="res://"+lut_uri
	var data:PackedByteArray=FileAccess.get_file_as_bytes(lut_uri);var image:=Image.create_from_data(int(meta.width),int(meta.height),false,Image.FORMAT_RGH,data)
	field_texture=ImageTexture.create_from_image(image);image=null;data=PackedByteArray()
	optimized_shader=load("res://tools/terrain_field_lut110.gdshader")
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="terrain_field110_probe";m.store.directory="user://terrain_field110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080));m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	var stages:Dictionary={}
	var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await qa.move_to(m.world.layout.vector(road.points[-1])+Vector3.UP*.1)
	m.player.yaw=1.04422919850175;m.player.pitch=-.2;m.player.zoom=6.0;m.player.enabled=true;m.player.automated_motion=true;m.player.automated_horizontal=Vector2.ZERO;m.player.camera.make_current()
	await m.world.prepare_region(m.player.global_position,184)
	for i in 120:await process_frame
	m.world.streamer.set_process(false);fixed_view=m.player.camera.global_transform;materials_refresh()
	field_apply(false);stages.castle_original_A=await terrain_sample("field_castle_original_A")
	field_apply(true);stages.castle_lookup=await terrain_sample("field_castle_lookup")
	field_apply(false);stages.castle_original_A_repeat=await terrain_sample("field_castle_original_A_repeat")
	m.world.streamer.set_process(true);m.player.automated_motion=false
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.enabled=true
	if not m.transport.board(0):push_error("Cannot enter cable");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[m.transport.rider].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184)
	for i in 120:await process_frame
	m.world.streamer.set_process(false);fixed_view=m.player.camera.global_transform;materials_refresh()
	field_apply(false);stages.original_A=await terrain_sample("field_original_A")
	field_apply(true);stages.lookup=await terrain_sample("field_lookup")
	field_apply(false);stages.original_A_repeat=await terrain_sample("field_original_A_repeat")
	var pixels:Array=[];pixels.append_array(await pixel_leg("cable"))
	m.transport.release_for_travel();m.world.streamer.set_process(true)
	var at:=Vector3(253,-1,447);await qa.move_to(at);await m.world.prepare_region(at,110)
	for i in 60:await process_frame
	m.world.streamer.set_process(false);materials_refresh();m.watch_camera.position=Vector3(287,15,471);m.watch_camera.look_at(Vector3(252,-2,443));m.watch_camera.make_current()
	pixels.append_array(await pixel_leg("coast"))
	json("res://reports/creative110_terrain_field_probe.json",{"pid":OS.get_process_id(),"stages":stages,"pixel_captures":pixels,"lut_sha256":FileAccess.get_sha256(lut_uri),"width":meta.width,"height":meta.height,"driver":RenderingServer.get_current_rendering_driver_name(),"renderer":RenderingServer.get_current_rendering_method(),"fixed_performance_camera":fixed_view,"pixel_leg_world_processes_frozen":true,"scope":"Normal castle and cable camera timing, full quality/settings/content; frozen terrain-only cable+coastal sand/wetness pixels, all original states restored; no resources saved","normal_saves":"isolated APPDATA"})
	print("TERRAIN_FIELD110 ",JSON.stringify(stages));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
