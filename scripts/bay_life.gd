extends Node3D
## Normal-play E/F/X activities and their persistent, visible outcomes.
var m
var vehicles
var animals
var boats
var details
var village
var workshops
var dual
var hand:Node3D
var effect:Node3D
var ornament:Node3D
var home_parent:int=0
var ornament_signature:=""
var fx:=AudioStreamPlayer.new()
var step_fx:=AudioStreamPlayer3D.new()
var animal_fx:=AudioStreamPlayer3D.new()
var music:=AudioStreamPlayer.new()
var ambience:=AudioStreamPlayer3D.new()
var mix_players:Array=[]
var mix_enabled:=false
var playlist_cursor:=0
var playlist_paused_by_media:=false
var foreground_busy:=false
var busy_token:=0
var pose_index:=0
var f_target:Dictionary={}
var rhythm:Dictionary={}
var rhythm_lights:Array=[]
var light_show:=false
var light_clock:=0.0
var local_music:=""
var timer:=0.0
var gait_time:=0.0
var life_media:Array=[]
var louvers:Array=[]
var sand_model:Node3D
var sand_style:=-2
var tea_light:OmniLight3D
var creek_tea_light:OmniLight3D
const POSES=["natural","drink","bouquet","camera","sit"]

func setup(target):
	m=target
	for audio in [fx,music,ambience,step_fx,animal_fx]:add_child(audio)
	for audio in [step_fx,animal_fx]:audio.bus="Environment";audio.unit_size=4;audio.max_distance=32;audio.volume_db=-6
	fx.bus="Interface";music.bus="Music";ambience.bus="Music";music.volume_db=-15;ambience.volume_db=-25;ambience.max_distance=24;ambience.unit_size=4
	music.finished.connect(next_song)
	life_media=JSON.parse_string(FileAccess.get_file_as_string("res://data/life_media_bay.json"))
	for i in 4:
		var a:=AudioStreamPlayer3D.new();a.bus="Music";a.max_distance=24;a.unit_size=3;a.position=Vector3(-234,11.8,-7);add_child(a);mix_players.append(a)
	vehicles=preload("res://scripts/bay_vehicles.gd").new();add_child(vehicles);vehicles.setup(m)
	animals=preload("res://scripts/bay_animals.gd").new();add_child(animals);animals.setup(m)
	boats=preload("res://scripts/bay_boats.gd").new();add_child(boats);boats.setup(m)
	details=preload("res://scripts/bay_detail_runtime.gd").new();add_child(details);details.setup(m)
	village=preload("res://scripts/bay_village.gd").new();add_child(village);village.setup(m)
	workshops=preload("res://scripts/bay_workshops.gd").new();add_child(workshops);workshops.setup(m)
	dual=preload("res://scripts/bay_dual106.gd").new();add_child(dual);dual.setup(m)
	make_louvers()
	tea_light=OmniLight3D.new();tea_light.position=m.world.layout.vector([-20,73.5,-396])+Vector3(0,1.8,0);tea_light.light_color=Color("ffa65c");tea_light.omni_range=9;add_child(tea_light)
	creek_tea_light=OmniLight3D.new();creek_tea_light.position=Vector3(-194,5,-187.5);creek_tea_light.light_color=Color("ffbd76");creek_tea_light.omni_range=4;creek_tea_light.light_energy=0;creek_tea_light.shadow_enabled=false;add_child(creek_tea_light)

func defaults():
	home_parent=0;sand_style=-2
	for key in ["inventory","activities","mix_recipe"]:
		if not m.state.get(key) is Dictionary:m.state[key]={}
	for key in ["playlist","itinerary"]:
		if not m.state.get(key) is Array:m.state[key]=[]
	if not m.state.has("handheld"):m.state.handheld="natural"
	refresh_hand()
	set_louvers(float(m.state.activities.get("blinds",0)))

func _exit_tree():
	for audio in [fx,music,ambience,step_fx,animal_fx]+mix_players:
		if is_instance_valid(audio):audio.stop();audio.stream=null

func sound(id:String,spatial:bool=false,at:Vector3=Vector3.INF):
	var path:="res://assets/audio/bay/"+id+".wav"
	if not ResourceLoader.exists(path):return
	if spatial:
		var voice:AudioStreamPlayer3D=step_fx if id.begins_with("step") else animal_fx
		voice.position=m.player.position if at==Vector3.INF else at;voice.stream=load(path);voice.play()
	else:fx.stream=load(path);fx.play()

