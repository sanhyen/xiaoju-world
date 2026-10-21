extends RefCounted
## Forest island, real mainland rooms and supported connections share layout data.
var w
var b
var l
var trim:="684a35"
var rng:=RandomNumberGenerator.new()
func _init(world):w=world;b=w.b;l=w.layout;rng.seed=1060618
func act(id:String,p:Vector3,title:String,topic:String):w.interact(id,p,title+" · E 查看 / F 操作","dual106",{"topic":topic})
func sign_at(p:Vector3,words:String):
	b.box(p+Vector3(0,1,0),Vector3(.14,2,.14),trim,false,0,"wood");b.box(p+Vector3(0,1.7,0),Vector3(3.8,.8,.14),"537a68",false,0,"wood");b.text3d(words,p+Vector3(0,1.7,.09),.007,"faf1d9")
func build():
	forest_paths()
	for house in l.config.island2.buildings:forest_house(house)
	forest_onsen();forest_planting();forest_stations()
	for room in l.config.theme_rooms:theme_room(room)
	w.set_meta("dual106",{"island2_land_m2":PI*float(l.config.island2.radius[0])*float(l.config.island2.radius[1]),"first_island_land_m2":PI*42*28,"nature_fraction":.75,"treehouses":4,"rooms":6,"public_boats":l.config.public_boats.size(),"light_interactions":4})

func night_lamp(p:Vector3,radius:float):
	var lamp:=OmniLight3D.new();lamp.position=p;lamp.light_color=Color("ffc58b");lamp.light_energy=0;lamp.omni_range=radius;lamp.shadow_enabled=false;lamp.set_meta("stream_ref","night");w.add_child(lamp);w.night_lights.append(lamp)

func forest_paths():
	var guards=preload("res://scripts/bay_guardrails.gd").new(w)
	for route in l.config.island2.canopy_routes:
		for i in route.points.size()-1:
			var a:Vector3=l.vector(route.points[i]);var c:Vector3=l.vector(route.points[i+1])
			b.ramp(a,c,route.width,"9a7c56");guards.span(a,c,route.width)
			var count:int=maxi(1,ceili(a.distance_to(c)/1.6));var side:=Vector3(-(c-a).z,0,(c-a).x).normalized()
			for j in count+1:
				var at:Vector3=a.lerp(c,float(j)/count)
				b.beam(at-side*route.width*.5+Vector3.UP*.018,at+side*route.width*.5+Vector3.UP*.018,.045,"745637")
			for at in [a,c]:
				var ground:float=w.height_at(at.x,at.z)-.3
				for sign in [-1,1]:
					var foot:Vector3=at+side*(route.width*.5-.15)*sign
					b.box(Vector3(foot.x,(ground+at.y)*.5,foot.z),Vector3(.26,maxf(.35,at.y-ground),.26),trim,false,0,"wood")
					if at.y-ground>1.6:b.beam(foot-Vector3.UP*1.6,at+side*sign*.35-Vector3.UP*.15,.16,trim)
			b.box(a+side*.98+Vector3.UP*1.25,Vector3(.19,.26,.19),trim,false,0,"wood");b.glow_box(a+side*.98+Vector3.UP*1.25,Vector3(.13,.18,.14))
	for h in l.config.island2.buildings:
		if not h.treehouse:continue
		var p:Vector3=l.vector(h.center);var porch:Vector3=p+Vector3(0,0,4.5)
		guards.pad(p,Vector2(h.size[0],h.size[1]),false);guards.pad(porch,Vector2(8.6,2.4))
		b.box(porch-Vector3.UP*.14,Vector3(8.6,.28,2.4),"a88a61",true,0,"wood")
		b.ramp(p+Vector3(0,0,4.5),p+Vector3(0,0,6),2.4,"a88a61");guards.span(p+Vector3(0,0,4.5),p+Vector3(0,0,6),2.4)
	# Ground-loop crossings are real openings, including the foot of both access ramps.
	for road in l.config.roads:
		if not str(road.id).begins_with("forest106"):continue
		for i in road.points.size()-1:guards.span(l.vector(road.points[i]),l.vector(road.points[i+1]),road.width,false)
	guards.build("forest_canopy",true)
	for point in [[-60,2.4,461],[-9,3.3,490],[-65,5.3,517]]:sign_at(l.vector(point)+Vector3(-3,0,0),"森屿地面环路 ↔ 双车可行\n树冠、树屋与温泉请步行")

