extends RefCounted
## Observes the ordinary UI/controller. Gameplay is driven only by Windows input.
var main
var elapsed:=0.0
var sequence:=0
var last_request:=""
var busy:=false
var last_capture:Dictionary={}
var render_mode:=""
var render_warm:=0.0
var render_samples:Dictionary={}
var render_last_usec:=0

func observe_render(delta:float):
	var now:int=Time.get_ticks_usec()
	var frame:float=float(now-render_last_usec)/1000.0 if render_last_usec>0 else delta*1000.0
	render_last_usec=now
	var mode:=""
	if main.active_game and not main.transitioning and not main.modal.visible and not busy:
		if main.transport!=null and main.transport.is_riding():mode="cable"
		elif not main.bay.boats.kind.is_empty():mode="boat"
		elif not main.bay.vehicles.mounted.is_empty():mode=main.bay.vehicles.mounted
		elif not main.environment_controls.overview:mode="walking"
	if mode!=render_mode:render_mode=mode;render_warm=0.0;return
	render_warm+=minf(delta,.1)
	if mode.is_empty() or render_warm<.75:return
	if not render_samples.has(mode):render_samples[mode]=[]
	var values:Array=render_samples[mode];values.append(frame)
	# This observer exists only in the bounded desktop QA run. Keep the entire
	# journey, including slow departure frames; a rolling 30 s tail would hide them.

func render_statistics()->Dictionary:
	var result:Dictionary={}
	for mode in render_samples:
		var values:Array=render_samples[mode].duplicate();values.sort();var total:=0.0
		for value in values:total+=float(value)
		if not values.is_empty():result[mode]={"frames":values.size(),"duration_ms":total,"average_fps":1000.0*values.size()/maxf(total,.001),"p95_ms":values[int(values.size()*.95)],"window":"all measured frames in this process; no rolling truncation"}
	return result

func run(target):
	main=target
	write_snapshot()

