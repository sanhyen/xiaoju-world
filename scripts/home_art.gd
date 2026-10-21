extends RefCounted
## B12: one retained footprint, designed facade, usable rooms and a supported garden approach.
var house
var world
var b
var o:Vector3
const WALL="e7dfca"
const WOOD="796047"
const DARK="3e4d49"
const SLATE="506c70"

func build(target):
	house=target;world=house.world;b=house.b;o=house.origin
	shell();interior();garden()
	house.action("enter",Vector3(0,0,7),"走进 · 我的海风小屋","enter",{"building":"B12"})
	house.action("decorate",Vector3(1,0,-1),"布置小屋 · 花束、照片与灯光","home",{})
	house.action("save",Vector3(-3,0,1),"手动保存 · 海风小屋","save",{})
	house.action("listen",Vector3(-1.8,0,-3.6),"小屋唱片 · 落日未眠","audio",{})
	house.action("reading",Vector3(4.3,0,-1.5),"旅行 PB · 翻阅本机收藏","pb",{})

func box(p:Vector3,size:Vector3,tone:String,solid:bool=false,kind:String="wood",angle:float=0):
	if solid and kind=="plaster" and size.y>0.5:
		preload("res://scripts/voxel_masonry.gd").panel(b,o+p,size,tone,0.6)
	else:b.box(o+p,size,tone,solid,angle,kind)

func roof(p:Vector3,width:float,depth:float,rise:float):
	# Real horizontal tile courses expose small risers on both slopes.
	var half:float=width/2
	var rows:int=ceili(half/0.55)
	var step:float=half/rows
	var columns:int=ceili(depth/0.65)
	var course:float=depth/columns
	for side in [-1,1]:
		for row in rows:
			var top:float=rise*(1.0-float(row)/rows)+0.09
			for col in columns:
				var q:=Vector3(side*(row+0.5)*step,top-0.10,-depth/2+(col+0.5)*course)
				box(p+q,Vector3(step+0.018,rise/rows+0.20,course-0.014),["49616a","536f76","607b7d"][posmod(row+col/3,3)],false,"slate")
		box(p+Vector3(side*half,0,0),Vector3(0.18,0.29,depth),DARK)
		for end in [-1,1]:
			for row in rows:
				box(p+Vector3(side*(row+0.5)*step,rise*(1.0-float(row)/rows)-0.07,end*(depth/2+0.015)),Vector3(step+0.025,0.22,0.16),"b9b6a0")
	for col in columns:box(p+Vector3(0,rise+0.18,-depth/2+(col+0.5)*course),Vector3(0.34,0.20,course-0.025),"788987",false,"slate")

func front_window(cx:float,width:float,z:float=5.5):
	# Wall sections form a real opening; glazing is a single thin layer.
	box(Vector3(cx,0.54,z),Vector3(width,1.08,0.28),"c9ccb8",true,"plaster")
	box(Vector3(cx,3.17,z),Vector3(width,0.96,0.28),WALL,true,"plaster")
	for side in [-1,1]:box(Vector3(cx+side*width/2,1.91,z),Vector3(0.18,1.72,0.4),WOOD,true)
	for yy in [1.09,2.72]:box(Vector3(cx,yy,z+0.03),Vector3(width+0.2,0.14,0.43),DARK)
	box(Vector3(cx,1.91,z+0.02),Vector3(0.07,1.64,0.18),WOOD)
	box(Vector3(cx,1.92,z+0.02),Vector3(width,0.07,0.18),WOOD)
	box(Vector3(cx,1.0,z+0.21),Vector3(width+0.35,0.14,0.68),"c1b18f",false,"stone")
	b.glass(o+Vector3(cx,1.92,z),Vector3(width-0.2,1.5,0.025))
	b.collision(o+Vector3(cx,1.92,z),Vector3(width-0.2,1.5,0.055))
	for side in [-1,1]:
		box(Vector3(cx+side*(width/2+0.34),1.91,z+0.06),Vector3(0.48,1.62,0.1),"7b9083")
		for row in 7:box(Vector3(cx+side*(width/2+0.34),1.32+row*0.18,z+0.13),Vector3(0.44,0.075,0.025),"a8b4a0")

