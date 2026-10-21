extends RefCounted
## Quantity is stored once. Works have stable UIDs; inventory, hand and rooms refer to those UIDs.
var m
var defs:Dictionary={}
const APPROVED=["everyday_cover","record_stand","street_box","street_lamp","poem_journal","star_bookmark","frost_light","mini_stage","flower_screen","flower_token","photo_print","travel_frame","coral_lamp","drift_chime","tidal_pack","woodgrain_lamp","forest_print","leaf_pack","castle_table","castle_cushion","castle_screen","paper_lamp","flower_stand","woodbuckle_pack","water_garden","glass_tile","bay_model","sail_flag"]
const MATERIAL_NAMES={"wheat":"小麦","carrot":"胡萝卜","corn":"玉米","tomato":"番茄","flour":"面粉","shell":"贝壳","pinecone":"松果","flower":"花材","conch":"星光海螺","clay":"矿泥","wood":"木料","paper":"手作纸","fiber":"植物纤维","pigment":"矿彩颜料","sea_glass":"海玻璃","leaf":"叶片","driftwood":"漂木","rope":"细麻绳","tea_leaf":"茶叶","beans":"咖啡豆"}
const LEGACY_NAMES={"legacy_bouquet":"旧旅途花束","legacy_pottery":"旅行陶器","legacy_windchime":"贝壳风铃","legacy_lamp":"松果桌灯","legacy_frame":"旅行相框","legacy_conchbox":"海螺八音盒","legacy_photo":"旅行照片","legacy_bread":"麦香面包篮","legacy_harvest":"丰收菜筐","legacy_bookmark":"干花书签","legacy_wax":"花香蜡牌","legacy_fruit":"花果茶","legacy_house_chime":"藤编贝壳风铃","legacy_drink":"随身饮品","starter_basic_pack":"启程帆布背包"}