func shell(p:Vector3,width:float,depth:float,height:float,tone:String,roof:String):
	b.box(p-Vector3.UP*.18,Vector3(width+.2,.36,depth+.2),"b59a72",true,0,"wood")
	for side in [-1,1]:
		var wing:float=(width-3.2)*.5;var x:float=side*(width+3.2)*.25
		b.box(p+Vector3(x,.55,depth*.5),Vector3(wing,1.1,.32),tone,true,0,"plaster")
		b.box(p+Vector3(x,height-.4,depth*.5),Vector3(wing,.8,.32),tone,true,0,"plaster")
		b.glass(p+Vector3(x,2.05,depth*.5-.11),Vector3(wing-.18,1.75,.04));b.collision(p+Vector3(x,2.05,depth*.5),Vector3(wing,1.85,.13))
		b.box(p+Vector3(side*width*.5,.55,0),Vector3(.32,1.1,depth),tone,true,0,"plaster")
		b.box(p+Vector3(side*width*.5,height-.4,0),Vector3(.32,.8,depth),tone,true,0,"plaster")
		b.glass(p+Vector3(side*(width*.5-.1),2.05,0),Vector3(.04,1.75,depth-.2));b.collision(p+Vector3(side*width*.5,2.05,0),Vector3(.12,1.85,depth))
		for z in range(-int(depth*.5),int(depth*.5)+1,2):b.box(p+Vector3(side*(width*.5+.1),2.1,z),Vector3(.18,2,.14),trim,false,0,"wood")
		for z in [-depth*.5,depth*.5]:b.box(p+Vector3(side*width*.5,height*.5,z),Vector3(.28,height,.28),trim,true,0,"wood")
	b.box(p+Vector3(0,height*.5,-depth*.5),Vector3(width,height,.38),tone,true,0,"plaster")
	b.box(p+Vector3(0,height-.4,depth*.5),Vector3(3.2,.8,.36),trim,true,0,"wood")
	preload("res://scripts/architecture_detail.gd").new().roof(b,p+Vector3.UP*height,width+1.6,depth+1.7,1.7,roof,false)
	for side in [-1,1]:
		b.beam(p+Vector3(side*(width*.5-.2),height-.6,depth*.5),p+Vector3(side*(width*.5-.2),height,depth*.5+.7),.16,trim)
		b.glow_box(p+Vector3(side*1.85,2.65,depth*.5+.22),Vector3(.2,.32,.17))
	for x in [-width*.5,width*.5]:
		for z in [-depth*.5,depth*.5]:
			var base:float=minf(p.y-.4,w.height_at(p.x+x,p.z+z)-.15)
			b.box(Vector3(p.x+x,(base+p.y)*.5,p.z+z),Vector3(.48,maxf(.4,p.y-base),.48),trim,false,0,"wood")

