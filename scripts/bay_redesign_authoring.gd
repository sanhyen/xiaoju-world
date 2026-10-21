extends RefCounted
## Structural repairs and terrain-attached district. Runtime moving objects live in bay_workshops.
var w
var b
var l
var trim:="5e4232"
var stone:="8c857b"
func _init(world):w=world;b=w.b;l=w.layout
func rail(a:Vector3,c:Vector3):load("res://scripts/bay_finishings.gd").new(w).rail(a,c)
func act(id:String,p:Vector3,title:String,topic:String):w.interact(id,p,title+" · F 操作","redesign",{"topic":topic})
func sign_at(p:Vector3,words:String):
	b.box(p+Vector3(0,1,0),Vector3(.18,2,.18),trim,true,0,"wood")
	b.box(p+Vector3(0,1.7,0),Vector3(3.5,.72,.15),"647e70",false,0,"wood")
	b.text3d(words,p+Vector3(0,1.7,.09),.006,"f4efe6")
func shelf(p:Vector3,tone:String="b78b60"):
	b.shelf(p,2.5)
	for i in 7:b.shape(p+Vector3(-1+i*.32,.65+(i%2)*.65,.12),Vector3(.22,.25,.22),tone,"pot")
func worktable(p:Vector3):b.table(p,2.7)
func oven(p:Vector3):
	b.box(p+Vector3(0,.75,0),Vector3(2,1.5,1.5),"b5a28b",true,0,"stone")
	b.box(p+Vector3(0,.65,.76),Vector3(1.3,.72,.03),"43392d")
	b.box(p+Vector3(0,2.2,-.45),Vector3(.65,1.7,.65),"8c857b",true,0,"stone")
	for i in 5:b.box(p+Vector3(-.5+i*.25,.42,.79),Vector3(.12,.08,.1),"d6a459")
func rack(p:Vector3,tone:String):
	for x in [-1.2,1.2]:b.box(p+Vector3(x,1.1,0),Vector3(.12,2.2,.12),trim,true,0,"wood")
	b.box(p+Vector3(0,2.2,0),Vector3(2.6,.12,.12),trim)
	for i in 7:
		b.beam(p+Vector3(-1+i*.33,2.1,0),p+Vector3(-1+i*.33,1.4,0),.025,"baa98b")
		b.shape(p+Vector3(-1+i*.33,1.4,0),Vector3(.23,.48,.21),tone,"shrub")

func build():
	wading_loop();district();neighborhoods();route_nodes();structural_seals();workshop_nodes()
	for h in l.config.living_houses:house_theme(h)
	for wing in l.config.street_wings:wing_theme(wing)
	for i in l.config.extra_places.size():
		var place:Dictionary=l.config.extra_places[i]
		if str(place.id).begins_with("VILLA_WADE_"):
			var p:Vector3=load("res://scripts/location_registry.gd").destination(w.spec,place)
			w.interact("INFO_"+place.id,p,place.name,"info",{"title":place.name,"body":"五级木梯连到白沙承接台，沿浅沙路可步行绕岛回到公共沙滩。礁石外是船只航道。"})
	w.set_meta("redesign105",{"house_themes":14,"wings":4,"cliff_buildings":6,"wading_ring":true,"future_island_built":not l.config.get("island2",{}).is_empty()})

func villa_access(index:int,o:Vector3):
	var z:float=o.z+8.5;var top:Vector3=Vector3(o.x+3.8,o.y,z);var bottom:=Vector3(o.x+7.8,-2.8,z)
	# Five solid treads rise by 0.394 m, below the normal 0.4 m character step limit.
	for i in 5:
		var y:float=lerpf(o.y,-2.8,float(i+1)/5);var x:float=o.x+4.2+i*.8
		b.box(Vector3(x,y-.14,z),Vector3(.85,.28,2.0),"947255",true,0,"wood")
	b.ramp(top,bottom,1.8,"947255")
	b.box(bottom-Vector3.UP*.14,Vector3(3.5,.28,3.5),"f5ebd6",true,0,"stone")
	for side in [-1,1]:rail(top+Vector3(0,0,side*1.05),bottom+Vector3(0,0,side*1.05))
	# Terrace perimeter has a real opening at the stair; walking surfaces overlap at all corners.
	rail(o+Vector3(-4,0,4),o+Vector3(-4,0,10))
	rail(o+Vector3(-4,0,10),o+Vector3(4,0,10))
	rail(o+Vector3(4,0,4),o+Vector3(4,0,7.3))
	sign_at(Vector3(o.x+2,-.73,o.z+9.7),"亲水木梯 ↓ 白沙环路")

