extends SceneTree
## Isolated logic tests. No main scene, save store, media, bake or GPU acceptance.
const Cable=preload("res://scripts/creative_transport110.gd")
const Layout=preload("res://scripts/world_layout.gd")
var results:Array=[]
var main
var transport

class FakeWorld extends Node:
	signal preparation_finished(ready:bool)
	var layout
	var spec:Dictionary={}
	var blocked:=false
	var delayed:=false
	var prepared:Array=[]
	func height_at(x:float,z:float)->float:return layout.height_at(Vector2(x,z))
	func transport_obstacle_height(point:Vector2)->Dictionary:
		# One deterministic authored-style obstacle exercises the shared clearance contract.
		var roof:float=height_at(point.x,point.y)
		if point.distance_to(Vector2(-174,-237))<11:roof+=24
		return {"roof":roof,"canopy":height_at(point.x,point.y)+10}
	func region_ready(_point:Vector3)->bool:return not blocked
	func prepare_region(point:Vector3,_radius:float=24.0)->bool:
		prepared.append(point)
		if delayed:return await preparation_finished
		return not blocked

class FakePlayer extends Node3D:
	var arm:SpringArm3D
	var figure:Node3D
	var legs:Array=[]
	var arms:Array=[]
	var seated_shins:Array=[]
	var velocity:=Vector3.ZERO
	var program_driven:=false
	var enabled:=true
	var zoom:=6.0
	var yaw:=0.0
	func _init():
		arm=SpringArm3D.new();add_child(arm);figure=Node3D.new();add_child(figure)
	func stand_up():pass
	func reset_jump_state():pass
	func apply_seated_pose():pass

class FakeMain extends Node3D:
	var world
	var player
	var hud:Control
	var modal:Control
	var prompt:Label
	var state:Dictionary={"activities":{},"time":0}
	var environment_controls:Dictionary={"overview":false}
	var active_game:=true
	var transitioning:=false
	var photo_mode:=false
	var bay=null
	var save_calls:=0
	var notices:Array=[]
	func save_game(_manual:bool=false):save_calls+=1
	func notify(message:String):notices.append(message)

func _initialize():run.call_deferred()
func check(name:String,passed:bool,detail:Dictionary={}):
	results.append({"test":name,"passed":passed,"detail":detail})
	print("TRANSPORT110 ",JSON.stringify(results[-1]))

func saved(progress:float=.4,cabin:int=0)->Dictionary:
	return {"schema":1,"progress":progress,"destination":1.0,"traveling":true,"speed":3.0,"cabin":cabin,"pose":1,"zoom":6.0}

func fixture_state(state:Dictionary):main.state.activities["cable110"]=state.duplicate(true)

func reset_transport():
	main.world.delayed=false;main.world.blocked=false;main.active_game=true;main.transitioning=false;main.modal.hide();main.environment_controls.overview=false
	transport.reset_session();main.player.position=Cable.station_landing(0)

