extends RefCounted
## Bay world: all authored objects use the same layout and actual supporting terrain.
var w
var b
var layout
var rng:=RandomNumberGenerator.new()
var pockets:Array=[]

func _init(target):w=target;b=w.b;layout=w.layout;rng.seed=6182026
func p(x:float,z:float,up:float=0)->Vector3:return w.surface(x,z,up)
func action(id:String,at:Vector3,title:String,kind:String,data:Dictionary={}):w.interact(id,at,title,kind,data)

func build():
	w.build_terrain()
	for segment in layout.segments:
		var a:Vector3=segment.a;var c:Vector3=segment.c
		if str(segment.id).begins_with("z09"):
			b.ramp(a,c,segment.width,"c9b695")
		elif segment.bridge:
			bridge(a,c,segment.width,segment.id=="mouth_bridge")
			if segment.id in ["mouth_bridge","valley_arch","garden_bridge"] or "navigable" in segment.id:stone_arch(a,c,segment.width,3 if segment.id=="mouth_bridge" else 1)
		else:w.path_between(Vector2(a.x,a.z),Vector2(c.x,c.z),segment.width,"cbbc9b" if a.z> -150 else "b5ad91")
	plaza()
	for item in w.spec.buildings:preload("res://scripts/buildings.gd").new().build(w,item)
	waterways()
	coast()
	landmarks()
	preload("res://scripts/bay_expansion.gd").new(w).build()
	preload("res://scripts/bay_sea_walk.gd").new(w).build()
	preload("res://scripts/bay_village_authoring.gd").new(w).build()
	preload("res://scripts/bay_finishings.gd").new(w).landscape()
	pocket_gardens()
	preload("res://scripts/bay_audit_finishings.gd").new(w).creek_tea()
	preload("res://scripts/world_design120.gd").new(w).creek_entry()
	for zone in w.spec.zones:
		var safe:Vector3=layout.safe_point(zone.id)
		var at:Vector3=p(safe.x+2.5,safe.z)
		w.path_between(Vector2(safe.x,safe.z),Vector2(at.x,at.z),2.6,"cbbc9b")
		b.box(at+Vector3(0,0.8,0),Vector3(1.1,1.6,0.65),"58796f",true)
		b.text3d(zone.name+"\n区域纪念章",at+Vector3(0,1.3,0.35),0.0065)
		action(zone.id,at+Vector3(0,0,1.2),"领取 · "+zone.name+"纪念章","stamp",zone)
	legacy_seats()
	preload("res://scripts/bay_redesign_authoring.gd").new(w).build()
	preload("res://scripts/bay_dual106_authoring.gd").new(w).build()
	preload("res://scripts/world_design120.gd").new(w).build()
	preload("res://scripts/outdoor_design120.gd").new(w).build()
	activity_stations()
	planting()
	preload("res://scripts/architecture120.gd").new(w).consolidate_labels()
	preload("res://scripts/bay_finishings.gd").new(w).limit_room_lights()
	b.finish()
	w.setup_ambience()
	w.set_meta("bay_v1",{"revision":"bay_v1","venues":13,"zones":w.spec.zones.size(),"shore":"double headland, lagoon and connected rivers","route_segments":layout.segments.size(),"pockets":pockets.size()})
	print("BAY_WORLD_BUILT ",JSON.stringify({"boxes":b.box_count,"colliders":b.collision_count,"interactions":w.interactions.size(),"buildings":w.building_bounds.size()}))

