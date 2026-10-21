extends RefCounted
## Third-round venue-specific architecture and furniture; source media and actions stay intact.
var house
var b
var o:Vector3
var w:float
var d:float
var h:float

func build(target):
	house=target;b=house.b;o=house.origin;w=house.w;d=house.d;h=house.h
	if house.item.type not in ["gallery","cinema","pb","dance","studio","theater"]:return
	base_and_windows()
	match house.item.type:
		"gallery":gallery()
		"cinema":cinema()
		"pb":photobook()
		"dance":dance()
		"studio":studio()
		"theater":theater()

func box(p:Vector3,s:Vector3,c:String,solid:bool=false):b.box(o+p,s,c,solid)
func text(t:String,p:Vector3,size:float=0.009,c:String="e7dcc1",angle:float=0):b.text3d(t,o+p,size,c,angle)
func beam(a:Vector3,c:Vector3,size:float,tone:String):b.beam(o+a,o+c,size,tone)

func base_and_windows():
	var kind:String=house.item.type
	var trim:String={"theater":"686a73","cinema":"687981","studio":"927557","gallery":"bac2b2","pb":"a9926c","dance":"a99673"}[kind]
	for side in [-1,1]:
		box(Vector3(side*(w/2+0.23),0.35,0),Vector3(0.15,0.5,d+0.3),trim)
		for z in range(-int(d/2),int(d/2),2):
			box(Vector3(side*(w/2+0.32),0.33,z),Vector3(0.018,0.46,0.02),"dfd4bd")
		if kind in ["gallery","pb","dance"]:
			if not (house.world.layout!=null and house.item.id=="B05" and side==-1):b.glass(o+Vector3(side*w/2,2.3,0),Vector3(0.025,1.74,d-0.2))
			for z in range(-int(d/2)+1,int(d/2),3):
				box(Vector3(side*(w/2+0.26),2.28,z),Vector3(0.16,1.9,0.08),"516a68")
			box(Vector3(side*(w/2+0.16),3.3,0),Vector3(0.45,0.15,d+0.5),trim)
			box(Vector3(side*(w/2+0.4),h-0.35,0),Vector3(0.23,0.35,d+0.5),trim)
		# Downpipes and shoes ground the roof details without blocking the door.
		box(Vector3(side*(w/2+0.28),h/2,-d/2+0.4),Vector3(0.13,h,0.13),"758780")
		box(Vector3(side*(w/2+0.38),0.1,-d/2+0.4),Vector3(0.45,0.2,0.4),"8f9989")
		if kind in ["cinema","theater"]:
			box(Vector3(side*(w/4+0.85),2.22,d/2+0.06),Vector3((w-3.4)/2,1.75,0.025),"647978")
		else:b.glass(o+Vector3(side*(w/4+0.8),2.22,d/2),Vector3((w-3.4)/2-0.1,1.75,0.025))
	for y in [0.6,1.1]:
		box(Vector3(0,y,-d/2-0.24),Vector3(w+0.3,0.08,0.16),trim)

func sofa(p:Vector3,width:float=2.6,tone:String="9eaaa0",angle:float=0):
	var basis:=Basis(Vector3.UP,angle)
	for x in [-width/2+0.18,width/2-0.18]:
		for z in [-0.34,0.34]:b.box(o+p+basis*Vector3(x,0.13,z),Vector3(0.1,0.26,0.1),"746650")
	b.box(o+p+Vector3(0,0.43,0),Vector3(width,0.36,0.95),tone,true,angle)
	b.box(o+p+basis*Vector3(0,0.85,-0.4),Vector3(width,0.7,0.18),tone,false,angle)
	for x in [-width/2,width/2]:b.box(o+p+basis*Vector3(x,0.6,0),Vector3(0.16,0.45,0.95),"8d968b",false,angle)
	for i in int(width/0.65):b.box(o+p+basis*Vector3(-width/2+0.3+i*0.65,0.62,0.04),Vector3(0.57,0.08,0.68),"b8bcaa",false,angle)

