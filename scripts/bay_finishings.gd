extends RefCounted
## Functional upper annexes, everyday rooms and landscape frames. Existing IDs stay intact.
var w
var b
var c
var o:Vector3
var lofts:=0

func _init(world):w=world;b=w.b

func venue(ctx):
	c=ctx;o=c.origin;b.venue_context=c.item.id
	if c.item.id in w.layout.config.get("annexes",{}):annex(w.layout.config.annexes[c.item.id])
	room()
	b.venue_context=""

func box(p:Vector3,size:Vector3,tone:String,solid:bool=false,kind:String="wood"):
	b.box(o+p,size,tone,solid,0,kind)

func cushion(p:Vector3,yaw:float=0):
	var art=preload("res://scripts/bay_architecture.gd").new();art.b=b;art.sofa(p,yaw)

func seat(id:String,p:Vector3,yaw:float=0,pose:String="sit"):
	w.interact(id,p+Vector3(0,0,-.8),"放松落座 · X","sit",{"seat":p+Vector3(0,.16,0),"yaw":yaw,"pose":pose})

func rail(a:Vector3,end:Vector3):
	b.beam(a+Vector3(0,1.12,0),end+Vector3(0,1.12,0),.12,"5e4232")
	var along:Vector3=(end-a).normalized();var right:Vector3=Vector3.UP.cross(along).normalized()
	b.oriented_box((a+end)*.5+Vector3.UP*.575,Vector3(.15,1.15,a.distance_to(end)+.10),"5e4232",Basis(right,along.cross(right).normalized(),along),true,"wood")
	b.beam(a+Vector3.UP*.18,end+Vector3.UP*.18,.16,"5e4232")
	var n:int=maxi(1,ceili(a.distance_to(end)/1.5))
	for i in n+1:b.box(a.lerp(end,float(i)/n)+Vector3(0,.53,0),Vector3(.12,1.06,.12),"5e4232",true)

func flight(a:Vector3,end:Vector3,width:float):
	b.ramp(a,end,width,"c9b695")
	var n:int=ceili(absf(end.y-a.y)/.15)
	var along:Vector3=(end-a).normalized();var side:=Vector3(-along.z,0,along.x).normalized()
	for i in n:
		var p:Vector3=a.lerp(end,(float(i)+.5)/n)
		b.oriented_box(p+Vector3(0,.015,0),Vector3(width,.08,Vector2(a.x-end.x,a.z-end.z).length()/n+.04),"c9b695",Basis(Vector3.UP,atan2(along.x,along.z)),false,"stone")
	# Rails are emitted once from the complete stair and landing surface network.