func step_surface()->String:
	var p:Vector3=m.player.position;var venue:String=m.world.inside_building(p)
	if m.world.layout.height_at(Vector2(p.x,p.z))<float(m.world.layout.config.sea_y)-.10 and p.y<float(m.world.layout.config.sea_y)-.10:return "water"
	var pool:Dictionary=m.world.layout.config.get("play_pool",{})
	if not pool.is_empty() and absf(p.x-pool.center[0])<pool.size[0]*.5 and absf(p.z-pool.center[2])<pool.size[1]*.5 and p.y<float(pool.water_h_sea)+float(m.world.layout.config.sea_y)-.1:return "water"
	if venue.begins_with("H") or venue.begins_with("VILLA_") or venue=="ISLAND_LOBBY" or venue in ["B02","B03","B07","B08","B12"] or m.world.within_pier(p):return "wood"
	var shore:float=m.world.layout.shore_z(p.x)
	if p.z>shore-22:return "water" if p.y< -1.8 else "sand"
	for road in m.world.layout.near(m.world.layout.road_index,Vector2(p.x,p.z)):
		var q:Vector3=m.world.layout.projection(Vector2(p.x,p.z),road)
		if Vector2(p.x-q.x,p.z-q.z).length()<road.width*.5:return "wood" if road.bridge else "stone"
	return "grass"

func nearest_kinds(kinds:Array,radius:float=4)->Dictionary:
	var closest:Dictionary={};var distance:float=radius
	for action in m.world.interactions:
		if action.kind not in kinds:continue
		var d:float=m.player.position.distance_to(action.pos)
		if d<distance:distance=d;closest=action
	return closest

func handle_input(event)->bool:
	if not event is InputEventKey or not event.pressed or event.echo:return false
	if not m.active_game or m.transitioning or m.environment_controls.overview:return false
	if not rhythm.is_empty() and event.physical_keycode in [KEY_F,KEY_ESCAPE]:
		if event.physical_keycode==KEY_ESCAPE:finish_rhythm(true)
		else:tap_rhythm()
		return true
	if foreground_busy and event.physical_keycode==KEY_ESCAPE:busy_token+=1;foreground_busy=false;clear_effect();m.notify("已停止当前动作，材料与结果保持原状。");return true
	if m.modal.visible or not m.player.enabled:return false
	if event.physical_keycode==KEY_F:
		if foreground_busy:return true
		if boats!=null and not boats.kind.is_empty():boats.dock();return true
		if not vehicles.mounted.is_empty():vehicles.dismount();return true
		var a:Dictionary=nearest_kinds(["bay_activity","bay_pick","bay_vehicle","bay_boat","bay_flower","bay_moored","life_house","life_farm","life_pasture","life_pool","redesign","dual106","bay_public_boat","creative110"],4.2)
		var parked:Dictionary=vehicles.nearest_parked()
		if a.is_empty() and not parked.is_empty():vehicles.mount(parked.kind,-1,parked.position);return true
		if a.is_empty():return false
		match a.kind:
			"creative110":if m.creative!=null:m.creative.activity(a)
			"dual106":dual.action(str(a.data.topic))
			"bay_public_boat":boats.board_public(str(a.data.source))
			"redesign":workshops.open_action(str(a.data.topic))
			"bay_vehicle":vehicles.mount(a.data.vehicle,int(a.data.dock))
			"bay_pick","bay_flower":pick(a)
			"bay_boat":if boats!=null:boats.board(int(a.data.dock))
			"bay_moored":boats.board_moored(int(a.data.index))
			"life_house","life_farm","life_pasture","life_pool":village.open_action(a)
			_:open_activity(str(a.data.activity))
		return true
	if event.physical_keycode==KEY_X:
		if boats!=null and not boats.kind.is_empty():boats.change_pose();return true
		if not vehicles.mounted.is_empty():sound("bell" if vehicles.mounted=="bike" else "horn",true);animals.ring(m.player.position);return true
		if village.pet_livestock():return true
		if animals.pet():return true
		var pose:Dictionary=nearest_kinds(["bay_pose"],2.8)
		if not pose.is_empty():details.monitoring_pose();return true
		var seat:Dictionary=nearest_kinds(["sit","bay_swing","bay_netbed"],3.5)
		if not seat.is_empty():
			if seat.kind=="sit":m.activate(seat)
			elif boats!=null:boats.rest(seat)
			return true
		pose_index=(pose_index+1)%POSES.size()
		var free_pose:String=POSES[pose_index]
		if m.creative!=null:
			m.creative.items.equip("")
			if free_pose in ["drink","bouquet"]:
				var owned:Array=m.creative.items.owned("legacy_"+free_pose,true)
				if owned.is_empty():m.notify("先制作一份饮品或花束放进背包，再选择手持展示。");return true
				m.creative.items.equip(str(owned.back().uid));m.creative.save();return true
		m.state.handheld=free_pose;refresh_hand();m.notify("姿态 · "+["自然行走","端杯","手捧花束","举起相机","原地歇息"][pose_index]);return true
	return false

