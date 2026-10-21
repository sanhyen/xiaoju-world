extends RefCounted
## One consolidated graphical pass. It never reads or writes the normal save namespace.
var m
var results:Array=[]
var frame_ms:Array=[]
var measuring:=false
var phase:=""
var sampled:Dictionary={}
var live_tick:=0.0
var retry_ids:Dictionary={}
var parts:PackedStringArray=[]
var retry_file:=""
var measured_last_usec:=0
var performance_conditions:Dictionary={}
func needed(id:String)->bool:return retry_ids.is_empty() or retry_ids.has(id)
func sample(delta:float):
	if measuring:
		var now:int=Time.get_ticks_usec()
		var frame:float=float(now-measured_last_usec)/1000.0 if measured_last_usec>0 else delta*1000.0
		measured_last_usec=now;frame_ms.append(frame)
		if not sampled.has(phase):sampled[phase]=[]
		sampled[phase].append(frame)
	else:measured_last_usec=0
	live_tick+=delta
	if live_tick>.75 and m!=null:
		live_tick=0;write_progress()
func write_progress():
	var f:=FileAccess.open(m.evidence_root+"reports/creative110_progress.json",FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify({"pid":OS.get_process_id(),"phase":phase,"checks":results.size(),"failed":results.filter(func(r):return not r.ok).size(),"position":m.player.position}));f.close()
func record(id:String,ok:bool,data:Dictionary={}):
	results.append({"id":id,"ok":ok,"data":data});print("C110_CHECK ",id," ",ok," ",JSON.stringify(data))
	write_progress()
