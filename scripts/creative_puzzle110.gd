extends Control
## Repeatable construction puzzles: answers are evaluated against geometry, patterns or simulated water.
signal completed(result:Dictionary)
var kind:="order"
var title:=""
var round_index:=0
var rounds:=3
var values:Array=[]
var goal:Array=[]
var rotations:Array=[]
var target_rotations:Array=[]
var selected:=-1
var moves:=0
var elapsed:=0.0
var solved:=false
var note:=""
var rng:=RandomNumberGenerator.new()
var font:Font
var topic:=""
var stable:=0.0
var basins:Array=[.12,.12,.12]
var crop_offset:=Vector2(.5,.5)
var crop_scale:=.72
var photo_texture:Texture2D
var geographic_goals:Array=[]
var geographic_labels:Array=[]
const TONES=[Color("91b9b6"),Color("d3b0bf"),Color("dcc487"),Color("a7b78d"),Color("a7b5ce"),Color("e2d9c2")]
const BOARD=Rect2(220,78,540,360)

func configure(mode:String,label:String,seed_value:int,chosen_font:Font,game_topic:String):
	kind=mode;title=label;font=chosen_font;topic=game_topic;rng.seed=seed_value;custom_minimum_size=Vector2(1000,520);mouse_filter=Control.MOUSE_FILTER_STOP;new_round()

func new_round():
	selected=-1;stable=0;note="";values.clear();goal.clear();rotations.clear();target_rotations.clear()
	if kind in ["dial","light"]:
		for i in 3:
			goal.append(int(geographic_goals[(i+round_index)%geographic_goals.size()]) if not geographic_goals.is_empty() else rng.randi_range(0,15));values.append((int(goal[i])+5+i*2)%16)
	elif kind=="water":values=[2,2,2];goal=[.45,.45,.45];basins=[.12,.12,.12]
	elif kind=="loom":
		for i in 16:goal.append((i%4+i/4+round_index)%3);values.append(0)
	elif kind=="model":values=[0,0,0,0,1,0,0,0,0];goal=[]
	elif kind=="crop":crop_offset=Vector2(.5,.5);crop_scale=.94;goal=[.60+round_index*.04]
	else:
		var count:int=9 if kind=="mosaic" else 6
		for i in count:goal.append(i);values.append(i);rotations.append(rng.randi_range(0,3));target_rotations.append((i+round_index)%4)
		if kind=="tide":goal=[0,3,1,4,2,5]
		for i in count:
			var j:int=rng.randi_range(0,count-1);var old=values[i];values[i]=values[j];values[j]=old
		if values==goal:values.reverse()
	queue_redraw()

func cell_rect(index:int,small:bool=false)->Rect2:
	var cols:int=4 if kind=="loom" else 3
	var rows:int=4 if kind=="loom" else 3 if kind in ["mosaic","model"] else 2
	var panel:Rect2=Rect2(28,112,145,145) if small else BOARD
	var size_value:=Vector2(panel.size.x/cols,panel.size.y/rows)
	return Rect2(panel.position+Vector2(index%cols,index/cols)*size_value,size_value).grow(-6 if not small else -2)

func label(at:Vector2,word:String,size_value:int=20,tone:Color=Color("ede7d3")):
	if font!=null:draw_string(font,at,word,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,tone)

func _draw():
	draw_style_box(panel_style(),Rect2(0,0,1000,520));label(Vector2(24,35),title,25)
	label(Vector2(24,68),"第 %d / %d 轮 · %d 秒 · 操作 %d 次"%[round_index+1,rounds,int(elapsed),moves],19,Color("d7cfb2"))
	if kind in ["dial","light"]:draw_dials()
	elif kind=="water":draw_water()
	elif kind=="crop":draw_crop()
	else:
		for i in values.size():draw_tile(cell_rect(i),int(values[i]),int(rotations[i]) if not rotations.is_empty() else 0,i==selected)
		if kind!="model":
			label(Vector2(26,100),"参考纹样",18)
			for i in goal.size():draw_tile(cell_rect(i,true),int(goal[i]),int(target_rotations[i]) if not target_rotations.is_empty() else 0,false)
	label(Vector2(24,468),instruction(),19,Color("e4ddc6"));label(Vector2(24,503),note,20,Color("f2cf8e"))

func panel_style()->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("263f40");style.corner_radius_top_left=12;style.corner_radius_top_right=12;style.corner_radius_bottom_left=12;style.corner_radius_bottom_right=12;return style