func setup(main):
	m=main
	for id in MATERIAL_NAMES:defs[id]={"name":MATERIAL_NAMES[id],"kind":"material","category":"材料","size":Vector3(.22,.25,.22)}
	var rows:Array=[
		["everyday_cover","原创封套","唱片",{"paper":2,"pigment":1},3.0,Vector3(.7,.7,.09),"everyday"],
		["record_stand","唱片展示架","家具",{"wood":3,"fiber":1},4.0,Vector3(1.15,1.1,.5),"everyday"],
		["street_box","街景盒","摆件",{"wood":2,"paper":1,"pigment":1},4.0,Vector3(1.1,.8,.7),"waiting"],
		["street_lamp","街灯模型","灯具",{"wood":2,"sea_glass":1},3.0,Vector3(.45,1.5,.45),"waiting"],
		["poem_journal","独立手札","纸品",{"paper":3,"fiber":1},3.0,Vector3(.55,.12,.75),"poem"],
		["star_bookmark","星纹书签","纸品",{"paper":1,"pigment":1},2.0,Vector3(.18,.04,.6),"poem"],
		["frost_light","霜月灯架","灯具",{"wood":3,"sea_glass":2,"fiber":1},5.0,Vector3(1.6,1.75,.65),"frost"],
		["mini_stage","微缩舞台","摆件",{"wood":3,"fiber":2,"pigment":1},5.0,Vector3(1.5,.9,1.0),"frost"],
		["flower_screen","花窗屏风","家具",{"wood":3,"flower":2,"fiber":1},5.0,Vector3(1.6,1.7,.35),"blossom"],
		["flower_token","花令挂饰","挂饰",{"flower":1,"paper":1,"rope":1},2.0,Vector3(.45,.75,.08),"blossom"],
		["photo_print","独立印片","照片",{"paper":1,"pigment":1},2.0,Vector3(.55,.7,.045),"daily"],
		["travel_frame","旅拍相框","照片",{"wood":2,"paper":1},3.0,Vector3(.8,.95,.14),"daily"],
		["coral_lamp","海玻璃灯","灯具",{"sea_glass":3,"shell":1,"driftwood":1},4.0,Vector3(.55,.8,.55),"coral"],
		["drift_chime","漂木风铃","挂饰",{"driftwood":2,"shell":2,"rope":1},4.0,Vector3(.8,1.1,.22),"coral"],
		["tidal_pack","潮汐背包","背包",{"fiber":3,"sea_glass":2,"rope":1},5.0,Vector3(.5,.65,.28),"coral"],
		["woodgrain_lamp","木纹灯","灯具",{"wood":3,"leaf":1},4.0,Vector3(.6,.75,.5),"forest"],
		["forest_print","森林拓印","纸品",{"paper":2,"leaf":2,"pigment":1},3.0,Vector3(.65,.85,.05),"forest"],
		["leaf_pack","叶纹背包","背包",{"fiber":3,"leaf":3,"rope":1},5.0,Vector3(.5,.65,.28),"forest"],
		["castle_table","矮桌","家具",{"wood":4,"fiber":1},4.0,Vector3(1.6,.65,1.0),"castle"],
		["castle_cushion","坐垫","家具",{"fiber":3,"pigment":1},3.0,Vector3(.75,.18,.75),"castle"],
		["castle_screen","立屏","家具",{"wood":4,"paper":2,"pigment":1},5.0,Vector3(1.6,1.85,.35),"castle"],
		["paper_lamp","纸灯","灯具",{"paper":2,"wood":1,"rope":1},3.0,Vector3(.55,.8,.55),"castle"],
		["flower_stand","花架","家具",{"wood":4,"flower":2},5.0,Vector3(1.2,1.4,.6),"castle"],
		["woodbuckle_pack","木扣背包","背包",{"wood":1,"fiber":4,"rope":1},5.0,Vector3(.5,.65,.28),"castle"],
		["water_garden","阶水庭园模型","摆件",{"clay":2,"sea_glass":2,"wood":1},5.0,Vector3(1.2,.75,.9),"azure_water"],
		["glass_tile","海玻璃镶片","挂饰",{"sea_glass":3,"clay":1},3.0,Vector3(.65,.65,.06),"azure_glass"],
		["bay_model","微缩湾岸","摆件",{"clay":3,"wood":2,"pigment":1},6.0,Vector3(1.4,.8,1.0),"azure_model"],
		["sail_flag","饰帆旗","挂饰",{"fiber":2,"wood":1,"rope":1,"pigment":1},3.0,Vector3(.8,1.1,.15),"azure_sail"]]
	for row in rows:defs[row[0]]={"name":row[1],"kind":"work","category":row[2],"cost":row[3],"seconds":row[4],"size":row[5],"lesson":row[6]}
	for id in LEGACY_NAMES:defs[id]={"name":LEGACY_NAMES[id],"kind":"work","category":"旧旅途","size":Vector3(.55,.65,.45),"cost":{},"seconds":2.0,"lesson":"legacy"}
	defs.starter_basic_pack.category="背包"
	var legacy_sizes:Dictionary={"legacy_bouquet":Vector3(.6,.7,.6),"legacy_pottery":Vector3(.7,.75,.7),"legacy_windchime":Vector3(.8,1.1,.25),"legacy_house_chime":Vector3(.8,1.1,.25),"legacy_lamp":Vector3(.6,.8,.5),"legacy_frame":Vector3(.7,.7,.09),"legacy_conchbox":Vector3(.6,.4,.5),"legacy_photo":Vector3(.55,.7,.05),"legacy_bread":Vector3(.7,.5,.5),"legacy_harvest":Vector3(.7,.5,.5),"legacy_bookmark":Vector3(.18,.15,.6),"legacy_wax":Vector3(.5,.2,.5),"legacy_fruit":Vector3(.3,.35,.3),"legacy_drink":Vector3(.3,.35,.3),"starter_basic_pack":Vector3(.5,.65,.28)}
	for id in legacy_sizes:defs[id].size=legacy_sizes[id]
	for id in ["photo_print","forest_print","glass_tile","flower_token","legacy_photo","everyday_cover"]:defs[id].wall=true

