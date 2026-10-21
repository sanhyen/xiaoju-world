extends Node3D
## Two visible vehicles, one grounded controller; collision uses the full vehicle envelope.
var m
var mounted:=""
var heading:=0.0
var speed:=0.0
var moving:Node3D
var wheels:Array=[]
var steering:Node3D
var lamp:SpotLight3D
var envelope:CollisionShape3D
var parked:Array=[]
var old_zoom:=6.0
var last_dock:=0
var turn:=0.0
var test_input:=Vector2.ZERO
var testing:=false
var braking:=false

func setup(target):
	m=target;m.player.vehicle_controller=self
	for i in m.world.layout.config.docks.size():
		var at:Vector3=m.world.layout.vector(m.world.layout.config.docks[i])
		for kind in ["bike","scooter"]:
			var model:Node3D=model_for(kind)
			add_child(model);model.position=at+Vector3(-2 if kind=="bike" else 2,0.12,0);model.set_meta("dock",i);model.set_meta("kind",kind);parked.append(model)

func part(parent:Node3D,p:Vector3,size:Vector3,tone:String)->MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(tone);mat.roughness=0.8;n.material_override=mat;parent.add_child(n);n.position=p;return n

func model_for(kind:String)->Node3D:
	var root:=Node3D.new();var tire_radius:float=0.36 if kind=="bike" else 0.27
	for z in [-0.78,0.78]:
		var wheel:=Node3D.new();root.add_child(wheel);wheel.position=Vector3(0,tire_radius,z);wheel.set_meta("wheel",true)
		var n:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=tire_radius;mesh.bottom_radius=tire_radius;mesh.height=0.15;mesh.radial_segments=16;n.mesh=mesh;n.rotation.z=PI*0.5
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color("354846");n.material_override=mat;wheel.add_child(n)
		for angle in 4:part(wheel,Vector3.ZERO,Vector3(0.17,0.045,tire_radius*1.75),"b6b49b").rotation.x=angle*PI*0.25
	if kind=="bike":
		part(root,Vector3(0,0.62,0),Vector3(0.10,0.12,1.6),"8baba0").rotation.x=-0.17
		part(root,Vector3(0,0.7,0.1),Vector3(0.10,0.65,0.10),"8baba0").rotation.x=0.35
		part(root,Vector3(0,0.76,0.2),Vector3(0.12,0.12,1.0),"8baba0").rotation.x=0.48
		part(root,Vector3(0,1.03,0.18),Vector3(0.35,0.12,0.42),"6d5641")
		part(root,Vector3(0,0.92,-0.75),Vector3(0.1,1.0,0.1),"c7c2a5").rotation.x=-0.12
		var basket:=part(root,Vector3(0,1.02,-0.98),Vector3(0.58,0.38,0.42),"bc9970");basket.set_meta("basket",true)
		for x in [-0.27,0.27]:part(root,Vector3(x,1.1,-0.97),Vector3(0.045,0.45,0.46),"947151")
	else:
		part(root,Vector3(0,0.5,0.3),Vector3(0.63,0.45,1.1),"eee2c5")
		part(root,Vector3(0,0.83,0.23),Vector3(0.56,0.14,0.82),"846650")
		part(root,Vector3(0,0.63,-0.55),Vector3(0.68,0.83,0.18),"eee2c5").rotation.x=0.15
		part(root,Vector3(0,0.31,-0.15),Vector3(0.66,0.14,0.9),"b6aa8c")
		part(root,Vector3(0,0.9,-0.7),Vector3(0.12,0.65,0.12),"9eab9d")
	if kind=="scooter":
		for side in [-1,1]:
			part(root,Vector3(side*.42,1.42,-.68),Vector3(.04,.38,.04),"bbc5bd")
			part(root,Vector3(side*.42,1.62,-.68),Vector3(.25,.19,.07),"bacccd")
		part(root,Vector3(0,1.12,.94),Vector3(.53,.32,.4),"b99469")
		part(root,Vector3(0,.65,.99),Vector3(.25,.10,.05),"c28673")
	var handle:=Node3D.new();handle.name="Handle";handle.position=Vector3(0,1.2,-0.7);root.add_child(handle)
	part(handle,Vector3.ZERO,Vector3(0.85,0.08,0.08),"6c725f")
	for x in [-0.4,0.4]:part(handle,Vector3(x,0,0.05),Vector3(0.16,0.10,0.22),"46594f")
	part(root,Vector3(0,0.95,-0.84),Vector3(0.25,0.19,0.10),"f5df9c")
	return root

