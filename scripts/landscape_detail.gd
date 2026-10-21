extends RefCounted
## Designed third-round connections, understory and river habitat. No change to world extent.
var world
var b
var garden
var rng:=RandomNumberGenerator.new()

func _init(target):
	world=target;b=world.b;garden=preload("res://scripts/district_detail.gd").new(target);rng.seed=30618
func g(x:float,z:float,y:float=0)->Vector3:return world.surface(x,z,y)

func build():
	music_gardens();cultural_walk();forest_floor();riverbank()
	preload("res://scripts/ecology_detail.gd").new(world).build()

func clear(p:Vector2,margin:float=5.0)->bool:
	for item in world.spec.buildings:
		if absf(p.x-item.x)<item.w/2+margin and absf(p.y-item.z)<item.d/2+margin:return false
	if p.distance_to(world.nearest_road(p))<6:return false
	if not world.clear_of_paths(p,1.8):return false
	for action in world.interactions:
		if p.distance_to(Vector2(action.pos.x,action.pos.z))<3:return false
	return true

func leaf_clump(p:Vector3,size:float,kind:int=0):
	if kind==0:
		for j in 5:
			var angle:float=j*2.4
			var end:=p+Vector3(cos(angle)*size*0.34,size*(0.2+0.08*(j%3)),sin(angle)*size*0.34)
			b.beam(p,end,0.025,"64805f")
			for k in [0.45,0.7,0.9]:
				var q:=p.lerp(end,k)
				b.box(q,Vector3(size*(1-k)*0.45,0.045,size*0.13),"8a9e72" if j%2 else "758f62",false,angle)
	else:
		for j in 5:
			var angle:float=j*1.9
			b.oriented_box(p+Vector3(sin(angle)*0.13,size*0.23,cos(angle)*0.13),Vector3(0.085,size*(0.45+j%3*0.12),0.04),"a7ad7d" if kind==2 else "849a6a",Basis(Vector3.UP,angle)*Basis(Vector3.FORWARD,0.25*sin(j)))

func grove(center:Vector2,rx:float,rz:float,count:int,trees:bool=true):
	for i in count:
		var angle:float=rng.randf()*TAU;var radius:float=sqrt(rng.randf())
		var p:=center+Vector2(cos(angle)*rx*radius,sin(angle)*rz*radius)
		if not clear(p,7):continue
		if absf(p.x-(307+18*sin(p.y*0.014)))<31:continue
		var q:=g(p.x,p.y)
		leaf_clump(q,rng.randf_range(0.7,1.5),i%3)
		if i%5==0:garden.shrub(q,rng.randf_range(1.1,2.8),["667f5f","809169","8b9d75"][i%3],i%2)
		if i%17==0:
			b.shape(q+Vector3(0,0.35,0),Vector3(2.6,1.2,1.8),"999c85","rock",angle)
		if trees and i%13==0:b.tree(q,i%2,rng.randf_range(0.8,1.18))

func garden_path(points:Array,width:float=3.5):
	for i in points.size()-1:world.path_between(points[i],points[i+1],width,"bdbca5")

