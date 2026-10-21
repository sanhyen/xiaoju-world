extends Node3D
## Optional forest activities and six distinct tactile theme-room workbenches.
const FOREST_PARKING={"id":"FOREST_PARKING106","name":"森屿双车架","kind":"vehicle","x":-52,"z":464,"safe":[-52,3.0,464]}
var vehicle_spares:Array=[]
const ROOM_WORDS={"everyday":"海风唱片间","waiting":"街角留声间","poem":"星夜手札间","frost":"霜月小舞台","blossom":"花影寻物间","daily":"日常摄影间"}
var m
var models:Dictionary={}
var fireflies:MultiMeshInstance3D
var steam:MultiMeshInstance3D
var clock:=0.0
var signature:=""
var motion:Dictionary={}
var selected_card:=0
var beat_begin:=-1.0
var beat_last:=-1
var beat_score:=0
var beat_hits:Array=[]

func setup(main):
	m=main;make_models()

func data()->Dictionary:
	if not m.state.activities.get("dual106") is Dictionary:m.state.activities.dual106={}
	var d:Dictionary=m.state.activities.dual106
	if not d.get("rooms") is Dictionary:d.rooms={}
	for id in ROOM_WORDS:
		if not d.rooms.get(id) is Dictionary:d.rooms[id]={"phase":0,"actions":0,"clues":[],"printed":0,"best":0}
	if not m.state.activities.get("island_02_state") is Dictionary:m.state.activities.island_02_state={}
	var island:Dictionary=m.state.activities.island_02_state
	island["enabled"]=true;island["schema"]=2
	if not island.get("observed") is Array:island["observed"]=[]
	if not island.get("star_records") is Array:island["star_records"]=[]
	if not island.get("letters") is Array:island["letters"]=[]
	if not island.has("temperature"):island.temperature=1
	if not island.has("star_step"):island.star_step=0
	if not island.has("star_chart"):island.star_chart=0
	# JSON reads numbers as floats; normalize collection identities before membership tests.
	if not d.rooms.daily.get("prints") is Array:d.rooms.daily.prints=[]
	d.rooms.daily["_creative_taken_prints"]=integer_ids(d.rooms.daily.get("_creative_taken_prints",[]),d.rooms.daily.prints.size()+1)
	island.observed=integer_ids(island.observed,3);island.star_records=integer_ids(island.star_records,3)
	for key in ROOM_WORDS:d.rooms[key].clues=integer_ids(d.rooms[key].get("clues",[]),3)
	return d

func integer_ids(values:Variant,limit:int)->Array:
	var result:Array=[]
	if values is Array:
		for value in values:
			if (value is int or value is float) and value>=0 and value<limit and int(value) not in result:result.append(int(value))
	return result

func island_data()->Dictionary:
	data();return m.state.activities.island_02_state

func root_at(id:String,at:Vector3)->Node3D:
	var node:=Node3D.new();node.name=id;node.position=at;add_child(node);models[id]=node;return node
func block(parent:Node3D,p:Vector3,size:Vector3,tone:String):return m.bay.add_block(parent,p,size,tone)
func cylinder(parent:Node3D,p:Vector3,radius:float,height:float,tone:String):return m.bay.workshops.cylinder(parent,p,radius,height,tone)
func picture(parent:Node3D,p:Vector3,path:String,size:Vector2)->MeshInstance3D:
	var texture:Texture2D
	if path.begins_with("user://"):
		var loaded:=Image.load_from_file(path)
		if loaded==null or loaded.is_empty():return null
		texture=ImageTexture.create_from_image(loaded)
	elif ResourceLoader.exists(path):texture=load(path)
	else:return null
	var node:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=size;node.mesh=mesh;node.position=p;var mat:=StandardMaterial3D.new();mat.albedo_texture=texture;mat.roughness=.9;node.material_override=mat;parent.add_child(node)

	return node