func annex(data:Dictionary):
	lofts+=1
	var p:Vector3=w.layout.vector(data.center)
	# Two real storeys, a ground lounge and an upper library/listening/observation room.
	b.box(p-Vector3(0,.18,0),Vector3(8.4,.36,8.4),"e2d5c1",true,0,"stone")
	b.box(p+Vector3(0,3.66,0),Vector3(8.4,.28,8.4),"aa906c",true,0,"wood")
	for x in [-4.0,4.0]:
		for z in [-4.0,4.0]:
			var ground:float=minf(p.y-.6,w.layout.natural_height(Vector2(p.x+x,p.z+z)))
			b.box(Vector3(p.x+x,(ground+p.y)*.5,p.z+z),Vector3(.7,maxf(.6,p.y-ground),.7),"b7a68c",false,0,"stone")
			b.box(p+Vector3(x,3.4,z),Vector3(.35,6.8,.35),"5e4232",true,0,"wood")
			b.beam(p+Vector3(x,6.1,z),p+Vector3(x*.7,6.8,z),.20,"5e4232")
		# Thick cheeks and projecting frames place glass 0.4 m behind the front moulding.
		if x<0 and c.item.id in ["B07","B08"]:
			var opening_z:float=-3.25
			for section in [[-3.85,opening_z-1.3],[opening_z+1.3,3.85]]:
				if section[1]>section[0]:b.box(p+Vector3(x,4.4,(section[0]+section[1])*.5),Vector3(.6,1.2,section[1]-section[0]),"f4efe6",true,0,"plaster")
		else:b.box(p+Vector3(x,4.4,0),Vector3(.6,1.2,7.7),"f4efe6",true,0,"plaster")
		b.box(p+Vector3(x,6.55,0),Vector3(.6,.65,7.7),"f4efe6",true,0,"plaster")
		# Open 4 m central bay; retain short wind screens at either end.
		for zz in [-2.85,2.85]:
			if x<0 and c.item.id in ["B07","B08"] and zz<0:continue
			b.glass(p+Vector3(x-.12*signf(x),5.65,zz),Vector3(.04,1.8,1.7));b.collision(p+Vector3(x,5.65,zz),Vector3(.16,1.8,1.7))
		for z in [-3.7,-1.2,1.2,3.7]:b.box(p+Vector3(x+signf(x)*.3,5.65,z),Vector3(.3,1.95,.17),"5e4232",false,0,"wood")
	load("res://scripts/architecture120.gd").new(w).annex_roof(c.item.id,p)
	for level in [0.0,3.8]:
		b.table(p+Vector3(-1.5,level,0),1.8);cushion(p+Vector3(-1.5,level,1.3),PI)
		seat("ADD_"+c.item.id+"_LOUNGE_"+str(int(level)),p+Vector3(-1.5,level,1.3),PI)
	# Upper room and stairs share the same perimeter and actual portals.
	# U stair has two separated flights and a resting landing; no ramp cuts through the upper floor.
	var route:Array=data.stairs
	for i in route.size()-1:
		var a:Vector3=w.layout.vector(route[i]);var end:Vector3=w.layout.vector(route[i+1])
		if absf(a.y-end.y)>.1:flight(a,end,2.5)
		else:b.ramp(a,end,2.8,"aa906c")
	for index in [1,2,3]:
		var at:Vector3=w.layout.vector(route[index]);b.box(at-Vector3(0,.10,0),Vector3(2.9,.2,2.9),"aa906c",true,0,"wood")
		for side in [-1,1]:
			var height:float=maxf(.4,at.y-p.y);b.box(at+Vector3(side*1.2,-height*.5,0),Vector3(.3,height,.3),"5e4232",false,0,"wood")
	var guards=preload("res://scripts/bay_guardrails.gd").new(w)
	guards.pad(p+Vector3.UP*3.8,Vector2(8.4,8.4))
	# The stair toe and the ground-room approach share a genuine forecourt.
	var stair_toe:Vector3=w.layout.vector(route[0]);var forecourt:=Vector3(p.x,p.y,stair_toe.z)
	b.ramp(forecourt,stair_toe,3.2,"c9b695");b.box(stair_toe-Vector3.UP*.12,Vector3(3.2,.24,3.2),"c9b695",true,0,"stone")
	guards.span(forecourt,stair_toe,3.2,false);guards.pad(stair_toe,Vector2(3.2,3.2),false)
	for i in route.size()-1:guards.span(w.layout.vector(route[i]),w.layout.vector(route[i+1]),2.8)
	for index in [1,2,3,4]:guards.pad(w.layout.vector(route[index]),Vector2(2.8,2.8))
	load("res://scripts/architecture120.gd").new(w).annex_receiving_portal(c.item.id,p,guards)
	guards.build("annex_"+c.item.id,true)
	for bound in w.building_bounds:
		if bound.id==c.item.id:
			if not bound.has("extra_bounds"):bound.extra_bounds=[]
			bound.extra_bounds.append({"x":p.x,"z":p.z,"w":8.4,"d":8.4,"y":p.y,"h":6.9})
	preload("res://scripts/bay_redesign_authoring.gd").new(w).upper_corner(c.item.id,p+Vector3(1.6,3.8,-1.5))
	if c.item.id=="B07":
		for x in [0,2.8]:b.shelf(p+Vector3(x,3.8,-3.5),2.25)
		b.table(p+Vector3(1.5,3.8,1),2.0)
		# Green banker shades and a supported shelf ladder make this a working reading loft.
		for x in [-1.6,1.6]:
			b.box(p+Vector3(x,4.85,1),Vector3(.42,.06,.28),"86764f")
			b.box(p+Vector3(x,5.08,1),Vector3(.055,.45,.055),"b39b61")
			b.box(p+Vector3(x,5.32,1),Vector3(.65,.18,.35),"497964")
			b.glow_box(p+Vector3(x,5.23,1),Vector3(.5,.045,.28))
		for x in [2.7,3.2]:b.beam(p+Vector3(x,3.8,-1.5),p+Vector3(x,6.3,-2.6),.07,"aa906c")
		for rung in 8:b.beam(p+Vector3(2.7,3.95+rung*.29,-1.57-rung*.127),p+Vector3(3.2,3.95+rung*.29,-1.57-rung*.127),.06,"aa906c")
		w.interact("ADD_B07_ATTIC_PB",p+Vector3(1.5,3.8,2.2),"阁楼精装画册 · E 翻阅","pb",{})
		b.text3d("海风阁楼 · 拾光阅读",p+Vector3(0,5.9,4.3),.009,"5e4232")
	else:b.text3d(c.item.name+" · 观景上层",p+Vector3(0,5.9,4.3),.008,"5e4232")

	load("res://scripts/architecture120.gd").new(w).annex_details(c.item.id,p)

