extends RefCounted
## Authored groves frame the retained routes. Variable gaps keep understory and outlooks readable.
var w
var b
var ecology
var art=preload("res://scripts/vegetation_art.gd").new()
var occupied:Dictionary={}
var planted:Array=[]
var summaries:Array=[]
const BUCKET=12.0

func _init(world):
	w=world;b=w.b;ecology=preload("res://scripts/ecology_detail.gd").new(w)
	# Existing narrow vertical colliders include trunks and lamps. Do not overlap either.
	for body in w.get_children():
		if not body is StaticBody3D:continue
		for node in body.get_children():
			if not node is CollisionShape3D or not node.shape is BoxShape3D:continue
			var size:Vector3=node.shape.size
			if maxf(size.x,size.z)<0.9 and size.y>1.0:occupy(Vector2(body.position.x,body.position.z),3.1)

func occupy(point:Vector2,radius:float):
	var key:=Vector2i(floori(point.x/BUCKET),floori(point.y/BUCKET))
	if not occupied.has(key):occupied[key]=[]
	occupied[key].append({"point":point,"radius":radius})

func space_available(point:Vector2,radius:float)->bool:
	var key:=Vector2i(floori(point.x/BUCKET),floori(point.y/BUCKET))
	for dx in range(-1,2):
		for dz in range(-1,2):
			for record in occupied.get(key+Vector2i(dx,dz),[]):
				if point.distance_to(record.point)<radius+record.radius:return false
	return true

func family(mix:String,rng:RandomNumberGenerator)->int:
	var roll:=rng.randf()
	if mix=="high":return 2 if roll<0.46 else (1 if roll<0.65 else 6)
	if mix=="broad":return 1 if roll<0.48 else (0 if roll<0.78 else (6 if roll<0.94 else 3))
	return 1 if roll<0.40 else (2 if roll<0.74 else (0 if roll<0.88 else 6))

func clear(point:Vector2,radius:float)->bool:
	if not ecology.clear(point,radius+1.2):return false
	if point.distance_to(Vector2(-237,-169))<46:return false
	if absf(point.x-(307+18*sin(point.y*0.014)))<43:return false
	if point.x>265 and point.x<355 and point.y< -275 and point.y> -362:return false
	if point.distance_to(Vector2(0,-385))<31:return false
	# Roots must sit on one actual terrace, not bridge a cliff or hang above a road cut.
	var base:float=w.height_at(point.x,point.y)
	for offset in [Vector2(-0.5,0),Vector2(0.5,0),Vector2(0,-0.5),Vector2(0,0.5)]:
		if absf(w.height_at(point.x+offset.x,point.y+offset.y)-base)>0.22:return false
	return space_available(point,radius)

func build(config_path:String="res://data/woodland_groves.json",metadata_key:String="woodland_groves_v12"):
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(config_path))
	for index in config.groves.size():
		var grove:Dictionary=config.groves[index]
		var center:=Vector2(grove.center[0],grove.center[1]);var radii:=Vector2(grove.radii[0],grove.radii[1])
		var rng:=RandomNumberGenerator.new();rng.seed=int(config.seed)+index*977
		var accepted:=0;var families:Dictionary={}
		for attempt in int(grove.count)*32:
			if accepted>=int(grove.count):break
			var angle:float=rng.randf()*TAU;var distance:float=sqrt(rng.randf())
			var point:=center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y)*distance
			# A scalloped edge and two internal openings replace uniform circular density.
			if distance>0.86+0.10*sin(angle*3+index):continue
			if point.distance_to(center+Vector2(radii.x*0.3,-radii.y*0.1))<4.5:continue
			var kind:int=family(str(grove.mix),rng)
			var size:float=rng.randf_range(0.78,1.38)*(0.80 if distance>0.80 else 1.0)
			if str(grove.mix)=="high":size*=0.83
			var radius:float=(2.0 if kind==6 else 2.8)*size
			if not clear(point,radius):continue
			var base:Vector3=w.surface(point.x,point.y)
			art.tree(b,base,kind,size);occupy(point,radius)
			accepted+=1;families[str(kind)]=int(families.get(str(kind),0))+1
			planted.append({"grove":grove.id,"position":[base.x,base.y,base.z],"family":kind,"scale":size})
		# Understory is concentrated at woodland margins, with the same route guards.
		for offset in [Vector2(-0.62,0.16),Vector2(0.48,0.45)]:
			ecology.understorey(center+offset*radii,5.0,3.8,12)
		summaries.append({"id":grove.id,"requested_trees":grove.count,"actual_trees":accepted,"families":families})
	w.set_meta(metadata_key,{"seed":config.seed,"groups":summaries,"trees":planted,"understorey_clusters":ecology.planted_clusters,"scope":"authored groups around retained roads; existing trees retained; actual counts are not a visual acceptance result"})
