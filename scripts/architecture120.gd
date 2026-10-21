extends "res://scripts/creative_architecture110.gd"
## 0120 replaces public envelopes and builds individual workshops over retained route contracts.
const Components=preload("res://scripts/craft_components120.gd")
var craft
func _init(world):
	super(world);craft=Components.new(world)
func public_shell(ctx):
	var p:Vector3=ctx.origin;var width:float=ctx.w;var depth:float=ctx.d;var high:float=ctx.h;var id:String=ctx.item.id
	var tones:Dictionary={"B01":["f2efe9","3b6e8c"],"B02":["eadfc9","906749"],"B03":["dedccd","4e7272"],"B04":["e7e9d8","4b7161"],"B05":["e3e0d6","829486"],"B06":["71817d","405660"],"B07":["e2d5bd","826245"],"B08":["e7e6d8","6c8883"],"B09":["c6c8b3","6d6f58"],"B10":["b7c4c0","536576"],"B11":["d9c8ac","987958"],"B13":["e2e4cc","638577"]}
	var palette:Array=tones.get(id,["eee4d1","7f8e76"]);var wall_tone:String=palette[0];var trim:String=palette[1]
	b.box(p-Vector3.UP*.18,Vector3(width+.4,.36,depth+.4),"c8baa1",true,0,"stone")
	for side in [-1,1]:
		var bay:float=(width-3.4)*.5;var center:Vector3=p+Vector3(side*(width+3.4)*.25,0,depth*.5)
		if id in ["B06","B10"]:
			b.box(center+Vector3(0,high*.5,0),Vector3(bay,high,.55),wall_tone,true,0,"stone")
			craft.at(center).window(Vector3(0,2.1,.30),Vector2(minf(3,bay-.6),1.65),trim)
		else:
			b.box(center+Vector3(0,.44,0),Vector3(bay,.88,.48),"cabca3",true,0,"stone")
			var glazed_h:float=high-1.5 if id=="B04" else 2.35 if id=="B01" else 1.95
			if id=="B02":
				b.box(center+Vector3(0,3.75,0),Vector3(bay,1.25,.42),wall_tone,true,0,"plaster")
				b.box(center+Vector3(0,7.65,0),Vector3(bay,.7,.42),wall_tone,true,0,"plaster")
			else:b.box(center+Vector3(0,(high+.88+glazed_h)*.5,0),Vector3(bay,maxf(.15,high-.88-glazed_h),.42),wall_tone,true,0,"plaster")
			var count:int=maxi(1,floori(bay/(3.8 if id=="B01" else 3.1)));var span:float=bay/count
			for i in count:craft.at(center+Vector3(-bay*.5+(i+.5)*span,.88+glazed_h*.5,0)).window(Vector3.ZERO,Vector2(span-.22,glazed_h),trim,id in ["B01","B13"])
			if id=="B02":
				# The existing occupied mezzanine remains behind an upper window bank.
				for i in count:craft.at(center+Vector3(-bay*.5+(i+.5)*span,5.85,.26)).window(Vector3.ZERO,Vector2(span-.25,2.55),trim)
		for z in [-depth*.5,depth*.5]:b.box(p+Vector3(side*width*.5,high*.5,z),Vector3(.45,high,.5),trim,true,0,"wood")
		var side_yaw:float=side*PI*.5;var side_center:Vector3=p+Vector3(side*width*.5,0,0)
		if id=="B06":
			var portal_z:float=depth*.37
			for ends in [[-depth*.5,portal_z-1.4],[portal_z+1.4,depth*.5]]:
				b.box(side_center+Vector3(0,high*.5,(ends[0]+ends[1])*.5),Vector3(.55,high,ends[1]-ends[0]),wall_tone,true,0,"stone")
			b.box(side_center+Vector3(0,(high+3.2)*.5,portal_z),Vector3(.55,high-3.2,2.8),wall_tone,true)
		elif id=="B10":b.box(side_center+Vector3.UP*high*.5,Vector3(.55,high,depth),wall_tone,true,0,"stone")
		else:
			var spans:Array=[[-depth*.5,depth*.5]]
			if id=="B05" and side==-1:spans=[[-depth*.5,4.0],[7.2,depth*.5]]
			var portal_z:float={"B01":depth*.35,"B07":-depth*.5+1.25,"B08":-depth*.5+1.25}.get(id,0.0)
			var linked:bool=id in ["B01","B07","B08"] and side==1
			if linked:spans=[[-depth*.5,portal_z-1.2],[portal_z-1.2,portal_z+1.2],[portal_z+1.2,depth*.5]]
			for section in spans:
				var length:float=section[1]-section[0]
				if length<.30:continue
				var middle:float=(section[0]+section[1])*.5;var sh:float=high-1.4 if id=="B04" else 1.9
				b.box(side_center+Vector3(0,.5,middle),Vector3(.45,1,length),"c9bba2",true,0,"stone")
				if id=="B02":
					b.box(side_center+Vector3(0,3.75,middle),Vector3(.42,1.25,length),wall_tone,true,0,"plaster")
					b.box(side_center+Vector3(0,7.65,middle),Vector3(.42,.7,length),wall_tone,true,0,"plaster")
				elif linked and absf(middle-portal_z)<.01:
					var floor_top:float={"B01":3.8,"B07":3.15,"B08":3.1}[id]
					b.box(side_center+Vector3(0,(1+sh+floor_top)*.5,middle),Vector3(.42,maxf(.12,floor_top-1-sh),length),wall_tone,true,0,"plaster")
				else:b.box(side_center+Vector3(0,(high+1+sh)*.5,middle),Vector3(.42,maxf(.15,high-1-sh),length),wall_tone,true,0,"plaster")
				var n:int=maxi(1,ceili(length/3.2));var cell:float=length/n
				for j in n:craft.at(side_center+Vector3(0,1+sh*.5,section[0]+(j+.5)*cell),side_yaw).window(Vector3.ZERO,Vector2(cell-.22,sh),trim)
				if id=="B02":
					for j in n:craft.at(side_center+Vector3(0,5.85,section[0]+(j+.5)*cell),side_yaw).window(Vector3.ZERO,Vector2(cell-.22,2.55),trim)
		# Masonry is sampled at each end and continues below the real floor.
		for z in range(-int(depth*.5),int(depth*.5)+1,2):
			var v:=p+Vector3(side*(width*.5+.25),0,z);var low:float=minf(p.y-.3,w.layout.natural_height(Vector2(v.x,v.z)))
			b.box(Vector3(v.x,(low+p.y-.18)*.5,v.z),Vector3(.65,maxf(.2,p.y-.18-low),1.96),"b9aa8e",false,0,"stone")
	if id=="B02":
		for side in [-1,1]:b.box(p+Vector3(side*(width+3.4)*.25,high*.5,-depth*.5),Vector3((width-3.4)*.5,high,.45),wall_tone,true)
		b.box(p+Vector3(0,(high+3.3)*.5,-depth*.5),Vector3(3.4,high-3.3,.45),wall_tone,true)
	elif id in ["B07","B08"]:
		# The graded annex walk leaves through the rear. Its rise stays outside
		# the main mezzanine so it never cuts across the original stair landing.
		var opening_x:float=width*.5-(5.2 if id=="B07" else 5.8)
		var sill:float=3.15 if id=="B07" else 3.1
		for section in [[-width*.5,opening_x-1.15],[opening_x+1.15,width*.5]]:
			b.box(p+Vector3((section[0]+section[1])*.5,high*.5,-depth*.5),Vector3(section[1]-section[0],high,.45),wall_tone,true,0,"plaster")
		b.box(p+Vector3(opening_x,(sill-.08)*.5,-depth*.5),Vector3(2.3,sill-.08,.45),wall_tone,true,0,"plaster")
		if high>sill+2.4:b.box(p+Vector3(opening_x,(high+sill+2.4)*.5,-depth*.5),Vector3(2.3,high-sill-2.4,.45),wall_tone,true,0,"plaster")
	else:b.box(p+Vector3(0,high*.5,-depth*.5),Vector3(width,high,.45),wall_tone,true,0,"plaster")
	b.box(p+Vector3(0,(high+3.3)*.5,depth*.5),Vector3(3.4,maxf(.12,high-3.3),.45),wall_tone,true)
	for side in [-1,1]:b.box(p+Vector3(side*1.85,1.65,depth*.5),Vector3(.25,3.3,.65),trim,true,0,"wood")
	main_roof(ctx)
	craft.sign(ctx.item.name,p+Vector3(0,3.65,depth*.5+.32),minf(width-1,maxf(4.8,ctx.item.name.length()*.58)))
	if id!="B01":roof_shed(p+Vector3(0,3.0,depth*.5+1.35),5.2,2.8,.35,trim)
	var lamp:=OmniLight3D.new();lamp.position=p+Vector3(0,minf(high-1,5),0);lamp.light_color=Color("ffe2b5");lamp.light_energy=.22 if id in ["B06","B10"] else .5;lamp.omni_range=maxf(width,depth)*.7;lamp.shadow_enabled=false;w.add_child(lamp)
	ctx.action("enter",Vector3(0,0,depth*.5+1.5),"走进 · "+ctx.item.name,"enter",{"building":id})
