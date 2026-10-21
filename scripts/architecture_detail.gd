extends RefCounted
## Original architectural components. All coordinates are relative to retained footprints.
var house
var b
var o:Vector3

func roof(builder,p:Vector3,width:float,depth:float,rise:float,tone:String,cross_gable:bool=false):
	var half:float=(width if cross_gable else depth)/2
	var length:float=depth if cross_gable else width
	var steps:int=maxi(1,ceili(half/0.62))
	var depth_step:float=half/steps
	var columns:int=maxi(1,ceili(length/0.68))
	var tile_width:float=length/columns
	for side in [-1,1]:
		for row in steps:
			var across:float=(row+0.5)*depth_step
			var y:float=rise*(1.0-across/half)
			for col in columns:
				var along:float=-length/2+(col+0.5)*tile_width
				var offset:=Vector3(side*across,y,along) if cross_gable else Vector3(along,y,side*across)
				var tile_size:=Vector3(depth_step+0.028,rise/steps+0.16,tile_width-0.016) if cross_gable else Vector3(tile_width-0.016,rise/steps+0.16,depth_step+0.028)
				var color:Color=Color(tone).lightened(0.025*posmod(col+row*3,4))
				builder.box(p+offset,tile_size,color.to_html(false),false,0,"slate")
		# Fascia emphasizes real thickness rather than a pile of horizontal lids.
		var edge:=Vector3(side*half,0,0) if cross_gable else Vector3(0,0,side*half)
		builder.box(p+edge,Vector3(0.16,0.28,length) if cross_gable else Vector3(length,0.28,0.16),tone)
		for end in [-1,1]:
			var a:=p+(Vector3(0,rise,end*length/2) if cross_gable else Vector3(end*length/2,rise,0))
			var c:=p+(Vector3(side*half,0,end*length/2) if cross_gable else Vector3(end*length/2,0,side*half))
			builder.beam(a,c,0.19,"e4dac1")
	# A closed gable meets the actual underside of the pitched roof. Small stepped
	# strips previously left a sawtooth gap and strong repetitive shadows under eaves.
	var inner:float=half-0.6
	var corner_y:float=maxf(0,rise*0.6/half-0.12)
	for end in [-1,1]:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var coordinates:Array=[Vector2(-inner,-0.12),Vector2(inner,-0.12),Vector2(inner,corner_y),Vector2(0,rise-0.12),Vector2(-inner,corner_y)]
		for index in [0,1,2,0,2,3,0,3,4]:
			var q:Vector2=coordinates[index]
			st.add_vertex(Vector3(q.x,q.y,end*(depth/2-0.8)) if cross_gable else Vector3(end*(width/2-0.8),q.y,q.x))
		st.generate_normals();var face:=MeshInstance3D.new();face.mesh=st.commit()
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color("d9d2bc");mat.roughness=0.9;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;face.material_override=mat
		builder.root.add_child(face);face.position=p
	for index in int(length/0.72)+1:
		builder.box(p+(Vector3(0,rise+0.14,-length/2+index*0.72) if cross_gable else Vector3(-length/2+index*0.72,rise+0.14,0)),Vector3(0.30,0.16,0.65) if cross_gable else Vector3(0.65,0.16,0.30),tone,false,0,"slate")
			
func build(target):
	house=target;b=house.b;o=house.origin
	match house.item.type:
		"records":record_detail()
		"cafe":cafe_detail()
		"florist":florist_detail()
		"souvenir":souvenir_detail()
		"station":station_detail()
		"visitor":visitor_detail()
		"gallery":gallery_detail()
		"cinema":cinema_detail()
		"pb":pb_detail()
		"dance":dance_detail()
		"studio":studio_detail()
		"theater":theater_detail()
		"home":home_detail()
	if house.item.type in ["cinema","studio","visitor","gallery","dance","theater"]:preload("res://scripts/interior_art.gd").new().build(house)

