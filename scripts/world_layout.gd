extends RefCounted
## Authored bay geometry is shared by terrain, routes, map and recovery.
var config:Dictionary
var venues:Dictionary={}
var creative_places:Array=[]
var creative_index:Dictionary={}
var segments:Array=[]
var road_index:Dictionary={}
var river_segments:Array=[]
var river_index:Dictionary={}
var sea_walk_index:Dictionary={}
var wading_index:Dictionary={}
var spec:Dictionary={}
const GRID=32.0

func _init():
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_layout_bay_v1.json"))
	creative_places=config.get("creative_places",[])
	for place in creative_places:
		index_segment(creative_index,{"place":place,"a":Vector3(place.center[0],place.center[1],place.center[2]),"c":Vector3(place.center[0],place.center[1],place.center[2])},maxf(place.size[0],place.size[1])*.5+12)
	for road in config.roads:
		for i in road.points.size()-1:
			var a:Vector3=vector(road.points[i]);var c:Vector3=vector(road.points[i+1])
			var r:Dictionary={"a":a,"c":c,"width":float(road.width),"bridge":bool(road.get("bridge",false)),"id":str(road.id)}
			segments.append(r);index_segment(road_index,r,float(road.width)*0.5+12.0)
	for river in config.rivers:
		for i in river.points.size()-1:
			var r:Dictionary={"a":vector(river.points[i]),"c":vector(river.points[i+1]),"width":float(river.width),"id":str(river.id)}
			river_segments.append(r);index_segment(river_index,r,float(river.width)*0.5+13.0)

	for route in config.get("sea_walk",{}).get("routes",[]):
		for i in route.points.size()-1:
			index_segment(sea_walk_index,{"a":vector(route.points[i]),"c":vector(route.points[i+1])},float(config.sea_walk.width)*.5+1)
	for route in config.get("wading_paths",[]):
		for i in route.points.size()-1:
			index_segment(wading_index,{"a":vector(route.points[i]),"c":vector(route.points[i+1]),"width":float(route.width)},float(route.width)*.5+3)
	split_water_crossings()

func split_water_crossings():
	var revised:Array=[]
	for r in segments:
		var crossings:Array=[]
		for river in river_segments:
			if river.id!="navigation" or r.bridge:continue
			var hit=Geometry2D.segment_intersects_segment(Vector2(r.a.x,r.a.z),Vector2(r.c.x,r.c.z),Vector2(river.a.x,river.a.z),Vector2(river.c.x,river.c.z))
			if hit!=null:
				var length:float=Vector2(r.c.x-r.a.x,r.c.z-r.a.z).length()
				var t:float=Vector2(r.a.x,r.a.z).distance_to(hit)/maxf(length,0.1)
				crossings.append([maxf(0,t-9.0/length),minf(1,t+9.0/length)])
		if crossings.is_empty():revised.append(r);continue
		crossings.sort_custom(func(a,c):return a[0]<c[0])
		var previous:float=0
		for span in crossings:
			if span[0]>previous:
				var land:Dictionary=r.duplicate();land.a=r.a.lerp(r.c,previous);land.c=r.a.lerp(r.c,span[0]);revised.append(land)
			var bridge:Dictionary=r.duplicate();bridge.a=r.a.lerp(r.c,maxf(previous,span[0]));bridge.c=r.a.lerp(r.c,span[1]);bridge.bridge=true;bridge.id+="_navigable";revised.append(bridge);previous=span[1]
		if previous<1:
			var land:Dictionary=r.duplicate();land.a=r.a.lerp(r.c,previous);revised.append(land)
	segments=revised;road_index.clear()
	for r in segments:index_segment(road_index,r,float(r.width)*0.5+12.0)

func vector(point:Array)->Vector3:
	return Vector3(float(point[0]),float(point[1])+float(config.sea_y),float(point[2]))

