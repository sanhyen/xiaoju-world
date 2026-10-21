extends Control
var m
var map
var collapsed:=false
var fold:Button
var tick:=0.0
func setup(main):
	m=main;name="BayMiniMap";set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map=preload("res://scripts/bay_map_view.gd").new();map.name="MiniMapSurface";map.spec=m.world.spec;map.layout_reference=m.world.layout;map.font=m.font;map.mini=true;map.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(map)
	map.destination.connect(func(_place):m.show_map())
	fold=Button.new();fold.name="MiniMapFold";fold.text="−";fold.tooltip_text="N 收起 / 展开；按住 Alt 可点击";fold.pressed.connect(toggle);add_child(fold);fold.add_theme_font_size_override("font_size",18)
	apply_size()
func apply_size():
	var width:float=48 if collapsed else 260;offset_left=-24-width;offset_right=-24;offset_top=24;offset_bottom=24+(48 if collapsed else 292)
	map.visible=not collapsed;map.position=Vector2(0,28);map.size=Vector2(260,260)
	fold.position=Vector2(width-34,0);fold.size=Vector2(30,26);fold.text="+" if collapsed else "−";queue_redraw()
func toggle():collapsed=not collapsed;apply_size()
func _input(event):
	if m==null or not m.active_game or m.photo_mode:return
	if event is InputEventKey and event.physical_keycode==KEY_N and event.pressed and not event.echo and not m.modal.visible:toggle();get_viewport().set_input_as_handled()
	if event is InputEventKey and event.physical_keycode==KEY_ALT and not m.modal.visible:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if event.pressed or m.environment_controls.is_observing() else Input.MOUSE_MODE_CAPTURED
func _draw():
	var style:=StyleBoxFlat.new();style.bg_color=Color("263f3b");style.border_color=Color("d5bd88");style.set_border_width_all(1);style.set_corner_radius_all(8);draw_style_box(style,Rect2(Vector2.ZERO,size))
	if m!=null:draw_string(m.font,Vector2(10,20),"N" if collapsed else "N ↑  山海导览   Alt 点击 · N 折叠",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("eee0bd"))
func _process(delta:float):
	if m==null:return
	visible=m.active_game and not m.modal.visible and not m.photo_mode
	tick+=delta
	if not visible or collapsed or tick<.1:return
	tick=0;map.player_pos=m.player.position;map.yaw=m.player.yaw;map.target=m.target_zone;map.discovered=m.state.discovered;map.clues=m.state.activities.get("clues",[]);map.queue_redraw()
