extends "res://scripts/nature_qa.gd"
## B11 fixed views, physical aisles, collection gating and saved-card readback.
func run(target):
	main=target;main.store.directory="user://qa_isolated/souvenir_review"
	var reading:bool=main.qa_mode.ends_with("read")
	await main.start_game(reading);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=70
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	if reading:
		check("independent_card_and_stamp_restored",main.state.cards==["Z03"] and main.state.home_card=="Z03" and "Z03" in main.state.stamps)
		main.player.position=w.surface(-237,-168.5,0.4);await w.prepare_region(main.player.position);main.sync_home_memories();await main.qa_frame()
		check("restored_card_has_home_geometry",is_instance_valid(w.home_extras) and w.home_card_name=="花音商店街")
	else:
		fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/souvenir_cameras.json"))
		for view in fixed_cameras:
			main.set_time(int(view.time));await capture(view.name,Vector3.ZERO,Vector3.ZERO);cameras[-1].time=int(view.time)
		main.set_time(0)
		var actions:Dictionary={}
		for action in w.interactions:actions[action.id]=action
		check("original_souvenir_actions_retained",actions.has("B11_enter") and actions.has("B11_collection"))
		main.player.position=w.surface(-55,162,0.4);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
		for point in [Vector2(-55,155),Vector2(-55,151),Vector2(-55,148.5)]:
			if not await walk(point):break
		if actions.has("B11_collection"):
			check("collection_point_reachable",main.player.position.distance_to(actions.B11_collection.pos)<1.5)
			main.activate(actions.B11_collection);await main.qa_frame()
			var card_buttons:Array=[]
			for node in main.modal.find_children("*","Button",true,false):
				if node.text.begins_with("领取旅行卡"):card_buttons.append(node)
			check("unearned_cards_locked",card_buttons.size()==8 and card_buttons.all(func(node):return node.disabled))
			check("cannot_claim_unearned_card",not main.claim_card("Z03") and main.state.cards.is_empty())
			# Controlled earned-state fixture; real regional approaches are covered by stamps_gpu.
			main.state.stamps.append("Z03");main.show_souvenirs();await main.qa_frame()
			var unlocked:Button=null
			for node in main.modal.find_children("*","Button",true,false):
				if node.text.begins_with("领取旅行卡") and not node.disabled:unlocked=node
			check("exact_earned_card_enabled",unlocked!=null and unlocked.text.ends_with("花音商店街"))
			if unlocked!=null:unlocked.pressed.emit();unlocked.pressed.emit()
			check("claim_idempotent_and_home_selected",main.state.cards==["Z03"] and main.state.home_card=="Z03")
			main.close_modal();main.player.enabled=false;main.hud.hide()
		for point in [Vector2(-55,145),Vector2(-58.5,145),Vector2(-55,145),Vector2(-51.5,145),Vector2(-55,145),Vector2(-55,151),Vector2(-55,157),Vector2(-55,162)]:
			if not await walk(point):break
		check("souvenir_state_saved",main.save_game(false))
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","scope":"fixed B11 cameras, physical walking, controlled earned-state fixture and actual collection callbacks; read mode uses separate process"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
