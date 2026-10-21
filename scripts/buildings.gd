extends RefCounted
var world
var b
var origin: Vector3
var item: Dictionary
var w: float
var d: float
var h: float

func build(target, record: Dictionary):
	world=target;b=world.b;item=record
	origin=Vector3(item.x,float(item.floor_y),item.z) if world.layout!=null else world.surface(item.x,item.z,0.08)
	if world.layout!=null:b.venue_context=item.id
	w=item.w;d=item.d;h=item.h
	var bounds:=item.duplicate();bounds.y=origin.y;world.building_bounds.append(bounds)
	if item.type=="home":
		preload("res://scripts/home_art.gd").new().build(self)
		preload("res://scripts/venue_finishings.gd").new().build(self)
		if world.layout!=null:preload("res://scripts/bay_architecture.gd").new().interior(self)
		preload("res://scripts/venue_wayfinding.gd").new().build(self)
		if world.layout!=null:preload("res://scripts/bay_finishings.gd").new(world).venue(self)
		b.venue_context=""
		return
	if world.layout!=null:
		preload("res://scripts/bay_architecture.gd").new().shell(self)
	else:
		shell()
		preload("res://scripts/voxel_masonry.gd").plinth(self)
		preload("res://scripts/venue_envelope.gd").new().build(self)
	match item.type:
		"records": records()
		"cafe": cafe()
		"florist": florist()
		"gallery": gallery()
		"cinema": cinema()
		"pb": photobook()
		"dance": dance()
		"studio": studio()
		"theater": theater()
		"souvenir": souvenir()
		"home": home()
		"station": station()
		"visitor": visitor()
	if world.layout==null:preload("res://scripts/architecture_detail.gd").new().build(self)
	else:
		preload("res://scripts/architecture_detail.gd").new().build(self)
		preload("res://scripts/bay_architecture.gd").new().interior(self)
	preload("res://scripts/venue_detail.gd").new().build(self)
	preload("res://scripts/venue_finishings.gd").new().build(self)
	preload("res://scripts/venue_wayfinding.gd").new().build(self)
	if world.layout!=null:preload("res://scripts/bay_finishings.gd").new(world).venue(self)
	b.venue_context=""

func box(p: Vector3,s: Vector3,c: String,solid: bool=false): b.box(origin+p,s,c,solid)
func label(t: String,p: Vector3,size: float=0.014,color: String="e7dec9"): b.text3d(t,origin+p,size,color)
func action(suffix: String,p: Vector3,title: String,kind: String,data: Dictionary={}): world.interact(item.id+"_"+suffix,origin+p,title,kind,data)
func photo(n: int,p: Vector3,height: float=2.0,angle: float=0.0):
	if world.layout!=null:
		var life:Dictionary={"B01":2,"B02":1,"B09":4}
		if item.id in ["B03","B07"]:return
		if item.id in life:
			if item.id in ["B03","B07"] and n in [7,1]:return
			b.picture("res://assets/media/bay_life/life_%02d.jpg"%int(life[item.id]),origin+p,height,angle);return
		if item.id=="B05":
			b.box(origin+p,Vector3(.7,.4,.05),"d2c3a7",false,angle);b.text3d("档案 %02d"%n,origin+p+Basis(Vector3.UP,angle)*Vector3(0,0,.04),.004,"4e6b5e",angle);return
		if item.id in ["B04","B06","B08","B11","B12","B13"]:return
	var picture=b.picture("res://assets/media/portrait_%02d.jpg" % n,origin+p,height,angle)
	if item.id=="B05" and picture!=null:
		picture.set_meta("stream_ref","gallery:"+str(n-1));picture.set_meta("gallery_frame_size",picture.mesh.size)

