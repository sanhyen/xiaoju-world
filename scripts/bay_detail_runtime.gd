extends Node3D
## Actual moving landmark, physical books, film/stage effects and persistent discovery loop.
var m
var clock:=0.0
var beacon:Node3D
var beam:SpotLight3D
var clock_hands:Array=[]
var books:Array=[]
var book_page:=-1
var disc:Node3D
var stars:MultiMeshInstance3D
var mist:MultiMeshInstance3D
var wish_until:=0.0
var last_chime:=-1
var projector:Node3D
var fire:MultiMeshInstance3D
var seasonal_paintings:Array=[]
var stage_rack:Node3D
var shadow_tick:=0.0
var foot_puffs:MultiMeshInstance3D
var footprints:Array=[]
var last_foot:=0.0

func setup(target):
	m=target
	var p:Vector3=m.world.layout.vector([360,21,383])
	beacon=Node3D.new();beacon.name="RotatingLighthouse";add_child(beacon);beacon.position=p
	beam=SpotLight3D.new();beam.light_color=Color("ffe7b9");beam.light_energy=1.3;beam.spot_range=210;beam.spot_angle=9;beam.shadow_enabled=false;beacon.add_child(beam)
	cone(beacon,Vector3(0,0,-40),80,4,.055)
	var v:Dictionary=m.world.layout.venues.B01
	for i in 2:
		var pivot:=Node3D.new();add_child(pivot);pivot.position=Vector3(v.x-v.w*.5-2,v.floor_y+8.28,v.z+2.16)
		m.bay.add_block(pivot,Vector3(0,.39 if i==0 else .56,0),Vector3(.1,.8 if i==0 else 1.15,.07),"5e4232");clock_hands.append(pivot)
	v=m.world.layout.venues.B03;disc=Node3D.new();add_child(disc);disc.position=Vector3(v.x,v.floor_y+1.32,v.z-3.8)
	var vinyl:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.37;cylinder.bottom_radius=.37;cylinder.height=.025;cylinder.radial_segments=32;vinyl.mesh=cylinder
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("253735");mat.roughness=.3;vinyl.material_override=mat;disc.add_child(vinyl)
	m.bay.add_block(disc,Vector3(.16,.027,0),Vector3(.12,.015,.07),"e6d6ae")
	v=m.world.layout.venues.B07;make_book(Vector3(v.x,v.floor_y+1.13,v.z))
	var attic:Dictionary=m.world.layout.config.annexes.B07;make_book(m.world.layout.vector(attic.center)+Vector3(1.5,4.89,1))
	stars=instances("StageStarRain",40,"edc98a",Vector3(.055,.055,.055),false)
	mist=instances("StageMist",12,"d6d9e0",Vector3(1,1,1),true)
	fire=instances("HomeFireGlow",8,"e8b171",Vector3(.10,.22,.08),false)
	projector=Node3D.new();projector.name="MovieProjectorLight";add_child(projector);cone(projector,Vector3(0,0,-8),16,2.7,.035)
	var gallery:Dictionary=m.world.layout.venues.B05
	for i in 2:
		var picture:=MeshInstance3D.new();var canvas:=QuadMesh.new();canvas.size=Vector2(2.6,1.7);picture.mesh=canvas
		var art:=ShaderMaterial.new();art.shader=load("res://assets/materials/gallery_seasons_bay.gdshader");art.set_shader_parameter("composition",float(i));picture.material_override=art
		picture.position=Vector3(gallery.x-6+i*12,gallery.floor_y+2.6,gallery.z-7.70);add_child(picture);seasonal_paintings.append(picture)
	stage_rack=Node3D.new();add_child(stage_rack);m.bay.add_block(stage_rack,Vector3.ZERO,Vector3(24,.22,.22),"4a5d6b")
	for x in [-10,-5,0,5,10]:m.bay.add_block(stage_rack,Vector3(x,-.3,0),Vector3(.55,.4,.65),"b8b3a3")
	foot_puffs=instances("FootDustAndSplash",12,"ffffff",Vector3(.09,.06,.09),true);foot_puffs.material_override.albedo_color=Color(1,1,1,.36)
	for i in 12:foot_puffs.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
	set_season(int(m.state.get("gallery_preset",0)));refresh_book()

