extends "res://scripts/nature_qa.gd"
## Same cameras for four retained buildings; actual booth access and visitor-service UI.
func run(target):
	main=target;main.store.directory="user://qa_isolated/interiors_review"
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=70;main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors_cameras.json"))
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
	main.player.position=w.surface(-211,65,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	for point in [Vector2(-211,59),Vector2(-211,55),Vector2(-211,52),Vector2(-211,48.5),Vector2(-213.5,48.5),Vector2(-215.8,48.5),Vector2(-213.5,48.5),Vector2(-211,48.5),Vector2(-211,55),Vector2(-211,62)]:
		if not await walk(point):break
	var actions:Dictionary={}
	for action in w.interactions:actions[action.id]=action
	check("original_service_and_listening_actions",actions.has("B13_map") and actions.has("B09_listen"))
	main.player.position=w.surface(57,106,0.4);main.player.velocity=Vector3.ZERO;await w.prepare_region(main.player.position)
	for point in [Vector2(57,101),Vector2(57,98),Vector2(57,94.2)]:
		if not await walk(point):break
	if actions.has("B13_map"):
		check("visitor_service_reachable",main.player.position.distance_to(actions.B13_map.pos)<1.5)
		main.activate(actions.B13_map);await main.qa_frame();await snap("visitor_services")
		if not main.qa_mode.contains("before"):
			var titles:=["查看地图与已探索区域","打开旅行纪念册","查看我的收藏","操作说明","素材来源与关于","设置"]
			var headings:=["山海导览 · 八区环线","拾光纪念册","我的山海纪念册","操作说明","素材与关于","设置"]
			for index in titles.size():
				var found:=false
				for node in main.modal.find_children("*","Button",true,false):
					if node.text==titles[index]:node.pressed.emit();found=true;break
				check("visitor_option_"+str(index)+"_opens",found and main.modal.visible)
				if found:
					await main.qa_frame();await snap("visitor_option_"+str(index))
					check("visitor_option_"+str(index)+"_content",has_heading(headings[index]))
					if index==0:
						# Actual map signal opens a destination and keeps the visitor origin.
						var map=main.modal_box.get_child(1)
						map.destination.emit(main.world.spec.zones[0]);await main.qa_frame()
						check("visitor_map_destination",main.target_zone.id==main.world.spec.zones[0].id and has_heading(main.world.spec.zones[0].name))
					if index==1:
						press("下一页");await main.qa_frame()
						check("visitor_pb_page_turn",int(main.state.pb_page)==1)
						press("放大影像 · 01");await main.qa_frame()
						check("visitor_pb_zoom",main.modal.find_child("ImageZoom",true,false)!=null)
						press("返回");await main.qa_frame()
						check("visitor_pb_zoom_returns_page",has_heading("拾光纪念册") and int(main.state.pb_page)==1)
					# Exercise the actual header button connected to return_from_modal.
					for node in main.modal.find_children("*","Button",true,false):
						if node.text=="返回":node.pressed.emit();break
					await main.qa_frame()
					var restored:=false
					for node in main.modal.find_children("*","Button",true,false):
						if node.text=="查看地图与已探索区域":restored=true
					check("visitor_option_"+str(index)+"_returns",restored)
			press("返回");await main.qa_frame()
			check("visitor_origin_cleared_on_close",not main.modal.visible and not main.visitor_return.is_valid())
			main.show_pb(0);press("返回");await main.qa_frame()
			check("ordinary_pb_does_not_return_to_visitor",not main.modal.visible)
		main.close_modal();main.player.enabled=false;main.hud.hide()
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"scope":"17 fixed room/facade views, actual studio-booth and visitor-desk walking, visitor choices and header return; original media/save suites run separately","runtime":"editor_binary" if OS.has_feature("editor") else "export_release"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)

func snap(name:String):
	await main.qa_frame()
	check(name+"_ui_capture",main.get_viewport().get_texture().get_image().save_png(main.evidence_root+"screenshots/"+main.qa_mode+"_"+name+".png")==OK)

func press(value:String)->bool:
	for node in main.modal.find_children("*","Button",true,false):
		if node.text==value:node.pressed.emit();return true
	return false

func has_heading(value:String)->bool:
	return str(main.modal_box.get_child(0).get_child(0).text).begins_with(value)