func wall(p:Vector3,size:Vector3,tone:String,solid:bool=true):
	var base:String={"records":"c7bda6","cafe":"e2ded0","florist":"d8ddd0","gallery":"deddd1","cinema":"a3aaa5","pb":"d9d3c1","dance":"d8d5c8","studio":"adb7ae","theater":"bcc3bb","souvenir":"d6c8af","station":"d4cdb8","visitor":"d7d9c9"}.get(item.type,tone)
	preload("res://scripts/voxel_masonry.gd").panel(b,origin+p,size,base,0.65)

func shell():
	var trim:String={"records":"564333","cafe":"708c97","florist":"779688","souvenir":"82604b"}.get(item.type,"71654f")
	box(Vector3(0,-0.18,0),Vector3(w,0.36,d),"b9a17b" if item.type in ["records","cafe","home","dance"] else "d9d1bc",true)
	# Front door has a real three-metre opening; paired display windows and transom.
	var wing:float=(w-3.4)/2
	for s in [-1,1]:
		wall(Vector3(s*(w/2-wing/2),0.6,d/2),Vector3(wing,1.2,0.35),"e4dfcf",true)
		if item.type=="cafe":
			wall(Vector3(s*(w/2-wing/2),3.85,d/2),Vector3(wing,1.1,0.35),"e4dfcf",true)
			wall(Vector3(s*(w/2-wing/2),7.65,d/2),Vector3(wing,0.7,0.35),"e4dfcf",true)
			for x in [s*1.7,s*(w/2-0.15),s*(w/4+0.8)]:box(Vector3(x,5.8,d/2),Vector3(0.16,3,0.42),trim,true)
			b.glass(origin+Vector3(s*(w/2-wing/2),5.85,d/2),Vector3(wing-0.2,2.9,0.035))
		else:
			wall(Vector3(s*(w/2-wing/2),(h+3.3)/2,d/2),Vector3(wing,h-3.3,0.35),"e4dfcf",true)
		for x in [s*1.7,s*(w/2-0.15),s*(w/4+0.8)]: box(Vector3(x,2.2,d/2+0.02),Vector3(0.14,2.1,0.46),trim,true)
		if item.type in ["cafe","records","florist","souvenir"]:b.glass(origin+Vector3(s*(w/2-wing/2),2.25,d/2),Vector3(wing-0.2,1.9,0.035))
	if item.type=="cafe":
		wall(Vector3(0,7.65,d/2),Vector3(3.4,0.7,0.35),"e4dfcf",true)
	else:
		wall(Vector3(0,(h+3.3)/2,d/2),Vector3(3.4,h-3.3,0.35),"e4dfcf",true)
	if item.type=="cafe":
		for side in [-1,1]:wall(Vector3(side*(w/4+0.85),h/2,-d/2),Vector3((w-3.4)/2,h,0.4),"e4dfcf",true)
		wall(Vector3(0,5.6,-d/2),Vector3(3.4,4.8,0.4),"e4dfcf",true)
	else:wall(Vector3(0,h/2,-d/2),Vector3(w,h,0.4),"e4dfcf",true)
	for s in [-1,1]:
		if item.type=="studio":
			wall(Vector3(s*w/2,0.7,0),Vector3(0.4,1.4,d),"e4dfcf",true)
			wall(Vector3(s*w/2,3.9,0),Vector3(0.4,1.8,d),"e4dfcf",true)
			wall(Vector3(s*w/2,2.2,-1.5),Vector3(0.4,1.6,10),"e4dfcf",true)
			b.glass(origin+Vector3(s*w/2,2.2,4.8),Vector3(0.035,1.6,2.9))
		elif item.type in ["cinema","theater"]:
			wall(Vector3(s*w/2,h/2,0),Vector3(0.4,h,d),"e4dfcf",true)
		elif item.type=="cafe":
			# Real upper side windows replace the solid wall above the retained floor.
			# Three deep openings align with the front glazing; glass remains collision-safe.
			wall(Vector3(s*w/2,0.7,0),Vector3(0.35,1.4,d),"e4dfcf",true)
			wall(Vector3(s*w/2,3.8,0),Vector3(0.35,1.2,d),"e4dfcf",true)
			wall(Vector3(s*w/2,7.65,0),Vector3(0.35,0.7,d),"e4dfcf",true)
			for z in range(-int(d/2),int(d/2)+1,3):box(Vector3(s*w/2,2.3,z),Vector3(0.4,1.8,0.18),trim,true)
			for section in [[-8.0,-6.7],[-2.7,-2.0],[2.0,2.7],[6.7,8.0]]:
				wall(Vector3(s*w/2,5.85,(section[0]+section[1])/2),Vector3(0.35,2.9,section[1]-section[0]),"e4dfcf",true)
			for z in [-4.7,0.0,4.7]:
				b.glass(origin+Vector3(s*(w/2-0.04),5.85,z),Vector3(0.035,2.9,4.0))
				b.collision(origin+Vector3(s*w/2,5.85,z),Vector3(0.18,2.9,4.0))
				for edge in [-2.0,0.0,2.0]:box(Vector3(s*(w/2+0.04),5.85,z+edge),Vector3(0.46,2.98,0.12),trim)
				for y in [4.4,6.6,7.3]:box(Vector3(s*(w/2+0.04),y,z),Vector3(0.46,0.12,4.12),trim)
				box(Vector3(s*(w/2+0.16),4.35,z),Vector3(0.64,0.13,4.28),"b5aa8f")
		else:
			wall(Vector3(s*w/2,0.7,0),Vector3(0.35,1.4,d),"e4dfcf",true)
			wall(Vector3(s*w/2,(h+3.2)/2,0),Vector3(0.35,h-3.2,d),"e4dfcf",true)
			for z in range(-int(d/2),int(d/2)+1,3): box(Vector3(s*w/2,2.3,z),Vector3(0.4,1.8,0.18),"7f7059",true)
		box(Vector3(s*(w/2+0.12),1.3,0),Vector3(0.65,0.17,d+0.3),"c1b292")
		box(Vector3(s*(w/2+0.2),0.08,0),Vector3(0.65,0.16,d+1),"aaa18c")
	# Substantial voxel roof variants; not one identical lid for every venue.
	if item.roof=="gable":
		preload("res://scripts/architecture_detail.gd").new().roof(b,origin+Vector3(0,h,0),w+2,d+2,2.4 if item.type!="souvenir" else 1.5,{"records":"574f48","cafe":"627e91","florist":"76948b","souvenir":"8c725b"}.get(item.type,"5b7374"),item.type=="florist")
	elif item.roof=="folded":
		for j in [-1,0,1]:preload("res://scripts/architecture_detail.gd").new().roof(b,origin+Vector3(j*11.5,h+(0.65 if j==0 else 0.0),0),12.2,d+2.4,1.75,"596b72",true)
	elif item.type=="gallery":
		# The two existing roof monitors become real clerestories over open ceiling wells.
		var half_x:float=(w+1.4)/2;var half_z:float=(d+1.4)/2
		box(Vector3(0,h,(-half_z-4.75)/2),Vector3(w+1.4,0.3,half_z-4.75),"607a79",true)
		box(Vector3(0,h,(half_z+2.75)/2),Vector3(w+1.4,0.3,half_z-2.75),"607a79",true)
		box(Vector3(0,h,-1),Vector3(4.0,0.3,7.5),"607a79",true)
		for side in [-1,1]:
			box(Vector3(side*(half_x+8.4)/2,h,-1),Vector3(half_x-8.4,0.3,7.5),"607a79",true)
			box(Vector3(side*half_x,h,0),Vector3(0.17,0.45,d+1.4),"bac2b2")
			box(Vector3(0,h,side*half_z),Vector3(w+1.4,0.45,0.17),"bac2b2")
	else:
		box(Vector3(0,h,0),Vector3(w+1.4,0.5,d+1.4),"607a79")
		box(Vector3(0,h+0.35,0),Vector3(w-2,0.25,d-2),"728984")
	if item.type!="gallery":box(Vector3(0,h-0.08,0),Vector3(w,0.12,d),"e7deca",true)
	var sign_y:float=7.65 if item.type=="cafe" else 3.6
	if item.type!="station":
		box(Vector3(0,sign_y,d/2+0.28),Vector3(minf(w-1,maxf(3.6,item.name.length()*0.58+0.6)),0.65,0.24),trim if item.type in ["records","florist","souvenir"] else "395b5b")
		label(item.name,Vector3(0,sign_y,d/2+0.42),0.0105)
		for side in [-1,1]:box(Vector3(side*1.35,sign_y,d/2+0.06),Vector3(0.14,0.85,0.28),trim)
	for s in [-1,1]: b.planter(origin+Vector3(s*(w/2-1.4),0,d/2+1.3),2.3)
	if item.type not in ["records","cafe","florist","souvenir","station"]:
		box(Vector3(0,3.0,d/2+1),Vector3(4.5,0.13,2.4),"a98c67")
		for s in [-1,1]: box(Vector3(s*2.05,1.5,d/2+1.8),Vector3(0.14,3,0.14),"866e51")
	# Ceiling fixtures are geometry, with one modest actual local light per interior.
	for x in [-w/4,w/4]:
		box(Vector3(x,h-0.3,0),Vector3(1.1,0.18,0.6),"f0dcaa")
	var light:=OmniLight3D.new()
	light.position=origin+Vector3(0,h-1,0)
	light.light_color=Color("fff0cd")
	light.light_energy=0.18 if item.type in ["cinema","theater"] else 0.7
	light.omni_range=maxf(w,d)*0.7
	light.shadow_enabled=false
	world.add_child(light)
	box(Vector3(w/2-1,0.8,d/2+2),Vector3(0.5,1.6,0.5),"445f5d")
	label("入口",Vector3(0,2.7,d/2+0.3),0.008,"d9d0b9")
	action("enter",Vector3(0,0,d/2+1.5),"走进 · "+item.name,"enter",{"building":item.id})

