extends "res://scripts/interiors_qa.gd"
## Fixed camera review of the remaining four cultural venues.
func run(target):
	main=target;main.store.directory="user://qa_isolated/arts_review"
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=70;main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/arts_cameras.json"))
	for item in definitions:
		var origin:=Vector3.ZERO
		for building in main.world.spec.buildings:
			if building.id==item.building:origin=main.world.surface(building.x,building.z,0.08);break
		var view:Dictionary=item.duplicate(true)
		for key in ["eye","target"]:
			var p:Vector3=origin+Vector3(item[key][0],item[key][1],item[key][2]);view[key]=[p.x,p.y,p.z]
		fixed_cameras.append(view)
	for view in fixed_cameras:
		main.set_time(int(view.time));await capture(view.name,Vector3.ZERO,Vector3.ZERO);cameras[-1].time=int(view.time)
	main.set_time(0)
	var w=main.world
	main.player.position=w.surface(-53,220,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	for point in [Vector2(-53,217),Vector2(-53,214),Vector2(-53,210.8),Vector2(-53,215),Vector2(-53,222),Vector2(-41.5,222),Vector2(-41.5,215),Vector2(-41.5,208),Vector2(-41.5,212),Vector2(-41.5,218)]:
		if not await walk(point):break
	var actions:Dictionary={}
	for action in w.interactions:actions[action.id]=action
	for id in ["B04_flowers","B05_exhibition","B08_dance","B10_performance","B10_lights"]:
		check("original_"+id,actions.has(id))
	for row in [["B04_flowers","florist_choices"],["B05_exhibition","gallery_choices"],["B08_dance","dance_choices"],["B10_performance","theater_choices"]]:
		if actions.has(row[0]):
			main.activate(actions[row[0]]);await main.qa_frame();await snap(row[1])
			check(row[1]+"_opens",main.modal.visible)
			if row[0]=="B04_flowers":
				if not main.qa_mode.contains("before"):
					check("flower_specific_heading",has_heading("花间花店"))
				for index in 3:
					check("flower_button_"+str(index),press(["淡紫花束","暖杏花束","林间绿色"][index]))
					await main.qa_frame()
					check("flower_state_"+str(index),int(main.state.bouquet)==index and w.home_bouquet==index)
					var saved:Dictionary=main.store.read()
					check("flower_disk_"+str(index),not saved.is_empty() and int(saved.get("bouquet",-1))==index)
				check("flower_save",main.save_game(false))
				if not main.qa_mode.contains("before"):
					# A regular file used as a directory forces an actual write failure in isolated QA storage.
					var directory:String=main.store.directory
					var original:PackedByteArray=FileAccess.get_file_as_bytes(directory+"/progress.json")
					var blocked:String=directory+"/not_a_directory"
					var fixture:=FileAccess.open(blocked,FileAccess.WRITE);fixture.store_string("QA fixture");fixture.close()
					main.store.directory=blocked
					press("淡紫花束");await main.qa_frame()
					check("flower_failed_save_rolls_back",int(main.state.bouquet)==2 and w.home_bouquet==2)
					var explained:=false
					for text_node in main.modal.find_children("*","Label",true,false):
						if text_node.text.contains("花束未保存"):explained=true
					check("flower_failed_save_explained",explained)
					await snap("florist_save_failure")
					main.store.directory=directory
					check("flower_failed_save_preserves_disk",FileAccess.get_file_as_bytes(directory+"/progress.json")==original)
					DirAccess.remove_absolute(blocked)
					press("暖杏花束");await main.qa_frame()
					check("flower_retry_saves",int(main.store.read().get("bouquet",-1))==1 and w.home_bouquet==1)
					check("flower_retry_clears_failure_notice",main.note_label.text=="花束已保存。")
			main.close_modal();main.player.enabled=false;main.hud.hide()
	if not main.qa_mode.contains("before"):
		main.player.position=w.surface(-53,210.8,0.4);main.player.velocity=Vector3.ZERO
		await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
		main.hud.show();await main.qa_frame();await snap("florist_play_hud");main.hud.hide()
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"scope":"17 fixed views; real florist and greenhouse route; four existing action menus and three bouquet choices. Full gallery/media/other venue routes verified by existing suites.","runtime":"editor_binary" if OS.has_feature("editor") else "export_release"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