func apply(source:Dictionary)->Dictionary:
	spec=source.duplicate(true)
	if config.has("cliff_district"):
		spec.zones.append({"id":"Z09","name":"崖湾嵌岩聚落","subtitle":"三级石街 · 水闸水轮 · 矿彩陶艺","x":285,"z":20})
	spec["bay_layout"]=config
	for item in spec.buildings:
		var placement:Dictionary=config.venues[item.id]
		for key in ["x","z","zone","subtitle"]:item[key]=placement[key]
		item["floor_y"]=float(placement.h_sea)+float(config.sea_y)
		venues[item.id]=item
	for zone in spec.zones:
		zone.x=config.zones[zone.id].x;zone.z=config.zones[zone.id].z
	spec["routes"]=[]
	for road in config.roads:
		var points:Array=[]
		for point in road.points:points.append([point[0],point[2]])
		spec.routes.append(points)
	# Door approaches are authored against the same route index and height field.
	for item in spec.buildings:
		var door:Vector3=Vector3(float(item.x),float(item.floor_y),float(item.z)+float(item.d)*0.5+1.5)
		var nearest:Vector3=nearest_route(door)
		if Vector2(door.x-nearest.x,door.z-nearest.z).length()>0.8:
			var r:Dictionary={"a":nearest,"c":door,"width":3.2,"bridge":false,"id":str(item.id)+"_approach"}
			segments.append(r);index_segment(road_index,r,14.0)
	return spec

func index_segment(index:Dictionary,r:Dictionary,pad:float):
	for x in range(floori((minf(r.a.x,r.c.x)-pad)/GRID),floori((maxf(r.a.x,r.c.x)+pad)/GRID)+1):
		for z in range(floori((minf(r.a.z,r.c.z)-pad)/GRID),floori((maxf(r.a.z,r.c.z)+pad)/GRID)+1):
			var key:=Vector2i(x,z)
			if not index.has(key):index[key]=[]
			index[key].append(r)

func near(index:Dictionary,p:Vector2)->Array:
	return index.get(Vector2i(floori(p.x/GRID),floori(p.y/GRID)),[])

func projection(p:Vector2,r:Dictionary)->Vector3:
	var a:=Vector2(r.a.x,r.a.z);var c:=Vector2(r.c.x,r.c.z)
	var t:float=clampf((p-a).dot(c-a)/maxf(a.distance_squared_to(c),0.0001),0.0,1.0)
	return r.a.lerp(r.c,t)

func nearest_route(p:Vector3)->Vector3:
	var result:=p;var distance:float=INF
	for r in segments:
		var q:Vector3=projection(Vector2(p.x,p.z),r)
		var d:float=Vector2(p.x-q.x,p.z-q.z).length_squared()
		if d<distance:distance=d;result=q
	return result

func shore_z(x:float)->float:
	var points:Array=config.shore
	for i in points.size()-1:
		if x>=float(points[i][0]) and x<=float(points[i+1][0]):
			var t:float=clampf((x-float(points[i][0]))/(float(points[i+1][0])-float(points[i][0])),0.0,1.0)
			t=t*t*(3.0-2.0*t)
			return lerpf(float(points[i][1]),float(points[i+1][1]),t)
	return float(points[0][1]) if x<float(points[0][0]) else float(points[-1][1])

