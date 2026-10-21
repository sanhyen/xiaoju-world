extends Node3D
## Continuous physical sailing, with safe shore boarding and return points.
var m
var kind:=""
var selected:="flower"
var dock_index:=1
var heading:=0.0
var speed:=0.0
var model:Node3D
var mast:Node3D
var envelope:CollisionShape3D
var viewing_pose:=0
var old_zoom:=6.0
var moored:Array=[]
var clock:=0.0
var swing:Dictionary={}
var fish:Array=[]
var auto_target:=-1
var testing:=false
var test_input:=Vector2.ZERO
var last_shore:=Vector3.ZERO
var free_models:Array=[]
var free_signature:=""
var boundary_notice:=0.0
var basket_signature:=""
var public_models:Dictionary={}
var public_tick:=0.0
var active_source:=""

func setup(target):
	m=target;m.player.boat_controller=self
	for i in m.world.layout.config.boat_docks.size():
		var record:Dictionary=m.world.layout.config.boat_docks[i];var pos:Vector3=m.world.layout.vector(record.water)
		for slot in (3 if i>=3 else 2):
			var boat:Node3D=make_boat("flower" if slot%2==0 else "yacht");add_child(boat);boat.position=pos+Vector3((slot-1)*4,.05,-7 if i==2 else 8)
			if i==0:
				var along:=Vector3(float(record.axis[0]),0,float(record.axis[1])).normalized();var side:=Vector3(-along.z,0,along.x)
				boat.position=pos+side*(-3.0 if slot==0 else 3.0)+Vector3(0,.05,0);boat.rotation.y=atan2(-along.x,-along.z)
			batch_parked(boat);moored.append(boat)
	for i in 18:
		var group:=Node3D.new();add_child(group)
		for j in 4:
			var body:MeshInstance3D=m.bay.add_block(group,Vector3(j*.6,j%2*.12,0),Vector3(.33,.18,.12),["e6bd62","81bdb7","bf88ad"][i%3])
			m.bay.add_block(group,body.position+Vector3(-.2,0,0),Vector3(.12,.22,.05),"b6ca9c")
		fish.append(group)
	for i in 4:
		var group:=Node3D.new();add_child(group);group.set_meta("home",Vector3(276+(4 if i in [1,2] else 0),-3.5,426+i*15))
		for j in 3:m.bay.add_block(group,Vector3(j*.35-.35,0,0),Vector3(.28,.15,.1),["edc15d","7dbdb4","c7a8d4"][j])
		fish.append(group)

