extends RefCounted
## Designed modules, rooted against the same terrace data; no random prop carpet.
var w
var b
var origin:Vector3

func _init(world,home_origin:Vector3):w=world;b=w.b;origin=home_origin
func g(dx:float,dz:float,offset:float=0)->Vector3:return w.surface(origin.x+dx,origin.z+dz,offset)

func rock_group(p:Vector3,size:float,variant:int=0):
	var stones:=[[Vector3(-0.32,0.31,0),Vector3(0.98,0.62,0.78)],[Vector3(0.41,0.18,0.29),Vector3(0.65,0.36,0.61)],[Vector3(-0.05,0.12,-0.54),Vector3(0.51,0.24,0.35)]]
	for i in stones.size():b.box(p+stones[i][0]*size,stones[i][1]*size,["777f77","9b9f94","5d6e70"][posmod(i+variant,3)],false,0,"stone")
	b.box(p+Vector3(-0.37,0.632,0.05)*size,Vector3(0.60,0.035,0.43)*size,"74846a",false,0,"leaf")

func herb(p:Vector3,height:float,flower:bool=false):
	for j in 3:
		var q:Vector3=p+Vector3((j-1)*0.11,height/2,cos(j*2.1)*0.1)
		b.box(q,Vector3(0.065,height*(0.7+j*0.1),0.06),"76866a",false,0,"leaf")
		b.box(q+Vector3(0.08,height*0.06,0),Vector3(0.22,0.04,0.11),"89976a",false,0,"leaf")
		if flower:
			var top:Vector3=q+Vector3(0,height*0.45,0)
			for offset in [Vector3(0.1,0,0),Vector3(-0.1,0,0),Vector3(0,0,0.1),Vector3(0,0,-0.1)]:b.box(top+offset,Vector3(0.12,0.09,0.12),"d9bda9" if j%2 else "cbb0bf",false,0,"leaf")
			b.box(top+Vector3(0,0.02,0),Vector3(0.08,0.09,0.08),"d7c78f",false,0,"leaf")

func flower_border(dx:float,dz:float,width:float):
	# The foreground has low herbs, the middle flowers, and a taller muted shrub backdrop.
	var p:=g(dx,dz)
	for side in [-1,1]:
		for i in int(width/0.6):
			var q:Vector3=w.surface(p.x-width/2+0.3+i*0.6,p.z+side*0.92)
			b.box(q+Vector3(0,0.12,0),Vector3(0.57,0.24,0.19),"aaa18c",false,0,"stone")
	for i in int(width/0.75):
		var x:float=p.x-width/2+0.38+i*0.75
		var back:Vector3=w.surface(x,p.z-0.46)
		b.box(back+Vector3(0,0.37,0),Vector3(0.64,0.74,0.61),"6f8060",false,0,"leaf")
		b.box(back+Vector3(0.11,0.76,-0.04),Vector3(0.40,0.16,0.42),"89976a",false,0,"leaf")
		herb(w.surface(x+0.11,p.z+0.03),0.7,i%2==0)
		herb(w.surface(x-0.08,p.z+0.54),0.26,false)

func build():
	# G01 + G04: framed arrival planting grows from earth terraces beside the entrance.
	flower_border(-5.0,11.4,4.6);flower_border(5.0,11.4,4.6)
	# A real horizontal landing replaces the lower half of the old timber ramp.
	var arrival:=g(0,12.0,0.035)
	b.box(arrival-Vector3(0,0.10,0),Vector3(5.8,0.20,2.4),"c9c2ab",true,0,"stone")
	for x in [-2,-1,0,1,2]:b.box(arrival+Vector3(x,0.009,0),Vector3(0.025,0.012,2.3),"9b9b88")
	for side in [-1,1]:
		var front:=g(side*2.99,12.0)
		b.box(front+Vector3(0,0.12,0),Vector3(0.18,0.24,2.5),"989f8c",false,0,"stone")
	# G02: three asymmetrical stone/root scenes at the lower, middle and upper forest edge.
	for record in [[-17,-10,1.0],[-30,-28,1.4],[17,-18,0.9]]:
		var p:=g(record[0],record[1]);rock_group(p,record[2],int(record[0]))
		for j in 4:
			var q:=g(record[0]+0.7+j*0.42,record[1]+0.8+sin(j)*0.6)
			if w.clear_of_paths(Vector2(q.x,q.z),1.0):herb(q,0.25+j%2*0.22)
	# G05: a curved climb through protected cuttings, with one purposeful shade destination.
	var route:=[Vector2(-246,-174),Vector2(-256,-185),Vector2(-266,-201),Vector2(-278,-211)]
	for i in route.size()-1:w.path_between(route[i],route[i+1],2.4,"b7a887")
	for point in [Vector2(-258,-190),Vector2(-270,-203)]:
		var p:Vector3=w.surface(point.x,point.y)
		b.box(p+Vector3(0,0.35,0),Vector3(0.10,0.70,0.10),"5f5949");b.glow_box(p+Vector3(0,0.8,0),Vector3(0.24,0.22,0.24));b.box(p+Vector3(0,0.95,0),Vector3(0.37,0.06,0.37),"506c70")
	# Exposed stone footing along the raised forest saddle, with staggered short courses.
	var start:=Vector2(-256,-185);var finish:=Vector2(-266,-201)
	var axis:Vector2=(finish-start).normalized();var lateral:=Vector2(-axis.y,axis.x)
	for index in range(2,17):
		var center:Vector2=start+axis*float(index)
		for sign in [-1,1]:
			var point:Vector2=center+lateral*1.48*sign
			var top:Vector3=w.surface(point.x,point.y)
			var rise:float=w.terrain_art.garden_road_relief(point)
			for row in ceili(rise/0.28):
				b.box(top+Vector3(0,-0.15-row*0.28,0),Vector3(0.34,0.265,0.96),["647b80","82918a","929c90"][posmod(row+index,3)],false,atan2(axis.x,axis.y),"stone")
	# G03: the existing usable veranda remains the main rest room; this shady paving is a pocket.
	var rest:=g(-25,-18,0.035)
	for x in [-1,0,1]:
		for z in [-1,0,1]:
			var p:=g(-25+x,-18+z,0.035)
			b.box(p-Vector3(0,0.055,0),Vector3(0.96,0.11,0.96),"b8b49e",false,0,"stone")
	# G08: a small open sight frame points back to the qualified cottage, with a real local photo.
	var frame:=g(-25,-18)
	for side in [-1,1]:b.box(frame+Vector3(side*1.18,1.18,0),Vector3(0.17,2.36,0.19),"947255")
	b.box(frame+Vector3(0,2.37,0),Vector3(2.65,0.18,0.25),"786047")
	b.picture("res://assets/media/portrait_03.jpg",frame+Vector3(-1.07,1.33,0.13),0.55)
	b.text3d("海风与星光",frame+Vector3(-0.79,0.77,0.15),0.0026,"e4dfcf")
	# G07: the retained low perimeter now has an actual open gate to the back path.
	for side in [-1,1]:
		var p:=g(-9.0+side*0.88,-5.0)
		b.box(p+Vector3(0,0.49,0),Vector3(0.20,0.98,0.20),"947255")
		b.box(p+Vector3(0,1.01,0),Vector3(0.29,0.07,0.29),"786047")
	w.set_meta("environment_garden_modules",["G01","G02","G03","G04","G05","G07","G08"])