func _process(delta:float):
	if m==null or not m.active_game:return
	if light_show:
		light_clock+=delta
		var sequence:Array=m.state.activities.get("light_sequence",[0,1,2])
		m.world.set_venue_lighting("B10",int(sequence[int(light_clock/4)%3]))
	if not rhythm.is_empty() and m.player.enabled and not m.modal.visible and not m.environment_controls.overview:
		rhythm.clock+=delta
		var beat:int=floori((rhythm.clock-1.4)/0.625)
		if beat!=rhythm.last and beat>=0:
			if rhythm.last>=0 and not rhythm.hit:rhythm.misses+=1
			rhythm.last=beat;rhythm.hit=false;sound("beat")
			for i in rhythm_lights.size():rhythm_lights[i].visible=i==beat%rhythm_lights.size()
		if beat>=16:finish_rhythm(false)
		else:m.prompt.text="F 跟随地面节拍 · %d / 16 · 命中 %d · Esc 退出"%[maxi(0,beat+1),rhythm.hits]
	timer+=delta
	if timer<0.18:return
	timer=0
	if rhythm.is_empty():
		f_target=nearest_kinds(["bay_activity","bay_pick","bay_vehicle","bay_boat","bay_flower","bay_moored","life_house","life_farm","life_pasture","life_pool","redesign","dual106","bay_public_boat","creative110"],4.2)
		if not vehicles.mounted.is_empty():m.prompt.text="F 下车 · X 按铃 · 空格刹车 · %.0f m/s"%absf(vehicles.speed)
		elif boats!=null and not boats.kind.is_empty():m.prompt.text="F 靠岸 · X 观景姿态 · W/S 航速 · A/D 转向"
		elif not f_target.is_empty():m.prompt.text+="\nF "+str(f_target.title)+"   X 姿态 / 就近落座"
	update_audio()
	update_home_object()
	update_scenery()
	if m.player.enabled and m.player.is_on_floor() and m.player.velocity.length()>2 and vehicles.mounted.is_empty() and (boats==null or boats.kind.is_empty()):
		gait_time+=0.18
		if gait_time>0.33:gait_time=0;sound("step_"+step_surface(),true)
	update_itinerary()

func add_block(parent:Node3D,p:Vector3,size:Vector3,tone:String)->MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh;var mat:=StandardMaterial3D.new();mat.albedo_color=Color(tone);mat.roughness=0.85;n.material_override=mat;parent.add_child(n);n.position=p;return n

func refresh_hand():
	if is_instance_valid(hand):hand.queue_free()
	hand=Node3D.new();hand.name="HeldTravelObject";m.player.figure.add_child(hand);hand.position=Vector3(0.38,1.0,-0.35)
	match str(m.state.get("handheld","natural")):
		"drink":
			var recipe:Array=m.state.activities.get("drink",[0,0]);var tone:String=["786044","bc9670","d5b354"][clampi(int(recipe[0]),0,2)]
			add_block(hand,Vector3.ZERO,Vector3(0.17,0.22,0.17),"eee0c4");add_block(hand,Vector3(0,0.115,0),Vector3(0.14,0.025,0.14),tone)
		"bouquet":
			for i in 7:
				add_block(hand,Vector3(sin(i*2.2)*0.08,0.07,cos(i*2.2)*0.07),Vector3(0.025,0.27,0.025),"6c8656")
				add_block(hand,Vector3(sin(i*2.2)*0.12,0.23+i%2*0.05,cos(i*2.2)*0.12),Vector3(0.13,0.16,0.13),bouquet_palette()[i%bouquet_palette().size()])
			var wrap:int=clampi(int(m.state.activities.get("bouquet_wrap",0)),0,2)
			for side in [-1,1]:
				add_block(hand,Vector3(side*.1,-.01,0),Vector3(.025,.22,.25),["b99567","f3eadd","b5ab8e"][wrap]).rotation.z=-side*.32
			add_block(hand,Vector3(0,-.04,-.13),Vector3(.24,.025,.025),["876a50","c7adbb","947f5a"][wrap])
		"headphones":
			hand.position=Vector3(0,1.56,0)
			for side in [-1,1]:add_block(hand,Vector3(side*.24,0,0),Vector3(.13,.26,.19),"586569")
			add_block(hand,Vector3(0,.27,0),Vector3(.52,.10,.15),"d1c5a9")
		"guitar":
			hand.position=Vector3(-.07,.88,-.24);hand.rotation.z=.20
			add_block(hand,Vector3(0,0,0),Vector3(.38,.47,.15),"be935f");add_block(hand,Vector3(.11,.34,0),Vector3(.10,.48,.09),"7b5b40")
			for i in 5:add_block(hand,Vector3(.06+i*.015,.14,-.082),Vector3(.008,.60,.009),"dcc9a0")
		"camera":add_block(hand,Vector3.ZERO,Vector3(0.26,0.16,0.12),"4b6056");add_block(hand,Vector3(0,0,-0.08),Vector3(0.11,0.11,0.09),"b4b49e")
		"sit":m.player.sit_at(m.player.position,m.player.yaw)
	vehicles.update_basket()