func natural_height(p:Vector2)->float:
	var t:float=clampf((-p.y-150.0)/260.0,0.0,1.0)
	var h:float=72.0*t*t*(3.0-2.0*t)+sin(p.x*0.018)*sin(t*PI)*5.0
	h+=12.0*exp(-pow((p.x+245.0)/100.0,2)-pow((p.y+105.0)/120.0,2))
	h+=12.0*exp(-pow((p.x-205.0)/115.0,2)-pow((p.y+170.0)/145.0,2))
	h+=4.0*exp(-pow((p.x+245.0)/145.0,2)-pow((p.y+5.0)/165.0,2))
	h+=3.0*exp(-pow(p.x/160.0,2)-pow((p.y-80.0)/165.0,2))
	if config.has("cliff_district") and p.x>210 and p.x<355 and p.y> -55 and p.y<103:
		var edge:float=maxf(maxf(230-p.x,p.x-345),maxf(-40-p.y,p.y-88))
		var cliff:float=21.0 if p.x<266 else 14.5 if p.x<305 else 6.0
		cliff+=sin(p.y*.13)*.7+sin(p.x*.24)*.35
		h=lerpf(cliff,h,smoothstep(0,18,edge))
	if p.y>220.0:
		var beach:float=float(config.sea_y)+(shore_z(p.x)-p.y)*0.075
		h=lerpf(h,beach,smoothstep(220.0,275.0,p.y))
		h=maxf(h,-12.0)
	var lagoon:Dictionary=config.lagoon
	var q:=Vector2((p.x-float(lagoon.center[0]))/float(lagoon.radius[0]),(p.y-float(lagoon.center[1]))/float(lagoon.radius[1]))
	if q.length()<1.15:h=lerpf(float(config.sea_y)-2.0,h,smoothstep(0.82,1.15,q.length()))
	var flower:Dictionary=config.flower_hill
	var flower_edge:float=maxf(absf(p.x-flower.center[0])-flower.size[0]*0.5,absf(p.y-flower.center[1])-flower.size[1]*0.5)
	if flower_edge<8:
		var slope:float=clampf((-p.y-154.5)/45,0,1)
		var flower_y:float=float(config.sea_y)+6.0+slope*14.0+sin(p.x*.12)*.9*sin(slope*PI)
		h=lerpf(flower_y,h,smoothstep(0,8,flower_edge))
	h=creative_relief(p,h)
	var island:Dictionary=config.island
	var iq:=Vector2((p.x-island.center[0])/island.radius[0],(p.y-island.center[1])/island.radius[1])
	var radius:float=iq.length()*(1+.055*sin(iq.angle()*3)+.035*cos(iq.angle()*5))
	if radius<1.85:h=maxf(h,lerpf(float(config.sea_y)-1.85,-12,smoothstep(1.25,1.85,radius)))
	if radius<1.3:
		var island_y:float=float(config.sea_y)+1.1+3.4*pow(maxf(0,1-radius),1.4)+.5*sin(p.x*.18)*sin(p.y*.15)*maxf(0,1-radius)
		h=lerpf(island_y,h,smoothstep(.82,1.3,radius))
	for river in near(river_index,p):
		var point:Vector3=projection(p,river)
		var distance:float=p.distance_to(Vector2(point.x,point.z))
		var half:float=float(river.width)*0.5
		if distance<half+12.0:h=lerpf(point.y-1.65,h,smoothstep(half,half+12.0,distance))
	if radius>=1.05 and radius<1.8:
		var depth:float=lerpf(.38,1.35,smoothstep(1.05,1.55,radius))
		h=maxf(h,lerpf(float(config.sea_y)-depth,h,smoothstep(1.55,1.8,radius)))
	var coast_edge:float=maxf(absf(p.x)+9*sin(p.y*.018),-p.y+8*sin(p.x*.014))
	h=lerpf(h,-12.0,smoothstep(428.0,479.0,coast_edge))
	# A continuous shallow shelf, not just two isolated allowed test points.
	var offshore:float=p.y-shore_z(p.x)
	if p.y>275 and absf(p.x)<420 and offshore>0 and offshore<40:
		var shelf:float=float(config.sea_y)-minf(1.2,offshore*.045)
		h=maxf(h,lerpf(shelf,h,smoothstep(28,40,offshore)))
	if radius>.9 and radius<1.8:
		var shelf:float=float(config.sea_y)-lerpf(.20,1.15,smoothstep(.9,1.45,radius))
		h=maxf(h,lerpf(shelf,h,smoothstep(1.45,1.8,radius)))
	return island2_height(p,h)