func room():
	# Different rugs, framed hand-written project notes and plants replace vacant floor and park furniture.
	var id:String=c.item.id
	if id not in ["B08","B10","B06"]:
		box(Vector3(0,.035,2.7),Vector3(minf(6,c.w-3),.035,3.6),"baab88",false,"fabric")
		for z in [1.15,4.2]:box(Vector3(0,.06,z),Vector3(minf(6,c.w-3),.015,.08),"876d55",false,"fabric")
	if id=="B02":
		# Continuous wall lining, exposed ceiling beams and filled partition shelves.
		for z in range(-5,7,2):box(Vector3(0,3.04,z),Vector3(c.w-.6,.22,.20),"5e4232")
		box(Vector3(0,.55,-c.d*.5+.27),Vector3(c.w-.6,1.1,.10),"8b7055")
		for y in [.35,.85,1.35]:box(Vector3(2.5,y,-3.3),Vector3(.5,.10,2.1),"5e4232")
		for z in [-4.0,-3.3,-2.6]:
			box(Vector3(2.5,.58,z),Vector3(.43,.35,.5),"b59c73",false,"fabric")
		for i in 6:
			box(Vector3(3.8+i%3*.72,2.3-i/3*.5,-c.d*.5+.31),Vector3(.5,.35,.025),["ebd9aa","d9b8b5","c4d1b4"][i%3],false,"fabric")
			b.glow_box(o+Vector3(3.8+i%3*.72,2.6-i/3*.5,-c.d*.5+.34),Vector3(.035,.035,.035))
		preload("res://scripts/bay_audit_finishings.gd").new(w).cafe(o)
		# The existing counter has an actual L return; these fittings make the work zones readable.
		box(Vector3(-5,1.51,-3),Vector3(1.25,.55,.65),"b7a073")
		for x in [-5.35,-4.65]:b.beam(o+Vector3(x,1.8,-3.2),o+Vector3(x,1.45,-2.7),.07,"d9caa1")
		box(Vector3(-2.4,1.65,-3),Vector3(1.5,.08,.8),"5e4232")
		b.glass(o+Vector3(-2.4,1.47,-3),Vector3(1.5,.38,.8))
		for k in 4:box(Vector3(-2.85+k*.3,1.39,-3),Vector3(.24,.18,.34),["dcb482","d7ab91","ead0ac","cca39d"][k])
		box(Vector3(-2,2.4,-5.72),Vector3(2.5,1.5,.12),"45554b")
		b.text3d("今日手冲 · 海盐拿铁\n花香茶 · 海风甜点",o+Vector3(-2,2.4,-5.62),.0045,"ead9b7")
		for k in 6:box(Vector3(2.5,1.75,-4.2+k*.3),Vector3(.13,3.5,.1),"5e4232")
		b.shape(o+Vector3(2.5,2.8,-3.6),Vector3(.7,.7,.7),"779466","shrub")
		for zz in [-4.5,-.5,3.5]:
			var curtain:=MeshInstance3D.new();var cloth:=BoxMesh.new();cloth.size=Vector3(.045,1.1,2.2);curtain.mesh=cloth;curtain.position=o+Vector3(-8.65,2.9,zz)
			var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/gauze_bay.gdshader");curtain.material_override=material;w.add_child(curtain)
		for x in [-5.0,-1.9]:
			for z in [1.0,5.0]:
				# Rounded trays, fruit pastries, cups and journals are visibly different at each table.
				box(Vector3(x+.3,1.08,z-.25),Vector3(.45,.035,.32),"b88061",false,"fabric")
				box(Vector3(x+.3,1.16,z-.25),Vector3(.30,.14,.24),"e4c090")
				box(Vector3(x-.3,1.04,z+.1),Vector3(.4,.025,.28),"ded1b1")
				if z<3:box(Vector3(x-.3,1.16,z+.1),Vector3(.15,.23,.14),"f3ead6")
				else:
					for k in 3:box(Vector3(x-.4+k*.12,1.1,z+.1),Vector3(.07,.08,.08),"d69b91")
				seat("ADD_B02_BOOTH_"+str(int(x*10))+"_"+str(int(z)),o+Vector3(x,0,z+1.15),PI)
		# A real padded sill is matched to the cat's fixed home anchor.
		box(Vector3(-8.3,1.06,5.3),Vector3(.8,.18,1.4),"bca88d",false,"fabric")
		for i in 8:box(Vector3(2.5,1.25,-4.2+i*.28),Vector3(.10,2.5,.08),"5e4232")
		b.shelf(o+Vector3(2.5,0,-3),2.0)
		cushion(o+Vector3(4.1,0,3.7));b.table(o+Vector3(4.1,0,2.2),1.8)
		seat("ADD_B02_READING",o+Vector3(4.1,0,3.7))
		box(Vector3(4.2,1.02,2.2),Vector3(.65,.04,.45),"e4d9bf")
	elif id=="B03":
		for i in 4:
			box(Vector3(-6+i*3,2.4,-6.1),Vector3(1.8,1.8,.12),["6c857d","a78974","a3a488","b4a1af"][i])
			b.text3d(["日落试听","山海歌单","声音资料","旅行编排"][i],o+Vector3(-6+i*3,2.4,-5.98),.005,"f4efe6")
	elif id=="B04":
		for i in 4:
			box(Vector3(-3.7+i*2.4,1.6,-4.7),Vector3(1.4,1.0,.08),"eadfbd")
			b.text3d(["春樱 · 粉","金盏 · 黄","绣球 · 蓝","薰衣草 · 紫"][i],o+Vector3(-3.7+i*2.4,1.6,-4.64),.005,"5e6950")
		for x in [-4.0,0.0,3.8]:
			for j in 4:box(Vector3(x+sin(j*2.1)*.18,3.4-j*.12,-3.7),Vector3(.12,.22,.12),"bca694",false,"fabric")
	elif id=="B09":
		for i in 5:
			box(Vector3(-5+i*2,2.4,-6),Vector3(.9,1.25,.04),"ece2c5")
			for j in 5:box(Vector3(-5+i*2,2.65-j*.13,-5.96),Vector3(.75,.018,.01),"687368")
		seat("ADD_B09_MONITOR",o+Vector3(4,0,3),0)
	elif id=="B12":
		box(Vector3(-5.6,.5,-4.9),Vector3(1.6,1.0,.5),"b3a088",true,"stone")
		box(Vector3(-5.6,.5,-4.62),Vector3(1.1,.65,.02),"433e36")
	elif id=="B06":
		for x in [-11,11]:cushion(o+Vector3(x,0,9),PI*.5 if x<0 else -PI*.5)
		seat("ADD_B06_LOBBY_SOFA",o+Vector3(11,0,9),-PI*.5)
	elif id=="B07":
		seat("ADD_B07_WINDOW_READ",o+Vector3(9,0,1),PI*.5)
	if id in ["B04","B11","B12"]:
		var picture:String={"B04":"life_05","B11":"life_07","B12":"life_03"}[id]
		b.picture("res://assets/media/bay_life/"+picture+".jpg",o+Vector3(1.5,2.5,-c.d*.5+.30),.9)
	elif id=="B05":b.picture("res://assets/media/bay_life/life_06.jpg",o+Vector3(0,2.5,-7.7),1.6)
	elif id in ["B06","B08","B10"]:
		var poster:String={"B06":"sunset","B08":"rehearsal","B10":"wall_stage"}[id]
		b.picture("res://assets/media/bay_life/poster_"+poster+".jpg",o+Vector3(-c.w*.3,2.5,c.d*.5-.35),1.0,PI)
		b.text3d("本地节目真实帧",o+Vector3(-c.w*.3,1.7,c.d*.5-.4),.004,"5e6950",PI)
	# A warm practical light is local to each room; it never adds a black track-light row.
	if id not in ["B06","B10","B08"]:
		var lamp:=OmniLight3D.new();lamp.position=o+Vector3(c.w*.3,2.2,2);lamp.light_color=Color("ffbe82");lamp.omni_range=7;lamp.light_energy=.42;lamp.shadow_enabled=false;w.add_child(lamp)

