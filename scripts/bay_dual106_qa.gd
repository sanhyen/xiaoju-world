extends RefCounted
## One consolidated physical and audiovisual run; normal saves are read only.
var m
var q
const Registry=preload("res://scripts/location_registry.gd")
func route(points:Array)->bool:
	for p in points:
		if not await q.walk(Vector2(p[0],p[2]),Vector2(m.player.position.x-p[0],m.player.position.z-p[2]).length()/8+3,.45):return false
	return true
func prepare(p:Vector3):
	m.player.enabled=false;m.player.stand_up();m.player.position=p+Vector3.UP*1.5;m.player.velocity=Vector3.ZERO
	await m.world.prepare_region(p,105)
	for i in 4:await m.get_tree().physics_frame
func run(main,qa):
	m=main;q=qa;var cfg:Dictionary=m.world.layout.config
	if m.qa_mode.contains("probe"):
		await boat_obstacle_probe();return
	if m.qa_mode.contains("ports"):
		await last_ports();return
	if m.qa_mode.contains("routes"):
		q.sampling=true
		var ground:Dictionary=cfg.roads.filter(func(a):return a.id=="forest106_loop")[0]
		await q.move_to(m.world.layout.vector(ground.points[0])+Vector3.UP*.3);q.check("final_ground_loop_after_access_opening",await route(ground.points),str(m.player.position))
		await boats();q.sampling=false;q.finish();return
	if m.qa_mode.contains("close"):
		await close_run();return
	if m.qa_mode.contains("repair"):
		await repair_run();return
	var ids:Array=m.world.interactions.map(func(a):return a.id)
	var old:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/protected_interactions_0105.json"))
	q.check("all_415_old_ids_and_original_content",old.size()==415 and old.all(func(id):return id in ids) and m.world.spec.buildings.size()==13 and m.world.spec.zones.size()==9 and cfg.living_houses.size()==14 and cfg.street_wings.size()==4,{"old_ids":old.size(),"current_ids":ids.size(),"bounds":m.world.building_bounds.size()})
	var unique:Dictionary={}
	for id in ids:unique[id]=true
	q.check("unique_all_static_and_public_ids",unique.size()==ids.size())
	q.check("second_island_real_area_and_connections",cfg.island2.buildings.size()==6 and cfg.theme_rooms.size()==6 and cfg.sea_walk.routes.size()==5 and cfg.public_boats.size()==16 and cfg.future_islands[0].enabled,{"land_ratio":float(cfg.island2.radius[0])*float(cfg.island2.radius[1])/(42*28),"nature":cfg.island2.nature_fraction})
	var normal=preload("res://scripts/save_store.gd").new();normal.directory="user://legacy_fixture/bay_v2"
	var normal_state:Dictionary=normal.read()
	if not normal_state.is_empty():
		var before:Dictionary=normal_state.duplicate(true);m.store.write(normal_state);await m.start_game(true);m.player.enabled=false;m.player.program_driven=true
		q.check("latest_0105_save_read_and_fields_retained",m.state.get("inventory",{})==before.get("inventory",{}) and m.state.stamps==before.stamps and m.state.shots==before.shots and m.state.get("playlist",[])==before.get("playlist",[]),{"source_updated_at":before.get("updated_at",""),"position":m.state.position,"read_only_source":normal.directory})
	else:q.check("latest_0105_save_read_and_fields_retained",false,"normal save unavailable")
	q.sampling=true
	for id in ["sunshine_forest","island_link106","island_landing"]:
		var r:Dictionary=cfg.sea_walk.routes.filter(func(v):return v.id==id)[0]
		await q.move_to(m.world.layout.vector(r.points[0])+Vector3.UP*.25)
		q.check("physical_continuous_bridge_"+id,await route(r.points),str(m.player.position))
	for r in cfg.island2.canopy_routes:
		await q.move_to(m.world.layout.vector(r.points[0])+Vector3.UP*.3)
		q.check("physical_canopy_"+r.id,await route(r.points),str(m.player.position))
	var loop:Dictionary=cfg.roads.filter(func(v):return v.id=="forest106_loop")[0]
	await q.move_to(m.world.layout.vector(loop.points[0])+Vector3.UP*.3);q.check("forest_ground_loop_walkable",await route(loop.points),str(m.player.position))
	for h in cfg.island2.buildings:
		var p:Vector3=m.world.layout.vector(h.center);await q.move_to(p+Vector3(0,.3,h.size[1]*.5+.8))
		q.check("enter_"+h.id,(await q.walk(Vector2(p.x,p.z+1.2),4,.35)) and m.world.inside_building(m.player.position)==h.id,str(m.player.position))
	for id in cfg.annexes:
		var a:Dictionary=cfg.annexes[id];await q.move_to(m.world.layout.vector(a.stairs[0])+Vector3.UP*.3)
		q.check("guarded_annex_stairs_"+id,await route(a.stairs),str(m.player.position))
	for h in cfg.living_houses:
		if not h.loft:continue
		await q.move_to(m.world.layout.vector(h.stairs[0])+Vector3.UP*.3);q.check("guarded_loft_stairs_"+h.id,await route(h.stairs),str(m.player.position))
	var cafe:Dictionary=m.world.layout.venues.B02
	await q.move_to(Vector3(cafe.x+6,cafe.floor_y+.3,cafe.z-6.5));var cafe_ok:bool=await q.walk(Vector2(cafe.x+6,cafe.z+6.4),6,.4)
	cafe_ok=(await q.walk(Vector2(cafe.x,cafe.z+6.4),4)) and cafe_ok;cafe_ok=(await q.walk(Vector2(cafe.x,cafe.z+10),4)) and cafe_ok
	q.check("cafe_floor_stair_and_outer_balcony",cafe_ok and m.player.position.y>cafe.floor_y+3.4,str(m.player.position))
	# Test real rail collision across all generated rail runs, sorted by streaming cell.
	var groups:Dictionary={};var manifest=m.world.streamer.manifest
	for group in manifest.authored_counts.get("guardrails106",[]):
		for record in group.rails:
			var mid:Vector3=(record.a+record.c)*.5;var key:=Vector2i(floori(mid.x/96),floori(mid.z/96))
			if not groups.has(key):groups[key]=[]
			groups[key].append(record)
	var misses:Array=[];var ray_count:=0
	for key in groups:
		var p:=Vector3(key.x*96+48,2,key.y*96+48);await prepare(p)
		var space:PhysicsDirectSpaceState3D=m.world.get_world_3d().direct_space_state
		for record in groups[key]:
			var mid:Vector3=(record.a+record.c)*.5+Vector3.UP*.6;var d:Vector3=(record.c-record.a).normalized();var side:=Vector3(-d.z,0,d.x).normalized()
			var ray:=PhysicsRayQueryParameters3D.create(mid-side*.4,mid+side*.4,1,[m.player.get_rid()]);ray_count+=1
			if space.intersect_ray(ray).is_empty():misses.append({"tag":record.tag,"point":str(mid)})
	q.check("all_generated_exposed_edges_have_physical_rails",ray_count>150 and misses.is_empty(),{"rays":ray_count,"missing":misses})
	await shallow_routes()
	# A single camera sweep per affected floor family also records geometric separation.
	var floor_gaps:Array=[]
	for r in cfg.theme_rooms:
		var p:Vector3=m.world.layout.vector(r.center);floor_gaps.append(p.y-m.world.height_at(p.x,p.z))
	for a in cfg.annexes.values():
		var p:Vector3=m.world.layout.vector(a.center);floor_gaps.append(p.y-m.world.height_at(p.x,p.z))
	q.check("indoor_terrain_below_supported_slabs",floor_gaps.all(func(v):return v>=.15),floor_gaps)
	for id in ["ISLAND_02","TREEHOUSE_2","FOREST_ONSEN","THEME_EVERYDAY","THEME_DAILY","H05_UPPER","B07_UPPER"]:
		var place:Dictionary=Registry.find(m.world.spec,id);await m.teleport_zone(place);m.player.enabled=false
		q.check("map_fast_travel_correct_level_"+id,not place.is_empty() and Vector2(m.player.position.x-place.safe[0],m.player.position.z-place.safe[2]).length()<2 and absf(m.player.position.y-float(place.safe[1])-float(cfg.sea_y))<.65,str(m.player.position))
	await forest_actions();await room_actions();await boats()
	q.sampling=false
	await visuals()
	q.check("new_state_saved",m.save_game(false));var saved:Dictionary=m.state.duplicate(true);await m.start_game(true);m.player.enabled=false
	q.check("cold_read_new_island_room_and_fleet_fields",m.state.activities.dual106==saved.activities.dual106 and m.state.activities.island_02_state==saved.activities.island_02_state and m.state.activities.get("moored_boats",[])==saved.activities.get("moored_boats",[]) and m.state.activities.get("public_boat_sources106",{})==saved.activities.get("public_boat_sources106",{}))
	q.finish()