func music_gardens():
	# The three venues meet through a chain of garden rooms, not duplicated building shells.
	garden_path([Vector2(-291,34),Vector2(-271,42),Vector2(-250,42)],5)
	garden_path([Vector2(-250,-22),Vector2(-264,-29),Vector2(-278,-21),Vector2(-291,-12)],3)
	garden_path([Vector2(-211,63),Vector2(-221,76),Vector2(-244,78)],3.5)
	for center in [Vector2(-277,57),Vector2(-273,-53),Vector2(-214,10),Vector2(-194,31)]:grove(center,12,14,40)
	var court:=g(-268,4,0.14)
	garden.paving(court,9,17,"c8bba0")
	garden.pergola(court+Vector3(0,0,-3),7,8,"8c8067")
	for z in [-2,3]:garden.seat(court+Vector3(2,0.1,z),-PI/2)
	garden_path([Vector2(-250,4),Vector2(-264,4),Vector2(-268,4)],3)
	for z in [-6,13]:garden.flower_bed(g(-268,z),9,2,"bdaac4")
	world.interact("Z05_GARDEN_SEAT",court+Vector3(0,0.1,3),"音乐庭院 · 林荫长椅","sit",{"seat":court+Vector3(2,0.1,3),"yaw":PI/2})
	# A low, project-original sound-wave sculpture is a focal point outside the route.
	var sculpture:=g(-274,27,0.07)
	b.box(sculpture,Vector3(7,0.14,4),"c2c5b5",true)
	for i in 9:
		var hh:float=1+1.2*pow(sin(i*0.65),2)
		b.box(sculpture+Vector3(-2.8+i*0.7,hh/2+0.1,0),Vector3(0.2,hh,0.34),"899ba2")
	for x in [-277,-271]:garden.shrub(g(x,23),2.7,"80916d",0)
	garden.board(g(-260,61),"声音与舞台","西侧：星光演艺厅\n北侧：律动排练馆\n东侧：回声工作室",3)
	for p in [Vector2(-264,18),Vector2(-265,-19),Vector2(-220,71)]:b.lamp(g(p.x,p.y))

func cultural_walk():
	# South-gallery, cinema and north reading garden form a linked, visibly distinct circuit.
	garden_path([Vector2(185,-29),Vector2(204,-37),Vector2(218,-51),Vector2(224,-61),Vector2(245,-63)],4)
	garden_path([Vector2(245,-64),Vector2(219,-67),Vector2(212,-98),Vector2(222,-119),Vector2(225,-138)],3.5)
	for center in [Vector2(209,-39),Vector2(190,-83),Vector2(246,-117),Vector2(272,-109),Vector2(179,-167)]:grove(center,12,13,38)
	var rest:=g(202,-66,0.13)
	garden.paving(rest,11,10,"d1cbb3")
	for z in [-3,3]:garden.seat(rest+Vector3(0,0.1,z),0 if z<0 else PI)
	garden_path([Vector2(202,-66),Vector2(218,-51)],3)
	for x in [-6,6]:garden.flower_bed(rest+Vector3(x,0,0),2,10,"d1bbaa")
	world.interact("Z06_READ_SEAT",rest+Vector3(0,0.1,-1),"影像花园 · 休息","sit",{"seat":rest+Vector3(0,0.1,-3),"yaw":PI})
	# An original framed courtyard connects the existing light-and-shadow set to the path.
	garden_path([Vector2(185,-114),Vector2(195,-112),Vector2(212,-98)],3)
	var frame:=g(185,-112)
	preload("res://scripts/courts_art.gd").new(world).courtyard(frame)
	garden_path([Vector2(195,-112),Vector2(202,-108.5)],2.2)
	garden.board(g(202,-110),"光影庭院","原创布景 · 可取景\n本地影像资料",3.0)
	# Standalone clapperboard form, with no invented production title or take number.
	var clap:=g(190,-108)
	b.box(clap+Vector3(0,0.6,0),Vector3(0.12,1.2,0.12),"747b6a")
	b.box(clap+Vector3(0,1.4,0),Vector3(1.55,1.05,0.12),"496361")
	for i in 7:b.box(clap+Vector3(-0.67+i*0.22,2.03,0),Vector3(0.18,0.2,0.13),"ddd6be" if i%2 else "596b62",false,0.08)
	b.text3d("光 影 庭 院",clap+Vector3(0,1.45,0.08),0.0045)
	for p in [Vector2(201,-36),Vector2(217,-88),Vector2(214,-128),Vector2(196,-104)]:b.lamp(g(p.x,p.y))

