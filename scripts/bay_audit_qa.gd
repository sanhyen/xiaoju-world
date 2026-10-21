extends RefCounted
func colors_in(node:Node)->Array:
	var result:Array=[]
	for child in node.find_children("*","MultiMeshInstance3D",true,false):
		for i in child.multimesh.instance_count:result.append(child.multimesh.get_instance_color(i).to_html(false))
	return result

func buttons(node:Node)->Array:
	var result:Array=[]
	if node is Button:result.append(node)
	for child in node.get_children():result.append_array(buttons(child))
	return result

func run(m,q):
	q.sampling=true;m.set_time(0)
	var ids:Array=m.world.interactions.map(func(a):return a.id);var unique:Dictionary={}
	for id in ids:unique[id]=true
	var frozen:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/migration_095_bay_v1.json"))
	q.check("eight_zones_thirteen_original_venues_and_old_ids",m.world.spec.zones.size()==8 and m.world.building_bounds.size()==13 and frozen.protected_interaction_ids.all(func(id):return id in ids) and ids.size()==unique.size(),ids.size())
	var broken:Array=[]
	for h in m.world.layout.config.living_houses:
		var p:Vector3=m.world.layout.vector(h.center)+Vector3(0,.3,2)
		await q.move_to(p);m.bay.local_music="cafe";m.bay.update_audio()
		var zone:Dictionary=m.zone_for_position(m.player.position)
		if not str(zone.get("id","")).begins_with("Z") or m.bay.step_surface()!="wood" or not m.world.is_sheltered(m.player.position):broken.append(h.id)
		await m.get_tree().create_timer(.25).timeout
	q.check("all_fourteen_houses_interior_zone_audio_footsteps_shelter",broken.is_empty(),broken)
	var bad_hotels:Array=[]
	for i in 4:
		var p:=Vector3(276+(4 if i in [1,2] else 0),-.5,426+i*15);await q.move_to(p);m.bay.local_music="book";m.bay.update_audio()
		if not m.world.is_sheltered(p) or m.bay.step_surface()!="wood" or m.zone_for_position(p).get("id","")!="Z02":bad_hotels.append(i)
	q.check("four_villas_indoor_camera_rain_shelter_and_wood_steps",bad_hotels.is_empty(),bad_hotels)
	var actions:Dictionary={}
	for action in m.world.interactions:
		if action.kind=="bay_activity" and action.data.has("venue"):actions[action.data.venue]=action.data.activity
	q.check("all_thirteen_distinct_main_activity_entries",actions.size()==13 and actions.values().size()==13,actions)
	# These values come from the real player and affect the actual viewport camera.
	m.player.enabled=true;m.player.velocity=Vector3(m.player.walk_speed,0,0);m.bay.details.update_motion_effects(1)
	q.check("walking_fov_65_after_speed_increase",absf(m.player.camera.fov-65)<.1,m.player.camera.fov)
	m.player.velocity=Vector3(m.player.walk_speed*m.player.run_multiplier,0,0);m.bay.details.update_motion_effects(1)
	q.check("running_fov_69",absf(m.player.camera.fov-69)<.1,m.player.camera.fov);m.player.enabled=false;m.player.velocity=Vector3.ZERO
	var home:Dictionary=m.world.layout.venues.B12;await q.move_to(Vector3(home.x,home.floor_y+.3,home.z+3))
	m.state.activities.home_object="lamp";m.bay.update_home_object();await m.get_tree().process_frame
	var lamps:Array=m.bay.ornament.find_children("*","OmniLight3D",true,false)
	q.check("crafted_table_lamp_really_lights",lamps.size()==1 and lamps[0].light_energy>0)
	m.state.home_light=2;m.bay.update_home_object();await m.get_tree().process_frame
	lamps=m.bay.ornament.find_children("*","OmniLight3D",true,false);q.check("crafted_lamp_respects_home_light_off",lamps.size()==1 and lamps[0].light_energy==0)
	m.state.activities.home_object="frame";m.bay.update_home_object();await m.get_tree().process_frame
	var framed:Array=m.bay.ornament.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.material_override.albedo_texture!=null)
	q.check("crafted_frame_updates_without_unloading_home",framed.size()==1)
	m.state.home_photo=2;m.bay.update_home_object();await m.get_tree().process_frame
	framed=m.bay.ornament.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.material_override.albedo_texture!=null)
	q.check("crafted_frame_displays_selected_real_photo",framed.size()==1 and framed[0].material_override.albedo_texture.resource_path=="res://"+m.assets[2].runtime_path)
	m.state.activities.bouquet_colors=[0,1,2,3,4];m.state.handheld="bouquet";m.bay.refresh_hand();m.world.update_home(0,"res://"+m.assets[2].runtime_path)
	var actual:Array=colors_in(m.world.home_flowers);var expected:Array=m.world.layout.config.flower_hill.colors
	q.check("five_colour_bouquet_really_displayed_at_home",expected.all(func(t):return str(t).to_lower() in actual),actual.size())
	m.show_home();q.check("home_ui_names_mixed_bouquet",m.modal_box.find_children("*","Label",true,false).any(func(n):return "五彩花束" in n.text));m.close_modal()
	m.choose_bouquet(1);await m.get_tree().process_frame
	q.check("legacy_bouquet_choice_refreshes_hand_and_palette",not m.state.activities.has("bouquet_colors") and m.bay.bouquet_palette().size()==1 and m.bay.hand.get_child_count()>0)
	# Reproduce the old import with a valid v1 envelope that has no migration dictionary.
	var old_dir:String=m.store.directory;var old_import:String=m.store.import_directory;var fixture:Dictionary=m.state.duplicate(true)
	fixture.erase("migration");fixture.world_revision="bay_v1";fixture.gallery_preset=0;fixture.cards=[];fixture.position=[-238,4.4,226];fixture.safe_point=fixture.position.duplicate();fixture.interior=""
	var legacy=preload("res://scripts/save_store.gd").new();legacy.directory="user://qa_isolated/audit103_import_source";q.check("valid_0100_fixture_without_migration_field",legacy.write(fixture))
	m.store.directory="user://qa_isolated/audit103_import_target";m.store.import_directory=legacy.directory;await m.start_game(true)
	q.check("actual_start_import_without_migration_metadata",m.active_game and m.state.get("migration") is Dictionary and not m.state.migration.get("source_envelope_sha256","").is_empty() and m.world.inside_building(m.player.position)=="H01")
	q.check("import_then_save_and_read_extended_progress",m.save_game(false) and m.store.read().get("activities",{}).get("home_object","")=="frame")
	m.store.directory=old_dir;m.store.import_directory=old_import;m.player.enabled=false;m.player.program_driven=true
	await q.move_to(Vector3(-191,2.4,-191));var access:bool=await q.walk(Vector2(-194,-189.55),5)
	access=(await q.walk(Vector2(-194,-188.3),5)) and access;q.check("waterwheel_tea_pavilion_walkable_from_existing_dock",access,str(m.player.position))
	var wheel:Node3D=m.world.bay_props.get("waterwheel");var before:Basis=wheel.basis if is_instance_valid(wheel) else Basis.IDENTITY
	await m.get_tree().create_timer(.8).timeout;q.check("actual_streamed_waterwheel_rotates",is_instance_valid(wheel) and not before.is_equal_approx(wheel.basis))
	m.bay.open_activity("tea");var brew:Array=buttons(m.modal_box).filter(func(n):return n.text=="选茶 · 注水 · 等待");q.check("tea_stop_uses_real_brew_action",brew.size()==1)
	if not brew.is_empty():brew[0].pressed.emit();await m.get_tree().create_timer(4.2).timeout
	q.check("brewing_commits_drink_and_persistent_lantern",m.state.handheld=="drink" and m.state.activities.get("tea_lamp",false) and m.store.read().get("activities",{}).get("tea_lamp",false))
	q.sampling=false
	m.show_settings()
	var switches:Array=m.modal_box.find_children("*","CheckButton",true,false).filter(func(n):return n.text=="跑步使用切换模式")
	if not switches.is_empty():switches[0].button_pressed=true
	m.close_modal();m.player.enabled=true;var shift:=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=true;m.player._unhandled_input(shift)
	q.check("settings_toggle_run_works_in_actual_player",switches.size()==1 and m.player.run_toggle and m.player.run_latched)
	m.player._unhandled_input(shift);q.check("second_shift_returns_to_walk",not m.player.run_latched);m.player.enabled=false
	var original_size:Vector2i=m.get_window().size;var original_position:Vector2i=m.get_window().position
	m.apply_window_size(Vector2i(1600,900));await m.get_tree().create_timer(.3).timeout
	var screen:Rect2i=DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen());var cfg:=ConfigFile.new();var ok:bool=cfg.load("user://settings.cfg")==OK
	q.check("window_resolution_ui_setting_applies_and_persists",ok and cfg.get_value("settings","run_toggle",false) and cfg.get_value("settings","window_size",[])==m.settings.window_size and m.get_window().size.x<=screen.size.x and m.get_window().size.y<=screen.size.y)
	m.get_window().size=original_size;m.get_window().position=original_position;await m.get_tree().create_timer(.3).timeout
	await m.qa_capture("audit103_waterwheel_tea_finished",Vector3(-188,6.5,-200),Vector3(-189,2.8,-187))
	await m.qa_capture("audit103_coral_glass",Vector3(276,.8,426.4),Vector3(276,-3.8,426.0))
	q.finish()
