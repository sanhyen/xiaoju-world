extends RefCounted
## Shared deep construction modules, assembled differently for every venue.
var c
var b
var o:Vector3
var w:float
var d:float
var h:float
var trim:="5e4232"
var roof:="4a5d6b"

func init(ctx):
	c=ctx;b=c.b;o=c.origin;w=c.w;d=c.d;h=c.h
	if c.item.id=="B03":
		h=maxf(h,7.2);c.h=h
		for bound in c.world.building_bounds:
			if bound.id=="B03":bound.h=h
	trim={"B01":"57746f","B04":"6d8876","B05":"718a82","B09":"665950"}.get(c.item.id,"5e4232")
	roof={"B02":"b86b4b","B03":"4a5d6b","B04":"718d7e","B07":"91674c","B11":"b86b4b"}.get(c.item.id,"4a5d6b")

func box(p:Vector3,s:Vector3,tone:String,solid:bool=false,kind:String=""):
	b.box(o+p,s,tone,solid,0,kind)

func shell(ctx):
	init(ctx)
	load("res://scripts/architecture120.gd").new(c.world).public_shell(c)

func window(p:Vector3,size:Vector2,side:bool):
	b.glass(o+p-Vector3(0,0,.16),Vector3(size.x,size.y,0.04))
	b.collision(o+p,Vector3(size.x,size.y,0.18))
	for x in [-size.x*0.5,0,size.x*0.5]:box(p+Vector3(x,0,0.14),Vector3(0.14,size.y+0.2,0.5),trim,false,"wood")
	for y in [-size.y*0.5,size.y*0.5]:box(p+Vector3(0,y,0.12),Vector3(size.x+0.25,0.14,0.65),trim,false,"wood")

func sofa(p:Vector3,angle:float=0):
	var basis:=Basis(Vector3.UP,angle)
	for part in [[Vector3(0,0.26,0),Vector3(2.15,0.5,0.85),"846c53"],[Vector3(0,0.55,-0.02),Vector3(2.0,0.22,0.76),"b3b28f"],[Vector3(0,0.92,0.3),Vector3(2.1,0.8,0.22),"9da584"],[Vector3(-1.03,0.66,0),Vector3(0.16,0.55,0.9),"846c53"],[Vector3(1.03,0.66,0),Vector3(0.16,0.55,0.9),"846c53"]]:
		b.oriented_box(p+basis*part[0],part[1],part[2],basis,false,"fabric")
	b.collision(p+Vector3(0,0.36,0),Vector3(2.2,0.72,0.9),angle)

func terrace(level:float=4):
	var z:float=d*0.5+4
	box(Vector3(0,level-0.14,z),Vector3(w+1,0.28,5.5),"aa906c",true,"wood")
	for x in [-w*0.5,w*0.5]:
		for zz in [z-2.5,z+2.5]:box(Vector3(x,level*0.5-0.15,zz),Vector3(0.38,level,0.38),trim,true,"wood")
		if x<0:box(Vector3(x,level+0.6,z),Vector3(0.18,1.2,5.5),trim,true,"wood")
		else:
			for side in [-1,1]:box(Vector3(x,level+.6,z+side*2.1),Vector3(.18,1.2,1.3),trim,true,"wood")
	for x in range(-int(w*0.5),int(w*0.5)+1,2):box(Vector3(x,level+0.55,z+2.6),Vector3(0.13,1.1,0.13),trim,true,"wood")
	preload("res://scripts/bay_finishings.gd").new(c.world).rail(o+Vector3(-w*.5,level,z+2.6),o+Vector3(w*.5,level,z+2.6))
	var a:Vector3=o+Vector3(w*0.5+3.3,0.1,z+22)
	var end:Vector3=o+Vector3(w*0.5+3.3,level,z)
	b.ramp(a,end,2.6,"baab8b")
	box(Vector3(w*0.5+1.7,level-0.14,z),Vector3(3.6,0.28,2.8),"aa906c",true,"wood")
	var guards=preload("res://scripts/bay_guardrails.gd").new(c.world)
	guards.pad(o+Vector3(0,level,z),Vector2(w+1,5.5))
	guards.pad(o+Vector3(w*.5+1.7,level,z),Vector2(3.6,2.8))
	guards.span(a,end,2.6)
	guards.build("venue_terrace_"+c.item.id,true)
	load("res://scripts/architecture120.gd").new(c.world).upper_route(c.item.id+"_TERRACE",c.item.id,[a,end,o+Vector3(w*.5+1.7,level,z),o+Vector3(w*.5-.5,level,z)],[{"center":o+Vector3(0,level,z),"size":Vector2(w+1,5.5),"y":o.y+level},{"center":o+Vector3(w*.5+1.7,level,z),"size":Vector2(3.6,2.8),"y":o.y+level}])
	for x in [-w*0.3]:
		b.table(o+Vector3(x,level,z),1.6);sofa(o+Vector3(x,level,z+1.2),PI)
	c.action("bay_terrace",Vector3(-w*0.3,level,z),"二层试听露台 · 落座","sit",{"seat":o+Vector3(-w*0.3,level,z+1.2),"yaw":PI})

