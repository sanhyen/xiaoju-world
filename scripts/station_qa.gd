extends "res://scripts/nature_qa.gd"
## B01 arrival, guide and waiting area tested through the retained controller.
func run(target):
	main=target;phase="station_review"
	fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string("res://data/station_cameras.json"))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=70
	main.sun.shadow_enabled=true;main.get_viewport().scaling_3d_scale=1.0
	var w=main.world
	for view in fixed_cameras:
		main.set_time(int(view.time))
		await capture(view.name,Vector3.ZERO,Vector3.ZERO)
		cameras[-1].time=int(view.time)
	main.set_time(0)
	var actions:Dictionary={}
	for action in w.interactions:actions[action.id]=action
	check("station_original_actions_retained",["B01_enter","B01_guide","B01_wait"].all(func(id):return actions.has(id)))
	main.player.position=w.surface(260,198,0.4);main.player.velocity=Vector3.ZERO
	await w.prepare_region(main.player.position);main.watch_camera.current=false;main.player.camera.current=true
	for point in [Vector2(260,193),Vector2(260,188),Vector2(260,182)]:
		if not await walk(point):break
	if actions.has("B01_guide"):
		check("guide_reachable_from_door",main.player.position.distance_to(actions.B01_guide.pos)<1.5)
		main.activate(actions.B01_guide)
		var maps:Array=[]
		for node in main.modal.find_children("*","Control",true,false):
			if node.get_script()==main.MapView:maps.append(node)
		check("guide_opens_actual_map",main.modal.visible and maps.size()==1)
		if maps.size()==1:
			check("map_contains_eight_actual_zones",maps[0].spec.zones.size()==8 and maps[0].spec==w.spec)
			maps[0].destination.emit(w.spec.zones[3])
			check("map_marks_actual_plaza",main.target_zone.id=="Z04" and main.target_zone.x==0 and main.target_zone.z==80)
		main.close_modal();main.player.enabled=false
	for point in [Vector2(267,182),Vector2(267,178)]:
		if not await walk(point):break
	if actions.has("B01_wait"):
		check("waiting_seat_reachable",main.player.position.distance_to(actions.B01_wait.pos)<1.5)
		main.activate(actions.B01_wait);check("waiting_seat_usable",main.player.seated)
		main.player.stand_up();check("waiting_seat_can_exit",not main.player.seated)
	for point in [Vector2(267,181),Vector2(260,181),Vector2(260,193),Vector2(255,201),Vector2(255,218)]:
		if not await walk(point):break
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"cameras":cameras,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","scope":"B01 fixed views, ordinary arrival/seat/exit movement and actual map destination; individual visual review required"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