func side_wall(side:int):
	var x:float=side*7.5
	box(Vector3(x,0.54,0),Vector3(0.3,1.08,11),"c9ccb8",true,"plaster")
	box(Vector3(x,3.17,0),Vector3(0.3,0.96,11),WALL,true,"plaster")
	for z in [-5.38,-0.3,5.38]:box(Vector3(x,1.91,z),Vector3(0.32,1.7,0.24),WALL,true,"plaster")
	for z in [-2.8,2.6]:
		for edge in [-1,1]:box(Vector3(x,1.91,z+edge*2.42),Vector3(0.42,1.7,0.13),WOOD)
		for y in [1.09,2.72]:box(Vector3(x,y,z),Vector3(0.46,0.14,4.9),DARK)
		box(Vector3(x,1.91,z),Vector3(0.18,1.62,0.07),WOOD)
		b.glass(o+Vector3(x,1.92,z),Vector3(0.025,1.48,4.75))
		b.collision(o+Vector3(x,1.92,z),Vector3(0.055,1.48,4.75))
		box(Vector3(x+side*0.17,1,z),Vector3(0.65,0.13,5.1),"c1b18f",false,"stone")

func shell():
	box(Vector3(0,-0.2,0),Vector3(15.1,0.4,11.1),"aaa692",true,"stone")
	box(Vector3(0,-0.025,0),Vector3(14.8,0.055,10.8),"b59b71",false,"wood")
	for row in 23:box(Vector3(0,0.008,-5.25+row*0.47),Vector3(14.65,0.012,0.022),"968665")
	for x in range(-7,8,2):
		for side in [-1,1]:box(Vector3(x,-0.18,side*5.66),Vector3(1.88,0.25,0.15),["aaa692","b3af9a","989d8b"][posmod(x,3)],false,"stone")
	side_wall(-1);side_wall(1)
	box(Vector3(0,1.8,-5.5),Vector3(15,3.6,0.28),WALL,true,"plaster")
	for x in [-7.38,-1.5,1.5,7.38]:box(Vector3(x,1.8,5.5),Vector3(0.29,3.6,0.3),WALL,true,"plaster")
	for x in [-4.45,4.45]:front_window(x,5.45)
	box(Vector3(0,3.2,5.5),Vector3(3,0.8,0.28),WALL,true,"plaster")
	for side in [-1,1]:
		box(Vector3(side*1.12,1.4,5.56),Vector3(0.17,2.8,0.38),DARK,true)
		box(Vector3(side*1.6,1.42,5.65),Vector3(0.57,2.55,0.1),"a38b69")
		for yy in [0.65,1.26,1.9]:box(Vector3(side*1.6,yy,5.72),Vector3(0.42,0.065,0.06),"d0bd97")
		box(Vector3(side*1.48,1.25,5.79),Vector3(0.045,0.2,0.07),"4b5858")
	box(Vector3(0,2.78,5.62),Vector3(2.4,0.15,0.39),DARK)
	box(Vector3(0,-0.045,5.57),Vector3(2.08,0.09,0.62),"bdb599",false,"stone")
	# Main ridge faces the entry: visible gable, filled ends, eaves and a smaller porch roof.
	for side in [-1,1]:
		var panel:=SurfaceTool.new();panel.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices:Array=[Vector3(-7.5,3.55,side*5.51),Vector3(7.5,3.55,side*5.51),Vector3(7.5,3.73,side*5.51),Vector3(0,5.76,side*5.51),Vector3(-7.5,3.73,side*5.51)]
		for index in ([0,1,2,0,2,3,0,3,4] if side>0 else [2,1,0,3,2,0,4,3,0]):panel.add_vertex(vertices[index])
		panel.generate_normals();var face:=MeshInstance3D.new();face.mesh=panel.commit()
		var plaster:=StandardMaterial3D.new();plaster.albedo_color=Color("c9cfba");plaster.roughness=0.91;plaster.cull_mode=BaseMaterial3D.CULL_DISABLED
		face.material_override=plaster;world.add_child(face);face.position=o
	roof(Vector3(0,3.62,0),16.65,12.65,2.25)
	box(Vector3(0,3.56,0),Vector3(14.9,0.12,10.95),"dfd6bd",true,"plaster")
	for x in [-7.3,7.3]:
		for z in [-5.33,5.33]:box(Vector3(x,1.8,z),Vector3(0.18,3.6,0.18),WOOD)
	for z in [-5.59,5.65]:box(Vector3(0,0.82,z),Vector3(14.9,0.1,0.12),"9aa48d")
	box(Vector3(0,4.48,5.65),Vector3(1.5,0.9,0.1),DARK)
	for x in [-0.6,-0.3,0,0.3,0.6]:box(Vector3(x,4.48,5.72),Vector3(0.055,0.68,0.08),"cad0b5")
	# Porch: grounded stone shoes, timber columns, visible brackets and weather shelter.
	box(Vector3(0,-0.125,6.95),Vector3(4.6,0.25,3.3),"b6a17b",true,"wood")
	for x in [-2.08,2.08,-6.84,-3.0]:
		var foot:Vector3=ground(x,7.72)
		var support_height:float=maxf(0.12,o.y+0.02-foot.y)
		b.box(foot+Vector3(0,support_height/2,0),Vector3(0.49,support_height,0.49),"a8a693",true,0,"stone")
	for side in [-1,1]:
		box(Vector3(side*2.08,0.1,7.72),Vector3(0.49,0.4,0.49),"a8a693",true,"stone")
		box(Vector3(side*2.08,1.6,7.72),Vector3(0.19,3.0,0.19),WOOD,true)
		b.beam(o+Vector3(side*2.08,2.28,7.72),o+Vector3(side*1.4,2.95,7.72),0.13,"a98a62")
	box(Vector3(0,2.99,7.72),Vector3(4.8,0.22,0.22),DARK)
	roof(Vector3(0,3.04,6.68),5.25,3.6,0.73)
	for side in [-1,1]:
		box(Vector3(side*1.28,2.81,7.84),Vector3(0.04,0.34,0.04),DARK)
	box(Vector3(0,2.57,7.84),Vector3(3.52,0.47,0.15),DARK)
	box(Vector3(0,2.57,7.925),Vector3(3.35,0.34,0.03),"65786d")
	var nameplate:Label3D=b.text3d("我的海风小屋",o+Vector3(0,2.57,7.95),0.0068,"eee4ce")
	nameplate.name="HomeNameplate093";nameplate.double_sided=false
	box(Vector3(-1.62,2.31,5.82),Vector3(0.54,0.26,0.09),"d8d2ba")
	b.text3d("入口",o+Vector3(-1.62,2.31,5.88),0.0035,"53665b")
	for x in [-2.0,2.0]:lantern(Vector3(x,2.34,5.86))
	# A chimney intersects the actual roof and has a flashed base, rather than a floating box.
	box(Vector3(-4.9,5.0,-2.9),Vector3(0.93,2.4,1.02),"ab9c86",false,"stone")
	box(Vector3(-4.9,6.22,-2.9),Vector3(1.23,0.16,1.32),DARK)
	box(Vector3(-4.9,4.38,-2.9),Vector3(1.28,0.12,1.37),"667871",false,"slate")
	var light:=OmniLight3D.new();world.add_child(light);light.position=o+Vector3(0,2.48,6.4);light.light_color=Color("ffd6a1");light.light_energy=0;light.omni_range=8;light.shadow_enabled=false;world.night_lights.append(light)

