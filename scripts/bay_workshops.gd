extends Node3D
## All new crafting and mechanical interactions use ordinary E/F/X paths and persistent visible results.
const HOUSE_TOPICS={"H01":"bread","H02":"harvest","H03":"frame","H04":"fruit","H05":"scope","H06":"chime","H07":"fire","H08":"specimen","H09":"cloth","H10":"seal","H11":"musicbox","H12":"darkroom","H13":"press","H14":"coffee"}
const PALETTE=["38b2c4","f4b8c4","4a5d6b"]
var m
var models:Dictionary={}
var anchors:Dictionary={}
var signature:=""
var clock:=0.0
var tick:=0.0
var wheel:Node3D
var sluice:Node3D
var gate:StaticBody3D
var flow:Node3D
var pasture_gate:StaticBody3D
var levers:Array=[]
var curtain:Node3D
var frame_overlay:Control
var scope_camera:Camera3D
var scope_active:=false
var frame_active:=false
var motion_until:Dictionary={}
var hand_prop:Node3D
var hand_signature:=""
var smoke:Node3D
var streams:Array=[]
var stage_lights:Array=[]
var furnace_light:OmniLight3D
var yard_cat:Dictionary={}

func setup(main):
	m=main
	for h in m.world.layout.config.living_houses:anchors[h.id]=m.world.layout.vector(h.center)
	for h in m.world.layout.config.cliff_district.buildings:anchors[h.id]=Vector3(h.center[0],h.center[1],h.center[2])
	for wing in m.world.layout.config.street_wings:anchors["wing_"+wing.id]=m.world.layout.vector(wing.center)+Vector3(wing.size[0]*.30,0,wing.size[1]*.2)
	mechanisms()
	scope_camera=Camera3D.new();scope_camera.name="BrassTelescopeCamera";scope_camera.near=.2;scope_camera.far=3000;add_child(scope_camera)
	frame_overlay=Control.new();frame_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);m.ui.add_child(frame_overlay);frame_overlay.hide()
	for i in 4:
		var border:=ColorRect.new();border.name="FrameEdge"+str(i);border.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame_overlay.add_child(border)

func data()->Dictionary:
	if not m.state.activities.get("workshops105") is Dictionary:m.state.activities.workshops105={}
	var d:Dictionary=m.state.activities.workshops105
	if not d.get("slots") is Dictionary:d.slots={}
	if not d.get("pottery") is Dictionary:d.pottery={"stage":0,"shape":0,"glaze":0}
	if not d.get("racks") is Array:d.racks=[null,null,null,null,null,null]
	if not m.state.activities.get("island_02_state") is Dictionary:m.state.activities.island_02_state={"enabled":false,"schema":1,"visited":false}
	return d

func root_for(id:String,at:Vector3)->Node3D:
	var node:=Node3D.new();node.name=id;node.position=at;add_child(node);models[id]=node;return node
func block(parent:Node3D,p:Vector3,size:Vector3,tone:String):return m.bay.add_block(parent,p,size,tone)
func cylinder(parent:Node3D,p:Vector3,r:float,height:float,tone:String)->MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r*.8;mesh.height=height;mesh.radial_segments=16;node.mesh=mesh;var mat:=StandardMaterial3D.new();mat.albedo_color=Color(tone);mat.roughness=.7;node.material_override=mat;parent.add_child(node);node.position=p;return node
func physical_box(parent:Node3D,p:Vector3,size:Vector3,tone:String)->StaticBody3D:
	var body:=StaticBody3D.new();parent.add_child(body);body.position=p;block(body,Vector3.ZERO,size,tone);var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);return body
func wheel_model(parent:Node3D,radius:float,depth:float)->Node3D:
	var node:=Node3D.new();parent.add_child(node)
	for i in 24:
		var angle:float=i*TAU/24;block(node,Vector3(0,sin(angle)*radius,cos(angle)*radius),Vector3(depth,.22,.65),"9c7952").rotation.x=-angle
	for i in 8:
		var angle:float=i*TAU/8;block(node,Vector3.ZERO,Vector3(depth*.5,radius*2,.15),"5e4232").rotation.x=angle
	return node
