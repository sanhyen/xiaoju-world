extends RefCounted
## Incremental N09/N10 structures; original anchors, access and media stay in place.
var world
var b
func _init(target):world=target;b=world.b

func stage(o:Vector3):
	for x in [-8,8]:
		for z in [-3.8,3.8]:
			b.box(o+Vector3(x,2.9,z),Vector3(0.32,4.2,0.32),"947255",true)
			b.box(o+Vector3(x,1.0,z),Vector3(0.54,0.4,0.54),"c5bca5")
		b.box(o+Vector3(x,4.65,0),Vector3(0.24,0.3,8.2),"655645")
	for z in [-3.8,3.8]:b.box(o+Vector3(0,4.65,z),Vector3(16.4,0.3,0.24),"655645")
	for x in range(-6,7,2):b.box(o+Vector3(x,4.77,0),Vector3(0.15,0.18,8.7),"947255")
	for z in [-5,5]:b.box(o+Vector3(0,4.98,z),Vector3(19.15,0.42,0.16),"607a79")
	for z in range(-4,5):b.box(o+Vector3(0,0.807,z),Vector3(16.8,0.014,0.025),"866e51")
	# Partial back and slatted wings define a small outdoor pavilion, not a closed hall.
	b.box(o+Vector3(0,2.55,-3.8),Vector3(10.6,3.5,0.22),"59716d",true)
	for x in [-7.5,7.5]:
		for z in [-3,-2.25,-1.5]:b.box(o+Vector3(x,2.3,z),Vector3(0.16,3,0.32),"947255")
	b.box(o+Vector3(0,3.3,-3.63),Vector3(7.0,1.2,0.12),"3b5354")
	b.text3d("海 风 小 舞 台",o+Vector3(0,3.42,-3.55),0.012,"eadbc0")
	b.text3d("听一段旋律 · 看一片海",o+Vector3(0,2.98,-3.55),0.006,"d7d4ba")
	for x in [-7,7]:
		b.box(o+Vector3(x,1.8,1),Vector3(1.3,2,1),"293e42")
		b.box(o+Vector3(x,1.8,1.515),Vector3(1.05,1.72,0.03),"182c30")
		for i in 9:b.box(o+Vector3(x,1.12+i*0.17,1.535),Vector3(0.98,0.025,0.015),"526566")
	var lights:Array=[]
	for x in [-4.5,4.5]:
		b.beam(o+Vector3(x,4.65,2),o+Vector3(x,4.25,2),0.08,"3b5354")
		b.box(o+Vector3(x,4.2,2),Vector3(0.56,0.42,0.58),"293e42")
		b.glow_box(o+Vector3(x,3.98,1.91),Vector3(0.4,0.045,0.4))
		var light:=SpotLight3D.new();world.add_child(light);light.position=o+Vector3(x,3.96,1.91)
		light.look_at(o+Vector3(x*0.45,0.8,-1.8));light.spot_range=14;light.spot_angle=50;light.shadow_enabled=false;lights.append(light)
	world.venue_lights["N09"]=lights;world.set_venue_lighting("N09",0)
	var desk:Vector3=world.surface(o.x-11,o.z+8) if world.layout!=null else world.surface(-232,122)
	b.box(desk+Vector3(0,0.53,0),Vector3(1.1,1.06,0.55),"947255",true)
	b.box(desk+Vector3(0,1.07,0),Vector3(1.23,0.10,0.67),"3b5354")
	for x in [-0.32,0,0.32]:b.box(desk+Vector3(x,1.14,0),Vector3(0.08,0.06,0.25),"d7c7ad")
	b.text3d("舞台灯光",desk+Vector3(0,0.78,0.286),0.0044)
	world.interact("N09_LIGHT",desk+Vector3(0,0,0.9),"小舞台 · 切换灯光","venue_light",{"venue":"N09"})

func courtyard(o:Vector3):
	# Separate piers, sills and lintel leave two actual windows and a central passage.
	for x in [-5.7,-1.3,1.3,5.7]:b.box(o+Vector3(x,1.5,-1.7),Vector3(0.6,3.0,0.38),"e4dfcf",true)
	b.box(o+Vector3(0,3.1,-1.7),Vector3(12,0.3,0.44),"e4dfcf",true)
	for x in [-3.5,3.5]:
		b.box(o+Vector3(x,0.375,-1.7),Vector3(3.8,0.75,0.38),"e4dfcf",true)
		for y in [0.82,2.86]:b.box(o+Vector3(x,y,-1.7),Vector3(4.02,0.12,0.5),"655645")
		for dx in [-1.84,1.84]:b.box(o+Vector3(x+dx,1.84,-1.7),Vector3(0.12,2.14,0.5),"655645")
		for dx in [-1.2,0,1.2]:b.box(o+Vector3(x+dx,1.83,-1.7),Vector3(0.065,1.95,0.12),"947255")
		b.box(o+Vector3(x,2.35,-1.7),Vector3(3.7,0.065,0.12),"947255")
	# Low fore-gate and layered eaves relate to the retained 3.4 m corridor.
	for x in [-6.4,6.4]:
		b.box(o+Vector3(x,1.8,0),Vector3(0.36,3.6,0.4),"947255",true)
		b.box(o+Vector3(x,0.16,0),Vector3(0.6,0.32,0.65),"c5bca5")
	b.box(o+Vector3(0,3.48,0),Vector3(13.2,0.26,0.3),"655645")
	for z in [-0.8,0,0.8]:b.box(o+Vector3(0,3.70+0.10*(1-absf(z)),z),Vector3(13.8,0.13,0.9),"596b72")
	for x in range(-6,7):b.box(o+Vector3(x,3.55,0),Vector3(0.09,0.14,2.3),"947255")
	var corridor:Vector3=world.surface(o.x-19,o.z-5) if world.layout!=null else world.surface(182,-115)
	for z in [-2,2]:b.box(corridor+Vector3(0,3.17,z),Vector3(20.4,0.2,0.2),"655645")
	for x in [174,178,182,186,190]:
		var p:Vector3=world.surface(o.x+float(x)-201,o.z-5) if world.layout!=null else world.surface(x,-115)
		for z in [-2,2]:b.box(p+Vector3(0,0.12,z),Vector3(0.56,0.24,0.56),"c5bca5")
		b.box(p+Vector3(0,3.13,0),Vector3(0.18,0.22,4.4),"947255")
	# Thin stone courses remain below the existing player's step allowance.
	var garden=preload("res://scripts/district_detail.gd").new(world)
	garden.paving(corridor+Vector3(0,0.02,0),20.5,4.7,"d9d1bc")
	garden.paving(o+Vector3(0,0.02,2.7),17.0,5.3,"d9d1bc")
	for x in [-6.7,6.7]:garden.seat(o+Vector3(x,0.08,3.2),PI/2 if x<0 else -PI/2)
	for x in [-6.3,6.3]:
		b.box(o+Vector3(x,2.67,0),Vector3(0.16,0.5,0.16),"655645")
		b.glow_box(o+Vector3(x,2.34,0),Vector3(0.36,0.42,0.36))
		b.box(o+Vector3(x,2.61,0),Vector3(0.49,0.12,0.49),"596b72")
		var light:=OmniLight3D.new();world.add_child(light);light.position=o+Vector3(x,2.34,0.2);light.light_color=Color("ffe0b1");light.omni_range=6;light.shadow_enabled=false;world.night_lights.append(light)
	world.interact("N10_ARCHIVE",world.surface(o.x+1,o.z+1.5) if world.layout!=null else world.surface(202,-108.5),"原创庭院 · 影像资料","set_archive",{})
