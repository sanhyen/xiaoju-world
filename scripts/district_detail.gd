extends RefCounted
## Purposeful landscape rooms around existing routes. Seeded planting stays inside designed beds.
var world
var b
var rng:=RandomNumberGenerator.new()

func _init(target):world=target;b=world.b;rng.seed=10618
func ground(x:float,z:float,offset:float=0)->Vector3:return world.surface(x,z,offset)

func shrub(p:Vector3,width:float,tone:String,kind:int=0):
	if kind==0:
		for i in 3:b.shape(p+Vector3((i-1)*width*0.2,width*(0.23+0.06*(i%2)),sin(i*2.7)*width*0.16),Vector3(width*0.63,width*0.55,width*0.63),tone,"shrub",i*0.7)
	else:
		b.box(p+Vector3(0,width*0.28,0),Vector3(width,width*0.56,width*0.7),tone)
		b.box(p+Vector3(width*0.15,width*0.6,0),Vector3(width*0.7,width*0.12,width*0.57),"8a9b72")

func flower_bed(p:Vector3,width:float,depth:float,tone:String="cfb6c8",border:bool=true):
	b.box(p+Vector3(0,0.055,0),Vector3(width,0.11,depth),"738060")
	if border:
		for side in [-1,1]:
			b.box(p+Vector3(side*width/2,0.16,0),Vector3(0.22,0.32,depth+0.2),"c5bca5")
			b.box(p+Vector3(0,0.16,side*depth/2),Vector3(width,0.32,0.22),"c5bca5")
	for i in int(width*depth*1.05):
		var q:=p+Vector3(rng.randf_range(-width/2+0.25,width/2-0.25),0.2,rng.randf_range(-depth/2+0.25,depth/2-0.25))
		var hh:=rng.randf_range(0.24,0.65)
		b.box(q+Vector3(0,hh/2,0),Vector3(0.045,hh,0.045),"647e55")
		b.box(q+Vector3(0.09,hh*0.45,0),Vector3(0.25,0.065,0.14),"8d9d68",false,rng.randf()*PI)
		if i%3==0:
			for j in 3:b.box(q+Vector3(0,hh+j*0.08,0),Vector3(0.14-j*0.025,0.09,0.14-j*0.025),tone)
		elif i%3==1:
			b.shape(q+Vector3(0,hh,0),Vector3(0.28,0.18,0.28),tone,"shrub")
		else:
			b.box(q+Vector3(0,hh,0),Vector3(0.3,0.08,0.11),"e1cda2")
			b.box(q+Vector3(0,hh+0.005,0),Vector3(0.11,0.08,0.3),"e1cda2")

func paving(p:Vector3,width:float,depth:float,tone:String="d6cab2",wood:bool=false):
	b.box(p,Vector3(width,0.1,depth),tone,true)
	if wood:
		for i in int(depth/0.45):b.box(p+Vector3(0,0.055,-depth/2+i*0.45),Vector3(width-0.1,0.012,0.02),"a18d70")
	else:
		for i in int(width/1.5):b.box(p+Vector3(-width/2+i*1.5,0.055,0),Vector3(0.035,0.012,depth),"b7ad96")
		for j in int(depth/1.5):b.box(p+Vector3(0,0.056,-depth/2+j*1.5),Vector3(width,0.012,0.035),"b7ad96")

func seat(p:Vector3,angle:float=0):
	var basis:=Basis(Vector3.UP,angle)
	for i in 4:b.box(p+basis*Vector3(0,0.5,-0.27+i*0.18),Vector3(2.5,0.1,0.14),"a48a64",false,angle)
	for i in 3:b.box(p+basis*Vector3(0,0.8+i*0.17,-0.34),Vector3(2.5,0.12,0.09),"b29a72",false,angle)
	for x in [-1,1]:
		b.box(p+basis*Vector3(x,0.24,0),Vector3(0.09,0.48,0.65),"536861",false,angle)
		b.box(p+basis*Vector3(x,0.73,0),Vector3(0.08,0.08,0.75),"536861",false,angle)
	b.collision(p+Vector3(0,0.28,0),Vector3(2.5,0.55,0.7),angle)