func box(p:Vector3,size:Vector3,tone:String,solid:bool=false):b.box(o+p,size,tone,solid)
func text(words:String,p:Vector3,size:float=0.009,tone:String="ede3c9"):b.text3d(words,o+p,size,tone)
func pot(p:Vector3,tone:String="ac8063",flowers:bool=false):
	b.shape(o+p+Vector3(0,0.3,0),Vector3(0.65,0.6,0.65),tone)
	b.shape(o+p+Vector3(0,0.58,0),Vector3(0.71,0.09,0.71),tone,"round")
	b.shape(o+p+Vector3(0,0.61,0),Vector3(0.57,0.04,0.57),"645940","round")
	var variety:int=posmod(roundi(p.x*4+p.z*2),3)
	for i in 7:
		var angle:float=i*2.4
		var q:Vector3=p+Vector3(sin(angle)*0.23,0.84+i%3*0.14,cos(angle)*0.23)
		b.beam(o+p+Vector3(0,0.61,0),o+q+Vector3(0,0.13,0),0.025,"68805d")
		for side in [-1,1]:
			var leaf_basis:=Basis(Vector3.UP,angle)*Basis(Vector3.FORWARD,side*0.48)
			b.oriented_box(o+q+Vector3(side*0.09,-0.14,0),Vector3(0.24,0.045,0.1),"849a6e",leaf_basis)
		if not flowers:
			b.oriented_box(o+q+Vector3(0,0.12,0),Vector3(0.13,0.04,0.54),"739268",Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,0.38))
		elif variety==0:
			for j in 5:
				var a:float=j*TAU/5
				b.shape(o+q+Vector3(cos(a)*0.10,0.16,sin(a)*0.10),Vector3(0.15,0.065,0.15),"ddc4d4","shrub")
			b.shape(o+q+Vector3(0,0.18,0),Vector3(0.1,0.08,0.1),"d5b475","shrub")
		elif variety==1:
			for j in 4:box(q+Vector3(0,0.12+j*0.07,0),Vector3(0.14-j*0.026,0.07,0.14-j*0.026),"baa9c6")
		else:
			b.shape(o+q+Vector3(0,0.17,0),Vector3(0.17,0.18,0.17),"dfc79e","shrub")
			for side in [-1,1]:box(q+Vector3(side*0.06,0.25,0),Vector3(0.055,0.11,0.1),"e3cfaa")

func chair(p:Vector3,angle:float=0):
	var basis:=Basis(Vector3.UP,angle)
	for x in [-0.25,0.25]:
		for z in [-0.22,0.22]:b.box(o+p+basis*Vector3(x,0.25,z),Vector3(0.06,0.5,0.06),"695e4b",false,angle)
	b.box(o+p+Vector3(0,0.53,0),Vector3(0.66,0.12,0.62),"b39a72",true,angle)
	for y in [0.84,1.05]:b.box(o+p+basis*Vector3(0,y,-0.28),Vector3(0.66,0.13,0.07),"b39a72",false,angle)
	for x in [-0.27,0.27]:b.box(o+p+basis*Vector3(x,0.8,-0.28),Vector3(0.065,0.6,0.065),"695e4b",false,angle)

func cup(p:Vector3):
	b.shape(o+p,Vector3(0.25,0.025,0.25),"e6dfc9","round")
	b.shape(o+p+Vector3(0,0.08,0),Vector3(0.14,0.15,0.14),"f0ead8","round")
	b.shape(o+p+Vector3(0,0.162,0),Vector3(0.11,0.008,0.11),"63513d","round")
	box(p+Vector3(0.09,0.08,0),Vector3(0.06,0.07,0.035),"e6dfc9")

func striped_awning(p:Vector3,width:float,depth:float,tone:String):
	var count:=int(width/0.5)
	for i in count:
		var x:float=-width/2+(i+0.5)*width/count
		b.oriented_box(o+p+Vector3(x,0,0),Vector3(width/count+0.005,0.08,depth),tone if i%2==0 else "e6ddc7",Basis(Vector3.RIGHT,0.12))
		box(p+Vector3(x,-0.18,depth/2),Vector3(width/count,0.27,0.07),tone if i%2==0 else "e6ddc7")
	for x in [-width/2,width/2]:b.beam(o+p+Vector3(x,-0.8,-depth/2),o+p+Vector3(x,-0.16,depth/2),0.055,"665d4c")