func open_activity(id:String):
	match id:
		"arrival":
			m.open_modal("海风站 · 准备启程");m.label(m.modal_box,"领一份导览，沿海湾或上山去旅行。",25)
			m.button(m.modal_box,"领取导览与站章",func():
				if "Z01" not in m.state.stamps:m.state.stamps.append("Z01")
				m.state.activities.arrival=true;m.save_game(false);m.show_map())
		"drink":drink()
		"tea":tea()
		"flowers":flower_form()
		"playlist":playlist()
		"exhibition":
			m.show_gallery();m.label(m.modal_box,"采光百叶",22)
			var slider:=HSlider.new();slider.min_value=0;slider.max_value=70;slider.value=float(m.state.activities.get("blinds",0));m.modal_box.add_child(slider)
			slider.value_changed.connect(func(v):m.state.activities.blinds=v;set_louvers(v))
		"cinema":
			m.open_modal("星幕影院 · 室内与星空外幕");m.label(m.modal_box,"内厅与外幕共用同一影片进度。",24)
			m.button(m.modal_box,"内厅节目册",func():m.show_program_selector("B06",false))
			m.button(m.modal_box,"星空外幕节目册",func():m.show_program_selector("B06_OUT",false))
		"wish":details.wish()
		"journal":details.journal()
		"rhythm":start_rhythm()
		"mix":mix_form()
		"show":show_form()
		"craft":craft_form()
		"decorate":decorate()
		"itinerary":itinerary_form()
		"sand":sand_form()

func chooser(parent:Node,names:Array)->OptionButton:
	var control:=OptionButton.new();control.custom_minimum_size=Vector2(650,44);parent.add_child(control)
	for text in names:control.add_item(text)
	return control

func drink():
	m.open_modal("暖木咖啡馆 · 冲泡一杯")
	m.label(m.modal_box,"选择基底与配料，再到吧台前完成冲泡。",24)
	var base:OptionButton=chooser(m.modal_box,["手冲咖啡","鲜奶拿铁","柑橘气泡水"])
	var topping:OptionButton=chooser(m.modal_box,["原味","香草","桂花"])
	m.button(m.modal_box,"开始冲泡",func():
		var recipe:Array=[base.selected,topping.selected]
		if m.creative!=null and not m.creative.items.can_afford({"beans":1}):m.notify("先到风物材料街屋旁采集一份咖啡豆。");return
		m.close_modal()
		await perform("brew",2.4,func():
			if m.creative!=null and not m.creative.consume("beans",1):return
			m.state.activities.drink=recipe
			if m.creative!=null:m.creative.legacy_output("legacy_drink",{"base":recipe[0],"topping":recipe[1]})
			else:m.state.handheld="drink";refresh_hand()
			m.notify("饮品已装杯并放进背包，可手持或摆到桌面。")))
	m.button(m.modal_box,"翻看生活相册",func():album("B02"))

func tea():
	m.open_modal("云间茶寮 · 山风一盏")
	var leaves:OptionButton=chooser(m.modal_box,["清香绿茶","桂花乌龙","暖焙红茶"])
	m.button(m.modal_box,"选茶 · 注水 · 等待",func():
		var selection:int=leaves.selected
		if m.creative!=null and not m.creative.items.can_afford({"tea_leaf":1}):m.notify("先到茶芽采集点收一份茶叶。");return
		m.close_modal()
		await perform("tea",3.8,func():
			if m.creative!=null and not m.creative.consume("tea_leaf",1):return
			m.state.activities.tea=selection;m.state.activities.tea_lamp=true
			if m.creative!=null:m.creative.legacy_output("legacy_drink",{"tea":selection})
			else:m.state.handheld="drink";refresh_hand()
			m.notify("茶已沏好，作品已放进背包，茶桌暖灯亮起。")))
	m.button(m.modal_box,"点亮 / 熄灭茶桌风灯",func():m.state.activities.tea_lamp=not m.state.activities.get("tea_lamp",false);m.save_game(false))

func bouquet_palette()->Array:
	var selected:Array=m.state.activities.get("bouquet_colors",[])
	if selected.is_empty():return [["cbb0ce"],["edcea3"],["b9c49a"]][clampi(int(m.state.bouquet),0,2)]
	var tones:Array=m.world.layout.config.flower_hill.colors;var result:Array=[]
	for color in selected:result.append(tones[clampi(int(color),0,4)])
	return result

func bouquet_label()->String:
	var colors:Array=m.state.activities.get("bouquet_colors",[])
	if colors.size()>=5:return "五彩花束 · 粉 / 黄 / 蓝 / 紫 / 白"
	if colors.size()==2:return "双色花束"
	if colors.size()==1:return ["春樱粉花束","金盏黄花束","绣球蓝花束","薰衣草紫花束","雪浪白花束"][clampi(int(colors[0]),0,4)]
	return ["淡紫花束","暖杏花束","林间绿色"][clampi(int(m.state.bouquet),0,2)]

