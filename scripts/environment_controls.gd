extends Node
## Normal-play overview and environment controls, independent of QA.
var main
var camera:Camera3D
var overview:=false
var follow:=false
var center:=Vector2(0,-25)
var free_focus_y:=24.0
var extent:=1040.0
var free_extent_limit:=1400.0
var follow_extent:=42.0
var view_yaw:=PI*.25
var view_pitch:=deg_to_rad(55.0)
var smoothed_target:=Vector3.ZERO
var cutaway_tick:=0.0
var saved:Dictionary={}
var weather:=0
var rain:MultiMeshInstance3D
var rain_audio:AudioStreamPlayer
var drops:Array[Vector3]=[]
var sheltered:=false
var shelter_timer:=0.0
var clock:=0.0
var banner:Label
const WEATHER_NAMES=["晴天","阴天","雨天"]

func setup(target):
	main=target
	camera=Camera3D.new();camera.name="WorldOverview";camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.near=.15;camera.far=5000.0;add_child(camera)
	banner=Label.new();banner.text="斜俯跟随  ·  WASD 行走 · E / F 互动 · 右键拖动转向 · 滚轮缩放 · V 自由观景 · O 返回"
	banner.position=Vector2(40,970);banner.add_theme_font_size_override("font_size",22)
	banner.add_theme_color_override("font_outline_color",Color("182e32"));banner.add_theme_constant_override("outline_size",6)
	main.hud.add_child(banner);banner.hide()
	make_rain()

func enter():
	if is_observing() or not main.active_game or main.transitioning:return
	# Observation never restores an old position: walking and the gondola keep advancing.
	saved={"yaw":main.player.yaw,"pitch":main.player.pitch,"zoom":main.player.zoom}
	main.player.reset_jump_state();main.player.velocity=Vector3.ZERO
	follow=true;overview=false;main.player.enabled=true
	smoothed_target=camera_target();center=Vector2(smoothed_target.x,smoothed_target.z);extent=follow_extent;update_camera()
	camera.current=true;main.photo_mode=false;main.hud.show();banner.show();main.current={};main.prompt.text=""
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func leave():
	if not is_observing():return
	overview=false;follow=false;banner.hide();apply_cutaway(false)
	main.player.yaw=float(saved.get("yaw",main.player.yaw));main.player.pitch=float(saved.get("pitch",main.player.pitch));main.player.zoom=float(saved.get("zoom",main.player.zoom))
	main.player.velocity=Vector3.ZERO;main.player.reset_jump_state();main.player.camera.current=true
	main.player.enabled=main.active_game and not main.modal.visible
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if main.player.enabled else Input.MOUSE_MODE_VISIBLE

func is_observing()->bool:return overview or follow

func movement_yaw()->float:return view_yaw if follow else float(main.player.yaw)

func camera_target()->Vector3:
	if main==null or main.player==null:return Vector3.ZERO
	if overview:return Vector3(center.x,free_focus_y,center.y)
	var transport=main.get("transport")
	if transport!=null and transport.is_riding():return transport.observation_anchor()+Vector3.UP
	return main.player.global_position+Vector3.UP*1.0

func restore_current_camera():
	if not main.active_game:return
	if is_observing():
		camera.current=true;banner.show();main.player.enabled=follow and not main.modal.visible
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	else:
		main.player.camera.current=true;main.player.enabled=not main.modal.visible
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if main.player.enabled else Input.MOUSE_MODE_VISIBLE

func switch_mode():
	if not is_observing():return
	if follow:
		var at:Vector3=camera_target();follow=false;overview=true;extent=260.0;center=Vector2(at.x,at.z);free_focus_y=at.y
		main.player.enabled=false;main.player.velocity=Vector3.ZERO;apply_cutaway(false)
		banner.text="自由观景  ·  WASD / 方向键平移 · 右键拖动转向 · 滚轮缩放 · Home 全图 · V 跟随人物 · O 返回"
	else:
		overview=false;follow=true;extent=follow_extent;main.player.enabled=true;smoothed_target=camera_target()
		banner.text="斜俯跟随  ·  WASD 行走 · E / F 互动 · 右键拖动转向 · 滚轮缩放 · V 自由观景 · O 返回"
	update_camera()

func update_camera():
	var focus:Vector3=smoothed_target if follow else Vector3(center.x,free_focus_y,center.y)
	camera.size=follow_extent if follow else extent
	var horizontal:float=48.0 if follow else maxf(90.0,extent*.68)
	camera.global_position=focus+Vector3(sin(view_yaw)*horizontal,tan(view_pitch)*horizontal,cos(view_yaw)*horizontal)
	camera.far=maxf(5000.0,camera.global_position.distance_to(focus)+2000.0)
	camera.look_at(focus,Vector3.UP)

