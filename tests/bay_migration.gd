extends SceneTree
const Layout=preload("res://scripts/world_layout.gd")
const Migration=preload("res://scripts/save_migration.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:Array=[]
class PreviewWorld extends RefCounted:
	var layout

func _initialize():
	var world:=PreviewWorld.new();world.layout=Layout.new()
	world.layout.apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json")))
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_095_bay_v1.json"))
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json"))
	check("all_legacy_ids_preserved",original.ids.all(func(id):return id in legacy.protected_interaction_ids))
	for item in legacy.buildings:
		var source:Dictionary={"position":[item.x,float(item.y)+0.1,item.z],"interior":item.id,"stamps":["Z01","Z07"],"photos":[0,4,"sunset"],"discovered":["Z01","Z07"],"cards":["Z01"],"bouquet":2,"home_photo":7,"home_light":1,"pb_page":4,"shots":["user://photos/real.png"],"time":2,"weather":1,"unknown_future":{"keep":true}}
		var result:Dictionary=Migration.migrate(source,world)
		var target:Dictionary=world.layout.venues[item.id]
		check(str(item.id)+"_mapped",absf(float(result.position[0])-float(target.x))<1.0 and absf(float(result.position[2])-float(target.z))<1.0)
		check(str(item.id)+"_progress",result.photos==source.photos and result.stamps==source.stamps and result.unknown_future==source.unknown_future and result.pb_page==4 and result.home_photo==7 and result.weather==1)
		check(str(item.id)+"_idempotent",Migration.migrate(result,world)==result)
	var cafe:Dictionary=legacy.buildings[1]
	var upstairs:Dictionary=Migration.migrate({"position":[cafe.x,float(cafe.y)+3.9,cafe.z],"interior":"B02"},world)
	check("cafe_upstairs_retained",float(upstairs.position[1])>float(world.layout.venues.B02.floor_y)+3.5)
	var oldbeach:Dictionary=Migration.migrate({"position":[0,-0.6,330],"safe_point":[0,-0.5,332]},world)
	check("old_beach_recovery_is_land",world.layout.shallow_or_dry(Vector3(oldbeach.position[0],oldbeach.position[1],oldbeach.position[2])))
	check("safe_point_also_migrated",oldbeach.safe_point!=[0,-0.5,332])
	var folder:String="user://qa_isolated/bay_migration_"+str(Time.get_ticks_usec())
	var oldstore=Store.new();oldstore.directory=folder+"/old"
	var source:Dictionary={"position":[-237,2.3,-169],"interior":"B12","stamps":["Z07"],"photos":[0,"sunset"],"bouquet":2,"home_photo":0,"pb_page":3,"time":1,"weather":2}
	check("write_legacy_fixture",oldstore.write(source))
	var before:String=FileAccess.get_sha256(oldstore.directory+"/progress.json")
	var target=Store.new();target.directory=folder+"/bay";target.import_directory=oldstore.directory
	check("read_only_legacy_import",same_data(target.read(),source) and target.imported_legacy and target.import_source_checksum==before)
	var migrated:Dictionary=Migration.migrate(source,world)
	check("write_new_world",target.write(migrated))
	check("read_new_world",same_data(target.read(),migrated) and not target.imported_legacy)
	check("second_write_makes_backup",target.write(migrated))
	var file:=FileAccess.open(target.directory+"/progress.json",FileAccess.WRITE);file.store_string("invalid");file.close()
	check("new_backup_recovery",same_data(target.read(),migrated))
	file=FileAccess.open(target.directory+"/progress.bak",FileAccess.WRITE);file.store_string("invalid");file.close()
	check("corrupt_new_does_not_reset_to_old",target.read().is_empty())
	check("legacy_bytes_unchanged",FileAccess.get_sha256(oldstore.directory+"/progress.json")==before)
	var v1:Dictionary=migrated.duplicate(true);v1.world_revision="bay_v1";v1.position=[276,-.8,426];v1.activities={"unknown_keep":73}
	var upgraded:Dictionary=Migration.migrate(v1,world)
	check("0100_position_and_progress_kept",upgraded.world_revision=="bay_v2" and upgraded.position==v1.position and upgraded.activities==v1.activities)
	var modern=Store.new();modern.directory=folder+"/full_v2"
	upgraded.cards=["Z01",world.layout.config.hidden_views[0].card];upgraded.gallery_preset=3;upgraded.activities.bouquet_colors=[0,1,2,3,4]
	check("new_postcard_and_fourth_season_write",modern.write(upgraded))
	check("new_postcard_and_fourth_season_read",same_data(modern.read(),upgraded))
	check("0100_source_save_unchanged",FileAccess.get_sha256(oldstore.directory+"/progress.json")==before)
	var failures:int=checks.filter(func(item):return not item.passed).size()
	var report:Dictionary={"checks":checks,"failures":failures,"scope":"isolated migration and envelope; no GPU or collision acceptance"}
	file=FileAccess.open("res://reports/bay_migration.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BAY_MIGRATION ",JSON.stringify({"checks":checks.size(),"failures":failures}));quit(1 if failures else 0)

func check(label:String,passed:bool):
	checks.append({"name":label,"passed":passed})
	if not passed:push_error("BAY_MIGRATION "+label)

func same_data(a:Dictionary,c:Dictionary)->bool:
	# JSON numbers deserialize as float; compare normalized values, not int/float tags.
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(c))