func draw_tile(rect:Rect2,value:int,rotation:int,active:bool):
	var tone:Color=TONES[posmod(value,TONES.size())];draw_rect(rect,tone.darkened(.05));draw_rect(rect,Color("f4df9d") if active else Color("506967"),false,3 if active else 1)
	var center:Vector2=rect.get_center();var unit:float=minf(rect.size.x,rect.size.y)
	if kind in ["order","mosaic"]:
		var a:float=rotation*PI*.5;var d:=Vector2(cos(a),sin(a));draw_line(center-d*unit*.28,center+d*unit*.28,Color("f7ecd4"),maxf(2,unit*.06));draw_circle(center+d*unit*.30,unit*.09,Color("7c896a"));
		if rect.size.x>70:label(rect.position+Vector2(10,25),str(value+1),20,Color("304c4a"))
	elif kind=="street":
		if value%3==0:
			draw_rect(Rect2(center-Vector2(unit*.25,unit*.10),Vector2(unit*.5,unit*.40)),Color("f3ead2"));draw_colored_polygon(PackedVector2Array([center+Vector2(-unit*.3,-unit*.10),center+Vector2(0,-unit*.35),center+Vector2(unit*.3,-unit*.10)]),Color("6a8378"))
		elif value%3==1:draw_line(center+Vector2(0,unit*.3),center-Vector2(0,unit*.3),Color("566d62"),4);draw_circle(center-Vector2(0,unit*.3),unit*.11,Color("f6dda0"))
		else:draw_rect(Rect2(center-Vector2(unit*.3,unit*.08),Vector2(unit*.6,unit*.16)),Color("7a9290"));draw_line(center-Vector2(unit*.25,0),center+Vector2(unit*.25,0),Color("efe3bb"),2)
		if rect.size.x>70:label(rect.position+Vector2(9,23),["高窗屋","街灯","石街","矮屋","风灯","渡口"][value%6],16,Color("2d4846"))
	elif kind=="journal":
		draw_rect(Rect2(center-Vector2(unit*.28,unit*.32),Vector2(unit*.56,unit*.64)),Color("f3e8cf"))
		for j in 3:draw_line(center+Vector2(-unit*.2,-unit*.15+j*unit*.14),center+Vector2(unit*.2,-unit*.15+j*unit*.14),tone.darkened(.3),2)
		if rect.size.x>70:label(rect.position+Vector2(9,23),["封面","扉页","风景","诗句","邮戳","尾页"][value%6],16,Color("2d4846"))
	elif kind=="model":
		var names:Array=["海面","白沙","丘陵","白屋","椰林"]
		if value==2:draw_colored_polygon(PackedVector2Array([center+Vector2(-unit*.3,unit*.2),center+Vector2(0,-unit*.3),center+Vector2(unit*.3,unit*.2)]),Color("7d9c80"))
		if value==3:draw_rect(Rect2(center-Vector2(unit*.23,unit*.24),Vector2(unit*.46,unit*.5)),Color("f6ebd2"))
		if value==4:draw_line(center+Vector2(0,unit*.3),center-Vector2(0,unit*.3),Color("927d57"),5);draw_circle(center-Vector2(0,unit*.23),unit*.22,Color("80a077"))
		label(rect.position+Vector2(10,23),names[value%5],17,Color("2d4846"))
	elif kind=="sail":
		var p:=PackedVector2Array()
		for corner in [Vector2(-unit*.2,unit*.25),Vector2(-unit*.2,-unit*.30),Vector2(unit*.3,unit*.20)]:p.append(center+corner.rotated(rotation*PI*.5))
		draw_colored_polygon(p,Color("f4e8d0"));draw_line(center-Vector2(unit*.2,unit*.34),center+Vector2(-unit*.2,unit*.3),Color("927a56"),3)
		if rect.size.x>70:label(rect.position+Vector2(9,23),str(value+1)+"号帆片",16,Color("2d4846"))
	elif kind=="tide":
		if value<3:
			draw_fish_oval(rect.get_center(),Vector2(unit*.25,unit*.12),TONES[value]);draw_colored_polygon(PackedVector2Array([center+Vector2(unit*.15,0),center+Vector2(unit*.4,-unit*.17),center+Vector2(unit*.4,unit*.17)]),Color("ede0bc"))
		else:
			for j in 3:draw_line(center+Vector2(-unit*.3,-unit*.15+j*unit*.14),center+Vector2(unit*.3,-unit*.15+j*unit*.14),Color("a6d1c7"),3)
		if rect.size.x>70:label(rect.position+Vector2(6,23),["暖金鱼","薄荷鱼","淡紫鱼","平潮","涨潮","落潮"][value],16,Color("2d4846"))
	elif kind=="loom":
		for j in 5:draw_line(rect.position+Vector2(2,j*rect.size.y/5+3),rect.end-Vector2(2,rect.size.y-j*rect.size.y/5-3),tone.lightened(.22),2)

