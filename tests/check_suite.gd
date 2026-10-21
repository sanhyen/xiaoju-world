extends SceneTree
const Store=preload("res://scripts/save_store.gd")
var outcomes: Array=[]
var main

func _initialize():run.call_deferred()

func check(name: String,ok: bool,detail: String=""):
	outcomes.append({"test":name,"passed":ok,"detail":detail})
	print("TEST ","PASS " if ok else "FAIL ",name," ",detail)

func run():
	var save=Store.new();save.directory="res://reports/isolated_save_test"
	var value:={"position":[0,1,80],"stamps":["Z04"],"photos":["portrait_01"],"bouquet":2,"pb_page":3,"interior":"","safe_point":[0,1,80]}
	check("write_and_checksum",save.write(value))
	var read:Dictionary=save.read()
	check("roundtrip_collect_and_decor",read.get("bouquet",-1)==2 and read.get("pb_page",-1)==3 and read.get("stamps",[]).has("Z04"))
	value.bouquet=1;check("second_save_backup",save.write(value))
	var file:=FileAccess.open(save.directory+"/progress.json",FileAccess.WRITE);file.store_string("{broken");file.close()
	read=save.read();check("corrupted_primary_falls_back",read.get("bouquet",-1)==2)
	check("save_after_corruption",save.write(value))
	check("keeps_valid_backup_after_corrupt_primary",save.decode(save.directory+"/progress.bak").get("bouquet",-1)==2)
	var other=Store.new();other.directory="res://reports/no_such_save"
	check("missing_save",other.read().is_empty())
	file=FileAccess.open(save.directory+"/invalid.json",FileAccess.WRITE);file.store_string(JSON.stringify({"version":99,"payload":"{}","checksum":"bad"}));file.close()
	check("future_version_rejected",save.decode(save.directory+"/invalid.json").is_empty())
	var coastal=Store.new();coastal.directory="res://reports/isolated_pier_save"
	var coast_state:Dictionary=value.duplicate(true);coast_state.position=[0,-0.35,364]
	check("constructed_pier_position_saves",coastal.write(coast_state))
	var saved_pier_hash:=FileAccess.get_sha256(coastal.directory+"/progress.json")
	coast_state.position=[15,-1,364]
	check("deep_water_position_rejected",not coastal.write(coast_state))
	check("rejected_write_keeps_valid_pier_save",not coastal.decode(coastal.directory+"/progress.json").is_empty() and FileAccess.get_sha256(coastal.directory+"/progress.json")==saved_pier_hash)
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	await physics_frame;await physics_frame
	check("13_core_interiors_present",main.world.building_bounds.size()==13)
	check("8_zones_present",main.world.spec.zones.size()==8)
	check("northeast_waterfall_belongs_to_Z08",main.zone_for_position(Vector3(315,42,-302)).id=="Z08")
	check("upper_river_bank_belongs_to_Z08",main.zone_for_position(Vector3(353,22,-246)).id=="Z08")
	check("culture_ascent_junction_keeps_Z06",main.zone_for_position(Vector3(220,1,-170)).id=="Z06")
	check("meaningful_interaction_count",main.world.interactions.size()>=24,str(main.world.interactions.size()))
	check("landmark_real_image",ResourceLoader.exists("res://assets/media/portrait_01.jpg"))
	main.player.enabled=false
	for item in main.world.spec.buildings:
		var p=main.player
		p.position=main.world.surface(item.x,item.z+item.d/2+2,0.5);p.velocity=Vector3.ZERO
		await main.world.prepare_region(p.position)
		for tick in 105:
			await physics_frame
			p.velocity=Vector3(0,maxf(p.velocity.y-19.0/60,-15),-4.8)
			if p.is_on_floor():p.velocity.y=-0.2
			p.move_character()
		check(item.id+"_walk_through_door",main.world.inside_building(p.position)==item.id,"position="+str(p.position))
		check(item.id+"_region_matches_venue",main.zone_for_position(p.position).id==item.zone)
		for tick in 108:
			await physics_frame
			p.velocity=Vector3(0,maxf(p.velocity.y-19.0/60,-15),4.8)
			if p.is_on_floor():p.velocity.y=-0.2
			p.move_character()
		check(item.id+"_walk_out",main.world.inside_building(p.position)=="","position="+str(p.position))
	main.store.directory="res://reports/isolated_game_save"
	main.player.position=Vector3(0,1,80);main.state.bouquet=2;main.state.pb_page=4
	check("game_save",main.save_game(false))
	check("game_load",main.store.read().get("pb_page",-1)==4)
	if ResourceLoader.exists("res://assets/media/sunset.ogg"):
		main.show_audio();await create_timer(1.0).timeout
		check("audio_playhead_advances",main.audio_player.playing and main.audio_player.get_playback_position()>0.2)
		main.close_modal();check("audio_released",main.audio_player.stream==null and not main.audio_player.playing)
	else:check("audio_exists",false)
	await main.show_video("B06");await create_timer(1.0).timeout
	check("video_playhead_advances",main.video.is_playing() and main.video.stream_position>0.2)
	main.close_modal();check("video_released",main.video.stream==null and not main.video.is_playing())
	main.show_pb(3);check("pb_remembers_page",main.state.pb_page==3);main.close_modal()
	var failures:=0
	for result in outcomes:if not result.passed:failures+=1
	var report:={"kind":"automated headless physics and functionality; not manual input or GPU visual QA","results":outcomes,"failures":failures}
	file=FileAccess.open("res://reports/test_suite.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	main.stop_media();main.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)