func shallow_routes():
	var cfg:Dictionary=m.world.layout.config
	for x in [-285.0,-60.0,165.0]:
		var z:float=m.world.layout.shore_z(x);await q.move_to(m.world.surface(x,z+10,.3));var ok:bool=await q.walk(Vector2(x,z+23),5,.5);ok=(await q.walk(Vector2(x,z+9),5,.5)) and ok
		q.check("mainland_continuous_wade_"+str(int(x)),ok and not m.player.water_edge_blocked,str(m.player.position))
	for island in [cfg.island,cfg.island2]:
		for i in 4:
			var angle:float=(i+.25)*TAU/4 if i!=3 else PI*1.5;var center:=Vector2(island.center[0],island.center[1]);var offset:=Vector2(cos(angle)*island.radius[0],sin(angle)*island.radius[1]);var start:Vector2=center+offset*1.08;var outer:Vector2=center+offset*1.32
			await q.move_to(m.world.surface(start.x,start.y,.3));var ok:bool=await q.walk(outer,5,.45);ok=(await q.walk(start,5,.45)) and ok
			q.check(("coral" if island==cfg.island else "forest")+"_wade_return_"+str(i),ok and not m.player.water_edge_blocked,str(m.player.position))
	for i in 4:
		var x:float=276+(4 if i in [1,2] else 0);var z:float=426+i*15+8.5
		await q.move_to(Vector3(x+2.5,-.5,z));var ok:bool=await q.walk(Vector2(x+7.8,z),5,.2);ok=(await q.walk(Vector2(x+2.5,z),5,.2)) and ok
		q.check("villa_ladder_down_and_back_"+str(i),ok,str(m.player.position))

