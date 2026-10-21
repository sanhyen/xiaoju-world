extends RefCounted
## A walking guide uses authored surfaces only. XZ crossings at separate levels stay separate.
const CROSSING_HEIGHT=.7
const GRID=64.0
static var shared_graphs:Dictionary={}
var layout
var world
var graph:AStar3D
var pieces:Array=[]
var raw:Array=[]
var buckets:Dictionary={}
var nodes:Dictionary={}
var unique_segments:Dictionary={}
var joins:Array=[]
var signature:=""
var cached_target:=""
var cached_position:=Vector3.INF
var cached_result:Dictionary={}
var stats:Dictionary={}
var source_imports:Dictionary={}
var terrain_sampler

func xyz(value:Variant,relative:bool=false)->Vector3:
	if value is Vector3:return value
	if value is Array and value.size()>=3:return Vector3(float(value[0]),float(value[1])+(float(layout.config.sea_y) if relative else 0.0),float(value[2]))
	return Vector3.INF

func ensure_layout(source,world_node=null):
	if source==null:return
	var routes:Array=world_node.get_meta("upper_routes110",[]) if world_node!=null else []
	var entries:Array=world_node.get_meta("entrances110",[]) if world_node!=null else []
	var next_signature:String=str(source.get_instance_id())+":"+str(source.segments.size())+":"+str(source.creative_places.size())+":"+str(routes.size())+":"+str(entries.size())
	if signature==next_signature:return
	layout=source;world=world_node;signature=next_signature;cached_target="";cached_result={};terrain_sampler=world.get("terrain_art") if world!=null else null
	if shared_graphs.has(signature):
		var saved:Dictionary=shared_graphs[signature];graph=saved.graph;pieces=saved.pieces;stats=saved.stats;return
	var begun:int=Time.get_ticks_usec();raw=[];pieces=[];buckets={};nodes={};unique_segments={};joins=[];source_imports={}
	for road in layout.segments:
		# These three old flower-lane declarations differ from their terrain-draped
		# meshes at the junction. Import the real paving below, not both heights.
		if terrain_sampler!=null and not road.bridge and str(road.id) in ["flower_path","flower_house_access","flower_dock_access"]:continue
		add_segment(road.a,road.c,float(road.width),str(road.id))
	for route in layout.config.get("sea_walk",{}).get("routes",[]):add_path(route.points,true,float(layout.config.sea_walk.width),str(route.id))
	for route in layout.config.get("island2",{}).get("canopy_routes",[]):add_path(route.points,true,float(route.get("width",2.4)),str(route.id))
	for deck in layout.config.get("decks",[]):
		if deck is Array and deck.size()>=3:add_segment(xyz(deck[0],true),xyz(deck[1],true),float(deck[2]),"authored_deck")
	for place in layout.creative_places:add_path(place.get("entry_path",[]),false,2.4,str(place.id)+"_entry")
	for entry in entries:add_path(entry.get("points",[]),false,float(entry.get("width",2.4)),str(entry.get("id","entry")))
	for route in routes:add_path(route.get("points",[]),false,float(route.get("width",2.4)),str(route.get("id","upper")))
	add_stair_front_aisles(routes)
	add_existing_local_surfaces()
	# The authored octagonal hub has a real four-metre circumradius. Its inscribed
	# disk joins nearby road centrelines without drawing a connector outside the deck.
	var before_hubs:Array=raw.duplicate()
	for value in layout.config.get("sea_walk",{}).get("hubs",[]):
		var hub:Vector3=xyz(value,true)
		for segment in before_hubs:
			var t:float=parameter(Vector2(hub.x,hub.z),segment.a,segment.c);var q:Vector3=segment.a.lerp(segment.c,t)
			if Vector2(q.x-hub.x,q.z-hub.z).length()<3.69 and absf(q.y-hub.y)<CROSSING_HEIGHT-.00001:add_segment(hub,q,1.2,"octagonal_hub")
	stats={"authored_segments":raw.size(),"height_separated_crossings":0,"recalculations":0,"source_imports":source_imports}
	var considered:Dictionary={}
	for index in raw.size():
		var segment:Dictionary=raw[index];var pad:float=float(segment.width)*.5
		for x in range(floori((minf(segment.a.x,segment.c.x)-pad)/GRID),floori((maxf(segment.a.x,segment.c.x)+pad)/GRID)+1):
			for z in range(floori((minf(segment.a.z,segment.c.z)-pad)/GRID),floori((maxf(segment.a.z,segment.c.z)+pad)/GRID)+1):
				var key:=Vector2i(x,z)
				for other in buckets.get(key,[]):
					var pair:=Vector2i(int(other),index)
					if considered.has(pair):continue
					considered[pair]=true;intersections(int(other),index)
				if not buckets.has(key):buckets[key]=[]
				buckets[key].append(index)
	graph=AStar3D.new();graph.reserve_space(raw.size()*3)
	for segment in raw:
		segment.cuts.sort();var previous:float=-1.0
		for value in segment.cuts:
			var t:float=float(value)
			if previous>=0 and t-previous>.000001:add_piece(segment.a.lerp(segment.c,previous),segment.a.lerp(segment.c,t),float(segment.width),str(segment.id))
			previous=t
	for join in joins:add_piece(join.a,join.c,float(join.width),"supported_junction")
	stats.points=graph.get_point_count();stats.pieces=pieces.size();stats.build_ms=float(Time.get_ticks_usec()-begun)/1000.0
	shared_graphs[signature]={"graph":graph,"pieces":pieces,"stats":stats}
	# One live world supplies both main map and minimap; do not retain discarded worlds forever.
	if shared_graphs.size()>3:
		for key in shared_graphs.keys():
			if key!=signature:shared_graphs.erase(key);break