func pergola(p:Vector3,width:float,depth:float,tone:String="7e8f7d"):
	for x in [-width/2,width/2]:
		for z in [-depth/2,depth/2]:
			b.box(p+Vector3(x,1.7,z),Vector3(0.2,3.4,0.2),tone,true)
			b.box(p+Vector3(x,0.17,z),Vector3(0.42,0.34,0.42),"c0b69d")
		b.box(p+Vector3(x,3.3,0),Vector3(0.18,0.24,depth+0.7),tone)
	for i in int(width*1.5)+1:b.box(p+Vector3(-width/2+i/1.5,3.5,0),Vector3(0.12,0.16,depth+0.8),tone)
	for z in [-depth/2,depth/2]:b.box(p+Vector3(0,3.3,z),Vector3(width+0.65,0.25,0.18),tone)

func board(p:Vector3,title:String,body:String,width:float=2.1):
	b.box(p+Vector3(0,1.2,0),Vector3(width,1.7,0.16),"526e67",true)
	for x in [-width/2+0.13,width/2-0.13]:b.box(p+Vector3(x,0.7,0),Vector3(0.12,1.4,0.35),"937b58")
	b.text3d(title,p+Vector3(0,1.65,0.1),minf(0.011,(width-0.25)/(title.length()*48)),"eadbc0")
	var longest:=1
	for line in body.split("\n"):longest=maxi(longest,line.length())
	b.text3d(body,p+Vector3(0,1.1,0.1),minf(0.0065,(width-0.22)/(longest*48)),"d7d4ba")

func direction(p:Vector3):
	b.box(p+Vector3(0,1.8,0),Vector3(0.14,3.6,0.14),"617b72",true)
	# Compass directions and explicit straight-line distances derive from real destinations.
	for entry in [["星光广场",Vector2(0,80)],["海边咖啡",Vector2(-65,287)],["花音唱片",Vector2(-97,188)]]:
		var index:int=[["星光广场",Vector2(0,80)],["海边咖啡",Vector2(-65,287)],["花音唱片",Vector2(-97,188)]].find(entry)
		var dest:Vector2=entry[1];var delta:=dest-Vector2(p.x,p.z)
		var arrow:=("西" if delta.x<0 else "东")+("北" if delta.y<0 else "南")
		b.box(p+Vector3(0,3.25-index*0.43,0),Vector3(3.4,0.37,0.12),"809487")
		b.text3d("%s · %s  直线%d m"%[arrow,entry[0],roundi(delta.length()/5)*5],p+Vector3(0,3.25-index*0.43,0.08),0.0041)