static func auditorium_seat(builder,p:Vector3,tone:String):
	builder.box(p+Vector3(0,0.19,0),Vector3(0.56,0.38,0.48),"38494b")
	builder.box(p+Vector3(0,0.49,0),Vector3(1.0,0.19,0.68),tone)
	builder.oriented_box(p+Vector3(0,0.97,0.34),Vector3(1.0,0.93,0.17),tone,Basis(Vector3.RIGHT,-0.1))
	builder.box(p+Vector3(0,1.2,0.21),Vector3(0.75,0.25,0.06),"a99bab")
	for side in [-1,1]:
		builder.box(p+Vector3(side*0.57,0.47,0.06),Vector3(0.07,0.82,0.08),"405256")
		builder.box(p+Vector3(side*0.57,0.81,-0.03),Vector3(0.15,0.11,0.65),"b29d7e")
	builder.collision(p+Vector3(0,0.62,0.07),Vector3(1.22,1.24,0.93))

func track(p:Vector3,length:float):
	if house.world.layout!=null and house.item.id not in ["B06","B08","B10"]:
		box(p,Vector3(length,.20,.25),"5e4232")
		for i in maxi(1,int(length/4)):
			var q:=p+Vector3(-length*.5+2+i*4,-.35,0);box(q,Vector3(.30,.45,.30),"d6bd93");b.glow_box(o+q,Vector3(.23,.32,.23))
		return
	box(p,Vector3(length,0.07,0.09),"455b5b")
	for i in int(length/2):
		var q:=p+Vector3(-length/2+1+i*2,-0.17,0)
		box(q,Vector3(0.28,0.3,0.38),"586761")
		b.glow_box(o+q+Vector3(0,-0.16,0.08),Vector3(0.19,0.025,0.21))

func book(p:Vector3,tone:String="aea0b8",open_book:bool=false,printed_lines:bool=true):
	if open_book:
		for side in [-1,1]:
			b.oriented_box(o+p+Vector3(side*0.23,0.035,0),Vector3(0.46,0.05,0.58),"e9dfc5",Basis(Vector3.FORWARD,side*0.09))
			if printed_lines:
				for i in 5:box(p+Vector3(side*0.23,0.07,-0.17+i*0.07),Vector3(0.31,0.009,0.009),"b2ae99")
	else:
		box(p,Vector3(0.56,0.06,0.73),tone)
		box(p+Vector3(0,0.035,0.04),Vector3(0.49,0.014,0.56),"d7ccb0")

func gallery():
	# Taller corner piers, horizontal stone bands, and roof-light volumes.
	for side in [-1,1]:
		box(Vector3(side*9.9,3.0,8.37),Vector3(1.35,6,0.75),"d2d3c5")
		for z in [-6,-2,2,6]:box(Vector3(side*11.25,4.45,z),Vector3(0.2,2.2,0.4),"b8c1b2")
	for x in [-5.2,5.2]:
		for side in [-1,1]:
			box(Vector3(x+side*3.25,6.28,-1),Vector3(0.13,0.82,7.5),"bac9c2")
			box(Vector3(x,6.28,-1+side*3.8),Vector3(6.6,0.82,0.13),"bac9c2")
			b.glass(o+Vector3(x+side*3.2,6.28,-1),Vector3(0.02,0.63,7.35))
			b.glass(o+Vector3(x,6.28,-1+side*3.75),Vector3(6.28,0.63,0.02))
		for edge in [-1,1]:box(Vector3(x+edge*1.6,6.27,-1),Vector3(0.075,0.8,7.4),"758b80")
		box(Vector3(x,6.78,-1),Vector3(7.6,0.22,8.6),"5c7776")
		for z in [-4,-2,0,2]:box(Vector3(x,6.35,z),Vector3(7.12,0.12,0.1),"e0dfca")
	for y in [3.42,5.65]:box(Vector3(0,y,8.24),Vector3(21.5,0.12,0.16),"b6bca8")
	track(Vector3(0,5.24,-6.5),18)
	track(Vector3(-5.5,4.8,1.4),7)
	track(Vector3(5.5,4.8,-0.5),7)
	for idx in 4:
		var x:float=-8.1+idx*5.4
		box(Vector3(x,1.03,-7.67),Vector3(1.15,0.32,0.035),"ece6d7")
		text("%02d  ·  精选影像"%(idx+1),Vector3(x,1.04,-7.64),0.0038,"586c65")
	# A reading guide sits beside the entrance, not across an artwork's viewing distance.
	box(Vector3(8,1.14,5.5),Vector3(2.85,0.08,1.06),"d1c4a9")
	book(Vector3(7.35,1.2,5.5),"a9b7ad",true)
	box(Vector3(8,0.75,6.015),Vector3(2.4,0.3,0.035),"e6dbc1")
	text("精选影像 · 来源在作品详情",Vector3(8,0.75,6.04),0.0032,"586c65")
	for z in [-5,0,5]:box(Vector3(-10.65,0.05,z),Vector3(0.11,0.07,2),"a5afa3")