func forest_actions():
	var dual=m.bay.dual;m.set_time(2)
	for i in 3:
		await q.move_to(m.world.layout.vector(m.world.layout.config.island2.observation_points[i]));dual.action("firefly_"+str(i))
	q.check("firefly_book_and_visible_avoidance",dual.island_data().observed.size()==3 and dual.fireflies.visible)
	await q.move_to(m.world.layout.vector([-59,6.5,517.2]))
	for i in 8:dual.action("star")
	q.check("rotating_star_chart_records",dual.island_data().star_records.size()>0 and dual.models.star.get_node("StarWheel")!=null)
	await q.move_to(m.world.layout.vector([-94,5.4,494]));dual.action("valve");await m.get_tree().create_timer(.5).timeout
	q.check("valve_water_and_steam_change",dual.island_data().temperature in [0,1,2] and is_instance_valid(dual.models.valve.get_node("WaterStream")))
	await q.move_to(m.world.layout.vector([-30,10.2,487]));var before:int=dual.island_data().letters.size();dual.action("mail")
	q.check("postcard_stamp_and_mainland_journal",dual.island_data().letters.size()==before+1 and "FOREST_MAIL" in m.state.cards)
	var pool:Dictionary=m.world.layout.config.island2.pools[0];var p:Vector3=m.world.layout.vector(pool.center)
	await q.move_to(p+Vector3(0,.3,-5));var ok:bool=await q.walk(Vector2(p.x,p.z),5,.45);ok=(await q.walk(Vector2(p.x,p.z-5),5,.45)) and ok
	q.check("onsen_steps_in_and_out",ok,str(m.player.position));m.set_time(0)