func run(main):
	m=main
	await m.start_game(false)
	await m.get_tree().physics_frame
	var protected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/protected_interactions_0106.json"))
	var actual:Dictionary={}
	for action in m.world.interactions:actual[str(action.id)]=true
	var missing:Array=[]
	for id in protected.ids:
		if not actual.has(id):missing.append(id)
	record("protected_463_ids",missing.is_empty(),{"missing":missing,"actual":actual.size()})
	record("unique_interaction_ids",actual.size()==m.world.interactions.size(),{"ids":actual.size(),"records":m.world.interactions.size()})
	record("place_registry",m.world.layout.creative_places.size()>=83,{"count":m.world.layout.creative_places.size()})
	var catalog:=FileAccess.open(m.evidence_root+"reports/creative110_places_actual.json",FileAccess.WRITE);catalog.store_string(JSON.stringify(m.world.layout.creative_places,"\t"));catalog.close()
	var specific:String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--place="):specific=arg.trim_prefix("--place=")
		if arg.begins_with("--part="):parts=arg.trim_prefix("--part=").split(",")
		if arg.begins_with("--retry="):retry_file=arg.trim_prefix("--retry=")
	if not retry_file.is_empty():
		var previous:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(retry_file))
		for failed in previous.get("failures",[]):retry_ids[str(failed.id)]=true
	if specific.is_empty() and parts.is_empty() and retry_file.is_empty():await screenshots()
	for p in m.world.layout.creative_places:
		if not parts.is_empty() and retry_file.is_empty():break
		if not specific.is_empty() and str(p.id) not in specific.split(","):continue
		if needed("entrance_"+str(p.id)):await entrance(p)
		if (str(p.id).begins_with("CASTLE_") or str(p.id) in ["AZURE_VIEW","AZURE_WEAVE"]) and (retry_ids.is_empty() or retry_ids.keys().any(func(id):return str(id).begins_with("stairs_"+str(p.id)+"_"))):await staircase(p)
		await authored_upper(p)
		if needed("floor_entries_"+str(p.id)):await floors_probe(p)
	if specific.is_empty():
		if "modes" in parts or (parts.is_empty() and retry_file.is_empty()):await mode_checks()
		if "cable" in parts or (parts.is_empty() and retry_file.is_empty()):await cable_checks()
		if "cable_downhill" in parts:await cable_downhill_checks()
		if "water" in parts or (parts.is_empty() and retry_file.is_empty()):await water_checks()
		if "items" in parts or (parts.is_empty() and needed("creative_save_roundtrip")):await item_integration()
		if "migration" in parts or (parts.is_empty() and retry_ids.keys().any(func(id):return str(id).begins_with("migration_"))):await migration_checks()
		if "perf" in parts or (parts.is_empty() and retry_file.is_empty()):await performance_routes()
		if "contracts" in parts:await doorway_contracts()
		if "guards" in parts:await new_upper_guards()
		if "shots" in parts:
			await shot("02_castle_fixed",Vector3(-40,62,110),Vector3(-112.5,23,10))
			await shot("01_east_fixed",Vector3(405,120,340),Vector3(220,12,100))
			await shot("06_forest_fixed",Vector3(-1,53,560),Vector3(-62,6,490))
			for p in m.world.layout.creative_places:
				if not str(p.id).begins_with("THEME_"):continue
				var center:=Vector3(p.center[0],p.center[1]+2,p.center[2])
				await shot(str(p.id)+"_fixed",center+Basis(Vector3.UP,float(p.door_yaw))*Vector3(18,12,24),center)
		if "shot_frost" in parts:
			for p in m.world.layout.creative_places:
				if str(p.id)!="THEME_FROST":continue
				var center:=Vector3(p.center[0],p.center[1]+2,p.center[2])
				await shot("THEME_FROST_front",center+Vector3(-18,12,24),center)
		if "shot_castle" in parts:
			await shot("02_castle_final",Vector3(-40,62,110),Vector3(-112.5,23,10))
			await shot("02_castle_upper_guard",Vector3(-104,46,31),Vector3(-112.5,40.4,16))
	frame_ms.sort()
	var stats:Dictionary={}
	for id in sampled:
		var values:Array=sampled[id];values.sort();var sum:=0.0
		for value in values:sum+=float(value)
		stats[id]={"frames":values.size(),"average_fps":1000.0*values.size()/maxf(.001,sum),"p95_ms":values[int(values.size()*.95)]}
	for id in stats:
		var ground:bool=id=="perf_ground_castle";var data:Dictionary=stats[id]
		record(id+"_target",float(data.average_fps)>=(55.0 if ground else 45.0) and float(data.p95_ms)<=(25.0 if ground else 33.0),data)
	var failures:Array=results.filter(func(r):return not r.ok)
	var report:Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"at":Time.get_datetime_string_from_system(),"checks":results,"failures":failures,"resolution":m.get_viewport().get_visible_rect().size,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"frame_samples":frame_ms.size(),"performance":stats,"performance_conditions":performance_conditions,"p95_ms":frame_ms[int(frame_ms.size()*.95)] if not frame_ms.is_empty() else 0,"performance_scope":"scripted graphical movement after resident-region preparation; foreground status is separately measured, not inferred; native traversal separately retains ordinary arrival and full journey frames"}
	var suffix:String="_"+specific.replace(",","_") if not specific.is_empty() else ""
	if not retry_file.is_empty():suffix+="_retry"
	if not parts.is_empty():suffix+="_"+"_".join(parts)
	var f:=FileAccess.open(m.evidence_root+"reports/creative110_consolidated"+suffix+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("C110_COMPLETE ",JSON.stringify({"checks":results.size(),"failed":failures.size()}));m.get_tree().quit(0 if failures.is_empty() else 1)

func move_to(point:Vector3)->bool:
	m.player.automated_motion=false;m.player.enabled=false
	if not await m.world.prepare_region(point,75):return false
	m.player.position=m.world.safe_ground_position(point);m.player.velocity=Vector3.ZERO
	await m.get_tree().physics_frame;await m.get_tree().physics_frame
	return true

func public_anchor(door:Vector3)->Vector3:
	var nearest:Vector3=door;var distance:=INF
	for r in m.world.layout.segments:
		if "approach" in str(r.id) or str(r.id).begins_with("creative110_") or r.bridge:continue
		var q:Vector3=m.world.layout.projection(Vector2(door.x,door.z),r)
		var d:float=Vector2(q.x-door.x,q.z-door.z).length()
		if d<distance:distance=d;nearest=q
	return nearest+Vector3.UP*.12

func walk_to(target:Vector3,speed:float=9.36,tolerance:float=.38)->bool:
	m.player.automated_motion=true
	var frames:int=0;var limit:int=ceili(maxf(5.0,m.player.position.distance_to(target)/speed*3+4)*60)
	while frames<limit:
		var delta:Vector3=target-m.player.position;delta.y=0
		if delta.length()<tolerance:
			m.player.automated_horizontal=Vector2.ZERO
			# A fast descent may reach the horizontal endpoint before gravity has
			# settled the capsule. Keep the real physics body still and let it land.
			for settle in 45:
				if absf(m.player.position.y-target.y)<.65 or m.player.is_on_floor():break
				await m.get_tree().physics_frame
			m.player.automated_motion=false
			return absf(m.player.position.y-target.y)<.65
		m.player.automated_horizontal=Vector2(delta.x,delta.z).normalized()*minf(speed,delta.length()*15)
		await m.get_tree().physics_frame;frames+=1
	m.player.automated_horizontal=Vector2.ZERO;m.player.automated_motion=false
	return false

func entrance(p:Dictionary):
	phase="entrance_"+str(p.id)
	var door:=Vector3(p.door[0],p.door[1]+.1,p.door[2]);var points:Array=[]
	for q in p.get("entry_path",[]):points.append(Vector3(q[0],q[1]+.1,q[2]))
	if points.is_empty():points=[public_anchor(door),door]
	var begin:Vector3=points[0]
	if not await move_to(begin):record(phase,false,{"reason":"public road resource not ready"});return
	# Resolve the public-road capsule start once; a valid ground adjustment is not a doorway warp.
	begin=m.player.position;points[0]=begin
	var ok:=true;var failed_at:Vector3=begin
	for target in points:
		if not await walk_to(target):ok=false;failed_at=target;break
	var yaw:float=p.get("door_yaw",0)
	var inner:Vector3=door-Basis(Vector3.UP,yaw)*Vector3(0,0,2.4)
	if ok:ok=await walk_to(inner);failed_at=inner
	if ok:
		ok=await walk_to(door,18.72)
		if ok:
			var reverse:Array=points.duplicate();reverse.reverse()
			for target in reverse:
				if not await walk_to(target,18.72):ok=false;failed_at=target;break
	record(phase,ok,{"public_start":begin,"door":door,"end":m.player.position,"failed_target":failed_at})

func staircase(p:Dictionary):
	if p.floors.size()<2:return
	phase="stairs_"+str(p.id)
	await move_to(Vector3(p.door[0],p.door[1]+.1,p.door[2]))
	var good:=true;var traversed:Array=[]
	for n in p.floors.size()-1:
		var failed_target:=Vector3.ZERO
		var path:Array=[]
		for route in m.world.get_meta("upper_routes110",[]):
			if str(route.owner)==str(p.id) and not route.points.is_empty() and absf(float(route.points[0].y)-float(p.floors[n]))<.04:
				for point in route.points:path.append(point+Vector3.UP*.08)
				break
		if path.is_empty():good=false
		for target in path:
			if not good:break
			good=await walk_to(target,5,.15);failed_target=target
			if good:traversed.append(target)
		record("stairs_"+str(p.id)+"_"+str(n+2),good,{"end":m.player.position,"expected_y":p.floors[n+1],"failed_target":failed_target})
		if not good:break
	if good:
		traversed.reverse()
		for target in traversed:
			if not await walk_to(target,9.36,.18):good=false;break
		record("stairs_return_"+str(p.id),good,{"end":m.player.position,"ground_floor":p.floors[0]})

func authored_upper(p:Dictionary):
	if str(p.id).begins_with("CASTLE_") or str(p.id) in ["AZURE_VIEW","AZURE_WEAVE"]:return
	for route in m.world.get_meta("upper_routes110",[]):
		if str(route.owner)!=str(p.id) or route.points.is_empty():continue
		if not needed("upper_"+str(route.id)):continue
		await move_to(route.points[0]+Vector3.UP*.1)
		var ok:=true;var failed_target:=Vector3.ZERO;var direction:="forward"
		for point in route.points:
			if not await walk_to(point+Vector3.UP*.1,5):ok=false;failed_target=point+Vector3.UP*.1;break
		if ok:
			direction="return"
			var reverse:Array=route.points.duplicate();reverse.reverse()
			for point in reverse:
				if not await walk_to(point+Vector3.UP*.1,9.36):ok=false;failed_target=point+Vector3.UP*.1;break
		record("upper_"+str(route.id),ok,{"end":m.player.position,"owner":route.owner,"failed_target":failed_target,"direction":direction})

func floors_probe(p:Dictionary):
	var missing:Array=[]
	for floor in p.get("floor_entries",[]):
		var point:=Vector3(floor.point[0],floor.point[1],floor.point[2])
		if not await m.world.prepare_region(point,24):missing.append(floor.name);continue
		var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP*1.2,1,[m.player.get_rid()])
		var hit:Dictionary=m.world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y<.65 or absf(hit.position.y-point.y)>.26:missing.append({"floor":floor.name,"point":point,"hit":hit.get("position",Vector3.INF),"normal":hit.get("normal",Vector3.ZERO)})
	record("floor_entries_"+str(p.id),missing.is_empty(),{"invalid":missing})