func add_path(points:Variant,relative:bool,width:float,id:String):
	if not points is Array:return
	for i in points.size()-1:add_segment(xyz(points[i],relative),xyz(points[i+1],relative),width,id)

func add_stair_front_aisles(routes:Array):
	# These rooms use creative_world110's full floor and its tested front aisle:
	# door -> front landing -> flight foot; the stairwell opening ends behind it.
	# Other architectural families do not inherit this shape or an invented connector.
	for place in layout.creative_places:
		var owner:String=str(place.id)
		if not owner.begins_with("CASTLE_") and owner not in ["AZURE_VIEW","AZURE_WEAVE"]:continue
		var flights:Array=routes.filter(func(route):return str(route.get("owner",""))==owner and "_STAIR_" in str(route.get("id","")) and route.get("points",[]).size()>=2)
		for flight in flights:
			var foot:Vector3=xyz(flight.points[0]);var top:Vector3=xyz(flight.points[-1]);var front:=Vector3(top.x,foot.y,foot.z)
			add_segment(front,foot,1.8,owner+"_floor_front_aisle")
			var entrance:Array=place.get("entry_path",[])
			if not entrance.is_empty():
				var inside:Vector3=xyz(entrance[-1])
				if absf(inside.y-front.y)<.2:add_segment(inside,front,1.8,owner+"_ground_aisle")
			for previous in flights:
				var last:Vector3=xyz(previous.points[-1])
				if absf(last.y-front.y)<.2:add_segment(last,front,1.8,owner+"_landing_aisle")

func coral_ground(p:Vector2)->float:
	# Coral-island cells are smooth 2m terrain tiles. This is terrain_voxel.height_at's
	# exact top-triangle interpolation, also used by its real collision mesh.
	var cell:=Vector2(floorf(p.x/2.0),floorf(p.y/2.0));var base:Vector2=cell*2.0
	var u:float=p.x/2.0-cell.x;var v:float=p.y/2.0-cell.y
	var h0:float=layout.height_at(base);var h1:float=layout.height_at(base+Vector2(2,0));var h2:float=layout.height_at(base+Vector2(2,2));var h3:float=layout.height_at(base+Vector2(0,2))
	return h0*(1-u)+h1*(u-v)+h2*v if v<=u else h0*(1-v)+h2*u+h3*(v-u)

