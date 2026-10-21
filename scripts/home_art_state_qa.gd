extends RefCounted
## Two separate native processes verify new decor, light UI and unchanged save schema.
static func run(main):
	main.store.directory="user://qa_isolated/art_v11_cold"
	var writing:bool=main.qa_mode=="home_state_write"
	var results:Array=[]
	await main.start_game(not writing);main.player.enabled=false;main.hud.hide()
	var o:Vector3=main.world.surface(-237,-169,0.08)
	if writing:
		main.player.position=o+Vector3(0,0.5,1);await main.world.prepare_region(main.player.position)
		main.state.stamps=["Z07"];main.claim_card("Z07")
		main.state.bouquet=2;main.state.home_photo=5
		main.world.update_home(2,"res://"+main.assets[5].runtime_path)
		main.watch_camera.position=o+Vector3(0,1.8,3.6);main.watch_camera.look_at(o+Vector3(0,2,-4.8));main.watch_camera.current=true
		await main.save_photo()
		main.state.home_shot=str(main.state.shots[-1]).get_file();main.sync_home_memories()
	main.show_home();await main.get_tree().process_frame
	var selector:OptionButton
	for option in main.modal.find_children("*","OptionButton",true,false):
		if option.item_count==3 and option.get_item_text(0)=="柔和暖光":selector=option;break
	results.append({"test":"real_home_light_selector_exists","passed":selector!=null})
	if selector!=null and writing:
		selector.select(2);selector.item_selected.emit(2)
		var all_off:=true
		for light in main.world.home_lights:all_off=all_off and light.light_energy==0
		results.append({"test":"UI_switches_actual_lights_off","passed":all_off and main.world.home_lights.size()==2})
		selector.select(1);selector.item_selected.emit(1)
		results.append({"test":"UI_reading_light_saved","passed":main.state.home_light==1 and main.save_game(false)})
	if not writing:
		results.append({"test":"light_UI_restored_in_new_process","passed":selector!=null and selector.selected==1})
		results.append({"test":"decor_fields_restored_in_new_process","passed":main.state.bouquet==2 and main.state.home_photo==5 and main.state.home_card=="Z07" and not main.state.home_shot.is_empty()})
		results.append({"test":"actual_light_energy_restored","passed":main.world.home_lights.size()==2 and main.world.home_lights.all(func(light):return is_equal_approx(light.light_energy,0.85))})
		results.append({"test":"actual_personal_image_restored","passed":is_instance_valid(main.world.home_extras) and FileAccess.file_exists(main.world.home_shot_path)})
		results.append({"test":"home_is_reachable_room_after_restore","passed":main.world.inside_building(main.player.position)=="B12"})
	await main.qa_frame()
	main.get_viewport().get_texture().get_image().save_png(main.evidence_root+"screenshots/art_v11_"+main.qa_mode+"_ui.png")
	main.close_modal();main.player.enabled=false;main.hud.hide()
	var picture=main.world.home_picture
	var tex:Texture2D=picture.material_override.albedo_texture
	results.append({"test":"real_photo_original_ratio_and_frame_limits","passed":absf(picture.mesh.size.x/picture.mesh.size.y-float(tex.get_width())/tex.get_height())<0.005 and picture.mesh.size.x<=2.101 and picture.mesh.size.y<=2.001})
	main.set_time(1)
	await main.qa_capture("art_v11_"+main.qa_mode+"_collection",o+Vector3(1.5,1.7,-0.9),o+Vector3(0,2,-5))
	var failures:=0
	for row in results:
		print("HOME_ART_STATE ",JSON.stringify(row))
		if not row.passed:failures+=1
	var report:={"mode":main.qa_mode,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","results":results,"failures":failures,"save_schema":main.state.version,"scope":"two independent native runs, isolated saves, real UI signal, real light nodes, original images and personal photo; no user save overwritten"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