func records():
	preload("res://scripts/records_art.gd").new().build(self)
	photo(6,Vector3(-5,3.4,-6.15),2)
	photo(7,Vector3(5,3.4,-6.15),2)
	box(Vector3(0,1.0,-3.8),Vector3(3.4,0.2,1.3),"8e7157",true)
	box(Vector3(0,1.2,-3.8),Vector3(0.9,0.16,0.65),"263e44")
	label("听一段音乐",Vector3(0,4.62,-6.05),0.0068,"425a58")
	label("原创演示音轨 · 素材说明请在试听台查看",Vector3(0,2.66,-5.97),0.003,"5a7063")
	action("listen",Vector3(0,0,-2.4),"唱片试听 · 落日未眠","audio",{})
	action("cover",Vector3(5,0,-3.5),"演示画作 · 查看与收藏","photo",{"index":6})

func cafe():
	b.venue_context="B02"
	# 0120 espresso equipment occupies this service bay; keep the east stair clear.
	for x in [-5,-1.9]:
		for z in [1,5]:
			b.table(origin+Vector3(x,0,z))
			b.bench(origin+Vector3(x,0,z+1.15),PI)
			box(Vector3(x,1.08,z),Vector3(0.18,0.24,0.18),"eee4cb")
	# Upstairs is walkable by a gentle stair-ramp along the east side.
	box(Vector3(-1.6,3.65,0),Vector3(w-4,0.25,d),"aa906c",true)
	var ramp:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new();shape.size=Vector3(2.6,0.25,12.5)
	collision.shape=shape;ramp.add_child(collision);world.add_child(ramp)
	ramp.position=origin+Vector3(6,1.8,0)
	ramp.rotation.x=-atan2(3.65,12.0)
	for i in 24:
		var yy:=i*3.65/24
		box(Vector3(6,yy,-6+i*0.5),Vector3(2.6,0.18,0.53),"c4b08a")
	if world.layout!=null:
		var guards=preload("res://scripts/bay_guardrails.gd").new(world)
		guards.pad(origin,Vector2(w,d),false)
		guards.pad(origin+Vector3(-1.6,3.8,0),Vector2(w-4,d))
		guards.pad(origin+Vector3(6,3.8,6.4),Vector2(4.2,2))
		guards.pad(origin+Vector3(-2,3.8,10),Vector2(12,4))
		guards.span(origin+Vector3(6,.1,-6),origin+Vector3(6,3.8,6),2.6)
		# The enclosing walls cover the other perimeter; the union preserves the true stair opening.
		guards.build("cafe_floor_and_stair",true)
	# Ramp rises to the south; connecting top landing spans the stair opening.
	box(Vector3(6,3.65,6.4),Vector3(4.2,0.25,2),"aa906c",true)
	for x in [-5,0]:
		b.table(origin+Vector3(x,3.8,4.2))
		b.bench(origin+Vector3(x,3.8,2.8))
	photo(4,Vector3(-4,5.5,-7.75),2.4)
	box(Vector3(-2,3.65,10),Vector3(12,0.3,4),"ba9b73",true)
	for x in [-8,4]:box(Vector3(x,4.8,10),Vector3(0.13,0.14,4),"74877d")
	box(Vector3(-2,4.8,12),Vector3(12,0.14,0.13),"74877d")
	for x in range(-8,5):box(Vector3(x,4.28,12),Vector3(0.09,1.0,0.09),"74877d")
	for x in [-8,4]:
		for z in [8,9,10,11]:box(Vector3(x,4.28,z),Vector3(0.09,1.0,0.09),"74877d")
	b.collision(origin+Vector3(-2,4.3,12),Vector3(12,1.3,0.15))
	for x in [-8,4]:b.collision(origin+Vector3(x,4.3,10),Vector3(0.15,1.3,4))
	for x in [-6,2]:box(Vector3(x,1.8,11),Vector3(0.35,3.6,0.35),"7f745d",true)
	action("sea",Vector3(-4,3.8,10),"露台休息 · 坐下看海","sit",{"seat":origin+Vector3(-6,3.82,10.3),"yaw":PI})
	action("card",Vector3(-4,3.8,-5.3),"海的明信片","photo",{"index":3})
	action("listen",Vector3(-4,3.8,-1.3),"窗边听歌 · 选择本地曲目","audio",{})
	b.venue_context=""

