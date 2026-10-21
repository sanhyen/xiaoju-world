extends SceneTree
var main
var results:Array=[]
var samples:Array=[]

func _initialize():run.call_deferred()
func check(name:String,passed:bool,detail:Dictionary={}):
	results.append({"test":name,"passed":passed,"detail":detail});print("STREAM_TEST ",name," ",passed," ",JSON.stringify(detail))

func relocate(point:Vector3):
	main.watch_camera.current=false;main.player.camera.current=true
	main.world.streamer.set_foci([point]);main.player.position=point
	var ok:bool=await main.world.prepare_region(point)
	main.player.enabled=false;main.player.velocity=Vector3.ZERO
	await create_timer(0.8).timeout
	samples.append(main.world.streamer.diagnostics())
	return ok

func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	main.qa_mode="stream_test";main.store.directory="user://qa_isolated/stream_lifecycle"
	await process_frame;await process_frame
	check("runtime_uses_real_stream_manager",main.world.phase=="streamed" and main.world.streamer!=null)
	var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	var current_ids:Array=[]
	for action in main.world.interactions:current_ids.append(action.id)
	var missing:Array=[]
	for id in contract.ids:
		if id not in current_ids:missing.append(id)
	for id in ["B12_listen","B12_porch_seat","B12_reading","B12_window_seat","N01_GARDEN_SEAT","B02_listen"]:
		if id not in current_ids:missing.append(id)
	check("full_authored_scope_preserved",main.world.building_bounds.size()==13 and main.world.spec.zones.size()==8 and contract.ids.size()==64 and missing.is_empty(),{"original_ids":contract.ids.size(),"current_ids":current_ids.size(),"missing_required_ids":missing})
	check("100_separately_loadable_cells",main.world.streamer.records.size()==100)
	await main.start_game(false);main.player.enabled=false
	check("spawn_prepares_collision",main.world.region_ready(main.player.position))
	var first_cell:Node=main.world.streamer.loaded.get("2_2")
	var first_ref:WeakRef=weakref(first_cell) if first_cell!=null else null
	var before_nodes:int=main.get_tree().get_node_count()
	var far_ok:bool=await relocate(main.world.surface(0,-377,0.7))
	check("distant_destination_loads_before_control",far_ok and main.world.region_ready(main.player.position))
	check("old_cells_removed_from_tree",not main.world.streamer.loaded.has("2_2"))
	check("old_cell_nodes_actually_freed",first_ref!=null and first_ref.get_ref()==null)
	check("details_are_not_all_resident",main.world.streamer.loaded.size()<50,{"loaded":main.world.streamer.loaded.size(),"nodes_before":before_nodes,"nodes_now":get_node_count()})
	var loaded_ids:Array=main.world.streamer.loaded.keys().duplicate()
	await main.world.prepare_region(main.player.position);await create_timer(0.3).timeout
	check("same_destination_does_not_duplicate_cells",main.world.streamer.loaded.size()==loaded_ids.size())
	if DisplayServer.get_name()!="headless":
		var buffers_ok:=true;var batches:=0
		for cell in main.world.streamer.loaded.values():
			for mesh in cell.find_children("*","MultiMeshInstance3D",true,false):buffers_ok=buffers_ok and not mesh.multimesh.buffer.is_empty();batches+=1
		check("real_render_buffers_survive_serialization",buffers_ok and batches>0,{"batches":batches})
		await main.qa_capture("art_v11_stream_summit",main.world.surface(0,-377,2.2),Vector3(0,5,110))
	for item in main.world.spec.buildings:
		var point:Vector3=main.world.surface(item.x,item.z+item.d/2+2,0.7)
		var ok:bool=await relocate(point)
		var hit:Dictionary=main.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3(0,1,0),point-Vector3(0,3,0)))
		check(item.id+"_collision_reloads",ok and not hit.is_empty())
	var home:Vector3=main.world.surface(-237,-168.5,0.7)
	await relocate(home);main.state.home_photo=2;main.state.bouquet=2
	main.world.update_home(2,"res://"+main.assets[2].runtime_path)
	var selected_path:String=main.world.home_picture.material_override.albedo_texture.resource_path
	await relocate(main.world.surface(260,193,0.7));await relocate(home)
	check("home_decoration_survives_real_unload",is_instance_valid(main.world.home_picture) and main.world.home_picture.material_override.albedo_texture.resource_path==selected_path)
	await main.show_video("B10");await create_timer(0.5).timeout
	check("video_uses_reloaded_physical_screen",main.video.is_playing() and is_instance_valid(main.watch_screen))
	main.stop_media();main.modal.hide();main.player.enabled=false
	check("video_releases_decoder_after_reload",main.video.stream==null and main.watch_screen==null)
	var old_position:Vector3=main.player.position
	var completion:={"done":false}
	var travel:Callable=func():await main.teleport_zone(main.world.spec.zones[7]);completion.done=true
	travel.call()
	check("travel_holds_position_until_prepared",main.transitioning and main.player.position==old_position and not main.player.enabled)
	while not completion.done:await process_frame
	check("travel_commits_to_prepared_destination",not main.transitioning and main.world.region_ready(main.player.position))
	var failed:=0
	for row in results:if not row.passed:failed+=1
	var report:={"results":results,"failures":failed,"samples":samples,"final":main.world.streamer.diagnostics(),"scope":"actual streamed scene-node and collision lifecycle; no GPU or long-duration performance claim"}
	var file:=FileAccess.open("res://reports/stream_lifecycle"+("_gpu" if DisplayServer.get_name()!="headless" else "")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
