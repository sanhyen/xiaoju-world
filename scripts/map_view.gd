extends Control
var spec: Dictionary
var player_pos := Vector3.ZERO
var discovered: Array=[]
var font: Font
var clues:Array=[]
signal destination(zone)

func point(x: float,z: float)->Vector2:
	return Vector2((x+480)/960*size.x,(z+480)/1040*size.y)

func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color("e9e2ce"))
	if spec.has("bay_layout"):
		var cfg:Dictionary=spec.bay_layout
		var polygon:=PackedVector2Array([point(-480,560),point(480,560)])
		for i in range(cfg.shore.size()-1,-1,-1):polygon.append(point(cfg.shore[i][0],cfg.shore[i][1]))
		draw_colored_polygon(polygon,Color("79b6b4"))
		for river in cfg.rivers:
			for i in river.points.size()-1:draw_line(point(river.points[i][0],river.points[i][2]),point(river.points[i+1][0],river.points[i+1][2]),Color("7bb3b3"),maxf(3,river.width/960*size.x),true)
		var island:Dictionary=cfg.island;var shape:=PackedVector2Array()
		for i in 36:shape.append(point(island.center[0]+cos(i*TAU/36)*island.radius[0],island.center[1]+sin(i*TAU/36)*island.radius[1]))
		draw_colored_polygon(shape,Color("cfcc99"));draw_string(font,point(196,450),"星海珊瑚岛",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("325c58"))
		for i in cfg.get("hidden_views",[]).size():
			if i in clues:
				var view:Dictionary=cfg.hidden_views[i];var marker:Vector2=point(view.point[0],view.point[2]);draw_circle(marker,5,Color("ba8665"));draw_string(font,marker+Vector2(7,-4),view.name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("704f40"))
		for route in cfg.get("sea_walk",{}).get("routes",[]):
			for i in route.points.size()-1:draw_line(point(route.points[i][0],route.points[i][2]),point(route.points[i+1][0],route.points[i+1][2]),Color("986b42"),3,true)
		for dock in cfg.boat_docks:draw_circle(point(dock.land[0],dock.land[2]),5,Color("a47b52"))
	else:draw_rect(Rect2(Vector2(0,size.y*0.84),Vector2(size.x,size.y*0.16)),Color("6b9b9d"))
	for r in spec.get("routes",[]):
		for i in r.size()-1:draw_line(point(r[i][0],r[i][1]),point(r[i+1][0],r[i+1][1]),Color("b4a783"),4,true)
	for item in spec.get("buildings",[]):
		draw_rect(Rect2(point(item.x-item.w/2,item.z-item.d/2),Vector2(item.w/960*size.x,item.d/960*size.y)),Color("839488"))
	if spec.has("bay_layout"):
		for place in spec.bay_layout.get("extra_places",[]):
			var at:Vector2=point(place.x,place.z);draw_circle(at,5,Color("ba8465"));draw_string(font,at+Vector2(7,-3),place.name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("704f40"))
	for z in spec.get("zones",[]):
		var p:=point(z.x,z.z)
		draw_circle(p,8,Color("ad9277") if z.id not in discovered else Color("3c726d"))
		draw_string(font,p+Vector2(13,5),z.name,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("2e4b48"))
	draw_circle(point(player_pos.x,player_pos.z),6,Color("b46765"))

func places()->Array:
	var result:Array=[]
	for zone in spec.zones:result.append(zone.duplicate(true))
	for venue in spec.buildings:result.append({"id":venue.id,"name":venue.name,"x":venue.x,"z":venue.z,"kind":"venue"})
	if spec.has("bay_layout"):
		result.append_array(spec.bay_layout.get("extra_places",[]))
		for i in spec.bay_layout.boat_docks.size():
			var d:Dictionary=spec.bay_layout.boat_docks[i];result.append({"id":"BOAT_DOCK_"+str(i),"name":d.name,"x":d.land[0],"z":d.land[2],"kind":"boat","safe":d.land})
		for i in spec.bay_layout.get("hidden_views",[]).size():
			if i in clues:
				var v:Dictionary=spec.bay_layout.hidden_views[i];result.append({"id":v.id,"name":v.name,"x":v.point[0],"z":v.point[2],"kind":"clue","safe":v.point})
	return result

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var nearest:Dictionary={};var distance:float=28
		for place in places():
			var d:float=event.position.distance_to(point(place.x,place.z))
			if d<distance:distance=d;nearest=place
		if not nearest.is_empty():destination.emit(nearest)
