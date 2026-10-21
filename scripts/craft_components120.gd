extends RefCounted
## Measured architectural joinery and purpose-built workshop equipment.
var w
var b
var origin:=Vector3.ZERO
var frame:=Basis.IDENTITY
const TIMBER="806345"
const BRASS="b79b61"
const PAPER="eee2c9"
func _init(world):w=world;b=w.b
func at(p:Vector3,yaw:float=0):origin=p;frame=Basis(Vector3.UP,yaw);return self
func point(p:Vector3)->Vector3:return origin+frame*p
func part(p:Vector3,s:Vector3,tone:String,solid:bool=false):b.oriented_box(point(p),s,tone,frame,solid,"metal" if tone==BRASS else "wood" if tone in [TIMBER,"a78c65","624c37"] else "stone" if tone in ["b8ae92","d6c5a6","a59983"] else "fabric" if tone==PAPER else "")
func rod(a:Vector3,c:Vector3,width:float=.07,tone:String=TIMBER):b.beam(point(a),point(c),width,tone)
func drum(p:Vector3,s:Vector3,tone:String=BRASS):b.shape(point(p),s,tone,"cylinder",frame.get_euler().y,"metal" if tone==BRASS else "")
func glow(p:Vector3,s:Vector3):b.glow_box(point(p),s)
func slab(p:Vector3,s:Vector2,height:float=.86,tone:String=TIMBER):
	part(p+Vector3(0,height,0),Vector3(s.x,.12,s.y),tone,true)
	for x in [-1,1]:
		for z in [-1,1]:part(p+Vector3(x*(s.x*.5-.16),height*.5,z*(s.y*.5-.12)),Vector3(.12,height,.12),TIMBER)
func mesh_surface(points:PackedVector3Array,indices:PackedInt32Array,tone:String,two_sided:bool=false)->MeshInstance3D:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:tool.add_vertex(points[i])
	tool.generate_normals();var n:=MeshInstance3D.new();n.mesh=tool.commit();var mat:StandardMaterial3D=b.material(tone).duplicate();mat.cull_mode=BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_BACK;n.material_override=mat;w.add_child(n);n.transform=Transform3D(frame,origin);return n
func arch_ring(p:Vector3,width:float,height:float,thick:float=.22,tone:String=PAPER):
	var points:=PackedVector3Array();var indices:=PackedInt32Array();var segments:=16
	for i in segments+1:
		var a:float=i*PI/segments
		for z in [-thick*.5,thick*.5]:
			for r in [width*.5,width*.5+thick]:points.append(p+Vector3(cos(a)*r,height+sin(a)*(minf(width*.5,2.2)+r-width*.5),z))
	for i in segments:
		var q:int=i*4
		for face in [[q,q+4,q+1,q+5],[q+2,q+3,q+6,q+7],[q,q+2,q+4,q+6],[q+1,q+5,q+3,q+7]]:
			for k in [0,1,2,2,1,3]:indices.append(face[k])
	mesh_surface(points,indices,tone,true)
	for x in [-1,1]:part(p+Vector3(x*(width*.5+thick*.5),height*.5,0),Vector3(thick,height,thick),tone)
func window(p:Vector3,s:Vector2,tone:String=TIMBER,arch:bool=false):
	# Glass sits behind thick jambs; collision matches the opening, never its route.
	var glass:=MeshInstance3D.new();var pane:=BoxMesh.new();pane.size=Vector3(s.x,s.y,.045);glass.mesh=pane;glass.material_override=b.material("97b6b0").duplicate();glass.material_override.albedo_color=Color(.59,.74,.71,.18);glass.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;w.add_child(glass);glass.transform=Transform3D(frame,point(p+Vector3(0,0,-.12)))
	b.collision(point(p),Vector3(s.x,s.y,.14),frame.get_euler().y)
	for x in [-1,1]:part(p+Vector3(x*s.x*.5,0,0),Vector3(.18,s.y+.22,.42),tone)
	for y in [-1,1]:part(p+Vector3(0,y*s.y*.5,.03),Vector3(s.x+.3,.16,.46),tone)
	part(p+Vector3(0,0,-.02),Vector3(.09,s.y,.13),tone);part(p+Vector3(0,-s.y*.12,-.02),Vector3(s.x,.08,.13),tone)
	part(p+Vector3(0,-s.y*.5-.10,.12),Vector3(s.x+.42,.12,.65),"c7b69a")
	if arch:arch_ring(p+Vector3(0,s.y*.5-s.x*.5,0),s.x,0,.16,tone)
