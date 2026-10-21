extends SceneTree
func _initialize():
	DirAccess.make_dir_recursive_absolute("res://LICENSES")
	var file:=FileAccess.open("res://LICENSES/GODOT_LICENSE.txt",FileAccess.WRITE)
	file.store_string(Engine.get_license_text());file.close()
	file=FileAccess.open("res://LICENSES/GODOT_THIRD_PARTY_LICENSES.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine_version":Engine.get_version_info().string,"copyright":Engine.get_copyright_info(),"licenses":Engine.get_license_info()},"\t"));file.close()
	print("ENGINE_LICENSES_WRITTEN ",Engine.get_version_info().string)
	quit()
