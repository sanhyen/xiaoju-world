extends SceneTree
func _initialize():
	var w=preload("res://scripts/world.gd").new();w.layout=preload("res://scripts/world_layout.gd").new();w.spec=w.layout.apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json")));w.terrain_art=preload("res://scripts/terrain_voxel.gd").new(w)
	var points:Array=[[266.907,461.572],[242.36,422.06],[245.9,417.9],[154,228],[154,225],[154,220]]
	for source in w.layout.config.public_boats:points.append([source.shore[0],source.shore[2]]);points.append([source.water[0],source.water[2]])
	var records:Array=[]
	for at in points:
		var p:=Vector2(at[0],at[1]);var ground:float=w.height_at(p.x,p.y);var design:float=w.layout.height_at(p);var details:Array=[]
		for r in w.layout.near(w.layout.road_index,p):
			var q:Vector3=w.layout.projection(p,r)
			if p.distance_to(Vector2(q.x,q.z))<r.width*.5+3:details.append({"id":r.id,"height":q.y,"distance":p.distance_to(Vector2(q.x,q.z))})
		records.append({"point":at,"ground":ground,"design":design,"depth":float(w.layout.config.sea_y)-ground,"shallow":w.layout.shallow_or_dry(Vector3(p.x,ground+.2,p.y)),"roads":details})
	var file:=FileAccess.open("res://reports/dual106_failed_point_probe.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close();w.free();quit()
