extends RefCounted
## Eight usable non-venue homes, adjacent crop field/pasture and a shallow coastal pool.
var w
var b
var l

func _init(world):w=world;b=w.b;l=w.layout

func build():
	for h in l.config.living_houses:house(h)
	field();pasture();pool()
	w.set_meta("bay_village",{"usable_houses":l.config.living_houses.size(),"loft_houses":4,"farm_area_m2":1980,"flower_area_ratio":.8,"plots":36,"sheep":4,"pigs":4,"play_pool":true,"additional_coastal_boat_points":4})

func furniture(p:Vector3,yaw:float=0):
	var art=preload("res://scripts/bay_architecture.gd").new();art.b=b;art.sofa(p,yaw)

func fence(p:Vector3,size:Vector2,gate:bool=true):
	for side in [-1,1]:
		for z in range(-int(size.y*.5),int(size.y*.5)+1,3):
			b.box(p+Vector3(side*size.x*.5,.65,z),Vector3(.17,1.3,.17),"967650",true,0,"wood")
		for y in [.45,1.0]:b.box(p+Vector3(side*size.x*.5,y,0),Vector3(.1,.13,size.y),"ad8e60",false,0,"wood")
		b.collision(p+Vector3(side*size.x*.5,.55,0),Vector3(.12,1.1,size.y))
		for x in range(-int(size.x*.5),int(size.x*.5)+1,3):
			if gate and side==1 and absf(x)<2:continue
			b.box(p+Vector3(x,.65,side*size.y*.5),Vector3(.17,1.3,.17),"967650",true,0,"wood")
		if side==1 and gate:
			for flank in [-1,1]:
				var span:float=(size.x-4)*.5
				for y in [.45,1.0]:b.box(p+Vector3(flank*(size.x+4)*.25,y,side*size.y*.5),Vector3(span,.13,.1),"ad8e60",false,0,"wood")
				b.collision(p+Vector3(flank*(size.x+4)*.25,.55,side*size.y*.5),Vector3(span,1.1,.12))
		else:
			for y in [.45,1.0]:b.box(p+Vector3(0,y,side*size.y*.5),Vector3(size.x,.13,.1),"ad8e60",false,0,"wood")
			b.collision(p+Vector3(0,.55,side*size.y*.5),Vector3(size.x,1.1,.12))

