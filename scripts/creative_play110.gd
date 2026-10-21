extends Node3D
## Unified offline creative loop: renewable resources, owned works, repeatable puzzles and supported placement.
const Items=preload("res://scripts/creative_items110.gd")
const Models=preload("res://scripts/creative_models110.gd")
const Puzzle=preload("res://scripts/creative_puzzle110.gd")
var m
var items=Items.new()
var models=Models.new()
var placed_nodes:Dictionary={}
var held_hand:Node3D
var held_back:Node3D
var equipment_signature:=""
var placed_signature:=""
var ghost:Node3D
var placing_uid:=""
var moving_existing:=false
var placing_yaw:=0.0
var placement_offset:=Vector3.ZERO
var placement_point:=Vector3.ZERO
var placement_area:Dictionary={}
var placement_normal:=Vector3.UP
var placement_ok:=false
var placement_reason:=""
var chosen_uid:=""
var bag_filter:="全部"
var bag_page:=0
var bag_search:=""
var bag_sort:="name"
var puzzle
var puzzle_topic:=""
var puzzle_photo_file:=""
var crafting:=false
var craft_clock:=0.0
var craft_job:Dictionary={}
var tick:=0.0
var source_nodes:Dictionary={}
var source_records:Dictionary={}
var sources_ready:=false
var commission_open:=false
var quickbar:Label
var latest_pattern:Dictionary={}
class WorkPreview:
	extends SubViewportContainer
	var model:Node3D
	var view:SubViewport
	var automatic:=true
	var dragging:=false
	func _gui_input(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed;accept_event()
		if event is InputEventMouseMotion and dragging and is_instance_valid(model):automatic=false;model.rotation.y+=event.relative.x*.012;accept_event()
	func _process(delta:float):
		if not is_instance_valid(view):return
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
		if is_visible_in_tree() and automatic and is_instance_valid(model):model.rotate_y(delta*.35)
const LESSON_NAMES={"everyday":"唱片排色与封套拼装","waiting":"街景线索与房灯布局","poem":"选纸、排版与装订","frost":"霜月灯光与垂幕","blossom":"旋转花纹拼合花令","daily":"旅行照片裁切冲印","coral":"潮汐拾物与海玻璃镶嵌","forest":"木纹拼板与星图对齐","azure_view":"对准海湾地标","azure_light":"三色折光片","azure_weave":"经纬织染纹样","azure_water":"阶水三池调流","azure_glass":"海玻璃拼片","azure_tide":"浅海游鱼图鉴","azure_model":"微缩湾岸造景","azure_sail":"饰帆形图与支架","castle":"纸木拼装"}
const MODES={"everyday":"order","waiting":"street","poem":"journal","frost":"light","blossom":"mosaic","daily":"crop","coral":"mosaic","forest":"mosaic","star":"dial","azure_view":"dial","azure_light":"light","azure_weave":"loom","azure_water":"water","azure_glass":"mosaic","azure_tide":"order","azure_model":"model","azure_sail":"sail","castle":"order"}
const REWARDS={"everyday":["everyday_cover","record_stand"],"waiting":["street_box","street_lamp"],"poem":["poem_journal","star_bookmark"],"frost":["frost_light","mini_stage"],"blossom":["flower_screen","flower_token"],"daily":["photo_print","travel_frame"],"coral":["coral_lamp","drift_chime","tidal_pack"],"forest":["woodgrain_lamp","forest_print","leaf_pack"],"castle":["castle_table","castle_cushion","castle_screen","paper_lamp","flower_stand","woodbuckle_pack"],"azure_view":["everyday_cover","bay_model"],"azure_light":["coral_lamp"],"azure_weave":["tidal_pack","leaf_pack","woodbuckle_pack"],"azure_water":["water_garden"],"azure_glass":["glass_tile"],"azure_tide":["coral_lamp","drift_chime"],"azure_model":["bay_model"],"azure_sail":["sail_flag"]}

func setup(main):
	m=main;items.setup(m)
	quickbar=Label.new();quickbar.name="CreativeQuickbar";quickbar.position=Vector2(40,1015);quickbar.size=Vector2(1840,27);quickbar.clip_text=true;quickbar.add_theme_font_size_override("font_size",17);quickbar.add_theme_color_override("font_outline_color",Color("203b3b"));quickbar.add_theme_constant_override("outline_size",5)
	if m.hud!=null:m.hud.add_child(quickbar)
	else:add_child(quickbar)
	quickbar.hide()

func initialize_state():
	cancel_placement();items.initialize_state();migrate_theme_positions();equipment_signature="";placed_signature="";crafting=false;craft_job={};puzzle=null;puzzle_photo_file="";sources_ready=false
	if is_instance_valid(held_hand):held_hand.queue_free()
	if is_instance_valid(held_back):held_back.queue_free()
	for node in placed_nodes.values():
		if is_instance_valid(node):node.queue_free()
	placed_nodes.clear()
	for node in source_nodes.values():
		if is_instance_valid(node):node.queue_free()
	source_nodes.clear();source_records.clear()
	if m.world!=null:m.world.interactions=m.world.interactions.filter(func(a):return not str(a.get("id","")).begins_with("C110_"))

func migrate_theme_positions():
	var d:Dictionary=items.data()
	if d.get("geometry_110_migrated",false):return
	var moved:Array=[]
	for uid in d.works:
		var work:Dictionary=d.works[uid]
		if work.get("location","")!="placed" or work.get("position",[]).size()!=3:continue
		var point:=Vector3(work.position[0],work.position[1],work.position[2])
		for place in places():
			if not str(place.id).begins_with("THEME_") or place.get("legacy_center",[]).size()!=3:continue
			var old:Array=place.legacy_center;var size_value:Array=place.get("legacy_size",place.size);var old_center:=Vector3(old[0],float(old[1])+float(m.world.layout.config.sea_y),old[2])
			if absf(point.x-old_center.x)>float(size_value[0])*.5+.5 or absf(point.z-old_center.z)>float(size_value[1])*.5+.5 or absf(point.y-old_center.y)>5:continue
			var offset:Vector3=point-old_center;var rotated:Vector3=Basis(Vector3.UP,float(place.get("door_yaw",0)))*offset;var next:=Vector3(place.center[0],place.center[1],place.center[2])+rotated
			work.position=[next.x,next.y,next.z];work.yaw=float(work.get("yaw",0))+float(place.get("door_yaw",0));moved.append({"uid":uid,"room":place.id,"from":[point.x,point.y,point.z],"to":work.position.duplicate()});break
	d.geometry_110_migrated=true;d.geometry_110_migration=moved

func snapshot_state():items.mirror_materials()
func save():
	equipment_signature="";placed_signature="";m.save_game(false)
func grant_material(id:String,amount:int=1):items.grant(id,amount)
func consume(id:String,amount:int=1)->bool:return items.consume(id,amount)
func legacy_display_active(location:String)->bool:return items.legacy_display_active(location)
func legacy_output(id:String,variant:Dictionary={})->String:
	var result:Array=items.grant(id,1,variant)
	if result.is_empty():return ""
	items.equip(str(result[0]));save();m.notify(items.defs[id].name+"已放入背包。B 查看，G 布置。");return str(result[0])
func collect_legacy_material(id:String,yields:Dictionary,interval:float)->bool:
	var remaining:float=float(items.data().regrowth.get(id,0))-float(items.data().online)
	if remaining>0:m.notify("材料正在恢复，在线约 "+str(ceili(remaining))+" 秒后可采。");return false
	for material in yields:items.grant(str(material),int(yields[material]))
	items.data().regrowth[id]=float(items.data().online)+interval;save();m.notify("材料已放入背包，之后可以再次采集。");return true
func canonical_variant(record:Dictionary)->Dictionary:
	var variant:Dictionary=record.get("variant",{}).duplicate(true)
	var file:String=str(variant.get("file",""))
	if not file.is_empty() and not file.is_absolute_path() and not file.begins_with("res://") and not file.begins_with("user://"):variant.file=m.photo_directory()+"/"+file.get_file()
	return variant
func eligible_legacy(slot:int)->Array:
	return items.bag_works().filter(func(record):return record.item=="legacy_bouquet" if slot==0 else record.item in ["photo_print","travel_frame","forest_print","legacy_photo"] if slot==2 else items.defs[record.item].category!="背包" and record.item not in ["photo_print","legacy_photo","legacy_bouquet"])
func place_legacy_slot(house:String,slot:int)->bool:
	var available:Array=eligible_legacy(slot)
	if available.is_empty() and slot==2 and not m.state.shots.is_empty():
		if not items.consume("paper",1):m.notify("冲印旧照片需要一张手作纸。");return false
		var uid:Array=items.grant("legacy_photo",1,{"file":m.photo_directory()+"/"+str(m.state.shots.back()).get_file()});available=[items.data().works[uid[0]]]
	if available.is_empty():m.notify("背包里还没有适合这个槽的作品，先制作或取回一件。");return false
	var uid:String=str(available.back().uid)
	for record in available:
		if record.uid==items.data().equipped_hand:uid=record.uid;break
	var d:Dictionary=m.bay.workshops.data();var key:String=house+"_"+str(slot);var old:Dictionary=d.slots.get(key,{})
	if old.has("_creative_uid"):items.take(str(old._creative_uid))
	var work:Dictionary=items.data().works[uid];var record:Dictionary=work.get("variant",{}).duplicate(true);record.kind=work.item;record["_creative_uid"]=uid
	d.slots[key]=record;items.transfer(uid,"legacy_slot:"+key);m.bay.workshops.signature="";m.bay.workshops.refresh();m.close_modal();save();m.notify("作品已移到陈列槽；清空槽位会完整取回背包。");return true
func legacy_rack_action(index:int):
	var d:Dictionary=m.bay.workshops.data()
	if index<0 or index>=d.racks.size():return
	if d.racks[index] is Dictionary:
		if d.racks[index].has("_creative_uid"):items.take(str(d.racks[index]._creative_uid))
		else:m.notify("这件旧陶器还未完成迁移，请保存后重新进入。")
	else:
		var pots:Array=items.owned("legacy_pottery",true)
		if pots.is_empty():m.notify("先烧制一件陶器，背包中的陶器可以逐件放入晒架。");return
		var work:Dictionary=pots.back();var record:Dictionary=work.variant.duplicate(true);record["_creative_uid"]=work.uid;d.racks[index]=record;items.transfer(work.uid,"legacy_rack:"+str(index))
	m.bay.workshops.signature="";m.bay.workshops.refresh();m.close_modal();save()
func place_legacy_home_vase():
	var available:Array=items.owned("legacy_bouquet",true)
	if available.is_empty():m.notify("先扎一束花放进背包。");return
	for record in items.data().works.values():
		if record.get("location","")=="legacy_home_vase":items.take(record.uid)
	var work:Dictionary=available.back();items.transfer(work.uid,"legacy_home_vase");m.state.activities.flower_vase=true
	m.world.update_home(int(m.state.bouquet),"res://"+m.assets[int(m.state.home_photo)].runtime_path);save();m.notify("这一束花已移入花瓶，可从背包的已陈列页取回。")
func legacy_photo_mount(key:String,file:String)->bool:
	if not items.consume("paper",1):m.notify("冲印需要一张手作纸。");return false
	var full:String=m.photo_directory()+"/"+file.get_file();var ids:Array=items.grant("legacy_photo",1,{"file":full})
	if key in ["framed_shot","printed_shot"]:
		for work in items.data().works.values():
			if work.get("location","")=="legacy_table:"+key:items.take(work.uid)
		items.transfer(str(ids[0]),"legacy_table:"+key)
	else:items.equip(str(ids[0]))
	m.bay.workshops.data()[key]=file;save();m.bay.workshops.signature="";m.bay.workshops.refresh();m.notify("照片已冲印；原图保持不变。");return true
func name_of(uid:String)->String:
	var record:Dictionary=items.data().works.get(uid,{})
	return str(items.defs.get(record.get("item",""),{}).get("name","空位"))

func handle_input(event)->bool:
	if not event is InputEventKey or not event.pressed or event.echo:return false
	if not m.active_game or m.transitioning:return false
	if crafting and event.physical_keycode==KEY_ESCAPE:crafting=false;craft_job={};m.notify("已取消制作，材料和作品保持原状。");return true
	if not placing_uid.is_empty():
		match event.physical_keycode:
			KEY_ESCAPE:cancel_placement();return true
			KEY_F,KEY_ENTER:commit_placement();return true
			KEY_R:placing_yaw+=PI/12;return true
			KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN:
				var amount:float=.05 if Input.is_physical_key_pressed(KEY_SHIFT) else .25
				placement_offset.x+=(-amount if event.physical_keycode==KEY_LEFT else amount if event.physical_keycode==KEY_RIGHT else 0);placement_offset.z+=(-amount if event.physical_keycode==KEY_UP else amount if event.physical_keycode==KEY_DOWN else 0);return true
		return true
	if event.physical_keycode==KEY_B:
		if m.modal.visible and m.modal.get_node_or_null("CreativeBagMarker")!=null:m.close_modal()
		elif not crafting:open_bag()
		return true
	if m.modal.visible or not m.player.enabled or m.environment_controls.overview:return false
	if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_8:
		var index:int=event.physical_keycode-KEY_1;var uid:String=str(items.data().shortcuts[index])
		if uid.is_empty():m.notify("快捷栏 %d 为空，按 B 选择作品后设置。"%(index+1))
		elif items.equip(uid,items.defs[items.data().works.get(uid,{}).get("item","starter_basic_pack")].category=="背包"):save();m.notify("已展示 · "+name_of(uid))
		else:m.notify("这件作品正在陈列，先取回背包。")
		return true
	if event.physical_keycode==KEY_G:
		var uid:String=items.data().equipped_hand
		if uid.is_empty():m.notify("先按 B 选一件作品拿在手里，再按 G 布置。")
		else:start_placement(uid)
		return true
	return false

func _input(event):
	if placing_uid.is_empty():return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:commit_placement();get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT:cancel_placement();get_viewport().set_input_as_handled()

func open_bag():
	if crafting:m.notify("作品制作中，可用 Esc 取消。材料尚未扣除。");return
	m.open_modal("旅行背包 · 实物与作品",1320);var marker:=Node.new();marker.name="CreativeBagMarker";m.modal.add_child(marker)
	m.label(m.modal_box,"容量不限 · 物品按数量保存 · 背上与手中各一个展示位 · 8 个快捷栏",22)
	var tabs:=HBoxContainer.new();m.modal_box.add_child(tabs)
	for name in ["全部","材料","作品","背包","已陈列"]:
		var choice:String=name;m.button(tabs,("● " if bag_filter==name else "")+name,func():bag_filter=choice;bag_page=0;open_bag())
	var tools:=HBoxContainer.new();m.modal_box.add_child(tools);var search:=LineEdit.new();search.placeholder_text="搜索名称或陈列位置，Enter 确认";search.text=bag_search;search.custom_minimum_size=Vector2(700,44);tools.add_child(search)
	search.text_changed.connect(func(value):bag_search=value);search.text_submitted.connect(func(_value):bag_page=0;open_bag());m.button(tools,"搜索",func():bag_page=0;open_bag())
	var sort_choice:=OptionButton.new();sort_choice.custom_minimum_size=Vector2(230,44)
	for name in ["按名称整理","按制作时间","按类别整理"]:sort_choice.add_item(name)
	sort_choice.select(["name","time","category"].find(bag_sort));sort_choice.item_selected.connect(func(index):bag_sort=["name","time","category"][index];open_bag());tools.add_child(sort_choice)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",25);m.modal_box.add_child(row)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(590,440);row.add_child(scroll);var list:=VBoxContainer.new();list.custom_minimum_size.x=550;scroll.add_child(list)
	if bag_filter in ["全部","材料"]:
		for id in items.MATERIAL_NAMES:
			var amount:int=items.count(id)
			if amount>0 and (bag_search.is_empty() or str(items.defs[id].name).contains(bag_search)):m.label(list,items.defs[id].name+" × "+str(amount),22)
	var works:Array=items.data().works.values();works.sort_custom(func(a,b):
		var a_def:Dictionary=items.defs.get(a.item,{});var b_def:Dictionary=items.defs.get(b.item,{})
		if bag_sort=="time":return str(a.get("created",""))>str(b.get("created","")) if a.get("created","")!=b.get("created","") else str(a.uid)<str(b.uid)
		if bag_sort=="category" and a_def.get("category","")!=b_def.get("category",""):return str(a_def.get("category","")).naturalnocasecmp_to(str(b_def.get("category","")))<0
		return str(a_def.get("name","")).naturalnocasecmp_to(str(b_def.get("name","")))<0 if a_def.get("name","")!=b_def.get("name","") else str(a.uid)<str(b.uid))
	var visible_count:=0
	for record in works:
		if str(record.get("location","")).begins_with("commission:"):continue
		var definition:Dictionary=items.defs.get(record.item,{"name":"旧旅途作品","category":"旧旅途"});var at_home:bool=record.get("location","")!="bag"
		if not bag_search.is_empty() and not str(definition.name).contains(bag_search) and not display_area_name(str(record.get("area",record.get("location","")))).contains(bag_search):continue
		if bag_filter=="材料" or (bag_filter=="已陈列" and not at_home) or (bag_filter=="背包" and definition.category!="背包") or (bag_filter=="作品" and (at_home or definition.category=="背包")):continue
		visible_count+=1
		if visible_count<=bag_page*30 or visible_count>(bag_page+1)*30:continue
		var uid:String=record.uid;var title:String=("● " if uid==chosen_uid else "")+definition.name+(" · 已陈列" if at_home else "")+(" · 手持" if uid==items.data().equipped_hand else "")+(" · 背上" if uid==items.data().equipped_back else "")
		m.button(list,title,func():chosen_uid=uid;open_bag())
	var action_scroll:=ScrollContainer.new();action_scroll.custom_minimum_size=Vector2(590,440);row.add_child(action_scroll);var actions:=VBoxContainer.new();actions.custom_minimum_size.x=550;action_scroll.add_child(actions)
	if items.data().works.has(chosen_uid):
		var selected:Dictionary=items.data().works[chosen_uid];var definition:Dictionary=items.defs.get(selected.item,{"name":"旅行作品","category":"旧旅途"})
		m.label(actions,definition.name,29);m.label(actions,"这一件作品有独立记录，可拿取、陈列并取回。",21)
		if selected.get("location","")=="bag":
			m.button(actions,"拿在手中",func():items.equip(chosen_uid);save();open_bag())
			if definition.category=="背包":m.button(actions,"背在背上",func():items.equip(chosen_uid,true);save();open_bag())
			m.button(actions,"开始自由布置",func():m.close_modal();start_placement(chosen_uid))
			var shortcuts:=GridContainer.new();shortcuts.columns=4;actions.add_child(shortcuts)
			for i in 8:
				var index:int=i;m.button(shortcuts,"快捷 "+str(i+1),func():items.data().shortcuts[index]=chosen_uid;save();open_bag())
		else:
			m.label(actions,"位置："+display_area_name(str(selected.get("area",selected.get("location","")))),21)
			if selected.get("location","")=="placed":m.button(actions,"移动这件作品",func():m.close_modal();start_placement(chosen_uid))
			m.button(actions,"取回背包",func():items.take(chosen_uid);save();open_bag())
		m.button(actions,"查看这件作品",func():preview_work(selected))
	else:m.label(actions,"选择左侧一件作品，可设置手持、背上、快捷栏或布置。",23)
	m.button(actions,"收起手中展示",func():items.equip("");m.state.handheld="natural";m.bay.refresh_hand();save();open_bag())
	m.button(actions,"收起背上展示",func():items.equip("",true);save();open_bag())
	var pages:=HBoxContainer.new();m.modal_box.add_child(pages)
	if bag_page>0:m.button(pages,"上一页",func():bag_page-=1;open_bag())
	if visible_count>(bag_page+1)*30:m.button(pages,"下一页",func():bag_page+=1;open_bag())
	m.label(m.modal_box,"G 布置 · R 旋转 · 方向键吸附 0.25m / Shift 精调 0.05m · F 确认 · Esc 取消",20)

func preview_work(record:Dictionary,return_action:Callable=Callable()):
	var id:String=str(record.get("item","starter_basic_pack"));var definition:Dictionary=items.defs.get(id,{"name":"旅行作品","size":Vector3.ONE})
	m.open_modal(str(definition.name)+" · 实物预览",1180);m.label(m.modal_box,"拖动模型左右旋转，或切换慢转；预览与实际手持、摆放使用同一个模型和参数。",21)
	var container:=WorkPreview.new();container.custom_minimum_size=Vector2(1040,475);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_STOP;m.modal_box.add_child(container)
	var viewport:=SubViewport.new();viewport.size=Vector2i(1040,475);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport);container.view=viewport
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("b7c5bb");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("f6ecd5");env.ambient_light_energy=.7;environment.environment=env;viewport.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-.75,-.6,0);light.light_energy=1.35;light.shadow_enabled=false;viewport.add_child(light)
	var model:Node3D=models.make(id,canonical_variant(record));viewport.add_child(model);container.model=model;var size_value:Vector3=definition.size;var center_y:float=size_value.y*.5;model.position.y=-center_y
	var ground:=Node3D.new();viewport.add_child(ground);models.box(ground,Vector3(0,-center_y-.06,0),Vector3(6,.05,6),"c8bea6")
	var camera:=Camera3D.new();camera.near=.04;camera.far=40;camera.fov=43;viewport.add_child(camera);var distance_value:float=maxf(1.8,maxf(size_value.x,maxf(size_value.y,size_value.z))*2.45);camera.position=Vector3(distance_value*.55,distance_value*.30,distance_value);camera.look_at(Vector3.ZERO);camera.current=true
	var row:=HBoxContainer.new();m.modal_box.add_child(row);m.button(row,"向左转",func():container.automatic=false;model.rotate_y(-PI/6));m.button(row,"向右转",func():container.automatic=false;model.rotate_y(PI/6));m.button(row,"慢转 / 暂停",func():container.automatic=not container.automatic)
	m.label(m.modal_box,"记录："+str(record.get("created","工作台样式预览"))+" · 原照片只读，作品可随时取回。",20)
	m.button(m.modal_box,"返回工作台" if return_action.is_valid() else "回到背包",return_action if return_action.is_valid() else open_bag)

