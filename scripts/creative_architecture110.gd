extends RefCounted
## Authored building families, flush portals and shared local frames for 0.11.
var w
var b
const WOOD="71583f"
const STONE="c8b999"
const PLASTER="eee6d5"

func _init(world):
	w=world;b=w.b

static func room_yaw(room:Dictionary)->float:
	return float(room.get("door_yaw",{"THEME_WAITING":PI,"THEME_POEM":PI*.5,"THEME_BLOSSOM":PI}.get(str(room.id),0.0)))

static func room_local_size(room:Dictionary)->Vector2:
	var result:=Vector2(float(room.size[0]),float(room.size[1]))
	if absf(sin(room_yaw(room)))>.7:return Vector2(result.y,result.x)
	return result

static func room_point(room:Dictionary,local:Vector3,sea_y:float=-2.4)->Vector3:
	return Vector3(float(room.center[0]),float(room.center[1])+sea_y,float(room.center[2]))+Basis(Vector3.UP,room_yaw(room))*local

static func room_work_offset(room:Dictionary)->Vector3:
	var size:Vector2=room_local_size(room)
	match str(room.id):
		"THEME_EVERYDAY":return Vector3(0,0,-1.0)
		"THEME_WAITING":return Vector3(-size.x*.28,0,.5)
		"THEME_POEM":return Vector3(-size.x*.22,0,-size.y*.15)
		"THEME_DAILY":return Vector3(-size.x*.28,0,-size.y*.20)
	return Vector3(-size.x*.34,0,-size.y*.1)

static func room_work(room:Dictionary,sea_y:float=-2.4)->Vector3:
	return room_point(room,room_work_offset(room),sea_y)

func capture()->Dictionary:
	var sizes:Dictionary={}
	for key in b.batches:sizes[key]=b.batches[key].size()
	return {"batches":sizes,"children":w.get_child_count(),"actions":w.interactions.size(),"paths":w.path_corridors.size(),"rails":w.get_meta("guardrails106",[]).size(),"upper_routes":w.get_meta("upper_routes110",[]).size()}

func rotate_capture(mark:Dictionary,p:Vector3,yaw:float):
	if absf(yaw)<.001:return
	var basis:=Basis(Vector3.UP,yaw);var pending:Array=[]
	for key in b.batches.keys():
		var rows:Array=b.batches[key];var begin:int=int(mark.batches.get(key,0))
		for index in range(begin,rows.size()):pending.append([str(key),rows[index]])
		rows.resize(begin)
	for item in pending:
		var key:String=item[0];var row:Array=item[1];var t:Transform3D=row[0]
		t=Transform3D(basis*t.basis,p+basis*(t.origin-p));row[0]=t
		var split:int=key.find("_",key.find("_")+1);var suffix:String=key.substr(split+1)
		var next_key:String="%d_%d_"%[floori(t.origin.x/96),floori(t.origin.z/96)]+suffix
		if not b.batches.has(next_key):b.batches[next_key]=[]
		b.batches[next_key].append(row)
	for index in range(int(mark.children),w.get_child_count()):
		var node:Node=w.get_child(index)
		if node is Node3D:node.transform=Transform3D(basis*node.transform.basis,p+basis*(node.position-p))
	for index in range(int(mark.actions),w.interactions.size()):
		var action:Dictionary=w.interactions[index];action.pos=p+basis*(action.pos-p)
		for field in ["seat","anchor","exit","target"]:
			if action.data.get(field) is Vector3:action.data[field]=p+basis*(action.data[field]-p)
		if action.data.has("yaw"):action.data.yaw=float(action.data.yaw)+yaw
	for index in range(int(mark.paths),w.path_corridors.size()):
		var path:Dictionary=w.path_corridors[index]
		for key in ["a","c"]:
			var q:=Vector3(path[key].x,p.y,path[key].y);q=p+basis*(q-p);path[key]=Vector2(q.x,q.z)
	var groups:Array=w.get_meta("guardrails106",[])
	for index in range(int(mark.rails),groups.size()):
		for record in groups[index].rails:
			record.a=p+basis*(record.a-p);record.c=p+basis*(record.c-p)
	var routes:Array=w.get_meta("upper_routes110",[])
	for index in range(int(mark.get("upper_routes",0)),routes.size()):
		var route:Dictionary=routes[index]
		for i in route.points.size():route.points[i]=p+basis*(route.points[i]-p)
		for floor in route.floors:
			floor.center=p+basis*(floor.center-p)
			if absf(sin(yaw))>.7:floor.size=Vector2(floor.size.y,floor.size.x)

func record(id:String,family:String,p:Vector3,size:Vector2,entry:Vector3,levels:Array):
	var records:Array=w.get_meta("architecture110",[])
	var floors:Array=[]
	for level in levels:floors.append({"y":p.y+float(level),"relative_y":float(level)})
	var entrances:Array=[]
	for portal in w.get_meta("entrances110",[]):
		if portal.id==id:entrances.push_front(portal)
		elif str(portal.id).begins_with(id+"_SIDE"):entrances.append(portal)
	var upper:Array=[]
	for route in w.get_meta("upper_routes110",[]):
		if route.owner==id:upper.append(route)
	var floor_entries:Array=[]
	for level in levels:
		var target_y:float=p.y+float(level)
		if absf(float(level))<.01:
			floor_entries.append({"name":"地面层","point":entrances[0].inside if not entrances.is_empty() else entry,"y":target_y,"route":entrances[0].points if not entrances.is_empty() else [entry],"route_id":id+"_ENTRY"})
		else:
			var found:bool=false
			for route in upper:
				var traversed:Array=[]
				for point in route.points:
					traversed.append(point)
					if absf(point.y-target_y)<.06:
						floor_entries.append({"name":"上层 %.2fm"%float(level),"point":point,"y":target_y,"route":traversed.duplicate(),"route_id":route.id});found=true;break
				if found:break
	records.append({"id":id,"family":family,"center":p,"size":size,"entry":entry,"levels":levels,"floors":floors,"floor_entries":floor_entries,"entrances":entrances,"external_route":entrances[0].points if not entrances.is_empty() else [],"upper_routes":upper,"floor_top":p.y,"door_width":3.2,"threshold_m":0.0})
	w.set_meta("architecture110",records)

func flush_entry(p:Vector3,width:float,depth:float,yaw:float=0.0,tag:String="",reach:float=3.8):
	var turn:=Basis(Vector3.UP,yaw);var front:Vector3=turn*Vector3.BACK
	var inside:Vector3=p+front*(depth*.5-.35);var landing:Vector3=p+front*(depth*.5+1.25)
	b.oriented_box((inside+landing)*.5-Vector3.UP*.12,Vector3(width,.24,inside.distance_to(landing)+.04),STONE,turn,true,"stone")
	var outer:Vector3=p+front*(depth*.5+reach)
	outer.y=w.height_at(outer.x,outer.z)+.015
	if tag in ["H05","H06","H08","H10","H13","BAKERY_REAR","LISTENING_WEST","THEME_EVERYDAY","FOREST_LODGE"]:outer.y=p.y
	# The visual and physical ramp share the declared top, without a raised sill.
	if absf(outer.y-p.y)<.05:outer.y=p.y
	b.ramp(landing,outer,width,STONE)
	if not tag.is_empty():
		var access:Dictionary=entry_access(tag,p,outer,width)
		var points:Array=access.points;points.append(landing);points.append(inside)
		var entries:Array=w.get_meta("entrances110",[]);entries.append({"id":tag,"public_route":points[0],"public_road_id":access.road_id,"source_roads":access.sources,"anchor":points[0],"approach":outer,"door":p+front*depth*.5,"inside":inside,"landing":landing,"outer":outer,"width":width,"points":points});w.set_meta("entrances110",entries)

func public_anchor(p:Vector3)->Dictionary:
	var result:Dictionary={"point":p,"id":"","distance":INF}
	var names:Array=["coast_east","coast_west","mouth_bridge","plaza_arrival","music","music_garden","arts","east_mountain","west_mountain","forest_cross","western_cape","eastern_cape","flower_path","valley_arch","garden_bridge","garden_bridge_east","hamlet_loop","farm_pool","shore_walk_west","shore_walk_east","z09_south","z09_west","z09_north","z09_middle","z09_low_to_middle","z09_high_loop","z09_mid_loop","forest106_loop","forest106_onsen"]
	for road in w.layout.segments:
		if str(road.id) not in names:continue
		var q:Vector3=w.layout.projection(Vector2(p.x,p.z),road)
		var score:float=Vector2(p.x-q.x,p.z-q.z).length_squared()+pow((p.y-q.y)*2,2)
		if score<float(result.distance):result={"point":q,"id":str(road.id),"distance":score}
	return result

func source_path(id:String)->Dictionary:
	var road_id:String=""
	if id.begins_with("H") and id.length()==3:road_id="house_"+id
	elif id.ends_with("_UPPER"):road_id=id.trim_suffix("_UPPER")+"_annex_approach"
	elif id.begins_with("THEME_"):
		road_id={"THEME_EVERYDAY":"theme106_EVERYDAY","THEME_WAITING":"creative110_theme_waiting","THEME_POEM":"creative110_theme_poem","THEME_FROST":"theme106_FROST","THEME_BLOSSOM":"creative110_theme_blossom","THEME_DAILY":"creative110_theme_daily"}.get(id,"")
	elif id.begins_with("Z09_"):
		road_id={"Z09_B1":"z09_wheel_door","Z09_B2":"z09_pottery_door","Z09_B3":"z09_tea_door","Z09_B4":"z09_loom_door","Z09_B5":"z09_high_door","Z09_B6":"z09_lookout_door"}.get(id,"")
	elif id in ["FOREST_LODGE","FOREST_OBSERVATORY"]:road_id="forest106_"+id
	elif id in ["LISTENING_WEST","BAKERY","LISTENING_EAST","CRAFT"]:road_id="wing_"+id
	var points:Array=[]
	for road in w.layout.config.roads:
		if str(road.id)!=road_id:continue
		for point in road.points:points.append(w.layout.vector(point))
		return {"id":road_id,"points":points}
	if id.begins_with("B") and id.length()==3:
		for road in w.layout.segments:
			if road.id==id+"_approach":return {"id":road.id,"points":[road.a,road.c]}
	return {"id":"","points":[]}

func missing_connection(a:Vector3,c:Vector3,width:float):
	if Vector2(a.x-c.x,a.z-c.z).length()<.20:return
	# Several retained entrances meet in the same public forecourt. Emit a shared
	# span once so their equal-height top faces do not flicker over one another.
	var links:Array=w.get_meta("architecture_links110",[])
	for link in links:
		if (a.distance_to(link.a)<.02 and c.distance_to(link.c)<.02) or (a.distance_to(link.c)<.02 and c.distance_to(link.a)<.02):return
	for road in w.layout.segments:
		var qa:Vector3=w.layout.projection(Vector2(a.x,a.z),road);var qc:Vector3=w.layout.projection(Vector2(c.x,c.z),road)
		var margin:float=maxf(.12,(float(road.width)-width)*.5)
		if Vector2(a.x-qa.x,a.z-qa.z).length()<=margin and Vector2(c.x-qc.x,c.z-qc.z).length()<=margin and absf(a.y-qa.y)<.08 and absf(c.y-qc.y)<.08:return
	b.ramp(a,c,width,"c6b99a")
	links.append({"a":a,"c":c,"width":width});w.set_meta("architecture_links110",links)
	var mid:Vector3=(a+c)*.5;var ground:float=w.layout.natural_height(Vector2(mid.x,mid.z))
	if mid.y-ground>.4 and mid.y-ground<8:b.box(Vector3(mid.x,(mid.y+ground)*.5,mid.z),Vector3(width*.8,mid.y-ground,.8),"b8aa90",false,0,"stone")

