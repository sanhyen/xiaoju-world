extends Node3D
## Workshop state is visible in the world; only the existing successful transaction grants rewards.
const Models=preload("res://scripts/creative_models110.gd")
var m
var models=Models.new()
var stations:Dictionary={}
var timer:=0.0
const TONES=["c9b283","97b6a5","b69bb7","89aeb4","d8caab","b48b6c"]
func setup(main):m=main
func topic_place(topic:String)->Dictionary:
	var wanted:String={"everyday":"THEME_EVERYDAY","waiting":"THEME_WAITING","poem":"THEME_POEM","frost":"THEME_FROST","blossom":"THEME_BLOSSOM","daily":"THEME_DAILY","coral":"ISLAND_LOBBY","forest":"FOREST_LODGE","star":"FOREST_OBSERVATORY","castle":"CASTLE_PAPER"}.get(topic,topic.to_upper())
	for place in m.world.layout.creative_places:
		if str(place.id)==wanted:return place
	return {}
func workshop_origin(topic:String,place:Dictionary)->Transform3D:
	var center:=Vector3(place.center[0],place.center[1],place.center[2]);var yaw:float=float(place.get("door_yaw",0));var local:=Vector3.ZERO
	var height:=1.05
	if topic in ["everyday","waiting","poem","frost","blossom","daily"]:
		for room in m.world.layout.config.theme_rooms:
			if str(room.id)!=str(place.id):continue
			local=preload("res://scripts/creative_architecture110.gd").room_work_offset(room);break
	elif topic=="coral":local=Vector3(-2,0,-2);yaw=0;height=.65
	elif topic=="forest":local=Vector3(-1.7,0,-.6);yaw=0
	elif topic=="azure_water":local=Vector3.ZERO;yaw=0;height=0
	elif topic=="azure_light":local=Vector3(float(place.size[0])*.3,0,float(place.size[1])*.1);yaw=0
	elif topic.begins_with("azure_"):local=Vector3(float(place.size[0])*.28,0,-float(place.size[1])*.26);yaw=0
	elif topic=="castle":local=Vector3(float(place.size[0])*.28,0,-float(place.size[1])*.26);yaw=0
	else:local=Vector3(float(place.size[0])*.25,0,-float(place.size[1])*.3);yaw=0
	return Transform3D(Basis(Vector3.UP,yaw),center+Basis(Vector3.UP,yaw)*local+Vector3.UP*height)
func result_for(topic:String)->Dictionary:
	var saved:Dictionary=m.creative.items.data().lessons.get(topic,{}).get("pattern",{}).duplicate(true)
	var puzzle=m.creative.puzzle
	if m.modal.visible and is_instance_valid(puzzle) and str(m.creative.puzzle_topic)==topic:
		saved={"pattern":puzzle.values.duplicate(),"angles":puzzle.rotations.duplicate(),"crop":[puzzle.crop_offset.x,puzzle.crop_offset.y,puzzle.crop_scale],"basins":puzzle.basins.duplicate(),"live":true}
	return saved