func recipe_panel(topic:String):
	var key:String=topic if REWARDS.has(topic) else "castle";m.open_modal(LESSON_NAMES.get(key,"手作工坊"),1180)
	m.label(m.modal_box,"先完成工作台的拼装或观察挑战，保存自己的纹样；制作后得到可携带、可布置的独立作品。",22)
	if MODES.has(key):m.button(m.modal_box,"开始可重玩挑战",func():begin_puzzle(key))
	if key=="daily":
		var photos:Array=daily_photo_candidates();var selected_photo:String=daily_photo_file();var photo_choice:=OptionButton.new();photo_choice.custom_minimum_size=Vector2(1000,42);var selected_photo_index:=0
		for i in photos.size():
			photo_choice.add_item(str(photos[i].name))
			if str(photos[i].file)==selected_photo:selected_photo_index=i
		photo_choice.select(selected_photo_index);photo_choice.item_selected.connect(func(i):select_daily_photo(str(photos[i].file));recipe_panel("daily"));m.modal_box.add_child(photo_choice)
		m.label(m.modal_box,"选片用于本次裁切、实物预览和冲印；各照片保留自己的裁切参数，原文件只读。",19)
	var color_choice:=OptionButton.new();color_choice.custom_minimum_size=Vector2(1000,42)
	for color_name in ["配色 · 海雾青绿","配色 · 蔷薇烟粉","配色 · 暖金麦沙"]:color_choice.add_item(color_name)
	color_choice.select(clampi(int(items.data().knowledge.get("selected_tone",0)),0,2));color_choice.item_selected.connect(func(i):items.data().knowledge.selected_tone=i;save());m.modal_box.add_child(color_choice)
	var patterns:Array=items.data().knowledge.get("unlocked_patterns",[])
	if not patterns.is_empty():
		m.label(m.modal_box,"背包刺绣纹样 · 可选委托解锁后可重复使用",20);var pattern_choice:=OptionButton.new();pattern_choice.custom_minimum_size=Vector2(900,45);pattern_choice.add_item("作品原纹样")
		for name in patterns:pattern_choice.add_item(str(name))
		var selected:int=patterns.find(str(items.data().knowledge.get("selected_pattern","")))+1;pattern_choice.select(maxi(0,selected));pattern_choice.item_selected.connect(func(i):items.data().knowledge.selected_pattern="" if i==0 else patterns[i-1];save());m.modal_box.add_child(pattern_choice)
	var learned:bool=items.data().lessons.has(key) or key=="castle"
	var recipes_scroll:=ScrollContainer.new();recipes_scroll.custom_minimum_size=Vector2(1050,250 if not patterns.is_empty() else 340);m.modal_box.add_child(recipes_scroll);var recipes_box:=VBoxContainer.new();recipes_box.custom_minimum_size.x=1000;recipes_box.add_theme_constant_override("separation",12);recipes_scroll.add_child(recipes_box)
	for id in REWARDS[key]:
		var item:String=id;var definition:Dictionary=items.defs[id];var cost_words:Array=[]
		for mat in definition.cost:cost_words.append(items.defs[mat].name+" × "+str(definition.cost[mat]))
		m.label(recipes_box,definition.name+" · "+" / ".join(cost_words)+" · %.0f 秒"%float(definition.seconds),23)
		var row:=HBoxContainer.new();recipes_box.add_child(row)
		for amount in [1,2,4,8]:
			var quantity:int=amount;var button:Button=m.button(row,"制作 × "+str(amount),func():begin_craft(item,quantity,key));button.disabled=not learned
		m.button(row,"实物预览",func():preview_work({"item":item,"variant":craft_variant(item,key)},func():recipe_panel(key)))
	if not learned:m.label(m.modal_box,"完成一次本工作台挑战后解锁制作；之后可自由重做。",21)
	m.button(m.modal_box,"打开背包",open_bag)