func mode_checks():
	await move_to(Vector3(0,4.5,110));m.player.enabled=true
	m.environment_controls.enter();await m.get_tree().process_frame
	record("overview_mode",m.environment_controls.follow or m.environment_controls.overview)
	var before:Vector3=m.player.position
	var key:=InputEventKey.new();key.physical_keycode=KEY_V;key.pressed=true;m.environment_controls.handle_input(key)
	await m.get_tree().process_frame
	record("overview_switch",m.environment_controls.overview or m.environment_controls.follow)
	m.environment_controls.leave();record("overview_keeps_position",m.player.position.distance_to(before)<.1)
	m.creative.open_bag();await m.get_tree().process_frame
	record("normal_bag_ui",m.modal.visible);m.close_modal()
	m.show_map();await m.get_tree().process_frame
	record("normal_map_ui",m.modal.visible);m.close_modal()

func cable_checks():
	phase="cable_roundtrip"
	var p:Vector3=m.transport.STATIONS[0]+Vector3(0,.1,4)
	await move_to(p);m.player.enabled=true
	var boarded:bool=m.transport.board(0)
	record("cable_board",boarded)
	if not boarded:return
	var before:float=m.transport.progress
	for i in 150:await m.get_tree().physics_frame
	record("cable_moving",m.transport.progress>before,{"progress":m.transport.progress})
	record("cable_no_air_exit",not m.transport.disembark())
	var snap:Dictionary=m.transport.snapshot_state();record("cable_snapshot",int(snap.get("cabin",-1))>=0 and float(snap.get("progress",0))>0)
	m.transport.release_for_travel()
	m.state.activities.cable110=snap.duplicate(true)
	await m.transport.resume_active()
	record("cable_resume",m.transport.is_riding())
	var end:int=Time.get_ticks_msec()+130000
	while m.transport.traveling and Time.get_ticks_msec()<end:await m.get_tree().physics_frame
	record("cable_complete_uphill",not m.transport.traveling and m.transport.progress>.999,{"progress":m.transport.progress,"length_m":m.transport.total_length,"cruise_mps":m.transport.CRUISE_MPS})
	var landed:bool=await m.transport.disembark()
	record("cable_arrival_safe_landing",landed and m.player.position.distance_to(m.transport.station_landing(1))<1)
	m.transport.release_for_travel()

