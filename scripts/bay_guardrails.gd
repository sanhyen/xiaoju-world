extends RefCounted
## Rails follow the exposed boundary of the union of real walking surfaces.
var w
var floors:Array=[]
var openings:Array=[]
var records:Array=[]
var surface_index:Dictionary={}
const INDEX_CELL=16.0
func _init(world):w=world

func span(a:Vector3,c:Vector3,width:float,guard:bool=true):
	if Vector2(a.x-c.x,a.z-c.z).length()<.02:return
	var d:=Vector3(c.x-a.x,0,c.z-a.z).normalized();var side:=Vector3(-d.z,0,d.x)*width*.5
	var polygon:=PackedVector2Array()
	for p in [a-side-d*.12,c-side+d*.12,c+side+d*.12,a+side-d*.12]:polygon.append(Vector2(p.x,p.z))
	floors.append({"polygon":polygon,"a":a,"c":c,"guard":guard,"bounds":bounds(polygon)})

func pad(p:Vector3,size:Vector2,guard:bool=true):
	var polygon:=PackedVector2Array([Vector2(p.x-size.x*.5,p.z-size.y*.5),Vector2(p.x+size.x*.5,p.z-size.y*.5),Vector2(p.x+size.x*.5,p.z+size.y*.5),Vector2(p.x-size.x*.5,p.z+size.y*.5)])
	floors.append({"polygon":polygon,"a":p,"c":p,"guard":guard,"bounds":bounds(polygon)})

func octagon(p:Vector3,radius:float,guard:bool=true):
	var polygon:=PackedVector2Array()
	for i in 8:polygon.append(Vector2(p.x+sin(i*TAU/8)*radius,p.z+cos(i*TAU/8)*radius))
	# Geometry2D orientation is normalized so every outward test has the same meaning.
	if Geometry2D.is_polygon_clockwise(polygon):polygon.reverse()
	floors.append({"polygon":polygon,"a":p,"c":p,"guard":guard,"bounds":bounds(polygon)})

func bounds(polygon:PackedVector2Array)->Rect2:
	var result:=Rect2(polygon[0],Vector2.ZERO)
	for p in polygon:result=result.expand(p)
	return result.grow(.04)

func height(f:Dictionary,p:Vector2)->float:
	var a:=Vector2(f.a.x,f.a.z);var c:=Vector2(f.c.x,f.c.z)
	var t:float=clampf((p-a).dot(c-a)/maxf(.001,a.distance_squared_to(c)),0,1)
	return lerpf(f.a.y,f.c.y,t)

func portal(p:Vector3,size:Vector2,low:float=0,high:float=1):
	openings.append({"rect":Rect2(Vector2(p.x,p.z)-size*.5,size),"low":p.y+low,"high":p.y+high})

func supported(p:Vector2,y:float,skip:int,ground:bool)->bool:
	for opening in openings:
		if opening.rect.has_point(p) and y>=float(opening.low)-.1 and y<=float(opening.high)+.1:return true
	for i in surface_index.get(Vector2i(floori(p.x/INDEX_CELL),floori(p.y/INDEX_CELL)),[]):
		if i==skip:continue
		var f:Dictionary=floors[i]
		if f.bounds.has_point(p) and absf(height(f,p)-y)<.42 and Geometry2D.is_point_in_polygon(p,f.polygon):return true
	if ground and absf(w.height_at(p.x,p.y)-y)<.24:return true
	return false

func build(tag:String,ground:bool=false):
	surface_index.clear()
	for index in floors.size():
		var box:Rect2=floors[index].bounds.grow(.5)
		for x in range(floori(box.position.x/INDEX_CELL),floori(box.end.x/INDEX_CELL)+1):
			for z in range(floori(box.position.y/INDEX_CELL),floori(box.end.y/INDEX_CELL)+1):
				var key:=Vector2i(x,z)
				if not surface_index.has(key):surface_index[key]=[]
				surface_index[key].append(index)
	for index in floors.size():
		var f:Dictionary=floors[index]
		if not f.guard:continue
		var polygon:PackedVector2Array=f.polygon
		var clockwise:bool=Geometry2D.is_polygon_clockwise(polygon)
		for i in polygon.size():
			var a:Vector2=polygon[i];var c:Vector2=polygon[(i+1)%polygon.size()];var along:Vector2=(c-a).normalized();var outward:=Vector2(along.y,-along.x)*(-1 if clockwise else 1)
			var count:int=maxi(1,ceili(a.distance_to(c)/.28));var begin:=-1
			for j in count+1:
				var expose:=false
				if j<count:
					var mid:Vector2=a.lerp(c,(float(j)+.5)/count)
					expose=not supported(mid+outward*.23,height(f,mid),index,ground)
				if expose and begin<0:begin=j
				if not expose and begin>=0:
					var start:Vector2=a.lerp(c,float(begin)/count);var end:Vector2=a.lerp(c,float(j)/count)
					var u:=Vector3(start.x,height(f,start),start.y);var v:=Vector3(end.x,height(f,end),end.y)
					if u.distance_to(v)>.1:
						load("res://scripts/bay_finishings.gd").new(w).rail(u,v)
						records.append({"a":u,"c":v,"tag":tag})
					begin=-1
	var all:Array=w.get_meta("guardrails106",[]);all.append({"tag":tag,"surfaces":floors.size(),"rails":records.duplicate(true)});w.set_meta("guardrails106",all)
