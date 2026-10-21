extends Control
## Visitor floor plans use the baked structure, real stairs and authored equipment positions.
var m
var place:Dictionary={}
var level:=0
var scale_m:=1.0
var origin:=Vector2.ZERO
var devices:Array=[]
const NAMES={"oven":"烤窑","espresso":"茶饮吧台","turntable":"唱盘","flowerbench":"花材台","folio":"展阅台","bindery":"装订台","loom":"织机","console":"操控台","drawers":"分类柜","projector":"放映机","camera":"摄影位","photo":"冲印台","easel":"画架","telescope":"观景仪","diorama":"造景台","street":"街景台","basin":"材料池","pottery":"拉坯台","hearth":"壁炉","puppet":"木偶台","drying":"晾晒架","mannequin":"人台","roaster":"烘豆机","chimes":"风铃架","seedwall":"材料架","schedule":"导览牌","luggage":"行李车","tools":"工具墙"}
func setup(main):
	m=main;mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_ALL;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back:Button=m.button(self,"返回世界地图",hide);back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);back.offset_left=-164;back.offset_right=-12;back.offset_top=5;back.offset_bottom=43;back.add_theme_font_size_override("font_size",17);hide()
func open(selection:Dictionary):
	var id:String=str(selection.get("parent",selection.id));place={};level=0
	for p in m.world.layout.creative_places:
		if str(p.id)==id:place=p;break
	if place.is_empty():return
	if "_FLOOR_" in str(selection.id):level=clampi(int(str(selection.id).get_slice("_FLOOR_",1)),0,place.floors.size()-1)
	if m.world.streamer!=null:devices=m.world.streamer.manifest.authored_counts.get("design120_devices",[])
	show();grab_focus();queue_redraw()
func xy(p:Vector3)->Vector2:
	var local:Vector3=Basis(Vector3.UP,-float(place.get("door_yaw",0)))*(p-Vector3(place.center[0],place.center[1],place.center[2]));return origin+Vector2(local.x,local.z)*scale_m
func label(p:Vector2,words:String,height:int=16,tone:Color=Color("38564e")):
	draw_string(m.font,p,words,HORIZONTAL_ALIGNMENT_LEFT,-1,height,tone)
func _draw():
	if place.is_empty():return
	draw_rect(Rect2(Vector2.ZERO,size),Color("e6e4d0"));label(Vector2(26,34),str(place.name)+" · 第 "+str(level+1)+" 层",24)
	var width:float=place.size[0];var depth:float=place.size[1]
	if str(place.id)=="CASTLE_MAIN":width-=level*1.6;depth-=level*1.4
	if absf(sin(float(place.get("door_yaw",0))))>.7:var swap:float=width;width=depth;depth=swap
	scale_m=minf((size.x-160)/(width+6),(size.y-150)/(depth+6));origin=Vector2(size.x*.5,size.y*.5+10)
	var extent:=Vector2(width,depth)*scale_m;var rect:=Rect2(origin-extent*.5,extent)
	draw_rect(rect,Color("f7f0db") if level==0 else Color("c3c9b3"));draw_rect(rect,Color("7c8e76"),false,5)
	if level>0:
		var surfaces:=0
		for route in m.world.get_meta("upper_routes110",[]):
			if str(route.get("owner",""))!=str(place.id):continue
			for surface in route.get("floors",[]):
				if absf(float(surface.y)-float(place.floors[level]))>.1:continue
				var at:Vector2=xy(surface.center);var extent_value:Vector2=surface.size*scale_m
				if absf(sin(float(place.get("door_yaw",0))))>.7:extent_value=Vector2(extent_value.y,extent_value.x)
				draw_rect(Rect2(at-extent_value*.5,extent_value),Color("f7f0db"));surfaces+=1
		if surfaces==0:draw_rect(rect,Color("f7f0db"))
	for x in range(-int(width*.5),int(width*.5)+1):draw_line(origin+Vector2(x*scale_m,-extent.y*.5),origin+Vector2(x*scale_m,extent.y*.5),Color(.42,.53,.42,.12),1)
	for z in range(-int(depth*.5),int(depth*.5)+1):draw_line(origin+Vector2(-extent.x*.5,z*scale_m),origin+Vector2(extent.x*.5,z*scale_m),Color(.42,.53,.42,.12),1)
	var y:float=place.floors[level]
	if str(place.id)=="THEME_EVERYDAY":draw_arc(origin,minf(extent.x,extent.y)*.5,0,TAU,48,Color("658975"),4)
	if str(place.id).begins_with("CASTLE_") and level>0:
		var center:=Vector3(place.center[0],y,place.center[2]);var hole:=Rect2(xy(center+Vector3(-5.2,0,-4.2)),Vector2(5.4,9)*scale_m);draw_rect(hole,Color("c3c9b3"));label(hole.position+Vector2(5,22),"梯井",15)
	for item in devices:
		var p:Vector3=item.position
		if absf(p.y-y)>.5:continue
		var at:Vector2=xy(p)
		if not rect.grow(scale_m*1.5).has_point(at):continue
		var unit:float=float(item.get("scale",1));var box:=Rect2(at-Vector2(1.5,.65)*unit*scale_m,Vector2(3,1.3)*unit*scale_m)
		draw_rect(box,Color("b4b99a"));draw_rect(box,Color("6a806c"),false,1);label(box.position+Vector2(4,16),str(NAMES.get(item.kind,"陈设")),14)
	for route in m.world.get_meta("upper_routes110",[]):
		if str(route.get("owner",""))!=str(place.id):continue
		var points:Array=route.get("points",[])
		for i in points.size()-1:
			var a:Vector3=points[i];var c:Vector3=points[i+1]
			if y<minf(a.y,c.y)-.3 or y>maxf(a.y,c.y)+.3:continue
			draw_line(xy(a),xy(c),Color("b58c53"),5,true)
	var entry:Array=place.get("door",[])
	if level<place.get("floor_entries",[]).size():entry=place.floor_entries[level].point
	if entry.size()==3:
		var door:Vector2=xy(Vector3(entry[0],entry[1],entry[2]));draw_circle(door,7,Color("658d87"));label(door+Vector2(12,5),"入口 / 楼层落点",15)
	if absf(m.player.position.y-y)<2:draw_circle(xy(m.player.position),7,Color("b4715a"))
	label(Vector2(26,size.y-50),"每格 1 米   绿色：固定设备   金线：楼梯与连廊   红点：当前位置",17)
	label(Vector2(26,size.y-23),"上 / 下方向键切换楼层；在原目录中选择入口、导航或立即前往。",17)
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.position.y<50 and event.position.x>size.x-155:hide();accept_event()
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_UP,KEY_DOWN]:level=posmod(level+(1 if event.keycode==KEY_UP else -1),place.floors.size());queue_redraw();accept_event()
