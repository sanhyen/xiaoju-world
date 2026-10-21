extends SceneTree
class FakeMain:
	extends Node
	var state:Dictionary={}
	var bay=null
var checks:Array=[]
func same(a:Variant,b:Variant)->bool:
	if (a is int or a is float) and (b is int or b is float):return absf(float(a)-float(b))<.000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not same(a[i],b[i]):return false
		return true
	return a==b
func check(id:String,ok:bool):checks.append({"id":id,"ok":ok});print("MIGRATION120 ",id," ",ok)
func _initialize():run.call_deferred()
func run():
	var fixture:String="res://.runtime/design120_migration_fixtures/creative_v1__progress.json"
	var store=preload("res://scripts/save_store.gd").new();var original:Dictionary=store.decode(fixture);var source_sha:String=FileAccess.get_sha256(fixture)
	check("latest_0110_fixture_is_valid",not original.is_empty())
	var directory:String="res://.runtime/design120_migration_fixtures/session_"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(directory+"/creative_v1")
	DirAccess.copy_absolute(fixture,directory+"/creative_v1/progress.json");store.directory=directory+"/design_v1";store.import_directory=directory+"/creative_v1"
	var imported:Dictionary=store.read();check("read_only_import_keeps_entire_payload",JSON.stringify(imported)==JSON.stringify(original) and store.imported_legacy)
	var fake:=FakeMain.new();fake.state=imported;root.add_child(fake);var items=preload("res://scripts/creative_items110.gd").new();items.setup(fake);items.initialize_state()
	var prior:Dictionary=original.get("creative110",{});var current:Dictionary=fake.state.creative110
	check("existing_works_uid_and_content_preserved",same(prior.get("works",{}),current.works))
	check("existing_stacks_shortcuts_equipment_preserved",same(prior.get("stacks",{}),current.stacks) and prior.get("shortcuts",[])==current.shortcuts and prior.get("equipped_hand","")==current.equipped_hand and prior.get("equipped_back","")==current.equipped_back)
	fake.state.game_version="0.12.0";check("new_namespace_write",store.write(fake.state));check("second_write_keeps_valid_backup",store.write(fake.state))
	var cold=preload("res://scripts/save_store.gd").new();cold.directory=store.directory;cold.import_directory=store.import_directory
	var restored:Dictionary=cold.read();check("cold_restore_uses_new_namespace",not cold.imported_legacy and same(restored.creative110.works,current.works))
	var backup_sha:String=FileAccess.get_sha256(cold.directory+"/progress.bak");var broken:=FileAccess.open(cold.directory+"/progress.json",FileAccess.WRITE);broken.store_string("broken isolated test");broken.close()
	var recovered:Dictionary=cold.read();check("corrupt_new_main_uses_valid_backup",not recovered.is_empty() and same(recovered.creative110.works,current.works))
	check("repair_does_not_overwrite_last_good_backup",cold.write(recovered) and FileAccess.get_sha256(cold.directory+"/progress.bak")==backup_sha)
	check("import_source_copy_unchanged",FileAccess.get_sha256(fixture)==source_sha and FileAccess.get_sha256(directory+"/creative_v1/progress.json")==source_sha)
	var failures:Array=checks.filter(func(r):return not r.ok);var file:=FileAccess.open("res://reports/design120_migration.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"normal_sources":"read-only copies; fixture namespace only"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
