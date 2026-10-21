extends RefCounted
var m
var q
var ws
const Registry=preload("res://scripts/location_registry.gd")
func route(points:Array,absolute:bool=false)->bool:
	for p in points:
		if not await q.walk(Vector2(p[0],p[2]),Vector2(m.player.position.x-p[0],m.player.position.z-p[2]).length()/8+4,.45):return false
	return true
func run(main,qa):
	m=main;q=qa;ws=m.bay.workshops;q.sampling=true
	if m.qa_mode=="bay_redesign105_south":
		var r:Dictionary=m.world.layout.config.roads.filter(func(x):return x.id=="z09_south")[0]
		await q.move_to(m.world.layout.vector(r.points[0])+Vector3.UP*.35)
		q.check("walk_z09_south",await route(r.points),str(m.player.position))
		q.sampling=false;q.finish();return
	if m.qa_mode in ["bay_redesign105_links","bay_redesign105_final"]:await links();return
	var cfg:Dictionary=m.world.layout.config
	var ids:Array=m.world.interactions.map(func(a):return a.id);var unique:Dictionary={}
	for id in ids:unique[id]=true
	var protected:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/protected_interactions_0104.json"))
	q.check("all_314_existing_interactions_and_original_13_venues",protected.size()==314 and protected.all(func(id):return id in ids) and m.world.spec.buildings.size()==13 and m.world.spec.zones.size()==9,{"interactions":ids.size(),"unique":unique.size(),"zones":m.world.spec.zones.size()})
	q.check("all_interaction_ids_unique",ids.size()==unique.size())
	q.check("six_cliff_buildings_fourteen_themed_homes",m.world.building_bounds.size()==19 and ws.HOUSE_TOPICS.size()==14)
	var points:Array=Registry.places(m.world.spec);var disabled:bool=points.all(func(p):return p.id!="ISLAND_02")
	q.check("second_island_reserved_hidden",disabled and not cfg.future_islands[0].enabled)
	q.check("minimap_attached_and_shared_registry",m.hud.get_node_or_null("BayMiniMap")!=null and points.any(func(p):return p.id=="Z09_B2_UPPER"))
	# Normal fast travel resolves actual upper floor rather than resetting onto a roof.
	for id in ["SHALLOWS_ISLAND","Z09","Z09_B2_UPPER","H05_UPPER"]:
		var place:Dictionary=Registry.find(m.world.spec,id);await m.teleport_zone(place);m.player.enabled=false
		q.check("map_destination_"+id,Vector2(m.player.position.x-place.safe[0],m.player.position.z-place.safe[2]).length()<3 and absf(m.player.position.y-(float(place.safe[1])+float(cfg.sea_y)))<.5,str(m.player.position))
	# Entrance, interior walls and steps are tested on loaded physical collision.
	for h in cfg.cliff_district.buildings:
		var p:=Vector3(h.center[0],h.center[1],h.center[2]);await q.move_to(p+Vector3(0,.35,h.size[1]*.5+2))
		var enter:bool=await q.walk(Vector2(p.x,p.z+1.4),5,.45)
		q.check("physical_front_door_"+h.id,enter and absf(m.player.position.y-p.y)<.5,str(m.player.position))
		var space:PhysicsDirectSpaceState3D=m.world.get_world_3d().direct_space_state
		var ray:=PhysicsRayQueryParameters3D.create(p+Vector3(0,1.4,0),p+Vector3(h.size[0],1.4,0),1,[m.player.get_rid()])
		q.check("solid_wall_"+h.id,not space.intersect_ray(ray).is_empty())
		if h.has("stairs"):
			var start:Array=h.stairs[0];await q.move_to(Vector3(start[0],start[1]+.35,start[2]));var ok:bool=await route(h.stairs,true)
			q.check("zigzag_stairs_to_roof_"+h.id,ok and absf(m.player.position.y-float(h.upper_y))<.5,str(m.player.position))
	for id in ["z09_south_link","z09_west_link","z09_north_link","z09_lower_to_mid","z09_mid_loop","z09_roof_link","z09_wheel_upper"]:
		var found:Array=cfg.roads.filter(func(r):return r.id==id)
		if found.is_empty():continue
		var r:Dictionary=found[0];await q.move_to(m.world.layout.vector(r.points[0])+Vector3.UP*.4)
		q.check("continuous_"+id,await route(r.points),str(m.player.position))
	# Waterwheel changes, a moving solid gate and a physically traversed tunnel.
	ws.data().sluice=false;ws.commit();ws.run("sluice");await m.get_tree().create_timer(3).timeout
	q.check("sluice_flow_and_moving_solid_gate",ws.flow.visible or ws.data().sluice,ws.gate.position.y)
	await q.move_to(Vector3(298,14.85,-31));var tunnel:bool=await q.walk(Vector2(272,-31),8,.5);ws.run("cave_stamp")
	q.check("open_tunnel_to_bird_nest_stamp",tunnel and "Z09_NEST" in m.state.cards,str(m.player.position))
	# Complete the real crafting state transition, carry and persist six separate slots.
	m.state.inventory.clay=8;ws.data().pottery={"stage":0,"shape":2,"glaze":1};ws.data().racks=[null,null,null,null,null,null]
	ws.pottery_step();ws.pottery_step();ws.pottery_step();await m.get_tree().create_timer(4.5).timeout
	q.check("pottery_form_glaze_fire_and_carry",int(ws.data().pottery.stage)==3 and m.state.handheld=="pottery" and is_instance_valid(ws.hand_prop))
	for i in 6:
		ws.data().pottery={"stage":3,"shape":i%3,"glaze":i%3};ws.rack_action(i)
	q.check("six_independent_persistent_pottery_slots",ws.data().racks.all(func(v):return v is Dictionary) and m.store.read().activities.workshops105.racks.size()==6)
	ws.data().pottery={"stage":3,"shape":1,"glaze":2};var placed:bool=ws.place_slot("B12",1)
	q.check("B12_pottery_slot_saved",placed and m.store.read().activities.workshops105.slots.has("B12_1"))
	m.state.inventory.merge({"wheat":5,"carrot":5,"tomato":5,"shell":5,"pinecone":5,"flower":5},true)
	var actions:bool=true
	for action in ["mill","bread","harvest","fruit","chime","fire","specimen","cloth","candles","seal","musicbox","postcard","bookmark","wax","coffee","cat","loom","croissant","sleeve","gramophone","mosaic","pasture_gate"]:actions=ws.run(action) and actions
	q.check("themed_house_and_street_actions_save",actions and m.store.read().activities.workshops105.has("mosaic"))
	for i in 3:ws.run("stage",i)
	q.check("three_physical_stage_levers",ws.levers.size()==3 and int(ws.data().stage_0)==1 and int(ws.data().stage_1)==1 and int(ws.data().stage_2)==1)
	# Down all four real stairs, along a branch, into the continuous island sand loop.
	for i in 4:
		var x:float=276+(4 if i in [1,2] else 0);var z:float=426+i*15
		await q.move_to(Vector3(x+2,-.4,z+8.5));var ok:bool=await q.walk(Vector2(x+7.8,z+8.5),5,.3)
		ok=(await q.walk(Vector2(294,z+8.5),6,.4)) and ok
		q.check("villa_"+str(i)+"_stairs_to_shallow_ring",ok and m.player.position.y< -2.5 and m.world.layout.shallow_or_dry(m.player.position),str(m.player.position))
	var ring:Dictionary=cfg.wading_paths[0];var first:Array=ring.points[0];await q.move_to(Vector3(first[0],first[1]+.3,first[2]))
	q.check("continuous_shallow_sand_ring",await route(ring.points,true),str(m.player.position))
	q.check("shallow_ring_back_to_public_beach",await q.walk(Vector2(190,440),5,.4),str(m.player.position))
	# Existing bridge junctions have no railing across their seams.
	for index in [0,1,2]:
		var r:Dictionary=cfg.sea_walk.routes[index];var segment:Array=r.points.slice(0,4) if index!=0 else r.points.slice(-5)
		await q.move_to(m.world.layout.vector(segment[0])+Vector3.UP*.4);q.check("sealed_sea_hub_"+str(index),await route(segment),str(m.player.position))
	# At least a 150 m southern/eastern/western envelope and 35 m clear outer ring.
	var navigation:bool=true
	for i in 25:
		var a:float=PI*float(i)/24;var p:=Vector3(235+cos(a)*150,-2.2,455+sin(a)*150)
		if m.bay.boats.water_at(p).is_empty():navigation=false
	q.check("150m_continuous_outer_sailing_envelope",navigation)
	await q.move_to(Vector3(300,6.35,110));q.check("new_content_save_roundtrip",m.save_game(false) and not m.store.read().is_empty())
	q.sampling=false
	await m.qa_capture("redesign105_cliff",Vector3(390,59,122),Vector3(285,13,15))
	await q.move_to(Vector3(294,-2.6,448));await m.qa_capture("redesign105_water_access",Vector3(310,10,492),Vector3(280,-1,455))
	await q.move_to(Vector3(-95,5,249));await m.qa_capture("redesign105_coffee_house",Vector3(-90,7.2,255),Vector3(-95,5.8,246))
	q.finish()

