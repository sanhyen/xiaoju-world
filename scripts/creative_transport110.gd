extends Node3D
## A paired reversible gondola. Static cables and moving cabins share one world-space path.
const STATIONS=[Vector3(-288,13.9,-116),Vector3(-60,70.13,-358)]
const SUPPORT_XZ=[Vector2(-221.88,-186.18),Vector2(-174,-237),Vector2(-123.84,-290.24),Vector2(-82.8,-333.8)]
const LANE_OFFSET=2.1
const HANGER_HEIGHT=3.6
const CRUISE_MPS=4.0
const ACCELERATION=2.0
var m
var path:Array[Vector3]=[]
var cumulative:PackedFloat32Array=[]
var total_length:=1.0
var cabins:Array[Node3D]=[]
var doors:Array[Node3D]=[]
var bodies:Array[AnimatableBody3D]=[]
var progress:=0.0
var destination:=0.0
var traveling:=false
var speed:=0.0
var waiting_for_region:=false
var rider:=-1
var pose:=0
var previous_zoom:=6.0
var prompt_tick:=0.0
var route_built:=false
var preparing_board:=false
var board_request_serial:=0
var restoring:=false
var restore_request_serial:=0
var status:Label

static func roof_height(world,point:Vector2)->float:
	var result:float=float(world.height_at(point.x,point.y))+8.0
	# Existing conifers top out below 15 m; this conservative envelope also clears their crowns.
	if point.y< -120.0:result=maxf(result,float(world.height_at(point.x,point.y))+18.0)
	if world.has_method("transport_obstacle_height"):
		var envelope=world.call("transport_obstacle_height",point)
		if envelope is Dictionary:
			result=maxf(result,float(envelope.get("roof",-1000))+8.0)
			result=maxf(result,float(envelope.get("canopy",-1000))+3.0)
		elif envelope is float or envelope is int:result=maxf(result,float(envelope)+8.0)
	var cfg:Dictionary=world.layout.config
	for item in world.spec.buildings:
		if absf(point.x-float(item.x))<float(item.w)*.5+5 and absf(point.y-float(item.z))<float(item.d)*.5+5:
			result=maxf(result,float(item.floor_y)+float(item.get("h",8))+12.0)
	for item in cfg.get("living_houses",[])+cfg.get("theme_rooms",[]):
		if absf(point.x-float(item.center[0]))<float(item.size[0])*.5+5 and absf(point.y-float(item.center[2]))<float(item.size[1])*.5+5:
			result=maxf(result,float(item.center[1])+float(cfg.sea_y)+18.0)
	var creative=world.layout.get("creative_places")
	if creative is Array:
		for item in creative:
			if str(item.get("id","")).begins_with("CABLE_"):continue
			if not item.get("center") is Array or not item.get("size") is Array:continue
			if absf(point.x-float(item.center[0]))<float(item.size[0])*.5+5 and absf(point.y-float(item.center[2]))<float(item.size[1])*.5+5:
				var floors:int=int(item.floors) if item.get("floors",1) is int or item.get("floors",1) is float else item.get("floors",[]).size()
				result=maxf(result,float(item.center[1])+float(item.get("height",maxi(1,floors)*3.65+4.0))+8.0)
	return result