func flower_form():
	m.open_modal("溪谷花房 · 五彩花束")
	m.label(m.modal_box,"从花丘采摘后，选择主色、混植配色与包装。旧三种花束继续保留。",23)
	var colors:OptionButton=chooser(m.modal_box,["春樱粉","金盏黄","绣球蓝","薰衣草紫","雪浪白"])
	var arrangement:OptionButton=chooser(m.modal_box,["同色花束","双色混合","五彩花束"])
	var paper:OptionButton=chooser(m.modal_box,["牛皮纸","暖白纱","细麻布"])
	m.button(m.modal_box,"扎束并带走 · 花材 × 1",func():
		if int(m.state.inventory.get("flower",0))<1:m.notify("先到花丘或花房旁采摘花材。");return
		var chosen:Array=[colors.selected] if arrangement.selected==0 else [colors.selected,(colors.selected+2)%5] if arrangement.selected==1 else [0,1,2,3,4]
		var wrap:int=paper.selected;m.close_modal()
		await perform("flowers",2.2,func():
			if m.creative!=null:
				if not m.creative.consume("flower",1):return
			else:m.state.inventory.flower=int(m.state.inventory.flower)-1
			m.state.bouquet=int(chosen[0])%3;m.state.activities.bouquet_colors=chosen;m.state.activities.bouquet_wrap=wrap
			if m.creative!=null:m.creative.legacy_output("legacy_bouquet",{"colors":bouquet_palette(),"wrap":wrap})
			else:m.state.handheld="bouquet";refresh_hand()
			m.notify("花束已扎好，可放进车篮或带回小屋。")))

func perform(id:String,duration:float,commit:Callable):
	if foreground_busy:return
	foreground_busy=true;busy_token+=1;var token:int=busy_token
	clear_effect();effect=Node3D.new();add_child(effect);effect.position=m.player.position+Basis(Vector3.UP,m.player.yaw)*Vector3(0,0,-1)
	var prop:MeshInstance3D=add_block(effect,Vector3(0,1.0,0),Vector3(0.35,0.25,0.35),"c6aa7a")
	var elapsed:=0.0
	while elapsed<duration:
		await get_tree().process_frame
		if token!=busy_token or not m.active_game:clear_effect();foreground_busy=false;return
		if m.modal.visible or m.environment_controls.overview:continue
		elapsed+=get_process_delta_time();prop.rotation.y=sin(elapsed*3)*0.2;prop.position.y=1.0+sin(elapsed*4)*0.08
		m.prompt.text="正在"+{"brew":"冲泡与装杯","tea":"注水候茶","flowers":"搭配与扎束","craft":"装配与打磨","sand":"堆筑沙景"}.get(id,"制作")+" · %d%% · Esc 取消"%int(minf(1,elapsed/duration)*100)
		sound("pour" if id in ["brew","tea"] else "craft_hit") if int(elapsed*5)%5==0 and not fx.playing else null
	clear_effect();foreground_busy=false;commit.call();m.save_game(false)

func clear_effect():
	if is_instance_valid(effect):effect.queue_free()
	effect=null

func pick(action:Dictionary):
	if m.creative!=null:m.creative.renewable_pick(action);return
	var picked:Array=m.state.activities.get("picked",[])
	if action.id in picked:m.notify("这处材料已经收集过。新的旅行仍可自由探索。");return
	var key:String=action.data.get("material","flower")
	picked.append(action.id);m.state.activities.picked=picked;m.state.inventory[key]=int(m.state.inventory.get(key,0))+1
	if key=="flower":
		var colors:Dictionary=m.state.inventory.get("flower_colors",{});var color:String=str(action.data.get("color",0));colors[color]=int(colors.get(color,0))+1;m.state.inventory.flower_colors=colors
	sound("cup");m.save_game(false);m.notify("已收集 "+{"shell":"贝壳","pinecone":"松果","flower":"多色花材","conch":"星光海螺"}.get(key,key)+" × 1")

func playlist():
	m.open_modal("花音唱片 · 随身歌单")
	m.label(m.modal_box,"步行和骑行时继续播放；影片、试听和混音会暂时取得播放权。",23)
	for program in m.programs:
		if str(program.get("audio","")).is_empty():continue
		var id:String=program.asset_id
		m.button(m.modal_box,("移出歌单 · " if id in m.state.playlist else "加入歌单 · ")+str(program.get("display_title",program.title)),func():
			if id in m.state.playlist:m.state.playlist.erase(id)
			else:m.state.playlist.append(id)
			m.save_game(false);playlist())
	var row:=HBoxContainer.new();m.modal_box.add_child(row)
	m.button(row,"播放 / 暂停",func():
		if music.stream!=null:music.stream_paused=not music.stream_paused
		else:next_song())
	m.button(row,"下一首",next_song)
	m.button(row,"首曲移到队尾",func():
		if m.state.playlist.size()>1:m.state.playlist.append(m.state.playlist.pop_front());m.save_game(false);playlist())

func next_song():
	if m.state.playlist.is_empty():music.stop();music.stream=null;return
	playlist_cursor=posmod(playlist_cursor,m.state.playlist.size());var id:String=m.state.playlist[playlist_cursor];playlist_cursor+=1
	var record:Dictionary=m.program_for(id)
	if not record.is_empty() and ResourceLoader.exists("res://"+str(record.get("audio",""))):music.stream=load("res://"+record.audio);music.stream_paused=false;music.play()