func entry_access(id:String,p:Vector3,outer:Vector3,width:float)->Dictionary:
	# These side wings use their original through-links, with a public starting point.
	# In particular the bakery is entered through the cafe's genuine front and rear portals.
	if id=="THEME_EVERYDAY":
		var near:Dictionary=public_anchor(Vector3(-120,p.y,180));var points:Array=[near.point,Vector3(-111,p.y,180.6),outer]
		for i in points.size()-1:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["coast_west","record_pavilion_front_path"]}
	if id=="FOREST_LODGE":
		var source:Dictionary=source_path(id);var near:Dictionary=public_anchor(w.layout.vector([-87,4.2,464]));var points:Array=[near.point,Vector3(-82,p.y,478.5),Vector3(p.x,p.y,478.5),outer]
		for i in points.size()-1:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":[source.id,"forest_lodge_front_path"]}
	if id in ["B04","B04_UPPER"]:
		# The garden bridge starts inside the conservatory's west/east footprint.
		# Its genuine public approach is the existing front flower-house street.
		var near:Dictionary=public_anchor(Vector3(-258,17.1,-207));var points:Array=[near.point,Vector3(-236,17.3,-201),Vector3(-215,17.6,-202)]
		if id=="B04_UPPER":
			points.append(Vector3(-215,p.y,-207));points.append(Vector3(-215,p.y,-208.5));points.append(Vector3(-206.5,p.y,-208.5))
		points.append(outer)
		return {"points":points,"road_id":near.id,"sources":["music_garden","flower_house_access","B04_annex_approach"] if id=="B04_UPPER" else ["music_garden","flower_house_access"]}
	if id=="B03":
		var near:Dictionary=public_anchor(Vector3(-124,4.6,220));var points:Array=[near.point,Vector3(-122,4.6,219),Vector3(-116.5,3.8,217.2),Vector3(-110,4.6,217.2),Vector3(-100,3.8,216.8),outer]
		for i in points.size()-1:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["coast_west","sleeve_and_bakery_shared_forecourt","B03_front_path"]}
	if id=="LISTENING_WEST":
		var near:Dictionary=public_anchor(Vector3(-124,4.6,220));var points:Array=[near.point,Vector3(-122,4.6,219),Vector3(-116.5,3.8,217.2),outer]
		for i in points.size()-1:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["coast_west","sleeve_forecourt"]}
	if id=="B11":
		var near:Dictionary=public_anchor(Vector3(-90,p.y,140));var points:Array=[near.point,Vector3(-83,p.y,153),Vector3(-68.5,p.y,153),Vector3(-68.5,p.y,161.5),Vector3(p.x,p.y,161.5),outer]
		for i in points.size()-1:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["coast_west","B11_west_forecourt_bypass"]}
	if id=="H13":
		var near:Dictionary=public_anchor(Vector3(-120,4.6,199));var points:Array=[near.point,Vector3(-127,p.y,198.5),Vector3(p.x,p.y,198.5),outer]
		for i in points.size()-1:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["coast_west","H13_flower_apron"]}
	if id in ["H05","H06","H08","H10"]:
		var source:Dictionary=source_path(id);var begin:Vector3=source.points[0];var near:Dictionary=public_anchor(begin);var points:Array=[near.point,begin]
		match id:
			"H05":points.append(Vector3(p.x,p.y,230.5));points.append(Vector3(p.x,p.y,228))
			"H06":points.append(Vector3(181,3.0,278));points.append(Vector3(181,p.y,245.2));points.append(Vector3(p.x,p.y,245.2))
			"H08":points.append(Vector3(111.5,p.y,45.5));points.append(Vector3(p.x,p.y,45.5));points.append(Vector3(p.x,p.y,42))
			"H10":points.append(Vector3(48.5,p.y,111));points.append(Vector3(48.5,p.y,96))
		points.append(outer)
		for i in points.size()-1:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":[source.id,id+"_unobstructed_forecourt"]}
	if id=="BAKERY_REAR":
		var near:Dictionary=public_anchor(Vector3(-124,4.6,220));var points:Array=[near.point,Vector3(-122,4.6,219),Vector3(-116.5,3.8,217.2),outer]
		for i in points.size()-1:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["coast_west","bakery_rear_forecourt"]}
	if id=="BAKERY":
		var cafe:Dictionary=w.layout.venues.B02;var y:float=cafe.floor_y;var near:Dictionary=public_anchor(Vector3(cafe.x-13,y,cafe.z+12))
		var points:Array=[near.point,Vector3(cafe.x-13,y,cafe.z+12),Vector3(cafe.x,y,cafe.z+12),Vector3(cafe.x,y,cafe.z+cafe.d*.5+1.0),Vector3(cafe.x,y,cafe.z),Vector3(cafe.x,y,cafe.z-cafe.d*.5+.4),outer]
		for i in 3:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["B02_front_portal","B02_center_aisle","B02_rear_portal","wing_BAKERY"]}
	if id=="LISTENING_EAST":
		var near:Dictionary=public_anchor(Vector3(-124,4.6,220));var link_start:=Vector3(-91.2,3.6,209)
		var link_landing:Vector3=Vector3(-80,p.y,191)+(Vector3(link_start.x,p.y,link_start.z)-Vector3(-80,p.y,191)).normalized()
		var points:Array=[near.point,Vector3(-122,4.6,219),Vector3(-116.5,3.8,217.2),Vector3(-110,4.6,217.2),Vector3(-100,3.8,216.8),link_start,link_landing,outer]
		for i in points.size()-1:
			if i!=5:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["coast_west","wing_LISTENING_WEST","retained_B03_forecourt","LISTENING_EAST_link"]}
	if id=="CRAFT":
		var near:Dictionary=public_anchor(Vector3(-90,p.y,144));var points:Array=[near.point,Vector3(-83,p.y,155),Vector3(-75,p.y,156.5),Vector3(-75,p.y,160),Vector3(-75,p.y,170),outer]
		for i in 3:missing_connection(points[i],points[i+1],width)
		return {"points":points,"road_id":near.id,"sources":["coast_west","CRAFT_rear_portal","CRAFT_center_aisle"]}
	var source:Dictionary=source_path(id);var path:Array=source.points
	if path.size()<2:
		var near:Dictionary=public_anchor(outer);missing_connection(near.point,outer,width)
		return {"points":[near.point,outer],"road_id":near.id,"sources":[]}
	# Orient toward the building, not toward the outer apron which can lie beyond
	# a short source road. The latter reversed the sleeve gallery's approach indoors.
	if Vector2(path[0].x-p.x,path[0].z-p.z).length_squared()<Vector2(path[-1].x-p.x,path[-1].z-p.z).length_squared():path.reverse()
	var best_i:int=0;var hit:Vector3=path[0];var best:float=INF
	for i in path.size()-1:
		var q:Vector3=w.layout.projection(Vector2(outer.x,outer.z),{"a":path[i],"c":path[i+1]});var distance:float=Vector2(q.x-outer.x,q.z-outer.z).length_squared()
		if distance<best:best=distance;hit=q;best_i=i
	var start:int=0;var anchor:Dictionary=public_anchor(path[0])
	for i in range(1,best_i+1):
		var next:Dictionary=public_anchor(path[i])
		if float(next.distance)<float(anchor.distance):anchor=next;start=i
	var result:Array=[anchor.point];missing_connection(anchor.point,path[start],width)
	for i in range(start,best_i+1):
		if result[-1].distance_to(path[i])>.05:result.append(path[i])
	if result[-1].distance_to(hit)>.05:result.append(hit)
	missing_connection(hit,outer,width)
	if result[-1].distance_to(outer)>.05:result.append(outer)
	return {"points":result,"road_id":anchor.id,"sources":[source.id]}

func upper_route(id:String,owner:String,points:Array,floors:Array):
	var routes:Array=w.get_meta("upper_routes110",[]);routes.append({"id":id,"owner":owner,"points":points,"floors":floors});w.set_meta("upper_routes110",routes)

func slab(p:Vector3,size:Vector2,tone:String=STONE):
	b.box(p-Vector3.UP*.14,Vector3(size.x,.28,size.y),tone,true,0,"stone")

func glass_panel(p:Vector3,size:Vector3,basis:Basis):
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.69,.84,.80,.20);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=.22;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(node);node.transform=Transform3D(basis,p);node.create_trimesh_collision()

func roof_gable(p:Vector3,width:float,depth:float,rise:float,tone:String="667b72",cross:bool=false):
	load("res://scripts/architecture_detail.gd").new().roof(b,p,width,depth,rise,tone,cross)

func roof_shed(p:Vector3,width:float,depth:float,rise:float,tone:String="6e8076",angle:float=0.0):
	var basis:=Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,-atan2(rise,depth))
	b.oriented_box(p+Vector3.UP*(rise*.5),Vector3(width,.22,sqrt(depth*depth+rise*rise)),tone,basis,true,"slate")
	for side in [-1,1]:b.beam(p+Vector3(side*width*.5,0,depth*.5),p+Vector3(side*width*.5,rise,-depth*.5),.17,WOOD)

func roof_barrel(p:Vector3,width:float,depth:float,rise:float,tone:String="657d79"):
	var n:int=14
	for i in n:
		var a:float=-PI*.5+PI*float(i)/n;var c:float=-PI*.5+PI*float(i+1)/n
		var x:float=sin(a)*width*.5;var nx:float=sin(c)*width*.5;var y:float=cos(a)*rise;var ny:float=cos(c)*rise
		var side:=Vector3(nx-x,ny-y,0).normalized();var up:=Vector3(-side.y,side.x,0)
		b.oriented_box(p+Vector3((x+nx)*.5,(y+ny)*.5,0),Vector3(Vector2(nx-x,ny-y).length()+.04,.16,depth),tone,Basis(side,up,Vector3.BACK),true,"slate")
		if i%2==0:b.beam(p+Vector3(x,y,-depth*.5),p+Vector3(x,y,depth*.5),.12,WOOD)

func roof_saw(p:Vector3,width:float,depth:float,count:int=3,tone:String="718682"):
	var span:float=depth/count
	for i in count:
		var at:Vector3=p+Vector3(0,0,-depth*.5+(i+.5)*span)
		roof_shed(at,width,span+.16,.95,tone)
		b.glass(at+Vector3(0,.45,-span*.5),Vector3(width-.5,.8,.035))
		b.collision(at+Vector3(0,.45,-span*.5),Vector3(width-.4,.85,.10))

func roof_butterfly(p:Vector3,width:float,depth:float,tone:String="637a7b"):
	for side in [-1,1]:
		b.oriented_box(p+Vector3(side*width*.25,.65,0),Vector3(width*.52,.2,depth),tone,Basis(Vector3.BACK,side*.19),true,"slate")
		b.beam(p+Vector3(side*width*.5,1.3,-depth*.5),p+Vector3(side*width*.5,1.3,depth*.5),.18,WOOD)