func room_actions():
	var dual=m.bay.dual
	for room in m.world.layout.config.theme_rooms:
		var p:Vector3=m.world.layout.vector(room.center);await q.move_to(p+Vector3(0,.3,room.size[1]*.5+.9))
		q.check("real_room_entrance_"+room.id,(await q.walk(Vector2(p.x,p.z+1.6),4,.35)) and m.world.inside_building(m.player.position)==room.id,str(m.player.position))
		m.state.playlist=["dual_everyday"];m.bay.next_song();await m.get_tree().create_timer(.25).timeout
		await m.show_video(room.id,room.program);await m.get_tree().create_timer(1.2).timeout;m.bay.update_audio()
		var picture:Image=m.video_viewport.get_texture().get_image();var values:Array=[]
		for x in range(80,picture.get_width()-80,160):values.append(picture.get_pixel(x,picture.get_height()/2).r)
		q.check("local_video_decodes_"+room.program,m.video.is_playing() and m.video.stream_position>.4 and values.max()-values.min()>.015 and m.bay.music.stream_paused,{"position":m.video.stream_position,"image_range":values.max()-values.min()})
		m.close_modal();m.bay.update_audio();q.check("media_focus_releases_"+room.id,m.video.stream==null and not m.bay.music.stream_paused);m.bay.music.stop();m.bay.music.stream=null
		var key:String=room.id.trim_prefix("THEME_").to_lower();var topic:String={"everyday":"record","waiting":"street","poem":"journal","frost":"frost_light","blossom":"clue_0","daily":"print"}[key];var before:int=dual.data().rooms[key].actions;dual.action(topic)
		q.check("physical_room_action_"+key,int(dual.data().rooms[key].actions)>before and is_instance_valid(dual.models[key]))