func make_boat(type:String)->Node3D:
	var root:=Node3D.new();var color:String="6d4930" if type=="flower" else "f4efe6"
	for i in 7:
		var z:float=-2.0+i*.65;var width:float=.75+sin(float(i)/6*PI)*.9
		m.bay.add_block(root,Vector3(0,.15,z),Vector3(width,.42,.72),color)
		m.bay.add_block(root,Vector3(0,.4,z),Vector3(width*.85,.12,.66),"a8895e")
	for side in [-1,1]:
		m.bay.add_block(root,Vector3(side*.8,.6,0),Vector3(.12,.45,2.9),color)
		m.bay.add_block(root,Vector3(side*.95,.8,-.9),Vector3(.12,.08,1.2),"bfaa82").rotation.y=side*.4
	if type=="flower":
		for z in [-.4,.8]:
			m.bay.add_block(root,Vector3(0,.72,z),Vector3(1.3,.12,.5),"a58962")
		for side in [-1,1]:m.bay.add_block(root,Vector3(side*.65,1.1,.5),Vector3(.1,1.2,.1),"654732")
		for i in 9:
			var angle:float=-PI*.5+PI*float(i)/8
			var rib:MeshInstance3D=m.bay.add_block(root,Vector3(sin(angle)*.8,1.0+cos(angle)*.75,.5),Vector3(.23,.12,1.9),"5e4937");rib.rotation.z=-angle
		m.bay.add_block(root,Vector3(0,.85,-1.4),Vector3(.65,.35,.45),"b49266")
		for i in 7:
			m.bay.add_block(root,Vector3(-.3+i*.1,.88,-1.635),Vector3(.026,.30,.018),"8f6c49")
			m.bay.add_block(root,Vector3(sin(i*2.1)*.15,1.1,-1.4+cos(i*2.1)*.1),Vector3(.13,.12,.13),["f4b8c4","f2c14e","6ba4d6","9b7ede","faf6f0"][i%5])
		for side in [-1,1]:
			var oar:=Node3D.new();oar.name="OarL" if side<0 else "OarR";oar.position=Vector3(side*.8,.6,.3);root.add_child(oar)
			m.bay.add_block(oar,Vector3(side*.85,0,0),Vector3(1.7,.07,.07),"ae8c5f")
			m.bay.add_block(oar,Vector3(side*1.7,-.05,0),Vector3(.45,.12,.3),"87613e")
		m.bay.add_block(root,Vector3(.65,1.4,-.8),Vector3(.18,.3,.18),"ead09a")
		var lantern:=OmniLight3D.new();lantern.name="Lantern";lantern.position=Vector3(.65,1.4,-.8);lantern.light_color=Color("ffa65c");lantern.omni_range=4;lantern.light_energy=0;root.add_child(lantern)
	else:
		for side in [-1,1]:m.bay.add_block(root,Vector3(side*.79,.45,0),Vector3(.025,.10,2.8),"3b7a9e")
		m.bay.add_block(root,Vector3(0,.75,.7),Vector3(1.1,.6,1.2),"e4dac3")
		m.bay.add_block(root,Vector3(0,1.1,.2),Vector3(.7,.08,.7),"648f9d")
		var sail:=Node3D.new();sail.name="FoldingSail";root.add_child(sail);sail.position=Vector3(0,.5,-.5)
		m.bay.add_block(sail,Vector3(0,1.8,0),Vector3(.1,3.6,.1),"b9ae8e")
		for i in 7:m.bay.add_block(sail,Vector3(.13+i*.1,.45+i*.4,0),Vector3(1.7-i*.21,.38,.045),"e9e5d1" if i%2==0 else "779daa")
	return root

func choose(index:int):
	dock_index=index;m.open_modal(m.world.layout.config.boat_docks[index].name+" · 选船")
	m.label(m.modal_box,"沿内河顺流或逆流，也可驶入前海前往珊瑚岛。可在码头选船，或沿海走近实体小船直接按 F。靠可站浅岸按 F 停泊下船。船会留在当地，之后可再次登船。",24)
	for item in [["flower","溪谷暖木花船 · 乌篷、藤篮与风灯"],["yacht","海风白帆轻游艇 · 折叠轻帆与柚木甲板"]]:
		var type:String=item[0]
		m.button(m.modal_box,item[1]+(" · 已选" if selected==type else ""),func():selected=type;m.state.activities.boat_choice=type;m.save_game(false);m.close_modal();m.notify("已选船，按 F 乘船。"))
	m.label(m.modal_box,"双岛航线已开放 · 珊瑚岛与萤火森屿均可自由绕行，桥下可通船。",20)
	m.label(m.modal_box,"W/S 加速与减速 · A/D 转向 · 空格停船 · X 船头 / 坐舱姿态 · 游艇按住 Shift 低速巡航\n轻游艇接近低桥时自动收帆。",22)

func board(index:int)->bool:
	if not kind.is_empty() or not m.bay.vehicles.mounted.is_empty():return false
	dock_index=index;selected=str(m.state.activities.get("boat_choice",selected));var record:Dictionary=m.world.layout.config.boat_docks[index]
	last_shore=m.world.layout.vector(record.land)+Vector3(0,.3,1.4)
	var angle:float=PI if index==1 and selected=="yacht" else float(record.heading)
	if index==0:angle=atan2(-float(record.axis[0]),-float(record.axis[1]))
	return await begin_board(selected,m.world.layout.vector(record.water)+Vector3(0,.2,0),angle)

