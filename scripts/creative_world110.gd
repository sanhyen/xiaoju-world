extends RefCounted
## Physical 0110 public buildings, seven usable castle floors and shared cable infrastructure.
var w
var b
var guards
var floors:Array=[]
var public_displays:Array=[]
func _init(world):
	w=world;b=w.b;guards=preload("res://scripts/bay_guardrails.gd").new(w)

func build():
	for r in w.layout.segments:
		guards.span(r.a,r.c,r.width,str(r.id).begins_with("creative110_"))
	for p in w.layout.creative_places:
		if str(p.id).begins_with("AZURE_"):azure(p)
		elif str(p.id).begins_with("CASTLE_"):castle(p)
		elif str(p.id).begins_with("CABLE_"):station(p)
	public_showcases()
	castle_links()
	cable()
	for portal in w.get_meta("entrances110",[]):
		if portal.get("inside") is Vector3 and portal.get("outer") is Vector3:guards.span(portal.outer,portal.inside,float(portal.get("width",3.2)),false)
	guards.build("creative110",true)
	w.set_meta("creative110",{"registered_places":w.layout.creative_places.size(),"floors":floors,"public_displays":public_displays,"east_region":w.layout.config.creative_region,"new_public_facilities":16})

func public_showcases():
	for id in ["B05","B07","B11","B13"]:
		var v:Dictionary=w.layout.venues[id]
		var point:=Vector3(v.x-v.w*.33,v.floor_y,v.z+v.d*.5-.55)
		var wall_only:bool=id=="B13"
		# Blank front-left wall segments, away from original pictures and central doors.
		var panel_y:float=2.4 if wall_only else 1.75;var panel_h:float=1.2 if wall_only else 2.0
		b.box(point+Vector3(0,panel_y,0),Vector3(3.0,panel_h,.10),"b8af91",true,0,"fabric")
		for side in [-1,1]:b.box(point+Vector3(side*1.58,panel_y,-.04),Vector3(.12,panel_h+.2,.14),"886c4a",false,0,"wood")
		b.text3d("旅人作品展示",point+Vector3(0,2.95,-.12),.005,"5a6c59",PI)
		var area:=point+Vector3(0,0,-.65)
		public_displays.append({"id":id+":public_display","name":v.name+" · 旅人作品展示面","center":[area.x,area.y+(1.6 if wall_only else 0),area.z],"ceiling":area.y+3.2,"size":[3.2,1.8],"door":[],"kind":"public_display","limit":12,"wall_only":wall_only})
		w.interact("DISPLAY110_"+id,area+Vector3(0,.1,-.8),"旅人作品展示面 · F","creative110",{"topic":"public_display","place":id})

func at(p:Dictionary)->Vector3:return Vector3(p.center[0],p.center[1],p.center[2])
func plate(o:Vector3,size:Vector2,tone:String="efe5d2",hole:bool=false):
	# Floor_y always means the top surface; the substrate stays below the slab.
	if not hole:
		b.box(o-Vector3(0,.12,0),Vector3(size.x,.24,size.y),tone,true,0,"stone")
		guards.pad(o,size,false)
	else:
		var left:float=-5.2;var right:float=.2;var back:float=-4.2;var front:float=4.8
		for r in [[-size.x*.5,left,-size.y*.5,size.y*.5],[right,size.x*.5,-size.y*.5,size.y*.5],[left,right,-size.y*.5,back],[left,right,front,size.y*.5]]:
			if r[1]<=r[0] or r[3]<=r[2]:continue
			b.box(o+Vector3((r[0]+r[1])*.5,-.12,(r[2]+r[3])*.5),Vector3(r[1]-r[0],.24,r[3]-r[2]),tone,true,0,"wood")
			guards.pad(o+Vector3((r[0]+r[1])*.5,0,(r[2]+r[3])*.5),Vector2(r[1]-r[0],r[3]-r[2]),false)
		guards.span(o+Vector3(left,0,back),o+Vector3(left,0,front),.05)
		guards.span(o+Vector3(right,0,back),o+Vector3(right,0,front),.05)

func foundation(p:Dictionary):
	var o:Vector3=at(p);var size:=Vector2(p.size[0],p.size[1])
	for side in [-1,1]:
		for z in range(-int(size.y*.5),int(size.y*.5)+1,2):
			var v:Vector3=o+Vector3(side*size.x*.5,0,z)
			var low:float=minf(o.y-.3,w.layout.natural_height(Vector2(v.x,v.z))-.4)
			b.box(Vector3(v.x,(low+o.y-.25)*.5,v.z),Vector3(.65,maxf(.2,o.y-.25-low),1.98),"b9a38a",true,0,"stone")
	plate(o,size+Vector2(.3,.3))
	var door:=Vector3(p.door[0],p.door[1],p.door[2]);var yaw:float=float(p.door_yaw)
	var outward:=Basis(Vector3.UP,yaw)*Vector3.FORWARD*-1
	b.ramp(door+outward*2,door-outward*.8,3.2,"e0d1b6")
	guards.span(door+outward*2,door-outward*.8,3.2,false)