func street():
	# A 92 m pedestrian spine; keep the 8 m central road entirely unobstructed.
	for z in range(143,237,3):
		for side in [-1,1]:
			paving(ground(-75+side*6.5,z,0.11),4.8,3,"c5b69a")
			b.box(ground(-75+side*4.05,z,0.12),Vector3(0.16,0.12,3),"8d9b8b")
	for doorway in [[-97,195,-97,201,-75,201],[-53,216,-53,223,-75,223],[-55,153.5,-55,160,-75,160]]:
		world.path_between(Vector2(doorway[0],doorway[1]),Vector2(doorway[2],doorway[3]),4,"d8c6a4")
		world.path_between(Vector2(doorway[2],doorway[3]),Vector2(doorway[4],doorway[5]),4,"d8c6a4")
	# Record forecourt has a listening porch; florist a working garden; souvenir a stamp court.
	paving(ground(-97,198.8,0.12),22,8,"cfbda0")
	paving(ground(-53,219,0.12),17,7,"d3c5a8")
	paving(ground(-55,157.4,0.12),17,6.5,"d7c6ac")
	for rec in [[-96,215,15,12],[-53,185,16,18],[-97,159,14,13]]:
		var p:=ground(rec[0],rec[1],0.04)
		flower_bed(p,rec[2],rec[3],"c3adc3",false)
		for side in [-1,1]:
			for i in 5:shrub(ground(rec[0]+side*(rec[2]/2+0.5),rec[1]-rec[3]/2+i*rec[3]/4),2.0,"6c845e",i%2)
		b.tree(ground(rec[0]-rec[2]/2+2,rec[1]-rec[3]/2+2),2 if rec[1]>180 else 1,0.88)
	# Benches face the opposite storefront, stopping points are outside connector paths.
	for p in [Vector2(-85,179),Vector2(-64,173),Vector2(-86,231),Vector2(-65,200)]:
		paving(ground(p.x,p.y,0.08),4,5,"cec1a4")
		seat(ground(p.x,p.y,0.14),PI/2 if p.x<-75 else -PI/2)
		b.lamp(ground(p.x,p.y-2.5))
		b.planter(ground(p.x,p.y+3),2.4)
	for z in [149,172,194,227]:
		for x in [-86, -64]:
			if x==-64 and z==149:continue
			b.tree(ground(x,z),1 if z%2 else 2,0.82)
			shrub(ground(x-1,z-1),1.8,"7d925f",1)
	# A small rest pergola occupies the gap, not another empty fake shop.
	paving(ground(-97,237,0.11),16,9,"d4c5a8")
	pergola(ground(-97,237,0.12),12,6,"927e5f")
	for x in [-101,-93]:seat(ground(x,235,0.15))
	for x in [-104,-90]:b.planter(ground(x,239),3.2,"d9baaa")
	world.path_between(Vector2(-91,240),Vector2(-75,236),3,"cbbb9e")
	# Public utility niche: original vending machine, paired waste bins, bicycle rack.
	var p:=ground(-62,235)
	b.box(p+Vector3(0,1.1,0),Vector3(1.4,2.2,0.85),"9db1a5",true)
	b.box(p+Vector3(-0.18,1.32,0.45),Vector3(0.8,1.18,0.035),"405d5e")
	for i in 3:
		for j in 3:b.box(p+Vector3(-0.43+i*0.26,0.92+j*0.32,0.49),Vector3(0.14,0.24,0.06),["dac19b","b8c6b5","b7a9b9"][i])
	b.box(p+Vector3(0,0.35,0.47),Vector3(0.8,0.2,0.06),"405d5e")
	b.text3d("饮品柜 · 场景陈设",p+Vector3(0,2.02,0.49),0.005,"405d5e")
	for x in [2,3]:
		b.box(p+Vector3(x,0.5,0),Vector3(0.7,1,0.7),"70887c",true)
		b.box(p+Vector3(x,1.03,0),Vector3(0.72,0.1,0.74),"405e58")
	board(ground(-102,201.7,0.12),"正在试听","海风演示\n原创器乐 · 本地试听")
	direction(ground(-67,231))
	# Street flags with restrained project-original colors, not invented album artwork.
	for z in [164,208]:
		for x in [-81,-69]:
			b.box(ground(x,z,3),Vector3(0.08,6,0.08),"74897c")
			b.box(ground(x+0.5,z,4.9),Vector3(0.95,1.5,0.045),"c2b6c1" if z==164 else "a7baa8")
			b.text3d("花\n音",ground(x+0.5,z+0.035,4.9),0.010,"f1e6cc")

