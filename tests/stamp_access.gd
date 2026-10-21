extends SceneTree
var main
var checks:Array=[]
func _initialize():run.call_deferred()
func walk(target:Vector2)->bool:
	var p=main.player;p.automated_motion=true
	var end:=Time.get_ticks_msec()+18000
	while Time.get_ticks_msec()<end:
		await physics_frame
		var direction:Vector2=target-Vector2(p.position.x,p.position.z)
		if direction.length()<0.7:p.automated_motion=false;p.automated_horizontal=Vector2.ZERO;return true
		p.automated_horizontal=direction.normalized()*6.6
	p.automated_motion=false;p.automated_horizontal=Vector2.ZERO;return false
func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main);await physics_frame
	main.store.directory="user://qa_isolated/stamp_access";await main.start_game(false)
	main.player.enabled=false;main.player.program_driven=true
	for zone in main.world.spec.zones:
		var entrance:Vector2=main.world.stamp_path_start(zone)
		var start:=entrance+Vector2(0,-7) if zone.id=="Z08" else entrance
		main.player.position=main.world.surface(start.x,start.y,0.5);main.player.velocity=Vector3.ZERO
		await main.world.prepare_region(main.player.position)
		var action:Dictionary={}
		for item in main.world.interactions:
			if item.id==zone.id:action=item;break
		var incoming:bool=await walk(entrance)
		for point in main.world.stamp_access_points(zone).slice(1):incoming=await walk(point) and incoming
		if incoming:main.activate(action)
		checks.append({"test":zone.id+"_access_and_claim","passed":incoming and zone.id in main.state.stamps,"position":str(main.player.position)})
		var outgoing:=true
		var reverse_path:Array=main.world.stamp_access_points(zone).slice(0,-1);reverse_path.reverse()
		for point in reverse_path:outgoing=await walk(point) and outgoing
		checks.append({"test":zone.id+"_return_to_road","passed":outgoing,"position":str(main.player.position)})
		print("STAMP_ROUTE ",JSON.stringify(checks[-2])," ",JSON.stringify(checks[-1]))
	# Reproduce the long-tour direction, then vary the approach instead of relying on one spawn.
	var mountain:Dictionary=main.world.spec.zones.filter(func(zone):return zone.id=="Z08")[0]
	var approach:Vector2=main.world.stamp_path_start(mountain)
	for offset in [Vector2(-0.72,-0.42),Vector2(-0.7,0.55),Vector2(0.7,-0.55),Vector2(0.6,0.6)]:
		var start:Vector2=approach+offset
		main.player.position=main.world.surface(start.x,start.y,0.5);main.player.velocity=Vector3.ZERO
		await main.world.prepare_region(main.player.position)
		var success:=true
		for point in main.world.stamp_access_points(mountain).slice(1):success=await walk(point) and success
		var reverse_path:Array=main.world.stamp_access_points(mountain).slice(0,-1);reverse_path.reverse()
		for point in reverse_path:success=await walk(point) and success
		checks.append({"test":"Z08_offset_roundtrip_"+str(offset),"passed":success,"position":str(main.player.position)})
		print("STAMP_OFFSET ",JSON.stringify(checks[-1]))
	var failed:=0
	for row in checks:failed+=0 if row.passed else 1
	var file:=FileAccess.open("res://reports/stamp_access.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failed,"scope":"eight original stamps; physical access, actual claim and return; includes mountain approach"},"\t"));file.close()
	main.stop_media();main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
