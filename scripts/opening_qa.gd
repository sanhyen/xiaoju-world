extends "res://scripts/nature_qa.gd"

func run(target):
	main=target;main.store.directory="user://qa_isolated/"+main.qa_mode
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/opening_view_083.json"))
	await main.start_game(false)
	main.player.enabled=false;main.player.program_driven=true
	main.player.automated_motion=true;main.player.automated_horizontal=Vector2.ZERO
	for tick in 34:await main.get_tree().physics_frame
	main.player.automated_motion=false
	var p=main.player
	var look:=Vector3(config.look_at[0],config.look_at[1],config.look_at[2])
	var camera:Camera3D=p.camera
	var pixel:=camera.unproject_position(look)
	var rect:Rect2=main.get_viewport().get_visible_rect()
	check("new_game_uses_station_forecourt",Vector2(p.position.x-config.spawn[0],p.position.z-config.spawn[2]).length()<0.10)
	check("standing_on_actual_ground",p.is_on_floor())
	check("landmark_projects_in_actual_player_camera",not camera.is_position_behind(look) and rect.has_point(pixel),{"pixel":str(pixel),"viewport":str(rect)})
	check("landmark_horizontal_composition",absf(pixel.x-rect.get_center().x)<rect.size.x*0.12)
	var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,look)
	ray.exclude=[p.get_rid()]
	var hit:Dictionary=main.world.get_world_3d().direct_space_state.intersect_ray(ray)
	var station:Dictionary={}
	for building in main.world.spec.buildings:
		if building.id=="B01":station=building;break
	var station_blocks:=false
	if not hit.is_empty():
		station_blocks=absf(hit.position.x-station.x)<=station.w/2+0.2 and absf(hit.position.z-station.z)<=station.d/2+0.2
	check("station_corner_does_not_block_landmark_ray",not station_blocks,{"first_hit":str(hit.position) if not hit.is_empty() else "none"})
	var actual_view:={"player":str(p.position),"yaw":p.yaw,"camera":str(camera.global_position),"landmark":str(look),"projected_pixel":str(pixel)}
	# One source image for the changed opening view; no image loop or native duplicate capture.
	var image_path:=""
	if OS.has_feature("editor"):
		await main.get_tree().process_frame;await RenderingServer.frame_post_draw
		image_path=main.evidence_root+"screenshots/"+main.qa_mode+"_first_view.png"
		check("single_opening_capture",main.get_viewport().get_texture().get_image().save_png(image_path)==OK)
	var legacy:Dictionary=main.fresh_state.duplicate(true)
	legacy.game_version="0.7.9-environment-development";legacy.position=[260.0,1.0,193.0];legacy.yaw=-0.71
	check("isolated_legacy_heading_save",main.store.write(legacy))
	await main.start_game(true)
	check("continue_preserves_saved_heading",absf(main.player.yaw+0.71)<0.001)
	check("continue_preserves_saved_position",Vector2(main.player.position.x-260.0,main.player.position.z-193.0).length()<0.10)
	var failed:=0
	for item in checks:
		if not item.passed:failed+=1
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failed,"opening":actual_view,"image":image_path,"scope":"Default starting position/heading, actual camera projection and station-corner ray; synthetic isolated079 save preserves old heading/position. One source image, no repeated full regression. Not complete world art acceptance."}
	var f:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close()
	main.get_tree().quit(1 if failed else 0)