func source_height(point:Vector2,native:bool)->float:
	if native and terrain_sampler!=null:return float(terrain_sampler.height_at(point.x,point.y))
	return coral_ground(point)

func source_paving(a:Vector2,c:Vector2,width:float,id:String,native:bool=false):
	# bay_expansion.island calls world.path_between here; sample its actual mesh
	# triangles, including the same cross-slope heights and 0.035m paving offset.
	var step:float=1.0 if a.distance_to(Vector2(-237,-169))<65 or c.distance_to(Vector2(-237,-169))<65 else 4.0
	var count:int=maxi(1,ceili(a.distance_to(c)/step));var side:Vector2=Vector2(-(c-a).y,(c-a).x).normalized()*width*.5
	for i in count:
		var p:Vector2=a.lerp(c,float(i)/count);var q:Vector2=a.lerp(c,float(i+1)/count)
		var h:Array=[source_height(p+side,native)+.035,source_height(p-side,native)+.035,source_height(q-side,native)+.035,source_height(q+side,native)+.035]
		var previous:=Vector3(p.x,(float(h[0])+float(h[1]))*.5,p.y)
		var steps:int=maxi(2,ceili(p.distance_to(q)/.7))
		for j in range(1,steps+1):
			var t:float=float(j)/steps;var flat:Vector2=p.lerp(q,t)
			var y:float=float(h[0])*.5+float(h[1])*(.5-t)+float(h[2])*t if t<=.5 else float(h[0])*(1-t)+float(h[2])*.5+float(h[3])*(t-.5)
			var next:=Vector3(flat.x,y,flat.y);add_segment(previous,next,width,id);previous=next

func add_existing_local_surfaces():
	# Recover the older, still-built tea ramp rather than trusting its newer road label.
	for place in layout.creative_places:
		if str(place.id)!="CREEK_TEA":continue
		var entry:Array=place.get("entry_path",[])
		if entry.is_empty():continue
		var ramp_end:=Vector3(-194,3.3,-189.55)
		add_segment(Vector3(-191,2.1,-191),ramp_end,2.4,"audit_creek_existing_ramp")
		# Both ends lie on the existing 4.8x4.4m tea platform, in front of its table.
		add_segment(ramp_end,xyz(entry[-1]),1.2,"audit_creek_existing_platform")
		source_imports.creek="bay_audit_finishings.creek_tea old ramp and occupied platform"
	if terrain_sampler!=null:
		for road in layout.segments:
			if str(road.id) not in ["flower_path","flower_house_access","flower_dock_access"] or road.bridge:continue
			source_paving(Vector2(road.a.x,road.a.z),Vector2(road.c.x,road.c.z),float(road.width),"actual_paving_"+str(road.id),true)
		source_imports.flower_paving="native terrain_voxel collision triangles + exact world.path_between subdivision and offset"
	if layout.config.get("island",{}).get("hotel_walk",{}).is_empty():return
	source_paving(Vector2(256,427),Vector2(222,434),2.8,"existing_coral_north_paving")
	source_paving(Vector2(222,434),Vector2(187,450),2.8,"existing_coral_west_paving")
	for dock in layout.config.get("boat_docks",[]):
		if float(dock.land[2])<400:continue
		var land:Vector3=xyz(dock.land,true);var pier:Vector3=xyz(dock.pier,true);var axis:=Vector3(dock.axis[0],0,dock.axis[1])
		if dock.get("bridge_access") is Array:add_segment(xyz(dock.bridge_access,true),land,3.2,"coral_existing_dock_access")
		add_segment(land,pier,3.2,"coral_existing_dock");add_segment(pier-axis*5,pier+axis*5,3.2,"coral_existing_t_dock")
	source_imports.coral_paving="bay_expansion.island two existing terrain-conforming paths and dock decks"
	# The root agent now authors a real 2.8m path here. It is imported only through
	# layout.segments above; no surveyed-but-unbuilt grass connector is created.
	for road in layout.segments:
		if str(road.id)=="creative110_coral_landlink":source_imports.coral_landlink="actual 2.8m creative110_coral_landlink road from shared layout"

