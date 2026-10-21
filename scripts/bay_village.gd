extends Node3D
## Persistent planting/watering/harvest, real roaming livestock and usable houses.
var m
var clock:=0.0
var tick:=0.0
var farm_mesh:MultiMeshInstance3D
var animals:Array=[]
var farm_cache:=""
const CROPS=["wheat","carrot","corn","tomato"]
const CROP_NAMES=["小麦","胡萝卜","玉米","番茄"]

func setup(main):
	m=main
	farm_mesh=MultiMeshInstance3D.new();farm_mesh.name="LivingCropField";var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=BoxMesh.new();mm.instance_count=36*16*4;farm_mesh.multimesh=mm
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true;mat.roughness=.9;farm_mesh.material_override=mat;farm_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(farm_mesh)
	var pasture:Vector3=m.world.layout.vector(m.world.layout.config.pasture.center)
	for i in 8:
		var root:=Node3D.new();add_child(root);var kind:String="sheep" if i<4 else "pig";var tone:String="eee6d0" if kind=="sheep" else "dca6a0"
		m.bay.add_block(root,Vector3(0,.57,0),Vector3(.75,.7,1.1),tone)
		var head:MeshInstance3D=m.bay.add_block(root,Vector3(0,.69,-.65),Vector3(.48,.50,.45),"8e8b75" if kind=="sheep" else "d6a09a")
		for side in [-1,1]:
			m.bay.add_block(root,Vector3(side*.22,.93,-.66),Vector3(.16,.24,.12),tone)
			m.bay.add_block(root,Vector3(side*.13,.77,-.89),Vector3(.055,.065,.025),"3a4940")
		if kind=="pig":m.bay.add_block(root,Vector3(0,.65,-.93),Vector3(.24,.18,.08),"c9918e")
		var tail:MeshInstance3D=m.bay.add_block(root,Vector3(0,.67,.64),Vector3(.12,.12,.28),tone)
		var legs:Array=[]
		for x in [-.25,.25]:
			for z in [-.32,.32]:legs.append(m.bay.add_block(root,Vector3(x,.18,z),Vector3(.17,.36,.17),"8e8670" if kind=="sheep" else "cb9690"))
		var home:Vector3=pasture+Vector3(-11+(i%4)*7,0,2+(i/4)*6);root.position=home
		animals.append({"node":root,"kind":kind,"home":home,"legs":legs,"phase":i*2.399,"fed_until":0.0,"head":head,"tail":tail})

func defaults():
	if not m.state.activities.get("farm_plots") is Dictionary:
		m.state.activities.farm_plots={}
	for i in 36:
		if not m.state.activities.farm_plots.has(str(i)):m.state.activities.farm_plots[str(i)]={"crop":i%4,"stage":3,"elapsed":0.0,"watered":false}

func open_action(action:Dictionary):
	defaults()
	match action.kind:
		"life_farm":farm_panel(int(action.data.plot))
		"life_pasture":pasture_panel()
		"life_pool":
			m.open_modal("海岸浅水游乐池");m.label(m.modal_box,"从中央五级石阶走进小池，水深约一米。可自由涉水、坐在池边或拍照。",25)
			m.button(m.modal_box,"下水玩一会儿",func():m.close_modal();m.bay.sound("step_water",true);m.notify("沿中央石阶进入；WASD 涉水，X 池边落座，P 拍照。"))
		"life_house":
			var house:Dictionary=m.world.layout.config.living_houses.filter(func(h):return h.id==action.data.house)[0]
			m.bay.workshops.house(house);return