func mechanisms():
	var cfg:Dictionary=m.world.layout.config.cliff_district
	wheel=wheel_model(self,2.25,1.45);wheel.position=Vector3(cfg.waterwheel[0],cfg.waterwheel[1],cfg.waterwheel[2])
	sluice=wheel_model(self,.62,.22);sluice.position=anchors.Z09_B5+Vector3(0,1.2,1.2);sluice.rotation.z=PI*.5
	gate=physical_box(self,Vector3(cfg.gate[0],cfg.gate[1]+1.7,cfg.gate[2]),Vector3(.55,3.4,3.15),"8c857b")
	flow=Node3D.new();add_child(flow)
	for i in cfg.water_course.size()-1:
		var a:Array=cfg.water_course[i];var c:Array=cfg.water_course[i+1];var start:=Vector3(a[0],a[1],a[2]);var end:=Vector3(c[0],c[1],c[2]);var direction:Vector3=(end-start).normalized()
		streams.append({"a":start,"c":end,"node":block(flow,start,Vector3(.7,.17,.45),"c5f5e8")})
		var node:MeshInstance3D=block(flow,(start+end)*.5,Vector3(1.1,.14,start.distance_to(end)),"7ce0d3");node.basis=Basis.looking_at(direction,Vector3.FORWARD if absf(direction.y)>.9 else Vector3.UP)
	smoke=Node3D.new();add_child(smoke);smoke.position=anchors.Z09_B2+Vector3(4,3.4,-4.45)
	for i in 8:
		var puff:MeshInstance3D=block(smoke,Vector3.ZERO,Vector3(.4,.4,.4),"d8d4c9");puff.material_override=puff.material_override.duplicate();puff.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;puff.material_override.albedo_color.a=.20
	var pasture:Vector3=m.world.layout.vector(m.world.layout.config.pasture.center)
	pasture_gate=physical_box(self,pasture+Vector3(-1.7,.65,20),Vector3(.13,1.3,.13),"5e4232")
	for y in [-.25,.25]:block(pasture_gate,Vector3(1.7,y,0),Vector3(3.4,.15,.15),"ad8e60")
	var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(3.4,1.2,.15);col.shape=shape;col.position.x=1.7;pasture_gate.add_child(col)
	var stage:Dictionary=m.world.layout.venues.B10
	for i in 3:
		var lever:=Node3D.new();add_child(lever);lever.position=Vector3(stage.x+10+i*.65,stage.floor_y+1.2,stage.z+6);levers.append(lever)
		block(lever,Vector3(0,.28,0),Vector3(.07,.55,.07),"bfa777");block(lever,Vector3(0,.56,0),Vector3(.25,.14,.14),["dbba70","b5a1c9","8db8ba"][i])
	for i in 3:
		var spot:=SpotLight3D.new();add_child(spot);spot.position=Vector3(stage.x-8+i*8,stage.floor_y+7,stage.z-10);spot.spot_range=20;spot.spot_angle=25;spot.shadow_enabled=false;spot.light_energy=1.7;stage_lights.append(spot)
	curtain=Node3D.new();add_child(curtain);curtain.position=Vector3(stage.x,stage.floor_y+4,stage.z-12.2)
	for i in 12:block(curtain,Vector3(-10+i*1.8,0,0),Vector3(1.82,6,.15),"687f9b")
	for i in 32:block(curtain,Vector3(sin(i*2.39)*9,cos(i*2.1)*2.5,.13),Vector3(.11,.11,.06),"e6ca8c")
	furnace_light=OmniLight3D.new();add_child(furnace_light);furnace_light.position=anchors.H07+Vector3(0,1.4,-3.5);furnace_light.omni_range=10;furnace_light.light_color=Color("ffba72");furnace_light.shadow_enabled=false

func house(h:Dictionary):open_action(HOUSE_TOPICS[h.id])
func open_action(topic:String,inspect:bool=false):
	var d:Dictionary=data()
	if topic in ["sluice","pasture_gate"] and not inspect:run(topic);return
	if topic=="pottery" and not inspect:pottery_step();return
	if topic.begins_with("lever_"):run("stage",int(topic.trim_prefix("lever_")));return
	if topic.begins_with("clay_"):
		if m.creative!=null:m.creative.collect_legacy_material("RD_"+topic,{"clay":2},120)
		else:run("clay")
		return
	if topic=="cave_stamp":run("cave_stamp");return
	if topic.begins_with("slot:"):
		var parts:PackedStringArray=topic.split(":");
		if inspect or parts.size()<3:slot_panel(parts[1])
		else:place_slot(parts[1],int(parts[2]))
		return
	if topic.begins_with("tour_"):
		tour_panel(topic.trim_prefix("tour_"));return
	if topic.begins_with("upper_"):
		m.open_modal("观景敞廊 · 专属功能角");m.label(m.modal_box,"转动桌上模型可切换构图与陈列，栏边可以俯瞰街景。",23);m.button(m.modal_box,"转动 / 更换陈列",func():run(topic));m.button(m.modal_box,"在这里取景",func():m.close_modal();m.enter_photo_mode());return
	var titles:Dictionary={"bread":"石磨与麦香烤炉","harvest":"农夫种子农具站与农务黑板","frame":"牧场写生与画框装裱","fruit":"柠檬柑橘花果茶","scope":"黄铜望远镜","chime":"编织与贝壳风铃","fire":"松果壁炉","specimen":"溪谷植物图鉴","cloth":"花艺茶席与星光布样","seal":"火漆与旅行手账","musicbox":"发条木偶小剧场","darkroom":"胶片暗房与明信片","press":"干花压花台","coffee":"咖啡豆仓","cat":"猫咪小院","sluice":"崖顶重力水闸","wheel":"水轮木石工坊","pottery":"矿彩陶艺 · E 选择 / F 制作","pottery_rack":"二层屋顶 · 六槽晒架","loom":"骑楼蓝染织机","lookout":"日落观景阁","tea":"半山嵌岩茶室","pasture_gate":"牧场木门","stage_lever":"舞台三联机械控台","pine_chute":"山林松果滑槽","wing_BAKERY":"暖阳牛角包烘焙","wing_LISTENING_WEST":"黑胶封套画报廊","wing_LISTENING_EAST":"留声机维修坊","wing_CRAFT":"海玻璃马赛克拼贴"}
	m.open_modal(titles.get(topic,"山海工坊"))
	match topic:
		"bread":
			m.label(m.modal_box,"小麦 → 石磨面粉 → 烤炉面包篮。成品会留在桌面，材料来自旁边农田。",23)
			choice("磨 1 份小麦成面粉","mill");choice("把面粉送入烤炉","bread")
		"harvest":
			choice("分拣小麦、胡萝卜、玉米与番茄种子","seed_sort")
			choice("分拣胡萝卜与番茄装筐","harvest");choice("翻转今日丰收黑板","harvest_board")
		"frame":
			choice("切换木画框色彩","frame_color");m.button(m.modal_box,"带画框取景拍照",func():m.close_modal();frame_active=true;m.enter_photo_mode());photo_options("framed_shot","装裱上墙")
		"fruit":choice("切片柠檬 · 暖金果茶","fruit",0);choice("切片柑橘 · 琥珀果茶","fruit",1)
		"scope":
			m.button(m.modal_box,"对准珊瑚岛",func():start_scope(Vector3(235,1,450)))
			m.button(m.modal_box,"对准东岬灯塔",func():start_scope(Vector3(360,15,383)))
		"chime":choice("用 2 枚贝壳串风铃","chime");choice("编织吊床挂穗","hammock")
		"fire":choice("添 1 枚松果与木柴","fire")
		"specimen":
			var colors:Dictionary=m.state.inventory.get("flower_colors",{});m.label(m.modal_box,"已识别花色 %d / 5 · 松果 %d · 星光海螺 %d"%[colors.size(),int(m.state.inventory.get("pinecone",0)),int(m.state.inventory.get("conch",0))],23)
			choice("翻开 / 合上标本夹","specimen")
		"cloth":choice("换一条桌旗","cloth");choice("切换星光烛台","candles")
		"seal":choice("熔火漆并盖旅行印章","seal")
		"musicbox":choice("拧动发条，观看木偶转动","musicbox")
		"darkroom":photo_options("printed_shot","冲洗并夹上照片绳");choice("给旅行明信片盖戳并投递","postcard")
		"press":choice("压制干花书签 · 1 份花材","bookmark");choice("浇注香薰蜡牌 · 1 份花材","wax")
		"coffee":choice("摇动磨豆机","coffee");choice("到猫碗放小鱼干","cat")
		"cat":choice("放小鱼干，引猫到院里","cat")
		"sluice":choice("转动青铜手轮 · 开闸 / 关闸","sluice")
		"wheel":m.label(m.modal_box,"水轮由崖顶引水驱动。开闸后沿石槽观察水流，再穿过开启的石门领取鸟巢露台印章。",24);choice("转动工作台传动齿轮","gear")
		"pottery":
			var shapes:OptionButton=m.bay.chooser(m.modal_box,["收口花瓶","矮口陶碗","旅行陶杯"]);shapes.select(int(d.pottery.shape));shapes.item_selected.connect(func(i):d.pottery.shape=i;commit())
			var glazes:OptionButton=m.bay.chooser(m.modal_box,["海青釉","晨曦粉釉","星夜蓝釉"]);glazes.select(int(d.pottery.glaze));glazes.item_selected.connect(func(i):d.pottery.glaze=i;commit())
			m.label(m.modal_box,"采矿泥后关闭面板，按 F 依次拉坯、上釉、入窑烧制；成品可带到二层六槽晒架或 B12。",23)
		"pottery_rack":
			for i in 6:
				var slot:int=i;m.button(m.modal_box,"槽位 %d · %s"%[i+1,"放入手中陶器" if d.racks[i]==null else "取回已陈列陶器"],func():rack_action(slot))
		"loom":choice("织出海风蓝染布","loom")
		"lookout":m.button(m.modal_box,"观海取景",func():m.close_modal();m.enter_photo_mode());choice("点亮观景阁风灯","lookout")
		"tea":m.button(m.modal_box,"选茶与注水",func():m.bay.open_activity("tea"))
		"pasture_gate":choice("推开 / 合上木门","pasture_gate");m.button(m.modal_box,"给羊猪添料",func():m.bay.village.pasture_panel())
		"stage_lever":
			for i in 3:
				choice(["灯架角度与灯色拉杆","星空 / 花海垂幕拉杆","星雨 / 干冰拉杆"][i],"stage",i)
		"pine_chute":choice("让松果滑下木槽","pine_chute")
		"wing_BAKERY":choice("揉面进炉 · 端出可颂","croissant")
		"wing_LISTENING_WEST":choice("翻一页实体封套","sleeve")
		"wing_LISTENING_EAST":choice("转动留声机手摇柄","gramophone")
		"wing_CRAFT":choice("拼海玻璃并点亮桌灯","mosaic")
	if topic in HOUSE_TOPICS.values():m.button(m.modal_box,"布置本屋的三个陈列槽与灯光",func():slot_panel(str(HOUSE_TOPICS.find_key(topic))))

