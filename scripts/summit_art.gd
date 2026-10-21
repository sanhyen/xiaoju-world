extends RefCounted
## Isolated080 candidate: retain original platform/rails/seats and replace the flat canopy.
var w
func _init(target):w=target

func build(top:Vector3):
	var rise:=1.45
	var half_span:=10.0
	var slope:=atan2(rise,half_span)
	var roof_length:=sqrt(half_span*half_span+rise*rise)
	for side in [-1,1]:
		w.b.oriented_box(top+Vector3(side*5.0,5.425,-3),Vector3(roof_length,0.22,10.8),"627771",Basis(Vector3.BACK,-side*slope),false,"slate")
	# The original four posts remain at the same positions and height.
	for z in [-7.0,1.0]:
		w.b.box(top+Vector3(0,4.69,z),Vector3(17.3,0.25,0.25),"a49476",false,0.0,"wood")
		for side in [-1,1]:
			w.b.beam(top+Vector3(side*8.5,3.67,z),top+Vector3(side*7.6,4.57,z),0.14,"a49476")
	for z in [-8.40,2.40]:
		for side in [-1,1]:
			w.b.beam(top+Vector3(0,6.15,z),top+Vector3(side*10,4.70,z),0.15,"9b927b")
		w.b.box(top+Vector3(0,4.58,z),Vector3(19.8,0.14,0.18),"9b927b",false,0.0,"wood")
		w.b.box(top+Vector3(0,5.33,z),Vector3(0.14,1.4,0.16),"a49476",false,0.0,"wood")
	w.b.box(top+Vector3(0,6.20,-3),Vector3(0.24,0.16,10.95),"738378",false,0.0,"slate")
	for z in [-7.8,-5.8,-3.8,-1.8,0.2,2.2]:
		for side in [-1,1]:w.b.beam(top+Vector3(0,6.04,z),top+Vector3(side*9.8,4.62,z),0.085,"baa98b")
	# The original solid floor stays; restrained joints describe actual paving modules.
	for x in range(-14,15,2):w.b.box(top+Vector3(x,0.306,0),Vector3(0.014,0.012,18.5),"a59e87",false,0.0,"stone")
	for z in [-8.0,-5.0,-2.0,1.0,4.0,7.0]:w.b.box(top+Vector3(0,0.306,z),Vector3(29.2,0.012,0.014),"a59e87",false,0.0,"stone")
	var support_count:=0
	for x in [-12.0,0.0,12.0]:
		for z in [-7.8,7.8]:
			var ground:float=w.height_at(top.x+x,top.z+z)
			var underside:float=top.y+0.02
			if underside-ground>0.25:
				w.b.box(Vector3(top.x+x,(ground+underside)/2,top.z+z),Vector3(0.75,underside-ground,0.75),"89907e",false,0.0,"stone")
				support_count+=1
	w.b.box(top+Vector3(0,4.22,2.51),Vector3(3.3,0.55,0.14),"d6cdb7",false,0.0,"wood")
	for x in [-1.1,1.1]:w.b.box(top+Vector3(x,4.50,2.48),Vector3(0.04,0.28,0.04),"a49476",false,0.0,"wood")
	w.b.text3d("云 间 亭",top+Vector3(0,4.22,2.605),0.011,"435951")
	for side in [-1,1]:
		var seat:=top+Vector3(side*8,0.3,1)
		w.interact("N08_SEAT_W" if side<0 else "N08_SEAT_E",seat+Vector3(0,0.2,1.25),"云间亭 · 坐下远眺", "sit",{"seat":seat,"yaw":PI})
	return {"roof_type":"two physical gable planes","roof_span_m":20.0,"roof_depth_m":10.8,"ridge_above_ground_m":6.2,"new_seat_actions":2,"paving_joints":21,"underdeck_supports":support_count,"supported_nameplate":true,"colliders_added":0,"original_platform_and_posts_retained":true,"scope":"Only canopy geometry; no original bench,guardrail,ramp or photo-action relocation"}