func make_models():
	var parking:Vector3=m.world.surface(FOREST_PARKING.x,FOREST_PARKING.z,.12);var rack:Node3D=root_at("forest_parking",parking)
	for x in [-3.2,0.0,3.2]:
		block(rack,Vector3(x,.48,.5),Vector3(.08,.96,.08),"9c8d6a");block(rack,Vector3(x,.96,.0),Vector3(.08,.08,1.1),"9c8d6a")
	for type in ["bike","scooter"]:
		var model:Node3D=m.bay.vehicles.model_for(type);m.bay.vehicles.add_child(model);model.position=m.world.surface(parking.x+(-1.6 if type=="bike" else 1.6),parking.z,.12);model.set_meta("dock",-106);model.set_meta("kind",type);m.bay.vehicles.parked.append(model);vehicle_spares.append(model)
	for r in m.world.layout.config.theme_rooms:
		var key:String=r.id.trim_prefix("THEME_").to_lower();var at:Vector3=m.world.layout.vector(r.center);var room_basis:=Basis(Vector3.UP,float(r.get("door_yaw",0)));var work:Vector3=at+room_basis*Vector3(-r.size[0]*.34,1.18,-r.size[1]*.1);var root:Node3D=root_at(key,work);root.rotation.y=float(r.get("door_yaw",0))
		match key:
			"everyday":
				var disk:MeshInstance3D=cylinder(root,Vector3(0,.13,0),.50,.045,"303b37");disk.name="Vinyl"
				for j in 3:
					var a:float=j*TAU/3;var stripe:MeshInstance3D=block(disk,Vector3(cos(a)*.32,.03,sin(a)*.32),Vector3(.06,.012,.15),"d5b98b");stripe.rotation.y=-a
				cylinder(root,Vector3(0,.17,0),.16,.015,"dfbc84")
				block(root,Vector3(.58,.12,.05),Vector3(.05,.06,.8),"b5aa85");block(root,Vector3(.55,.12,-.35),Vector3(.15,.10,.12),"73847a")
				for i in 3:picture(root,Vector3(-.6+i*.6,.65,-.54),"res://assets/media/bay_life/life_0"+str(1+i)+".jpg",Vector2(.55,.65)).name="Cover"+str(i)
			"waiting":
				for i in 5:
					var house:=Node3D.new();house.name="MiniStreet"+str(i);root.add_child(house);house.position=Vector3(-.9+i*.45,0,-.13)
					block(house,Vector3(0,.3,0),Vector3(.30,.6+i%2*.22,.4),["c6b19a","9eafa2","c9bc9e"][i%3]);block(house,Vector3(0,.64+i%2*.2,0),Vector3(.38,.10,.48),"706858")
					for j in 3:block(house,Vector3(0,.15+j*.15,.205),Vector3(.13,.07,.015),"f2d89e")
				block(root,Vector3(0,.01,.43),Vector3(2.3,.025,.2),"5c6d65")
				for i in 3:
					block(root,Vector3(-.8+i*.8,.25,.42),Vector3(.025,.5,.025),"7d765c");var lamp:MeshInstance3D=block(root,Vector3(-.8+i*.8,.52,.42),Vector3(.12,.1,.12),"ead7a3");lamp.name="StreetLamp"+str(i);lamp.material_override.emission_enabled=true;lamp.material_override.emission=Color("f3d495")
			"poem":
				for i in 3:
					var page:MeshInstance3D=block(root,Vector3(-.65+i*.65,.07,0),Vector3(.58,.05,.8),["e2d5b8","c6c7be","c8b7cf"][i]);page.name="JournalPage"+str(i)
					picture(page,Vector3(0,.39,-.39),"res://assets/media/bay_life/life_0"+str(4+i)+".jpg",Vector2(.5,.55))
			"frost":
				root.position=at
				var curtain:=Node3D.new();curtain.name="Curtain";root.add_child(curtain);curtain.position=Vector3(0,3.3,-r.size[1]*.5+.7)
				for i in 12:block(curtain,Vector3(-3.1+i*.56,0,sin(i*1.1)*.05),Vector3(.58,1.8,.06),"c2cbd9" if i%2 else "9eb0c6")
				for i in 4:
					var pad:MeshInstance3D=block(root,Vector3(-2.5+i*1.7,.39,.5),Vector3(1.2,.035,1.2),"acc0ce");pad.name="Pad"+str(i)
				for i in 2:
					var lamp:=SpotLight3D.new();lamp.name="Light"+str(i);lamp.position=Vector3(-3+i*6,3.6,-2.3);lamp.rotation.x=-PI*.65;lamp.spot_range=12;lamp.spot_angle=44;lamp.light_energy=1;lamp.shadow_enabled=false;root.add_child(lamp)
			"blossom":
				root.position=at+room_basis*Vector3(0,1.2,1)
				for i in 3:
					var token:MeshInstance3D=block(root,Vector3(-.65+i*.65,0,0),Vector3(.44,.16,.44),["afc1aa","c6a4b4","dac598"][i]);token.name="Clue"+str(i)
			"daily":
				block(root,Vector3(0,.1,0),Vector3(1.6,.2,1),"6c7a70");block(root,Vector3(0,.18,.51),Vector3(1.2,.07,.02),"433d31")
				var paper:MeshInstance3D=block(root,Vector3(0,.13,.35),Vector3(.7,.02,.55),"f4e9cd");paper.name="PrintPaper"
				for i in 3:picture(root,Vector3(-.65+i*.65,.70,-.45),"res://assets/media/bay_life/life_0"+str(1+i*2)+".jpg",Vector2(.58,.68)).name="DryPhoto"+str(i)
	var valve:Node3D=root_at("valve",m.world.layout.vector([-94,5.4,494])+Vector3(-.6,1,0));var wheel:Node3D=m.bay.workshops.wheel_model(valve,.36,.08);wheel.name="ValveWheel"
	block(valve,Vector3(0,-.4,0),Vector3(.15,.8,.15),"b29b6b");block(valve,Vector3(.5,-.68,.0),Vector3(1.0,.12,.12),"b29b6b")
	var stream:MeshInstance3D=block(valve,Vector3(.98,-.98,0),Vector3(.08,.55,.08),"9ed6c9");stream.name="WaterStream"
	var star:Node3D=root_at("star",m.world.layout.vector([-59,6.5,516])+Vector3(-1.7,1.15,-.6));var disk:Node3D=m.bay.workshops.wheel_model(star,.65,.12);disk.name="StarWheel"
	for i in 8:
		var a:float=i*TAU/8;var light:MeshInstance3D=block(star,Vector3(sin(a)*.72,cos(a)*.72,.12),Vector3(.09,.09,.09),"bcaa78");light.name="Star"+str(i)
	var mail:Node3D=root_at("mail",m.world.layout.vector([-30,10.2,487])+Vector3(0,1.35,1.15));block(mail,Vector3(0,.04,.02),Vector3(.8,.10,.12),"c2b28e")
	var stamp:Node3D=Node3D.new();stamp.name="Stamp";mail.add_child(stamp);block(stamp,Vector3(.3,.2,.08),Vector3(.13,.32,.13),"917653");block(stamp,Vector3(.3,.03,.08),Vector3(.25,.04,.23),"756449")
	# Sent cards and selected local photographs are built from saved letters in refresh_models().
	fireflies=particles("ForestFireflies",120,Color("dbe897"),Vector3(.075,.075,.075),false)
	steam=particles("WarmSpringSteam",28,Color(1,1,.9,.13),Vector3(.45,.08,.35),true)

