extends RefCounted
## Rooted talus and habitat groups finish existing landforms without changing ground or routes.
var w
var b
var ecology
var cover
var rng:=RandomNumberGenerator.new()
var records:Array=[]
var selected:Array[Vector2]=[]
var rocks:=0
var ferns:=0
var grass:=0
var moss:=0
var trunk_cells:Dictionary={}

func _init(target):
	w=target;b=w.b
	ecology=preload("res://scripts/ecology_detail.gd").new(w)
	cover=preload("res://scripts/groundcover_art.gd").new(w)
	# Existing timber instances are indexed once; candidate placement never scans all batches.
	for key in b.batches:
		if not str(key).ends_with("_box_wood"):continue
		for module in b.batches[key]:
			var t:Transform3D=module[0];var size:Vector3=t.basis.get_scale()
			if size.y<2.0 or size.x>1.5 or size.z>1.5:continue
			var cell:=Vector2i(floori(t.origin.x/8),floori(t.origin.z/8))
			if not trunk_cells.has(cell):trunk_cells[cell]=[]
			trunk_cells[cell].append(Vector2(t.origin.x,t.origin.z))

func placeable(point:Vector2,half:Vector2,margin:float=1.2)->bool:
	if not ecology.clear(point,margin+maxf(half.x,half.y)):return false
	# Protect the maintained path skirts and every already-built tree trunk.
	if w.terrain_art.road_clearance(point)<0.7:return false
	var cell:=Vector2i(floori(point.x/8),floori(point.y/8))
	for x in range(cell.x-1,cell.x+2):
		for z in range(cell.y-1,cell.y+2):
			for trunk in trunk_cells.get(Vector2i(x,z),[]):
				if point.distance_to(trunk)<1.0+half.length():return false
	for used in selected:
		if point.distance_to(used)<0.9+maxf(half.x,half.y):return false
	var base:float=w.height_at(point.x,point.y)
	var reach:float=half.length()
	for offset in [Vector2(-reach,-reach),Vector2(reach,-reach),Vector2(reach,reach),Vector2(-reach,reach)]:
		if absf(w.height_at(point.x+offset.x,point.y+offset.y)-base)>0.12:return false
	return true

func record(point:Vector2,half:Vector2,kind:String,group:String):
	selected.append(point)
	records.append({"x":point.x,"z":point.y,"ground_y":w.height_at(point.x,point.y),"half":[half.x,half.y],"kind":kind,"group":group})

func stone(point:Vector2,scale:float,wet:bool,group:String)->bool:
	var half:=Vector2(0.67,0.53)*scale
	if not placeable(point,half):return false
	var height:float=0.44*scale
	var base:Vector3=w.surface(point.x,point.y)
	var palette:Array=["6b7c75","83958a","9aa593"] if wet else ["8b907c","a0a28c","777f77"]
	b.shape(base+Vector3(0,height*0.28,0),Vector3(half.x*2,height,half.y*2),palette[rng.randi()%3],"rock",rng.randf()*PI)
	if scale>0.8:
		# A small flat moss cap has the same support as the embedded stone; no floating patch.
		b.box(base+Vector3(-0.08,height*0.53,0.03),Vector3(0.28*scale,0.025,0.23*scale),"738367" if wet else "899573",false,0,"leaf")
		moss+=1
	rocks+=1;record(point,half,"wet_stone" if wet else "talus",group);return true

func fern(point:Vector2,scale:float,group:String)->bool:
	var half:=Vector2(0.43,0.43)*scale
	if not placeable(point,half):return false
	var base:Vector3=w.surface(point.x,point.y)
	var yaw:float=rng.randf()*TAU
	for i in 4:
		var angle:float=yaw+i*1.57
		var end:Vector3=base+Vector3(sin(angle)*0.39,0.20,cos(angle)*0.39)*scale
		b.beam(base,end,0.024,"61775c")
		for t in [0.48,0.72,0.90]:
			var center:Vector3=base.lerp(end,t)
			b.box(center,Vector3((1.0-t)*0.41,0.035,0.10)*scale,"7d8d6b" if i%2 else "849577",false,angle,"leaf")
	ferns+=1;record(point,half,"fern",group);return true