func bridge(a:Vector3,c:Vector3,width:float,dock_access:bool=false):
	w.reserve_path(Vector2(a.x,a.z),Vector2(c.x,c.z),width)
	b.ramp(a+Vector3(0,0.1,0),c+Vector3(0,0.1,0),width,"b6a080")
	var side:Vector3=Vector3(-(c-a).z,0,(c-a).x).normalized()
	var pieces:int=maxi(2,ceili(a.distance_to(c)/3))
	for i in pieces+1:
		var at:Vector3=a.lerp(c,float(i)/pieces)
		for sign in [-1,1]:
			var edge:Vector3=at+side*(width*0.5-0.05)*sign
			if dock_access and sign==-1 and absf(edge.x-298)<2.0:continue
			if new_street_portal(edge):continue
			b.box(edge+Vector3(0,0.65,0),Vector3(0.17,1.3,0.17),"6e786a",true)
			if i%3==0:
				var low:float=minf(at.y-0.5,w.height_at(edge.x,edge.z))
				b.box(Vector3(edge.x,(low+at.y)*0.5,edge.z),Vector3(0.6,maxf(0.5,at.y-low),0.6),"a3a28b",false,0,"stone")
	for sign in [-1,1]:
		var start:Vector3=a+side*(width*.5)*sign
		var end:Vector3=c+side*(width*.5)*sign
		var rail_pieces:int=maxi(2,ceili(start.distance_to(end)/1.2))
		for i in rail_pieces:
			var p:Vector3=start.lerp(end,float(i)/rail_pieces)
			var q:Vector3=start.lerp(end,float(i+1)/rail_pieces)
			var mid:Vector3=(p+q)*.5
			if dock_access and sign==-1 and absf(mid.x-298)<2.5:continue
			if new_street_portal(mid):continue
			preload("res://scripts/bay_finishings.gd").new(w).rail(p,q)
	for i in int(a.distance_to(c)/0.65):
		var at:Vector3=a.lerp(c,float(i)/maxi(1,int(a.distance_to(c)/0.65)))
		b.oriented_box(at+Vector3(0,0.17,0),Vector3(width,0.035,0.06),"8e7b60",Basis(Vector3.UP,atan2((c-a).x,(c-a).z)),false,"wood")

func new_street_portal(p:Vector3)->bool:
	# Annex ground floors are open, supported rooms. A pre-existing bridge through
	# one shares that floor rather than drawing a railing across the room's entrance.
	for annex in layout.config.get("annexes",{}).values():
		var y:float=float(annex.center[1])+float(layout.config.sea_y)
		if absf(p.y-y)<.4 and absf(p.x-annex.center[0])<float(annex.get("width",8.4))*.5-.15 and absf(p.z-annex.center[2])<float(annex.get("depth",8.4))*.5-.15:return true
	# This tea-stop connection leaves the old valley bridge through its south side.
	# It is built by creek_entry(), at the bridge's own floor height.
	var tea_a:=Vector3(-192.6,3.3,-194);var tea_c:=Vector3(-192.6,3.3,-189.7)
	var tea_near:Vector2=Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),Vector2(tea_a.x,tea_a.z),Vector2(tea_c.x,tea_c.z))
	if absf(p.y-tea_a.y)<.4 and tea_near.distance_to(Vector2(p.x,p.z))<1.7:return true
	for road in layout.near(layout.road_index,Vector2(p.x,p.z)):
		if road.bridge:continue
		var q:Vector3=layout.projection(Vector2(p.x,p.z),road)
		if Vector2(q.x-p.x,q.z-p.z).length()<road.width*.5+.65 and absf(q.y-p.y)<.40:return true
	return false

func stone_arch(a:Vector3,c:Vector3,width:float,spans:int):
	var along:Vector3=(c-a).normalized();var side:=Vector3(-along.z,0,along.x)
	var length:float=a.distance_to(c)/spans
	for span in spans:
		var center:Vector3=a.lerp(c,(float(span)+.5)/spans)
		var radius:float=length*.5-.45
		var rise:float=minf(3.8,maxf(1.8,center.y+2.4-.8))
		for flank in [-1,1]:
			for i in 16:
				var angle:float=PI*(float(i)+.5)/16
				var p:Vector3=center+along*(cos(angle)*radius)+side*(width*.5+.18)*flank
				p.y=center.y-rise-.4+sin(angle)*rise
				var tangent:Vector3=(-along*sin(angle)*radius+Vector3.UP*cos(angle)*rise).normalized()
				var basis:=Basis(tangent,side.cross(tangent).normalized(),side)
				b.oriented_box(p,Vector3(length/16+.08,.65,.65),"c8b89b" if i%3 else "b6a78e",basis,true,"stone")