func island2_height(p:Vector2,h:float)->float:
	var island:Dictionary=config.get("island2",{})
	if island.is_empty():return h
	var q:=Vector2((p.x-island.center[0])/island.radius[0],(p.y-island.center[1])/island.radius[1])
	var r:float=q.length()*(1+.035*sin(q.angle()*5)+.025*cos(q.angle()*3))
	var sea:float=config.sea_y
	if r<1.0:
		var core:float=sea+.1+7.4*pow(1-r,1.18)+.7*sin(p.x*.16)*sin(p.y*.13)*(1-r)
		return maxf(h,core)
	if r<1.55:
		var bed:float=sea-lerpf(.10,1.24,smoothstep(1,1.5,r))
		return maxf(h,bed)
	if r<1.95:return maxf(h,lerpf(sea-1.24,sea-9.6,smoothstep(1.55,1.95,r)))
	return h

func hotel_walk_point(angle:float)->Vector3:
	var h:Dictionary=config.island.hotel_walk
	return vector([h.center[0]+h.radius[0]*cos(angle),h.h_sea,h.center[1]+h.radius[1]*sin(angle)])

func hotel_branch_start(z:float)->Vector3:
	var h:Dictionary=config.island.hotel_walk
	return vector([h.center[0]+h.radius[0]*sqrt(maxf(0,1-pow((z-h.center[1])/h.radius[1],2))),h.h_sea,z])