static func route_points(world)->Array[Vector3]:
	var anchors:Array[Vector2]=[Vector2(STATIONS[0].x,STATIONS[0].z)]
	for at in SUPPORT_XZ:anchors.append(at)
	anchors.append(Vector2(STATIONS[1].x,STATIONS[1].z))
	var planar_total:float=anchors[0].distance_to(anchors[-1]);var result:Array[Vector3]=[]
	for span in anchors.size()-1:
		var pieces:int=maxi(1,ceili(anchors[span].distance_to(anchors[span+1])/2.0))
		for j in pieces:
			var at:Vector2=anchors[span].lerp(anchors[span+1],float(j)/pieces)
			var along:float=anchors[0].distance_to(at);var edge:float=minf(along,planar_total-along)
			var baseline:float=lerpf(STATIONS[0].y,STATIONS[1].y,along/planar_total)
			var floor_y:float=baseline
			# Sample both lanes plus cabin width. These are cabin-floor heights, not wire heights.
			for offset in [Vector2.ZERO,Vector2(-3,-3),Vector2(-3,3),Vector2(3,-3),Vector2(3,3)]:
				floor_y=maxf(floor_y,roof_height(world,at+offset))
			floor_y=lerpf(baseline,floor_y,smoothstep(0,20,edge))
			result.append(Vector3(at.x,floor_y,at.y))
	result.append(STATIONS[1])
	# Remove sawtooth dips while leaving the two boarding decks at their authored heights.
	for i in range(1,result.size()-1):
		var neighbor:float=result[i-1].y-Vector2(result[i].x-result[i-1].x,result[i].z-result[i-1].z).length()*.85
		result[i].y=maxf(result[i].y,neighbor)
	for i in range(result.size()-2,0,-1):
		var neighbor:float=result[i+1].y-Vector2(result[i].x-result[i+1].x,result[i].z-result[i+1].z).length()*.85
		result[i].y=maxf(result[i].y,neighbor)
	return result

static func point_at(points:Array[Vector3],fraction:float)->Vector3:
	if points.is_empty():return Vector3.ZERO
	if points.size()==1:return points[0]
	var lengths:PackedFloat32Array=[0.0];var length:=0.0
	for i in points.size()-1:length+=points[i].distance_to(points[i+1]);lengths.append(length)
	var wanted:float=clampf(fraction,0,1)*length
	for i in points.size()-1:
		if wanted<=lengths[i+1]:return points[i].lerp(points[i+1],(wanted-lengths[i])/maxf(.001,lengths[i+1]-lengths[i]))
	return points[-1]

static func lane_at(points:Array[Vector3],fraction:float,index:int)->Vector3:
	var at:Vector3=point_at(points,fraction)
	var tangent:Vector3=point_at(points,minf(1,fraction+.002))-point_at(points,maxf(0,fraction-.002));tangent.y=0
	var side:Vector3=Vector3(-tangent.z,0,tangent.x).normalized()
	return at+side*LANE_OFFSET*(-1 if index==0 else 1)

static func station_landing(index:int)->Vector3:return STATIONS[clampi(index,0,1)]+Vector3(0,.10,4.0)

func setup(main):
	m=main;name="PairedForestGondola110";path=route_points(m.world);rebuild_lengths()
	for i in 2:
		var cabin:Node3D=build_cabin(i);add_child(cabin);cabins.append(cabin)
	status=Label.new();status.name="GondolaStatus110";status.position=Vector2(550,860);status.custom_minimum_size=Vector2(820,54)
	status.add_theme_font_size_override("font_size",22);status.add_theme_color_override("font_outline_color",Color("1f352e"));status.add_theme_constant_override("outline_size",6);status.hide();m.hud.add_child(status)
	route_built=true;update_cabins()

func rebuild_lengths():
	cumulative=PackedFloat32Array([0.0]);total_length=0
	for i in path.size()-1:total_length+=path[i].distance_to(path[i+1]);cumulative.append(total_length)
	total_length=maxf(1,total_length)

func cached_point_at(fraction:float)->Vector3:
	if path.is_empty():return Vector3.ZERO
	if path.size()==1:return path[0]
	var wanted:float=clampf(fraction,0,1)*total_length
	if wanted>cumulative[-1]:return path[-1]
	# The authored route stays fixed. Reuse its float32 prefix distances rather
	# than rebuilding all 169 segment lengths for every cabin/camera query.
	var low:=1;var high:int=cumulative.size()-1
	while low<high:
		var middle:int=(low+high)/2
		if wanted<=cumulative[middle]:high=middle
		else:low=middle+1
	var index:int=low-1
	return path[index].lerp(path[index+1],(wanted-cumulative[index])/maxf(.001,cumulative[index+1]-cumulative[index]))

