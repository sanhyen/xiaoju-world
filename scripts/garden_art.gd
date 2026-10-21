extends RefCounted
## N05 retains its loop, seven benches and shade pocket; 080 groups seats around the planting.
var w
var b
var detail
var herb_art
var planted:=0
var shrubs:=0

func _init(world):
	w=world;b=w.b
	detail=preload("res://scripts/district_detail.gd").new(w)
	herb_art=preload("res://scripts/environment_garden.gd").new(w,Vector3.ZERO)

func g(x:float,z:float,y:float=0)->Vector3:return w.surface(x,z,y)

func seating_layout():
	# Reuse all seven bench modules. Only the old anonymous row changes position.
	# These flat-ground pockets clear the retained paths and original flower drifts.
	var layout:=[
		{"x":-231.0,"z":-134.0,"target":[-205.0,-145.0],"group":"west"},
		{"x":-231.0,"z":-141.0,"target":[-205.0,-145.0],"group":"west"},
		{"x":-221.0,"z":-129.0,"target":[-215.0,-143.0],"group":"west"},
		{"x":-176.5,"z":-137.0,"target":[-205.0,-145.0],"group":"east"},
		{"x":-176.5,"z":-144.0,"target":[-205.0,-145.0],"group":"east"},
		{"x":-196.0,"z":-127.0,"target":[-215.0,-143.0],"group":"north"},
		{"x":-190.0,"z":-130.0,"target":[-205.0,-145.0],"group":"north"}
	]
	for seat in layout:
		var direction:=Vector2(seat.target[0]-seat.x,seat.target[1]-seat.z)
		var yaw:=atan2(direction.x,direction.y)
		var base:=g(seat.x,seat.z)
		b.box(base+Vector3(0,-0.015,0),Vector3(3.0,0.07,2.2),"bfb59d",false,yaw,"stone")
		b.bench(base+Vector3(0,0.02,0),yaw)
		seat.yaw=yaw
		seat.ground_y=base.y
		var number:=layout.find(seat)+1
		var approach:=base+Basis(Vector3.UP,yaw)*Vector3(0,0.2,1.25)
		w.interact("N05_SEAT_%02d"%number,approach,"花间庭 · 坐下看花", "sit",{"seat":base+Vector3(0,0.02,0),"yaw":yaw+PI})
	w.set_meta("garden_seats_080",{"benches":7,"groups":3,"layout":layout,"old_anonymous_row_relocated":true,"added_colliders":0,"retained_actions":["N05_SHADE_SEAT"],"new_seat_actions":7,"scope":"Seven existing bench colliders relocated; all original interaction anchors, garden loop and cottage access retained"})

func shade_pocket():
	var path:=[Vector2(-205,-120),Vector2(-201,-111),Vector2(-203,-104),Vector2(-210.5,-104)]
	for i in path.size()-1:w.path_between(path[i],path[i+1],2.6,"bdbba4")
	# Reserve the whole deck for the new groves; original tree generation has already finished.
	w.reserve_path(Vector2(-212,-106),Vector2(-212,-102),10)
	var base:=g(-212,-104,0.10)
	detail.paving(base,6,8,"c6bca2")
	detail.pergola(base,6,8,"88795f")
	detail.seat(base+Vector3(-0.8,0.05,0),PI/2)
	w.interact("N05_SHADE_SEAT",g(-210.5,-104,0.2),"花间庭 · 树荫下坐一会儿","sit",{"seat":base+Vector3(-0.8,0.05,0),"yaw":-PI/2})
	for z in [-107,-101]:
		var p:=g(-215.8,z)
		b.box(p+Vector3(0,0.2,0),Vector3(1.0,0.4,1.5),"a7a28c",false,0,"stone")
		herb_art.herb(p+Vector3(0,0.40,0),0.7,true)
	# The small title faces the approach and makes no unsupported personal claim.
	detail.board(g(-199.5,-110),"花 间 庭","前方：花园与海风小屋\n西侧：声音与舞台",2.7)