func house(h:Dictionary):
	var p:Vector3=l.vector(h.center);var width:float=h.size[0];var depth:float=h.size[1];var height:float=6.8 if h.loft else 4.1
	b.venue_context=h.id
	b.box(p-Vector3(0,.2,0),Vector3(width,.4,depth),"c1ad8b",true,0,"stone")
	for side in [-1,1]:
		var span:float=(width-3.4)*.5
		b.box(p+Vector3(side*(width+3.4)*.25,.7,depth*.5),Vector3(span,1.4,.65),"e2d5c1",true,0,"stone")
		if h.loft:
			b.box(p+Vector3(side*(width+3.4)*.25,3.75,depth*.5),Vector3(span,.9,.65),"f4efe6",true,0,"plaster")
			b.box(p+Vector3(side*(width+3.4)*.25,6.55,depth*.5),Vector3(span,.5,.65),"f4efe6",true,0,"plaster")
			b.glass(p+Vector3(side*(width+3.4)*.25,5.25,depth*.5-.18),Vector3(span-.25,2.1,.045));b.collision(p+Vector3(side*(width+3.4)*.25,5.25,depth*.5),Vector3(span-.25,2.1,.13))
		else:b.box(p+Vector3(side*(width+3.4)*.25,(height+3.3)*.5,depth*.5),Vector3(span,height-3.3,.65),"f4efe6",true,0,"plaster")
		b.glass(p+Vector3(side*(width+3.4)*.25,2.3,depth*.5-.25),Vector3(span-.2,1.8,.045))
		b.collision(p+Vector3(side*(width+3.4)*.25,2.3,depth*.5),Vector3(span-.2,1.8,.14))
		for edge in [-1,1]:b.box(p+Vector3(side*(width+3.4)*.25+edge*span*.5,2.3,depth*.5+.18),Vector3(.17,2,.3),"5e4232",false,0,"wood")
		b.box(p+Vector3(side*width*.5,.65,0),Vector3(.6,1.3,depth),"e2d5c1",true,0,"stone")
		b.box(p+Vector3(side*width*.5,(height+3.3)*.5,0),Vector3(.6,height-3.3,depth),"f4efe6",true,0,"plaster")
		b.glass(p+Vector3(side*(width*.5-.22),2.25,0),Vector3(.045,1.8,depth-.5));b.collision(p+Vector3(side*width*.5,2.25,0),Vector3(.15,1.8,depth-.5))
		for zz in range(-int(depth*.5)+1,int(depth*.5),3):b.box(p+Vector3(side*(width*.5+.18),2.25,zz),Vector3(.28,2,.16),"5e4232",false,0,"wood")
		for z in [-depth*.5,depth*.5]:
			b.box(p+Vector3(side*(width*.5+.2),height*.5,z),Vector3(.35,height,.35),"5e4232",false,0,"wood")
			var low:float=minf(p.y-.8,l.natural_height(Vector2(p.x+side*width*.5,p.z+z)))
			b.box(Vector3(p.x+side*width*.5,(low+p.y)*.5,p.z+z),Vector3(.85,p.y-low,.85),"b7a68c",false,0,"stone")
	b.box(p+Vector3(0,height*.5,-depth*.5),Vector3(width,height,.55),"f4efe6",true,0,"plaster")
	if h.loft:
		b.box(p+Vector3(0,3.45,depth*.5),Vector3(3.4,.3,.65),"f4efe6",true,0,"plaster")
		b.box(p+Vector3(0,6.6,depth*.5),Vector3(3.4,.4,.65),"f4efe6",true,0,"plaster")
	else:b.box(p+Vector3(0,(height+3.3)*.5,depth*.5),Vector3(3.4,height-3.3,.65),"f4efe6",true,0,"plaster")
	load("res://scripts/architecture120.gd").new(w).living_roof(h,p,Vector2(width,depth),height)
	for x in range(-int(width*.5)+1,int(width*.5),2):b.beam(p+Vector3(x,height-.45,depth*.5),p+Vector3(x,height,depth*.5+.8),.18,"5e4232")
	b.box(p+Vector3(0,-.08,depth*.5+1.4),Vector3(width,.16,3.0),"aa906c",true,0,"wood")
	for side in [-1,1]:
		b.box(p+Vector3(side*(width*.5-.6),1.45,depth*.5+2.5),Vector3(.22,2.9,.22),"5e4232",true,0,"wood")
		b.planter(p+Vector3(side*4,0,depth*.5+2.4),2.2,"f4b8c4" if h.id in ["H01","H03","H07"] else "9b7ede")
	b.box(p+Vector3(0,3,depth*.5+1.5),Vector3(width+.8,.16,3.7),h.roof,false,0,"slate")
	b.text3d(h.name,p+Vector3(0,3.6,depth*.5+.5),.008,"5e4232")
	# Purpose-built workrooms share only the retained private sleeping and seating contracts.
	load("res://scripts/architecture120.gd").new(w).living_furniture(h,p,Vector2(width,depth))
	var bed:Vector3=p+Vector3(width*.27,0,depth*.2)
	b.box(bed+Vector3(0,.3,0),Vector3(1.6,.6,2.8),"aa906c",true,0,"wood")
	b.box(bed+Vector3(0,.69,0),Vector3(1.55,.18,2.65),{"H01":"c8b885","H03":"b8c6bd","H05":"a0b5c4","H07":"b69a82","H09":"b9a2b8","H11":"bdac8f","H12":"b5b7a5","H14":"baad91"}.get(h.id,"ded3ba"),false,0,"fabric")
	b.box(bed+Vector3(0,.82,-.8),Vector3(1.4,.12,.5),"f4efe6",false,0,"fabric")
	w.interact("ADD_"+h.id+"_BED",bed+Vector3(-1.4,0,0),"软榻 · X 躺卧", "bay_netbed",{"seat":bed+Vector3(0,.45,0),"yaw":0})
	w.interact("ADD_"+h.id+"_USE",p+Vector3(0,0,2),h.name+" · F 使用", "life_house",{"house":h.id})
	w.interact("ADD_"+h.id+"_SEAT",p+Vector3(-width*.25,0,3),"起居沙发 · X","sit",{"seat":p+Vector3(-width*.25,.16,2),"yaw":0})
	if h.use=="photo":
		b.box(p+Vector3(0,1.2,-depth*.35),Vector3(1.3,1.8,.08),"e5d4ae",false,0,"fabric")
		for j in 4:b.box(p+Vector3(sin(j)*.3,1.2-j*.23,-depth*.35+.05),Vector3(.7,.2,.04),["91a783","a3babb","c0a9bb","beac7d"][j])
	if h.loft:loft(h,p,width,depth)
	load("res://scripts/architecture120.gd").new(w).living_details(h,p,Vector2(width,depth))
	var light:=OmniLight3D.new();light.position=p+Vector3(0,2.7,0);light.light_color=Color("ffd29b");light.omni_range=9;light.light_energy=.5;light.shadow_enabled=false;light.set_meta("room_light",h.id);w.add_child(light)
	for side in [-1,1]:b.glow_box(p+Vector3(side*(width+3.4)*.25,2.7,depth*.5-.20),Vector3(.18,.3,.12))
	b.venue_context=""