func cable_downhill_checks():
	phase="cable_downhill_and_pause"
	await move_to(m.transport.station_landing(1));m.player.enabled=true
	var boarded:bool=m.transport.board(1);record("cable_upper_station_boards_downhill",boarded)
	if not boarded:return
	m.environment_controls.enter();m.environment_controls.switch_mode()
	var before:float=m.transport.progress
	for i in 45:await m.get_tree().physics_frame
	record("cable_keeps_moving_in_free_observation",absf(m.transport.progress-before)>.000001 and m.transport.is_riding(),{"before":before,"after":m.transport.progress,"direction":"downhill"})
	m.environment_controls.leave();m.open_modal("缆车暂停检查")
	var paused:float=m.transport.progress
	for i in 25:await m.get_tree().physics_frame
	record("cable_pause_freezes_exact_progress",absf(m.transport.progress-paused)<.000001)
	m.close_modal()
	var limit:int=Time.get_ticks_msec()+130000
	while m.transport.traveling and Time.get_ticks_msec()<limit:await m.get_tree().physics_frame
	var landed:bool=await m.transport.disembark()
	record("cable_complete_downhill_and_disembark",landed and m.player.position.distance_to(m.transport.station_landing(0))<1)
	if not landed:return
	var again:bool=m.transport.board(0)
	for i in 45:await m.get_tree().physics_frame
	var point:Dictionary=preload("res://scripts/location_registry.gd").find(m.world.spec,"B13")
	await m.teleport_zone(point);m.close_modal()
	var released:bool=again and not m.transport.is_riding() and not m.player.program_driven and m.transport.traveling
	var empty_progress:float=m.transport.progress
	for i in 30:await m.get_tree().physics_frame
	record("map_travel_detaches_rider_and_empty_cabins_continue",released and m.transport.progress!=empty_progress,{"position":m.player.position})

func ship_to(target:Vector2,seconds:float=50)->bool:
	var boats=m.bay.boats;var end:int=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		await m.get_tree().physics_frame
		var d:Vector2=target-Vector2(m.player.position.x,m.player.position.z)
		if d.length()<3:boats.test_input=Vector2.ZERO;boats.speed=0;return true
		var wanted:float=atan2(-d.x,-d.y);var diff:float=angle_difference(boats.heading,wanted)
		boats.test_input=Vector2(clampf(-diff*2.8,-1,1),.4 if absf(diff)>.7 else 1)
	return false

