extends SceneTree
var main
var results:Array=[]
func _initialize():run.call_deferred()

func walk(target:Vector2)->bool:
	var p=main.player
	for tick in 1200:
		await physics_frame
		var delta:=target-Vector2(p.position.x,p.position.z)
		if delta.length()<0.6:return true
		var direction:=delta.normalized()*6.6
		p.velocity=Vector3(direction.x,maxf(p.velocity.y-19.0/60,-20),direction.y)
		if p.is_on_floor():p.velocity.y=-0.2
		p.move_character()
	return false

func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	main.player.enabled=false
	for x in [-99,15,51]:
		var z:float=303+10*sin(x*0.015)
		main.player.position=main.world.surface(x,z,0.5);await main.world.prepare_region(main.player.position)
		var outgoing:bool=await walk(Vector2(x,z+10))
		var incoming:bool=await walk(Vector2(x,z))
		results.append({"test":"beach_ramp_"+str(x),"passed":outgoing and incoming,"position":str(main.player.position)})
	main.player.position=main.world.surface(0,303,0.5);await main.world.prepare_region(main.player.position)
	var z:float=303+10*sin(15*0.015);var passed:=true
	for point in [Vector2(15,z),Vector2(15,z+10),Vector2(15,325.5),Vector2(9,325.5),Vector2(15,325.5),Vector2(15,z+10),Vector2(15,z),Vector2(0,303)]:passed=await walk(point) and passed
	results.append({"test":"Z02_stamp_actual_roundtrip","passed":passed,"position":str(main.player.position)})
	if DisplayServer.get_name()!="headless":
		main.qa_mode="beach";main.menu.hide();main.hud.hide()
		await main.qa_capture("g4_beach_east_ramp",main.world.surface(20,317,2.1),main.world.surface(15,308,0.4))
	var failed:=0
	for row in results:
		print("BEACH_ACCESS ",JSON.stringify(row))
		if not row.passed:failed+=1
	var file:=FileAccess.open("res://reports/beach_access"+("_gpu" if DisplayServer.get_name()!="headless" else "")+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failed,"scope":"actual collision walk through three beach ramp openings and stamp approach/return","renderer":RenderingServer.get_current_rendering_method()},"\t"));file.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
