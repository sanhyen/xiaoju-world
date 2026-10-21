extends Control
## Illustrated visitor map. Every point stays selectable; nearby names unfold with zoom.
var spec:Dictionary={}
var player_pos:=Vector3.ZERO
var discovered:Array=[]
var font:Font
var clues:Array=[]
var mini:=false
var yaw:=0.0
var target:Dictionary={}
var view_rect:=Rect2(-475,-455,950,1100)
var region_id:=""
var layers:Dictionary={"transport":true,"collection":true,"rest":true,"theme":true}
var layout_reference
var search_query:=""
var selected_kind:=""
var all_places_cache:Array=[]
var cache_signature:=""
var labels:Array=[]
var hits:Array=[]
var clusters:Array=[]
var navigation=preload("res://scripts/creative_navigation110.gd").new()
const SHORT={"Z01":"迎宾海港","Z02":"海湾沙岸","Z03":"花音小街","Z04":"星光广场","Z05":"山麓舞台","Z06":"艺文山腰","Z07":"花谷小径","Z08":"北山林海","Z09":"崖湾石街","ISLAND":"珊瑚岛","ISLAND_01":"珊瑚岛","ISLAND_02":"萤火森屿","B01":"海风站","B02":"海边咖啡","B03":"花音唱片","B04":"溪谷花房","B05":"光影画廊","B06":"星幕影院","B07":"拾光纪念馆","B08":"律动排练","B09":"回声混音","B10":"星光演艺","B11":"星笺杂货","B12":"海风小屋","B13":"游客中心","H01":"麦香烘焙屋","H02":"种子农具屋","H03":"牧场画室","H04":"花果茶坊","H05":"黄铜观海阁","H06":"藤编风铃屋","H07":"松果壁炉屋","H08":"植物图鉴阁","H09":"花艺茶席","H10":"山海印章屋","H11":"八音盒小屋","H12":"暗房明信片","H13":"干花工坊","H14":"咖啡猫屋","THEME_EVERYDAY":"每一天唱片屋","THEME_WAITING":"等不到你街角","THEME_POEM":"孤独与诗书楼","THEME_FROST":"醉飞霜舞台","THEME_BLOSSOM":"花间令花馆","THEME_DAILY":"日常摄影馆","BAKERY":"牛角包工坊","LISTENING_WEST":"黑胶画报廊","LISTENING_EAST":"留声机工坊","CRAFT":"海玻璃拼贴坊"}
signal destination(place)
signal view_changed
func point(x:float,z:float)->Vector2:
	if mini:return size*.5+Vector2(x-player_pos.x,z-player_pos.z)*(size.x/320.0)
	var rect:Rect2=plot_rect();return rect.position+(Vector2(x,z)-view_rect.position)*scale_m()
func plot_rect()->Rect2:
	var factor:float=minf(size.x/maxf(1,view_rect.size.x),size.y/maxf(1,view_rect.size.y))*.96
	var extent:Vector2=view_rect.size*factor;return Rect2((size-extent)*.5,extent)
func world_point(p:Vector2)->Vector2:return view_rect.position+(p-plot_rect().position)/scale_m()
func scale_m()->float:return size.x/320.0 if mini else minf(size.x/maxf(1,view_rect.size.x),size.y/maxf(1,view_rect.size.y))*.96
func inside(p:Vector2,pad:float=0)->bool:return p.x>=pad and p.y>=pad and p.x<=size.x-pad and p.y<=size.y-pad
func stroke(a:Vector2,c:Vector2,tone:Color,width:float,dashed:bool=false):
	var delta:Vector2=c-a;var lo:float=0;var hi:float=1
	var dirs:Array=[-delta.x,delta.x,-delta.y,delta.y];var limits:Array=[a.x,size.x-a.x,a.y,size.y-a.y]
	for i in 4:
		if absf(dirs[i])<.00001:
			if limits[i]<0:return
		else:
			var t:float=limits[i]/dirs[i]
			if dirs[i]<0:lo=maxf(lo,t)
			else:hi=minf(hi,t)
	if lo>hi:return
	if dashed:draw_dashed_line(a+delta*lo,a+delta*hi,tone,width,5,true)
	else:draw_line(a+delta*lo,a+delta*hi,tone,width,true)
