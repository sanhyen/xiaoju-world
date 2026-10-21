extends "res://scripts/woodland_groves.gd"
## Lowland canopy groups use the same rooted spacing guard as the verified forest.

func family(mix:String,rng:RandomNumberGenerator)->int:
	var roll:=rng.randf()
	if mix=="garden":return 3 if roll<0.25 else (0 if roll<0.76 else 6)
	if mix=="park":return 0 if roll<0.64 else (1 if roll<0.84 else 6)
	return 1 if roll<0.60 else (0 if roll<0.88 else 6)

func clear(point:Vector2,radius:float)->bool:
	# Keep the summit-to-portrait axis, square approaches and open sea foreground.
	if absf(point.x)<42+radius:return false
	if point.y>245:return false
	if point.distance_to(Vector2(-205,-145))<37:return false
	return super.clear(point,radius)

func build(config_path:String="res://data/lowland_groves_077.json",metadata_key:String="lowland_groves_v12"):
	super.build(config_path,metadata_key)
	var record:Dictionary=w.get_meta(metadata_key)
	record.scope="Authored lowland canopy groups, distinct from montane forest; retained axes, routes and open lawns"
	w.set_meta(metadata_key,record)