func begin_board(type:String,at:Vector3,angle:float)->bool:
	if not kind.is_empty() or not m.bay.vehicles.mounted.is_empty():return false
	if type not in ["flower","yacht"]:return false
	m.player.enabled=false;m.transitioning=true
	if not await m.world.prepare_region(at,70):m.transitioning=false;m.player.enabled=true;return false
	kind=type;m.player.stand_up();m.player.position=at;heading=angle;speed=0;viewing_pose=0;old_zoom=m.player.zoom;m.player.zoom=8
	model=make_boat(kind);m.player.add_child(model);model.rotation.y=heading;model.position.y=-.15;mast=model.get_node_or_null("FoldingSail")
	envelope=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.85,.65,4.2);envelope.shape=shape;envelope.position.y=.35;m.player.add_child(envelope)
	m.player.figure.position=Vector3(0,-.05 if kind=="flower" else .25,.4);m.player.yaw=heading;m.player.velocity=Vector3.ZERO
	m.transitioning=false;m.player.enabled=true;m.notify("已登船。W/S 航速，A/D 转向，空格停船，F 近岸停泊，X 观景姿态。")
	return true

func water_at(p:Vector3)->Dictionary:
	if not m.world.layout.within_bounds(p):return {}
	var l=m.world.layout;var result:Dictionary={};var distance:float=INF
	for r in l.near(l.river_index,Vector2(p.x,p.z)):
		if r.id!="navigation":continue
		var q:Vector3=l.projection(Vector2(p.x,p.z),r);var d:float=Vector2(p.x-q.x,p.z-q.z).length()
		if d<r.width*.5-.45 and d<distance:distance=d;result={"y":q.y,"width":r.width}
	var lagoon:Dictionary=l.config.lagoon
	if Vector2((p.x-lagoon.center[0])/lagoon.radius[0],(p.z-lagoon.center[1])/lagoon.radius[1]).length()<1:result={"y":-2.28,"width":35}
	# Open sea is continuous; only visible ground depth and the outer buoy line restrict it.
	if p.z>=l.shore_z(p.x)-1 and p.z>260:result={"y":float(l.config.sea_y),"width":100}
	if result.is_empty():return {}
	var depth:float=float(result.y)-m.world.height_at(p.x,p.z)
	if depth<float(l.config.navigation_policy.get("min_depth_m",.32)):return {}
	result["depth"]=depth
	return result

func drive(delta:float):
	var input:Vector2=test_input if testing else Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)))
	if auto_target>=0:
		var target:Vector3=m.world.layout.vector(m.world.layout.config.boat_docks[auto_target].water)
		var direction:Vector3=target-m.player.position;var desired:float=atan2(-direction.x,-direction.z)
		input=Vector2(clampf(-angle_difference(heading,desired)*2,-1,1),1)
		if Vector2(direction.x,direction.z).length()<4:auto_target=-1;speed=0
	var brake:bool=not testing and Input.is_physical_key_pressed(KEY_SPACE)
	var top:float=6.75 if kind=="flower" else 12.0
	if not testing and kind=="yacht" and Input.is_physical_key_pressed(KEY_SHIFT):top=4.05
	var here:Dictionary=water_at(m.player.position)
	if not here.is_empty() and float(here.width)<12:top=minf(top,4.8)
	var limits:Array=m.world.layout.config.navigation_policy.bounds
	var margin:float=minf(float(limits[3])-m.player.position.z,minf(m.player.position.x-float(limits[0]),float(limits[1])-m.player.position.x))
	if m.player.position.z>380 and margin<22.5:
		top*=lerpf(.20,1.0,smoothstep(0,22.5,margin))
		if clock-boundary_notice>4:m.notify("前方橙白航标为外海边界，减速返航；A/D 可原地掉头。");boundary_notice=clock
	speed=move_toward(speed,0 if brake else input.y*top,delta*(6.9 if brake else 2.7 if kind=="flower" else 3.6))
	# Stopped boats can pivot without scraping the bank; cruising steering stays unchanged.
	heading-=input.x*(1.1 if absf(speed)<.6 else maxf(.25,absf(speed)*.18))*delta
	var next:Vector3=m.player.position+Vector3(-sin(heading),0,-cos(heading))*speed*delta
	var water:Dictionary=water_at(next)
	if water.is_empty():
		# Slow at the visible shallow bed; turning remains available while stopped.
		speed=move_toward(speed,0,delta*9);m.player.velocity=Vector3.ZERO
		model.rotation.y=heading;envelope.rotation.y=heading;m.player.figure.rotation.y=heading
		return
	m.player.velocity=Vector3(-sin(heading)*speed,0,-cos(heading)*speed)
	m.player.move_and_slide();m.player.position.y=float(water.y)+.2
	model.rotation.y=heading;model.rotation.z=sin(clock*1.5)*.012;envelope.rotation.y=heading
	m.player.figure.rotation.y=heading;m.player.figure.position=Basis(Vector3.UP,heading)*Vector3(0,.15 if viewing_pose==1 else -.05 if kind=="flower" else .25,-1.0 if viewing_pose==1 else .45)
	for leg in m.player.legs:leg.rotation.x=0 if viewing_pose==1 else -1.1
	if mast!=null:
		var low_bridge:=false
		for r in m.world.layout.near(m.world.layout.road_index,Vector2(next.x,next.z)):
			if r.bridge and Vector2(next.x,next.z).distance_to(Vector2(m.world.layout.projection(Vector2(next.x,next.z),r).x,m.world.layout.projection(Vector2(next.x,next.z),r).z))<18:low_bridge=true
		mast.rotation.x=move_toward(mast.rotation.x,PI*.45 if low_bridge else 0,delta*1.5)
	if kind=="flower":
		for side in [-1,1]:
			var oar:Node3D=model.get_node("OarL" if side<0 else "OarR");oar.rotation.y=side*(.25+sin(clock*2.1)*.45*minf(absf(speed),1));oar.rotation.z=side*.12
	m.player.jump_requested=false