func roof_hip(p:Vector3,width:float,depth:float,rise:float,tone:String="7a7565"):
	for side in [-1,1]:
		b.oriented_box(p+Vector3(0,rise*.5,side*depth*.25),Vector3(width,.20,sqrt(pow(depth*.5,2)+rise*rise)),tone,Basis(Vector3.RIGHT,side*atan2(rise,depth*.5)),true,"slate")
	for side in [-1,1]:
		b.beam(p+Vector3(side*width*.5,0,-depth*.5),p+Vector3(side*(width*.5-1.3),rise,0),.18,WOOD)
		b.beam(p+Vector3(side*width*.5,0,depth*.5),p+Vector3(side*(width*.5-1.3),rise,0),.18,WOOD)

func wall(a:Vector3,c:Vector3,height:float,tone:String=PLASTER,glazed:bool=true):
	var along:Vector3=(c-a).normalized();var basis:=Basis(along,Vector3.UP,along.cross(Vector3.UP));var length:float=a.distance_to(c);var mid:Vector3=(a+c)*.5
	if not glazed:
		b.oriented_box(mid+Vector3.UP*height*.5,Vector3(length,height,.28),tone,basis,true,"plaster");return
	b.oriented_box(mid+Vector3.UP*.40,Vector3(length,.8,.28),tone,basis,true,"stone")
	var yaw:float=atan2(-along.z,along.x)
	b.glass(mid+Vector3.UP*1.9,Vector3(length-.12,2.1,.035),yaw);b.collision(mid+Vector3.UP*1.9,Vector3(length,2.1,.12),yaw)
	b.oriented_box(mid+Vector3.UP*3.12,Vector3(length,.25,.32),WOOD,basis,false,"wood")
	if height>6:
		b.glass(mid+Vector3.UP*4.65,Vector3(length-.12,2.7,.035),yaw);b.collision(mid+Vector3.UP*4.65,Vector3(length,2.7,.12),yaw)
	b.oriented_box(mid+Vector3.UP*(height-.25),Vector3(length,.5,.30),WOOD,basis,true,"wood")
	for point in [a,c]:b.box(point+Vector3.UP*height*.5,Vector3(.20,height,.20),WOOD,true,0,"wood")

func polygon_floor(p:Vector3,poly:PackedVector2Array,tone:String=STONE):
	var vertices:PackedInt32Array=Geometry2D.triangulate_polygon(poly);var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,vertices.size(),3):
		var triangle:Array=[]
		for index in [vertices[i],vertices[i+1],vertices[i+2]]:
			var q:Vector2=poly[index];triangle.append(Vector3(q.x,0,q.y))
		# Godot's front winding is clockwise: match terrain_voxel's top-face order.
		if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).y>0:triangle.reverse()
		for point in triangle:st.set_normal(Vector3.UP);st.add_vertex(point)
	var node:=MeshInstance3D.new();node.mesh=st.commit();node.material_override=b.material(tone);w.add_child(node);node.position=p;node.create_trimesh_collision()
	# A buried skirt seals the same polygon while its visible top stays at zero.
	for i in poly.size():
		var a:=p+Vector3(poly[i].x,-.14,poly[i].y);var c:=p+Vector3(poly[(i+1)%poly.size()].x,-.14,poly[(i+1)%poly.size()].y);var d:Vector3=(c-a).normalized()
		b.oriented_box((a+c)*.5,Vector3(a.distance_to(c)+.03,.28,.20),tone,Basis(d,Vector3.UP,d.cross(Vector3.UP)),true,"stone")

func perimeter(p:Vector3,poly:PackedVector2Array,height:float,door_width:float=3.4):
	var front:float=-INF
	for q in poly:front=maxf(front,q.y)
	for i in poly.size():
		var u:Vector2=poly[i];var v:Vector2=poly[(i+1)%poly.size()]
		if u.y>front-.6 and v.y>front-.6 and minf(u.x,v.x)<door_width*.5 and maxf(u.x,v.x)>-door_width*.5:
			var a:Vector2=u;var c:Vector2=v
			if a.x>c.x:
				var swap:Vector2=a
				a=c;c=swap
			if a.x< -door_width*.5:wall(p+Vector3(a.x,0,a.y),p+Vector3(-door_width*.5,0,front),height)
			if c.x>door_width*.5:wall(p+Vector3(door_width*.5,0,front),p+Vector3(c.x,0,c.y),height)
			b.box(p+Vector3(0,height-.25,front),Vector3(door_width,.5,.30),WOOD,true,0,"wood")
		else:wall(p+Vector3(u.x,0,u.y),p+Vector3(v.x,0,v.y),height,PLASTER,i%3!=1)

func upper_walk(p:Vector3,size:Vector2,level:float,tag:String,reading:bool=true)->Dictionary:
	var width:float=size.x;var depth:float=size.y;var stair_x:float=width*.5-1.45;var top_z:float=-depth*.5+3.2;var waiting:bool=tag=="THEME_WAITING"
	if waiting:stair_x=-stair_x
	var start:Vector3=p+Vector3(stair_x,0,depth*.5-1.55);var top:Vector3=p+Vector3(stair_x,level,top_z)
	var end:Vector3=p+Vector3(stair_x,level,top_z-.65)
	var left:Vector3=p+Vector3(-width*.5+1.5,level,0);var back:Vector3=p+Vector3(0,level,-depth*.5+1.25)
	var back_width:float=width-.45
	if waiting:left=p+Vector3(width*.1,level,0);back.x=p.x-width*.16;back_width=width*.68-.45
	b.box(left-Vector3.UP*.12,Vector3(2.8,.24,maxf(2,depth-4.6)),"a88a62",true,0,"wood")
	b.box(back-Vector3.UP*.12,Vector3(back_width,.24,2.5),"a88a62",true,0,"wood")
	load("res://scripts/bay_finishings.gd").new(w).flight(start,top,2.4);b.ramp(top,end,2.4,"aa906c")
	var guards=load("res://scripts/bay_guardrails.gd").new(w)
	guards.pad(p,size,false);guards.pad(left,Vector2(2.8,maxf(2,depth-4.6)));guards.pad(back,Vector2(back_width,2.5));guards.span(start,top,2.4);guards.span(top,end,2.4)
	if tag=="THEME_POEM":
		# This real second flight joins the rear mezzanine. Include its toe in the
		# same surface union so the mezzanine's front rail leaves the stair opening.
		guards.span(p+Vector3(-width*.215,level,-depth*.5+2.25),p+Vector3(-width*.215,6.9,depth*.1),2.0,false)
	if waiting:
		var rain:Vector3=p+Vector3(width*.26,level,depth*.22);slab(rain,Vector2(width*.47,2.8),"a88a62");guards.pad(rain,Vector2(width*.47,2.8))
	if tag in ["B07_ARCHIVE","B08_OBSERVE"]:load("res://scripts/architecture120.gd").new(w).join_annex(p,size,level,tag,guards)
	guards.build(tag,true)
	if reading:
		var seat:Vector3=left+Vector3(0,0,3.0);b.bench(seat,PI*.5)
		w.interact("ARCH110_"+tag+"_SEAT",seat+Vector3(.9,0,0),"上层阅读与观景 · X","sit",{"seat":seat+Vector3.UP*.08,"yaw":PI*.5})
	upper_route(tag,tag if tag.begins_with("THEME_") else tag.get_slice("_",0),[start,top,end,Vector3(end.x,back.y,back.z),back,Vector3(left.x,back.y,back.z),left],[{"center":left,"size":Vector2(2.8,maxf(2,depth-4.6)),"y":left.y},{"center":back,"size":Vector2(back_width,2.5),"y":back.y}])
	return {"height":level,"stairs":[start,top,end],"landing":back,"tag":tag}

func main_roof(ctx):
	var p:Vector3=ctx.origin;var width:float=ctx.w;var depth:float=ctx.d;var high:float=ctx.h;var id:String=ctx.item.id
	match id:
		"B01":
			roof_barrel(p+Vector3.UP*high,width+1.5,depth+1.3,1.6,"5c7a76")
			roof_shed(p+Vector3(0,3.3,depth*.5+1.2),width+2.5,3.4,.35,"69867c")
		"B02":
			# An L of two occupied wings leaves an actual open-to-sky sea-facing court.
			roof_gable(p+Vector3(-width*.28,high,0),width*.48,depth+1.6,1.8,"a87857",true)
			roof_shed(p+Vector3(width*.22,high,-depth*.31),width*.59,depth*.42,1.1,"a87857")
			for z in [-depth*.1,depth*.22]:b.beam(p+Vector3(width*.02,high-.15,z),p+Vector3(width*.5,high-.15,z),.16,WOOD)
		"B03":
			roof_shed(p+Vector3(-width*.25,high,0),width*.56,depth+1.2,1.6,"516f78")
			roof_shed(p+Vector3(width*.25,high-.75,0),width*.54,depth+1.2,.9,"829a92")
			b.glass(p+Vector3(0,high+.3,0),Vector3(.05,1.6,depth-.6));b.collision(p+Vector3(0,high+.3,0),Vector3(.1,1.6,depth-.6))
		"B04":
			# Real transparent conservatory roof; opaque timber is limited to the frame.
			for side in [-1,1]:
				var basis:=Basis(Vector3.RIGHT,side*.32)
				glass_panel(p+Vector3(0,high+.9,side*depth*.26),Vector3(width+1,.055,depth*.56),basis)
				b.oriented_box(p+Vector3(0,high+.9,side*depth*.26),Vector3(.12,.14,depth*.57),WOOD,basis)
				for x in range(-int(width*.5),int(width*.5)+1,2):b.beam(p+Vector3(x,high,side*depth*.55),p+Vector3(x,high+1.8,0),.12,WOOD)
			b.beam(p+Vector3(-width*.54,high+1.8,0),p+Vector3(width*.54,high+1.8,0),.18,WOOD)
		"B05":roof_saw(p+Vector3.UP*high,width+1.4,depth+1.3,4,"748982")
		"B06":
			b.box(p+Vector3(0,high, -depth*.10),Vector3(width+.8,.35,depth*.82),"46545b",true,0,"slate")
			roof_shed(p+Vector3(0,high-3.2,depth*.43),width+1,depth*.23,.8,"9b9986")
			for side in [-1,1]:b.box(p+Vector3(side*width*.4,high+.35,-depth*.32),Vector3(2.4,.7,3.8),"3a484f",true,0,"metal")
		"B07":
			roof_gable(p+Vector3(-width*.29,high,0),width*.47,depth+1.4,2.4,"85745c",true)
			roof_shed(p+Vector3(width*.20,high-.35,0),width*.64,depth+1.2,1.6,"ab8d69")
			for z in [-depth*.32,0,depth*.32]:b.box(p+Vector3(width*.5,high-.1,z),Vector3(.35,1.3,2.3),"927b60",false,0,"wood")
		"B08":
			roof_barrel(p+Vector3.UP*high,width+1.4,depth+1.2,2.4,"71908a")
			for z in range(-int(depth*.5),int(depth*.5)+1,3):
				b.beam(p+Vector3(-width*.5,high-.2,z),p+Vector3(0,high+2,z),.22,WOOD);b.beam(p+Vector3(0,high+2,z),p+Vector3(width*.5,high-.2,z),.22,WOOD)
		"B09":
			for i in 3:roof_barrel(p+Vector3(-width/3+i*width/3,high,0),width/3+.25,depth+1.1,.85,["6f807d","566f73","87978b"][i])
		"B10":
			for i in [-1,0,1]:roof_gable(p+Vector3(i*width*.33,high+(.7 if i==0 else 0),0),width*.35,depth+1.4,2,"5f7380",true)
			b.box(p+Vector3(width*.33,high+1.4,-depth*.33),Vector3(width*.2,2.8,depth*.25),"687379",true,0,"slate")
		"B11":
			roof_butterfly(p+Vector3.UP*high,width+1.1,depth+1.3,"94785e")
			roof_shed(p+Vector3(-width*.25,3.1,depth*.5+.9),width*.57,2.8,.35,"aa8660")
		"B13":
			roof_shed(p+Vector3(-width*.35,high,0),width*.34,depth+1.2,.65,"69867a")
			roof_shed(p+Vector3(width*.35,high,0),width*.34,depth+1.2,.65,"69867a")
			roof_gable(p+Vector3(0,high,-depth*.35),width*.48,depth*.4,1,"627a6c")
		_:roof_gable(p+Vector3.UP*high,width+1.4,depth+1.4,1.8)