func run():
	main=FakeMain.new();root.add_child(main)
	main.world=FakeWorld.new();main.add_child(main.world);main.world.layout=Layout.new()
	main.world.spec=main.world.layout.apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json")))
	main.player=FakePlayer.new();main.add_child(main.player)
	main.hud=Control.new();main.add_child(main.hud);main.modal=Control.new();main.add_child(main.modal);main.modal.hide()
	main.prompt=Label.new();main.hud.add_child(main.prompt)
	transport=Cable.new();main.add_child(transport);transport.setup(main);transport.set_physics_process(false);transport.set_process(false)
	if "--only=invalid_values" in OS.get_cmdline_user_args():
		await invalid_value_checks();await finish();return
	var route:Array[Vector3]=transport.path
	var positions_equal:=true;var lanes_equal:=true
	for step in range(-1,2002):
		var fraction:float=float(step)/2000.0
		positions_equal=positions_equal and transport.cached_point_at(fraction).distance_to(Cable.point_at(route,fraction))<.00001
		for lane in 2:lanes_equal=lanes_equal and transport.cached_lane_at(fraction,lane).distance_to(Cable.lane_at(route,fraction,lane))<.00001
	check("cached_route_matches_all_segments_and_clamped_edges",positions_equal and lanes_equal,{"fractions":2003,"lanes":2,"tolerance_m":.00001})
	check("authored_stations_are_exact",route[0].distance_to(Cable.STATIONS[0])<.001 and route[-1].distance_to(Cable.STATIONS[1])<.001)
	var finite:=true;var clearance:=true;var lanes:=true
	var planar_length:float=Vector2(route[0].x,route[0].z).distance_to(Vector2(route[-1].x,route[-1].z))
	for point in route:
		finite=finite and point.is_finite()
		var at:=Vector2(point.x,point.z)
		if at.distance_to(Vector2(route[0].x,route[0].z))>21 and at.distance_to(Vector2(route[-1].x,route[-1].z))>21:
			var envelope:Dictionary=main.world.transport_obstacle_height(at)
			clearance=clearance and point.y>=main.world.height_at(point.x,point.z)+7.99 and point.y>=float(envelope.roof)+7.99 and point.y>=float(envelope.canopy)+2.99
	for n in range(1,20):
		var fraction:float=float(n)/20
		var a:Vector3=Cable.lane_at(route,fraction,0);var b:Vector3=Cable.lane_at(route,fraction,1)
		lanes=lanes and absf(a.distance_to(b)-Cable.LANE_OFFSET*2)<.005 and ((a+b)*.5).distance_to(Cable.point_at(route,fraction))<.005
	check("finite_route_and_requested_clearance",finite and clearance,{"samples":route.size(),"length_m":transport.total_length,"planar_m":planar_length})
	check("parallel_lanes_share_center_and_clearance",lanes)
	check("approved_cruise_duration",is_equal_approx(Cable.CRUISE_MPS,4) and transport.total_length/4>=80 and transport.total_length/4<=130,{"cruise_seconds":transport.total_length/4})
	check("idle_does_not_pin_remote_stream_cells",transport.anchor_points().is_empty())
	reset_transport()
	var boarded:bool=transport.board(0)
	check("lower_station_board_is_physical_and_saved_once",boarded and transport.is_riding() and main.player.program_driven and main.save_calls==1)
	var start:float=transport.progress
	for n in 90:transport._physics_process(1.0/30)
	check("smooth_acceleration_and_two_cab_motion",transport.progress>start and transport.speed<=4 and transport.speed>0 and transport.cabins[0].global_position.distance_to(Cable.lane_at(route,transport.progress,0))<.001 and transport.cabins[1].global_position.distance_to(Cable.lane_at(route,1-transport.progress,1))<.001)
	var before:float=transport.progress;var before_speed:float=transport.speed
	main.modal.show()
	for n in 30:transport._physics_process(1.0/30)
	check("modal_freezes_progress_and_speed",transport.progress==before and transport.speed==before_speed)
	main.modal.hide();main.transitioning=true
	transport._physics_process(1.0)
	check("transition_freezes_progress",transport.progress==before)
	main.transitioning=false;main.active_game=false;transport._physics_process(1.0)
	check("inactive_game_freezes_progress",transport.progress==before)
	main.active_game=true;main.world.blocked=true
	for n in 90:transport._physics_process(1.0/30)
	check("unready_region_never_advances_cabins",transport.progress==before and transport.speed==0 and transport.waiting_for_region)
	main.world.blocked=false
	var elapsed:=3.0;var cap:=0
	while transport.traveling and cap<4800:
		transport._physics_process(1.0/30);elapsed+=1.0/30;cap+=1
	check("full_leg_arrives_and_disembarks_on_platform",not transport.traveling and absf(transport.progress-1)<.0001 and transport.disembark() and main.player.position.distance_to(Cable.station_landing(1))<.001,{"simulated_moving_seconds":elapsed})
	check("upper_station_has_return_cabin",transport.board(1) and transport.rider==0 and transport.destination==0)
	transport.release_for_travel();transport.reset_session();main.player.position=Cable.station_landing(1)
	check("initial_upper_station_uses_cabin_one",transport.board(1) and transport.rider==1 and transport.destination==1)
	transport.release_for_travel();reset_transport()
	main.environment_controls.overview=true
	var key:=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true
	check("free_observation_cannot_board_with_f",not transport.handle_input(key) and not transport.is_riding())
	reset_transport();var desired:Dictionary=saved(.37,1);fixture_state(desired)
	await transport.resume_active()
	check("resume_exact_cabin_progress_and_pose",transport.rider==1 and absf(transport.progress-.37)<.00001 and transport.pose==1 and main.player.program_driven and main.player.position.distance_to(transport.cabins[1].global_transform*Vector3(0,.09,-.48))<.001)
	for cabin_id in [0,1]:
		reset_transport();var cold:Dictionary=JSON.parse_string(JSON.stringify(saved(.37,cabin_id)));fixture_state(cold)
		await transport.resume_active()
		check("json_cold_restore_cabin_"+str(cabin_id),transport.rider==cabin_id and transport.pose==1 and absf(transport.progress-.37)<.00001 and main.player.program_driven)
	var calls:int=main.save_calls
	for n in 20:transport.snapshot_state()
	check("snapshots_do_not_write_save_store",main.save_calls==calls)
	reset_transport();var safe_point:Vector3=main.player.position;main.world.delayed=true;fixture_state(saved(.42,0))
	transport.resume_active();transport._physics_process(1.0)
	check("restore_wait_never_moves_passenger_into_unready_region",transport.restoring and main.player.position==safe_point and absf(transport.progress-.42)<.00001)
	transport.release_for_travel();main.world.preparation_finished.emit(true);await process_frame
	check("cancelled_restore_never_reattaches",not transport.restoring and not transport.is_riding() and not main.player.program_driven and main.player.position==safe_point)
	reset_transport();safe_point=main.player.position;main.world.delayed=true;fixture_state(saved(.5,0));transport.resume_active()
	main.world.preparation_finished.emit(false);await process_frame
	check("failed_restore_retains_prepared_safe_position",not transport.is_riding() and not main.player.program_driven and main.player.position==safe_point)
	reset_transport();fixture_state(saved(3.2,-1));await transport.resume_active()
	check("out_of_range_progress_clamps_to_route",transport.progress==1.0 and not transport.traveling)
	await invalid_value_checks();await finish()

func invalid_value_checks():
	reset_transport();var invalid:Dictionary=saved(NAN,-1);invalid.speed=NAN;invalid.zoom=NAN;invalid.destination=NAN;fixture_state(invalid);await transport.resume_active()
	check("nan_save_fields_are_repaired",is_finite(transport.progress) and is_finite(transport.speed) and is_finite(transport.previous_zoom) and is_finite(transport.destination))
	reset_transport();invalid=saved(.2,999);fixture_state(invalid);await transport.resume_active()
	check("invalid_cabin_does_not_attach_to_an_arbitrary_cabin",not transport.is_riding())
	reset_transport();invalid=saved(.2);invalid.cabin=.9;fixture_state(invalid);await transport.resume_active()
	check("fractional_cabin_does_not_truncate_to_valid_zero",not transport.is_riding())

func finish():
	transport.release_for_travel()
	var failures:=0
	for result in results:
		if not result.passed:failures+=1
	print("TRANSPORT110_SUMMARY ",JSON.stringify({"checks":results.size(),"failures":failures,"scope":"real transport logic and authored layout heights; fake readiness/player/save counter; no GPU, real input, full world, media or normal save used","user_data":OS.get_user_data_dir()}))
	main.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