func wall(o:Vector3,width:float,depth:float,height:float,tone:String,side_portal:bool=false,open_front:bool=false):
	var opening:float=3.2
	if not open_front:
		for side in [-1,1]:
			var x:float=side*(width+opening)*.25;var wing:float=(width-opening)*.5
			if tone=="eee0c5":
				b.box(o+Vector3(x,.4,depth*.5),Vector3(wing,.8,.32),tone,true,0,"plaster")
				b.box(o+Vector3(x,height-.4,depth*.5),Vector3(wing,.8,.32),tone,true,0,"plaster")
				b.glass(o+Vector3(x,height*.5,depth*.5),Vector3(wing-.25,height-1.6,.045))
				b.collision(o+Vector3(x,height*.5,depth*.5),Vector3(wing,height,.2))
				for j in maxi(2,ceili(wing/1.8)):
					var u:float=x-wing*.5+(j+.5)*wing/maxi(2,ceili(wing/1.8))
					b.box(o+Vector3(u,height*.5,depth*.5+.08),Vector3(.12,height-1.2,.13),"59402c",false,0,"wood")
				for y in [1.0,height*.5,height-1.0]:b.box(o+Vector3(x,y,depth*.5+.09),Vector3(wing,.13,.14),"59402c",false,0,"wood")
			else:b.box(o+Vector3(x,height*.5,depth*.5),Vector3(wing,height,.32),tone,true,0,"plaster")
		b.box(o+Vector3(0,(height+2.8)*.5,depth*.5),Vector3(opening,maxf(.1,height-2.8),.32),tone,true)
	b.box(o+Vector3(0,height*.5,-depth*.5),Vector3(width,height,.32),tone,true,0,"plaster")
	for side in [-1,1]:
		if side_portal:
			for zsign in [-1,1]:b.box(o+Vector3(side*width*.5,height*.5,zsign*(depth+3.2)*.25),Vector3(.32,height,(depth-3.2)*.5),tone,true)
			b.box(o+Vector3(side*width*.5,(height+2.8)*.5,0),Vector3(.32,maxf(.1,height-2.8),3.2),tone,true)
		else:
			b.box(o+Vector3(side*width*.5,.65,0),Vector3(.32,1.3,depth),tone,true,0,"plaster")
			b.box(o+Vector3(side*width*.5,height-.55,0),Vector3(.32,1.1,depth),tone,true,0,"plaster")
			b.glass(o+Vector3(side*width*.5,(height+.75)*.5,0),Vector3(.035,maxf(1,height-2.4),depth-.4))
			b.collision(o+Vector3(side*width*.5,height*.5,0),Vector3(.2,height,depth))
			for z in range(-int(depth*.5),int(depth*.5)+1,3):b.box(o+Vector3(side*width*.5,height*.5,z),Vector3(.45,height,.16),"927553")

func stairs(o:Vector3,rise:float,owner:String=""):
	var a:=o+Vector3(-4,0,5);var mid:=o+Vector3(-4,rise*.5,-3.2)
	var turn:=o+Vector3(-1,rise*.5,-3.2);var end:=o+Vector3(-1,rise,4.4)
	var compact:bool=owner in ["CASTLE_MATERIAL","CASTLE_DISPLAY"]
	# The existing floor beyond the stairwell is also the next flight's foot landing.
	# Register that support so a side rail cannot close the approach on upper floors.
	guards.pad(o+Vector3(-4,0,5.25 if compact else 5.6),Vector2(2.8,.9 if compact else 1.6),false)
	b.ramp(a,mid,1.8,"bda581");b.ramp(turn,end,1.8,"bda581")
	b.box(o+Vector3(-2.5,rise*.5-.12,-3.2),Vector3(4.8,.24,1.8),"bda581",true)
	guards.pad(o+Vector3(-2.5,rise*.5,-3.2),Vector2(4.8,1.8))
	# The flight reaches its full height before meeting the floor's vertical slab edge.
	var landing:Vector3=o+Vector3(-1,rise,4.735)
	b.box(landing-Vector3.UP*.12,Vector3(1.8,.24,.13),"bda581",true)
	guards.pad(landing,Vector2(1.8,.13),false)
	for pair in [[a,mid],[turn,end]]:
		var begin:Vector3=pair[0];var finish:Vector3=pair[1]
		var count:int=ceili(rise*.5/.15)
		for n in count:
			var v:Vector3=begin.lerp(finish,(n+.5)/count)
			b.box(v+Vector3(0,.02,0),Vector3(1.8,.07,Vector2(begin.x-finish.x,begin.z-finish.z).length()/count),"8f7858")
		guards.span(begin,finish,1.8)
	guards.span(mid,turn,1.8)
	if not owner.is_empty():
		var routes:Array=w.get_meta("upper_routes110",[])
		var points:Array=[o+Vector3(-4,0,6.1),a,mid,turn,end,o+Vector3(-1,rise,5.45),o+Vector3(-1,rise,6.1),o+Vector3(3,rise,6.1)]
		if compact:points=[o+Vector3(0,0,3.4),o+Vector3(-4,0,5.25),a,mid,turn,end,o+Vector3(-1,rise,5.25),o+Vector3(3,rise,5.25)]
		routes.append({"id":owner+"_STAIR_"+str(roundi(o.y*100)),"owner":owner,"width":1.8,"points":points,"floors":[]})
		w.set_meta("upper_routes110",routes)

