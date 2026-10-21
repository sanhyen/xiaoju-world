extends "res://scripts/construction_qa.gd"

func check_batch_extension(w,counts:Dictionary):
	var fittings:Dictionary=counts.get("venue_finishings_084",{})
	check("finishing_modules_for_thirteen_retained_venues",fittings.size()==13)
	for item in w.spec.buildings:
		var detail:Dictionary=fittings.get(item.id,{})
		check(item.id+"_specific_fittings_baked",detail.get("modules",0)>0 and detail.get("colliders_added",-1)==0,{"details":detail.get("details",[]),"modules":detail.get("modules",0)})
		main.player.position=w.surface(item.x,item.z+item.d/2+1.8,0.5);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		check(item.id+"_retained_entrance_walk",await walk(Vector2(item.x,item.z+item.d/2-1.8)))
		check(item.id+"_entered_original_interior",w.inside_building(main.player.position)==item.id)
	var cuts:Dictionary=counts.get("roadcuts_084",{})
	check("actual_cut_faces_dressed_without_new_collision",cuts.get("exposed_retaining_faces",0)>0 and cuts.get("colliders_added",-1)==0 and not cuts.get("terrain_height_changes",true),cuts)

	for id in ["B05_rest","B07_rest","B08_rest","B09_rest","B13_rest"]:
		var action:Dictionary={}
		for candidate in w.interactions:
			if candidate.id==id:action=candidate;break
		check(id+"_actual_seat_action",not action.is_empty())
		if action.is_empty():continue
		main.player.position=action.pos+Vector3(0,0.3,0);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position)
		await main.get_tree().physics_frame;await main.get_tree().physics_frame
		var exit_position:Vector3=main.player.position
		main.activate(action)
		check(id+"_sits_at_existing_bench",main.player.seated and main.player.position.distance_to(action.data.seat)<0.01)
		main.player.enabled=true;main.player.program_driven=false
		var key:=InputEventKey.new();key.keycode=KEY_W;key.physical_keycode=KEY_W;key.pressed=true;Input.parse_input_event(key);Input.flush_buffered_events()
		for tick in 12:
			await main.get_tree().physics_frame
			if not main.player.seated:break
		key=InputEventKey.new();key.keycode=KEY_W;key.physical_keycode=KEY_W;key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
		await main.get_tree().process_frame
		check(id+"_ordinary_key_exit",not main.player.seated and main.player.position.distance_to(exit_position)<0.5)
		main.player.stand_up() # Cleanup follows the real assertion, never supplies the passing exit.
		main.player.enabled=false;main.player.program_driven=true;main.player.velocity=Vector3.ZERO
