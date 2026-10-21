extends SceneTree

func _initialize():
	print("DESIGN_HANDOFF_PROBE ",JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"main_scene":ResourceLoader.exists("res://scenes/world/main.tscn"),"user_data":OS.get_user_data_dir(),"no_focus_flag":ClassDB.class_get_integer_constant("Window","FLAG_NO_FOCUS")}))
	quit()