func forest_floor():
	# Hillside swathes follow both approach routes. Density is local, seeded and path-filtered.
	# Woodland drifts behind B12 form a near forest edge and a farther canopy backdrop.
	for center in [Vector2(-284,-216),Vector2(-251,-231),Vector2(-297,-181),Vector2(-201,-213)]:grove(center,16,13,76)
	for center in [Vector2(-172,-232),Vector2(-120,-284),Vector2(-72,-307),Vector2(-38,-366),Vector2(54,-319),Vector2(112,-273),Vector2(164,-239),Vector2(241,-239)]:grove(center,28,21,110)
	for entry in [[-142,-249,0.3],[-58,-328,-0.5],[114,-253,0.65],[221,-250,-0.2]]:
		var p:=g(entry[0],entry[1],0.24);var angle:float=entry[2]
		if not clear(Vector2(p.x,p.z),8):continue
		b.box(p,Vector3(4.5,0.55,0.6),"796f55",false,angle)
		for k in [-1.5,0,1.5]:leaf_clump(p+Vector3(k,0.28,0),1,0)
		b.shape(p+Vector3(1.7,0.25,0.2),Vector3(1.3,0.4,0.9),"8a956b","rock",angle)
	# The forest rest clearings are side pockets, leaving the mountain circuit unobstructed.
	for v in [Vector2(-90,-293),Vector2(117,-265)]:
		var q:=g(v.x,v.y,0.12)
		garden.paving(q,7,5,"b6b39a");garden.seat(q+Vector3(0,0.1,-1.3))
		var road:Vector2=world.nearest_road(v)
		garden_path([v,road],2.5)
		var approach:Vector2=(road-v).normalized()
		var reach:float=minf(3.5/maxf(absf(approach.x),0.001),2.5/maxf(absf(approach.y),0.001))-0.05
		b.ramp(g(road.x,road.y,0.05),q+Vector3(approach.x*reach,0.06,approach.y*reach),2.5,"b6b39a")
		for side in [-1,1]:garden.shrub(g(v.x+side*4,v.y),2.2,"7b8e68",0)