func landscape():
	street_wings()
	waterfall_pools()
	framing_groves()
	# Reflecting wish basin in front of L01, with curved low sandstone coping.
	var y:float=w.height_at(0,80)
	for i in 42:
		var a:float=i*TAU/42;var p:=Vector3(cos(a)*9.0,y+.20,54+sin(a)*2.8)
		b.box(p,Vector3(.8,.4,.45),"e2d5c1",false,-a,"stone")
	var water:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(17,5);water.mesh=plane;water.position=Vector3(0,y+.13,54)
	var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/wish_reflection_bay.gdshader");mat.set_shader_parameter("portrait",load("res://assets/media/portrait_01.jpg"));mat.set_shader_parameter("portrait_center",Vector3(0,y+10.5,39.44));mat.set_shader_parameter("portrait_size",Vector2(16.0*4579.0/6146.0,16));water.material_override=mat;w.add_child(water)
	w.interact("ADD_PLAZA_WISH",Vector3(0,y,58),"星光祈愿池 · F 点亮","bay_activity",{"activity":"wish"})
	for side in [-1,1]:
		var p:Vector3=w.surface(side*39,72)
		b.box(p+Vector3(0,.5,0),Vector3(11,1,13),"c6b79a",true,0,"stone")
		b.ramp(p+Vector3(-side*8,0,6),p+Vector3(-side*3,1,6),3.2,"d4c4a5")
		preload("res://scripts/bay_authoring.gd").new(w).pergola(p+Vector3(0,1,0),Vector2(10,10))
		b.planter(p+Vector3(side*3,1,-3),3,"c9afc0");cushion(p+Vector3(0,1,1))
	# Each core approach has a lantern, real beam brace and flowering close foreground.
	for id in w.layout.venues:
		var v:Dictionary=w.layout.venues[id];var p:=Vector3(v.x-v.w*.5-2,v.floor_y,v.z+v.d*.5+3)
		for j in 3:b.shape(p+Vector3(j*.5,.45,0),Vector3(.75,.9,.8),"8a9f68","shrub")
		b.box(p+Vector3(0,2.4,0),Vector3(.22,4.8,.22),"5e4232",false,0,"wood")
		b.beam(p+Vector3(0,4.4,0),p+Vector3(1.2,4.9,0),.18,"5e4232")
		b.glow_box(p+Vector3(1.2,4.5,0),Vector3(.4,.6,.4))
		for k in 8:b.shape(p+Vector3(sin(k*1.8)*1.2,4+sin(k)*.5,cos(k*1.8)*.8),Vector3(.8,.4,.7),"d9b4c3","shrub")
	# A wind-bell/rope/sign sequence every 14 m gives the main ring readable near references.
	for r in w.layout.segments:
		if r.bridge or r.width<4.2:continue
		var side:=Vector3(-(r.c-r.a).z,0,(r.c-r.a).x).normalized()
		var n:int=int(r.a.distance_to(r.c)/14)
		for i in n:
			var p:Vector3=r.a.lerp(r.c,(float(i)+.5)/maxi(n,1))+side*(r.width*.5+1.2)
			p.y=w.height_at(p.x,p.z);b.lamp(p)
			var warm:=OmniLight3D.new();warm.position=p+Vector3(0,3.8,0);warm.light_color=Color("ffb86c");warm.light_energy=0;warm.omni_range=8;warm.shadow_enabled=false;warm.distance_fade_enabled=true;warm.distance_fade_begin=42;warm.distance_fade_length=12;w.add_child(warm);w.night_lights.append(warm)
			b.box(p+Vector3(.3,2.25,0),Vector3(.7,.55,.08),"a8bdb2")
			b.shape(p+Vector3(.8,.35,.7),Vector3(1,.7,.8),"869b65","shrub")
	# A listening pavilion on the western ascent and clear side paths remain off the road.
	var p:Vector3=w.surface(-270,-271)
	preload("res://scripts/bay_authoring.gd").new(w).pergola(p+Vector3(0,.1,0),Vector2(6,5))
	b.bench(p+Vector3(0,.1,-1));seat("ADD_FOREST_LISTEN",p+Vector3(0,.1,-1),0)
	for i in w.layout.config.get("hidden_views",[]).size():
		var view:Dictionary=w.layout.config.hidden_views[i];var at:Vector3=w.layout.vector(view.point)
		b.box(at-Vector3(0,.12,0),Vector3(8,.24,6),"aa906c",true,0,"wood")
		rail(at+Vector3(4,0,-3),at+Vector3(4,0,3))
		rail(at+Vector3(-4,0,-3),at+Vector3(-4,0,-1.8));rail(at+Vector3(-4,0,1.8),at+Vector3(-4,0,3))
		rail(at+Vector3(-4,0,-3),at+Vector3(4,0,-3));b.bench(at+Vector3(1,0,-1));b.text3d(view.name,at+Vector3(-2,1.4,1),.008,"5e4232")
		w.interact(view.id,at+Vector3(0,0,1),"山海手札机位 · E 留影","bay_hidden",{"index":i})
	for x in [-5.5,5.5]:
		var wash:=SpotLight3D.new();wash.position=Vector3(x,y+.8,46);wash.rotation.x=-.60;wash.light_color=Color("ffe6c0");wash.spot_range=24;wash.spot_angle=33;wash.light_energy=0;wash.shadow_enabled=false;w.add_child(wash);w.night_lights.append(wash)
	var studio:Dictionary=w.layout.venues.B09
	w.interact("ADD_B09_MONITOR_POSE",Vector3(studio.x+4,studio.floor_y,studio.z+2.3),"监听耳机 / 抱吉他 · X","bay_pose",{})
	w.set_meta("bay_finishings",{"upper_annexes":w.layout.config.get("annexes",{}).size(),"plaza_wish_basin":true,"two_level_plaza":true,"frames":13})