func controls(node:Node,result:Array):
	if node is Control and not node.is_visible_in_tree():return
	if node is Button:
		var rect:Rect2=node.get_global_rect()
		result.append({"kind":"button","text":node.text,"disabled":node.disabled,"focused":node.has_focus(),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	elif node is LineEdit:
		var rect:Rect2=node.get_global_rect();result.append({"kind":"line_edit","text":node.placeholder_text,"value":node.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	elif node.get_script()==preload("res://scripts/bay_map_view.gd") and not node.mini:
		for zone in node.places():
			var p:Vector2=node.global_position+node.point(zone.x,zone.z)
			result.append({"kind":"map_zone","text":zone.id,"center":[p.x,p.y]})
	for child in node.get_children():controls(child,result)

func write_snapshot():
	if main==null:return
	sequence+=1
	var visible:Array=[]
	controls(main.menu,visible);controls(main.modal,visible);controls(main.hud,visible)
	var saved:Dictionary=main.store.read()
	var p:Vector3=main.player.position
	var size:Vector2=main.get_viewport().get_visible_rect().size
	var record:={"pid":OS.get_process_id(),"sequence":sequence,"ticks_ms":Time.get_ticks_msec(),"mode":main.qa_mode,"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","version":ProjectSettings.get_setting("application/config/version"),"active_game":main.active_game,"transitioning":main.transitioning,"menu_visible":main.menu.visible,"modal_visible":main.modal.visible,"hud_visible":main.hud.visible,"player_enabled":main.player.enabled,"program_driven":main.player.program_driven,"automated_motion":main.player.automated_motion,"position":[p.x,p.y,p.z],"yaw":main.player.yaw,"pitch":main.player.pitch,"zoom":main.player.zoom,"on_floor":main.player.is_on_floor(),"mouse_mode":Input.mouse_mode,"photo_mode":main.photo_mode,"photo_saving":main.photo_saving,"photo_count":main.state.shots.size(),"last_photo":main.last_photo_capture,"target_zone":main.target_zone.get("id",""),"viewport_size":[size.x,size.y],"controls":visible,"saved_position":saved.get("position",[]),"saved_photos":saved.get("shots",[]),"last_capture":last_capture,"store_error":main.store.last_error}
	record.merge({"water_edge_blocked":main.player.water_edge_blocked,"camera_fov":main.player.camera.fov,"inside_building":main.world.inside_building(p),"zone_text":main.zone_label.text,"tea_lamp":main.state.get("activities",{}).get("tea_lamp",false)})
	if main.bay!=null:
		record.merge({"farm_inventory":main.state.get("inventory",{}),"farm_plots":main.state.get("activities",{}).get("farm_plots",{}),"fed_pig":main.state.get("activities",{}).get("fed_pig",0),"moored_boats":main.state.get("activities",{}).get("moored_boats",[]),"fps":Performance.get_monitor(Performance.TIME_FPS)})
		record.merge({"vehicle":main.bay.vehicles.mounted,"vehicle_speed":main.bay.vehicles.speed,"handheld":main.state.get("handheld","natural"),"boat":main.bay.boats.kind,"boat_pose":main.bay.boats.viewing_pose,"seated":main.player.seated,"rest_pose":main.player.rest_pose,"f_target":main.bay.f_target.get("id",""),"workshops":main.state.activities.get("workshops105",{}),"minimap_collapsed":main.hud.get_node("BayMiniMap").collapsed})
	if main.bay!=null and main.bay.dual!=null:record.merge({"dual106":main.state.activities.get("dual106",{}),"island2":main.state.activities.get("island_02_state",{}),"public_boats":main.state.activities.get("public_boat_sources106",{}),"boat_speed":main.bay.boats.speed,"media_playing":main.video.is_playing(),"media_position":main.video.stream_position,"current_screen":main.current_screen_id})
	if main.bay!=null:
		var contacts:Array=[]
		for action in main.world.interactions:
			if action.kind not in ["bay_vehicle","bay_public_boat","bay_boat"] or action.pos.distance_to(p)>48:continue
			var at:Vector3=action.pos;contacts.append({"id":action.id,"kind":action.kind,"title":action.title,"position":[at.x,at.y,at.z],"data":action.data})
		record.merge({"nearby_transport":contacts,"vehicle_heading":main.bay.vehicles.heading,"vehicle_testing":main.bay.vehicles.testing,"boat_heading":main.bay.boats.heading,"boat_testing":main.bay.boats.testing,"boat_auto_target":main.bay.boats.auto_target,"boat_active_source":main.bay.boats.active_source,"camera_movement_yaw":main.environment_controls.movement_yaw()})
	var station_action:Dictionary={}
	for action in main.world.interactions:
		if action.id=="Z01":station_action=action;break
	var marker:Vector3=station_action.get("pos",Vector3.ZERO)
	var cursor:Vector2=main.get_viewport().get_mouse_position()
	record.merge({"cursor_viewport":[cursor.x,cursor.y],"stamps":main.state.stamps,"interaction_id":main.current.get("id",""),"station_stamp_position":[marker.x,marker.y,marker.z],"photo_path":ProjectSettings.globalize_path(main.photo_directory()+"/"+str(main.last_photo_capture.get("filename",""))) if main.last_photo_capture.get("saved",false) else ""})
	record.merge({"jump_count":main.player.jump_count,"velocity":[main.player.velocity.x,main.player.velocity.y,main.player.velocity.z],"overview":main.environment_controls.overview,"overview_center":[main.environment_controls.center.x,main.environment_controls.center.y],"overview_extent":main.environment_controls.extent,"time":main.state.time,"weather":main.environment_controls.weather,"environment_panel":main.environment_panel_open,"rain_visible":main.environment_controls.rain.visible})
	# Read-only 0110 observation. No item, transport, camera or gameplay setters are called.
	record["native_render_performance"]=render_statistics()
	record.merge({"follow":main.environment_controls.follow,"overview_focus_y":main.environment_controls.free_focus_y,"save_directory":ProjectSettings.globalize_path(main.store.directory),"creative110":main.state.get("creative110",{}),"saved_creative110":saved.get("creative110",{}),"saved_cable110":saved.get("activities",{}).get("cable110",{})})
	var floor_plan:Control=main.modal.find_child("FloorPlan120",true,false)
	record["floor_plan120"]={"visible":is_instance_valid(floor_plan) and floor_plan.is_visible_in_tree(),"level":floor_plan.level if is_instance_valid(floor_plan) else -1,"place":floor_plan.place.get("id","") if is_instance_valid(floor_plan) else ""}
	var creative=main.get("creative")
	if creative!=null:
		record.merge({"creative_bag_visible":main.modal.visible and main.modal.get_node_or_null("CreativeBagMarker")!=null,"creative_bag_search":creative.bag_search,"creative_chosen_uid":creative.chosen_uid,"creative_placing_uid":creative.placing_uid,"creative_hand_visible":is_instance_valid(creative.held_hand) and creative.held_hand.is_visible_in_tree(),"creative_back_visible":is_instance_valid(creative.held_back) and creative.held_back.is_visible_in_tree()})
	var transport=main.get("transport")
	if transport!=null:
		var cabin_positions:Array=[]
		for cabin in transport.cabins:
			var at:Vector3=cabin.global_position;cabin_positions.append([at.x,at.y,at.z])
		var body_offsets:Array=[]
		for i in transport.cabins.size():body_offsets.append(transport.cabins[i].global_position.distance_to(transport.bodies[i].global_position))
		record["transport110"]={"body_offsets":body_offsets,"rider":transport.rider,"progress":transport.progress,"pose":transport.pose,"traveling":transport.traveling,"speed":transport.speed,"restoring":transport.restoring,"cabin_positions":cabin_positions}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+"_live.json",FileAccess.WRITE)
	if file==null:push_error("Desktop observer snapshot could not be written");return
	file.store_string(JSON.stringify(record));file.close()

func sample(delta:float):
	if main==null:return
	observe_render(delta)
	elapsed+=delta
	if elapsed<0.15 or busy:return
	elapsed=0.0
	write_snapshot()
	var path:String=main.evidence_root+"reports/"+main.qa_mode+"_request.json"
	if not FileAccess.file_exists(path):return
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary:return
	var request:Dictionary=parser.data
	# A cold-start process must not replay a previous process's capture request.
	if int(request.get("pid",-1))!=OS.get_process_id():return
	var id:=str(request.get("id",""))
	if id.is_empty() or id==last_request:return
	last_request=id
	# The only command captures the currently displayed viewport. No teleport/UI/gameplay commands.
	if request.get("action","")!="capture":return
	if not id.is_valid_identifier():return
	busy=true
	var ok:bool=await main.wait_for_viewport_draw()
	var name:String=main.qa_mode+"_"+id+".png"
	var err:int=ERR_UNAVAILABLE
	if ok:err=main.get_viewport().get_texture().get_image().save_png(main.evidence_root+"screenshots/"+name)
	last_capture={"id":id,"path":name,"ok":ok and err==OK,"error":err}
	busy=false;write_snapshot()
