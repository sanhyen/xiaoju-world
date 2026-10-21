extends SceneTree
var main
func _initialize():run.call_deferred()
func walk(target:Vector2)->bool:
	for tick in 1500:
		await physics_frame
		var p=main.player;var difference:=target-Vector2(p.position.x,p.position.z)
		if difference.length()<0.7:return true
		var direction:=difference.normalized()*6.6
		p.velocity=Vector3(direction.x,maxf(p.velocity.y-19.0/60,-20),direction.y)
		if p.is_on_floor():p.velocity.y=-0.2
		p.move_character()
	return false
func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main);main.player.enabled=false
	main.player.position=main.world.surface(0,303,0.5);await main.world.prepare_region(main.player.position)
	var results:Array=[];var failed:=0
	for point in [Vector2(-65,305),Vector2(-65,298),Vector2(-65,290),Vector2(-65,298),Vector2(-65,305),Vector2(0,303)]:
		var passed:bool=await walk(point);var row:={"target":str(point),"passed":passed,"position":str(main.player.position)}
		results.append(row);print("CAFE_BEACH ",JSON.stringify(row))
		if not passed:failed+=1;break
	var file:=FileAccess.open("res://reports/cafe_beach_connection.json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failed},"\t"));file.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