func street_wings():
	for wing in w.layout.config.street_wings:
		var p:Vector3=w.layout.vector(wing.center);var width:float=wing.size[0];var depth:float=wing.size[1];b.venue_context=wing.owner
		b.box(p-Vector3(0,.22,0),Vector3(width,.44,depth),"c1ad8b",true,0,"stone")
		# Two usable street portals, thick recessed window bays and a supported low roof.
		for side in [-1,1]:
			for flank in [-1,1]:
				var span:float=(width-3.4)*.5;var x:float=flank*(width+3.4)*.25
				b.box(p+Vector3(x,.6,side*depth*.5),Vector3(span,1.2,.65),"e2d5c1",true,0,"stone")
				b.box(p+Vector3(x,3.55,side*depth*.5),Vector3(span,.75,.65),"f4efe6",true,0,"plaster")
				b.glass(p+Vector3(x,2.2,side*(depth*.5-.22)),Vector3(span-.28,1.8,.04))
				b.collision(p+Vector3(x,2.2,side*depth*.5),Vector3(span-.28,1.8,.15))
				for edge in [-1,1]:b.box(p+Vector3(x+edge*span*.5,2.2,side*(depth*.5+.22)),Vector3(.16,2.0,.24),"5e4232")
			b.box(p+Vector3(0,3.55,side*depth*.5),Vector3(3.4,.75,.65),"f4efe6",true,0,"plaster")
			b.box(p+Vector3(side*width*.5,1.95,0),Vector3(.55,3.9,depth),"f4efe6",true,0,"plaster")
			b.box(p+Vector3(side*(width*.5+.1),.12,0),Vector3(.75,.24,depth+.8),"c1ad8b",false,0,"stone")
		load("res://scripts/architecture120.gd").new(w).wing_roof(wing,p,Vector2(width,depth))
		b.text3d(wing.name,p+Vector3(0,3.55,depth*.5+.40),.008,"5e4232")
		for zz in [-depth*.25,depth*.25]:
			b.table(p+Vector3(-width*.24,0,zz),1.7);cushion(p+Vector3(-width*.24,0,zz+1.2),PI)
			seat("ADD_WING_"+wing.id+"_"+str(int(zz*10)),p+Vector3(-width*.24,0,zz+1.2),PI)
		b.shelf(p+Vector3(width*.3,0,-depth*.25),2.1)
		b.box(p+Vector3(width*.3,1.1,depth*.2),Vector3(2.6,2.2,.7),"5e4232",true,0,"wood")
		w.interact("ADD_WING_"+wing.id,p+Vector3(width*.3,0,depth*.2+1),"侧间专属活动 · F","bay_activity",{"activity":wing.activity})
		for index in [0,1]:
			var landing:Vector3=p+Vector3(0,0,(depth*.5+1.3)*(1 if index==0 else -1))
			b.ramp(landing+Vector3(0,0,1.1 if index==0 else -1.1),landing-Vector3(0,0,.4 if index==0 else -.4),3.2,"e2d5c1")
		var link:Array=wing.link;var a:Vector3=w.layout.vector(link[0]);var end:Vector3=w.layout.vector(link[1]);var pergola_center:Vector3=(a+end)*.5
		# Stop the sloping link on the flat forecourt. Its old end cap protruded
		# through the first interior floor sample instead of ending outside the door.
		if wing.id=="LISTENING_EAST":a+=(Vector3(end.x,a.y,end.z)-a).normalized()
		b.ramp(a,end,2.6,"c9b695")
		preload("res://scripts/bay_authoring.gd").new(w).pergola(pergola_center,Vector2(3.0,3.5))
		for bound in w.building_bounds:
			if bound.id==wing.owner:
				if not bound.has("extra_bounds"):bound.extra_bounds=[]
				bound.extra_bounds.append({"x":p.x,"z":p.z,"w":width,"d":depth,"y":p.y,"h":4.0})
		load("res://scripts/architecture120.gd").new(w).wing_details(wing,p,Vector2(width,depth))
		var glow:=OmniLight3D.new();glow.position=p+Vector3(0,2.8,0);glow.omni_range=7;glow.light_color=Color("ffcf94");glow.light_energy=.4;glow.shadow_enabled=false;w.add_child(glow)
		b.venue_context=""
	w.set_meta("bay_street_wings",w.layout.config.street_wings)