func update_audio():
	var venue:String=m.world.inside_building(m.player.position)
	var main_media:bool=m.audio_player.playing or m.video.is_playing()
	var mixing:bool=mix_enabled and venue=="B09"
	if main_media or mixing:
		if music.playing and not music.stream_paused:music.stream_paused=true;playlist_paused_by_media=true
	elif playlist_paused_by_media:music.stream_paused=false;playlist_paused_by_media=false
	for a in mix_players:a.stream_paused=not mixing or main_media
	var desired:String={"B01":"arrival","B02":"cafe","B04":"garden","B05":"gallery","B07":"book","B11":"craft","B03":"records","B09":"studio","B13":"visitor","B08":"rehearsal","B10":"stage","B12":"home","B06":"sea_room"}.get(venue,"")
	if m.player.position.distance_to(m.world.layout.vector([-20,73.5,-396]))<18:desired="tea"
	if main_media or mixing or (music.playing and not music.stream_paused):desired=""
	if desired!=local_music:
		local_music=desired;ambience.stop()
		if m.world.layout.venues.has(venue):
			var at:Dictionary=m.world.layout.venues[venue];ambience.position=Vector3(at.x,at.floor_y+1.5,at.z)
		else:ambience.position=m.world.layout.vector([-20,73.5,-396])+Vector3(0,1.5,0)
		if not desired.is_empty():
			var stream:AudioStreamWAV=load("res://assets/audio/bay/"+desired+".wav").duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate);ambience.stream=stream;ambience.play()

func mix_form():
	m.open_modal("回声工作室 · 四轨原创创作台")
	m.label(m.modal_box,"钢琴、原声低音乐器、弦乐与自然声，96 BPM，共用 32 拍循环。原曲在 E 试听台单独播放。",23)
	for i in 4:
		var index:int=i;var volume:float=float(m.state.mix_recipe.get(str(i),0.65))
		m.label(m.modal_box,["钢琴","原声低音乐器","弦乐","自然声"][i],21)
		var slider:=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.01;slider.value=volume;m.modal_box.add_child(slider)
		slider.value_changed.connect(func(value):m.state.mix_recipe[str(index)]=value;mix_players[index].volume_db=linear_to_db(maxf(0.0001,value))-9)
	var row:=HBoxContainer.new();m.modal_box.add_child(row)
	m.button(row,"同步播放四轨",start_mix)
	m.button(row,"停止",func():
		mix_enabled=false
		for a in mix_players:a.stop())
	m.button(row,"保存配方",func():m.state.activities.mix=true;m.save_game(false);m.notify("四轨配方已保存。"))

func start_mix():
	m.stop_media("four_track_mix")
	for i in 4:
		var stream:AudioStreamWAV=load("res://assets/audio/bay/mix_"+str(i)+".wav").duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate)
		var studio:Dictionary=m.world.layout.venues.B09;mix_players[i].position=Vector3(studio.x-4,studio.floor_y+1.0,studio.z+1)
		mix_players[i].stop();mix_players[i].stream=stream;mix_players[i].stream_paused=false;mix_players[i].volume_db=linear_to_db(maxf(.0001,float(m.state.mix_recipe.get(str(i),.65))))-9
	for a in mix_players:a.play(0)
	mix_enabled=true

func journal():
	m.open_modal("拾光书房 · 山海手札")
	m.label(m.modal_box,"旅人手札是项目原创。沿溪谷花丘到上游码头，再从海湾乘船去珊瑚岛；山顶茶寮仍向所有旅人开放。",25)
	m.button(m.modal_box,"收起手札并标记溪谷路线",func():m.state.activities.journal=true;m.target_zone=m.world.spec.zones[6];m.save_game(false);m.close_modal();m.notify("手札线索已记入地图：花间溪谷。"))
	m.button(m.modal_box,"继续翻阅原 PB",func():m.show_pb(int(m.state.pb_page)))
	m.button(m.modal_box,"旅行相册",func():album("B07"))

func start_rhythm():
	if not rhythm.is_empty():return
	m.close_modal();rhythm={"clock":0.0,"last":-1,"hit":false,"hits":0,"misses":0,"errors":[]};rhythm_lights=[]
	var item:Dictionary=m.world.layout.venues.B08
	for i in 4:
		var node:MeshInstance3D=add_block(self,Vector3(item.x-4.5+i*3,item.floor_y+0.13,item.z),Vector3(1.1,0.04,1.1),"ecd898");node.visible=false;rhythm_lights.append(node)
	m.notify("跟随地面灯光按 F，共 16 拍。Esc 可退出。")

func tap_rhythm():
	var clock:float=rhythm.clock-1.4
	var nearest:int=roundi(clock/0.625)
	var error:float=absf(clock-nearest*0.625)
	if nearest>=0 and nearest<16 and error<0.19 and nearest not in rhythm.errors:
		rhythm.errors.append(nearest);rhythm.hits+=1;rhythm.hit=true;sound("cup")

func finish_rhythm(cancelled:bool):
	if rhythm.is_empty():return
	if not cancelled:m.state.activities.rhythm_best=maxi(int(m.state.activities.get("rhythm_best",0)),int(rhythm.hits));m.save_game(false);m.notify("节拍练习完成 · 命中 %d / 16"%int(rhythm.hits))
	else:m.notify("已退出节拍练习。")
	for node in rhythm_lights:node.queue_free()
	rhythm_lights=[];rhythm={}