func plaza():
	var y:float=layout.height_at(Vector2(0,80))
	# Four physical slabs leave the reflecting basin open; its bed is a safe shallow depression.
	for side in [-1,1]:b.box(Vector3(side*29.5,y+.03,80),Vector3(41,.12,90),"e2d5c1",true)
	b.box(Vector3(0,y+.03,43),Vector3(18,.12,16),"e2d5c1",true)
	b.box(Vector3(0,y+.03,91),Vector3(18,.12,68),"e2d5c1",true)
	b.box(Vector3(0,y-.25,54),Vector3(18,.16,6),"b6ab94",true)
	for x in range(-48,49,4):b.box(Vector3(x,y+0.105,80),Vector3(0.04,0.02,88),"c8bca5")
	for z in range(36,125,4):b.box(Vector3(0,y+0.105,z),Vector3(98,0.02,0.04),"c8bca5")
	var width:float=16.0*4579.0/6146.0
	b.box(Vector3(0,y+0.4,40),Vector3(width+6,0.8,7),"c1b499",true)
	b.box(Vector3(0,y+10.3,38),Vector3(width+1.8,19,2.5),"e2d5c1",true)
	b.box(Vector3(0,y+10.5,39.32),Vector3(width+0.5,16.6,0.18),"596765")
	b.picture("res://assets/media/portrait_01.jpg",Vector3(0,y+10.5,39.44),16.0)
	for x in [-width*0.5-0.7,width*0.5+0.7]:
		b.box(Vector3(x,y+10.4,39.1),Vector3(0.75,19.3,2.6),"f4efe6",true)
		for yy in [2,7,12,17]:b.box(Vector3(x,y+yy,40.5),Vector3(0.95,0.18,0.2),"bec6c3")
	b.box(Vector3(0,y+20,38.9),Vector3(width+3.5,0.6,3.8),"f4efe6")
	b.text3d("鞠 婧 祎",Vector3(0,y+1.55,42.6),0.023,"435855")
	b.text3d("星 光 在 此 相 逢",Vector3(0,y+0.65,43.1),0.009,"5f7069")
	action("L01",Vector3(0,y+0.3,69),"巨幅肖像 · 查看作品与来源","photo",{"index":0})
	action("P01",Vector3(0,y+0.2,81),"星光合影位 · 拍照","photo_mode")
	for side in [-1,1]:
		for zz in [64,102]:
			var at:=Vector3(side*32,y,zz)
			pergola(at,Vector2(13,10));b.planter(at+Vector3(side*5,0,0),4)
			b.bench(at+Vector3(0,0,-2),PI)
		b.lamp(Vector3(side*24,y,117))
	action("Z04_REST",Vector3(-32,y,105),"广场廊下 · 休息","sit",{"seat":Vector3(-32,y+0.08,100),"yaw":PI})

