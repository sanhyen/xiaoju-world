extends RefCounted
## Maps, triggers, routes and fast travel resolve through the same authored locations.
static func places(spec:Dictionary,clues:Array=[])->Array:
	var cfg:Dictionary=spec.get("bay_layout",{});var result:Array=[]
	for zone in spec.zones:
		var item:Dictionary=zone.duplicate(true);item["kind"]="zone";item["safe"]=cfg.zones[zone.id].safe;result.append(item)
	for venue in spec.buildings:
		result.append({"id":venue.id,"name":venue.name,"x":venue.x,"z":venue.z,"kind":"venue","safe":[venue.x,venue.floor_y-float(cfg.sea_y),venue.z+venue.d*.5+1.6]})
	for id in cfg.get("annexes",{}):
		var a:Dictionary=cfg.annexes[id];result.append({"id":id+"_UPPER","name":str(cfg.get("venue_names",{}).get(id,"观景馆"))+" · 上层敞廊","kind":"upper","level":"2F▲","x":a.center[0],"z":a.center[2]+2.4,"safe":[a.center[0],a.upper_h_sea,a.center[2]+2.4]})
	for h in cfg.get("living_houses",[]):
		if h.loft:result.append({"id":h.id+"_UPPER","name":h.name+" [阁楼▲]","kind":"upper","level":"阁楼▲","x":h.center[0],"z":h.center[2]+h.size[1]*.5+1.3,"safe":[h.center[0],h.center[1]+3.4,h.center[2]+h.size[1]*.5+1.3]})
	for h in cfg.get("cliff_district",{}).get("buildings",[]):
		if h.role in ["pottery","loom","wheel"]:result.append({"id":h.id+"_UPPER","name":h.name+" [2F▲]","kind":"upper","level":"2F▲","x":h.center[0],"z":h.center[2]+2,"safe":[h.center[0],h.upper_y-float(cfg.sea_y),h.center[2]+2]})
	for place in cfg.get("extra_places",[]):result.append(place.duplicate(true))
	for i in cfg.get("boat_docks",[]).size():
		var dock:Dictionary=cfg.boat_docks[i];result.append({"id":"BOAT_DOCK_"+str(i),"name":dock.name,"x":dock.land[0],"z":dock.land[2],"kind":"boat","safe":dock.land})
	for i in cfg.get("hidden_views",[]).size():
		if i in clues:
			var view:Dictionary=cfg.hidden_views[i];result.append({"id":view.id,"name":view.name,"x":view.point[0],"z":view.point[2],"kind":"clue","safe":view.point})
	for reserved in cfg.get("future_islands",[]):
		if reserved.get("hidden",true):continue
		result.append({"id":reserved.id,"name":reserved.name,"x":reserved.map_hint[0],"z":reserved.map_hint[1],"kind":"reserved","enabled":false,"subtitle":reserved.theme_direction+" · 远期预留，尚未开放"})
	for p in cfg.get("creative_places",[]):
		var found:bool=false
		for item in result:
			if item.id==p.id:found=true;break
		if found:continue
		var door:Array=p.get("travel_point",p.door)
		result.append({"id":p.id,"name":p.name,"x":p.center[0],"z":p.center[2],"kind":"creative","safe":[door[0],float(door[1])-float(cfg.sea_y),door[2]],"level":str(p.floors.size())+"层"})
	return result

static func find(spec:Dictionary,id:String,clues:Array=[])->Dictionary:
	for place in places(spec,clues):
		if str(place.id)==id:return place
	return {}

static func destination(spec:Dictionary,place:Dictionary)->Vector3:
	var actual:Dictionary=find(spec,str(place.get("id","")))
	if actual.is_empty():actual=place
	if not actual.get("enabled",true) or not actual.has("safe"):return Vector3.INF
	var p:Array=actual.safe;return Vector3(p[0],float(p[1])+float(spec.bay_layout.sea_y),p[2])