func florist():
	b.table(origin+Vector3(-3,0,-2),3)
	for z in [-2.5,0,2.5]:
		b.planter(origin+Vector3(4,0,z),2.2,["cbb0ce","edcea3","b9c49a"][int(z+3)%3])
	# Low flower stands and supported pots are built by architecture_detail.
	for i in 3:
		var floor_position:Vector3=[Vector3(-5.2,0,0.8),Vector3(-0.7,0,-2.3),Vector3(2,0,-2.3)][i]
		b.planter(origin+floor_position,1.2,["b6a0c7","d6bc8c","adbb91"][i])
	photo(3,Vector3(0,2.8,-4.7),1.3)
	action("flowers",Vector3(0,0,0),"原创花束 · 选一束带回小屋","flowers",{})
	# Framed conservatory, plants and its clear central aisle are in architecture_detail.

func gallery():
	# Two offset, double-sided exhibition walls; central route remains over 3 m wide.
	for x in [-5.5,5.5]:box(Vector3(x,1.85,-0.5 if x<0 else 1.8),Vector3(7,3.7,0.35),"ddd9cd",true)
	for idx in 4:
		var x:float=-8.1+idx*5.4
		photo(idx+1,Vector3(x,2.65,-7.73),2.7)
		action("art"+str(idx),Vector3(x,0,-5.35),"展品 %02d · 来源与收藏" % (idx+1),"photo",{"index":idx})
	var layouts:=[[5,-7.3,-0.29,0.0],[6,-3.7,-0.29,0.0],[7,-7.3,-0.71,PI],[8,-3.7,-0.71,PI],[9,3.7,2.01,0.0],[10,7.3,2.01,0.0],[11,3.7,1.59,PI],[12,7.3,1.59,PI]]
	for entry in layouts:
		var n:int=entry[0];var angle:float=entry[3]
		photo(n,Vector3(entry[1],2.4,entry[2]),1.85 if n==9 else 2.3,angle)
		action("art"+str(n-1),Vector3(entry[1],0,entry[2]+(2 if angle==0 else -2)),"展品 %02d · 来源与收藏" % n,"photo",{"index":n-1})
	b.bench(origin+Vector3(-5,0,4.5))
	box(Vector3(8,0.55,5.5),Vector3(2.8,1.1,1.0),"b3a187",true)
	label("光 落 下 的 瞬 间",Vector3(0,4.7,-7.74),0.018,"4d6662")
	action("exhibition",Vector3(0,0,4.8),"浏览精选照片 · 12 件","gallery",{})