func interior(ctx):
	init(ctx)
	match c.item.id:
		"B01":
			# The accessible clock tower is integrated into the retained east B01_UPPER wing.
			box(Vector3(0,h-.6,-d*.32),Vector3(w*.72,.35,.35),"748f84",false,"wood")
		"B02":
			box(Vector3(-7,0.6,-1.4),Vector3(1.2,1.2,3.8),"947359",true,"wood")
			for x in range(-7,3):box(Vector3(x,2.0,-5.9),Vector3(0.12,3.8,0.14),trim,false,"wood")
		"B03","B11":terrace()
		"B04":
			for zz in [-1,2,5]:
				var p:Vector3=c.world.surface(o.x-11,o.z+zz*1.8)
				b.planter(p,3,["cbb0ce","edcea3","b9c49a"][posmod(zz+1,3)])
			for x in [-3.5,0,3.5]:box(Vector3(x,1.6,-4.1),Vector3(2.7,0.14,1),trim,false,"wood")
		"B05":
			var court:Vector3=c.world.surface(o.x-w*0.5-7,o.z)
			b.box(court,Vector3(10,0.18,15),"e2d5c1",true)
			preload("res://scripts/vegetation_art.gd").new().tree(b,court+Vector3(-1,0,-1),3,.85)
			for z in [-6,6]:b.bench(court+Vector3(0,0,z))
			gallery_wing()
		"B06":
			var p:Vector3=c.world.surface(o.x-21,o.z+4)
			b.box(p+Vector3(0,3.4,0),Vector3(10,6,0.35),"ded9c4",true)
			var mi:=MeshInstance3D.new();var q:=QuadMesh.new();q.size=Vector2(9,5.0625);mi.mesh=q;mi.material_override=b.material("263b3c");mi.position=p+Vector3(0,3.4,0.21);mi.set_meta("stream_ref","screen:B06_OUT");c.world.add_child(mi);c.world.screens.B06_OUT=mi
			for x in [-3,3]:sofa(p+Vector3(x,0,8))
		"B07":
			for side in [-1,1]:
				sofa(o+Vector3(side*9,0,1),side*PI*0.5)
				box(Vector3(side*10,3.4,-5),Vector3(2,0.18,7),"aa906c",false,"wood")
		"B08":
			for x in [-5,-2,1,4]:box(Vector3(x,0.022,0),Vector3(0.45,0.025,0.45),"bcb788")
			for x in [-5,-2,1,4]:box(Vector3(x,5.1,5.5),Vector3(2.5,0.14,2.3),"aa906c",false,"wood")
		"B09":
			b.picture("res://assets/media/bay_life/life_04.jpg",o+Vector3(5.6,2.5,-5.85),1.1)
			for x in range(-7,8):box(Vector3(x*0.8,2.6,-6.2),Vector3(0.12,4.6,0.22),trim,false,"wood")
			b.glass(o+Vector3(3.2,2,-1.5),Vector3(3.8,2.5,0.03))
		"B10":
			for level in 3:box(Vector3(0,0.3+level*0.35,-9.5-level),Vector3(24-level*2,0.2,2),"aa906c",false,"wood")
			for side in [-1,1]:box(Vector3(side*14,3.7,-9),Vector3(1.2,7,6),"766273",false,"fabric")
		"B12":
			# Home keeps every legacy display and gains a dedicated crafted-object ledge.
			box(Vector3(4,1.0,1.0),Vector3(2.2,0.16,0.7),trim,true,"wood")
		"B13":
			b.table(o+Vector3(-4,0,0),3)
			box(Vector3(-4,1.04,0),Vector3(2.7,0.06,1.5),"ded5bb")
			c.label("山 海 行 程",Vector3(-4,2.9,-4.2),0.009,"48675d")

	load("res://scripts/architecture120.gd").new(c.world).main_details(c)

func gallery_wing():
	var center:=Vector3(-16,-.03,-4.5)
	box(center,Vector3(10,.26,7),"e2d5c1",true,"stone")
	box(Vector3(-21,2.9,-4.5),Vector3(.4,5.8,7),"f4efe6",true,"plaster")
	box(Vector3(-16,2.9,-8),Vector3(10,5.8,.4),"f4efe6",true,"plaster")
	for side in [-1,1]:box(Vector3(-16+side*3.35,1.65,-1),Vector3(3.3,3.3,.4),"f4efe6",true,"plaster")
	box(Vector3(-16,5.8,-4.5),Vector3(11,.35,8),"4a5d6b",true,"slate")
	box(Vector3(-16,4.55,-1),Vector3(10,2.5,.4),"f4efe6",true,"plaster")
	for i in 3:box(Vector3(-19+i*3,2.5,-7.76),Vector3(1.7,2.1,.08),["d1b7ac","a2bab2","c9bd9b"][i])
	b.bench(o+Vector3(-18,0,-3))
	c.world.path_between(Vector2(o.x-16,o.z-1),Vector2(o.x-16,o.z+5),2.5,"e2d5c1")
	for bound in c.world.building_bounds:
		if bound.id=="B05":bound["extra_bounds"]=[{"x":o.x-16,"z":o.z-4.5,"w":10,"d":7,"y":o.y,"h":5.8}]