func daily_photo_candidates()->Array:
	var result:Array=[];var seen:Dictionary={}
	for entry in [["原节目照片","res://assets/media/dual106/daily.jpg"],["原公开照片 · 1","res://assets/media/bay_life/life_01.jpg"],["原公开照片 · 2","res://assets/media/bay_life/life_03.jpg"],["原公开照片 · 3","res://assets/media/bay_life/life_05.jpg"]]:
		if ResourceLoader.exists(entry[1]):result.append({"name":entry[0],"file":entry[1]});seen[entry[1]]=true
	for shot in m.state.get("shots",[]):
		var file:String=m.photo_directory()+"/"+str(shot).get_file()
		if not seen.has(file) and FileAccess.file_exists(file):result.append({"name":"本机旅行照 · "+str(shot).get_file(),"file":file});seen[file]=true
	return result

func daily_photo_file()->String:
	var photos:Array=daily_photo_candidates();var selected:String=str(items.data().knowledge.get("daily_photo_file",""))
	for photo in photos:
		if str(photo.file)==selected:return selected
	# Preserve the previous default until the traveller explicitly chooses a source.
	for i in range(photos.size()-1,-1,-1):
		if str(photos[i].name).begins_with("本机旅行照"):return str(photos[i].file)
	return str(photos[0].file) if not photos.is_empty() else "res://assets/media/dual106/daily.jpg"