func roof(o:Vector3,width:float,depth:float,style:String,tone:String):
	match style:
		"dome":
			for i in 8:
				var radius:float=cos(float(i)/8*PI*.5)*minf(width,depth)*.48
				b.shape(o+Vector3(0,i*.48,0),Vector3(radius*2,.52,radius*2),tone,"cylinder")
		"saw":
			for i in 4:
				var z:float=-depth*.5+(i+.5)*depth/4
				var pitch:float=-atan2(1.2,depth/4)
				b.oriented_box(o+Vector3(0,.65,z),Vector3(width+1,.20,sqrt(pow(depth/4,2)+1.44)+.15),tone,Basis(Vector3.RIGHT,pitch),true,"slate")
				b.glass(o+Vector3(0,.65,z+depth/8),Vector3(width,.95,.04))
		"double_shed":
			for side in [-1,1]:
				b.oriented_box(o+Vector3(side*width*.25,.55 if side<0 else 1.0,0),Vector3(width*.55,.24,depth+1.4),tone,Basis(Vector3.FORWARD,side*.17),true,"slate")
		"skylight":
			for side in [-1,1]:b.box(o+Vector3(side*width*.34,.12,0),Vector3(width*.37,.26,depth+1.4),tone,true,0,"stone")
			b.glass(o+Vector3(0,.24,0),Vector3(width*.31,.055,depth+1.3))
			for z in range(-int(depth*.5),int(depth*.5)+1,3):b.box(o+Vector3(0,.28,z),Vector3(width*.34,.15,.16),"aa9b7a")
		"sail_canopy":
			for side in [-1,1]:b.oriented_box(o+Vector3(side*width*.24,.35,0),Vector3(width*.57,.08,depth+1.6),"e9debf",Basis(Vector3.FORWARD,side*.24),false,"fabric")
			for x in [-width*.5,width*.5]:b.beam(o+Vector3(x,-4.4,-depth*.5),o+Vector3(x,.95,depth*.5),.10,"876e4c")
		"pergola":
			for x in range(-int(width*.5),int(width*.5)+1,2):b.box(o+Vector3(x,0,0),Vector3(.18,.25,depth+1.5),tone)
		"castle":
			preload("res://scripts/architecture_detail.gd").new().roof(b,o,width+3.1,depth+3.1,1.3,tone,true)
			for end in [-1,1]:
				for side in [-1,1]:
					b.beam(o+Vector3(side*(width*.5+1.3),.08,end*(depth*.5+1.3)),o+Vector3(side*(width*.5+1.85),.44,end*(depth*.5+1.65)),.18,"4d463b")
		_:
			b.box(o+Vector3(0,.1,0),Vector3(width+1.2,.28,depth+1.2),tone)
			b.box(o+Vector3(-width*.15,.65,0),Vector3(width*.63,.24,depth+.8),tone)

