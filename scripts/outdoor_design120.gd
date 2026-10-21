extends RefCounted
var w
var b
var craft
func _init(world):w=world;b=w.b;craft=preload("res://scripts/craft_components120.gd").new(world)
func clear_at(p:Vector3)->bool:
	for bound in w.building_bounds:
		if absf(p.x-bound.x)<bound.w*.5+1.5 and absf(p.z-bound.z)<bound.d*.5+1.5 and absf(p.y-float(bound.get("y",p.y)))<8:return false
	for road in w.layout.near(w.layout.road_index,Vector2(p.x,p.z)):
		var q:Vector3=w.layout.projection(Vector2(p.x,p.z),road)
		if Vector2(p.x-q.x,p.z-q.z).length()<road.width*.5+.8:return false
	return true
func dry_side(origin:Vector3)->Vector3:
	for distance in [4.5,7.0,10.0,14.0]:
		for direction in [Vector2(1,0),Vector2(-1,0),Vector2(0,-1),Vector2(0,1),Vector2(.7,-.7)]:
			var q:Vector3=origin+Vector3(direction.x*distance,0,direction.y*distance);q.y=w.height_at(q.x,q.z)
			if q.y>float(w.layout.config.sea_y)+.3 and absf(q.y-origin.y)<3.0 and clear_at(q):return q
	return Vector3.INF
func build():
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/design120_outdoors.json"));var records:Array=[];var occupied:Array=[]
	for place in data.places:
		var v:Array=place.point;var p:=Vector3(v[0],v[1],v[2]);var id:String=place.id;var role:String=place.role
		var entry:Dictionary={"id":id,"role":role,"original_destination":p,"route_kept":true,"boat_waterway_kept":true}
		if id.begins_with("VILLA_WADE_"):
			var index:int=int(id.trim_prefix("VILLA_WADE_"))
			for villa in w.layout.creative_places:
				if str(villa.id)!="VILLA_"+str(index):continue
				var o:=Vector3(villa.center[0],villa.center[1],villa.center[2])
				for step in 5:
					var y:float=lerpf(o.y,-2.8,float(step+1)/5);b.box(Vector3(o.x+4.54+step*.8,y+.015,o.z+8.5),Vector3(.06,.025,1.85),"c6b991",false,0,"wood")
				for side in [-1,1]:b.shape(o+Vector3(3.8,1.14,8.5+side*1.05),Vector3(.18,.12,.18),"b8a071","cylinder")
			entry.feature="five_tread_nosings_and_rail_caps";entry.feature_at=p;records.append(entry);continue
		if id=="FOREST_MAIL":
			b.box(p+Vector3(0,1.12,1.18),Vector3(.64,.38,.04),"ded0ab");b.box(p+Vector3(0,.77,1.18),Vector3(.8,.24,.06),"536f5e");b.text3d("树冠来信",p+Vector3(0,.77,1.22),.0035,"eee2c9")
			entry.feature="canopy_letter_sorting_pockets";entry.feature_at=p;records.append(entry);continue
		if role=="boat":
			# Non-solid mooring floats mark actual source points without closing navigation.
			var at:Vector3=p+Vector3(2.3,0,-1.8);at.y=float(w.layout.config.sea_y)+.15
			b.shape(at,Vector3(.52,.26,.52),"b9ad86","cylinder");b.shape(at+Vector3.UP*.24,Vector3(.19,.4,.19),"9b8155","cylinder")
			entry.feature="mooring_float";entry.feature_at=at;records.append(entry);continue
		var at:Vector3=dry_side(p)
		if not at.is_finite():
			# Elevated canopy mail and water-house ladders keep their existing clear landings.
			entry.feature="retained_platform_joints";entry.feature_at=p;records.append(entry);continue
		var shared:=false
		for old in occupied:
			if at.distance_to(old)<5:shared=true;break
		if shared:entry.feature="shared_wayfinding";entry.feature_at=at;records.append(entry);continue
		occupied.append(at)
		var words:String=place.name
		craft.sign(words,at+Vector3.UP*1.4,3.8)
		for x in [-1.55,1.55]:b.box(at+Vector3(x,.62,0),Vector3(.14,1.24,.16),"8e7753",true,0,"wood")
		entry.feature_at=at;entry.feature="physical_wayfinding"
		match role:
			"dock":
				for side in [-1,1]:b.shape(at+Vector3(side*1.4,.17,-.8),Vector3(.45,.34,.45),"7b8679","cylinder")
				b.box(at+Vector3(0,.22,-.8),Vector3(1.5,.44,.55),"a59068",true,0,"wood");entry.feature="mooring_hardware_and_route_board"
			"farm":craft.device("seedwall",at+Vector3(0,0,-1.7),.6);entry.feature="seed_inventory_and_field_map"
			"pasture":craft.device("tools",at+Vector3(0,0,-1.8),.6);entry.feature="feed_and_grooming_station"
			"mail":craft.device("drawers",at+Vector3(0,0,-1.7),.55);entry.feature="canopy_letter_sorting"
			"pool":craft.device("seedwall",at+Vector3(0,0,-1.7),.5);entry.feature="towel_and_water_guide"
			"parking":
				for i in 3:
					var q:=at+Vector3(-.9+i*.9,0,-1.1);b.beam(q+Vector3(-.25,0,0),q+Vector3(-.25,.55,0),.055,"718276");b.beam(q+Vector3(-.25,.55,0),q+Vector3(.25,.55,0),.055,"718276");b.beam(q+Vector3(.25,.55,0),q+Vector3(.25,0,0),.055,"718276")
				entry.feature="cycle_rack_and_tour_board"
			"firefly":craft.device("telescope",at+Vector3(0,0,-1.6),.65);entry.feature="night_observation_scope"
			"walk","wade":
				b.box(at+Vector3(0,.05,-.8),Vector3(2.4,.08,.8),"b4a88c",false,0,"stone");entry.feature="open_water_access_marker"
			"district":craft.device("diorama",at+Vector3(0,0,-2),.65);entry.feature="district_relief_map"
		records.append(entry)
	w.set_meta("outdoors120",records)
