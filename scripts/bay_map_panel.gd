extends RefCounted
var m
var map
var floor_plan
var search:LineEdit
var list:GridContainer
var detail:VBoxContainer
var directory_title:Label
var selected:Dictionary={}
func build(main):
	m=main;m.open_modal("山海全景导览 · 建筑、双岛与云麓",1760)
	var panel:PanelContainer=m.modal_box.get_parent();panel.position=Vector2(80,32);panel.size=Vector2(1760,1016)
	var tools:=HBoxContainer.new();m.modal_box.add_child(tools)
	search=LineEdit.new();search.name="MapSearch110";search.placeholder_text="搜索中文名称、主题、船点或楼层 · 所有地点默认显示";search.custom_minimum_size=Vector2(940,42);search.add_theme_font_size_override("font_size",21);tools.add_child(search)
	m.button(tools,"返回全图",func():floor_plan.hide();map.reset_view();selected={};refresh_detail())
	m.button(tools,"我的附近",func():map.focus_region({"id":"附近","x":m.player.position.x,"z":m.player.position.z});refresh_list())
	m.label(m.modal_box,"全部地点保留标记；短名贴近地标，密集处点击聚簇或滚轮放大。右侧中文目录始终完整，可直接搜索与前往。",18)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);m.modal_box.add_child(row)
	map=Control.new();map.set_script(preload("res://scripts/bay_map_view.gd"));map.name="VisitorMap106";map.spec=m.world.spec;map.layout_reference=m.world.layout;map.font=m.font;map.player_pos=m.player.position;map.yaw=m.player.yaw;map.target=m.target_zone;map.discovered=m.state.discovered;map.clues=m.state.activities.get("clues",[]);map.custom_minimum_size=Vector2(1050,650);map.clip_contents=true;row.add_child(map)
	var sidebar:=VBoxContainer.new();sidebar.custom_minimum_size=Vector2(600,650);sidebar.add_theme_constant_override("separation",6);row.add_child(sidebar)
	directory_title=m.label(sidebar,"地点目录 · 全部可查",20)
	var scroll:=ScrollContainer.new();scroll.name="AllMapLocations110";scroll.custom_minimum_size=Vector2(600,430);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sidebar.add_child(scroll)
	list=GridContainer.new();list.name="MapDirectoryGrid110";list.columns=2;list.custom_minimum_size=Vector2(578,0);list.add_theme_constant_override("h_separation",6);list.add_theme_constant_override("v_separation",4);scroll.add_child(list)
	var detail_scroll:=ScrollContainer.new();detail_scroll.custom_minimum_size=Vector2(600,176);detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sidebar.add_child(detail_scroll)
	detail=VBoxContainer.new();detail.custom_minimum_size=Vector2(578,0);detail.add_theme_constant_override("separation",5);detail_scroll.add_child(detail)
	floor_plan=preload("res://scripts/floor_plan120.gd").new();floor_plan.name="FloorPlan120";map.add_child(floor_plan);floor_plan.setup(m)
	map.destination.connect(choose);map.view_changed.connect(refresh_list);search.text_changed.connect(func(text):map.search_query=text;map.queue_redraw();refresh_list())
	m.label(m.modal_box,"圆点是地点，数字聚簇可展开附近建筑。点击名签或目录查看详情；滚轮缩放、右键拖动，选中后可导航或立即前往。",18)
	var routes:=HBoxContainer.new();m.modal_box.add_child(routes)
	for route in m.world.layout.config.tour_routes:
		var id:String=route.id;m.button(routes,route.name,func():m.bay.workshops.tour_panel(id))
	m.button(routes,"森屿旅行册",m.bay.dual.travel_book)
	refresh_list();refresh_detail()

func compact_button(button:Button,width:float=285):
	button.add_theme_font_size_override("font_size",16);button.custom_minimum_size=Vector2(width,29);button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("365c58") if state=="normal" else Color("4d7269") if state=="hover" else Color("294b49");style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=4;style.content_margin_bottom=4;style.corner_radius_top_left=3;style.corner_radius_bottom_right=3
		if state=="focus":style.draw_center=false;style.border_width_left=1;style.border_width_right=1;style.border_width_top=1;style.border_width_bottom=1;style.border_color=Color("bcd2bd")
		button.add_theme_stylebox_override(state,style)
func directory_rank(place:Dictionary)->int:
	if str(place.id) in ["B01","B02","B03","B04","B05","B06","B07","B08","B09","B10","B11","B12","B13"]:return 0
	if str(place.id).begins_with("THEME_") or str(place.id).begins_with("CASTLE_") or str(place.id).begins_with("AZURE_") or place.get("role","")=="cable":return 1
	if place.get("kind","")=="upper":return 6
	if place.get("kind","") in ["zone","island"]:return 4
	return 5 if map.secondary_point(place) else 2