func castle_eaves(o:Vector3,width:float,depth:float):
	# The occupied floor above remains open. Only the outer roof ring projects beyond it.
	for side in [-1,1]:
		b.box(o+Vector3(side*(width*.5+.3),4.68,0),Vector3(3.7,.22,depth+4),"58685f",false,0,"slate")
		b.box(o+Vector3(0,4.68,side*(depth*.5+.3)),Vector3(width-2.6,.22,3.7),"58685f",false,0,"slate")
	var nx:int=ceili((width+4)/.65);var nz:int=ceili((depth+4)/.65)
	for i in nx:
		for j in nz:
			var x:float=-(width+4)*.5+(i+.5)*(width+4)/nx;var z:float=-(depth+4)*.5+(j+.5)*(depth+4)/nz
			var edge:float=maxf((absf(x)-(width*.5-1.1))/3.1,(absf(z)-(depth*.5-1.1))/3.1)
			if edge<0:continue
			var y:float=4.73+.57*(1.0-edge)+.20*smoothstep(.70,1,edge)
			b.box(o+Vector3(x,y,z),Vector3((width+4)/nx+.02,.18,(depth+4)/nz+.02),["4b5b53","53635a","5a6a60"][(i+j)%3],false,0,"slate")
	for side in [-1,1]:
		for x in range(-int(width*.5)+1,int(width*.5),3):
			var at:Vector3=o+Vector3(x,4.25,side*(depth*.5-.1))
			b.box(at,Vector3(.48,.22,1.25),"674c34",false,0,"wood")
			b.box(at+Vector3(0,.25,side*.25),Vector3(.75,.18,1.35),"785b3d",false,0,"wood")
		for x in [-width*.5,width*.5]:
			b.box(o+Vector3(x,4.05,side*depth*.5),Vector3(.55,.35,1.15),"604630",false,0,"wood")

func arch(a:Vector3,c:Vector3,height:float):
	var axis:Vector3=(c-a).normalized();var radius:float=a.distance_to(c)*.5;var o:Vector3=(a+c)*.5
	for i in 12:
		var t:float=(i+.5)*PI/12;var v:Vector3=o+axis*(cos(t)*radius)+Vector3.UP*(height+sin(t)*radius*.65)
		b.box(v,Vector3(.6,.55,.65),"f3eddf",false)
	b.box(a+Vector3(0,height*.5,0),Vector3(.55,height,.55),"e8ddc8",true)
	b.box(c+Vector3(0,height*.5,0),Vector3(.55,height,.55),"e8ddc8",true)

func station(p:Dictionary):
	foundation(p);var o:Vector3=at(p)
	guards.pad(o,Vector2(20,14))
	# Both station faces stay open; the cabin exit at z+4 is inside the protected platform.
	for x in [-9,9]:
		for z in [-6,6]:b.box(o+Vector3(x,2.2,z),Vector3(.45,4.4,.45),"76604a",true)
	for side in [-1,1]:
		b.box(o+Vector3(side*7.6,4.6,-1),Vector3(5.2,.35,15),"647c78")
		b.box(o+Vector3(side*7.6,5.0,-2),Vector3(4,.3,10),"b79f77")
	for side in [-1,1]:b.bench(o+Vector3(side*6,0,-4))
	b.text3d(p.name,o+Vector3(0,3.55,6.8),.010,"f6eedc")
	w.interact(p.id,o+Vector3(0,.1,4),p.name+" · F 乘缆车","creative_cable",{"station":0 if p.id=="CABLE_LOWER" else 1})
	floors.append({"id":p.id,"y":o.y,"entry":Vector3(p.door[0],o.y,p.door[2])})

