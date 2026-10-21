extends RefCounted
## Real rendered views and short diagnostics of the third-round changes.
static func run(main):
	await main.get_tree().create_timer(2).timeout
	main.menu.hide();main.hud.hide();main.active_game=true;main.player.enabled=false
	var w=main.world
	var views:Array=[
		["theater",w.surface(-315,33,3),w.surface(-291,8,5)],
		["theater_side",w.surface(-321,-20,3),w.surface(-291,8,7)],
		["theater_inside",w.surface(-291,19,2.3),w.surface(-291,-2,4.8)],
		["theater_stage",w.surface(-278,4,2.2),w.surface(-291,-3,4.2)],
		["dance_front",w.surface(-252,-15,2.5),w.surface(-232,-38,4)],
		["dance_inside",w.surface(-232,-32,2.1),w.surface(-232,-44,2.7)],
		["dance_lockers",w.surface(-232,-37,2.1),w.surface(-237,-31.2,1.8)],
		["studio_front",w.surface(-198,71,2.5),w.surface(-211,52,2.6)],
		["studio_inside",w.surface(-211,56,2.2),w.surface(-215,48,2)],
		["studio_equipment",w.surface(-210,52,2.0),w.surface(-215,51,1.5)],
		["studio_booth_entry",w.surface(-210,48.4,1.8),w.surface(-215,48.4,1.5)],
		["gallery",w.surface(155,-16,2.6),w.surface(173,-42,3)],
		["gallery_side",w.surface(194,-55,2.7),w.surface(173,-42,4)],
		["gallery_inside",w.surface(173,-35,2.2),w.surface(173,-48,2.4)],
		["gallery_rear",w.surface(181,-46,2.1),w.surface(166,-48,2.5)],
		["cinema_front",w.surface(225,-57,2.5),w.surface(245,-87,4)],
		["cinema_lobby",w.surface(249,-78.3,2.1),w.surface(236,-78,2.5)],
		["cinema_inside",w.surface(256.5,-83,2.8),w.surface(242,-94,3.2)],
		["pb_garden",w.surface(196,-134,2.4),w.surface(225,-153,2.9)],
		["pb_inside",w.surface(225,-146,2.1),w.surface(226,-159,2.4)],
		["pb_reading",w.surface(231,-151,2),w.surface(235,-155,2)],
		["pb_table",w.surface(224,-150,1.7),w.surface(225,-153,0.95)],
		["music_court",w.surface(-248,40,2.5),w.surface(-290,10,4)],
		["music_garden",w.surface(-253,1,2.2),w.surface(-271,3,2.8)],
		["music_garden_close",w.surface(-262,8,2.1),w.surface(-270,1,2.1)],
		["music_connection",w.surface(-261,-23,2.3),w.surface(-281,-8,3)],
		["culture_path",w.surface(216,-62,2.2),w.surface(186,-39,3)],
		["culture_courtyard",w.surface(199,-100,2.2),w.surface(185,-113,2.7)],
		["culture_reading_garden",w.surface(215,-110,2.1),w.surface(225,-144,3)],
		["forest_floor",w.surface(-101,-273,2.1),w.surface(-122,-286,2.5)],
		["forest_east",w.surface(108,-275,2.1),w.surface(122,-262,2.5)],
		["river_entry",w.surface(270,-55,2.1),Vector3(288,-0.3,-32)],
		["river_walk",Vector3(302,1.2,22),Vector3(314,-0.2,62)],
		["river_bay",Vector3(296,1.3,34),Vector3(313,-0.1,44)],
		["river_south",Vector3(313,1.2,113),Vector3(310,-0.4,131)]
	]
	for entry in views:await main.qa_capture(main.qa_mode+"_"+entry[0],entry[1],entry[2])
	main.set_time(1)
	await main.qa_capture(main.qa_mode+"_music_dusk",w.surface(-248,40,2.5),w.surface(-290,10,4))
	await main.qa_capture(main.qa_mode+"_cinema_dusk",w.surface(225,-57,2.5),w.surface(245,-87,4))
	main.set_time(0)
	var diagnostics:Array=[]
	for entry in [["music",w.surface(-250,27,2.5),w.surface(-288,8,5)],["culture",w.surface(215,-62,2.2),w.surface(185,-42,3)]]:
		main.watch_camera.position=entry[1];main.watch_camera.look_at(entry[2]);main.watch_camera.current=true
		await main.get_tree().create_timer(1).timeout
		main.qa_ms.clear();main.qa_collect=true
		await main.get_tree().create_timer(8).timeout
		main.qa_collect=false;main.qa_ms.sort()
		var total:=0.0;var slow:=0
		for ms in main.qa_ms:total+=ms;if ms>100:slow+=1
		diagnostics.append({"location":entry[0],"frames":main.qa_ms.size(),"average_fps":1000.0/(total/main.qa_ms.size()),"p95_ms":main.qa_ms[int(main.qa_ms.size()*0.95)],"p99_ms":main.qa_ms[int(main.qa_ms.size()*0.99)],"over100ms":slow,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)})
	var report:={"mode":main.qa_mode,"views":views.size()+2,"diagnostics":diagnostics,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","resolution":[main.get_viewport().size.x,main.get_viewport().size.y],"renderer":RenderingServer.get_current_rendering_method(),"caveat":"two 8-second stationary diagnostics; monotonic frame intervals, not final long route acceptance"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VENUES_QA ",JSON.stringify(report));main.get_tree().quit()