func data()->Dictionary:
	if not m.state.get("creative110") is Dictionary:m.state.creative110={}
	var d:Dictionary=m.state.creative110
	if not d.get("repairs") is Array:d.repairs=[]
	for key in ["stacks","works","lessons","regrowth","commissions","knowledge","legacy_history","legacy_aliases"]:
		if not d.get(key) is Dictionary:
			if d.has(key):d.repairs.append({"field":key,"reason":"invalid_dictionary","preserved":d[key]})
			d[key]={}
	if not d.get("shortcuts") is Array:d.shortcuts=[]
	while d.shortcuts.size()<8:d.shortcuts.append("")
	if d.shortcuts.size()>8:d.shortcuts=d.shortcuts.slice(0,8)
	for key in ["equipped_hand","equipped_back"]:
		if not d.get(key) is String:d[key]=""
	if not d.has("next_uid"):d.next_uid=1
	if not d.has("online"):d.online=0.0
	d.schema=1
	return d

func initialize_state():
	var d:Dictionary=data()
	repair_state()
	if not d.get("migrated_legacy",false):migrate_legacy()
	repair_state()
	reconcile_legacy_aliases()
	for key in ["equipped_hand","equipped_back"]:
		if not d.works.has(d[key]) or d.works[d[key]].get("location","")!="bag":d[key]=""
	mirror_materials()

func number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
func vector_value(value:Variant)->bool:
	if not value is Array or value.size()!=3:return false
	for axis in value:
		if not number(axis):return false
	return true
func location_ok(location:String)->bool:
	if location in ["bag","placed","legacy_home_object","legacy_home_vase","commission:0","commission:1","commission:2"]:return true
	if location.begins_with("legacy_table:"):return location.trim_prefix("legacy_table:") in ["bread","harvest","bookmark","wax","chime","fruit_ready","croissant","framed_shot","printed_shot","postcard"]
	var pattern:=RegEx.new()
	if location.begins_with("legacy_slot:"):pattern.compile("^(B12|H(0[1-9]|1[0-4]))_[0-2]$");return pattern.search(location.trim_prefix("legacy_slot:"))!=null
	if location.begins_with("legacy_rack:"):return location.trim_prefix("legacy_rack:") in ["0","1","2","3","4","5"]
	if location.begins_with("legacy_mail:"):
		var suffix:String=location.trim_prefix("legacy_mail:");return suffix.is_valid_int() and int(suffix)>=0 and int(suffix)<1000000
	if location.begins_with("legacy_theme:THEME_DAILY:"):
		var suffix:String=location.trim_prefix("legacy_theme:THEME_DAILY:");return suffix.is_valid_int() and int(suffix)>=0 and int(suffix)<1000000
	return false
