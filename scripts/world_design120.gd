extends "res://scripts/creative_world110.gd"
const Components=preload("res://scripts/craft_components120.gd")
var craft
var castle_context:Dictionary={}
var castle_level:=0
func _init(world):super(world);craft=Components.new(world)
func azure(p:Dictionary):
	foundation(p);var o:Vector3=at(p);var size:=Vector2(p.size[0],p.size[1]);var levels:int=p.floors.size();var role:String=p.role
	var open:bool=role in ["azure_light","azure_water","azure_glass","azure_sail"]
	for level in levels:
		var f:Vector3=Vector3(o.x,float(p.floors[level]),o.z)
		if level>0:plate(f,size,"d5c4a5",true)
		if not open:wall(f,size.x,size.y,4.0,"f5efdf",false,role=="azure_model")
		else:
			guards.pad(f,size)
			for x in [-size.x*.5,size.x*.5]:
				for z in [-size.y*.5,size.y*.5]:b.box(f+Vector3(x,2,z),Vector3(.55,4,.55),"e6ddc8",true,0,"stone")
		if level<levels-1:stairs(f,float(p.floors[level+1])-f.y,p.id)
		floors.append({"id":p.id,"floor":level,"y":f.y,"entry":f+Vector3(size.x*.3,.1,size.y*.28)})
	var top:Vector3=o+Vector3.UP*(levels*4.4)
	match role:
		"azure_view":
			craft.barrel_roof(top,size.x+1.8,size.y+1.8,2.4,"3f7496")
			for side in [-1,1]:
				craft.at(o+Vector3(side*size.x*.5,1.0,0),side*PI*.5);craft.arch_ring(Vector3.ZERO,3.2,1.7,.32,"eee7d3")
			craft.device("telescope",o+Vector3(size.x*.3,0,-size.y*.27),1.1)
			craft.device("diorama",o+Vector3(size.x*.25,4.4,-size.y*.28),.75)
		"azure_light":
			for i in 3:
				var q:=o+Vector3(-6+i*6,0,-3);b.shape(q+Vector3.UP*.3,Vector3(1.5,.6,1.5),"d0c3a4","cylinder")
				b.beam(q+Vector3.UP*.5,q+Vector3.UP*2.6,.12,"b39a65");b.oriented_box(q+Vector3.UP*2.7,Vector3(2.1,1.8,.1),["9cbdb4","b4bdca","d8c48c"][i],Basis(Vector3.RIGHT,-.35+i*.35))
				craft.at(q+Vector3(0,0,-2.1));craft.arch_ring(Vector3.ZERO,2.8,1.8,.25,"eee7d3")
			roof(top,size.x,size.y,"pergola","76929a");craft.device("console",o+Vector3(size.x*.3,0,size.y*.1),.8)
		"azure_weave":
			for side in [-1,1]:craft.barrel_roof(top+Vector3(side*size.x*.25,.6 if side<0 else 0,0),size.x*.52,size.y+1.6,1.5,"4787aa" if side<0 else "6d9eae")
			for i in 3:craft.device("loom",o+Vector3(size.x*.28,0,-size.y*.29+i*3.2),.9,PI*.5)
			craft.device("drying",o+Vector3(size.x*.28,4.4,-size.y*.28),1.1)
		"azure_water":
			for i in 3:
				var q:=o+Vector3(-6+i*6,.18+i*.18,-2.5);craft.device("flow_basin",q,1.15)
				if i<2:b.box(q+Vector3(3,.5,0),Vector3(3.0,.16,.45),"95b6ac",false)
			for side in [-1,1]:
				for z in [-size.y*.3,0,size.y*.3]:craft.at(o+Vector3(side*size.x*.5,0,z),side*PI*.5).arch_ring(Vector3.ZERO,3.2,2.5,.32,"eee7d3")
			roof(top,size.x,size.y,"pergola","7a9697");craft.device("console",o+Vector3(size.x*.31,0,size.y*.24),.65)
		"azure_glass":
			for i in 7:
				var z:float=-size.y*.5+(i+.5)*size.y/7;craft.at(o+Vector3(0,0,z)).arch_ring(Vector3.ZERO,size.x-.8,3.0,.26,"eee7d3")
			roof(top+Vector3.UP*1.5,size.x,size.y,"skylight","4b89a6")
			for i in 3:craft.device("basin",o+Vector3(-size.x*.28,0,-size.y*.3+i*size.y*.3),.7,PI*.5)
			craft.device("flowerbench",o+Vector3(size.x*.26,0,-size.y*.2),1.2)
		"azure_tide":
			craft.barrel_roof(top,size.x+1.1,size.y+1.8,2.3,"4f86a0")
			craft.device("basin",o+Vector3(size.x*.2,0,-size.y*.22),1.25)
			b.glass(o+Vector3(size.x*.2,1.5,-size.y*.22+1),Vector3(4,1.8,.05));b.box(o+Vector3(-size.x*.35,1.5,-size.y*.4),Vector3(3,2.6,.15),"9fb4a6")
		"azure_model":
			roof(top,size.x,size.y,"saw","4f85a0");craft.device("diorama",o+Vector3(size.x*.25,0,-size.y*.18),1.4);craft.device("tools",o+Vector3(-size.x*.3,0,-size.y*.4))
		"azure_sail":
			roof(top+Vector3.UP*.8,size.x,size.y,"sail_canopy","d7d4b6");craft.device("loom",o+Vector3(size.x*.26,0,-size.y*.25),1.1);craft.device("folio",o+Vector3(-size.x*.25,0,-size.y*.2),.8)
	craft.sign(p.name,o+Vector3(0,3.2,size.y*.5+.25),minf(size.x-1,7))
	var work:Vector3=o+Vector3(3,.1,1);w.interact(p.id+"_WORK",work,p.name+" · 创作与观察","creative110",{"topic":role,"place":p.id})
	for side in [-1,1]:b.planter(o+Vector3(side*(size.x*.5-1.5),0,size.y*.5+1.2),1.5,"d8b0bd")
	craft.record(p.id,[role,"deep_white_arcade"],o,size)