func select_daily_photo(file:String)->bool:
	for photo in daily_photo_candidates():
		if str(photo.file)==file:items.data().knowledge.daily_photo_file=file;save();return true
	return false

func cycle_daily_photo()->bool:
	var photos:Array=daily_photo_candidates()
	if photos.is_empty():return false
	var current:String=daily_photo_file();var index:=0
	for i in photos.size():
		if str(photos[i].file)==current:index=(i+1)%photos.size();break
	if not select_daily_photo(str(photos[index].file)):return false
	m.notify("已选冲印照片 · "+str(photos[index].name));return true

func craft_variant(id:String,lesson:String)->Dictionary:
	var pattern:Dictionary=items.data().lessons.get(lesson,{}).get("pattern",latest_pattern).duplicate(true)
	pattern.tone=clampi(int(items.data().knowledge.get("selected_tone",0)),0,2)
	pattern.pattern_style=str(items.data().knowledge.get("selected_pattern",""))
	if id in ["photo_print","travel_frame"]:
		var file:String=daily_photo_file();var crops:Dictionary=items.data().knowledge.get("daily_photo_crops",{}) if items.data().knowledge.get("daily_photo_crops",{}) is Dictionary else {}
		var crop=crops.get(file,pattern.get("crop",[.5,.5,1.0]) if str(pattern.get("file",""))==file else [.5,.5,1.0])
		pattern.file=file;pattern.crop=crop.duplicate() if crop is Array and crop.size()==3 else [.5,.5,1.0]
	return pattern

func begin_craft(id:String,quantity:int=1,lesson:String=""):
	if crafting:return
	quantity=clampi(quantity,1,8);var definition:Dictionary=items.defs.get(id,{})
	if definition.is_empty():return
	if not items.can_afford(definition.get("cost",{}),quantity):m.notify("材料不足：可到可见资源点采集，或在材料街屋加工。");return
	m.close_modal();crafting=true;craft_clock=0;var pattern:Dictionary=craft_variant(id,lesson);craft_job={"id":id,"quantity":quantity,"lesson":lesson,"seconds":float(definition.seconds)*quantity,"variant":pattern}
	m.notify("正在制作 "+definition.name+" × "+str(quantity)+"，Esc 可取消；完成时统一扣料。")

func complete_craft()->bool:
	if not crafting:return false
	var job:Dictionary=craft_job;crafting=false;craft_job={}
	var definition:Dictionary=items.defs[job.id]
	if not items.consume_cost(definition.get("cost",{}),int(job.quantity)):m.notify("材料发生变化，制作已取消，未扣除材料。");return false
	var ids:Array=items.grant(job.id,int(job.quantity),job.get("variant",{}))
	if not ids.is_empty():items.equip(str(ids[0]),definition.category=="背包")
	if job.id in ["photo_print","travel_frame"]:
		var room:Dictionary=m.bay.dual.data().rooms.daily;room.printed=int(room.printed)+int(job.quantity)
		if not room.get("_creative_taken_prints") is Array:room._creative_taken_prints=[]
		room._creative_taken_prints.append(room.prints.size());room.prints.append(int(job.get("variant",{}).get("tone",0))%3);m.bay.dual.signature="";m.bay.dual.motion.daily=m.bay.dual.clock+1.8
	save();m.notify(definition.name+" × "+str(job.quantity)+" 已完成并放入背包。");return true

func pause_puzzle():
	if not is_instance_valid(puzzle) or puzzle.solved:return
	var drafts:Dictionary=items.data().knowledge.get("puzzle_drafts120",{})
	drafts[puzzle_topic]={"mode":puzzle.kind,"round_index":puzzle.round_index,"runs":int(items.data().lessons.get(puzzle_topic,{}).get("runs",0)),"values":puzzle.values.duplicate(),"goal":puzzle.goal.duplicate(),"angles":puzzle.rotations.duplicate(),"targets":puzzle.target_rotations.duplicate(),"moves":puzzle.moves,"elapsed":puzzle.elapsed,"crop":[puzzle.crop_offset.x,puzzle.crop_offset.y,puzzle.crop_scale],"basins":puzzle.basins.duplicate(),"stable":puzzle.stable,"rng_state":str(puzzle.rng.state)}
	items.data().knowledge.puzzle_drafts120=drafts;puzzle.set_process(false);puzzle=null
	if m.active_game:save()

func resume_puzzle(topic:String):
	var draft:Dictionary=items.data().knowledge.get("puzzle_drafts120",{}).get(topic,{})
	if draft.is_empty() or str(draft.get("mode",""))!=puzzle.kind or int(draft.get("runs",-1))!=int(items.data().lessons.get(topic,{}).get("runs",0)):return
	if not draft.get("values") is Array or not draft.get("goal") is Array or draft.values.size()!=puzzle.values.size():return
	puzzle.round_index=clampi(int(draft.get("round_index",0)),0,2);puzzle.values=draft.values.duplicate();puzzle.goal=draft.goal.duplicate();puzzle.rotations=draft.get("angles",[]).duplicate();puzzle.target_rotations=draft.get("targets",[]).duplicate();puzzle.moves=maxi(0,int(draft.get("moves",0)));puzzle.elapsed=maxf(0,float(draft.get("elapsed",0)))
	var crop:Array=draft.get("crop",[.5,.5,.94]);puzzle.crop_offset=Vector2(crop[0],crop[1]);puzzle.crop_scale=clampf(float(crop[2]),.45,.98);puzzle.basins=draft.get("basins",[.12,.12,.12]).duplicate();puzzle.stable=clampf(float(draft.get("stable",0)),0,3)
	puzzle.rng.state=int(str(draft.get("rng_state",puzzle.rng.state)));puzzle.note="已恢复上次未完成的操作，材料保持原状。";puzzle.queue_redraw()

func begin_puzzle(topic:String):
	if crafting:return
	if topic=="coral" and found_count("coral_find_")<3:shore_hunt_panel("coral");return
	if topic=="forest" and found_count("forest_find_")<3:shore_hunt_panel("forest");return
	if topic=="azure_tide" and found_count("tide_seen_")<3:tide_panel();return
	if topic=="blossom" and m.bay.dual.data().rooms.blossom.clues.size()<3:
		m.open_modal("花影寻物 · 三处纹样线索");m.label(m.modal_box,"先在花影寻物间不同的三张纹样桌旁按 F 找齐线索，再回来旋转花纹。",24);return
	puzzle_topic=topic;m.open_modal(LESSON_NAMES.get(topic,"星位对齐"),1180)
	puzzle=Puzzle.new()
	if topic=="azure_view":
		var origin:=Vector2(193,-35)
		for place in places():
			if place.get("role","")=="azure_view":origin=Vector2(place.center[0],place.center[2]);break
		for target in [["海风站",Vector2(280,235)],["珊瑚岛",Vector2(225,450)],["森屿",Vector2(-60,490)]]:
			var direction:Vector2=target[1]-origin;puzzle.geographic_goals.append(posmod(roundi(atan2(direction.y,direction.x)*16/TAU),16));puzzle.geographic_labels.append(target[0])
	var challenge_seed:int=int(hash(topic))+int(items.data().lessons.get(topic,{}).get("runs",0))*7919
	if topic=="star":challenge_seed+=int(m.bay.dual.island_data().star_chart)*100003
	puzzle.configure("tide" if topic=="azure_tide" else MODES.get(topic,"order"),LESSON_NAMES.get(topic,"对齐三组星位"),challenge_seed,m.font,topic)
	resume_puzzle(topic)
	if topic=="daily":
		var file:String=daily_photo_file();puzzle_photo_file=file
		if file.begins_with("res://") and ResourceLoader.exists(file):puzzle.photo_texture=load(file)
		elif FileAccess.file_exists(file):
			var image:=Image.load_from_file(file)
			if image!=null and not image.is_empty():puzzle.photo_texture=ImageTexture.create_from_image(image)
		if puzzle.photo_texture==null:puzzle.photo_texture=load("res://assets/media/dual106/daily.jpg")
	m.modal_box.add_child(puzzle);puzzle.completed.connect(func(result):finish_puzzle(topic,result))
	var board=puzzle;m.button(m.modal_box,"检查作品 / 下一轮",func():
		if is_instance_valid(board):board.submit())
	m.label(m.modal_box,"不消耗材料。返回会保留本次操作，重新打开可继续；通过判定后才记录完成。",20)