func repair_state():
	var d:Dictionary=data()
	if not d.get("quarantine") is Dictionary:d.quarantine={}
	if not number(d.online) or float(d.online)<0:d.repairs.append({"field":"online","reason":"invalid_online_clock"});d.online=0.0
	var highest:=0;var pattern:=RegEx.new();pattern.compile("^C110_[0-9]{8,12}$")
	for id in d.stacks.keys():
		var amount=d.stacks[id]
		if not defs.has(str(id)) or defs[str(id)].kind!="material" or not number(amount) or float(amount)<0 or float(amount)!=floorf(float(amount)) or float(amount)>2147483647:
			d.quarantine["stack:"+str(id)]=amount;d.repairs.append({"field":"stacks."+str(id),"reason":"invalid_quantity_or_material"});d.stacks.erase(id)
		else:d.stacks[id]=int(amount)
	for uid in d.works.keys():
		var record=d.works[uid];var reason:=""
		if not record is Dictionary:reason="invalid_work_record"
		elif not defs.has(str(record.get("item",""))) or defs[str(record.get("item",""))].kind!="work":reason="unknown_work_item"
		elif pattern.search(str(uid))==null:reason="invalid_uid"
		elif record.has("quantity") and (not number(record.quantity) or float(record.quantity)!=1.0):reason="unique_work_quantity_must_be_one"
		if not reason.is_empty():d.quarantine["work:"+str(uid)]=record;d.repairs.append({"field":"works."+str(uid),"reason":reason});d.works.erase(uid);continue
		record.uid=str(uid);record.quantity=1;highest=maxi(highest,int(str(uid).trim_prefix("C110_")))
		if not record.get("variant") is Dictionary:record.variant={};d.repairs.append({"field":str(uid)+".variant","reason":"invalid_variant"})
		var location:String=str(record.get("location","bag"));var valid_location:bool=location_ok(location)
		if not valid_location:record.location="bag";d.repairs.append({"field":str(uid)+".location","reason":"unknown_location_returned_to_bag"})
		else:record.location=location
		if record.location=="placed":
			var p=record.get("position",null)
			if not vector_value(p) or float(p[0])< -475 or float(p[0])>475 or float(p[1])< -16 or float(p[1])>180 or float(p[2])< -455 or float(p[2])>645 or not record.get("area") is String:
				record.location="bag";record.erase("position");record.erase("area");d.repairs.append({"field":str(uid)+".position","reason":"invalid_placement_returned_to_bag"})
		if record.has("yaw") and not number(record.yaw):record.yaw=0;d.repairs.append({"field":str(uid)+".yaw","reason":"invalid_rotation_reset"})
	for key in d.regrowth.keys():
		if not number(d.regrowth[key]) or float(d.regrowth[key])<0:d.repairs.append({"field":"regrowth."+str(key),"reason":"invalid_cooldown"});d.regrowth.erase(key)
	for field in ["lessons","commissions"]:
		for key in d[field].keys():
			if not d[field][key] is Dictionary:d.quarantine[field+":"+str(key)]=d[field][key];d[field].erase(key);d.repairs.append({"field":field+"."+str(key),"reason":"invalid_progress_record"})
	if not number(d.next_uid) or float(d.next_uid)<1:d.next_uid=1
	d.next_uid=maxi(int(d.next_uid),highest+1)

func mirror_materials():
	if not m.state.get("inventory") is Dictionary:m.state.inventory={}
	for id in MATERIAL_NAMES:m.state.inventory[id]=int(data().stacks.get(id,0))

func count(id:String)->int:return int(data().stacks.get(id,0))
func grant(id:String,amount:int=1,variant:Dictionary={})->Array:
	if amount<=0 or not defs.has(id):return []
	var d:Dictionary=data();var result:Array=[]
	if defs[id].kind=="material":d.stacks[id]=count(id)+amount;mirror_materials();return result
	for i in amount:
		var uid:String="C110_%08d"%int(d.next_uid);d.next_uid=int(d.next_uid)+1
		while d.works.has(uid):uid="C110_%08d"%int(d.next_uid);d.next_uid=int(d.next_uid)+1
		d.works[uid]={"uid":uid,"item":id,"quantity":1,"variant":variant.duplicate(true),"location":"bag","created":Time.get_datetime_string_from_system()};result.append(uid)
	return result

func can_afford(cost:Dictionary,quantity:int=1)->bool:
	if quantity<1:return false
	for id in cost:
		if not defs.has(str(id)) or defs[str(id)].kind!="material" or not number(cost[id]) or float(cost[id])<1 or float(cost[id])!=floorf(float(cost[id])):return false
		if count(str(id))<int(cost[id])*quantity:return false
	return true
func consume_cost(cost:Dictionary,quantity:int=1)->bool:
	if quantity<1 or not can_afford(cost,quantity):return false
	var d:Dictionary=data()
	for id in cost:d.stacks[id]=count(str(id))-int(cost[id])*quantity
	mirror_materials();return true
func consume(id:String,quantity:int=1)->bool:return consume_cost({id:quantity})
func transfer(uid:String,location:String,extra:Dictionary={})->bool:
	var d:Dictionary=data()
	if not d.works.has(uid) or not location_ok(location):return false
	if location=="placed" and (not vector_value(extra.get("position",null)) or not extra.get("area") is String or not number(extra.get("yaw",0))):return false
	var record:Dictionary=d.works[uid];record.location=location
	for key in ["position","yaw","area"]:record.erase(key)
	for key in extra:record[key]=extra[key]
	if location!="bag":
		if d.equipped_hand==uid:d.equipped_hand=""
		if d.equipped_back==uid:d.equipped_back=""
	if location.begins_with("commission:"):
		for i in d.shortcuts.size():
			if d.shortcuts[i]==uid:d.shortcuts[i]=""
	return true