func boats():
	var boats=m.bay.boats;var cfg:Dictionary=m.world.layout.config
	var invalid:Array=[]
	for island in [cfg.island,cfg.island2]:
		for i in 48:
			var a:float=i*TAU/48;var p:=Vector3(island.center[0]+cos(a)*(island.radius[0]+35),-2.2,island.center[1]+sin(a)*(island.radius[1]+35))
			if boats.water_at(p).is_empty():invalid.append(str(p))
	q.check("continuous_35m_outer_sailing_margin_both_islands",invalid.is_empty(),invalid)
	for source in cfg.public_boats:
		var p:Vector3=m.world.layout.vector(source.water)
		q.check("public_boat_float_and_stand_"+source.id,not boats.water_at(p).is_empty() and m.world.layout.shallow_or_dry(m.world.surface(source.shore[0],source.shore[2],.15)))
	var source:Dictionary=cfg.public_boats.filter(func(v):return v.id=="COAST_3")[0];await q.move_to(m.world.layout.vector(source.shore));boats.sync_public_boats()
	var ok:bool=await boats.board_public(source.id);m.player.program_driven=false;m.player.enabled=true;boats.testing=true;boats.test_input=Vector2(0,1)
	q.check("physical_F_public_board",ok and boats.kind=="yacht")
	var began:Vector3=m.player.position;await m.get_tree().create_timer(4).timeout;boats.test_input=Vector2.ZERO;boats.speed=0;await m.get_tree().create_timer(.6).timeout
	q.check("yacht_acceleration_and_source_replenishment",m.player.position.distance_to(began)>15 and boats.public_models.has(source.id),{"distance":m.player.position.distance_to(began),"speed_max":8})
	var afloat:Vector3=m.player.position;boats.test_input=Vector2.ZERO;boats.speed=0;m.save_game(false);await m.start_game(true);m.player.program_driven=false;m.player.enabled=true
	q.check("active_boat_cold_recovery_exact_position",boats.kind=="yacht" and m.player.position.distance_to(afloat)<.5,{"before":str(afloat),"after":str(m.player.position)})
	# Run one continuous open-water loop through both island surrounds and beneath high spans.
	# Pass outside the visible hotel footprint and its stair rails, not through the villas.
	var points:Array=[Vector2(-60,395),Vector2(-150,490),Vector2(-60,565),Vector2(35,550),Vector2(145,550),Vector2(225,550),Vector2(325,535),Vector2(325,455),Vector2(325,375),Vector2(225,370),Vector2(145,410),Vector2(25,420),Vector2(-60,405)]
	var failed:Array=[]
	for target in points:
		if not await ship_to(target,50):failed.append({"target":str(target),"actual":str(m.player.position)});break
	q.check("physical_sail_both_islands_and_bridge_clearance",failed.is_empty(),failed)
	boats.test_input=Vector2.ZERO;boats.speed=0
	q.check("deep_sea_dismount_gives_direction",not await boats.dock() and not boats.kind.is_empty() and not boats.shore_hint().is_empty())
	# Return continuously to the sunshine shallow bank, then keep the exact parked vessel.
	await ship_to(Vector2(-60,m.world.layout.shore_z(-60)+21),65);boats.test_input=Vector2.ZERO;boats.speed=0;var at:Vector3=m.player.position;var before:int=m.state.activities.get("moored_boats",[]).size()
	var docked:bool=await boats.dock();boats.testing=false;m.player.program_driven=true;m.player.enabled=false
	q.check("continuous_shore_dismount_and_saved_boat",docked and m.state.activities.moored_boats.size()==before+1 and m.player.position.distance_to(at)<9.5,{"boat":str(at),"shore":str(m.player.position)})

func ship_to(target:Vector2,timeout:float)->bool:
	var boats=m.bay.boats;var end:int=Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<end:
		await m.get_tree().physics_frame
		var d:Vector2=target-Vector2(m.player.position.x,m.player.position.z)
		if d.length()<3:boats.test_input=Vector2.ZERO;boats.speed=0;return true
		var wanted:float=atan2(-d.x,-d.y);var diff:float=angle_difference(boats.heading,wanted)
		boats.test_input=Vector2(clampf(-diff*2.8,-1,1),.4 if absf(diff)>.7 else 1.0)
	return false

func boat_obstacle_probe():
	var boats=m.bay.boats
	await boats.begin_board("yacht",Vector3(278.7348,-2.2,481.6092),-PI*.5)
	m.player.program_driven=false;m.player.enabled=true;boats.testing=true
	await ship_to(Vector2(307,455),3)
	var hits:Array=[]
	for i in m.player.get_slide_collision_count():
		var hit:KinematicCollision3D=m.player.get_slide_collision(i);var body:CollisionObject3D=hit.get_collider();var owner:Node=body.shape_owner_get_owner(body.shape_find_owner(hit.get_collider_shape_index()))
		hits.append({"point":str(owner.global_position),"normal":str(hit.get_normal()),"shape_size":str(owner.shape.size) if owner is CollisionShape3D and owner.shape is BoxShape3D else str(owner)})
	q.check("outer_boat_obstacle_diagnosis",true,{"position":str(m.player.position),"depth":boats.water_at(m.player.position),"shapes":hits});q.finish()

