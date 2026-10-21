extends RefCounted
## User extension: dense flower hill, navigable piers and natural coral island.
var w
var b
var layout
var rng:=RandomNumberGenerator.new()
var flower_count:=0
var eligible:=0
var occupied:=0
var total_cells:=0

func _init(target):w=target;b=w.b;layout=w.layout;rng.seed=618144
func at(x:float,z:float,up:float=0)->Vector3:return w.surface(x,z,up)

func build():
	flower_hill()
	for i in layout.config.boat_docks.size():dock(i)
	island()
	w.set_meta("bay_expansion",{"flower_clusters":flower_count,"planted_cells":occupied,"eligible_cells":eligible,"flower_coverage":float(occupied)/maxi(1,eligible),"whole_hill_coverage":float(occupied)/maxi(1,total_cells),"all_cells":total_cells,"flower_height_m":[.6,1.1],"boat_docks":layout.config.boat_docks.size(),"hotel_villas":4,"natural_planning_area":layout.config.island.reef_design_ellipse.natural_area_m2,"hotel_planning_area":layout.config.island.reef_design_ellipse.hotel_area_m2,"natural_region_ratio":.7,"note":"70/30 is measured planning-region area, same rendered reef design ellipse, not object counts"})

func flower_hill():
	var config:Dictionary=layout.config.flower_hill
	var size:Array=config.size;var center:Array=config.center;var spacing:float=config.spacing
	var x:float=center[0]-size[0]*.5
	while x<center[0]+size[0]*.5:
		var z:float=center[1]-size[1]*.5
		while z<center[1]+size[1]*.5:
			total_cells+=1
			var path:bool=not w.clear_of_paths(Vector2(x,z),.15)
			if not path:
				eligible+=1;occupied+=1
				var tone:String=config.colors[posmod(floori((x+260)*.13+sin(z*.17)*1.8),5)]
				flower(at(x+rng.randf_range(-.09,.09),z+rng.randf_range(-.09,.09)),rng.randf_range(.6,1.1),tone,posmod(floori(x+z),5))
			z+=spacing
		x+=spacing
	# The protected serpentine paving is authored once in the shared road graph.
	var mill:Vector3=at(-245,-197)
	b.box(mill+Vector3(0,2.0,0),Vector3(2.2,4,2.2),"f4efe6",true)
	b.box(mill+Vector3(0,4.15,0),Vector3(2.8,.3,2.8),"94765a")
	var blades:=Node3D.new();blades.position=mill+Vector3(0,3.5,1.4);blades.set_meta("stream_ref","prop:windmill");w.add_child(blades);w.bay_props.windmill=blades
	var builder=preload("res://scripts/builder.gd").new(blades)
	for i in 4:
		var basis:=Basis(Vector3.BACK,i*PI*.5+PI*.25)
		builder.oriented_box(basis*Vector3(0,1.2,0),Vector3(.65,2.4,.15),"f4efe6",basis)
	builder.finish()
	swing("FLOWER",at(-246,-190),false)
	for i in 5:
		var point:Vector3=at(-217+i%2*5,-194+i*7)
		w.interact("ADD_FLOWER_COLOR_"+str(i),point,"花丘采摘 · 多色鲜花","bay_flower",{"material":"flower","color":i})

func flower(p:Vector3,height:float,tone:String,kind:int):
	# Overlapping heads and a lower leaf layer create thickness rather than isolated dots.
	b.box(p+Vector3(0,height*.43,0),Vector3(.04,height*.86,.04),"718a50")
	for sign in [-1,1]:b.box(p+Vector3(sign*.17,height*.38,0),Vector3(.4,.09,.18),"83a05a",false,sign*.3)
	if kind==2:
		for j in 3:b.shape(p+Vector3((j-1)*.16,height+sin(j)*.05,0),Vector3(.48,.3,.44),tone,"shrub")
	elif kind==3:
		for j in 4:b.shape(p+Vector3(0,height-.24+j*.12,0),Vector3(.29-j*.04,.16,.29-j*.04),tone,"shrub")
	else:
		for j in 5:
			var angle:float=j*TAU/5
			b.box(p+Vector3(cos(angle)*.19,height,sin(angle)*.19),Vector3(.34,.09,.23),tone,false,angle)
		b.shape(p+Vector3(0,height+.035,0),Vector3(.17,.12,.17),"d8b45e","shrub")
	flower_count+=1