func particles(id:String,count:int,color:Color,scale_value:Vector3,transparent:bool)->MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new();node.name=id;var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=BoxMesh.new();mm.instance_count=count;node.multimesh=mm
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.vertex_color_use_as_albedo=true;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.emission_enabled=not transparent;material.emission=color;material.emission_energy_multiplier=.55
	if transparent:material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.set_meta("particle_size",scale_value);add_child(node);return node

func room_for(key:String)->Dictionary:
	for room in m.world.layout.config.theme_rooms:
		if room.id=="THEME_"+key.to_upper():return room
	return {}

func open_action(topic:String):
	var d:Dictionary=data();var island:Dictionary=island_data()
	if topic.begins_with("room_"):
		var key:String=topic.trim_prefix("room_");var room:Dictionary=room_for(key)
		if room.is_empty():return
		m.open_modal(room.name+" · "+room.work,1120)
		m.label(m.modal_box,{"everyday":"将黑胶、封套和旅行照片配成你的海风唱片。","waiting":"调节微缩街景、街灯与门牌，留下街角故事。","poem":"翻动手札、照片和星灯，整理星夜旅行页。","frost":"调灯架、升降垂幕，或在四块踏灯上跟拍。","blossom":"在三张花纹桌边找齐线索，再合成花影纪念。","daily":"选择本机旅行照或原公开照片，裁切、冲印与装框；原照片只读保留。"}[key],25)
		m.button(m.modal_box,"本房独立玩法与两件作品",func():m.creative.recipe_panel(key) if m.creative!=null else null)
		m.button(m.modal_box,"点播 · "+room.work,func():m.show_video(room.id,room.program))
		if key in ["everyday","waiting","poem"]:
			m.button(m.modal_box,"单独试听",func():m.show_audio(room.program))
			m.button(m.modal_box,("移出随身歌单" if room.program in m.state.playlist else "加入随身歌单"),func():
				if room.program in m.state.playlist:m.state.playlist.erase(room.program)
				else:m.state.playlist.append(room.program)
				m.save_game(false);open_action(topic))
		m.label(m.modal_box,"默认保留环境声，节目由你主动点播。实体工作台在房间左侧，走近按 F。",22)
		m.label(m.modal_box,"本房操作 "+str(d.rooms[key].actions)+" 次 · 当前布置 "+str(int(d.rooms[key].phase)+1),21)
		if key=="frost":m.button(m.modal_box,"开始 12 拍踏灯",start_beats)
		if key=="daily":m.button(m.modal_box,"选择下一张冲印照片",func():action("print_select"))
		return
	if topic=="welcome":travel_book();return
	if topic.begins_with("firefly_"):
		m.open_modal("萤火观察图鉴")
		for i in 3:m.label(m.modal_box,("● " if i in island.observed else "○ ")+["蕨叶荧光","林间金点","岩泉暮萤"][i],25)
		m.label(m.modal_box,"夜间走近观察庭按 F，记录萤火。萤火会在你靠近时分散，主路和树屋无需解锁。",23)
		return
	if topic=="star":
		m.open_modal("南岚星图 · 旋转观星")
		for i in 3:
			var index:int=i;m.button(m.modal_box,["海风星弧","森屿北斗","萤火长河"][i]+(" · 已记录" if i in island.star_records else ""),func():island.star_chart=index;island.star_step=0;m.save_game(false);m.close_modal();m.notify("星图已选，靠近转盘按 F 开始三轮星位对齐。"))
		m.label(m.modal_box,"按 F 打开所选星图，拖动三枚指针对准金色目标线，再检查进入下一轮；完成三轮后记入旅行册。夜间可看清实体星灯。",23)
		if m.creative!=null:m.button(m.modal_box,"开始所选星图挑战",func():m.creative.begin_puzzle("star"))
		return
	if topic=="valve":
		m.open_modal("岩泉水温")
		m.label(m.modal_box,"当前 "+["清凉","温暖","暖热"][clampi(int(island.temperature),0,2)]+" · F 旋转冷热水阀，水流和蒸汽随档位变化。沿北侧石阶可自由入池与回岸。",25)
		return
	if topic=="mail":
		m.open_modal("树冠寄信")
		var choices:Array=["森屿晨光","树冠来信","温泉暮色"]+m.state.shots
		for i in mini(choices.size(),11):
			var index:int=i;m.button(m.modal_box,("● " if i==selected_card else "○ ")+str(choices[i]).get_file(),func():selected_card=index;open_action("mail"))
		m.button(m.modal_box,"盖戳寄出",func():m.close_modal();action("mail"))
		m.label(m.modal_box,"已寄 "+str(island.letters.size())+" 张；大陆旅行册与海风小屋可查看。照片只在本机使用。",21)
		return
	m.open_modal("实体操作")
	m.label(m.modal_box,"走近按 F 操作。布置和收集会保存在旅行记录。",25)
	m.button(m.modal_box,"操作一次",func():m.close_modal();action(topic))