func lantern(p:Vector3):
	box(p+Vector3(0,0.24,0),Vector3(0.48,0.1,0.38),DARK)
	box(p+Vector3(0,-0.24,0),Vector3(0.44,0.09,0.35),DARK)
	b.glow_box(o+p,Vector3(0.3,0.37,0.24))
	for side in [-1,1]:box(p+Vector3(side*0.18,0,0.12),Vector3(0.04,0.45,0.035),DARK)

func chair(p:Vector3,angle:float=0):
	var basis:=Basis(Vector3.UP,angle)
	for x in [-0.27,0.27]:
		for z in [-0.25,0.25]:box(p+basis*Vector3(x,0.26,z),Vector3(0.065,0.52,0.065),WOOD)
	box(p+Vector3(0,0.56,0),Vector3(0.69,0.14,0.68),"bebba1",true,"fabric",angle)
	box(p+basis*Vector3(0,0.98,-0.3),Vector3(0.69,0.72,0.12),WOOD,false,"wood",angle)
	box(p+basis*Vector3(0,1.01,-0.21),Vector3(0.55,0.48,0.09),"c9c5a9",false,"fabric",angle)

func book(p:Vector3,tone:String,width:float=0.38):
	box(p,Vector3(width,0.065,0.48),tone)
	box(p+Vector3(0,0.018,0.025),Vector3(width-0.035,0.025,0.4),"e4dac0",false,"plaster")