func main_details(ctx):
	var p:Vector3=ctx.origin;var width:float=ctx.w;var depth:float=ctx.d;var id:String=ctx.item.id;var levels:Array=[0.0]
	match id:
		"B01":
			for side in [-1,1]:
				for z in [-depth*.26,depth*.15]:b.beam(p+Vector3(side*(width*.5-.7),.1,z),p+Vector3(side*(width*.5-.7),ctx.h-.3,z),.24,WOOD)
			b.box(p+Vector3(0,ctx.h-.35,-depth*.32),Vector3(width*.64,.42,.32),"7e9383",false,0,"wood")
			b.text3d("海 风 站 · 候 车 大 厅",p+Vector3(0,ctx.h-.35,-depth*.30),.012,"f5e8cc")
		"B02":
			# Court boundaries are low and open, retaining the existing cafe stair and all tables.
			for z in [-depth*.32,depth*.12]:b.planter(p+Vector3(-width*.40,3.8,z),1.15,"eac3c4")
			b.box(p+Vector3(-width*.32,4.3,depth*.35),Vector3(2.4,1,1.1),"c8baa1",true,0,"stone")
			b.text3d("海风内院",p+Vector3(width*.22,5.35,depth*.36),.007,"6a775d");levels.append(3.8)
			upper_route("B02_CAFE_STAIR",id,[p+Vector3(6,.1,-6),p+Vector3(6,3.8,6),p+Vector3(2.6,3.8,6),p+Vector3(-2,3.8,6)],[{"center":p+Vector3(-1.6,3.8,0),"size":Vector2(width-4,depth),"y":p.y+3.8},{"center":p+Vector3(6,3.8,6.4),"size":Vector2(4.2,2),"y":p.y+3.8},{"center":p+Vector3(-2,3.8,10),"size":Vector2(12,4),"y":p.y+3.8}])
		"B03":
			upper_walk(p,Vector2(width,depth),3.8,"B03_LISTEN",false);levels.append(3.8)
			for i in 4:b.box(p+Vector3(-width*.40,1.5,-depth*.34+i*1.9),Vector3(.38,3,1.4),"a58d70",true,0,"wood")
			b.text3d("唱片连廊",p+Vector3(-width*.39,5.1,depth*.12),.007,"576d65",PI*.5)
		"B04":
			for i in 5:
				var at:Vector3=p+Vector3(-width*.36+i*width*.18,0,-depth*.42)
				b.box(at+Vector3.UP*.55,Vector3(width*.15,1.1,.65),"a58a67",true,0,"wood")
				for k in 4:b.shape(at+Vector3((k-1.5)*.28,1.3,.02),Vector3(.32,.4,.32),["f4b8c4","f2c14e","6ba4d6","9b7ede","faf6f0"][i],"flower")
		"B05":
			# The original two offset exhibition walls remain the actual turning gallery.
			for i in 4:b.box(p+Vector3(-width*.36+i*width*.24,ctx.h-.35,-depth*.15),Vector3(.18,.6,depth*.9),"a6ad96",false,0,"wood")
		"B06":
			for side in [-1,1]:
				for flank in [-1,1]:b.box(p+Vector3(side*(width*.5-.8),1.3,depth*.37+flank*1.85),Vector3(.35,2.6,.38),"546264",true,0,"stone")
				b.text3d("侧廊出口",p+Vector3(side*(width*.5-2.5),3.0,depth*.25),.006,"d7d1ad")
				flush_entry(p+Vector3(0,0,depth*.37),2.6,width,side*PI*.5,id+"_SIDE_"+str(side),3.4)
		"B07":
			upper_walk(p,Vector2(width,depth),3.15,"B07_ARCHIVE");levels.append(3.15)
			for z in [-depth*.36,-depth*.13,depth*.12]:
				b.box(p+Vector3(-width*.5+.6,2.6,z),Vector3(.6,5.2,2.4),"7c6850",true,0,"wood")
				for row in 8:b.box(p+Vector3(-width*.5+.9,.3+row*.62,z),Vector3(.38,.08,2.4),"c4af86",false,0,"wood")
		"B08":
			upper_walk(p,Vector2(width,depth),3.1,"B08_OBSERVE",false);levels.append(3.1)
			for side in [-1,1]:b.beam(p+Vector3(side*(width*.5-.8),.1,-depth*.36),p+Vector3(side*(width*.5-.8),ctx.h-.3,-depth*.36),.28,WOOD)
		"B09":
			# Split performance/control rooms have an actual opening at the south end.
			wall(p+Vector3(1.8,0,-depth*.44),p+Vector3(1.8,0,-1.4),3.4,"657568",true)
			b.box(p+Vector3(1.8,.45,-3),Vector3(.35,.9,3.2),"6d7764",true,0,"wood")
			for i in 4:b.box(p+Vector3(width*.42,2,-depth*.36+i*1.9),Vector3(.45,3.7,.3),"7e897b",true,0,"wood")
		"B10":
			for side in [-1,1]:
				b.box(p+Vector3(side*(width*.5-2.5),.34,-depth*.29),Vector3(3.8,.68,7.2),"8d7762",true,0,"wood")
				b.ramp(p+Vector3(side*(width*.5-2.5),0,0),p+Vector3(side*(width*.5-2.5),.68,-depth*.18),2.5,"aa906c")
				b.text3d("侧台",p+Vector3(side*(width*.5-2.5),2.7,-depth*.30),.007,"e8d8b7")
		"B11":
			levels.append(4.0)
			b.box(p+Vector3(-width*.34,.55,-depth*.24),Vector3(1.1,1.1,3.2),"a08760",true,0,"wood")
			b.box(p+Vector3(width*.33,1.4,-depth*.35),Vector3(2.4,2.8,.45),"a78d68",true,0,"wood")
			b.text3d("包装 · 印章",p+Vector3(width*.30,2.9,-depth*.32),.006,"5e6957")
		"B12":
			for i in 3:b.box(p+Vector3(5.8,.55,-3.7+i*1.2),Vector3(1.15,1.1,.8),"9a8c6d",true,0,"wood")
		"B13":
			for side in [-1,1]:
				b.box(p+Vector3(side*width*.21,.20,depth*.32),Vector3(1.4,.4,1.8),"b5b398",true,0,"stone")
				b.shape(p+Vector3(side*width*.21,1,depth*.32),Vector3(.7,1.2,.7),"819c70","shrub")
			b.text3d("山海导览庭",p+Vector3(0,3.7,-depth*.25),.008,"587665")
	flush_entry(p,3.2,depth,0,id,4.2 if id!="B12" else 5.0)
	if id=="B03":levels.append(4.0)
	record(id,{"B01":"barrel_station_clock","B02":"L_cafe_court","B03":"split_record_gallery","B04":"glass_flowerhouse","B05":"sawtooth_turning_gallery","B06":"cinema_box_lobby","B07":"stepped_archive_loft","B08":"longspan_rehearsal","B09":"segmented_acoustic_rooms","B10":"folded_stagehouse","B11":"corner_craft_shop","B12":"forest_stone_home","B13":"guide_courtyard"}.get(id,id),p,Vector2(width,depth),p+Vector3(0,0,depth*.5),levels)

func living_roof(h:Dictionary,p:Vector3,size:Vector2,height:float):
	var width:float=size.x;var depth:float=size.y
	match str(h.id):
		"H01":roof_gable(p+Vector3.UP*height,width+1.5,depth+1.4,3.2,"9e7554",true)
		"H02":
			roof_barrel(p+Vector3.UP*height,width+1.4,depth+1.5,2.7,"7e866d")
			for side in [-1,1]:b.beam(p+Vector3(side*1.9,0,depth*.5+.15),p+Vector3(side*4.8,3.1,depth*.5+.15),.20,WOOD)
		"H03":roof_saw(p+Vector3.UP*height,width+1.3,depth+1.4,2,"778e86")
		"H04":
			roof_shed(p+Vector3(-width*.28,height,0),width*.5,depth+1.2,1.1,"9f775f")
			roof_gable(p+Vector3(width*.23,height,-depth*.18),width*.55,depth*.72,1.2,"b0916a")
		"H05":
			roof_hip(p+Vector3.UP*height,width+1.2,depth+1.4,1.6,"637e86")
			for side in [-1,1]:b.box(p+Vector3(side*2.2,height+1.6,-2),Vector3(.14,2.2,.14),WOOD,true,0,"wood")
			roof_hip(p+Vector3(0,height+2.8,-2),5.8,5,1.3,"587781")
		"H06":
			roof_shed(p+Vector3.UP*height,width+2,depth+2,.9,"ad9067")
			for x in range(-int(width*.5),int(width*.5)+1):b.beam(p+Vector3(x,3.2,depth*.5),p+Vector3(x,3.2,depth*.5+3.2),.09,"9c865e")
		"H07":roof_gable(p+Vector3.UP*height,width+1.6,depth+1.5,2.7,"776b58")
		"H08":
			roof_gable(p+Vector3(-width*.23,height,0),width*.58,depth+1.4,2,"688178",true)
			glass_panel(p+Vector3(width*.28,height+.8,0),Vector3(width*.48,.055,depth+1.2),Basis(Vector3.RIGHT,-atan2(1.6,depth+1.2)))
			for z in [-depth*.4,0,depth*.4]:b.beam(p+Vector3(width*.04,height+.8,z),p+Vector3(width*.52,height+.8,z),.13,WOOD)
		"H09":roof_butterfly(p+Vector3.UP*height,width+1.1,depth+1.4,"9b7e7b")
		"H10":roof_gable(p+Vector3.UP*height,width+1.3,depth+1.5,2.1,"718a82",true)
		"H11":roof_barrel(p+Vector3.UP*height,width+1.2,depth+1.2,1.8,"9b8870")
		"H12":roof_saw(p+Vector3.UP*height,width+1.3,depth+1.3,3,"7b8f8b")
		"H13":
			for side in [-1,1]:roof_shed(p+Vector3(side*width*.28,height,0),width*.47,depth+1.2,1.8,"8e947d",side*PI)
			b.glass(p+Vector3(0,height+1.45,0),Vector3(1.3,.05,depth-.1))
		"H14":roof_hip(p+Vector3.UP*height,width+1.5,depth+1.4,1.7,"7c8d72")
		_:roof_gable(p+Vector3.UP*height,width+1.4,depth+1.4,2,h.roof)