func screen(pos: Vector3,width: float):
	box(pos+Vector3(0,0,-0.15),Vector3(width+0.6,width*9/16+0.5,0.2),"203237")
	var m:=MeshInstance3D.new();var q:=QuadMesh.new();q.size=Vector2(width,width*9/16);m.mesh=q
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("192b30");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.material_override=mat
	world.add_child(m);m.position=origin+pos;world.screens[item.id]=m

func cinema():
	# Enclosed, dark auditorium behind the brighter lobby; side exits stay clear.
	box(Vector3(0,0.04,-2),Vector3(w-0.5,0.08,17.3),"31353d")
	box(Vector3(0,h-0.18,-2),Vector3(w-0.5,0.12,17.4),"222c33")
	box(Vector3(0,h/2,-d/2+0.24),Vector3(w-0.5,h-0.2,0.08),"293840")
	for side in [-1,1]:
		box(Vector3(side*(w/2-0.24),h/2,-2),Vector3(0.08,h-0.2,17.3),"343643")
		for z in [-9,-6,-3,0,3]:
			box(Vector3(side*(w/2-0.32),3.1,z),Vector3(0.12,4.6,1.7),"46404e")
			box(Vector3(side*11.7,0.18,z),Vector3(0.10,0.12,0.8),"baa57c")
		box(Vector3(side*12.0,2.6,5.5),Vector3(1.1,0.42,0.08),"435259")
		b.text3d("出口",origin+Vector3(side*12.0,2.6,5.451),0.005,"afd2b4",PI)
	box(Vector3(0,4.3,d/2+2.2),Vector3(18,0.32,4.3),"43545b")
	# The facade title and programme caption remain; the oversized overlapping slogan is retired.
	box(Vector3(0,1.5,6),Vector3(w-6,3,0.4),"435259",true)
	label("星幕放映室",Vector3(0,2.70,6.27),0.0065)
	box(Vector3(-9,0.65,9),Vector3(5,1.3,1.2),"9d7f62",true)
	photo(4,Vector3(8,2.4,11.22),2,PI)
	screen(Vector3(0,4,-10.85),10)
	for row in 6:
		var level:float=(5-row)*0.24
		box(Vector3(0,level/2,3-row*1.65),Vector3(17,maxf(level,0.04),1.68),"42464f",true)
		for col in 8:
			var p:=Vector3(-7+col*2,level,3-row*1.65)
			preload("res://scripts/venue_detail.gd").auditorium_seat(b,origin+p,"786d80")
	for x in [-10,10]:
		var ramp:=StaticBody3D.new();var cs:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(2.4,0.16,10.0);cs.shape=shape;ramp.add_child(cs);world.add_child(ramp);ramp.position=origin+Vector3(x,0.6,-1);ramp.rotation.x=-atan2(1.2,10)
		for j in 20:box(Vector3(x,j*0.06,-6+j*0.5),Vector3(2.4,0.08,0.51),"b3a98f")
	# Side entrance ramps reach a proper landing before turning toward the raised aisles.
	for side in [-1,1]:
		box(Vector3(side*11.3,0.6,3.75),Vector3(4.4,1.2,2.5),"b3a98f",true)
		b.ramp(origin+Vector3(side*12.25,0.06,9.5),origin+Vector3(side*12.25,1.2,4.98),2.3,"b3a98f")
	action("show",Vector3(0,0,8.7),"影院节目册 · 影视剪辑与 MV","video",{"screen":"B06"})
	action("seat",Vector3(10,0,1),"进入影院观看位","video",{"screen":"B06"})