func finish_puzzle(topic:String,result:Dictionary):
	if not is_instance_valid(puzzle) or not puzzle.solved or puzzle_topic!=topic:return
	if items.data().knowledge.get("puzzle_drafts120",{}) is Dictionary:items.data().knowledge.get("puzzle_drafts120",{}).erase(topic)
	if topic=="daily":
		var file:String=puzzle_photo_file if not puzzle_photo_file.is_empty() else daily_photo_file();result=result.duplicate(true);result.file=file
		if not items.data().knowledge.get("daily_photo_crops") is Dictionary:items.data().knowledge.daily_photo_crops={}
		var crop=result.get("crop",[.5,.5,1.0])
		if crop is Array and crop.size()==3:items.data().knowledge.daily_photo_crops[file]=crop.duplicate()
		items.data().knowledge.daily_photo_file=file;puzzle_photo_file=""
	var old:Dictionary=items.data().lessons.get(topic,{})
	items.data().lessons[topic]={"runs":int(old.get("runs",0))+1,"best_moves":mini(int(old.get("best_moves",9999)),int(result.get("moves",0))),"pattern":result.duplicate(true),"at":Time.get_datetime_string_from_system()}
	latest_pattern=result.duplicate(true);latest_pattern.tone=int(old.get("runs",0))%3
	if topic in m.bay.dual.ROOM_WORDS:
		var room:Dictionary=m.bay.dual.data().rooms[topic];room.actions=int(room.actions)+1;room.phase=int(latest_pattern.tone);m.bay.dual.signature=""
	if topic=="star":
		items.data().lessons.forest=items.data().lessons[topic].duplicate(true)
		var island:Dictionary=m.bay.dual.island_data();var chart:int=int(island.star_chart)
		if chart not in island.star_records:island.star_records.append(chart)
		island.star_step=int(result.get("pattern",[0])[0])/2
	if topic=="azure_light":items.data().lessons.coral=items.data().lessons[topic].duplicate(true)
	if topic=="azure_weave":
		for key in ["forest","coral","castle"]:
			if not items.data().lessons.has(key):items.data().lessons[key]={"runs":1,"pattern":result.duplicate(true)}
	var materials:Dictionary={"paper":2,"pigment":1} if topic in ["everyday","poem","daily"] else {"wood":2,"fiber":1} if topic in ["waiting","frost","forest","castle"] else {"sea_glass":2,"shell":1} if topic in ["coral","azure_glass","azure_light","azure_tide"] else {"clay":2,"fiber":1}
	for id in materials:items.grant(id,int(materials[id]))
	save();puzzle=null
	var recipe_topic:String="forest" if topic=="star" else topic
	m.notify("构图判定完成，纹样与材料已收好。可以制作独立作品。")
	recipe_panel(recipe_topic)

func activity(interaction):
	var payload:Dictionary=interaction.get("data",{}) if interaction is Dictionary else {};var topic:String=str(payload.get("topic",interaction if interaction is String else ""))
	if topic.begins_with("supply:"):collect_source(topic.trim_prefix("supply:"));return
	if topic.begins_with("coral_find_") or topic.begins_with("forest_find_"):discover_island(topic);return
	if topic.begins_with("tide_seen_"):observe_tide(int(topic.trim_prefix("tide_seen_")));return
	if topic in ["island_coral","coral"]:recipe_panel("coral");return
	if topic in ["island_forest","forest"]:recipe_panel("forest");return
	if topic=="star":begin_puzzle("star");return
	if topic=="castle_commission":commissions();return
	if topic=="castle_archive":catalog();return
	if topic=="castle_display":open_bag();return
	if topic=="public_display":
		m.open_modal("旅人作品展示面")
		m.label(m.modal_box,"这面展板供照片、拓印和挂饰使用；下方花池和通道保持开放。" if payload.get("place","")=="B13" else "这块木框展板和前方标记范围可展示你的独立作品。照片、拓印和挂饰可以挂墙；小模型可以放在展板前的地面。固定展品与中央通道保持开放。",24)
		m.button(m.modal_box,"从背包选择作品",open_bag);return
	if topic=="castle_material":material_panel();return
	if topic=="castle_photo":
		m.open_modal("花霞影像室 · 本机旅行照");m.bay.workshops.photo_options("castle_photo","选作展厅照片");m.button(m.modal_box,"摄影裁切与冲印",func():recipe_panel("daily"));return
	if topic=="castle_tea":m.bay.tea();return
	if topic in ["castle_paper","castle_cloth","castle_garden","castle_window"]:recipe_panel("castle");return
	if REWARDS.has(topic):recipe_panel(topic);return
	if topic.begins_with("room_"):recipe_panel(topic.trim_prefix("room_"));return
	open_bag()

func material_panel():
	m.open_modal("风物材料街屋 · 简加工")
	for row in [["木料裁成手作纸",{"wood":1},{"paper":2}],["纤维搓成细麻绳",{"fiber":2},{"rope":2}],["花材与矿泥调矿彩",{"flower":1,"clay":1},{"pigment":2}]]:
		var recipe:Array=row;m.button(m.modal_box,recipe[0],func():
			if items.consume_cost(recipe[1]):
				for id in recipe[2]:items.grant(id,int(recipe[2][id]))
				save();m.notify("材料已加工并放入背包。")
			else:m.notify("材料不足，可先到可见资源点采集。"))
	m.button(m.modal_box,"查看背包",open_bag)

func catalog():
	m.open_modal("花霞图鉴 · 28 件独立作品",1180);var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1040,650);m.modal_box.add_child(scroll);var list:=VBoxContainer.new();scroll.add_child(list)
	for id in items.APPROVED:
		var definition:Dictionary=items.defs[id];m.label(list,("● " if not items.owned(id).is_empty() else "○ ")+definition.name+" · "+definition.category+" · 已拥有 "+str(items.owned(id).size()),23)
	m.button(m.modal_box,"打开背包",open_bag)

func commissions():
	m.open_modal("可选风物委托 · 随时可重做",1180)
	var jobs:Array=[["海湾点灯","coral_lamp",1,"海玻璃灯交到这里，赠海湾纹样。"],["林间来信","poem_journal",1,"交一册独立手札，赠叶脉纹样。"],["小镇开幕","street_box",1,"交一件街景盒，赠城郭窗纹。"]]
	for i in jobs.size():
		var index:int=i;var job:Array=jobs[i];var done:Dictionary=items.data().commissions.get(str(i),{})
		m.label(m.modal_box,job[0]+" · "+job[3]+" · 已完成 "+str(int(done.get("runs",0)))+" 次",23)
		m.button(m.modal_box,"提交背包中的 "+items.defs[job[1]].name,func():
			var owned:Array=items.owned(str(job[1]),true)
			if owned.is_empty():m.notify("背包里没有这件作品；正在家中陈列的不会被取走。");return
			var uid:String=owned[0].uid;items.transfer(uid,"commission:"+str(index))
			var history:Dictionary=items.data().commissions.get(str(index),{});history.runs=int(history.get("runs",0))+1;history.pattern=["海湾波纹","林间叶脉","城郭窗纹"][index];items.data().commissions[str(index)]=history
			if not items.data().knowledge.get("unlocked_patterns") is Array:items.data().knowledge.unlocked_patterns=[]
			if history.pattern not in items.data().knowledge.unlocked_patterns:items.data().knowledge.unlocked_patterns.append(history.pattern)
			for material in ["wood","paper","fiber"]:items.grant(material,2)
			save();m.notify("委托完成，"+("首次纹样与" if int(history.runs)==1 else "")+"材料已放入背包。");commissions())

func places()->Array:
	if m.world==null or m.world.layout==null:return []
	var list=m.world.layout.get("creative_places")
	if list is Array:return list
	if list is Dictionary:return list.get("places",[])
	return []