func height_at(p:Vector2)->float:
	var h:float=natural_height(p)
	var best_distance:float=INF;var road_y:float=h;var weight:float=0.0
	for r in near(road_index,p):
		if r.bridge:continue
		var q:Vector3=projection(p,r)
		var edge:float=p.distance_to(Vector2(q.x,q.z))-float(r.width)*0.5
		if edge<best_distance:
			best_distance=edge;road_y=q.y;weight=1.0-smoothstep(1.5,11.0,edge)
	h=lerpf(h,road_y,weight)
	for room in config.get("theme_rooms",[]):
		var edge:float=maxf(absf(p.x-room.center[0])-room.size[0]*.5,absf(p.y-room.center[2])-room.size[1]*.5)
		if edge<4:h=lerpf(float(room.center[1])+float(config.sea_y)-.22,h,smoothstep(0,4,edge))
	for house in config.get("island2",{}).get("buildings",[]):
		if house.treehouse:continue
		var edge:float=maxf(absf(p.x-house.center[0])-house.size[0]*.5,absf(p.y-house.center[2])-house.size[1]*.5)
		if edge<3:h=lerpf(float(house.center[1])+float(config.sea_y)-.22,h,smoothstep(0,3,edge))
	for point in config.get("island2",{}).get("observation_points",[]):
		var edge:float=maxf(absf(p.x-point[0])-3,absf(p.y-point[2])-2)
		if edge<2:h=lerpf(float(point[1])+float(config.sea_y)-.22,h,smoothstep(0,2,edge))
	for pool in config.get("island2",{}).get("pools",[]):
		var edge:float=maxf(absf(p.x-pool.center[0])-pool.size[0]*.5,absf(p.y-pool.center[2])-pool.size[1]*.5)
		if edge<4:h=lerpf(float(pool.center[1])+float(config.sea_y)-.10,h,smoothstep(0,4,edge))
		if edge<0:h=float(pool.center[1])+float(config.sea_y)-float(pool.depth)-.16
	for terrace in config.terraces:
		var edge:float=maxf(absf(p.x-float(terrace.center[0]))-float(terrace.size[0])*0.5,absf(p.y-float(terrace.center[1]))-float(terrace.size[1])*0.5)
		var feather:float=2.0 if str(terrace.get("id","")).begins_with("villa_coral_bed_") else 12.0
		if edge<feather:h=lerpf(float(terrace.h_sea)+float(config.sea_y),h,smoothstep(0.0,feather,edge))
	for id in venues:
		var item:Dictionary=venues[id]
		var pad:float=3.5 if id=="B12" else 3.0
		var edge:float=maxf(absf(p.x-float(item.x))-float(item.w)*0.5-pad,absf(p.y-float(item.z))-float(item.d)*0.5-pad)
		if edge<9.0:h=lerpf(float(item.floor_y),h,smoothstep(0.0,9.0,edge))
	for annex in config.get("annexes",{}).values():
		var edge:float=maxf(absf(p.x-annex.center[0])-4.6,absf(p.y-annex.center[2])-4.6)
		if edge<8:h=lerpf(float(annex.center[1])+float(config.sea_y)-.22,h,smoothstep(0,8,edge))
	for annex in config.get("annexes",{}).values():
		if p.x>annex.center[0]+4.3 and p.x<annex.center[0]+10.8 and p.y>annex.center[2]-4 and p.y<annex.center[2]+10.5:
			h=minf(h,float(annex.center[1])+float(config.sea_y)-.22)
	var pool:Dictionary=config.get("play_pool",{})
	if not pool.is_empty() and absf(p.x-pool.center[0])<1.85 and p.y>pool.center[2]+3.0 and p.y<pool.center[2]+7.5:
		h=minf(h,float(pool.bed_h_sea)+float(config.sea_y)-.12)
	if not pool.is_empty() and absf(p.x-pool.center[0])<pool.size[0]*.5 and absf(p.y-pool.center[2])<pool.size[1]*.5:
		h=minf(h,float(pool.bed_h_sea)+float(config.sea_y)-.12)
	# Indoor ground remains below the thick slab instead of sharing its visible plane.
	for id in venues:
		var item:Dictionary=venues[id]
		if absf(p.x-item.x)<item.w*.5+.25 and absf(p.y-item.z)<item.d*.5+.25:h=minf(h,float(item.floor_y)-.22)
	for house in config.get("living_houses",[]):
		if absf(p.x-house.center[0])<house.size[0]*.5+.15 and absf(p.y-house.center[2])<house.size[1]*.5+.15:h=minf(h,float(house.center[1])+float(config.sea_y)-.22)
	for source in config.get("public_boats",[]):
		var water:Vector3=vector(source.water);var shore:Vector3=vector(source.shore)
		var radius:float=p.distance_to(Vector2(water.x,water.z))
		if radius<7:h=minf(h,lerpf(float(config.sea_y)-1.02,h,smoothstep(4,7,radius)))
		var d:float=p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(water.x,water.z),Vector2(shore.x,shore.z)))
		if d<2.2:h=lerpf(float(config.sea_y)-.95,h,smoothstep(1.4,2.2,d))
	# Navigation bed wins over adjacent road/terrace feathering; no hidden earth dams.
	# The small supported tea deck leaves its existing dock approach unchanged.
	if p.x> -196.4 and p.x< -191.6 and p.y> -189.7 and p.y< -185.3:h=minf(h,3.28)
	for river in near(river_index,p):
		if river.id!="navigation":continue
		var q:Vector3=projection(p,river)
		if p.distance_to(Vector2(q.x,q.z))<river.width*.5+.1:h=minf(h,q.y-1.65)
	for dock in config.get("boat_docks",[]):
		var water:Vector3=vector(dock.water)
		if p.distance_to(Vector2(water.x,water.z))<3.8:h=minf(h,water.y-1.65)
	for house in config.get("cliff_district",{}).get("buildings",[]):
		var center:Array=house.center;var size:Array=house.size
		var edge:float=maxf(absf(p.x-center[0])-size[0]*.5-.45,absf(p.y-center[2])-size[1]*.5-.45)
		if edge<2.8:h=lerpf(float(center[1])-.08,h,smoothstep(0,2.8,edge))
	for house in config.get("cliff_district",{}).get("buildings",[]):
		if not house.has("stairs"):continue
		for step in house.stairs:
			if absf(p.x-step[0])<2 and p.y>float(house.center[2])-float(house.size[1])*.5-5 and p.y<float(house.center[2])+float(house.size[1])*.5+5:h=minf(h,float(house.center[1])-.12)
	if p.x>241 and p.x<259 and p.y>27 and p.y<34:h=minf(h,17.9)
	# Carve the tunnel floor; a separate physical rock vault covers it above head height.
	if config.has("cliff_district") and p.x>275 and p.x<300 and absf(p.y+31)<3.0:h=minf(h,14.42)
	for span in near(wading_index,p):
		var q:Vector3=projection(p,span);var edge:float=p.distance_to(Vector2(q.x,q.z))-span.width*.5
		if edge<1.2:h=maxf(h,lerpf(q.y-.06,h,smoothstep(0,1.2,edge)))
	return creative_foundation(p,h)