func bag_works()->Array:
	var result:Array=[]
	for record in data().works.values():
		if record.get("location","")=="bag":result.append(record)
	return result
func owned(id:String,only_bag:bool=false)->Array:
	return data().works.values().filter(func(r):return r.get("item","")==id and not str(r.get("location","")).begins_with("commission:") and (not only_bag or r.get("location","")=="bag"))
func equip(uid:String,back:bool=false)->bool:
	var d:Dictionary=data()
	if uid.is_empty():d["equipped_back" if back else "equipped_hand"]="";return true
	if not d.works.has(uid) or d.works[uid].get("location","")!="bag":return false
	if back and defs[d.works[uid].item].category!="背包":return false
	d["equipped_back" if back else "equipped_hand"]=uid
	if back and d.equipped_hand==uid:d.equipped_hand=""
	if not back and d.equipped_back==uid:d.equipped_back=""
	return true
func legacy_item(kind:String)->String:
	var aliases:Dictionary={"bouquet":"legacy_bouquet","pottery":"legacy_pottery","photo":"legacy_photo","windchime":"legacy_windchime","lamp":"legacy_lamp","frame":"legacy_frame","conchbox":"legacy_conchbox"}
	return aliases.get(kind,"legacy_"+kind if defs.has("legacy_"+kind) else "legacy_windchime")
func migrate_work(item:String,location:String,variant:Dictionary={})->String:
	var d:Dictionary=data();var previous:String=str(variant.get("_creative_uid",""))
	if not d.works.has(previous):previous=str(d.legacy_aliases.get(location,"")) if location!="bag" else ""
	if d.works.has(previous):
		if location!="bag":d.legacy_aliases[location]=previous
		return previous
	if location!="bag":
		for work in d.works.values():
			if work.get("location","")==location:d.legacy_aliases[location]=work.uid;return str(work.uid)
	var ids:Array=grant(item,1,variant)
	if ids.is_empty():return ""
	var uid:String=str(ids[0])
	if location!="bag":d.legacy_aliases[location]=uid
	if not transfer(uid,location):legacy_issue(location,variant,"invalid_display_location_recovered_to_bag")
	return uid

func legacy_issue(field:String,value:Variant,reason:String):
	var d:Dictionary=data();d.quarantine["legacy:"+field]=value.duplicate(true) if value is Dictionary or value is Array else value
	for repair in d.repairs:
		if repair is Dictionary and repair.get("field","")==field and repair.get("reason","")==reason:return
	d.repairs.append({"field":field,"reason":reason})