func forest_house(h:Dictionary):
	var p:Vector3=l.vector(h.center);var width:float=h.size[0];var depth:float=h.size[1];b.venue_context=h.id
	load("res://scripts/architecture120.gd").new(w).forest_shell(h,p,Vector2(width,depth))
	if h.treehouse:
		var tree:Vector3=Vector3(p.x-width*.5-1.2,w.height_at(p.x-width*.5-1.2,p.z),p.z-.7)
		var trunk_h:float=maxf(12,p.y-tree.y+6.5)
		b.shape(tree+Vector3.UP*trunk_h*.5,Vector3(1.7,trunk_h,1.5),"7b6348","post");b.collision(tree+Vector3.UP*trunk_h*.5,Vector3(1.2,trunk_h,1.2))
		for z in [-2.6,2.6]:b.beam(tree+Vector3(0,trunk_h*.35,0),p+Vector3(width*.35,-.15,z),.35,"775b3d")
		for i in 9:
			var angle:float=i*2.399;var at:Vector3=tree+Vector3(cos(angle)*3.5,trunk_h-1.8+sin(i)*1.1,sin(angle)*3.3)
			b.beam(tree+Vector3.UP*(trunk_h-5),at,.32,"7b6348");b.shape(at,Vector3(5.4,3.0,4.4),["718e60","8ba572","5d815a"][i%3],"shrub",angle)
		b.box(p+Vector3(2,.3,-.5),Vector3(1.7,.6,2.9),trim,true,0,"wood");b.box(p+Vector3(2,.69,-.5),Vector3(1.66,.18,2.8),"e6dac0",false,0,"fabric");b.box(p+Vector3(2,.83,-1.2),Vector3(1.4,.12,.6),"b9c6ad",false,0,"fabric")
		w.interact(h.id+"_BED",p+Vector3(.7,0,-.4),"树屋软榻 · X 躺卧","bay_netbed",{"seat":p+Vector3(2,.45,-.5),"yaw":0})
	else:b.bench(p+Vector3(width*.28,0,-.5),PI)
	b.table(p+Vector3(-1.7,0,-.6),1.7);b.shelf(p+Vector3(-2.0 if width<7 else -2.5,0,-depth*.5+.6),2.1)
	b.box(p+Vector3(-1.7,.035,1),Vector3(2.8,.035,2.6),"a5b593",false,0,"fabric")
	preload("res://scripts/bay_finishings.gd").new(w).cushion(p+Vector3(-1.7,0,1.1),PI)
	w.interact(h.id+"_SEAT",p+Vector3(-.8,0,1.7),h.name+" · X 歇脚","sit",{"seat":p+Vector3(-1.7,.16,1.1),"yaw":PI})
	b.text3d(h.name,p+Vector3(0,3.25,depth*.5+.25),.009,"5e4232")
	night_lamp(p+Vector3(0,2.8,0),6.0)
	w.building_bounds.append({"id":h.id,"x":p.x,"z":p.z,"w":width,"d":depth,"y":p.y,"h":4.0})
	if h.id=="FOREST_OBSERVATORY":act("FOREST_STAR",p+Vector3(0,0,1.2),"星图转盘","star")
	elif h.id=="FOREST_LODGE":act("FOREST_WELCOME",p+Vector3(0,0,1.2),"森屿旅行册","welcome")
	b.venue_context=""

func forest_onsen():
	for index in l.config.island2.pools.size():
		var pool:Dictionary=l.config.island2.pools[index];var p:Vector3=l.vector(pool.center);var width:float=pool.size[0];var depth:float=pool.size[1];var bed:float=pool.depth
		b.box(p-Vector3.UP*(bed+.14),Vector3(width,.28,depth),"c8bfa8",true,0,"stone")
		# North entrance stays open and grades continuously down to the standing pool bed.
		b.ramp(p+Vector3(0,.02,-depth*.5-1.8),p+Vector3(0,-bed,-depth*.5+1.7),2.8,"c8bfa8")
		for side in [-1,1]:
			b.box(p+Vector3(side*(width*.5+.18),-.28,0),Vector3(.5,1,depth+.7),"8d9381",true,0,"stone")
			b.box(p+Vector3(side*(width*.25+1),-.28,-depth*.5-.18),Vector3(width*.5-2,1,.5),"8d9381",true,0,"stone")
		b.box(p+Vector3(0,-.28,depth*.5+.18),Vector3(width+.7,1,.5),"8d9381",true,0,"stone")
		var water:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(width,depth);water.mesh=plane;water.position=p+Vector3.UP*.025
		var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/coastal_water.gdshader");preload("res://scripts/bay_authoring.gd").new(w).set_water_curve(mat);water.material_override=mat;w.add_child(water)
		for j in 13:
			var a:float=j*TAU/13;var at:Vector3=p+Vector3(cos(a)*(width*.5+1.2),0,sin(a)*(depth*.5+1.1))
			if at.z<p.z-depth*.3 and absf(at.x-p.x)<2:continue
			at.y=w.height_at(at.x,at.z);b.shape(at+Vector3.UP*.5,Vector3(1.7,.9,1.1),["8b9283","9ba18a","b7b49e"][j%3],"rock",a)
		b.box(p+Vector3(width*.5-1,.6,-depth*.5+.1),Vector3(.16,1.2,.16),"b7a476",false,0,"wood")
		w.interact("FOREST_SOAK_"+str(index),p+Vector3(0,-bed,-depth*.2),"岩泉坐席 · X 泡汤","sit",{"seat":p+Vector3(width*.28,-bed+.12,depth*.2),"yaw":PI*.5})
	act("FOREST_VALVE",l.vector([-94,5.4,494]),"冷热水阀","valve")
	sign_at(l.vector([-98,5.4,492]),"岩石温泉 · 沿石阶入池\nF 调水 · X 泡汤，移动起身")
	var p:Vector3=l.vector([-97,5.4,491]);b.box(p-Vector3.UP*.12,Vector3(7,.24,3),"a88a61",true,0,"wood")
	preload("res://scripts/bay_authoring.gd").new(w).pergola(p+Vector3(-1,0,0),Vector2(6,3))
	b.bench(p+Vector3(-1,0,-.7));w.interact("FOREST_DRY_SEAT",p+Vector3(0,0,-.6),"温泉更衣休憩 · X","sit",{"seat":p+Vector3(-1,.12,-.7),"yaw":0})