func draw_dials():
	label(Vector2(26,112),"金线是目标方向",18)
	for i in 3:
		var center:=Vector2(315+i*210,257);var a:float=int(values[i])*TAU/16;var g:float=int(goal[i])*TAU/16
		draw_circle(center,83,TONES[i].darkened(.25));draw_arc(center,86,0,TAU,64,Color("abbeb0"),2)
		for j in 16:
			var angle:float=j*TAU/16;draw_line(center+Vector2(cos(angle),sin(angle))*69,center+Vector2(cos(angle),sin(angle))*78,Color("dce0c9"),2)
		draw_line(center,center+Vector2(cos(g),sin(g))*76,Color("efd293"),6);draw_line(center,center+Vector2(cos(a),sin(a))*65,Color("f1ecde"),3);draw_circle(center,7,Color("677e6d"))
		label(center+Vector2(-42,115),str(geographic_labels[(i+round_index)%geographic_labels.size()]) if not geographic_labels.is_empty() else ["方位环","星位环","纹样环"][i] if kind=="dial" else ["青色片","暖色片","月白片"][i],18)
	label(Vector2(220,420),"点选转盘并拖动指针；三个指针分别对齐金线。",19)

func draw_water():
	for i in 3:
		var rect:=Rect2(250+i*200,150,140,210);draw_rect(rect,Color("718b83"));draw_rect(Rect2(rect.position+Vector2(6,rect.size.y*(1-float(basins[i]))),Vector2(rect.size.x-12,rect.size.y*float(basins[i]))),Color("8bc8c0"))
		for mark in [.35,.65]:draw_line(rect.position+Vector2(0,rect.size.y*(1-mark)),rect.position+Vector2(rect.size.x,rect.size.y*(1-mark)),Color("f4dc9e"),2)
		label(rect.position-Vector2(0,15),["上池","中池","下池"][i]+" %d%%"%int(float(basins[i])*100),19)
		var at:=Vector2(320+i*200,405);draw_circle(at,24,Color("b6a47c"));label(at-Vector2(19,-7),str(int(values[i])*25)+"%",15,Color("334f4c"))
	label(Vector2(26,115),"点击三个铜阀调流量",18);label(Vector2(26,145),"三池同时保持在金线间",18);label(Vector2(26,175),"稳定三秒后开闸成功",18)

func draw_crop():
	var frame:=Rect2(250,95,490,330);draw_rect(frame,Color("c4d7ca"))
	if photo_texture!=null:
		var tw:=Vector2(photo_texture.get_size());var region:=Rect2((crop_offset-Vector2.ONE*crop_scale*.5)*tw,tw*crop_scale);draw_texture_rect_region(photo_texture,frame,region)
	else:
		draw_rect(Rect2(frame.position+Vector2(0,180),Vector2(frame.size.x,150)),Color("8bbebc"));draw_circle(frame.position+Vector2(350,80),40,Color("efd8a8"))
	for t in [1.0/3,2.0/3]:draw_line(frame.position+Vector2(t*frame.size.x,0),frame.position+Vector2(t*frame.size.x,frame.size.y),Color(1,1,.9,.6),1);draw_line(frame.position+Vector2(0,t*frame.size.y),frame.position+Vector2(frame.size.x,t*frame.size.y),Color(1,1,.9,.6),1)
	label(Vector2(28,115),"目标取景宽度",18);label(Vector2(28,148),"%d%% ± 4%%"%int(float(goal[0])*100),23);label(Vector2(28,185),"当前 %d%%"%int(crop_scale*100),20)

func instruction()->String:
	match kind:
		"water":return "调整三池出水阀，不消耗物品；流量稳定后按『检查作品』。"
		"crop":return "拖动照片取景，滚轮调整裁切范围；原图文件保持不变。"
		"dial","light":return "拖动三个实际指针，对准参考方向后检查。"
		"loom":return "点击织格换线色，按左侧纹样穿经纬线。"
		"model":return "点格选择海面/白沙/丘陵/白屋/椰林；至少两格海、两格屋、一个椰林，陆地相连。"
		"mosaic":return "先点两块交换位置，右键旋转玻璃片；位置和纹路都要相合。"
		_:return "依照参考构图，依次点击两块交换；完成后检查，三轮会有不同版式。"

