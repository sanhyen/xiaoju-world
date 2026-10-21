extends "res://tools/creative110_terrain_combined_probe.gd"
## Reorder only original opaque flower instance records, front to back.
var ordered:Array=[]
var sorter=preload("res://scripts/dense_flora110.gd").new()
func make_orders():
	var forward:Vector3=-m.player.camera.global_basis.z
	for node in m.world.find_children("*","MultiMeshInstance3D",true,false):
		if not node.has_meta("dense_flora110_group"):continue
		var source:MultiMesh=node.multimesh;var buffer:PackedFloat32Array=source.buffer;var stride:int=12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0);var entries:Array=[]
		for i in source.instance_count:
			var point:Vector3=node.global_transform*sorter.raw_transform(buffer,i*stride).origin
			entries.append([point.dot(forward),i])
		entries.sort_custom(func(a,b):return a[0]<b[0] if a[0]!=b[0] else a[1]<b[1])
		var ids:Array=[]
		for entry in entries:ids.append(entry[1])
		var target:=MultiMesh.new();target.transform_format=source.transform_format;target.use_colors=source.use_colors;target.use_custom_data=source.use_custom_data;target.mesh=source.mesh;target.instance_count=source.instance_count;target.buffer=sorter.record_subset(buffer,stride,ids);target.custom_aabb=source.get_aabb();target.visible_instance_count=source.visible_instance_count
		ordered.append({"node":node,"source":source,"ordered":target,"count":source.instance_count})
func apply(on:bool):
	for item in ordered:item.node.multimesh=item.ordered if on else item.source
func shot(label:String,on:bool)->Dictionary:
	apply(on)
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	var picture:Image=root.get_texture().get_image();var folder:="res://.runtime/creative110_flower_order_pixels";DirAccess.make_dir_recursive_absolute(folder)
	var path:String=folder.path_join(label+".raw");var f:=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(picture.get_data());f.close()
	return {"path":path,"width":picture.get_width(),"height":picture.get_height(),"format":picture.get_format()}
func run():
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="flower_order110_probe";m.store.directory="user://flower_order110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080));m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.enabled=true
	if not m.transport.board(0):push_error("No cable for flower-order probe");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[m.transport.rider].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184)
	for i in 120:await process_frame
	m.world.streamer.set_process(false);fixed_view=m.player.camera.global_transform;make_orders()
	var data:Dictionary={};apply(false);data.original_A=await terrain_sample("flower_order_A")
	apply(true);data.sorted=await terrain_sample("flower_front_to_back")
	apply(false);data.original_A_repeat=await terrain_sample("flower_order_A_repeat")
	m.process_mode=Node.PROCESS_MODE_DISABLED;var pixels:Dictionary={}
	pixels.original_A=await shot("A",false);pixels.sorted=await shot("sorted",true);pixels.original_A_repeat=await shot("A_repeat",false);apply(false);m.process_mode=Node.PROCESS_MODE_INHERIT
	var instances:=0
	for item in ordered:instances+=item.count
	json("res://reports/creative110_flower_order_probe.json",{"stages":data,"pixel_captures":pixels,"groups":ordered.size(),"instances":instances,"scope":"Same original native instance record bytes in a different order; original geometry/shaders/shadows/resolution, 3D camera depth ascending. All restored, no resources saved.","driver":RenderingServer.get_current_rendering_driver_name()})
	print("FLOWER_ORDER110 ",JSON.stringify(data));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