func rebuild(topic:String,station:Node3D,result:Dictionary):
	for child in station.get_children():station.remove_child(child);child.queue_free()
	var values:Array=result.get("pattern",[0,1,2,3,4,5]);var angles:Array=result.get("angles",[])
	if values.is_empty():values=[0,1,2,3,4,5]
	if topic in ["star","azure_view","azure_light","frost"]:
		for i in 3:
			var pivot:=Node3D.new();pivot.name="Dial"+str(i);station.add_child(pivot);pivot.position=Vector3((i-1)*.85,.12,0);pivot.rotation.y=float(values[i%values.size()])*TAU/16
			models.cylinder(pivot,Vector3.ZERO,.37,.08,TONES[i]);models.box(pivot,Vector3(.13,.07,0),Vector3(.48,.05,.045),"e4d09c")
			if topic in ["azure_light","frost"]:models.box(pivot,Vector3(0,.12,-.3),Vector3(.65,.8,.045),TONES[i],0,true)
	elif topic=="azure_water":
		var levels:Array=result.get("basins",[.45,.45,.45])
		for i in 3:
			var water:MeshInstance3D=models.box(station,Vector3(-6+i*6,1.166+i*.18+clampf(float(levels[i]),0,1)*.2,-2.5),Vector3(3.27,.025,1.2),"8fbdb0",0,true);water.name="PoolWater"+str(i)
			var valve:=Node3D.new();station.add_child(valve);valve.position=Vector3(5.3+i*.55,.8,4.3);valve.rotation.y=float(values[i%values.size()])*PI*.5;models.box(valve,Vector3.ZERO,Vector3(.38,.04,.06),"b8a377")
	elif topic=="daily":
		var variant:Dictionary=result.duplicate(true);variant.file=m.creative.daily_photo_file();models.photo(station,Vector3(0,.68,.03),Vector2(1.9,1.3),variant)
		for x in [-1.15,1.15]:models.box(station,Vector3(x,.68,0),Vector3(.08,1.5,.08),"9b805b")
	elif topic in ["waiting","azure_model"]:
		for i in mini(values.size(),9):
			var value:int=int(values[i]);var at:=Vector3((i%3-1)*.62,.10,(i/3-1)*.54)
			models.box(station,at,Vector3(.58,.04,.5),TONES[posmod(value,6)])
			if value%3==0:models.box(station,at+Vector3.UP*.25,Vector3(.35,.45,.32),"eee3c9");models.box(station,at+Vector3.UP*.5,Vector3(.41,.10,.38),"6f927f")
			elif value%3==1:models.box(station,at+Vector3.UP*.35,Vector3(.04,.7,.04),"947d58");models.box(station,at+Vector3.UP*.72,Vector3(.15,.16,.15),"e8cd8e",0,true)
	elif topic=="everyday":
		for i in mini(values.size(),6):
			var pivot:=Node3D.new();pivot.name="Record"+str(i);station.add_child(pivot);pivot.position=Vector3((i%3-1)*.73,.08,(i/3-.5)*.7);models.cylinder(pivot,Vector3.ZERO,.29,.035,"344b44");models.cylinder(pivot,Vector3.UP*.025,.10,.015,TONES[posmod(int(values[i]),6)])
	elif topic in ["poem","castle"]:
		for i in mini(values.size(),6):
			var at:=Vector3((i%3-1)*.65,.02+i*.018,(i/3-.5)*.65);models.box(station,at,Vector3(.55,.04,.57),TONES[posmod(int(values[i]),6)])
			for j in 3:models.box(station,at+Vector3(0,.03,-.16+j*.13),Vector3(.38,.01,.018),"697b69")
	elif topic=="azure_tide":
		for i in 3:
			var q:=Node3D.new();station.add_child(q);q.position=Vector3((i-1)*.7,.18+i*.08,0);models.box(q,Vector3.ZERO,Vector3(.48,.16,.22),TONES[posmod(int(values[i%values.size()]),6)]);models.box(q,Vector3(.30,0,0),Vector3(.15,.27,.035),"c9c3a5")
	else:
		for i in mini(values.size(),12):
			var pivot:=Node3D.new();station.add_child(pivot);pivot.position=Vector3((i%4-1.5)*.48,.05,(i/4-1)*.48);pivot.rotation.y=float(angles[i] if i<angles.size() else 0)*PI*.5
			models.box(pivot,Vector3.ZERO,Vector3(.43,.05,.43),TONES[posmod(int(values[i]),6)]);models.box(pivot,Vector3(.08,.045,0),Vector3(.24,.02,.035),"eee1c2",0,true)
	station.set_meta("signature",JSON.stringify(result))
func _process(delta:float):
	if m==null or not m.active_game or m.creative==null:return
	timer+=delta
	if timer<.12:return
	timer=0
	var topics:Array=m.creative.MODES.keys()
	for topic_value in topics:
		var topic:String=topic_value;var place:Dictionary=topic_place(topic)
		if topic=="star":continue
		if place.is_empty():continue
		var transform:Transform3D=workshop_origin(topic,place);var near:bool=m.player.position.distance_to(transform.origin)<75
		var station:Node3D=stations.get(topic)
		if not near:
			if is_instance_valid(station):station.hide()
			continue
		if not is_instance_valid(station):station=Node3D.new();station.name="Workshop_"+topic;add_child(station);station.transform=transform;stations[topic]=station
		station.show();var result:Dictionary=result_for(topic)
		if str(station.get_meta("signature",""))!=JSON.stringify(result):rebuild(topic,station,result)
