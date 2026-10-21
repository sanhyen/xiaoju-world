extends RefCounted
## Original park stationery, not official merchandise. Existing collection actions stay in Buildings.
var b
var o:Vector3

func box(p:Vector3,s:Vector3,color:String,solid:bool=false):
	b.box(o+p,s,color,solid)

func words(value:String,p:Vector3,size:float=0.0036,color:String="f0e4ca"):
	b.text3d(value,o+p,size,color)

func postcard(p:Vector3,variant:int):
	box(p,Vector3(0.66,0.45,0.035),"e8dcc2")
	box(p+Vector3(0,0.035,0.024),Vector3(0.58,0.30,0.014),["a3bec0","b9c8b0","aaaec7"][variant%3])
	# Small original landscape vignettes, built as stepped shapes in the same voxel language.
	if variant%3==0:
		for i in 3:box(p+Vector3(0,-0.035+i*0.065,0.036),Vector3(0.56,0.025,0.009),["758f92","8fa7a7","d3d0ad"][i])
		box(p+Vector3(0.15,0.12,0.04),Vector3(0.065,0.065,0.009),"e8cf9c")
	elif variant%3==1:
		for i in 5:
			var height:float=0.06+0.04*(2-absi(i-2))
			box(p+Vector3(-0.23+i*0.115,-0.055+height/2,0.036),Vector3(0.12,height,0.009),"769182")
		box(p+Vector3(0.15,0.1,0.04),Vector3(0.025,0.15,0.009),"627868")
		box(p+Vector3(0.15,0.14,0.045),Vector3(0.12,0.06,0.009),"6b8273")
	else:
		box(p+Vector3(0,0.045,0.036),Vector3(0.11,0.22,0.009),"637577")
		for offset in [Vector2(-0.18,0.13),Vector2(0.17,0.09),Vector2(0.08,-0.025)]:
			box(p+Vector3(offset.x,offset.y,0.045),Vector3(0.045,0.016,0.009),"eee0b8")
			box(p+Vector3(offset.x,offset.y,0.045),Vector3(0.016,0.045,0.009),"eee0b8")
	box(p+Vector3(-0.06,-0.165,0.027),Vector3(0.37,0.017,0.012),"8d9b8d")
	box(p+Vector3(0.21,-0.165,0.027),Vector3(0.055,0.035,0.012),"b49374")

func ticket(p:Vector3,tone:String):
	box(p,Vector3(0.66,0.31,0.035),"e9dec4")
	box(p+Vector3(-0.235,0,0.025),Vector3(0.13,0.25,0.012),tone)
	box(p+Vector3(0.02,0.075,0.025),Vector3(0.27,0.022,0.012),"70847c")
	for i in 4:box(p+Vector3(-0.065+i*0.058,-0.02,0.025),Vector3(0.022,0.07,0.012),"8d998a")
	for y in [-0.11,-0.055,0,0.055,0.11]:box(p+Vector3(0.215,y,0.025),Vector3(0.012,0.018,0.012),"b8aa8b")
	box(p+Vector3(0.27,0.065,0.025),Vector3(0.045,0.045,0.012),tone)

func build(house):
	b=house.b;o=house.origin
	# Same footprint and collision as the previous two cabinets; clear middle aisle retained.
	for x in [-4,4]:
		b.shelf(o+Vector3(x,0,-4.7),2.6,false)
		for y in [0.35,1.05,1.75]:
			box(Vector3(x,y-0.265,-4.19),Vector3(2.44,0.075,0.17),"af9270")
			for i in 3:
				var p:=Vector3(x-0.8+i*0.8,y,-4.185)
				if x<0:postcard(p,(i+int(y*3))%3)
				else:ticket(p-Vector3(0,0.0725,0),["819c9d","ae9296","a0a27f"][i])
		words("山海明信片" if x<0 else "旅行票根 · 原创样式",Vector3(x,2.55,-4.12),0.0045,"586f64")
	# Eight sample stamp marks correspond to the actual eight zones, independent of unlock state.
	box(Vector3(0,1.45,-5.03),Vector3(4.05,1.9,0.12),"846f55")
	box(Vector3(0,1.45,-4.956),Vector3(3.83,1.69,0.04),"d0c4a7")
	for index in 8:
		var x:float=-1.38+(index%4)*0.92
		var y:float=1.73-float(index/4)*0.65
		var tone:String=["819b9a","a7a176","ad9298","809682"][index%4]
		box(Vector3(x,y,-4.918),Vector3(0.47,0.47,0.027),tone)
		box(Vector3(x,y,-4.896),Vector3(0.38,0.38,0.025),"e7dcc3")
		words("Z%02d"%(index+1),Vector3(x,y,-4.867),0.0027,"5d776b")
	words("纪念章样式 · 已解锁项请查看收藏",Vector3(0,0.72,-4.91),0.0032,"566c60")
	# Existing table and bags keep their positions; paper trays use the free right half.
	b.table(o+Vector3(-3,0,1),2.5)
	for z in [0.73,1.16]:
		box(Vector3(-2.27,1.0,z),Vector3(0.66,0.05,0.31),"cbb899")
		box(Vector3(-2.27,1.034,z),Vector3(0.61,0.015,0.27),"e5d9bc")
		box(Vector3(-2.48,1.048,z),Vector3(0.09,0.01,0.23),"8caaa3")
	words("原创乐园纸品",Vector3(-2.95,0.67,1.57),0.0041,"5c7064")
	# A modest register on the retained counter makes its purpose legible, without a payment UI.
	box(Vector3(3,1.3,0),Vector3(0.64,0.18,0.48),"64766c")
	box(Vector3(3,1.58,-0.08),Vector3(0.55,0.4,0.12),"657b72")
	box(Vector3(3,1.58,-0.005),Vector3(0.44,0.28,0.02),"acc0aa")
	words("乐园纪念",Vector3(3,1.58,0.012),0.0019,"4f6a5c")