func water_checks():
	phase="boat_and_shallows";var cfg:Dictionary=m.world.layout.config;var boats=m.bay.boats
	var invalid:Array=[]
	for island in [cfg.island,cfg.island2]:
		for i in 48:
			var a:float=i*TAU/48;var point:=Vector3(island.center[0]+cos(a)*(island.radius[0]+35),cfg.sea_y+.2,island.center[1]+sin(a)*(island.radius[1]+35))
			if boats.water_at(point).is_empty():invalid.append(point)
	record("both_islands_outer_water_margin",invalid.is_empty(),{"invalid":invalid})
	for route in cfg.get("wading_paths",[]):
		if route.points.is_empty():continue
		var start:Vector3=m.world.layout.vector(route.points[0]);await move_to(start+Vector3.UP*.1)
		var ok:=true
		for entry in route.points:
			var point:Vector3=m.world.layout.vector(entry);point.y=m.world.height_at(point.x,point.z)+.1
			if not await walk_to(point,5):ok=false;break
		record("wading_"+str(route.id),ok,{"end":m.player.position})
	var source:Dictionary=cfg.public_boats.filter(func(v):return v.id=="COAST_3")[0]
	await move_to(m.world.layout.vector(source.shore));m.player.enabled=true;boats.sync_public_boats()
	var boarded:bool=await boats.board_public(source.id);boats.testing=true;boats.test_input=Vector2(0,1)
	record("free_boat_board",boarded)
	if not boarded:boats.testing=false;return
	var max_speed:=0.0
	for i in 240:
		await m.get_tree().physics_frame;max_speed=maxf(max_speed,boats.speed)
	record("yacht_new_acceleration",max_speed>10.5 and max_speed<=12.01,{"observed_mps":max_speed,"top_mps":12})
	boats.test_input=Vector2.ZERO;boats.speed=0
	var ok:=true
	for target in [Vector2(-60,395),Vector2(-150,490),Vector2(-60,565),Vector2(35,550),Vector2(145,550),Vector2(225,550),Vector2(325,535),Vector2(325,455),Vector2(325,375),Vector2(225,370),Vector2(145,410),Vector2(25,420),Vector2(-60,405)]:
		if not await ship_to(target):ok=false;break
	record("sail_complete_both_island_loop",ok,{"end":m.player.position})
	boats.test_input=Vector2.ZERO;boats.speed=0
	record("deep_water_keeps_boat",not await boats.dock() and not boats.kind.is_empty())
	var returned:bool=await ship_to(Vector2(-60,m.world.layout.shore_z(-60)+21),65)
	boats.test_input=Vector2.ZERO;boats.speed=0
	var afloat:Vector3=m.player.position;var parked_before:int=m.state.activities.get("moored_boats",[]).size()
	var docked:bool=await boats.dock()
	record("shallow_dismount_and_park",returned and docked and m.state.activities.get("moored_boats",[]).size()==parked_before+1,{"boat":afloat,"shore":m.player.position})
	boats.testing=false;boats.leave_for_travel()

func item_integration():
	phase="item_integration"
	phase="item_integration";var service=m.creative.items
	m.creative.ensure_sources();var id:="C110_WOOD_WEST"
	var before:int=service.count("wood")
	var picked:bool=m.creative.collect_source(id)
	record("real_resource_to_canonical_bag",picked and service.count("wood")==before+3)
	var blocked:bool=not m.creative.collect_source(id)
	record("resource_cannot_duplicate_before_regrowth",blocked and service.count("wood")==before+3)
	m.creative.collect_source("C110_PAPER_WEST")
	var stack_before:String=JSON.stringify(service.data().stacks)
	m.creative.begin_craft("paper_lamp",1,"castle")
	var began:bool=m.creative.crafting
	if m.creative.crafting:
		var cancel:=InputEventKey.new();cancel.pressed=true;cancel.physical_keycode=KEY_ESCAPE;m.creative.handle_input(cancel)
	record("cancel_craft_keeps_materials",began and not m.creative.crafting and JSON.stringify(service.data().stacks)==stack_before)
	service.data().knowledge.selected_tone=1
	var old_count:int=service.owned("paper_lamp").size();var wood:int=service.count("wood");var paper:int=service.count("paper");var rope:int=service.count("rope")
	m.creative.begin_craft("paper_lamp",1,"castle")
	await m.get_tree().create_timer(3.6).timeout
	var crafted:bool=service.owned("paper_lamp").size()==old_count+1
	record("real_material_craft_and_uid",crafted and service.count("wood")==wood-1 and service.count("paper")==paper-2 and service.count("rope")==rope-1)
	record("selected_palette_saved_in_work",crafted and int(service.owned("paper_lamp").back().variant.get("tone",-1))==1)
	if crafted:await placement_roundtrip(str(service.owned("paper_lamp",true).back().uid))
	var snapshots:Dictionary=service.data().duplicate(true)
	m.save_game(false)
	var saved:Dictionary=m.store.read()
	var differences:Array=[];compare_persisted(snapshots,saved.get("creative110",{}),"creative110",differences)
	record("creative_save_roundtrip",differences.is_empty(),{"works":snapshots.works.size(),"materials":snapshots.stacks.size(),"store":m.store.directory,"differences":differences})
	var model_failures:Array=[];var palette_failures:Array=[]
	for item in service.APPROVED:
		var model:Node3D=m.creative.models.make(item,{"tone":1})
		if model==null or model.get_child_count()==0:model_failures.append(item)
		var alternate:Node3D=m.creative.models.make(item,{"tone":2})
		if model!=null and alternate!=null:
			var first:Array=model.find_children("*","MeshInstance3D",true,false)
			var second:Array=alternate.find_children("*","MeshInstance3D",true,false)
			var distinct:bool=false
			for n in mini(first.size(),second.size()):
				var a:Material=first[n].material_override;var b:Material=second[n].material_override
				if a is StandardMaterial3D and b is StandardMaterial3D and a.albedo_color!=b.albedo_color:distinct=true;break
			if not distinct:palette_failures.append(item)
		if alternate!=null:alternate.free()
		if model!=null:model.free()
	record("all_28_construct_real_models",model_failures.is_empty(),{"missing":model_failures})
	record("all_28_palette_variants_visible",palette_failures.is_empty(),{"unchanged":palette_failures})

