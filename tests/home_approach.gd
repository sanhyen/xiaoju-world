extends SceneTree
var main
func _initialize():run.call_deferred()
func walk(target:Vector2)->bool:
	for tick in 1500:
		await physics_frame
		var p=main.player;var delta:=target-Vector2(p.position.x,p.position.z)
		if delta.length()<0.85:return true
		var direction:=delta.normalized()*6.6
		p.velocity=Vector3(direction.x,maxf(p.velocity.y-19.0/60,-20),direction.y)
		if p.is_on_floor():p.velocity.y=-0.2
		p.move_character()
	return false
func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main);main.player.enabled=false
	main.player.position=main.world.surface(-220,-150,0.5);await main.world.prepare_region(main.player.position)
	var results:Array=[];var failed:=0
	for point in [Vector2(-237,-148.5),Vector2(-237,-168),Vector2(-237,-148.5),Vector2(-220,-150)]:
		var passed:bool=await walk(point);var row:={"target":str(point),"passed":passed,"position":str(main.player.position)}
		results.append(row);print("HOME_APPROACH ",JSON.stringify(row))
		if not passed:failed+=1;break
	if DisplayServer.get_name()!="headless":
		main.qa_mode="home_approach";main.menu.hide();main.hud.hide()
		await main.qa_capture("g4_home_approach_clear",main.world.surface(-232,-149,2.1),main.world.surface(-237,-161,1.0))
	var file:=FileAccess.open("res://reports/home_approach"+("_gpu" if DisplayServer.get_name()!="headless" else "")+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failed,"scope":"real diagonal approach and ramp access; no relocation onto the ramp centreline"},"\t"));file.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