func mount(kind:String,dock:int,spot:Vector3=Vector3.INF)->bool:
	if not mounted.is_empty() or not m.world.inside_building(m.player.position).is_empty():return false
	var at:Vector3=spot if dock<0 else m.world.layout.vector(m.world.layout.config.docks[dock])+Vector3(-2 if kind=="bike" else 2,0.2,0)
	if m.player.position.distance_to(at)>5.0:return false
	m.player.stand_up();mounted=kind;last_dock=dock;heading=m.player.yaw;speed=0;old_zoom=m.player.zoom
	moving=model_for(kind);m.player.add_child(moving);moving.rotation.y=heading;wheels=[]
	for n in moving.get_children():
		if n.has_meta("wheel"):wheels.append(n)
	steering=moving.get_node("Handle");m.player.position=at;m.player.zoom=maxf(old_zoom,6.2)
	m.player.figure.position.y=0.45
	for leg in m.player.legs:leg.rotation.x=-0.7
	envelope=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(0.85,1.25,2.15);envelope.shape=shape;envelope.position.y=0.72;envelope.rotation.y=heading;m.player.add_child(envelope)
	lamp=SpotLight3D.new();lamp.spot_range=22;lamp.spot_angle=30;lamp.light_color=Color("ffe4ae");lamp.light_energy=1.2;lamp.position=Vector3(0,1.05,-0.9);moving.add_child(lamp)
	for model in parked:
		if model.get_meta("kind")==kind and ((dock>=0 and model.get_meta("dock")==dock) or (dock<0 and model.position.distance_to(at)<.5)):model.hide()
	update_basket();m.notify("已上车 · WASD 跟随镜头方向，空格刹车，F 下车，X 按铃")
	return true

func dismount(force:bool=false)->bool:
	if mounted.is_empty():return true
	if absf(speed)>1.6 and not force:m.notify("请先松开加速并刹车，再按 F 下车。");return false
	var exit:Vector3=m.player.position
	var found:=false
	for side in [-1.0,1.0]:
		var candidate:Vector3=exit+Basis(Vector3.UP,heading)*Vector3(side*1.6,0,0)
		if not m.world.layout.shallow_or_dry(candidate):continue
		var ray:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*1.3,candidate-Vector3.UP*2.2,1,[m.player.get_rid()])
		var hit:Dictionary=m.world.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<0.7:continue
		candidate.y=hit.position.y+0.1
		var cap:=CapsuleShape3D.new();cap.radius=0.36;cap.height=1.65
		var q:=PhysicsShapeQueryParameters3D.new();q.shape=cap;q.exclude=[m.player.get_rid()];q.transform=Transform3D(Basis.IDENTITY,candidate+Vector3.UP*0.9)
		if m.world.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():exit=candidate;found=true;break
	if not found and not force:m.notify("两侧暂时无法安全下车，请驶到开阔处。");return false
	var parked_model:Node3D=moving; m.player.remove_child(parked_model);add_child(parked_model);parked_model.position=m.player.position;parked_model.rotation.y=heading;parked_model.set_meta("dock",-1);parked_model.set_meta("kind",mounted);parked.append(parked_model)
	# Leave one recoverable vehicle at the current spot; docks always retain a spare of each type.
	for model in parked:
		if model.get_meta("dock")==last_dock and model.get_meta("kind")==mounted:model.show()
	for child in parked_model.get_children():
		if child is SpotLight3D:child.queue_free()
	if parked.size()>18:
		for model in parked.duplicate():
			if model.get_meta("dock")==-1 and model!=parked_model:parked.erase(model);model.queue_free();break
	mounted="";speed=0;envelope.queue_free();envelope=null;moving=null;m.player.position=exit;m.player.velocity=Vector3.ZERO;m.player.zoom=old_zoom;m.player.figure.position.y=0
	for leg in m.player.legs:leg.rotation.x=0
	m.notify("已安全下车。车辆可在六处车港重新领取。")
	return true

