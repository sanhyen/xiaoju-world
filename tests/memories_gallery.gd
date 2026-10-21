extends SceneTree
var main
var results:Array=[]
func _initialize():run.call_deferred()
func check(name:String,passed:bool,detail:Dictionary={}):
	results.append({"test":name,"passed":passed,"detail":detail});print("MEMORY_TEST ",name," ",passed)

func at(point:Vector3):
	main.watch_camera.current=false;main.player.camera.current=true;main.player.position=point
	await main.world.prepare_region(point);main.player.enabled=false
	await create_timer(0.5).timeout

func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	main.qa_mode="memories";main.store.directory="user://qa_isolated/memories"
	await main.start_game(false);main.player.enabled=false
	check("unearned_card_cannot_be_claimed",not main.claim_card("Z07"))
	main.state.stamps.append("Z07")
	check("earned_card_claimed",main.claim_card("Z07") and main.state.cards==["Z07"])
	main.claim_card("Z07");check("repeat_claim_is_idempotent",main.state.cards.size()==1)
	await at(main.world.surface(173,-36,0.5))
	check("all_12_exhibition_surfaces_registered",main.world.gallery_pictures.size()==12)
	for preset in 3:
		main.state.gallery_preset=preset;main.world.set_gallery_preset(preset)
		var paths:Array=[];var correct_ratio:=true;var mapped:=true
		for picture in main.world.gallery_pictures.values():
			var texture:Texture2D=picture.material_override.albedo_texture;paths.append(texture.resource_path)
			correct_ratio=correct_ratio and absf(picture.mesh.size.x/picture.mesh.size.y-float(texture.get_width())/texture.get_height())<0.005
		var unique:Dictionary={}
		for path in paths:unique[path]=true
		for action in main.world.interactions:
			if action.id.begins_with("B05_art"):
				var slot:=int(str(action.id).trim_prefix("B05_art"));mapped=mapped and int(action.data.index)==main.world.GALLERY_ORDERS[preset][slot]
		check("preset_"+str(preset)+"_12_unique_pictures",unique.size()==12)
		check("preset_"+str(preset)+"_original_ratios",correct_ratio)
		check("preset_"+str(preset)+"_detail_source_matches_wall",mapped)
	main.state.gallery_preset=1;main.world.set_gallery_preset(1)
	await main.qa_capture("art_v11_gallery_recurated",main.world.surface(168,-35,2.2),main.world.surface(176,-46,2.4))
	await main.save_photo();main.state.home_shot=str(main.state.shots[-1]).get_file();main.sync_home_memories()
	await at(main.world.surface(-237,-168.5,0.6));main.sync_home_memories()
	check("home_has_card_and_player_photo_geometry",is_instance_valid(main.world.home_extras) and main.world.home_extras.find_children("*","MeshInstance3D",true,false).size()>0 and main.world.home_card_name=="花间生活")
	await main.qa_capture("art_v11_home_card",main.world.surface(-240,-168,2.1),main.world.surface(-244.3,-166,1.35))
	await main.qa_capture("art_v11_home_player_photo",main.world.surface(-233,-168.5,2.1),main.world.surface(-229.7,-168.5,1.65))
	check("memory_fields_saved",main.save_game(false))
	await at(main.world.surface(260,193,0.6));await at(main.world.surface(-237,-168.5,0.6))
	check("physical_card_and_photo_reload",is_instance_valid(main.world.home_extras) and main.world.home_card_name=="花间生活" and main.world.home_shot_path.ends_with(main.state.home_shot))
	main.state.cards=[];main.state.home_card="";main.state.home_shot="";main.state.gallery_preset=0
	await main.start_game(true);main.player.enabled=false
	check("memory_state_restored_from_disk",main.state.cards==["Z07"] and main.state.home_card=="Z07" and not main.state.home_shot.is_empty() and main.state.gallery_preset==1)
	var old:Dictionary=main.fresh_state.duplicate(true)
	for field in ["cards","home_card","home_shot","gallery_preset","home_light"]:old.erase(field)
	main.store.write(old);await main.start_game(true);main.player.enabled=false
	check("version1_old_fields_receive_defaults",main.state.get("cards",null)==[] and main.state.get("home_card",null)=="" and main.state.get("home_shot",null)=="" and main.state.get("gallery_preset",-1)==0)
	check("version1_old_home_light_receives_default",main.state.get("home_light",-1)==0 and main.world.home_light_index==0)
	main.show_souvenirs();await main.qa_frame();root.get_texture().get_image().save_png("res://screenshots/art_v11_souvenir_cards.png")
	main.close_modal();main.player.enabled=false
	var failed:=0
	for row in results:if not row.passed:failed+=1
	var file:=FileAccess.open("res://reports/memories_gallery.json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failed,"scope":"actual rendered exhibit changes, card claims, personal-photo geometry, reload and optional-field compatibility"},"\t"));file.close()
	main.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
