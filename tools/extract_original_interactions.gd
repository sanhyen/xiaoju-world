extends SceneTree
func _initialize():
	var manifest=load("res://.runtime/fixtures/original_manifest_r4.tres")
	if manifest==null:push_error("Protected baseline manifest missing");quit(1);return
	var ids:Array=[]
	for row in manifest.interactions:ids.append(row.id)
	ids.sort()
	var file:=FileAccess.open("res://data/original_interactions_r4.json",FileAccess.WRITE);file.store_string(JSON.stringify({"source_checkpoint":"checkpoints/xiaoju_construction_20261011_152837.zip","ids":ids},"\t"));file.close()
	print("ORIGINAL_INTERACTION_CONTRACT ",ids.size());quit(0 if ids.size()==64 else 1)