func main_roof(ctx):
	var p:Vector3=ctx.origin;var width:float=ctx.w;var depth:float=ctx.d;var h:float=ctx.h;var id:String=ctx.item.id
	match id:
		"B01":
			for i in 3:craft.barrel_roof(p+Vector3((i-1)*width/3,h+(.5 if i==1 else 0),0),width/3+.16,depth+1.8,1.8 if i==1 else 1.1,"3b6e8c")
			roof_shed(p+Vector3(0,3.45,depth*.5+1.4),width+2.4,3.5,.5,"456f83")
			for x in [-width*.43,-width*.18,width*.18,width*.43]:b.beam(p+Vector3(x,2.3,depth*.5),p+Vector3(x,3.5,depth*.5+2.5),.15,"b39463")
		"B03":roof_saw(p+Vector3.UP*h,width+1.3,depth+1.6,3,"4e7272")
		"B06":
			b.box(p+Vector3(0,h,-depth*.1),Vector3(width+1,.4,depth*.84),"40545c",true,0,"slate")
			craft.barrel_roof(p+Vector3(0,4.35,depth*.5+1.2),width+1.2,3.6,.7,"566f76")
			for i in range(-int(width*.5),int(width*.5),1):b.glow_box(p+Vector3(i,4.2,depth*.5+2.95),Vector3(.12,.14,.14))
		"B08":craft.barrel_roof(p+Vector3.UP*h,width+1.4,depth+1.5,2.1,"6c8883")
		"B09":
			for i in 3:craft.barrel_roof(p+Vector3((i-1)*width/3,h,0),width/3+.2,depth+1.2,.95,["61756c","7b8670","526e6b"][i])
		"B10":
			roof_gable(p+Vector3.UP*h,width+1,depth+1.2,2.6,"526775",true)
			b.box(p+Vector3(0,h+.9,-depth*.29),Vector3(width*.6,1.8,depth*.35),"576b75",true,0,"slate");roof_gable(p+Vector3(0,h+1.9,-depth*.29),width*.64,depth*.4,1.1,"405b69",true)
		_:super.main_roof(ctx)
	for side in [-1,1]:
		for x in range(-int(width*.5)+1,int(width*.5),2):b.beam(p+Vector3(x,h-.35,side*depth*.5),p+Vector3(x,h+.12,side*(depth*.5+.65)),.12,"8b7150")