func action(topic:String):
	var d:Dictionary=data();var island:Dictionary=island_data()
	if m.creative!=null:
		if topic=="print_select":m.creative.cycle_daily_photo();m.creative.recipe_panel("daily");return
		var tactile:Dictionary={"record":"everyday","street":"waiting","journal":"poem","frost_light":"frost","print":"daily","print_select":"daily"}
		if tactile.has(topic):m.creative.recipe_panel(tactile[topic]);return
		if topic=="star":m.creative.begin_puzzle("star");return
	if topic.begins_with("room_") or topic=="welcome":open_action(topic);return
	if topic.begins_with("firefly_"):
		var index:int=int(topic.get_slice("_",1))
		if int(m.state.time)==0:m.notify("已找到观察庭。黄昏或夜间再按 F，观察叶间萤火；F6 可调整时光。");return
		if index not in island.observed:island.observed.append(index)
		m.notify("已记录 "+["蕨叶荧光","林间金点","岩泉暮萤"][index]+"，旅行册已更新。")
	elif topic=="star":
		island.star_step=(int(island.star_step)+1)%8
		if int(island.star_step)==0 and int(island.star_chart) not in island.star_records:island.star_records.append(int(island.star_chart))
		motion.star=clock+1.1;m.notify("星图转至第 "+str(int(island.star_step)+1)+" 段 · 已记录 "+str(island.star_records.size())+" 幅。")
	elif topic=="valve":island.temperature=(int(island.temperature)+1)%3;motion.valve=clock+1.1;m.notify("水阀转到"+["清凉","温暖","暖热"][int(island.temperature)]+"，水流与蒸汽已改变。")
	elif topic=="mail":
		if m.creative!=null and not m.creative.consume("paper",1):m.notify("寄信需要一张手作纸，可去风物材料街屋采集或加工。");return
		var choices:Array=["森屿晨光","树冠来信","温泉暮色"]+m.state.shots;var index:int=clampi(selected_card,0,choices.size()-1)
		island.letters.append({"card":choices[index],"time":Time.get_datetime_string_from_system(),"stamp":"森屿来信"});motion.mail=clock+1.2
		if m.creative!=null:
			var file:String=m.photo_directory()+"/"+str(choices[index]).get_file() if index>=3 else ""
			var ids:Array=m.creative.items.grant("photo_print",1,{"file":file,"letter":choices[index]});var uid:String=str(ids[0]);m.creative.items.transfer(uid,"legacy_mail:"+str(island.letters.size()-1));island.letters.back()["_creative_uid"]=uid
		if "FOREST_MAIL" not in m.state.cards:m.state.cards.append("FOREST_MAIL")
		m.notify("明信片已盖戳，已记入大陆旅行册。")
	elif topic.begins_with("shore_"):
		if m.creative!=null:m.creative.collect_legacy_material("FOREST_"+topic,{"sea_glass":1,"driftwood":1},180)
		island[topic]=true;m.notify("森屿浅岸材料已记录，恢复后可再次采集。")
	elif topic.begins_with("clue_"):
		var index:int=int(topic.get_slice("_",1));var room:Dictionary=d.rooms.blossom
		if index not in room.clues:room.clues.append(index);room.actions=int(room.actions)+1
		room.phase=room.clues.size();motion.blossom=clock+1.2;m.notify("花纹线索 "+str(room.clues.size())+" / 3"+(" · 花影纪念拼合完成。" if room.clues.size()==3 else " · 其余线索在房间不同桌边。"))
	elif topic.begins_with("beat_"):tap_beat(int(topic.get_slice("_",1)));return
	else:
		var key:String={"record":"everyday","street":"waiting","journal":"poem","frost_light":"frost","print":"daily","print_select":"daily"}.get(topic,"")
		if key.is_empty():return
		var room:Dictionary=d.rooms[key];room.actions=int(room.actions)+1;room.phase=int(room.phase) if topic=="print" else (int(room.phase)+1)%3;motion[key]=clock+1.8
		if topic=="print":room.printed=int(room.printed)+1;room.prints.append(int(room.phase))
		m.notify({"record":"已更换黑胶与封套组合，唱盘开始转动。","street":"街灯、门牌与微缩街景已重新布置。","journal":"手札页与旅行照片已换到下一组。","frost_light":"已调整舞台灯色与实体垂幕。","print":"相纸正在出片，晾片墙保留冲印记录。","print_select":"已选择下一组公开照片。"}.get(topic,"布置已更新。"))
	m.save_game(false);signature=""