func protected(p:Vector2)->bool:
	for record in near(creative_index,p):
		var place:Dictionary=record.place
		if absf(p.x-place.center[0])<place.size[0]*.5+3 and absf(p.y-place.center[2])<place.size[1]*.5+3:return true
	var forest:Dictionary=config.get("island2",{})
	if not forest.is_empty() and Vector2((p.x-forest.center[0])/forest.radius[0],(p.y-forest.center[1])/forest.radius[1]).length()<2.0:return true
	for room in config.get("theme_rooms",[]):
		if absf(p.x-room.center[0])<room.size[0]*.5+4 and absf(p.y-room.center[2])<room.size[1]*.5+4:return true
	for source in config.get("public_boats",[]):
		if p.distance_to(Vector2(source.water[0],source.water[2]))<8:return true
	if config.has("cliff_district") and p.x>219 and p.x<354 and p.y> -49 and p.y<105:return true
	for span in near(wading_index,p):
		var q:Vector3=projection(p,span)
		if p.distance_to(Vector2(q.x,q.z))<span.width*.5+1.3:return true
	var flower:Dictionary=config.flower_hill
	if absf(p.x-float(flower.center[0]))<float(flower.size[0])*.5+1 and absf(p.y-float(flower.center[1]))<float(flower.size[1])*.5+1:return true
	for annex in config.get("annexes",{}).values():
		if p.x>annex.center[0]-5 and p.x<annex.center[0]+11 and absf(p.y-annex.center[2])<11:return true
	for river in near(river_index,p):
		if river.id=="navigation":
			var q:Vector3=projection(p,river)
			if p.distance_to(Vector2(q.x,q.z))<river.width*.5+.5:return true
	for r in near(road_index,p):
		if r.bridge:continue
		var q:Vector3=projection(p,r)
		if p.distance_to(Vector2(q.x,q.z))<float(r.width)*0.5+3.0:return true
	for id in venues:
		var item:Dictionary=venues[id]
		if absf(p.x-float(item.x))<float(item.w)*0.5+5.0 and absf(p.y-float(item.z))<float(item.d)*0.5+5.0:return true
	for terrace in config.terraces:
		if absf(p.x-float(terrace.center[0]))<float(terrace.size[0])*0.5+1.5 and absf(p.y-float(terrace.center[1]))<float(terrace.size[1])*0.5+1.5:return true
	return false

func zone_id(p:Vector3)->String:
	if p.z>405:return "Z02"
	if config.has("cliff_district") and p.x>225 and p.x<352 and p.z> -47 and p.z<100:return "Z09"
	for id in ["Z06","Z07","Z05","Z04","Z03","Z01","Z08","Z02"]:
		var polygon:=PackedVector2Array()
		for q in config.zones[id].polygon:polygon.append(Vector2(float(q[0]),float(q[1])))
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon):return id
	return "Z08" if p.z< -150.0 else "Z02" if p.z>260.0 else "Z04"

func safe_point(id:String)->Vector3:
	return vector(config.zones.get(id,config.zones.Z04).safe)+Vector3(0,0.5,0)

func within_bounds(p:Vector3)->bool:
	var bounds:Array=config.bounds
	return p.x>=bounds[0] and p.x<=bounds[1] and p.z>=bounds[2] and p.z<=bounds[3] and p.y> -16.0 and p.y<180.0