func record_detail():
	for side in [-1,1]:
		for x in range(3,9):box(Vector3(side*x,0.6,6.72),Vector3(0.85,1.1,0.07),"765b42" if x%2==0 else "806248")
		box(Vector3(side*5.45,1.25,6.88),Vector3(7.5,0.13,0.65),"443d32")
		box(Vector3(side*8.6,3.15,7.8),Vector3(0.14,0.14,2.2),"433c32")
	striped_awning(Vector3(0,3.05,7.55),17.4,2.1,"947e5e")
	# A real disc-shaped sign, with original typographic name only.
	box(Vector3(-8,4.5,8),Vector3(0.1,1.2,0.1),"574938")
	var disc_basis:=Basis(Vector3.RIGHT,PI/2)
	for radius_tone in [[1.4,"263a3c"],[0.55,"bea07d"]]:
		var disc:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=radius_tone[0]/2;mesh.bottom_radius=mesh.top_radius;mesh.height=0.06;mesh.radial_segments=32;disc.mesh=mesh;disc.material_override=b.material(radius_tone[1]);house.world.add_child(disc);disc.transform=Transform3D(disc_basis,o+Vector3(-8,4.05,8.02+(0.05 if radius_tone[0]<1 else 0)))
	text("RECORDS · LISTENING ROOM",Vector3(0,4.35,6.77),0.009,"6c5740")
	for side in [-1,1]:
		# Window displays face the street and are separate from the real listening console.
		box(Vector3(side*5.2,1.5,5.8),Vector3(3.5,0.1,0.8),"72533c")
		# Source-mapped window contents are provided by records_art.gd.
	for x in [-1.05,1.05]:
		box(Vector3(x,1.47,-3.8),Vector3(0.5,0.55,0.38),"26373b")
		box(Vector3(x,1.48,-3.58),Vector3(0.31,0.32,0.045),"56635f")
	# Turntable platter, tonearm and headphone stand.
	b.shape(o+Vector3(0,1.31,-3.8),Vector3(0.5,0.025,0.5),"101f24","round")
	b.shape(o+Vector3(0,1.33,-3.8),Vector3(0.13,0.02,0.13),"bd9b74","round")
	b.beam(o+Vector3(0.3,1.35,-4),o+Vector3(0.13,1.35,-3.72),0.035,"c1c4b7")
	text("试听台",Vector3(0,0.8,-3.09),0.008)
	box(Vector3(-7.6,0.65,-2.7),Vector3(1.6,1.3,2.3),"987650",true)
	box(Vector3(-7.6,1.44,-2.7),Vector3(0.8,0.24,0.6),"455754")
	pot(Vector3(7.8,0,3.9),"91745a")

