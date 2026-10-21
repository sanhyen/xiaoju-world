extends RefCounted
## Small original-brief details and a physical creek-side waterwheel tea stop.
var w
var b
func _init(world):w=world;b=w.b

func cafe(o:Vector3):
	# Glasses have two circular rims and a bridge, beside an open travel journal.
	for side in [-1,1]:
		for j in 16:
			var a:float=j*TAU/16;var p:Vector3=o+Vector3(-5.55+side*.067+cos(a)*.053,1.075,1.22+sin(a)*.053)
			b.box(p,Vector3(.028,.012,.012),"877a57",false,-a)
	b.beam(o+Vector3(-5.58,1.075,1.22),o+Vector3(-5.52,1.075,1.22),.012,"877a57")
	for side in [-1,1]:b.box(o+Vector3(-4.70+side*.10,1.07,.77),Vector3(.19,.025,.30),"efe3c6",false,side*.07,"fabric")
	b.text3d("山海一日",o+Vector3(-4.70,1.10,.77),.0015,"6b7763")
	# A real vase and five small flowers distinguish the far table.
	b.shape(o+Vector3(-2.45,1.18,4.8),Vector3(.16,.30,.16),"e4d5b9","pot")
	for i in 5:
		var p:Vector3=o+Vector3(-2.45+sin(i*2.4)*.10,1.47,4.8+cos(i*2.4)*.10)
		b.beam(p-Vector3(0,.25,0),p,.018,"7b925d");b.shape(p,Vector3(.11,.09,.11),["f4b8c4","f2c14e","6ba4d6","9b7ede","faf6f0"][i],"shrub")
	b.box(o+Vector3(4.5,2.1,-5.81),Vector3(3.2,1.55,.09),"b49b73",false,0,"fabric")
	for y in [1.8,2.55]:
		b.beam(o+Vector3(3, y,-5.65),o+Vector3(6,y-.06,-5.65),.022,"ad9872")
		for x in [3.5,4.4,5.3]:b.box(o+Vector3(x,y-.06,-5.62),Vector3(.04,.12,.025),"826548")
	for i in 2:
		b.box(o+Vector3(5.7,2.33-i*.54,-5.69),Vector3(.50,.35,.025),"e8dcb9",false,0,"fabric")
		b.text3d(["溪岸速写","周末手账"][i],o+Vector3(5.7,2.33-i*.54,-5.66),.0019,"5e6950")
	var chair:Vector3=o+Vector3(6.4,0,3.5)
	for side in [-1,1]:
		for j in 6:b.beam(chair+Vector3(side*.43,.10+pow((j-2.5)/6,2)*.28,-.55+j*.20),chair+Vector3(side*.43,.10+pow((j-1.5)/6,2)*.28,-.35+j*.20),.07,"8d7253")
		b.beam(chair+Vector3(side*.4,.15,-.3),chair+Vector3(side*.4,.65,-.2),.07,"8d7253")
	b.box(chair+Vector3(0,.49,0),Vector3(.86,.12,.83),"c9b78f",false,0,"fabric")
	b.box(chair+Vector3(0,.92,.36),Vector3(.86,.86,.14),"b1b38c",false,0,"fabric")
	b.collision(chair+Vector3(0,.33,0),Vector3(.9,.65,.9))
	w.interact("AUDIT_CAFE_ROCKER",chair+Vector3(0,0,-1),"藤编阅读椅 · X 落座","sit",{"seat":chair+Vector3(0,.15,0),"yaw":0})
	var lamp:Vector3=o+Vector3(7.3,0,2.4)
	b.box(lamp+Vector3(0,.08,0),Vector3(.55,.16,.55),"847151")
	b.box(lamp+Vector3(0,1.20,0),Vector3(.07,2.4,.07),"847151")
	b.shape(lamp+Vector3(0,2.42,0),Vector3(.70,.38,.70),"dfca9c","pot");b.glow_box(lamp+Vector3(0,2.23,0),Vector3(.4,.05,.4))

func creek_tea():
	var p:=Vector3(-194,3.3,-187.5)
	b.box(p-Vector3(0,.14,0),Vector3(4.8,.28,4.4),"aa906c",true,0,"wood")
	for x in [-2.2,2.2]:
		for z in [-2.0,2.0]:
			var low:float=minf(p.y-.4,w.height_at(p.x+x,p.z+z))
			b.box(Vector3(p.x+x,(p.y+low)*.5,p.z+z),Vector3(.24,p.y-low,.24),"6f4d35",false,0,"wood")
	preload("res://scripts/bay_authoring.gd").new(w).pergola(p,Vector2(4.6,4.2))
	preload("res://scripts/architecture_detail.gd").new().roof(b,p+Vector3(0,3.5,0),5.5,5.0,1.0,"4a5d6b",false)
	b.ramp(Vector3(-191,2.1,-191),p+Vector3(0,0,-2.05),2.4,"aa906c")
	b.table(p+Vector3(0,0,.3),1.4);b.bench(p+Vector3(-1.1,0,.3),PI*.5)
	w.interact("AUDIT_CREEK_TEA",p+Vector3(0,0,-.7),"溪岸水车茶座 · F 沏茶","bay_activity",{"activity":"tea"})
	w.interact("AUDIT_CREEK_SEAT",p+Vector3(-.4,0,.3),"水车听溪座 · X","sit",{"seat":p+Vector3(-1.1,.17,.3),"yaw":PI*.5})
	b.text3d("溪岸水车茶座",p+Vector3(0,2.6,-2.25),.007,"eee5cc",PI)
	var river:Dictionary=w.layout.river_segments.filter(func(r):return r.id=="navigation")[0]
	var along:Vector3=(river.c-river.a).normalized();along.y=0;along=along.normalized();var side:=Vector3(-along.z,0,along.x)
	var at:Vector3=river.a+along*7+side*3.4;at.y=river.a.y+1.9
	var rotor:=Node3D.new();rotor.name="CreekWaterwheel";rotor.transform=Transform3D(Basis(along,Vector3.UP,side),at);rotor.set_meta("stream_ref","prop:waterwheel");w.add_child(rotor);w.bay_props.waterwheel=rotor
	var wheel=preload("res://scripts/builder.gd").new(rotor)
	for flank in [-.25,.25]:
		for i in 24:
			var a:float=i*TAU/24;var c:float=(i+1)*TAU/24
			wheel.beam(Vector3(cos(a)*2.05,sin(a)*2.05,flank),Vector3(cos(c)*2.05,sin(c)*2.05,flank),.13,"8c6747")
		for i in 8:wheel.beam(Vector3(0,0,flank),Vector3(cos(i*TAU/8)*1.98,sin(i*TAU/8)*1.98,flank),.10,"ad8e60")
	for i in 16:
		var a:float=i*TAU/16;wheel.box(Vector3(cos(a)*1.96,sin(a)*1.96,0),Vector3(.18,.33,.72),"947255",false,a)
	wheel.finish()
	b.beam(at-side*.75,at+side*.75,.18,"b19a6d")
	w.set_meta("bay_audit_details",{"waterwheel_tea_stop":true,"canvas_pier_roofs":7,"cafe_reading_corner":true})