func desk_lamp(p:Vector3):
	b.shape(o+p+Vector3(0,0.035,0),Vector3(0.3,0.07,0.3),"5d6f63","round")
	box(p+Vector3(0,0.31,0),Vector3(0.045,0.56,0.045),DARK)
	b.shape(o+p+Vector3(0,0.65,0),Vector3(0.53,0.27,0.53),"d9c6a3","pot")
	b.glow_box(o+p+Vector3(0,0.51,0),Vector3(0.34,0.06,0.34))

func cabinet(p:Vector3,width:float,height:float=1.0):
	box(p+Vector3(0,height/2,0),Vector3(width,height,0.54),"937c58",true)
	box(p+Vector3(0,height+0.035,0),Vector3(width+0.1,0.1,0.64),"b8a77f")
	for x in [-width/4,width/4]:
		box(p+Vector3(x,height/2,0.3),Vector3(width/2-0.07,height-0.15,0.06),"b09973")
		box(p+Vector3(x+width/8,height/2+0.06,0.35),Vector3(0.08,0.06,0.05),"54685f")

func interior():
	# A clear central route connects entrance, collection and both side rooms.
	box(Vector3(-4.65,0.032,-0.45),Vector3(4.6,0.02,4.15),"c2b69e",false,"fabric")
	for x in [-6.6,-2.7]:box(Vector3(x,0.046,-0.45),Vector3(0.05,0.012,3.9),"8d9c8c",false,"fabric")
	box(Vector3(-4.8,0.44,-2.05),Vector3(3.15,0.62,1.03),"a1b3a1",true,"fabric")
	box(Vector3(-4.8,1.06,-2.44),Vector3(3.12,0.74,0.23),"91a592",false,"fabric")
	for side in [-1,1]:
		box(Vector3(-4.8+side*1.55,0.73,-2.0),Vector3(0.23,0.95,1.1),WOOD,true)
		box(Vector3(-4.8+side*0.75,0.8,-2.05),Vector3(1.35,0.16,0.9),"b5c1a9",false,"fabric")
		box(Vector3(-4.8+side*0.99,1.04,-2.3),Vector3(0.5,0.43,0.15),"d8c8b2",false,"fabric")
		for z in [-2.36,-1.65]:box(Vector3(-4.8+side*1.17,0.13,z),Vector3(0.12,0.26,0.12),DARK)
	box(Vector3(-4.8,0.46,0.11),Vector3(2.1,0.13,1.06),"b09872",true)
	for side in [-1,1]:box(Vector3(-4.8+side*0.72,0.2,0.11),Vector3(0.12,0.4,0.78),DARK)
	book(Vector3(-5.17,0.56,0.15),"879b9a",0.46)
	b.shape(o+Vector3(-4.17,0.56,-0.02),Vector3(0.21,0.03,0.21),"e7dfc8","round")
	b.shape(o+Vector3(-4.17,0.63,-0.02),Vector3(0.13,0.13,0.13),"ece4ce","round")
	# Entry shoe cabinet and coat hooks are tucked against the front wall.
	cabinet(Vector3(-5.3,0,4.77),2.3,0.72)
	for x in [-5.9,-5.3,-4.7]:
		box(Vector3(x,1.8,5.17),Vector3(0.08,0.15,0.19),DARK)
		box(Vector3(x,1.1,4.81),Vector3(0.42,0.08,0.24),"c7bbaa")
	box(Vector3(0,0.02,4.55),Vector3(2.3,0.025,1.1),"718980",false,"fabric")
	# Actual source photograph, record archive and PB shelf form one composed collection wall.
	cabinet(Vector3(0,0,-4.76),5.0,0.94)
	box(Vector3(0,2.24,-5.30),Vector3(2.3,2.2,0.10),"a28f6b")
	box(Vector3(0,2.24,-5.24),Vector3(2.12,2.01,0.025),"e0d6be",false,"plaster")
	world.home_picture=b.picture("res://assets/media/portrait_01.jpg",o+Vector3(0,2.24,-5.17),2,0,false)
	for side in [-1,1]:
		house.photo(6 if side<0 else 7,Vector3(side*2.28,2.16,-5.17),0.95)
		box(Vector3(side*2.28,1.52,-5.11),Vector3(1.1,0.18,0.04),"d3c9b0")
		b.text3d("精选影像",o+Vector3(side*2.28,1.52,-5.08),0.0025,"55695e")
	box(Vector3(0,0.80,-4.40),Vector3(2.30,0.24,0.03),"597264")
	b.text3d("鞠婧祎 · 我的收藏",o+Vector3(0,0.80,-4.377),0.003,"e5d9bd")
	box(Vector3(-1.75,1.07,-4.75),Vector3(0.82,0.13,0.45),DARK)
	b.shape(o+Vector3(-1.75,1.15,-4.75),Vector3(0.52,0.03,0.52),"354e51","round")
	b.shape(o+Vector3(-1.75,1.17,-4.75),Vector3(0.12,0.034,0.12),"cfbb92","round")
	box(Vector3(-1.60,0.30,-4.40),Vector3(1.50,0.29,0.03),"cbbd9c")
	b.text3d("海风演示\n原创器乐 · 本地试听",o+Vector3(-1.60,0.30,-4.377),0.0018,"52695b")
	for i in 5:book(Vector3(1.35,1.03+i*0.075,-4.76),["879896","c5ac92","acb79e"][i%3],0.42)
	# Desk faces the side garden; it no longer blocks the middle of the room.
	box(Vector3(4.8,0.81,-3.0),Vector3(2.65,0.13,1.17),"b39b74",true)
	for x in [3.7,5.9]:box(Vector3(x,0.39,-3.0),Vector3(0.12,0.78,0.87),DARK)
	chair(Vector3(4.7,0,-1.75),PI)
	book(Vector3(4.5,0.9,-2.95),"7e9793",0.51);book(Vector3(4.4,0.97,-2.99),"c3b69c",0.46)
	desk_lamp(Vector3(5.78,0.87,-3.04))
	box(Vector3(4.70,0.81,-2.39),Vector3(1.90,0.19,0.03),"597264")
	b.text3d("旅行 PB · 阅读",o+Vector3(4.70,0.81,-2.367),0.0025,"e5d9bd")
	# A small window seat is usable as a rest interaction, with garden framed beyond.
	box(Vector3(4.85,0.28,4.67),Vector3(3.1,0.56,0.82),"af9670",true)
	box(Vector3(4.85,0.59,4.67),Vector3(2.98,0.13,0.8),"c5c5ab",false,"fabric")
	box(Vector3(4.85,0.12,5.25),Vector3(2.6,0.06,0.15),WOOD)
	house.action("window_seat",Vector3(4.85,0,3.4),"窗边休息 · 看花园","sit",{"seat":o+Vector3(4.85,0.22,4.67),"yaw":PI})
	for x in [-3.7,3.6]:
		box(Vector3(x,3.26,-0.2),Vector3(0.04,0.38,0.04),DARK)
		b.shape(o+Vector3(x,2.99,-0.2),Vector3(0.76,0.35,0.76),"d9c59e","pot")
		b.glow_box(o+Vector3(x,2.84,-0.2),Vector3(0.52,0.06,0.52))
		var light:=OmniLight3D.new();world.add_child(light);light.position=o+Vector3(x,2.8,-0.2);light.light_color=Color("ffe0b1");light.omni_range=9;light.shadow_enabled=false;world.home_lights.append(light);light.set_meta("stream_ref","home_light")
	# Compact vase table is the existing bouquet slot, inside the collection zone.
	box(Vector3(2,0.67,-2.6),Vector3(0.8,0.12,0.75),"b29970",true)
	box(Vector3(2,0.32,-2.6),Vector3(0.32,0.64,0.32),DARK)
	world.set_home_light(world.home_light_index)