func travel_book():
	var d:Dictionary=data();var island:Dictionary=island_data();m.open_modal("森屿与主题房旅行册",1140)
	m.label(m.modal_box,"萤火观察 "+str(island.observed.size())+" / 3 · 星图 "+str(island.star_records.size())+" / 3 · 水温 "+["清凉","温暖","暖热"][int(island.temperature)],25)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1020,540);m.modal_box.add_child(scroll);var list:=VBoxContainer.new();scroll.add_child(list)
	for key in ROOM_WORDS:m.label(list,ROOM_WORDS[key]+" · 操作 "+str(d.rooms[key].actions)+" 次",23)
	for letter in island.letters:
		var sent:Dictionary=letter;m.button(list,"来信 · "+str(letter.card).get_file()+" · "+str(letter.time),func():show_letter(sent))
	if island.letters.is_empty():m.label(list,"树冠邮局尚无寄信记录。桥、船和树屋已全部开放。",23)
	m.button(m.modal_box,"打开双岛地图",m.show_map)

func start_beats():
	m.close_modal();beat_begin=clock;beat_last=-1;beat_score=0;beat_hits.clear();m.notify("12 拍踏灯开始 · 依次踏到亮起的地板，在节拍附近按 F。Esc 可暂停。")

func tap_beat(index:int):
	if beat_begin<0:start_beats();return
	var beat:int=roundi((clock-beat_begin)/.8)
	if beat<0 or beat>=12:return
	if index!=beat%4 or beat in beat_hits or absf((clock-beat_begin)-beat*.8)>.30:m.notify("跟随当前亮起的踏灯，靠近后在节拍附近按 F。");return
	beat_hits.append(beat);beat_score+=1;m.bay.sound("beat");m.notify("踏灯命中 "+str(beat_score)+" / 12")

