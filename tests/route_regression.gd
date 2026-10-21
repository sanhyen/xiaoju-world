extends SceneTree
var main
var results:Array=[]
func _initialize():run.call_deferred()

func walk(target:Vector2,limit:int=420)->bool:
	var p=main.player
	await main.world.prepare_region(p.position)
	for i in limit:
		await physics_frame
		var delta:=target-Vector2(p.position.x,p.position.z)
		if delta.length()<0.65:return true
		var v:=delta.normalized()*8.8
		p.velocity=Vector3(v.x,maxf(p.velocity.y-19.0/60,-20),v.y)
		if p.is_on_floor():p.velocity.y=-0.2
		p.move_character()
	return false

func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	await physics_frame;await physics_frame
	main.player.enabled=false
	main.player.position=main.world.surface(-65,297,0.5);main.player.velocity=Vector3.ZERO
	var entered:bool=await walk(Vector2(-65,289))
	results.append({"test":"cafe_clear_central_entrance","passed":entered and main.world.inside_building(main.player.position)=="B02"})
	var exited:bool=await walk(Vector2(-65,297))
	results.append({"test":"cafe_clear_central_exit","passed":exited and main.world.inside_building(main.player.position)==""})
	main.player.position=main.world.surface(0,-360,0.5)
	var ok:bool=await walk(Vector2(0,-378))
	results.append({"test":"summit_ramp_without_jump","passed":ok,"position":str(main.player.position)})
	main.player.position=main.world.surface(220,-170,0.5);main.player.velocity=Vector3.ZERO
	for target in [Vector2(251,-170),Vector2(251,-128),Vector2(220,-112)]:
		ok=await walk(target,600)
		results.append({"test":"PB_east_bypass_"+str(target),"passed":ok,"position":str(main.player.position)})
	main.player.position=main.world.surface(-65,287,0.5)+Vector3(6,0,-5.3);main.player.velocity=Vector3.ZERO
	ok=await walk(Vector2(-59,293.4))
	results.append({"test":"cafe_second_floor","passed":ok and main.player.position.y>3.2,"position":str(main.player.position)})
	ok=await walk(Vector2(-65,293.4))
	ok=await walk(Vector2(-65,297.2)) and ok
	results.append({"test":"cafe_terrace_walkable","passed":ok and main.player.position.y>3.2,"position":str(main.player.position)})
	main.store.directory="res://reports/isolated_cold_save"
	main.state.bouquet=2;main.state.home_photo=2;main.state.pb_page=4
	main.save_game(false);var old:Dictionary=main.store.read()
	main.state.bouquet=0;main.state.home_photo=0;main.state.pb_page=0
	await main.start_game(true);main.player.enabled=false
	results.append({"test":"restore_cafe_and_house_fields","passed":main.state.bouquet==2 and main.state.home_photo==2 and main.state.pb_page==4 and main.player.position.y>3.2})
	main.show_personal_library();results.append({"test":"personal_library_ui","passed":main.modal.visible})
	var entries=JSON.parse_string(FileAccess.get_file_as_string(main.personal_directory()+"/library.json"))
	for entry in entries:
		main.open_personal(entry,main.personal_directory())
		await create_timer(0.4).timeout
		results.append({"test":"personal_"+str(entry.kind),"passed":main.audio_player.playing if entry.kind=="audio" else main.modal.visible})
		main.close_modal();main.player.enabled=false
	var fails:=0
	for r in results:
		print("REGRESSION ",JSON.stringify(r))
		if not r.passed:fails+=1
	var f:=FileAccess.open("res://reports/route_regression.json",FileAccess.WRITE);f.store_string(JSON.stringify({"results":results,"failures":fails},"\t"));f.close()
	main.stop_media();main.queue_free();await process_frame;await process_frame
	quit(1 if fails else 0)