func cached_lane_at(fraction:float,index:int)->Vector3:
	var at:Vector3=cached_point_at(fraction)
	var tangent:Vector3=cached_point_at(minf(1,fraction+.002))-cached_point_at(maxf(0,fraction-.002));tangent.y=0
	var side:Vector3=Vector3(-tangent.z,0,tangent.x).normalized()
	return at+side*LANE_OFFSET*(-1 if index==0 else 1)

func part(parent:Node3D,at:Vector3,size:Vector3,tone:String,glass:bool=false)->MeshInstance3D:
	var piece:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;piece.mesh=mesh;piece.position=at
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(tone);mat.roughness=.74
	if glass:mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color.a=.20;mat.roughness=.16;piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.material_override=mat;parent.add_child(piece);return piece

func collider(parent:AnimatableBody3D,at:Vector3,size:Vector3):
	var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;col.shape=shape;col.position=at;parent.add_child(col)

func build_cabin(index:int)->Node3D:
	var cabin:=Node3D.new();cabin.name="云麓缆车"+str(index+1)
	# Parent is moved inside _physics_process; body sync would undo inherited transforms.
	var body:=AnimatableBody3D.new();body.name="EnclosedCabinBody";body.collision_layer=1;body.collision_mask=0;body.sync_to_physics=false;cabin.add_child(body);bodies.append(body)
	part(body,Vector3(0,-.08,0),Vector3(1.9,.20,2.30),"9a704a");collider(body,Vector3(0,-.08,0),Vector3(1.9,.20,2.30))
	part(body,Vector3(0,2.42,0),Vector3(2.05,.22,2.42),"496b61" if index==0 else "6f7392");collider(body,Vector3(0,2.42,0),Vector3(2.05,.22,2.42))
	for side in [-1,1]:
		for z in [-1.04,1.04]:part(body,Vector3(side*.85,1.20,z),Vector3(.11,2.4,.11),"e5d8b7")
		part(body,Vector3(side*.91,.45,0),Vector3(.12,.86,2.15),"597b6b" if index==0 else "7b7893");collider(body,Vector3(side*.91,1.12,0),Vector3(.12,2.24,2.15))
		part(body,Vector3(side*.91,1.61,0),Vector3(.035,1.34,2.02),"bad8da",true)
		part(body,Vector3(side*.56,.42,0),Vector3(.49,.17,1.30),"d1bc91")
		part(body,Vector3(side*.78,.72,0),Vector3(.12,.62,1.30),"a9926a")
	part(body,Vector3(0,.43,-1.06),Vector3(1.7,.86,.12),"77907a");collider(body,Vector3(0,1.12,-1.06),Vector3(1.7,2.24,.12))
	part(body,Vector3(0,1.59,-1.10),Vector3(1.6,1.3,.035),"bddbdf",true)
	var door:=Node3D.new();door.name="SlidingClosedDoor";body.add_child(door);doors.append(door)
	for side in [-1,1]:
		part(door,Vector3(side*.43,.48,1.10),Vector3(.82,.96,.10),"9a8b72")
		part(door,Vector3(side*.43,1.62,1.10),Vector3(.80,1.27,.035),"bddbdf",true)
		part(door,Vector3(side*.82,1.15,1.10),Vector3(.07,2.3,.09),"e5d8b7")
		part(door,Vector3(side*.1,1.14,1.17),Vector3(.06,.24,.04),"625b46")
	part(cabin,Vector3(0,2.97,0),Vector3(.16,1.02,.16),"495c55")
	part(cabin,Vector3(0,HANGER_HEIGHT,0),Vector3(.38,.18,.80),"586e63")
	for z in [-.27,.27]:part(cabin,Vector3(0,HANGER_HEIGHT+.11,z),Vector3(.43,.24,.24),"394b43")
	var light:=OmniLight3D.new();light.name="WarmCabinLamp";light.position=Vector3(0,2.12,0);light.omni_range=4;light.light_color=Color("ffdda5");light.light_energy=.6;light.shadow_enabled=false;cabin.add_child(light)
	return cabin

