extends RefCounted
## Retained road geometry; shared paving and slim continuous garden/narrow-route edges.
var w
var records:Array=[]
var curb_count:=0
var opening_count:=0
var corridor_buckets:Dictionary={}
const BUCKET_SIZE=32.0

func _init(target):w=target

func register(mesh:MeshInstance3D,a:Vector2,c:Vector2,width:float,color:String,is_garden:bool=false,divisions:int=0):
	var axis:=Vector2(0.0,1.0) # One physical grid prevents conflicting courses at junctions.
	var material:=ShaderMaterial.new()
	material.shader=load("res://assets/materials/path_paving_079.gdshader")
	material.set_shader_parameter("path_axis",axis)
	material.set_shader_parameter("seam_strength",0.12 if is_garden else 0.16)
	mesh.material_override=material
	records.append({"a":a,"c":c,"width":width,"color":color,"corridor":w.path_corridors.size()-1,"local_garden":is_garden,"divisions":divisions})

func index_corridors():
	# Exact same junction-distance predicate, with a spatial lookup during construction.
	for index in w.path_corridors.size():
		var corridor:Dictionary=w.path_corridors[index]
		var a:Vector2=corridor.a;var c:Vector2=corridor.c
		var pad:float=float(corridor.width)/2.0+0.4
		for x in range(floori((minf(a.x,c.x)-pad)/BUCKET_SIZE),floori((maxf(a.x,c.x)+pad)/BUCKET_SIZE)+1):
			for z in range(floori((minf(a.y,c.y)-pad)/BUCKET_SIZE),floori((maxf(a.y,c.y)+pad)/BUCKET_SIZE)+1):
				var key:=Vector2i(x,z)
				if not corridor_buckets.has(key):corridor_buckets[key]=[]
				corridor_buckets[key].append(index)

func opening(p:Vector2,own_index:int)->bool:
	var key:=Vector2i(floori(p.x/BUCKET_SIZE),floori(p.y/BUCKET_SIZE))
	for index in corridor_buckets.get(key,[]):
		if index==own_index:continue
		var other:Dictionary=w.path_corridors[index]
		var nearest:Vector2=Geometry2D.get_closest_point_to_segment(p,other.a,other.c)
		if p.distance_to(nearest)<float(other.width)/2.0+0.4:return true
	return false

func ground_point(record:Dictionary,t:float,sign:int)->Vector3:
	# Match the actual unchanged paving triangles, rather than a fresh ground
	# query between their original vertices, which can leave small floating edges.
	var a:Vector2=record.a;var c:Vector2=record.c
	var divisions:int=int(record.divisions) if int(record.get("divisions",0))>0 else maxi(1,ceili(a.distance_to(c)/4.0))
	var section:int=mini(floori(t*divisions),divisions-1)
	var along:float=t*divisions-section
	var axis:Vector2=(c-a).normalized()
	var side:Vector2=Vector2(-axis.y,axis.x)*float(record.width)/2.0
	var p:Vector2=a.lerp(c,float(section)/divisions)
	var q:Vector2=a.lerp(c,float(section+1)/divisions)
	var v0:Vector3=w.surface((p+side).x,(p+side).y,0.035)
	var v1:Vector3=w.surface((p-side).x,(p-side).y,0.035)
	var v2:Vector3=w.surface((q-side).x,(q-side).y,0.035)
	var v3:Vector3=w.surface((q+side).x,(q+side).y,0.035)
	var inset:float=0.07 if record.get("local_garden",false) else 0.10
	var across:float=inset/float(record.width) if sign>0 else 1.0-inset/float(record.width)
	var height:float=v0.y*(1.0-across)+v1.y*(across-along)+v2.y*along if across>=along else v0.y*(1.0-along)+v2.y*across+v3.y*(along-across)
	var point:Vector2=a.lerp(c,t)+side.normalized()*(float(record.width)/2.0-inset)*sign
	return Vector3(point.x,height+(0.05 if record.get("local_garden",false) else 0.07),point.y)

func build():
	index_corridors()
	var garden_routes:=0
	var narrow_routes:=0
	for record in records:
		if record.get("local_garden",false):garden_routes+=1
		elif float(record.width)<4.0:narrow_routes+=1
		var a:Vector2=record.a;var c:Vector2=record.c
		var length:float=a.distance_to(c)
		if length<5.0:continue
		var direction:Vector2=(c-a).normalized()
		var inset:float=0.07 if record.get("local_garden",false) else 0.10
		var side:Vector2=Vector2(-direction.y,direction.x)*(float(record.width)/2.0-inset)
		var divisions:int=maxi(1,ceili(length/1.45))
		for index in divisions:
			var t0:float=float(index)/divisions;var t1:float=float(index+1)/divisions
			# End turns stay open; other registered approaches and crossings get gaps.
			if t0*length<1.8 or (1.0-t1)*length<1.8:continue
			for sign in [-1,1]:
				var p:Vector2=a.lerp(c,t0)+side*sign
				var q:Vector2=a.lerp(c,t1)+side*sign
				if opening(p,int(record.corridor)) or opening(q,int(record.corridor)):
					opening_count+=1;continue
				var start:Vector3=ground_point(record,t0,sign)
				var end:Vector3=ground_point(record,t1,sign)
				var forward:Vector3=(end-start).normalized()
				var right:Vector3=Vector3.UP.cross(forward).normalized()
				var up:Vector3=forward.cross(right).normalized()
				var garden:bool=record.get("local_garden",false)
				var tone:String="b7ad95" if garden else ("c3bba6" if record.color=="c7bda4" else "b7af9a")
				w.b.oriented_box((start+end)/2.0,Vector3(0.18 if garden else 0.25,0.10 if garden else 0.14,start.distance_to(end)-0.015),tone,Basis(right,up,forward),false,"stone")
				curb_count+=1
	return {"paved_routes":records.size(),"garden_paved_routes":garden_routes,"narrow_paved_routes":narrow_routes,"garden_curb_width_m":0.18,"garden_curb_height_m":0.10,"curb_segments":curb_count,"junction_segments_omitted":opening_count,"colliders_added":0,"paving_grid":"shared world XZ grid from081","scope":"Retained road mesh and collision; additive visual material and curb geometry only"}