func reconcile_legacy_aliases():
	# Old labels and inventory/equipment may refer to one work. They never mint extra works.
	var d:Dictionary=data();var activities:Dictionary=m.state.get("activities",{}) if m.state.get("activities",{}) is Dictionary else {}
	var workshop:Dictionary=activities.get("workshops105",{}) if activities.get("workshops105",{}) is Dictionary else {}
	var slots:Dictionary=workshop.get("slots",{}) if workshop.get("slots",{}) is Dictionary else {}
	for key in slots.keys():
		var record=slots[key]
		if not record is Dictionary or not record.has("_creative_uid"):continue
		var uid:String=str(record._creative_uid);var location:String="legacy_slot:"+str(key)
		if not d.works.has(uid):uid=migrate_work(legacy_item(str(record.get("kind",""))),location,record);record._creative_uid=uid
		d.legacy_aliases[location]=uid
		if d.works[uid].get("location","")!=location:legacy_issue(location,record,"duplicate_or_moved_display_alias_hidden");slots.erase(key)
	var racks:Array=workshop.get("racks",[]) if workshop.get("racks",[]) is Array else []
	for i in racks.size():
		if not racks[i] is Dictionary or not racks[i].has("_creative_uid"):continue
		var record:Dictionary=racks[i];var uid:String=str(record._creative_uid);var location:String="legacy_rack:"+str(i)
		if not d.works.has(uid):uid=migrate_work("legacy_pottery",location,record);record._creative_uid=uid
		d.legacy_aliases[location]=uid
		if d.works[uid].get("location","")!=location:legacy_issue(location,record,"duplicate_or_moved_display_alias_hidden");racks[i]=null
	var island:Dictionary=activities.get("island_02_state",{}) if activities.get("island_02_state",{}) is Dictionary else {}
	var letters:Array=island.get("letters",[]) if island.get("letters",[]) is Array else []
	for i in letters.size():
		var letter=letters[i]
		if not letter is Dictionary or not letter.has("_creative_uid"):continue
		var uid:String=str(letter._creative_uid)
		if d.works.has(uid) and d.works[uid].get("location","")!="legacy_mail:"+str(i):letter._creative_taken=true
	var dual:Dictionary=activities.get("dual106",{}) if activities.get("dual106",{}) is Dictionary else {}
	var rooms:Dictionary=dual.get("rooms",{}) if dual.get("rooms",{}) is Dictionary else {}
	var daily:Dictionary=rooms.get("daily",{}) if rooms.get("daily",{}) is Dictionary else {}
	if daily.get("_creative_print_refs") is Array:
		if not daily.get("_creative_taken_prints") is Array:daily._creative_taken_prints=[]
		for i in daily._creative_print_refs.size():
			var uid:String=str(daily._creative_print_refs[i])
			if d.works.has(uid) and d.works[uid].get("location","")!="legacy_theme:THEME_DAILY:"+str(i) and i not in daily._creative_taken_prints:daily._creative_taken_prints.append(i)