func farm_panel(index:int):
	defaults();m.open_modal("暖阳农田 · 播种与收获")
	if index<0:
		m.label(m.modal_box,"44 × 45 米农田，约为云麓花海面积的 80%。走近田畦按 F，可播种、浇水、收获与再种。",24)
		m.label(m.modal_box,"粮仓 · 小麦 %d · 胡萝卜 %d · 玉米 %d · 番茄 %d"%[int(m.state.inventory.get("wheat",0)),int(m.state.inventory.get("carrot",0)),int(m.state.inventory.get("corn",0)),int(m.state.inventory.get("tomato",0))],21)
		m.button(m.modal_box,"收获附近成熟田畦",func():
			var f:Vector3=m.world.layout.vector(m.world.layout.config.farm.center);var near:int=clampi(roundi((m.player.position.z-f.z+17.5)/7),0,5)*6+clampi(roundi((m.player.position.x-f.x+17.5)/7),0,5)
			harvest(near);m.close_modal())
		return
	var plot:Dictionary=m.state.activities.farm_plots[str(index)]
	m.label(m.modal_box,"田畦 %d · %s · %s"%[index+1,CROP_NAMES[int(plot.crop)],["待播种","幼苗","生长中","可收获"][int(plot.stage)]],26)
	if int(plot.stage)==0:
		for i in 4:
			var choice:int=i;m.button(m.modal_box,"播种 · "+CROP_NAMES[i],func():plant(index,choice);m.close_modal())
	elif int(plot.stage)<3:m.button(m.modal_box,"浇水 · 加快生长",func():water(index);m.close_modal())
	else:m.button(m.modal_box,"收获成熟庄稼",func():harvest(index);m.close_modal())
	m.label(m.modal_box,"浇水后约 30 秒成熟，未浇水约 60 秒。旅行进度和田畦状态会保存。",21)

func plant(index:int,crop:int)->bool:
	defaults();var plot:Dictionary=m.state.activities.farm_plots[str(index)]
	if int(plot.stage)!=0:return false
	plot.crop=clampi(crop,0,3);plot.stage=1;plot.elapsed=0.0;plot.watered=false;farm_cache="";m.save_game(false);m.notify("已播种 · "+CROP_NAMES[crop]);return true

func water(index:int)->bool:
	defaults();var plot:Dictionary=m.state.activities.farm_plots[str(index)]
	if int(plot.stage) not in [1,2]:return false
	plot.watered=true;farm_cache="";m.bay.sound("step_water",true);m.save_game(false);m.notify("已浇水，嫩苗开始生长。");return true

func harvest(index:int)->bool:
	defaults();var plot:Dictionary=m.state.activities.farm_plots[str(index)]
	if int(plot.stage)!=3:m.notify("这块田还未成熟。");return false
	var item:String=CROPS[int(plot.crop)]
	if m.creative!=null:m.creative.grant_material(item,4)
	else:m.state.inventory[item]=int(m.state.inventory.get(item,0))+4
	plot.stage=0;plot.elapsed=0.0;farm_cache="";m.save_game(false);m.notify("收获 "+CROP_NAMES[int(plot.crop)]+" × 4，可再播种或投喂牧场。");return true

func pasture_panel():
	m.open_modal("海湾牧场 · 羊与猪");m.label(m.modal_box,"羊喜欢小麦和玉米，猪喜欢胡萝卜与番茄。走近动物按 X 可以轻抚。",24)
	m.button(m.modal_box,"投喂羊群 · 消耗 1 份小麦或玉米",func():feed("sheep");m.close_modal())
	m.button(m.modal_box,"投喂猪群 · 消耗 1 份胡萝卜或番茄",func():feed("pig");m.close_modal())

func feed(kind:String)->bool:
	for crop in (["wheat","corn"] if kind=="sheep" else ["carrot","tomato"]):
		if int(m.state.inventory.get(crop,0))>0:
			if m.creative!=null:
				if not m.creative.consume(str(crop),1):return false
			else:m.state.inventory[crop]=int(m.state.inventory[crop])-1
			for a in animals:
				if a.kind==kind:a.fed_until=clock+8
			m.state.activities["fed_"+kind]=int(m.state.activities.get("fed_"+kind,0))+1;m.save_game(false);m.notify("已投喂，动物会向食槽和你靠近。");return true
	m.notify("粮仓里还没有合适的庄稼，先去相邻农田收获。");return false

