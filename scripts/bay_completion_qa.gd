extends RefCounted
## One grouped acceptance of the changed geometry, dynamic loops and three additions.
var m
var q

func run(main,driver):
	m=main;q=driver;q.sampling=true
	var frozen:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_095_bay_v1.json"))
	var ids:Array=m.world.interactions.map(func(a):return a.id)
	q.check("completion_87_legacy_ids",frozen.protected_interaction_ids.all(func(id):return id in ids))
	q.check("completion_8_zones_13_venues",m.world.spec.zones.size()==8 and m.world.building_bounds.size()==13)
	var doors:Array=[]
	for v in m.world.spec.buildings:
		await q.move_to(Vector3(v.x,v.floor_y+.4,v.z+v.d*.5+1.5))
		if not await q.walk(Vector2(v.x,v.z+v.d*.5-1.5),5):doors.append(v.id)
	q.check("completion_all_13_main_doors",doors.is_empty(),doors)
	var failed_lofts:Array=[]
	for id in m.world.layout.config.annexes:
		var data:Dictionary=m.world.layout.config.annexes[id];var road:Dictionary={}
		for r in m.world.layout.config.roads:
			if r.id==id+"_annex_approach":road=r;break
		await q.move_to(m.world.layout.vector(road.points[0])+Vector3.UP*.35)
		var ok:=true
		for a in road.points.slice(1):
			if not await q.walk(Vector2(a[0],a[2]),7):ok=false;break
		if ok:
			for a in data.stairs.slice(1):
				if not await q.walk(Vector2(a[0],a[2]),7):ok=false;break
		if not ok or m.player.position.y<m.world.layout.vector(data.center).y+3.4:failed_lofts.append(id)
	q.check("completion_ten_real_upper_annexes",failed_lofts.is_empty(),failed_lofts)
	# Independently raycast every real navigable bridge at centre and the two hull edges.
	var clearances:Array=[];var low:Array=[]
	for road in m.world.layout.segments:
		if not road.bridge:continue
		for river in m.world.layout.river_segments:
			if river.id!="navigation":continue
			var hit=Geometry2D.segment_intersects_segment(Vector2(road.a.x,road.a.z),Vector2(road.c.x,road.c.z),Vector2(river.a.x,river.a.z),Vector2(river.c.x,river.c.z))
			if hit==null:continue
			var water:Vector3=m.world.layout.projection(hit,river)
			await m.world.prepare_region(water,75)
			var side:=Vector3(-(river.c-river.a).z,0,(river.c-river.a).x).normalized()
			for offset in [-.9,0.0,.9]:
				var origin:Vector3=water+side*offset+Vector3.UP*.06
				var ray:=PhysicsRayQueryParameters3D.create(origin,origin+Vector3.UP*12,1,[m.player.get_rid()])
				var result:Dictionary=m.world.get_world_3d().direct_space_state.intersect_ray(ray)
				if result.is_empty():continue
				var height:float=result.position.y-water.y;clearances.append({"bridge":road.id,"m":height,"offset":offset})
				if height<3.2:low.append(clearances.back())
	q.check("completion_bridge_physical_clearance_3_2m",clearances.size()>0 and low.is_empty(),{"samples":clearances,"too_low":low})
	# Crouch, a finite actual follow, local return and a route-specific squirrel movement.
	var cat:Dictionary=m.bay.animals.animals.filter(func(a):return a.kind=="cat")[3]
	await q.move_to(cat.home+Vector3(-1,.2,1));m.player.enabled=true;m.player.program_driven=true
	await m.get_tree().create_timer(.3).timeout
	var petted:bool=m.bay.animals.pet();await m.get_tree().create_timer(.2).timeout
	q.check("completion_X_cat_visible_crouch",petted and m.player.figure.position.y<-.2 and m.player.pet_until_msec>Time.get_ticks_msec())
	await m.get_tree().create_timer(2.7).timeout
	var before:Vector3=cat.node.position
	await q.walk(Vector2(cat.home.x+6,cat.home.z),4);await m.get_tree().create_timer(2.5).timeout
	q.check("completion_cat_actual_follow",cat.node.position.distance_to(before)>1.5,{"from":str(before),"to":str(cat.node.position)})
	cat.follow_until=0;await m.get_tree().create_timer(4).timeout
	q.check("completion_cat_returns_home",cat.node.position.distance_to(cat.home)<.65,str(cat.node.position))
	var squirrel:Dictionary=m.bay.animals.animals.filter(func(a):return a.kind=="squirrel")[0]
	await q.move_to(squirrel.home+Vector3(-2,.2,1));await m.get_tree().create_timer(2).timeout
	q.check("completion_squirrel_guides_authored_path",squirrel.guide_started and squirrel.guide_distance>1.5,{"distance":squirrel.guide_distance,"path":squirrel.guide})
	q.check("completion_two_white_rabbits",m.bay.animals.animals.filter(func(a):return a.kind=="rabbit").size()==2)
	q.check("completion_instanced_gulls_butterflies",m.bay.animals.batches.size()>=7)
	# The same real archive page appears on the desk and loft; the hidden postcard route is physical.
	m.state.pb_page=4;m.bay.details.refresh_book()
	q.check("completion_physical_book_spread",m.bay.details.books.size()==2 and m.bay.details.books.all(func(b):return b.pages[0].material_override.albedo_texture!=null and b.pages[1].material_override.albedo_texture!=null))
	m.bay.details.unlock(0)
	var hidden:Dictionary=m.world.layout.config.hidden_views[0]
	await q.move_to(m.world.layout.vector(hidden.route[0])+Vector3.UP*.3);var hidden_ok:=true
	for a in hidden.route.slice(1):
		if not await q.walk(Vector2(a[0],a[2]),7):hidden_ok=false;break
	m.bay.details.hidden_view(0);m.photo_mode=false;m.hud.show();m.player.camera.current=true;m.player.enabled=false
	q.check("completion_journal_hidden_platform_postcard",hidden_ok and hidden.card in m.state.cards)
	m.set_time(2);var heading:float=m.bay.details.beacon.rotation.y;await m.get_tree().create_timer(.4).timeout
	q.check("completion_rotating_lighthouse",m.bay.details.beacon.rotation.y>heading)
	m.bay.details.set_season(3)
	q.check("completion_fourth_season",m.bay.details.seasonal_paintings.all(func(p):return p.material_override.get_shader_parameter("season")==3))
	m.state.activities.bouquet_colors=[0,1,2,3,4];m.state.handheld="bouquet";m.bay.refresh_hand()
	q.check("completion_five_colour_visible_bouquet",m.bay.bouquet_palette().size()==5 and m.bay.hand.get_child_count()>=16)
	var studio:Dictionary=m.world.layout.venues.B09;await q.move_to(Vector3(studio.x+4,studio.floor_y+.2,studio.z+3))
	m.bay.details.monitoring_pose();q.check("completion_headphones_pose",m.state.handheld=="headphones" and m.player.seated)
	m.bay.details.monitoring_pose();q.check("completion_guitar_pose",m.state.handheld=="guitar" and m.player.seated);m.player.stand_up()
	m.bay.light_show=true;await q.move_to(Vector3(-287,9,13));await m.get_tree().create_timer(.4).timeout
	q.check("completion_stage_star_mist_and_moving_rack",m.bay.details.stars.visible and m.bay.details.mist.visible and m.bay.details.stage_rack.position.y<21.6)
	m.bay.light_show=false
	await q.move_to(m.world.layout.vector(m.world.layout.config.boat_docks[1].land));m.state.activities.boat_choice="yacht"
	var boarded:bool=await m.bay.boats.board(1);m.bay.boats.testing=true;m.player.program_driven=true;m.player.enabled=false
	var sailed:bool=boarded
	var start:int=Time.get_ticks_msec()
	for point in [Vector3(283,-2.4,385),Vector3(243,-2.4,401),m.world.layout.vector(m.world.layout.config.boat_docks[2].water)]:
		if not await q.sail_to(point,40):sailed=false;break
	var seconds:float=(Time.get_ticks_msec()-start)/1000.0;m.bay.boats.speed=0
	var landed:bool=await m.bay.boats.dock() if sailed else false
	if not landed:m.bay.boats.leave_for_travel()
	m.bay.boats.testing=false;m.player.program_driven=true;m.player.enabled=false
	q.check("completion_sea_to_island_and_dock",sailed and landed,{"seconds":seconds})
	await q.move_to(m.world.layout.vector([256,2,427]));var hotel_ok:=true
	for a in m.world.layout.config.island.hotel_walk.arrival:
		if not await q.walk(Vector2(a[0],a[2]),6):hotel_ok=false;break
	for i in 11:
		var p:Vector3=m.world.layout.hotel_walk_point(lerpf(-1.15,1.15,float(i)/10))
		if not await q.walk(Vector2(p.x,p.z),6):hotel_ok=false;break
	q.check("completion_hotel_lobby_and_entire_crescent",hotel_ok)
	for i in 4:
		var x:float=276+(4 if i in [1,2] else 0);var z:float=426+i*15
		await q.move_to(m.world.layout.hotel_branch_start(z)+Vector3.UP*.3)
		var entered:bool=await q.walk(Vector2(x,z),6)
		q.check("completion_villa_"+str(i)+"_glass_and_door",entered and absf(m.player.position.y+.8)<.35)
		if i==0:
			var deck:bool=await q.walk(Vector2(x,z+6),4);m.player.enabled=true
			var net:Dictionary=m.bay.nearest_kinds(["bay_netbed"],4);m.bay.boats.rest(net)
			q.check("completion_X_netbed_lie",deck and m.player.seated and m.player.rest_pose=="lie");m.player.stand_up();m.player.enabled=false
			var stairs:bool=await q.walk(Vector2(x,z+9.5),4,.15)
			stairs=(await q.walk(Vector2(x+3.5,z+9.5),4,.15)) and stairs
			stairs=(await q.walk(Vector2(x+3.5,z+8.5),4,.15)) and stairs
			stairs=(await q.walk(Vector2(x+5.87,z+8.5),4,.04)) and stairs
			m.player.velocity=Vector3.ZERO;m.player.automated_motion=true;m.player.automated_horizontal=Vector2.ZERO;await m.get_tree().create_timer(.8).timeout;m.player.automated_motion=false
			q.check("completion_five_steps_stable_water_landing",stairs and m.player.is_on_floor() and m.player.position.y< -2 and m.world.layout.shallow_or_dry(m.player.position))
	q.check("completion_reef_70_30_same_rendered_region",absf(m.world.layout.config.island.reef_design_ellipse.natural_ratio-.7)<.00001)
	# One final media ownership check after spatial room loops replaced the old 2D ambience.
	m.state.playlist=["sunset"];m.bay.next_song();await m.show_video("B06","sunset");await m.get_tree().create_timer(.7).timeout;m.bay.update_audio()
	var movie=m.video;var position:float=m.video.stream_position
	q.check("completion_original_movie_audio_ownership",m.video.is_playing() and m.bay.music.stream_paused)
	m.switch_cinema_screen();await m.get_tree().create_timer(.35).timeout
	q.check("completion_same_decoder_on_outdoor_screen",m.video==movie and m.video.stream_position>position)
	m.close_modal();m.bay.update_audio();q.check("completion_media_close_release",m.video.stream==null and m.audio_player.stream==null)
	q.check("completion_new_state_save",m.save_game(false))
	q.sampling=false
	await m.qa_capture("completion101_cafe",Vector3(-116,7.2,256),Vector3(-113,5.6,247))
	await m.qa_capture("completion101_pb_attic",m.world.layout.vector(m.world.layout.config.annexes.B07.center)+Vector3(1,5.6,3),m.world.layout.vector(m.world.layout.config.annexes.B07.center)+Vector3(1.5,4.9,1))
	await m.qa_capture("completion101_island",Vector3(308,24,493),Vector3(245,0,450))
	await m.qa_capture("completion101_summit",Vector3(-30,81,-397),Vector3(5,15,20))
	await m.qa_capture("completion101_street",Vector3(-141,14,268),Vector3(-91,8,207))
	await m.qa_capture("completion101_gallery",Vector3(202,27,-192),Vector3(188,22,-225))
	await m.qa_capture("completion101_plaza",Vector3(0,9,115),Vector3(0,14,40))
	await m.qa_capture("completion101_flower",Vector3(-248,22,-149),Vector3(-225,13,-182))
	await m.qa_capture("completion101_forest",Vector3(-273,38,-260),Vector3(-230,46,-320))
	q.finish()
