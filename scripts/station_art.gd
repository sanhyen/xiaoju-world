extends RefCounted
## B01 retained station: attached lean-to canopy and a readable arrival wall.
func build(house):
	var b=house.b
	var o:Vector3=house.origin
	# Rear edge meets the existing 5 m eave; front edge is carried by the colonnade.
	var slope:float=atan2(0.95,6.8)
	var basis:=Basis(Vector3.RIGHT,slope)
	b.oriented_box(o+Vector3(0,4.375,9.6),Vector3(26,0.18,sqrt(6.8*6.8+0.95*0.95)),"5c7372",basis,false,"slate")
	for x in range(-12,13,2):
		b.beam(o+Vector3(x,4.72,6.2),o+Vector3(x,3.77,13),0.12,"b4aa8d")
		b.beam(o+Vector3(x,4.96,6.2),o+Vector3(x,4.01,13),0.045,"85978c")
	for x in [-13,13]:
		b.beam(o+Vector3(x,4.82,6.2),o+Vector3(x,3.87,13),0.2,"71897f")
	b.box(o+Vector3(0,3.80,12.5),Vector3(25.2,0.28,0.28),"889780")
	b.box(o+Vector3(0,3.90,13),Vector3(26.2,0.22,0.18),"71897f")
	for x in [-10,-5,5,10]:
		b.box(o+Vector3(x,1.83,12.5),Vector3(0.24,3.66,0.24),"acaa91",true)
		b.box(o+Vector3(x,0.18,12.5),Vector3(0.39,0.36,0.39),"8d9280")
		for side in [-1,1]:
			b.beam(o+Vector3(x,3.12,12.5),o+Vector3(x+side*0.66,3.68,12.5),0.12,"889780")
	# Edge marking follows the existing platform, with a gap at the central exit.
	for side in [-1,1]:
		b.box(o+Vector3(side*7.8,0.113,13.4),Vector3(10.1,0.015,0.13),"bba77a")
		for index in 10:
			b.box(o+Vector3(side*(3.15+index),0.116,13.05),Vector3(0.62,0.014,0.08),"ded0a8")
		b.box(o+Vector3(side*12.55,1.87,12.85),Vector3(0.1,3.74,0.1),"758780")
	# No railway timetable or real journey is invented. This is the park arrival wall.
	b.box(o+Vector3(0,2.88,-6.66),Vector3(6.1,1.35,0.12),"6a8175")
	b.text3d("欢迎来到小鞠世界",o+Vector3(0,3.1,-6.58),0.009,"efe5cd")
	b.text3d("鞠婧祎主题 · 非官方同人乐园",o+Vector3(0,2.63,-6.58),0.0055,"e5dcc6")
	# Hang the sole station name in front of the columns, clear from both approach angles.
	b.box(o+Vector3(0,3.27,13.25),Vector3(4.6,0.70,0.12),"395b5b")
	b.text3d("海风站",o+Vector3(0,3.27,13.33),0.012,"e7dec9")
	for x in [-1.4,1.4]:b.beam(o+Vector3(x,3.62,13.25),o+Vector3(x,3.92,13),0.045,"66796b")
	# Signs state the actual road directions instead of ambiguous left/right arrows.
	b.box(o+Vector3(7.2,3.10,13.25),Vector3(4.8,0.9,0.12),"46675f")
	for x in [5.6,8.8]:b.beam(o+Vector3(x,3.55,13.25),o+Vector3(x,3.92,13),0.04,"66796b")
	b.text3d("星光广场 · 沿西侧步道",o+Vector3(7.2,3.32,13.33),0.0055,"f0e4c9")
	b.text3d("潮汐海岸 · 沿南侧步道",o+Vector3(7.2,2.99,13.33),0.0055,"f0e4c9")
	for x in [-7.5,7.5]:
		b.box(o+Vector3(x,4.0,9.25),Vector3(1.2,0.12,0.42),"667c70")
		b.glow_box(o+Vector3(x,3.93,9.25),Vector3(1.0,0.025,0.27))

	if house.world.layout!=null:
		b.picture("res://assets/maps/bay_arrival.svg",o+Vector3(-8.2,2.25,-6.42),3.5)
		b.text3d("八区 · 山海实景导览",o+Vector3(-8.2,4.03,-6.32),.007,"5e4232")
		for i in house.world.spec.zones.size():
			var zone:Dictionary=house.world.spec.zones[i];b.text3d(zone.name,o+Vector3(-5.05,3.5-i*.30,-6.30),.0038,"5e4232")
		house.world.interact("ADD_B01_WALL_MAP",o+Vector3(-8.2,0,-4.8),"实体山海导览 · E 打开地图","map",{})