func _gui_input(event):
	if solved:return
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if kind in ["dial","light"] and selected>=0:
				var delta:Vector2=event.position-Vector2(315+selected*210,257);values[selected]=posmod(roundi(atan2(delta.y,delta.x)*16/TAU),16);queue_redraw()
			elif kind=="crop":crop_offset=(crop_offset-event.relative/Vector2(1400,1000)).clamp(Vector2.ONE*crop_scale*.5,Vector2.ONE*(1-crop_scale*.5));queue_redraw()
	if not event is InputEventMouseButton or not event.pressed:return
	if kind=="crop":
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:crop_scale=clampf(crop_scale+(-.025 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .025),.45,.98);crop_offset=crop_offset.clamp(Vector2.ONE*crop_scale*.5,Vector2.ONE*(1-crop_scale*.5));moves+=1;queue_redraw()
		return
	if kind in ["dial","light"]:
		for i in 3:
			if event.position.distance_to(Vector2(315+i*210,257))<90:selected=i;moves+=1
		return
	if kind=="water":
		for i in 3:
			if event.position.distance_to(Vector2(320+i*200,405))<30:values[i]=(int(values[i])+1)%5;moves+=1
		return
	for i in values.size():
		if not cell_rect(i).has_point(event.position):continue
		moves+=1
		if kind in ["loom","model"]:values[i]=(int(values[i])+1)%(3 if kind=="loom" else 5)
		elif kind in ["mosaic","sail"] and event.button_index==MOUSE_BUTTON_RIGHT:rotations[i]=(int(rotations[i])+1)%4
		elif selected<0:selected=i
		elif selected==i:selected=-1
		else:
			var old=values[i];values[i]=values[selected];values[selected]=old
			if not rotations.is_empty():var angle=rotations[i];rotations[i]=rotations[selected];rotations[selected]=angle
			selected=-1
		queue_redraw();accept_event();return

func valid()->bool:
	if kind=="water":return stable>=3
	if kind=="crop":return absf(crop_scale-float(goal[0]))<=.041 and crop_offset.distance_to(Vector2(.5,.5))<.17
	if kind=="model":
		var sea_count:int=values.count(0);var homes:int=values.count(3)
		if sea_count<2 or homes<2 or values.count(4)<1 or values.count(1)<1:return false
		var open:Array=[];var seen:Array=[]
		for i in 9:
			if int(values[i])!=0:open.append(i);break
		while not open.is_empty():
			var index:int=int(open.pop_back())
			if index in seen:continue
			seen.append(index)
			for other in 9:
				if int(values[other])!=0 and abs(index%3-other%3)+abs(index/3-other/3)==1 and other not in seen:open.append(other)
		return seen.size()==9-sea_count
	if values!=goal:return false
	if kind in ["mosaic","sail"] and rotations!=target_rotations:return false
	return true

func draw_fish_oval(center:Vector2,radius:Vector2,tone:Color):
	var points:=PackedVector2Array()
	for i in 24:
		var angle:float=i*TAU/24;points.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
	draw_colored_polygon(points,tone)

func submit()->bool:
	if solved:return false
	if not valid():note="还差一点："+ ("水位需在金线间稳定三秒。" if kind=="water" else "检查构图、顺序或方向，再试一次。") ;queue_redraw();return false
	round_index+=1
	if round_index>=rounds:
		solved=true;completed.emit({"topic":topic,"moves":moves,"seconds":elapsed,"pattern":values.duplicate(),"angles":rotations.duplicate(),"crop":[crop_offset.x,crop_offset.y,crop_scale],"basins":basins.duplicate()});return true
	note="本轮完成，下一轮的目标已经换好。";new_round();return true

func _process(delta:float):
	if solved:return
	elapsed+=delta
	if kind=="water":
		var flow:Array=[]
		for i in 3:flow.append(float(values[i])*.25*.32*clampf(float(basins[i])*2,0,1))
		basins[0]=clampf(float(basins[0])+delta*(.22-float(flow[0])),0,1);basins[1]=clampf(float(basins[1])+delta*(float(flow[0])-float(flow[1])),0,1);basins[2]=clampf(float(basins[2])+delta*(float(flow[1])-float(flow[2])),0,1)
		var all_ready:bool=true
		for level in basins:
			if float(level)<.35 or float(level)>.65:all_ready=false
		stable=stable+delta if all_ready else 0
	queue_redraw()