func wading_loop():
	for route in l.config.wading_paths:
		for i in route.points.size()-1:
			var a:Vector3=l.vector(route.points[i]);var c:Vector3=l.vector(route.points[i+1]);b.ramp(a,c,route.width,"f5ebd6")
			b.box(a-Vector3.UP*.12,Vector3(route.width+.1,.24,route.width+.1),"f5ebd6",true,0,"stone")
			if route.id!="island_wade_ring":continue
			var tangent:Vector3=(c-a).normalized();var outer:=Vector3(tangent.z,0,-tangent.x)
			# Low submerged reefs mark the shelf without fencing off the sailing water.
			var n:int=maxi(1,ceili(a.distance_to(c)/4))
			for j in n:
				var at:Vector3=a.lerp(c,float(j)/n)+outer*(float(route.width)*.5+1.0)
				b.shape(at+Vector3.UP*.08,Vector3(1.1,.55,1.2),["8ea99d","a5b6a3","92aaa7"][j%3],"rock")
				b.collision(at+Vector3.UP*.08,Vector3(.9,.45,.9))
				var end:Vector3=a.lerp(c,float(j+1)/n)+outer*(float(route.width)*.5+1.0)
	# Boundary navigation buoys, visibly separate from the natural shallow reef.
	for x in range(-440,446,18):buoy(Vector3(x,-2.4,635))
	for z in range(388,635,18):buoy(Vector3(445,-2.4,z))
	for z in range(402,635,18):buoy(Vector3(-455,-2.4,z))
	for i in 8:
		var angle:float=i*TAU/8;var p:=Vector3(223+cos(angle)*46,-2.85,452+sin(angle)*35)
		var routes:Array=l.near(l.wading_index,Vector2(p.x,p.z))
		if routes.is_empty():continue
		var near:Vector3=l.projection(Vector2(p.x,p.z),routes[0]);p=near
		b.shape(p+Vector3(.8,.12,0),Vector3(.27,.20,.30),"eccdb4","shrub")
		w.interact("RD_CONCH_"+str(i),p,"浅滩拾螺","bay_pick",{"material":"conch"})

func buoy(p:Vector3):
	b.shape(p+Vector3.UP*.18,Vector3(.8,.35,.8),"e1a268","post")
	b.box(p+Vector3.UP*.65,Vector3(.18,.8,.18),"faf6f0")
	b.glow_box(p+Vector3.UP*1.13,Vector3(.24,.25,.24))

func district():
	var cfg:Dictionary=l.config.cliff_district
	# These rock bodies continue into the terrain, never stand on a detached slab.
	for edge in [[266.0,21.0,7.0],[305.0,14.5,9.0]]:
		for z in range(-36,85,4):
			if (edge[0]==266 and z>26 and z<48) or (edge[0]==305 and z>62):continue
			if not w.clear_of_paths(Vector2(edge[0],z),2.2):continue
			var p:=Vector3(edge[0],edge[1]-edge[2]*.5,z)
			b.box(p,Vector3(1.5,edge[2],4.15),stone,true,0,"stone")
			for j in 3:b.box(p+Vector3(.78,(j-1)*1.6,.2*(j%2)),Vector3(.16,.045,4.1),"b7ad9b")
	for house in cfg.buildings:cliff_house(house)
	var cave:Dictionary=cfg.tunnel;var a:=Vector3(cave.a[0],cave.a[1],cave.a[2]);var c:=Vector3(cave.b[0],cave.b[1],cave.b[2])
	b.ramp(a-Vector3(2,0,0),c+Vector3(2,0,0),3.2,"b8aa92")
	for side in [-1,1]:
		b.box((a+c)*.5+Vector3(0,1.8,side*2.05),Vector3(19,3.6,.9),stone,true,0,"stone")
		for i in 6:
			var p:Vector3=a+Vector3(i*3.2,1.9,side*1.62);b.box(p,Vector3(.7,.8,.18),trim);b.glow_box(p+Vector3(0,0,-side*.12),Vector3(.34,.45,.1))
	b.box((a+c)*.5+Vector3.UP*4.4,Vector3(21,1.1,7),stone,true,0,"stone")
	for i in 7:
		for side in [-1,1]:b.box(a+Vector3(i*3,3.6,side*1.7),Vector3(.3,.4,.5),"bcae96",true,0,"stone")
	sign_at(a-Vector3(2,0,-2.7),"穿岩洞廊 · 开闸后贯通")
	act("RD_WATERWHEEL",Vector3(320,6,-9),"水轮连动观察台","wheel")
	# Actual three-tier stone channels and downfalls from the clock tower.
	for i in cfg.water_course.size()-1:
		var start:Array=cfg.water_course[i];var end:Array=cfg.water_course[i+1]
		var p:=Vector3(start[0],start[1],start[2]);var q:=Vector3(end[0],end[1],end[2])
		if absf(p.y-q.y)<.1:
			b.ramp(p-Vector3.UP*.2,q-Vector3.UP*.2,1.8,stone)
			for sign in [-1,1]:b.beam(p+Vector3(0,0,sign*.85),q+Vector3(0,0,sign*.85),.3,stone)
			for x in range(int(p.x)+2,int(q.x),5):b.box(Vector3(x,(p.y+6)*.5,p.z),Vector3(.6,p.y-6,.6),stone,true,0,"stone")
	# A bridge opens the upper street directly onto the loom roof terrace.
	b.ramp(Vector3(258,18,27),Vector3(276,18,27),3.4,"aa906c")
	for z in [25.25,28.75]:rail(Vector3(258,18,z),Vector3(276,18,z))
	# North welcome tea seat retains the legacy ID and coordinates.
	var welcome:Vector3=w.surface(290,-70);load("res://scripts/bay_authoring.gd").new(w).pergola(welcome,Vector2(6,5));sign_at(welcome+Vector3(-4,0,2),"北口溪谷 · 艺文山路")
	var guards=preload("res://scripts/bay_guardrails.gd").new(w)
	for span in l.segments:
		guards.span(span.a,span.c,float(span.width),str(span.id).begins_with("z09") and maxf(span.a.y,span.c.y)>=9)
	for h in cfg.buildings:
		var p:=Vector3(h.center[0],h.center[1],h.center[2])
		guards.pad(p,Vector2(h.size[0],h.size[1]),false)
		if h.role in ["pottery","loom","wheel"]:
			guards.pad(Vector3(p.x,h.upper_y,p.z),Vector2(h.size[0]+.5,h.size[1]+.5),false)
			for i in h.stairs.size()-1:
				var from_step:Array=h.stairs[i];var to_step:Array=h.stairs[i+1];guards.span(Vector3(from_step[0],from_step[1],from_step[2]),Vector3(to_step[0],to_step[1],to_step[2]),2.8,false)
	guards.span(Vector3(258,18,27),Vector3(276,18,27),3.4,false)
	# The sunken viewing terrace and its right-angle street arrival are one floor.
	b.box(Vector3(250,17.88,36),Vector3(3.2,.24,3.2),"c9b695",true,0,"stone")
	guards.pad(Vector3(250,18,36),Vector2(3.2,3.2));guards.pad(Vector3(250,18,30),Vector2(16,6),false)
	guards.build("z09_street",true)
	for p in [Vector3(350,6,78),Vector3(238,18,36),Vector3(244,21,-35)]:sign_at(p+Vector3(-4,0,0),"崖湾嵌岩聚落 · 三级石街")