func main_details(ctx):
	super.main_details(ctx)
	var p:Vector3=ctx.origin;var width:float=ctx.w;var depth:float=ctx.d;var id:String=ctx.item.id
	var kinds:Dictionary={"B01":["schedule","luggage"],"B02":["espresso","seedwall"],"B03":["turntable","drawers"],"B04":["flowerbench","basin"],"B05":["folio","easel"],"B06":["projector","schedule"],"B07":["folio","drawers"],"B08":["console","drying"],"B09":["console","turntable"],"B10":["console","puppet"],"B11":["bindery","drawers"],"B12":["hearth","seedwall"],"B13":["diorama","schedule"]}
	var set:Array=kinds.get(id,["folio"])
	# Use perimeter equipment bays; the entry spine and public display wall stay clear.
	var base:Vector3=p+Vector3(width*.28,0,-depth*.31)
	if id=="B01":base=p+Vector3(-width*.28,0,-depth*.31)
	if id=="B02":base=p+Vector3(-5,0,-3)
	if id=="B09":base=p+Vector3(-width*.27,0,-depth*.25)
	if id=="B12":base=p+Vector3(-width*.35,0,-depth*.35)
	for i in set.size():
		var spot:Vector3=base+Vector3(0,0,i*3.0)
		if id=="B02" and i==1:spot=p+Vector3(-width*.34,0,-depth*.42)
		craft.device(set[i],spot,.8 if id in ["B09","B12"] else 1,PI*.5 if id=="B05" else 0)
	if id=="B01":
		station_internal_stair(p,width,depth)
		for side in [-1,1]:
			for z in [-depth*.22,depth*.22]:
				b.box(p+Vector3(side*width*.39,1.1,z),Vector3(.5,2.2,.5),"8a7653",true)
				for y in [2.2,3.2,4.2,5.2]:b.beam(p+Vector3(side*width*.39,y,z),p+Vector3(side*(width*.39-.5),y+1,z),.12,"b99a66")
	if id=="B04":
		for i in 3:
			var at:Vector3=p+Vector3(-width*.28,.18+i*.22,-depth*.31+i*.85);b.box(at,Vector3(width*.48,.36+i*.44,.72),"98a78b",true,0,"stone")
	if id=="B08":
		# A deliberately matte, silvered practice wall works with the retained mobile renderer.
		b.box(p+Vector3(0,2,-depth*.5+.32),Vector3(width*.74,3.2,.06),"a7b8b2",false,0,"metal")
		for y in [.85,1.2]:b.beam(p+Vector3(-width*.36,y,-depth*.5+.75),p+Vector3(width*.36,y,-depth*.5+.75),.065,"b49b72")
		for x in range(-4,5,2):
			for z in [-1,2,5]:b.box(p+Vector3(x,.02,z),Vector3(.45,.025,.45),"c2c9ae")
	craft.record(id,set,p,Vector2(width,depth))