func azure(p:Dictionary):
	foundation(p);var o:Vector3=at(p);var size:=Vector2(p.size[0],p.size[1]);var levels:int=p.floors.size()
	var open:bool=p.role in ["azure_light","azure_water","azure_glass","azure_sail"]
	if open:guards.pad(o,size)
	for level in levels:
		var f:Vector3=o+Vector3(0,level*4.4,0)
		if level>0:plate(f,size,"d5c4a5",true)
		if not open:wall(f,size.x,size.y,4.0,"f5efdf",false,p.role=="azure_model")
		if level>0 and not open:
			load("res://scripts/bay_finishings.gd").new(w).rail(f+Vector3(-1.6,0,size.y*.5),f+Vector3(1.6,0,size.y*.5))
		else:
			for x in [-size.x*.5,size.x*.5]:
				for z in [-size.y*.5,size.y*.5]:b.box(f+Vector3(x,2,z),Vector3(.6,4,.6),"e4d7c0",true)
		if level<levels-1:stairs(f,4.4,p.id)
		floors.append({"id":p.id,"floor":level,"y":f.y,"entry":f+Vector3(size.x*.3,.1,size.y*.28)})
	var top:Vector3=o+Vector3(0,levels*4.4,0)
	var style:String={"azure_view":"dome","azure_water":"pergola","azure_sail":"sail_canopy","azure_light":"pergola","azure_weave":"double_shed","azure_glass":"skylight","azure_model":"saw"}.get(str(p.role),"flat")
	roof(top,size.x,size.y,style,"4e89b2")
	if p.role=="azure_weave":
		for i in 4:
			var rail:Vector3=o+Vector3(-size.x*.5-1.3,2.5,-size.y*.3+i*size.y*.20)
			b.box(rail,Vector3(2.5,.10,.1),"8e7959")
			b.box(rail-Vector3.UP*.65,Vector3(1.8,1.25,.055),["c9a5b9","96b7ba","d9c08e","a8b89c"][i],false,0,"fabric")
	if p.role=="azure_glass":
		for x in [-size.x*.5,size.x*.5]:
			for z in range(-int(size.y*.5)+1,int(size.y*.5),4):arch(o+Vector3(x,0,z-1.5),o+Vector3(x,0,z+1.5),2.4)
	if p.role=="azure_water":
		for i in 3:
			var f:Vector3=o+Vector3(-6+i*6,.18,-3)
			b.box(f,Vector3(4.2,.3,5),"b2c5bc",true)
			for s in [-1,1]:b.box(f+Vector3(s*2.1,.22,0),Vector3(.2,.4,5),"ded0b6",true)
	if p.role=="azure_light":
		for i in 3:
			var f:Vector3=o+Vector3(-6+i*6,1.8,-3)
			for s in [-1,1]:b.box(f+Vector3(s*1.2,0,0),Vector3(.12,3.4,.12),"967c54",true)
			b.box(f+Vector3(0,1.7,0),Vector3(2.6,.12,.18),"967c54")
	if p.role=="azure_tide":
		b.box(o+Vector3(0,.35,-3),Vector3(8,.7,4),"c2d9cd",true)
		b.glass(o+Vector3(0,1.2,-.9),Vector3(8,1.5,.04))
	if p.role=="azure_model":b.table(o+Vector3(4,0,-2),4)
	else:b.table(o+Vector3(4,0,-2),2.5)
	b.text3d(p.name,o+Vector3(0,3.1,size.y*.5+.25),.009,"496b77")
	var work:Vector3=o+Vector3(3,.1,1)
	w.interact(p.id+"_WORK",work,p.name+" · 创作与观察","creative110",{"topic":p.role,"place":p.id})
	# A dry forecourt and planted margins explain every new entrance.
	for side in [-1,1]:b.planter(o+Vector3(side*(size.x*.5-1.5),0,size.y*.5+1.2),1.5,"d8b0bd")

func castle(p:Dictionary):
	foundation(p);var o:Vector3=at(p);var levels:int=p.floors.size();var main:bool=p.id=="CASTLE_MAIN"
	if p.id=="CASTLE_TEA":
		for x in [-4,4]:
			for z in [-3,3]:b.box(o+Vector3(x,1.7,z),Vector3(.3,3.4,.3),"695441",true)
		roof(o+Vector3(0,3.6,0),10,8,"castle","526c67");b.table(o+Vector3(0,0,-1),2)
		w.interact(p.id+"_WORK",o+Vector3(0,.1,1),"花霞茶亭 · 沏茶","creative110",{"topic":"castle_tea","place":p.id});return
	for n in levels:
		var f:=o+Vector3(0,n*(5.5 if levels>=3 else 4.4),0)
		var width:float=p.size[0]-(n*1.6 if main else 0);var depth:float=p.size[1]-(n*1.4 if main else 0)
		if n>0:plate(f,Vector2(width,depth),"c7ae89",true)
		wall(f,width,depth,7.35 if main and n==levels-1 else 4.35,"eee0c5",n==2 and levels>=3)
		if n>0:
			load("res://scripts/bay_finishings.gd").new(w).rail(f+Vector3(-1.6,0,depth*.5),f+Vector3(1.6,0,depth*.5))
		if n==2 and str(p.id) in ["CASTLE_PAPER","CASTLE_CLOTH"]:
			var outside:float=-1.0 if str(p.id)=="CASTLE_PAPER" else 1.0
			load("res://scripts/bay_finishings.gd").new(w).rail(f+Vector3(outside*width*.5,0,-1.6),f+Vector3(outside*width*.5,0,1.6))
		for side in [-1,1]:
			for z in [-depth*.5,depth*.5]:b.box(f+Vector3(side*width*.5,2.2,z),Vector3(.45,4.4,.45),"694b36")
		if n==levels-1:castle_roof(f+Vector3(0,7.7 if main else 4.5,0),width,depth,str(p.id))
		else:castle_eaves(f,width,depth)
		for side in [-1,1]:
			if side<0:b.box(f+Vector3(0,.85,-depth*.5-.18),Vector3(width,.16,.21),"5e4531",false,0,"wood")
			else:
				for sign in [-1,1]:b.box(f+Vector3(sign*(width+3.2)*.25,.85,depth*.5+.18),Vector3((width-3.2)*.5,.16,.21),"5e4531",false,0,"wood")
			b.box(f+Vector3(0,4.15,side*(depth*.5+.18)),Vector3(width,.25,.25),"5e4531",false,0,"wood")
			for x in range(-int(width*.5),int(width*.5)+1,4):
				if side>0 and absf(x)<1.9:continue
				b.box(f+Vector3(x,2.1,side*(depth*.5+.19)),Vector3(.19,4.2,.23),"654b34",false,0,"wood")
		# Roof eaves over lower floors do not cover the stairwell or next occupied room.
		if n<levels-1:stairs(f,5.5 if levels>=3 else 4.4,p.id)
		var topic:String=str(p.role)
		if main:topic=["castle_commission","castle_archive","castle_display","castle_paper","castle_photo","castle_garden","castle_window"][n]
		castle_room(f,width,depth,topic)
		if not main:castle_facade(f,width,depth,str(p.id))
		b.text3d(["风物委托","造物档案","我的作品展厅","纸灯与茶席","作品摄影","花木窗庭","山海望阁"][n] if main else p.name,f+Vector3(width*.29,2,-depth*.5+.25),.006,"5f685a")
		w.interact(p.id+"_F"+str(n+1),f+Vector3(width*.29,.1,depth*.18),"使用 · "+(str(n+1)+"层 " if main else "")+p.name,"creative110",{"topic":topic,"place":p.id,"floor":n})
		floors.append({"id":p.id,"floor":n,"y":f.y,"entry":f+Vector3(width*.29,.12,depth*.18)})
	b.text3d(p.name,o+Vector3(0,3.1,p.size[1]*.5+.25),.008,"6a5845")