func fit_world_view():
	var bounds:Array=main.world.layout.config.bounds
	var low:float=float(main.world.layout.config.sea_y);var high:float=low
	# Height queries use the same authored terrain as walking; the upper envelope includes crowns.
	var columns:int=maxi(1,ceili((float(bounds[1])-float(bounds[0]))/32.0))
	var rows:int=maxi(1,ceili((float(bounds[3])-float(bounds[2]))/32.0))
	for x in columns+1:
		for z in rows+1:
			var at:=Vector2(lerpf(bounds[0],bounds[1],float(x)/columns),lerpf(bounds[2],bounds[3],float(z)/rows))
			var height:float=main.world.height_at(at.x,at.y)
			low=minf(low,height);high=maxf(high,height+18.0)
	for place in main.world.layout.creative_places:
		var floors=place.get("floors",[])
		var top:float=float(floors[-1])+8.0 if floors is Array and not floors.is_empty() else float(place.center[1])+8.0
		high=maxf(high,top)
	for building in main.world.spec.get("buildings",[]):
		high=maxf(high,float(building.floor_y)+float(building.get("h",8))+6.0)
	center=Vector2((float(bounds[0])+float(bounds[1]))*.5,(float(bounds[2])+float(bounds[3]))*.5)
	free_focus_y=(low+high)*.5;update_camera()
	var focus:=Vector3(center.x,free_focus_y,center.y)
	var right:Vector3=camera.global_basis.x;var up:Vector3=camera.global_basis.y
	var half_width:=0.0;var half_height:=0.0
	for x in [float(bounds[0]),float(bounds[1])]:
		for y in [low,high]:
			for z in [float(bounds[2]),float(bounds[3])]:
				var corner:Vector3=Vector3(x,y,z)-focus
				half_width=maxf(half_width,absf(corner.dot(right)));half_height=maxf(half_height,absf(corner.dot(up)))
	var viewport_size:Vector2=camera.get_viewport().get_visible_rect().size
	var aspect:float=maxf(.1,viewport_size.x/maxf(1,viewport_size.y))
	extent=maxf(half_height*2.0,half_width*2.0/aspect)*1.10;free_extent_limit=maxf(1400.0,extent*1.4);update_camera()

func apply_cutaway(enabled:bool):
	if main!=null and main.world!=null and main.world.has_method("set_observation_cutaway"):
		main.world.call("set_observation_cutaway",camera_target(),enabled)

func handle_input(event)->bool:
	if not is_observing() or main.modal.visible:return false
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
		view_yaw-=event.relative.x*.006;view_pitch=clampf(view_pitch+event.relative.y*.003,deg_to_rad(30),deg_to_rad(75));update_camera();return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var factor:float=1.0/1.16 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.16
			if follow:follow_extent=clampf(follow_extent*factor,12,105)
			else:extent=clampf(extent*factor,70,free_extent_limit)
			update_camera();return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_O,KEY_ESCAPE]:leave();return true
		if event.physical_keycode==KEY_V:switch_mode();return true
		if event.physical_keycode==KEY_HOME:
			if follow:switch_mode()
			fit_world_view();return true
		# Free observation freezes walking; follow mode preserves every normal interaction.
		if overview and event.physical_keycode not in [KEY_F6,KEY_F5,KEY_M,KEY_P,KEY_F12,KEY_N]:return true
	return false

func panel():
	main.open_modal("山海环境 · 昼夜与天气",980)
	main.label(main.modal_box,"随时切换光照与天气，返回后继续原地探索。",23)
	var time_row:=HBoxContainer.new();main.modal_box.add_child(time_row)
	for i in 3:
		var index:int=i
		var btn:Button=main.button(time_row,["白天","黄昏","夜晚"][i],func():main.set_time(index);panel())
		btn.toggle_mode=true;btn.button_pressed=int(main.state.time)==i;btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var weather_row:=HBoxContainer.new();main.modal_box.add_child(weather_row)
	for i in 3:
		var index:int=i
		var btn:Button=main.button(weather_row,WEATHER_NAMES[i],func():set_weather(index);panel())
		btn.toggle_mode=true;btn.button_pressed=weather==i;btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	main.mix_slider(main.modal_box,"环境音量","environment_volume")
	if main.active_game:
		main.button(main.modal_box,"返回地面探索" if is_observing() else "斜俯跟随 · 边走边看",func():
			main.dismiss_environment_panel()
			if is_observing():leave()
			else:enter())
	main.label(main.modal_box,"O：斜俯跟随 / 返回　 V：跟随 / 自由观景　 F6：环境面板\n跟随时正常行走、骑行和互动；自由观景时人物原地停留。右键拖动转向，滚轮缩放，Home 看全图。",21)