func loft(h:Dictionary,p:Vector3,width:float,depth:float):
	b.box(p+Vector3(0,3.28,-depth*.2),Vector3(width-1,.24,depth*.6),"aa906c",true,0,"wood")
	b.box(p+Vector3(0,3.28,depth*.3),Vector3(3.4,.24,depth*.4),"aa906c",true,0,"wood")
	b.box(p+Vector3(0,3.28,depth*.5+1.7),Vector3(width,.24,3.4),"aa906c",true,0,"wood")
	var steps:Array=h.stairs;var art=preload("res://scripts/bay_finishings.gd").new(w)
	# Guard both exposed sides of the upper bridge, leaving a 3.4 m portal.
	for side in [-1,1]:art.rail(p+Vector3(side*1.78,3.4,depth*.1),p+Vector3(side*1.78,3.4,depth*.5))
	for side in [-1,1]:art.rail(p+Vector3(side*1.78,3.4,depth*.1),p+Vector3(side*(width*.5-.5),3.4,depth*.1))
	for i in steps.size()-1:
		var a:Vector3=l.vector(steps[i]);var end:Vector3=l.vector(steps[i+1])
		if absf(a.y-end.y)>.1:art.flight(a,end,2.5)
		else:b.ramp(a,end,2.8,"aa906c")
		b.box(end-Vector3.UP*.12,Vector3(2.8,.24,2.8),"aa906c",true,0,"wood")
	for index in [1,2,3]:
		var at:Vector3=l.vector(steps[index]);var low:float=minf(at.y-.4,l.natural_height(Vector2(at.x,at.z)))
		for side in [-1,1]:b.box(Vector3(at.x+side*1.1,(low+at.y)*.5,at.z),Vector3(.24,at.y-low,.24),"5e4232",false,0,"wood")
	var guards=preload("res://scripts/bay_guardrails.gd").new(w)
	guards.pad(p+Vector3(0,3.4,depth*.5+1.7),Vector2(width,3.4))
	guards.pad(p+Vector3(0,3.4,depth*.3),Vector2(3.4,depth*.4),false)
	guards.pad(p+Vector3(0,3.4,-depth*.2),Vector2(width-1,depth*.6),false)
	for i in steps.size()-1:guards.span(l.vector(steps[i]),l.vector(steps[i+1]),2.8)
	for index in [1,2,3,4]:guards.pad(l.vector(steps[index]),Vector2(2.8,2.8))
	# A supported lower approach connects the front porch to the first stair, including H05.
	var entry:Vector3=l.vector(steps[0]);var front:Vector3=p+Vector3(0,0,depth*.5+1.4);var corner:=Vector3(p.x,p.y,entry.z)
	guards.pad(front,Vector2(width,3.0),false)
	# A capsule needs a square landing at both lower turns. Thin intersecting strips
	# otherwise leave half an end rail across the centreline of the actual junction.
	for at in [corner,entry]:
		b.box(at-Vector3.UP*.12,Vector3(3.2,.24,3.2),"aa906c",true,0,"wood");guards.pad(at,Vector2(3.2,3.2))
	# These actual entrance ramps arrive from the public street at the lower turn.
	# Their union opens the pad's receiving edge while guarding its other sides.
	if h.id=="H05":guards.span(Vector3(p.x,p.y,230.5),corner,3.2,false)
	if h.id=="H08":guards.span(Vector3(p.x,p.y,45.5),corner,3.2,false)
	for pair in [[front,corner],[corner,entry]]:
		b.ramp(pair[0],pair[1],2.8,"aa906c");guards.span(pair[0],pair[1],2.8)
		var mid:Vector3=(pair[0]+pair[1])*.5;var ground:float=minf(mid.y-.3,w.height_at(mid.x,mid.z))
		for dx in [-1.0,1.0]:b.box(Vector3(mid.x+dx,(mid.y+ground)*.5,mid.z),Vector3(.22,mid.y-ground,.22),"5e4232",false,0,"wood")
	guards.build("loft_"+h.id,true)
	b.table(p+Vector3(-3,3.4,-depth*.2));furniture(p+Vector3(-3,3.4,0),PI)
	# An upper external door keeps the lower main portal and both floors usable.
	w.interact("ADD_"+h.id+"_LOFT",p+Vector3(-3,3.4,1),"上层阅读座 · X","sit",{"seat":p+Vector3(-3,3.56,0),"yaw":PI})