func drive(delta:float):
	var input:Vector2=test_input if testing else Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)))
	var brake:bool=braking if testing else Input.is_physical_key_pressed(KEY_SPACE)
	var top:float=18 if mounted=="bike" else 24
	# Ground material and route membership never cap speed. Collision still stops the vehicle.
	if not testing:
		var movement:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		input.y=1.0 if movement.length_squared()>0 else 0.0
	var throttle:float=top if input.y>0 else -3.0 if input.y<0 else 0.0
	if not testing and not Input.is_physical_key_pressed(KEY_SHIFT):throttle=minf(throttle,16 if mounted=="bike" else 20)
	if input.y<0 and speed>0.5:throttle=0
	speed=move_toward(speed,0 if brake else throttle,delta*(15 if brake or input.y<0 else 5.8 if input.y>0 else 2.8))
	turn=move_toward(turn,input.x,delta*4)
	var radius:float=3.1 if mounted=="bike" else 4.0
	if testing:heading-=turn*speed/radius*delta
	else:
		var movement:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if movement.length()>.01:
			var direction:Vector3=Basis(Vector3.UP,m.player.yaw)*Vector3(movement.x,0,movement.y).normalized();var wanted:float=atan2(-direction.x,-direction.z)
			heading=lerp_angle(heading,wanted,clampf(delta*(4.8 if mounted=="bike" else 4.0),0,1));speed=absf(speed)
		else:speed=move_toward(speed,0,delta*8)
	m.player.velocity.x=-sin(heading)*speed;m.player.velocity.z=-cos(heading)*speed
	m.player.velocity.y=maxf(m.player.velocity.y-19*delta,-20)
	if m.player.is_on_floor():m.player.velocity.y=-0.2
	var before:Vector3=m.player.position;var ahead:Vector3=before+Vector3(m.player.velocity.x,0,m.player.velocity.z)*delta
	var hazard:bool=not m.world.layout.shallow_or_dry(ahead) or not m.world.inside_building(ahead).is_empty() or (m.bay.dual!=null and m.bay.dual.foot_only_ahead(ahead))
	if hazard:
		speed=0;m.player.velocity=Vector3.ZERO;dismount(true);m.notify("已在入口或水岸前安全停靠，继续步行探索。");return
	m.player.move_character()
	if absf(speed)>3 and before.distance_to(m.player.position)<absf(speed)*delta*0.3:speed=move_toward(speed,0,delta*30)
	moving.rotation.y=heading;envelope.rotation.y=heading;m.player.figure.rotation.y=heading;m.player.figure.position.y=0.38
	for i in m.player.legs.size():m.player.legs[i].rotation.x=-0.8+sin(Time.get_ticks_msec()*0.009+i*PI)*0.22*(minf(absf(speed),8)/8 if mounted=="bike" else 0)
	for wheel in wheels:wheel.rotation.x-=speed*delta/(0.36 if mounted=="bike" else 0.27)
	steering.rotation.y=-turn*0.35;lamp.visible=int(m.state.time)>0
	var basket:Node3D=moving.get_node_or_null("CarriedBouquet")
	if basket!=null:basket.rotation.z=sin(Time.get_ticks_msec()*.003)*.025
	m.player.jump_requested=false

func update_basket():
	if moving==null or mounted!="bike":return
	var bouquet:Node3D=moving.get_node_or_null("CarriedBouquet")
	if bouquet!=null:bouquet.queue_free()
	if m.state.get("handheld","natural")!="bouquet":return
	bouquet=Node3D.new();bouquet.name="CarriedBouquet";moving.add_child(bouquet)
	for i in 7:part(bouquet,Vector3(sin(i*2.3)*0.18,1.3+i%2*0.06,-0.97+cos(i*2.3)*0.12),Vector3(0.16,0.18,0.16),m.bay.bouquet_palette()[i%m.bay.bouquet_palette().size()])

func nearest_parked()->Dictionary:
	var result:Dictionary={};var distance:float=2.6
	for item in parked:
		if not item.visible or int(item.get_meta("dock"))>=0:continue
		var d:float=m.player.position.distance_to(item.position)
		if d<distance:distance=d;result={"kind":item.get_meta("kind"),"position":item.position}
	return result