func plaza():
	# Double border and an unobstructed ceremonial axis preserve the full portrait sightline.
	for side in [-1,1]:
		b.box(Vector3(side*47,0.135,80),Vector3(0.7,0.025,87),"849b91")
		b.box(Vector3(side*44.8,0.135,80),Vector3(0.12,0.025,87),"a39879")
	for z in [36,122]:b.box(Vector3(0,0.135,z),Vector3(94,0.025,0.7),"849b91")
	for x in [-11,11]:b.box(Vector3(x,0.141,83),Vector3(0.5,0.026,76),"bec8ba")
	for z in range(49,121,4):
		for x in [-11,11]:b.box(Vector3(x,0.155,z),Vector3(0.7,0.026,0.7),"8d9e92",false,PI/4)
	# Ground star/compass is a walkable inlay, not a prop obscuring the landmark.
	for i in 8:
		var angle:float=i*PI/4
		var basis:=Basis(Vector3.UP,angle)
		b.box(Vector3(0,0.143,82)+basis*Vector3(0,0,5.1),Vector3(0.45,0.02,7.7),"b6a37e",false,angle)
		b.box(Vector3(0,0.144,82)+basis*Vector3(0,0,10),Vector3(1.1,0.025,1.1),"728c84",false,angle+PI/4)
	# Four planted rooms give foreground, shade and places to stay, keeping both cross axes clear.
	for x in [-32,32]:
		for z in [59,105]:
			flower_bed(Vector3(x,0.16,z),13,8,"c9b4c7")
			for dx in [-5,0,5]:shrub(Vector3(x+dx,0.25,z-3),2.2,"81976e",int(dx==0))
			b.tree(Vector3(x-4,0.17,z-1),2,0.86)
			seat(Vector3(x,0.16,z+6),PI)
			b.lamp(Vector3(x+8,0.15,z+4))
		# Side gallery pergolas remain below the portrait's lower third.
		pergola(Vector3(x,0.15,42),18,7,"8b9b88")
		for dx in [-6,6]:seat(Vector3(x+dx,0.16,42),PI/2 if x<0 else -PI/2)
		for dx in [-8,8]:b.planter(Vector3(x+dx,0.16,46.3),2.4)
		for z in [87,93]:flower_bed(Vector3(x,0.15,z),14,2.4,"dac4a5")
	# Side runnels echo the sea without obstructing the central approach.
	for x in [-20,20]:
		b.box(Vector3(x,0.28,57),Vector3(3.4,0.3,18),"bebaa6")
		b.box(Vector3(x,0.445,57),Vector3(2.9,0.045,17.6),"79a6a0")
		for z in [49,65]:b.box(Vector3(x,0.48,z),Vector3(3.5,0.2,0.3),"d6ceba")
	# Landmark base receives a broad shallow apron and architectural uplight housings.
	paving(Vector3(0,0.14,47),20,6,"c8c7b6")
	for x in [-9,9]:
		b.box(Vector3(x,0.3,44),Vector3(1.3,0.3,0.8),"82978c")
		b.box(Vector3(x,0.48,44),Vector3(0.8,0.06,0.43),"eddaad")
	for x in [-19,19]:
		b.box(Vector3(x,3,119),Vector3(0.1,6,0.1),"7e9688")
		b.box(Vector3(x+0.8,4.8,119),Vector3(1.6,2,0.04),"b6b5c5")
		b.text3d("星 光\n在此相逢",Vector3(x+0.8,4.8,119.035),0.01)
	board(Vector3(41,0.15,114),"星光广场","肖像来源可在作品旁查看\n东侧：山海游客中心",3.1)
	world.interact("Z04_REST",Vector3(-32,0.2,67),"花园长椅 · 看星光广场","sit",{"seat":Vector3(-32,0.16,65),"yaw":0.0})
	# Visitor forecourt connects the street-level map board to the square.
	paving(ground(57,104.5,0.13),17,7,"d4c6a9")
	world.path_between(Vector2(50,105),Vector2(42,105),4,"d4c6a9")