func set_weather(index:int):
	weather=clampi(index,0,2);main.state.weather=weather
	main.set_time(int(main.state.time))

func apply_weather():
	var index:int=int(main.state.time)
	var e:Environment=main.environment.environment
	var sky:ShaderMaterial=e.sky.sky_material
	sky.set_shader_parameter("cloud_cover",[0.0,0.68,0.9][weather])
	e.fog_depth_begin=[300.0,180.0,85.0][weather];e.fog_depth_end=[4800.0,2200.0,1150.0][weather]
	if weather>0:
		main.sun.light_energy*=[1.0,0.58,0.38][weather]
		main.sun.light_color=main.sun.light_color.lerp(Color("b4c6d0"),0.55)
		e.ambient_light_energy*=[1.0,0.91,0.80][weather]
		var horizon:Color=[Color("a1b7be"),Color("aaa4ad"),Color("354755")][index]
		var top:Color=[Color("778e9c"),Color("6f7386"),Color("1b2b3d")][index]
		sky.set_shader_parameter("top_color",top);sky.set_shader_parameter("horizon_color",horizon)
		sky.set_shader_parameter("cloud_color",horizon.lightened(0.10 if index<2 else 0.03));e.fog_light_color=horizon
		if main.world.water_material!=null:main.world.water_material.set_shader_parameter("horizon_tone",horizon)

func make_rain():
	# A bounded opaque instance field avoids global particle/transparent overdraw.
	rain=MultiMeshInstance3D.new();rain.name="LocalRain";rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
	var mesh:=BoxMesh.new();mesh.size=Vector3(0.015,0.24,0.015);mm.mesh=mesh;mm.instance_count=256
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("8faebc");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	rain.multimesh=mm;rain.material_override=mat;add_child(rain);rain.hide()
	var rng:=RandomNumberGenerator.new();rng.seed=618093
	for i in mm.instance_count:drops.append(Vector3(rng.randf_range(-11,11),rng.randf_range(-6,10),rng.randf_range(-11,11)))
	rain_audio=AudioStreamPlayer.new();rain_audio.bus="Environment";rain_audio.volume_db=-80;add_child(rain_audio)
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var data:=PackedByteArray();data.resize(22050*4*2);var smooth:=0.0
	for i in 22050*4:
		var noise:float=rng.randf_range(-1,1);smooth=lerpf(smooth,noise,0.22)
		data.encode_s16(i*2,int((smooth*0.7+noise*0.18)*9000))
	stream.data=data;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=22050*4;rain_audio.stream=stream

func _process(delta:float):
	if main==null:return
	clock+=delta
	if follow and main.active_game and not main.modal.visible:
		var focus:Vector3=camera_target();smoothed_target=smoothed_target.lerp(focus,1.0-exp(-delta*10.0))
		if smoothed_target.distance_to(focus)>65:smoothed_target=focus
		update_camera();camera.current=true;cutaway_tick-=delta
		if cutaway_tick<=0:cutaway_tick=.12;apply_cutaway(true)
	if overview and not main.modal.visible:
		var movement:=Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):movement.y-=1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):movement.y+=1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):movement.x-=1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):movement.x+=1
		var travel:Vector3=Basis(Vector3.UP,view_yaw)*Vector3(movement.x,0,movement.y).normalized()
		center+=Vector2(travel.x,travel.z)*extent*.45*delta;center.x=clampf(center.x,-475,475);center.y=clampf(center.y,-455,645);update_camera()
	var eye:Camera3D=main.get_viewport().get_camera_3d()
	var wet:bool=weather==2 and main.active_game and not overview and eye!=null
	shelter_timer-=delta
	if wet and shelter_timer<=0:
		shelter_timer=0.12
		sheltered=main.world.is_sheltered(main.player.position)
		if not sheltered:
			var query:=PhysicsRayQueryParameters3D.create(eye.global_position,eye.global_position+Vector3.UP*30)
			query.exclude=[main.player.get_rid()]
			sheltered=not main.world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	wet=wet and not sheltered
	rain.visible=wet
	if wet:
		rain.global_position=eye.global_position
		for i in drops.size():
			var p:Vector3=drops[i];p.y=fposmod(p.y-clock*14.0+6.0,16.0)-6.0
			# Exclude venue roofs and floor penetration without global rain simulation.
			var global:Vector3=eye.global_position+p
			var hidden:bool=global.y<main.world.height_at(global.x,global.z)+0.08 or main.world.is_sheltered(global)
			rain.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO if hidden else Vector3.ONE),p))
	var volume:float=-21.0 if wet else -80.0
	rain_audio.volume_db=move_toward(rain_audio.volume_db,volume,delta*55.0)
	if wet and not rain_audio.playing:rain_audio.play()
	elif not wet and rain_audio.volume_db<=-79.0:rain_audio.stop()