func castle_roof(o:Vector3,width:float,depth:float,id:String):
	var detail=preload("res://scripts/architecture_detail.gd").new()
	if id=="CASTLE_PAPER":detail.roof(b,o,width+2.5,depth+2.8,2.3,"65786e",false)
	elif id=="CASTLE_CLOTH":
		for side in [-1,1]:detail.roof(b,o+Vector3(side*width*.25,.45 if side<0 else 0,0),width*.59,depth+2.2,1.4,"7b7562",false)
	elif id=="CASTLE_MATERIAL":detail.roof(b,o,width+2.8,depth+2.0,1.75,"7e6d55",false)
	else:roof(o,width,depth,"castle","586a64")

func castle_facade(o:Vector3,width:float,depth:float,id:String):
	if id in ["CASTLE_PAPER","CASTLE_DISPLAY"]:
		var side:float=1.0 if id=="CASTLE_PAPER" else -1.0
		var bay:=o+Vector3(side*width*.30,1.9,depth*.5+.36)
		b.box(bay,Vector3(2.5,1.6,.22),"886c49",false,0,"wood")
		for i in 7:b.box(bay+Vector3(-1.05+i*.35,0,.13),Vector3(.12,1.45,.06),"ddd1ab",false,0,"fabric")
		b.box(bay+Vector3(0,.93,.12),Vector3(2.9,.15,1.1),"65746a",false,0,"slate")
	elif id=="CASTLE_CLOTH":
		for side in [-1,1]:
			var p:=o+Vector3(side*(width*.5-1.15),2.5,depth*.5+.3)
			b.box(p,Vector3(1.45,2.35,.06),"b29aa6" if side<0 else "9eafa0",false,0,"fabric")
			b.box(p+Vector3(0,1.25,0),Vector3(1.7,.14,.22),"70583d",false,0,"wood")
	elif id=="CASTLE_MATERIAL":
		for side in [-1,1]:
			var p:=o+Vector3(side*(width*.5-1.1),.6,depth*.5-.5)
			for i in 3:b.box(p+Vector3(0,i*.45,0),Vector3(1.25,.40,.55),["9f906d","b3a17a","8f977c"][i],true,0,"wood")