func sign(words:String,p:Vector3,width:float=4,yaw:float=0):
	at(p,yaw);part(Vector3.ZERO,Vector3(width,.65,.20),"526b61");part(Vector3(0,0,.105),Vector3(width-.12,.53,.025),"294d4e");var label:Label3D=b.text3d(words,point(Vector3(0,0,.14)),.0065,PAPER,yaw);label.set_meta("design120_sign",true)
func barrel_roof(p:Vector3,width:float,depth:float,rise:float,tone:String="3b6e8c",yaw:float=0):
	at(p,yaw);var points:=PackedVector3Array();var indices:=PackedInt32Array();var n:=24
	for i in n+1:
		var u:float=float(i)/n;var x:float=(u-.5)*width;var y:float=sin(u*PI)*rise
		for z in [-depth*.5,depth*.5]:
			points.append(Vector3(x,y,z));points.append(Vector3(x,y-.16,z))
	for i in n:
		var a:int=i*4
		for face in [[a,a+2,a+4,a+6],[a+1,a+5,a+3,a+7],[a,a+4,a+1,a+5],[a+2,a+3,a+6,a+7]]:
			for k in [0,1,2,2,1,3]:indices.append(face[k])
	mesh_surface(points,indices,tone,true)
	for z in [-depth*.48,0,depth*.48]:
		for i in 12:
			var u:float=float(i)/12;var v:float=float(i+1)/12;rod(Vector3((u-.5)*width,sin(u*PI)*rise-.24,z),Vector3((v-.5)*width,sin(v*PI)*rise-.24,z),.16,TIMBER)
	for x in [-width*.5,width*.5]:part(Vector3(x,-.04,0),Vector3(.18,.20,depth+.25),TIMBER)
func curved_roof(p:Vector3,width:float,depth:float,rise:float,tone:String="697d70"):
	at(p);var points:=PackedVector3Array();var indices:=PackedInt32Array();var nx:=12;var nz:=8
	for j in nz+1:
		for i in nx+1:
			var x:float=(float(i)/nx-.5)*width;var z:float=(float(j)/nz-.5)*depth
			var edge:float=maxf(absf(x)/(width*.5),absf(z)/(depth*.5));var y:float=rise*(1-pow(edge,.75))+.34*pow(edge,8)
			points.append(Vector3(x,y,z))
	for j in nz:
		for i in nx:
			var a:int=j*(nx+1)+i
			for k in [a,a+nx+1,a+1,a+1,a+nx+1,a+nx+2]:indices.append(k)
	mesh_surface(points,indices,tone,true)
	for side in [-1,1]:
		rod(Vector3(-width*.5,.34,side*depth*.5),Vector3(width*.5,.34,side*depth*.5),.18,"4b5144")
	for x in range(-int(width*.5)+1,int(width*.5),2):
		for side in [-1,1]:
			part(Vector3(x,-.35,side*(depth*.5-.8)),Vector3(.18,.36,1.25),TIMBER);part(Vector3(x,-.12,side*(depth*.5-.65)),Vector3(.55,.16,1.6),"98744c")