func placement_regions()->Array:
	var result:Array=m.world.get_meta("creative110",{}).get("public_displays",[]).duplicate(true)
	for place in places():
		var id:String=str(place.id);var floors:Array=place.get("floors",[place.center[1]])
		for i in floors.size():
			var floor_allowed:bool=place.get("private",false)
			for allowed in place.get("private_floors",[]):
				if int(allowed)==i:floor_allowed=true
			if not floor_allowed:continue
			var ceiling:float=float(floors[i+1])-.05 if i+1<floors.size() else float(floors[i])+4.5
			result.append({"id":id+":floor:"+str(i),"name":place.name+" · "+str(i+1)+"层","center":[place.center[0],floors[i],place.center[2]],"ceiling":ceiling,"size":place.size,"door":place.get("door",[]),"yaw":place.get("door_yaw",0),"kind":"inside"})
		if not place.get("private",false) or place.get("role","")=="annex":continue
		if id.begins_with("VILLA_"):
			result.append({"id":id+":deck","name":place.name+" · 私人甲板","center":[place.center[0],place.center[1],place.center[2]+7],"size":[8,5.8],"door":[],"kind":"deck"})
		elif id.begins_with("TREEHOUSE"):
			result.append({"id":id+":deck","name":place.name+" · 树冠露台","center":[place.center[0],place.center[1],place.center[2]+place.size[1]*.5+1],"size":[place.size[0],2.2],"door":[],"kind":"deck"})
		elif id=="B12" or id.begins_with("H"):
			result.append({"id":id+":yard","name":place.name+" · 私人庭院","center":[place.center[0],place.center[1],place.center[2]+place.size[1]*.5+4],"size":[place.size[0]+3,5.5],"door":place.get("door",[]),"kind":"yard"})
	return result

func display_area_name(id:String)->String:
	for area in placement_regions():
		if str(area.id)==id:return str(area.name)
	return "旧旅途陈列位" if id.begins_with("legacy_") else "作品记录"
func area_count(id:String)->int:
	var count:=0;var house:String=id.get_slice(":",0);var ground_floor:bool=id.ends_with(":floor:0")
	for work in items.data().works.values():
		var location:String=str(work.get("location",""))
		if location=="placed" and str(work.get("area",""))==id:count+=1
		elif ground_floor and location.begins_with("legacy_slot:"+house+"_"):count+=1
		elif ground_floor and house=="B12" and location in ["legacy_home_vase","legacy_home_object"]:count+=1
	return count

func start_placement(uid:String):
	var record:Dictionary=items.data().works.get(uid,{})
	if record.is_empty() or record.get("location","") not in ["bag","placed"]:m.notify("先将这件作品取回背包。");return
	if not m.bay.boats.kind.is_empty() or not m.bay.vehicles.mounted.is_empty() or m.player.seated or (m.transport!=null and m.transport.is_riding()):m.notify("请先在平地站稳，再布置作品。");return
	cancel_placement();placing_uid=uid;moving_existing=record.get("location","")=="placed"
	if moving_existing and placed_nodes.has(uid):placed_nodes[uid].queue_free();placed_nodes.erase(uid)
	placing_yaw=float(record.get("yaw",m.player.yaw));placement_offset=Vector3.ZERO;ghost=models.make(record.item,canonical_variant(record));ghost.name="PlacementPreview";add_child(ghost);ghost.set_meta("preview",true)
	for child in ghost.find_children("*","MeshInstance3D",true,false):child.transparency=.45;child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.notify("瞄准私人房间、庭院或甲板的实际地面/桌面/墙面。R 旋转，F 确认，Esc 取消。")

func cancel_placement():
	placing_uid="";moving_existing=false;placement_ok=false
	if is_instance_valid(ghost):ghost.queue_free()
	ghost=null