func cafe_detail():
	# A blue-grey two-storey seaside house; shaded lower windows, open upper view.
	for side in [-1,1]:
		for x in [2.15,8.4]:box(Vector3(side*x,4,8.23),Vector3(0.22,7.9,0.18),"829b9e")
		striped_awning(Vector3(side*5.2,2.98,9),6.4,2,"7f9da2")
		for y in [1.25,3.8,7.4]:box(Vector3(side*5.25,y,8.27),Vector3(7.2,0.16,0.2),"869d9d")
	text("COFFEE & READING",Vector3(0,2.77,8.25),0.0055,"466369")
	for z in range(-7,8):box(Vector3(-8.73,2.25,z),Vector3(0.035,1.7,0.055),"a09a81")
	# Floor joints, pendant details, book corner and preparation shelves.
	var light:=OmniLight3D.new();light.position=o+Vector3(-3,2.9,-1);light.light_color=Color("ffe7bd");light.light_energy=0.8;light.omni_range=9;house.world.add_child(light)
	for x in range(-8,4):box(Vector3(x,3.782,0),Vector3(0.025,0.009,15.7),"897b63")
	for x in [-6,-3]:
		box(Vector3(x,3.0,0),Vector3(0.04,0.8,0.04),"635b49")
		b.shape(o+Vector3(x,2.65,0),Vector3(0.7,0.28,0.7),"ccb38a","pot")
	for y in [1.8,2.55]:
		box(Vector3(-5,y,-7.4),Vector3(5,0.09,0.45),"93714f")
		for i in 6:cup(Vector3(-7+i*0.7,y+0.07,-7.3))
	box(Vector3(-7.5,0.68,-5.3),Vector3(1.4,1.36,2.1),"c3b59a",true)
	b.glass(o+Vector3(-7.5,1.52,-5.3),Vector3(1.4,0.8,2.1))
	for i in 3:b.shape(o+Vector3(-7.5,1.17,-5.9+i*0.6),Vector3(0.35,0.17,0.25),"c79e65","shrub")
	b.shelf(o+Vector3(-7,3.8,-5),2.3)
	text("书 报 角",Vector3(-7,6.55,-5.2),0.01,"5d726d")
	# A usable local music selector belongs to the reading nook, with existing sources.
	box(Vector3(-4,4.15,-2.7),Vector3(1.9,0.70,0.65),"977c5c",true)
	box(Vector3(-4,4.56,-2.7),Vector3(1.04,0.52,0.39),"5a6a66")
	for x in [-4.32,-3.68]:
		box(Vector3(x,4.57,-2.485),Vector3(0.26,0.31,0.025),"374846")
		for y in [4.49,4.57,4.65]:box(Vector3(x,y,-2.465),Vector3(0.22,0.018,0.018),"97a597")
	box(Vector3(-4,4.59,-2.475),Vector3(0.19,0.12,0.035),"cfba85")
	text("窗边听歌",Vector3(-4,4.99,-2.68),0.0045,"5d726d")
	for x in [-5,-1.9]:
		for z in [1,5]:cup(Vector3(x+0.35,1.01,z));box(Vector3(x-0.4,1.0,z),Vector3(0.5,0.045,0.7),"829d9b")
	for x in [-5,0]:cup(Vector3(x,4.82,4.2))
	# Terrace seats stay away from the old central exit and east stair landing.
	for x in [-6,1.8]:
		chair(Vector3(x,3.82,10.3))
		b.shape(o+Vector3(x+0.8,4.35,10.2),Vector3(0.55,1.0,0.55),"bca07a","round")
		cup(Vector3(x+0.8,4.87,10.2))
	pot(Vector3(-7,3.82,8.8),"d0bd9d")
	# Stair guard, with openings retained at bottom and landing.
	for z in [-4,-2,0,2,4]:
		var y:float=(z+6)*3.65/12
		box(Vector3(7.45,y+0.6,z),Vector3(0.065,1.2,0.065),"7b8f89")
	b.beam(o+Vector3(7.45,1.45,-5.3),o+Vector3(7.45,4.7,5.3),0.09,"7b8f89")
	b.text3d("小镇入口",o+Vector3(0,2.65,-8.24),0.009,"466369",PI)
	house.world.path_between(Vector2(o.x,o.z-8.5),Vector2(-75,265),4,"d6c7a8")