func castle_room(o:Vector3,width:float,depth:float,topic:String):
	var right:float=width*.31
	match topic:
		"castle_commission":
			b.box(o+Vector3(-width*.32,1.15,-depth*.38),Vector3(4.6,2.3,.35),"76583d",true,0,"wood")
			for i in 3:b.box(o+Vector3(-width*.32-1.35+i*1.35,1.28,-depth*.38+.21),Vector3(1.04,1.35,.04),"e6d8b8",false,0,"fabric")
		"castle_archive","castle_paper","castle_material":
			for side in [-1,1]:
				var x:float=side*width*.37
				for y in [.5,1.3,2.1]:
					b.box(o+Vector3(x,y,-depth*.36),Vector3(3.1,.13,.68),"8a6846",true,0,"wood")
					for i in 8:b.box(o+Vector3(x-1.3+i*.35,y+.26,-depth*.36),Vector3(.24,.46,.43),["b4b993","bda283","c0a6ae","95acaa"][i%4],false,0,"fabric")
		"castle_display":
			for i in 3:
				var p:Vector3=o+Vector3(right,0,-depth*.34+i*depth*.31)
				b.box(p+Vector3(0,.28,0),Vector3(1.1,.56,1.1),"c6b391",true,0,"stone")
				b.shape(p+Vector3(0,.78,0),Vector3(.5,.5,.5),["abae8b","c9acae","a5bdba"][i],"pot")
		"castle_photo":
			b.box(o+Vector3(right,1.55,-depth*.40),Vector3(4.3,3.1,.08),"b8c3b2",false,0,"fabric")
			for side in [-1,1]:
				var p:Vector3=o+Vector3(right+side*1.85,0,-depth*.29)
				b.beam(p,p+Vector3(0,2.4,0),.08,"776950");b.glow_box(p+Vector3(0,2.5,0),Vector3(.65,.46,.12))
		"castle_garden":
			for side in [-1,1]:
				var p:Vector3=o+Vector3(side*width*.35,0,depth*.31)
				b.planter(p,2.4,"b9acb5");b.beam(p+Vector3(-1,0,0),p+Vector3(-1,2.4,0),.12,"8b7252");b.beam(p+Vector3(1,0,0),p+Vector3(1,2.4,0),.12,"8b7252");b.beam(p+Vector3(-1,2.4,0),p+Vector3(1,2.4,0),.14,"8b7252")
		"castle_window":
			for z in [-depth*.30,depth*.30]:b.bench(o+Vector3(right,0,z),PI*.5)
			b.shape(o+Vector3(right,1.3,0),Vector3(.32,.35,.85),"a59470","cylinder",.45)
		"castle_cloth":
			for i in 3:b.box(o+Vector3(width*.33,1.45,-depth*.3+i*depth*.3),Vector3(.06,2.1,2.2),["caaebd","b2c6c2","d5be8c"][i],false,0,"fabric")
		_:
			for side in [-1,1]:b.box(o+Vector3(right+side*.65,.15,depth*.22),Vector3(.65,.30,.65),"aa9b7c",false,0,"fabric")

func castle_links():
	var y:=18.4
	for pair in [[Vector3(-137,y,10),Vector3(-125.9,y,10)],[Vector3(-99.1,y,10),Vector3(-91,y,10)]]:
		b.ramp(pair[0],pair[1],3.2,"b49a72");guards.span(pair[0],pair[1],3.2)
	for c in [Vector3(-112.5,4.2,68),Vector3(-112.5,5.8,44),Vector3(-112.5,7.4,28)]:
		var size:=Vector2(72,14 if c.z==68 else 18 if c.z==44 else 12)
		for x in range(-36,36,2):
			for z in range(-int(size.y*.5),int(size.y*.5),2):
				var point:Vector3=c+Vector3(x+1,0,z+1);var indoor:=false
				for p in w.layout.creative_places:
					if not str(p.id).begins_with("CASTLE_"):continue
					if absf(point.x-p.center[0])<p.size[0]*.5+1 and absf(point.z-p.center[2])<p.size[1]*.5+1:indoor=true;break
				for road in w.layout.near(w.layout.road_index,Vector2(point.x,point.z)):
					var q:Vector3=w.layout.projection(Vector2(point.x,point.z),road)
					if Vector2(point.x-q.x,point.z-q.z).length()<road.width*.5+1.42:indoor=true;break
				if not indoor:b.box(point-Vector3.UP*.35,Vector3(2,.7,2),"c7b894" if (x+z)%6==0 else "d6c6a5",true,0,"stone")
		# These courts feather into ground 0.3 m below; upper bridges keep their own rails.
		guards.pad(c,size,false)
		for side in [-1,1]:
			b.planter(c+Vector3(side*29,0,4.5),3,"cda4b5")
			b.lamp(c+Vector3(side*32,0,-4))

func cable():
	var transport=preload("res://scripts/creative_transport110.gd")
	var points:Array=transport.route_points(w)
	for lane in 2:
		for i in points.size()-1:
			var t0:float=float(i)/(points.size()-1);var t1:float=float(i+1)/(points.size()-1)
			var a:Vector3=transport.lane_at(points,t0,lane)+Vector3.UP*transport.HANGER_HEIGHT
			var c:Vector3=transport.lane_at(points,t1,lane)+Vector3.UP*transport.HANGER_HEIGHT
			b.beam(a,c,.075,"5c665e")
	for v in [Vector2(-221.88,-186.18),Vector2(-174,-237),Vector2(-123.84,-290.24),Vector2(-82.8,-333.8)]:
		var ground:float=w.height_at(v.x,v.y);var nearest:Vector3=points[0];var dist:=INF
		for point in points:
			var d:float=Vector2(point.x-v.x,point.z-v.y).length_squared()
			if d<dist:dist=d;nearest=point
		var high:float=nearest.y+transport.HANGER_HEIGHT+.5
		b.box(Vector3(v.x,(ground+high)*.5,v.y),Vector3(.9,high-ground,.9),"6d7a70",true)
		b.box(Vector3(v.x,ground+.2,v.y),Vector3(3,.4,3),"b9ac91",true)
		b.box(Vector3(v.x,high,v.y),Vector3(6,.4,.7),"6d7a70")