func station_internal_stair(p:Vector3,width:float,depth:float):
	var annex:Vector3=w.layout.vector(w.layout.config.annexes.B01.center)
	var a:=p+Vector3(width*.31,0,depth*.35);var c:=p+Vector3(width*.31,1.9,-depth*.34);var turn:=p+Vector3(width*.425,1.9,-depth*.34);var top:=p+Vector3(width*.425,3.8,depth*.35)
	var second_start:Vector3=turn+Vector3(0,0,1.1);var second_end:Vector3=top-Vector3(0,0,1.1)
	var end:=Vector3(annex.x-2.5,annex.y+3.8,p.z);var corner:=Vector3(end.x,end.y,top.z);var guards=load("res://scripts/bay_guardrails.gd").new(w)
	guards.pad(p,Vector2(width,depth),false)
	for pair in [[a,c],[second_start,second_end]]:load("res://scripts/bay_finishings.gd").new(w).flight(pair[0],pair[1],2.0);guards.span(pair[0],pair[1],2.0)
	for pair in [[c,turn],[turn,second_start],[second_end,top],[top,corner],[corner,end]]:b.ramp(pair[0],pair[1],2.2,"ad9370");guards.span(pair[0],pair[1],2.2)
	for at in [c,turn,top,corner]:slab(at,Vector2(2.2,2.2),"ad9370");guards.pad(at,Vector2(2.2,2.2))
	var low:float=minf(p.y-.2,w.height_at(corner.x,corner.z));b.box(Vector3(corner.x,(low+corner.y-.15)*.5,corner.z),Vector3(.3,corner.y-.15-low,.3),"8e7754",false,0,"wood")
	guards.pad(annex+Vector3.UP*3.8,Vector2(8.4,8.4),false);guards.build("B01_internal_station_stair",true)
	upper_route("B01_INTERNAL_TO_CLOCK","B01",[a,c,turn,second_start,second_end,top,corner,end],[])