func flower(p:Vector3,kind:int,scale:float):
	var h:float=[0.42,0.77,0.32][kind]*scale
	b.box(p+Vector3(0,h*0.5,0),Vector3(0.045,h,0.045),"667d56",false,0,"leaf")
	b.box(p+Vector3(0.10,h*0.40,0),Vector3(0.23,0.055,0.11)*scale,"89976a",false,0,"leaf")
	if kind==0:
		for offset in [Vector3(-0.12,0,0),Vector3(0.12,0,0),Vector3(0,0,-0.12),Vector3(0,0,0.12)]:
			b.box(p+Vector3(0,h,0)+offset*scale,Vector3(0.16,0.08,0.16)*scale,"e0d1ae",false,0,"leaf")
		b.box(p+Vector3(0,h+0.05,0),Vector3(0.09,0.06,0.09)*scale,"c9b572",false,0,"leaf")
	elif kind==1:
		for i in 4:b.box(p+Vector3(0,h+i*0.09*scale,0),Vector3(0.22-i*0.035,0.10,0.20-i*0.03)*scale,"b3a4be" if i%2 else "c4b5cc",false,0,"leaf")
	else:
		for i in 3:b.box(p+Vector3((i-1)*0.13,h+0.06*(i%2),0.06*sin(i))*scale,Vector3(0.25,0.16,0.22)*scale,"c3a6b7" if i%2 else "d7bfc9",false,0,"leaf")
	planted+=1

func drift(center:Vector2,radii:Vector2,kind:int,seed_value:int):
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	for i in 60:
		var angle:float=rng.randf()*TAU
		var distance:float=sqrt(rng.randf())
		if distance>0.84+0.12*sin(angle*3.0):continue
		var point:Vector2=center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y)*distance
		if not w.clear_of_paths(point,0.65):continue
		flower(g(point.x,point.y),kind,0.85+rng.randf()*0.35)
	# Broken stone edging follows the drift, leaving real gaps rather than a sealed box.
	for i in 11:
		var angle:float=0.1+i*0.21
		var point:=center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y)
		if not w.clear_of_paths(point,0.8):continue
		b.box(g(point.x,point.y,0.10),Vector3(0.52,0.20,0.30),"a6a38f",false,0,"stone")

func shrub_patch(point:Vector2,kind:int):
	if not w.clear_of_paths(point,1.8):return
	var p:=g(point.x,point.y)
	if kind==0:
		for i in 3:
			var q:=p+Vector3((i-1)*0.56,0.38+0.11*(i%2),0.16*sin(i*2.2))
			b.box(q,Vector3(0.92,0.76,0.86),"62775a",false,0,"leaf")
			b.box(q+Vector3(0.09,0.42,-0.07),Vector3(0.62,0.12,0.58),"82946a",false,0,"leaf")
	else:
		for i in 4:
			var angle:float=i*2.4
			var q:=p+Vector3(cos(angle)*0.40,0.72+0.10*(i%2),sin(angle)*0.40)
			b.beam(p,q,0.045,"786047")
			b.box(q,Vector3(0.68,0.32,0.56),"708b78",false,0,"leaf")
			b.box(q+Vector3(0.07,0.20,-0.03),Vector3(0.48,0.09,0.37),"92a88d",false,0,"leaf")
	shrubs+=1

func planting():
	# A low meadow core preserves a view across the loop; taller planting frames its edges.
	drift(Vector2(-215,-143),Vector2(5.2,3.4),0,77701)
	drift(Vector2(-200,-137),Vector2(5.6,2.6),1,77702)
	drift(Vector2(-187,-148),Vector2(3.5,4.3),2,77703)
	drift(Vector2(-222,-111),Vector2(5.5,3.0),1,77704)
	drift(Vector2(-197,-111),Vector2(2.7,3.3),0,77705)
	for i in 10:
		var point:=Vector2(-222+i*3.1,-153.5+1.8*sin(i*0.7))
		shrub_patch(point,i%2)
	for point in [Vector2(-219,-105),Vector2(-216,-97),Vector2(-207,-97),Vector2(-199,-107)]:shrub_patch(point,1)
	w.set_meta("garden_077",{"flower_clusters":planted,"shrub_groups":shrubs,"flower_forms":3,"shrub_forms":2,"original_benches_retained":7,"new_shade_seat":1,"scope":"N05 local garden, existing loop/home/music links retained; actual visual review required"})