func living_details(h:Dictionary,p:Vector3,size:Vector2):
	var width:float=size.x;var depth:float=size.y;var id:String=h.id
	# Private sofas, beds, kitchens and authored use points remain in place. These zones sit
	# against the far walls, outside the 3.2 m entry spine and the original U stairs.
	match id:
		"H01":
			b.box(p+Vector3(width*.45,2.8,-depth*.35),Vector3(.8,5.6,.8),"9e8b73",true,0,"stone")
			b.box(p+Vector3(-width*.40,.85,-.8),Vector3(1.2,1.7,2.3),"b69c72",true,0,"wood")
		"H02":
			for side in [-1,1]:
				b.box(p+Vector3(side*2.3,1.3,depth*.5+.5),Vector3(.12,2.6,1.25),"9c855b",true,side*.35,"wood")
			for i in 4:b.box(p+Vector3(width*.40,.35,-depth*.20+i*1.2),Vector3(1,.7,.85),"bd9f65",true,0,"wood")
		"H03":
			for side in [-1,1]:b.beam(p+Vector3(side*width*.42,3.1,-depth*.3),p+Vector3(side*width*.42,5.9,-depth*.3),.14,WOOD)
			b.box(p+Vector3(-width*.40,1.5,-depth*.1),Vector3(.35,3,2.4),"bca478",true,0,"wood")
		"H04":
			for side in [-1,1]:b.planter(p+Vector3(side*(width*.5-1.1),0,depth*.5+1.5),1.4,"efc0c5")
			b.box(p+Vector3(width*.40,.8,-depth*.12),Vector3(.65,1.6,3.5),"9d8762",true,0,"wood")
		"H05":
			b.box(p+Vector3(-width*.39,1.7,-depth*.28),Vector3(.12,2,2.8),"8d9f98",true,0,"wood")
			b.text3d("潮汐 · 航线",p+Vector3(-width*.38,2,-depth*.28),.005,"e8d9b5",PI*.5)
		"H06":
			for z in [-depth*.22,depth*.16]:
				for i in 6:b.box(p+Vector3(-width*.41,.7+i*.27,z),Vector3(1.0,.08,1.8),"aa9169",true,0,"wood")
		"H07":
			b.box(p+Vector3(-width*.5+.20,.9,0),Vector3(.40,1.8,depth*.85),"9b9988",true,0,"stone")
			for z in [-depth*.25,depth*.15]:b.box(p+Vector3(0,3.85,z),Vector3(width-.5,.27,.28),WOOD,false,0,"wood")
		"H08":
			for j in 3:b.box(p+Vector3(width*.41,1.45,-depth*.27+j*1.5),Vector3(.30,2.9,.9),"b1a786",true,0,"wood")
			b.glass(p+Vector3(width*.39,4.8,0),Vector3(.03,1.6,depth*.7))
		"H09":
			b.box(p+Vector3(-width*.40,1.5,-depth*.1),Vector3(.26,2.7,3.8),"c9bca1",true,0,"wood")
			b.text3d("裁样 · 花庭",p+Vector3(-width*.38,2.3,-depth*.1),.005,"657363",PI*.5)
		"H10":
			for row in 4:
				for col in 4:b.box(p+Vector3(width*.42,.5+row*.5,-depth*.24+col*.75),Vector3(.45,.42,.65),"9c896b",true,0,"wood")
		"H11":
			b.box(p+Vector3(-width*.42,1.15,depth*.05),Vector3(.6,2.3,2.5),"8c735d",true,0,"wood")
			b.box(p+Vector3(-width*.4,2.5,depth*.05),Vector3(1.1,.35,2.8),"b99b70",true,0,"wood")
		"H12":
			# A darkroom alcove is screened from the bright main room without enclosing its door.
			b.box(p+Vector3(-width*.29,1.25,-depth*.37),Vector3(3,2.5,.2),"56625c",true,0,"wood")
			for side in [-1,1]:b.beam(p+Vector3(side*2,2.8,depth*.5+1),p+Vector3(side*2,2.8,depth*.5+2.7),.025,WOOD)
		"H13":
			for z in [-depth*.27,depth*.18]:
				for x in [-width*.4,width*.4]:
					b.box(p+Vector3(x,1.7,z),Vector3(.13,3.4,.13),WOOD,true,0,"wood")
					b.box(p+Vector3(x,3.4,z),Vector3(1.2,.12,.13),WOOD,false,0,"wood")
		"H14":
			for i in 3:
				var at:Vector3=p+Vector3(-width*.31+i*1.35,0,-depth*.44)
				b.shape(at+Vector3.UP*1.2,Vector3(1.0,2.4,1.0),"a18a61","post");b.collision(at+Vector3.UP*1.2,Vector3(.85,2.4,.85))
			for i in 4:b.box(p+Vector3(width*.435,.5+i*.55,-depth*.03+i*.4),Vector3(1.1,.16,1.0),"ab9367",true,0,"wood")
	flush_entry(p,3.2,depth,0,id,5.2)
	if bool(h.loft):
		var points:Array=[];var entry:Vector3=w.layout.vector(h.stairs[0]);var front:Vector3=p+Vector3(0,0,depth*.5+1.4)
		points.append(front);points.append(Vector3(p.x,p.y,entry.z))
		for point in h.stairs:points.append(w.layout.vector(point))
		upper_route(id+"_LOFT",id,points,[{"center":p+Vector3(0,3.4,-depth*.2),"size":Vector2(width-1,depth*.6),"y":p.y+3.4},{"center":p+Vector3(0,3.4,depth*.3),"size":Vector2(3.4,depth*.4),"y":p.y+3.4},{"center":p+Vector3(0,3.4,depth*.5+1.7),"size":Vector2(width,3.4),"y":p.y+3.4}])
	var families:Dictionary={"H01":"oven_loft","H02":"seed_barn","H03":"daylight_atelier","H04":"orchard_court","H05":"nautical_tower","H06":"wicker_workyard","H07":"stone_hearth_hall","H08":"greenhouse_bookloft","H09":"flower_tailoring","H10":"postal_bindery","H11":"puppet_musicbox","H12":"photo_darkroom","H13":"flower_drying","H14":"bean_cat_library"}
	record(id,families[id],p,size,p+Vector3(0,0,depth*.5),[0.0,3.4] if h.loft else [0.0])

func fan_roof(p:Vector3,size:Vector2,rise:float,tone:String):
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var a:float=i*TAU/16;var c:float=(i+1)*TAU/16
		var left:=Vector3(sin(a)*size.x*.5,0,cos(a)*size.y*.5);var right:=Vector3(sin(c)*size.x*.5,0,cos(c)*size.y*.5)
		for q in [Vector3(0,rise,0),left,right]:st.add_vertex(q)
		b.beam(p+left,p+Vector3(0,rise,0),.13,WOOD)
	st.generate_normals();var node:=MeshInstance3D.new();node.mesh=st.commit();var mat:StandardMaterial3D=b.material(tone).duplicate();mat.cull_mode=BaseMaterial3D.CULL_DISABLED;node.material_override=mat;w.add_child(node);node.position=p;node.create_trimesh_collision()