func choice(title:String,action:String,value:int=0):m.button(m.modal_box,title,func():run(action,value))
func consume(item:String,amount:int)->bool:
	if m.creative!=null:
		if m.creative.consume(item,amount):return true
		m.notify("材料不足，请在背包检查"+str(item)+"。");return false
	var count:int=int(m.state.inventory.get(item,0))
	if count<amount:m.notify("材料不足：需要 %d 份%s。"%[amount,{"wheat":"小麦","flour":"面粉","shell":"贝壳","pinecone":"松果","flower":"花材","clay":"矿泥","carrot":"胡萝卜","tomato":"番茄"}.get(item,item)]);return false
	m.state.inventory[item]=count-amount;return true
func run(action:String,value:int=0)->bool:
	var d:Dictionary=data()
	match action:
		"mill":
			if not consume("wheat",1):return false
			if m.creative!=null:m.creative.grant_material("flour",1)
			else:m.state.inventory.flour=int(m.state.inventory.get("flour",0))+1
			d.mill=int(d.get("mill",0))+1
		"bread":
			if not consume("flour",1):return false
			d.bread=int(d.get("bread",0))+1
			if m.creative!=null:m.creative.legacy_output("legacy_bread")
		"harvest":
			if int(m.state.inventory.get("carrot",0))<1 or int(m.state.inventory.get("tomato",0))<1:m.notify("先到农田各收获一份胡萝卜和番茄。");return false
			consume("carrot",1);consume("tomato",1);d.harvest=int(d.get("harvest",0))+1;d.harvest_board=true
			if m.creative!=null:m.creative.legacy_output("legacy_harvest")
		"seed_sort":d.seed_sort=not d.get("seed_sort",false)
		"harvest_board","hammock","specimen","pasture_gate","lookout":d[action]=not d.get(action,false)
		"frame_color","cloth","candles","sleeve","gear","loom","mosaic":d[action]=(int(d.get(action,-1))+1)%3
		"fruit":
			if m.creative!=null:
				if not m.creative.items.consume_cost({"tea_leaf":1,"flower":1}):m.notify("花果茶需要茶叶和花材各一份。");return false
				m.creative.legacy_output("legacy_fruit",{"fruit":value})
			d.fruit=value;d.fruit_ready=true
		"chime":
			if not consume("shell",2):return false
			d.chime=true
			if m.creative!=null:m.creative.legacy_output("legacy_house_chime")
		"fire":
			if not consume("pinecone",1):return false
			d.fire=int(d.get("fire",0))+1
		"seal","postcard","coffee","musicbox","gramophone":d[action]=int(d.get(action,0))+1
		"croissant":
			if not consume("flour",1):return false
			d.croissant=int(d.get("croissant",0))+1
			if m.creative!=null:m.creative.legacy_output("legacy_bread",{"croissant":true})
		"bookmark","wax":
			if not consume("flower",1):return false
			d[action]=int(d.get(action,0))+1
			if m.creative!=null:m.creative.legacy_output("legacy_"+action)
		"cat":
			d.cat=true
			for animal in m.bay.animals.animals:
				if animal.kind=="cat" and animal.home.x< -90 and animal.home.x> -125:yard_cat=animal;break
			if not yard_cat.is_empty():yard_cat["feed_target"]=anchors.H14+Vector3(-3,0,10);yard_cat["feed_until"]=m.bay.animals.clock+24
		"sluice":d.sluice=not d.get("sluice",false)
		"clay":
			if m.creative!=null:m.creative.collect_legacy_material("RD_clay_common",{"clay":2},120)
			else:m.state.inventory.clay=int(m.state.inventory.get("clay",0))+2
			d.clay_collected=int(d.get("clay_collected",0))+1
		"cave_stamp":
			if not d.get("sluice",false):m.notify("先开启水闸，让水轮推动岩洞暗门。");return false
			d.cave_stamp=true
			if "Z09_NEST" not in m.state.cards:m.state.cards.append("Z09_NEST")
		"stage":d["stage_"+str(value)]=(int(d.get("stage_"+str(value),0))+1)%3;m.bay.light_show=true
		"pine_chute":
			if not consume("pinecone",1):return false
			d.pine_chute=int(d.get("pine_chute",0))+1
		_:
			if action.begins_with("upper_"):d[action]=(int(d.get(action,0))+1)%4
			else:return false
	motion_until[action]=clock+(24 if action in ["musicbox","gramophone"] else 4)
	m.close_modal();commit();m.notify("已完成操作，实体变化与陈列已保存。");return true
