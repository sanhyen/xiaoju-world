extends RefCounted
var m
var q
func run(main,driver):
	m=main;q=driver;q.sampling=true;m.set_time(0)
	for id in ["music_garden","east_mountain"]:
		var r:Dictionary=m.world.layout.config.roads.filter(func(a):return a.id==id)[0];var pts:Array=r.points.slice(7 if id=="music_garden" else 0,r.points.size() if id=="music_garden" else 6);var ok:=true
		await q.move_to(m.world.layout.vector(pts[0])+Vector3.UP*.3)
		for a in pts.slice(1):
			if not await q.walk(Vector2(a[0],a[2]),maxf(6,Vector2(m.player.position.x-a[0],m.player.position.z-a[2]).length()/8+3)):ok=false;break
		q.check("repaired_road_"+id,ok,str(m.player.position))
	var sea:float=m.world.layout.config.sea_y;var x:float=120;var z:float=m.world.layout.shore_z(x)+8
	await q.move_to(Vector3(x,m.world.height_at(x,z)+.3,z));var wade:bool=await q.walk(Vector2(123,m.world.layout.shore_z(123)+10),6);await m.get_tree().create_timer(.6).timeout
	q.check("open_mainland_shallow_walk_without_return",wade and m.player.position.y<sea and absf(m.player.position.x-123)<1,str(m.player.position))
	var pool:Dictionary=m.world.layout.config.play_pool;var p:Vector3=m.world.layout.vector(pool.center);await q.move_to(p+Vector3(0,.3,8));var ok:=true
	for zz in [6.5,5.7,4.9,4.1,3.3,1.0]:
		if not await q.walk(Vector2(p.x,p.z+zz),5,.12):ok=false;break
	q.check("pool_entry_and_five_steps_to_bottom",ok and absf(m.player.position.y-(sea+pool.bed_h_sea))<.25,str(m.player.position))
	if ok:
		for zz in [3.3,4.1,4.9,5.7,6.5,8.0]:
			if not await q.walk(Vector2(p.x,p.z+zz),5,.12):ok=false;break
	q.check("pool_climb_out_on_same_five_steps",ok and absf(m.player.position.y-p.y)<.3,str(m.player.position))
	var bad:Array=[]
	for h in m.world.layout.config.living_houses.slice(8):
		var at:Vector3=m.world.layout.vector(h.center);await q.move_to(at+Vector3(0,.3,h.size[1]*.5+1.7))
		if not await q.walk(Vector2(at.x,at.z+h.size[1]*.5-1.5),5):bad.append(h.id)
	q.check("six_additional_street_and_plaza_house_doors",bad.is_empty(),bad)
	var low:Array=[];var samples:Array=[]
	for road in m.world.layout.segments:
		if not road.bridge:continue
		for river in m.world.layout.river_segments:
			if river.id!="navigation":continue
			var hit=Geometry2D.segment_intersects_segment(Vector2(road.a.x,road.a.z),Vector2(road.c.x,road.c.z),Vector2(river.a.x,river.a.z),Vector2(river.c.x,river.c.z))
			if hit==null:continue
			var water:Vector3=m.world.layout.projection(hit,river);await m.world.prepare_region(water,75);var side:=Vector3(-(river.c-river.a).z,0,(river.c-river.a).x).normalized()
			for offset in [-.9,0.0,.9]:
				var origin:Vector3=water+side*offset+Vector3.UP*.06;var ray:=PhysicsRayQueryParameters3D.create(origin,origin+Vector3.UP*12,1,[m.player.get_rid()]);var result:Dictionary=m.world.get_world_3d().direct_space_state.intersect_ray(ray)
				if result.is_empty():continue
				var clearance:float=result.position.y-water.y;samples.append({"bridge":road.id,"m":clearance,"offset":offset})
				if clearance<3.2:low.append(samples.back())
	q.check("all_navigation_bridges_actual_clearance",not samples.is_empty() and low.is_empty(),samples)
	q.sampling=false
	await m.qa_capture("final102_street_finished",Vector3(-145,14,245),Vector3(-105,7,210))
	await m.qa_capture("final102_cafe_finished",Vector3(-109,7.3,254),Vector3(-113,5.9,246))
	var y:float=m.world.height_at(0,80);await m.qa_capture("final102_plaza_finished",Vector3(0,y+2.0,58.5),Vector3(0,y+.2,53.8))
	m.set_time(2);await m.qa_capture("final102_village_night",Vector3(-330,18,242),Vector3(-280,5,227))
	q.finish()