func change_pose():
	viewing_pose=(viewing_pose+1)%2;m.notify("船头凭栏观景" if viewing_pose==1 else "坐舱观景")

func shore_point()->Vector3:
	return last_shore if last_shore!=Vector3.ZERO else m.world.layout.vector(m.world.layout.config.boat_docks[dock_index].land)+Vector3(0,.3,1.4)

func nearest_shore()->Vector3:
	var source:Vector3=m.player.position;var space:PhysicsDirectSpaceState3D=m.world.get_world_3d().direct_space_state
	var candidates:Array=[]
	for radius in [2.0,2.8,3.6,4.5,5.5,6.5,8.0]:
		for i in 40:
			var a:float=i*TAU/40;var p:Vector3=source+Vector3(cos(a)*radius,0,sin(a)*radius);var ground:float=m.world.height_at(p.x,p.z)
			if ground<float(m.world.layout.config.sea_y)-1.30 or ground>float(m.world.layout.config.sea_y)+1.2:continue
			p.y=ground+.12
			var ray:=PhysicsRayQueryParameters3D.create(Vector3(p.x,ground+1.5,p.z),Vector3(p.x,ground-.5,p.z),1,[m.player.get_rid()]);var hit:Dictionary=space.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y<.7 or absf(float(hit.position.y)-ground)>.55:continue
			p.y=hit.position.y+.12
			var cap:=CapsuleShape3D.new();cap.radius=.36;cap.height=1.65;var q:=PhysicsShapeQueryParameters3D.new();q.shape=cap;q.exclude=[m.player.get_rid()];q.transform=Transform3D(Basis.IDENTITY,p+Vector3(0,.86,0));q.collision_mask=1
			if space.intersect_shape(q,1).is_empty():candidates.append(p)
		if not candidates.is_empty():break
	if candidates.is_empty():return Vector3.INF
	candidates.sort_custom(func(a,c):return a.distance_squared_to(source)<c.distance_squared_to(source))
	return candidates[0]

func shore_hint()->String:
	var p:Vector3=m.player.position;var targets:Array=[Vector2(p.x,m.world.layout.shore_z(p.x)+18)]
	for island in [m.world.layout.config.island,m.world.layout.config.island2]:
		var delta:=Vector2(p.x-island.center[0],p.z-island.center[1]);var angle:float=atan2(delta.y/island.radius[1],delta.x/island.radius[0])
		targets.append(Vector2(island.center[0]+cos(angle)*island.radius[0]*1.15,island.center[1]+sin(angle)*island.radius[1]*1.15))
	var at:=Vector2(p.x,p.z);targets.sort_custom(func(a,c):return a.distance_squared_to(at)<c.distance_squared_to(at))
	var d:Vector2=targets[0]-at;var dirs:Array=["东","东南","南","西南","西","西北","北","东北"];var direction:String=dirs[posmod(roundi(d.angle()/(PI*.25)),8)]
	return "最近浅岸在"+direction+"侧约 "+str(roundi(d.length()))+" m；驶近浅岸后 F 下船。"

