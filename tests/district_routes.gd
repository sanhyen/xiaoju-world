extends SceneTree
var main
var results:Array=[]

func _initialize():run.call_deferred()

func walk(target:Vector2,seconds:float=12)->bool:
	var p=main.player
	await main.world.prepare_region(p.position)
	for i in int(seconds*60):
		await physics_frame
		var delta:=target-Vector2(p.position.x,p.position.z)
		if delta.length()<0.55:return true
		var v:=delta.normalized()*8.8
		p.velocity=Vector3(v.x,maxf(p.velocity.y-19.0/60,-20),v.y)
		if p.is_on_floor():p.velocity.y=-0.2
		p.move_character()
	return false

func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	await physics_frame;await physics_frame
	main.player.enabled=false
	var paths:Array=[
		["street_full_clear",Vector2(-75,236),[Vector2(-75,144)]],
		["record_forecourt",Vector2(-75,201),[Vector2(-97,201),Vector2(-97,190),Vector2(-97,201),Vector2(-75,201)]],
		["florist_forecourt",Vector2(-75,223),[Vector2(-53,223),Vector2(-53,211),Vector2(-53,223)]],
		["greenhouse_aisle",Vector2(-41.5,222),[Vector2(-41.5,210),Vector2(-41.5,216)]],
		["souvenir_forecourt",Vector2(-75,160),[Vector2(-55,160),Vector2(-55,149),Vector2(-55,160)]],
		["cafe_new_rear_entry",Vector2(-65,276),[Vector2(-65,287),Vector2(-65,276)]],
		["cafe_sea_exit",Vector2(-65,290),[Vector2(-65,298),Vector2(-60,298)]],
		["sea_deck_ramp",Vector2(-28,305),[Vector2(-28,322),Vector2(-28,305)]],
		["pier_continuous",Vector2(0,303),[Vector2(0,365),Vector2(0,303)]],
		["plaza_portrait_axis",Vector2(0,122),[Vector2(0,46),Vector2(0,122)]],
		["plaza_east_crossing",Vector2(-49,80),[Vector2(49,80)]],
		["home_new_patio",Vector2(-220,-150),[Vector2(-237,-148.5),Vector2(-237,-168),Vector2(-237,-148.5),Vector2(-220,-150)]],
		["mountain_bridge",Vector2(291.5,-285),[Vector2(349,-285)]],
		["cultural_bridge",Vector2(263,-70),[Vector2(321,-70)]],
		["theater_court",Vector2(-250,30),[Vector2(-291,30),Vector2(-291,17)]],
		["waterfall_viewing_spur",Vector2(283,-302),[Vector2(317,-302),Vector2(283,-302)]]
	]
	for path in paths:
		main.player.position=main.world.surface(path[1].x,path[1].y,0.4);main.player.velocity=Vector3.ZERO
		await physics_frame;await physics_frame
		var passed:=true;var points:Array=[]
		for dest in path[2]:
			var ok:bool=await walk(dest,18)
			points.append({"target":[dest.x,dest.y],"passed":ok,"position":str(main.player.position)})
			passed=passed and ok
			if not ok:break
		var entry:={"test":path[0],"passed":passed,"points":points};results.append(entry);print("DISTRICT_ROUTE ",JSON.stringify(entry))
	var failed:=0
	for row in results:
		if not row.passed:failed+=1
	var f:=FileAccess.open("res://reports/district_routes.json",FileAccess.WRITE);f.store_string(JSON.stringify({"results":results,"failures":failed,"scope":"automated character collision walks, does not replace camera and manual input acceptance"},"\t"));f.close()
	main.stop_media();main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