func lamp(p:Vector3):
	b.box(p+Vector3(0,.8,0),Vector3(.12,1.6,.12),"654732")
	b.glow_box(p+Vector3(0,1.5,0),Vector3(.25,.36,.25))
	b.box(p+Vector3(0,1.72,0),Vector3(.35,.1,.35),"654732")

func deck(a:Vector3,c:Vector3,width:float,rails:bool=true):
	b.ramp(a,c,width,"786047")
	var length:float=a.distance_to(c);var side:=Vector3(-(c-a).z,0,(c-a).x).normalized()
	for i in maxi(2,ceili(length/3))+1:
		var p:Vector3=a.lerp(c,float(i)/maxi(2,ceili(length/3)))
		for sign in [-1,1]:
			var q:Vector3=p+side*sign*(width*.5-.12)
			var bottom:float=minf(q.y-.5,w.height_at(q.x,q.z));var height:float=maxf(.5,q.y-bottom)
			b.box(q-Vector3(0,height*.5,0),Vector3(.25,height,.25),"654732")
			if false:b.box(q+Vector3(0,.55,0),Vector3(.10,1.1,.10),"947456",true)
		if i%3==0:lamp(p+side*(width*.5+.1))

func rail_opening(p:Vector3)->bool:
	for entry in layout.config.island.hotel_walk.arrival:
		var q:Vector3=layout.vector(entry)
		if Vector2(p.x-q.x,p.z-q.z).length()<2.0:return true
	var first:Vector3=layout.hotel_walk_point(-1.15)
	if Vector2(p.x-first.x,p.z-first.z).length()<2.0:return true
	for z in [426.0,441.0,456.0,471.0]:
		var start:Vector3=layout.hotel_branch_start(z)
		if absf(p.z-z)<1.8 and absf(p.x-start.x)<2.8:return true
	return false

func dock(index:int):
	var record:Dictionary=layout.config.boat_docks[index]
	var water:Vector3=layout.vector(record.water);var land:Vector3=layout.vector(record.land)
	var entry:Vector3=layout.vector(record.pier)
	var axis:=Vector3(record.axis[0],0,record.axis[1]);var normal:=Vector3(-axis.z,0,axis.x)
	if record.has("bridge_access"):deck(layout.vector(record.bridge_access),land,3.2,false)
	deck(land,entry,3.2,false)
	deck(entry-axis*5,entry+axis*5,3.2,false)
	for side in [-1,1]:
		b.box(entry+axis*side*4+Vector3(0,.55,0),Vector3(.25,1.1,.25),"5e4232",true)
		lamp(entry+axis*side*4)
	preload("res://scripts/bay_authoring.gd").new(w).pergola(land+Vector3(0,.1,0),Vector2(7,5))
	for side in [-1,1]:b.oriented_box(land+Vector3(side*2.0,3.55,0),Vector3(4.15,.08,6),"e8dcc4",Basis(Vector3.FORWARD,side*.10),false,"fabric")
	b.text3d(record.name,land+Vector3(0,2.8,2.6),.011,"f4efe6")
	warm_light(land+Vector3(0,2.2,0),8)
	w.interact("BOAT_DOCK_"+str(index),land+Vector3(0,.1,1.3),record.name+" · E 选船 / F 乘船","bay_boat",{"dock":index})
	for j in 5:
		var p:Vector3=land+Vector3(-4+j*.5,-j*.17,3+j*.45)
		b.box(p,Vector3(2,.25,.6),"c8bba1",true)