func join_annex(p:Vector3,size:Vector2,level:float,tag:String,guards):
	var id:String=tag.get_slice("_",0)
	if id not in ["B07","B08"]:return
	var annex:Vector3=w.layout.vector(w.layout.config.annexes[id].center)
	var a:=p+Vector3(size.x*.5-5.2 if id=="B07" else size.x*.5-5.8,level,-size.y*.5+1.0)
	var rear_z:float=minf(p.z-size.y*.5,annex.z-4.2)-2.4
	var low:=Vector3(a.x,a.y,rear_z);var top:=Vector3(annex.x-2.5,annex.y+3.8,rear_z);var inside:=Vector3(annex.x-2.5,annex.y+3.8,annex.z-1.5)
	for pair in [[a,low],[low,top],[top,inside]]:b.ramp(pair[0],pair[1],1.8,"b7a17a");guards.span(pair[0],pair[1],1.8)
	guards.pad(annex+Vector3.UP*3.8,Vector2(8.4,8.4),false)
	for at in [low,top]:
		var ground_y:float=minf(p.y-.3,w.height_at(at.x,at.z));b.box(Vector3(at.x,(ground_y+at.y-.15)*.5,at.z),Vector3(.26,at.y-.15-ground_y,.26),"977c54",false,0,"wood")
	upper_route(id+"_ANNEX_GRADED_LINK",id,[a,low,top,inside],[{"center":inside,"size":Vector2(2.2,2.2),"y":inside.y}])
func annex_receiving_portal(id:String,p:Vector3,guards):
	if id not in ["B01","B07","B08"]:return
	var from:=p+Vector3(-2.5,3.8,7.9) if id=="B01" else p+Vector3(-2.5,3.8,-6.6);var inside:=p+Vector3(-2.5,3.8,3.0 if id=="B01" else -1.5)
	guards.span(from,inside,2.2 if id=="B01" else 1.8,false)
func consolidate_labels():
	var replacements:Array=[];var retained:Dictionary={}
	for child in w.get_children():
		if not child is Label3D:continue
		var words:String=child.text.replace(" ","")
		if child.get_meta("design120_sign",false):retained[words]=true;continue
		if "F" in words or "E" in words or "X" in words:continue
		for place in w.layout.creative_places:
			var title:String=str(place.name).replace(" ","")
			if words==title or words.begins_with(title+"·"):
				replacements.append(child);break
	for child in replacements:w.remove_child(child);child.free()
	for place in w.layout.creative_places:
		if retained.has(str(place.name).replace(" ","")):continue
		var door:Array=place.door;var yaw:float=place.door_yaw
		var p:=Vector3(door[0],float(place.floors[0])+3.15,door[2])+Basis(Vector3.UP,yaw)*Vector3(0,0,.23)
		craft.sign(place.name,p,clampf(place.name.length()*.48,3.8,7),yaw)
	w.set_meta("design120_labels",{"replaced_titles":replacements.size(),"scope":"Exact registered building titles only; interaction, guidance and contextual labels retained"})