func set_season(index:int):
	for painting in seasonal_paintings:painting.material_override.set_shader_parameter("season",clampi(index,0,3))

func cone(parent:Node3D,p:Vector3,length:float,radius:float,alpha:float):
	var node:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=0;mesh.bottom_radius=radius;mesh.height=length;mesh.radial_segments=16;node.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(1,.88,.65,alpha);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=mat;node.position=p;node.rotation.x=PI*.5;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)

func instances(title:String,count:int,tone:String,size:Vector3,transparent:bool)->MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new();node.name=title;var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	var mesh:=BoxMesh.new();mesh.size=size;mm.mesh=mesh;mm.instance_count=count;node.multimesh=mm
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(tone);mat.vertex_color_use_as_albedo=true
	if transparent:mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color.a=.09
	else:mat.emission_enabled=true;mat.emission=Color(tone);mat.emission_energy_multiplier=.4
	node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node

func make_book(p:Vector3):
	var root:=Node3D.new();root.name="PhysicalPhotobook";root.position=p;add_child(root)
	m.bay.add_block(root,Vector3(0,-.07,0),Vector3(1.8,.12,1.2),"826553")
	var pages:Array=[]
	for side in [-1,1]:
		var page:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(.85,1.08);page.mesh=mesh;page.rotation.x=-PI*.5;page.position=Vector3(side*.45,0,0)
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color("f5ead0");mat.roughness=.9;page.material_override=mat;root.add_child(page);pages.append(page)
	books.append({"root":root,"pages":pages})

func refresh_book():
	if not m.state.has("pb_page"):return
	var page:int=int(m.state.pb_page)
	if page==book_page:return
	book_page=page
	for book in books:
		for i in 2:
			var index:int=posmod(maxi(0,page-1)+i,m.assets.size());book.pages[i].material_override.albedo_texture=load("res://"+m.assets[index].runtime_path)
			var texture:Texture2D=book.pages[i].material_override.albedo_texture;var ratio:float=float(texture.get_width())/texture.get_height();book.pages[i].mesh.size=Vector2(minf(.78,ratio),minf(1.0,.78/ratio))
			book.pages[i].rotation.z=(.028 if i==0 else -.028)
	m.bay.sound("page",true,m.world.layout.vector(m.world.layout.config.annexes.B07.center))

func journal():
	m.open_modal("阁楼手札 · 山海藏景")
	m.label(m.modal_box,"手札和明信片是本项目原创。沿松鼠引导的山路探索；主路与茶寮始终开放。",24)
	m.button(m.modal_box,"森屿来信与主题房记录",m.bay.dual.travel_book)
	for i in m.world.layout.config.hidden_views.size():
		var index:int=i;var view:Dictionary=m.world.layout.config.hidden_views[index]
		m.label(m.modal_box,view.story,22)
		m.button(m.modal_box,"收下线索 · "+view.name,func():unlock(index);m.close_modal())
	m.button(m.modal_box,"继续翻阅原 PB",func():m.show_pb(int(m.state.pb_page)))

func unlock(index:int):
	var clues:Array=m.state.activities.get("clues",[])
	if index not in clues:clues.append(index)
	m.state.activities.clues=clues;var view:Dictionary=m.world.layout.config.hidden_views[index]
	m.target_zone={"id":view.id,"name":view.name,"x":view.point[0],"z":view.point[2]};m.save_game(false);m.notify("已记下手札线索，M 地图显示专属观景标记。")