func commit():signature="";m.save_game(false);refresh()
func photo_options(key:String,label:String):
	if m.state.shots.is_empty():m.label(m.modal_box,"还没有风景照片。P 取景后按 F12 保存，再回这里装裱。",22);return
	for filename in m.state.shots.slice(maxi(0,m.state.shots.size()-6)):
		var shot:String=filename;m.button(m.modal_box,label+" · "+shot.trim_prefix("sea_and_stars_").left(18),func():
			if m.creative!=null:
				if not m.creative.legacy_photo_mount(key,shot):return
			else:data()[key]=shot
			m.close_modal();commit())

func pottery_step():
	var p:Dictionary=data().pottery;var stage:int=int(p.stage)
	if m.creative!=null and stage==3:p.stage=0;stage=0
	if stage==0:
		if not consume("clay",1):return
		p.stage=1;motion_until.pottery=clock+3;m.state.handheld="natural";m.bay.refresh_hand();m.notify("踩下踏板，陶坯已拉成。再次 F 上釉；E 可更换器型与釉色。")
	elif stage==1:p.stage=2;motion_until.glaze=clock+2;m.notify("釉色已涂好，再按 F 送入柴窑烧制。")
	elif stage==2:
		p.stage=4;motion_until.kiln=clock+4;m.notify("陶坯已入柴窑，等待窑烟散去后取出成品。")
	elif stage==4:m.notify("柴窑正在烧制，请等约 4 秒。")
	else:m.notify("手中已有一件成品，先陈列或放入小屋，再制作下一件。")
	commit()
func rack_action(index:int):
	if m.creative!=null:m.creative.legacy_rack_action(index);return
	var d:Dictionary=data();var p:Dictionary=d.pottery
	if d.racks[index]==null:
		if int(p.stage)!=3:m.notify("请先在楼下完成拉坯、上釉、烧制。");return
		d.racks[index]=p.duplicate(true);p.stage=0;m.state.handheld="natural"
	else:
		if int(p.stage)==3:m.notify("先放下手中成品再取回。 ");return
		d.pottery=d.racks[index].duplicate(true);d.racks[index]=null;m.state.handheld="pottery"
	m.bay.refresh_hand();m.close_modal();commit()

func slot_panel(house_id:String):
	var d:Dictionary=data();m.open_modal(house_id+" · 可视化陈列与灯光")
	m.label(m.modal_box,"飘窗花束槽、书桌摆件槽、墙面相框槽互不覆盖；按 F 摆放，空位可随时清理。",23)
	for i in 3:
		var slot:int=i;var key:String=house_id+"_"+str(i)
		m.button(m.modal_box,["飘窗槽 · 放花束","书桌槽 · 放陶器 / 手作","相框槽 · 放最新风景照"][i],func():place_slot(house_id,slot))
		m.button(m.modal_box,"清空槽位 "+str(i+1),func():
			if m.creative!=null and d.slots.has(key) and d.slots[key].has("_creative_uid"):m.creative.items.take(str(d.slots[key]._creative_uid));m.creative.save()
			else:d.slots.erase(key)
			commit();slot_panel(house_id))
	choice_light(house_id)
func choice_light(id:String):
	for i in 4:
		var index:int=i;m.button(m.modal_box,["灯光 · 暖黄","灯光 · 自然白","灯光 · 月白","灯光 · 关闭"][i],func():data()["light_"+id]=index;commit())
func place_slot(house_id:String,slot:int)->bool:
	if m.creative!=null:return m.creative.place_legacy_slot(house_id,slot)
	var d:Dictionary=data();var record:Dictionary={}
	if slot==0:
		if m.state.handheld!="bouquet" and m.state.activities.get("bouquet_colors",[]).is_empty():m.notify("先到花房扎一束花。");return false
		record={"kind":"bouquet","colors":m.bay.bouquet_palette()}
	elif slot==1:
		if int(d.pottery.stage)==3:record={"kind":"pottery","shape":d.pottery.shape,"glaze":d.pottery.glaze};d.pottery.stage=0;m.state.handheld="natural"
		elif not m.state.activities.get("crafted",[]).is_empty():record={"kind":m.state.activities.get("home_object",m.state.activities.crafted.back())}
		else:m.notify("先烧一件陶器，或在 B11 做一件手作。");return false
	else:
		if m.state.shots.is_empty():m.notify("先按 P 和 F12 拍下一张风景照。");return false
		record={"kind":"photo","file":m.state.shots.back()}
	d.slots[house_id+"_"+str(slot)]=record;m.bay.refresh_hand();m.close_modal();commit();return true