func coast():
	# Continuous curved promenade, with board joints and supported expanded bays.
	for x in range(-225,226,3):
		var z:float=303+10*sin(x*0.015)
		var p:=ground(x,z,0.12)
		b.box(p,Vector3(3.07,0.25,5),"b29a76",true)
		for dz in [-2.45,2.45]:
			if dz>0 and x in [-99,15,51]:continue
			b.box(p+Vector3(0,0.16,dz),Vector3(3.1,0.14,0.11),"d3c09c")
		for i in 10:b.box(p+Vector3(-1.5+i*0.3,0.132,0),Vector3(0.021,0.012,4.9),"8c775b")
		if x%24==0:
			seat(ground(x,z-4))
			b.lamp(ground(x,z-6))
			for dz in [-2,2]:b.box(p+Vector3(0,-0.4,dz),Vector3(0.25,0.9,0.25),"827355")
	# Explicit beach access at three designed openings; do not force a hop over boardwalk edging.
	for x in [-99,15,51]:
		var z:float=303+10*sin(x*0.015)
		var top:=ground(x,z,0.25)
		b.ramp(ground(x,z+10,0.04),Vector3(x,top.y,z+2.35),2.9,"b29a76")
	# Central pier is now a continuous deck over the water with a widened lookout.
	for z in range(307,362,3):
		var p:=Vector3(0,-0.58,z)
		b.box(p,Vector3(5,0.25,3.05),"ad916e",true)
		for i in 6:b.box(p+Vector3(0,0.132,-1.5+i*0.5),Vector3(4.9,0.012,0.02),"a08b6e")
		for x in [-2.4,2.4]:
			b.box(p+Vector3(x,0.57,0),Vector3(0.13,1.3,0.13),"7b7e68",true)
			b.box(p+Vector3(x,1.15,0),Vector3(0.14,0.14,3.1),"d2c29e",true)
			b.box(p+Vector3(x,0.64,0),Vector3(0.08,0.08,3.1),"aaa98b")
			b.box(p+Vector3(x,-1.4,0),Vector3(0.3,3.3,0.3),"766c54")
	var end:=Vector3(0,-0.58,363)
	b.box(end,Vector3(11,0.25,9),"ad916e",true);paving(end+Vector3(0,0.09,0),10.9,8.9,"ad916e",true)
	for x in [-5.4,5.4]:
		b.box(end+Vector3(x,0.6,0),Vector3(0.13,1.2,9),"aeb295",true)
		for z in [-4,0,4]:b.box(end+Vector3(x,-1.0,z),Vector3(0.38,4.4,0.38),"7f735b")
	b.box(end+Vector3(0,0.6,4.4),Vector3(11,1.2,0.13),"aeb295",true)
	for x in [-3,3]:seat(end+Vector3(x,0.22,1.9))
	world.interact("N02_SEAT",Vector3(0,-0.35,364),"坐在码头 · 看海","sit",{"seat":end+Vector3(-3,0.22,1.9),"yaw":PI})
	# Main shaded sea-view terrace, with load-bearing posts and a gentle access ramp.
	var deck:=Vector3(-28,-0.62,320)
	b.box(deck,Vector3(20,0.3,12),"b79b75",true);paving(deck+Vector3(0,0.14,0),19.8,11.8,"b79b75",true)
	b.ramp(ground(-28,307,0.15),deck+Vector3(0,0.3,-5.5),4,"b79b75")
	pergola(deck+Vector3(0,0.3,-1),16,8,"9b8c6d")
	for x in [-37,-19]:
		for z in [315,320,325]:b.box(Vector3(x,-1.2,z),Vector3(0.3,1.4,0.3),"857356")
	for x in [-33,-23]:seat(deck+Vector3(x+28,0.3,2.2))
	for dx in [-9.8,9.8]:
		b.box(deck+Vector3(dx,1.4,0),Vector3(0.12,0.12,12),"a7aa8b",true)
		for z in [-5,-2,1,4]:b.box(deck+Vector3(dx,0.88,z),Vector3(0.1,1.1,0.1),"a7aa8b",true)
		b.collision(deck+Vector3(dx,0.85,0),Vector3(0.12,1.2,12))
	b.box(deck+Vector3(0,1.4,5.8),Vector3(20,0.14,0.12),"a7aa8b",true)
	for dx in range(-9,10,2):b.box(deck+Vector3(dx,0.86,5.8),Vector3(0.1,1.1,0.1),"a7aa8b")
	b.collision(deck+Vector3(0,0.85,5.8),Vector3(20,1.2,0.12))
	world.interact("N02_DECK",deck+Vector3(-3.4,0.35,3),"海风休闲台 · 坐下看海","sit",{"seat":deck+Vector3(-5,0.3,2.2),"yaw":PI})
	board(ground(-20,306),"潮 汐 海 岸","木栈道 · 观海台 · 小码头",2.5)
	# Three separated beach lounges, leaving the central photograph view open.
	for i in 6:
		var x:float=45+i*19 if i<3 else -100-(i-3)*23
		var p:=ground(x,324+5*sin(i*2.1))
		umbrella(p,"a5b7af" if i%2==0 else "d7c4a1")
		for dx in [-1,1]:lounger(p+Vector3(dx,0,2.5),0.15 if dx<0 else -0.13)
	# Dune planting occurs in broad shaped islands; low grass is batched and non-colliding.
	for i in 26:
		var x:float=-211+i*17
		var z:float=315+8*sin(x*0.018)
		if x>-43 and x<15:continue
		for j in 14:
			var xx:float=x+rng.randf_range(-5,5);var zz:float=z+rng.randf_range(-2.4,2.4)
			var p:=ground(xx,zz)
			for k in 4:
				b.beam(p+Vector3(k*0.045,0,0),p+Vector3(sin(j+k)*0.23,0.35+(k%3)*0.18,cos(k)*0.15),0.045,["919b6e","b6ae7b","7e9268"][k%3])
	# Faceted rock groups give the two ends a silhouette and a grounded shoreline.
	for side in [-1,1]:
		for i in 38:
			var x:float=side*(235+rng.randf_range(-15,68));var z:float=315+rng.randf_range(-5,48)
			var size:=rng.randf_range(1.3,5.0)
			var p:=ground(x,z,-0.35)
			b.shape(p+Vector3(0,size*0.32,0),Vector3(size*1.4,size,size),["9ba38f","9c9983","b5b19a"][i%3],"rock",rng.randf()*PI)
			if size>3.8:b.collision(p+Vector3(0,size*0.25,0),Vector3(size*0.8,size*0.6,size*0.65))
	# Café courtyard and real transition down to the promenade.
	paving(ground(-65,299,0.1),20,4,"d5c5a8")
	world.path_between(Vector2(-65,299),Vector2(-65,303+10*sin(-65*0.015)),4,"d5c5a8")
	for x in [-80,-49]:
		flower_bed(ground(x,287,0.05),4,12,"c9b9c9")
		b.tree(ground(x,281),1,0.9)
	board(ground(-76,299),"海边咖啡馆","一层吧台 · 二层阅读\n露台向海 · 小镇入口在北侧",2.5)
	for x in [30,130]:
		var p:=ground(x,312)
		b.box(p+Vector3(0,1.25,0),Vector3(0.18,2.5,0.18),"98aca3")
		b.box(p+Vector3(0.2,2.5,0),Vector3(0.55,0.08,0.13),"98aca3")
		paving(p+Vector3(0,0.03,0),1.8,1.8,"c1baa2")