func field():
	var f:Dictionary=l.config.farm;var p:Vector3=l.vector(f.center);fence(p,Vector2(44,45))
	for row in 6:
		for col in 6:
			var at:Vector3=p+Vector3(-17.5+col*7,0,-17.5+row*7)
			b.box(at+Vector3(0,.045,0),Vector3(5.7,.09,5.7),"8b7051",false,0,"stone")
			for x in [-2.85,2.85]:b.box(at+Vector3(x,.12,0),Vector3(.12,.24,5.7),"aa8863",false,0,"wood")
			for z in [-2.85,2.85]:b.box(at+Vector3(0,.12,z),Vector3(5.7,.24,.12),"aa8863",false,0,"wood")
			w.interact("FARM_PLOT_"+str(row*6+col),at+Vector3(0,0,3.1),"田畦 · F 播种 / 浇水 / 收获","life_farm",{"plot":row*6+col})
	for col in [0,2,4]:
		var at:Vector3=p+Vector3(-21+col*7,.13,0);b.box(at,Vector3(.45,.18,41),"749f99",false)
	var scare:Vector3=p+Vector3(19,0,-18)
	b.box(scare+Vector3(0,1.1,0),Vector3(.18,2.2,.18),"92714b",false,0,"wood")
	b.box(scare+Vector3(0,1.7,0),Vector3(2.6,.15,.16),"92714b",false,0,"wood")
	b.box(scare+Vector3(0,1.3,0),Vector3(.7,.95,.4),"bd8b62",false,0,"fabric")
	b.shape(scare+Vector3(0,2.13,0),Vector3(.45,.45,.45),"cba873","shrub");b.shape(scare+Vector3(0,2.42,0),Vector3(.9,.12,.9),"aa8954","post")
	b.text3d("暖阳农田 · 44 × 45 m",p+Vector3(0,2.1,22.7),.009,"5e4232")
	w.interact("FARM_GATE",p+Vector3(0,0,23.3),"农务台 · F","life_farm",{"plot":-1})

func pasture():
	var p:Vector3=l.vector(l.config.pasture.center);fence(p,Vector2(36,40))
	# A separate shelter and feed trough leave the gate and loop open.
	for x in [-5,5]:
		for z in [-16,-9]:b.box(p+Vector3(x,1.6,z),Vector3(.28,3.2,.28),"5e4232",true,0,"wood")
	preload("res://scripts/architecture_detail.gd").new().roof(b,p+Vector3(0,3.3,-12.5),12,9,1.5,"b86b4b",false)
	for x in [-5,5]:b.box(p+Vector3(x,1.0,-12.5),Vector3(.18,2,7),"aa8863",true,0,"wood")
	for x in [-7,7]:
		b.box(p+Vector3(x,.24,8),Vector3(2.5,.48,.75),"aa8863",true,0,"wood")
		b.box(p+Vector3(x,.49,8),Vector3(2.3,.06,.55),"c7ad75",false)
	b.text3d("海湾牧场 · 羊与猪",p+Vector3(0,2.1,20.3),.009,"5e4232")
	w.interact("PASTURE_FEED",p+Vector3(0,0,21),"牧场 · F 投喂羊猪","life_pasture",{})

func pool():
	var data:Dictionary=l.config.play_pool;var p:Vector3=l.vector(data.center);var bed_y:float=float(data.bed_h_sea)+float(l.config.sea_y)
	b.box(Vector3(p.x,bed_y-.12,p.z),Vector3(16,.24,10),"8aada9",true,0,"stone")
	for side in [-1,1]:b.box(p+Vector3(side*8.15,-.45,0),Vector3(.3,1.1,10.6),"e2d5c1",true,0,"stone")
	b.box(p+Vector3(0,-.45,-5.15),Vector3(16.6,1.1,.3),"e2d5c1",true,0,"stone")
	for side in [-1,1]:b.box(p+Vector3(side*5,-.45,5.15),Vector3(6.6,1.1,.3),"e2d5c1",true,0,"stone")
	b.box(p+Vector3(0,-.10,8.6),Vector3(3.4,.2,4.7),"c9b695",true,0,"stone")
	for i in 5:
		var at:Vector3=p+Vector3(0,-.2*i,6.5-.8*i);var height:float=at.y-bed_y;b.box(Vector3(at.x,bed_y+height*.5,at.z),Vector3(3.2,height,.85),"c9b695",true,0,"stone")
	var water:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(16,10);water.mesh=plane;water.position=p+Vector3(0,.01,0)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.35,.74,.73,.36);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=.20;water.material_override=mat;w.add_child(water)
	for side in [-1,1]:
		var seat:Vector3=p+Vector3(side*10.4,0,0);b.bench(seat,side*PI*.5);w.interact("POOL_SEAT_"+str(side),seat+Vector3(0,0,1),"池边休息 · X","sit",{"seat":seat+Vector3(0,.08,0),"yaw":side*PI*.5})
	w.interact("POOL_PLAY",p+Vector3(0,0,7.4),"浅水游乐池 · F 戏水","life_pool",{})