func swing(id:String,p:Vector3,sea:bool):
	for side in [-1,1]:
		b.box(p+Vector3(side*1.6,1.8,0),Vector3(.2,3.6,.2),"f4efe6" if not sea else "9a7951",true)
		b.beam(p+Vector3(side*1.6,3.4,0),p+Vector3(side*1.6,.1,1),.15,"94795b")
	b.box(p+Vector3(0,3.5,0),Vector3(3.6,.25,.25),"94795b")
	var seat:=Node3D.new();seat.position=p+Vector3(0,.8,0);seat.set_meta("stream_ref","prop:swing_"+id);w.add_child(seat)
	var builder=preload("res://scripts/builder.gd").new(seat)
	builder.box(Vector3.ZERO,Vector3(1.9,.15,.7),"a98c67")
	for side in [-1,1]:builder.box(Vector3(side*.8,1.3,0),Vector3(.045,2.6,.045),"ccb589")
	builder.finish();w.bay_props["swing_"+id]=seat
	w.interact("SWING_"+id,p+Vector3(0,0,1.2),"木秋千 · X 落座拍照","bay_swing",{"seat":p+Vector3(0,.5,0),"yaw":PI,"prop":"swing_"+id})

func island():
	# Reef tint and transparency use the continuous ocean surface: no second edge or wave seam.
	for i in 42:
		var theta:float=rng.randf()*TAU;var radial:float=rng.randf_range(1.22,1.48)
		var p:=Vector3(225+cos(theta)*42*radial,0,450+sin(theta)*28*radial)
		for j in 3:
			var q:Vector3=p+Vector3(sin(j*2.1)*.5,0,cos(j*2.1)*.5);q.y=w.height_at(q.x,q.z)
			var height:float=minf(.62,float(layout.config.sea_y)-.13-q.y)
			if height<.20:continue
			b.shape(q+Vector3(0,height*.5,0),Vector3(.5,height,.4),["c899ac","b7c6a0","d7ba82","a8b9d1"][i%4],"shrub")
	for i in 22:
		var angle:float=i*2.399;var radius:float=8+sqrt(float(i))*5
		var q:=Vector2(218+cos(angle)*radius,450+sin(angle)*radius*.55)
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q,Vector2(225,459),Vector2(222,434)))<2.1:continue
		if w.height_at(q.x,q.y)< -1.1:continue
		palm(at(q.x,q.y),4.5+(i%4)*.6)
	for i in 54:
		var q:=Vector2(204+sin(i*1.8)*25,450+cos(i*1.8)*18)
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q,Vector2(225,459),Vector2(222,434)))<2.1:continue
		var p:Vector3=at(q.x,q.y)
		if p.y< -1.2:continue
		b.shape(p+Vector3(0,.5,0),Vector3(1.2,1,1.2),"8fa67b","shrub")
		for j in 4:b.shape(p+Vector3(cos(j*1.57)*.4,.9,sin(j*1.57)*.4),Vector3(.38,.17,.38),"faf6f0","shrub")
	var cliff:Vector3=at(187,450)
	for i in 7:b.shape(cliff+Vector3(-i*.7,-.25,i%2*1.8),Vector3(2.8,1.6,2.2),"8c998a","rock")
	b.bench(cliff+Vector3(0,.2,0),PI*.5)
	w.interact("ISLAND_SUNSET",cliff+Vector3(2,0,0),"西礁听涛崖 · 落座","sit",{"seat":cliff+Vector3(0,.25,0),"yaw":PI*.5})
	swing("ISLAND",Vector3(205,-1.4,478),true)
	var arrival:Vector3=layout.vector([256,2,427]);var previous:Vector3=arrival
	for entry in layout.config.island.hotel_walk.arrival:
		var next:Vector3=layout.vector(entry)
		if previous.distance_to(next)>.1:deck(previous,next,2.8)
		previous=next
	previous=layout.hotel_walk_point(-1.15)
	for i in range(1,11):
		var angle:float=lerpf(-1.15,1.15,float(i)/10)
		var p:Vector3=layout.hotel_walk_point(angle)
		deck(previous,p,2.8);previous=p
	for i in 4:
		var z:float=426+i*15;var x:float=276+(4 if i in [1,2] else 0)
		deck(layout.hotel_branch_start(z),Vector3(x,-.8,z),2.8)
		villa(i,Vector3(x,-.8,z))
	# Lobby bar, with real furniture and a tea activity, at the start of the crescent walk.
	var lobby:=Vector3(263.5,-.7,421)
	b.box(lobby-Vector3.UP*.1,Vector3(11.4,.2,9),"786047",true)
	load("res://scripts/architecture120.gd").new(w).coral_lobby(lobby)
	b.venue_context="HOTEL";b.table(lobby+Vector3(-2,0,0),2);b.bench(lobby+Vector3(-2,0,1.4));b.venue_context=""
	b.box(lobby+Vector3(-3.5,.6,-2.6),Vector3(3,1.2,1.3),"947359",true)
	w.interact("ISLAND_LOBBY_TEA",lobby+Vector3(-3.5,0,-.8),"海上大堂吧 · 茶饮","bay_activity",{"activity":"tea"})
	w.path_between(Vector2(256,427),Vector2(222,434),2.8,"e7d7b7")
	w.path_between(Vector2(222,434),Vector2(187,450),2.8,"e7d7b7")
	var guards=preload("res://scripts/bay_guardrails.gd").new(w)
	# The enlarged real lobby floor absorbs the old crescent-walk rail crossing it.
	# Outer public boardwalk rails remain; the pavilion's interior stays traversable.
	guards.pad(lobby,Vector2(11.4,9),false)
	for entry in layout.config.decks:
		if minf(entry[0][2],entry[1][2])>400 and minf(entry[0][0],entry[1][0])>170:guards.span(layout.vector(entry[0]),layout.vector(entry[1]),entry[2])
	for area in layout.config.deck_areas:
		if area[1]>400 and area[0]>170:guards.pad(layout.vector([(area[0]+area[2])*.5,area[4],(area[1]+area[3])*.5]),Vector2(area[2]-area[0],area[3]-area[1]))
	for i in 4:
		var x:float=276+(4 if i in [1,2] else 0);var z:float=426+i*15+8.5
		guards.span(Vector3(x+3.8,-.8,z),Vector3(x+7.8,-2.8,z),1.8)
		guards.pad(Vector3(x+7.8,-2.8,z),Vector2(3.5,3.5))
	guards.build("coral_hotel_walk_and_villas",true)