func waterways():
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in layout.river_segments:
		var a:Vector3=r.a;var c:Vector3=r.c
		var side:=Vector3(-(c-a).z,0,(c-a).x).normalized()*float(r.width)*0.5
		for index in [0,1,2,0,2,3]:
			var points:Array=[a-side,a+side,c+side,c-side]
			st.add_vertex(points[index])
	st.generate_normals();var river:=MeshInstance3D.new();river.name="BayConnectedRivers";river.mesh=st.commit()
	var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/coastal_water.gdshader");set_water_curve(material);river.material_override=material;w.add_child(river)
	for zz in [-285.0,-225.0,-70.0,180.0]:
		var best:Vector3=Vector3.ZERO;var dist:float=INF
		for segment in layout.river_segments:
			if segment.id!="east":continue
			var q:Vector3=layout.projection(Vector2(310,zz),segment)
			if absf(q.z-zz)<dist:dist=absf(q.z-zz);best=q
		var a:Vector3=p(best.x-22,zz,0.2);var c:Vector3=p(best.x+22,zz,0.2)
		var y:float=maxf(maxf(a.y,c.y),best.y+1.8);a.y=y;c.y=y
		bridge(a,c,4.8)
		for endpoint in [a,c]:
			var land:Vector3=p(endpoint.x+(-8.0 if endpoint.x<best.x else 8.0),zz,0.1)
			b.ramp(land,endpoint,4.8,"b6a080")
	# Falling water is exactly the steep reach of the connected channel.
	for dx in [-3,-1,1,3]:
		var a:Vector3=layout.vector([311+dx,55,-330]);var c:Vector3=layout.vector([315+dx,35,-320])
		b.beam(a,c,0.8,"b4d7ca")
	for zz in range(-380,283,11):
		var point:=Vector2(310+14*sin(zz*0.016),zz)
		for side in [-1,1]:
			var at:Vector3=p(point.x+side*11,point.y)
			b.shape(at+Vector3(0,0.35,0),Vector3(2.6,1.2,2),"8e9d83","rock")

func coast():
	# Long supported pier, connected to the coastal loop by a gentle real ramp.
	var head:=Vector3(0,-1.0,304);var tail:=Vector3(0,-1.0,367)
	b.ramp(layout.vector([0,3.5,276]),head,5.5,"b9a17b")
	bridge(head,tail,6.5)
	for z in [320.0,342.0,361.0]:
		b.bench(Vector3(-1.9,-0.83,z),-PI*0.5)
	action("N02_DECK",Vector3(0,-0.7,350),"海岸长栈桥 · 看海","sit",{"seat":Vector3(-1.9,-0.8,342),"yaw":-PI*0.5})
	action("N02_SEAT",p(-35,282),"听涛木亭 · 落座","sit",{"seat":p(-35,282,0.08),"yaw":PI})
	pergola(p(-35,282),Vector2(9,7));b.bench(p(-35,282))
	for x in [-190,-70,60,170]:
		var z:float=layout.shore_z(x)-12
		var at:Vector3=p(x,z)
		b.box(at+Vector3(0,0.12,0),Vector3(6,0.24,4),"cab58c",true)
		b.bench(at+Vector3(0,0.24,-1))
		pockets.append(at)
	var cape:Vector3=layout.vector([-375,7,378]);pergola(cape,Vector2(9,7));b.bench(cape+Vector3(0,0,1))
	action("ADD_CAPE_VIEW",cape+Vector3(0,0,2),"西岬木亭 · 留影","photo_mode")
	var light:Vector3=layout.vector([360,12,383])
	preload("res://scripts/world_design120.gd").new(w).lighthouse(light)
	action("ADD_LIGHTHOUSE_VIEW",light+Vector3(0,0,5),"东岬灯塔 · 留影","photo_mode")

func pergola(at:Vector3,size:Vector2):
	for x in [-size.x*0.5,size.x*0.5]:
		for z in [-size.y*0.5,size.y*0.5]:b.box(at+Vector3(x,1.65,z),Vector3(0.25,3.3,0.25),"6d5741",true)
	for x in range(-int(size.x*0.5),int(size.x*0.5)+1):b.box(at+Vector3(x,3.35,0),Vector3(0.18,0.25,size.y+1),"9e8862")
	b.box(at+Vector3(0,3.12,-size.y*0.5),Vector3(size.x+1,0.22,0.24),"5e4232")

