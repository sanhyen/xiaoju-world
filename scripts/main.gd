extends Node3D
const WorldScript=preload("res://scripts/world.gd")
const PlayerScript=preload("res://scripts/player.gd")
const Store=preload("res://scripts/save_store.gd")
const MapView=preload("res://scripts/bay_map_view.gd")
var world
var player
var store=Store.new()
var assets: Array=[]
var media: Dictionary={}
var programs:Array=[]
var state: Dictionary={"version":1,"game_version":"0.9.5-environment-development","position":[260,1,193],"yaw":0,"stamps":[],"photos":[],"discovered":[],"bouquet":0,"home_photo":0,"home_light":0,"home_card":"","home_shot":"","cards":[],"gallery_preset":0,"pb_page":0,"shots":[],"time":0,"weather":0,"safe_point":[0,1,80]}
var settings: Dictionary={"volume":0.65,"master_volume":1.0,"music_volume":1.0,"media_volume":1.0,"environment_volume":0.75,"interface_volume":0.65,"sensitivity":0.0025,"invert_y":false,"quality":1,"run_toggle":false,"window_size":[0,0]}
var sun: DirectionalLight3D
var environment: WorldEnvironment
var ui: CanvasLayer
var hud: Control
var zone_label: Label
var prompt: Label
var note_label: Label
var menu: Control
var modal: Control
var modal_box: VBoxContainer
var modal_return:Callable=Callable()
var visitor_return:Callable=Callable()
var current: Dictionary={}
var audio_player: AudioStreamPlayer
var interface_player:AudioStreamPlayer
var video: VideoStreamPlayer
var video_viewport: SubViewport
var watch_camera: Camera3D
var watch_screen: MeshInstance3D
var saved_screen_material: Material
var photo_mode:=false
var photo_saving:=false
var last_photo_capture:Dictionary={}
var active_game:=false
var update_timer:=0.0
var autosave_timer:=0.0
var notification_timer:=0.0
var current_zone: String=""
var font: Font
var qa_mode: String=""
var qa_ms: Array=[]
var qa_collect:=false
var qa_forced_draws:=0
var qa_last_usec:=0
var target_zone: Dictionary={}
var session_start:=Time.get_datetime_string_from_system()
var fresh_state: Dictionary
var evidence_root:="res://"
var current_screen_id:=""
var viewing_angle:=0
var transitioning:=false
var qa_driver
var environment_controls
var bay
var creative
var workshop_feedback
var transport
var environment_panel_open:=false
var route_draw_controller=preload("res://scripts/qa_draw_controller.gd").new()