func placement_surface(camera:Camera3D,screen_point:Vector2=Vector2.INF)->Dictionary:
	var origin:Vector3=camera.global_position;var direction:Vector3=-camera.global_basis.z
	var reach:float=18.0
	if m.environment_controls!=null and m.environment_controls.follow and camera==m.environment_controls.camera:
		var cursor:Vector2=get_viewport().get_mouse_position() if not screen_point.is_finite() else screen_point
		origin=camera.project_ray_origin(cursor);direction=camera.project_ray_normal(cursor)
		var place:Dictionary=m.world.layout.creative_at(m.player.position)
		var floor_y:float=m.player.position.y
		if not place.is_empty():
			floor_y=float(place.floors[0])
			for y in place.floors:
				if float(y)<=m.player.position.y+.35:floor_y=float(y)
		# Start below the current cutaway ceiling. Upper floors and roofs keep their
		# collision for walking, but do not intercept placement in the visible room.
		var ceiling:float=floor_y+2.25
		if direction.y<-.01 and origin.y>ceiling:origin+=direction*((ceiling-origin.y)/direction.y)
		reach=14.0
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*reach,1,[m.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func update_placement():
	if not is_instance_valid(ghost) or placing_uid.is_empty():return
	var camera:Camera3D=m.get_viewport().get_camera_3d()
	if camera==null:return
	var hit:Dictionary=placement_surface(camera)
	placement_ok=false;placement_reason="瞄准可布置区域中的实际支承面";ghost.visible=not hit.is_empty()
	if hit.is_empty():return
	placement_normal=hit.normal;placement_point=hit.position;placement_point.x=snappedf(placement_point.x,.25);placement_point.z=snappedf(placement_point.z,.25);placement_point+=placement_offset
	var record:Dictionary=items.data().works[placing_uid];var definition:Dictionary=items.defs[record.item];var wall:bool=placement_normal.y<.3 and definition.get("wall",false)
	ghost.rotation=Vector3.ZERO;ghost.rotation.y=placing_yaw
	if wall:ghost.rotation.y=atan2(placement_normal.x,placement_normal.z);placement_point+=placement_normal*.035;ghost.position=placement_point-Vector3.UP*float(definition.size.y)*.5
	else:ghost.position=placement_point+Vector3.UP*.018
	placement_area={}
	for area in placement_regions():
		var center:Array=area.center;var half:Vector2=Vector2(area.size[0],area.size[1])*.5
		if absf(placement_point.x-center[0])<half.x-.18 and absf(placement_point.z-center[2])<half.y-.18 and placement_point.y>=float(center[1])-.3 and placement_point.y<float(area.get("ceiling",float(center[1])+4.5)):placement_area=area;break
	if placement_area.is_empty():placement_reason="这里是公共通道；请在自己的房间、庭院、甲板或三层展厅布置";return
	if placement_area.get("wall_only",false) and not wall:placement_reason="这面展板供挂墙作品使用，花池和地面通道保持开放";return
	var count:int=area_count(str(placement_area.id))
	if moving_existing and record.get("area","")==placement_area.id:count-=1
	var limit:int=int(placement_area.get("limit",100))
	if count>=limit:placement_reason="这个空间已有 "+str(limit)+" 件作品，先取回一件";return
	if not wall and placement_normal.y<.72:placement_reason="作品需要平整地面或桌面支承";return
	var footprint:Vector3=definition.size;var center:Array=placement_area.center
	var angle:float=ghost.rotation.y
	var half_x:float=(absf(cos(angle))*footprint.x+absf(sin(angle))*footprint.z)*.5
	var half_z:float=(absf(sin(angle))*footprint.x+absf(cos(angle))*footprint.z)*.5
	if absf(placement_point.x-center[0])+half_x>float(placement_area.size[0])*.5-.05 or absf(placement_point.z-center[2])+half_z>float(placement_area.size[1])*.5-.05:placement_reason="作品底座需要完整位于可布置区域";return
	if blocked_route(placement_point,footprint):placement_reason="请为门口、楼梯和道路留出通道";return
	if not wall:
		for x in [-.35,.35]:
			for z in [-.35,.35]:
				var edge:Vector3=placement_point+Basis(Vector3.UP,placing_yaw)*Vector3(footprint.x*x,0,footprint.z*z);var support:=PhysicsRayQueryParameters3D.create(edge+Vector3.UP*.12,edge-Vector3.UP*.15,1,[m.player.get_rid()]);var below:Dictionary=get_world_3d().direct_space_state.intersect_ray(support)
				if below.is_empty() or absf(below.position.y-placement_point.y)>.13:placement_reason="底座边角没有支承，不能悬空放置";return
	var shape:=BoxShape3D.new();shape.size=footprint*Vector3(.88,.90,.88);var overlap:=PhysicsShapeQueryParameters3D.new();overlap.shape=shape;overlap.collision_mask=1;overlap.exclude=[m.player.get_rid()];overlap.transform=Transform3D(Basis(Vector3.UP,ghost.rotation.y),ghost.position+Vector3.UP*footprint.y*.52)
	if not wall and not get_world_3d().direct_space_state.intersect_shape(overlap,1).is_empty():placement_reason="这里与家具或建筑重叠，换个落点";return
	placement_ok=true;placement_reason=str(placement_area.name)+" · F 放置"

func blocked_route(point:Vector3,size_value:Vector3)->bool:
	var radius:float=maxf(size_value.x,size_value.z)*.5
	for place in places():
		var door:Array=place.get("door",[])
		if door.size()!=3:continue
		var anchor:=Vector3(door[0],door[1],door[2]);var local:Vector3=Basis(Vector3.UP,-float(place.get("door_yaw",0)))*(point-anchor)
		if absf(local.x)<1.15+radius and absf(local.z)<3.1+radius and absf(point.y-anchor.y)<2:return true
	for road in m.world.layout.segments:
		var q:Vector3=m.world.layout.projection(Vector2(point.x,point.z),road)
		if Vector2(point.x-q.x,point.z-q.z).length()<float(road.width)*.5+radius+.2 and absf(point.y-q.y)<1.5:return true
	for route in m.world.get_meta("upper_routes110",[]):
		var path:Array=route.get("points",[])
		var margin:float=float(route.width)*.5+.2 if route.has("width") else 1.3
		for i in path.size()-1:
			var a:Vector3=path[i] if path[i] is Vector3 else Vector3(path[i][0],path[i][1],path[i][2])
			var c:Vector3=path[i+1] if path[i+1] is Vector3 else Vector3(path[i+1][0],path[i+1][1],path[i+1][2])
			var flat:=Vector2(c.x-a.x,c.z-a.z);var offset:=Vector2(point.x-a.x,point.z-a.z)
			var t:float=clampf(offset.dot(flat)/flat.length_squared(),0,1) if flat.length_squared()>.0001 else 0.0
			var nearest:Vector3=a.lerp(c,t)
			if Vector2(point.x-nearest.x,point.z-nearest.z).length()>=margin+radius:continue
			# Reserve the walking surface and its headroom, without blocking another floor.
			var route_low:float=minf(a.y,c.y) if flat.length_squared()<=.0001 else nearest.y
			var route_high:float=maxf(a.y,c.y) if flat.length_squared()<=.0001 else nearest.y
			if point.y+size_value.y>route_low-.15 and point.y<route_high+2.2:return true
	return false

func commit_placement()->bool:
	if not placement_ok or placing_uid.is_empty():m.notify(placement_reason);return false
	var uid:String=placing_uid;var point:Vector3=ghost.position;var yaw:float=ghost.rotation.y
	if not items.transfer(uid,"placed",{"position":[point.x,point.y,point.z],"yaw":yaw,"area":placement_area.id}):return false
	cancel_placement();save();m.notify("作品已放好。按 B → 已陈列，可随时原样取回背包。");return true

func refresh_equipment():
	var d:Dictionary=items.data();var signature:String=str(d.equipped_hand)+":"+str(d.equipped_back)
	if signature==equipment_signature:return
	equipment_signature=signature
	for node in [held_hand,held_back]:
		if is_instance_valid(node):node.queue_free()
	held_hand=null;held_back=null
	if m.player==null:return
	for back in [false,true]:
		var uid:String=d.equipped_back if back else d.equipped_hand
		if not d.works.has(uid):continue
		var record:Dictionary=d.works[uid]
		if record.get("location","")!="bag":continue
		var node:Node3D=models.make(record.item,canonical_variant(record));m.player.figure.add_child(node)
		if back:held_back=node;node.position=Vector3(0,.88,.23);node.rotation.y=PI;node.scale=Vector3.ONE*.85
		else:
			held_hand=node;node.position=Vector3(.40,.91,-.40);node.scale=Vector3.ONE*.42;node.rotation.y=-.2
			m.state.handheld="natural"
			if m.bay!=null:m.bay.refresh_hand()

func refresh_placed():
	var d:Dictionary=items.data();var desired:Dictionary={}
	for uid in d.works:
		var record:Dictionary=d.works[uid]
		if record.get("location","")!="placed" or record.get("position",[]).size()!=3:continue
		if moving_existing and uid==placing_uid:continue
		var position_value:=Vector3(record.position[0],record.position[1],record.position[2])
		if not interested(position_value,220) or not m.world.region_ready(position_value):continue
		desired[uid]=true
		if placed_nodes.has(uid):continue
		var node:Node3D=models.make(record.item,canonical_variant(record));add_child(node);node.position=Vector3(record.position[0],record.position[1],record.position[2]);node.rotation.y=float(record.get("yaw",0));node.set_meta("creative_uid",uid)
		var body:=StaticBody3D.new();node.add_child(body);body.set_meta("creative_uid",uid);var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=items.defs[record.item].size;collider.shape=shape;collider.position.y=shape.size.y*.5;body.add_child(collider);placed_nodes[uid]=node
	for uid in placed_nodes.keys():
		if not desired.has(uid):placed_nodes[uid].queue_free();placed_nodes.erase(uid)
	for node in placed_nodes.values():node.visible=interested(node.position,210)

func interested(point:Vector3,radius:float)->bool:
	if Vector2(point.x-m.player.position.x,point.z-m.player.position.z).length()<radius:return true
	if m.world.streamer!=null:
		for focus in m.world.streamer.foci:
			if Vector2(point.x-focus.x,point.z-focus.z).length()<radius:return true
	return false

func renewable_pick(action:Dictionary)->bool:
	var d:Dictionary=items.data();var id:String=str(action.id);var interval:float=90 if action.kind=="bay_flower" or "flower" in id.to_lower() else 180 if "CONCH" in id else 120
	var remaining:float=float(d.regrowth.get(id,0))-float(d.online)
	if remaining>0:m.notify("这处材料正在恢复，在线约 "+str(ceili(remaining))+" 秒后可再采。");return false
	var material:String=str(action.data.get("material","flower"));items.grant(material,1);d.regrowth[id]=float(d.online)+interval
	var picked:Array=m.state.activities.get("picked",[])
	if id not in picked:picked.append(id);m.state.activities.picked=picked
	if material=="flower":
		var colors:Dictionary=m.state.inventory.get("flower_colors",{});var color:String=str(action.data.get("color",0));colors[color]=int(colors.get(color,0))+1;m.state.inventory.flower_colors=colors;items.data().knowledge.flower_colors=colors.duplicate(true)
	if material=="pinecone":items.grant("wood",1)
	if material=="shell":items.grant("fiber",1)
	if material=="conch":items.grant("sea_glass",1)
	save();m.notify("已采集 "+items.defs.get(material,{"name":material}).name+"，材料会在线恢复。");return true

func add_source(id:String,at:Vector3,title:String,yields:Dictionary,interval:float):
	var node:=Node3D.new();node.name=id;add_child(node);node.position=at;var item:String=str(yields.keys()[0]);var color:String="93b083" if item in ["wood","leaf","tea_leaf"] else "b5d5c5" if item=="sea_glass" else "c4ac82"
	models.box(node,Vector3(0,.12,0),Vector3(.65,.24,.5),"b39e79")
	for i in 5:models.box(node,Vector3(-.23+i*.11,.27+i%2*.05,0),Vector3(.10,.12,.25),color,i*.06)
	var label:=Label3D.new();label.text=title+" · F 采集";label.font=m.font;label.font_size=32;label.pixel_size=.007;label.position=Vector3(0,.9,0);label.modulate=Color("f3e8cb");node.add_child(label)
	source_nodes[id]=node;source_records[id]={"at":at,"title":title,"yields":yields,"interval":interval}
	m.world.interact(id,at,title+" · F 采集","creative110",{"topic":"supply:"+id})

func ensure_sources():
	if sources_ready or m.world==null or m.world.layout==null:return
	sources_ready=true
	# Side pockets beside actual paths; no source blocks a door or edits supplied media.
	var rows:Array=[
		["C110_WOOD_WEST",[-160,0,76],"落枝木料",{"wood":3,"fiber":1},120],
		["C110_PAPER_WEST",[-153,0,62],"手作纸与旧麻绳",{"paper":3,"rope":1},120],
		["C110_COLOR_WEST",[-151,0,47],"矿彩与纤维",{"pigment":2,"fiber":2},120],
		["C110_TEA_WEST",[-154,0,33],"茶叶与咖啡豆",{"tea_leaf":2,"beans":2},120],
		["C110_CLAY_WEST",[-153,0,88],"溪岸矿泥",{"clay":3},120],
		["C110_WOOD_NORTH",[-300,0,-134],"林缘落枝",{"wood":3,"fiber":1},120],
		["C110_LEAF_NORTH",[-266,0,-159],"叶片与茶芽",{"leaf":3,"tea_leaf":2},120],
		["C110_GLASS_COAST",[174,0,291],"浅岸海玻璃",{"sea_glass":3,"driftwood":2},180],
		["C110_FIBER_COAST",[206,0,275],"海风纤维",{"fiber":3,"rope":1},120],
		["C110_WOOD_FOREST",[-91,0,462],"森屿风落木",{"wood":3,"leaf":2},180],
		["C110_GLASS_CORAL",[218,0,431],"珊瑚岛漂木与海玻璃",{"driftwood":3,"sea_glass":2,"shell":1},180]]
	for row in rows:
		var at:Vector3=m.world.surface(float(row[1][0]),float(row[1][2]),.04);add_source(row[0],at,row[2],row[3],row[4])
	for island in ["coral","forest"]:
		var points:Array=[[208,442],[192,452],[214,467]] if island=="coral" else [[-96,476],[-75,510],[-30,496]]
		for i in 3:
			var at:Vector3=m.world.surface(points[i][0],points[i][1],.04);var id:String="C110_"+island.to_upper()+"_FIND_"+str(i);var node:=Node3D.new();add_child(node);node.position=at;source_nodes[id]=node
			models.box(node,Vector3(0,.15,0),Vector3(.33,.30,.35),["9dcfc4","b1c6a0","d1bca0"][i],i*.4)
			m.world.interact(id,at,("潮汐拾物" if island=="coral" else "森林木纹线索")+" · F","creative110",{"topic":island+"_find_"+str(i)})
	var coral:Vector3=m.world.surface(221,440,.05);var forest:Vector3=m.world.surface(-85,469,.05)
	for entry in [["C110_CORAL_BENCH",coral,"珊瑚潮汐镶嵌台","island_coral"],["C110_FOREST_BENCH",forest,"森屿木纹拼板台","island_forest"]]:
		var node:=Node3D.new();add_child(node);node.position=entry[1];source_nodes[entry[0]]=node;models.box(node,Vector3(0,.65,0),Vector3(1.4,.12,.8),"a38c68")
		for x in [-.55,.55]:models.box(node,Vector3(x,.31,0),Vector3(.1,.62,.6),"806b4e")
		m.world.interact(entry[0],entry[1]+Vector3(0,0,1),entry[2]+" · F","creative110",{"topic":entry[3]})
	for i in 3:
		var x:float=370+i*15;var shore_z:float=m.world.layout.shore_z(x);var at:Vector3=m.world.surface(x,shore_z-6,.04);var id:String="C110_TIDE_"+str(i);var node:=Node3D.new();add_child(node);node.position=at;node.set_meta("water_y",float(m.world.layout.config.sea_y)-.55-at.y);source_nodes[id]=node
		models.box(node,Vector3(0,.28,0),Vector3(.08,.56,.08),"aa916c");models.box(node,Vector3(0,.54,0),Vector3(.48,.32,.04),"e9dec0")
		for j in 5:
			var fish:=Node3D.new();node.add_child(fish);fish.name="Fish"+str(j);models.box(fish,Vector3.ZERO,Vector3(.22,.18,.50),["d7b36d","99cfc8","b2a6cc"][i]);models.box(fish,Vector3(0,0,.32),Vector3(.32,.18,.15),["d7b36d","99cfc8","b2a6cc"][i]);fish.position=Vector3(1+j*.5,float(node.get_meta("water_y")),10+j*.4)
		m.world.interact(id,at,"浅海游鱼观察牌 · F","creative110",{"topic":"tide_seen_"+str(i)})

func collect_source(id:String)->bool:
	if not source_records.has(id):return false
	var record:Dictionary=source_records[id];var remaining:float=float(items.data().regrowth.get(id,0))-float(items.data().online)
	if remaining>0:m.notify(record.title+"正在恢复，在线约 "+str(ceili(remaining))+" 秒后可采。");return false
	for item in record.yields:items.grant(item,int(record.yields[item]))
	items.data().regrowth[id]=float(items.data().online)+float(record.interval);save();m.notify("已收集 "+record.title+"，背包材料已更新。");return true

func discover_island(topic:String):
	var prefix:String="coral_find_" if topic.begins_with("coral") else "forest_find_";var interval:float=180;var remaining:float=float(items.data().regrowth.get(topic,0))-float(items.data().online)
	if remaining>0:m.notify("这处自然材料正在恢复，可先去工作台拼装。");return
	items.data().knowledge[topic]=true;items.data().regrowth[topic]=float(items.data().online)+interval
	items.grant("sea_glass" if prefix=="coral_find_" else "wood",2);items.grant("driftwood" if prefix=="coral_find_" else "leaf",1);save();m.notify("线索已收好 "+str(found_count(prefix))+" / 3 · 回岛上工作台开始拼装。")
func found_count(prefix:String)->int:
	var total:=0
	for key in items.data().knowledge:
		if str(key).begins_with(prefix) and items.data().knowledge[key]:total+=1
	return total
func shore_hunt_panel(island:String):
	m.open_modal("潮汐拾物" if island=="coral" else "森林木纹采样")
	m.label(m.modal_box,"先沿岛上的路找齐三种"+("海玻璃与漂木" if island=="coral" else "木纹采样")+"，观察后回工作台拼合。每处有真实小模型和 F 提示，可在线恢复。",25)
	m.label(m.modal_box,"已发现 "+str(found_count(island+"_find_"))+" / 3",24)

func observe_tide(index:int):
	m.open_modal("浅海观察 · 认出眼前游鱼")
	m.label(m.modal_box,"看一看观察牌旁的游动鱼群，选择它的主色。",24)
	for i in 3:
		var chosen:int=i;m.button(m.modal_box,["暖金小鱼","薄荷青鱼","淡紫礁鱼"][i],func():
			if chosen!=index:m.notify("再看一眼鱼群的颜色，认准后记录。");return
			items.data().knowledge["tide_seen_"+str(index)]={"fish":index,"water_phase":int(float(items.data().online)/60)%3};save();m.close_modal();m.notify("游鱼与水位已记入观察图鉴。"))
func tide_panel():
	m.open_modal("潮汐观察图鉴")
	m.label(m.modal_box,"沿东湾三块实际浅海观察牌看鱼、辨色并记录水位，再回观察屋拼合图鉴。",25)
	m.label(m.modal_box,"已记录 "+str(found_count("tide_seen_"))+" / 3",24)

func _process(delta:float):
	if m==null or not m.active_game:return
	if not m.modal.visible:items.data().online=float(items.data().online)+delta
	if crafting:
		if Input.is_physical_key_pressed(KEY_ESCAPE):crafting=false;craft_job={};m.notify("已取消制作，材料和作品保持原状。")
		elif not m.modal.visible and not m.environment_controls.overview:craft_clock+=delta;m.prompt.text="制作中 %d%% · Esc 取消"%int(clampf(craft_clock/float(craft_job.seconds),0,1)*100)
		if crafting and craft_clock>=float(craft_job.seconds):complete_craft()
	if not placing_uid.is_empty():update_placement();m.prompt.text=placement_reason
	if is_instance_valid(puzzle) and puzzle_topic=="star" and m.bay!=null and m.bay.dual!=null:
		var star:Node3D=m.bay.dual.models.get("star")
		if is_instance_valid(star):
			for i in 3:
				var needle:Node3D=star.get_node_or_null("CreativeNeedle"+str(i))
				if needle==null:
					needle=Node3D.new();needle.name="CreativeNeedle"+str(i);star.add_child(needle);models.box(needle,Vector3(.28,0,.13+i*.02),Vector3(.56,.025,.025),["e7cf93","a8c7b4","ccb7d9"][i])
				needle.rotation.z=float(puzzle.values[i])*TAU/16
	tick+=delta
	if tick<.18:return
	tick=0;ensure_sources();refresh_equipment();refresh_placed()
	update_vehicle_basket()
	for id in source_nodes:
		var node:Node3D=source_nodes[id];node.visible=interested(node.position,145)
		if id.begins_with("C110_TIDE_"):
			for fish in node.get_children():
				if not str(fish.name).begins_with("Fish"):continue
				var i:int=int(str(fish.name).trim_prefix("Fish"));var t:float=float(items.data().online)*.4+i;fish.position.x=1.8+sin(t)*1.2;fish.position.z=10.5+cos(t*.8+i)*1.1;fish.position.y=float(node.get_meta("water_y",-.65))+sin(t*2)*.1;fish.rotation.y=atan2(cos(t),-sin(t*.8+i))
	quickbar.visible=m.active_game and not m.modal.visible and not m.environment_controls.overview
	if quickbar.visible:
		var labels:Array=[]
		for i in 8:labels.append(str(i+1)+" "+name_of(str(items.data().shortcuts[i])))
		quickbar.text="B 背包   G 布置   "+"  ·  ".join(labels)

func update_vehicle_basket():
	if m.bay==null or m.bay.vehicles==null:return
	var vehicle=m.bay.vehicles;var uid:String=items.data().equipped_hand;var bouquet:bool=items.data().works.has(uid) and items.data().works[uid].item=="legacy_bouquet"
	if is_instance_valid(held_hand):held_hand.visible=not (vehicle.mounted=="bike" and bouquet)
	if vehicle.mounted!="bike" or not is_instance_valid(vehicle.moving):return
	var old:Node3D=vehicle.moving.get_node_or_null("CreativeBasket")
	if old!=null and old.get_meta("uid","")!=uid:old.queue_free();return
	if bouquet and old==null:
		var model:Node3D=models.make("legacy_bouquet",canonical_variant(items.data().works[uid]));model.name="CreativeBasket";model.set_meta("uid",uid);vehicle.moving.add_child(model);model.position=Vector3(0,1.15,-.97);model.scale=Vector3.ONE*.7