func cinema():
	# Brick-like upper band and deep steel surround distinguish it from the theatre.
	for side in [-1,1]:
		box(Vector3(side*13.4,4.5,11.9),Vector3(1.25,9,1.1),"50636c")
		for z in [-9,-5,-1,3,7]:
			box(Vector3(side*14.28,4.2,z),Vector3(0.2,7.6,2.5),"85938f")
		for y in [1.7,3.7,5.7,7.7]:box(Vector3(side*14.4,y,0),Vector3(0.06,0.055,21.6),"b8b9a4")
	box(Vector3(0,8.25,11.85),Vector3(25.5,1.7,0.65),"536974")
	text("C I N E M A",Vector3(0,8.28,12.2),0.026,"e0d5b4")
	box(Vector3(0,4.04,12.7),Vector3(24.3,0.22,3),"64767a")
	for x in range(-11,12):box(Vector3(x,3.89,12.7),Vector3(0.11,0.11,2.8),"b5a282")
	# Lobby programme desk, ticket-window grille and coat niche.
	# Open ticket-window frame sits at the back edge of the original counter.
	for x in [-11.2,-6.8]:box(Vector3(x,2.5,8.48),Vector3(0.13,2.4,0.13),"627876")
	box(Vector3(-9,3.7,8.48),Vector3(4.53,0.15,0.13),"627876")
	box(Vector3(-9,3.43,8.48),Vector3(2.4,0.40,0.08),"627876")
	text("放映咨询",Vector3(-9,3.43,8.528),0.005,"e6dac0")
	sofa(Vector3(6.8,0,10.8),3.6,"889c9e")
	box(Vector3(0,0.04,9.5),Vector3(6,0.045,3.1),"687a78")
	for side in [-1,1]:
		box(Vector3(side*10.4,3.4,5.97),Vector3(0.38,3.1,0.4),"546569")
		text("影厅入口",Vector3(side*11.4,3.1,6.28),0.0065,"dccf9e")
	track(Vector3(0,7.9,8.5),19)
	# Existing six tiered rows stay intact; low warm strips make each riser readable.
	for row in 6:
		var level:float=(5-row)*0.24
		for side in [-1,1]:
			b.glow_box(o+Vector3(side*8.15,level+0.035,3-row*1.65+0.77),Vector3(0.5,0.05,0.045))
	var aisle_light:=OmniLight3D.new();house.world.add_child(aisle_light);aisle_light.position=o+Vector3(0,5.9,-1.5);aisle_light.light_color=Color("dfcfb5");aisle_light.light_energy=0.22;aisle_light.omni_range=13;aisle_light.shadow_enabled=false