func refresh_list():
	for child in list.get_children():list.remove_child(child);child.queue_free()
	var query:String=search.text.strip_edges();var count:=0;var entries:Array=map.places().duplicate()
	entries.sort_custom(func(a,b):
		var ak:int=directory_rank(a);var bk:int=directory_rank(b)
		return map.short_name(a).naturalnocasecmp_to(map.short_name(b))<0 if ak==bk else ak<bk)
	for place in entries:
		if place.get("kind","")=="reserved":continue
		var name:String=map.short_name(place)
		if not query.is_empty():
			if not (query.to_lower() in (name+map.clean_name(place)+str(place.get("subtitle",""))).to_lower()):continue
		elif place.get("kind","")=="upper":continue
		var item:Dictionary=place
		var button:Button=m.button(list,name,func():
			if item.get("kind","") in ["zone","island"]:map.focus_region(item)
			selected=item;refresh_detail())
		compact_button(button);button.tooltip_text=map.clean_name(place);count+=1
	directory_title.text=("地点目录 · "+str(count)+"处" if query.is_empty() else "搜索结果 · "+str(count)+"处")+" · 点击名称查看"
	if count==0:m.label(list,"没有匹配地点。试试建筑、主题或中文短名。",18)

func choose(place:Dictionary):
	if place.has("region"):selected=place.region;refresh_detail();return
	if place.has("choices"):
		for child in detail.get_children():child.queue_free()
		m.label(detail,"选择地点与楼层",21)
		for item in place.choices:
			var choice:Dictionary=item;var choice_button:Button=m.button(detail,map.clean_name(choice),func():selected=choice;refresh_detail());compact_button(choice_button,570)
		return
	selected=place;refresh_detail()

func refresh_detail():
	for child in detail.get_children():detail.remove_child(child);child.queue_free()
	if selected.is_empty():m.label(detail,"选中地点后查看详情与楼层",20);m.label(detail,"建筑排在目录前部；区域、船点、木梯和停车架也完整保留。地图缩放只展开名签，不隐藏地点。",17);return
	if selected.get("kind","")=="cluster":
		m.label(detail,"附近地点 · 已展开详图",20);var group:=GridContainer.new();group.columns=2;group.add_theme_constant_override("h_separation",6);detail.add_child(group)
		for member in selected.get("members",[]):
			var choice:Dictionary=member;var choice_button:Button=m.button(group,map.short_name(choice),func():selected=choice;refresh_detail());compact_button(choice_button)
		return
	map.target=selected;map.queue_redraw();m.target_zone=selected
	m.label(detail,map.clean_name(selected),21)
	var description:Label=m.label(detail,str(selected.get("subtitle","已选定地点，可立即前往安全入口。")),16);description.max_lines_visible=2
	if selected.has("level"):m.label(detail,"楼层："+str(selected.level),18)
	if selected.get("private",false):m.label(detail,"私人住处 · 进入后可使用对应展示与生活功能",18)
	var chosen:Dictionary=selected
	var plan_id:String=str(selected.get("parent",selected.id))
	if m.world.layout.creative_places.any(func(p):return str(p.id)==plan_id):compact_button(m.button(detail,"查看本层布局",func():floor_plan.open(chosen)),570)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",6);detail.add_child(actions)
	var button:Button=m.button(actions,"立即前往",func():await m.teleport_zone(chosen);m.close_modal();m.save_game(false));button.disabled=not selected.get("enabled",true);compact_button(button)
	compact_button(m.button(actions,"标记并继续探索",func():m.target_zone=chosen;m.close_modal()))
	var floors:Array=[]
	for place in map.places():
		if place.get("kind","")!="upper":continue
		var parent:String=str(place.get("parent",""))
		if parent==str(selected.id) or str(place.id).begins_with(str(selected.id)+"_"):floors.append(place)
	if not floors.is_empty():
		m.label(detail,"楼层与附属廊",18)
		var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(578,72);detail.add_child(scroll);var box:=GridContainer.new();box.columns=2;box.custom_minimum_size.x=570;box.add_theme_constant_override("h_separation",6);scroll.add_child(box)
		for floor in floors:
			var landing:Dictionary=floor;var floor_button:Button=m.button(box,str(floor.get("level",map.clean_name(floor))),func():selected=landing;refresh_detail());compact_button(floor_button,280)