func waterfall_pools():
	# Three connected rest basins lie on the existing eastern steep reach, away from the navigable river.
	for i in 3:
		var t:float=float(i)/2;var p:Vector3=w.layout.vector([lerpf(311,315,t),lerpf(55,35,t),lerpf(-330,-320,t)])
		var pool:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(9.4,3.3);pool.mesh=plane;pool.position=p+Vector3(0,.035,0)
		var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/coastal_water.gdshader");preload("res://scripts/bay_authoring.gd").new(w).set_water_curve(mat);pool.material_override=mat;w.add_child(pool)
		for side in [-1,1]:
			for j in 4:
				var at:Vector3=p+Vector3(side*(5.4+j*.52),-.1+sin(j*1.7)*.26,sin(j*2.399)*2.1)
				b.shape(at,Vector3(2.2,1.4,2.3),["818d80","9b9c85","7d8878"][j%3],"rock",j*.6)
				b.shape(at+Vector3(0,.57,0),Vector3(1.5,.17,1.4),"74865b","shrub")
			var at:Vector3=p+Vector3(side*7,0,2.5);b.box(at+Vector3(0,.6,0),Vector3(.7,1.2,.7),"8c857b",false,0,"stone");b.glow_box(at+Vector3(0,1.25,0),Vector3(.42,.36,.42))
	w.set_meta("bay_waterfall_basins",3)