func hidden_view(index:int):
	if index not in m.state.activities.get("clues",[]):m.notify("这处木牌藏着一段山海手札，先去拾光阁楼读读线索。 ");return
	var view:Dictionary=m.world.layout.config.hidden_views[index]
	if m.player.position.distance_to(m.world.layout.vector(view.point))>3.8:m.notify("沿手札标记的小径走到观景台，再按 E 留影。");return
	if view.card not in m.state.cards:m.state.cards.append(view.card);m.save_game(false)
	m.notify("已收集原创明信片 · "+view.card);m.enter_photo_mode()

func wish():
	m.close_modal();wish_until=clock+6;m.state.activities.wish_count=int(m.state.activities.get("wish_count",0))+1;m.save_game(false);m.bay.sound("bell",true,Vector3(0,m.world.height_at(0,54),54));m.notify("星光沿镜面水池升起，心愿记入旅行。")

func monitoring_pose():
	var guitar:bool=m.state.get("handheld","")=="headphones"
	m.state.handheld="guitar" if guitar else "headphones";m.bay.refresh_hand()
	var v:Dictionary=m.world.layout.venues.B09;m.player.sit_at(Vector3(v.x+4,v.floor_y+.16,v.z+3),0)
	m.notify("抱吉他坐姿 · 移动键起身" if guitar else "戴上监听耳机 · 再按 X 换抱吉他")

func _process(delta:float):
	if m==null:return
	update_motion_effects(delta)
	clock+=delta;var camera:Camera3D=m.get_viewport().get_camera_3d();var eye:Vector3=camera.global_position
	beacon.rotation.y=clock*.13;beacon.visible=m.active_game and int(m.state.time)>0 and (eye.distance_to(beacon.position)<700 or m.environment_controls.overview)
	var now:Dictionary=Time.get_datetime_dict_from_system();clock_hands[0].rotation.z=-TAU*(float(now.hour%12)+float(now.minute)/60)/12;clock_hands[1].rotation.z=-TAU*float(now.minute)/60
	if now.minute==0 and last_chime!=now.hour and m.active_game:
		last_chime=now.hour;var v:Dictionary=m.world.layout.venues.B01;m.bay.sound("bell",true,Vector3(v.x,v.floor_y+4,v.z))
	var windmill:Node3D=m.world.bay_props.get("windmill")
	if is_instance_valid(windmill):windmill.rotation.z=clock*.45
	var waterwheel:Node3D=m.world.bay_props.get("waterwheel")
	if is_instance_valid(waterwheel):waterwheel.rotate_object_local(Vector3(0,0,1),delta*.32)
	disc.visible=m.active_game and eye.distance_to(disc.position)<45
	if m.bay.music.playing or m.audio_player.playing:disc.rotation.y+=delta*3.5
	for book in books:book.root.visible=m.active_game and eye.distance_to(book.root.position)<40
	refresh_book()
	var stage:Dictionary=m.world.layout.venues.B10;var origin:=Vector3(stage.x,stage.floor_y,stage.z-7)
	stage_rack.position=Vector3(stage.x,stage.floor_y+8-(.6+.4*sin(clock*.3) if m.bay.light_show else 0),stage.z-10)
	stage_rack.rotation.z=float(m.state.activities.get("workshops105",{}).get("stage_0",0)-1)*.06
	stage_rack.visible=m.active_game and eye.distance_to(stage_rack.position)<60
	if m.state.get("handheld","")=="guitar" and m.player.seated:
		for i in m.player.arms.size():m.player.arms[i].rotation.x=-.8+sin(clock*4+i)*.06
	shadow_tick+=delta
	if shadow_tick>1:
		shadow_tick=0;var lights:Array=m.world.night_lights.filter(func(l):return is_instance_valid(l))
		lights.sort_custom(func(a,b):return a.global_position.distance_squared_to(m.player.position)<b.global_position.distance_squared_to(m.player.position))
		for i in lights.size():lights[i].shadow_enabled=i<3 and int(m.state.time)>0 and lights[i].global_position.distance_to(m.player.position)<35 and int(m.settings.quality)>0
	stars.visible=m.active_game and (m.bay.light_show or clock<wish_until) and (eye.distance_to(origin)<70 or clock<wish_until)
	mist.visible=m.active_game and m.bay.light_show and eye.distance_to(origin)<70
	var effect_mode:int=int(m.state.activities.get("workshops105",{}).get("stage_2",0))
	if m.state.activities.get("workshops105",{}).has("stage_2"):
		stars.visible=stars.visible and effect_mode!=2;mist.visible=mist.visible and effect_mode!=1
	if stars.visible:
		if clock<wish_until:origin=Vector3(0,m.world.height_at(0,54),54)
		for i in stars.multimesh.instance_count:
			var p:Vector3=origin+Vector3(sin(i*2.4+clock*.25)*6,fposmod(float(i)*.37-clock*.7,5)+.6,cos(i*2.4+clock*.25)*3)
			stars.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,clock+i),p));stars.multimesh.set_instance_color(i,Color("fff1ba"))
	if mist.visible:
		for i in mist.multimesh.instance_count:
			var p:Vector3=origin+Vector3(sin(i*2.1+clock*.2)*8,.5+sin(clock*.3+i)*.15,cos(i*2.1+clock*.2)*2)
			mist.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(1.8,.35,1.1)),p));mist.multimesh.set_instance_color(i,Color.WHITE)
	projector.visible=m.video.is_playing() and m.current_screen_id in ["B06","B06_OUT"]
	if projector.visible and is_instance_valid(m.watch_screen):
		projector.position=m.watch_screen.global_position+Vector3(0,2,16);projector.look_at(m.watch_screen.global_position)
		m.world.set_venue_lighting("B06",0)
	var home:Dictionary=m.world.layout.venues.B12;var fire_at:=Vector3(home.x-5.6,home.floor_y+.3,home.z-4.6)
	fire.visible=m.active_game and eye.distance_to(fire_at)<35
	if fire.visible:
		for i in fire.multimesh.instance_count:
			fire.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(1,.8+sin(clock*5+i)*.25,1)),fire_at+Vector3(sin(i*2)*.3,.1,cos(i*2)*.1)));fire.multimesh.set_instance_color(i,Color("f6c17c"))

