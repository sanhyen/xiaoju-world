extends SceneTree
## Real protected fixtures plus content-heavy boundaries. No normal save is opened for writing.
class FakeMain:
	extends Node
	var state:Dictionary={}
	var bay=null
	var world=null
var checks:Array=[]
var failures:Array=[]
var numeric_differences:Array=[]
var run_id:=""

func _initialize():call_deferred("run")
func check(name:String,ok:bool,detail:Dictionary={}):
	checks.append({"name":name,"ok":ok,"detail":detail})
	if not ok:failures.append(name)
func service_for(value:Dictionary):
	var fake:=FakeMain.new();fake.state=value;root.add_child(fake)
	var service=load("res://scripts/creative_items110.gd").new();service.setup(fake);return [fake,service]
func sorted_keys(value:Dictionary)->Array:
	var result:Array=[]
	for key in value:result.append(str(key))
	result.sort();return result
func contains_original(a:Variant,b:Variant)->bool:
	if a is Dictionary and b is Dictionary:
		for key in a:
			if not b.has(key) or not contains_original(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not contains_original(a[i],b[i]):return false
		return true
	return a==b
func differences(a:Variant,b:Variant,path:String="",rounding:bool=false)->Array:
	var result:Array=[]
	if (a is int or a is float) and (b is int or b is float):
		if a!=b:
			var delta:float=absf(float(a)-float(b))
			if rounding:numeric_differences.append({"field":path,"before":a,"after":b,"absolute_error":delta})
			var exact_integer:bool=path.contains(".stacks.") or path.ends_with(".quantity") or path.ends_with(".next_uid") or path.ends_with(".schema")
			if not rounding or exact_integer or delta>1e-9:result.append(path)
	elif a is Dictionary and b is Dictionary:
		if sorted_keys(a)!=sorted_keys(b):result.append(path+".keys")
		for key in a:
			if b.has(key):result.append_array(differences(a[key],b[key],path+"."+str(key),rounding))
	elif a is Array and b is Array:
		if a.size()!=b.size():result.append(path+".length")
		for i in mini(a.size(),b.size()):result.append_array(differences(a[i],b[i],path+"["+str(i)+"]",rounding))
	elif a!=b:result.append(path)
	return result
func aliases_valid(fake,service)->bool:
	var d:Dictionary=service.data();var activities:Dictionary=fake.state.get("activities",{});var workshop:Dictionary=activities.get("workshops105",{})
	for key in workshop.get("slots",{}):
		var record:Dictionary=workshop.slots[key];var uid:String=str(record.get("_creative_uid",""))
		if uid.is_empty() or not d.works.has(uid) or d.works[uid].location!="legacy_slot:"+str(key):return false
	for i in workshop.get("racks",[]).size():
		var record=workshop.racks[i]
		if not record is Dictionary:continue
		var uid:String=str(record.get("_creative_uid",""))
		if uid.is_empty() or not d.works.has(uid) or d.works[uid].location!="legacy_rack:"+str(i):return false
	return true

func real_samples(manifest:Dictionary):
	for sample in manifest.samples:
		var store=load("res://scripts/save_store.gd").new();var source:Dictionary=store.decode(str(sample.fixture))
		var name:String=str(sample.id);check(name+"_valid_envelope",not source.is_empty() and FileAccess.get_sha256(str(sample.fixture))==str(sample.sha256))
		if source.is_empty():continue
		var pair:Array=service_for(source.duplicate(true));var fake=pair[0];var service=pair[1];service.initialize_state()
		var preserved:bool=true
		for field in ["stamps","cards","photos","shots","letters","discovered","home_card","home_shot","home_photo","playlist","mix_recipe","itinerary"]:
			if source.has(field) and not differences(source[field],fake.state.get(field),field).is_empty():preserved=false
		check(name+"_all_original_collections_and_selection_preserved",preserved)
		var material_ok:=true
		for key in source.get("inventory",{}):
			if service.MATERIAL_NAMES.has(key) and service.count(str(key))!=int(source.inventory[key]):material_ok=false
			elif fake.state.inventory.get(key)!=source.inventory[key]:material_ok=false
		check(name+"_real_materials_and_flower_discovery_preserved",material_ok and service.data().knowledge.flower_colors==source.get("inventory",{}).get("flower_colors",{}))
		check(name+"_actual_activity_progress_preserved",contains_original(source.get("activities",{}),fake.state.get("activities",{})))
		if source.get("handheld","")=="drink":check(name+"_existing_held_drink_is_owned_and_equipped",service.owned("legacy_drink",true).size()==1 and service.data().equipped_hand==service.owned("legacy_drink",true)[0].uid)
		var work_ids:Array=sorted_keys(service.data().works);var materials:Dictionary=service.data().stacks.duplicate(true)
		service.initialize_state();check(name+"_repeat_init_cannot_duplicate",sorted_keys(service.data().works)==work_ids and service.data().stacks==materials)
		var cold:Array=service_for(JSON.parse_string(JSON.stringify(fake.state)));cold[1].initialize_state()
		check(name+"_json_cold_restore_preserves_uids_and_materials",sorted_keys(cold[1].data().works)==work_ids and differences(cold[1].data().stacks,materials).is_empty())
		check(name+"_normal_source_hash_still_protected",FileAccess.get_sha256(str(sample.source))==str(sample.sha256))
		cold[0].free();fake.free()

func full_content(source:Dictionary):
	var state:Dictionary=source.duplicate(true)
	state.inventory={"wheat":7,"shell":3,"flower":2,"flower_colors":{"0":5,"4":2},"future_material":9}
	state.stamps=["B01","B08"];state.cards=["Z01","Z09_NEST"];state.photos=[0,3];state.shots=["sea_a.png","sea_b.png"];state.letters=[{"text":"keep original opaque letter"}];state.home_shot="sea_a.png"
	state.handheld="pottery"
	state.activities={"crafted":["windchime","lamp"],"home_object":"lamp","flower_vase":true,"bouquet_colors":[0,2,4],"bouquet_wrap":1,"picked":["ADD_PICK_flower7","ADD_PICK_shell3"],"untouched_progress":{"steps":[3,2,1]},"workshops105":{"slots":{"H01_0":{"kind":"bouquet","colors":["f4b8c4","6ba4d6"]},"H01_1":{"kind":"photo","file":"sea_a.png"},"B12_0":{"kind":"pottery","shape":2,"glaze":1}},"racks":[{"shape":0,"glaze":1},{"shape":2,"glaze":2},null,null,null,null],"pottery":{"stage":3,"shape":1,"glaze":2},"bread":7,"harvest":2,"bookmark":4,"wax":3,"chime":true,"fruit_ready":true,"croissant":5,"postcard":3,"framed_shot":"sea_a.png","printed_shot":"sea_a.png"},"island_02_state":{"letters":[{"card":"sea_b.png","stamp":"old"},{"card":"林间祝福","stamp":"old"}],"observed":[1,3],"star_records":[[0,4,9]]},"dual106":{"rooms":{"daily":{"prints":[0,1,2],"printed":3},"poem":{"actions":7,"phase":2,"best":5}}}}
	var pair:Array=service_for(state);var fake=pair[0];var service=pair[1];service.initialize_state();var d:Dictionary=service.data()
	check("full_content_25_real_works_no_history_count_multiplication",d.works.size()==25,{"works":d.works.size()})
	check("full_content_material_counts_and_discovery_are_separate",service.count("flower")==2 and service.count("wheat")==7 and d.knowledge.flower_colors=={"0":5,"4":2} and fake.state.inventory.future_material==9)
	check("full_content_collection_indexes_unchanged",fake.state.stamps==["B01","B08"] and fake.state.photos==[0,3] and fake.state.shots==["sea_a.png","sea_b.png"] and fake.state.letters.size()==1 and fake.state.cards.size()==2)
	check("full_content_legacy_slots_racks_uid_identity",aliases_valid(fake,service) and service.owned("legacy_pottery").size()==4 and service.owned("legacy_photo").size()==4)
	check("full_content_in_progress_and_recipe_history_kept",fake.state.activities.dual106.rooms.poem=={"actions":7,"phase":2,"best":5} and fake.state.activities.untouched_progress.steps==[3,2,1] and d.legacy_history.crafted==["windchime","lamp"])
	check("full_content_current_fired_pot_is_owned_once",fake.state.activities.workshops105.pottery.stage==0 and d.works.has(d.equipped_hand) and d.works[d.equipped_hand].item=="legacy_pottery")
	check("full_content_regrowth_does_not_regrant_old_pickups",float(d.regrowth.ADD_PICK_flower7)==90 and float(d.regrowth.ADD_PICK_shell3)==120 and service.count("flower")==2 and service.count("shell")==3)
	var letter_uid:String=fake.state.activities.island_02_state.letters[0]._creative_uid;var print_uid:String=fake.state.activities.dual106.rooms.daily._creative_print_refs[0];var rack_uid:String=fake.state.activities.workshops105.racks[0]._creative_uid;var slot_uid:String=fake.state.activities.workshops105.slots.H01_0._creative_uid
	var ids:Array=sorted_keys(d.works)
	check("full_content_take_old_mail_and_print_keeps_history",service.take(letter_uid) and service.take(print_uid) and fake.state.activities.island_02_state.letters[0]._creative_taken and 0 in fake.state.activities.dual106.rooms.daily._creative_taken_prints and fake.state.activities.island_02_state.letters.size()==2 and fake.state.activities.dual106.rooms.daily.prints.size()==3)
	check("full_content_take_old_slot_rack_clears_display_only",service.take(slot_uid) and service.take(rack_uid) and not fake.state.activities.workshops105.slots.has("H01_0") and fake.state.activities.workshops105.racks[0]==null and sorted_keys(d.works)==ids)
	service.initialize_state();var cold:Array=service_for(JSON.parse_string(JSON.stringify(fake.state)));cold[1].initialize_state()
	check("full_content_repeated_and_cold_migration_cannot_clone",sorted_keys(cold[1].data().works)==ids and cold[1].data().works[letter_uid].location=="bag" and cold[1].data().works[print_uid].location=="bag" and aliases_valid(cold[0],cold[1]))
	cold[0].free();fake.free()

func partial_aliases(source:Dictionary):
	var state:Dictionary=source.duplicate(true);var uid:="C110_00000042"
	state.creative110={"works":{uid:{"uid":uid,"item":"legacy_pottery","quantity":1,"location":"legacy_slot:H01_0","variant":{"shape":1,"glaze":2}}},"next_uid":43}
	state.activities={"workshops105":{"slots":{"H01_0":{"kind":"pottery","shape":1,"glaze":2,"_creative_uid":uid},"H01_1":{"kind":"pottery","shape":1,"glaze":2,"_creative_uid":uid}},"racks":[{"shape":1,"glaze":2,"_creative_uid":uid},null,null,null,null,null]}}
	var pair:Array=service_for(state);var fake=pair[0];var service=pair[1];service.initialize_state()
	check("partial_aliases_reuse_existing_uid_without_copy",service.owned("legacy_pottery").size()==1 and service.data().works.has(uid) and service.data().works.size()==2)
	check("partial_aliases_hide_duplicate_displays_preserve_repairs",aliases_valid(fake,service) and fake.state.activities.workshops105.slots.size()==1 and fake.state.activities.workshops105.racks[0]==null and service.data().quarantine.size()==2 and service.data().legacy_aliases.size()==3)
	var ids:Array=sorted_keys(service.data().works);service.initialize_state();check("partial_aliases_repeated_migration_stays_conserved",sorted_keys(service.data().works)==ids)
	fake.free()
	state=source.duplicate(true);uid="C110_00000055"
	state.creative110={"works":{uid:{"uid":uid,"item":"photo_print","quantity":1,"location":"bag","variant":{"file":"sea_a.png"}}},"next_uid":56}
	state.activities={"island_02_state":{"letters":[{"card":"sea_a.png","_creative_uid":uid,"_creative_taken":true}]},"dual106":{"rooms":{"daily":{"prints":[0],"_creative_print_refs":[uid],"_creative_taken_prints":[0]}}}}
	pair=service_for(state);fake=pair[0];service=pair[1];service.initialize_state()
	check("taken_mail_and_print_are_references_to_same_owned_work",service.owned("photo_print").size()==1 and service.data().works[uid].location=="bag" and fake.state.activities.island_02_state.letters[0]._creative_uid==uid and fake.state.activities.dual106.rooms.daily._creative_print_refs==[uid])
	fake.free()

func malformed_legacy(source:Dictionary):
	var state:Dictionary=source.duplicate(true);state.inventory={"flower":-2,"shell":1.5,"flower_colors":19};state.activities={"crafted":7,"picked":{"bad":true},"workshops105":{"slots":{"H01_0":14},"racks":["bad",{},null,null,null,null]},"dual106":{"rooms":18}}
	var pair:Array=service_for(state);var fake=pair[0];var service=pair[1];service.initialize_state()
	check("malformed_legacy_fields_quarantined_not_crashing",service.data().quarantine.size()>=7 and service.count("flower")==0 and service.count("shell")==0 and service.data().knowledge.flower_colors=={} and fake.state.activities.workshops105.slots.is_empty() and fake.state.activities.workshops105.racks[0]==null)
	check("malformed_legacy_empty_pot_recovered_with_safe_style",service.owned("legacy_pottery").size()==1 and fake.state.activities.workshops105.racks[1].shape==0 and fake.state.activities.workshops105.racks[1].glaze==0)
	fake.free()

func isolated_import_and_roundtrip(source:Dictionary,fixture:String):
	var base:String="user://migration110_"+run_id;var import_dir:String=base+"/latest_dual";DirAccess.make_dir_recursive_absolute(import_dir)
	var copied:int=DirAccess.copy_absolute(fixture,import_dir+"/progress.json")
	var store=load("res://scripts/save_store.gd").new();store.directory=base+"/creative_v1";store.import_directory=import_dir
	var imported:Dictionary=store.read();check("latest_dual_uses_real_readonly_store_import",copied==OK and store.imported_legacy and not imported.is_empty() and differences(imported,source).is_empty() and not store.import_source_checksum.is_empty())
	var pair:Array=service_for(imported);var fake=pair[0];var service=pair[1];service.initialize_state()
	for i in 2000:service.data().online=float(service.data().online)+1.0/60.0
	service.data().regrowth.diagnostic_clock=float(service.data().online)+120.015
	var work:Array=service.grant("bay_model",1,{"fine_offset":.123456789012345,"pattern":[0,0,1,0,3,4,0,3,1]})
	service.transfer(str(work[0]),"placed",{"position":[-240.123456789012,25.6000003814697,-242.123456789012],"yaw":.123456789012345,"area":"B12:floor:0"})
	var snapshot:Dictionary=service.data().duplicate(true);var written:bool=store.write(fake.state);var saved:Dictionary=store.read();var actual:Dictionary=saved.get("creative110",{})
	var mismatch:Array=differences(snapshot,actual,"creative110",true)
	check("isolated_save_envelope_roundtrip_preserves_all_semantic_data",written and not saved.is_empty() and mismatch.is_empty(),{"strict_dictionary_equal":actual==snapshot,"semantic_mismatches":mismatch,"numeric_rounding":numeric_differences})
	check("roundtrip_quantity_uid_and_placement_are_exact",differences(actual.stacks,snapshot.stacks).is_empty() and sorted_keys(actual.works)==sorted_keys(snapshot.works) and actual.works[str(work[0])].quantity==1 and actual.works[str(work[0])].location=="placed" and actual.works[str(work[0])].area=="B12:floor:0",{"stack_differences":differences(actual.stacks,snapshot.stacks),"strict_stacks_equal":actual.stacks==snapshot.stacks,"uid_lists_equal":sorted_keys(actual.works)==sorted_keys(snapshot.works),"strict_int_float_dictionary_equal":{"x":1}=={"x":1.0},"strict_name_string_dictionary_equal":{&"x":1}=={"x":1}})
	var cold:Array=service_for(saved);cold[1].initialize_state();check("isolated_saved_candidate_cold_load_keeps_owned_instances",sorted_keys(cold[1].data().works)==sorted_keys(snapshot.works) and differences(cold[1].data().stacks,snapshot.stacks).is_empty())
	check("isolated_import_sample_unchanged_after_candidate_write",FileAccess.get_sha256(fixture)==FileAccess.get_sha256(import_dir+"/progress.json"))
	cold[0].free();fake.free()

func run():
	run_id=str(Time.get_ticks_usec());var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.workspace/creative110_migration_samples/manifest.json"))
	check("eight_real_protected_fixtures_present",manifest.get("count",0)==8 and manifest.get("all_match_protection",false) and manifest.get("all_sources_read_only_unchanged",false))
	var targeted:bool="--case=roundtrip-and-dual" in OS.get_cmdline_user_args()
	if targeted:
		var selected:Dictionary=manifest.duplicate(true);selected.samples=selected.samples.filter(func(sample):return str(sample.id).begins_with("dual_island_v1"));real_samples(selected)
	else:real_samples(manifest)
	var fixture:String="res://.workspace/creative110_migration_samples/"+str(manifest.latest_dual_sample)
	var store=load("res://scripts/save_store.gd").new();var source:Dictionary=store.decode(fixture)
	if not targeted:full_content(source);partial_aliases(source);malformed_legacy(source)
	isolated_import_and_roundtrip(source,fixture)
	var result:Dictionary={"ok":failures.is_empty(),"checks":checks,"failures":failures,"numeric_differences":numeric_differences,"normal_save_io":"read only; writes only in isolated APPDATA","real_sample_count":manifest.get("count",0),"real_sample_limit":"Normal samples have no racks/slots/mail/prints; those branches are covered by synthetic full-content and UID-alias fixtures."}
	print("CREATIVE_MIGRATION110_CHECK "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