func framing_groves():
	var sites:Array=[[-135,267,"lemon"],[-64,199,"lemon"],[180,-208,"magnolia"],[282,-222,"cherry"],[-277,-272,"cherry"],[288,-282,"maple"],[-26,-390,"cherry"]]
	for site in sites:
		var p:Vector3=w.surface(site[0],site[1]);var tone:String="f4b8c4" if site[2]=="cherry" else "faf6f0" if site[2]=="magnolia" else "b5b868" if site[2]=="lemon" else "bb876a"
		b.box(p+Vector3(0,1.5,0),Vector3(.4,3,.4),"786047",false,0,"wood")
		for j in 5:
			var a:float=j*2.399;var at:Vector3=p+Vector3(cos(a)*1.2,3.5+sin(j)*.55,sin(a)*1.2);b.beam(p+Vector3(0,2.4,0),at,.18,"786047")
			b.shape(at,Vector3(2.3,1.5,2.1),tone,"shrub")
			if site[2]=="lemon":
				for k in 3:b.shape(at+Vector3(sin(k*2.5)*.7,-.65,cos(k*2.5)*.7),Vector3(.22,.30,.22),"f2c14e","shrub")
		for j in 3:b.shape(p+Vector3(sin(j*2.4),.24,cos(j*2.4)),Vector3(.9,.48,.8),"859866","shrub")
	for at in [w.surface(-114,217),w.surface(181,-207),w.layout.vector([-20,73.5,-396])]:
		for j in 12:b.shape(at+Vector3(sin(j*2.1)*2.8,3.0-(j%4)*.2,cos(j*2.1)*2.5),Vector3(.45,.8,.40),"9b7ede","shrub")

func limit_room_lights():
	var groups:Dictionary={}
	for light in w.find_children("*","OmniLight3D",true,false):
		var id:String=w.inside_building(light.position)
		if id.is_empty() or id in ["B06","B08","B10"]:continue
		if not groups.has(id):groups[id]=[]
		groups[id].append(light)
	var counts:Dictionary={}
	for id in groups:
		var lights:Array=groups[id];counts[id]=mini(4,lights.size())
		for i in range(4,lights.size()):
			w.night_lights.erase(lights[i]);w.home_lights.erase(lights[i]);lights[i].free()
	w.set_meta("bay_room_light_counts",counts)