func add_segment(a:Vector3,c:Vector3,width:float,id:String):
	if not a.is_finite() or not c.is_finite() or a.distance_to(c)<.02:return
	var ka:String=str(a.snapped(Vector3.ONE*.002));var kc:String=str(c.snapped(Vector3.ONE*.002));var key:String=ka+":"+kc if ka<kc else kc+":"+ka
	if unique_segments.has(key):raw[int(unique_segments[key])].width=maxf(width,float(raw[int(unique_segments[key])].width));return
	unique_segments[key]=raw.size();raw.append({"a":a,"c":c,"width":maxf(.8,width),"id":id,"cuts":[0.0,1.0]})

func parameter(p:Vector2,a:Vector3,c:Vector3)->float:
	var delta:=Vector2(c.x-a.x,c.z-a.z)
	return clampf((p-Vector2(a.x,a.z)).dot(delta)/maxf(.000001,delta.length_squared()),0,1)

func intersections(first:int,second:int):
	var a:Dictionary=raw[first];var b:Dictionary=raw[second]
	var hit=Geometry2D.segment_intersects_segment(Vector2(a.a.x,a.a.z),Vector2(a.c.x,a.c.z),Vector2(b.a.x,b.a.z),Vector2(b.c.x,b.c.z))
	if hit!=null:
		var ta:float=parameter(hit,a.a,a.c);var tb:float=parameter(hit,b.a,b.c)
		if absf(lerpf(a.a.y,a.c.y,ta)-lerpf(b.a.y,b.c.y,tb))<CROSSING_HEIGHT-.00001:a.cuts.append(ta);b.cuts.append(tb)
		else:stats.height_separated_crossings=int(stats.height_separated_crossings)+1
		return
	# Parallel overlaps and T-junctions can meet within the actual paved strip.
	# These short connectors stay inside that strip; no free-space link is invented.
	for t in [0.0,1.0]:endpoint_join(a,b,t);endpoint_join(b,a,t)

func endpoint_join(a:Dictionary,b:Dictionary,t:float):
	var p:Vector3=a.a.lerp(a.c,t);var u:float=parameter(Vector2(p.x,p.z),b.a,b.c);var q:Vector3=b.a.lerp(b.c,u)
	if Vector2(p.x-q.x,p.z-q.z).length()>maxf(.08,float(b.width)*.5-.1) or absf(p.y-q.y)>=CROSSING_HEIGHT-.00001:return
	a.cuts.append(t);b.cuts.append(u)
	if p.distance_to(q)>.03:joins.append({"a":p,"c":q,"width":minf(float(a.width),float(b.width))})

func node_for(p:Vector3)->int:
	var cell:=Vector2i(roundi(p.x*10),roundi(p.z*10))
	for x in range(cell.x-1,cell.x+2):
		for z in range(cell.y-1,cell.y+2):
			for id in nodes.get(Vector2i(x,z),[]):
				var previous:Vector3=graph.get_point_position(int(id))
				if Vector2(previous.x-p.x,previous.z-p.z).length()<.08 and absf(previous.y-p.y)<CROSSING_HEIGHT-.00001:return int(id)
	var id:int=graph.get_available_point_id();graph.add_point(id,p)
	if not nodes.has(cell):nodes[cell]=[]
	nodes[cell].append(id);return id

func add_piece(a:Vector3,c:Vector3,width:float,id:String):
	var first:int=node_for(a);var second:int=node_for(c)
	if first==second:return
	graph.connect_points(first,second,true);pieces.append({"a":a,"c":c,"first":first,"second":second,"width":width,"id":id})