func living_roof(h:Dictionary,p:Vector3,size:Vector2,height:float):
	var id:String=h.id
	if id=="H02":
		for side in [-1,1]:
			roof_shed(p+Vector3(side*size.x*.36,height,0),size.x*.30,size.y+1.7,1.8,"7a866d",0 if side<0 else PI)
			roof_shed(p+Vector3(side*size.x*.14,height+1.8,0),size.x*.34,size.y+1.7,.8,"7a866d",0 if side<0 else PI)
	elif id=="H07":craft.barrel_roof(p+Vector3.UP*height,size.x+1.8,size.y+1.7,2.7,"7f7258")
	elif id=="H11":craft.barrel_roof(p+Vector3.UP*height,size.x+1.6,size.y+1.6,2.0,"967b68")
	else:super.living_roof(h,p,size,height)
	if id in ["H01","H07"]:
		var chimney:=p+Vector3(size.x*.43,height*.5,-size.y*.25)
		b.box(chimney,Vector3(.9,height+2.4,.9),"a57f60" if id=="H01" else "a79980",true,0,"stone");b.box(chimney+Vector3.UP*(height*.5+1.25),Vector3(1.2,.18,1.2),"b9ae94")
	if id=="H14":
		b.shape(p+Vector3(size.x*.38,height*.52,-size.y*.25),Vector3(1.8,height+1.1,1.8),"a77c50","cylinder")
		for y in range(1,ceili(height)+1):b.shape(p+Vector3(size.x*.38,y,-size.y*.25),Vector3(1.86,.08,1.86),"6d6951","cylinder")
func living_furniture(h:Dictionary,p:Vector3,size:Vector2):
	var palette:Array=["bfae8e","99b5a6","c4a5ae","a6b7b9","c9bd8f"]
	var seat:Vector3=p+Vector3(-size.x*.25,0,2);var tone:String=palette[posmod(int(h.id.trim_prefix("H"))-1,palette.size())]
	# Every retained seat ID still points to a real cushioned seat. Private beds remain authored.
	b.box(seat+Vector3.UP*.25,Vector3(2.2,.5,1.0),"8c7354",true,0,"wood");b.box(seat+Vector3.UP*.55,Vector3(2.1,.16,.94),tone,false,0,"fabric");b.box(seat+Vector3(0,.93,-.4),Vector3(2.2,.75,.14),tone,false,0,"fabric")
	for side in [-1,1]:b.box(seat+Vector3(side*1.05,.7,0),Vector3(.15,.5,1),"9c8461")
	craft.at(p+Vector3(-size.x*.25,0,.4)).slab(Vector3.ZERO,Vector2(1.55,.8),.45)
	var devices:Dictionary={"H01":["oven","seedwall"],"H02":["seedwall","tools"],"H03":["easel","folio"],"H04":["espresso","seedwall"],"H05":["diorama","telescope"],"H06":["loom","chimes"],"H07":["hearth","tools"],"H08":["bindery","drying"],"H09":["mannequin","folio"],"H10":["drawers","bindery"],"H11":["puppet","console"],"H12":["photo","camera"],"H13":["flowerbench","drying"],"H14":["roaster","seedwall"]}
	var set:Array=devices[h.id]
	craft.device(set[0],p+Vector3(size.x*.23,0,-size.y*.28),.85)
	craft.device(set[1],p+Vector3(-size.x*.28,0,-size.y*.38),.8)
	if h.id=="H14":
		for i in 5:b.box(p+Vector3(size.x*.43,.5+i*.48,-size.y*.08+i*.45),Vector3(1.0,.13,.8),"bba17c",false,0,"wood")
	craft.record(h.id,set,p,size)
func living_details(h:Dictionary,p:Vector3,size:Vector2):
	super.living_details(h,p,size)
	for side in [-1,1]:
		for z in [-size.y*.27,size.y*.18]:craft.at(p+Vector3(side*(size.x*.5+.05),2.2,z),side*PI*.5).window(Vector3.ZERO,Vector2(2.2,1.75),"886b4e",h.id in ["H01","H04","H07","H10"])
	if h.loft:
		var kind:String={"H01":"seedwall","H03":"easel","H05":"telescope","H08":"drying"}.get(h.id,"folio")
		craft.device(kind,p+Vector3(size.x*.27,3.4,-size.y*.3),.7)
func annex_roof(id:String,p:Vector3):
	super.annex_roof(id,p)
	for side in [-1,1]:
		for z in [-3.7,-1.1,1.1,3.7]:b.beam(p+Vector3(side*4,6.0,z),p+Vector3(side*4.6,6.95,z),.12,"a88b62")