func rail_open(p:Vector3,id:String)->bool:
	if p.x>266 and p.x<302 and absf(p.z+31)<3.5:return true
	if p.x>240 and p.x<260 and p.z>25 and p.z<37:return true
	for other in l.segments:
		if str(other.id)==id:continue
		var q:Vector3=l.projection(Vector2(p.x,p.z),other)
		if absf(q.y-p.y)<2 and Vector2(p.x-q.x,p.z-q.z).length()<float(other.width)*.5+1:return true
	return false

func cliff_house(h:Dictionary):
	var center:Array=h.center;var p:=Vector3(center[0],center[1],center[2]);var width:float=h.size[0];var depth:float=h.size[1];var high:float=float(h.upper_y)-p.y
	b.venue_context=h.id
	b.box(p-Vector3.UP*.7,Vector3(width+.6,1.4,depth+.6),"c4b391",true,0,"stone")
	for side in [-1,1]:
		b.box(p+Vector3(side*width*.5,high*.5,0),Vector3(.65,high,depth+.4),"f4efe6",true,0,"plaster")
		var wing:float=(width-3.4)*.5
		b.box(p+Vector3(side*(width+3.4)*.25,.55,depth*.5),Vector3(wing,1.1,.65),stone,true,0,"stone")
		b.box(p+Vector3(side*(width+3.4)*.25,3.85,depth*.5),Vector3(wing,1.3,.65),"f4efe6",true,0,"plaster")
		b.glass(p+Vector3(side*(width+3.4)*.25,2.2,depth*.5),Vector3(wing-.3,2.1,.06));b.collision(p+Vector3(side*(width+3.4)*.25,2.2,depth*.5),Vector3(wing,2.1,.15))
		b.box(p+Vector3(side*(width*.5-.15),2.25,depth*.5),Vector3(.35,high,.85),trim,true,0,"wood")
		# Solid stepped back foundations, embedded behind the usable room.
		b.box(p+Vector3(side*(width*.5+.7),-1.2,-depth*.18),Vector3(1.4,2.4,depth*.7),stone,true,0,"stone")
	b.box(p+Vector3(0,high*.5,-depth*.5),Vector3(width+.5,high,.75),stone,true,0,"stone")
	b.box(p+Vector3(0,4,depth*.5),Vector3(3.4,1,.65),"f4efe6",true,0,"plaster")
	if h.role=="sluice":
		# The clock gallery has an actual stairwell, rather than a full collision slab.
		b.box(p+Vector3(-1.3,high-.14,0),Vector3(width-2.7,.28,depth),"aa906c",true,0,"wood")
		b.box(p+Vector3(2.9,high-.14,-depth*.5+.9),Vector3(3.2,.28,1.8),"aa906c",true,0,"wood")
	else:b.box(p+Vector3(0,high-.14,0),Vector3(width+.5,.28,depth+.5),"aa906c",true,0,"wood")
	if h.role in ["pottery","loom","wheel"]:
		var steps:Array=h.stairs
		for i in steps.size()-1:
			var a:=Vector3(steps[i][0],steps[i][1],steps[i][2]);var c:=Vector3(steps[i+1][0],steps[i+1][1],steps[i+1][2])
			if absf(a.y-c.y)>.1:load("res://scripts/bay_finishings.gd").new(w).flight(a,c,2.5)
			else:b.ramp(a,c,2.8,"aa906c")
		for step in steps:
			b.box(Vector3(step[0],step[1]-.12,step[2]),Vector3(2.8,.24,2.8),"aa906c",true,0,"wood")
		var guards=preload("res://scripts/bay_guardrails.gd").new(w)
		guards.pad(p+Vector3.UP*high,Vector2(width+.5,depth+.5))
		for i in steps.size()-1:
			guards.span(Vector3(steps[i][0],steps[i][1],steps[i][2]),Vector3(steps[i+1][0],steps[i+1][1],steps[i+1][2]),2.8)
		for step in steps:guards.pad(Vector3(step[0],step[1],step[2]),Vector2(2.8,2.8))
		for span in l.segments:guards.span(span.a,span.c,float(span.width),false)
		guards.span(Vector3(258,18,27),Vector3(276,18,27),3.4,false)
		guards.build("cliff_roof_"+h.id,true)
		if h.role=="pottery":
			rack(p+Vector3(-4,high,-4),"c29a6c");act("RD_POTTERY_RACK",p+Vector3(-2,high,0),"屋顶晒架陈列","pottery_rack")
	else:load("res://scripts/architecture120.gd").new(w).cliff_roof(h,p,Vector2(width,depth))
	b.text3d(h.name,p+Vector3(0,3.9,depth*.5+.5),.010,"5e4232")
	worktable(p+Vector3(-3,0,-1.4));shelf(p+Vector3(-width*.3,0,-depth*.35),"ad9977")
	var seat_x:float=-width*.28 if h.role=="sluice" else width*.28
	b.bench(p+Vector3(seat_x,0,1.4),PI)
	act("RD_"+h.id,p+Vector3(0,0,1.4),h.name,h.role)
	w.interact(h.id+"_SEAT",p+Vector3(seat_x,0,2.5),"窗前歇脚 · X","sit",{"seat":p+Vector3(seat_x,.08,1.4),"yaw":PI})
	w.building_bounds.append({"id":h.id,"x":p.x,"z":p.z,"w":width,"d":depth,"y":p.y,"h":high})
	if h.role=="loom":
		# Two legs support an actual open arcade underneath the roof-level passage.
		for z in [16.0,30.0]:
			b.box(Vector3(264,15.9,z),Vector3(.75,4.2,.75),stone,true,0,"stone")
			b.beam(Vector3(260,17.85,z),Vector3(270,17.85,z),.6,stone)
	if h.role=="lookout":
		b.box(p+Vector3(0,-1.62,8),Vector3(16,.24,6),"aa906c",true,0,"wood")
		b.ramp(p+Vector3(0,0,5),p+Vector3(0,-1.5,10),3.2,"c9b695")
		for x in [-8,8]:
			if x<0:rail(p+Vector3(x,-1.5,5),p+Vector3(x,-1.5,11))
		rail(p+Vector3(-8,-1.5,11),p+Vector3(-2,-1.5,11));rail(p+Vector3(2,-1.5,11),p+Vector3(8,-1.5,11))
		for side in [-1,1]:b.planter(p+Vector3(side*6,-1.5,8),2,"f4b8c4")
	# Recessed window frames, braced eaves, flower ledges and supported roof gardens.
	for side in [-1,1]:
		var x:float=side*(width+3.4)*.25
		for dx in [-1.2,1.2]:b.box(p+Vector3(x+dx,2.25,depth*.5+.35),Vector3(.18,2.35,.65),trim,false,0,"wood")
		b.box(p+Vector3(x,1.1,depth*.5+.45),Vector3(2.8,.18,.8),trim,false,0,"wood")
		for j in 5:b.shape(p+Vector3(x-.9+j*.45,1.25,depth*.5+.5),Vector3(.30,.28,.28),["f4b8c4","f2c14e","6ba4d6","9b7ede","faf6f0"][j],"flower")
		for z in [-depth*.3,depth*.3]:b.beam(p+Vector3(side*width*.5,high-.6,z),p+Vector3(side*(width*.5+.7),high,z),.17,trim)
	if h.role in ["wheel","pottery","loom"]:
		for x in [-width*.35,width*.35]:b.planter(p+Vector3(x,high,depth*.5-1),1.5,"9b7ede" if h.role=="loom" else "f4b8c4")
		load("res://scripts/bay_authoring.gd").new(w).pergola(p+Vector3(-width*.2,high,-1),Vector2(4,3))
		if h.role=="loom":
			for i in 8:b.box(p+Vector3(-3+i*.8,high+2.3,1),Vector3(.5,.7,.03),["7c9eae","a1b8b9","d2c5a4"][i%3],false,0,"fabric")
	load("res://scripts/architecture120.gd").new(w).cliff_details(h,p,Vector2(width,depth))
	if h.role=="sluice":
		for bound in w.building_bounds:
			if bound.id==h.id:bound.h=11.5
	b.venue_context=""