func is_riding()->bool:return rider>=0

func observation_anchor()->Vector3:
	return cabins[rider].global_position+Vector3(0,.24,0) if not restoring and rider>=0 and rider<cabins.size() else m.player.global_position

func anchor_points()->Array[Vector3]:
	var points:Array[Vector3]=[]
	# The persistent cabins follow an authored clearance path without streamed detail.
	# Only a passenger needs nearby building/collision scenes and an 8 s look-ahead.
	if not is_riding() or rider>=cabins.size():return points
	points.append(cabins[rider].global_position)
	if traveling:
		var future:float=clampf(progress+signf(destination-progress)*CRUISE_MPS*8.0/total_length,0,1)
		points.append(passenger_at(future))
	return points

func passenger_at(fraction:float)->Vector3:
	return cached_lane_at(fraction if rider==0 else 1-fraction,rider)

func station_for_cabin(index:int)->int:
	var fraction:float=progress if index==0 else 1-progress
	return 0 if fraction<.002 else 1 if fraction>.998 else -1

func near_station()->int:
	if m==null:return -1
	for i in 2:
		if Vector2(m.player.position.x-STATIONS[i].x,m.player.position.z-STATIONS[i].z).length()<7 and absf(m.player.position.y-STATIONS[i].y)<3:return i
	return -1

func board(station:int)->bool:
	if restoring or is_riding() or traveling or station not in [0,1]:return false
	if near_station()!=station:return false
	if not m.world.region_ready(station_landing(station)):
		if not preparing_board:
			preparing_board=true;board_request_serial+=1;prepare_board.call_deferred(station,board_request_serial)
			m.notify("正在准备缆车站台，完成后自动登舱。")
		return false
	if m.bay!=null and ((m.bay.vehicles!=null and not m.bay.vehicles.mounted.is_empty()) or (m.bay.boats!=null and not m.bay.boats.kind.is_empty())):
		m.notify("请先下车或靠岸，再进入封闭缆车舱。");return false
	var available:=-1
	for i in 2:
		if station_for_cabin(i)==station:available=i;break
	if available<0:return false
	m.player.stand_up();previous_zoom=m.player.zoom;rider=available;pose=0
	m.player.program_driven=true;m.player.velocity=Vector3.ZERO;m.player.reset_jump_state()
	m.player.arm.add_excluded_object(bodies[rider].get_rid());m.player.zoom=5.5
	destination=1.0 if progress<.5 else 0.0;traveling=true;speed=0;update_cabins();update_passenger()
	m.player.yaw=cabins[rider].rotation.y
	m.save_game(false);m.notify("缆车已发车 · X 坐姿 / 凭窗 · O 斜俯观景 · 到站后 F 下车")
	return true

func prepare_board(station:int,serial:int):
	var ready:bool=await m.world.prepare_region(station_landing(station),24.0)
	if serial!=board_request_serial:return
	preparing_board=false
	if ready and m.active_game and not m.transitioning and not m.modal.visible and near_station()==station:board(station)

func disembark()->bool:
	if restoring or not is_riding():return false
	if traveling:m.notify("缆车正在运行；到站后按 F 下车。");return false
	var station:int=station_for_cabin(rider)
	if station<0:return false
	var at:Vector3=station_landing(station)
	if not m.world.region_ready(at):m.notify("正在准备站台，请稍候再下车。");return false
	var cabin_id:int=rider;rider=-1;m.player.program_driven=false;m.player.arm.remove_excluded_object(bodies[cabin_id].get_rid())
	reset_rider_pose();m.player.zoom=previous_zoom
	m.player.global_position=at;m.player.velocity=Vector3.ZERO;m.player.reset_jump_state()
	m.player.enabled=m.active_game and not m.modal.visible and not m.environment_controls.overview
	m.save_game(false);m.notify("已抵达"+("云麓山脚站" if station==0 else "北山观景站")+"。两端各留一舱，可随时返程。")
	return true

