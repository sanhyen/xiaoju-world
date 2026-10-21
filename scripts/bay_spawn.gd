extends RefCounted
## Resolve against loaded floors, preferring the requested level and nearby shallow exits.
static func resolve(w,desired:Vector3)->Vector3:
	var start:Vector3=desired
	if not w.layout.within_bounds(start):start=w.layout.safe_point(w.layout.zone_id(start))
	var sea:float=w.layout.config.sea_y
	if not w.layout.shallow_or_dry(start) and not w.within_pier(start) and sea-w.height_at(start.x,start.z)>1.35:
		var nearby:Vector3=Vector3.INF
		for radius in [1.5,3.0,5.0,8.0,12.0,17.0]:
			for i in 32:
				var a:float=i*TAU/32;var p:Vector3=start+Vector3(cos(a)*radius,0,sin(a)*radius);var h:float=w.height_at(p.x,p.z)
				if sea-h<=1.30 and w.layout.within_bounds(p):nearby=Vector3(p.x,h+.2,p.z);break
			if nearby.is_finite():break
		start=nearby if nearby.is_finite() else w.layout.safe_point(w.layout.zone_id(start))
	var space:PhysicsDirectSpaceState3D=w.get_world_3d().direct_space_state
	var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.65
	var offsets:Array=[Vector2.ZERO,Vector2(1.2,0),Vector2(-1.2,0),Vector2(0,1.2),Vector2(0,-1.2),Vector2(2.5,2.5),Vector2(-2.5,2.5)]
	var excluded:Array[RID]=[]
	for node in w.get_parent().get_children():
		if node is CharacterBody3D:excluded.append(node.get_rid())
	var result:Vector3=Vector3.INF;var score:float=INF
	for offset in offsets:
		var p:Vector3=start+Vector3(offset.x,0,offset.y)
		var query:=PhysicsRayQueryParameters3D.create(p+Vector3(0,1,0),p-Vector3(0,8,0),1,excluded);var hit:Dictionary=space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y<.65:continue
		p.y=hit.position.y+.08
		if not w.layout.shallow_or_dry(p) and sea-w.height_at(p.x,p.z)>1.35:continue
		var overlap:=PhysicsShapeQueryParameters3D.new();overlap.shape=capsule;overlap.exclude=excluded;overlap.transform=Transform3D(Basis.IDENTITY,p+Vector3(0,.9,0));overlap.collision_mask=1
		if not space.intersect_shape(overlap,1).is_empty():continue
		var distance:float=absf(p.y-start.y)*4+offset.length()
		if distance<score:score=distance;result=p
	if result.is_finite():return result
	var venue:String=w.inside_building(start)
	if not venue.is_empty() and w.layout.venues.has(venue):
		var item:Dictionary=w.layout.venues[venue];return Vector3(item.x,item.floor_y+.35,item.z+item.d*.5+1.4)
	var nearest:Vector3=w.layout.nearest_route(start)
	return Vector3(nearest.x,maxf(nearest.y,w.height_at(nearest.x,nearest.z))+.35,nearest.z)