func compare_persisted(a,b,path:String,differences:Array):
	if (a is int or a is float) and (b is int or b is float):
		# JSON text rounds binary doubles; quantities remain exact integers.
		if (float(a)==floorf(float(a)) and a!=b) or absf(float(a)-float(b))>maxf(1.0,absf(float(a)))*1e-12:differences.append({"path":path,"expected":a,"actual":b})
	elif a is Dictionary and b is Dictionary:
		if a.size()!=b.size():differences.append({"path":path,"reason":"key count"})
		for key in a:
			if not b.has(key):differences.append({"path":path+"."+str(key),"reason":"missing"})
			else:compare_persisted(a[key],b[key],path+"."+str(key),differences)
	elif a is Array and b is Array:
		if a.size()!=b.size():differences.append({"path":path,"reason":"array length"});return
		for i in a.size():compare_persisted(a[i],b[i],path+"["+str(i)+"]",differences)
	elif a!=b:differences.append({"path":path,"expected":a,"actual":b})

func migration_checks():
	phase="moved_room_migration"
	var migration=preload("res://scripts/creative_migration110.gd")
	for place in m.world.layout.creative_places:
		if not place.has("legacy_center"):continue
		var c:Array=place.legacy_center
		var old:=Vector3(c[0]+1,float(c[1])+float(m.world.layout.config.sea_y)+.1,c[2]+1)
		var sample:Dictionary={"position":[old.x,old.y,old.z],"safe_point":[old.x,old.y,old.z],"interior":place.id,"yaw":.3,"game_version":"0.10.6"}
		migration.migrate(sample,m.world)
		var target:=Vector3(sample.position[0],sample.position[1],sample.position[2])
		var expected:=Vector3(place.center[0],place.center[1],place.center[2])+Basis(Vector3.UP,float(place.door_yaw))*Vector3(1,.1,1)
		record("migration_local_"+str(place.id),target.distance_to(expected)<.001 and sample.position==sample.safe_point)
		await m.world.prepare_region(target,40)
		var resolved:Vector3=migration.resolve_after_stream(sample,m.world,target)
		record("migration_supported_"+str(place.id),migration.within_place(resolved,place) and migration.supported(m.world,resolved,place).is_finite(),{"target":target,"resolved":resolved})
		var encoded:String=JSON.stringify(sample);migration.migrate(sample,m.world)
		record("migration_once_"+str(place.id),JSON.stringify(sample)==encoded)
		var wall:=Vector3(place.center[0]+place.size[0]*.5-.1,float(place.floors[-1])+.08,place.center[2])
		var blocked:Dictionary={"migration110":{"position_place":place.id,"changes":[]}}
		var fallback:Vector3=migration.resolve_after_stream(blocked,m.world,wall)
		record("migration_same_room_fallback_"+str(place.id),migration.within_place(fallback,place) and migration.supported(m.world,fallback,place).is_finite(),{"requested":wall,"resolved":fallback})
	var road:Dictionary={"position":[289.0,3.95,248.0],"safe_point":[289.0,3.95,248.0],"interior":"","yaw":.3}
	var original:Array=road.position.duplicate();migration.migrate(road,m.world)
	record("migration_keeps_normal_road_position",road.position==original)