func _process(delta:float):
	if m==null or not m.active_game:return
	for spare in vehicle_spares:
		if is_instance_valid(spare) and not spare.visible and m.player.position.distance_to(spare.position)>12:spare.show()
	clock+=delta;var d:Dictionary=data();var island:Dictionary=island_data()
	for id in models:
		var node:Node3D=models[id];node.visible=m.player.position.distance_to(node.position)<110
	var serial:String=JSON.stringify(d)+JSON.stringify(island)
	if serial!=signature:signature=serial;refresh_models()
	if models.everyday.visible:models.everyday.get_node("Vinyl").rotation.y+=delta*.65 if float(motion.get("everyday",0))>clock else 0
	if models.star.visible:models.star.get_node("StarWheel").rotation.z=lerp_angle(models.star.get_node("StarWheel").rotation.z,float(island.star_step)*TAU/8,clampf(delta*3,0,1))
	if models.valve.visible:models.valve.get_node("ValveWheel").rotation.z=lerp_angle(models.valve.get_node("ValveWheel").rotation.z,float(island.temperature)*TAU/3,clampf(delta*4,0,1))
	if models.mail.visible:models.mail.get_node("Stamp").position.y=sin((float(motion.get("mail",0))-clock)*5)*.09 if float(motion.get("mail",0))>clock else 0
	if models.daily.visible:models.daily.get_node("PrintPaper").position.z=lerpf(models.daily.get_node("PrintPaper").position.z,.65 if int(d.rooms.daily.printed)>0 else .35,clampf(delta*2,0,1))
	if models.frost.visible:
		var curtain:Node3D=models.frost.get_node("Curtain");curtain.visible=not (m.video.is_playing() and m.current_screen_id=="THEME_FROST");curtain.position.y=lerpf(curtain.position.y,3.3+int(d.rooms.frost.phase)*.34,clampf(delta*3,0,1))
	if beat_begin>=0:
		if m.modal.visible or not models.frost.visible:beat_begin=-1
		elif clock-beat_begin>9.9:
			d.rooms.frost.best=maxi(int(d.rooms.frost.best),beat_score);d.rooms.frost.actions=int(d.rooms.frost.actions)+1;beat_begin=-1;m.save_game(false);m.notify("踏灯完成 "+str(beat_score)+" / 12 · 最佳 "+str(d.rooms.frost.best))
			if m.creative!=null and beat_score>=8:m.creative.finish_puzzle("frost",{"moves":12,"seconds":9.6,"pattern":[beat_score],"tone":int(d.rooms.frost.phase)})
		else:
			var beat:int=roundi((clock-beat_begin)/.8)
			if beat!=beat_last:
				beat_last=beat
				for i in 4:models.frost.get_node("Pad"+str(i)).material_override.albedo_color=Color("f2d79c" if i==beat%4 else "acc0ce")
	if not island.get("visited",false) and Vector2((m.player.position.x+60)/60,(m.player.position.z-490)/39.2).length()<.96:island.visited=true
	update_nature(island)

