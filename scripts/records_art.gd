extends RefCounted
## Original display fixtures, with source-mapped video stills kept distinct from album covers.
var b
var o:Vector3

func box(p:Vector3,s:Vector3,color:String):
	b.box(o+p,s,color)

func words(value:String,p:Vector3,size:float=0.0034,color:String="e7dbc2"):
	b.text3d(value,o+p,size,color)

func disc(p:Vector3,radius:float,tone:String="bda07a"):
	for entry in [[radius,"253739",0.0],[radius*0.81,"304345",0.012],[radius*0.31,tone,0.026],[radius*0.065,"ded5bd",0.039]]:
		var node:=MeshInstance3D.new();var mesh:=CylinderMesh.new()
		mesh.top_radius=entry[0];mesh.bottom_radius=entry[0];mesh.height=0.018;mesh.radial_segments=24
		node.mesh=mesh;node.material_override=b.material(entry[1]);b.root.add_child(node)
		node.position=o+p+Vector3(0,0,entry[2]);node.rotation.x=PI/2

func sleeve(p:Vector3,tone:String,size:float=0.62):
	box(p,Vector3(size,size,0.035),tone)
	box(p+Vector3(-size*0.34,0,0.024),Vector3(size*0.065,size*0.82,0.01),"d4c7a8")
	disc(p+Vector3(size*0.06,0,0.035),size*0.36,"b39c7b")

func build(house):
	b=house.b;o=house.origin
	# Reuse the four original table bodies and collision footprints, with three browsing bins each.
	for x in [-5.5,4.8]:
		for z in [-1.5,2.2]:
			b.table(o+Vector3(x,0,z),3.1)
			box(Vector3(x,1.08,z-0.40),Vector3(2.95,0.2,0.07),"796449")
			box(Vector3(x,1.04,z+0.46),Vector3(2.95,0.12,0.07),"baa07b")
			for divider in [-1.44,-0.48,0.48,1.44]:box(Vector3(x+divider,1.10,z+0.03),Vector3(0.05,0.24,0.85),"927858")
			for i in 3:
				var cx:float=x-0.96+i*0.96
				for layer in 3:
					var p:=Vector3(cx,1.32+layer*0.035,z+0.20-layer*0.18)
					if layer==0:sleeve(p,["91a49c","bda384","a99090"][i])
					else:box(p,Vector3(0.62,0.62,0.035),["9ca99b","c9b598","b29c98"][i])
			box(Vector3(x,0.90,z+0.57),Vector3(1.55,0.17,0.035),"64796b")
			words("原创唱片陈列",Vector3(x,0.90,z+0.592),0.0022,"eadcc1")
	# Three low back cabinets keep their previous solid boundaries and gain grouped, face-on records.
	for x in [-5,0,5]:
		b.shelf(o+Vector3(x,0,-5.6),3.2,false)
		for row in 3:
			var y:float=0.40+row*0.70
			box(Vector3(x,y-0.295,-5.11),Vector3(3.04,0.06,0.16),"b89970")
			for i in 4:sleeve(Vector3(x-1.13+i*0.75,y,-5.10),["91a49c","b7a284","aa9395"][(i+row)%3],0.53)
		if x!=0:
			box(Vector3(x,2.18,-5.16),Vector3(1.9,0.24,0.035),"64796b")
			words("音乐主题陈列" if x<0 else "演示画作",Vector3(x,2.18,-5.136),0.0030,"eadcc1")
	# These are complete-aspect stills extracted from existing source copies, never labelled album covers.
	b.picture("res://assets/media/records_sunset_still.png",o+Vector3(-0.94,3.65,-6.05),0.92)
	b.picture("res://assets/media/records_wall_still.png",o+Vector3(0.78,3.65,-6.05),0.92)
	words("落日未眠 · MV 画面",Vector3(-0.94,3.01,-5.96),0.0029,"536b5c")
	words("壁上观 · 视频画面",Vector3(0.78,3.01,-5.96),0.0029,"536b5c")
	# Window plinths remain. Two records and one source frame per window replace the anonymous boxes.
	for side in [-1,1]:
		var x:float=side*5.2
		var path:String="res://assets/media/records_sunset_still.png" if side<0 else "res://assets/media/records_wall_still.png"
		b.picture(path,o+Vector3(x,2.14,6.04),0.90)
		for dx in [-1.28,1.28]:sleeve(Vector3(x+dx,1.91,5.98),"a89675",0.64)
		box(Vector3(x,1.47,6.94),Vector3(3.30,0.32,0.07),"64796b")
		words("落日未眠 · MV 画面" if side<0 else "壁上观 · 视频画面",Vector3(x,1.47,6.982),0.0035,"e8dabc")
	# A visible listening position, without adding collisions to either approach.
	box(Vector3(1.45,1.08,-4.23),Vector3(0.40,0.04,0.36),"705d46")
	box(Vector3(1.45,1.41,-4.23),Vector3(0.045,0.66,0.045),"9f927a")
	box(Vector3(1.45,1.76,-4.23),Vector3(0.41,0.055,0.08),"3d4e49")
	for dx in [-0.19,0.19]:
		box(Vector3(1.45+dx,1.61,-4.23),Vector3(0.055,0.26,0.065),"42544f")
		box(Vector3(1.45+dx,1.46,-4.23),Vector3(0.13,0.23,0.16),"2b3d3b")