func pet_livestock()->bool:
	for a in animals:
		if a.node.visible and m.player.position.distance_to(a.node.position)<2.3:
			m.player.gentle_pet(a.node.position,1.8);a.fed_until=clock+3;m.notify("轻轻抚摸"+("绵羊" if a.kind=="sheep" else "小猪"));return true
	return false

func refresh_field():
	var appearances:Array=[]
	for index in 36:
		var plot:Dictionary=m.state.activities.farm_plots[str(index)];appearances.append([plot.crop,plot.stage,plot.watered])
	var serial:String=JSON.stringify(appearances)
	if serial==farm_cache:return
	farm_cache=serial;var f:Vector3=m.world.layout.vector(m.world.layout.config.farm.center);var mm:MultiMesh=farm_mesh.multimesh;var cursor:=0
	for index in 36:
		var plot:Dictionary=m.state.activities.farm_plots[str(index)];var base:Vector3=f+Vector3(-17.5+(index%6)*7,0,-17.5+(index/6)*7)
		for i in 16:
			var p:Vector3=base+Vector3(-2.1+(i%4)*1.4,0,-2.1+(i/4)*1.4);var stage:int=int(plot.stage);var crop:int=int(plot.crop);var height:float=[0,.24,.55,.95][stage]*(1.1 if crop==2 else .8 if crop==1 else 1)
			for component in 4:
				var size:=Vector3(.07,height,.07);var position:Vector3=p+Vector3(0,height*.5,0);var tone:=Color("749251")
				if component==1 or component==2:
					size=Vector3(.32,.06,.16);position=p+Vector3(-.14 if component==1 else .14,height*.4,0)
				if component==3:
					size=Vector3(.18,.29,.15) if crop in [0,2] else Vector3(.24,.20,.24);position=p+Vector3(0,height+.05,0);tone=Color(["e1c068","e79b62","d5bd59","c98775"][crop])
				if stage==0:size=Vector3.ZERO
				elif stage<3 and component==3:tone=Color("9eb56b")
				mm.set_instance_transform(cursor,Transform3D(Basis.IDENTITY.scaled(size),position));mm.set_instance_color(cursor,tone);cursor+=1

func _process(delta:float):
	if m==null or not m.active_game:return
	clock+=delta;tick+=delta
	if tick<.20:return
	var dt:float=tick;tick=0;defaults()
	for plot in m.state.activities.farm_plots.values():
		if int(plot.stage) in [1,2]:
			plot.elapsed+=dt*(2 if plot.watered else 1);plot.stage=3 if plot.elapsed>=60 else 2 if plot.elapsed>=25 else 1
	refresh_field();var pasture:Vector3=m.world.layout.vector(m.world.layout.config.pasture.center)
	farm_mesh.visible=m.player.position.distance_to(m.world.layout.vector(m.world.layout.config.farm.center))<210 or m.environment_controls.overview
	for a in animals:
		var node:Node3D=a.node;node.visible=m.player.position.distance_to(pasture)<170 or m.environment_controls.overview
		if not node.visible:continue
		var wanted:Vector3=a.home+Vector3(sin(clock*.17+a.phase)*2.7,0,cos(clock*.13+a.phase)*2.4)
		if clock<a.fed_until:wanted=pasture+Vector3(-7 if a.kind=="pig" else 7,0,7)
		var before:Vector3=node.position;var direction:Vector2=Vector2(wanted.x-before.x,wanted.z-before.z)
		var step:Vector2=direction.normalized()*minf(direction.length(),dt*(1.8 if clock<a.fed_until else .9));node.position.x+=step.x;node.position.z+=step.y;node.position.y=m.world.height_at(node.position.x,node.position.z)+.02
		if step.length()>.01:node.rotation.y=atan2(-step.x,-step.y)
		a.head.rotation.x=sin(clock*3)*.10+.12 if clock<a.fed_until and direction.length()<1.5 else 0
		a.tail.rotation.y=sin(clock*8+a.phase)*(.6 if clock<a.fed_until else .15)
		for i in a.legs.size():a.legs[i].rotation.x=sin(clock*5+a.phase+i*PI)*.18 if step.length()>.01 else 0
