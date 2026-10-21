extends RefCounted
## Regional ground scenes use the verified voxel/plant palette, with open sight corridors.
var w
var b
var garden
var rng:=RandomNumberGenerator.new()
var rock_nodes:=0
var planted_clusters:=0
var paving:Array=[]

func _init(world):
	w=world;b=w.b;garden=preload("res://scripts/environment_garden.gd").new(w,Vector3.ZERO);rng.seed=12618
	# Reserve existing decks and terrace paving too, even where they are not route splines.
	for body in w.get_children():
		if not body is StaticBody3D:continue
		for node in body.get_children():
			if not node is CollisionShape3D or not node.shape is BoxShape3D:continue
			var size:Vector3=node.shape.size
			if size.y>0.8 or maxf(size.x,size.z)<2.0:continue
			if body.position.y-w.height_at(body.position.x,body.position.z)>1.5:continue
			paving.append({"inverse":body.transform.affine_inverse(),"center_y":body.position.y,"half":size/2})

func clear(point:Vector2,margin:float)->bool:
	if not w.clear_of_paths(point,margin):return false
	for deck in paving:
		var local:Vector3=deck.inverse*Vector3(point.x,deck.center_y,point.y)
		if absf(local.x)<deck.half.x+margin and absf(local.z)<deck.half.z+margin:return false
	for item in w.spec.buildings:
		if absf(point.x-item.x)<item.w/2+margin+2 and absf(point.y-item.z)<item.d/2+margin+2:return false
	for zone in w.spec.zones:
		if point.distance_to(Vector2(zone.x+9,zone.z+14))<4+margin:return false
	for action in w.interactions:
		if point.distance_to(Vector2(action.pos.x,action.pos.z))<3+margin:return false
	return true

func outcrop(point:Vector2,scale:float,wet:bool=false):
	if not clear(point,3*scale):return
	var center:Vector3=w.surface(point.x,point.y)
	var ground:float=center.y
	for offset in [Vector2(-1.9,-1.1),Vector2(1.9,-1.1),Vector2(1.9,1.1),Vector2(-1.9,1.1)]:ground=minf(ground,w.height_at(point.x+offset.x*scale,point.y+offset.y*scale))
	var top:float=center.y+1.4*scale
	b.box(Vector3(center.x,(ground+top)/2,center.z),Vector3(3.6*scale,top-ground,2.3*scale),"5d6e70" if wet else "777f77",true,0,"stone")
	b.box(Vector3(center.x-0.5*scale,top+0.28*scale,center.z-0.2*scale),Vector3(2.4,0.56,1.5)*scale,"839085" if wet else "9b9f94",false,0,"stone")
	rock_nodes+=1
	for i in 4:
		var p:=point+Vector2(1.5+i*0.35,sin(i*1.6))*scale
		if not clear(p,0.7):continue
		garden.rock_group(w.surface(p.x,p.y),0.3+0.13*(i%2),i)
		if i%2==0:garden.herb(w.surface(p.x,p.y+0.4),0.28)

func understorey(center:Vector2,rx:float,rz:float,count:int):
	for i in count:
		var angle:float=rng.randf()*TAU;var radius:float=sqrt(rng.randf())
		var point:=center+Vector2(cos(angle)*rx,sin(angle)*rz)*radius
		if not clear(point,1.2):continue
		var p:Vector3=w.surface(point.x,point.y)
		planted_clusters+=1
		if i%7==0:garden.rock_group(p,rng.randf_range(0.5,1.1),i)
		elif i%4==0:
			b.box(p+Vector3(0,0.25,0),Vector3(0.8,0.5,0.65),"6f8060",false,0,"leaf")
			b.box(p+Vector3(0.08,0.54,-0.04),Vector3(0.57,0.12,0.46),"89976a",false,0,"leaf")
		else:garden.herb(p,0.22+0.09*(i%3),i%13==0)

func build():
	# Woodland foreground pockets, with meadows left between them.
	for record in [[-304,-248,18,12],[-212,-245,14,17],[-149,-279,18,13],[-51,-359,15,11],[103,-291,18,13]]:
		understorey(Vector2(record[0],record[1]),record[2],record[3],52)
	for record in [[-302,-250,1.2],[-202,-227,0.8],[-119,-305,1.0],[65,-332,1.0],[151,-250,0.9]]:outcrop(Vector2(record[0],record[1]),record[2])
	# River scenes occupy actual banks, not the deep centre of the channel.
	for z in [-246,-198,-131,-18,72,212]:
		var river_x:float=307+18*sin(z*0.014)
		for side in [-1,1]:
			var point:=Vector2(river_x+side*29,z)
			outcrop(point,0.75,true);understorey(point+Vector2(side*5,1),5,8,22)
	# Coastal wind grass and stone clusters preserve the sea-view axis and sandy foreground.
	for center in [Vector2(-143,296),Vector2(98,290),Vector2(187,296)]:
		for i in 18:
			var p:Vector2=center+Vector2(sin(i*2.4)*rng.randf_range(2,6),cos(i*2.4)*rng.randf_range(1,3))
			if not clear(p,1.0):continue
			garden.herb(w.surface(p.x,p.y),0.34+i%3*0.08)
			if i%8==0:garden.rock_group(w.surface(p.x,p.y),0.45,i)
	w.set_meta("regional_environment_details",{"seed":12618,"rock_nodes":rock_nodes,"planted_clusters":planted_clusters,"bands":["woodland_understorey","montane_outcrops","riparian_rocks","coastal_wind_grass"],"scope":"original local clusters; preserve buildings, paths, stamps and sea-view axes"})
