extends "res://scripts/nature_qa.gd"

func run(target):
	main=target;main.store.directory="user://qa_isolated/"+main.qa_mode
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=75
	check("four_shadow_splits",main.sun.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	check("four_sample_msaa",main.get_viewport().msaa_3d==Viewport.MSAA_4X)
	for index in 3:
		main.set_time(index)
		check("water_material_bound_"+str(index),main.world.water_material!=null)
		if main.world.water_material!=null:
			var actual=main.world.water_material.get_shader_parameter("horizon_tone")
			var expected=main.environment.environment.sky.sky_material.get_shader_parameter("horizon_color")
			check("shared_sky_sea_palette_"+str(index),actual==expected,{"sea":str(actual),"sky":str(expected)})
		# Three changed light presets in one source run; no old17-camera gallery repeated.
		if OS.has_feature("editor"):
			await main.qa_capture(main.qa_mode+"_sea_"+str(index),Vector3(0,4.0,370),Vector3(0,2.5,2500))
	var failures:=0
	for item in checks:
		if not item.passed:failures+=1
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"scope":"Only changed shadow/AA settings and actual streamed-water material palette; Source three light presets, no repeated old image gallery. Visual/performance acceptance remains separate."}
	var f:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close();main.get_tree().quit(1 if failures else 0)
