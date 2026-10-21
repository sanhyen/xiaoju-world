extends Control
## Local image inspection: preserve aspect ratio, zoom around cursor and bound panning.
signal zoom_changed(value:float)
var texture:Texture2D
var zoom:float=1.0
var pan:=Vector2.ZERO
var dragging:=false
var last_pointer:=Vector2.ZERO

func _ready():
	clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_ALL
	resized.connect(func():clamp_pan();queue_redraw())
	mouse_exited.connect(func():dragging=false)
	queue_redraw()

func fitted_size()->Vector2:
	if texture==null or size.x<=0 or size.y<=0:return Vector2.ZERO
	var dimensions:=texture.get_size()
	if dimensions.x<=0 or dimensions.y<=0:return Vector2.ZERO
	return dimensions*minf(size.x/dimensions.x,size.y/dimensions.y)

func image_rect()->Rect2:
	var dimensions:=fitted_size()*zoom
	return Rect2((size-dimensions)/2+pan,dimensions)

func clamp_pan():
	var limit:Vector2=((fitted_size()*zoom-size)/2).max(Vector2.ZERO)
	pan=pan.clamp(-limit,limit)

func set_zoom_at(value:float,at:Vector2):
	var old:=image_rect()
	if old.size.x<=0 or old.size.y<=0:return
	var uv:Vector2=(at-old.position)/old.size
	zoom=clampf(value,1.0,4.0)
	var dimensions:=fitted_size()*zoom
	pan=at-uv*dimensions-(size-dimensions)/2
	clamp_pan();queue_redraw();zoom_changed.emit(zoom)

func reset_view():
	zoom=1.0;pan=Vector2.ZERO;dragging=false
	queue_redraw();zoom_changed.emit(zoom)

func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color("122a29"))
	if texture!=null:draw_texture_rect(texture,image_rect(),false)

func _gui_input(event:InputEvent):
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			dragging=event.pressed;last_pointer=event.position
			if event.pressed:
				grab_focus()
				if event.double_click:reset_view()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			set_zoom_at(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8),event.position)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan+=event.position-last_pointer;last_pointer=event.position
		clamp_pan();queue_redraw();accept_event()