func photobook():
	for x in [-8,-4,0,4,8]: b.shelf(origin+Vector3(x,0,-7.9),2.6)
	b.table(origin+Vector3(0,0,0),5)
	box(Vector3(0,1.04,0),Vector3(1.0,0.08,0.75),"b6a1c4")
	for x in [-7,7]:b.bench(origin+Vector3(x,0,4))
	photo(3,Vector3(-8,3.9,-8.7),2.2)
	photo(1,Vector3(8,3.9,-8.7),2.2)
	label("拾 光 / PHOTO BOOK",Vector3(0,4.5,-8.7),0.021,"4a625e")
	action("read",Vector3(0,0,1.8),"翻开 · 拾光纪念册","pb",{})

func dance():
	box(Vector3(0,2.4,-7.12),Vector3(13,3.6,0.12),"9bacac")
	label("练 习 / MOVE WITH THE LIGHT",Vector3(0,4.8,-7.08),0.015,"48625f")
	for x in [-8,8]:
		box(Vector3(x,1.1,-1),Vector3(0.15,0.15,8),"a78a62")
		for z in [-4,2]:box(Vector3(x,0.6,z),Vector3(0.12,1.2,0.12),"697c79")
		box(Vector3(x,0.7,5),Vector3(1,1.4,0.8),"2f4348")
	photo(6,Vector3(-7,2.9,7.26),2.5,PI)
	screen(Vector3(0,2.6,-6.9),4.5)
	b.bench(origin+Vector3(5,0,5.8))
	action("dance",Vector3(0,0,-3.8),"演示画作与节目 · 排练灯光","dance",{"screen":"B08"})
	venue_lighting(Vector3(0,4.8,-1),9)
	for x in [-7,-5,-3]:
		box(Vector3(x,1.2,6.5),Vector3(1.7,2.4,0.6),"9baca7",true)
		box(Vector3(x+0.5,1.1,6.15),Vector3(0.08,0.3,0.06),"4d6263")

