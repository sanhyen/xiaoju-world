extends RefCounted
## Authored crescents alternate understory screens and clear foreground pockets.
var w
var b
var ecology
var rng:=RandomNumberGenerator.new()

func _init(target):
	w=target;b=w.b;ecology=preload("res://scripts/ecology_detail.gd").new(w)

func build():
	rng.seed=618094
	var groups:Array=[];var roots:Array=[]
	# center X/Z, radii, open-sector direction; following the forest, river and coastal edges.
	var pockets:Array=[[-279,-205,15,11,0.8],[-221,-213,17,12,2.0],[-310,-239,20,14,0.3],[-189,-251,18,15,1.2],[-100,-289,21,14,1.8],[65,-283,20,15,1.1],[158,-229,18,13,2.2],[271,-202,9,18,0.0],[345,-111,10,17,PI],[-119,266,15,8,1.4],[99,280,18,7,1.5],[-129,164,10,9,0.1]]
	for index in pockets.size():
		var record:Array=pockets[index];var center:=Vector2(record[0],record[1]);var count:=0
		for candidate in 112:
			var angle:float=rng.randf()*TAU
			# A genuinely empty bay faces the path/view; plants sit on the opposite crescent.
			if absf(wrapf(angle-float(record[4]),-PI,PI))<0.72:continue
			var radius:float=rng.randf_range(0.30,1.0)
			var point:Vector2=center+Vector2(cos(angle)*record[2],sin(angle)*record[3])*radius
			if not ecology.clear(point,1.65):continue
			var base:Vector3=w.surface(point.x,point.y)
			var stable:=true
			for offset in [Vector2(-0.65,0),Vector2(0.65,0),Vector2(0,-0.65),Vector2(0,0.65)]:
				if absf(w.height_at(point.x+offset.x,point.y+offset.y)-base.y)>0.18:stable=false;break
			if not stable:continue
			var crowded:=false
			for previous in roots:
				if point.distance_to(previous)<1.20:crowded=true;break
			if crowded:continue
			roots.append(point)
			var height:float=lerpf(0.24,1.18,radius)*(0.85+0.15*sin(angle*3))
			if center.y>250:height*=0.55
			var palette:Array=["415e54","617c60","879565"] if center.y<0 else ["68785b","89966f","acb384"]
			for lobe in 3:
				var offset:=Vector3(cos(lobe*2.3+angle)*0.31,height*(0.30+lobe*0.08),sin(lobe*2.3+angle)*0.29)
				b.box(base+offset,Vector3(0.65,height*(0.57-lobe*0.06),0.58),palette[lobe],false,0,"leaf")
				b.box(base+offset+Vector3(0.12,height*0.26,-0.08),Vector3(0.34,height*0.20,0.37),palette[mini(2,lobe+1)],false,0,"leaf")
			if candidate%4==0:ecology.garden.herb(w.surface(point.x+0.65,point.y),0.24,candidate%12==0)
			count+=1
		groups.append({"index":index,"center":center,"clusters":count,"open_sector_radians":1.44})
	w.set_meta("forest_edge_094",{"groups":groups,"clusters":roots.size(),"colliders_added":0,"protected":"paths, entrances, interactions, terraces; terrain-rooted","scope":"twelve authored crescent pockets, not uniformly scattered vegetation"})