func landmarks():
	var top:Vector3=layout.vector([0,72.53,-385])
	b.box(top+Vector3(0,0.08,0),Vector3(30,0.16,19),"d2c3a5",true)
	for side in [-1,1]:b.box(top+Vector3(side*14.6,0.7,0),Vector3(0.22,1.4,19),"8c8972",true)
	b.box(top+Vector3(0,0.7,-9.2),Vector3(30,1.4,0.22),"8c8972",true)
	for x in [-8,8]:b.bench(top+Vector3(x,0.12,1))
	action("N08_TOP",top+Vector3(0,0.3,5),"山海观景台 · 合影","photo_mode")
	var tea:Vector3=layout.vector([-20,73.5,-396]);pergola(tea,Vector2(13,10))
	# Tea is reached around the open south edge; summit guardrails remain intact.
	b.box(tea+Vector3(0,3.5,0),Vector3(14,0.25,11),"4a5d6b")
	for x in [-3,3]:
		b.box(tea+Vector3(x,.04,1.4),Vector3(2.5,.08,2.6),"a4ab7e",false,0,"fabric")
		for z in [.2,2.6]:b.box(tea+Vector3(x,.09,z),Vector3(2.5,.025,.09),"5e6950",false,0,"fabric")
		b.table(tea+Vector3(x,0,-.3),1.6)
		b.box(tea+Vector3(x,.13,1.5),Vector3(.9,.18,.8),"c2a88b",false,0,"fabric")
		action("ADD_TEA_SEAT_"+str(x),tea+Vector3(x,0,2.5),"榻榻米茶席 · X 静坐观海","sit",{"seat":tea+Vector3(x,.02,1.5),"yaw":PI})
	b.text3d("云间茶寮",tea+Vector3(0,2.8,5.1),0.014,"eee6d0")
	action("ADD_TEA_BREW",tea+Vector3(0,0,3),"茶寮 · 选茶与注水","bay_activity",{"activity":"tea"})
	preload("res://scripts/architecture120.gd").new(w).landmark_entry("SUMMIT_TEA",tea,Vector2(13,10))
	var stage:Vector3=layout.vector([-217,9.5,111])
	preload("res://scripts/courts_art.gd").new(w).stage(stage+Vector3(0,-.4,0))
	b.box(stage+Vector3(0,0.2,0),Vector3(17,0.4,9),"b8ac91",true)
	b.ramp(p(stage.x,stage.z+10,0.05),stage+Vector3(0,0.4,4.5),4,"b8ac91")
	action("N09_STAGE",stage+Vector3(0,0,7),"海风小舞台 · 听一段音乐","audio")
	var set:Vector3=layout.vector([165,29,-264])
	preload("res://scripts/courts_art.gd").new(w).courtyard(set)
	action("N10_SET",set+Vector3(0,0,5),"原创光影庭院 · 取景","photo_mode")
	action("N07_VIEW",layout.vector([285,41,-302]),"瀑布观景 · 记录风景","photo_mode")

func pocket_gardens():
	for item in w.spec.buildings:
		var at:Vector3=p(item.x-item.w*0.5-4,item.z+item.d*0.5+3)
		b.planter(at,2.6,["cfb6c8","e0bf8e","b1c391"][int(item.id.trim_prefix("B"))%3])
		if item.id not in ["B05","B06","B12"] and w.clear_of_paths(Vector2(at.x-2,at.z-2),1.8):b.bench(at+Vector3(-2,0,-2),PI*0.5)
		pockets.append(at)
	for segment in layout.segments:
		if segment.bridge:continue
		var n:int=int(segment.a.distance_to(segment.c)/42)
		var side:Vector3=Vector3(-(segment.c-segment.a).z,0,(segment.c-segment.a).x).normalized()
		for j in n:
			var q:Vector3=segment.a.lerp(segment.c,float(j+1)/float(n+1))+side*(segment.width*0.5+3)
			if not plantable(Vector2(q.x,q.z),1):continue
			var at:Vector3=p(q.x,q.z)
			if q.z> -180:b.lamp(at)
			else:b.shape(at+Vector3(0,0.5,0),Vector3(1.6,1.2,1.3),"8b987c","rock")
			if j%2==0:b.bench(at+side*3,atan2(side.x,side.z))
			pockets.append(at)

