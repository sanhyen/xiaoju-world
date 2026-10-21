extends RefCounted
## Retaining skin follows existing exposed terrain faces; all terrain heights/collision stay intact.
var terrain_ref:WeakRef
var terrain:
	get:return terrain_ref.get_ref()
var faces:=0
var coping:=0
var drains:=0

func _init(target):terrain_ref=weakref(target)

func classify(a:Vector3,c:Vector3,low_a:float,low_c:float,region:String)->bool:
	var point:Vector3=(a+c)/2.0
	if point.z> -160.0 or point.y<5.0 or region=="river":return false
	if maxf(a.y-low_a,c.y-low_c)<0.65:return false
	return terrain.road_clearance(Vector2(point.x,point.z))<3.0

func dress(a:Vector3,c:Vector3,low_a:float,low_c:float,normal:Vector3,far:bool):
	if far:return
	faces+=1
	# Coping only crowns a real horizontal ledge, never spans a slope or creates a new barrier.
	var selector:=posmod(roundi(a.x/2)*7+roundi(a.z/2)*5,4)
	if absf(a.y-c.y)<0.025 and selector==0:
		var forward:Vector3=(c-a).normalized()
		var right:Vector3=Vector3.UP.cross(forward).normalized()
		terrain.w.b.oriented_box((a+c)/2+normal*0.025+Vector3(0,0.025,0),Vector3(0.14,0.10,maxf(0.02,a.distance_to(c)-0.015)),"999e8d",Basis(right,Vector3.UP,forward),false,"stone")
		coping+=1
	if selector==1:
		var point:Vector3=(a+c)/2
		point.y-=minf(0.25,maxf(a.y-low_a,c.y-low_c)*0.30)
		var right:Vector3=Vector3.UP.cross(normal).normalized()
		terrain.w.b.oriented_box(point+normal*0.024,Vector3(0.16,0.09,0.028),"637064",Basis(right,Vector3.UP,normal),false,"stone")
		drains+=1

func summary()->Dictionary:
	return {"exposed_retaining_faces":faces,"rooted_coping_modules":coping,"drain_markers":drains,"colliders_added":0,"terrain_height_changes":false,"scope":"Skin of actual pre-existing cut faces near mountain paths; natural cliffs, river/waterfall and protected roads retained"}