func placement_roundtrip(uid:String):
	var place:Dictionary={}
	for candidate in m.world.layout.creative_places:
		if candidate.id=="B12":place=candidate;break
	var o:=Vector3(place.center[0],place.center[1],place.center[2])
	await move_to(o+Vector3(0,.1,3));m.player.enabled=true
	m.creative.start_placement(uid);var valid:=false
	for x in [-3.0,3.0,-1.5,1.5]:
		for z in [-3.0,0.0,2.0]:
			var aim:Vector3=o+Vector3(x,0,z)
			m.watch_camera.position=aim+Vector3.UP*2.8;m.watch_camera.look_at(aim,Vector3.FORWARD);m.watch_camera.current=true
			m.creative.update_placement()
			if m.creative.placement_ok:valid=true;break
		if valid:break
	var placed:bool=m.creative.commit_placement() if valid else false
	record("real_supported_private_placement",placed,{"reason":m.creative.placement_reason,"area":m.creative.placement_area.get("id","")})
	if placed:
		await m.get_tree().create_timer(.25).timeout
		record("placed_work_has_physical_model",m.creative.placed_nodes.has(uid))
		var original:Dictionary=m.creative.items.data().works[uid].duplicate(true)
		m.creative.start_placement(uid)
		var began:bool=m.creative.moving_existing and m.creative.placing_uid==uid
		m.creative.cancel_placement();await m.get_tree().create_timer(.25).timeout
		record("move_cancel_keeps_placement_and_uid",began and m.creative.items.data().works[uid]==original and m.creative.placed_nodes.has(uid))
		var before:int=m.creative.items.owned("paper_lamp").size()
		var returned:bool=m.creative.items.take(uid)
		record("real_placed_work_retrieval_conserves_uid",returned and m.creative.items.data().works[uid].location=="bag" and m.creative.items.owned("paper_lamp").size()==before)
		await m.get_tree().create_timer(.3).timeout
		m.environment_controls.enter();await m.get_tree().process_frame
		var aim:Vector3=Vector3(original.position[0],original.position[1],original.position[2])
		var screen:Vector2=m.environment_controls.camera.unproject_position(aim)
		var hit:Dictionary=m.creative.placement_surface(m.environment_controls.camera,screen)
		record("follow_cutaway_placement_reaches_current_floor",not hit.is_empty() and hit.position.distance_to(aim)<.25,{"expected":aim,"hit":hit.get("position",Vector3.INF)})
		m.environment_controls.leave()
	m.creative.cancel_placement();m.player.camera.current=true

func performance_routes():
	var route:Dictionary=m.world.layout.config.roads.filter(func(r):return r.id=="creative110_castle_main")[0]
	await move_to(m.world.layout.vector(route.points[0])+Vector3.UP*.1);m.player.enabled=true
	phase="perf_ground_warmup"
	var preparation_start:int=Time.get_ticks_msec()
	var prepared:bool=await m.world.prepare_region(m.player.global_position,184)
	# This leg measures resident exploration. Previously move_to prepared only
	# the 75 m collision region, mixing new GPU cell insertion into this short leg.
	for i in 120:await m.get_tree().process_frame
	performance_conditions={"resident_radius_m":184,"preparation_ok":prepared,"warmup_frames":120,"preparation_and_warmup_ms":Time.get_ticks_msec()-preparation_start,"route_and_measured_frames":"unchanged; all measured frames retained","opaque_sort":m.world.streamer.opaque_order.diagnostics(),"terrain_field":preload("res://scripts/terrain_fields110.gd").diagnostics()}
	record("terrain_numeric_field_bound_once",performance_conditions.terrain_field.success and performance_conditions.terrain_field.load_attempts==1 and performance_conditions.terrain_field.successful_binds>0,performance_conditions.terrain_field)
	phase="perf_ground_castle";measuring=true
	for point in route.points:await walk_to(m.world.layout.vector(point)+Vector3.UP*.1)
	for i in 120:await m.get_tree().process_frame
	measuring=false
	m.environment_controls.enter();m.environment_controls.switch_mode()
	var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_HOME;m.environment_controls.handle_input(key)
	for i in 90:await m.get_tree().process_frame
	phase="perf_full_world_overview";measuring=true
	for i in 420:await m.get_tree().process_frame
	measuring=false;m.environment_controls.leave()