func house_theme(h:Dictionary):
	var p:Vector3=l.vector(h.center);var width:float=h.size[0];var depth:float=h.size[1]
	var table:Vector3=p+Vector3(0,0,-1.5);worktable(table)
	match h.id:
		"H01":
			oven(p+Vector3(1.4,0,-depth*.35));b.shape(table+Vector3(-.8,1.15,0),Vector3(.8,.25,.8),"8c857b","post")
			rack(p+Vector3(-2,3.4,depth*.5+1.5),"e4c777")
			for side in [-1,1]:b.box(p+Vector3(side*(width*.5+1),.45,depth*.5+3),Vector3(2,.9,2),"d1b676",true,0,"fabric")
		"H02":
			for i in 4:
				var q:Vector3=p+Vector3(-2.4+i*1.6,.35,-depth*.35);b.box(q,Vector3(1.3,.7,.9),"b69266",true,0,"wood");b.shape(q+Vector3(0,.36,0),Vector3(1,.15,.7),["dab96b","e2a16c","d4c463","bc7161"][i],"shrub")
			for i in 5:
				b.box(p+Vector3(-width*.5+.4,1.7,-3+i),Vector3(.07,1.8,.07),"ac8b62");b.box(p+Vector3(-width*.5+.4,2.5,-3+i),Vector3(.12,.2,.6),"8b9c93")
			var well:Vector3=w.surface(p.x-4,p.z+depth*.5+5);b.shape(well+Vector3.UP*.5,Vector3(1.7,1,1.7),stone,"post");b.shape(well+Vector3.UP*1.01,Vector3(1.1,.03,1.1),"567873","post")
			load("res://scripts/bay_authoring.gd").new(w).pergola(well,Vector2(2.4,2.4))
			b.box(p+Vector3(3,1.8,-depth*.5+.4),Vector3(2.1,1.25,.12),"486359")
			b.box(well+Vector3(3,.5,0),Vector3(1.5,.65,.85),"b69266");b.shape(well+Vector3(3,.22,-.6),Vector3(.6,.6,.2),trim,"post")
		"H03":
			for i in 5:
				b.box(p+Vector3(-2+i,1.9,-depth*.5+.35),Vector3(.8,1.1,.08),["c0d6c2","a8c8d0","d4bb9a","d5b2be","9fb7b0"][i])
				b.shape(table+Vector3(-1+i*.5,1.2,0),Vector3(.22,.25,.22),["ba766b","6b8ca3","c5ae6a"][i%3],"pot")
			b.glass(p+Vector3(0,6.1,0),Vector3(4,.04,2.6));act("RD_H03_EASEL",p+Vector3(2,3.4,1),"阁楼画框取景","frame")
		"H04":
			rack(p+Vector3(0,2.2,-depth*.25),"dbb765");shelf(p+Vector3(3.5,0,-depth*.3),"d1a15f")
			for side in [-1,1]:
				var q:Vector3=w.surface(p.x+side*5,p.z+depth*.5+5);b.tree(q,2,.7)
				for i in 8:b.shape(q+Vector3(sin(i*2.4)*1.4,2.7+cos(i)*.3,cos(i*2.4)*1.4),Vector3(.25,.30,.25),"f2c14e" if side<0 else "e6ae5d","shrub")
		"H05":
			b.box(table+Vector3(0,1.04,0),Vector3(2.3,.04,1.1),"d8d0aa")
			for i in 8:b.box(table+Vector3(-1+i*.3,1.07,sin(i)*.25),Vector3(.16,.025,.4),"72938c")
			shelf(p+Vector3(3.5,0,-depth*.3),"a5c1b6");act("RD_H05_SCOPE",p+Vector3(2,3.4,depth*.5+1.5),"阁楼黄铜望远镜","scope")
		"H06":
			var q:Vector3=w.surface(p.x-4,p.z+depth*.5+7);load("res://scripts/bay_authoring.gd").new(w).pergola(q,Vector2(5,4))
			for i in 16:b.shape(q+Vector3(sin(i*2.3)*2,3-i%3*.25,cos(i*2.3)*1.5),Vector3(.4,.8,.4),"9b7ede","shrub")
			for x in [-1.7,1.7]:b.box(q+Vector3(x,.9,0),Vector3(.12,1.8,.12),trim,true)
			b.box(q+Vector3(0,.7,0),Vector3(3.2,.14,1.5),"d4c5a8",true,0,"fabric");w.interact("RD_H06_HAMMOCK",q+Vector3(0,0,1.3),"紫藤双人吊床 · X","bay_netbed",{"seat":q+Vector3(0,.7,0),"yaw":PI*.5})
		"H07":
			oven(p+Vector3(0,0,-depth*.35));rack(p+Vector3(-4,0,-3),"8d7458")
			for i in 8:b.box(p+Vector3(2.2+i%3*.2,.16+i/3*.16,-3),Vector3(.13,.14,.7),"92714e",false,0,"wood")
		"H08":
			for i in 3:
				var q:Vector3=p+Vector3(-3+i*2,3.4,-depth*.3);b.table(q,1.5);b.glass(q+Vector3.UP*1.3,Vector3(1.3,.6,.8));b.shape(q+Vector3.UP*1.2,Vector3(.4,.35,.4),["b7c58d","caa9c1","b6ac81"][i],"shrub")
			act("RD_H08_SPECIMEN",p+Vector3(0,3.4,0),"阁楼植物标本夹","specimen")
		"H09":
			for i in 5:b.box(p+Vector3(-2+i,2.15,-depth*.5+.35),Vector3(.7,1.9,.07),["e6d5ae","818caa","bfa5bb","d4bd78","f4efe6"][i],false,0,"fabric")
			rack(p+Vector3(3,0,-3),"f4b8c4")
		"H10":
			for i in 8:b.shape(table+Vector3(-1+i%4*.65,1.1,-.3+i/4*.6),Vector3(.25,.22,.25),"b89b64","post")
			b.box(p+Vector3(3,1.0,-depth*.3),Vector3(2.5,.18,1.5),"7f9a85",true)
			for i in 8:b.box(p+Vector3(2.1+i%4*.55,1.3+i/4*.15,-depth*.3-.3+i/4*.6),Vector3(.35,.5,.35),"e6d8c0")
		"H11":
			for i in 5:b.shape(p+Vector3(-2+i,2,-depth*.5+.3),Vector3(.6,.6,.08),"bca370","post")
			b.box(p+Vector3(0,2.1,depth*.5+.45),Vector3(3.2,.6,.4),trim)
		"H12":
			var q:Vector3=w.surface(p.x-3,p.z+depth*.5+3);b.box(q+Vector3.UP*.9,Vector3(.65,1.8,.6),"b76b58",true,0,"wood");b.box(q+Vector3(0,1.25,.32),Vector3(.4,.08,.03),"473f38")
			for y in [1.7,2.5]:b.beam(p+Vector3(-4,y,-depth*.5+.5),p+Vector3(4,y,-depth*.5+.5),.025,"cfb991")
			var red:=OmniLight3D.new();red.position=p+Vector3(0,2.6,0);red.light_color=Color("ed8065");red.omni_range=7;red.light_energy=.45;red.shadow_enabled=false;w.add_child(red)
		"H13":
			rack(p+Vector3(3,0,-3),"c3a3c8");b.box(table+Vector3(0,1.13,0),Vector3(1.2,.16,.8),trim,true,0,"wood")
			for i in 4:b.shape(table+Vector3(-1+i*.6,1.3,-.5),Vector3(.18,.45,.18),"eddcb6","post")
		"H14":
			b.shape(p+Vector3(0,1.4,-3),Vector3(1.2,1.1,1.2),"b99c62","post")
			for i in 5:b.box(p+Vector3(2+i%2*.7,.3+i/2*.4,-3),Vector3(.6,.6,.7),"bba67b",false,0,"fabric")
			for i in 4:
				b.box(p+Vector3(-4,1.7,-2),Vector3(.24,3.4,.24),trim,true,0,"wood");b.box(p+Vector3(-4+.3*(i%2),.6+i*.8,-2),Vector3(1.1,.14,1.1),"c3b28f",true,0,"wood")
			act("RD_H14_CAT",w.surface(p.x-3,p.z+depth*.5+4),"猫咪小院 · 放小鱼干","cat")