func venue_lighting(center: Vector3,span: float):
	var lights:Array=[]
	for side in [-1,1]:
		var light:=SpotLight3D.new();world.add_child(light)
		light.position=origin+center+Vector3(side*span/2,0,0)
		light.look_at(origin+Vector3(side*span/4,0,center.z-2))
		light.spot_range=18;light.spot_angle=48;light.shadow_enabled=false
		lights.append(light)
	world.venue_lights[item.id]=lights
	world.set_venue_lighting(item.id,0)

func studio():
	for x in [-5,-3,3,5]:
		box(Vector3(x,2,-6.1),Vector3(1.4,3,0.3),"687276")
		for i in 7:box(Vector3(x-0.6+i*0.2,2,-5.9),Vector3(0.06,2.7,0.1),"87908a")
	b.table(origin+Vector3(-4,0,-1),3)
	box(Vector3(-4,1.08,-1),Vector3(2.2,0.16,0.8),"3e5357")
	for i in 7:box(Vector3(-4.8+i*0.24,1.21,-0.9),Vector3(0.07,0.07,0.1),"b8d2c3")
	box(Vector3(2,0.8,-2),Vector3(0.06,1.6,0.06),"4a5757")
	box(Vector3(2,1.65,-2),Vector3(0.18,0.35,0.18),"343f44")
	box(Vector3(3.5,1.1,-2.3),Vector3(1,0.08,0.7),"a79d80")
	b.bench(origin+Vector3(4,0,3))
	label("回声 · 聆听与跟唱\n麦克风默认关闭，不录音",Vector3(3.4,4.1,-5.88),0.006,"4c625f")
	action("listen",Vector3(2,0,0),"听歌与跟唱 · 本地音轨","audio",{})

