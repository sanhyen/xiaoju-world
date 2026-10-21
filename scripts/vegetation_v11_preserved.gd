extends RefCounted
## Four silhouette families, varied by deterministic world position; shared batched geometry.
func tree(b,p:Vector3,kind:int,size:float):
	var yaw:float=fposmod(p.x*0.131+p.z*0.076,TAU)
	var basis:=Basis(Vector3.UP,yaw)
	var colors:Array=["647f5b","7d996b","91a877"]
	var height:float=[6.7,8.6,4.9,6.0][posmod(kind,4)]*size
	b.shape(p+Vector3(0,height*0.34,0),Vector3(0.34*size,height*0.68,0.34*size),"75664f","round")
	if kind==1:
		# Narrow upright trees with stepped, overlapping whorls and broken outlines.
		for level in 5:
			var width:float=(3.7-level*0.59)*size
			var q:=p+Vector3(sin(level*2.7)*size*0.22,(3.0+level*1.05)*size,cos(level)*size*0.16)
			b.shape(q,Vector3(width,1.6*size,width*0.82),colors[level%3],"shrub",yaw+level*0.4)
			b.box(q+Vector3(size*0.18,0.06,0),Vector3(width*0.68,0.83*size,width*0.67),colors[(level+1)%3],false,yaw)
	else:
		var breadth:float=[5.2,3.4,3.6,4.3][posmod(kind,4)]*size
		var count:int=7 if kind==0 else 5
		for i in count:
			var angle:float=i*2.4+yaw
			var radius:float=breadth*(0.16 if i==0 else 0.29)
			var q:=p+Vector3(cos(angle)*radius,height*(0.62+0.055*(i%3)),sin(angle)*radius)
			var scale:=Vector3(breadth*(0.44+0.04*(i%2)),height*(0.29 if kind!=3 else 0.34),breadth*0.48)
			var tone:String=colors[i%3] if kind!=2 else (["d1b8c2","e2cbd0","b899ac"][i%3] if p.z> -175 else ["abb58a","bfc89b","929e75"][i%3])
			b.shape(q,scale,tone,"shrub",angle)
			b.box(q+Vector3(0,scale.y*0.13,0),scale*Vector3(0.71,0.47,0.7),tone,false,angle)
			if i%2==0:b.beam(p+Vector3(0,height*0.31,0),q-Vector3(0,scale.y*0.23,0),0.10*size,"75664f")
		if kind==3:
			b.shape(p+basis*Vector3(-0.35*size,height*0.30,0.3*size),Vector3(0.18*size,height*0.6,0.18*size),"75664f","round")
	for side in [-1,1]:
		b.oriented_box(p+basis*Vector3(side*0.23*size,0.08*size,0),Vector3(0.54*size,0.15*size,0.18*size),"847356",basis)
	# Root-side understory stays in clusters and follows actual ground height.
	for i in 3:
		var offset:=basis*Vector3(sin(i*2.4+0.7)*(1.4+i*0.4)*size,0,cos(i*2.4+0.7)*(1.4+i*0.4)*size)
		var q:=p+offset
		if b.root.has_method("clear_of_paths") and not b.root.clear_of_paths(Vector2(q.x,q.z),0.9):continue
		if b.root.has_method("surface"):q=b.root.surface(q.x,q.z)
		b.shape(q+Vector3(0,0.26*size,0),Vector3(0.96,0.52,0.8)*size,["687e58","8b9b70","788d63"][i],"shrub",yaw+i)
		if i==1:b.shape(q+Vector3(0.67*size,0.11*size,-0.2*size),Vector3(0.65,0.28,0.45)*size,"a8ac92","rock",yaw)
