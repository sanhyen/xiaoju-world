extends SceneTree
const Architecture=preload("res://scripts/architecture120.gd")
const Art=preload("res://scripts/craft_components120.gd")
const Outdoor=preload("res://scripts/outdoor_design120.gd")
const NewWorld=preload("res://scripts/world_design120.gd")
const Feedback=preload("res://scripts/creative_feedback120.gd")
const Plan=preload("res://scripts/floor_plan120.gd")
func _initialize():
	var places:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creative_places110.json"));var outdoors:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/design120_outdoors.json"))
	var ids:Dictionary={}
	for p in places.places:ids[p.id]=true
	var ok:bool=ids.size()==83 and outdoors.places.size()==58
	print("DESIGN120_PARSE_AND_SCOPE ",JSON.stringify({"ok":ok,"places":ids.size(),"outdoors":outdoors.places.size()}));quit(0 if ok else 1)