func palm(p:Vector3,height:float):
	for j in 7:b.box(p+Vector3(j*.06,(j+.5)*height/7,0),Vector3(.3,height/7+.06,.3),"9d855d")
	for j in 7:
		var angle:float=j*TAU/7;var end:Vector3=p+Vector3(cos(angle)*2.9,height-.4,sin(angle)*2.9)
		b.beam(p+Vector3(.35,height,0),end,.19,"5f8b60")
		for k in 6:
			var center:Vector3=(p+Vector3(.35,height,0)).lerp(end,float(k+1)/7)
			for sign in [-1,1]:
				var side:Vector3=Vector3(-sin(angle),0,cos(angle))*sign
				b.beam(center,center+side*(.7-.07*k)+Vector3(cos(angle)*.28,-.15,sin(angle)*.28),.14,"7da16b")

func villa(index:int,o:Vector3):
	warm_light(o+Vector3(0,2,4),9)
	# Colourful rooted branching coral stays inside the real glass opening.
	for i in 9:
		var q:=Vector3(o.x+(i%3-1)*.64,0,o.z+(i/3-1)*.64);q.y=w.height_at(q.x,q.z)
		var tone:String=["e2a2b7","97bca0","ddbd79","9dbbd8","b39bd4"][i%5];var rise:float=minf(.65,float(layout.config.sea_y)-.17-q.y)
		if rise<.18:continue
		b.shape(q+Vector3(0,.08,0),Vector3(.46,.16,.40),"a3b8a6","rock")
		for side in [-1,0,1]:
			b.beam(q+Vector3(0,.1,0),q+Vector3(side*.14,rise-.04,side*.08),.07,tone)
			b.shape(q+Vector3(side*.14,rise,side*.08),Vector3(.19,.15,.18),tone,"shrub")
	# The central opening is actual glass with collision; coral remains visible below it.
	for side in [-1,1]:
		b.box(o+Vector3(side*2.55,-.14,0),Vector3(2.76,.28,8.16),"947255",true)
		b.box(o+Vector3(0,-.14,side*2.55),Vector3(2.5,.28,2.76),"947255",true)
	b.glass(o-Vector3.UP*.025,Vector3(2.4,.05,2.4));b.collision(o-Vector3.UP*.05,Vector3(2.5,.10,2.5))
	for x in [-4,4]:
		for z in [-4,4]:b.box(o+Vector3(x,1.65,z),Vector3(.25,3.3,.25),"6f4d35",true)
	for side in [-1,1]:
		# The west branch meets a real side doorway; glass never spans the entrance.
		for section in ([[-2.6,2.8],[2.6,2.8]] if side<0 else [[0,8]]):
			b.box(o+Vector3(side*4,.6,section[0]),Vector3(.3,1.2,section[1]),"b8a17e",true)
			b.glass(o+Vector3(side*4,2.1,section[0]),Vector3(.04,1.8,section[1]-.1));b.collision(o+Vector3(side*4,2.1,section[0]),Vector3(.12,1.8,section[1]))
		if side<0:b.box(o+Vector3(-4,3.1,0),Vector3(.3,.3,2.4),"6f4d35",true)
		b.box(o+Vector3(side*2.5,1.5,-4),Vector3(3,3,.3),"b8a17e",true)
		b.box(o+Vector3(side*2.5,.5,4),Vector3(3,1,.3),"b8a17e",true)
	load("res://scripts/architecture120.gd").new(w).villa_roof(index,o)
	b.box(o+Vector3(0,3.2,-4),Vector3(2,.35,.3),"b8a17e",true)
	b.venue_context="HOTEL";b.bench(o+Vector3(-2.5,0,2.3),PI*.5);b.venue_context="";b.table(o+Vector3(-2,0,-1),1.2)
	b.box(o+Vector3(2,.4,-2),Vector3(2.3,.8,2),"eee5d0",true)
	var deck_o:Vector3=o+Vector3(0,0,7)
	# Four panels surround a 2.6 x 3.0 m opening. The woven bed looks directly into water.
	for panel in [[-3.65,0,.7,6],[1.65,0,4.7,6],[-2,-1.75,2.6,2.5],[-2,2.75,2.6,.5]]:
		b.box(deck_o+Vector3(panel[0],-.12,panel[1]),Vector3(panel[2]+.12,.24,panel[3]+.12),"947255",true)
	for side in [-1,1]:
		for z in [4,9.5]:
			var p:Vector3=o+Vector3(side*3.8,-2,z);b.box(p,Vector3(.25,4,.25),"654732")
	# A woven white net, supported at all four corners, is a usable reclining surface.
	var net:Vector3=deck_o+Vector3(-2,.22,1)
	for j in 13:
		b.box(net+Vector3(-1.2+j*.2,0,0),Vector3(.035,.035,2.8),"eee7d6")
		b.box(net+Vector3(0,.015,-1.4+j*.233),Vector3(2.4,.035,.035),"eee7d6")
	b.collision(net-Vector3(0,.06,0),Vector3(2.5,.1,2.9))
	w.interact("VILLA_NET_"+str(index),deck_o+Vector3(-1,0,-1),"白色编织网床 · X 躺卧","bay_netbed",{"seat":net+Vector3(0,.15,-.6),"yaw":0})
	b.box(deck_o+Vector3(2,.3,0),Vector3(1.4,.6,2.3),"f4efe6",true)
	for x in [1.1,2.9]:
		for z in [-1.2,1.2]:b.box(deck_o+Vector3(x,1.55,z),Vector3(.08,3.1,.08),"dfd6bc")
	b.box(deck_o+Vector3(2,3.1,0),Vector3(2.1,.08,2.6),"f4efe6")
	for x in [1.15,2.85]:
		var drape:=MeshInstance3D.new();var curtain:=QuadMesh.new();curtain.size=Vector2(2.4,2.2);drape.mesh=curtain
		var fabric:=ShaderMaterial.new();fabric.shader=load("res://assets/materials/gauze_bay.gdshader");drape.material_override=fabric
		drape.position=deck_o+Vector3(x,1.8,0);drape.rotation.y=PI*.5;drape.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;w.add_child(drape)
	preload("res://scripts/bay_redesign_authoring.gd").new(w).villa_access(index,o)
	for sign in [-1,1]:lamp(o+Vector3(sign*3.5,0,4.5))
	load("res://scripts/architecture120.gd").new(w).villa_details(index,o)

func warm_light(p:Vector3,radius:float):
	var light:=OmniLight3D.new();light.position=p;light.light_color=Color("ffa65c");light.light_energy=0;light.omni_range=radius;light.shadow_enabled=false;light.set_meta("stream_ref","night");w.add_child(light);w.night_lights.append(light)