func doorway_contracts():
	phase="doorway_surface_contracts"
	var invalid:Array=[];var gap_max:=0.0
	for place in m.world.layout.creative_places:
		var d:Array=place.door;var door:=Vector3(d[0],d[1],d[2])
		if not await m.world.prepare_region(door,16):invalid.append({"id":place.id,"reason":"not ready"});continue
		var heights:Array=[];var front:Vector3=Basis(Vector3.UP,float(place.door_yaw))*Vector3.BACK
		for side in [-1,1]:
			var p:Vector3=door+front*.05*side
			var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.4,p-Vector3.UP*.8,1,[m.player.get_rid()])
			var hit:Dictionary=m.world.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y<.7:invalid.append({"id":place.id,"side":side,"reason":"no horizontal portal surface"});continue
			heights.append(hit.position.y)
		if heights.size()==2:
			var gap:float=absf(float(heights[0])-float(heights[1]));gap_max=maxf(gap_max,gap)
			if gap>.0405:invalid.append({"id":place.id,"gap_m":gap,"heights":heights})
	record("all_83_door_seams_within_004m",invalid.is_empty(),{"invalid":invalid,"maximum_gap_m":gap_max,"method":"physical rays 0.05m inside/outside every registered portal; whole approaches separately walked in the consolidated run"})
	var start:=Vector3(225,.9,459);var finish:=Vector3(222,-.0811,434)
	var connected:bool=await move_to(start)
	if connected:connected=await walk_to(finish) and await walk_to(start,18.72)
	record("coral_landing_to_existing_island_path",connected,{"end":m.player.position,"actual_road":"creative110_coral_landlink"})

func new_upper_guards():
	phase="upper_guard_contracts";var invalid:Array=[];var probes:=0
	for p in m.world.layout.creative_places:
		if not str(p.id).begins_with("CASTLE_") and str(p.id) not in ["AZURE_VIEW","AZURE_WEAVE"]:continue
		for n in range(1,p.floors.size()):
			var main:bool=str(p.id)=="CASTLE_MAIN"
			var width:float=float(p.size[0])-(n*1.6 if main else 0);var depth:float=float(p.size[1])-(n*1.4 if main else 0)
			var floor:=Vector3(p.center[0],float(p.floors[n]),p.center[2])
			await m.world.prepare_region(floor,16)
			var edges:Array=[[floor+Vector3(0,0,depth*.5),Vector3.FORWARD,Vector3.RIGHT]]
			if n==2 and str(p.id) in ["CASTLE_PAPER","CASTLE_CLOTH"]:
				var sign_value:float=-1 if str(p.id)=="CASTLE_PAPER" else 1
				edges.append([floor+Vector3(sign_value*width*.5,0,0),Vector3(-sign_value,0,0),Vector3.BACK])
			for edge in edges:
				for offset in [-1.0,0.0,1.0]:
					var center:Vector3=edge[0]+edge[2]*offset+Vector3.UP*.65
					var ray:=PhysicsRayQueryParameters3D.create(center+edge[1]*.7,center-edge[1]*.7,1,[m.player.get_rid()])
					var hit:Dictionary=m.world.get_world_3d().direct_space_state.intersect_ray(ray);probes+=1
					if hit.is_empty() or absf(hit.normal.y)>.3:invalid.append({"id":p.id,"floor":n+1,"at":center})
	record("new_upper_openings_have_continuous_guards",invalid.is_empty(),{"probes":probes,"invalid":invalid})

func shot(name:String,eye:Vector3,target:Vector3):
	await move_to(target)
	m.watch_camera.position=eye;m.watch_camera.look_at(target);m.watch_camera.current=true
	for i in 10:await m.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image:Image=m.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(m.evidence_root+"screenshots/creative110")
	image.save_png(m.evidence_root+"screenshots/creative110/"+name+".png")
	m.player.camera.current=true

func screenshots():
	phase="representative_visuals"
	await shot("01_east",Vector3(405,120,340),Vector3(220,12,100))
	await shot("02_castle",Vector3(-40,62,110),Vector3(-112.5,23,10))
	await shot("03_station",Vector3(320,22,278),Vector3(280,7,235))
	await shot("04_cable",Vector3(-245,65,-110),Vector3(-210,40,-200))
	await shot("05_coral",Vector3(325,40,495),Vector3(253,1,450))
	await shot("06_forest",Vector3(-1,53,560),Vector3(-62,6,490))
	for p in m.world.layout.creative_places:
		if not str(p.id).begins_with("THEME_"):continue
		var center:=Vector3(p.center[0],p.center[1]+2,p.center[2]);var yaw:float=p.door_yaw
		await shot(str(p.id),center+Basis(Vector3.UP,yaw)*Vector3(18,12,24),center)