func theme_shell(room:Dictionary,p:Vector3,size:Vector2)->Dictionary:
	var width:float=size.x;var depth:float=size.y;var id:String=room.id;var high:float=4.4;var levels:Array=[0.0]
	var poly:=PackedVector2Array([Vector2(-width*.5,-depth*.5),Vector2(width*.5,-depth*.5),Vector2(width*.5,depth*.5),Vector2(-width*.5,depth*.5)])
	match id:
		"THEME_EVERYDAY":
			poly.clear()
			for i in 16:
				var a:float=i*TAU/16;poly.append(Vector2(sin(a)*width*.5,cos(a)*depth*.5))
		"THEME_WAITING":
			high=7.4;levels.append(3.7)
			poly=PackedVector2Array([Vector2(-width*.5,-depth*.5),Vector2(width*.18,-depth*.5),Vector2(width*.18,-depth*.08),Vector2(width*.5,-depth*.08),Vector2(width*.5,depth*.5),Vector2(-width*.5,depth*.5)])
		"THEME_POEM":high=7.0;levels.append(3.4);levels.append(6.9)
		"THEME_FROST":high=6.7;levels.append(4.1)
		"THEME_BLOSSOM":high=4.8
		"THEME_DAILY":high=7.3;levels.append(3.7)
	polygon_floor(p,poly,"c7b997")
	if id=="THEME_FROST":
		wall(p+Vector3(-width*.5,0,-depth*.5),p+Vector3(width*.5,0,-depth*.5),high,"73848c",false)
		for side in [-1,1]:wall(p+Vector3(side*width*.5,0,-depth*.5),p+Vector3(side*width*.5,0,depth*.07),4.0,"8a9aa0",false)
	else:perimeter(p,poly,high)
	match id:
		"THEME_EVERYDAY":
			fan_roof(p+Vector3.UP*high,Vector2(width+.6,depth+.6),1.35,"658375")
			# Radial record bins follow the curved wall and leave the portal and sofa sector open.
			for i in 9:
				var a:float=1.35+i*.39;var at:Vector3=p+Vector3(sin(a)*(width*.5-.9),0,cos(a)*(depth*.5-.9));var yaw:float=a+PI*.5
				b.box(at+Vector3.UP*.65,Vector3(1.05,1.3,.48),"9e8964",true,yaw,"wood")
				for j in 5:b.box(at+Basis(Vector3.UP,yaw)*Vector3((j-2)*.16,1.43,0),Vector3(.10,.26,.35),["e4c493","acbbaa","b9c5c8"][j%3],false,yaw)
		"THEME_WAITING":
			upper_walk(p,size,3.7,"THEME_WAITING",false)
			roof_shed(p+Vector3(-width*.16,high,0),width*.68+.8,depth+.6,1,"8c7660")
			roof_gable(p+Vector3(width*.22,high,depth*.23),width*.61,depth*.57,1.3,"6e877a")
			for i in 4:b.box(p+Vector3(width*.25,1.7,-depth*.08+.18+i*.65),Vector3(2.5,.12,.12),"d1bf91",false,0,"wood")
			b.box(p+Vector3(width*.18,1.4,-depth*.08),Vector3(1.4,2.8,.2),"8d7961",true,0,"wood")
			b.text3d("雨廊候车 · 街角小站",p+Vector3(-width*.22,5.3,depth*.5+.12),.009,"e6d7b5")
		"THEME_POEM":
			upper_walk(p,size,3.4,"THEME_POEM",false)
			for i in 5:
				b.box(p+Vector3(-width*.475,2.9,-depth*.35+i*depth*.15),Vector3(.5,5.8,1.6),"8c795e",true,0,"wood")
				for row in 8:b.box(p+Vector3(-width*.45,.35+row*.68,-depth*.35+i*depth*.15),Vector3(.3,.10,1.5),"bba47b",false,0,"wood")
			# Second stair starts on the mezzanine and arrives on an open roof reading terrace.
			var a:Vector3=p+Vector3(-width*.215,3.4,-depth*.5+2.25);var c:Vector3=p+Vector3(-width*.215,6.9,depth*.1);var corner:Vector3=c+Vector3(0,0,1.45);var landing:Vector3=p+Vector3(width*.08,6.9,depth*.1+1.45)
			load("res://scripts/bay_finishings.gd").new(w).flight(a,c,2.0);b.ramp(c,corner,2.0,"ad926c");b.ramp(corner,landing,2.4,"ad926c");slab(corner,Vector2(2.8,2.8),"ac9169");slab(landing,Vector2(2.8,2.8),"ac9169")
			var terrace:Vector3=p+Vector3(width*.16,6.9,-depth*.17);slab(terrace,Vector2(width*.60,depth*.58),"ac9169")
			var guards=load("res://scripts/bay_guardrails.gd").new(w);guards.pad(p+Vector3(0,3.4,-depth*.5+1.25),Vector2(width-.45,2.5),false);guards.span(a,c,2.0);guards.span(c,corner,2.0);guards.span(corner,landing,2.4);guards.pad(corner,Vector2(2.8,2.8));guards.pad(landing,Vector2(2.8,2.8));guards.pad(terrace,Vector2(width*.60,depth*.58));guards.build("poem_roof_reading",true)
			b.table(terrace+Vector3(1,0,-1.2),1.3);b.bench(terrace+Vector3(1,0,-2.4))
			w.interact("ARCH110_POEM_ROOF",terrace+Vector3(1,0,-.2),"屋顶星灯阅读台 · X","sit",{"seat":terrace+Vector3(1,.08,-2.4),"yaw":0})
			roof_shed(p+Vector3(-width*.36,9.5,0),width*.30,depth+.5,.9,"657c70")
			for z in [-depth*.4,depth*.25]:b.box(p+Vector3(-width*.43,8.2,z),Vector3(.18,2.6,.18),WOOD,true,0,"wood")
			upper_route("THEME_POEM_ROOF","THEME_POEM",[a,c,corner,landing,Vector3(landing.x,terrace.y,terrace.z),terrace],[{"center":terrace,"size":Vector2(width*.60,depth*.58),"y":terrace.y},{"center":landing,"size":Vector2(2.8,2.8),"y":landing.y}])
		"THEME_FROST":
			upper_walk(p,size,4.1,"THEME_FROST",false)
			roof_butterfly(p+Vector3(0,high,-depth*.19),width+.7,depth*.69,"7f9096")
			for i in 3:
				var at:Vector3=p+Vector3(-width*.32,.13+i*.26,depth*.24+i*.9)
				b.box(at,Vector3(3.8,.26+i*.52,.85),"a4b1ad",true,0,"stone")
			for side in [-1,1]:b.box(p+Vector3(side*width*.44,.26,-depth*.17),Vector3(1.4,.52,depth*.35),"8c9b9d",true,0,"wood")
			for i in 5:b.box(p+Vector3(-width*.35+i*width*.175,4.6,-depth*.4),Vector3(.34,.4,.48),"666e78",false,0,"metal")
		"THEME_BLOSSOM":
			# Two open courtyards, a covered search promenade and a separate rear programme hall.
			for side in [-1,1]:
				var garden:Vector3=p+Vector3(side*width*.17,0,depth*.28)
				b.box(garden+Vector3.UP*.13,Vector3(2.2,.26,2.4),"9d896b",true,0,"stone")
				for i in 6:b.shape(garden+Vector3(sin(i*2.399)*.62,.65,cos(i*2.399)*.7),Vector3(.55,.75,.55),["e9b6c4","e8d5b0","bca9d1"][i%3],"flower")
				roof_shed(p+Vector3(side*(width*.5-1.05),high,0),2.7,depth+.8,.65,"8a7e68")
				for z in [-depth*.28,0,depth*.28]:b.box(p+Vector3(side*(width*.5-1.05),2.3,z),Vector3(.14,4.6,.14),WOOD,true,0,"wood")
			roof_gable(p+Vector3(0,high,-depth*.33),width+.8,depth*.37,1.2,"8f7b63")
			b.beam(p+Vector3(-width*.5,high,depth*.5),p+Vector3(width*.5,high,depth*.5),.20,WOOD)
		"THEME_DAILY":
			upper_walk(p,size,3.7,"THEME_DAILY",false)
			roof_saw(p+Vector3.UP*high,width+.9,depth+.8,3,"83928b")
			var dark:Vector3=p+room_work_offset(room);var front:float=-depth*.03
			for side in [-1,1]:
				b.box(Vector3(dark.x+side*2.0,p.y+1.55,p.z+front),Vector3(1.25,3.1,.22),"59635e",true,0,"wood")
			b.box(Vector3(dark.x,p.y+2.95,p.z+front),Vector3(2.8,.3,.22),"59635e",true,0,"wood")
			for i in 5:b.box(p+Vector3(width*.42,1.8,-depth*.3+i*depth*.12),Vector3(.12,3.6,.18),WOOD,false,0,"wood")
			b.text3d("暗房 → 天光摄影棚 → 晾片院",p+Vector3(0,3.3,depth*.5+.1),.007,"657162")
	# Local frame is rotated with all furniture, surfaces, collision and existing IDs by caller.
	return {"height":high,"levels":levels,"polygon":poly}

func forest_shell(h:Dictionary,p:Vector3,size:Vector2):
	var width:float=size.x;var depth:float=size.y;var id:String=h.id;var high:float=3.8
	var poly:=PackedVector2Array([Vector2(-width*.5,-depth*.5),Vector2(width*.5,-depth*.5),Vector2(width*.5,depth*.5),Vector2(-width*.5,depth*.5)])
	if id=="TREEHOUSE_1":
		poly=PackedVector2Array([Vector2(-width*.5+.22,-depth*.5),Vector2(width*.5,-depth*.5),Vector2(width*.5,depth*.5),Vector2(-width*.5,depth*.5),Vector2(-width*.5,-depth*.13),Vector2(-width*.5+.22,-depth*.13)])
	if id=="FOREST_OBSERVATORY":
		poly.clear()
		for i in 8:
			var a:float=(i+.5)*TAU/8;poly.append(Vector2(sin(a)*width*.54,cos(a)*depth*.55))
	polygon_floor(p,poly,"b59a72");perimeter(p,poly,high,3.2)
	match id:
		"TREEHOUSE_1":
			roof_gable(p+Vector3(.35,high,0),width+.6,depth+1,1.8,"7d775d",true)
			b.box(p+Vector3(-width*.40,.55,-depth*.07),Vector3(.75,1.1,1.6),"af9c75",true,0,"wood")
		"TREEHOUSE_2":
			roof_butterfly(p+Vector3.UP*high,width+1,depth+1,"79846a")
			for side in [-1,1]:
				for i in 6:b.box(p+Vector3(side*(width*.5+.08),1.8,-2.1+i*.7),Vector3(.15,2.2,.42),"a59d76",false,side*.35,"wood")
		"TREEHOUSE_3":
			for side in [-1,1]:roof_shed(p+Vector3(side*width*.32,high,0),width*.44,depth+1,.65,"7e8068")
			roof_shed(p+Vector3(0,high,-depth*.32),width*.45,depth*.4,.7,"7e8068")
			b.shape(p+Vector3(.1,.3,-.9),Vector3(.7,.6,.7),"b5a783","pot");b.shape(p+Vector3(.1,1,-.9),Vector3(.75,1.3,.75),"7a9968","shrub")
		"TREEHOUSE_4":
			for side in [-1,1]:roof_shed(p+Vector3(side*width*.35,high,0),width*.40,depth+1,.8,"68796f")
			for side in [-1,1]:roof_shed(p+Vector3(0,high,side*depth*.36),width*.31,depth*.42,.7,"68796f")
			glass_panel(p+Vector3(0,high+.5,0),Vector3(width*.32,.06,depth*.32),Basis.IDENTITY)
			b.box(p+Vector3(-width*.38,.65,-.3),Vector3(.7,1.3,1.4),"958b6d",true,0,"wood")
		"FOREST_LODGE":
			roof_saw(p+Vector3.UP*high,width+1,depth+1,2,"74846e")
			for i in 3:b.shelf(p+Vector3(width*.39,0,-depth*.30+i*1.6),1.6)
			b.text3d("旅行册 · 资源架",p+Vector3(width*.37,2.5,0),.0045,"5d735f",-PI*.5)
		"FOREST_OBSERVATORY":
			fan_roof(p+Vector3.UP*high,Vector2(width+1,depth+1),1.6,"5d7a72")
			for i in 8:
				var a:float=i*TAU/8;var at:Vector3=p+Vector3(sin(a)*width*.42,2.4,cos(a)*depth*.42)
				b.box(at,Vector3(.13,1.4,.13),"d2bf85",false,a,"wood")
				b.glow_box(at+Vector3.UP*.7,Vector3(.10,.10,.10))
	if not bool(h.treehouse):flush_entry(p,3.0,depth,0,id)
	else:
		# Canopy porches already meet the public elevated route. Cover the door-to-porch join.
		b.box(p+Vector3(0,-.12,depth*.5+.40),Vector3(3.2,.24,1.1),"a88a61",true,0,"wood")
		var anchor:Vector3=p+Vector3(0,0,6);var porch:Vector3=p+Vector3(0,0,4.5);var door:Vector3=p+Vector3(0,0,depth*.5);var inside:Vector3=p+Vector3(0,0,depth*.5-.65)
		var entries:Array=w.get_meta("entrances110",[]);entries.append({"id":id,"public_route":anchor,"anchor":anchor,"approach":porch,"door":door,"inside":inside,"width":3.2,"points":[anchor,porch,door,inside]});w.set_meta("entrances110",entries)
	record(id,{"TREEHOUSE_1":"trunk_wrap_reading","TREEHOUSE_2":"dual_louvre_balcony","TREEHOUSE_3":"firefly_mini_court","TREEHOUSE_4":"skylight_star_corner","FOREST_LODGE":"travelbook_lodge","FOREST_OBSERVATORY":"alignment_ring"}.get(id,id),p,size,p+Vector3(0,0,depth*.5),[0.0])

func annex_roof(id:String,p:Vector3):
	match id:
		"B01":
			# Clock is on the existing east wing, leaving the station's west approach untouched.
			for x in [-3.5,3.5]:
				for z in [-3.5,3.5]:b.box(p+Vector3(x,8.1,z),Vector3(.42,2.8,.42),"809184",true,0,"wood")
			roof_hip(p+Vector3(0,9.6,0),8.8,8.8,1.8,"5d7774")
			for side in [-1,1]:
				b.box(p+Vector3(0,8.3,side*2.7),Vector3(2.1,2.1,.16),"e6dcc0",false,0,"stone")
				b.box(p+Vector3(0,8.55,side*2.81),Vector3(.08,.7,.09),WOOD,false,0,"wood");b.box(p+Vector3(.33,8.3,side*2.81),Vector3(.70,.08,.09),WOOD,false,0,"wood")
		"B04":
			glass_panel(p+Vector3(0,7.35,0),Vector3(9.2,.055,9.2),Basis(Vector3.RIGHT,-atan2(.9,9.2)))
			for x in [-4,-2,0,2,4]:b.beam(p+Vector3(x,6.9,4.6),p+Vector3(x,7.8,-4.6),.15,WOOD)
		"B05":roof_saw(p+Vector3(0,6.9,0),9.1,9.1,3,"7e968d")
		"B06":
			roof_shed(p+Vector3(0,6.9,0),9.1,9.1,1.3,"747c76")
			for z in [-3,0,3]:b.box(p+Vector3(0,7.2,z),Vector3(8.6,.25,.4),"879188",false,0,"wood")
		"B07":roof_gable(p+Vector3(0,6.9,0),9.1,9.2,2.8,"9a7c5e",true)
		"B08":roof_barrel(p+Vector3(0,6.9,0),9.2,9.1,1.5,"768f89")
		"B09":roof_butterfly(p+Vector3(0,6.9,0),9.1,9.1,"787e73")
		"B10":
			b.box(p+Vector3(0,6.9,0),Vector3(9.2,.28,9.2),"617481",true,0,"slate")
			roof_shed(p+Vector3(0,7.3,-2),8.8,5.0,1.0,"71838a")
		"B12":
			roof_gable(p+Vector3(0,6.9,0),9.2,9.2,1.8,"849281")
			b.glass(p+Vector3(0,7.6,0),Vector3(2.0,.05,6.8))
		"B13":roof_hip(p+Vector3(0,6.9,0),9.8,9.8,1.25,"638271")

