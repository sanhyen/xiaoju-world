extends RefCounted
## Shared geometry generates decks, junctions, guardrails and map paths.
var w
var b
var l
func _init(world):w=world;b=w.b;l=w.layout
func build():
	var width:float=l.config.sea_walk.width
	var guards=preload("res://scripts/bay_guardrails.gd").new(w)
	for route in l.config.sea_walk.routes:
		var distance:=0.0
		for i in route.points.size()-1:
			var a:Vector3=l.vector(route.points[i]);var c:Vector3=l.vector(route.points[i+1]);var along:Vector3=(c-a).normalized();var side:=Vector3(-along.z,0,along.x).normalized()
			b.ramp(a-along*.09,c+along*.09,width,"a58763");guards.span(a,c,width)
			var length:float=a.distance_to(c)
			for j in maxi(1,ceili(length/.7)):
				var at:Vector3=a.lerp(c,float(j)/maxi(1,ceili(length/.7)))
				b.beam(at-side*width*.5+Vector3.UP*.016,at+side*width*.5+Vector3.UP*.016,.035,"72553c")
			if i%3==0:
				for sign in [-1,1]:
					var p:Vector3=a+side*(width*.5-.14)*sign;var bed:float=minf(p.y-.6,w.height_at(p.x,p.z)-.3)
					b.box(Vector3(p.x,(p.y+bed)*.5,p.z),Vector3(.3,maxf(.5,p.y-bed),.3),"654a35",false,0,"wood")
					b.box(p+Vector3.UP*1.25,Vector3(.26,.3,.26),"795e42",false,0,"wood");b.glow_box(p+Vector3.UP*1.25,Vector3(.18,.19,.28))
			distance+=length
		w.set_meta("sea_walk_"+route.id,{"length_m":distance,"width_m":width})
	for point in l.config.sea_walk.hubs:
		var p:Vector3=l.vector(point);hub_platform(p);guards.octagon(p,4)
	for road in l.segments:
		if str(road.id).begins_with("forest106"):guards.span(road.a,road.c,road.width,false)
	for deck in l.config.decks:guards.span(l.vector(deck[0]),l.vector(deck[1]),float(deck[2]),false)
	for area in l.config.deck_areas:guards.pad(l.vector([(area[0]+area[2])*.5,area[4],(area[1]+area[3])*.5]),Vector2(area[2]-area[0],area[3]-area[1]),false)
	guards.build("sea_walk_all",true)
	for id in ["SEA_WALK_WEST","SEA_WALK_EAST","SEA_WALK_ISLAND","SHALLOWS_MAIN","SHALLOWS_ISLAND"]:
		var place:Dictionary=l.config.extra_places.filter(func(v):return v.id==id)[0];var at:Vector3=l.vector(place.safe)
		if id!="SHALLOWS_ISLAND":at.y=w.height_at(at.x,at.z)
		var sign:Vector3=at+Vector3(-3,0,0)
		b.box(sign+Vector3.UP*1.05,Vector3(.17,2.1,.17),"72553c",false,0,"wood");b.box(sign+Vector3.UP*1.65,Vector3(2.8,.65,.13),"5e7468",false,0,"wood");b.text3d(place.name,sign+Vector3(0,1.65,.08),.006,"f4e8cb")
		w.interact("INFO_"+id,at,place.name,"info",{"title":place.name,"body":"阳光沙滩、萤火森屿、珊瑚岛和大陆已连成木栈道环线，可步行或骑行。浅水可涉水回岸，深水乘自由船。"})
	for x in [-84,-72,-60,-48,-36]:b.shape(Vector3(x,float(l.config.sea_y)+.08,l.shore_z(x)+28),Vector3(.36,.30,.36),"e7c785","shrub")
	w.set_meta("sea_walk104",{"arcs":2,"dual_island_routes":5,"island_branch":true,"width_m":width,"high_deck_above_sea_m":6.3,"minimum_high_span_clearance_m":6.1,"mainland_shallow_band_m":28,"deep_water_behavior":"stop_in_place","guardrail_surfaces":guards.floors.size()})

func hub_platform(p:Vector3):
	var surface:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=4;mesh.bottom_radius=4;mesh.height=.26;mesh.radial_segments=8;surface.mesh=mesh;surface.material_override=b.material("a58763");surface.position=p-Vector3.UP*.13;w.add_child(surface)
	var body:=StaticBody3D.new();var col:=CollisionShape3D.new();var shape:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
	for i in 8:
		for y in [-.26,0]:points.append(Vector3(sin(i*TAU/8)*4,y,cos(i*TAU/8)*4))
	shape.points=points;col.shape=shape;body.add_child(col);body.position=p;w.add_child(body)