func dock()->bool:
	if kind.is_empty():return false
	if absf(speed)>1.0:m.notify("请先按空格减速，再按 F 停泊。");return false
	var distance:float=9.0;var best:=-1
	for i in m.world.layout.config.boat_docks.size():
		var p:Vector3=m.world.layout.vector(m.world.layout.config.boat_docks[i].water);var d:float=Vector2(m.player.position.x-p.x,m.player.position.z-p.z).length()
		if d<distance:best=i;distance=d
	var shore:Vector3
	if best>=0:
		dock_index=best;shore=m.world.layout.vector(m.world.layout.config.boat_docks[best].land)+Vector3(0,.3,1.4)
	else:shore=nearest_shore()
	if not shore.is_finite():speed=0;m.notify("船已停稳。附近水深，"+shore_hint()+" X 可留在船上观景。");return false
	m.player.enabled=false;m.transitioning=true
	if not await m.world.prepare_region(shore,70):m.transitioning=false;m.player.enabled=true;return false
	moor_current(shore);leave_for_travel();m.player.position=m.world.safe_ground_position(shore);m.player.velocity=Vector3.ZERO;m.transitioning=false;m.player.enabled=true
	m.state.safe_point=[m.player.position.x,m.player.position.y,m.player.position.z]
	if best>=0:m.state.activities["dock_"+str(best)]=true
	m.save_game(false);m.notify("已停泊下船。小船留在原处，走近停泊标记按 F 可再次登船。");return true

func moor_current(shore:Vector3):
	if kind.is_empty():return
	if not shore.is_finite():shore=shore_point()
	var fleet:Array=m.state.activities.get("moored_boats",[]);var at:Vector3=m.player.position
	fleet.append({"kind":kind,"water":[at.x,at.y,at.z],"shore":[shore.x,shore.y,shore.z],"heading":heading,"sail_folded":mast!=null and mast.rotation.x>.1})
	# Every legitimate parked boat is retained; distant visuals are streamed by visibility.
	m.state.activities.moored_boats=fleet;free_signature="";sync_free_boats()

func sync_free_boats():
	var fleet:Array=m.state.get("activities",{}).get("moored_boats",[]);var serial:String=JSON.stringify(fleet)+str(Vector2i(floori(m.player.position.x/96),floori(m.player.position.z/96)))
	if serial==free_signature:return
	free_signature=serial
	for boat in free_models:boat.queue_free()
	free_models.clear();m.world.interactions=m.world.interactions.filter(func(a):return not str(a.id).begins_with("FREE_BOAT_"))
	for i in fleet.size():
		var record:Dictionary=fleet[i]
		if record.get("kind","") not in ["flower","yacht"] or record.get("water",[]).size()!=3 or record.get("shore",[]).size()!=3:continue
		var at:=Vector3(record.water[0],record.water[1],record.water[2])
		if at.distance_to(m.player.position)>155:continue
		var shore:=Vector3(record.shore[0],record.shore[1],record.shore[2]);var boat:Node3D=make_boat(record.kind);add_child(boat);boat.position=at+Vector3(0,-.15,0);boat.rotation.y=float(record.get("heading",0));free_models.append(boat)
		var sail:Node3D=boat.get_node_or_null("FoldingSail")
		if sail!=null and record.get("sail_folded",false):sail.rotation.x=PI*.45
		batch_parked(boat)
		m.world.interact("FREE_BOAT_"+str(i),shore,"原地停泊的小船 · F 再次登船","bay_moored",{"index":i})

func board_moored(index:int)->bool:
	var fleet:Array=m.state.activities.get("moored_boats",[])
	if index<0 or index>=fleet.size():return false
	var record:Dictionary=fleet[index];last_shore=Vector3(record.shore[0],record.shore[1],record.shore[2])
	var ok:bool=await begin_board(record.kind,Vector3(record.water[0],record.water[1],record.water[2]),float(record.heading))
	if ok:fleet.remove_at(index);m.state.activities.moored_boats=fleet;free_signature="";sync_free_boats();m.save_game(false)
	return ok