func florist_detail():
	box(Vector3(0,2.7,5.24),Vector3(1.6,0.45,0.08),"3c5c54")
	b.text3d("出口",o+Vector3(0,2.7,5.185),0.006,"dbe1c3",PI)
	striped_awning(Vector3(0,3.08,5.9),12.8,1.9,"91a489")
	text("FLOWERS · 本项目原创花束",Vector3(0,4.25,5.22),0.0055,"57725f")
	for side in [-1,1]:
		for x in [2.7,4.7]:pot(Vector3(side*x,0,6.9+0.3*sin(x)),"a68e6e",true)
		box(Vector3(side*4.1,1.22,5.33),Vector3(4.2,0.14,0.5),"759483")
	# Same rear footprints, lower solid stands; every pot has physical support.
	for x in [-4,0,4]:
		box(Vector3(x,0.34,-4.2),Vector3(2,0.68,0.8),"b39c79",true)
		box(Vector3(x,0.71,-4.2),Vector3(2.06,0.06,0.86),"d2c3a0")
		for side in [-1,1]:
			pot(Vector3(x+side*0.49,0.74,-4.2),"b69c78",true)
			box(Vector3(x+side*0.49,0.35,-3.787),Vector3(0.75,0.32,0.025),"879782")
		box(Vector3(x,0.35,-3.76),Vector3(0.05,0.16,0.025),"decfae")
	# Wrapping stack, upright ribbon spools and crossed scissors rest on the retained table.
	for i in 3:box(Vector3(-3.8,0.993+i*0.028,-2),Vector3(0.83,0.024,0.68),["d5c6ab","bca4b1","cad0b2"][i])
	for i in 3:
		var p:=Vector3(-2.75+i*0.4,0.98,-2.27)
		b.shape(o+p+Vector3(0,0.11,0),Vector3(0.23,0.20,0.23),["bca4b1","a6b49b","d4bd97"][i],"round")
		box(p+Vector3(0,0.23,0),Vector3(0.055,0.05,0.055),"ddcfb1")
	for side in [-1,1]:
		b.beam(o+Vector3(-2.4+side*0.10,1.005,-1.75),o+Vector3(-2.4-side*0.10,1.005,-2.04),0.025,"758981")
		box(Vector3(-2.4+side*0.10,1.006,-1.71),Vector3(0.09,0.025,0.11),"53776b")
	box(Vector3(-3,0.73,-1.43),Vector3(2.3,0.28,0.055),"698775")
	text("花束配色 · 按 E 选择",Vector3(-3,0.73,-1.392),0.0035,"ece0c3")
	# Conservatory has a real front opening and a 2.4 m centre aisle.
	box(Vector3(11.5,0,0),Vector3(7.4,0.15,8.4),"d1c9b0",true)
	box(Vector3(11.5,0.09,0),Vector3(2.5,0.04,8.4),"b5ad92")
	for side in [-1,1]:
		var x:float=11.5+side*3.5
		box(Vector3(x,0.35,0),Vector3(0.22,0.6,8.2),"a6b29b",true)
		box(Vector3(x,3.15,0),Vector3(0.18,0.15,8.4),"759181")
		b.glass(o+Vector3(x,1.8,0),Vector3(0.03,2.6,8))
		for z in [-4,-2,0,2,4]:
			box(Vector3(x,1.7,z),Vector3(0.12,3.3,0.12),"749182")
			b.beam(o+Vector3(x,3.15,z),o+Vector3(11.5,4.65,z),0.12,"749182")
		for z in [-2.8,0,2.8]:pot(Vector3(11.5+side*2.4,0.55,z),"ba9d7b",true)
		box(Vector3(11.5+side*2.4,0.52,0),Vector3(1.5,0.13,7),"927b59",true)
		for z in [-3,3]:box(Vector3(11.5+side*2.4,0.26,z),Vector3(0.14,0.52,0.14),"71836d")
	box(Vector3(11.5,4.65,0),Vector3(0.14,0.14,8.4),"749182")
	for side in [-1,1]:
		var glass:=MeshInstance3D.new();var plate:=BoxMesh.new();plate.size=Vector3(3.82,0.025,8.1);glass.mesh=plate
		var material:=StandardMaterial3D.new();material.albedo_color=Color(0.64,0.83,0.81,0.12);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.roughness=0.25;glass.material_override=material;glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		house.world.add_child(glass);glass.position=o+Vector3(11.5+side*1.75,3.9,0);glass.rotation.z=-side*atan2(1.5,3.5)
	b.glass(o+Vector3(11.5,1.8,-4),Vector3(7,2.6,0.03))
	box(Vector3(11.5,0.35,-4),Vector3(7,0.6,0.2),"a6b29b",true)
	box(Vector3(11.5,3.18,4.05),Vector3(7.2,0.17,0.17),"749182")
	text("小 温 室",Vector3(11.5,3.75,4.18),0.011,"526e59")
	house.world.path_between(Vector2(o.x+11.5,o.z+4.4),Vector2(o.x+11.5,o.z+12),2.5,"d1c3a4")
	house.world.path_between(Vector2(o.x+11.5,o.z+12),Vector2(-75,o.z+12),3,"d1c3a4")