func migrate_legacy():
	var d:Dictionary=data();var inventory:Dictionary=m.state.get("inventory",{}) if m.state.get("inventory",{}) is Dictionary else {};var activities:Dictionary=m.state.get("activities",{}) if m.state.get("activities",{}) is Dictionary else {}
	if not m.state.get("inventory",{}) is Dictionary:d.quarantine.legacy_inventory=m.state.inventory;m.state.inventory={}
	if not m.state.get("activities",{}) is Dictionary:d.quarantine.legacy_activities=m.state.activities;m.state.activities={}
	m.state.activities=activities
	for id in MATERIAL_NAMES:
		var amount=inventory.get(id,0)
		if number(amount) and float(amount)>=0 and float(amount)==floorf(float(amount)) and float(amount)<=2147483647:d.stacks[id]=int(amount)
		else:d.stacks[id]=0;legacy_issue("inventory."+str(id),amount,"invalid_legacy_material_quantity")
	var flower_colors=inventory.get("flower_colors",{})
	if flower_colors is Dictionary:d.knowledge.flower_colors=flower_colors.duplicate(true)
	else:legacy_issue("inventory.flower_colors",flower_colors,"invalid_discovery_dictionary");d.knowledge.flower_colors={};inventory.flower_colors={}
	var crafted=activities.get("crafted",[])
	if not crafted is Array:legacy_issue("activities.crafted",crafted,"invalid_craft_history");crafted=[];activities.crafted=[]
	d.legacy_history={"crafted":crafted.duplicate(true),"home_object":activities.get("home_object",""),"handheld":m.state.get("handheld","natural")}
	var workshops:Dictionary=activities.get("workshops105",{}) if activities.get("workshops105",{}) is Dictionary else {}
	if not workshops.get("slots",{}) is Dictionary:d.quarantine.legacy_slots=workshops.slots;workshops.slots={}
	for key in workshops.get("slots",{}).keys():
		if not workshops.slots[key] is Dictionary:legacy_issue("legacy_slot:"+str(key),workshops.slots[key],"invalid_display_record");workshops.slots.erase(key);continue
		var record:Dictionary=workshops.slots[key]
		if record.is_empty():continue
		record["_creative_uid"]=migrate_work(legacy_item(str(record.get("kind",""))),"legacy_slot:"+str(key),record)
	if not workshops.get("racks",[]) is Array:d.quarantine.legacy_racks=workshops.racks;workshops.racks=[null,null,null,null,null,null]
	for i in workshops.get("racks",[]).size():
		var record=workshops.racks[i]
		if record is Dictionary:
			for field in ["shape","glaze"]:
				if not number(record.get(field,0)):legacy_issue("legacy_rack:"+str(i)+"."+field,record[field],"invalid_pottery_style");record[field]=0
				if not record.has(field):record[field]=0
			record["_creative_uid"]=migrate_work("legacy_pottery","legacy_rack:"+str(i),record)
		elif record!=null:legacy_issue("legacy_rack:"+str(i),record,"invalid_display_record");workshops.racks[i]=null
	var pottery:Dictionary=workshops.get("pottery",{}) if workshops.get("pottery",{}) is Dictionary else {}
	if number(pottery.get("stage",0)) and int(pottery.get("stage",0))==3:
		var uid:String=migrate_work("legacy_pottery","bag",pottery);pottery.stage=0;pottery._creative_uid=uid
		if m.state.get("handheld","")=="pottery" and not uid.is_empty():d.equipped_hand=uid
	var old_object:String=str(activities.get("home_object",""))
	if not old_object.is_empty():migrate_work(legacy_item(old_object),"legacy_home_object",{"kind":old_object})
	if activities.get("flower_vase",false):migrate_work("legacy_bouquet","legacy_home_vase",{"colors":activities.get("bouquet_colors",[]),"wrap":activities.get("bouquet_wrap",0)})
	var island:Dictionary=activities.get("island_02_state",{}) if activities.get("island_02_state",{}) is Dictionary else {}
	if island.get("letters",[]) is Array:
		for i in island.get("letters",[]).size():
			var letter=island.letters[i]
			if not letter is Dictionary:continue
			letter["_creative_uid"]=migrate_work("photo_print","legacy_mail:"+str(i),{"file":str(letter.get("card","")) if str(letter.get("card","")).get_extension() in ["png","jpg","jpeg"] else "","letter":str(letter.get("card","")),"_creative_uid":letter.get("_creative_uid","")})
			if letter.get("_creative_taken",false) and d.works[str(letter._creative_uid)].location=="legacy_mail:"+str(i):transfer(str(letter._creative_uid),"bag")
	var dual:Dictionary=activities.get("dual106",{}) if activities.get("dual106",{}) is Dictionary else {}
	var rooms:Dictionary=dual.get("rooms",{}) if dual.get("rooms",{}) is Dictionary else {}
	var daily:Dictionary=rooms.get("daily",{}) if rooms.get("daily",{}) is Dictionary else {}
	if daily.get("prints",[]) is Array:
		if not daily.get("_creative_print_refs") is Array:daily._creative_print_refs=[]
		for i in daily.get("prints",[]).size():
			if not number(daily.prints[i]):legacy_issue("daily.prints."+str(i),daily.prints[i],"invalid_print_phase");continue
			while daily._creative_print_refs.size()<=i:daily._creative_print_refs.append("")
			var phase:int=posmod(int(daily.prints[i]),3);var uid:String=migrate_work("photo_print","legacy_theme:THEME_DAILY:"+str(i),{"file":"res://assets/media/bay_life/life_0"+str(1+phase*2)+".jpg","tone":phase,"_creative_uid":daily._creative_print_refs[i]})
			daily._creative_print_refs[i]=uid
			if daily.get("_creative_taken_prints",[]) is Array and i in daily.get("_creative_taken_prints",[]) and d.works[uid].location=="legacy_theme:THEME_DAILY:"+str(i):transfer(uid,"bag")
	var table:Dictionary={"bread":"legacy_bread","harvest":"legacy_harvest","bookmark":"legacy_bookmark","wax":"legacy_wax","chime":"legacy_house_chime","fruit_ready":"legacy_fruit","croissant":"legacy_bread","postcard":"legacy_photo"}
	for key in table:
		if workshops.get(key,0):migrate_work(table[key],"legacy_table:"+key,{"legacy_count":workshops.get(key,0)})
	for key in ["framed_shot","printed_shot"]:
		if workshops.get(key,"") is String and not str(workshops.get(key,"")).is_empty():migrate_work("legacy_photo","legacy_table:"+key,{"file":workshops[key]})
	for kind in crafted:
		var id:String=legacy_item(str(kind))
		if owned(id).is_empty():grant(id)
	var held:String=str(m.state.get("handheld","natural"))
	if held=="drink":
		var uid:String=migrate_work("legacy_drink","bag",{"recipe":activities.get("drink",[])});d.equipped_hand=uid
	elif held=="bouquet" and activities.get("bouquet_colors",[]) is Array and not activities.get("bouquet_colors",[]).is_empty():
		var ids:Array=grant("legacy_bouquet",1,{"colors":activities.get("bouquet_colors",[]),"wrap":activities.get("bouquet_wrap",0)})
		d.equipped_hand=ids[0]
	elif held=="craft" and not old_object.is_empty():
		var available:Array=owned(legacy_item(old_object),true)
		if available.is_empty():available=grant(legacy_item(old_object))
		d.equipped_hand=available[0].uid if available[0] is Dictionary else available[0]
	var packs:Array=owned("starter_basic_pack",true)
	var pack_uid:String=str(packs[0].uid) if not packs.is_empty() else str(grant("starter_basic_pack")[0])
	if d.equipped_back.is_empty():d.equipped_back=pack_uid
	if str(d.shortcuts[0]).is_empty():d.shortcuts[0]=pack_uid
	# Existing one-off pickups become renewable after one full cooldown, never duplicate on migration.
	var picked=activities.get("picked",[])
	if not picked is Array:legacy_issue("activities.picked",picked,"invalid_pickup_history");picked=[];activities.picked=[]
	for id in picked:
		if not d.regrowth.has(str(id)):d.regrowth[str(id)]=float(d.online)+ (90.0 if "FLOWER" in str(id) or "flower" in str(id) else 180.0 if "CONCH" in str(id) else 120.0)
	d.migrated_legacy=true;d.migration_counts={"works":d.works.size(),"material_kinds":d.stacks.size(),"at":Time.get_datetime_string_from_system()}
	mirror_materials()

