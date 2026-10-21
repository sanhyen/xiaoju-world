extends RefCounted
var m
var q
func run(main,qa):
	m=main;q=qa;q.sampling=true
	var layout=m.world.layout
	var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_095_bay_v1.json"))
	var ids:Array=m.world.interactions.map(func(a):return a.id)
	q.check("preserve_eight_zones_thirteen_venues_old_ids",m.world.spec.zones.size()==8 and m.world.building_bounds.size()==13 and old.protected_interaction_ids.all(func(id):return id in ids))
	# Walk across the entire physical loop, including the island ramp, without teleports between arcs.
	var west:Dictionary=layout.config.sea_walk.routes[0];var east:Dictionary=layout.config.sea_walk.routes[1];var landing:Dictionary=layout.config.sea_walk.routes[2]
	var approach:Vector3=layout.vector(west.points[0])+Vector3(0,2,-7)
	await q.move_to(approach)
	q.check("walk_from_mainland_onto_west_entrance",await q.walk(Vector2(west.points[0][0],west.points[0][2]),5,.35))
	for route in [west,landing]:
		var ok:=true
		for point in route.points:
			if not await q.walk(Vector2(point[0],point[2]),5,.35):ok=false;break
		q.check("continuous_"+route.id,ok,str(m.player.position))
	var back:Array=landing.points.duplicate();back.reverse()
	for point in back:await q.walk(Vector2(point[0],point[2]),5,.35)
	var east_ok:=true
	for point in east.points:
		if not await q.walk(Vector2(point[0],point[2]),5,.35):east_ok=false;break
	q.check("continuous_east_arc_back_to_other_mainland",east_ok,str(m.player.position))
	# Both land and island shorelines: move from dry sand into actual water, pause, and walk back.
	for x in [-160.0,-60.0,130.0,390.0]:
		var start:=Vector3(x,layout.height_at(Vector2(x,layout.shore_z(x)-3))+.3,layout.shore_z(x)-3)
		await q.move_to(start)
		var target:=Vector2(x,layout.shore_z(x)+23)
		var ok:bool=await q.walk(target,6,.35)
		var at:Vector3=m.player.position
		await m.get_tree().create_timer(.5).timeout
		q.check("mainland_wade_"+str(int(x)),ok and m.player.position.distance_to(at)<.2 and m.player.position.y<float(layout.config.sea_y)-.45,{"position":str(at),"depth":float(layout.config.sea_y)-at.y})
		q.check("mainland_return_on_foot_"+str(int(x)),await q.walk(Vector2(start.x,start.z),6,.4))
	await q.move_to(Vector3(190,1,440))
	var island_ok:bool=await q.walk(Vector2(169,440),6,.4)
	q.check("island_wade_without_recovery",island_ok and m.player.position.y<float(layout.config.sea_y)-.4,str(m.player.position))
	q.check("island_return_on_foot",await q.walk(Vector2(190,440),6,.4))
	# Hold ordinary movement path past the limit: player stops locally rather than returning to safe_point.
	await q.move_to(Vector3(-60,-2,layout.shore_z(-60)+22))
	var before:Vector3=m.player.position
	m.player.automated_motion=true;m.player.automated_horizontal=Vector2(0,9.36)
	await m.get_tree().create_timer(3).timeout
	m.player.automated_motion=false;m.player.automated_horizontal=Vector2.ZERO;m.player.velocity=Vector3.ZERO
	q.check("deep_edge_stops_locally_not_teleported",m.player.water_edge_blocked and m.player.position.z>=before.z and m.player.position.z<before.z+20 and absf(m.player.position.x-before.x)<.2,str(m.player.position))
	q.check("shallow_position_save",m.save_game(false) and m.store.read().get("position",[]).size()==3)
	# Sail physically under a high bridge span using the existing boat controller.
	var boats=m.bay.boats
	for dock_i in [2,3,4,5,6]:
		var dock:Dictionary=layout.config.boat_docks[dock_i]
		var outlet_ok:=true
		var forward:=Vector3(-sin(float(dock.heading)),0,-cos(float(dock.heading)))
		for meters in [0,1,2,3,4,6,8]:
			if boats.water_at(layout.vector(dock.water)+forward*meters).is_empty():outlet_ok=false
		q.check("preserve_coastal_boat_outlet_"+str(dock_i),outlet_ok)
	for route in [west,east]:
		var points:Array=route.points;var i:int=int(points.size()*.45);var at:Vector3=layout.vector(points[i]);var along:Vector3=(layout.vector(points[i+1])-at).normalized();var side:=Vector3(-along.z,0,along.x)
		var start:Vector3=at-side*9;start.y=float(layout.config.sea_y)+.2
		await q.move_to(layout.vector(west.points[0]))
		m.player.program_driven=false;m.player.enabled=true
		var boarded:bool=await boats.begin_board("yacht",start,atan2(-side.x,-side.z))
		boats.testing=true;boats.test_input=Vector2(0,1)
		await m.get_tree().create_timer(6).timeout
		q.check("yacht_passes_under_"+route.id,boarded and (m.player.position-start).dot(side)>15,{"distance":(m.player.position-start).dot(side),"position":str(m.player.position)})
		boats.testing=false;boats.leave_for_travel();m.player.program_driven=true;m.player.enabled=false
	q.sampling=false
	await m.qa_capture("sea104_loop",Vector3(440,155,590),Vector3(230,0,420))
	await q.move_to(Vector3(-60,-2,layout.shore_z(-60)+20))
	await m.qa_capture("sea104_wading",m.player.position+Vector3(7,3,6),m.player.position+Vector3(0,.7,0))
	q.finish()