func annex_details(id:String,p:Vector3):
	var levels:Array=[0.0,3.8]
	var route:Array=[]
	for point in w.layout.config.annexes[id].stairs:route.append(w.layout.vector(point))
	upper_route(id+"_ANNEX_STAIR",id+"_UPPER",route,[{"center":p+Vector3.UP*3.8,"size":Vector2(8.4,8.4),"y":p.y+3.8}])
	match id:
		"B01":
			# A compact second U stair reaches the real open clock observation floor.
			var a:Vector3=p+Vector3(2.7,3.8,2.5);var c:Vector3=p+Vector3(2.7,6.9,-1.7);var corner:Vector3=p+Vector3(2.7,6.9,-3.05);var d:Vector3=p+Vector3(0,6.9,-3.05)
			load("res://scripts/bay_finishings.gd").new(w).flight(a,c,2.2);b.ramp(c,corner,2.3,"ab906b");b.ramp(corner,d,2.3,"ab906b")
			# Hole stays above the stair; the observation floor is a wide L rather than a solid lid.
			slab(p+Vector3(-1.1,6.9,0),Vector2(5.4,7.6),"ab906b");slab(p+Vector3(1.8,6.9,-2.8),Vector2(3.0,2.0),"ab906b")
			var guards=load("res://scripts/bay_guardrails.gd").new(w);guards.pad(p+Vector3.UP*3.8,Vector2(8.4,8.4),false);guards.span(a,c,2.2);guards.span(c,corner,2.3);guards.span(corner,d,2.3);guards.pad(p+Vector3(-1.1,6.9,0),Vector2(5.4,7.6));guards.pad(p+Vector3(1.8,6.9,-2.8),Vector2(3,2));guards.build("B01_clock_observation",true)
			b.bench(p+Vector3(-1.2,6.9,.4),PI);w.interact("ARCH110_B01_CLOCK",p+Vector3(-1.2,6.9,1.5),"海风钟楼观景层 · X","sit",{"seat":p+Vector3(-1.2,7.0,.4),"yaw":PI});levels.append(6.9)
			upper_route("B01_CLOCK","B01_UPPER",[a,c,corner,d,p+Vector3(1.0,6.9,-3.05),p+Vector3(1.0,6.9,1.5),p+Vector3(-1.2,6.9,1.5)],[{"center":p+Vector3(-1.1,6.9,0),"size":Vector2(5.4,7.6),"y":p.y+6.9},{"center":p+Vector3(1.8,6.9,-2.8),"size":Vector2(3,2),"y":p.y+6.9}])
		"B04":
			for i in 5:
				var at:Vector3=p+Vector3(2.7,3.8,-2.8+i*1.25)
				b.beam(at+Vector3.UP*2.5,at+Vector3(.8,2.5,0),.08,WOOD)
				b.shape(at+Vector3(.5,1.9,0),Vector3(.25,.65,.25),["e4c4cc","d4c496","b8b9d4"][i%3],"shrub")
		"B05":
			for i in 8:b.box(p+Vector3(0,5.7,-3.8+i*.45),Vector3(6.9,.14,.20),"b6b59b",false,0,"wood")
			b.box(p+Vector3(2.9,4.15,-1.2),Vector3(1.1,.7,3.0),"b3a27d",true,0,"wood")
		"B06":
			for i in 4:
				b.box(p+Vector3(-2.7+i*1.8,5.3,-3.7),Vector3(1.3,1.4,.10),["9caa9d","c1ae8d","a7b6ae","b6a7ac"][i],false,0,"fabric")
			b.box(p+Vector3(2.4,5.1,-.8),Vector3(.20,2.6,2.8),"949f91",true,.24,"plaster")
		"B07":
			b.box(p+Vector3(2.8,4.3,-2.8),Vector3(1.2,1.0,1.1),"bca37b",true,0,"wood")
		"B08":
			for i in 2:b.box(p+Vector3(2.4,3.95+i*.20,-1.3+i*1.1),Vector3(2,.3+i*.4,.8),"b0a17e",true,0,"wood")
		"B09":
			wall(p+Vector3(1.0,3.8,-3.4),p+Vector3(1.0,3.8,-.5),2.8,"8c9988",true)
			for i in 3:
				b.shape(p+Vector3(2.7,5.0,-2.4+i*1.7),Vector3(.7,.7,.2),"9d8b68","post",PI*.5)
		"B10":
			b.box(p+Vector3(2.3,4.35,-1.2),Vector3(1.3,1.1,3.1),"788988",true,0,"metal")
			for i in 5:b.glow_box(p+Vector3(2.3,4.95,-2.3+i*.5),Vector3(.16,.05,.16))
		"B12":
			wall(p+Vector3(1.0,3.8,-3.4),p+Vector3(1.0,3.8,-.5),2.8,"a9b69b",true)
			for i in 4:b.planter(p+Vector3(2.6,3.8,-2.7+i*1.6),.9,["e7bdc4","ddcd8e","a5bca8","b2b4ce"][i])
		"B13":
			b.box(p+Vector3(2.7,5.1,-.5),Vector3(.16,2.2,3.4),"d3caab",true,0,"wood")
	flush_entry(p,3.2,8.4,0,id+"_UPPER")
	record(id+"_UPPER",{"B01":"clock_waiting_wing","B04":"transparent_flower_drying","B05":"louvre_observation","B06":"storyboard_loft","B07":"bookspine_PB_bay","B08":"rehearsal_stand","B09":"rhythm_machine_loft","B10":"stage_control_bridge","B12":"season_sunroom","B13":"open_map_pavilion"}.get(id,id),p,Vector2(8.4,8.4),p+Vector3(0,0,4.2),levels)

func wing_roof(wing:Dictionary,p:Vector3,size:Vector2):
	var width:float=size.x;var depth:float=size.y
	match str(wing.id):
		"BAKERY":
			roof_barrel(p+Vector3(0,3.95,0),width+1.2,depth+1.2,1.9,"a4805c")
			b.box(p+Vector3(width*.32,5,-depth*.28),Vector3(1.1,3,1.1),"9b8b77",true,0,"stone")
		"LISTENING_WEST":roof_saw(p+Vector3(0,3.95,0),width+1.1,depth+1.1,2,"6b8580")
		"LISTENING_EAST":
			roof_shed(p+Vector3(0,5.1,0),width+1.4,depth+1.4,1.6,"748a86")
			for side in [-1,1]:
				for z in [-depth*.4,depth*.4]:b.box(p+Vector3(side*width*.46,4.5,z),Vector3(.25,1.6,.25),WOOD,true,0,"wood")
		"CRAFT":
			for side in [-1,1]:roof_shed(p+Vector3(side*width*.34,3.95,0),width*.44,depth+1.2,.65,"94886a")
			roof_shed(p+Vector3(0,3.95,-depth*.36),width*.45,depth*.35,.6,"a18c6b")
		_:roof_gable(p+Vector3(0,3.95,0),width+1.2,depth+1.2,1.8)

func wing_details(wing:Dictionary,p:Vector3,size:Vector2):
	var width:float=size.x;var depth:float=size.y
	match str(wing.id):
		"BAKERY":
			for z in [-depth*.32,-depth*.05,depth*.25]:b.box(p+Vector3(width*.40,.7,z),Vector3(.65,1.4,2.1),"a89570",true,0,"wood")
		"LISTENING_WEST":
			for i in 6:
				b.box(p+Vector3(width*.42,1.4,-depth*.36+i*depth*.14),Vector3(.48,2.8,.15),"9d8f6e",true,0,"wood")
				b.box(p+Vector3(width*.42,1.6,-depth*.36+i*depth*.14+.20),Vector3(.55,.8,.08),["bdad8c","93b2a8","b8a2b7"][i%3],false,0,"fabric")
		"LISTENING_EAST":
			for side in [-1,1]:b.beam(p+Vector3(side*width*.42,3.7,-depth*.25),p+Vector3(0,5,-depth*.25),.18,WOOD)
		"CRAFT":
			b.box(p+Vector3(width*.39,.6,depth*.30),Vector3(1.1,1.2,2.0),"b3b29a",true,0,"stone")
			b.box(p+Vector3(width*.39,1.22,depth*.30),Vector3(.8,.04,1.6),"7caba6",false,0,"stone")
	flush_entry(p,3.2,depth,0,str(wing.id));flush_entry(p,3.2,depth,PI,str(wing.id)+"_REAR",1.6 if wing.id=="BAKERY" else 3.8)
	record(str(wing.id),{"BAKERY":"through_ovenhouse","LISTENING_WEST":"sleeve_gallery","LISTENING_EAST":"horn_repair_shed","CRAFT":"daylight_mosaic_court"}.get(str(wing.id),str(wing.id)),p,size,p+Vector3(0,0,depth*.5),[0.0])

func cliff_roof(h:Dictionary,p:Vector3,size:Vector2):
	var width:float=size.x;var depth:float=size.y
	match str(h.role):
		"tea":
			roof_shed(p+Vector3(0,4.5,0),width+1,depth+1,.9,"858a77")
			for i in 4:b.box(p+Vector3(-width*.35+i*width*.23,3,depth*.5+.3),Vector3(.35,1.8,.55),"8c8473",true,0,"stone")
		"lookout":
			# The open frame leaves the existing sunken sea terrace under the sky.
			roof_shed(p+Vector3(0,4.5,-depth*.20),width+1,depth*.68,.6,"7f8c7d")
			for side in [-1,1]:b.beam(p+Vector3(side*width*.47,0,depth*.4),p+Vector3(side*width*.47,4.5,depth*.4),.26,WOOD)
		"sluice":
			for x in [-3.9,3.9]:
				for z in [-3.9,3.9]:b.box(p+Vector3(x,7.2,z),Vector3(.42,5.4,.42),"a2a58e",true,0,"stone")
			roof_hip(p+Vector3(0,10,0),8.4,8.4,1.5,"73836f")
			for side in [-1,1]:
				b.box(p+Vector3(0,8.25,side*2.7),Vector3(2.2,2.2,.16),"e7d9ad",false,0,"stone")
				b.box(p+Vector3(.2,8.35,side*2.8),Vector3(.08,.9,.08),WOOD,false,0,"wood");b.box(p+Vector3(.3,8.1,side*2.8),Vector3(.8,.08,.08),WOOD,false,0,"wood")
		_:roof_gable(p+Vector3(0,4.5,0),width+1.4,depth+1.4,1.5,h.roof)

