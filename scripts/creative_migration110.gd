extends RefCounted
## Stable room identities move first; loaded physics resolves a same-room landing afterwards.
static func migrate(state:Dictionary,world)->Dictionary:
	var info:Dictionary=state.get("migration110",{}).duplicate(true)
	var already:bool=info.get("locations",false)
	if already and info.get("safe_locations",false):return state
	var changes:Array=info.get("changes",[])
	for field in ["position","safe_point"]:
		if field=="position" and already:continue
		var saved:Array=state.get(field,state.get("position",[289,4,248]))
		var old:=Vector3(saved[0],saved[1],saved[2])
		for place in world.layout.creative_places:
			if not place.has("legacy_center"):continue
			var c:Array=place.legacy_center;var size:Array=place.legacy_size
			var base:=Vector3(c[0],float(c[1])+float(world.layout.config.sea_y),c[2])
			var belongs:bool=field=="position" and str(state.get("interior",""))==str(place.id)
			belongs=belongs or (absf(old.x-base.x)<size[0]*.5-.25 and absf(old.z-base.z)<size[1]*.5-.25 and old.y>=base.y-.6 and old.y<base.y+11.0)
			if not belongs:continue
			var local:Vector3=old-base
			var local_size:=Vector2(place.size[0],place.size[1])
			if absf(sin(float(place.door_yaw)))>.5:local_size=Vector2(local_size.y,local_size.x)
			var clipped:=Vector3(clampf(local.x,-local_size.x*.5+.8,local_size.x*.5-.8),local.y,clampf(local.z,-local_size.y*.5+.8,local_size.y*.5-.8))
			var desired:=Vector3(place.center[0],place.center[1],place.center[2])+Basis(Vector3.UP,float(place.door_yaw))*clipped
			state[field]=[desired.x,desired.y,desired.z]
			if field=="position":state.yaw=float(state.get("yaw",0))+float(place.door_yaw);info.position_place=place.id
			changes.append({"field":field,"place":place.id,"from":saved.duplicate(),"to":state[field].duplicate(),"local_preserved":local.distance_to(clipped)<.01});break
	info.merge({"schema":2,"locations":true,"safe_locations":true,"changes":changes,"at":Time.get_datetime_string_from_system(),"source_game_version":state.get("game_version","")},true)
	state.migration110=info
	return state

static func within_place(point:Vector3,place:Dictionary)->bool:
	return absf(point.x-place.center[0])<place.size[0]*.5-.42 and absf(point.z-place.center[2])<place.size[1]*.5-.42

static func supported(world,point:Vector3,place:Dictionary)->Vector3:
	if not within_place(point,place):return Vector3.INF
	var excluded:Array[RID]=[]
	for node in world.get_parent().get_children():
		if node is CharacterBody3D:excluded.append(node.get_rid())
	var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.75,point-Vector3.UP*.75,1,excluded)
	var hit:Dictionary=space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<.72:return Vector3.INF
	var result:=Vector3(point.x,hit.position.y+.08,point.z)
	var capsule:=CapsuleShape3D.new();capsule.radius=.36;capsule.height=1.65
	var overlap:=PhysicsShapeQueryParameters3D.new();overlap.shape=capsule;overlap.exclude=excluded;overlap.collision_mask=1
	overlap.transform=Transform3D(Basis.IDENTITY,result+Vector3.UP*.9)
	if not space.intersect_shape(overlap,1).is_empty():return Vector3.INF
	return result

static func resolve_after_stream(state:Dictionary,world,desired:Vector3)->Vector3:
	var info:Dictionary=state.get("migration110",{})
	var owner:String=str(info.get("position_place",""))
	if owner.is_empty() or info.get("position_resolved",false):return world.safe_ground_position(desired)
	var place:Dictionary={}
	for candidate in world.layout.creative_places:
		if str(candidate.id)==owner:place=candidate;break
	if place.is_empty():return world.safe_ground_position(desired)
	var result:Vector3=supported(world,desired,place)
	var nearest_y:float=place.floors[0]
	for y in place.floors:
		if absf(float(y)-desired.y)<absf(nearest_y-desired.y):nearest_y=float(y)
	if not result.is_finite():
		for radius in [.75,1.5,2.5,4.0,6.0,8.0]:
			for i in 24:
				var a:float=i*TAU/24
				result=supported(world,Vector3(desired.x+cos(a)*radius,nearest_y+.08,desired.z+sin(a)*radius),place)
				if result.is_finite():break
			if result.is_finite():break
	if not result.is_finite():
		var entries:Array=place.get("floor_entries",[]).duplicate(true)
		entries.sort_custom(func(a,b):return absf(float(a.point[1])-desired.y)<absf(float(b.point[1])-desired.y))
		for entry in entries:
			var p:Array=entry.point;result=supported(world,Vector3(p[0],p[1],p[2]),place)
			if result.is_finite():break
	if not result.is_finite():
		var door:Array=place.door;result=world.safe_ground_position(Vector3(door[0],door[1],door[2]))
	if result.distance_to(desired)>.12:
		info.changes.append({"field":"position","place":owner,"reason":"nearest_valid_surface_in_same_place","from":[desired.x,desired.y,desired.z],"to":[result.x,result.y,result.z]})
	info.position_resolved=true;state.migration110=info
	return result
