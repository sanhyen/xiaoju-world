extends RefCounted
class RejectStore:
	extends RefCounted
	func write(_state:Dictionary)->bool:return false
var main
var checks:Array=[]
func sample(_delta:float):pass
func check(name:String,ok:bool,detail:Dictionary={}):
	checks.append({"test":name,"passed":ok,"details":detail});print("PHOTO_CHECK ",name," ",ok," ",JSON.stringify(detail))

func run(target):
	main=target;main.store.directory="user://qa_isolated/photo_capture_regression"
	if main.qa_mode.ends_with("read"):
		await main.start_game(true);main.player.enabled=false
		check("independent_process_restores_photo_index",main.state.shots.size()==3,{"shots":main.state.shots.size()})
		for filename in main.state.shots:
			var picture:=Image.load_from_file(main.photo_directory()+"/"+str(filename))
			check("independent_process_decodes_"+str(filename),picture!=null and not picture.is_empty())
	else:
		await main.start_game(false);main.player.enabled=false
		main.player.position=main.world.surface(0,80,0.5);await main.world.prepare_region(main.player.position)
		main.watch_camera.position=main.world.surface(9,96,3);main.watch_camera.look_at(main.world.surface(0,59,9));main.watch_camera.current=true
		var marker:=ColorRect.new();marker.position=Vector2(12,12);marker.size=Vector2(70,70);marker.mouse_filter=Control.MOUSE_FILTER_IGNORE;main.ui.add_child(marker)
		for mode in ["visible","minimized","render_loop_disabled"]:
			marker.color=Color("dc2866") if mode=="visible" else (Color("27c966") if mode=="minimized" else Color("405cf0"))
			if mode=="minimized":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
				await main.get_tree().create_timer(0.4).timeout
			if mode=="render_loop_disabled":RenderingServer.render_loop_enabled=false
			var before:int=main.state.shots.size();var forced:int=main.qa_forced_draws
			var begun:=Time.get_ticks_msec()
			var saved:bool=await main.save_photo()
			var elapsed:=Time.get_ticks_msec()-begun
			check(mode+"_bounded_save",saved and elapsed<4500 and main.state.shots.size()==before+1,{"elapsed_ms":elapsed,"capture":main.last_photo_capture,"forced_draws":main.qa_forced_draws-forced,"window_mode":DisplayServer.window_get_mode()})
			if saved:
				var picture:=Image.load_from_file(main.photo_directory()+"/"+str(main.state.shots[-1]))
				var pixel:Color=picture.get_pixel(30,30) if picture!=null else Color.BLACK
				check(mode+"_fresh_pixels_and_png",picture!=null and picture.get_width()==1920 and pixel.is_equal_approx(marker.color),{"pixel":str(pixel),"expected":str(marker.color)})
				if picture!=null:picture.save_png(main.evidence_root+"screenshots/"+main.qa_mode+"_"+mode+".png")
			RenderingServer.render_loop_enabled=true
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			await main.get_tree().create_timer(0.3).timeout
		marker.queue_free()
		main.photo_saving=true
		var count:int=main.state.shots.size()
		check("duplicate_request_rejected",not await main.save_photo() and main.state.shots.size()==count)
		main.photo_saving=false
		var original_store=main.store
		main.store=RejectStore.new()
		var result:bool=await main.save_photo()
		check("index_failure_not_reported_as_success",not result and main.last_photo_capture.get("saved",false) and not main.last_photo_capture.get("indexed",true))
		main.store=original_store
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"scope":"actual GPU photo capture, fresh color sentinel, PNG decode, isolated save; not full tour"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.active_game=false
	main.get_tree().quit(1 if failures else 0)