func _ready():
	state.game_version=ProjectSettings.get_setting("application/config/version")
	var opening:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/opening_view_083.json"))
	state.position=opening.spawn.duplicate()
	state.yaw=atan2(float(opening.spawn[0])-float(opening.look_at[0]),float(opening.spawn[2])-float(opening.look_at[2]))
	fresh_state=state.duplicate(true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa="):qa_mode=arg.trim_prefix("--qa=")
	if qa_mode!="":store.directory="user://qa_isolated"
	if qa_mode.begins_with("desktop_"):store.directory="user://qa_isolated/"+qa_mode
	if qa_mode!="" and not OS.has_feature("editor"):
		evidence_root=OS.get_executable_path().get_base_dir()+"/qa_evidence/"
		DirAccess.make_dir_recursive_absolute(evidence_root+"screenshots")
		DirAccess.make_dir_recursive_absolute(evidence_root+"reports")
	load_settings()
	preload("res://scripts/audio_mix.gd").apply(settings)
	assets=JSON.parse_string(FileAccess.get_file_as_string("res://data/assets.json"))
	if FileAccess.file_exists("res://data/media.json"):media=JSON.parse_string(FileAccess.get_file_as_string("res://data/media.json"))
	if FileAccess.file_exists("res://data/programs.json"):
		var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/programs.json"))
		if catalog is Array:programs=catalog
	if programs.is_empty() and not media.is_empty():programs=[media]
	world=Node3D.new();world.set_script(WorldScript)
	world.phase="sample" if qa_mode.begins_with("sample") else "streamed"
	add_child(world)
	if world.layout!=null and qa_mode.is_empty():
		store.directory="user://save/open_v1"
		store.import_directory=""
	if world.layout!=null:
		var arrival:Vector3=world.layout.vector(world.layout.config.spawn)+Vector3(0,0.35,0)
		state.position=[arrival.x,arrival.y,arrival.z];state.safe_point=state.position.duplicate();state.world_revision="bay_v2"
		state.yaw=atan2(arrival.x,arrival.z-80.0)
		state.merge({"inventory":{},"activities":{},"handheld":"natural","playlist":[],"mix_recipe":{},"itinerary":[]},true)
		fresh_state=state.duplicate(true)
	font=world.b.font
	setup_environment()
	sun.shadow_enabled=int(settings.quality)>0
	player=CharacterBody3D.new();player.set_script(PlayerScript);player.home_world=world;add_child(player)
	player.program_driven=qa_mode=="tour"
	player.position=world.surface(float(fresh_state.position[0]),float(fresh_state.position[2]),0.6)
	player.yaw=float(fresh_state.yaw)
	player.sensitivity=settings.sensitivity;player.invert_y=settings.invert_y;player.run_toggle=bool(settings.run_toggle)
	if qa_mode.is_empty() and settings.window_size is Array and settings.window_size.size()==2 and int(settings.window_size[0])>0:apply_window_size(Vector2i(int(settings.window_size[0]),int(settings.window_size[1])),false)
	setup_media()
	setup_ui()
	environment_controls=preload("res://scripts/environment_controls.gd").new();add_child(environment_controls);environment_controls.setup(self)
	if world.layout!=null:
		creative=preload("res://scripts/creative_play110.gd").new();add_child(creative);creative.setup(self)
		transport=preload("res://scripts/creative_transport110.gd").new();add_child(transport);transport.setup(self)
		bay=preload("res://scripts/bay_life.gd").new();add_child(bay);bay.setup(self)
		workshop_feedback=preload("res://scripts/creative_feedback120.gd").new();add_child(workshop_feedback);workshop_feedback.setup(self)
	if world.layout!=null:
		var minimap=preload("res://scripts/bay_minimap.gd").new();hud.add_child(minimap);minimap.setup(self)
	show_main_menu()
	print("DEVICE ",JSON.stringify({"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"resolution":get_viewport().get_visible_rect().size,"version":ProjectSettings.get_setting("application/config/version")}))
	if qa_mode in ["public_release","public_restore"]:
		qa_driver=preload("res://scripts/public_release_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("creative110"):
		qa_driver=preload("res://scripts/creative110_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("design120"):
		if qa_mode=="design120_check":qa_driver=preload("res://scripts/design120_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("bay_"):
		qa_driver=preload("res://scripts/bay_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode=="route":route_run.call_deferred()
	elif qa_mode=="tour":
		qa_driver=preload("res://scripts/acceptance_tour.gd").new(self);qa_driver.run.call_deferred()
	elif qa_mode.begins_with("batch095_"):
		qa_driver=preload("res://scripts/batch095_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("batch094_"):
		qa_driver=preload("res://scripts/batch094_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("batch093_"):
		qa_driver=preload("res://scripts/batch093_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("release_evidence_"):
		qa_driver=preload("res://scripts/release_evidence_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("desktop_"):
		qa_driver=preload("res://scripts/desktop_input_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("opening_"):
		qa_driver=preload("res://scripts/opening_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("atmosphere_"):
		qa_driver=preload("res://scripts/atmosphere_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("wayfinding_"):
		qa_driver=preload("res://scripts/wayfinding_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("landform_"):
		qa_driver=preload("res://scripts/landform_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("finishing_"):
		qa_driver=preload("res://scripts/finishing_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("construction_"):
		qa_driver=preload("res://scripts/construction_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("paths_"):
		qa_driver=preload("res://scripts/paths_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("garden_"):
		qa_driver=preload("res://scripts/garden_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("horizon_"):
		qa_driver=preload("res://scripts/horizon_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("courts_"):
		qa_driver=preload("res://scripts/courts_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("arts_"):
		qa_driver=preload("res://scripts/arts_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("interiors_"):
		qa_driver=preload("res://scripts/interiors_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("records_"):
		qa_driver=preload("res://scripts/records_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("souvenir_"):
		qa_driver=preload("res://scripts/souvenir_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("pbzoom_"):
		qa_driver=preload("res://scripts/pb_zoom_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("photo_"):
		qa_driver=preload("res://scripts/photo_capture_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("homeart_"):
		qa_driver=preload("res://scripts/home_art_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("environment_"):
		qa_driver=preload("res://scripts/environment_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("nature_"):
		qa_driver=preload("res://scripts/nature_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("coast_"):
		qa_driver=preload("res://scripts/coast_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("cafe_"):
		qa_driver=preload("res://scripts/cafe_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("woodland_"):
		qa_driver=preload("res://scripts/woodland_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("station_"):
		qa_driver=preload("res://scripts/station_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("landmark_"):
		qa_driver=preload("res://scripts/landmark_qa.gd").new();qa_driver.run.call_deferred(self)
	elif qa_mode.begins_with("home_state_"):preload("res://scripts/home_art_state_qa.gd").run.call_deferred(self)
	elif qa_mode.begins_with("art_"):art_run.call_deferred()
	elif qa_mode.begins_with("venues_"):preload("res://scripts/round3_qa.gd").run.call_deferred(self)
	elif qa_mode.begins_with("cold_"):cold_probe.call_deferred()
	elif qa_mode!="":qa_run.call_deferred()

func setup_environment():
	environment=WorldEnvironment.new();var e:=Environment.new();environment.environment=e
	e.background_mode=Environment.BG_SKY
	var sky:=Sky.new();var sky_mat:=ShaderMaterial.new();sky_mat.shader=load("res://assets/materials/coastal_sky.gdshader")
	sky_mat.set_shader_parameter("radiance_decode",2.0 if RenderingServer.get_current_rendering_method()=="mobile" else 1.0)
	sky.radiance_size=Sky.RADIANCE_SIZE_256;sky.process_mode=Sky.PROCESS_MODE_QUALITY
	sky.sky_material=sky_mat;e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("e7ede0");e.ambient_light_energy=0.45
	# 078 candidate: match distant haze to the actual sky, with a long transition.
	# Near playable landmarks keep low haze; only background water reaches full extinction.
	e.fog_enabled=true;e.fog_mode=Environment.FOG_MODE_DEPTH;e.fog_depth_begin=300;e.fog_depth_end=4800;e.fog_density=1.0;e.fog_aerial_perspective=1.0;e.fog_light_color=Color("b9d4d1");e.fog_sky_affect=0
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	add_child(environment)
	sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-44,-28,0);sun.light_color=Color("fff4dc");sun.light_energy=0.92
	sun.shadow_enabled=true;sun.directional_shadow_max_distance=110;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1=0.10;sun.directional_shadow_split_2=0.28;sun.directional_shadow_split_3=0.58
	sun.directional_shadow_blend_splits=true
	add_child(sun)

func setup_media():
	audio_player=AudioStreamPlayer.new();audio_player.bus="Music";add_child(audio_player)
	interface_player=AudioStreamPlayer.new();interface_player.bus="Interface";interface_player.volume_db=-16;add_child(interface_player)
	var click:=AudioStreamWAV.new();click.format=AudioStreamWAV.FORMAT_16_BITS;click.mix_rate=22050
	var samples:=PackedByteArray();samples.resize(1544*2)
	for index in 1544:
		var envelope:=sin(PI*index/1544.0)*exp(-index/500.0)
		samples.encode_s16(index*2,int(sin(index*TAU*880/22050.0)*envelope*4500))
	click.data=samples;interface_player.stream=click
	video_viewport=SubViewport.new();video_viewport.size=Vector2i(1280,720);video_viewport.disable_3d=true
	video_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(video_viewport)
	video=VideoStreamPlayer.new();video.expand=true;video.size=Vector2(1280,720);video_viewport.add_child(video)
	video.bus="Media"
	video.finished.connect(func():notify("播放结束。可重新播放或返回探索。"))
	watch_camera=Camera3D.new();watch_camera.near=0.3;watch_camera.far=12000;add_child(watch_camera)

func setup_ui():
	ui=CanvasLayer.new();add_child(ui)
	var theme:=Theme.new();theme.default_font=font;theme.default_font_size=23
	var style:=StyleBoxFlat.new();style.bg_color=Color("365c58");style.corner_radius_top_left=5;style.corner_radius_bottom_right=5
	style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=12;style.content_margin_bottom=12
	theme.set_stylebox("normal","Button",style)
	var hover:=style.duplicate();hover.bg_color=Color("53776e");theme.set_stylebox("hover","Button",hover)
	var pressed:=style.duplicate();pressed.bg_color=Color("294b49");theme.set_stylebox("pressed","Button",pressed)
	theme.set_color("font_color","Button",Color("f5eedc"))
	theme.set_color("font_color","Label",Color("f3ead6"))
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.theme=theme;ui.add_child(hud)
	zone_label=Label.new();zone_label.position=Vector2(40,28);zone_label.add_theme_font_size_override("font_size",29);zone_label.add_theme_color_override("font_shadow_color",Color("28413c"));zone_label.add_theme_constant_override("shadow_offset_x",1);zone_label.add_theme_constant_override("shadow_offset_y",2);hud.add_child(zone_label)
	var controls:=Label.new();controls.text="WASD 行走 · Shift 跑步 · 空格 二段跳 · E/F 互动 · X 姿态 · M 地图 · O/V 视角 · B 背包 · Tab 旅行册 · P 拍照 · F6 昼夜天气 · Esc 菜单";controls.position=Vector2(40,1050);controls.add_theme_font_size_override("font_size",17);hud.add_child(controls)
	prompt=Label.new();prompt.position=Vector2(450,932);prompt.size=Vector2(1020,45);prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;prompt.add_theme_font_size_override("font_size",28);hud.add_child(prompt)
	note_label=Label.new();note_label.position=Vector2(520,75);note_label.size=Vector2(1000,50);note_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(note_label)
	# These labels sit directly over bright paving/sand as well as dark interiors.
	for readout in [controls,prompt,note_label]:
		readout.add_theme_color_override("font_outline_color",Color("243b35"))
		readout.add_theme_constant_override("outline_size",4)
		readout.add_theme_color_override("font_shadow_color",Color(0.08,0.13,0.12,0.7))
		readout.add_theme_constant_override("shadow_offset_y",2)
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.theme=theme;ui.add_child(menu)
	modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.theme=theme;ui.add_child(modal);modal.hide()

func button(parent: Node,title: String,callback: Callable) -> Button:
	var btn:=Button.new();btn.text=title;btn.custom_minimum_size=Vector2(0,52);btn.pressed.connect(func():
		if interface_player!=null:interface_player.play()
		callback.call())
	if qa_mode=="tour":btn.mouse_filter=Control.MOUSE_FILTER_IGNORE;btn.focus_mode=Control.FOCUS_NONE
	parent.add_child(btn);return btn

func label(parent: Node,words: String,font_size: int=24) -> Label:
	var l:=Label.new();l.text=words;l.add_theme_font_size_override("font_size",font_size);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(l);return l

func panel(parent: Node,rect: Rect2,color: Color) -> PanelContainer:
	var p:=PanelContainer.new();p.position=rect.position;p.size=rect.size
	var s:=StyleBoxFlat.new();s.bg_color=color;s.content_margin_left=34;s.content_margin_right=34;s.content_margin_top=24;s.content_margin_bottom=24
	s.corner_radius_top_left=10;s.corner_radius_bottom_right=10;p.add_theme_stylebox_override("panel",s);parent.add_child(p);return p

func clear(node: Node):
	for child in node.get_children():node.remove_child(child);child.queue_free()

func show_main_menu():
	active_game=false
	if environment_controls!=null:environment_controls.leave()
	if modal!=null:modal.hide()
	if transport!=null:transport.release_for_travel()
	clear(menu);menu.show();hud.hide();player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	watch_camera.position=Vector3(42,26,112) if world.layout!=null else Vector3(32,17,93);watch_camera.look_at(Vector3(0,18,40) if world.layout!=null else Vector3(0,9,40));watch_camera.current=true
	var p:=panel(menu,Rect2(90,178,520,700),Color(0.09,0.19,0.19,0.91));var v:=VBoxContainer.new();v.add_theme_constant_override("separation",14);p.add_child(v)
	label(v,"X I A O J U  W O R L D",19)
	label(v,"小 鞠 世 界",52)
	label(v,"海风与星光\n鞠婧祎主题探索乐园",26)
	label(v,"持续制作 "+str(ProjectSettings.get_setting("application/config/version")).trim_suffix("-development")+" · 非官方同人项目",18)
	button(v,"开始探索",func():start_game(false))
	var cont:=button(v,"继续上次旅行",func():start_game(true));cont.disabled=store.read().is_empty()
	button(v,"设置",show_settings)
	button(v,"素材与关于",show_sources)
	button(v,"退出",func():get_tree().quit())

func start_game(continue_saved: bool):
	if transitioning:return
	if transport!=null:transport.reset_session()
	if bay!=null:bay.reset_session()
	transitioning=true;player.enabled=false
	player.ignore_focus_loss=qa_mode!="" and not qa_mode.begins_with("desktop_")
	player.stand_up()
	state=fresh_state.duplicate(true)
	if continue_saved:
		var loaded:=store.read()
		if not loaded.is_empty():
			state.merge(loaded,true)
			if not loaded.has("world_revision"):state.erase("world_revision")
	if world.layout!=null:
		state=preload("res://scripts/save_migration.gd").migrate(state,world)
		if store.imported_legacy:
			var imported:Dictionary=state.get("migration",{}) if state.get("migration",{}) is Dictionary else {}
			imported["source_envelope_sha256"]=store.import_source_checksum;imported["source_file"]=store.import_source_file.get_file();state["migration"]=imported
	if world.layout!=null:state=preload("res://scripts/creative_migration110.gd").migrate(state,world)
	if creative!=null:creative.initialize_state()
	var p: Array=state.position
	var desired:=Vector3(float(p[0]),float(p[1]),float(p[2]))
	menu.hide();hud.show()
	notify("正在准备旅行地点……")
	if not await world.prepare_region(desired):
		transitioning=false;open_modal("旅行地点暂不可用");label(modal_box,"区域资源准备失败，请返回菜单后重试。");button(modal_box,"回到菜单",show_main_menu);return
	player.position=preload("res://scripts/creative_migration110.gd").resolve_after_stream(state,world,desired)
	if state.get("migration110") is Dictionary and not state.migration110.get("changes",[]).is_empty() and player.position.distance_to(desired)>.35:
		state.migration110.changes.append({"reason":"nearest_valid_surface_after_stream_ready","from":[desired.x,desired.y,desired.z],"to":[player.position.x,player.position.y,player.position.z]})
	player.yaw=float(state.get("yaw",0));player.velocity=Vector3.ZERO
	environment_controls.weather=clampi(int(state.get("weather",0)),0,2)
	player.reset_jump_state()
	if bay!=null:bay.defaults()
	set_time(int(state.time))
	world.update_home(int(state.bouquet),"res://"+assets[int(state.home_photo)%assets.size()].runtime_path)
	world.set_home_light(int(state.get("home_light",0)))
	world.set_gallery_preset(int(state.get("gallery_preset",0)));sync_home_memories()
	menu.hide();modal.hide();hud.show();active_game=true;player.camera.current=true
	player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	transitioning=false
	if continue_saved and bay!=null:await bay.boats.resume_active()
	if continue_saved and transport!=null:await transport.resume_active()
	notify("欢迎来到小鞠世界。沿路探索，按 M 查看双岛导览。")

func open_modal(title: String,width: float=1050,return_action:Callable=Callable()):
	if creative!=null:creative.pause_puzzle()
	environment_panel_open=title=="山海环境 · 昼夜与天气"
	modal_return=return_action if return_action.is_valid() else visitor_return
	clear(modal);modal.show();player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var shade:=ColorRect.new();shade.color=Color(0.03,0.09,0.09,0.48);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(shade)
	var p:=panel(modal,Rect2((1920-width)/2,100,width,875),Color(0.08,0.18,0.18,0.97))
	modal_box=VBoxContainer.new();modal_box.add_theme_constant_override("separation",12);p.add_child(modal_box)
	var header:=HBoxContainer.new();modal_box.add_child(header)
	var heading:=label(header,title,31);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(header,"返回",return_from_modal)

func return_from_modal():
	if modal_return.is_valid():
		var callback:=modal_return;modal_return=Callable();callback.call()
	else:close_modal()

func dismiss_environment_panel():
	environment_panel_open=false;modal_return=Callable();visitor_return=Callable();modal.hide()
	if environment_controls.overview:
		environment_controls.camera.current=true;player.enabled=false;hud.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	elif active_game:
		environment_controls.restore_current_camera();hud.show()
	else:show_main_menu()

func close_modal():
	if creative!=null:creative.pause_puzzle()
	if environment_panel_open:
		dismiss_environment_panel();return
	modal_return=Callable();visitor_return=Callable()
	stop_media("close_modal");modal.hide();photo_mode=false
	if active_game:
		if environment_controls.overview:
			environment_controls.camera.current=true;player.enabled=false;hud.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		else:
			environment_controls.restore_current_camera();hud.show()
	else:show_main_menu()

func _unhandled_input(event):
	if transport!=null and transport.handle_input(event):get_viewport().set_input_as_handled();return
	if creative!=null and creative.handle_input(event):get_viewport().set_input_as_handled();return
	if environment_controls!=null and environment_controls.handle_input(event):get_viewport().set_input_as_handled();return
	if qa_mode=="tour":return # Program-driven long QA has its own controls; avoid accidental desktop input.
	if bay!=null and bay.handle_input(event):get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_O:
				if active_game and not modal.visible:environment_controls.enter()
			KEY_F6:
				if active_game and not modal.visible:environment_controls.panel()
			KEY_ESCAPE:
				if modal.visible:return_from_modal()
				elif photo_mode:close_modal()
				elif active_game:show_pause()
			KEY_M:
				if active_game:
					if modal.visible:close_modal()
					else:show_map()
			KEY_TAB:
				if active_game:show_collection()
			KEY_E:
				if active_game and player.enabled and not modal.visible and not environment_controls.overview and not current.is_empty():activate(current)
			KEY_P:
				if active_game and not modal.visible:enter_photo_mode()
			KEY_F12:
				if active_game:save_photo()
			KEY_F5:
				if active_game:save_game()

func _process(delta):
	if qa_driver!=null:qa_driver.sample(delta)
	if world!=null and world.streamer!=null and player!=null and watch_camera!=null:
		var points:Array[Vector3]=[player.position]
		if watch_camera.current:points.append(watch_camera.position)
		if environment_controls!=null and (environment_controls.overview or environment_controls.follow):points.append(environment_controls.camera_target())
		if transport!=null:points.append_array(transport.anchor_points())
		world.streamer.set_foci(points)
	if world!=null and player!=null:world.update_ambience(watch_camera.position if watch_camera.current else player.position,delta)
	if qa_collect:
		if qa_mode=="route":route_draw_controller.sample()
		var now:=Time.get_ticks_usec()
		if qa_last_usec>0:qa_ms.append((now-qa_last_usec)/1000.0)
		qa_last_usec=now
	else:qa_last_usec=0
	if not active_game or transitioning:return
	update_timer+=delta;autosave_timer+=delta
	if notification_timer>0:
		notification_timer-=delta
		if notification_timer<=0:note_label.text=""
	if environment_controls!=null and environment_controls.overview:
		prompt.text="";return
	if (transport==null or not transport.is_riding()) and (bay==null or bay.boats==null or bay.boats.kind.is_empty()) and ((world.layout!=null and (not world.layout.within_bounds(player.position))) or (world.layout==null and (player.position.y < -16 or absf(player.position.x)>472 or player.position.z < -453 or (player.position.z>357 and not world.within_pier(player.position))))):
		return_safe();return
	if update_timer<0.15:return
	update_timer=0
	var closest:Dictionary={};var distance:=4.0
	for interaction in world.interactions:
		if interaction.kind in ["bay_activity","bay_vehicle","bay_pick","bay_flower"]:continue
		var dd:float=player.position.distance_to(interaction.pos)
		if dd<distance:closest=interaction;distance=dd
	current=closest
	prompt.text="E  "+current.title if not current.is_empty() else ""
	if player.water_edge_blocked and current.is_empty():prompt.text="前方水深 · 可沿浅滩行走，或乘船继续出海"
	var zone:Dictionary=zone_for_position(player.position)
	if current_zone!=zone.id:
		current_zone=zone.id
		if zone.id not in state.discovered:state.discovered.append(zone.id);notify("发现新区域 · "+zone.name)
	zone_label.text=zone.name+"\n"+zone.subtitle
	if not target_zone.is_empty():zone_label.text+="\n前往 "+target_zone.name+" · "+str(int(Vector2(player.position.x-target_zone.x,player.position.z-target_zone.z).length()))+" m"
	if player.is_on_floor() and (transport==null or not transport.is_riding()) and world.inside_building(player.position)=="" and (world.layout.shallow_or_dry(player.position) if world.layout!=null else player.position.z<330):
		state.safe_point=[player.position.x,player.position.y+0.15,player.position.z]
	if autosave_timer>45 and player.is_on_floor() and not modal.visible:save_game(false);autosave_timer=0

func zone_for_position(point:Vector3)->Dictionary:
	if world.layout!=null:
		if point.z>430 and point.x<25 and point.x> -145:return {"id":"ISLAND_02","name":"星夜萤火森屿","subtitle":"森林、树冠与岩石温泉 · 双岛栈道环线"}
		var id:String=world.inside_building(point)
		var zone:String=world.layout.venues[id].zone if world.layout.venues.has(id) else world.layout.zone_id(point)
		for item in world.spec.zones:
			if item.id==zone:return item
	# Venue membership wins. The northern mountain/waterfall band belongs to Z08;
	# nearest-centre classification incorrectly unlocked Z06 at the northeast waterfall.
	var desired:=""
	var building:String=world.inside_building(point)
	if not building.is_empty():
		for item in world.spec.buildings:
			if item.id==building:desired=str(item.zone);break
	if desired.is_empty() and point.z< -225:desired="Z08"
	var nearest:Dictionary=world.spec.zones[0];var distance:=INF
	for zone in world.spec.zones:
		if zone.id==desired:return zone
		var separation:float=Vector2(point.x-zone.x,point.z-zone.z).length_squared()
		if separation<distance:distance=separation;nearest=zone
	return nearest

func notify(words: String):
	if note_label!=null:note_label.text=words;notification_timer=6
	print("NOTICE ",words)

func activate(interaction: Dictionary):
	match interaction.kind:
		"creative110":creative.activity(interaction)
		"creative_cable":notify("走近站台按 F 乘缆车，X 切换观景姿态。")
		"info":
			open_modal(interaction.data.get("title",interaction.title));label(modal_box,interaction.data.get("body",""),24)
		"bay_hidden":bay.details.hidden_view(int(interaction.data.index))
		"bay_album":bay.album(interaction.data.venue)
		"bay_boat":if bay.boats!=null:bay.boats.choose(int(interaction.data.dock))
		"bay_swing","bay_netbed":if bay.boats!=null:bay.boats.rest(interaction)
		"enter":notify("入口已开放，直接向前走入。")
		"stamp":
			if interaction.id not in state.stamps:state.stamps.append(interaction.id);save_game(false);notify("已收集 · "+interaction.data.name+"纪念章")
			else:notify("这枚纪念章已在你的收藏中。")
		"photo":show_photo(int(interaction.data.index))
		"gallery":show_gallery()
		"audio":show_program_selector("B09" if interaction.id.begins_with("B09") else "N09" if interaction.id.begins_with("N09") else "B03",true)
		"video":show_program_selector(interaction.data.get("screen","B06"),false)
		"dance":show_dance()
		"pb":show_pb(int(state.pb_page))
		"dual106":bay.dual.open_action(str(interaction.data.topic))
		"bay_public_boat":bay.boats.public_panel(str(interaction.data.source))
		"redesign":bay.workshops.open_action(str(interaction.data.topic),true)
		"bay_moored":bay.boats.choose_moored(int(interaction.data.index))
		"life_house","life_farm","life_pasture","life_pool":bay.village.open_action(interaction)
		"map":
			if interaction.id=="B13_map":preload("res://scripts/visitor_services.gd").new().show(self)
			else:show_map()
		"collection":
			if interaction.id.begins_with("B11"):show_souvenirs()
			else:show_collection()
		"flowers":show_flowers()
		"home":show_home()
		"save":save_game()
		"sit":
			var anchor:Vector3=interaction.data.get("seat",interaction.pos)
			player.sit_at(anchor,interaction.data.get("yaw",PI));notify("坐下歇一会儿。按移动键起身。")
		"photo_mode":enter_photo_mode()
		"set_archive":show_set_archive()
		"time":set_time((int(state.time)+1)%3);notify("已切换光照预设。")
		"venue_light":
			var venue:String=interaction.data.venue
			world.set_venue_lighting(venue,int(world.stage_presets.get(venue,0))+1)
			notify("已切换本馆灯光。")

func show_set_archive():
	open_modal("光影庭院 · 原创布景",1000)
	label(modal_box,"短廊、窗洞和景框为本项目原创设计，不对应未经核验的真实剧组场景。",24)
	label(modal_box,"可在庭院取景，或查看已有本地影像的标题、档案日期和来源。作品资料与这里的原创建筑分别标明。",22)
	button(modal_box,"进入庭院取景",func():close_modal();enter_photo_mode())
	button(modal_box,"查看本地影像节目",func():show_program_selector("B06",false);modal_return=show_set_archive)
	button(modal_box,"素材与来源",func():show_sources();modal_return=show_set_archive)

func show_photo(index: int,return_action:Callable=Callable()):
	index=posmod(index,assets.size())
	var a:Dictionary=assets[index]
	open_modal("光影收藏 · %02d / %02d" % [index+1,assets.size()],1220,return_action)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",30);modal_box.add_child(row)
	var tex:=TextureRect.new();tex.texture=load("res://"+a.runtime_path);tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tex.custom_minimum_size=Vector2(620,670);row.add_child(tex)
	tex.mouse_filter=Control.MOUSE_FILTER_STOP;tex.tooltip_text="点击放大；滚轮缩放，拖动查看"
	tex.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			show_image_zoom(tex.texture,"影像细节",func():show_photo(index,return_action)))
	var text:=VBoxContainer.new();text.custom_minimum_size.x=430;row.add_child(text)
	label(text,"小鞠世界 · 原创演示图",28)
	label(text,"创作者："+a.publisher+"\n制作日期："+a.archive_publish_time+"\n原图：%d × %d\n原创几何海景，保留画幅比例" % [a.width,a.height],21)
	label(text,"来源：本项目程序生成的演示图。\n许可：MIT。这里不包含真人照片。",20)
	button(text,"查看素材说明",func():OS.shell_open(a.post_url))
	button(text,"加入我的收藏",func():
		if a.asset_id not in state.photos:state.photos.append(a.asset_id)
		save_game(false);notify("已收藏这张照片。"))
	button(text,"上一件",func():show_photo(index-1,return_action));button(text,"下一件",func():show_photo(index+1,return_action))

func show_gallery():
	open_modal("光影画廊 · 选择展览顺序")
	label(modal_box,"切换实体展墙上的作品顺序。原十二件影像从档案卡继续访问；现场四季展陈和生活影像分别分流。",23)
	for item in [["春樱展厅",0],["夏海展厅",1],["秋林展厅",2],["冬雪展厅",3]]:
		var preset:int=item[1]
		button(modal_box,item[0],func():state.gallery_preset=preset;world.set_gallery_preset(preset);bay.details.set_season(preset);save_game(false);close_modal();notify("已更新画廊展览。"))
	button(modal_box,"查看作品与来源",func():show_photo(0))

func program_for(id:String)->Dictionary:
	for item in programs:
		if item.get("asset_id","")==id:return item
	return {}

func show_program_selector(venue:String,audio_only:bool=false):
	open_modal("试听曲目" if audio_only else "场馆节目册",1180)
	label(modal_box,"选择原创演示节目，或在个人导入库中播放你自己的素材。",22)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1080,575);modal_box.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",16);scroll.add_child(list)
	for item in programs:
		if ("B06" if venue=="B06_OUT" else venue) not in item.get("venues",["B03","B06","B08","B09","B10","N09"]):continue
		if str(item.get("audio","" if audio_only else item.get("video",""))).is_empty() and audio_only:continue
		var record:Dictionary=item
		var title:String=str(record.get("display_title",record.title))
		button(list,("试听 · " if audio_only else "观看 · ")+title,func():
			if audio_only:show_audio(str(record.asset_id))
			else:show_video(venue,str(record.asset_id)))
		label(list,"制作日期："+str(record.get("archive_publish_time",record.get("publish_time","未记录")))+" · 创作者："+str(record.get("publisher","鞠婧祎_Official")),19)
	label(modal_box,"本版节目是原创几何海景短片与程序器乐，用于体验场馆播放功能。",19)

func show_audio(program_id:String="sunset"):
	var record:=program_for(program_id)
	if record.is_empty():open_modal("曲目不可用");label(modal_box,"这条曲目不在本地节目册中。");return
	open_modal("唱片试听 · "+str(record.title))
	label(modal_box,"本地节目音轨\n制作日期："+str(record.get("archive_publish_time",record.get("publish_time","未记录"))),25)
	var audio_path:String=str(record.get("audio",""))
	if audio_path.is_empty() or not ResourceLoader.exists("res://"+audio_path):
		label(modal_box,"本地音频缺失。请从素材导入目录恢复资源。");return
	stop_media("begin_audio:"+program_id);audio_player.stream=load("res://"+audio_path);audio_player.volume_db=linear_to_db(maxf(float(settings.volume),0.0001));audio_player.stream_paused=false;audio_player.play()
	button(modal_box,"暂停 / 继续",func():audio_player.stream_paused=not audio_player.stream_paused)
	button(modal_box,"从头播放",func():audio_player.play())
	button(modal_box,"收藏试听条目",func():
		if program_id not in state.photos:state.photos.append(program_id)
		save_game(false);notify("已收藏试听条目。"))
	volume_slider(modal_box)
	label(modal_box,"声音工作室可自行跟唱。默认不启用麦克风，不录音。\n关闭窗口后停止播放。",21)

func show_video(screen_id: String,program_id:String="sunset"):
	stop_media("begin_video:"+program_id)
	player.enabled=false
	var record:=program_for(program_id)
	if record.is_empty():open_modal("影片不可用");label(modal_box,"这条节目不在本地节目册中。");return
	for item in world.spec.buildings:
		if item.id==screen_id:
			if not await world.prepare_region(world.surface(item.x,item.z)):
				open_modal("暂时无法观影");label(modal_box,"场馆准备失败，请返回后重试。");return
			break
	var video_path:String=str(record.get("video",""))
	if video_path.is_empty() or not ResourceLoader.exists("res://"+video_path):
		open_modal("影片不可用");label(modal_box,"本地影片缺失，请恢复素材后重试。");return
	if not world.screens.has(screen_id):return
	modal_return=Callable()
	clear(modal);modal.show();player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;hud.hide()
	var p:=panel(modal,Rect2(405,874,1110,170),Color(0.07,0.15,0.16,0.92));var box:=VBoxContainer.new();p.add_child(box)
	label(box,str(record.get("display_title",record.title))+"   |   本地播放",22)
	var row:=HBoxContainer.new();box.add_child(row)
	button(row,"暂停 / 继续",func():video.paused=not video.paused)
	button(row,"重新播放",func():video.stop();video.play())
	button(row,"切换机位",func():viewing_angle=(viewing_angle+1)%3;set_viewing_angle())
	if screen_id=="B10":button(row,"舞台灯光",func():world.set_venue_lighting("B10",int(world.stage_presets.B10)+1))
	if screen_id in ["B06","B06_OUT"]:button(row,"内厅 / 星空外幕",switch_cinema_screen)
	button(row,"退出观看",close_modal)
	var vol:=HSlider.new();vol.min_value=0;vol.max_value=1;vol.step=0.01;vol.value=settings.volume;vol.custom_minimum_size=Vector2(650,28);box.add_child(vol)
	vol.value_changed.connect(func(value):settings.volume=value;video.volume_db=linear_to_db(maxf(value,0.0001));save_settings())
	watch_screen=world.screens[screen_id];saved_screen_material=watch_screen.material_override
	var mat:=StandardMaterial3D.new();mat.albedo_texture=video_viewport.get_texture();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture_force_srgb=true
	watch_screen.material_override=mat
	video_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	video.stream=load("res://"+video_path);video.volume_db=linear_to_db(maxf(float(settings.volume),0.0001));video.play()
	current_screen_id=screen_id;viewing_angle=0;video.paused=false
	set_viewing_angle()

func switch_cinema_screen():
	var target:String="B06_OUT" if current_screen_id=="B06" else "B06"
	if not world.screens.has(target):return
	var material:Material=watch_screen.material_override
	watch_screen.material_override=saved_screen_material
	watch_screen=world.screens[target];saved_screen_material=watch_screen.material_override;watch_screen.material_override=material;current_screen_id=target;set_viewing_angle()

func set_viewing_angle():
	if not is_instance_valid(watch_screen):return
	var distances:=[Vector3(0,-0.3,15),Vector3(-6,0.5,17),Vector3(6,0.5,17)]
	if current_screen_id.begins_with("THEME_"):distances=[Vector3(0,-.1,6),Vector3(-1.6,.2,6.7),Vector3(1.6,.2,6.7)]
	if current_screen_id=="B08":distances=[Vector3(0,-0.2,9),Vector3(-3,0.2,10),Vector3(3,0.2,10)]
	watch_camera.position=watch_screen.global_position+distances[viewing_angle]
	watch_camera.look_at(watch_screen.global_position);watch_camera.current=true

func stop_media(reason:String="script_step"):
	if qa_mode=="tour" and audio_player!=null and audio_player.playing:
		print("QA_MEDIA_STOP_TRACE ",JSON.stringify({"reason":reason,"phase":qa_driver.phase if qa_driver!=null else "","position_s":audio_player.get_playback_position(),"stream":audio_player.stream.resource_path if audio_player.stream!=null else "","stack":get_stack()}))
	if audio_player!=null:audio_player.stop();audio_player.stream=null
	if video!=null:video.stop();video.stream=null;video_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(watch_screen):watch_screen.material_override=saved_screen_material
	watch_screen=null

func show_dance():
	open_modal("律动排练馆")
	label(modal_box,"观看原创演示短片，查看几何海景，并切换本馆灯光。",24)
	button(modal_box,"选择排练影像",func():show_program_selector("B08",false))
	button(modal_box,"查看演示画作",func():show_photo(5))
	button(modal_box,"观看已导入 MV",func():show_video("B08"))
	button(modal_box,"切换排练灯光",func():world.set_venue_lighting("B08",int(world.stage_presets.B08)+1))

func show_pb(page: int):
	var max_page:int=assets.size()+state.shots.size()
	page=clampi(page,0,max_page);state.pb_page=page
	open_modal("拾光纪念册 · %d / %d" % [page+1,max_page+1],1340)
	var spread:=HBoxContainer.new();spread.name="PBSpread";spread.custom_minimum_size.y=630;modal_box.add_child(spread)
	if page==0:
		var cover:=VBoxContainer.new();cover.custom_minimum_size.x=400;spread.add_child(cover)
		label(cover,"拾 光",65);label(cover,"海风与星光\n原创几何海景\n我的旅行纪念册",28)
		label(cover,"原创演示画作与我的旅行风景。",20)
		pb_image(spread,0,720,page)
	elif page>assets.size():
		var filename:String=str(state.shots[page-assets.size()-1]).get_file()
		var file_path:=photo_directory()+"/"+filename
		var loaded:=Image.load_from_file(file_path) if FileAccess.file_exists(file_path) else null
		if loaded!=null and not loaded.is_empty():
			var column:=VBoxContainer.new();spread.add_child(column)
			var shot:=TextureRect.new();shot.name="PBPersonalImage";shot.texture=ImageTexture.create_from_image(loaded);shot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;shot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;shot.custom_minimum_size=Vector2(1190,575);column.add_child(shot)
			var open_button:=button(column,"放大这张旅行风景",func():show_image_zoom(shot.texture,"我的旅行风景",func():show_pb(page)))
			open_button.name="PBPersonalOpen"
		else:label(spread,"这张风景照片已不在本机照片目录中。其收藏记录仍然保留。",24)
	elif page%2==1:
		pb_image(spread,(page-1)%assets.size(),570,page);pb_image(spread,page%assets.size(),570,page)
	else:pb_image(spread,page-1,1190,page)
	var row:=HBoxContainer.new();modal_box.add_child(row)
	button(row,"上一页",func():show_pb(maxi(page-1,0)))
	button(row,"下一页",func():show_pb(mini(page+1,max_page)))
	if page>assets.size():button(row,"我的风景照片",func():OS.shell_open(ProjectSettings.globalize_path(photo_directory())))
	button(row,"保存阅读位置",func():save_game())

func pb_image(parent: Node,index: int,width: float,page:int):
	var column:=VBoxContainer.new();column.custom_minimum_size.x=width;parent.add_child(column)
	var image:=TextureRect.new();image.texture=load("res://"+assets[index].runtime_path);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(width,575);column.add_child(image)
	var open_button:=button(column,"放大影像 · %02d" % [index+1],func():
		show_image_zoom(image.texture,"纪念册影像 · %02d" % [index+1],func():show_pb(page),func():show_photo(index,func():show_pb(page))))
	open_button.name="PBImageOpen_"+str(index)

func show_image_zoom(texture:Texture2D,title:String,back_action:Callable,source_action:Callable=Callable()):
	open_modal(title,1340,back_action)
	var viewer:=preload("res://scripts/image_zoom.gd").new();viewer.name="ImageZoom";viewer.texture=texture;viewer.custom_minimum_size=Vector2(1250,550);viewer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;modal_box.add_child(viewer)
	var row:=HBoxContainer.new();modal_box.add_child(row)
	button(row,"缩小",func():viewer.set_zoom_at(viewer.zoom/1.25,viewer.size/2))
	button(row,"放大",func():viewer.set_zoom_at(viewer.zoom*1.25,viewer.size/2))
	var fit_button:=button(row,"完整图片",viewer.reset_view);fit_button.name="ImageZoomFit"
	var ratio:=label(row,"1.00 ×",21);ratio.custom_minimum_size.x=110
	viewer.zoom_changed.connect(func(value):ratio.text="%.2f ×" % value)
	if source_action.is_valid():button(row,"查看这张图的来源",source_action)
	label(modal_box,"滚轮缩放 · 按住左键拖动 · 双击恢复完整图片 · Esc 返回上一页",20)

func show_map():
	preload("res://scripts/bay_map_panel.gd").new().build(self)

func show_map_choices(places:Array):
	open_modal("请选择地点与楼层")
	label(modal_box,"这些地点在平面地图中靠得很近，选择名称可准确前往对应楼层。",23)
	for place in places:
		var selected:Dictionary=place
		button(modal_box,str(place.name),func():target_zone=selected;show_destination(selected))
	button(modal_box,"返回地图",show_map)

func show_destination(z:Dictionary):
	open_modal(str(z.name))
	label(modal_box,str(z.get("subtitle","已选定目的地，可直接前往安全落脚点。")),26)
	var travel:Button=button(modal_box,"立即前往",func():await teleport_zone(z);close_modal();save_game(false));travel.disabled=not z.get("enabled",true)
	button(modal_box,"标记并继续步行",func():target_zone=z;close_modal())
	button(modal_box,"返回地图",show_map)

func teleport_zone(z:Dictionary):
	if transitioning or not z.get("enabled",true):return
	transitioning=true;player.enabled=false
	if transport!=null:transport.release_for_travel()
	player.stand_up()
	var desired:Vector3
	if z.has("safe"):desired=preload("res://scripts/location_registry.gd").destination(world.spec,z)+Vector3.UP*.35
	elif world.layout.venues.has(str(z.id)):
		var v:Dictionary=world.layout.venues[z.id];desired=Vector3(v.x,v.floor_y+.35,v.z+v.d*.5+1.6)
	else:desired=world.layout.safe_point(z.id)
	if bay!=null:
		bay.vehicles.dismount(true)
		if not bay.boats.kind.is_empty():bay.boats.moor_current(bay.boats.nearest_shore());bay.boats.leave_for_travel()
	notify("正在准备 "+str(z.name)+"……")
	if not await world.prepare_region(desired):transitioning=false;notify("目的地暂未准备好，请重试。");return
	player.position=world.safe_ground_position(desired);player.velocity=Vector3.ZERO;state.safe_point=[player.position.x,player.position.y,player.position.z];transitioning=false

func show_collection():
	open_modal("我的山海纪念册")
	label(modal_box,"区域纪念章：%d / 9\n已收藏条目：%d\n风景照片：%d" % [state.stamps.size(),state.photos.size(),state.shots.size()],30)
	for z in world.spec.zones:label(modal_box,("● " if z.id in state.stamps else "○ ")+z.name,21)
	for view in world.layout.config.get("hidden_views",[]):
		if view.card in state.cards:label(modal_box,"● 原创明信片 · "+view.card,21)
	button(modal_box,"浏览真实照片",func():show_photo(0))
	button(modal_box,"翻阅 PB",func():show_pb(int(state.pb_page)))
	button(modal_box,"森屿与主题房旅行册",bay.dual.travel_book)
	button(modal_box,"保存收藏",func():save_game())

func claim_card(zone_id:String)->bool:
	if zone_id not in state.stamps:return false
	if zone_id not in state.get("cards",[]):state.cards.append(zone_id)
	state.home_card=zone_id;sync_home_memories();save_game(false)
	return true

func show_souvenirs():
	open_modal("山海纪念卡 · 同人项目原创",1140)
	label(modal_box,"领取已收集纪念章对应的旅行卡，再带回小屋展示。重复查看会保留同一张卡。",23)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1040,590);modal_box.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",14);scroll.add_child(list)
	for zone in world.spec.zones:
		var id:String=zone.id
		var card:=button(list,("放入小屋 · " if id in state.get("cards",[]) else "领取旅行卡 · ")+str(zone.name),func():
			if claim_card(id):notify("旅行卡已陈列在小屋。"))
		card.disabled=id not in state.stamps
	label(modal_box,"未到访的卡会显示锁定状态；场馆和道路始终开放。",19)

func sync_home_memories():
	var card_name:=""
	for zone in world.spec.zones:
		if zone.id==state.get("home_card",""):card_name=zone.name;break
	if card_name.is_empty():card_name="森屿来信" if state.get("home_card","")=="FOREST_MAIL" else str(state.get("home_card",""))
	var filename:String=str(state.get("home_shot","")).get_file()
	world.update_home_memories(card_name,photo_directory()+"/"+filename if not filename.is_empty() else "")

func choose_bouquet(index:int)->bool:
	var previous:int=int(state.bouquet)
	state.bouquet=index
	var had_colors:bool=state.get("activities",{}).has("bouquet_colors");var previous_colors:Array=state.get("activities",{}).get("bouquet_colors",[]).duplicate()
	if had_colors:state.activities.erase("bouquet_colors")
	if bay!=null:bay.refresh_hand()
	world.update_home(index,"res://"+assets[int(state.home_photo)].runtime_path)
	if save_game(false):
		notify("花束已保存。")
		return true
	state.bouquet=previous
	if had_colors:state.activities.bouquet_colors=previous_colors
	if bay!=null:bay.refresh_hand()
	world.update_home(previous,"res://"+assets[int(state.home_photo)].runtime_path)
	notify("花束未保存："+store.last_error)
	return false

func show_flowers(message:String=""):
	open_modal("花间花店 · 选一束带回家")
	label(modal_box,"当前花束："+["淡紫花束","暖杏花束","林间绿色"][int(state.bouquet)],27)
	label(modal_box,"三套配色为乐园原创。选择后会布置在海风小屋，并保存到这次旅行。",23)
	for i in 3:
		var index:=i
		button(modal_box,["淡紫花束","暖杏花束","林间绿色"][i],func():
			var saved:bool=choose_bouquet(index)
			show_flowers("已保存，回到海风小屋可以看到这束花。" if saved else "花束未保存，仍保留原来的布置。请重试。"))
	if not message.is_empty():label(modal_box,message,22)

func show_home():
	open_modal("我的海风小屋 · 预设布置")
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(920,635);modal_box.add_child(scroll)
	var form:=VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;form.add_theme_constant_override("separation",12);scroll.add_child(form)
	label(form,"当前花束："+(bay.bouquet_label() if bay!=null else ["淡紫花束","暖杏花束","林间绿色"][int(state.bouquet)])+"\n花束配色是乐园原创。",26)
	for i in 3:
		var index:=i
		button(form,["淡紫花束","暖杏花束","林间绿色"][i],func():choose_bouquet(index);show_home())
	button(form,"选择下一张展示照片",func():state.home_photo=(int(state.home_photo)+1)%assets.size();world.update_home(int(state.bouquet),"res://"+assets[int(state.home_photo)].runtime_path);save_game(false);show_photo(int(state.home_photo)))
	label(form,"室内照明",21)
	var lights:=OptionButton.new();lights.custom_minimum_size=Vector2(750,42);form.add_child(lights)
	for name in ["柔和暖光","阅读亮度","关闭室内灯"]:lights.add_item(name)
	lights.select(int(state.get("home_light",0)))
	lights.item_selected.connect(func(index):state.home_light=index;world.set_home_light(index);save_game(false))
	if not state.get("cards",[]).is_empty():
		label(form,"旅行纪念卡",21)
		var cards:=OptionButton.new();cards.custom_minimum_size=Vector2(750,42);form.add_child(cards)
		for id in state.cards:
			var label_name:String="崖湾鸟巢露台" if id=="Z09_NEST" else "森屿来信" if id=="FOREST_MAIL" else str(id)
			for zone in world.spec.zones:
				if zone.id==id:label_name=zone.name;break
			cards.add_item(label_name)
		cards.select(maxi(state.cards.find(state.home_card),0))
		cards.item_selected.connect(func(index):state.home_card=state.cards[index];sync_home_memories();save_game(false))
	if not state.shots.is_empty():
		button(form,"把最新旅行风景放入相框",func():state.home_shot=str(state.shots[-1]).get_file();sync_home_memories();save_game(false);notify("风景已陈列在小屋。"))
	label(form,"照片、花束、纪念卡和照明保存后，继续游戏可恢复。",20)

func show_pause():
	open_modal("在山海之间歇一会儿")
	button(modal_box,"继续探索",close_modal)
	button(modal_box,"山海环境 · 昼夜 / 天气",environment_controls.panel)
	button(modal_box,"全局俯视",func():close_modal();environment_controls.enter())
	button(modal_box,"保存旅行",func():save_game())
	button(modal_box,"返回中央广场",func():await teleport_zone({"x":0,"z":60,"name":"中央广场"});close_modal())
	button(modal_box,"设置",show_settings)
	button(modal_box,"素材与关于",show_sources)
	button(modal_box,"保存并退出",func():
		if save_game(false):get_tree().quit())

func volume_slider(parent: Node):
	label(parent,"媒体音量",22)
	var slider:=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.01;slider.value=settings.volume;slider.custom_minimum_size=Vector2(650,36);parent.add_child(slider)
	slider.value_changed.connect(func(value):settings.volume=value;audio_player.volume_db=linear_to_db(maxf(value,0.0001));video.volume_db=linear_to_db(maxf(value,0.0001));save_settings())

func show_settings():
	open_modal("设置")
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(950,660);modal_box.add_child(scroll)
	var form:=VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;form.add_theme_constant_override("separation",12);scroll.add_child(form)
	for item in [["主音量","master_volume"],["音乐","music_volume"],["视频媒体","media_volume"],["环境","environment_volume"],["界面","interface_volume"]]:
		mix_slider(form,item[0],item[1])
	label(form,"鼠标灵敏度",22)
	var slider:=HSlider.new();slider.min_value=0.0008;slider.max_value=0.006;slider.step=0.0001;slider.value=settings.sensitivity;form.add_child(slider)
	slider.value_changed.connect(func(value):settings.sensitivity=value;player.sensitivity=value;save_settings())
	var inverse:=CheckButton.new();inverse.text="反转纵向视角";inverse.button_pressed=settings.invert_y;form.add_child(inverse)
	inverse.toggled.connect(func(value):settings.invert_y=value;player.invert_y=value;save_settings())
	var run_mode:=CheckButton.new();run_mode.text="跑步使用切换模式";run_mode.button_pressed=bool(settings.run_toggle);form.add_child(run_mode)
	run_mode.toggled.connect(func(value):settings.run_toggle=value;player.run_toggle=value;player.run_latched=false;save_settings())
	label(form,"窗口大小（按屏幕自动适配）",22)
	var resolution:=OptionButton.new();resolution.custom_minimum_size=Vector2(750,42);form.add_child(resolution)
	for title in ["保持当前窗口","1280 × 720","1600 × 900","1920 × 1080"]:resolution.add_item(title)
	resolution.item_selected.connect(func(index):
		if index>0:apply_window_size([Vector2i.ZERO,Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)][index]))
	button(form,"阴影：开 / 关",func():sun.shadow_enabled=not sun.shadow_enabled;settings.quality=1 if sun.shadow_enabled else 0;save_settings())
	button(form,"山海环境 · 昼夜 / 天气",environment_controls.panel)
	label(form,"默认无镜头摇晃、无运动模糊。渲染器调整需重新启动。",20)

func apply_window_size(requested:Vector2i,persist:bool=true):
	var usable:Rect2i=DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var available:Vector2i=usable.size-Vector2i(40,80)
	var actual:=Vector2i(clampi(requested.x,800,maxi(800,available.x)),clampi(requested.y,450,maxi(450,available.y)))
	get_window().size=actual;get_window().position=usable.position+(usable.size-actual)/2
	settings.window_size=[actual.x,actual.y]
	if persist:save_settings();notify("窗口已适配为 %d × %d"%[actual.x,actual.y])

func set_time(index: int):
	index=clampi(index,0,2)
	world.set_night_lighting(index)
	world.set_water_horizon_palette(index)
	state.time=index
	sun.light_energy=[0.92,0.52,0.12][index]
	sun.light_color=[Color("fff8e7"),Color("ff9e5e"),Color("a4bada")][index]
	sun.rotation_degrees.x=[-44,-12,-28][index]
	environment.environment.ambient_light_energy=[0.45,0.34,0.27][index]
	environment.environment.fog_light_color=[Color("d6e8df"),Color("edc8a7"),Color("4a6275")][index]
	var mat:ShaderMaterial=environment.environment.sky.sky_material
	mat.set_shader_parameter("top_color",[Color("77b1d0"),Color("8687ad"),Color("182d49")][index])
	mat.set_shader_parameter("horizon_color",[Color("d6e8df"),Color("edc8a7"),Color("4a6275")][index])
	mat.set_shader_parameter("cloud_color",[Color("f5f0dd"),Color("ead6bf"),Color("53677c")][index])
	if environment_controls!=null:environment_controls.apply_weather()

func show_sources():
	open_modal("素材与关于 · 开源试玩版",1240)
	label(modal_box,"小鞠世界 · 开源试玩版\n非官方同人探索项目。环境、建筑、角色和玩法由本项目构造。",26)
	label(modal_box,"本版图片、封面、音乐和短片均为原创演示资源。\n原私人版的真人照片、歌曲和 MV 未随开源版分发。",23)
	label(modal_box,"代码与项目原创资源采用 MIT；三份基础环境声为 CC0。\n中文字体采用 SIL OFL。Godot 及其依赖的许可随发行包保留。",21)
	button(modal_box,"GitHub 项目",func():OS.shell_open("https://github.com/sanhyen/xiaoju-world"))
	button(modal_box,"个人导入库",show_personal_library)
	label(modal_box,"可以自行导入有权使用的本地素材。个人库仅保存在本机。",21)

func personal_directory()->String:
	if not qa_mode.is_empty():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--qa-library="):return arg.trim_prefix("--qa-library=").replace("\\","/")
	if OS.has_feature("editor"):return ProjectSettings.globalize_path("res://UserMedia")
	return OS.get_executable_path().get_base_dir()+"/UserMedia"

func show_personal_library():
	open_modal("个人导入库")
	var folder:=personal_directory()
	if not FileAccess.file_exists(folder+"/library.json"):
		label(modal_box,"还没有个人素材。把素材放入工程的“待导入素材”目录，运行配套导入工具后即可在这里查看。",24);return
	var library=JSON.parse_string(FileAccess.get_file_as_string(folder+"/library.json"))
	if not library is Array:label(modal_box,"素材索引损坏，请重新运行导入工具。");return
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(940,620);modal_box.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for entry in library:
		var record:Dictionary=entry
		button(list,str(entry.title)+" · "+str(entry.kind),func():open_personal(record,folder))

func open_personal(record:Dictionary,folder:String):
	stop_media("personal_media");open_modal(str(record.title),1250)
	var path:=folder+"/"+str(record.runtime_path).get_file()
	if not FileAccess.file_exists(path):label(modal_box,"文件已丢失。请重新导入。");return
	match record.kind:
		"image":
			var im:=Image.load_from_file(path)
			if im==null:label(modal_box,"图片无法读取。");return
			var tex:=TextureRect.new();tex.texture=ImageTexture.create_from_image(im);tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tex.custom_minimum_size=Vector2(1150,640);modal_box.add_child(tex)
		"audio":
			audio_player.stream=AudioStreamOggVorbis.load_from_file(path);audio_player.volume_db=linear_to_db(maxf(float(settings.volume),0.0001));audio_player.play()
			button(modal_box,"暂停 / 继续",func():audio_player.stream_paused=not audio_player.stream_paused)
		"video":
			var stream:=VideoStreamTheora.new();stream.file=path;video.stream=stream;video.volume_db=linear_to_db(maxf(float(settings.volume),0.0001));video_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;video.play()
			var tex:=TextureRect.new();tex.texture=video_viewport.get_texture();tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tex.custom_minimum_size=Vector2(1100,620);modal_box.add_child(tex)
			button(modal_box,"暂停 / 继续",func():video.paused=not video.paused)
	label(modal_box,"个人导入素材 · 来源与传播许可由素材提供者确认。",19)

func enter_photo_mode():
	photo_mode=true;hud.hide();player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	notify("F12 保存风景，Esc 返回。")

func photo_directory()->String:
	return "user://qa_isolated/photos" if qa_mode!="" else "user://photos"

func save_photo()->bool:
	if photo_saving:return false
	photo_saving=true
	var begun:=Time.get_ticks_msec()
	last_photo_capture={"saved":false,"reason":"waiting_for_draw"}
	if not await wait_for_viewport_draw():
		last_photo_capture={"saved":false,"reason":"draw_unavailable","elapsed_ms":Time.get_ticks_msec()-begun}
		photo_saving=false;notify("暂时无法取得画面，请恢复游戏窗口后重试。");return false
	var picture:=get_viewport().get_texture().get_image()
	if picture==null or picture.is_empty():
		last_photo_capture={"saved":false,"reason":"empty_image"}
		photo_saving=false;notify("未取得有效画面，请重试。");return false
	var folder:=photo_directory()
	var error:=DirAccess.make_dir_recursive_absolute(folder)
	var filename:="sea_and_stars_"+str(Time.get_unix_time_from_system()).replace(".","_")+"_"+str(Time.get_ticks_usec())+".png"
	if error==OK:error=picture.save_png(folder+"/"+filename)
	if error!=OK:
		last_photo_capture={"saved":false,"reason":"write_failed","error":error}
		photo_saving=false;notify("截图保存失败，错误码 "+str(error));return false
	state.shots.append(filename)
	var indexed:=save_game(false)
	last_photo_capture={"saved":true,"indexed":indexed,"filename":filename,"elapsed_ms":Time.get_ticks_msec()-begun}
	photo_saving=false
	notify("风景已保存至本机照片目录。" if indexed else "照片已写入本机，但旅行记录保存失败，请重试保存旅行。")
	return indexed

func save_game(show_note: bool=true) -> bool:
	if creative!=null:creative.snapshot_state()
	if transport!=null:transport.snapshot_state()
	if bay!=null and bay.boats!=null:bay.boats.snapshot_active()
	var saved_position:Vector3=player.seat_exit if player.seated else player.position
	if bay!=null and bay.boats!=null and not bay.boats.kind.is_empty():saved_position=bay.boats.shore_point()
	if transport!=null and transport.is_riding():
		var cabin_fraction:float=transport.progress if transport.rider==0 else 1.0-transport.progress
		saved_position=transport.station_landing(0 if cabin_fraction<.5 else 1)
	state.position=[saved_position.x,saved_position.y,saved_position.z]
	state.game_version=ProjectSettings.get_setting("application/config/version")
	if world.layout!=null:state.world_revision="bay_v2"
	state.yaw=player.yaw;state.updated_at=Time.get_datetime_string_from_system();state.interior=world.inside_building(player.position)
	if not state.has("created_at"):state.created_at=session_start
	var ok:bool=store.write(state)
	if show_note:notify("旅行已保存。" if ok else "保存失败："+store.last_error)
	return ok

func return_safe():
	if transitioning:return
	transitioning=true;player.enabled=false
	player.stand_up()
	var p:Array=state.safe_point;var desired:=Vector3(p[0],p[1]+0.5,p[2])
	if await world.prepare_region(desired):
		player.position=world.safe_ground_position(desired);player.velocity=Vector3.ZERO;notify("已返回安全位置。")
	else:notify("安全位置准备失败，请在暂停菜单重试返回广场。")
	transitioning=false;player.enabled=active_game and not modal.visible

func load_settings():
	var config:=ConfigFile.new()
	if config.load("user://settings.cfg")==OK:
		for key in settings:settings[key]=config.get_value("settings",key,settings[key])

func save_settings():
	preload("res://scripts/audio_mix.gd").apply(settings)
	var config:=ConfigFile.new()
	for key in settings:config.set_value("settings",key,settings[key])
	config.save("user://settings.cfg")

func mix_slider(parent:Node,title:String,key:String):
	var row:=HBoxContainer.new();parent.add_child(row)
	var name:=label(row,title,20);name.custom_minimum_size=Vector2(135,30)
	var slider:=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.01;slider.value=float(settings.get(key,1.0));slider.custom_minimum_size=Vector2(650,30);row.add_child(slider)
	slider.value_changed.connect(func(value):settings[key]=value;save_settings())

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if active_game:save_game(false)
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and active_game and (qa_mode=="" or qa_mode.begins_with("desktop_")):
		if audio_player:audio_player.stream_paused=true
		if video:video.paused=true
		if modal and not modal.visible:show_pause.call_deferred()

func wait_for_viewport_draw()->bool:
	if DisplayServer.get_name()=="headless":return false
	# Keep the callback connected during the fallback so a request alone is not success.
	var completion:={"drawn":false}
	var callback:=func():completion.drawn=true
	RenderingServer.frame_post_draw.connect(callback,CONNECT_ONE_SHOT)
	var deadline:=Time.get_ticks_msec()+2000
	while not completion.drawn and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	if not completion.drawn:
		RenderingServer.force_draw(false);RenderingServer.force_sync()
		deadline=Time.get_ticks_msec()+500
		while not completion.drawn and Time.get_ticks_msec()<deadline:await get_tree().process_frame
		if completion.drawn:qa_forced_draws+=1
	if RenderingServer.frame_post_draw.is_connected(callback):RenderingServer.frame_post_draw.disconnect(callback)
	return completion.drawn

func qa_frame()->bool:
	return await wait_for_viewport_draw()

func qa_capture(filename: String, eye: Vector3, target: Vector3):
	if not await world.prepare_region(eye):push_error("Capture region was not ready "+filename);return
	watch_camera.position=eye;watch_camera.look_at(target);watch_camera.current=true
	await get_tree().create_timer(0.6).timeout
	if not await qa_frame():push_error("Capture draw unavailable "+filename);return
	var path:=evidence_root+"screenshots/"+filename+".png"
	var err:=get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ",path," ",err)

func cold_probe():
	await get_tree().create_timer(0.5).timeout
	var result:Dictionary={}
	if qa_mode=="cold_write":
		player.position=world.surface(-236.5,-168.5,0.4)
		state.bouquet=2;state.home_photo=2;state.pb_page=4;state.stamps=["Z04","Z07"];state.discovered=["Z04","Z07"]
		result={"write_ok":save_game(false),"position":state.position,"interior":state.interior}
	else:
		await start_game(true);player.enabled=false
		result={"restored":int(state.bouquet)==2 and int(state.home_photo)==2 and int(state.pb_page)==4 and state.stamps.has("Z07"),"position":state.position,"interior":world.inside_building(player.position),"home_texture":world.home_picture.material_override.albedo_texture.resource_path}
		await qa_capture("V19_cold_restore",world.surface(-237,-169)+Vector3(3,2.4,3.5),world.surface(-237,-169)+Vector3(0,2,-4))
	var f:=FileAccess.open(evidence_root+"reports/"+qa_mode+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	print("COLD_PROBE ",JSON.stringify(result));get_tree().quit()

func route_run():
	await get_tree().create_timer(1).timeout
	await start_game(false);player.yaw=0
	var result:Array=[]
	var before:Vector3=player.position
	var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=true;Input.parse_input_event(key)
	await get_tree().create_timer(0.5).timeout
	key=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=false;Input.parse_input_event(key)
	result.append({"test":"physical_W_event_moves_character","passed":player.position.distance_to(before)>0.5,"distance":player.position.distance_to(before)})
	show_map();before=player.position
	key=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=true;Input.parse_input_event(key)
	await get_tree().create_timer(0.3).timeout
	key=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=false;Input.parse_input_event(key)
	result.append({"test":"modal_blocks_movement","passed":player.position.distance_to(before)<0.1})
	close_modal();player.enabled=false
	var route:Array=[[260,194],[255,232],[135,248],[20,248],[-75,236],[-75,190],[-75,144],[-35,130],[0,120],[0,80],[-105,80],[-195,78],[-250,70],[-250,10],[-250,-80],[-205,-120],[-220,-150],[-160,-218],[-100,-272],[0,-330],[0,-377],[0,-330],[85,-285],[175,-220],[220,-170],[251,-170],[251,-128],[220,-112],[200,-70],[160,0],[85,55],[0,80]]
	route_draw_controller.start();qa_collect=true;var started:=Time.get_ticks_msec();var route_failures:=0
	for i in route.size():
		var destination:=Vector2(route[i][0],route[i][1])
		var remaining:=Vector2(player.position.x,player.position.z).distance_to(destination)
		var deadline:=Time.get_ticks_msec()+int((remaining/8.8+6)*1000)
		while remaining>0.9 and Time.get_ticks_msec()<deadline:
			await get_tree().physics_frame
			var delta:=destination-Vector2(player.position.x,player.position.z)
			var dir:=delta.normalized()
			player.velocity=Vector3(dir.x*8.8,maxf(player.velocity.y-19.0/60,-20),dir.y*8.8)
			if player.is_on_floor():player.velocity.y=-0.2
			player.move_character();player.yaw=atan2(-dir.x,-dir.y);player.figure.rotation.y=player.yaw
			remaining=Vector2(player.position.x,player.position.z).distance_to(destination)
		var ok:=remaining<=0.9
		result.append({"waypoint":i,"target":route[i],"passed":ok,"position":[player.position.x,player.position.y,player.position.z],"remaining":remaining})
		print("ROUTE ",i," ",ok," ",player.position)
		var progress:=FileAccess.open(evidence_root+"reports/route_progress.json",FileAccess.WRITE)
		progress.store_string(JSON.stringify({"waypoint":i,"passed":ok,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0,"position":str(player.position)}));progress.flush();progress.close()
		if not ok:
			route_failures+=1
			# Explicit failed segment recovery to inspect subsequent independent sections.
			player.position=world.surface(destination.x,destination.y,1);player.velocity=Vector3.ZERO
		if i in [0,5,9,13,16,20,25,29]:
			await qa_frame()
			get_viewport().get_texture().get_image().save_png(evidence_root+"screenshots/route_%02d.png"%i)
	qa_collect=false;route_draw_controller.stop();qa_ms.sort();var sum:=0.0
	for ms in qa_ms:sum+=ms
	var slow:=0
	for ms in qa_ms:
		if ms>100:slow+=1
	var report:={"duration_s":(Time.get_ticks_msec()-started)/1000.0,"frame_measurement":"monotonic wall-clock microseconds between process frames; not GPU timer","runtime":"editor_binary" if OS.has_feature("editor") else "export_release","over100ms":slow,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[get_viewport().size.x,get_viewport().size.y],"average_fps":1000/(sum/qa_ms.size()),"p95_ms":qa_ms[int(qa_ms.size()*0.95)],"p99_ms":qa_ms[int(qa_ms.size()*0.99)],"route_failures":route_failures,"results":result,"scope":"automated physics walk with injected input smoke tests; failed sections explicitly recovered, not continuous manual acceptance"}
	report.version=ProjectSettings.get_setting("application/config/version")
	report.configured_quality=int(settings.quality)
	report.render_scale=get_viewport().scaling_3d_scale
	report.render_coverage=route_draw_controller.report()
	report.forced_capture_draws=qa_forced_draws
	var file:=FileAccess.open(evidence_root+"reports/route_test.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	var failed_inputs:=0
	for entry in result:
		if not entry.passed:failed_inputs+=1
	print("ROUTE_RESULT ",JSON.stringify(report));get_tree().quit(1 if failed_inputs else 0)

func qa_run():
	await get_tree().create_timer(2).timeout
	await qa_capture("V01_menu_"+qa_mode,Vector3(32,17,93),Vector3(0,9,40))
	menu.hide();hud.show();active_game=true;player.enabled=false
	player.position=Vector3(0,0.3,76)
	await qa_capture("V05_plaza_"+qa_mode,Vector3(24,5,89),Vector3(0,9,40))
	await qa_capture("V06_portrait_"+qa_mode,Vector3(0,11.8,55),Vector3(0,11.8,39.4))
	await qa_capture("V04_street_"+qa_mode,Vector3(-77,4,219),Vector3(-96,2.5,188))
	await qa_capture("V08_records_"+qa_mode,Vector3(-97,2.7,193),Vector3(-97,1.9,182))
	await qa_capture("V03_coast_"+qa_mode,Vector3(-32,6,303),Vector3(-5,-1,350))
	set_time(1);await qa_capture("V07_dusk_"+qa_mode,Vector3(20,5,88),Vector3(0,9,40));set_time(0)
	if not qa_mode.begins_with("sample"):
		# Overview cameras do not move the player; hide its unrelated plaza HUD.
		hud.hide()
		for item in world.spec.buildings:
			var o:Vector3=world.surface(item.x,item.z)
			if item.id=="B06":
				# Retain the already verified auditorium view, clear of the lobby partition.
				await qa_capture(item.id+"_interior",world.surface(256.5,-83,2.8),world.surface(242,-94,3.2))
			else:await qa_capture(item.id+"_interior",o+Vector3(0,2.6,item.d/2-1.5),o+Vector3(0,2,-item.d/3))
		await qa_capture("V17_summit",world.surface(0,-377,2.2),Vector3(0,5,110))
		await qa_capture("V16_waterfall",Vector3(316,world.height_at(286,-302)+2.2,-302),Vector3(325,world.land_height(325,-332)-11,-331))
		await show_video("B06");await get_tree().create_timer(3).timeout
		await qa_frame()
		get_viewport().get_texture().get_image().save_png(evidence_root+"screenshots/V12_video.png")
		print("VIDEO_CHECK ",JSON.stringify({"playing":video.is_playing(),"position":video.stream_position,"texture":video.get_video_texture()!=null}))
		close_modal();player.enabled=false
	show_map();await get_tree().create_timer(0.3).timeout
	await qa_frame()
	get_viewport().get_texture().get_image().save_png(evidence_root+"screenshots/V18_map.png")
	modal.hide()
	watch_camera.current=true;watch_camera.position=Vector3(24,5,89);watch_camera.look_at(Vector3(0,9,40))
	qa_collect=true
	await get_tree().create_timer(8).timeout
	qa_collect=false;qa_ms.sort()
	var sum:=0.0;var slow:=0
	for n in qa_ms:sum+=n;if n>100:slow+=1
	var report:={"mode":qa_mode,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","frame_measurement":"monotonic wall-clock microseconds between process frames; not GPU timer","frames":qa_ms.size(),"average_fps":1000.0/(sum/maxi(qa_ms.size(),1)),"p95_ms":qa_ms[int(qa_ms.size()*0.95)],"p99_ms":qa_ms[int(qa_ms.size()*0.99)],"over100ms":slow,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":[get_viewport().size.x,get_viewport().size.y],"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"static_memory":OS.get_static_memory_usage(),"caveat":"8-second stationary diagnostic; static_memory is unavailable in release; not final 20-30 minute route acceptance"}
	var f:=FileAccess.open(evidence_root+"reports/qa_"+qa_mode+"_"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("QA_METRICS ",JSON.stringify(report))
	get_tree().quit()

func art_run():
	await get_tree().create_timer(2).timeout
	menu.hide();hud.hide();active_game=true;player.enabled=false
	player.position=Vector3(0,0.3,76)
	# Use the same explicit daytime palette as ordinary start_game; shader defaults differ.
	set_time(0)
	var views:Array=[
		["compare_street",Vector3(-77,4,219),Vector3(-96,2.5,188)],
		["compare_coast",Vector3(-32,6,303),Vector3(-5,-1,350)],
		["compare_plaza",Vector3(24,5,89),Vector3(0,9,40)],
		["plaza_approach",Vector3(24,3.2,110),Vector3(0,8.5,40)],
		["plaza_garden",Vector3(-44,2.4,88),Vector3(0,8,40)],
		["street_south",Vector3(-75,2.5,237),Vector3(-86,2.5,184)],
		["records_front",Vector3(-83,2.4,208),Vector3(-97,2.8,189)],
		["records_inside",Vector3(-97,2.1,193),Vector3(-99,1.9,183)],
		["florist_front",Vector3(-65,2.3,234),Vector3(-49,2.2,211)],
		["greenhouse",Vector3(-40.9,1.9,216.7),Vector3(-41.5,1.7,208)],
		["souvenir",Vector3(-69,2.3,165),Vector3(-55,2.2,148)],
		["coast",Vector3(-47,3.0,307),Vector3(0,-0.4,356)],
		["cafe_front",Vector3(-49,3.3,316),Vector3(-65,3.8,287)],
		["cafe_reading",Vector3(-69,5.55,288.5),Vector3(-66,4.9,330)],
		["cafe_ground",Vector3(-65,2.2,292),Vector3(-70,1.7,282)],
		["pier",Vector3(3,2.3,351),Vector3(-1,0,366)],
		["beach_rocks",world.surface(216,322,2.4),Vector3(263,0,350)],
		["station",world.surface(245,203,2.5),world.surface(260,180,3)],
		["visitor_map",world.surface(57,99,2.2),world.surface(59,91,2.5)],
		["theater",world.surface(-315,33,3),world.surface(-291,8,5)],
		["gallery",world.surface(155,-16,2.6),world.surface(173,-42,3)],
		["home",world.surface(-250,-153,2.5),world.surface(-237,-169,3)],
		["cinema_front",world.surface(225,-57,2.5),world.surface(245,-87,4)],
		["pb_garden",world.surface(196,-134,2.4),world.surface(225,-153,2.9)],
		["music_court",world.surface(-248,40,2.5),world.surface(-290,10,4)],
		["studio_inside",world.surface(-211,56,2.2),world.surface(-215,48,2)],
		["dance_inside",world.surface(-232,-32,2.1),world.surface(-232,-44,2.7)],
		["mountain_grove",world.surface(-108,-269,2.4),world.surface(-130,-249,4)],
		["mountain_bridge",Vector3(300,world.land_height(346,-285)+2.5,-285),Vector3(330,world.land_height(346,-285)+1.9,-285)],
		["culture_bridge",Vector3(277,world.land_height(277,-60)+2.5,-60),Vector3(300,1.8,-70)],
		["waterfall",Vector3(316,world.height_at(286,-302)+2.2,-302),Vector3(325,world.land_height(325,-332)-11,-331)]
	]
	for entry in views:await qa_capture(qa_mode+"_"+entry[0],entry[1],entry[2])
	for interaction in world.interactions:
		if interaction.id=="N02_SEAT":
			player.position=interaction.pos;activate(interaction)
			await qa_capture(qa_mode+"_seated_at_pier",Vector3(-1,1.7,367),Vector3(-3,0.5,364.9))
			player.stand_up();break
	set_time(1);await qa_capture(qa_mode+"_plaza_dusk",Vector3(24,3.2,110),Vector3(0,8.5,40))
	set_time(2);await qa_capture(qa_mode+"_street_night",Vector3(-75,2.5,237),Vector3(-86,2.5,184))
	set_time(0)
	watch_camera.position=Vector3(-75,2.5,222);watch_camera.look_at(Vector3(-96,2.5,188))
	qa_collect=true;await get_tree().create_timer(8).timeout;qa_collect=false;qa_ms.sort()
	var total:=0.0;var slow:=0
	for ms in qa_ms:total+=ms;if ms>100:slow+=1
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"day_palette_initialized":true,"mode":qa_mode,"views":views.size()+3,"frames":qa_ms.size(),"average_fps":1000.0/(total/qa_ms.size()),"p95_ms":qa_ms[int(qa_ms.size()*0.95)],"p99_ms":qa_ms[int(qa_ms.size()*0.99)],"over100ms":slow,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","resolution":[get_viewport().size.x,get_viewport().size.y],"renderer":RenderingServer.get_current_rendering_method(),"caveat":"8-second stationary street diagnostic; wall-clock frame intervals, not final long route acceptance"}
	var f:=FileAccess.open(evidence_root+"reports/"+qa_mode+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("ART_QA ",JSON.stringify(report));get_tree().quit()