func refresh_models():
	var d:Dictionary=data();var island:Dictionary=island_data()
	models.everyday.get_node("Vinyl").material_override.albedo_color=Color(["303b37","384c58","5c4851"][int(d.rooms.everyday.phase)])
	for i in 3:
		models.everyday.get_node("Cover"+str(i)).scale=Vector3.ONE*(1.12 if i==int(d.rooms.everyday.phase) else .82)
		models.waiting.get_node("StreetLamp"+str(i)).material_override.emission_energy_multiplier=.25+int(d.rooms.waiting.phase)*.45
		var photo:MeshInstance3D=models.daily.get_node("DryPhoto"+str(i));var prints:Array=d.rooms.daily.prints;photo.visible=i<mini(3,prints.size())
		if photo.visible and maxi(0,prints.size()-3)+i in d.rooms.daily.get("_creative_taken_prints",[]):photo.visible=false
		if photo.visible:photo.material_override.albedo_texture=load("res://assets/media/bay_life/life_0"+str(1+int(prints[maxi(0,prints.size()-3)+i])*2)+".jpg")
	var old:Node=models.mail.get_node_or_null("SentCards")
	if old!=null:models.mail.remove_child(old);old.queue_free()
	var rack:=Node3D.new();rack.name="SentCards";models.mail.add_child(rack)
	for i in mini(6,island.letters.size()):
		var letter:Dictionary=island.letters[maxi(0,island.letters.size()-6)+i]
		if letter.get("_creative_taken",false):continue
		var card:=Node3D.new();rack.add_child(card);card.position=Vector3(-1.02+i*.41,.46,.05)
		block(card,Vector3.ZERO,Vector3(.36,.48,.025),"eee2bd");var path:String=m.photo_directory()+"/"+str(letter.card).get_file()
		if FileAccess.file_exists(path):picture(card,Vector3(0,0,.018),path,Vector2(.32,.43))
		else:
			block(card,Vector3(0,.01,.02),Vector3(.025,.27,.01),"8b7855")
			for j in 3:block(card,Vector3(0,.10-j*.06,.025),Vector3(.22-j*.04,.07,.01),["8ba174","a5b991","c6d2a5"][j])
	for i in 5:
		var mini_house:Node3D=models.waiting.get_node("MiniStreet"+str(i));mini_house.position.z=-.13+(i%2)*.16*int(d.rooms.waiting.phase);mini_house.rotation.y=(int(d.rooms.waiting.phase)-1)*.08
	for i in 3:models.poem.get_node("JournalPage"+str(i)).rotation.y=(i-1)*.08+int(d.rooms.poem.phase)*.09
	for i in 3:models.blossom.get_node("Clue"+str(i)).visible=i in d.rooms.blossom.clues
	for i in 8:models.star.get_node("Star"+str(i)).material_override.albedo_color=Color("f0dd93" if i<=int(island.star_step) else "8d9074")
	for i in 2:models.frost.get_node("Light"+str(i)).light_color=[Color("c6dce7"),Color("d9c8e5"),Color("e9d2a4")][(int(d.rooms.frost.phase)+i)%3]
	models.valve.get_node("WaterStream").scale.x=1+int(island.temperature)*.4