func theater():
	box(Vector3(0,0.6,-7.5),Vector3(25,1.2,10),"947766",true)
	for x in [-13,13]:box(Vector3(x,4,-10),Vector3(2,8,3),"716075")
	if world.layout==null:box(Vector3(0,8,-10),Vector3(28,0.35,0.35),"35484c")
	if world.layout==null:
		for x in [-10,-5,0,5,10]:box(Vector3(x,7.7,-9.5),Vector3(0.6,0.4,0.7),"ada3ba")
	screen(Vector3(0,4.8,-12.9),10)
	for row in 6:
		for x in [-10,-8,-6,-4,4,6,8,10]:preload("res://scripts/venue_detail.gd").auditorium_seat(b,origin+Vector3(x,0,row*1.75),"8b788d")
	for x in [-14,14]:box(Vector3(x,2,-6),Vector3(1.5,4,1.5),"293e44",true)
	label("星 光 演 艺 厅",Vector3(0,10.3,-13.6),0.023)
	action("performance",Vector3(0,0,8),"选择节目 · 进入观演","video",{"screen":"B10"})
	box(Vector3(12,0.8,8),Vector3(2.5,1.6,1.2),"48575b",true)
	for x in range(5):box(Vector3(11.1+x*0.38,1.64,8),Vector3(0.16,0.07,0.6),"c9c0ad")
	action("lights",Vector3(12,0,6),"舞台灯光 · 三种预设","venue_light",{"venue":"B10"})
	venue_lighting(Vector3(0,7.2,-4),17)

func souvenir():
	preload("res://scripts/souvenir_art.gd").new().build(self)
	box(Vector3(3,0.6,0),Vector3(2.2,1.2,1.0),"947558",true)
	label("山海纪念",Vector3(0,3.38,-5.15),0.009,"466460")
	label("同人项目原创",Vector3(0,2.86,-5.15),0.0048,"63776a")
	action("collection",Vector3(0,0,1.5),"查看纪念章与数字纪念卡","collection",{})

func home():
	b.bench(origin+Vector3(-4,0,-2),PI/2)
	b.table(origin+Vector3(-1.5,0,-2))
	b.shelf(origin+Vector3(4,0,-4.5),2.4)
	box(Vector3(-4,0.4,3),Vector3(3.2,0.8,2.0),"b5a6b7",true)
	box(Vector3(-4,0.85,2.6),Vector3(1.2,0.18,0.65),"eee4ce")
	world.home_picture=b.picture("res://assets/media/portrait_01.jpg",origin+Vector3(0,2.5,-5.2),2)
	label("我 的 海 风 小 屋",Vector3(0,3.8,-5.2),0.017,"4c625e")
	action("decorate",Vector3(1,0,-1),"布置小屋 · 花束与照片","home",{})
	action("save",Vector3(-3,0,1),"手动保存 · 海风小屋","save",{})

func station():
	for x in [-8,-4,4,8]:b.bench(origin+Vector3(x,0,-3))
	box(Vector3(-8,1.0,3),Vector3(4,2,1),"9b7c58",true)
	photo(1,Vector3(8,2.3,-6.7),2.8)
	box(Vector3(0,0,10),Vector3(27,0.2,8),"d4c9ac",true)
	action("guide",Vector3(0,0,2),"领取山海导览 · 打开地图","map",{})

func visitor():
	box(Vector3(-3,0.6,-1.4),Vector3(4,1.2,1.3),"9b7d5e",true)
	label("服 务 台\nM 导览 / Tab 收藏\n非官方同人乐园",Vector3(-4.7,2.6,-4.65),0.006,"42605b")
	b.bench(origin+Vector3(4,0,1),PI/2)
	action("map",Vector3(0,0,-1.8),"导览、目的地与来源","map",{})
