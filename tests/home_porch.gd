extends SceneTree
var main
func _initialize():run.call_deferred()
func walk(target:Vector2)->bool:
	var p=main.player;p.automated_motion=true
	for tick in 1400:
		await physics_frame
		var delta:=target-Vector2(p.position.x,p.position.z)
		if delta.length()<0.55:p.automated_motion=false;p.automated_horizontal=Vector2.ZERO;return true
		p.automated_horizontal=delta.normalized()*4.0
	p.automated_motion=false;p.automated_horizontal=Vector2.ZERO;return false
func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main);main.qa_mode="home_porch"
	await main.start_game(false);main.player.enabled=false;main.player.position=main.world.surface(-237,-149,0.5);await main.world.prepare_region(main.player.position)
	var results:Array=[]
	for point in [Vector2(-237,-160.75),Vector2(-240.7,-160.75)]:
		var passed:bool=await walk(point);results.append({"target":str(point),"passed":passed,"position":str(main.player.position)})
		if not passed:break
	if results.all(func(row):return row.passed):
		var seat:Dictionary={}
		for action in main.world.interactions:
			if action.id=="B12_porch_seat":seat=action;break
		var before:Vector3=main.player.position
		main.activate(seat);results.append({"test":"real_porch_seat_interaction","passed":main.player.seated})
		await main.qa_capture("art_v11_home_porch_seated",main.world.surface(-241.9,-157.6,2),main.world.surface(-240.7,-162.2,1.0))
		main.player.stand_up();results.append({"test":"stand_restores_actual_reachable_position","passed":main.player.position.distance_to(before)<0.001})
		for point in [Vector2(-237,-160.75),Vector2(-237,-149)]:
			var passed:bool=await walk(point);results.append({"target":str(point),"passed":passed,"position":str(main.player.position)})
	var failures:=0
	for row in results:
		print("HOME_PORCH ",JSON.stringify(row))
		if not row.passed:failures+=1
	var file:=FileAccess.open("res://reports/home_porch.json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failures,"scope":"walk from garden road through main porch to side veranda; sit via actual interaction and walk back"},"\t"));file.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