func photobook():
	# Fine timber screen wraps the upper wall, leaving real side windows exposed.
	for side in [-1,1]:
		for z in range(-8,9):box(Vector3(side*12.3,4.55,z),Vector3(0.18,2.3,0.12),"ad9270")
		box(Vector3(side*12.5,3.32,0),Vector3(0.8,0.13,18.4),"b39a78")
		box(Vector3(side*8,0.1,4.7),Vector3(4.3,0.05,3.4),"b6bda8")
	sofa(Vector3(-10.8,0,-2),2.6,"a8b5a2",PI/2)
	sofa(Vector3(10.8,0,-1.5),2.6,"b3a4b2",-PI/2)
	for x in [-1.6,1.6]:book(Vector3(x,0.995,0),"ad9bb8",true,false)
	for x in [-8,-4,0,4,8]:
		text("项目策展册",Vector3(x,2.64,-7.5),0.0042,"596d61")
		box(Vector3(x,2.45,-7.5),Vector3(2.2,0.04,0.08),"b9ac8e")
		var shelf_index:int=int((x+8)/4)
		for slot in 2:
			var cover_pos:=Vector3(x-0.48+slot*0.96,1.75,-7.39)
			box(cover_pos,Vector3(0.42,0.50,0.085),"d4c4a0")
			printed_photo(shelf_index*2+slot+1,cover_pos+Vector3(0,0,0.05),Vector2(0.36,0.43))
	# Real selected image pages lie on the existing physical reading books.
	for book_index in 2:
		var xx:float=-1.6 if book_index==0 else 1.6
		for side in [-1,1]:
			printed_photo(1+book_index*4+(1 if side>0 else 0),Vector3(xx+side*0.23,1.056,0),Vector2(0.37,0.46),Basis(Vector3.FORWARD,side*0.09)*Basis(Vector3.RIGHT,-PI/2))
	text("本项目主题纪念册 · 非官方出版物",Vector3(0,2.06,-6.9),0.0034,"647967")
	for x in [-8,8]:
		box(Vector3(x,3.9,1),Vector3(0.045,2.7,0.045),"776d57")
		b.shape(o+Vector3(x,2.55,1),Vector3(0.9,0.24,0.9),"d9c6a3","pot")
	box(Vector3(0,0.77,0.585),Vector3(2.2,0.32,0.065),"dfd2b3")
	text("纪念册阅读台",Vector3(0,0.77,0.625),0.004,"576b64")

func printed_photo(index:int,p:Vector3,frame:Vector2,basis:Basis=Basis.IDENTITY):
	var texture:Texture2D=load("res://assets/media/portrait_%02d.jpg"%index)
	var ratio:=float(texture.get_width())/texture.get_height()
	var quad:=QuadMesh.new();quad.size=Vector2(minf(frame.x,frame.y*ratio),minf(frame.y,frame.x/ratio))
	var picture:=MeshInstance3D.new();picture.mesh=quad
	var mat:=StandardMaterial3D.new();mat.albedo_texture=texture;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC;picture.material_override=mat
	house.world.add_child(picture);picture.transform=Transform3D(basis,o+p)
	picture.set_meta("printed_source","portrait_%02d"%index)

func dance():
	for side in [-1,1]:
		for z in range(-7,8,2):box(Vector3(side*10.25,4.8,z),Vector3(0.23,2.35,0.16),"ad9877")
		box(Vector3(side*10.23,5.1,0),Vector3(0.15,0.2,15),"718a86")
	for x in [-6,0,6]:
		box(Vector3(x,6.53,0),Vector3(4.7,0.72,11),"b5c5bf")
		b.oriented_box(o+Vector3(x,7.03,0),Vector3(5.1,0.18,11.4),"698680",Basis(Vector3.RIGHT,-0.075))
		for z in [-5,5]:box(Vector3(x,6.63,z),Vector3(4.7,0.1,0.1),"e4dcc4")
	# Clear practice floor receives a border and restrained spacing marks.
	for x in [-6.5,6.5]:box(Vector3(x,0.035,-1),Vector3(0.035,0.018,9),"cdbb93")
	for z in [-4,0,3]:
		for x in [-3,0,3]:box(Vector3(x,0.037,z),Vector3(0.16,0.014,0.035),"bfaa83")
	for x in [-7,-5,-3]:
		for y in [0.4,2.1]:
			for j in 4:box(Vector3(x-0.45+j*0.25,y,6.17),Vector3(0.14,0.035,0.02),"5c7775")
		text(str(int(x+8)),Vector3(x-0.35,1.72,6.16),0.0045,"e4dcc7",PI)
	sofa(Vector3(7.8,0,2.5),2.1,"b2b4a2",-PI/2)
	for x in [-8,8]:
		for z in [-4,0,2]:box(Vector3(x,0.3,z),Vector3(0.3,0.12,0.38),"6d7f77")
	track(Vector3(0,5.35,3.5),15)
	text("更 衣 / 储 物",Vector3(-5,3.4,7.3),0.007,"4e6b64",PI)