func start_scope(target:Vector3):
	m.close_modal();m.player.enabled=false;scope_active=true;scope_camera.position=anchors.H05+Vector3(2,5.1,7.5);scope_camera.look_at(target);scope_camera.fov=24;scope_camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;m.notify("望远镜观海 · 滚轮调焦，Esc 返回")
func stop_scope():scope_active=false;m.player.camera.make_current();m.player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _input(event):
	if scope_active:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:scope_camera.fov=clampf(scope_camera.fov+(-3 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 3),8,40);get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:stop_scope();get_viewport().set_input_as_handled()
	if frame_active and not m.photo_mode:frame_active=false

func tour_panel(id:String):
	for route in m.world.layout.config.tour_routes:
		if route.id!=id:continue
		m.open_modal(route.name);m.label(m.modal_box,route.duration,23)
		for place_id in route.places:
			var place:Dictionary=preload("res://scripts/location_registry.gd").find(m.world.spec,place_id)
			if not place.is_empty():m.label(m.modal_box,"· "+place.name,20)
		m.button(m.modal_box,"开始这条路线",func():data().tour=route.places.duplicate();m.close_modal();commit())

func pottery_model(parent:Node3D,at:Vector3,shape:int,glaze:int,scale_factor:float=1):
	var node:=Node3D.new();parent.add_child(node);node.position=at;node.scale=Vector3.ONE*scale_factor
	var body:MeshInstance3D=cylinder(node,Vector3.UP*.28,.24 if shape!=1 else .34,.55 if shape!=1 else .28,PALETTE[posmod(glaze,3)])
	if shape==0:cylinder(node,Vector3.UP*.60,.14,.18,PALETTE[posmod(glaze,3)])
	elif shape==2:block(node,Vector3(.27,.32,0),Vector3(.10,.25,.22),PALETTE[posmod(glaze,3)])
	return node
func picture(parent:Node3D,p:Vector3,file:String,width:float=1.3):
	var path:String=m.photo_directory()+"/"+file
	if not FileAccess.file_exists(path):return
	var image:=Image.load_from_file(ProjectSettings.globalize_path(path))
	if image==null:return
	image.resize(512,maxi(1,roundi(512.0*image.get_height()/image.get_width())),Image.INTERPOLATE_LANCZOS)
	var quad:=QuadMesh.new();quad.size=Vector2(width,width*image.get_height()/float(image.get_width()));var mesh:=MeshInstance3D.new();mesh.mesh=quad;mesh.position=p
	var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(image);mat.roughness=.8;mesh.material_override=mat;parent.add_child(mesh)
	block(parent,p-Vector3(0,0,.06),Vector3(quad.size.x+.15,quad.size.y+.15,.1),["5e4232","c6aa79","f4efe6"][int(data().get("frame_color",0))%3])

func refresh():
	var d:Dictionary=data();var serial:String=JSON.stringify(d)+str(m.state.inventory.get("flower_colors",{}))+str(m.state.inventory.get("conch",0))
	if signature==serial:return
	signature=serial
	for node in models.values():node.queue_free()
	models.clear()
	for id in HOUSE_TOPICS:house_model(id,d)
	for wing in m.world.layout.config.street_wings:wing_model(wing,d)
	var p:Dictionary=d.pottery;var studio:Node3D=root_for("Pottery",anchors.Z09_B2+Vector3(-3,0,-1.4));cylinder(studio,Vector3.UP*1.13,.75,.12,"8c857b")
	if int(p.stage)>0:
		var clay:Node3D=pottery_model(studio,Vector3.UP*1.2,int(p.shape),int(p.glaze),1.25)
		if int(p.stage)==1:
			for part in clay.get_children():part.material_override=part.material_override.duplicate();part.material_override.albedo_color=Color("b99b7d")
	var rack:Node3D=root_for("PotteryRack",anchors.Z09_B2+Vector3(-4,5,-4))
	for i in 6:
		if d.racks[i]!=null:pottery_model(rack,Vector3((i%3)*1.25,1+(i/3)*.8,0),int(d.racks[i].shape),int(d.racks[i].glaze),.8)
	var loom:Node3D=root_for("Loom",anchors.Z09_B4+Vector3(-3,0,-1));block(loom,Vector3(0,1.5,0),Vector3(2.3,.12,.2),"5e4232")
	for i in 16:block(loom,Vector3(-1+i*.13,1.0,0),Vector3(.04,1.5,.04),["aac7cb","99b4c4","d6c2ab"][int(d.get("loom",0))%3])
	for id in m.world.layout.config.annexes:
		var at:Vector3=m.world.layout.vector(m.world.layout.config.annexes[id].center)+Vector3(1.6,5.5,-1.1)
		var model:Node3D=root_for("upper_"+id,at);block(model,Vector3.ZERO,Vector3(.85,.3,.45),["bbaa7e","84a9b6","bc95aa","a5b985"][int(d.get("upper_"+id,0))%4]);model.rotation.y=float(d.get("upper_"+id,0))*PI*.5
	for id in ["B02","B03","B11"]:
		var v:Dictionary=m.world.layout.venues[id];var at:=Vector3(v.x,v.floor_y+5.7,v.z+v.d*.5+2.5);var model:Node3D=root_for("upper_"+id,at)
		block(model,Vector3.ZERO,Vector3(.8,.3,.4),["bb9b71","869eb2","c3a8b4"][posmod(int(d.get("upper_"+id,0)),3)]);model.rotation.y=float(d.get("upper_"+id,0))*PI*.5
	for id in anchors:
		if str(id).begins_with("H"):make_slots(id,anchors[id],d)
	var home:Dictionary=m.world.layout.venues.B12;make_slots("B12",Vector3(home.x,home.floor_y,home.z),d)
	var conch:Node3D=root_for("ConchBook",anchors.H08+Vector3(1.7,4.7,-2.5))
	for i in mini(8,int(m.state.inventory.get("conch",0))):cylinder(conch,Vector3(i%4*.23,i/4*.16,0),.08,.12,"e6cfa9")