func annex_details(id:String,p:Vector3):
	super.annex_details(id,p)
	var kinds:Dictionary={"B01":"schedule","B04":"drying","B05":"easel","B06":"projector","B07":"drawers","B08":"diorama","B09":"chimes","B10":"console","B12":"flowerbench","B13":"diorama"}
	craft.device(kinds[id],p+Vector3(0,3.8,-2.65),.65)
	if id=="B01":
		for side in [-1,1]:
			craft.at(p+Vector3(0,8.3,side*2.82),0 if side>0 else PI);craft.drum(Vector3.ZERO,Vector3(1.85,1.85,.07),"d8c79d")
			for i in 12:
				var a:float=i*TAU/12;craft.rod(Vector3(sin(a)*.70,cos(a)*.70,.05),Vector3(sin(a)*.82,cos(a)*.82,.05),.035,"5f6a58")
	craft.record(id+"_UPPER",[kinds[id],"deep_window_joinery"],p,Vector2(8.4,8.4))
func wing_details(wing:Dictionary,p:Vector3,size:Vector2):
	super.wing_details(wing,p,size)
	var kinds:Dictionary={"BAKERY":["oven","seedwall"],"LISTENING_WEST":["turntable","drawers"],"LISTENING_EAST":["console","chimes"],"CRAFT":["basin","flowerbench"]}
	var set:Array=kinds[wing.id]
	for i in set.size():craft.device(set[i],p+Vector3(size.x*.26,0,-size.y*.27+i*2.8),.8)
	craft.record(wing.id,set,p,size)
func cliff_details(h:Dictionary,p:Vector3,size:Vector2):
	super.cliff_details(h,p,size)
	var sets:Dictionary={"wheel":["tools","diorama"],"pottery":["oven","pottery"],"tea":["hearth","espresso"],"loom":["loom","basin"],"sluice":["console","chimes"],"lookout":["telescope","easel"]}
	var set:Array=sets[h.role]
	for i in set.size():craft.device(set[i],p+Vector3(size.x*.26,0,-size.y*.3+i*2.8),.85)
	if h.role in ["wheel","pottery","loom"]:craft.device("drying",p+Vector3(-size.x*.22,float(h.upper_y)-p.y,-size.y*.25),.8)
	if h.role=="lookout":
		for side in [-1,1]:b.box(p+Vector3(side*(size.x*.5-.45),2.25,size.y*.35),Vector3(.5,4.5,.7),"967c58",true,0,"wood")
		b.box(p+Vector3(0,4.35,size.y*.35),Vector3(size.x,.5,.75),"967c58",false,0,"wood")
	craft.record(h.id,set,p,size)
func theme_shell(room:Dictionary,p:Vector3,size:Vector2)->Dictionary:
	var result:Dictionary=super.theme_shell(room,p,size)
	var id:String=room.id;var kind:String={"THEME_EVERYDAY":"turntable","THEME_WAITING":"street","THEME_POEM":"bindery","THEME_FROST":"console","THEME_BLOSSOM":"flowerbench","THEME_DAILY":"photo"}[id]
	var work:Vector3=p+room_work_offset(room)
	craft.device(kind,work,.9)
	if id=="THEME_BLOSSOM":
		for i in 3:
			var at:Vector3=p+Vector3(-size.x*.35+i*size.x*.35,2.0,size.y*.5-.12)
			craft.at(at);craft.arch_ring(Vector3.ZERO,1.5,.05,.12,"d4c7a9")
			for j in 8:
				var a:float=j*TAU/8;craft.rod(Vector3.ZERO,Vector3(sin(a)*.76,cos(a)*.76,.02),.045,"987c55")
	if id=="THEME_DAILY":craft.device("camera",p+Vector3(size.x*.23,0,-size.y*.16));craft.device("drying",p+Vector3(size.x*.29,0,-size.y*.4),.85)
	if id=="THEME_FROST":
		craft.at(p+Vector3(0,4.8,-size.y*.39));craft.arch_ring(Vector3.ZERO,2.4,0,.12,"d5dfd1")
	if id=="THEME_POEM":craft.device("drying",p+Vector3(-size.x*.35,6.9,-size.y*.3),.65)
	craft.record(id,[kind,"theme_specific_structure"],p,size);return result