func castle(p:Dictionary):
	castle_context=p;castle_level=0
	super.castle(p)
	var o:Vector3=at(p);var size:=Vector2(p.size[0],p.size[1])
	craft.record(p.id,[p.role,"stone_column_bases","curved_eaves"],o,size)
	for side in [-1,1]:
		for z in [-size.y*.5,size.y*.5]:
			b.shape(o+Vector3(side*size.x*.5,.16,z),Vector3(.85,.32,.85),"b9ad92","cylinder")
	if p.id=="CASTLE_TEA":
		craft.device("espresso",o+Vector3(2.7,0,-1.6),.6)
		for x in [-4,4]:
			for z in [-3,3]:
				b.box(o+Vector3(x,3.1,z),Vector3(.4,.7,.4),"99784e");b.glow_box(o+Vector3(x,3.1,z),Vector3(.25,.45,.25))
func castle_room(o:Vector3,width:float,depth:float,topic:String):
	# Dedicated equipment replaces the generic table of the old authoring pass.
	var kinds:Dictionary={"castle_commission":"schedule","castle_archive":"drawers","castle_display":"diorama","castle_paper":"bindery","castle_photo":"camera","castle_garden":"flowerbench","castle_window":"telescope","castle_cloth":"loom","castle_material":"tools"}
	var kind:String=kinds.get(topic,"folio")
	var index:int=castle_level;castle_level+=1
	var id:String=str(castle_context.get("id",""))
	if id=="CASTLE_PAPER":kind=["basin","tools","bindery"][mini(index,2)]
	if id=="CASTLE_CLOTH":kind=["loom","mannequin","drying"][mini(index,2)]
	if id=="CASTLE_MATERIAL":kind="tools" if index==0 else "drawers"
	if id=="CASTLE_DISPLAY":kind="diorama" if index==0 else "easel"
	var p:Vector3=o+Vector3(width*.28,0,-depth*.26)
	if topic=="castle_display":
		# The hundred-work private gallery retains its free placement surface.
		craft.device("drawers",o+Vector3(width*.37,0,-depth*.4),.8);return
	craft.device(kind,p,.9)
	if topic in ["castle_archive","castle_paper","castle_material"]:craft.device("seedwall",o+Vector3(width*.34,0,depth*.15),.7,PI*.5)
	if topic=="castle_cloth":craft.device("drying",o+Vector3(width*.34,0,depth*.22),.7,PI*.5)
	if topic=="castle_photo":
		b.box(o+Vector3(width*.25,1.8,-depth*.42),Vector3(width*.48,3.6,.12),"b8c2aa");craft.device("mannequin",o+Vector3(width*.25,0,-depth*.35),.8)
	if topic=="castle_garden":
		for i in 3:b.planter(o+Vector3(width*.28,0,-depth*.32+i*depth*.3),1.6,["b9b696","c6a5b3","a1b9a7"][i])
func castle_roof(o:Vector3,width:float,depth:float,id:String):
	craft.curved_roof(o,width+3,depth+3,2.4 if id=="CASTLE_MAIN" else 1.7,"586d62")
	if id=="CASTLE_MAIN":
		craft.curved_roof(o+Vector3.UP*1.8,width*.7,depth*.7,1.6,"667a68")
		for side in [-1,1]:b.shape(o+Vector3(side*width*.21,3.05,0),Vector3(.45,.65,.45),"b69b66","pot")
func lighthouse(o:Vector3):
	super.lighthouse(o)
	var high:Vector3=o+Vector3.UP*8
	for i in 8:
		var a:float=i*TAU/8;var c:float=(i+1)*TAU/8;var q:Vector3=high+Vector3(sin(a)*2.0,1.5,cos(a)*2.0);var end:Vector3=high+Vector3(sin(c)*2.0,1.5,cos(c)*2.0)
		b.beam(q-Vector3.UP*1.2,q+Vector3.UP*1.2,.1,"657563");b.beam(q+Vector3.UP*1.2,end+Vector3.UP*1.2,.1,"657563")
	craft.curved_roof(high+Vector3.UP*2.8,5.2,5.2,1.5,"5c786d")
	craft.record("LIGHTHOUSE",["octagonal_lantern","fresnel_lens_frame"],o,Vector2(9,9))
func creek_entry():
	super.creek_entry();craft.device("espresso",Vector3(-195,3.3,-188.3),.45)
	craft.record("CREEK_TEA",["root_tea_bench","waterwheel_pavilion"],Vector3(-194,3.3,-187.5),Vector2(4.8,4.4))
func station(p:Dictionary):
	super.station(p);var o:Vector3=at(p)
	for x in [-9,9]:
		for z in [-6,6]:b.beam(o+Vector3(x,2.0,z),o+Vector3(x*.65,4.55,z),.22,"9a8059")
	craft.device("schedule",o+Vector3(6.4,0,-3.8),.65)
	# The cable's swept volume and both cabin exit points remain open.
	craft.at(o+Vector3(-6.7,3.7,-2.8));craft.drum(Vector3.ZERO,Vector3(2.8,.28,2.8),"667a71")
	if p.id=="CABLE_UPPER":
		for z in [-5.3,-1.3]:craft.at(o+Vector3(7,1.7,z)).window(Vector3.ZERO,Vector2(4,2.8),"8f7956")
	craft.record(p.id,["cable_drive_wheel","alpine_braces","schedule"],o,Vector2(20,14))