func tuft(point:Vector2,wet:bool,group:String)->bool:
	var half:=Vector2(0.30,0.30)
	if not placeable(point,half):return false
	cover.clump(w.surface(point.x,point.y),rng.randf_range(0.30,0.47) if wet else rng.randf_range(0.17,0.30),"wind" if wet else "forest")
	grass+=1;record(point,half,"riparian_grass" if wet else "forest_grass",group);return true

func road_shoulders(spacing:float)->Array:
	var groups:Array=[]
	for route in w.path_corridors:
		var a:Vector2=route.a;var c:Vector2=route.c
		if minf(a.y,c.y)>-175 or minf(a.y,c.y)<-389:continue
		if float(route.width)<3.0 or a.distance_to(c)<16.0:continue
		var direction:Vector2=(c-a).normalized();var side:Vector2=direction.orthogonal()
		var actual:=0
		var id:="shoulder_"+str(groups.size())
		for i in maxi(1,floori(a.distance_to(c)/spacing)):
			var t:float=(i+0.45)/maxi(1,floori(a.distance_to(c)/spacing))
			var center:Vector2=a.lerp(c,t)
			var sign:float=1.0 if (i+groups.size())%3 else -1.0
			var point:Vector2=center+side*sign*(float(route.width)/2+4.2+rng.randf()*1.2)
			if absf(point.x-(307+18*sin(point.y*0.014)))<33:continue
			if stone(point,rng.randf_range(0.54,0.88),false,id):actual+=1
			if i%2==0 and tuft(point+side*sign*1.8,false,id):actual+=1
		if actual>0:groups.append({"id":id,"kind":"mountain_road_shoulder","actual":actual})
	return groups

func forest_pockets(config:Array)->Array:
	var groups:Array=[]
	for pocket in config:
		var center:=Vector2(pocket.center[0],pocket.center[1]);var radii:=Vector2(pocket.radii[0],pocket.radii[1]);var actual:=0
		for i in int(pocket.count):
			var angle:float=rng.randf()*TAU;var radius:float=sqrt(rng.randf())
			if radius>0.78+0.13*sin(angle*3.0):continue
			var point:Vector2=center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y)*radius
			var placed:bool=stone(point,rng.randf_range(0.58,1.05),false,pocket.id) if i%5==0 or str(pocket.id).contains("summit") else (fern(point,rng.randf_range(0.65,0.96),pocket.id) if i%3==0 else tuft(point,false,pocket.id))
			if placed:actual+=1
		groups.append({"id":pocket.id,"zone":pocket.zone,"kind":"forest_floor","actual":actual})
	return groups

func riparian_pockets(config:Array)->Array:
	var groups:Array=[]
	for pocket in config:
		var actual:=0;var side:float=float(pocket.side)
		for i in int(pocket.count):
			var z:float=float(pocket.z)+rng.randf_range(-0.5,0.5)*float(pocket.length)
			var river_x:float=307+18*sin(z*0.014)
			var water:float=w.land_height(river_x,z)-1.5-w.river_drop(z)
			var point:=Vector2.ZERO;var found:=false
			# Select the actual wet shelf of each differently carved bank, not a fixed-width row.
			for offset in [14.0,17.0,20.0,23.0,26.0]:
				var q:=Vector2(river_x+side*(offset+rng.randf_range(-0.8,0.8)),z)
				var h:float=w.height_at(q.x,q.y)
				if h>=water-0.45 and h<=water+1.6 and placeable(q,Vector2(0.32,0.32)):
					point=q;found=true;break
			if not found:continue
			var placed:=false
			if i%3==0:placed=stone(point,rng.randf_range(0.58,0.86),true,pocket.id)
			elif w.height_at(point.x,point.y)>=water+0.10:placed=tuft(point,true,pocket.id)
			if placed:actual+=1
		groups.append({"id":pocket.id,"zone":pocket.zone,"kind":"riparian_shelf","actual":actual})
	return groups

func build():
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/landform_details_088.json"))
	rng.seed=int(config.seed);cover.rng.seed=int(config.seed)+321
	var start:int=b.box_count
	var groups:Array=road_shoulders(float(config.shoulder_spacing_m))
	groups.append_array(forest_pockets(config.forest_pockets));groups.append_array(riparian_pockets(config.riparian_pockets))
	w.set_meta("landform_details_088",{"seed":config.seed,"groups":groups,"records":records,"rocks":rocks,"ferns":ferns,"grass_clumps":grass,"moss_caps":moss,"modules":b.box_count-start,"colliders_added":0,"scope":config.scope})
