extends SceneTree
var main
func _initialize():run.call_deferred()
func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	main.qa_mode="home_camera";main.store.directory="user://qa_isolated/home_camera"
	await main.start_game(false);main.player.enabled=false
	var o:Vector3=main.world.surface(-237,-169,0.08);await main.world.prepare_region(o)
	var results:Array=[]
	for pose in [["entry",Vector3(0,0.5,3.7),0.0],["sofa",Vector3(-2.4,0.5,-0.4),0.25],["window",Vector3(5.5,0.5,2.8),-PI/2]]:
		main.player.position=o+pose[1];main.player.yaw=pose[2];main.player.pitch=-0.17;main.player.velocity=Vector3.ZERO
		main.player.automated_motion=true;main.player.automated_horizontal=Vector2.ZERO
		for tick in 60:await physics_frame
		main.player.automated_motion=false;main.player.camera.current=true;main.watch_camera.current=false
		var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=0.12;query.shape=sphere;query.transform=main.player.camera.global_transform;query.exclude=[main.player.get_rid()]
		var hits:Array=main.world.get_world_3d().direct_space_state.intersect_shape(query)
		var passed:bool=hits.is_empty() and main.player.is_on_floor()
		results.append({"pose":pose[0],"camera_position":str(main.player.camera.global_position),"collision_overlaps":hits.size(),"grounded":main.player.is_on_floor(),"passed":passed})
		main.hud.hide();await main.qa_frame();root.get_texture().get_image().save_png("res://screenshots/art_v11_player_camera_"+pose[0]+".png")
	var failures:=0
	for row in results:
		print("HOME_CAMERA ",JSON.stringify(row))
		if not row.passed:failures+=1
	var out:=FileAccess.open("res://reports/home_player_camera.json",FileAccess.WRITE);out.store_string(JSON.stringify({"results":results,"failures":failures,"scope":"real player SpringArm camera and settled body inside upgraded house; sphere query against actual world colliders"},"\t"));out.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