func forest_stations():
	for i in l.config.island2.observation_points.size():
		var p:Vector3=l.vector(l.config.island2.observation_points[i]);b.box(p-Vector3.UP*.12,Vector3(5,.24,4),"a58a61",true,0,"wood");b.table(p+Vector3(-1.7,0,-.4),1.2)
		b.box(p+Vector3(-1.7,1.05,-.4),Vector3(.7,.06,.5),"ece3bf",false,0,"fabric");b.text3d("萤火观察簿",p+Vector3(-1.7,1.10,-.4),.003,"6d785a")
		night_lamp(p+Vector3(-1.8,1.25,-.8),4.5)
		act("FOREST_FIREFLY_"+str(i),p,"萤火观察点 "+str(i+1),"firefly_"+str(i))
		var nearest:Vector3=l.nearest_route(p)
		if p.distance_to(nearest)<35:b.ramp(nearest,p,2.4,"b8aa87")
	var mail:Vector3=l.vector([-30,10.2,487]);b.box(mail+Vector3(0,.5,.9),Vector3(.12,1,.12),trim,false,0,"wood");b.box(mail+Vector3(0,1.15,.9),Vector3(.8,.65,.45),"769780",false,0,"wood");b.box(mail+Vector3(0,1.3,1.14),Vector3(.42,.08,.02),"493d30");act("FOREST_POSTCARD",mail,"树冠寄信","mail")
	for i in 12:
		var angle:float=i*TAU/12;var at:Vector3=l.vector([-60+cos(angle)*61,-.65,490+sin(angle)*41])
		b.shape(at+Vector3.UP*.08,Vector3(.35,.18,.28),"d1bf94","rock",angle)
		if i%3==0:act("FOREST_BEACH_"+str(i),at,"浅岸拾光","shore_"+str(i))

func forest_planting():
	var count:=0;var planted:Array=[]
	for i in 420:
		var q:=Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))
		if q.length()>.86:continue
		var p:Vector3=w.surface(-60+q.x*58,490+q.y*38)
		if not w.clear_of_paths(Vector2(p.x,p.z),2.8):continue
		var near_house:=false
		for h in l.config.island2.buildings:
			if absf(p.x-h.center[0])<h.size[0]*.5+3 and absf(p.z-h.center[2])<h.size[1]*.5+4:near_house=true
		for pool in l.config.island2.pools:
			if absf(p.x-pool.center[0])<pool.size[0]*.5+3 and absf(p.z-pool.center[2])<pool.size[1]*.5+3:near_house=true
		if near_house or planted.any(func(q):return p.distance_to(q)<3.0):continue
		planted.append(p)
		var height:float=rng.randf_range(6,11);b.shape(p+Vector3.UP*height*.5,Vector3(.42,height,.42),"786449","post");b.collision(p+Vector3.UP*height*.5,Vector3(.32,height,.32))
		for j in 6:
			var angle:float=j*2.399+i*.2;var at:Vector3=p+Vector3(cos(angle)*1.7,height-.5+sin(j)*1.3,sin(angle)*1.7)
			b.beam(p+Vector3.UP*(height-2.4),at,.15,"786449");b.shape(at,Vector3(3.7,2.6,3.3),["769b67","8ba576","5e895f","9db57d"][i%4],"shrub",angle)
		count+=1
		if count>=74:break
	for i in 330:
		var a:float=rng.randf()*TAU;var r:float=sqrt(rng.randf())*.88;var p:Vector3=w.surface(-60+cos(a)*58*r,490+sin(a)*38*r)
		if not w.clear_of_paths(Vector2(p.x,p.z),.65):continue
		var excluded:=false
		for h in l.config.island2.buildings:
			if absf(p.x-h.center[0])<h.size[0]*.5+1.6 and absf(p.z-h.center[2])<h.size[1]*.5+3:excluded=true
		for pool in l.config.island2.pools:
			if absf(p.x-pool.center[0])<pool.size[0]*.5+2 and absf(p.z-pool.center[2])<pool.size[1]*.5+2:excluded=true
		if excluded:continue
		b.shape(p+Vector3.UP*.35,Vector3(1.4,.7,1.2),["8b9e6a","6e945e","a0b27d"][i%3],"shrub",a)
		if i%5==0:b.shape(p+Vector3(.2,.74,.1),Vector3(.45,.26,.4),["f3e9cc","bca2cb","ecc4c0"][i%3],"flower",a)
	for i in 25:
		var a:float=i*2.399;var p:Vector3=w.surface(-60+cos(a)*49,490+sin(a)*32)
		if not w.clear_of_paths(Vector2(p.x,p.z),2):continue
		b.shape(p+Vector3.UP*.6,Vector3(2.5,1.2,1.8),["87917e","a3a58e","c0b79b"][i%3],"rock",a)
	w.set_meta("forest106_trees",count)

