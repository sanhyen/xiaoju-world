extends SceneTree
var main
var results:Array=[]
var selected:=""
func _initialize():run.call_deferred()

func walk(target:Vector2,seconds:float=18)->bool:
	var p=main.player
	await main.world.prepare_region(p.position)
	for i in int(seconds*60):
		await physics_frame
		var delta:=target-Vector2(p.position.x,p.position.z)
		if delta.length()<0.5:return true
		var velocity:=delta.normalized()*8.8
		p.velocity=Vector3(velocity.x,maxf(p.velocity.y-19.0/60,-20),velocity.y)
		if p.is_on_floor():p.velocity.y=-0.2
		p.move_character()
	var collisions:Array=[]
	for j in p.get_slide_collision_count():
		var collision=p.get_slide_collision(j);var body=collision.get_collider()
		collisions.append({"position":str(collision.get_position()),"body_position":str(body.global_position) if body is Node3D else str(body)})
	print("BLOCKED ",JSON.stringify({"target":str(target),"collisions":collisions}))
	return false

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):selected=arg.trim_prefix("--case=")
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	await physics_frame;await physics_frame
	main.player.enabled=false;main.store.directory="user://qa_isolated/venue_routes"
	var paths:Array=[
		["theater_center_and_lighting",Vector2(-291,27),[Vector2(-291,16),Vector2(-291,19),Vector2(-277,19),Vector2(-277,14),Vector2(-279,14)]],
		["theater_side_aisle",Vector2(-291,19),[Vector2(-304.5,19),Vector2(-304.5,7),Vector2(-291,5.8)]],
		["dance_practice_and_locker",Vector2(-232,-27),[Vector2(-232,-41.8),Vector2(-238,-41),Vector2(-238,-33.2),Vector2(-232,-33.2),Vector2(-232,-27)]],
		["studio_listen_and_booth",Vector2(-211,62),[Vector2(-211,54),Vector2(-209,52),Vector2(-211,48.5),Vector2(-214,48.5),Vector2(-211,48.5),Vector2(-211,56)]],
		["gallery_12_art_positions",Vector2(173,-31),[Vector2(173,-38),Vector2(176.7,-38),Vector2(180.3,-38),Vector2(173,-38),Vector2(169.3,-40),Vector2(165.7,-40),Vector2(173,-40),Vector2(173,-45),Vector2(165.7,-45),Vector2(169.3,-45),Vector2(173,-45),Vector2(176.7,-43),Vector2(180.3,-43),Vector2(180.3,-47.35),Vector2(175.7,-47.35),Vector2(170.3,-47.35),Vector2(164.9,-47.35)]],
		["cinema_lobby_and_side_aisle",Vector2(245,-72),[Vector2(245,-78.3),Vector2(257,-78.3),Vector2(257,-82),Vector2(255,-84),Vector2(255,-86),Vector2(255,-84),Vector2(257,-82),Vector2(257,-78.3),Vector2(245,-78.3)]],
		["photobook_reading_and_windows",Vector2(225,-141),[Vector2(225,-151.2),Vector2(225,-146.5),Vector2(235,-146.5),Vector2(234,-154),Vector2(225,-157),Vector2(216,-157),Vector2(216,-155),Vector2(225,-157)]],
		["music_south_garden",Vector2(-291,34),[Vector2(-271,42),Vector2(-250,42)]],
		["music_north_connection",Vector2(-250,-22),[Vector2(-264,-29),Vector2(-278,-21),Vector2(-291,-12)]],
		["studio_garden_connection",Vector2(-211,63),[Vector2(-221,76),Vector2(-244,78)]],
		["music_shade_seat",Vector2(-250,4),[Vector2(-264,4),Vector2(-268,4),Vector2(-268,7)]],
		["gallery_cinema_connection",Vector2(185,-29),[Vector2(204,-37),Vector2(218,-51),Vector2(224,-61),Vector2(245,-63)]],
		["cinema_photobook_connection",Vector2(245,-64),[Vector2(219,-67),Vector2(212,-98),Vector2(222,-119),Vector2(225,-138)]],
		["river_cinema_return",Vector2(220,-112),[Vector2(212,-98),Vector2(219,-67),Vector2(245,-64),Vector2(219,-67),Vector2(212,-98),Vector2(220,-112)]],
		["culture_reading_seat",Vector2(218,-51),[Vector2(202,-66),Vector2(202,-67)]],
		["film_courtyard_connection",Vector2(212,-98),[Vector2(195,-112),Vector2(185,-110),Vector2(180,-110)]],
		["forest_west_rest",main.world.nearest_road(Vector2(-90,-293)),[Vector2(-90,-293)]],
		["forest_east_rest",main.world.nearest_road(Vector2(117,-265)),[Vector2(117,-265)]]
	]
	var north_x:float=297+18*sin(-53*0.014)
	var south_x:float=297+18*sin(135*0.014)
	var river_points:Array=[Vector2(north_x,-53)]
	for z in range(-45,136,12):river_points.append(Vector2(297+18*sin(z*0.014),z))
	river_points.append(Vector2(south_x,135));river_points.append(Vector2(south_x-18,135))
	paths.append(["river_full_188m_with_both_ramps",Vector2(north_x-18,-53),river_points])
	paths.append(["river_north_main_connection",Vector2(245,-62),[Vector2(north_x-18,-53)]])
	paths.append(["river_south_main_connection",Vector2(south_x-18,135),[Vector2(260,160)]])
	for path in paths:
		if selected!="" and path[0]!=selected:continue
		main.player.position=main.world.surface(path[1].x,path[1].y,0.4);main.player.velocity=Vector3.ZERO
		await physics_frame;await physics_frame
		var passed:=true;var points:Array=[]
		for dest in path[2]:
			var ok:bool=await walk(dest)
			points.append({"target":[dest.x,dest.y],"passed":ok,"position":str(main.player.position)})
			passed=passed and ok
			if not ok:break
		var entry:={"test":path[0],"passed":passed,"points":points};results.append(entry);print("VENUE_ROUTE ",JSON.stringify(entry))
	for id in ["Z05_GARDEN_SEAT","Z06_READ_SEAT","N04_RIVER_SEAT"]:
		if selected!="":continue
		for action in main.world.interactions:
			if action.id!=id:continue
			main.player.position=action.pos;main.activate(action)
			var ok:bool=main.player.seated and main.player.position.distance_to(action.data.seat)<0.02 and main.save_game(false)
			main.player.stand_up();ok=ok and main.player.position.distance_to(action.pos)<0.02
			results.append({"test":id+"_sit_save_stand","passed":ok});print("SEAT_ROUTE ",id," ",ok)
	var failed:=0
	for row in results:
		if not row.passed:failed+=1
	if results.is_empty():failed+=1
	var file:=FileAccess.open("res://reports/venue_routes"+("_"+selected if selected!="" else "")+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failed,"selected_case":selected,"scope":"20 automated physical route groups and three seat/save/stand checks when unfiltered; independent starts, no replacement for complete manual tour"},"\t"));file.close()
	main.stop_media();main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