func souvenir_detail():
	striped_awning(Vector3(0,3.08,6.3),13,1.9,"a38369")
	for x in [-1.05,0,1.05]:
		box(Vector3(x,2.8,5.83),Vector3(0.95,0.58,0.035),"9aa5a0")
	text("星   笺",Vector3(0,2.83,5.88),0.011)
	for side in [-1,1]:
		for x in [2.3,3.4,4.5,5.6]:box(Vector3(side*x,2.24,5.77),Vector3(0.06,2.0,0.08),"8c7056")
		box(Vector3(side*4,1.3,4.95),Vector3(3.4,0.15,0.85),"987755")
		for i in 3:
			box(Vector3(side*4-1+i,1.66,4.94),Vector3(0.64,0.58,0.14),["9aaab0","c2a897","b8bba0"][i])
			text(["山 海","花 音","星 光"][i],Vector3(side*4-1+i,1.65,5.02),0.0035,"f5ecd8")
	box(Vector3(-4,2.39,7.28),Vector3(3.25,0.54,0.08),"765b45")
	for x in [-5.4,-2.6]:box(Vector3(x,2.72,7.28),Vector3(0.035,0.22,0.04),"765b45")
	text("明信片 · 票根",Vector3(-4,2.51,7.34),0.0043,"f0e5cd")
	text("原创乐园小物",Vector3(-4,2.27,7.34),0.0034,"d4c7aa")
	# Stamp desk and bags: tactile scene objects, no payments or fictitious official merchandise.
	box(Vector3(4.5,0.48,3.1),Vector3(2.1,0.96,1.0),"ab916c",true)
	for i in 3:
		box(Vector3(3.8+i*0.5,1.01,3.05),Vector3(0.34,0.05,0.3),"365f61")
		box(Vector3(3.8+i*0.5,1.14,3.05),Vector3(0.13,0.2,0.13),"a57651")
	text("纪念章台",Vector3(4.5,0.73,3.62),0.008)
	for x in [-4.3,-3.3]:
		box(Vector3(x,1.32,1),Vector3(0.52,0.65,0.28),"ceb99a")
		b.beam(o+Vector3(x-0.15,1.64,1),o+Vector3(x-0.15,1.84,1),0.035,"8b7053")
		b.beam(o+Vector3(x+0.15,1.64,1),o+Vector3(x+0.15,1.84,1),0.035,"8b7053")
		box(Vector3(x,1.85,1),Vector3(0.32,0.035,0.035),"8b7053")

func station_detail():
	# Platform colonnade, luggage bays, ticket grille and a geometric analogue clock.
	preload("res://scripts/station_art.gd").new().build(house)
	for x in [-10.5,10.5]:
		box(Vector3(x,1.1,0),Vector3(1.3,0.1,3),"71847b",true)
		box(Vector3(x,2.3,0),Vector3(1.3,0.1,3),"71847b")
		for z in [-1,1]:box(Vector3(x,1.15,z),Vector3(0.1,2.3,0.1),"71847b")
		for z in [-0.7,0.6]:
			box(Vector3(x,1.48,z),Vector3(0.6,0.65,0.85),"9b8873" if z<0 else "788f90")
			box(Vector3(x,1.86,z),Vector3(0.25,0.08,0.15),"4e635f")
	for x in range(-19,-12):box(Vector3(x/2.0,2.2,3.4),Vector3(0.045,1.6,0.055),"66796b")
	text("旅 行 服 务",Vector3(-8,2.95,3.6),0.01,"526b62")
	# Clock sits in front of the main eave, carried by two brackets.
	for x in [-0.48,0.48]:box(Vector3(x,5.22,8.3),Vector3(0.1,1.45,0.15),"405e5a")
	box(Vector3(0,6.2,8.34),Vector3(1.65,1.65,0.2),"405e5a")
	box(Vector3(0,6.2,8.48),Vector3(1.43,1.43,0.06),"e7dfc7")
	for i in 12:
		var a:float=i*TAU/12
		box(Vector3(sin(a)*0.6,6.2+cos(a)*0.6,8.53),Vector3(0.05,0.07,0.025),"596e61")
	b.beam(o+Vector3(0,6.2,8.55),o+Vector3(-0.27,6.55,8.55),0.05,"415e58")
	b.beam(o+Vector3(0,6.2,8.56),o+Vector3(0.46,6.2,8.56),0.035,"415e58")
	house.action("wait",Vector3(7,0,-1.7),"候车长椅 · 休息","sit",{"seat":o+Vector3(8,0,-3),"yaw":PI})

