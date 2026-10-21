extends CharacterBody3D
var yaw := 0.0
var pitch := -0.2
var zoom := 6.0
var sensitivity := 0.0025
var invert_y := false
var run_toggle:=false
var run_latched:=false
var walk_speed := 9.36
var run_multiplier := 2.0
var jump_count := 0
var jump_requested := false
var enabled := false:
	set(value):
		if enabled != value:reset_jump_state()
		enabled=value
		if not value:run_latched=false
var ignore_focus_loss:=false
var automated_motion:=false
var program_driven:=false
var automated_horizontal:=Vector2.ZERO
var rest_pose:="sit"
var seated := false
var seat_exit:=Vector3.ZERO
var seat_anchor:=Vector3.ZERO
var seated_shins:Array=[]
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var figure: Node3D
var legs: Array=[]
var gait := 0.0
var arms:Array=[]
var pet_until_msec:=0
var home_world
var vehicle_controller
var boat_controller
var water_edge_blocked:=false

func _ready():
	var col:=CollisionShape3D.new();var cap:=CapsuleShape3D.new();cap.radius=0.33;cap.height=1.65;col.shape=cap;col.position.y=0.85;add_child(col)
	floor_snap_length=0.6
	floor_max_angle=deg_to_rad(48)
	pivot=Node3D.new();add_child(pivot);pivot.position.y=1.45
	arm=SpringArm3D.new();pivot.add_child(arm);arm.spring_length=zoom;arm.margin=0.2;arm.add_excluded_object(get_rid())
	camera=Camera3D.new();arm.add_child(camera);camera.fov=66;camera.near=0.2;camera.far=12000;camera.current=true
	figure=Node3D.new();add_child(figure)
	part(Vector3(0,1,0),Vector3(0.56,0.64,0.28),"d4c1d6")
	part(Vector3(0,1.54,0),Vector3(0.43,0.43,0.4),"e8d1b2")
	part(Vector3(0,1.76,0.03),Vector3(0.47,0.14,0.44),"494642")
	part(Vector3(-0.07,1.56,-0.215),Vector3(0.04,0.04,0.025),"293637")
	part(Vector3(0.07,1.56,-0.215),Vector3(0.04,0.04,0.025),"293637")
	for x in [-0.17,0.17]:legs.append(part(Vector3(x,0.35,0),Vector3(0.22,0.7,0.25),"4e676b"))
	for x in [-0.17,0.17]:
		var shin:=part(Vector3(x,0.28,-0.58),Vector3(0.22,0.45,0.23),"4e676b");shin.visible=false;seated_shins.append(shin)
	for x in [-0.36,0.36]:arms.append(part(Vector3(x,1.0,0),Vector3(0.18,0.62,0.22),"c3b5cb"))
	part(Vector3(0,1.05,0.23),Vector3(0.4,0.4,0.2),"8e9c88")

func part(p: Vector3,size: Vector3,color: String) -> MeshInstance3D:
	var mi:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;mi.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mi.material_override=mat;figure.add_child(mi);mi.position=p;return mi

func reset_jump_state():
	jump_requested=false
	# Opening a UI or changing views cannot recharge a jump in mid-air.
	jump_count=0 if is_on_floor() else 2

func _unhandled_input(event):
	if event is InputEventKey and event.physical_keycode==KEY_SHIFT and event.pressed and not event.echo and enabled and run_toggle:run_latched=not run_latched
	if event is InputEventKey and event.physical_keycode==KEY_SPACE and event.pressed and not event.echo and enabled:
		jump_requested=true
	if event is InputEventMouseMotion and enabled and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not (get_parent().get("environment_controls")!=null and get_parent().environment_controls.follow):
		yaw-=event.relative.x*sensitivity
		pitch=clampf(pitch-event.relative.y*sensitivity*(-1 if invert_y else 1),-0.95,0.6)
	if event is InputEventMouseButton and enabled:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=maxf(2.2,zoom-0.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=minf(10,zoom+0.5)

func _physics_process(delta):
	var main=get_parent()
	if main.get("environment_controls")!=null and main.environment_controls.follow:yaw=main.environment_controls.movement_yaw()
	pivot.rotation=Vector3(pitch,yaw,0)
	var indoor:bool=home_world!=null and home_world.is_sheltered(global_position)
	arm.spring_length=lerpf(arm.spring_length,minf(zoom,3.0) if indoor else zoom,delta*8)
	if pet_until_msec>Time.get_ticks_msec() and enabled:
		var interrupt:bool=not program_driven and (jump_requested or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D))
		if not interrupt:
			velocity=Vector3(0,-.2,0);move_and_slide();figure.position.y=-.38
			for leg in legs:leg.rotation.x=-.65
			for arm_part in arms:arm_part.rotation.x=-.9+sin(Time.get_ticks_msec()*.006)*.09
			return
		pet_until_msec=0
	if pet_until_msec>0:
		pet_until_msec=0;figure.position.y=0
		for leg in legs:leg.rotation.x=0
		for arm_part in arms:arm_part.rotation.x=0
	if automated_motion:
		velocity.y=maxf(velocity.y-19*delta,-20)
		if is_on_floor():velocity.y=-0.2
		velocity.x=automated_horizontal.x;velocity.z=automated_horizontal.y
		move_character()
		return
	if not enabled or program_driven:
		jump_requested=false
		return
	if boat_controller!=null and not boat_controller.kind.is_empty():boat_controller.drive(delta);return
	if vehicle_controller!=null and not vehicle_controller.mounted.is_empty():vehicle_controller.drive(delta);return
	if is_on_floor():jump_count=0
	elif jump_count==0:jump_count=1
	if not is_on_floor():velocity.y-=19*delta
	var input:=Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):input.y-=1
	if Input.is_physical_key_pressed(KEY_S):input.y+=1
	if Input.is_physical_key_pressed(KEY_A):input.x-=1
	if Input.is_physical_key_pressed(KEY_D):input.x+=1
	if seated:
		if input.length()>0.1 or jump_requested:stand_up();jump_requested=false
		else:
			global_position=seat_anchor;velocity=Vector3.ZERO;apply_seated_pose();return
	var direction:=Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y).normalized()
	var running:bool=run_latched if run_toggle else Input.is_physical_key_pressed(KEY_SHIFT)
	var speed:float=walk_speed*(run_multiplier if running else 1.0)
	velocity.x=move_toward(velocity.x,direction.x*speed,delta*25)
	velocity.z=move_toward(velocity.z,direction.z*speed,delta*25)
	if jump_requested and jump_count<2:
		velocity.y=6.8 if jump_count==0 else 6.4
		jump_count+=1
	jump_requested=false
	move_character()
	if direction.length()>0.1:
		figure.rotation.y=lerp_angle(figure.rotation.y,atan2(-direction.x,-direction.z),delta*12)
		gait+=delta*speed*2.2
		for i in 2:legs[i].rotation.x=sin(gait+i*PI)*0.4
	else:
		for leg in legs:leg.rotation.x=lerpf(leg.rotation.x,0,delta*10)
	figure.position.y=0.0

