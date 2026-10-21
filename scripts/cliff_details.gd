extends RefCounted
## Shallow rock shelves attach to existing tall exposed faces. Heightfield/collision stay unchanged.
var w
var b
var t
var rng:=RandomNumberGenerator.new()
var records:Array=[]
var groups:Array=[]

func _init(target):
	w=target;b=w.b;t=w.terrain_art

func build():
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cliff_details_091.json"))
	var initial:int=b.box_count
	for index in config.pockets.size():
		var pocket:Dictionary=config.pockets[index]
		rng.seed=int(config.seed)+index*977
		var count:=0
		var faces:=0
		for x in range(int(pocket.center[0]-pocket.radius[0]),int(pocket.center[0]+pocket.radius[0]),2):
			for z in range(int(pocket.center[1]-pocket.radius[1]),int(pocket.center[1]+pocket.radius[1]),2):
				var key:=Vector2i(floori(x/2.0),floori(z/2.0))
				var tile:Dictionary=t.tile(key)
				if str(tile.biome) not in ["woodland","montane","summit"]:continue
				var positions:=[Vector2(x,z),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]
				for edge in t.EDGES:
					var other:Dictionary=t.tile(key+edge[2])
					var high:float=minf(float(tile.heights[edge[0]]),float(tile.heights[edge[1]]))
					var low:float=maxf(float(other.heights[edge[3]]),float(other.heights[edge[4]]))
					if high-low<2.1 or rng.randf()>0.64:continue
					var a:=Vector3(positions[edge[0]].x,float(tile.heights[edge[0]]),positions[edge[0]].y)
					var c:=Vector3(positions[edge[1]].x,float(tile.heights[edge[1]]),positions[edge[1]].y)
					if t.roadcut_art.classify(a,c,float(other.heights[edge[3]]),float(other.heights[edge[4]]),str(tile.biome)):continue
					var normal:=Vector3((c-a).z,0,-(c-a).x).normalized()
					var middle:Vector3=(a+c)*0.5
					var outside:=Vector2(middle.x,middle.z)+Vector2(normal.x,normal.z)*0.9
					if not w.clear_of_paths(outside,2.6):continue
					var overlaps_building:=false
					for item in w.spec.buildings:
						if absf(outside.x-item.x)<item.w/2+8 and absf(outside.y-item.z)<item.d/2+8:overlaps_building=true;break
					if overlaps_building:continue
					faces+=1
					var level:float=low+0.55+rng.randf_range(0.0,0.38)
					while level<high-0.9:
						var depth:float=rng.randf_range(0.38,0.66)
						var height:float=rng.randf_range(0.22,0.43)
						var center:=Vector3(middle.x,level,middle.z)+normal*depth*0.16
						var width:float=rng.randf_range(1.12,1.78)
						var tone:String=["72796e","858779","929082","7d8376"][rng.randi_range(0,3)]
						b.box(center,Vector3(width,height,depth),tone,false,atan2(normal.x,normal.z),"stone")
						records.append({"group":pocket.id,"cell":[key.x,key.y],"edge":[edge[0],edge[1],edge[2].x,edge[2].y,edge[3],edge[4]],"low":low,"high":high,"center":[center.x,center.y,center.z],"normal":[normal.x,normal.z],"size":[width,height,depth],"embedded_depth":depth*0.34})
						count+=1
						level+=rng.randf_range(1.25,1.8)
		groups.append({"id":pocket.id,"faces":faces,"modules":count})
	w.set_meta("cliff_details_091",{"seed":config.seed,"modules":b.box_count-initial,"colliders_added":0,"groups":groups,"records":records,"scope":"Embedded shallow shelves on existing natural faces; retain all heights, roads, old trees, buildings and interactions. Road-cut retaining walls excluded."})