func visuals():
	await q.move_to(m.world.layout.vector(m.world.layout.config.island2.observation_points[0]));await m.get_tree().create_timer(.4).timeout
	m.set_time(0);await m.qa_capture("dual106_forest_day_"+m.qa_mode,Vector3(-124,32,543),Vector3(-48,5,488))
	m.set_time(2);await m.qa_capture("dual106_forest_night_"+m.qa_mode,Vector3(-84,5,480),Vector3(-81,4,487))
	m.set_time(0);await q.move_to(m.world.layout.vector([-60,2.4,461]));m.show_map();await m.get_tree().create_timer(.8).timeout
	await m.wait_for_viewport_draw();m.get_viewport().get_texture().get_image().save_png(m.evidence_root+"screenshots/dual106_map_"+m.qa_mode+".png");m.close_modal()
	await m.qa_capture("dual106_two_island_bridges_"+m.qa_mode,Vector3(52,88,558),Vector3(64,0,442))

func repair_run():
	var cfg:Dictionary=m.world.layout.config
	q.sampling=true
	var ids:Array=m.world.interactions.map(func(a):return a.id);var old:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/protected_interactions_0105.json"))
	q.check("all_415_existing_ids_after_repairs",old.all(func(id):return id in ids))
	for road in cfg.sea_walk.routes:
		await q.move_to(m.world.layout.vector(road.points[0])+Vector3.UP*.3)
		q.check("repaired_full_bridge_"+road.id,await route(road.points),str(m.player.position))
	for road in cfg.island2.canopy_routes:
		await q.move_to(m.world.layout.vector(road.points[0])+Vector3.UP*.3)
		q.check("repaired_canopy_"+road.id,await route(road.points),str(m.player.position))
	var ground:Dictionary=cfg.roads.filter(func(a):return a.id=="forest106_loop")[0]
	await q.move_to(m.world.layout.vector(ground.points[0])+Vector3.UP*.3);q.check("repaired_ground_ring_ports",await route(ground.points),str(m.player.position))
	for h in cfg.living_houses:
		if not h.loft:continue
		var p:Vector3=m.world.layout.vector(h.center);await q.move_to(p+Vector3(0,.4,h.size[1]*.5+1.4));var entry:Array=h.stairs[0]
		var access:bool=await q.walk(Vector2(p.x,entry[2]),4,.45);access=(await q.walk(Vector2(entry[0],entry[2]),4,.45)) and access
		q.check("real_ground_approach_"+h.id,access,str(m.player.position))
		q.check("repaired_loft_stair_"+h.id,await route(h.stairs),str(m.player.position))
	await shallow_routes();await forest_actions()
	await q.move_to(m.world.layout.vector([-30,10.2,487]));q.check("new_card_save_is_valid",m.save_game(false),m.store.last_error)
	var saved:Dictionary=m.state.duplicate(true);await m.start_game(true);m.player.program_driven=true;m.player.enabled=false
	q.check("new_card_and_forest_state_cold_recovery",m.state.activities.get("island_02_state",{})==saved.activities.island_02_state and "FOREST_MAIL" in m.state.cards)
	await boats()
	q.check("fleet_and_public_source_save",m.save_game(false),m.store.last_error);saved=m.state.duplicate(true);await m.start_game(true);m.player.program_driven=true;m.player.enabled=false
	q.check("fleet_and_source_cold_recovery",m.state.activities.get("moored_boats",[])==saved.activities.get("moored_boats",[]) and m.state.activities.get("public_boat_sources106",{})==saved.activities.get("public_boat_sources106",{}))
	q.sampling=false;await visuals();q.finish()

func same_saved(a:Variant,b:Variant)->bool:
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))