func theme_room(room:Dictionary):
	var p:Vector3=l.vector(room.center);var art=load("res://scripts/architecture120.gd").new(w);var size:Vector2=art.room_local_size(room);var width:float=size.x;var depth:float=size.y;b.venue_context=room.id
	var mark:Dictionary=art.capture();var frame:Dictionary=art.theme_shell(room,p,size)
	b.box(p+Vector3(0,.025,0),Vector3(width*.62,.045,depth*.56),room.tone,false,0,"fabric")
	b.text3d(room.name+" · "+room.work,p+Vector3(0,3.8,depth*.5+.28),.011,"5b604b")
	b.box(p+Vector3(0,2.6,-depth*.5+.25),Vector3(5.2,3.1,.18),trim,true,0,"wood")
	var screen:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(4.7,2.65);screen.mesh=mesh;screen.position=p+Vector3(0,2.6,-depth*.5+.37);var mat:=StandardMaterial3D.new();mat.albedo_color=Color("e1d6b9");mat.roughness=.9
	var poster:String="res://assets/media/dual106/"+str(room.program).trim_prefix("dual_")+".jpg"
	if ResourceLoader.exists(poster):mat.albedo_texture=load(poster)
	screen.material_override=mat;screen.set_meta("stream_ref","screen:"+room.id);w.add_child(screen);w.screens[room.id]=screen
	act(room.id+"_PROGRAM",p+Vector3(0,0,depth*.5-1.5),room.name,"room_"+room.id.trim_prefix("THEME_").to_lower())
	var work:Vector3=p+art.room_work_offset(room)
	preload("res://scripts/bay_finishings.gd").new(w).cushion(p+Vector3(width*.3,0,depth*.16),PI*.5)
	w.interact(room.id+"_SEAT",p+Vector3(width*.22,0,depth*.3),"主题窗边沙发 · X","sit",{"seat":p+Vector3(width*.3,.16,depth*.16),"yaw":PI*.5})
	match str(room.id):
		"THEME_EVERYDAY":
			b.box(work+Vector3.UP*1.16,Vector3(1.8,.17,1.1),"56645b",false,0,"wood")
			act("THEME_RECORD_PRESS",work+Vector3(0,0,1.7),"换唱片与旅行封套","record")
		"THEME_WAITING":
			b.box(work+Vector3.UP*1.14,Vector3(2.4,.10,1.5),"8d9990",false,0,"stone")
			for i in 3:
				var at:Vector3=p+Vector3(width*.32,0,-2+i*1.6);b.box(at+Vector3.UP*.85,Vector3(.12,1.7,.12),trim,false,0,"wood");b.glow_box(at+Vector3.UP*1.78,Vector3(.25,.22,.25))
			act("THEME_STREET_DIARY",work+Vector3(0,0,1.7),"街灯门牌与桌面小街景","street")
		"THEME_POEM":
			for i in 6:b.box(work+Vector3(-.8+i*.3,1.12,0),Vector3(.25,.045,.5),["b5bdc7","d3bba6","bfc8ad"][i%3],false,0,"fabric")
			for j in 9:
				var a:float=j*2.399;b.glow_box(p+Vector3(cos(a)*3.6,3+sin(j)*.35,-depth*.25+sin(a)*.5),Vector3(.10,.10,.10))
			act("THEME_POETRY_DESK",work+Vector3(0,0,1.7),"星灯照片与手札拼贴","journal")
		"THEME_FROST":
			b.box(p+Vector3(0,.18,-1.2),Vector3(width*.65,.36,5.2),"8d9da7",true,0,"wood");b.ramp(p+Vector3(0,0,2.7),p+Vector3(0,.36,1.3),3,"b6c6cd")
			for side in [-1,1]:
				b.box(p+Vector3(side*3.8,2.0,-2.5),Vector3(.2,4,.2),"7f8c95",true,0,"metal");b.beam(p+Vector3(side*3.8,3.8,-2.5),p+Vector3(0,4,-2.5),.18,"7f8c95")
			for i in 4:act("THEME_FROST_PAD_"+str(i),p+Vector3(-2.5+i*1.7,.36,.5),"霜月踏灯 "+str(i+1),"beat_"+str(i))
			act("THEME_FROST_LIGHT",p+Vector3(4.7,0,2),"舞台灯架与垂幕","frost_light")
		"THEME_BLOSSOM":
			for side in [-1,1]:
				b.box(p+Vector3(side*3,1.4,.5),Vector3(.17,2.8,.17),trim,true,0,"wood");b.beam(p+Vector3(side*3,2.8,.5),p+Vector3(0,3.4,.5),.16,trim)
			for i in 3:
				var at:Vector3=p+Vector3(-4+i*4,0,-2.1);b.table(at,1.1);b.shape(at+Vector3.UP*1.1,Vector3(.3,.22,.3),["b8a275","d7adbd","a6bca3"][i],"pot");act("THEME_FLOWER_CLUE_"+str(i),at+Vector3(0,0,1.2),"花纹线索 "+str(i+1),"clue_"+str(i))
		"THEME_DAILY":
			for side in [-1,1]:
				b.box(p+Vector3(side*3.7,1.8,-1.0),Vector3(.10,3.6,.10),trim,true,0,"wood");b.box(p+Vector3(side*3.7,3.55,-1.0),Vector3(1.1,.65,.12),"e6dfc8",false,0,"fabric")
			b.box(p+Vector3(3.6,1.8,-2.8),Vector3(3.6,3.3,.06),"d7cfae",false,0,"fabric")
			b.beam(p+Vector3(-2,2.5,-depth*.5+.5),p+Vector3(2,2.5,-depth*.5+.5),.025,trim)
			act("THEME_DARKROOM",work+Vector3(0,0,1.7),"照片冲印与晾片","print")
	for i in 3:
		var at:Vector3=p+Vector3(-width*.5+.8,0,-depth*.35+i*depth*.35)
		if room.id=="THEME_EVERYDAY":at=p+Vector3(-width*.39,0,-depth*.22+i*depth*.22)
		b.shape(at+Vector3.UP*.3,Vector3(.7,.6,.7),"aa936b","pot");b.shape(at+Vector3.UP*.9,Vector3(1,1.2,.9),"819a69","shrub")
	var yaw:float=art.room_yaw(room);art.rotate_capture(mark,p,yaw)
	art.flush_entry(p,3.2,depth,yaw,room.id,3.6)
	w.building_bounds.append({"id":room.id,"x":p.x,"z":p.z,"w":float(room.size[0]),"d":float(room.size[1]),"y":p.y,"h":frame.height+(3.6 if room.id=="THEME_POEM" else 1.6)})
	art.record(room.id,{"THEME_EVERYDAY":"radial_record_pavilion","THEME_WAITING":"L_waiting_rain_gallery","THEME_POEM":"tall_bookhouse_roof_terrace","THEME_FROST":"open_stage_lighting_gallery","THEME_BLOSSOM":"double_flower_courtyards","THEME_DAILY":"daylight_photo_darkroom"}.get(str(room.id),str(room.id)),p,Vector2(room.size[0],room.size[1]),art.room_point(room,Vector3(0,0,depth*.5),float(l.config.sea_y)),frame.levels)
	var frames:Dictionary=w.get_meta("theme_room_frames110",{});frames[room.id]={"origin":p,"yaw":yaw,"local_size":size,"world_size":Vector2(room.size[0],room.size[1]),"height":frame.height,"levels":frame.levels,"work":art.room_work(room,float(l.config.sea_y))};w.set_meta("theme_room_frames110",frames)
	b.venue_context=""
