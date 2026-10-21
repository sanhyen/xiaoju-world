extends SceneTree
var main
var results:Array=[]
func _initialize():run.call_deferred()
func check(name:String,ok:bool):results.append({"test":name,"passed":ok});print("ENV_SAVE ",name," ",ok)
func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main);await physics_frame
	main.qa_mode="env_save_compat";main.store.directory="user://qa_isolated/environment_v12_compat";main.player.enabled=false;main.player.program_driven=true
	var old:Dictionary=main.fresh_state.duplicate(true)
	old.game_version="0.5.0-art-development";old.position=[-279.3,0,-219.4];old.stamps=["Z07"];old.cards=["Z07"];old.home_card="Z07";old.home_photo=5;old.home_light=1;old.pb_page=3;old.gallery_preset=2
	check("old_schema_one_fixture_written",main.store.write(old))
	var checksum:=FileAccess.get_sha256(main.store.directory+"/progress.json")
	await main.start_game(true);main.player.enabled=false
	check("buried_old_position_above_actual_terrain",main.player.position.y>main.world.height_at(-279.3,-219.4))
	check("legacy_collectibles_and_theme_choices_retained",main.state.cards==["Z07"] and main.state.home_card=="Z07" and int(main.state.home_photo)==5 and int(main.state.home_light)==1 and int(main.state.gallery_preset)==2 and int(main.state.pb_page)==3)
	check("loading_did_not_rewrite_original_envelope",checksum==FileAccess.get_sha256(main.store.directory+"/progress.json"))
	main.player.automated_motion=true;main.player.automated_horizontal=Vector2.ZERO
	for tick in 90:await physics_frame
	main.player.automated_motion=false
	check("restored_capsule_settles_on_collision",main.player.is_on_floor() and absf(main.player.position.y-main.world.height_at(main.player.position.x,main.player.position.z))<0.18)
	old.position=[-279.3,main.world.height_at(-279.3,-219.4)+4,-219.4]
	check("compat_write_keeps_previous_backup",main.store.write(old) and not main.store.decode(main.store.directory+"/progress.bak").is_empty())
	await main.start_game(true);main.player.enabled=false;main.player.automated_motion=true;main.player.automated_horizontal=Vector2.ZERO
	for tick in 150:await physics_frame
	main.player.automated_motion=false
	check("old_floating_position_falls_to_valid_ground",main.player.is_on_floor() and absf(main.player.position.y-main.world.height_at(main.player.position.x,main.player.position.z))<0.18)
	old.position=[-281.95,0,-220.05];check("edge_fixture_saved",main.store.write(old))
	await main.start_game(true);main.player.enabled=false;await physics_frame
	var collision:CollisionShape3D=main.player.get_child(0)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=collision.shape;query.transform=main.player.global_transform*collision.transform;query.exclude=[main.player.get_rid()]
	check("old_save_at_voxel_edge_has_clear_capsule",main.world.get_world_3d().direct_space_state.intersect_shape(query).is_empty())
	var fail:=0
	for row in results:fail+=0 if row.passed else 1
	var file:=FileAccess.open("res://reports/environment_save_compat.json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":fail,"scope":"isolated old version-one saves; no real user save touched"},"\t"));file.close()
	main.stop_media();main.queue_free();await process_frame;await process_frame;quit(1 if fail else 0)
