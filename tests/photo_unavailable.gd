extends SceneTree
func _initialize():run.call_deferred()
func run():
	var main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	main.qa_mode="photo_unavailable";main.store.directory="user://qa_isolated/photo_unavailable"
	var count:int=main.state.shots.size();var begun:=Time.get_ticks_msec()
	var saved:bool=await main.save_photo()
	var elapsed:=Time.get_ticks_msec()-begun
	var passed:bool=not saved and not main.photo_saving and main.state.shots.size()==count and elapsed<1000 and main.last_photo_capture.reason=="draw_unavailable"
	var report:={"passed":passed,"elapsed_ms":elapsed,"capture":main.last_photo_capture,"scope":"headless absence returns failure without a photo index; not GPU evidence"}
	var file:=FileAccess.open("res://reports/photo_unavailable.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PHOTO_UNAVAILABLE ",JSON.stringify(report))
	main.queue_free();await process_frame;await process_frame;quit(0 if passed else 1)