func polygon(points:PackedVector2Array,tone:Color):
	var bounds:=PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
	for clipped in Geometry2D.intersect_polygons(points,bounds):
		if clipped.size()>2:draw_colored_polygon(clipped,tone)
func ellipse(center:Array,radius:Array,tone:Color):
	var shape:=PackedVector2Array()
	for i in 64:shape.append(point(center[0]+cos(i*TAU/64)*radius[0],center[1]+sin(i*TAU/64)*radius[1]))
	polygon(shape,tone)
func label_at(p:Vector2,words:String,tone:Color=Color("345349"),height:int=14):
	if inside(p,3):draw_string(font,p,words,HORIZONTAL_ALIGNMENT_LEFT,-1,height,tone)
func clean_name(place:Dictionary)->String:
	var text:String=str(place.name);var regex:=RegEx.new();regex.compile("(?:^| )(?:(?:B|H|Z)[0-9]{2})(?: |$)");text=regex.sub(text," ",true).strip_edges()
	return text
func short_name(place:Dictionary)->String:
	if place.has("short_name"):return str(place.short_name)
	return str(SHORT.get(str(place.id),clean_name(place)))
func visible_place(place:Dictionary)->bool:
	var kind:String=place.get("kind","")
	if kind in ["reserved","upper"]:return false
	return true
func available_label(rect:Rect2)->bool:
	if not Rect2(Vector2(6,29),size-Vector2(12,36)).encloses(rect):return false
	for previous in labels:
		if rect.grow(2).intersects(previous):return false
	return true
func nearby_label_rect(anchor:Vector2,words:String,priority:bool,occupied:Array)->Rect2:
	var height:int=16 if priority else 14;var extent:Vector2=font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,height)+Vector2(8,5)
	# A name belongs beside its real marker. Crowding is carried by the directory
	# and a local cluster, never by moving a label into a distant empty sea corner.
	for radius in [8.0,17.0]:
		for offset in [Vector2(radius,-height-3),Vector2(radius,5),Vector2(-extent.x-radius,-height-3),Vector2(-extent.x-radius,5),Vector2(-extent.x*.5,-radius-height),Vector2(-extent.x*.5,radius)]:
			var rect:=Rect2(anchor+offset,extent)
			if not Rect2(Vector2(7,31),size-Vector2(14,40)).encloses(rect):continue
			var free:=true
			for previous in occupied:
				if rect.grow(3).intersects(previous):free=false;break
			if free:return rect
	return Rect2()
func try_label(anchor:Vector2,words:String,priority:bool=false)->Rect2:
	var chosen:Rect2=nearby_label_rect(anchor,words,priority,labels)
	if not chosen.has_area():return chosen
	labels.append(chosen);draw_style_box(label_style(),chosen)
	label_at(chosen.position+Vector2(4,16 if priority else 14),words,Color("345349"),16 if priority else 14);return chosen
func secondary_point(place:Dictionary)->bool:
	return place.get("kind","") in ["free_boat","vehicle","wading","seaside","upper"] or place.get("role","")=="annex"
func map_label_name(place:Dictionary)->String:
	var name:String=short_name(place)
	return name if name.length()<=9 else name.left(8)+"…"
func name_priority(place:Dictionary)->int:
	if str(place.id)==str(target.get("id","")):return 120
	if not search_query.is_empty() and search_query.to_lower() in (short_name(place)+clean_name(place)+str(place.get("subtitle",""))).to_lower():return 110
	if place.get("region_name",false):return 100
	if place.get("kind","") in ["zone","island"]:return 100
	if str(place.id) in ["CASTLE_MAIN","CABLE_LOWER","CABLE_UPPER","AZURE_VIEW"]:return 90
	if str(place.id) in ["B01","B02","B03","B04","B05","B06","B07","B08","B09","B10","B11","B12","B13"]:return 80
	return 10 if secondary_point(place) else 50
