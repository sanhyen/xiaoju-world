extends "res://tools/creative110_backend_probe.gd"
## Isolated short diagnostic: the closed body must move with its parent cabin.
func state()->Dictionary:
	var cabin:Node3D=m.transport.cabins[0];var body:AnimatableBody3D=m.transport.bodies[0]
	return {"parent":cabin.global_position,"body":body.global_position,"offset":cabin.global_position.distance_to(body.global_position),"body_local":body.transform,"sync_to_physics":body.sync_to_physics,"body_visible":body.is_visible_in_tree()}
func shot(label:String):
	for i in 15:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/creative110/cabin_sync_"+label+".png")
func run():
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="cabin_sync110_probe";m.store.directory="user://cabin_sync110_probe";m.store.import_directory=""
	await m.start_game(false);DisplayServer.window_set_size(Vector2i(1920,1080));m.player.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var qa=preload("res://scripts/creative110_qa.gd").new();qa.m=m
	await qa.move_to(m.transport.station_landing(0)+Vector3.UP*.1);m.player.enabled=true
	if not m.transport.board(0):push_error("No cable for cabin transform probe");quit(4);return
	m.transport.set_physics_process(false);m.transport.progress=.035;m.transport.pose=1;m.transport.update_cabins();m.transport.update_passenger();m.player.yaw=m.transport.cabins[0].rotation.y;m.player.pitch=-.2;m.player.zoom=5.5
	for i in 10:await physics_frame
	var before:Dictionary=state();await shot("original")
	for body in m.transport.bodies:body.sync_to_physics=false;body.transform=Transform3D.IDENTITY
	for fraction in [.04,.045,.05]:
		m.transport.progress=fraction;m.transport.update_cabins();m.transport.update_passenger()
		for i in 5:await physics_frame
	var after:Dictionary=state();await shot("manual_physics")
	json("res://reports/creative110_cabin_sync_probe.json",{"before":before,"after":after,"body_follows":float(after.offset)<.001,"normal_saves":"isolated APPDATA","scope":"Unchanged closed cabin geometry; three parent translations with 15 physics ticks after disabling body sync. Diagnostic only, no production resources saved."})
	print("CABIN_SYNC110 ",JSON.stringify({"before":before,"after":after}));m.world.streamer.shutdown();m.queue_free();await process_frame;quit()
