extends RefCounted
## Baked geometry supplies the final routes and floor entries for every consumer.
static func xyz(value:Variant)->Array:
	if value is Vector3:return [value.x,value.y,value.z]
	return value if value is Array else []

static func apply(world,counts:Dictionary):
	var records:Variant=counts.get("architecture110",[])
	if not records is Array:records=[]
	world.set_meta("architecture110",records)
	world.set_meta("creative110",counts.get("creative110",{}))
	var entrances:Array=counts.get("entrances110",[]).duplicate(true);var routes:Array=counts.get("upper_routes110",[]).duplicate(true)
	for record in records:
		for place in world.layout.creative_places:
			if str(place.id)!=str(record.id):continue
			if record.get("center") is Vector3:place.center=xyz(record.center)
			if record.get("size") is Vector2:place.size=[record.size.x,record.size.y]
			var entries:Array=[];var heights:Array=[]
			for floor in record.get("floor_entries",[]):
				var point:Array=xyz(floor.point)
				if point.size()!=3:continue
				var entry:Dictionary={"name":floor.name,"point":point,"route_id":floor.get("route_id","")}
				entries.append(entry);heights.append(float(floor.get("y",point[1])))
			if not entries.is_empty():place.floor_entries=entries;heights.sort();place.floors=heights
			var exterior:Array=[]
			for point in record.get("external_route",[]):exterior.append(xyz(point))
			if not exterior.is_empty():place.entry_path=exterior
			if record.get("entry") is Vector3:place.door=xyz(record.entry)
			if record.get("center") is Vector3:
				var direction:Vector3=record.entry-record.center
				for portal in record.get("entrances",[]):
					if str(portal.get("id",""))==str(record.id) and portal.get("door") is Vector3 and portal.get("inside") is Vector3:
						direction=portal.door-portal.inside;break
				place.door_yaw=atan2(direction.x,direction.z)
	world.set_meta("entrances110",entrances);world.set_meta("upper_routes110",routes)
	for floor in counts.get("creative110",{}).get("floors",[]):
		for place in world.layout.creative_places:
			if place.id!=floor.id:continue
			var index:int=int(floor.get("floor",0))
			while place.floor_entries.size()<=index:place.floor_entries.append({})
			place.floor_entries[index]={"name":str(index+1)+"层","point":xyz(floor.entry)}
	for place in world.layout.creative_places:
		if str(place.id) not in ["CABLE_LOWER","CABLE_UPPER"]:continue
		var transport=preload("res://scripts/creative_transport110.gd")
		var landing:Vector3=transport.station_landing(0 if place.id=="CABLE_LOWER" else 1)
		place.travel_point=xyz(landing)
		place.floor_entries=[{"name":"乘车站台","point":xyz(landing)}]
	world.layout.creative_index.clear()
	for place in world.layout.creative_places:
		var at:=Vector3(place.center[0],place.center[1],place.center[2])
		world.layout.index_segment(world.layout.creative_index,{"place":place,"a":at,"c":at},maxf(place.size[0],place.size[1])*.5+12)