func show_form():
	m.open_modal("星光演艺厅 · 三段灯光编排")
	var controls:Array=[]
	var sequence:Array=m.state.activities.get("light_sequence",[0,1,2])
	for i in 3:
		var option:OptionButton=chooser(m.modal_box,["暖金与海蓝","淡紫与青光","月白与晚霞"]);option.select(int(sequence[i]));controls.append(option)
	m.button(m.modal_box,"保存并启动编排",func():
		m.state.activities.light_sequence=[controls[0].selected,controls[1].selected,controls[2].selected];light_show=true;light_clock=0;m.save_game(false);m.close_modal())
	m.button(m.modal_box,"停止编排",func():light_show=false;m.world.set_venue_lighting("B10",0))

func craft_form():
	m.open_modal("星笺手作 · 把旅途带回家")
	m.label(m.modal_box,"采集点会在线恢复。每次制作产生一件独立作品，材料按实际数量扣除。",23)
	for item in [["windchime","贝壳风铃","shell",2],["lamp","松果桌灯","pinecone",2],["frame","旅行相框","shell",1],["conchbox","海螺八音盒","conch",2]]:
		var recipe:Array=item
		m.button(m.modal_box,recipe[1]+" · "+str(recipe[3])+" 份材料",func():
			var crafted:Array=m.state.activities.get("crafted",[])
			if int(m.state.inventory.get(recipe[2],0))<int(recipe[3]):m.notify("材料不足，请到海岸拾贝或山林拾松果。");return
			m.close_modal();await perform("craft",2.5,func():
				if m.creative!=null:
					if not m.creative.consume(str(recipe[2]),int(recipe[3])):return
				else:m.state.inventory[recipe[2]]=int(m.state.inventory[recipe[2]])-int(recipe[3])
				if recipe[0] not in crafted:crafted.append(recipe[0])
				m.state.activities.crafted=crafted
				if m.creative!=null:m.creative.legacy_output("legacy_"+str(recipe[0]))
				else:m.state.activities.home_object=recipe[0];m.state.handheld="craft";refresh_hand()
				m.notify("手作完成，可在背包选择并带回小屋陈列。")))

func decorate():
	m.show_home()
	m.button(m.modal_box,"三个独立槽位与全屋灯光",func():workshops.slot_panel("B12"))
	m.button(m.modal_box,"把背包花束插入花瓶",func():m.creative.place_legacy_home_vase() if m.creative!=null else null)
	m.button(m.modal_box,"从背包选择作品布置",func():m.creative.open_bag() if m.creative!=null else null)

func update_home_object():
	if not is_instance_valid(m.world.home_picture):home_parent=0;return
	var parent:Node=m.world.home_picture.get_parent()
	var signature:String=str(parent.get_instance_id())+":"+str(m.state.activities.get("home_object",""))+":"+str(m.state.get("home_photo",0))+":"+str(m.state.get("home_light",0))
	if home_parent==parent.get_instance_id() and signature==ornament_signature:return
	home_parent=parent.get_instance_id();ornament_signature=signature
	if is_instance_valid(ornament):ornament.queue_free()
	var type:String=m.state.activities.get("home_object","")
	if type.is_empty():return
	if m.creative!=null and not m.creative.legacy_display_active("legacy_home_object"):return
	ornament=Node3D.new();parent.add_child(ornament);var v:Dictionary=m.world.layout.venues.B12;ornament.position=Vector3(v.x+4,v.floor_y+1.2,v.z+1)
	if type=="lamp":
		add_block(ornament,Vector3(0,.06,0),Vector3(.32,.12,.30),"8d7355");add_block(ornament,Vector3(0,.28,0),Vector3(.08,.45,.08),"94755b")
		add_block(ornament,Vector3(0,.53,0),Vector3(.48,.27,.40),"ddbd7c")
		var lamp:=OmniLight3D.new();lamp.position=Vector3(0,.47,0);lamp.light_color=Color("ffbd76");lamp.light_energy=0 if int(m.state.get("home_light",0))==2 else .6;lamp.omni_range=3.4;lamp.shadow_enabled=false;ornament.add_child(lamp)
	elif type=="frame":
		add_block(ornament,Vector3(0,.25,0),Vector3(.65,.5,.08),"8d7355")
		var picture:=MeshInstance3D.new();var page:=QuadMesh.new();var texture:Texture2D=load("res://"+m.assets[int(m.state.home_photo)%m.assets.size()].runtime_path);var ratio:float=float(texture.get_width())/texture.get_height()
		page.size=Vector2(minf(.54,.40*ratio),minf(.40,.54/ratio));picture.mesh=page;picture.position=Vector3(0,.25,.05)
		var material:=StandardMaterial3D.new();material.albedo_texture=texture;material.roughness=.9;picture.material_override=material;ornament.add_child(picture)
	else:
		add_block(ornament,Vector3(0,.6,0),Vector3(.65,.08,.14),"8d7355")
		for i in 3:add_block(ornament,Vector3((i-1)*.22,.3-i%2*.1,0),Vector3(.12,.35,.06),"ead9b8")

