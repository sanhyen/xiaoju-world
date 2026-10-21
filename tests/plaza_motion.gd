extends SceneTree
var main
var results:Array=[]
func _initialize():run.call_deferred()
func segment(target:Vector2,limit:int=450)->bool:
	var p=main.player
	for tick in limit:
		await physics_frame
		var delta:=target-Vector2(p.position.x,p.position.z)
		if delta.length()<0.85:
			p.automated_motion=false;p.automated_horizontal=Vector2.ZERO;return true
		var direction:=delta.normalized()*6.6
		p.automated_motion=true;p.automated_horizontal=direction
	main.player.automated_motion=false;main.player.automated_horizontal=Vector2.ZERO
	return false
func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	main.qa_mode="plaza_motion";main.store.directory="user://qa_isolated/plaza_motion"
	await main.start_game(false);main.player.enabled=false
	main.player.position=main.world.surface(0,80,0.5);await main.world.prepare_region(main.player.position)
	for iteration in 8:
		var outgoing:bool=await segment(Vector2(9,95.5))
		await main.save_photo()
		var back:bool=await segment(Vector2(0,80))
		var collisions:Array=[]
		if not back:
			for index in main.player.get_slide_collision_count():
				var hit=main.player.get_slide_collision(index)
				collisions.append({"normal":str(hit.get_normal()),"position":str(hit.get_position()),"body":str(hit.get_collider().global_position)})
		var row:={"iteration":iteration,"passed":outgoing and back,"position":str(main.player.position),"on_floor":main.player.is_on_floor(),"velocity":str(main.player.velocity),"collisions":collisions}
		results.append(row);print("PLAZA_MOTION ",JSON.stringify(row))
		if not back:break
	var failed:=0
	for row in results:if not row.passed:failed+=1
	var file:=FileAccess.open("res://reports/plaza_motion.json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failed},"\t"));file.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