func take(uid:String)->bool:
	var d:Dictionary=data()
	if not d.works.has(uid):return false
	var record:Dictionary=d.works[uid];var old:String=record.get("location","");var workshops:Dictionary=m.state.activities.get("workshops105",{})
	if old.begins_with("commission:"):return false
	if old.begins_with("legacy_slot:"):workshops.get("slots",{}).erase(old.trim_prefix("legacy_slot:"))
	elif old.begins_with("legacy_rack:"):
		var index:int=int(old.trim_prefix("legacy_rack:"))
		if index<workshops.get("racks",[]).size():workshops.racks[index]=null
	elif old.begins_with("legacy_mail:"):
		var index:int=int(old.trim_prefix("legacy_mail:"));var island:Dictionary=m.state.activities.get("island_02_state",{})
		if index<island.get("letters",[]).size() and island.letters[index] is Dictionary:island.letters[index]["_creative_taken"]=true
		if m.bay!=null and m.bay.dual!=null:m.bay.dual.signature=""
	elif old.begins_with("legacy_theme:THEME_DAILY:"):
		var index:int=int(old.trim_prefix("legacy_theme:THEME_DAILY:"));var daily:Dictionary=m.state.activities.get("dual106",{}).get("rooms",{}).get("daily",{})
		if not daily.get("_creative_taken_prints") is Array:daily._creative_taken_prints=[]
		if index not in daily._creative_taken_prints:daily._creative_taken_prints.append(index)
		if m.bay!=null and m.bay.dual!=null:m.bay.dual.signature=""
	elif old=="legacy_home_object":
		if m.bay!=null:m.bay.home_parent=0;m.bay.ornament_signature=""
	elif old=="legacy_home_vase":
		m.state.activities.flower_vase=false
		if m.bay!=null and is_instance_valid(m.world.home_flowers):m.world.home_flowers.hide()
	transfer(uid,"bag")
	if m.bay!=null and m.bay.workshops!=null:m.bay.workshops.signature="";m.bay.workshops.refresh()
	return true

func legacy_display_active(location:String)->bool:
	for record in data().works.values():
		if record.get("location","")==location:return true
	return false