func regional_name_groups(entries:Array)->Array:
	var result:Array=[]
	for area in [["AZURE_","晴岬叠台镇"],["CASTLE_","花霞城郭"]]:
		var members:Array=[];var center:=Vector2.ZERO
		for place in entries:
			if str(place.id).begins_with(area[0]) and place.get("kind","")!="upper":members.append(place);center+=Vector2(place.x,place.z)
		if members.is_empty():continue
		center/=float(members.size());result.append({"id":"MAP_AREA_"+str(area[0]),"name":area[1],"kind":"cluster","region_name":true,"x":center.x,"z":center.y,"members":members})
	return result
func name_layout(entries:Array)->Dictionary:
	var names:Array=[];var pending:Array=[];var occupied:Array=labels.duplicate();var sorted:Array=entries.duplicate()
	if view_rect.size.x>680:sorted.append_array(regional_name_groups(entries))
	sorted.sort_custom(func(a,b):return str(a.id)<str(b.id) if name_priority(a)==name_priority(b) else name_priority(a)>name_priority(b))
	var overview:bool=view_rect.size.x>680;var budget:int=36 if overview else 90
	for place in sorted:
		var at:Vector2=point(place.x,place.z)
		if not visible_place(place) or not inside(at,9):continue
		var score:int=name_priority(place);var major:bool=place.get("kind","") in ["zone","island"] or place.get("region_name",false)
		if (overview and secondary_point(place) and score<110) or names.size()>=budget:
			if not secondary_point(place) and not major:pending.append(place)
			continue
		var words:String=map_label_name(place);var rect:Rect2=nearby_label_rect(at,words,major,occupied)
		if rect.has_area():names.append({"place":place,"point":at,"words":words,"rect":rect,"major":major});occupied.append(rect)
		elif not secondary_point(place) and not major:pending.append(place)
	var groups:Array=[]
	for place in pending:
		var at:Vector2=point(place.x,place.z);var group:Dictionary={}
		for candidate in groups:
			if at.distance_to(candidate.seed)<34:group=candidate;break
		if group.is_empty():group={"seed":at,"sum":Vector2.ZERO,"members":[]};groups.append(group)
		group.members.append(place);group.sum+=at
	var badges:Array=[]
	for group in groups:
		if group.members.size()<3:continue
		var at:Vector2=group.sum/float(group.members.size());var words:String=str(group.members.size())+"处";var rect:Rect2=nearby_label_rect(at,words,false,occupied)
		if not rect.has_area():continue
		var region:Dictionary={"id":"nearby_cluster","name":"附近地点 · "+words,"kind":"cluster","x":world_point(at).x,"z":world_point(at).y,"members":group.members}
		badges.append({"place":region,"point":at,"words":words,"rect":rect,"major":false});occupied.append(rect)
	return {"names":names,"clusters":badges}
