extends RefCounted
## Recessed window surrounds, supported eaves and fitted parapets; no new floor obstacles.
func build(house):
	var b=house.b;var o:Vector3=house.origin
	var width:float=house.w;var depth:float=house.d;var height:float=house.h
	var kind:String=house.item.type
	var first:int=b.box_count
	var trim:String={"cafe":"647f86","records":"574939","florist":"668473","souvenir":"806447","pb":"79694f","dance":"7b7460","studio":"4b6560","cinema":"50626b","theater":"596971"}.get(kind,"6b7b72")
	# Full-depth lintels and split sills attach to retained window edges, not to panes.
	var wing:float=(width-3.4)/2
	for sign in [-1,1]:
		var center:float=sign*(width/2-wing/2)
		for y in [1.19,3.29]:
			b.box(o+Vector3(center,y,depth/2+0.20),Vector3(wing-0.18,0.12,0.36),trim,false,0,"wood")
		for x in [sign*1.76,sign*(width/2-0.20)]:
			b.box(o+Vector3(x,2.22,depth/2+0.16),Vector3(0.14,2.12,0.30),trim,false,0,"wood")
		# Corbels are above the window; slim brackets are supported by the wall.
		var count:int=maxi(2,floori(depth/2.2))
		for i in count:
			var z:float=-depth/2+(i+0.5)*depth/count
			b.box(o+Vector3(sign*(width/2+0.27),height-0.42,z),Vector3(0.55,0.17,0.16),trim,false,0,"wood")
			b.beam(o+Vector3(sign*(width/2+0.04),height-0.72,z),o+Vector3(sign*(width/2+0.48),height-0.39,z),0.105,trim)
	# Flat roofs retain gallery light wells; perimeter units do not cover the roof.
	if house.item.roof=="flat":
		for sign in [-1,1]:
			for i in ceili(width/0.7):
				var step:float=width/ceili(width/0.7)
				b.box(o+Vector3(-width/2+(i+0.5)*step,height+0.29,sign*(depth/2+0.32)),Vector3(step-0.018,0.28,0.48),"9da99e",false,0,"stone")
			for i in ceili(depth/0.7):
				var step:float=depth/ceili(depth/0.7)
				b.box(o+Vector3(sign*(width/2+0.32),height+0.29,-depth/2+(i+0.5)*step),Vector3(0.48,0.28,step-0.018),"9da99e",false,0,"stone")
	# Different opaque side-wall rhythms by use, preserving all studio/cafe windows.
	if kind in ["cinema","theater"]:
		for sign in [-1,1]:
			for i in maxi(2,floori(depth/3.4)):
				var z:float=-depth/2+1.6+i*3.4
				for row in 5:
					b.box(o+Vector3(sign*(width/2+0.23),height*(0.18+row*0.14),z),Vector3(0.22,height*0.11,0.46),trim,false,0,"stone")
	elif kind in ["pb","dance","studio"]:
		for sign in [-1,1]:
			for i in 5:
				b.box(o+Vector3(sign*(width/2+0.22),height-0.62,-1.4+i*0.42),Vector3(0.15,0.72,0.14),trim,false,0,"wood")
	var record:Dictionary=house.world.get_meta("envelopes_094",{})
	record[house.item.id]={"modules":b.box_count-first,"style":kind,"walls":"actual 0.65m panels","openings":"original shell wall bands only; glazing and door gaps retained"}
	house.world.set_meta("envelopes_094",record)