func house_model(id:String,d:Dictionary):
	var node:Node3D=root_for(id,anchors[id]);var table:=Vector3(0,1.1,-1.5)
	match id:
		"H01":
			var mill:=wheel_model(node,.38,.20);mill.name="Mill";mill.position=table+Vector3(-.8,.12,0);mill.rotation.z=PI*.5
			if int(d.get("bread",0))>0 and (m.creative==null or m.creative.legacy_display_active("legacy_table:bread")):
				block(node,table+Vector3(.4,.06,0),Vector3(1,.12,.6),"b3976d")
				for i in 4:cylinder(node,table+Vector3(.1+i*.2,.2,0),.14,.2,"d5ac6d")
		"H02":
			for i in 16:
				var grouped:bool=d.get("seed_sort",false)
				var at:=Vector3(-2.4+(i%4)*1.6,.78,-4.0+(i/4)*.12) if grouped else table+Vector3(-.55+(i%4)*.35,.15,(i/4)*.13)
				cylinder(node,at,.055,.08,["dab96b","e2a16c","d4c463","bc7161"][i%4])
			if int(d.get("harvest",0))>0 and (m.creative==null or m.creative.legacy_display_active("legacy_table:harvest")):
				for i in 8:cylinder(node,table+Vector3(-.7+i%4*.35,.16,i/4*.33),.12,.3,"d29a5c" if i%2 else "c57f6e")
			block(node,Vector3(3,1.8,-5.5),Vector3(1.8,.8,.08),"d8c697" if d.get("harvest_board",false) else "53675a")
		"H03":
			if d.has("framed_shot") and (m.creative==null or m.creative.legacy_display_active("legacy_table:framed_shot")):picture(node,Vector3(0,2.1,-4.6),d.framed_shot,2.1)
		"H04":
			cylinder(node,table+Vector3.UP*.2,.28,.4,"e2d5b3")
			if d.get("fruit_ready",false) and (m.creative==null or m.creative.legacy_display_active("legacy_table:fruit_ready")):cylinder(node,table+Vector3.UP*.41,.24,.05,"e2bd6d" if int(d.fruit)==0 else "d49b54")
			for i in 5:cylinder(node,table+Vector3(.65,.05+i*.04,0),.20,.035,"e6c56f")
		"H05":
			var scope:Node3D=Node3D.new();node.add_child(scope);scope.position=Vector3(2,4.8,7.5);scope.name="Telescope"
			block(scope,Vector3(0,.1,0),Vector3(.22,.25,1.3),"bfa46c");block(scope,Vector3(0,-.65,0),Vector3(.08,1.3,.08),"5e4232")
		"H06":
			if d.get("chime",false) and (m.creative==null or m.creative.legacy_display_active("legacy_table:chime")):
				var chime:=Node3D.new();node.add_child(chime);chime.name="Chime";chime.position=Vector3(-3,2.8,5.7)
				block(chime,Vector3.ZERO,Vector3(1,.08,.08),"947559")
				for i in 5:block(chime,Vector3(-.4+i*.2,-.35-i%2*.12,0),Vector3(.04,.7,.04),"bda77b");cylinder(chime,Vector3(-.4+i*.2,-.7-i%2*.12,0),.12,.1,"ead4b5")
		"H07":
			if int(d.get("fire",0))>0:
				for i in 6:block(node,Vector3(-.5+i*.2,.5,-3.55),Vector3(.12,.3+i%2*.2,.10),"edb362").name="Flame"+str(i)
		"H08":
			var folder:MeshInstance3D=block(node,Vector3(0,4.5,-1),Vector3(1.6,.05,1),"c8bb94");folder.rotation.z=-.5 if d.get("specimen",false) else 0
			for i in 5:
				var found:bool=m.state.inventory.get("flower_colors",{}).has(str(i));block(node,Vector3(-.6+i*.3,4.56,-1),Vector3(.17,.07,.26),["f4b8c4","f2c14e","6ba4d6","9b7ede","faf6f0"][i] if found else "7f8c78")
		"H09":
			block(node,table+Vector3.UP*.02,Vector3(.6,.03,1.1),["c7aab9","8ba5bc","d6c18c"][int(d.get("cloth",0))%3])
			for i in 3:cylinder(node,table+Vector3(-.6+i*.6,.18,0),.07,.35+int(d.get("candles",0))*.1,"e8d7b4")
		"H10":
			block(node,table,Vector3(.9,.08,.65),"d5c39a")
			if int(d.get("seal",0))>0:cylinder(node,table+Vector3(.15,.08,.12),.14,.045,"d4b162")
		"H11":
			var carousel:=Node3D.new();node.add_child(carousel);carousel.position=table;carousel.name="Carousel"
			cylinder(carousel,Vector3.ZERO,.6,.14,"96714e")
			for i in 3:
				var p:=Vector3(sin(i*TAU/3)*.4,.4,cos(i*TAU/3)*.4);block(carousel,p,Vector3(.18,.42,.16),["c1aaca","a7bdab","e1c582"][i]);cylinder(carousel,p+Vector3.UP*.3,.12,.17,"dec49f")
		"H12":
			if d.has("printed_shot") and (m.creative==null or m.creative.legacy_display_active("legacy_table:printed_shot")):
				picture(node,Vector3(-1,2.2,-4.7),d.printed_shot,1.4);block(node,Vector3(-1,2.65,-4.65),Vector3(.08,.18,.06),"bca172")
			if int(d.get("postcard",0))>0 and (m.creative==null or m.creative.legacy_display_active("legacy_table:postcard")):block(node,table+Vector3(0,.1,0),Vector3(.65,.03,.45),"e7d6af");cylinder(node,table+Vector3(.2,.14,.1),.08,.02,"b78169")
		"H13":
			if int(d.get("bookmark",0))>0 and (m.creative==null or m.creative.legacy_display_active("legacy_table:bookmark")):
				block(node,table+Vector3(.6,.2,0),Vector3(.22,.035,.65),"e8dec6")
				for i in 5:block(node,table+Vector3(.6,.24,-.22+i*.11),Vector3(.12,.025,.08),["f4b8c4","f2c14e","6ba4d6","9b7ede","faf6f0"][i])
			if int(d.get("wax",0))>0 and (m.creative==null or m.creative.legacy_display_active("legacy_table:wax")):cylinder(node,table+Vector3(-.6,.15,0),.22,.1,"ebdab7")
		"H14":
			cylinder(node,table+Vector3.UP*.15,.22,.3,"b39765");var handle:MeshInstance3D=block(node,table+Vector3(.2,.36,0),Vector3(.5,.07,.07),"5e4232");handle.name="Grinder"
			cylinder(node,Vector3(-3,.12,10),.35,.2,"e0c6a0")
			if d.get("cat",false):block(node,Vector3(-3,.24,10),Vector3(.25,.08,.18),"9e8460")