func label_style()->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color(.98,.96,.88,.94);style.corner_radius_top_left=5;style.corner_radius_bottom_right=5;style.border_width_bottom=1;style.border_color=Color("bdcdb2");return style
func _draw():
	if spec.is_empty() or font==null:return
	labels.clear();hits.clear();clusters.clear();draw_rect(Rect2(Vector2.ZERO,size),Color("9fd9d2"))
	var cfg:Dictionary=spec.get("bay_layout",{})
	if cfg.is_empty():return
	# Continuous mainland shore, shallow rim and simplified natural forms.
	var land:=PackedVector2Array([point(-480,-480),point(480,-480)])
	for i in range(cfg.shore.size()-1,-1,-1):land.append(point(cfg.shore[i][0],cfg.shore[i][1]))
	polygon(land,Color("d6dfb8"))
	for i in cfg.shore.size()-1:
		stroke(point(cfg.shore[i][0],cfg.shore[i][1]),point(cfg.shore[i+1][0],cfg.shore[i+1][1]),Color("efe3c0"),14 if not mini else 9)
	if not mini:
		for i in 17:
			var x:float=-400+i*51;var z:float=-385+sin(i*2.3)*60
			polygon(PackedVector2Array([point(x-35,z+65),point(x,z-34),point(x+45,z+62)]),Color("94b58c"));polygon(PackedVector2Array([point(x-20,z+52),point(x,z-12),point(x+22,z+52)]),Color("b3c69b"))
		for i in 28:
			var at:Vector2=point(-360+(i%9)*79,390+(i/9)*86)
			if inside(at,18):draw_arc(at,15,.15,PI-.15,12,Color(.85,.98,.93,.55),1.5,true)
	var island:Dictionary=cfg.island;ellipse(island.center,[island.radius[0]*1.45,island.radius[1]*1.5],Color("7fcfc4"));ellipse(island.center,island.radius,Color("f1e5c7"));ellipse(island.center,[island.radius[0]*.72,island.radius[1]*.72],Color("bed1a1"))
	var forest:Dictionary=cfg.get("island2",{})
	if not forest.is_empty():ellipse(forest.center,[forest.radius[0]*1.5,forest.radius[1]*1.5],Color("82cdbd"));ellipse(forest.center,forest.radius,Color("f0e5c3"));ellipse(forest.center,[forest.radius[0]*.87,forest.radius[1]*.82],Color("8db085"))
	for river in cfg.rivers:
		for i in river.points.size()-1:stroke(point(river.points[i][0],river.points[i][2]),point(river.points[i+1][0],river.points[i+1][2]),Color("79bab4"),maxf(3,river.width*scale_m()))
	for road in cfg.roads:
		if region_id.is_empty() and road.width<4.2:continue
		for i in road.points.size()-1:
			var a:Vector2=point(road.points[i][0],road.points[i][2]);var c:Vector2=point(road.points[i+1][0],road.points[i+1][2]);var overview:bool=view_rect.size.x>680
			stroke(a,c,Color("b1a281"),2.6 if overview else 4 if road.width>=4.2 else 2.5);stroke(a,c,Color("eee2c3"),1.4 if overview else 2.4 if road.width>=4.2 else 1.3)
	for route in cfg.sea_walk.routes:
		for i in route.points.size()-1:
			var a:Vector2=point(route.points[i][0],route.points[i][2]);var c:Vector2=point(route.points[i+1][0],route.points[i+1][2]);stroke(a,c,Color("a1845d"),3 if view_rect.size.x>680 else 4);stroke(a,c,Color("e5cda1"),1.5 if view_rect.size.x>680 else 2)
	if not forest.is_empty() and (region_id=="ISLAND_02" or mini):
		for r in forest.canopy_routes:
			for i in r.points.size()-1:stroke(point(r.points[i][0],r.points[i][2]),point(r.points[i+1][0],r.points[i+1][2]),Color("946f50"),2.5,true)
	for house in spec.buildings:building(house.x,house.z,house.w,house.d,Color("e7bf88"))
	for h in cfg.living_houses:building(h.center[0],h.center[2],h.size[0],h.size[1],Color("d6a185"))
	for h in cfg.get("cliff_district",{}).get("buildings",[]):building(h.center[0],h.center[2],h.size[0],h.size[1],Color("b3b59b"))
	for h in forest.get("buildings",[]):building(h.center[0],h.center[2],h.size[0],h.size[1],Color("a08458"))
	for h in cfg.theme_rooms:building(h.center[0],h.center[2],h.size[0],h.size[1],Color("c7a5bd"))
	for h in cfg.get("street_wings",[]):building(h.center[0],h.center[2],h.size[0],h.size[1],Color("d4b38e"))
	for i in 4:building(276+(4 if i in [1,2] else 0),426+i*15,8.2,8.2,Color("c6a879"))
	building(263.5,421,11.4,9,Color("c6a879"))
	if layout_reference!=null and layout_reference.get("creative_places") is Array:
		for h in layout_reference.creative_places:
			if h.get("center") is Array and h.get("size") is Array:building(h.center[0],h.center[2],h.size[0],h.size[1],Color("cdad91"))
	draw_target_route()
	var drawn:Array=places()
	drawn.sort_custom(func(a,c):return int(a.get("kind","") in ["zone","island"])>int(c.get("kind","") in ["zone","island"]))
	for place in drawn:
		var kind:String=place.get("kind","");var p:Vector2=point(place.x,place.z)
		if not inside(p,9) or not visible_place(place):continue
		if mini:
			if kind in ["venue","island"]:draw_circle(p,3.5,Color("6d8362"))
			continue
		var major:bool=kind in ["zone","island"];var radius:float=4 if major else 1.9 if secondary_point(place) else 2.6
		draw_circle(p,radius+2,Color("f8edcd"));draw_circle(p,radius,Color("547764") if major else Color("b58475") if kind=="theme" else Color("8d8265"));hits.append({"place":place,"point":p})
		if not search_query.is_empty() and search_query.to_lower() in (short_name(place)+clean_name(place)+str(place.get("subtitle",""))).to_lower():draw_arc(p,8,0,TAU,20,Color("d49b35"),2,true)
	if not mini:
		var plan:Dictionary=name_layout(drawn);clusters=plan.clusters
		for entry in plan.names+plan.clusters:
			var rect:Rect2=entry.rect;var major:bool=entry.major;labels.append(rect);draw_style_box(label_style(),rect);label_at(rect.position+Vector2(4,16 if major else 14),entry.words,Color("345349"),16 if major else 14)
			if entry.place.get("kind","")=="cluster":hits.append({"place":entry.place,"point":entry.point,"label":rect})
			else:
				for hit in hits:
					if str(hit.place.id)==str(entry.place.id):hit.label=rect;break
	if not target.is_empty():
		var p:Vector2=point(target.x,target.z)
		if inside(p,8):draw_arc(p,13,0,TAU,24,Color("e0ad42"),3,true)
	var p:Vector2=point(player_pos.x,player_pos.z);var direction:=Vector2(-sin(yaw),-cos(yaw))
	if inside(p,8):draw_colored_polygon(PackedVector2Array([p+direction*10,p+direction.rotated(2.5)*8,p+direction.rotated(-2.5)*8]),Color("e4a94f"));draw_arc(p,12,0,TAU,20,Color("f7f1d6"),2,true)
	if not mini:label_at(Vector2(14,21),"N ↑   山海全景 · 全建筑与交通" if region_id.is_empty() else "N ↑   区域详图 · "+SHORT.get(region_id,"附近地点"),Color("34554a"),16)
	draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("84a68f"),false,2)