func wing_theme(wing:Dictionary):
	var p:Vector3=l.vector(wing.center)+Vector3(wing.size[0]*.30,0,wing.size[1]*.2)
	if wing.id=="BAKERY":oven(p-Vector3(0,0,2.2))
	elif wing.id=="LISTENING_WEST":
		for i in 7:b.box(p+Vector3(-1+i*.3,1.4,-.2),Vector3(.08,.85,.8),["9b7e7e","9aaf9a","c6b68a"][i%3],false,0,"fabric")
	elif wing.id=="LISTENING_EAST":
		b.shape(p+Vector3(0,1.5,0),Vector3(.9,.9,.9),"b79b62","pot");b.box(p+Vector3(.7,1.3,0),Vector3(.5,.06,.06),trim)
	else:
		for i in 12:b.box(p+Vector3(-1+i%4*.45,1.2,-.5+i/4*.4),Vector3(.25,.10,.22),["7ce0d3","d8b9c4","e6c575","a4b6d4"][i%4])
	for a in w.interactions:
		if a.id=="ADD_WING_"+wing.id:a.kind="redesign";a.title=wing.name+" · F 操作";a.data={"topic":"wing_"+wing.id}

func upper_corner(id:String,p:Vector3):
	var names:Dictionary={"B01":"海湾行程牌","B02":"咖啡冲泡沙盘","B03":"黑胶封套陈列","B11":"手作材料抽屉","B04":"花材分类抽屉","B05":"光影取景百叶","B06":"手绘分镜桌","B07":"阁楼手札索引","B08":"舞台走位沙盘","B09":"木质节拍机构","B10":"舞台灯光模型","B12":"四季窗台花架","B13":"山海路线拼图"}
	if not names.has(id):return
	b.box(p+Vector3(0,.8,0),Vector3(1.7,1.6,.55),trim,true,0,"wood")
	b.box(p+Vector3(0,1.35,.31),Vector3(1.5,.75,.08),"d1c9ad")
	for i in 4:b.box(p+Vector3(-.55+i*.36,1.35,.37),Vector3(.22,.48,.07),["a0bfae","bd9eb7","d9be7e","94afc7"][i])
	act("RD_UPPER_"+id,p+Vector3(0,0,1.2),names[id],"upper_"+id)

