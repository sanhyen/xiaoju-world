extends RefCounted
## Seven block-built families; positions and ecology choose prototypes reproducibly.
const PALETTES=[
	["527b50","779457","9cab70"],["273f3d","3f6854","709363"],
	["253e40","355955","587e6b"],["b28c9e","d9aeb5","e4c8c7"],
	["4b685f","62796f","778674"],["41695d","6c9275","94ad83"],
	["596d50","6f8060","89976a"]
]
const HEIGHTS=[6.3,9.4,8.8,5.8,5.2,7.9,3.4]

func choose(p:Vector3,hint:int)->int:
	var roll:=posmod(floori(p.x*0.37+p.z*0.53)+hint*7,100)
	var river_x:float=307+18*sin(p.z*0.014)
	if absf(p.x-river_x)<40:return 5 if roll<72 else 6
	if p.z>255:return 4 if roll<78 else 6
	if p.z< -330:return 2 if roll<78 else 6
	if p.z< -220:return 2 if roll<52 else 1
	if p.z< -170:return 1 if roll<65 else (2 if roll<90 else 6)
	if hint==2 and p.z< -80:return 3
	return 0 if roll<72 else (6 if roll<89 else 3)

func crown(b,p:Vector3,width:float,depth:float,height:float,palette:Array,variant:int):
	# Layered, open-edged crowns across woodland, river and coast; original rooted positions retained.
	if p.z< -150 or absf(p.x-(307+18*sin(p.z*0.014)))<44 or p.z>255:
		for layer in 3:
			var count:int=4 if layer==1 else 3
			var dx:float=width/count;var dz:float=depth/3
			for ix in count:
				for iz in 3:
					if (ix==0 or ix==count-1) and (iz==0 or iz==2) and posmod(ix+iz+variant+layer,3)!=0:continue
					var q:=Vector3((ix-(count-1)*0.5)*dx+0.10*dx*sin(layer+variant),(layer-1)*height*0.30,(iz-1)*dz)
					b.box(p+q,Vector3(dx*1.02,height*0.39,dz*1.02),palette[layer],false,0,"leaf")
		return
	# Interior shade, a broad mid-layer and staggered cap/edge blocks leave gaps between lobes.
	b.box(p+Vector3(0,-height*0.22,0),Vector3(width*0.69,height*0.47,depth*0.67),palette[0],false,0,"leaf")
	b.box(p,Vector3(width*0.89,height*0.50,depth*0.81),palette[1],false,0,"leaf")
	b.box(p+Vector3(width*0.12,height*0.36,-depth*0.08),Vector3(width*0.61,height*0.30,depth*0.59),palette[2],false,0,"leaf")
	var side:float=1 if variant%2 else -1
	b.box(p+Vector3(side*width*0.39,-height*0.06,depth*0.18),Vector3(width*0.28,height*0.44,depth*0.37),palette[1],false,0,"leaf")
	b.box(p+Vector3(-side*width*0.24,height*0.20,-depth*0.35),Vector3(width*0.34,height*0.32,depth*0.30),palette[2],false,0,"leaf")
	if variant%3==0:b.box(p+Vector3(width*0.23,-height*0.28,depth*0.39),Vector3(width*0.31,height*0.24,depth*0.25),palette[0],false,0,"leaf")

func tree(b,p:Vector3,kind:int,size:float):
	kind=posmod(kind,7)
	var yaw:float=fposmod(p.x*0.131+p.z*0.076,TAU)
	var basis:=Basis(Vector3.UP,yaw)
	var palette:Array=PALETTES[kind]
	var h:float=HEIGHTS[kind]*size
	var lean:=Vector3(1.05*size,0,0.28*size) if kind==4 else basis*Vector3(0.22*size,0,0.10*size)
	var fork:Vector3=p+lean*0.4+Vector3(0,h*0.34,0)
	var upper:Vector3=p+lean+Vector3(0,h*0.68,0)
	b.beam(p,fork,(0.42 if kind in [1,2] else 0.30)*size,"786047")
	b.beam(fork,upper,0.24*size,"947255")
	b.collision(p+Vector3(0,minf(2.4*size,h*0.34)/2,0),Vector3(0.30*size,minf(2.4*size,h*0.34),0.30*size))
	if kind==2:
		for level in 6:
			var breadth:float=(4.6-level*0.61)*size
			var center:Vector3=p+Vector3(0,(2.6+level*0.99)*size,0)+basis*Vector3(sin(level*2.2)*0.25,0,cos(level)*0.14)*size
			for side in [-1,1]:b.beam(center+Vector3(0,-0.16*size,0),center+basis*Vector3(side*breadth*0.36,-0.29*size,0),0.095*size,"786047")
			crown(b,center,breadth,breadth*0.79,1.16*size,palette,level)
		b.box(p+Vector3(0,h*0.97,0),Vector3(0.44,0.76,0.46)*size,palette[2],false,0,"leaf")
	else:
		var count:int=4 if kind in [0,3,4] else 5
		for i in count:
			var angle:float=yaw+i*2.39
			var radius:float=([1.7,2.25,0,1.65,1.45,2.0,1.0][kind])*(0.66 if i==0 else 1.0)*size
			var q:Vector3=p+Vector3(cos(angle)*radius,h*(0.68+0.075*(i%3)),sin(angle)*radius)+lean
			var branch_start:Vector3=fork if i%2 else upper-Vector3(0,h*0.15,0)
			var joint:Vector3=branch_start.lerp(q,0.58)-Vector3(0,0.38*size,0)
			b.beam(branch_start,joint,0.17*size,"786047");b.beam(joint,q,0.10*size,"947255")
			var breadth:float=([3.0,3.3,0,2.7,3.1,2.8,2.2][kind])*(1.0+0.09*sin(i*3.1+yaw))*size
			var crown_h:float=(1.35 if kind in [4,6] else 1.8)*size
			crown(b,q,breadth,breadth*(0.73+0.06*(i%3)),crown_h,palette,i)
			if kind==5:
				for j in 3:
					var tail:Vector3=q+basis*Vector3((j-1)*breadth*0.25,-0.3*size,breadth*0.33)
					for k in 3:b.box(tail+Vector3(sin(j+k)*0.12*size,-k*0.46*size,0),Vector3(0.34,0.67,0.36)*size,palette[(j+k)%3],false,0,"leaf")
			if kind==3:
				for j in 3:b.box(q+Vector3(cos(i+j)*breadth*0.36,0.2*size,sin(i+j)*breadth*0.32),Vector3(0.32,0.19,0.29)*size,"e7d8cf",false,0,"leaf")
		if kind==6:
			for side in [-1,1]:b.beam(p+basis*Vector3(side*0.26,0,0)*size,p+basis*Vector3(side*0.65,h*0.68/size,0.1)*size,0.15*size,"786047")
	for i in 3:
		var q:Vector3=p+basis*Vector3(cos(i*2.1)*0.32,0.05,sin(i*2.1)*0.32)*size
		b.box(q,Vector3(0.64,0.16,0.18)*size,"786047",false,yaw+i*2.1,"wood")
	b.tree_counts[kind]=int(b.tree_counts.get(kind,0))+1