func riverbank():
	# Irregular embedded rocks replace the previous uninterrupted identical bank blocks.
	for z in range(-405,339,7):
		var x:float=307+18*sin(z*0.014)
		var water_y:float=world.land_height(x,z)-1.5-world.river_drop(z)
		for side in [-1,1]:
			var size:float=rng.randf_range(1.1,2.8)
			var rock_x:float=x+side*(6.2+rng.randf()*1.2)
			var rock_z:float=z+rng.randf_range(-1.5,1.5)
			var riverbed:float=world.height_at(rock_x,rock_z)
			# The old water-relative centres suspended rocks above the deeply cut channel.
			# Extend each actual block down into the bed while keeping its wet crest visible.
			var height:float=maxf(size*0.65,water_y-riverbed+0.55)
			b.shape(Vector3(rock_x,riverbed+height*0.5-0.18,rock_z),Vector3(size*1.4,height,size),["9ba48c","adb29b","8c9986"][posmod(z,3)],"rock",rng.randf()*PI)
			if z>-280 and z<260:
				for j in 5:leaf_clump(Vector3(x+side*(5.1+j*0.3),water_y-0.10,z+j*0.6),1.7,2)
			var bank:=Vector2(x+side*rng.randf_range(25,33),z)
			if clear(bank,8) and not (z>-60 and z<150 and side<0):
				garden.shrub(g(bank.x,bank.y),rng.randf_range(1.5,3),"7a916d",0)
	# 188 m near-water boardwalk with landings and gentle access at both ends.
	for z in range(-53,135,4):
		var a:=Vector3(297+18*sin(z*0.014),-0.86,z)
		var c:=Vector3(297+18*sin((z+4)*0.014),-0.86,z+4)
		var angle:float=atan2((c-a).x,(c-a).z)
		b.box((a+c)/2,Vector3(4,0.24,a.distance_to(c)+0.08),"b3a386",true,angle)
		for t in [0.0,0.25,0.5,0.75]:b.box(a.lerp(c,t)+Vector3(0,0.127,0),Vector3(3.9,0.012,0.022),"a69b83",false,angle)
		var edge:Vector3=Basis(Vector3.UP,angle)*Vector3(1.9,0,0)
		b.box((a+c)/2+edge+Vector3(0,1,0),Vector3(0.12,0.14,a.distance_to(c)+0.1),"8e9a88",false,angle)
		b.collision((a+c)/2+edge+Vector3(0,0.6,0),Vector3(0.12,1.2,a.distance_to(c)+0.1),angle)
		b.box(a+edge+Vector3(0,0.52,0),Vector3(0.15,1.25,0.15),"869581")
		# The bank-side edge is guarded too; keep both ramp entrances and the rest bay open.
		if z>-53 and z<131 and not (z>=31 and z<=43):
			b.box((a+c)/2-edge+Vector3(0,1,0),Vector3(0.12,0.14,a.distance_to(c)+0.1),"8e9a88",false,angle)
			b.collision((a+c)/2-edge+Vector3(0,0.6,0),Vector3(0.12,1.2,a.distance_to(c)+0.1),angle)
			b.box(a-edge+Vector3(0,0.52,0),Vector3(0.15,1.25,0.15),"869581")
		if z%12==-5 or z%12==7:
			for side in [-1,1]:b.box(a+Vector3(side*1.6,-1,0),Vector3(0.3,2,0.3),"877f68")
	for z in [-53,135]:
		var x:float=297+18*sin(z*0.014)
		var upper:=g(x-18,z,0.12);var landing:=Vector3(x,-0.7,z)
		b.ramp(upper,landing,3.6,"baa88a")
		garden_path([Vector2(upper.x,z),Vector2(245,-62) if z<0 else Vector2(260,160)],3.5)
		garden.board(upper+Vector3(-1,0,3),"滨 水 步 道","沿坡道下行\n两端连接主环线",2.4)
	# An expanded stopping bay faces the flowing channel, without blocking the walkway.
	var bay:=Vector3(297+18*sin(39*0.014)-3,-0.82,39)
	b.box(bay,Vector3(8,0.3,10),"b7a889",true)
	garden.seat(bay+Vector3(-2,0.22,0),PI/2)
	world.interact("N04_RIVER_SEAT",bay+Vector3(0,0.24,0),"河岸坐席 · 听流水","sit",{"seat":bay+Vector3(-2,0.22,0),"yaw":-PI/2})
	for z in [-4,4]:b.box(bay+Vector3(-2,-1,z),Vector3(0.35,2.5,0.35),"8a826b")
	for z in [-4.8,4.8]:
		b.box(bay+Vector3(-1.5,1.1,z),Vector3(4.9,0.13,0.14),"8e9a88")
		b.collision(bay+Vector3(-1.5,0.7,z),Vector3(4.9,1.3,0.14))
		for x in [-3.8,-1.5,0.8]:b.box(bay+Vector3(x,0.6,z),Vector3(0.14,1.3,0.14),"869581")
	b.box(bay+Vector3(-3.85,1.1,0),Vector3(0.14,0.13,9.6),"8e9a88")
	b.collision(bay+Vector3(-3.85,0.7,0),Vector3(0.14,1.3,9.6))
	for z in [-2,0,2]:b.box(bay+Vector3(-3.85,0.6,z),Vector3(0.14,1.3,0.14),"869581")
	# Close planting frames the river in groups while avoiding both ramp approaches.
	for z in range(-39,124,11):
		var river_x:float=307+18*sin(z*0.014)
		for side in [-1,1]:
			var p:=Vector2(river_x+side*(21+rng.randf()*3),z+rng.randf()*3)
			if not world.clear_of_paths(p,2):continue
			garden.shrub(g(p.x,p.y),rng.randf_range(2.0,3.4),"829976",0)
			if posmod(z,3)==0:b.tree(g(p.x,p.y),0,0.8)
			for j in 9:leaf_clump(g(p.x+rng.randf_range(-3,3),p.y+rng.randf_range(-3,3)),rng.randf_range(1,1.8),j%3)