func navigation_world():
	var cursor:Node=get_parent()
	while cursor!=null:
		var candidate=cursor.get("world")
		if candidate is Node and candidate.get("layout")==layout_reference:return candidate
		cursor=cursor.get_parent()
	return null
func draw_target_route():
	if target.is_empty():return
	var routed:=false
	if layout_reference!=null:
		navigation.ensure_layout(layout_reference,navigation_world())
		var guide:Dictionary=navigation.route_from(player_pos,target)
		if guide.get("connected",false):
			var path:PackedVector3Array=guide.points
			draw_route_dashes(path,Color(.43,.35,.19,.75),4.8 if not mini else 4.0)
			draw_route_dashes(path,Color("f5ca62"),2.8 if not mini else 2.3)
			routed=true
	if not routed:
		# A small bearing arrow communicates direction without inventing a walkable sea/air line.
		var start:Vector2=point(player_pos.x,player_pos.z);start=start.clamp(Vector2(24,44),size-Vector2(24,42))
		var bearing:Vector2=Vector2(float(target.get("x",player_pos.x))-player_pos.x,float(target.get("z",player_pos.z))-player_pos.z).normalized()
		if bearing.length_squared()>.5:
			var tip:Vector2=start+bearing*28
			stroke(start+bearing*15,tip,Color("f1c55e"),2.7)
			draw_colored_polygon(PackedVector2Array([tip+bearing*5,tip+bearing.rotated(2.5)*7,tip+bearing.rotated(-2.5)*7]),Color("f1c55e"))
	var words:String="金线 · 道路与栈道" if routed else "目标方向 · 未接通步行路线"
	var extent:Vector2=font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,14)+Vector2(12,8)
	var legend:=Rect2(Vector2(8,size.y-extent.y-6),extent);labels.append(legend);draw_style_box(label_style(),legend)
	label_at(legend.position+Vector2(6,18),words,Color("735c2c"),14)