func handle_input(event)->bool:
	if m==null or not m.active_game or m.transitioning or m.modal.visible:return false
	if m.environment_controls.overview:return false
	if not event is InputEventKey or not event.pressed or event.echo:return false
	if restoring:return event.physical_keycode in [KEY_E,KEY_F,KEY_X,KEY_SPACE]
	if event.physical_keycode==KEY_F:
		if is_riding():disembark();return true
		var station:int=near_station()
		if station>=0:
			if traveling:m.notify("两舱正在对向运行，约 %d 秒后到站。"%remaining_seconds())
			else:board(station)
			return true
	if is_riding():
		if event.physical_keycode==KEY_X:pose=(pose+1)%2;update_passenger();snapshot_state();return true
		if event.physical_keycode in [KEY_E,KEY_SPACE]:return true
	return false

func remaining_seconds()->int:return ceili(absf(destination-progress)*total_length/CRUISE_MPS)

func update_cabins():
	for i in cabins.size():
		var fraction:float=progress if i==0 else 1-progress
		var at:Vector3=cached_lane_at(fraction,i);var next:Vector3=cached_point_at(minf(1,fraction+.003));var previous:Vector3=cached_point_at(maxf(0,fraction-.003))
		var tangent:Vector3=next-previous;tangent.y=0;cabins[i].global_position=at
		if tangent.length_squared()>.001:cabins[i].rotation.y=atan2(-tangent.x,-tangent.z)
		doors[i].visible=traveling or (rider==i and station_for_cabin(i)<0)
		var light:OmniLight3D=cabins[i].get_node("WarmCabinLamp");light.light_energy=.55 if int(m.state.get("time",0))>0 else .1

func update_passenger():
	if restoring or not is_riding():return
	var cabin:Node3D=cabins[rider]
	m.player.program_driven=true;m.player.velocity=Vector3.ZERO
	m.player.global_position=cabin.global_transform*Vector3(-.45,.09,0) if pose==0 else cabin.global_transform*Vector3(0,.09,-.48)
	if pose==0:
		m.player.apply_seated_pose();m.player.figure.rotation.y=cabin.rotation.y-PI*.5
	else:
		reset_rider_pose();m.player.figure.rotation.y=cabin.rotation.y
	status.text=("前往北山" if (destination>.5)==(rider==0) else "返回山脚")+" · "+("正在准备前方区域" if waiting_for_region else "约 %d 秒到站"%remaining_seconds() if traveling else "已到站 · F 下车")+" · X 换姿态 · O 观景"

func reset_rider_pose():
	m.player.figure.position=Vector3.ZERO;m.player.figure.rotation.x=0
	for i in m.player.legs.size():m.player.legs[i].position=Vector3(-.17 if i==0 else .17,.35,0);m.player.legs[i].rotation.x=0
	for shin in m.player.seated_shins:shin.hide()
	for arm in m.player.arms:arm.rotation.x=0

func snapshot_state()->Dictionary:
	var state:Dictionary={"schema":1,"progress":progress,"destination":destination,"traveling":traveling,"speed":speed,"cabin":rider,"pose":pose,"zoom":previous_zoom}
	if m!=null and m.state.get("activities") is Dictionary:m.state.activities["cable110"]=state.duplicate(true)
	return state