func goal_position(target:Dictionary)->Vector3:
	if layout==null:return Vector3.INF
	if str(target.get("id","")) in ["ISLAND","ISLAND_01"]:
		for route in layout.config.get("sea_walk",{}).get("routes",[]):
			if str(route.id)=="island_landing" and not route.points.is_empty():return xyz(route.points[-1],true)
	if target.get("kind","")=="upper" and world!=null and target.get("safe") is Array:
		var desired:Vector3=xyz(target.safe,true);var parent:String=str(target.get("parent",""));var best:=Vector3.INF;var distance:float=INF
		for route in world.get_meta("upper_routes110",[]):
			if str(route.get("owner",""))!=parent:continue
			var path:Array=route.get("points",[])
			for i in path.size()-1:
				var a:Vector3=xyz(path[i]);var c:Vector3=xyz(path[i+1])
				if absf(a.y-c.y)>.1:continue
				var q:Vector3=a.lerp(c,parameter(Vector2(desired.x,desired.z),a,c))
				if absf(q.y-desired.y)>.7:continue
				var flat:float=Vector2(q.x-desired.x,q.z-desired.z).length_squared()
				if flat<distance:best=q;distance=flat
		# Work-table entries can lie away from the stair. End on its real landing,
		# rather than inventing a line through furniture across the room.
		if best.is_finite():return best
	if target.get("kind","")!="upper":
		for place in layout.creative_places:
			if str(place.id)!=str(target.get("id","")):continue
			var path:Array=place.get("entry_path",[])
			if not path.is_empty():return xyz(path[-1])
			if place.get("door") is Array:return xyz(place.door)
	if target.get("safe") is Array:return xyz(target.safe,true)
	var zone:Dictionary=layout.config.get("zones",{}).get(str(target.get("id","")),{})
	if zone.get("safe") is Array:return xyz(zone.safe,true)
	return Vector3.INF

func anchor(point:Vector3)->Dictionary:
	var best:Dictionary={};var distance:float=INF
	for i in pieces.size():
		var piece:Dictionary=pieces[i];var t:float=parameter(Vector2(point.x,point.z),piece.a,piece.c);var q:Vector3=piece.a.lerp(piece.c,t)
		var flat:float=Vector2(point.x-q.x,point.z-q.z).length();var height:float=absf(point.y-q.y)
		if flat>float(piece.width)*.5+.8 or height>1.15:continue
		var score:float=flat*flat+height*height*4.0
		if score<distance:distance=score;best={"point":q,"piece":i}
	return best

func route_from(player:Vector3,target:Dictionary)->Dictionary:
	var next_target:String=JSON.stringify([target.get("id",""),target.get("parent",""),target.get("safe",[]),target.get("kind","")])
	if next_target==cached_target and not cached_result.is_empty() and Vector2(player.x-cached_position.x,player.z-cached_position.z).length()<12.0 and absf(player.y-cached_position.y)<.7:return cached_result
	cached_target=next_target;cached_position=player;var goal:Vector3=goal_position(target)
	cached_result={"connected":false,"points":PackedVector3Array(),"goal":goal,"reason":"outside_authored_routes"}
	if graph==null or not goal.is_finite():return cached_result
	stats.recalculations=int(stats.get("recalculations",0))+1
	var start:Dictionary=anchor(player);var finish:Dictionary=anchor(goal)
	if start.is_empty() or finish.is_empty():return cached_result
	var start_id:int=graph.get_available_point_id();graph.add_point(start_id,start.point)
	var end_id:int=graph.get_available_point_id();graph.add_point(end_id,finish.point)
	for endpoint in [pieces[int(start.piece)].first,pieces[int(start.piece)].second]:graph.connect_points(start_id,int(endpoint),true)
	for endpoint in [pieces[int(finish.piece)].first,pieces[int(finish.piece)].second]:graph.connect_points(end_id,int(endpoint),true)
	if int(start.piece)==int(finish.piece):graph.connect_points(start_id,end_id,true)
	var path:PackedVector3Array=graph.get_point_path(start_id,end_id)
	graph.remove_point(start_id);graph.remove_point(end_id)
	if path.is_empty():cached_result.reason="disconnected_authored_routes";return cached_result
	var length:=0.0
	for i in path.size()-1:length+=path[i].distance_to(path[i+1])
	cached_result={"connected":true,"points":path,"goal":goal,"reason":"authored_routes","length":length};return cached_result