func last_ports():
	q.sampling=true
	var cfg:Dictionary=m.world.layout.config;var ground:Dictionary=cfg.roads.filter(func(a):return a.id=="forest106_loop")[0]
	await q.move_to(m.world.layout.vector(ground.points[0])+Vector3.UP*.3);q.check("final_ground_loop_after_observatory_detour",await route(ground.points),str(m.player.position))
	await q.move_to(m.world.layout.vector([-58.16,6.2,523.8])+Vector3.UP*.2)
	q.check("ground_ring_to_observatory_front_entrance",await q.walk(Vector2(-59,517.4),5,.4) and m.world.inside_building(m.player.position)=="FOREST_OBSERVATORY",str(m.player.position))
	var access:Dictionary=cfg.island2.canopy_routes[2];await q.move_to(m.world.layout.vector(access.points[0])+Vector3.UP*.3);q.check("canopy_south_connection_after_ground_detour",await route(access.points),str(m.player.position))
	var rails:=0;var misses:Array=[];var space:PhysicsDirectSpaceState3D=m.world.get_world_3d().direct_space_state
	for group in m.world.streamer.manifest.authored_counts.get("guardrails106",[]):
		if group.tag!="forest_canopy":continue
		for record in group.rails:
			var mid:Vector3=(record.a+record.c)*.5+Vector3.UP*.6;var d:Vector3=(record.c-record.a).normalized();var side:=Vector3(-d.z,0,d.x).normalized();rails+=1
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(mid-side*.4,mid+side*.4,1,[m.player.get_rid()])).is_empty():misses.append(str(mid))
	q.check("final_forest_guardrails_physical_edges",rails>50 and misses.is_empty(),{"rays":rails,"missing":misses})
	await q.move_to(m.world.layout.vector(cfg.theme_rooms[5].center)+Vector3(0,.2,1.5))
	await m.show_video("THEME_DAILY","dual_studio");await m.get_tree().create_timer(1.8).timeout
	q.check("official_studio_behind_the_scenes_decodes",m.video.is_playing() and m.video.stream_position>.6 and m.video.stream.resource_path.ends_with("studio.ogv"),{"path":m.video.stream.resource_path,"position":m.video.stream_position});m.close_modal()
	q.sampling=false;q.finish()

func close_run():
	q.sampling=true
	var cfg:Dictionary=m.world.layout.config
	var ground:Dictionary=cfg.roads.filter(func(a):return a.id=="forest106_loop")[0]
	await q.move_to(m.world.layout.vector(ground.points[0])+Vector3.UP*.3);q.check("final_forest_ground_loop",await route(ground.points),str(m.player.position))
	var access:Dictionary=cfg.island2.canopy_routes[2];await q.move_to(m.world.layout.vector(access.points[0])+Vector3.UP*.3)
	q.check("final_canopy_south_junction",await route(access.points),str(m.player.position))
	await forest_actions()
	var dual=m.bay.dual;dual.action("clue_0");dual.action("clue_1");dual.action("clue_2");dual.action("print")
	q.check("final_new_fields_write",m.save_game(false),m.store.last_error)
	var saved:Dictionary=m.state.duplicate(true);await m.start_game(true);m.player.program_driven=true;m.player.enabled=false;dual.data()
	q.check("final_semantic_forest_room_card_recovery",same_saved(m.state.activities.island_02_state,saved.activities.island_02_state) and same_saved(m.state.activities.dual106,saved.activities.dual106) and "FOREST_MAIL" in m.state.cards)
	m.set_time(2);var before:int=dual.island_data().observed.size();dual.action("firefly_0");var room_count:int=dual.data().rooms.blossom.clues.size();dual.action("clue_0")
	q.check("numeric_collection_ids_idempotent_after_cold_read",dual.island_data().observed.size()==before and dual.data().rooms.blossom.clues.size()==room_count)
	await boats()
	q.check("final_fleet_save",m.save_game(false),m.store.last_error);saved=m.state.duplicate(true);await m.start_game(true);m.player.program_driven=true;m.player.enabled=false
	q.check("final_fleet_and_source_cold_recovery",same_saved(m.state.activities.get("moored_boats",[]),saved.activities.get("moored_boats",[])) and same_saved(m.state.activities.get("public_boat_sources106",{}),saved.activities.get("public_boat_sources106",{})))
	q.sampling=false;await visuals();q.finish()