func bouquet(builder,p:Vector3,index:int,colors:Array=[]):
	builder.shape(p+Vector3(0,0.16,0),Vector3(0.24,0.32,0.24),"d2c2a5","pot")
	for i in 5:
		var q:=p+Vector3(sin(i*2.4)*0.14,0.48+(i%3)*0.08,cos(i*2.4)*0.14)
		builder.beam(p+Vector3(0,0.22,0),q,0.02,"718657")
		builder.shape(q,Vector3(0.19,0.15,0.19),(colors[i%colors.size()] if not colors.is_empty() else ["c8afca","e2c797","92ac7d"][clampi(index,0,2)]),"shrub")

func ground(dx:float,dz:float,offset:float=0)->Vector3:return world.surface(o.x+dx,o.z+dz,offset)

func garden():
	# Remove the old giant wood slab: a narrow supported walk rises through a planted court.
	if world.layout==null:
		world.path_between(Vector2(-220,-148.5),Vector2(-237,-148.5),3.8,"c6bba1")
		world.path_between(Vector2(-237,-148.5),Vector2(-237,-157),3.0,"c6bba1")
	var entry:=o+Vector3(0,0.10,8.64)
	b.ramp(ground(0,12.0,0.055),entry,2.6,"b3a181")
	# Boards lie on the real incline; side cheeks meet the ground rather than exposing a triangle.
	var a:=ground(0,12.0,0.055);var c:=entry
	var slope_basis:=Basis(Vector3.RIGHT,-atan2(c.y-a.y,c.z-a.z))
	for i in 9:
		var p:Vector3=a.lerp(c,(i+0.5)/9.0)
		b.oriented_box(p+Vector3(0,0.012,0),Vector3(2.58,0.025,a.distance_to(c)/9-0.04),"b4a583" if i%3 else "a89d7e",slope_basis,false,"wood")
		for side in [-1,1]:
			var y:float=world.height_at(p.x+side*1.45,p.z);var height:float=maxf(0.10,p.y-y)
			b.box(Vector3(p.x+side*1.45,y+height/2,p.z),Vector3(0.24,height,0.52),["a7a996","b8b49d","969e8b"][i%3],false,0,"stone")
	for side in [-1,1]:
		b.beam(a+Vector3(side*1.34,0.05,0),c+Vector3(side*1.34,0.05,0),0.12,DARK)
	# A distinct side veranda is a real reachable outdoor room.
	box(Vector3(-4.9,-0.08,6.95),Vector3(4.4,0.22,3.3),"a8936d",true)
	box(Vector3(-2.55,-0.08,6.95),Vector3(1.0,0.22,3.3),"a8936d",true)
	for x in [-6.84,-3.0]:
		box(Vector3(x,1.34,7.7),Vector3(0.14,2.68,0.14),WOOD,true)
		box(Vector3(x,0.1,7.7),Vector3(0.33,0.3,0.33),"b2ad94",false,"stone")
	box(Vector3(-4.9,2.74,6.9),Vector3(4.65,0.17,2.95),SLATE,true,"slate")
	box(Vector3(-4.9,2.61,7.7),Vector3(4.25,0.17,0.14),DARK)
	for x in [-6.2,-3.7]:
		chair(Vector3(x,0.04,6.82))
		box(Vector3(x,0.13,7.4),Vector3(0.64,0.06,0.13),DARK)
	box(Vector3(-4.9,0.59,6.84),Vector3(0.92,0.12,0.8),"b3a17c",true)
	box(Vector3(-4.9,0.26,6.84),Vector3(0.12,0.52,0.12),DARK)
	house.action("porch_seat",Vector3(-3.7,0,7.6),"门廊休息 · 看向镇区","sit",{"seat":o+Vector3(-3.7,0.22,6.82),"yaw":PI})
	# Forecourt planting and landings are now assembled by the environment modules.
	# Low perimeter has openings, a turn and varied planting, not an enclosing long fence.
	for side in [-1,1]:
		for dz in [-7.2,-4.8,-2.4,0,2.4,4.8,7.2]:
			if side<0 and dz==-7.2:continue
			var p:Vector3=ground(side*10.2,dz)
			b.box(p+Vector3(0,0.42,0),Vector3(0.13,0.84,0.16),"a9b5a0")
			for yy in [0.28,0.67]:b.box(p+Vector3(0,yy,1.2),Vector3(0.095,0.075,2.4),"bbc3aa")
		if side<0:
			world.path_between(Vector2(o.x-9,o.z+8.2),Vector2(o.x-9,o.z-5),2.1,"b4b49a")
			world.path_between(Vector2(o.x-9,o.z+8.2),Vector2(o.x,o.z+15.5),2.1,"b4b49a")
		for dz in [-5.8,-1.1,3.5,7.4]:
			var p:Vector3=ground(side*12.0,dz)
			plant_cluster(p,1.1,roundi(dz*3))
	# Mailbox and low lanterns anchor the actual entrance without huge signs.
	var mail:Vector3=ground(6.4,16.8)
	b.box(mail+Vector3(0,0.5,0),Vector3(0.11,1,0.11),DARK)
	b.box(mail+Vector3(0,1.04,0),Vector3(0.63,0.47,0.38),"6f8981")
	b.box(mail+Vector3(0,1.27,0),Vector3(0.73,0.06,0.47),SLATE)
	b.box(mail+Vector3(0,1.1,0.205),Vector3(0.39,0.025,0.035),DARK)
	for p in [ground(-2.2,15.5),ground(2.3,10.8),ground(-10.9,6.5)]:
		b.box(p+Vector3(0,0.37,0),Vector3(0.11,0.74,0.11),DARK);b.glow_box(p+Vector3(0,0.82,0),Vector3(0.26,0.24,0.26));b.box(p+Vector3(0,0.98,0),Vector3(0.38,0.07,0.38),SLATE)
	# Purposeful small tree groups: clear entrance, different silhouettes and a visible hillside.
	# The east-rear scrub tree used to block N05's 240-to-260-degree path.
	# Keep its family and size, moving its rooted trunk into the outside planting margin.
	for record in [[-15.6,5.0,3,0.85],[13.8,3.5,0,0.92],[-15,-10,1,1.15],[19,-16,6,0.85],[-21,-20,1,1.25],[6,-21,2,1.2],[-4,-18,0,0.95]]:
		preload("res://scripts/vegetation_art.gd").new().tree(b,ground(record[0],record[1]),record[2],record[3])
	for center in [Vector2(-18,-6),Vector2(13,-18),Vector2(-26,-16),Vector2(10,15)]:
		for i in 6:
			var p:Vector3=ground(center.x+sin(i*2.4)*2.7,center.y+cos(i*2.4)*2.0)
			if world.clear_of_paths(Vector2(p.x,p.z),0.85):plant_cluster(p,0.58+i%3*0.2,i)
	preload("res://scripts/environment_garden.gd").new(world,o).build()

func plant_cluster(p:Vector3,size:float,variation:int):
	for i in 3:
		b.box(p+Vector3((i-1)*size*0.31,size*0.28,cos(i*2.3)*size*0.21),Vector3(size*0.58,size*0.56,size*0.61),["6f8060","89976a","596d50"][posmod(i+variation,3)],false,0,"leaf")
	if posmod(variation,3)==0:
		for i in 4:
			var q:=p+Vector3(sin(i*2.4)*size*0.45,size*0.65,cos(i*2.4)*size*0.3)
			b.beam(q-Vector3(0,size*0.5,0),q,0.025,"72875d")
			b.box(q,Vector3(0.21,0.13,0.21),["d8c8aa","cdb5c5"][i%2],false,0,"leaf")