func update_motion_effects(delta:float):
	var player=m.player;var moving:bool=player.enabled and not player.seated and not m.environment_controls.overview
	var speed:float=Vector2(player.velocity.x,player.velocity.z).length();var target:float=65.0
	if moving:target=74.0 if not m.bay.vehicles.mounted.is_empty() or not m.bay.boats.kind.is_empty() else 69.0 if speed>player.walk_speed*1.08 else 65.0
	player.camera.fov=lerpf(player.camera.fov,target,clampf(delta*3.0,0,1))
	if moving and player.is_on_floor() and speed>2 and m.bay.vehicles.mounted.is_empty() and m.bay.boats.kind.is_empty() and clock-last_foot>.33:
		last_foot=clock;var surface:String=m.bay.step_surface();var water:bool=surface=="water"
		for i in 3:
			footprints.append({"p":player.position+Vector3((i-1)*.1,.06,0),"age":0.0,"water":water,"surface":surface})
		while footprints.size()>12:footprints.pop_front()
	for item in footprints:item.age+=delta
	footprints=footprints.filter(func(a):return a.age<.48);foot_puffs.visible=m.active_game and not footprints.is_empty()
	for i in 12:
		if i>=footprints.size():foot_puffs.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO));continue
		var item:Dictionary=footprints[i];var t:float=item.age/.48;var p:Vector3=item.p+Vector3(sin(i*2.4)*t*.15,t*.20,cos(i*2.4)*t*.15)
		var size:float=(1.0-t)*(1.4 if item.water else .8);foot_puffs.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),p))
		var tone:=Color("bfe1d8" if item.water else "ded5bd" if item.surface in ["stone","sand"] else "a9b190" if item.surface=="grass" else "c4aa8e");tone.a=1-t;foot_puffs.multimesh.set_instance_color(i,tone)