func shallow_or_dry(p:Vector3)->bool:
	for span in near(sea_walk_index,Vector2(p.x,p.z)):
		var foot:Vector3=projection(Vector2(p.x,p.z),span)
		if Vector2(p.x-foot.x,p.z-foot.z).length()<float(config.sea_walk.width)*.5+.2 and p.y>=foot.y-.5:return true
	for deck in config.get("decks",[]):
		var r:Dictionary={"a":vector(deck[0]),"c":vector(deck[1])};var q:Vector3=projection(Vector2(p.x,p.z),r)
		if Vector2(p.x-q.x,p.z-q.z).length()<float(deck[2])*.5+.15 and p.y>=q.y-.25:return true
	for area in config.get("deck_areas",[]):
		if p.x>=area[0] and p.x<=area[2] and p.z>=area[1] and p.z<=area[3] and p.y>=float(area[4])+float(config.sea_y)-.25:return true
	if not within_bounds(p):return false
	var ground:float=height_at(Vector2(p.x,p.z));var depth:float=float(config.sea_y)-ground
	if depth<=float(config.get("shallow_policy",{}).get("max_wade_depth_m",1.35))+.025 and p.y>=ground-.45:return true
	for r in near(road_index,Vector2(p.x,p.z)):
		var q:Vector3=projection(Vector2(p.x,p.z),r)
		if r.bridge and Vector2(p.x-q.x,p.z-q.z).length()<float(r.width)*0.5+0.2 and p.y>=q.y-0.5:return true
	return false

func creative_relief(p:Vector2,h:float)->float:
	if p.x<90 or p.x>445 or p.y< -75 or p.y>350:return h
	# A real eastern limestone shoulder, terraced and broadly blended into the old town.
	var r:float=Vector2((p.x-191)/81.0,(p.y+24)/76.0).length()
	if r<1:
		var terrace:float=29.2 if r<.30 else 23.2 if r<.53 else 16.2 if r<.77 else 9.2
		h=lerpf(h,maxf(h,terrace),1.0-smoothstep(.84,1.0,r))
	return h

func creative_foundation(p:Vector2,h:float)->float:
	for court in [[68.0,14.0,4.2],[44.0,18.0,5.8],[28.0,12.0,7.4]]:
		var edge:float=maxf(absf(p.x+112.5)-36.0,absf(p.y-court[0])-court[1]*.5)
		if edge<2:h=lerpf(float(court[2])-.3,h,smoothstep(0,2,edge))
	for record in near(creative_index,p):
		var place:Dictionary=record.place
		if not str(place.id).begins_with("AZURE_") and not str(place.id).begins_with("CASTLE_") and not str(place.id).begins_with("CABLE_"):continue
		var edge:float=maxf(absf(p.x-place.center[0])-place.size[0]*.5,absf(p.y-place.center[2])-place.size[1]*.5)
		if edge<7:h=lerpf(float(place.center[1])-.30,h,smoothstep(0,7,edge))
	# Engineered approaches win over terrace feathering, never over navigable beds.
	for r in near(road_index,p):
		if r.bridge or not str(r.id).begins_with("creative110_"):continue
		var q:Vector3=projection(p,r)
		var distance:float=p.distance_to(Vector2(q.x,q.z))-r.width*.5
		if distance<2.5:h=lerpf(q.y-.02,h,smoothstep(.1,2.5,distance))
	for record in near(creative_index,p):
		var place:Dictionary=record.place
		var edge:float=maxf(absf(p.x-place.center[0])-place.size[0]*.5,absf(p.y-place.center[2])-place.size[1]*.5)
		if edge<.18 and str(place.role) not in ["villa","treehouse"]:h=minf(h,float(place.center[1])-.30)
	for river in near(river_index,p):
		if river.id!="navigation":continue
		var q:Vector3=projection(p,river)
		if p.distance_to(Vector2(q.x,q.z))<river.width*.5+.15:h=minf(h,q.y-1.65)
	return h

func creative_at(p:Vector3)->Dictionary:
	for record in near(creative_index,Vector2(p.x,p.z)):
		var place:Dictionary=record.place
		if absf(p.x-place.center[0])<=place.size[0]*.5 and absf(p.z-place.center[2])<=place.size[1]*.5 and p.y>=float(place.center[1])-.5 and p.y<=float(place.floors[-1])+5:return place
	return {}