func wing_model(wing:Dictionary,d:Dictionary):
	var node:Node3D=root_for("wing_"+wing.id,anchors["wing_"+wing.id]);var p:=Vector3(0,1.3,.35)
	match wing.id:
		"BAKERY":
			if int(d.get("croissant",0))>0 and (m.creative==null or m.creative.legacy_display_active("legacy_table:croissant")):
				for i in 3:block(node,p+Vector3(-.6+i*.5,0,0),Vector3(.34,.22,.28),"d9b377").rotation.y=(i-1)*.35
		"LISTENING_WEST":block(node,p+Vector3(0,.25,0),Vector3(.9,.9,.08),["b99fb2","9cbcaf","d3c087"][int(d.get("sleeve",0))%3]).rotation.y=float(d.get("sleeve",0))*.4
		"LISTENING_EAST":
			var crank:MeshInstance3D=block(node,p+Vector3(.5,0,0),Vector3(.5,.07,.07),"b4a06c");crank.name="Crank"
		"CRAFT":
			if d.has("mosaic"):
				for i in 12:block(node,p+Vector3(sin(i*TAU/12)*.35,.2,cos(i*TAU/12)*.35),Vector3(.15,.4,.15),["7ce0d3","d4b6c4","e0c478"][i%3])
				var lamp:=OmniLight3D.new();node.add_child(lamp);lamp.position=p;lamp.omni_range=3;lamp.light_energy=.7;lamp.light_color=Color("ffd496")
func make_slots(id:String,p:Vector3,d:Dictionary):
	var group:Node3D=root_for("Slots_"+id,p)
	for i in 3:
		var at:Vector3=[Vector3(-4,1.3,-3.0),Vector3(3.5,1.4,-3.0),Vector3(1,2.5,-4.5)][i]
		var record:Dictionary=d.slots.get(id+"_"+str(i),{})
		if record.is_empty():continue
		if m.creative!=null and record.has("_creative_uid"):
			var work:Dictionary=m.creative.items.data().works.get(str(record._creative_uid),{})
			if not work.is_empty():
				var model:Node3D=m.creative.models.make(work.item,m.creative.canonical_variant(work));group.add_child(model);model.position=at;model.scale=Vector3.ONE*.65
			continue
		match record.kind:
			"pottery":pottery_model(group,at,int(record.shape),int(record.glaze))
			"photo":picture(group,at,record.file)
			"bouquet":
				cylinder(group,at,.16,.30,"d0bb93")
				for j in 7:block(group,at+Vector3(sin(j*2.4)*.18,.38+j%2*.1,cos(j*2.4)*.16),Vector3(.18,.18,.18),record.colors[j%record.colors.size()])
			_:craft_model(group,at,record.kind)
	var lamp:=OmniLight3D.new();group.add_child(lamp);lamp.position=Vector3(0,2.6,0);lamp.omni_range=8;lamp.shadow_enabled=false
	var selection:int=int(d.get("light_"+id,0));lamp.light_color=Color(["ffc98a","f8e5c3","c8dbed","ffffff"][selection%4]);lamp.light_energy=.55 if selection!=3 else 0

func update_hand():
	var d:Dictionary=data();var serial:String=str(m.state.handheld)+str(d.pottery)+str(m.state.activities.get("home_object",""))
	if serial==hand_signature:return
	hand_signature=serial
	if is_instance_valid(hand_prop):hand_prop.queue_free()
	if m.state.handheld=="pottery":
		hand_prop=Node3D.new();m.player.figure.add_child(hand_prop);hand_prop.position=Vector3(0,1.05,-.45);pottery_model(hand_prop,Vector3.ZERO,int(d.pottery.shape),int(d.pottery.glaze),.8)

	elif m.state.handheld=="craft":
		hand_prop=Node3D.new();m.player.figure.add_child(hand_prop);hand_prop.position=Vector3(0,1.12,-.48)
		craft_model(hand_prop,Vector3.ZERO,str(m.state.activities.get("home_object","贝壳风铃")))

func craft_model(parent:Node3D,p:Vector3,kind:String):
	if "松果" in kind or "lamp" in kind:
		cylinder(parent,p+Vector3.UP*.18,.18,.36,"c3a274");var light:=OmniLight3D.new();parent.add_child(light);light.position=p+Vector3.UP*.3;light.omni_range=2;light.light_energy=.3;light.light_color=Color("ffcf88")
	elif "海螺" in kind or "conch" in kind:
		block(parent,p,Vector3(.5,.15,.4),"aa906c");cylinder(parent,p+Vector3.UP*.24,.20,.35,"ead6ad")
	else:
		block(parent,p+Vector3.UP*.4,Vector3(.55,.06,.1),"947559")
		for j in 3:block(parent,p+Vector3(-.18+j*.18,.19,0),Vector3(.1,.35,.07),"e5d0a6")