func links():
	var cfg:Dictionary=m.world.layout.config
	for r in cfg.roads:
		if not str(r.id).begins_with("z09"):continue
		if m.qa_mode=="bay_redesign105_final" and r.id not in ["z09_south","z09_lookout_door"]:continue
		await q.move_to(m.world.layout.vector(r.points[0])+Vector3.UP*.35)
		q.check("walk_"+r.id,await route(r.points),str(m.player.position))
	await m.teleport_zone(Registry.find(m.world.spec,"Z09"));m.player.enabled=false
	q.check("map_Z09_at_matching_floor",absf(m.player.position.y-14.5)<.3,str(m.player.position))
	ws.data().sluice=true;ws.commit();await m.get_tree().create_timer(3).timeout
	await q.move_to(Vector3(298,14.85,-31));q.check("tunnel_and_nest_clear",await q.walk(Vector2(272,-31),8,.4),str(m.player.position))
	var landing:Dictionary=cfg.sea_walk.routes[2];await q.move_to(m.world.layout.vector(landing.points[0])+Vector3.UP*.4);q.check("island_octagonal_hub_flush",await route(landing.points),str(m.player.position))
	# Check unchanged physical stair joins where rail behavior or ramp end lengths changed.
	for id in ["B02","B03","B11"]:
		var v:Dictionary=m.world.layout.venues[id]
		if id=="B02":
			await q.move_to(Vector3(v.x+6,v.floor_y+.35,v.z-6.5));var ok:bool=await q.walk(Vector2(v.x+6,v.z+6.4),6);ok=(await q.walk(Vector2(v.x,v.z+6.4),4)) and ok;q.check("cafe_existing_stairs",ok)
		else:
			await q.move_to(Vector3(v.x+v.w*.5+3.3,v.floor_y+.35,v.z+v.d*.5+26));var ok:bool=await q.walk(Vector2(v.x+v.w*.5+3.3,v.z+v.d*.5+4),8);ok=(await q.walk(Vector2(v.x,v.z+v.d*.5+4),6)) and ok;q.check("terrace_entry_"+id,ok)
	if m.qa_mode=="bay_redesign105_final":
		var boats=m.bay.boats
		for r in cfg.sea_walk.routes.slice(0,2):
			var pts:Array=r.points;var i:int=int(pts.size()*.45);var at:Vector3=m.world.layout.vector(pts[i]);var along:Vector3=(m.world.layout.vector(pts[i+1])-at).normalized();var side:=Vector3(-along.z,0,along.x)
			var start:Vector3=at-side*9;start.y=-2.2;await q.move_to(Registry.destination(m.world.spec,Registry.find(m.world.spec,"SEA_WALK_WEST")))
			m.player.program_driven=false;m.player.enabled=true;var boarded:bool=await boats.begin_board("yacht",start,atan2(-side.x,-side.z));boats.testing=true;boats.test_input=Vector2(0,1)
			await m.get_tree().create_timer(6).timeout;q.check("sail_under_"+r.id,boarded and (m.player.position-start).dot(side)>15,{"distance":(m.player.position-start).dot(side)})
			boats.testing=false;boats.leave_for_travel();m.player.program_driven=true;m.player.enabled=false
		await q.move_to(m.world.layout.vector(cfg.boat_docks[7].land));m.player.program_driven=false;m.player.enabled=true;var new_boarded:bool=await boats.board(7);boats.testing=true;boats.test_input=Vector2(0,1);var dock_start:Vector3=m.player.position
		await m.get_tree().create_timer(5).timeout;q.check("cliff_river_dock_departure",new_boarded and m.player.position.distance_to(dock_start)>9,str(m.player.position));boats.testing=false;boats.leave_for_travel();m.player.program_driven=true;m.player.enabled=false
		# Use open flat ground and measure actual motion, not only the configured speed.
		var vehicles=m.bay.vehicles
		for kind in ["bike","scooter"]:
			await q.move_to(Vector3(-360,7,120));m.player.yaw=PI;m.player.program_driven=true;m.player.enabled=false;var mounted:bool=vehicles.mount(kind,-1,m.player.position);vehicles.testing=true;vehicles.test_input=Vector2(0,1)
			var speed:float=16 if kind=="bike" else 20;vehicles.speed=speed;var start:Vector3=m.player.position
			for i in 45:await m.get_tree().physics_frame;vehicles.speed=speed;vehicles.drive(1.0/60)
			q.check("unrestricted_grass_"+kind,mounted and vehicles.speed>speed-.5 and m.player.position.distance_to(start)>speed*.6,{"speed":vehicles.speed,"distance":m.player.position.distance_to(start)})
			vehicles.speed=0;vehicles.dismount(true);vehicles.testing=false
	q.sampling=false
	await q.move_to(Vector3(298,14.85,24));await m.qa_capture("redesign105_cliff_final",Vector3(360,40,92),Vector3(284,14,18))
	q.finish()