func studio():
	for side in [-1,1]:
		for z in range(-6,7):box(Vector3(side*8.77,3.65,z),Vector3(0.18,1.8,0.18),"987b5c")
		box(Vector3(side*8.74,1.1,0),Vector3(0.17,0.18,12.8),"a9916e")
	box(Vector3(0,4.65,6.8),Vector3(17.7,0.38,1.7),"546c6b")
	for x in [-7.7,7.7]:box(Vector3(x,2.4,6.93),Vector3(0.5,4.8,0.5),"8b785d")
	# The west booth has solid rear/side walls, protected glazing and a 1.8 m east entrance.
	box(Vector3(-7.4,1.5,-3.8),Vector3(0.12,3,3.3),"6c7b76",true)
	box(Vector3(-4.5,1.5,-5.45),Vector3(5.9,3,0.12),"6c7b76",true)
	box(Vector3(-4.5,0.25,-2.1),Vector3(5.9,0.5,0.12),"6c7b76",true)
	b.collision(o+Vector3(-4.5,1.8,-2.1),Vector3(5.9,3,0.08))
	box(Vector3(-1.55,1.5,-5),Vector3(0.12,3,0.9),"6c7b76",true)
	box(Vector3(-1.55,1.5,-2.45),Vector3(0.12,3,0.6),"6c7b76",true)
	box(Vector3(-1.55,2.86,-3.55),Vector3(0.12,0.28,2),"6c7b76")
	# Console monitors, faders and headphone rests; never recording the user.
	for x in [-4.85,-3.2]:
		box(Vector3(x,1.57,-1.5),Vector3(0.95,0.64,0.08),"2b4247")
		box(Vector3(x,1.6,-1.447),Vector3(0.8,0.44,0.015),"91b4ad")
		box(Vector3(x,1.15,-1.52),Vector3(0.08,0.27,0.16),"576762")
	for i in 8:
		box(Vector3(-4.85+i*0.24,1.18,-0.8),Vector3(0.015,0.04,0.43),"bac7b3")
		box(Vector3(-4.85+i*0.24,1.23,-0.82+sin(i)*0.1),Vector3(0.14,0.06,0.08),"d8ccb1")
	# Pop filter, stand tripod, cable and printed generic sheet (no invented lyrics).
	beam(Vector3(2,1.35,-2),Vector3(2,1.62,-1.72),0.025,"4c5e5c")
	box(Vector3(2,1.68,-1.72),Vector3(0.3,0.3,0.035),"425454")
	for i in 3:
		var angle:float=i*TAU/3
		beam(Vector3(2,0.27,-2),Vector3(2+sin(angle)*0.45,0.05,-2+cos(angle)*0.45),0.04,"4b5c58")
	book(Vector3(3.5,1.17,-2.3),"b7ae91",true)
	box(Vector3(3.5,0.54,-2.3),Vector3(0.055,1.08,0.055),"68796b")
	for i in 3:
		var angle:float=i*TAU/3
		beam(Vector3(3.5,0.22,-2.3),Vector3(3.5+sin(angle)*0.4,0.05,-2.3+cos(angle)*0.4),0.035,"68796b")
	for x in [-6.9,-1.1]:
		box(Vector3(x,0.79,-1),Vector3(0.45,1.55,0.45),"394e52")
		for y in [0.55,1.1]:box(Vector3(x,y,-0.75),Vector3(0.3,0.3,0.025),"6b7d79")
	sofa(Vector3(5.9,0,4.2),3.2,"9aaea3")
	for x in [-2.3,0.8]:
		box(Vector3(x,0.81,-0.3),Vector3(0.055,1.62,0.055),"66756b")
		box(Vector3(x,0.045,-0.3),Vector3(0.48,0.09,0.4),"57675f")
		for i in 7:
			var a:float=i*PI/6
			box(Vector3(x+cos(a)*0.17,1.73+sin(a)*0.17,-0.3),Vector3(0.08,0.08,0.12),"3f5355")
		for side in [-1,1]:box(Vector3(x+side*0.17,1.65,-0.3),Vector3(0.13,0.23,0.16),"75867f")

