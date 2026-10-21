extends SceneTree
## Read-only physical seam measurement over the final baked geometry.
const World=preload("res://scripts/world.gd")
class ProbeHost:
	extends Node3D
	var bay=null
func _initialize():run.call_deferred()
func run():
	var host:=ProbeHost.new();root.add_child(host)
	var world:=Node3D.new();world.set_script(World);world.phase="streamed";host.add_child(world);await physics_frame
	var measurements:Array=[];var invalid:Array=[];var maximum:=0.0
	for place in world.layout.creative_places:
		var door:=Vector3(place.door[0],place.door[1],place.door[2]);var heights:Array=[]
		world.streamer.set_foci([door])
		if not await world.prepare_region(door,16):invalid.append({"id":place.id,"reason":"region not ready"});continue
		await physics_frame
		var forward:Vector3=Basis(Vector3.UP,float(place.door_yaw))*Vector3.BACK
		for side in [-1,1]:
			var point:Vector3=door+forward*.05*side
			var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.4,point-Vector3.UP*.8,1)
			var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y<.7:invalid.append({"id":place.id,"side":side,"reason":"no horizontal threshold surface","point":point,"hit":hit.get("position",Vector3.INF),"normal":hit.get("normal",Vector3.ZERO),"collider":str(hit.get("collider","none"))})
			else:heights.append(hit.position.y)
		if heights.size()==2:
			var gap:float=absf(float(heights[0])-float(heights[1]));maximum=maxf(maximum,gap)
			measurements.append({"id":place.id,"heights":heights,"gap_m":gap})
			if gap>.0405:invalid.append({"id":place.id,"gap_m":gap})
	var file:=FileAccess.open("res://reports/design120_portals.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":invalid.is_empty() and measurements.size()==83,"measurements":measurements,"failures":invalid,"maximum_gap_m":maximum,"scope":"Actual static physics rays 0.05 m inside and outside each portal over final baked geometry. Not a replacement for the graphical route or ordinary-input checks."},"\t"));file.close()
	print("DESIGN120_PORTALS ",JSON.stringify({"measured":measurements.size(),"failed":invalid.size(),"maximum_gap_m":maximum}));quit(0 if invalid.is_empty() and measurements.size()==83 else 1)