func itinerary_form():
	m.open_modal("游客中心 · 自选三站行程")
	var names:Array=[]
	for v in m.world.spec.buildings:names.append(v.name)
	var choices:Array=[]
	for i in 3:choices.append(chooser(m.modal_box,names));choices[i].select([2,6,11][i])
	m.button(m.modal_box,"生成行程",func():
		var stops:Array=[]
		for c in choices:
			var id:String=m.world.spec.buildings[c.selected].id
			if id not in stops:stops.append(id)
		m.state.itinerary=stops;m.state.activities.itinerary_done=[];m.save_game(false);m.close_modal();m.notify("已生成行程，左上角会显示下一站。"))
	m.button(m.modal_box,"取消行程",func():m.state.itinerary=[];m.save_game(false);m.close_modal())

func update_itinerary():
	if m.state.get("itinerary",[]).is_empty():return
	var id:String=m.state.itinerary[0];var v:Dictionary=m.world.layout.venues[id]
	var distance:float=Vector2(m.player.position.x-v.x,m.player.position.z-v.z).length()
	m.zone_label.text+="\n行程下一站："+str(v.name)+" · %d m"%int(distance)
	if m.world.inside_building(m.player.position)==id:
		m.state.itinerary.pop_front();m.notify("已抵达 "+str(v.name));m.save_game(false)

func sand_form():
	m.open_modal("潮汐沙景 · 三处有限摆位")
	var style:OptionButton=chooser(m.modal_box,["小城堡","贝壳小路","星形沙丘"])
	m.button(m.modal_box,"开始堆筑",func():var selected:int=style.selected;m.close_modal();await perform("sand",2.1,func():m.state.activities.sand=selected;m.notify("沙景已完成，保存在这次旅行中。")))

func make_louvers():
	var v:Dictionary=m.world.layout.venues.B05
	for side in [-1,1]:
		for i in 8:
			var node:MeshInstance3D=add_block(self,Vector3(v.x+side*(v.w*0.5+.35),v.floor_y+1.4+i*.23,v.z),Vector3(.3,.15,v.d-1),"788c79");louvers.append(node)

func set_louvers(degrees:float):
	for node in louvers:node.rotation.z=deg_to_rad(degrees)

func album(venue:String):
	m.open_modal("生活与工作 · 本地影像相册",1240)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1120,650);m.modal_box.add_child(scroll);var row:=HBoxContainer.new();scroll.add_child(row)
	for record in life_media:
		if record.venue!=venue:continue
		var col:=VBoxContainer.new();row.add_child(col);var tex:=TextureRect.new();tex.texture=load("res://"+record.runtime_path);tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tex.custom_minimum_size=Vector2(650,510);col.add_child(tex)
		m.label(col,record.category+" · "+record.publisher+"\n制作日期："+record.archive_publish_time+"\n原创演示画作，许可为 MIT。",21)
		m.button(col,"查看素材说明",func():OS.shell_open(record.post_url))

func update_scenery():
	if tea_light!=null:tea_light.light_energy=.8 if m.state.activities.get("tea_lamp",false) else 0
	if creek_tea_light!=null:creek_tea_light.light_energy=.55 if m.state.activities.get("tea_lamp",false) else 0
	var selection:int=int(m.state.activities.get("sand",-1))
	if sand_style==selection:return
	sand_style=selection
	if is_instance_valid(sand_model):sand_model.queue_free()
	if selection<0:return
	sand_model=Node3D.new();add_child(sand_model);sand_model.position=m.world.surface(72,m.world.layout.shore_z(72)-9)
	if selection==0:
		add_block(sand_model,Vector3(0,.3,0),Vector3(1.6,.6,1.3),"d4bc8f")
		for x in [-.8,.8]:
			for z in [-.65,.65]:
				add_block(sand_model,Vector3(x,.5,z),Vector3(.5,1,.5),"d4bc8f")
	elif selection==1:
		for i in 12:
			var p:=Vector3(sin(i*.5)*.65,.07,(i-5.5)*.32)
			add_block(sand_model,p,Vector3(.28,.14,.22),"e8d7b9").rotation.y=i*.32
	else:
		for arm in 5:
			var angle:float=arm*TAU/5
			for step in 4:
				var p:=Vector3(sin(angle)*step*.28,.1+(3-step)*.04,cos(angle)*step*.28)
				add_block(sand_model,p,Vector3(.35,.2+(3-step)*.08,.35),"d4bc8f")

func reset_session():
	busy_token+=1;foreground_busy=false;clear_effect();finish_rhythm(true);light_show=false
	vehicles.dismount(true);animals.reset();m.player.pet_until_msec=0
	if boats!=null:boats.leave_for_travel()
	music.stop();music.stream=null;ambience.stop();local_music="";mix_enabled=false
	for audio in mix_players:audio.stop()
