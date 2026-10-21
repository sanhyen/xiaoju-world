extends RefCounted
## Authored low groundcover pockets leave the retained paths, seats and views open.
var w
var b
var ecology
var rng:=RandomNumberGenerator.new()
var planted:=0
var dirt_patches:=0

func _init(target):
	w=target;b=w.b
	ecology=preload("res://scripts/ecology_detail.gd").new(w)

func clump(p:Vector3,height:float,kind:String):
	var yaw:=rng.randf()*TAU
	var blades:=3 if kind=="short" else 5
	var palette:Array=["869568","9bab7d"] if kind=="short" else (["7c8b67","a0ab80"] if kind=="wind" else ["61775c","7d8d6b"])
	for i in blades:
		var angle:=yaw+i*TAU/blades
		var h:=height*rng.randf_range(0.72,1.12)
		var basis:=Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,0.14+0.10*(i%3))
		b.oriented_box(p+Vector3(sin(angle)*0.055,h*0.49,cos(angle)*0.055),Vector3(0.06,h,0.075),palette[i%2],basis,false,"leaf")
	planted+=1

func build():
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/groundcover_081.json"))
	rng.seed=int(config.seed)
	var summary:Array=[]
	for patch in config.patches:
		var center:=Vector2(patch.center[0],patch.center[1])
		var radii:=Vector2(patch.radii[0],patch.radii[1])
		var count:=0
		var selected:Array=[]
		for i in int(patch.count):
			var angle:=rng.randf()*TAU
			var radius:=sqrt(rng.randf())
			# Scalloped islands with empty bays, rather than a carpet or a regular grid.
			if radius>0.78+0.16*sin(angle*3.0+center.x*0.1):continue
			var point:Vector2=center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y)*radius
			if absf(point.x)<36 and point.y>35 and point.y<140:continue
			if not ecology.clear(point,1.25):continue
			var base:Vector3=w.surface(point.x,point.y)
			var rooted:=true
			for offset in [Vector2(-0.32,0),Vector2(0.32,0),Vector2(0,-0.32),Vector2(0,0.32)]:
				if absf(w.height_at(point.x+offset.x,point.y+offset.y)-base.y)>0.12:rooted=false;break
			if not rooted:continue
			var crowded:=false
			for used in selected:
				if point.distance_to(used)<0.48:crowded=true;break
			if crowded:continue
			selected.append(point)
			clump(base,rng.randf_range(patch.height[0],patch.height[1]),patch.kind)
			if i%13==0:
				b.box(base+Vector3(0,0.012,0),Vector3(0.68,0.024,0.48),"968768" if patch.kind!="forest" else "756f59",false,rng.randf()*PI,"stone")
				dirt_patches+=1
			count+=1
		summary.append({"id":patch.id,"zone":patch.zone,"kind":patch.kind,"requested":patch.count,"actual":count})
	w.set_meta("groundcover_081",{"seed":config.seed,"patches":summary,"grass_clumps":planted,"bare_soil_patches":dirt_patches,"forms":3,"colliders_added":0,"scope":"New short, wind and forest groundcover in authored pockets; original terrain height, paths, trees, architecture and media retained"})
