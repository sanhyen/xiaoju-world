extends "res://scripts/nature_qa.gd"
## Rendered PB interaction, real viewport input and independent saved-page readback.

func button_named(name:String)->Button:
	for node in main.modal.find_children(name,"Button",true,false):return node
	return null

func zoom_view():
	for node in main.modal.find_children("ImageZoom","Control",true,false):return node
	return null

func settle():
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	await main.qa_frame()

func shot(name:String):
	await settle()
	var viewport:Rect2=main.get_viewport().get_visible_rect()
	var outside:Array=[]
	for node in main.modal.find_children("*","Control",true,false):
		if node.visible and (node is Button or node is Label or node.name=="ImageZoom"):
			var rect:Rect2=node.get_global_rect()
			if not viewport.grow(1).encloses(rect):outside.append({"name":str(node.name),"rect":str(rect)})
	check("controls_inside_viewport_"+name,outside.is_empty(),{"outside":outside})
	var path:String=main.evidence_root+"screenshots/"+main.qa_mode+"_"+name+".png"
	check("capture_"+name,main.get_viewport().get_texture().get_image().save_png(path)==OK)

func mouse_button(view,where:Vector2,index:MouseButton,pressed:bool):
	var event:=InputEventMouseButton.new();event.button_index=index;event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if index==MOUSE_BUTTON_LEFT and pressed else 0
	event.position=view.get_global_transform_with_canvas()*where;event.global_position=event.position
	main.get_viewport().push_input(event,true)
	if pressed and index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var release:=event.duplicate();release.pressed=false;release.button_mask=0;main.get_viewport().push_input(release,true)
	await main.get_tree().process_frame

func run(target):
	main=target;main.store.directory="user://qa_isolated/pb_zoom"
	await main.start_game(main.qa_mode.ends_with("read"));main.player.enabled=false;main.player.program_driven=true
	if main.qa_mode.ends_with("read"):
		check("independent_process_restores_reading_position",int(main.state.pb_page)==3)
		main.show_pb(int(main.state.pb_page));await settle()
		check("restored_spread_has_matching_pages",button_named("PBImageOpen_2")!=null and button_named("PBImageOpen_3")!=null)
		await shot("restored_spread")
	else:
		main.show_pb(0);await settle();check("cover_has_full_image",button_named("PBImageOpen_0")!=null);await shot("cover")
		main.show_pb(1);await settle()
		var right:=button_named("PBImageOpen_1")
		check("spread_has_independent_left_and_right",button_named("PBImageOpen_0")!=null and right!=null)
		await shot("spread")
		if right!=null:right.pressed.emit()
		await settle();var view=zoom_view()
		check("right_image_opens_its_own_texture",view!=null and view.texture.resource_path=="res://"+main.assets[1].runtime_path)
		if view!=null:
			var image_ratio:float=float(view.texture.get_width())/view.texture.get_height()
			check("fit_preserves_original_ratio",absf(view.image_rect().size.x/view.image_rect().size.y-image_ratio)<0.0001)
			await mouse_button(view,view.size/2,MOUSE_BUTTON_WHEEL_UP,true)
			check("viewport_wheel_really_zooms",view.zoom>1.0)
			for i in 8:await mouse_button(view,view.size/2,MOUSE_BUTTON_WHEEL_UP,true)
			check("zoom_is_bounded",is_equal_approx(view.zoom,4.0))
			await mouse_button(view,view.size/2,MOUSE_BUTTON_LEFT,true)
			var motion:=InputEventMouseMotion.new();motion.position=view.get_global_transform_with_canvas()*(view.size/2+Vector2(180,100));motion.global_position=motion.position;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			main.get_viewport().push_input(motion,true);await main.get_tree().process_frame
			await mouse_button(view,view.size/2+Vector2(180,100),MOUSE_BUTTON_LEFT,false)
			check("viewport_drag_moves_image",view.pan.length()>50)
			check("zoom_preserves_ratio",absf(view.image_rect().size.x/view.image_rect().size.y-image_ratio)<0.0001)
			await shot("zoom_pan")
			view.pan=Vector2(100000,-100000);view.clamp_pan()
			var rect:Rect2=view.image_rect()
			check("pan_stops_at_image_edges",rect.position.x<=0.01 and rect.position.y<=0.01 and rect.end.x>=view.size.x-0.01 and rect.end.y>=view.size.y-0.01)
			var fit:=button_named("ImageZoomFit")
			if fit!=null:
				var pointer:=InputEventMouseMotion.new();pointer.position=fit.get_global_transform_with_canvas()*(fit.size/2);pointer.global_position=pointer.position
				main.get_viewport().push_input(pointer,true);await main.get_tree().process_frame
				await mouse_button(fit,fit.size/2,MOUSE_BUTTON_LEFT,true)
				await mouse_button(fit,fit.size/2,MOUSE_BUTTON_LEFT,false)
				await settle()
			check("viewport_fit_button_resets",fit!=null and is_equal_approx(view.zoom,1.0) and view.pan==Vector2.ZERO,{"zoom":view.zoom,"pan":str(view.pan),"hovered":fit.is_hovered() if fit!=null else false})
			var escape:=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.keycode=KEY_ESCAPE;escape.pressed=true
			main.get_viewport().push_input(escape,true);await settle()
			check("escape_returns_to_same_spread",main.modal.visible and int(main.state.pb_page)==1 and zoom_view()==null and button_named("PBImageOpen_1")!=null)
		var reopen:=button_named("PBImageOpen_1")
		if reopen!=null:
			reopen.pressed.emit();await settle()
			for node in main.modal.find_children("*","Button",true,false):
				if node.text=="查看这张图的来源":node.pressed.emit();break
			await settle();var matching:=false
			for node in main.modal.find_children("*","TextureRect",true,false):
				if node.texture!=null and node.texture.resource_path=="res://"+main.assets[1].runtime_path:matching=true
			check("right_image_source_matches_right_image",matching)
			await shot("right_source");main.return_from_modal();await settle()
			check("source_returns_to_reading_page",int(main.state.pb_page)==1 and button_named("PBImageOpen_1")!=null)
		main.show_pb(2);await settle();check("single_page_preserved",button_named("PBImageOpen_1")!=null and button_named("PBImageOpen_0")==null);await shot("single")
		main.close_modal();main.player.enabled=false
		check("personal_photo_captured",await main.save_photo())
		main.show_pb(main.assets.size()+1);await settle()
		var personal:=button_named("PBPersonalOpen");check("personal_page_has_zoom",personal!=null)
		if personal!=null:
			personal.pressed.emit();await settle();check("personal_photo_opens_zoom",zoom_view()!=null);await shot("personal")
		var before:int=main.state.shots.size();main.state.shots.append("qa_missing_image.png")
		main.show_pb(main.assets.size()+main.state.shots.size());await settle()
		var message:=false
		for node in main.modal.find_children("*","Label",true,false):
			if node.text.begins_with("这张风景照片已不在"):message=true
		check("missing_photo_keeps_record_and_explains",message and main.state.shots.size()==before+1)
		main.state.shots.pop_back();main.show_pb(3);check("reading_position_saved",main.save_game(false))
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var report:={"mode":main.qa_mode,"checks":checks,"failures":failures,"window_size":str(main.get_window().size),"ui_viewport_size":str(main.get_viewport().get_visible_rect().size),"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","scope":"rendered PB and synthetic viewport events; actual saved-page readback in separate mode; not human-input acceptance"}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.get_tree().quit(1 if failures else 0)