func forest_shell(h:Dictionary,p:Vector3,size:Vector2):
	super.forest_shell(h,p,size)
	var set:Dictionary={"TREEHOUSE_1":"folio","TREEHOUSE_2":"loom","TREEHOUSE_3":"flowerbench","TREEHOUSE_4":"telescope","FOREST_LODGE":"drawers","FOREST_OBSERVATORY":"telescope"}
	var kind:String=set[h.id];craft.device(kind,p+Vector3(0 if h.treehouse else size.x*.25,0,-size.y*.3),.55 if h.treehouse else .8)
	for side in [-1,1]:
		for z in [-size.y*.3,size.y*.25]:b.beam(p+Vector3(side*size.x*.48,-.45,z),p+Vector3(side*size.x*.3,1.25,z),.16,"826c4b")
	craft.record(h.id,[kind,"tree_joinery" if h.treehouse else "forest_gallery"],p,size)
func villa_roof(index:int,p:Vector3):
	match index:
		0:craft.barrel_roof(p+Vector3(0,3.5,0),9,9.7,2.2,"ad925e")
		1:
			for side in [-1,1]:roof_shed(p+Vector3(side*3.0,3.5,0),3.3,9.7,1.4,"a88c59",0 if side<0 else PI)
			for side in [-1,1]:roof_shed(p+Vector3(0,3.5,side*3.5),3.0,2.7,1.1,"ad9465",0 if side<0 else PI)
		2:roof_shed(p+Vector3(0,3.5,0),9.2,9.3,2.0,"b39767",.26)
		3:
			for side in [-1,1]:craft.barrel_roof(p+Vector3(side*2.15,3.5,0),4.6,10.0,2.4,"ae9566")
	# Individual thatch bundles follow the eave, rather than a single featureless slab.
	for side in [-1,1]:
		for i in 32:b.box(p+Vector3(-4.45+i*.28,3.45,side*4.85),Vector3(.20,.2+(i%3)*.06,.65),["a08b5b","b59d6a","c1aa77"][i%3],false,0,"fabric")
func villa_details(index:int,p:Vector3):
	super.villa_details(index,p)
	var set:Array=["basin","flowerbench","camera","folio"]
	craft.device(set[index],p+Vector3(-2.5,0,-3.0),.5)
	if index==1:
		for x in [1.5,3.3]:
			for z in [5.5,8.8]:b.box(p+Vector3(x,1.5,z),Vector3(.12,3,.12),"a18a5d",true,0,"wood")
		for x in [1.5,3.3]:b.box(p+Vector3(x,2.0,7.15),Vector3(.04,1.8,3.3),"dedbc3",false,0,"fabric")
	if index==3:craft.device("telescope",p+Vector3(2.6,0,9.1),.65)
	craft.record("VILLA_"+str(index),[set[index],"thatch_frame_"+str(index)],p,Vector2(8.2,14.2))
func coral_lobby(p:Vector3):
	super.coral_lobby(p);craft.device("basin",p+Vector3(-2,0,-2),.7)
	for i in 8:
		var a:float=i*TAU/8;b.beam(p+Vector3(sin(a)*4.6,5.3,cos(a)*3.6),p+Vector3(0,7.2,0),.13,"a68a58")
	craft.record("ISLAND_LOBBY",["coral_sorting_bar","bamboo_shell_trusses"],p,Vector2(11.4,9))
func landmark_entry(id:String,p:Vector3,size:Vector2,yaw:float=0):
	super.landmark_entry(id,p,size,yaw);craft.device("hearth",p+Vector3(0,0,-size.y*.25),.65,yaw);craft.record(id,["hearth","windbreak_joinery"],p,size)
