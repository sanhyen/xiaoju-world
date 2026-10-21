extends SceneTree
## Isolated quantity / migration contract. No save file, original asset or player window is touched.
class FakeMain:
	extends Node
	var state:Dictionary={}
	var bay=null
var checks:Array=[]
var failures:Array=[]
func _initialize():call_deferred("run")
func check(name:String,ok:bool,detail:Dictionary={}):
	checks.append({"name":name,"ok":ok,"detail":detail})
	if not ok:failures.append(name)
func service_for(value:Dictionary):
	var fake:=FakeMain.new();fake.state=value;root.add_child(fake);var service=load("res://scripts/creative_items110.gd").new();service.setup(fake);return [fake,service]
func run():
	var pair:Array=service_for({"inventory":{"wood":5,"paper":2},"activities":{},"handheld":"natural"});var fake=pair[0];var service=pair[1];service.initialize_state()
	check("approved_28_distinct_definitions",service.APPROVED.size()==28 and service.APPROVED.all(func(id):return service.defs.has(id)))
	check("legacy_materials_preserved",service.count("wood")==5 and service.count("paper")==2)
	var before:String=JSON.stringify(service.data().stacks)
	check("insufficient_cost_is_atomic",not service.consume_cost({"wood":6,"paper":1}) and JSON.stringify(service.data().stacks)==before)
	check("negative_cost_cannot_mint_material",not service.consume_cost({"wood":-1}) and service.count("wood")==5)
	var ids:Array=service.grant("castle_table",2,{"tone":1});check("uid_is_unique_per_work",ids.size()==2 and ids[0]!=ids[1])
	check("equipment_is_same_work_reference",service.equip(ids[0]) and service.data().equipped_hand==ids[0] and service.owned("castle_table").size()==2)
	check("placement_moves_instead_of_copies",service.transfer(ids[0],"placed",{"position":[-240,25.6,-242],"yaw":.25,"area":"B12:floor:0"}) and service.data().equipped_hand=="" and service.owned("castle_table",true).size()==1 and service.owned("castle_table").size()==2)
	check("retrieve_restores_same_uid",service.take(ids[0]) and service.data().works[ids[0]].location=="bag" and service.owned("castle_table",true).size()==2)
	var total:int=service.data().works.size();service.initialize_state();check("initialize_is_idempotent",service.data().works.size()==total and service.owned("starter_basic_pack").size()==1)
	service.data().next_uid=1;service.initialize_state();var next:Array=service.grant("paper_lamp");check("counter_cannot_overwrite_existing_uid",next.size()==1 and next[0] not in ids and service.owned("castle_table").size()==2)
	var serialized:String=JSON.stringify(fake.state);var cold:Array=service_for(JSON.parse_string(serialized));var restored=cold[1];restored.initialize_state()
	check("json_cold_restore_preserves_quantity_and_uids",restored.count("wood")==5 and restored.owned("castle_table").size()==2 and restored.data().works.has(ids[0]))
	restored.data().works["broken_record"]=17
	var damaged:Array=restored.grant("street_lamp");restored.data().works[damaged[0]].quantity=-1
	var misplaced:Array=restored.grant("flower_stand");restored.data().works[misplaced[0]].location="placed";restored.data().works[misplaced[0]].position=["bad",2,3];restored.data().works[misplaced[0]].area="B12:floor:0"
	restored.data().stacks.wood=-9;restored.initialize_state()
	check("corrupt_work_quarantined_without_losing_good_works",not restored.data().works.has("broken_record") and not restored.data().works.has(damaged[0]) and restored.data().works.has(ids[0]) and restored.data().quarantine.size()>=3)
	check("invalid_placement_returns_owned_work_to_bag",restored.data().works[misplaced[0]].location=="bag")
	check("negative_stack_repaired_and_recorded",restored.count("wood")==0 and not restored.data().repairs.is_empty())
	var legacy:Array=service_for({"inventory":{"shell":3,"flower":2,"flower_colors":{"0":2}},"activities":{"crafted":["windchime"],"workshops105":{"slots":{"H01_0":{"kind":"bouquet","colors":["f4b8c4"]},"B12_1":{"kind":"pottery","shape":1,"glaze":2}},"racks":[{"shape":0,"glaze":1},null,null,null,null,null],"pottery":{"stage":3,"shape":2,"glaze":0}}},"handheld":"pottery"})
	var old_main=legacy[0];var migrated=legacy[1];migrated.initialize_state();var migrated_count:int=migrated.data().works.size()
	check("legacy_slots_and_racks_keep_independent_works",migrated.owned("legacy_pottery").size()==3 and migrated.owned("legacy_bouquet").size()==1 and old_main.state.activities.workshops105.slots.H01_0.has("_creative_uid"))
	check("legacy_flower_discovery_not_minted_as_material",migrated.count("flower")==2 and migrated.data().knowledge.flower_colors.get("0",0)==2)
	migrated.initialize_state();check("legacy_migration_does_not_duplicate",migrated.data().works.size()==migrated_count)
	var slot_uid:String=old_main.state.activities.workshops105.slots.H01_0._creative_uid;check("legacy_slot_take_removes_old_display_record",migrated.take(slot_uid) and not old_main.state.activities.workshops105.slots.has("H01_0") and migrated.data().works[slot_uid].location=="bag")
	print("CREATIVE_ITEMS110_CHECK "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