func theater():
	# The audience sees a low entrance wing, tall rhythm piers and three real pitched folds.
	# The raised middle fold overlaps its neighbours horizontally but leaves a vertical
	# step at each valley. Actual upstands and narrow valley trays close that joint.
	for side in [-1,1]:
		box(Vector3(side*6.04,h+0.34,0),Vector3(0.13,0.82,d+2.46),"596b72")
		box(Vector3(side*5.78,h+0.08,0),Vector3(0.60,0.11,d+2.46),"6b7f80")
		for end in [-1,1]:box(Vector3(side*5.83,h+0.35,end*(d/2+1.24)),Vector3(0.69,0.67,0.12),"b1b6a7")
	house.world.set_meta("theater_roof_joints_089",{"vertical_step_m":0.65,"valleys":2,"joint_modules":8,"colliders_added":0,"roof_volume_retained":true})
	for side in [-1,1]:
		for z in [-11,-6,-1,4,9,13]:
			box(Vector3(side*17.32,5.4,z),Vector3(0.55,10.8,1.15),"8a8d90")
			box(Vector3(side*17.67,5.5,z),Vector3(0.18,8.8,0.3),"c2c1b2")
		box(Vector3(side*17.25,2.5,1),Vector3(0.28,2.7,23),"78838a")
		box(Vector3(side*17.9,3.95,1),Vector3(1.5,0.22,25),"5f737a")
		for x in [4.5,7,9.5,12,14.5]:
			box(Vector3(side*x,9,14.34),Vector3(0.35,5.2,0.5),"bdbaa6")
	box(Vector3(0,11.65,14.32),Vector3(34.7,0.36,0.8),"bfc3b5")
	text("S T A R L I G H T",Vector3(0,8.8,14.32),0.03,"657479")
	# Rear service elevation uses recessed louvres and stone bands rather than a blank box.
	for x in [-12,-6,0,6,12]:
		box(Vector3(x,5.3,-14.24),Vector3(2.6,5.8,0.18),"7c8984")
		for y in range(3,8):box(Vector3(x,y,-14.4),Vector3(2.45,0.16,0.3),"b4b7a6")
	for y in [1.1,9.5]:box(Vector3(0,y,-14.28),Vector3(34,0.2,0.35),"b4b7a6")
	# Timber acoustic wall panels and staggered baffles add scale above seated sightlines.
	for side in [-1,1]:
		for z in [-10,-5,0,5,10]:
			box(Vector3(side*16.7,4.5,z),Vector3(0.13,5.2,3.5),"8c7e72")
			for j in 7:box(Vector3(side*16.58,4.5,z-1.3+j*0.42),Vector3(0.13,5.0,0.11),"b5a28a")
	for z in [-5,0,5]:
		box(Vector3(0,10.55,z),Vector3(29,0.16,1.5),"ada18a")
		track(Vector3(0,10.28,z),26)
	# Portal, stage apron and side wing flats frame the existing live screen.
	box(Vector3(0,1.12,-2.5),Vector3(25.4,0.24,0.45),"b8a38d")
	for side in [-1,1]:
		for i in 3:box(Vector3(side*(8.4+i*1.7),4.4,-12+i*1.4),Vector3(0.28,6.1,1.2),"8d7b93")
		box(Vector3(side*7.1,4.45,-11.6),Vector3(0.3,6.3,0.35),"acaaa1")
		box(Vector3(side*10,1.5,-4),Vector3(1.2,0.6,0.7),"3e5157")
	box(Vector3(0,7.58,-11.6),Vector3(14.4,0.22,0.35),"acaaa1")
	for x in range(-12,13,2):
		beam(Vector3(x,8.5,-5.5),Vector3(x+2,9.1,-5.5),0.06,"6b7775")
		beam(Vector3(x,9.1,-5.5),Vector3(x+2,8.5,-5.5),0.06,"6b7775")
	for y in [8.5,9.1]:box(Vector3(0,y,-5.5),Vector3(28,0.07,0.07),"53676b")
	for x in [-12,-8,-4,4,8,12]:
		box(Vector3(x,8.2,-5.5),Vector3(0.42,0.45,0.65),"455b61")
		b.glow_box(o+Vector3(x,7.96,-5.4),Vector3(0.27,0.025,0.35))
	box(Vector3(0,0.025,6),Vector3(4.8,0.035,14),"938b85")
	for side in [-1,1]:
		for z in [0,3,6,10]:b.glow_box(o+Vector3(side*14.7,0.2,z),Vector3(0.11,0.1,0.3))
		text("返回门厅",Vector3(side*14.5,2.9,12.8),0.006,"c6ccb8",PI)
