extends RefCounted
## Small interior exit faces attach to retained door headers; no layout or action replacement.
var house
var b
var o:Vector3

func build(target):
	house=target;b=house.b;o=house.origin
	var start:int=b.box_count
	var created:=false
	var existing:Label3D
	for node in house.world.get_children():
		if not node is Label3D:continue
		if node.text not in ["出口","返回小镇","前往小镇","庭院"]:continue
		var local:Vector3=node.position-o
		if absf(local.x)<1.8 and absf(local.z-house.d/2)<0.6 and node.basis.z.z< -0.9:
			existing=node;break
	var anchor:=Vector3(0,2.7,house.d/2-0.27)
	if house.item.type=="home":anchor.y=2.53
	if existing==null:
		b.box(o+anchor,Vector3(1.48,0.31,0.09),"62796c",false,0,"wood")
		var header_y:float=2.78 if house.item.type=="home" else 3.32
		for side in [-1,1]:
			b.beam(o+Vector3(side*0.48,header_y,house.d/2-0.12),o+anchor+Vector3(side*0.48,0.18,0),0.03,"8f9a83")
		var title:String="庭院" if house.item.type=="home" else ("前往小镇" if house.item.type=="station" else "返回小镇")
		existing=b.text3d(title,o+anchor+Vector3(0,0,-0.057),0.0042,"e6dfc6",PI)
		created=true
	existing.name="VenueExit_"+str(house.item.id)
	existing.set_meta("venue_exit",str(house.item.id))
	var record:={"created":created,"modules":b.box_count-start,"position":existing.position,"normal":existing.basis.z,"text":existing.text,"colliders_added":0,"scope":"Interior reading face at actual retained front door; all old entrance and exit labels, actions and collision retained"}
	var summary:Dictionary=house.world.get_meta("venue_wayfinding_089",{});summary[house.item.id]=record
	house.world.set_meta("venue_wayfinding_089",summary)