func draw_route_dashes(path:PackedVector3Array,tone:Color,width:float):
	# Carry dash phase across short sea-walk spans, so a detailed polyline stays dashed.
	var phase:=0.0
	for i in path.size()-1:
		var a:Vector2=point(path[i].x,path[i].z);var c:Vector2=point(path[i+1].x,path[i+1].z);var length:float=a.distance_to(c)
		if length<.0001:continue
		var along:Vector2=(c-a)/length;var travelled:=0.0
		while travelled<length-.0001:
			var painted:bool=phase<7.0;var span:float=minf(length-travelled,(7.0 if painted else 12.0)-phase)
			if painted:stroke(a+along*travelled,a+along*(travelled+span),tone,width)
			travelled+=span;phase=fmod(phase+span,12.0)
func building(x:float,z:float,width:float,depth:float,tone:Color):
	var a:Vector2=point(x-width*.5,z-depth*.5);var c:Vector2=point(x+width*.5,z+depth*.5);var rect:=Rect2(a,c-a).intersection(Rect2(Vector2.ZERO,size))
	if not rect.has_area():return
	draw_rect(rect.grow(1),Color("f4e5c5"));draw_rect(rect,tone);stroke(rect.position,Vector2(rect.end.x,rect.position.y),Color("867356"),2)
	if rect.size.x>9 and rect.size.y>6:stroke(rect.position+rect.size*Vector2(.2,.5),rect.position+rect.size*Vector2(.8,.5),Color("f7ebca"),2)
func places()->Array:
	var creative:Array=[]
	if layout_reference!=null and layout_reference.get("creative_places") is Array:creative=layout_reference.creative_places
	elif spec.get("bay_layout",{}).get("creative_places") is Array:creative=spec.bay_layout.creative_places
	var signature:String=str(spec.get("version",""))+str(clues)+str(creative.size())
	if cache_signature==signature and not all_places_cache.is_empty():return all_places_cache
	var result:Array=preload("res://scripts/location_registry.gd").places(spec,clues)
	result.append(preload("res://scripts/bay_dual106.gd").FOREST_PARKING.duplicate(true))
	for i in spec.bay_layout.docks.size():
		var p:Array=spec.bay_layout.docks[i];result.append({"id":"VEHICLE_MAP_"+str(i),"name":"双车停车架 "+str(i+1),"kind":"vehicle","x":p[0],"z":p[2],"safe":p})
	for h in spec.bay_layout.get("street_wings",[]):
		var door:Array=h.link[0] if h.get("link",[]).size()>0 else [h.center[0],h.center[1],h.center[2]+h.size[1]*.5+1]
		result.append({"id":h.id,"name":h.name,"kind":"workshop","x":h.center[0],"z":h.center[2],"safe":door,"subtitle":"可进入的主题工坊"})
	var creative_ids:Dictionary={}
	for record in creative:creative_ids[str(record.get("id",""))]=true
	for i in 4:
		if creative_ids.has("VILLA_"+str(i)):continue
		var x:float=276+(4 if i in [1,2] else 0);var z:float=426+i*15
		result.append({"id":"CORAL_VILLA_"+str(i),"name":"珊瑚水屋"+["一","二","三","四"][i],"kind":"forest_house","x":x,"z":z,"safe":[x-5.3,1.6,z],"subtitle":"水上客厅、亲水甲板与网床"})
	if not creative_ids.has("ISLAND_LOBBY"):result.append({"id":"CORAL_LOBBY","name":"海上迎宾大堂","kind":"forest_house","x":263.5,"z":421,"safe":[263.5,1.7,425.5]})
	for record in creative:
		if not record.get("center") is Array:continue
		var point:Array=record.get("travel_point",record.get("door",record.center));var item:Dictionary=record.duplicate(true)
		item["kind"]=str(record.get("kind","venue"));item["x"]=record.center[0];item["z"]=record.center[2]
		item["safe"]=[point[0],float(point[1])-float(spec.bay_layout.sea_y),point[2]]
		if not item.has("subtitle"):item["subtitle"]="可进入建筑"+(" · 私人住处" if record.get("private",false) else "")
		result.append(item)
		# Registered floor entries contain world-space landings. Numeric floors only describe heights.
		var entries:Array=[]
		if record.get("floor_entries") is Array:entries=record.floor_entries
		elif record.get("layout") is Dictionary:entries=record.layout.get("floor_entries",[])
		if entries.is_empty() and record.get("floors") is Array:
			for entry in record.floors:
				if entry is Dictionary or entry is Array:entries.append(entry)
		for level in entries.size():
			var entry=entries[level];var landing:Array=[];var title:String="第 %d 层"%(level+1)
			if entry is Dictionary:landing=entry.get("point",[]);title=str(entry.get("name",title))
			elif entry is Array:landing=entry
			if landing.size()<3:continue
			result.append({"id":str(record.id)+"_FLOOR_"+str(level),"parent":record.id,"name":str(record.name)+" · "+title,"kind":"upper","level":title,"x":landing[0],"z":landing[2],"safe":[landing[0],float(landing[1])-float(spec.bay_layout.sea_y),landing[2]]})
	var unique:Dictionary={}
	for place in result:
		if str(place.id)=="ISLAND_01":continue
		unique[str(place.id)]=place
	all_places_cache=unique.values();cache_signature=signature;return all_places_cache