func visitor_detail():
	# The physical board is drawn directly from the same world.json coordinates as the UI.
	var center:=o+Vector3(1.4,2.5,-4.65)
	box(Vector3(1.4,2.5,-4.78),Vector3(5.7,3.5,0.18),"486b65")
	box(Vector3(1.4,2.5,-4.65),Vector3(5.45,3.23,0.05),"ded6b9")
	for route in house.world.spec.routes:
		for i in route.size()-1:
			var a:Vector3=center+Vector3(route[i][0]*0.006,-route[i][1]*0.004,0.055)
			var c:Vector3=center+Vector3(route[i+1][0]*0.006,-route[i+1][1]*0.004,0.055)
			b.beam(a,c,0.035,"799186")
	for z in house.world.spec.zones:
		var p:Vector3=center+Vector3(z.x*0.006,-z.z*0.004,0.08)
		b.box(p,Vector3(0.09,0.09,0.035),"b39066")
		b.text3d(z.name,p+Vector3(0.25,0.12,0.02),0.0035,"49665e")
	text("山 海 步 行 导 览",Vector3(1.4,4.44,-4.53),0.012,"405e59")
	box(Vector3(-4,0.58,2.2),Vector3(2.1,1.16,0.8),"b19874",true)
	for i in 4:box(Vector3(-4.75+i*0.46,1.23,2.2),Vector3(0.38,0.055,0.54),"8daba5")
	# The guide label is attached to the existing cabinet front by interior_art.gd.
	for side in [-1,1]:
		box(Vector3(side*6,3.7,6),Vector3(0.1,5,0.1),"80918a")
		box(Vector3(side*6+0.6,5.15,6),Vector3(1.1,1.4,0.05),"9daea1")

func gallery_detail():
	for x in [-9,-6,6,9]:
		box(Vector3(x,2.8,10),Vector3(0.16,5.6,0.22),"aab3a6",true)
	box(Vector3(0,5.45,9),Vector3(23,0.16,3.7),"b9c3b6")
	for x in range(-10,11):box(Vector3(x,5.64,9),Vector3(0.09,0.11,3.7),"718780")
	text("GALLERY / 光影十二帧",Vector3(0,4.65,8.25),0.012,"526d63")
	for x in [-8,-3,3,8]:box(Vector3(x,5.37,-4),Vector3(0.1,0.1,6),"9fa695")
	for x in [-8,8]:pot(Vector3(x,0,5.3),"c8bda4")

func cinema_detail():
	for x in [-10,10]:
		box(Vector3(x,2.3,12.1),Vector3(2.8,3.7,0.32),"665e5c")
		house.photo(4 if x<0 else 7,Vector3(x,2.5,12.31),2.8)
	for x in range(-8,9,2):box(Vector3(x,4.09,13.7),Vector3(0.14,0.1,0.14),"f1dfb4")
	box(Vector3(-9,1.305,9),Vector3(4.5,0.05,0.95),"dec8a0")
	for x in [-10.5,-9.6,-8.7]:box(Vector3(x,1.525,9),Vector3(0.24,0.4,0.3),"b89165")
	text("节目册 · 影视剪辑 / MV",Vector3(0,5.7,11.83),0.0065,"435259")