func lighthouse(o:Vector3):
	plate(o,Vector2(7,7),"d4c4a5")
	wall(o,4.6,4.6,8,"f4efe6")
	var path:Array=[o+Vector3(3.6,0,4.1),o+Vector3(3.6,2,-4.1),o+Vector3(-3.6,4,-4.1),o+Vector3(-3.6,6,4.1),o+Vector3(3.6,8,4.1)]
	var all_points:Array=[path[0]]
	for point in path:plate(point,Vector2(2.4,2.4),"c6b597")
	for i in path.size()-1:
		var direction:Vector3=path[i+1]-path[i];direction.y=0;direction=direction.normalized()
		var a:Vector3=path[i]+direction*1.1;var c:Vector3=path[i+1]-direction*1.1
		# Full-height flat turns precede the change of direction; no slab edge rises into a flight.
		b.ramp(a,c,1.8,"bdac8c");guards.span(a,c,1.8)
		all_points.append(a);all_points.append(c);all_points.append(path[i+1])
	var observation:=o+Vector3(0,8,-1.2)
	plate(observation,Vector2(9,6.6),"c2b296");guards.pad(observation,Vector2(9,6.6))
	var inward:=o+Vector3(3.6,8,1.9);var lookout:=o+Vector3(2,8,1.4)
	b.ramp(path[-1],inward,1.8,"bdac8c");guards.span(path[-1],inward,1.8)
	b.ramp(inward,lookout,1.8,"bdac8c");guards.span(inward,lookout,1.8,false)
	for y in [2.0,5.0]:
		for side in [-1,1]:b.box(o+Vector3(side*2.33,y,0),Vector3(.06,.38,4.6),"b86b4b")
	b.glow_box(o+Vector3(0,9.6,0),Vector3(1.4,1.1,1.4));b.box(o+Vector3(0,10.4,0),Vector3(3.2,.3,3.2),"4a5d6b")
	w.interact("LIGHTHOUSE_UPPER",lookout+Vector3.UP*.1,"灯塔观景层 · 看海","photo_mode",{})
	guards.build("lighthouse110",true)
	var art=preload("res://scripts/creative_architecture110.gd").new(w)
	art.flush_entry(o,3,4.6,0,"LIGHTHOUSE")
	all_points.append(inward);all_points.append(lookout)
	art.upper_route("LIGHTHOUSE_CLIFF_WALK","LIGHTHOUSE",all_points,[{"center":observation,"size":Vector2(9,6.6),"y":o.y+8}])
	art.record("LIGHTHOUSE","walkable_coastal_beacon",o,Vector2(9,9),o+Vector3(0,0,2.3),[0.0,8.0])

func creek_entry():
	var p:=Vector3(-194,3.3,-187.5)
	var public:=Vector3(-194,3.3,-194)
	var turn:=Vector3(-192.6,3.3,-194)
	var door:=Vector3(-192.6,3.3,-189.7)
	var inside:=Vector3(-192.6,3.3,-189.0)
	# A gently graded bridge reaches the clear side of the tea table, from the actual public path.
	b.ramp(public,turn,3.2,"aa906c");b.ramp(turn,door,2.8,"aa906c")
	plate(turn,Vector2(3.2,3.2),"aa906c");guards.pad(turn,Vector2(3.2,3.2))
	guards.span(public,turn,3.2,false);guards.span(turn,door,2.8)
	guards.pad(p,Vector2(4.8,4.4),false)
	for x in [-193.9,-191.3]:
		var low:float=minf(2.0,w.height_at(x,-192))
		b.box(Vector3(x,(low+3.23)*.5,-192),Vector3(.22,3.23-low,.22),"6f4d35",false,0,"wood")
	guards.build("creek_entry110",true)
	var entries:Array=w.get_meta("entrances110",[])
	entries.append({"id":"CREEK_TEA","public_route":public,"public_road_id":"valley_arch","anchor":public,"approach":turn,"door":door,"inside":inside,"landing":door,"outer":turn,"width":2.8,"points":[public,turn,door,inside]})
	w.set_meta("entrances110",entries)
	preload("res://scripts/creative_architecture110.gd").new(w).record("CREEK_TEA","waterwheel_tea_bridge",p,Vector2(4.8,4.4),door,[0.0])