func _process(delta:float):
	if m==null or not m.active_game:return
	clock+=delta;tick+=delta;var d:Dictionary=data()
	wheel.visible=m.player.position.distance_to(wheel.position)<170;sluice.visible=m.player.position.distance_to(sluice.position)<110
	var opened:bool=d.get("sluice",false);flow.visible=opened and m.player.position.distance_to(wheel.position)<180
	if opened:wheel.rotate_x(delta*.65)
	if clock<float(motion_until.get("sluice",0)):sluice.rotate_y(delta*2.5)
	for i in streams.size():streams[i].node.position=streams[i].a.lerp(streams[i].c,fmod(clock*.6+i*.24,1.0))
	smoke.visible=int(d.pottery.stage)==4
	if int(d.pottery.stage)==4:
		if not motion_until.has("kiln"):motion_until.kiln=clock+4
		for i in smoke.get_child_count():
			var puff:Node3D=smoke.get_child(i);var t:float=fmod(clock*.5+i*.16,1);puff.position=Vector3(sin(clock+i)*.2+t*.6,t*3,0);puff.scale=Vector3.ONE*(.5+t)
		if clock>=float(motion_until.kiln):
			d.pottery.stage=3
			if m.creative!=null:d.pottery["_creative_uid"]=m.creative.legacy_output("legacy_pottery",{"shape":int(d.pottery.shape),"glaze":int(d.pottery.glaze)})
			else:m.state.handheld="pottery";m.bay.refresh_hand()
			commit();m.notify("陶器已出窑并放入背包。可到晒架或私人房间布置。")
	for i in stage_lights.size():
		var lamp:SpotLight3D=stage_lights[i];lamp.visible=m.bay.light_show and m.player.position.distance_to(lamp.position)<80;lamp.light_color=Color(["f4b8c4","6ba4d6","f2c14e"][(i+int(d.get("stage_0",0)))%3]);lamp.rotation=Vector3(-.7+sin(clock+i)*.15,0,float(d.get("stage_0",0))*.12)
	for part in curtain.get_children():
		if part is MeshInstance3D:part.material_override.albedo_color=Color(("687f9b" if int(d.get("stage_1",0))==0 else "d0a3b5") if part.mesh.size.x>1 else ("e6ca8c" if int(d.get("stage_1",0))==0 else "faf6f0"))

	gate.position.y=move_toward(gate.position.y,14.5+1.7+(4 if opened else 0),delta*1.5)
	pasture_gate.rotation.y=lerp_angle(pasture_gate.rotation.y,-PI*.52 if d.get("pasture_gate",false) else 0,clampf(delta*4,0,1))
	for i in levers.size():levers[i].rotation.x=lerpf(levers[i].rotation.x,-.55+float(d.get("stage_"+str(i),0))*.55,clampf(delta*6,0,1))
	curtain.visible=m.player.position.distance_to(curtain.position)<90;curtain.position.y=move_toward(curtain.position.y,float(m.world.layout.venues.B10.floor_y)+4+(6 if int(d.get("stage_1",0))==2 else 0),delta*2)
	furnace_light.light_energy=(.6+sin(clock*11)*.08) if int(d.get("fire",0))>0 else 0
	for id in models:
		var node:Node3D=models[id];node.visible=m.player.position.distance_to(node.position)<100 or m.environment_controls.overview
		if not node.visible:continue
		var rotating:String={"H01":"Mill","H11":"Carousel","H14":"Grinder","wing_LISTENING_EAST":"Crank"}.get(id,"")
		var action:String={"H01":"mill","H11":"musicbox","H14":"coffee","wing_LISTENING_EAST":"gramophone"}.get(id,"")
		if not rotating.is_empty() and clock<float(motion_until.get(action,0)):
			var part:Node3D=node.get_node_or_null(rotating)
			if part!=null:part.rotate_y(delta*2.4)
		var chime:Node3D=node.get_node_or_null("Chime")
		if chime!=null:chime.rotation.z=sin(clock*1.5)*.12
		if id=="Pottery" and clock<float(motion_until.get("pottery",0)):node.rotation.y+=delta*3
	frame_overlay.visible=frame_active and m.photo_mode
	if frame_overlay.visible:
		var rect:Rect2=m.get_viewport().get_visible_rect();var p:=rect.size*.15;var s:=rect.size*.70
		for i in 4:
			var edge:ColorRect=frame_overlay.get_child(i);edge.color=Color(["5e4232","c6aa79","f4efe6"][int(d.get("frame_color",0))%3]);edge.position=p+Vector2(0,s.y-12 if i==1 else 0) if i<2 else p+Vector2(s.x-12 if i==3 else 0,0);edge.size=Vector2(s.x,12) if i<2 else Vector2(12,s.y)
	if tick<.18:return
	tick=0;refresh();update_hand()
	for light in m.world.find_children("*","OmniLight3D",true,false):
		var room:String=str(light.get_meta("room_light",""))
		if room.is_empty():room=m.world.inside_building(light.global_position)
		if room.is_empty() or not d.has("light_"+room):continue
		var preset:int=int(d["light_"+room]);light.light_color=Color(["ffc98a","f8e5c3","c8dbed","ffffff"][preset%4]);light.light_energy=.5 if preset!=3 else 0

	if not d.get("tour",[]).is_empty():
		var place:Dictionary=preload("res://scripts/location_registry.gd").find(m.world.spec,d.tour[0])
		if not place.is_empty():
			m.target_zone=place
			if Vector2(m.player.position.x-place.x,m.player.position.z-place.z).length()<8:d.tour.pop_front();m.save_game(false)