func update_nature(island:Dictionary):
	var here:Vector3=m.player.position;var active:bool=here.distance_to(Vector3(-60,3,490))<130
	fireflies.visible=active and int(m.state.time)>0
	if fireflies.visible:
		for i in fireflies.multimesh.instance_count:
			var point:Array=m.world.layout.config.island2.observation_points[i%3];var base:Vector3=m.world.layout.vector(point);var a:float=i*2.399+clock*(.14+i%3*.025)
			var p:Vector3=base+Vector3(cos(a)*(2+i%7*.8),.6+sin(clock*.7+i)*.35+(i%5)*.32,sin(a)*(1.7+i%6*.65))
			var away:Vector3=p-here
			if away.length()<2.5:p+=away.normalized()*(2.5-away.length())
			var pulse:float=.55+.45*sin(clock*1.7+i*1.2);fireflies.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(.05+pulse*.045)),p));fireflies.multimesh.set_instance_color(i,Color(1,.94,.55)*(.7+pulse*.3))
	steam.visible=active and int(island.temperature)>0
	if steam.visible:
		for i in steam.multimesh.instance_count:
			var pool:Dictionary=m.world.layout.config.island2.pools[i%2];var base:Vector3=m.world.layout.vector(pool.center);var t:float=fposmod(clock*.19+i*.137,1)
			var p:Vector3=base+Vector3(sin(i*2.399)*pool.size[0]*.32+sin(clock*.3+i)*t*.4,.1+t*(.55+int(island.temperature)*.30),cos(i*2.399)*pool.size[1]*.28)
			steam.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(.35+t*.7,.08+t*.10,.3+t*.5)),p));steam.multimesh.set_instance_color(i,Color(1,1,.93,(1-t)*.18))

func foot_only_ahead(p:Vector3)->bool:
	var cfg:Dictionary=m.world.layout.config
	if p.x< -145 or p.x>10 or p.z<435 or p.z>545:return false
	for pool in cfg.island2.pools:
		if absf(p.x-pool.center[0])<pool.size[0]*.5+.6 and absf(p.z-pool.center[2])<pool.size[1]*.5+.6:return true
	if p.y-m.world.height_at(p.x,p.z)<1.15:return false
	for route in cfg.island2.canopy_routes:
		for i in route.points.size()-1:
			var a:Vector3=m.world.layout.vector(route.points[i]);var c:Vector3=m.world.layout.vector(route.points[i+1]);var q:Vector3=m.world.layout.projection(Vector2(p.x,p.z),{"a":a,"c":c})
			if Vector2(p.x-q.x,p.z-q.z).length()<route.width*.5+.4 and absf(p.y-q.y)<1:return true
	return false

func show_letter(letter:Dictionary):
	var path:String=m.photo_directory()+"/"+str(letter.card).get_file()
	if FileAccess.file_exists(path):
		m.open_personal({"title":"森屿来信 · "+str(letter.time),"kind":"image","runtime_path":str(letter.card)},ProjectSettings.globalize_path(m.photo_directory()));return
	m.open_modal("原创森屿图卡 · "+str(letter.card),1150)
	m.label(m.modal_box,"森屿来信 · "+str(letter.time),25)
	var card:=Control.new();card.set_script(load("res://scripts/bay_map_view.gd"));card.spec=m.world.spec;card.font=m.font;card.region_id="ISLAND_02";card.view_rect=Rect2(-144,425,177,142);card.custom_minimum_size=Vector2(1040,530);card.mouse_filter=Control.MOUSE_FILTER_IGNORE;m.modal_box.add_child(card)
	m.button(m.modal_box,"带回海风小屋展示",func():m.state.home_card="FOREST_MAIL";m.sync_home_memories();m.save_game(false);m.notify("森屿来信已放到海风小屋纪念卡架。"))