func legacy_seats():
	var sites:Array=[[-232,-224],[-255,-230],[-255,-253],[-231,-261],[-215,-246],[-216,-230],[-261,-207],[-264,-242]]
	var overrides:Dictionary={"Z05_GARDEN_SEAT":[-270,59],"Z06_READ_SEAT":[213,-279],"N04_RIVER_SEAT":[290,-70],"N01_GARDEN_SEAT":[285,220],"N05_SHADE_SEAT":[-250,-225],"N08_SEAT_W":[-8,-384],"N08_SEAT_E":[8,-384],"N09_LIGHT":[-209,119]}
	var records:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_actions_095.json"))
	var i:int=0
	for old in records:
		if w.interactions.any(func(v):return v.id==old.id):continue
		if str(old.id).begins_with("B"):
			push_error("Missing legacy venue function "+str(old.id));continue
		var site:Array=overrides.get(old.id,sites[i%sites.size()]);i+=1
		var at:Vector3=p(site[0],site[1]);var data:Dictionary=old.data.duplicate(true)
		if old.kind=="sit":
			b.bench(at);data.seat=at+Vector3(0,0.08,0);data.yaw=PI
			action(old.id,at+Vector3(0,0,1.5),old.title,old.kind,data)
		else:action(old.id,at,old.title,old.kind,data)

func activity_stations():
	var descriptors:Dictionary={"B01":["arrival",[0,0,3]],"B02":["drink",[-5,0,-1]],"B03":["playlist",[0,0,-2.4]],"B04":["flowers",[-3,0,0]],"B05":["exhibition",[0,0,5]],"B06":["cinema",[0,0,9]],"B07":["journal",[0,0,2]],"B08":["rhythm",[0,0,1]],"B09":["mix",[-4,0,1]],"B10":["show",[11,0,6]],"B11":["craft",[0,0,2]],"B12":["decorate",[0,0,1]],"B13":["itinerary",[-4,0,2]]}
	for id in descriptors:
		var item:Dictionary=layout.venues[id];var local:Array=descriptors[id][1]
		var at:=Vector3(item.x+float(local[0]),item.floor_y+float(local[1])+0.1,item.z+float(local[2]))
		action("ADD_"+id+"_ACT",at,"生活互动 · "+item.subtitle,"bay_activity",{"activity":descriptors[id][0],"venue":id})
	for record in JSON.parse_string(FileAccess.get_file_as_string("res://data/life_media_bay.json")):
		var v:Dictionary=layout.venues[record.venue]
		var album_id:String="ADD_ALBUM_"+record.venue
		if w.interactions.any(func(a):return a.id==album_id):continue
		action(album_id,Vector3(v.x+3,v.floor_y+.1,v.z+2),"生活与工作相册","bay_album",{"venue":record.venue})
	for i in layout.config.docks.size():
		var at:Vector3=layout.vector(layout.config.docks[i]);b.box(at,Vector3(8,0.14,5),"d0c2a7",true)
		b.text3d("山海慢行 · 双车停靠",at+Vector3(0,2.1,-2),0.007,"4e695d")
		for kind in ["bike","scooter"]:action("VEHICLE_"+str(i)+"_"+kind,at+Vector3(-2 if kind=="bike" else 2,0,0),"藤篮自行车" if kind=="bike" else "奶油代步车","bay_vehicle",{"vehicle":kind,"dock":i})
	for kind in ["shell","pinecone","flower"]:
		for i in 8:
			var x:float=-160+i*40 if kind=="shell" else -165+i*35 if kind=="pinecone" else -232+(i%4)*6
			var z:float=layout.shore_z(x)-6 if kind=="shell" else -280-(i%3)*12 if kind=="pinecone" else -208-(i/4)*6
			var at:Vector3=p(x,z)
			b.shape(at+Vector3(0,0.12,0),Vector3(0.4,0.22,0.4),"e2c9ac" if kind=="shell" else "82654a" if kind=="pinecone" else "d1a9c5","shrub")
			action("ADD_PICK_"+kind+str(i),at,"拾取 · "+{"shell":"贝壳","pinecone":"松果","flower":"花材"}[kind],"bay_pick",{"material":kind})
	var beach:Vector3=p(72,layout.shore_z(72)-9)
	action("ADD_SAND",beach,"沙景小桌 · 摆一座沙堡","bay_activity",{"activity":"sand"})