func neighborhoods():
	for group in [["田园烘焙 · 农夫与画家",-276,239],["听潮双墅 · 观海与藤编",170,265],["花音手作巷",-137,224],["星光双廊 · 花艺与印章",36,105],["林间木舍 · 松果与标本",106,37]]:
		sign_at(w.surface(group[1],group[2]),group[0])
	# Low courtyard boundaries frame neighbors without obstructing front doors or roads.
	for h in l.config.living_houses:
		var p:Vector3=l.vector(h.center);var width:float=h.size[0];var z:float=h.size[1]*.5+4
		for sign in [-1,1]:
			b.box(p+Vector3(sign*(width*.25+1.3),.35,z),Vector3(width*.5-2.8,.7,.4),stone,true,0,"stone")
	var a:Vector3=l.vector(l.config.living_houses.filter(func(h):return h.id=="H14")[0].center)+Vector3(-5,0,8)
	var c:=Vector3(-106,4.6,257);b.ramp(a,c,2.4,"aa906c")
	for q in [a,c]:load("res://scripts/bay_authoring.gd").new(w).pergola(q,Vector2(2.5,3))

func route_nodes():
	# A compact physical wayfinding board links each themed route to the map controls.
	for spec in [[Vector2(284,252),"抵达与山海小镇", "TOWN"],[Vector2(-265,293),"花丘田园与云间山林","NATURE"],[Vector2(299,327),"环海亲水与珊瑚度假","SEA"]]:
		var p:Vector3=w.surface(spec[0].x,spec[0].y);sign_at(p,spec[1]);act("RD_TOUR_"+spec[2],p+Vector3(0,0,1.3),spec[1],"tour_"+spec[2])
	# Old garden seats gain supported terraces and short paths, IDs and seats remain usable.
	for action in w.interactions:
		if not str(action.id).begins_with("N05_SEAT"):continue
		var seat:Vector3=action.data.get("seat",action.pos);b.box(seat-Vector3.UP*.12,Vector3(4,.24,3.5),"c6b594",true,0,"stone")
		b.planter(seat+Vector3(-1.8,0,-1.2),1.7,"f4b8c4");rack(seat+Vector3(0,0,-1.8),"b6a1cc")
	var p:Vector3=w.surface(213,-285);load("res://scripts/bay_authoring.gd").new(w).pergola(p,Vector2(6,4));b.bench(p+Vector3(0,0,1))
	var tea:Vector3=l.vector([-20,73.5,-396]);rail(tea+Vector3(-6.5,0,-5),tea+Vector3(6.5,0,-5));rail(tea+Vector3(-6.5,0,-5),tea+Vector3(-6.5,0,4))
	act("RD_PINE_CHUTE",w.surface(-214,-316),"林间松果滑槽","pine_chute")
	b.ramp(w.surface(-215,-318,1.4),w.surface(-215,-314,.2),.6,"aa906c")

