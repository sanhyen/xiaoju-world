extends RefCounted
## Import progress by stable venue identity without writing the 095b source save.
static func migrate(source:Dictionary,world)->Dictionary:
	var result:Dictionary=source.duplicate(true)
	if str(result.get("world_revision",""))=="bay_v2":return result
	if str(result.get("world_revision",""))=="bay_v1":
		result["world_revision"]="bay_v2";result["migration_0100"]={"source_world":"bay_v1","at":Time.get_datetime_string_from_system()};return result
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_095_bay_v1.json"))
	var p:Array=result.get("position",[260,1,193])
	var old:=Vector3(float(p[0]),float(p[1]),float(p[2]))
	var desired:Vector3=map_point(old,str(result.get("interior","")),legacy,world)
	result.position=[desired.x,desired.y,desired.z]
	var safe:Array=result.get("safe_point",p)
	var recovery:Vector3=map_point(Vector3(float(safe[0]),float(safe[1]),float(safe[2])),"",legacy,world)
	result.safe_point=[recovery.x,recovery.y,recovery.z]
	result["world_revision"]="bay_v2"
	result["migration"]={"source_world":"095b","source_game_version":str(result.get("game_version","unknown")),"at":Time.get_datetime_string_from_system(),"source_position":p.duplicate(),"source_interior":str(result.get("interior",""))}
	var index:int=int(result.get("home_photo",0))
	if index>=0 and index<legacy.legacy_asset_order.size():result["home_photo_id"]=legacy.legacy_asset_order[index]
	for key in ["inventory","activities","handheld","playlist","mix_recipe","itinerary"]:
		if not result.has(key):result[key]=[] if key in ["playlist","itinerary"] else "natural" if key=="handheld" else {}
	return result

static func map_point(p:Vector3,interior:String,legacy:Dictionary,world)->Vector3:
	var venue:String=interior
	if venue.is_empty():
		for item in legacy.buildings:
			if absf(p.x-float(item.x))<float(item.w)*0.5 and absf(p.z-float(item.z))<float(item.d)*0.5 and p.y>=float(item.y)-0.6 and p.y<float(item.y)+float(item.h)+1.0:
				venue=str(item.id);break
	if not venue.is_empty() and world.layout.venues.has(venue):
		for item in legacy.buildings:
			if str(item.id)!=venue:continue
			var target:Dictionary=world.layout.venues[venue]
			var local:=Vector3(p.x-float(item.x),p.y-float(item.y),p.z-float(item.z))
			var floor_y:float=3.8 if venue=="B02" and local.y>2.8 else 0.0
			return Vector3(float(target.x)+clampf(local.x,-float(target.w)*0.5+1.0,float(target.w)*0.5-1.0),float(target.floor_y)+floor_y+0.35,float(target.z)+clampf(local.z,-float(target.d)*0.5+1.0,float(target.d)*0.5-1.0))
	var zone:String="Z08" if p.z< -225.0 else ""
	if zone.is_empty():
		var distance:float=INF
		for item in legacy.zones:
			var d:float=Vector2(p.x-float(item.x),p.z-float(item.z)).length_squared()
			if d<distance:distance=d;zone=str(item.id)
	return world.layout.safe_point(zone)