func focus_region(place:Dictionary):
	region_id=str(place.id);var cfg:Dictionary=spec.bay_layout
	if place.get("members") is Array and not place.members.is_empty():
		var bounds:=Rect2(Vector2(place.members[0].x,place.members[0].z),Vector2.ZERO)
		for member in place.members:bounds=bounds.expand(Vector2(member.x,member.z))
		var center:Vector2=bounds.get_center();var extent:=Vector2(maxf(115,bounds.size.x+65),maxf(90,bounds.size.y+55));view_rect=Rect2(center-extent*.5,extent)
	elif region_id in ["ISLAND","ISLAND_01"]:view_rect=Rect2(140,388,180,145)
	elif region_id=="ISLAND_02":view_rect=Rect2(-144,425,177,142)
	elif cfg.zones.has(region_id):
		var points:Array=cfg.zones[region_id].polygon;var bounds:=Rect2(Vector2(points[0][0],points[0][1]),Vector2.ZERO)
		for q in points:bounds=bounds.expand(Vector2(q[0],q[1]))
		view_rect=bounds.grow(25)
	else:view_rect=Rect2(place.x-85,place.z-65,170,130)
	queue_redraw();view_changed.emit()
func reset_view():region_id="";view_rect=Rect2(-475,-455,950,1100);queue_redraw();view_changed.emit()
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and not mini:
			var anchor:Vector2=world_point(event.position);var factor:float=.78 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.28
			if (view_rect.size.x<85 and factor<1) or (view_rect.size.x>1200 and factor>1):return
			view_rect=Rect2(anchor+(view_rect.position-anchor)*factor,view_rect.size*factor);region_id="附近" if region_id.is_empty() else region_id;queue_redraw();view_changed.emit();accept_event();return
		if event.button_index!=MOUSE_BUTTON_LEFT:return
		if mini:destination.emit({});accept_event();return
		var nearest:Dictionary={};var distance:float=30
		for hit in hits:
			var d:float=0.0 if hit.get("label",Rect2()).has_point(event.position) else event.position.distance_to(hit.point)
			if d<distance:distance=d;nearest=hit.place
		if nearest.is_empty():return
		if nearest.get("kind","")=="cluster":focus_region(nearest);destination.emit({"region":nearest});accept_event();return
		if nearest.get("kind","") in ["zone","island"] and region_id.is_empty():focus_region(nearest);destination.emit({"region":nearest});accept_event();return
		var choices:Array=[]
		for place in places():
			if point(place.x,place.z).distance_to(point(nearest.x,nearest.z))<14:choices.append(place)
		destination.emit({"choices":choices} if choices.size()>1 else nearest);accept_event()
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT and not mini:
		view_rect.position-=event.relative/scale_m();region_id="附近" if region_id.is_empty() else region_id;queue_redraw();view_changed.emit();accept_event()