func structural_seals():
	# Every venue and home has closed wall corners and a foundation buried into terrain.
	for v in w.spec.buildings:
		seal_corners(Vector3(v.x,v.floor_y,v.z),float(v.w),float(v.d),float(v.get("h",5.0)))
	for h in l.config.living_houses:
		seal_corners(l.vector(h.center),float(h.size[0]),float(h.size[1]),6.8 if h.loft else 4.1)
	for wing in l.config.street_wings:seal_corners(l.vector(wing.center),wing.size[0],wing.size[1],4.1)
	for h in l.config.cliff_district.buildings:seal_corners(Vector3(h.center[0],h.center[1],h.center[2]),h.size[0],h.size[1],float(h.upper_y)-float(h.center[1]))
func seal_corners(p:Vector3,width:float,depth:float,high:float):
	b.box(p-Vector3.UP*.65,Vector3(width+.2,1.3,depth+.2),stone,true,0,"stone")
	for x in [-width*.5,width*.5]:
		for z in [-depth*.5,depth*.5]:b.box(p+Vector3(x,high*.5,z),Vector3(.6,high,.6),stone,true,0,"stone")
func workshop_nodes():
	for i in 3:
		var p:=Vector3(340,6,36+i*4)
		for j in 4:b.shape(p+Vector3(sin(j)*.7,.15,cos(j)*.5),Vector3(.55,.35,.45),["b99b7d","c0a585","ad8e70"][i],"shrub")
		act("RD_CLAY_"+str(i),p+Vector3(1,0,0),"崖脚矿泥 · 采集","clay_"+str(i))
	var kiln:=Vector3(330,5.5,55);oven(kiln);rack(Vector3(322,10.5,55),"b99b7d")
	# A supported bird nest balcony is accessible through the opened tunnel.
	var bird:=Vector3(272,14.5,-31);b.box(bird-Vector3.UP*.15,Vector3(8,.3,5),"aa906c",true,0,"wood")
	for z in [-33.5,-28.5]:rail(Vector3(268,14.5,z),Vector3(276,14.5,z))
	rail(Vector3(268,14.5,-33.5),Vector3(268,14.5,-28.5));b.ramp(bird,Vector3(278,14.5,-31),3.2,"aa906c")
	b.shape(bird+Vector3(-2,.65,-1.4),Vector3(1.2,.3,1),"aa906c","pot")
	for i in 3:b.shape(bird+Vector3(-2+i*.22,.87,-1.4),Vector3(.15,.2,.15),"e9dfc3","shrub")
	act("RD_NEST_STAMP",bird,"鸟巢露台 · 专属印章","cave_stamp")
	var pasture:Vector3=l.vector(l.config.pasture.center);act("RD_PASTURE_GATE",pasture+Vector3(1,0,21.7),"牧场木门","pasture_gate")
	var stage:Dictionary=l.venues.B10
	for i in 3:act("RD_STAGE_LEVER_"+str(i),Vector3(stage.x+10+i*.65,stage.floor_y,stage.z+7),["灯架与灯色","星空花海垂幕","干冰星雨"][i],"lever_"+str(i))
	for h in l.config.living_houses:slot_furniture(h.id,l.vector(h.center))
	var home:Dictionary=l.venues.B12;slot_furniture("B12",Vector3(home.x,home.floor_y,home.z))
	for id in ["B02","B03","B11"]:
		var v:Dictionary=l.venues[id];var p:=Vector3(v.x,v.floor_y+4,v.z+v.d*.5+4)
		upper_corner(id,p+Vector3(0,0,-1.5))
	# Retained sunset platform; the forest island is served by the new dual-island loop.
	var p:=Vector3(-365,2,385);b.box(p-Vector3.UP*.15,Vector3(5,.3,5),"aa906c",true,0,"wood")
	var shore:Vector3=w.surface(-365,370);b.ramp(shore,p,3.2,"aa906c")
	for x in [-2.5,2.5]:rail(p+Vector3(x,0,-2.5),p+Vector3(x,0,2.5))
	rail(p+Vector3(-2.5,0,2.5),p+Vector3(2.5,0,2.5));sign_at(p+Vector3(0,0,1),"西岬听涛台 · 双岛航线已开放")
	for index in [3,6]:
		var q:Vector3=l.vector(l.config.boat_docks[index].land);sign_at(q+Vector3(3,0,0),"星夜森屿航线 · 双岛已开放")
func slot_furniture(id:String,p:Vector3):
	b.box(p+Vector3(-4,1.22,-3),Vector3(1.2,.16,1.1),"aa906c",true,0,"wood")
	b.box(p+Vector3(-4,.6,-3),Vector3(.14,1.2,.14),trim,true,0,"wood")
	b.box(p+Vector3(3.5,1.32,-3),Vector3(1.2,.16,1.1),"aa906c",true,0,"wood")
	b.box(p+Vector3(3.5,.65,-3),Vector3(.14,1.3,.14),trim,true,0,"wood")
	b.box(p+Vector3(1,2.5,-4.58),Vector3(1.6,1.2,.10),trim,false,0,"wood")
	for i in 3:act("RD_SLOT_"+id+"_"+str(i),p+[Vector3(-4,0,-1.9),Vector3(3.5,0,-1.9),Vector3(1,0,-3.3)][i],"陈列槽 · E 预览 / F 摆放","slot:"+id+":"+str(i))