func device(kind:String,p:Vector3,scale_value:float=1,yaw:float=0):
	at(p,yaw);frame=frame.scaled(Vector3.ONE*scale_value)
	var records:Array=w.get_meta("design120_devices",[]);records.append({"kind":kind,"position":p,"scale":scale_value,"yaw":yaw,"extent":Vector2(3.6,1.6)*scale_value});w.set_meta("design120_devices",records)
	match kind:
		"schedule":
			for x in [-1.55,1.55]:part(Vector3(x,1.3,0),Vector3(.16,2.6,.2),TIMBER)
			part(Vector3(0,2.0,0),Vector3(3.4,1.3,.3),"486568",true)
			for i in 3:
				for j in 8:part(Vector3(-1.3+j*.37,1.6+i*.37,.18),Vector3(.28,.27,.04),"d0c7ab");part(Vector3(-1.3+j*.37,1.6+i*.37,.207),Vector3(.18,.025,.015),"677c6b")
			part(Vector3(0,1.28,.20),Vector3(3.3,.12,.6),BRASS)
		"luggage":
			part(Vector3(0,.35,0),Vector3(2.2,.13,1.2),TIMBER,true)
			for x in [-.9,.9]:
				for z in [-.4,.4]:drum(Vector3(x,.17,z),Vector3(.28,.28,.16),"5d6a58")
			for i in 3:part(Vector3(-.6+i*.6,.72+(i%2)*.16,0),Vector3(.55,.65+(i%2)*.3,.85),["9a7a56","b29a72","708a79"][i]);part(Vector3(-.6+i*.6,1.1+(i%2)*.31,0),Vector3(.20,.06,.1),BRASS)
			for z in [-.5,.5]:rod(Vector3(1,.35,z),Vector3(1,1.6,z),.06,BRASS)
			rod(Vector3(1,1.6,-.5),Vector3(1,1.6,.5),.06,BRASS)
		"tools":
			part(Vector3(0,1.5,0),Vector3(3.6,2.8,.16),"a68f6a",true)
			for i in 6:
				var x:float=-1.45+i*.58;rod(Vector3(x,.45,.16),Vector3(x,2.35,.16),.045,TIMBER);part(Vector3(x,2.4,.17),Vector3(.28,.18,.07),"667968")
				if i%2==0:part(Vector3(x,.42,.17),Vector3(.3,.40,.06),"7b8979")
			part(Vector3(0,.45,.48),Vector3(3.5,.12,.8),TIMBER)
		"oven":
			part(Vector3(0,.48,0),Vector3(2.8,.96,1.7),"ad7958",true)
			for y in 4:
				for x in 7:part(Vector3(-1.4+x*.42+(y%2)*.2,.96+y*.18,.84),Vector3(.39,.16,.12),["a66547","bb805a","965940"][(x+y)%3])
			part(Vector3(0,1.21,.92),Vector3(1.05,.51,.12),"423e33");arch_ring(Vector3(0,1.0,.99),1.05,.25,.16,"c5986c");part(Vector3(.98,2.9,-.45),Vector3(.65,3.8,.66),"a87554");part(Vector3(.98,4.84,-.45),Vector3(.9,.16,.9),"c3b397")
		"espresso":
			slab(Vector3.ZERO,Vector2(3.8,1.3),.95);part(Vector3(0,1.08,0),Vector3(3.9,.12,1.4),"d6c5a6");drum(Vector3(-.6,1.58,0),Vector3(.7,.8,.65));part(Vector3(.45,1.48,-.2),Vector3(1.5,.65,.52),"a58352")
			for x in [-.1,.4,.9]:rod(Vector3(x,1.52,.15),Vector3(x,1.36,.42),.08,BRASS);drum(Vector3(x,1.2,.38),Vector3(.22,.16,.22),PAPER)
		"turntable":
			slab(Vector3.ZERO,Vector2(3.1,1.5),.88);part(Vector3(0,1,0),Vector3(2.8,.12,1.3),"46544a")
			for x in [-.75,.75]:
				drum(Vector3(x,1.10,0),Vector3(1.05,.06,1.05),"283c3a");drum(Vector3(x,1.14,0),Vector3(.27,.025,.27),"d2ae73");rod(Vector3(x+.45,1.17,-.4),Vector3(x+.05,1.17,.12),.045,BRASS)
		"flowerbench":
			slab(Vector3.ZERO,Vector2(3.4,1.45));part(Vector3(-.85,.97,-.05),Vector3(.75,.06,.8),"cbb9a1")
			for i in 6:
				var t:=Vector3(-1.1+i*.43,1.0,.2);drum(t,Vector3(.23,.18,.23),"d1c09f");rod(t,t+Vector3(.12,.65,-.1),.025,"6f8e61");drum(t+Vector3(.12,.65,-.1),Vector3(.23,.15,.23),["dba7b7","d7c68f","afc8b2"][i%3])
			rod(Vector3(1.1,1,-.3),Vector3(1.1,1.6,-.3),.065,BRASS);rod(Vector3(1.1,1.6,-.3),Vector3(.85,1.6,-.3),.065,BRASS)
		"folio","bindery":
			slab(Vector3.ZERO,Vector2(3.4,1.4));
			for i in 5:part(Vector3(-1.1+i*.5,.97,0),Vector3(.40,.05,.75),[PAPER,"c4b395","b7bfa7"][i%3])
			for side in [-1,1]:part(Vector3(side*1.35,1.42,-.35),Vector3(.13,.85,.13),TIMBER)
			part(Vector3(0,1.81,-.35),Vector3(2.9,.18,.3),TIMBER);rod(Vector3(0,1.2,-.35),Vector3(0,2.1,-.35),.07,BRASS);part(Vector3(0,1.19,-.35),Vector3(1.6,.14,.7),"ab9971")
		"loom":
			for x in [-1.25,1.25]:part(Vector3(x,1.45,0),Vector3(.18,2.9,.22),TIMBER);part(Vector3(x,.14,0),Vector3(.24,.28,1.5),TIMBER)
			for y in [.3,2.7]:part(Vector3(0,y,0),Vector3(2.7,.18,.25),TIMBER)
			for i in 22:rod(Vector3(-1.12+i*.105,.45,.02),Vector3(-1.12+i*.105,2.6,.02),.018,"decaa1")
			for i in 15:part(Vector3(0,.5+i*.075,.035),Vector3(2.22,.045,.035),["759ca0","c5aa87","aeb9a0"][i%3])
			part(Vector3(0,.31,.7),Vector3(1.7,.10,.24),TIMBER);rod(Vector3(0,.4,.7),Vector3(0,1.35,0),.07,TIMBER)
		"console":
			slab(Vector3.ZERO,Vector2(3.2,1.4),.9);part(Vector3(0,1.02,0),Vector3(3.1,.14,1.3),"53645c")
			for i in 12:
				var x:float=-1.35+i*.24;part(Vector3(x,1.10,.13),Vector3(.025,.016,.56),"c7c4aa");part(Vector3(x,1.14,-.12+(i%4)*.13),Vector3(.12,.05,.1),BRASS)
				for j in 3:part(Vector3(x,1.13,-.43+j*.08),Vector3(.10,.035,.035),["d2b776","a7bd93","cd9c89"][j])
			for side in [-1,1]:part(Vector3(side*1.85,1.2,-.3),Vector3(.5,1.2,.6),"3e514b");drum(Vector3(side*1.85,1.3,.025),Vector3(.35,.35,.1),"ad9f7f")
		"drawers":
			part(Vector3(0,1.22,0),Vector3(3.6,2.44,.7),TIMBER,true)
			for row in 6:
				for col in 8:
					var q:=Vector3(-1.55+col*.445,.22+row*.39,.37);part(q,Vector3(.40,.35,.05),["ab9471","bba580","947957"][(row+col)%3]);part(q+Vector3(0,-.04,.035),Vector3(.17,.055,.035),BRASS);part(q+Vector3(0,.07,.04),Vector3(.22,.075,.015),PAPER)
		"projector":
			part(Vector3(0,.7,0),Vector3(.65,1.4,.65),"55605b",true);part(Vector3(0,1.55,0),Vector3(.8,.6,.9),"5d6c61");drum(Vector3(-.5,2.06,-.25),Vector3(.8,.8,.13),"9b956f");drum(Vector3(.5,2.06,-.25),Vector3(.8,.8,.13),"9b956f");part(Vector3(0,1.57,.63),Vector3(.35,.3,.4),"b4a077")
		"camera":
			for a in [0,TAU/3,TAU*2/3]:rod(Vector3(0,1.45,0),Vector3(sin(a)*.65,0,cos(a)*.65),.055,"63756b")
			part(Vector3(0,1.6,0),Vector3(.65,.45,.35),"44564e");drum(Vector3(0,1.6,.3),Vector3(.32,.32,.45),"9e9479")
		"photo":
			slab(Vector3.ZERO,Vector2(3.8,1.25));
			for i in 3:part(Vector3(-1.1+i*1.1,.97,0),Vector3(.88,.15,.85),["8a6b57","aa9681","b8b9a2"][i]);part(Vector3(-1.1+i*1.1,1.06,0),Vector3(.70,.02,.68),"b9c4b1")
			rod(Vector3(-1.4,.98,-.35),Vector3(-1.4,2.25,-.35),.08,TIMBER);part(Vector3(-1.2,2.1,-.18),Vector3(.6,.3,.65),"657464")
		"easel":
			for x in [-.6,.6]:rod(Vector3(x,0,.35),Vector3(x*.4,2.1,0),.08,TIMBER)
			rod(Vector3(0,1.7,0),Vector3(0,0,-.7),.08,TIMBER);part(Vector3(0,1.25,.09),Vector3(1.1,1.45,.07),PAPER);part(Vector3(0,.55,.16),Vector3(1.45,.09,.2),TIMBER)
			for i in 5:part(Vector3(-.35+i*.16,1.05+i%3*.14,.14),Vector3(.24,.3+i%2*.2,.03),["a0b49a","94b9b3","c8b194"][i%3])
		"telescope":
			for a in [0,TAU/3,TAU*2/3]:rod(Vector3(0,1.35,0),Vector3(sin(a)*.8,0,cos(a)*.8),.08,TIMBER)
			rod(Vector3(0,1.35,0),Vector3(0,1.9,.8),.26,BRASS);part(Vector3(0,1.86,.82),Vector3(.33,.33,.1),"5c7c78")
		"diorama","street":
			slab(Vector3.ZERO,Vector2(3.6,2.2));part(Vector3(0,.97,0),Vector3(3.4,.10,2),"90b9ac")
			for i in 7:
				var q:=Vector3(-1.25+(i%4)*.75,1.15,-.6+(i/4)*.9);part(q,Vector3(.48,.3+(i%3)*.12,.45),PAPER);part(q+Vector3(0,.2+(i%3)*.06,0),Vector3(.55,.1,.52),"65867b")
		"basin","flow_basin":
			part(Vector3(0,.42,0),Vector3(3.2,.84,1.4),"b8ae92",true)
			if kind!="flow_basin":part(Vector3(0,.85,0),Vector3(2.85,.025,1.05),"8bb4ae")
			for x in [-1.55,1.55]:part(Vector3(x,.93,0),Vector3(.18,.22,1.5),"ded1b4")
			if kind!="flow_basin":
				for i in 12:drum(Vector3(-1.2+(i%6)*.47,.90,-.3+(i/6)*.5),Vector3(.18,.09,.23),["87b8b1","a5bfc1","d8c28c","baa7b6"][i%4])
		"pottery":
			slab(Vector3.ZERO,Vector2(3.2,1.5),.7)
			for x in [-.95,0,.95]:drum(Vector3(x,.85,0),Vector3(.75,.13,.75),"9e8360");drum(Vector3(x,1.1,0),Vector3(.38,.45,.38),"bd9d7c")
		"hearth":
			part(Vector3(0,.2,0),Vector3(2.8,.4,1.8),"a59983",true);part(Vector3(0,1.0,-.45),Vector3(2.5,1.6,.65),"9f947e",true)
			for x in [-.85,.85]:part(Vector3(x,.82,.2),Vector3(.55,1.3,.8),"b2a48a",true)
			part(Vector3(0,1.6,.2),Vector3(2.7,.32,1.0),"b7aa8e",true);part(Vector3(0,3.0,-.4),Vector3(1.1,2.6,.8),"9d927c");part(Vector3(0,.55,.25),Vector3(.8,.05,.5),"69533c");glow(Vector3(0,.62,.26),Vector3(.55,.11,.25))
		"puppet":
			part(Vector3(0,.5,0),Vector3(3.2,1,.9),TIMBER,true)
			for x in [-1.4,1.4]:part(Vector3(x,1.75,0),Vector3(.35,1.5,.6),"a57763");part(Vector3(x*.7,1.7,-.15),Vector3(.45,1.35,.12),"946974")
			part(Vector3(0,2.6,0),Vector3(3.4,.35,.65),TIMBER);rod(Vector3(-1.3,2.45,-.25),Vector3(1.3,2.45,-.25),.07,BRASS)
			for i in 3:rod(Vector3(-.7+i*.7,2.4,-.2),Vector3(-.7+i*.7,1.6,-.2),.012,PAPER);drum(Vector3(-.7+i*.7,1.5,-.2),Vector3(.25,.4,.25),["c2ab7c","a7b59a","b99baa"][i])
		"drying":
			for x in [-1.6,1.6]:part(Vector3(x,1.6,0),Vector3(.14,3.2,.18),TIMBER)
			for y in [.45,1.3,2.2,3.05]:rod(Vector3(-1.6,y,0),Vector3(1.6,y,0),.055,TIMBER)
			for i in 8:part(Vector3(-1.35+(i%4)*.9,1.0+(i/4)*.95,.03),Vector3(.55,.75,.025),["c5adb2",PAPER,"a8beb3"][i%3]);part(Vector3(-1.35+(i%4)*.9,1.42+(i/4)*.95,.03),Vector3(.04,.12,.055),TIMBER)
		"mannequin":
			for i in 3:
				var x:float=(i-1)*1.1;drum(Vector3(x,.08,0),Vector3(.65,.16,.65),TIMBER);rod(Vector3(x,.1,0),Vector3(x,1.5,0),.05,BRASS);drum(Vector3(x,1.35,0),Vector3(.5,.85,.38),["bda4ae","a9bcae","d2be98"][i]);part(Vector3(x,1.8,0),Vector3(.6,.1,.32),PAPER)
		"roaster":
			part(Vector3(0,.5,0),Vector3(2,.9,1.2),"5b6154",true);drum(Vector3(0,1.15,0),Vector3(1.25,1.1,1.1),"aa7c50");drum(Vector3(.6,.9,.8),Vector3(1.3,.14,1.3),"b8a77c");part(Vector3(-.6,2,0),Vector3(.25,1.4,.25),"8b7859")
		"chimes":
			for x in [-1.6,1.6]:part(Vector3(x,1.5,0),Vector3(.12,3,.16),TIMBER)
			part(Vector3(0,3,0),Vector3(3.5,.16,.24),TIMBER)
			for i in 12:rod(Vector3(-1.4+i*.25,2.95,0),Vector3(-1.4+i*.25,1.65+(i%4)*.19,0),.013,PAPER);drum(Vector3(-1.4+i*.25,1.4+(i%4)*.19,0),Vector3(.12,.5,.12),[BRASS,"d0c0a0","a9b7a1"][i%3])
		"seedwall":
			for y in [.2,1,1.8,2.6]:part(Vector3(0,y,0),Vector3(3.6,.12,.6),TIMBER)
			for x in [-1.75,1.75]:part(Vector3(x,1.4,0),Vector3(.12,2.8,.65),TIMBER)
			for i in 18:drum(Vector3(-1.4+(i%6)*.56,.5+(i/6)*.8,0),Vector3(.36,.52,.36),["b3b88c","c0a97b","cdbb94","9cae8f"][i%4])
		_:
			slab(Vector3.ZERO,Vector2(2.8,1.25));
			for i in 5:drum(Vector3(-.9+i*.45,1.1,0),Vector3(.25,.36,.25),["c4b394","9eb69f","b4b6c3"][i%3])
func record(id:String,parts:Array,origin_point:Vector3,size:Vector2):
	var entries:Dictionary=w.get_meta("design120",{});entries[id]={"id":id,"devices":parts,"origin":origin_point,"size":size,"schema":1};w.set_meta("design120",entries)