func choose_moored(index:int):
	m.open_modal("原地停泊的小船");m.label(m.modal_box,"小船保持上次的停泊位置。F 可再次登船，继续自由沿岸游览。",24)
	m.button(m.modal_box,"返回岸边",m.close_modal)

func batch_parked(boat:Node3D):
	var pieces:Array=boat.find_children("*","MeshInstance3D",true,false);var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=BoxMesh.new();mm.instance_count=pieces.size()
	for i in pieces.size():
		var piece:MeshInstance3D=pieces[i];var local:Transform3D=boat.global_transform.affine_inverse()*piece.global_transform;local.basis=local.basis.scaled_local(piece.mesh.size);mm.set_instance_transform(i,local);mm.set_instance_color(i,piece.material_override.albedo_color);piece.queue_free()
	var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true;mat.roughness=.8;node.material_override=mat;boat.add_child(node)

func leave_for_travel():
	if m!=null and m.state.get("activities") is Dictionary:m.state.activities.erase("active_boat106")
	active_source=""
	if kind.is_empty():return
	model.queue_free();model=null;envelope.queue_free();envelope=null;kind="";speed=0;auto_target=-1;m.player.figure.position=Vector3.ZERO;m.player.zoom=old_zoom
	for leg in m.player.legs:leg.rotation.x=0

func rest(action:Dictionary):
	m.player.sit_at(action.data.seat,float(action.data.get("yaw",PI)))
	if action.kind=="bay_netbed":m.player.rest_pose="lie";m.player.apply_seated_pose();m.notify("躺在白色网床上。移动键起身；F6 切换黄昏或星空。")
	else:swing={"anchor":m.player.seat_anchor,"id":action.data.get("prop",""),"begun":clock};m.notify("已坐上秋千。移动键起身，P 可进入拍照。")

func _process(delta:float):
	if m==null:return
	clock+=delta
	if m.active_game:
		sync_free_boats();public_tick+=delta
		if public_tick>.4:public_tick=0;sync_public_boats()
	update_bouquet()
	for boat in moored+free_models+public_models.values()+([model] if model!=null else []):
		if boat!=model:boat.visible=m.active_game and (boat.global_position.distance_to(m.player.position)<150 or m.environment_controls.overview or m.environment_controls.follow and boat.global_position.distance_to(m.environment_controls.camera_target())<140)
		var lantern:OmniLight3D=boat.get_node_or_null("Lantern")
		if lantern!=null:lantern.light_energy=.8 if int(m.state.time)>0 else 0
	for i in fish.size():
		var q:Node3D=fish[i];var angle:float=clock*.13+i*2.4
		q.visible=m.active_game and m.player.position.distance_to(Vector3(260,-3,450))<130
		if q.has_meta("home"):
			q.position=q.get_meta("home")+Vector3(sin(clock*.7+i)*.42,sin(clock+i)*.10,cos(clock*.6+i)*.40);q.rotation.y=clock*.6
		else:q.position=Vector3(225+cos(angle)*(51+i%4*2),-3.4,450+sin(angle)*(35+i%3*2));q.rotation.y=-angle
		var delta_to_player:Vector3=q.position-m.player.position
		if delta_to_player.length()<3.5:q.position+=Vector3(delta_to_player.x,0,delta_to_player.z).normalized()*(3.5-delta_to_player.length())*.6
		var ground:float=m.world.height_at(q.position.x,q.position.z);var sea:float=m.world.layout.config.sea_y
		q.visible=q.visible and ground<sea-.45
		q.position.y=lerpf(ground,sea,.60)+sin(clock+i)*.045 if not q.has_meta("home") else sea-.62+sin(clock+i)*.08
	if not swing.is_empty():
		var prop:Node3D=m.world.bay_props.get(swing.id)
		if m.player.seated:
			var shift:float=sin((clock-swing.begun)*1.7)*.35
			m.player.seat_anchor=swing.anchor+Vector3(0,.05*(1-cos(shift)),shift)
			if is_instance_valid(prop):prop.position.z=swing.anchor.z+shift
		else:
			if is_instance_valid(prop):prop.position.z=swing.anchor.z
			swing={}

