extends RefCounted
func run(m,q):
	q.sampling=true;m.set_time(0)
	var east:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="east_mountain")[0]
	await q.move_to(m.world.layout.vector(east.points[0])+Vector3.UP*.3)
	var ok:=true;var grades:Array=[]
	for i in range(1,east.points.size()):
		var a:Vector3=m.world.layout.vector(east.points[i-1]);var b:Vector3=m.world.layout.vector(east.points[i])
		grades.append(rad_to_deg(atan2(absf(b.y-a.y),Vector2(b.x-a.x,b.z-a.z).length())))
		if not await q.walk(Vector2(b.x,b.z),maxf(6,a.distance_to(b)/8+3)):ok=false;break
	q.check("east_mountain_continuous_to_summit",ok,str(m.player.position))
	q.check("east_mountain_all_grades_under_12_degrees",grades.max()<12,grades)
	var shared:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="waterfall_approach")[0]
	q.check("waterfall_access_uses_same_surface",shared.points.slice(0,3)==east.points.slice(1,4))
	if m.qa_mode=="bay_road102":q.sampling=false;q.finish();return
	var ids:Array=m.world.interactions.map(func(a):return a.id);var distinct:Dictionary={}
	for id in ids:distinct[id]=true
	var frozen:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_095_bay_v1.json"))
	q.check("all_original_ids_unique_and_preserved",distinct.size()==ids.size() and frozen.protected_interaction_ids.all(func(id):return id in ids),ids.size())
	var tea:Vector3=m.world.layout.vector([-20,73.5,-396]);await q.move_to(tea+Vector3(-3,.3,2.5));m.player.enabled=true
	var event:=InputEventKey.new();event.physical_keycode=KEY_X;event.pressed=true;m.bay.handle_input(event)
	q.check("tatami_X_seated",m.player.seated);m.player.stand_up();m.player.enabled=false
	var v:Dictionary=m.world.layout.venues.B02;await q.move_to(Vector3(v.x,v.floor_y+.3,v.z+6))
	q.check("cafe_lined_room_entrance_remains_clear",await q.walk(Vector2(v.x,v.z+2),4))
	await q.move_to(Vector3(276,-.5,426));await m.get_tree().create_timer(.6).timeout
	var visible:=0;var submerged:=true
	for fish in m.bay.boats.fish:
		if not fish.visible:continue
		visible+=1;submerged=submerged and fish.position.y>m.world.height_at(fish.position.x,fish.position.z) and fish.position.y<float(m.world.layout.config.sea_y)-.1
	q.check("visible_fish_above_seabed_below_water",visible>5 and submerged,visible)
	q.sampling=false
	await m.qa_capture("resume102_villa_glass",Vector3(276,1.5,428.5),Vector3(276,-3.6,426))
	await m.qa_capture("resume102_cafe_details",Vector3(-109,6.9,253.5),Vector3(-113,6.2,246))
	q.finish()