func plantable(q:Vector2,margin:float)->bool:
	for record in layout.near(layout.creative_index,q):
		var place:Dictionary=record.place
		if absf(q.x-place.center[0])<place.size[0]*.5+margin+2 and absf(q.y-place.center[2])<place.size[1]*.5+margin+2:return false
	if absf(q.x+225)<29.5 and absf(q.y+177)<24.5:return false
	if q.x>220 and q.x<355 and q.y> -50 and q.y<112:return false
	if not w.clear_of_paths(q,margin):return false
	if absf(q.x)<19 and q.y>35 and q.y<133:return false
	for terrace in layout.config.terraces:
		if absf(q.x-terrace.center[0])<terrace.size[0]*0.5+3 and absf(q.y-terrace.center[1])<terrace.size[1]*0.5+3:return false
	for item in w.spec.buildings:
		if absf(q.x-item.x)<item.w*0.5+8 and absf(q.y-item.z)<item.d*0.5+12:return false
	if w.height_at(q.x,q.y)< -1.8:return false
	return true

func planting():
	for i in 4900:
		var q:=Vector2(rng.randf_range(-455,455),rng.randf_range(-440,305))
		if not plantable(q,3.6):continue
		var biome:String=w.terrain_art.biome(q)
		if biome in ["river","sand","coast"]:continue
		var patch:float=0.5+0.5*sin(q.x*0.027+sin(q.y*0.023)*1.3)*cos(q.y*0.031)
		if rng.randf()>(0.32+patch*0.5 if q.y< -135 else 0.16):continue
		var kind:int=0 if q.y< -300 else 1 if q.y< -160 else 2 if i%8==0 else i%3
		b.tree(p(q.x,q.y),kind,rng.randf_range(0.75,1.5))
	# Deliberate mid-distance woodland groups, with protected outlook gaps.
	for site in [[-320,-170],[-150,-80],[90,-135],[330,-170],[-300,-300],[150,-330]]:
		for i in 42:
			var angle:float=i*2.399;var radius:float=sqrt(float(i))*3.3
			var q:=Vector2(site[0]+cos(angle)*radius,site[1]+sin(angle)*radius*.8)
			if plantable(q,4):b.tree(p(q.x,q.y),0 if q.y> -200 else 1,rng.randf_range(.95,1.55))
	for i in 4600:
		var q:=Vector2(rng.randf_range(-440,440),rng.randf_range(-430,315))
		if not plantable(q,1.3):continue
		var at:Vector3=p(q.x,q.y)
		if at.y< -1.3:continue
		var size:float=rng.randf_range(0.4,1.6)
		if i%5==0:b.shape(at+Vector3(0,size*0.25,0),Vector3(size,size*0.5,size*0.8),"88947e","rock")
		else:b.shape(at+Vector3(0,size*0.28,0),Vector3(size,size*0.56,size*0.8),["728b56","8d9e63","a0aa73","688665"][i%4],"shrub")

func set_water_curve(material:ShaderMaterial):
	var points:=PackedVector2Array()
	for point in layout.config.shore:points.append(Vector2(point[0],point[1]))
	while points.size()<24:points.append(Vector2(10000,344))
	material.set_shader_parameter("shore_count",mini(layout.config.shore.size(),24));material.set_shader_parameter("shore_points",points)