func pb_detail():
	for x in [-11,-10.5,-10,10,10.5,11]:box(Vector3(x,2.7,9.25),Vector3(0.1,5.0,0.17),"967e5c")
	box(Vector3(-8,0.58,2),Vector3(4,1.16,1.15),"baaa8b",true)
	b.glass(o+Vector3(-8,1.42,2),Vector3(4,0.6,1.1))
	for i in 5:box(Vector3(-9.4+i*0.7,1.22,2),Vector3(0.45,0.06,0.64),["a2b5b1","bda3b5","cbb78d"][i%3])
	for x in [-1.6,1.6]:chair(Vector3(x,0,-1.4));cup(Vector3(x*1.4375,1.01,0.22))
	pot(Vector3(9.5,0,4.7),"bfa88c")

func dance_detail():
	for i in range(-18,19):box(Vector3(i*0.5,0.012,0),Vector3(0.017,0.018,14.4),"97866b")
	for x in [-6.5,-3.25,0,3.25,6.5]:box(Vector3(x,2.4,-7.02),Vector3(0.065,3.6,0.06),"d1d3bf")
	for x in [-9,-8,-7,7,8,9]:box(Vector3(x,3.6,7.83),Vector3(0.13,4.5,0.18),"ac9979")
	text("MOVE / 排练中的光",Vector3(0,5.35,7.81),0.014,"496d66")

func studio_detail():
	# Acoustic booth occupies the unused west-rear corner; entrance faces the clear aisle.
	box(Vector3(-7.5,1.65,-3.8),Vector3(0.12,3.3,3.3),"778e88")
	box(Vector3(-4.5,3.3,-3.8),Vector3(6,0.13,3.4),"778e88")
	b.glass(o+Vector3(-4.5,1.9,-2.1),Vector3(5.9,2.7,0.04))
	for x in [-7.5,-4.5,-1.5]:box(Vector3(x,1.75,-2.08),Vector3(0.1,3.1,0.12),"71847b")
	# The smaller booth plaque is attached by interior_art.gd.
	for x in [-7,-5.6,5.6,7]:box(Vector3(x,3.1,6.8),Vector3(0.48,4.0,0.18),"889486")

func theater_detail():
	for x in [-14,-10,10,14]:
		box(Vector3(x,3.1,16),Vector3(0.48,6.2,0.5),"b6b4a0",true)
		for y in [1.6,3.1,4.6]:box(Vector3(x, y,16.3),Vector3(0.5,0.16,0.07),"eee1bd")
	box(Vector3(0,6.2,15.1),Vector3(33,0.25,5.2),"647b7c")
	for x in [-11,11]:
		box(Vector3(x,3,14.4),Vector3(3.5,4.3,0.4),"53676d")
		house.photo(6 if x<0 else 7,Vector3(x,3.1,14.65),3.6)
	for side in [-1,1]:
		for i in 9:box(Vector3(side*(11.5+i*0.35),4.3,-8.8),Vector3(0.25,7.6,0.4),"826b85" if i%2 else "6d5b74")
	text("观 演 入 口",Vector3(0,5.3,14.4),0.022)

func home_detail():
	box(Vector3(-5,6.1,-3),Vector3(1.25,3.1,1.4),"ae9680")
	box(Vector3(-5,7.7,-3),Vector3(1.55,0.2,1.7),"776c60")
	for x in [-6,6]:pot(Vector3(x,0,6.5),"bf9e7a",true)
	box(Vector3(5,0.76,1.5),Vector3(2.8,0.15,1.2),"aa8863",true)
	for x in [4,6]:box(Vector3(x,0.38,1.5),Vector3(0.12,0.76,0.8),"7d6d53")
	chair(Vector3(5,0,2.9),PI)
	box(Vector3(5,0.9,1.5),Vector3(0.8,0.06,0.55),"b4b79c")
	box(Vector3(6,1.3,1.3),Vector3(0.07,0.95,0.07),"746851")
	b.shape(o+Vector3(6,1.8,1.3),Vector3(0.7,0.3,0.7),"d6c29a","pot")