func resume_active():
	if m==null:return
	var state:Dictionary=m.state.get("activities",{}).get("cable110",{}).duplicate(true)
	if state.is_empty():return
	restore_request_serial+=1;var request:int=restore_request_serial;restoring=true
	var p:float=float(state.get("progress",0));progress=clampf(p,0,1) if is_finite(p) else 0.0
	destination=1.0 if float(state.get("destination",0))>.5 else 0.0;traveling=bool(state.get("traveling",false)) and absf(destination-progress)>.00001
	var saved_speed:float=float(state.get("speed",0));speed=clampf(saved_speed,0,CRUISE_MPS) if is_finite(saved_speed) else 0.0
	var saved_cabin=state.get("cabin",-1)
	# JSON decodes integer literals as floats; Array.has/in compares their types.
	rider=int(saved_cabin) if (saved_cabin is int or saved_cabin is float) and (saved_cabin==0 or saved_cabin==1) else -1
	pose=clampi(int(state.get("pose",0)),0,1)
	var saved_zoom:float=float(state.get("zoom",6));previous_zoom=clampf(saved_zoom,2.2,10) if is_finite(saved_zoom) else 6.0
	update_cabins()
	if is_riding():
		# Keep the already prepared safe landing until the saved cabin region is ready.
		m.player.program_driven=true;m.player.velocity=Vector3.ZERO
		var ready:bool=await m.world.prepare_region(cabins[rider].global_position)
		if request!=restore_request_serial:return
		if not ready or not m.active_game:
			restoring=false;rider=-1;speed=0;m.player.program_driven=false;reset_rider_pose();m.player.zoom=previous_zoom
			snapshot_state()
			if m.active_game:m.notify("缆车所在区域尚未准备完成，已留在安全站台。")
			return
		m.player.stand_up();m.player.program_driven=true;m.player.arm.add_excluded_object(bodies[rider].get_rid());restoring=false;update_passenger()
		m.notify("已恢复缆车旅程，继续前往原目的站。")
	else:restoring=false

func release_for_travel():
	board_request_serial+=1;preparing_board=false
	restore_request_serial+=1;restoring=false
	if is_riding():
		m.player.arm.remove_excluded_object(bodies[rider].get_rid());m.player.program_driven=false;reset_rider_pose();m.player.zoom=previous_zoom
		rider=-1
	if status!=null:status.hide()
	snapshot_state()

func reset_session():
	release_for_travel();traveling=false;progress=0;destination=0;speed=0;pose=0;waiting_for_region=false;update_cabins()

func _physics_process(delta:float):
	if not route_built or m==null:return
	if m.active_game and traveling and not restoring and not m.modal.visible and not m.transitioning:
		var future:float=clampf(progress+signf(destination-progress)*CRUISE_MPS*8.0/total_length,0,1)
		var ahead_ready:bool=not is_riding() or m.world.region_ready(passenger_at(future))
		waiting_for_region=not ahead_ready
		var remaining:float=absf(destination-progress)*total_length
		var target_speed:float=minf(CRUISE_MPS,sqrt(maxf(0,2.0*ACCELERATION*remaining))) if ahead_ready else 0.0
		speed=move_toward(speed,target_speed,ACCELERATION*delta)
		var next:float=move_toward(progress,destination,speed*delta/total_length)
		if not is_riding() or m.world.region_ready(passenger_at(next)):progress=next
		else:speed=0;waiting_for_region=true
		if ahead_ready and remaining<.06:
			progress=destination;traveling=false;speed=0;waiting_for_region=false
			if is_riding():m.save_game(false);m.notify("缆车已到站，按 F 走上站台。")
	update_cabins();update_passenger()
	status.visible=m.active_game and is_riding() and not restoring and not m.modal.visible and not m.photo_mode
	for cabin in cabins:cabin.visible=m.active_game
	prompt_tick-=delta
	if m.active_game and not is_riding() and not m.modal.visible and not m.environment_controls.overview and prompt_tick<=0:
		prompt_tick=.15
		if near_station()>=0:m.prompt.text="F  乘坐云麓缆车" if not traveling else "缆车运行中 · 到站后 F 登舱"