func cliff_details(h:Dictionary,p:Vector3,size:Vector2):
	var width:float=size.x;var depth:float=size.y;var high:float=float(h.upper_y)-p.y;var levels:Array=[0.0]
	match str(h.role):
		"wheel":
			for i in 4:b.box(p+Vector3(width*.41,1.35,-depth*.30+i*depth*.18),Vector3(.5,2.7,.18),"898f7a",true,0,"wood")
			b.text3d("传动机房",p+Vector3(width*.38,3.2,0),.006,"607462",-PI*.5);levels.append(high)
		"pottery":
			b.box(p+Vector3(width*.40,1.2,-depth*.30),Vector3(1.2,2.4,2.7),"a4957a",true,0,"stone")
			b.box(p+Vector3(width*.40,1.2,-depth*.18),Vector3(.75,1.25,.05),"504c40",false,0,"stone");levels.append(high)
		"tea":
			for z in [-depth*.27,depth*.17]:b.box(p+Vector3(-width*.42,.55,z),Vector3(1.0,1.1,2.2),"aca180",true,0,"wood")
		"loom":
			for i in 6:b.box(p+Vector3(width*.36,high+1.3,-depth*.27+i*.9),Vector3(.1,2.6,.5),["bca8c6","a5bdb3","d6c48d"][i%3],false,0,"fabric")
			levels.append(high)
		"sluice":
			# An internal stair reaches the roof clock gallery through a real floor opening.
			var sx:float=width*.5-1.35;var a:Vector3=p+Vector3(sx,0,depth*.5-1.25);var c:Vector3=p+Vector3(sx,high,-depth*.5+1.8);var corner:Vector3=p+Vector3(sx,high,-depth*.5+.85);var landing:Vector3=p+Vector3(0,high,-depth*.5+.85)
			load("res://scripts/bay_finishings.gd").new(w).flight(a,c,2.2);b.ramp(c,corner,1.8,"aa906c");b.ramp(corner,landing,1.8,"aa906c")
			var left:Vector3=p+Vector3(-1.3,high,0);var back:Vector3=p+Vector3(2.9,high,-depth*.5+.9)
			var guards=load("res://scripts/bay_guardrails.gd").new(w);guards.pad(p,size,false);guards.span(a,c,2.2);guards.span(c,corner,1.8);guards.span(corner,landing,1.8);guards.pad(left,Vector2(width-2.7,depth));guards.pad(back,Vector2(3.2,1.8));guards.build("Z09_clock_gallery",true)
			b.bench(left+Vector3(-.4,0,.3),PI);w.interact("ARCH110_Z09_CLOCK",left+Vector3(-.4,0,1.4),"引水钟楼观察层 · X","sit",{"seat":left+Vector3(-.4,.08,.3),"yaw":PI})
			upper_route("Z09_B5_CLOCK",str(h.id),[a,c,corner,landing,Vector3(p.x+.6,landing.y,landing.z),p+Vector3(.6,high,1.4),left+Vector3(-.4,0,1.4)],[{"center":left,"size":Vector2(width-2.7,depth),"y":left.y},{"center":back,"size":Vector2(3.2,1.8),"y":back.y}]);levels.append(high)
		"lookout":
			levels.append(-1.5)
			upper_route("Z09_B6_SUNKEN",str(h.id),[p+Vector3(0,0,5),p+Vector3(0,-1.5,10),p+Vector3(0,-1.5,8)],[{"center":p+Vector3(0,-1.5,8),"size":Vector2(16,6),"y":p.y-1.5}])
	if h.role in ["wheel","pottery","loom"]:
		var points:Array=[]
		for point in h.stairs:points.append(Vector3(point[0],point[1],point[2]))
		upper_route(str(h.id)+"_WORK_ROOF",str(h.id),points,[{"center":p+Vector3.UP*high,"size":Vector2(width+.5,depth+.5),"y":p.y+high}])
	flush_entry(p,3.2,depth,0,str(h.id))
	record(str(h.id),{"wheel":"rock_machine_workroof","pottery":"embedded_kiln_drying","tea":"deep_window_rock_tea","loom":"arcade_weaving_roof","sluice":"waterclock_observation","lookout":"framed_sunken_terrace"}.get(str(h.role),str(h.role)),p,size,p+Vector3(0,0,depth*.5),levels)

func villa_roof(index:int,p:Vector3):
	match index:
		0:
			roof_gable(p+Vector3(0,3.5,0),9.0,9.4,1.8,"aa8352",true)
			roof_shed(p+Vector3(0,3.25,4.6),8.0,1.6,.22,"b49465")
		1:
			roof_gable(p+Vector3(-2.2,3.5,0),4.8,9.1,1.6,"a58356",true)
			roof_shed(p+Vector3(1.6,3.5,-2.5),5.7,4.4,1.25,"b39262")
			b.beam(p+Vector3(-.1,3.6,1.0),p+Vector3(3.8,3.6,1.0),.18,WOOD)
		2:
			roof_shed(p+Vector3(0,3.5,0),9.1,9.0,1.7,"aa865c",.13)
			for z in [-2.7,0,2.7]:b.beam(p+Vector3(-3.8,3.5,z-.4),p+Vector3(3.8,4.9,z+.4),.19,"8f7452")
		3:
			roof_hip(p+Vector3(0,3.5,0),9.1,9.1,1.8,"ae8c60")
			roof_gable(p+Vector3(0,3.5,-3),3.4,3.3,.9,"b49a6a",true)

func villa_details(index:int,p:Vector3):
	match index:
		0:
			for side in [-1,1]:b.beam(p+Vector3(side*3.6,2.8,4.1),p+Vector3(side*3.6,2.8,9.6),.16,"a78b5d")
		1:
			# A low L around the open roof courtyard; the glass floor remains completely visible.
			b.box(p+Vector3(3.5,.45,1.8),Vector3(.45,.9,3.1),"c4b28a",true,0,"wood")
			b.box(p+Vector3(2.4,.45,3.25),Vector3(2.1,.9,.45),"c4b28a",true,0,"wood")
		2:
			for i in 4:b.box(p+Vector3(3.5,.8+i*.42,2),Vector3(.14,.12,2.0),"ab946b",false,.25,"wood")
			b.box(p+Vector3(1.0,.035,5.0),Vector3(4.5,.025,.12),"c2ad7b",false,.24,"wood")
		3:
			b.table(p+Vector3(0,0,-3.0),1.5)
			b.box(p+Vector3(-.8,1.06,-3.0),Vector3(.5,.04,.36),"dfd5b7",false,0,"fabric")
			b.box(p+Vector3(3.5,.95,.1),Vector3(.40,1.9,2.1),"b4a078",true,0,"wood")
	# A wood-to-wood side entry follows the original west branch without a terrain ramp.
	var anchor:Vector3=w.layout.hotel_branch_start(p.z);var door:Vector3=p+Vector3(-4,0,0);var inside:Vector3=p+Vector3(-3.5,0,0)
	b.box(p+Vector3(-4.1,-.12,0),Vector3(1.1,.24,2.7),"947255",true,0,"wood")
	var entries:Array=w.get_meta("entrances110",[]);entries.append({"id":"VILLA_"+str(index),"public_route":anchor,"anchor":anchor,"approach":p+Vector3(-4.8,0,0),"door":door,"inside":inside,"width":2.4,"points":[anchor,p+Vector3(-4.8,0,0),door,inside]});w.set_meta("entrances110",entries)
	record("VILLA_"+str(index),["long_sundeck_villa","L_court_villa","oblique_view_villa","sunset_study_villa"][index],p,Vector2(8.2,14.2),door,[0.0])

func coral_lobby(p:Vector3):
	var height:float=5.5
	for x in [-5.2,5.2]:
		for z in [-4,4]:b.box(p+Vector3(x,height*.5,z),Vector3(.28,height,.28),WOOD,true,0,"wood")
	roof_barrel(p+Vector3.UP*height,12.2,9.8,2,"a2865b")
	var level:float=2.9;var guards=load("res://scripts/bay_guardrails.gd").new(w)
	for side in [-1,1]:
		var at:Vector3=p+Vector3(side*4.7,level,0);slab(at,Vector2(2,9),"aa8c60");guards.pad(at,Vector2(2,9))
		at=p+Vector3(0,level,side*3.5);slab(at,Vector2(9.6,2),"aa8c60");guards.pad(at,Vector2(9.6,2))
	var reading_bay:Vector3=p+Vector3(-3.1,level,-.6);slab(reading_bay,Vector2(2.8,3.0),"aa8c60");guards.pad(reading_bay,Vector2(2.8,3.0))
	# The upper ring starts at z=-2.5. Finish the flight before its edge,
	# continue straight into the ring, then turn across the back gallery.
	var a:Vector3=p+Vector3(2.4,0,2.2);var c:Vector3=p+Vector3(2.4,level,-2.45);var corner:Vector3=p+Vector3(2.4,level,-3.5)
	load("res://scripts/bay_finishings.gd").new(w).flight(a,c,2.1);b.ramp(c,corner,2.1,"aa8c60");guards.span(a,c,2.1);guards.span(c,corner,2.1);guards.pad(p,Vector2(11.4,9),false);guards.build("coral_lobby_gallery",true)
	b.bench(reading_bay,PI*.5);w.interact("ARCH110_CORAL_LOBBY_VIEW",p+Vector3(-4.3,level,-.6),"珊瑚大堂环廊 · X","sit",{"seat":reading_bay+Vector3.UP*.08,"yaw":PI*.5})
	upper_route("CORAL_LOBBY_RING","ISLAND_LOBBY",[a,c,corner,p+Vector3(-4.7,level,-3.5),p+Vector3(-4.7,level,-.6)],[{"center":p+Vector3(0,level,-3.5),"size":Vector2(9.6,2),"y":p.y+level},{"center":p+Vector3(-4.7,level,0),"size":Vector2(2,9),"y":p.y+level}])
	var anchor:Vector3=w.layout.hotel_branch_start(p.z+2.6)
	# The crescent boardwalk enters this open pavilion from the east, not its
	# unsupported west edge. Both sides of this shared portal are on the real slab.
	var door:=Vector3(anchor.x,p.y,anchor.z);var inside:Vector3=door-Vector3(1,0,0)
	var entries:Array=w.get_meta("entrances110",[]);entries.append({"id":"ISLAND_LOBBY","public_route":anchor,"anchor":anchor,"approach":anchor,"door":door,"inside":inside,"width":2.8,"points":[anchor,door,inside]});w.set_meta("entrances110",entries)
	record("ISLAND_LOBBY","high_coral_ring_lobby",p,Vector2(11.4,9),door,[0.0,level])

# Root-owned bay_authoring can call these additions after retaining its original landmark.
func landmark_entry(id:String,p:Vector3,size:Vector2,yaw:float=0.0):
	flush_entry(p,3.0,size.y,yaw,id)
	record(id,"retained_landmark",p,size,p+Basis(Vector3.UP,yaw)*Vector3(0,0,size.y*.5),[0.0])
