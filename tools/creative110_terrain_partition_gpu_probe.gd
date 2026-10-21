extends "res://tools/creative110_terrain_combined_probe.gd"
## One original cable hotspot. Split only original native terrain triangle records.
var partition
func image_for(label:String,on:bool)->Dictionary:
	partition.enabled=on;partition.update(m.player.camera)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var picture:Image=root.get_texture().get_image();var folder:="res://.runtime/creative110_terrain_partition_pixels";DirAccess.make_dir_recursive_absolute(folder)
	var path:String=folder.path_join(label+".raw");var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(picture.get_data());file.close()
	return {"path":path,"width":picture.get_width(),"height":picture.get_height(),"format":picture.get_format()}
func run():
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="terrain_partition110_probe";m.store.directory="user://terrain_partition110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080));m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.enabled=true
	if not m.transport.board(0):push_error("No cable for terrain partition");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[0].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	await m.world.prepare_region(m.player.global_position,184)
	for i in 120:await process_frame
	m.world.streamer.set_process(false);fixed_view=m.player.camera.global_transform
	partition=load("res://tools/creative110_terrain_partition_probe.gd").Candidate.new();var setup:Dictionary=partition.install(m.world)
	var result:Dictionary={};var pixels:Dictionary={}
	partition.enabled=false;partition.update(m.player.camera);result.original_A=await terrain_sample("terrain_partition_A")
	partition.enabled=true;partition.update(m.player.camera);result.partitioned=await terrain_sample("terrain_partition_24m")
	m.process_mode=Node.PROCESS_MODE_DISABLED
	var old_mask:int=m.player.camera.cull_mask;m.player.camera.cull_mask=1<<19
	for node in m.world.find_children("*","GeometryInstance3D",true,false):
		if node.has_meta("stream_terrain"):node.layers=1<<19
	pixels.A=await image_for("A",false);pixels.partitioned=await image_for("partitioned",true);pixels.A_repeat=await image_for("A_repeat",false)
	var split_diagnostics:Dictionary=partition.diagnostics();partition.uninstall();m.player.camera.cull_mask=old_mask;m.process_mode=Node.PROCESS_MODE_INHERIT
	partition=load("res://tools/creative110_terrain_partition_probe.gd").Candidate.new();partition.cluster_size=0.0;var weld_setup:Dictionary=partition.install(m.world);partition.enabled=true;partition.update(m.player.camera)
	result.weld_only=await terrain_sample("terrain_weld_only")
	m.process_mode=Node.PROCESS_MODE_DISABLED;m.player.camera.cull_mask=1<<19;pixels.weld_only=await image_for("weld_only",true);m.player.camera.cull_mask=old_mask;m.process_mode=Node.PROCESS_MODE_INHERIT
	partition.enabled=false;partition.update(m.player.camera);result.original_A_final=await terrain_sample("terrain_partition_A_final")
	json("res://reports/creative110_terrain_partition_gpu_probe.json",{"setup":setup,"weld_setup":weld_setup,"stages":result,"diagnostics":split_diagnostics,"weld_diagnostics":partition.diagnostics(),"pixels":pixels,"scope":"Same complete cable camera including actual closed cabin, identical resolution/AA/shadows/materials; terrain native records regrouped and welded only; pixel captures isolate terrain after timing. No production cache or normal save modified."})
	print("TERRAIN_PARTITION110 ",JSON.stringify(result));partition.uninstall();m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