func umbrella(p:Vector3,tone:String):
	b.box(p+Vector3(0,1.35,0),Vector3(0.09,2.7,0.09),"a58b62")
	for i in 8:
		var angle:float=i*PI/4
		var basis:=Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,0.2)
		b.oriented_box(p+Basis(Vector3.UP,angle)*Vector3(0,2.65,0.77),Vector3(1.2,0.07,1.6),tone if i%2==0 else "e2d6b9",basis)
	b.shape(p+Vector3(0,2.85,0),Vector3(0.38,0.18,0.38),"e0cba5","pot")

func night_lighting():
	for entry in [[-82,231],[-68,203],[-82,178],[-68,150],[-32,108],[32,108],[-32,65],[32,65],[-60,300],[-28,318],[0,363]]:
		var light:=OmniLight3D.new();world.add_child(light);light.position=ground(entry[0],entry[1],3.6)
		light.light_color=Color("ffe0a3");light.light_energy=0;light.omni_range=13;light.shadow_enabled=false
		world.night_lights.append(light)

func other_districts():
	# Z01: arrival forecourt, luggage-side planting and a clear view towards town.
	paving(ground(260,202,0.13),34,9,"d0c4a7")
	for x in [240,280]:
		flower_bed(ground(x,200),5,13,"cdb7c5")
		b.tree(ground(x,194),1,1.05)
		seat(ground(x,209),PI)
	board(ground(273,207),"从这里出发","西侧：星光广场\n沿南侧步道前往海岸",3.1)
	for i in 5:
		var p:=ground(273+i*4,222+i*0.4)
		shrub(p,2.8,"718860",i%2)
		if i%2==0:b.tree(p+Vector3(0,0,4),1,0.9)
	# Z05: the large theatre has its own arrival court; music buildings share a planted walk.
	paving(ground(-291,29,0.1),36,13,"bfc2b0")
	world.path_between(Vector2(-291,30),Vector2(-250,30),6,"bfc2b0")
	for x in [-307,-275]:
		for z in [36,44]:flower_bed(ground(x,z),6,4,"b9adc5")
		b.lamp(ground(x,32));seat(ground(x,40 if x<-291 else 49),PI/2 if x<-291 else -PI/2)
	for z in [-61,-16,32,59]:
		for x in [-259,-242]:
			if not clear_ground(Vector2(x,z),3):continue
			shrub(ground(x,z),2.8,"718b65",1)
			b.tree(ground(x,z+5),1,1.0)
	world.path_between(Vector2(-232,-26),Vector2(-250,-26),4,"cfc2a7")
	paving(ground(-232,-27.5,0.12),23,6,"cfc2a7")
	paving(ground(-211,61,0.12),20,5.5,"c9bba0")
	for x in [-223,-198]:
		flower_bed(ground(x,51),4,13,"c1b7c8");seat(ground(x,61),PI)
	# Step-free connection to the existing outdoor stage, with a loose audience court.
	world.path_between(Vector2(-226,145),Vector2(-227,120),4,"cbbb9b")
	b.ramp(ground(-227,125,0.05),ground(-227,118,0.84),4,"b8ac91")
	for z in [128,132,136]:
		var tier:float=0.12+float(z-128)*0.035
		for x in [-234,-220]:
			b.box(ground(x,z,tier/2),Vector3(4.8,tier,3.8),"c5bca5",true)
			seat(ground(x,z,tier),PI)
	for x in [-238,-216]:b.tree(ground(x,137),1,1.1)
	# Z06: short gallery garden, quiet PB forecourt and cinema marquee planting.
	paving(ground(173,-30,0.12),26,7,"dbd4bf")
	world.path_between(Vector2(173,-28),Vector2(160,0),4,"dbd4bf")
	for x in [156,190]:
		flower_bed(ground(x,-37),4,18,"d7c7ad")
		for z in [-43,-31]:shrub(ground(x,z),2.1,"829873",0)
	paving(ground(245,-71,0.13),32,8,"b8bcb0")
	for x in [227,263]:
		b.tree(ground(x,-68),1,0.95);seat(ground(x,-62),PI)
		flower_bed(ground(x,-74),4,5,"b7abc2")
	paving(ground(225,-140,0.13),28,8,"d1c6ad")
	for x in [209,241]:
		flower_bed(ground(x,-143),3.8,12,"ccbccb")
		b.tree(ground(x,-139),2,0.87)
	var reading:=ground(202,-153,0.13)
	paving(reading,12,10,"c4b797");pergola(reading,10,7,"9c8b6b")
	for x in [-3,3]:seat(reading+Vector3(x,0.07,0))
	world.path_between(Vector2(202,-148),Vector2(209,-138),3,"c4b797")
	world.path_between(Vector2(209,-138),Vector2(225,-138),3,"c4b797")
	# B12's retained garden is now authored with the house in home_art.gd.
	# Do not lay the previous broad slab or duplicate porch furniture over it.
	# Designed beds around the original garden loop, not a full-map random scatter.
	for i in 12:
		var a:float=i*TAU/12;var p:=ground(-205+26*cos(a),-145+18*sin(a))
		if not clear_ground(Vector2(p.x,p.z),2.5):continue
		flower_bed(p,5,3,["c5abc9","d6bf91","b8c69d"][i%3],false)
		shrub(p+Vector3(2,0,-2),2.5,"788e65",i%2)
	# Z08: grove islands and rest nodes on the mountain loops, with a clear trail buffer.
	for center in [Vector2(-124,-250),Vector2(-175,-204),Vector2(60,-276),Vector2(131,-240),Vector2(-26,-353),Vector2(52,-356)]:
		for i in 18:
			var p:Vector2=center+Vector2(rng.randf_range(-16,16),rng.randf_range(-13,13))
			if not clear_ground(p,4):continue
			if p.distance_to(world.nearest_road(p))<7:continue
			shrub(ground(p.x,p.y),rng.randf_range(1,2.5),["6c845e","7d906b"][i%2],i%2)
			if i%4==0:b.tree(ground(p.x+1,p.y+1),0,rng.randf_range(0.9,1.35))
			if i%5==0:b.shape(ground(p.x-1,p.y,0.3),Vector3(2.3,1.0,1.7),"9b9d84","rock",i)
	for entry in [[-104,-281],[-164,-225],[92,-282],[8,-349]]:
		var p:=ground(entry[0],entry[1],0.1)
		paving(p,6,4,"bfb396");seat(p+Vector3(0,0.08,-0.8))
		world.path_between(Vector2(p.x,p.z),world.nearest_road(Vector2(p.x,p.z)),2.5,"bfb396")
	# Waterfall overlook: planted approach, guard and a distinct overall-view marker.
	var view:=ground(286,-302)
	# The bank blocked the original marker's line of sight. Build a reachable supported
	# viewing spur into the carved channel instead of relocating only the QA camera.
	var deck_y:float=view.y+0.12
	# Approach along the uphill path. The old east-west ramp exposed a one-metre side
	# face to travellers coming from the south, despite the deck itself being reachable.
	b.ramp(ground(284,-295.5,0.06),Vector3(286,deck_y+0.16,-302),5.0,"bca785")
	b.box(Vector3(287,deck_y+0.06,-302),Vector3(2.1,0.2,3.8),"bca785",true)
	b.box(Vector3(300.8,deck_y,-302),Vector3(25.8,0.3,4),"b8a17d",true)
	paving(Vector3(300.8,deck_y+0.17,-302),25.8,3.9,"b8a17d",true)
	b.box(Vector3(316,deck_y,-302),Vector3(7,0.3,8),"b8a17d",true)
	paving(Vector3(316,deck_y+0.17,-302),6.9,7.9,"b8a17d",true)
	for z in [-303.9,-300.1]:
		for x in range(289,314,3):
			b.box(Vector3(x,deck_y+0.74,z),Vector3(0.14,1.4,0.14),"817d65",true)
		b.box(Vector3(300.8,deck_y+1.36,z),Vector3(25.8,0.16,0.16),"a5a18a",true)
		b.box(Vector3(300.8,deck_y+0.8,z),Vector3(25.8,0.1,0.1),"a5a18a")
	for z in [-305.9,-298.1]:
		b.box(Vector3(316,deck_y+1.35,z),Vector3(7,0.16,0.16),"a5a18a",true)
		b.box(Vector3(316,deck_y+0.8,z),Vector3(7,0.1,0.1),"a5a18a")
		for x in [312.6,316,319.4]:b.box(Vector3(x,deck_y+0.74,z),Vector3(0.14,1.4,0.14),"817d65",true)
	b.box(Vector3(319.4,deck_y+1.35,-302),Vector3(0.16,0.16,8),"a5a18a",true)
	b.box(Vector3(319.4,deck_y+0.8,-302),Vector3(0.1,0.1,8),"a5a18a")
	for x in [292,299,306,313,319]:
		for z in [-303.8,-300.2]:
			var soil:float=world.height_at(x,z)-0.25
			var hh:float=maxf(0.3,deck_y-soil)
			b.box(Vector3(x,soil+hh/2,z),Vector3(0.44,hh,0.44),"827861")
			if hh>3:b.beam(Vector3(x,deck_y-2.6,z),Vector3(x-1.5,deck_y-0.15,z),0.18,"827861")
	seat(Vector3(316,deck_y+0.23,-299.4),PI)
	for dz in [-5,-2,2,5]:shrub(ground(280,-302+dz),2.4,"79916e",0)
	for i in 12:
		var p:=ground(340+rng.randf_range(-4,9),-331+rng.randf_range(-20,18))
		b.shape(p+Vector3(0,0.8,0),Vector3(4.5,2.7,3.4),"969d88","rock",rng.randf()*PI)
	board(ground(278,-296),"山 溪 观 景","沿栈台东行看瀑布\n木廊桥：南侧步道",2.4)

