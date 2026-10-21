extends RefCounted
## A single grouped walk/ride/mooring/farm pass, with only milestone viewpoints.
var m
var q

func run(main,driver):
	m=main;q=driver;q.sampling=true;m.set_time(0)
	var frozen:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_095_bay_v1.json"));var ids:Array=m.world.interactions.map(func(a):return a.id);var unique:Dictionary={}
	for id in ids:unique[id]=true
	q.check("final_8_zones_13_original_venues",m.world.spec.zones.size()==8 and m.world.building_bounds.size()==13)
	q.check("final_87_legacy_ids_and_unique_all_ids",frozen.protected_interaction_ids.all(func(id):return id in ids) and ids.size()==unique.size(),ids.size())
	var bad_doors:Array=[]
	for v in m.world.spec.buildings:
		await q.move_to(Vector3(v.x,v.floor_y+.4,v.z+v.d*.5+1.5))
		if not await q.walk(Vector2(v.x,v.z+v.d*.5-1.5),5):bad_doors.append(v.id)
	q.check("final_13_main_doors",bad_doors.is_empty(),bad_doors)
	var annex:Dictionary=m.world.layout.config.annexes.B07
	await q.move_to(m.world.layout.vector(annex.stairs[0])+Vector3.UP*.3);var attic_ok:=true
	for a in annex.stairs.slice(1):
		if not await q.walk(Vector2(a[0],a[2]),6):attic_ok=false;break
	q.check("corrected_PB_attic_U_stair",attic_ok and m.player.position.y>m.world.layout.vector(annex.center).y+3.4,str(m.player.position))
	var houses:Array=[];var lofts:Array=[]
	for h in m.world.layout.config.living_houses:
		var p:Vector3=m.world.layout.vector(h.center)
		await q.move_to(p+Vector3(0,.3,h.size[1]*.5+1.7))
		if not await q.walk(Vector2(p.x,p.z+h.size[1]*.5-2),5):houses.append(h.id)
		if h.loft:
			await q.move_to(m.world.layout.vector(h.stairs[0])+Vector3.UP*.3);var ok:=true
			for a in h.stairs.slice(1):
				if not await q.walk(Vector2(a[0],a[2]),6):ok=false;break
			if ok:ok=await q.walk(Vector2(p.x,p.z),5)
			if not ok or m.player.position.y<p.y+3.1:lofts.append(h.id)
	q.check("eight_usable_house_doors",houses.is_empty(),houses)
	q.check("four_house_lofts_connected_to_real_floor",lofts.is_empty(),lofts)
	var wing_fail:Array=[]
	for wing in m.world.layout.config.street_wings:
		var p:Vector3=m.world.layout.vector(wing.center);await q.move_to(p+Vector3(0,.3,wing.size[1]*.5+1.2))
		if not await q.walk(Vector2(p.x,p.z+wing.size[1]*.5-1.5),5):wing_fail.append(wing.id)
	q.check("four_functional_street_side_wings",wing_fail.is_empty(),wing_fail)
	for i in 2:
		m.bay.details.unlock(i);var hidden:Dictionary=m.world.layout.config.hidden_views[i];await q.move_to(m.world.layout.vector(hidden.route[0])+Vector3.UP*.3);var ok:=true
		for a in hidden.route.slice(1):
			if not await q.walk(Vector2(a[0],a[2]),6):ok=false;break
		m.bay.details.hidden_view(i);m.photo_mode=false;m.hud.show();m.player.camera.current=true;m.player.enabled=false
		q.check("hidden_view_and_postcard_"+str(i),ok and hidden.card in m.state.cards)
	m.bay.details.set_season(3);m.state.gallery_preset=3
	q.check("new_postcards_and_winter_saved",m.save_game(false) and m.store.read().get("gallery_preset",-1)==3)
	# Three short affected slope sections replace whole-world repeated walking.
	for entry in [["music_garden",7,-1],["arts",11,-1],["east_mountain",0,4]]:
		var road:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id==entry[0])[0];var pts:Array=road.points.slice(entry[1],road.points.size() if entry[2]<0 else entry[2]+1);var ok:=true
		await q.move_to(m.world.layout.vector(pts[0])+Vector3.UP*.3)
		for a in pts.slice(1):
			if not await q.walk(Vector2(a[0],a[2]),maxf(6,Vector2(m.player.position.x-a[0],m.player.position.z-a[2]).length()/8+3)):ok=false;break
		q.check("corrected_slope_"+str(entry[0]),ok)
	# Actual sea-bed collision and the normal recovery rule both permit shallow walking.
	var sea:float=m.world.layout.config.sea_y;var x:float=90;var z:float=m.world.layout.shore_z(x)+8
	await q.move_to(Vector3(x,m.world.height_at(x,z)+.25,z));var wade:bool=await q.walk(Vector2(x+3,m.world.layout.shore_z(x+3)+10),6)
	await m.get_tree().create_timer(.6).timeout
	q.check("mainland_shallow_walk_without_return",wade and m.player.position.y<sea and absf(m.player.position.x-93)<1,str(m.player.position))
	await q.move_to(Vector3(172,m.world.height_at(172,450)+.3,450));wade=await q.walk(Vector2(174,449),5);await m.get_tree().create_timer(.6).timeout
	q.check("island_shallow_walk_without_return",wade and m.player.position.y<sea and absf(m.player.position.x-174)<1,str(m.player.position))
	var pool:Dictionary=m.world.layout.config.play_pool;var p:Vector3=m.world.layout.vector(pool.center);await q.move_to(p+Vector3(0,.3,8));var pool_ok:=true
	for zz in [6.5,5.7,4.9,4.1,3.3,1.0]:
		if not await q.walk(Vector2(p.x,p.z+zz),5,.12):pool_ok=false;break
	q.check("pool_five_steps_and_real_shallow_floor",pool_ok and absf(m.player.position.y-(sea+pool.bed_h_sea))<.25,str(m.player.position))
	var village=m.bay.village;village.defaults();village.refresh_field();await q.move_to(m.world.layout.vector(m.world.layout.config.farm.center)+Vector3(0,.3,23.7))
	var initial:int=int(m.state.inventory.get("wheat",0));var harvested:bool=village.harvest(0);var planted:bool=village.plant(0,1);var watered:bool=village.water(0)
	q.check("farm_real_harvest_plant_water_and_model",harvested and planted and watered and int(m.state.inventory.get("wheat",0))==initial+4 and int(m.state.activities.farm_plots["0"].stage)==1)
	await q.move_to(m.world.layout.vector(m.world.layout.config.pasture.center)+Vector3(0,.3,21));var before:Vector3=village.animals[0].node.position;var fed:bool=village.feed("sheep")
	await m.get_tree().create_timer(2).timeout
	q.check("sheep_pigs_feed_and_actual_movement",fed and village.animals.size()==8 and village.animals[0].node.position.distance_to(before)>.4,{"from":str(before),"to":str(village.animals[0].node.position)})
	var v=m.bay.vehicles;await q.move_to(m.world.layout.vector(m.world.layout.config.docks[5]));m.state.handheld="bouquet";m.state.activities.bouquet_colors=[0,1,2,3,4];var mounted:bool=v.mount("bike",5);v.testing=true
	var flowers:Node3D=v.moving.get_node_or_null("CarriedBouquet");var colors:Dictionary={}
	if flowers!=null:
		for piece in flowers.get_children():colors[piece.material_override.albedo_color.to_html()]=true
	q.check("five_colours_in_actual_bicycle_basket",mounted and colors.size()==5)
	var route:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="flower_path")[0];await q.move_to(m.world.layout.vector(route.points[0])+Vector3.UP*.15);var ride_ok:=true;v.heading=atan2(-(route.points[1][0]-route.points[0][0]),-(route.points[1][2]-route.points[0][2]))
	for i in range(3,route.points.size(),3):
		if not await ride_to(Vector2(route.points[i][0],route.points[i][2]),12):ride_ok=false;break
	q.check("bicycle_through_winding_flower_path",ride_ok,str(m.player.position));v.speed=0;v.dismount(true);v.testing=false
	# User-selected map destinations work without discovery, including new locations.
	var destination:Dictionary=m.world.layout.config.extra_places.filter(func(a):return a.id=="H01")[0];await m.teleport_zone(destination)
	q.check("map_new_house_immediate_safe_destination",absf(m.player.position.x-destination.x)<2 and absf(m.player.position.z-(destination.z+8))<3)
	m.transitioning=false;m.player.enabled=false
	var boats=m.bay.boats;m.state.activities.boat_choice="yacht";await q.move_to(m.world.layout.vector(m.world.layout.config.boat_docks[5].land));var boarded:bool=await boats.board(5);boats.testing=true;m.player.program_driven=true;m.player.enabled=false
	var sailed:bool=boarded and (await q.sail_to(Vector3(120,sea+.2,m.world.layout.shore_z(120)+14),35));boats.speed=0;var at:Vector3=m.player.position;var landed:bool=await boats.dock() if sailed else false;boats.testing=false;m.player.enabled=false
	var fleet:Array=m.state.activities.get("moored_boats",[])
	q.check("free_coastal_sailing_and_mooring_off_dock",sailed and landed and not fleet.is_empty() and absf(at.x-90)>20,{"stop":str(at),"shore":str(m.player.position)})
	var again:bool=await boats.board_moored(fleet.size()-1) if not fleet.is_empty() else false
	q.check("reboard_boat_at_exact_saved_water_position",again and m.player.position.distance_to(at)<.15)
	if again:boats.speed=0;await boats.dock()
	m.player.enabled=false;m.player.program_driven=true
	var gull:Dictionary=m.bay.animals.animals.filter(func(a):return a.kind=="gull")[1];await q.move_to(gull.home+Vector3(10,.3,0));m.bay.animals.ring(gull.home);await m.get_tree().create_timer(1).timeout
	q.check("gull_actual_flight_after_bell",gull.node.position.y>gull.home.y+1)
	await q.move_to(gull.home+Vector3(30,.3,0));await m.get_tree().create_timer(8).timeout
	q.check("gull_returns_to_roost",gull.node.position.distance_to(gull.home)<.8,str(gull.node.position))
	q.check("final_saved_farm_postcards_boats_roundtrip",m.save_game(false) and m.store.read().get("activities",{}).get("farm_plots",{}).has("0") and m.store.read().get("cards",[]).size()>=2)
	q.sampling=false
	await m.qa_capture("final102_street_day",Vector3(-152,16,270),Vector3(-103,7,206))
	await m.qa_capture("final102_cafe_day",Vector3(-115,6.4,255),Vector3(-113,5.4,246))
	await m.qa_capture("final102_village_farm",Vector3(-382,42,324),Vector3(-277,5,246))
	await m.qa_capture("final102_pool",p+Vector3(-18,12,22),p)
	await m.qa_capture("final102_plaza_reflection",Vector3(0,7,68),Vector3(0,6,50))
	await m.qa_capture("final102_waterfall",Vector3(279,61,-300),Vector3(313,39,-323))
	q.finish()

func ride_to(target:Vector2,seconds:float)->bool:
	var v=m.bay.vehicles;var deadline:int=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await m.get_tree().physics_frame;var d:Vector2=target-Vector2(m.player.position.x,m.player.position.z)
		if d.length()<1.8:v.test_input=Vector2.ZERO;return true
		var wanted:float=atan2(-d.x,-d.y);var error:float=angle_difference(v.heading,wanted);v.test_input=Vector2(clampf(-error*3,-1,1),1);v.braking=absf(error)>1.15 and absf(v.speed)>3
		v.drive(1.0/60);if not m.world.region_ready(m.player.position):await m.world.prepare_region(m.player.position,75)
	return false