func update_bouquet():
	if model==null or kind!="flower":basket_signature="";return
	var serial:String=str(m.state.activities.get("bouquet_colors",[]))+str(m.state.handheld)
	if serial==basket_signature:return
	basket_signature=serial
	var old:Node3D=model.get_node_or_null("SelectedBouquet")
	if old!=null:old.queue_free()
	if m.state.handheld!="bouquet" and m.state.activities.get("bouquet_colors",[]).is_empty():return
	var bouquet:=Node3D.new();bouquet.name="SelectedBouquet";model.add_child(bouquet);var colors:Array=m.bay.bouquet_palette()
	for i in 9:m.bay.add_block(bouquet,Vector3(sin(i*2.4)*.22,1.20+i%3*.06,-1.4+cos(i*2.4)*.18),Vector3(.15,.16,.15),colors[i%colors.size()])

func sync_public_boats():
	if not m.state.activities.get("public_boat_sources106") is Dictionary:m.state.activities.public_boat_sources106={}
	var states:Dictionary=m.state.activities.public_boat_sources106;var changed:=false
	for source in m.world.layout.config.public_boats:
		var id:String=source.id;var water:Vector3=m.world.layout.vector(source.water)
		var state:Dictionary=states.get(id,{})
		if state.get("depleted",false) and m.player.position.distance_to(water)>18:
			state["depleted"]=false;state["replenished"]=int(state.get("replenished",0))+1;states[id]=state;changed=true
		var available:bool=not state.get("depleted",false)
		if available and not public_models.has(id):
			var boat:Node3D=make_boat(source.kind);add_child(boat);boat.position=water+Vector3.UP*.05;boat.rotation.y=float(source.heading)
			var sail:Node3D=boat.get_node_or_null("FoldingSail")
			if sail!=null:sail.rotation.x=PI*.45
			batch_parked(boat);public_models[id]=boat
			var shore:Vector3=m.world.layout.vector(source.shore);var interaction:Vector3=(water+shore)*.5;interaction.y=m.world.height_at(interaction.x,interaction.z)+.15
			m.world.interact("PUBLIC_BOAT_"+id,interaction,source.name+" · F 自由登船","bay_public_boat",{"source":id})
		elif not available and public_models.has(id):
			public_models[id].queue_free();public_models.erase(id)
			m.world.interactions=m.world.interactions.filter(func(a):return a.id!="PUBLIC_BOAT_"+id)
	if changed:m.save_game(false)

func board_public(id:String)->bool:
	var matches:Array=m.world.layout.config.public_boats.filter(func(a):return a.id==id)
	if matches.is_empty() or not public_models.has(id):return false
	var source:Dictionary=matches[0];last_shore=m.world.layout.vector(source.shore)+Vector3.UP*.12
	var ok:bool=await begin_board(source.kind,m.world.layout.vector(source.water)+Vector3.UP*.2,float(source.heading))
	if ok:
		active_source=id;m.state.activities.public_boat_sources106[id]={"depleted":true,"borrowed":int(m.state.activities.public_boat_sources106.get(id,{}).get("borrowed",0))+1};sync_public_boats();m.save_game(false)
	return ok

func public_panel(id:String):
	m.open_modal("海岸自由船")
	m.label(m.modal_box,"走近实体小船直接按 F。花船慢游、游艇远航；Shift 可低速巡航，空格刹停。两岛周围及桥下都可通行。",24)
	m.button(m.modal_box,"登上这艘船",func():m.close_modal();await board_public(id))

func snapshot_active():
	if kind.is_empty():m.state.activities.erase("active_boat106");return
	var p:Vector3=m.player.position;var shore:Vector3=shore_point()
	m.state.activities.active_boat106={"kind":kind,"water":[p.x,p.y,p.z],"heading":heading,"shore":[shore.x,shore.y,shore.z],"source":active_source}

func resume_active():
	var record:Dictionary=m.state.activities.get("active_boat106",{}).duplicate(true)
	if record.is_empty() or record.get("water",[]).size()!=3 or record.get("kind","") not in ["flower","yacht"]:return
	var at:=Vector3(record.water[0],record.water[1],record.water[2])
	if water_at(at).is_empty():return
	last_shore=Vector3(record.shore[0],record.shore[1],record.shore[2])
	if await begin_board(record.kind,at,float(record.heading)):active_source=str(record.get("source",""))