func clear_ground(p:Vector2,margin:float)->bool:
	for item in world.spec.buildings:
		if absf(p.x-item.x)<item.w/2+margin and absf(p.y-item.z)<item.d/2+margin:return false
	return true

func bridge_detail(x:float,y:float,z:float):
	var mountain:bool=z<-200
	if mountain:
		for i in range(-21,22):b.box(Vector3(x+i,y+0.21,z),Vector3(0.91,0.07,4.85),"ae9672")
		for side in [-1,1]:
			for i in range(-21,21,3):
				b.beam(Vector3(x+i,y+0.2,z+side*2.42),Vector3(x+i+3,y+1.05,z+side*2.42),0.09,"897e61")
				b.beam(Vector3(x+i,y+1.05,z+side*2.42),Vector3(x+i+3,y+0.2,z+side*2.42),0.09,"897e61")
		if z==-285:
			preload("res://scripts/architecture_detail.gd").new().roof(b,Vector3(x,y+4.2,z),13,7,1.1,"738477")
			for dx in [-5.7,5.7]:
				for dz in [-2.35,2.35]:b.box(Vector3(x+dx,y+2.1,z+dz),Vector3(0.2,4.2,0.2),"a69d7d",true)
	else:
		for dx in range(-21,22,3):
			for side in [-1,1]:
				b.box(Vector3(x+dx,y+0.6,z+side*2.5),Vector3(0.42,1.15,0.5),"c2c4b2")
				b.box(Vector3(x+dx,y+1.2,z+side*2.5),Vector3(0.6,0.16,0.7),"ded7be")
		for side in [-1,1]:b.box(Vector3(x,y+0.9,z+side*2.48),Vector3(43,0.1,0.1),"a9b6a6")

func lounger(p:Vector3,angle:float):
	var basis:=Basis(Vector3.UP,angle)
	b.box(p+Vector3(0,0.35,0),Vector3(0.85,0.12,1.45),"e0ceb0",true,angle)
	b.oriented_box(p+basis*Vector3(0,0.58,-0.96),Vector3(0.85,0.12,0.8),"a4b7ad",basis*Basis(Vector3.RIGHT,0.6))
	for z in [-0.65,0.55]:b.box(p+basis*Vector3(0,0.16,z),Vector3(0.77,0.32,0.09),"968568",false,angle)