func sit_at(anchor:Vector3,angle:float):
	if seated:return
	reset_jump_state()
	seat_exit=global_position;seat_anchor=anchor;global_position=anchor
	velocity=Vector3.ZERO;seated=true;figure.rotation.y=angle;yaw=angle
	apply_seated_pose()

func apply_seated_pose():
	if rest_pose=="lie":
		figure.rotation.x=PI*.5;figure.position.y=.35
		for i in 2:
			legs[i].rotation.x=0;legs[i].position=Vector3(-.17 if i==0 else .17,.35,0);seated_shins[i].visible=false
		return
	figure.position.y=-0.12
	for i in 2:
		legs[i].position=Vector3(-0.17 if i==0 else 0.17,0.60,-0.3)
		legs[i].rotation.x=-PI/2
		seated_shins[i].visible=true

func stand_up():
	if not seated:return
	reset_jump_state()
	seated=false;rest_pose="sit";figure.rotation.x=0;global_position=seat_exit;velocity=Vector3.ZERO;figure.position.y=0
	for i in 2:
		legs[i].position=Vector3(-0.17 if i==0 else 0.17,0.35,0)
		legs[i].rotation=Vector3.ZERO;seated_shins[i].visible=false

func foot_destination_allowed(p:Vector3)->bool:
	var layout=home_world.layout
	if layout.shallow_or_dry(p) or home_world.within_pier(p):return true
	# Water limits use water depth. Voxel steps can sit below the smooth design field;
	# their height difference must not create invisible barriers on dry hillsides.
	return layout.within_bounds(p) and float(layout.config.sea_y)-home_world.height_at(p.x,p.z)<=float(layout.config.shallow_policy.max_wade_depth_m)+.025

func move_character():
	if home_world!=null and not home_world.region_ready(global_position):
		velocity=Vector3.ZERO;return
	water_edge_blocked=false
	if home_world!=null and home_world.layout!=null:
		var step:Vector3=velocity*get_physics_process_delta_time();step.y=0
		var next:Vector3=global_position+step
		if not foot_destination_allowed(next):
			water_edge_blocked=true
			# Slide along the shallow edge; never relocate the player to a distant anchor.
			var x_only:Vector3=global_position+Vector3(step.x,0,0)
			var z_only:Vector3=global_position+Vector3(0,0,step.z)
			if foot_destination_allowed(x_only):velocity.z=0
			elif foot_destination_allowed(z_only):velocity.x=0
			else:velocity.x=0;velocity.z=0
	var before:=global_position
	var wanted:=velocity
	var grounded:=is_on_floor()
	move_and_slide()
	var actual:=Vector2(global_position.x-before.x,global_position.z-before.z).length()
	var planned:=Vector3(wanted.x,0,wanted.z)*get_physics_process_delta_time()
	if grounded and planned.length()>0.01 and actual<planned.length()*0.45:
		var raised:=global_transform;raised.origin.y+=0.4
		if not test_move(global_transform,Vector3.UP*0.4) and not test_move(raised,planned):
			global_position.y+=0.4;velocity=Vector3(wanted.x,0,wanted.z);move_and_slide();apply_floor_snap()

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and not ignore_focus_loss:
		velocity=Vector3.ZERO
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		enabled=false

func gentle_pet(point:Vector3,duration:float=2.4):
	stand_up();yaw=atan2(global_position.x-point.x,global_position.z-point.z);figure.rotation.y=yaw
	pet_until_msec=Time.get_ticks_msec()+int(duration*1000);velocity=Vector3.ZERO
