extends RefCounted
## Authored coastal garden rooms. Shared terrain, restrained plants, open sea/landmark axes.
var w
var b
var garden
var eligibility
var rng:=RandomNumberGenerator.new()
var plants:=0
var trees:=0
var stones:=0
var occupied_trees:Array[Vector2]=[]

func _init(world):
	w=world;b=w.b;garden=preload("res://scripts/environment_garden.gd").new(w,Vector3.ZERO)
	eligibility=preload("res://scripts/ecology_detail.gd").new(w);rng.seed=126306
	for body in w.get_children():
		if not body is StaticBody3D or body.position.z<250 or body.position.z>305:continue
		for node in body.get_children():
			if node is CollisionShape3D and node.shape is BoxShape3D:
				var size:Vector3=node.shape.size
				if size.x<0.9 and size.z<0.9 and size.y>1.0:occupied_trees.append(Vector2(body.position.x,body.position.z))

func clear(p:Vector2,margin:float=1.0)->bool:
	if not eligibility.clear(p,margin):return false
	# Existing timber walk, its benches and lamps form an occupied band, not a planting bed.
	if absf(p.y-(303+10*sin(p.x*0.015)))<7+margin:return false
	# Keep the real central portrait visible along the seafront arrival axis.
	if absf(p.x)<24 and p.y>250:return false
	if absf(p.x+146)<4 and absf(p.y-282.8)<2.6:return false
	return true

func salt_grass(p:Vector3,size:float,variant:int):
	var tone:String=["849485","a3ab91","bdb793"][posmod(variant,3)]
	for j in 5:
		var angle:float=j*2.31+variant*0.24
		var offset:=Vector3(cos(angle)*0.12,0,sin(angle)*0.12)*size
		var tip:=p+offset+Vector3(cos(angle)*0.20,0.55+0.11*(j%3),sin(angle)*0.20)*size
		b.beam(p+offset,tip,0.055*size,tone)
		if j%2==0:b.box(tip,Vector3(0.08,0.19,0.09)*size,"c4ba98",false,0,"leaf")

func flowering_scrub(p:Vector3,size:float,variant:int):
	# Three offset leafy masses with deliberately open gaps; no spherical green blobs.
	for j in 3:
		var q:=p+Vector3((j-1)*0.42,0.20+0.07*(j%2),sin(j*2.1)*0.24)*size
		b.box(q,Vector3(0.65,0.42,0.62)*size,"64796d",false,0,"leaf")
		b.box(q+Vector3(0.07,0.26,-0.04)*size,Vector3(0.47,0.15,0.45)*size,"90a18c",false,0,"leaf")
		if variant%3!=0:
			for k in 2:b.box(q+Vector3((k-0.5)*0.22,0.37,0.1)*size,Vector3(0.16,0.10,0.15)*size,"cbb5c1" if variant%2 else "e0d7bc",false,0,"leaf")

func planted_drift(center:Vector2,rx:float,rz:float,count:int,variant:int):
	for i in count:
		var angle:float=rng.randf()*TAU;var r:float=sqrt(rng.randf())
		var p:=center+Vector2(cos(angle)*rx,sin(angle)*rz)*r
		if not clear(p,0.9):continue
		# Meandering narrow gaps divide drifts rather than covering the whole lawn uniformly.
		if sin(p.x*0.52+sin(p.y*0.4))>0.88:continue
		var q:Vector3=w.surface(p.x,p.y)
		plants+=1
		if i%11==0:garden.rock_group(q,rng.randf_range(0.5,1.15),i);stones+=1
		elif i%4==0:flowering_scrub(q,rng.randf_range(0.85,1.65),i+variant)
		elif i%3==0:garden.herb(q,0.45+rng.randf()*0.4,true)
		else:salt_grass(q,0.75+rng.randf()*0.6,i)

func build():
	var detail=preload("res://scripts/district_detail.gd").new(w)
	# A shallow loop links the existing promenade without crossing the café door or pier.
	var route:Array=w.terrain_art.config.coast_garden_route
	for i in route.size()-1:
		w.path_between(Vector2(route[i][0],route[i][1]),Vector2(route[i+1][0],route[i+1][1]),2.8,"c2bca6")
	for record in [[-126,272,23,8,120],[-183,277,20,12,115],[56,274,24,9,110],[141,278,23,10,110],[-132,285,19,4,85],[-167,284,10,5,58],[115,292,14,3,56]]:
		planted_drift(Vector2(record[0],record[1]),record[2],record[3],int(record[4]),int(record[0]))
	# Trees group above low foreground plants, with varied size and unequal intervals.
	for record in [[-176,274,4,1.32],[-188,281,4,0.95],[-164,275,6,0.87],[-137,267,4,1.10],[-119,276,4,0.96],[47,269,4,1.25],[60,276,6,0.90],[143,271,4,1.22],[155,283,4,0.92]]:
		var p:=Vector2(record[0],record[1])
		if not clear(p,3.0):continue
		if occupied_trees.any(func(q):return q.distance_to(p)<5.0):continue
		preload("res://scripts/vegetation_art.gd").new().tree(b,w.surface(p.x,p.y),int(record[2]),float(record[3]));trees+=1
		occupied_trees.append(p)
	# A small sheltered pause beside the loop, oriented toward the sea through a real opening.
	var rest:Vector3=w.surface(-146,282.8,0.10)
	detail.paving(rest,6.0,3.4,"c6bea5")
	detail.seat(rest+Vector3(0,0.08,-0.6))
	w.path_between(Vector2(-146,282.8),Vector2(-146,286),2.8,"c2bca6")
	w.interact("N01_GARDEN_SEAT",rest+Vector3(0,0.13,0.5),"海风花境 · 坐看海岸","sit",{"seat":rest+Vector3(0,0.08,-0.6),"yaw":PI})
	# Low stepped coastal stone strata replace the isolated large pebble silhouette at two ends.
	for entry in [[-235,332,5.2,2.2],[-246,345,7.6,3.8],[241,323,5.0,2.1],[252,342,7.1,3.3]]:
		var base:Vector3=w.surface(entry[0],entry[1]);var width:float=entry[2];var h:float=entry[3]
		var foot:float=base.y
		for side in [-1,1]:foot=minf(foot,w.height_at(base.x+side*width*0.6,base.z+width*0.4))
		b.box(Vector3(base.x,(foot+base.y+h*0.5)/2,base.z),Vector3(width*1.3,base.y+h*0.5-foot,width*0.9),"7f8e88",true,0,"stone")
		b.box(base+Vector3(-width*0.14,h*0.65,-width*0.10),Vector3(width,h*0.3,width*0.68),"a4ad9f",true,0,"stone")
		b.box(base+Vector3(width*0.04,h*0.9,-width*0.16),Vector3(width*0.65,h*0.2,width*0.52),"bdc0aa",true,0,"stone")
		stones+=1
	w.set_meta("coastal_garden_v12",{"seed":126306,"plant_clusters":plants,"authored_trees":trees,"stone_groups":stones,"route_width_m":2.8,"scope":"coastal dune garden, connected pause and layered rock ends; existing beach accesses and central sightline preserved"})
