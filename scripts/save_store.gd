extends RefCounted
## Versioned, checksummed envelope. Tests use a separate directory.
var directory := "user://save"
var last_error := ""
var import_directory := ""
var imported_legacy := false
var import_source_checksum:=""
var import_source_file:=""

func write(state: Dictionary) -> bool:
	last_error=""
	DirAccess.make_dir_recursive_absolute(directory)
	var payload := JSON.stringify(state)
	var envelope := JSON.stringify({"version":1,"checksum":payload.sha256_text(),"payload":payload})
	var file := FileAccess.open(directory+"/progress.tmp",FileAccess.WRITE)
	if file==null: last_error="无法创建临时存档";return false
	file.store_string(envelope);file.flush();file.close()
	if decode(directory+"/progress.tmp").is_empty(): last_error="临时存档校验失败";return false
	if not decode(directory+"/progress.json").is_empty():
		var copy_error:=DirAccess.copy_absolute(directory+"/progress.json",directory+"/progress.bak")
		if copy_error!=OK: last_error="备份失败，保留原存档";return false
	var err:=DirAccess.rename_absolute(directory+"/progress.tmp",directory+"/progress.json")
	if err!=OK: last_error="替换存档失败，原存档与临时文件保留";return false
	return true

func decode(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return {}
	var parsed = parser.data
	if not parsed is Dictionary:return {}
	if parsed.get("version",-1)!=1:return {}
	var payload=parsed.get("payload","")
	if not payload is String:return {}
	if payload.sha256_text()!=parsed.get("checksum",""):return {}
	var value=JSON.parse_string(payload)
	if not value is Dictionary:return {}
	if not value.get("position",null) is Array or value.position.size()!=3:return {}
	for n in value.position:
		if not (n is float or n is int) or not is_finite(n):return {}
	var p:=Vector3(value.position[0],value.position[1],value.position[2])
	if str(value.get("world_revision","")) in ["bay_v1","bay_v2"]:
		var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_layout_bay_v1.json"))
		var bounds:Array=layout.bounds
		if p.x<bounds[0] or p.x>bounds[1] or p.z<bounds[2] or p.z>bounds[3] or p.y< -16.0 or p.y>180.0:return {}
	elif absf(p.x)>475 or p.z<-455 or (p.z>355 and not preload("res://scripts/world_limits.gd").within_pier(p)):return {}
	if not value.get("stamps",[]) is Array or not value.get("photos",[]) is Array:return {}
	for field in ["discovered","shots"]:
		if not value.get(field,[]) is Array:return {}
	if not value.get("cards",[]) is Array:return {}
	var valid_cards:Array=["Z01","Z02","Z03","Z04","Z05","Z06","Z07","Z08","Z09","Z09_NEST"]
	if str(value.get("world_revision",""))=="bay_v2":
		var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_layout_bay_v1.json"))
		for view in cfg.get("hidden_views",[]):valid_cards.append(view.card)
		for id in cfg.get("valid_travel_cards106",[]):valid_cards.append(id)
	for id in value.get("cards",[]):
		if not id is String or id not in valid_cards:return {}
	for field in ["home_card","home_shot"]:
		if not value.get(field,"") is String:return {}
	if not (value.get("gallery_preset",0) is int or value.get("gallery_preset",0) is float) or int(value.get("gallery_preset",0)) not in ([0,1,2,3] if str(value.get("world_revision",""))=="bay_v2" else [0,1,2]):return {}
	if not (value.get("home_light",0) is int or value.get("home_light",0) is float) or int(value.get("home_light",0)) not in [0,1,2]:return {}
	for field in ["bouquet","home_photo","pb_page","time"]:
		if not (value.get(field,0) is int or value.get(field,0) is float):return {}
	if int(value.get("bouquet",0)) not in [0,1,2] or int(value.get("time",0)) not in [0,1,2]:return {}
	if not (value.get("weather",0) is int or value.get("weather",0) is float) or int(value.get("weather",0)) not in [0,1,2]:return {}
	var safe=value.get("safe_point",[0,1,80])
	if not safe is Array or safe.size()!=3:return {}
	for n in safe:
		if not (n is float or n is int) or not is_finite(n):return {}
	return value

func read() -> Dictionary:
	imported_legacy=false;import_source_checksum="";import_source_file="";last_error=""
	var state:=decode(directory+"/progress.json")
	if not state.is_empty():return state
	state=decode(directory+"/progress.bak")
	if not state.is_empty():last_error="主存档异常，已读取备份。"
	elif not import_directory.is_empty() and not FileAccess.file_exists(directory+"/progress.json") and not FileAccess.file_exists(directory+"/progress.bak"):
		import_source_file=import_directory+"/progress.json";state=decode(import_source_file)
		if state.is_empty():import_source_file=import_directory+"/progress.bak";state=decode(import_source_file)
		if not state.is_empty():import_source_checksum=FileAccess.get_sha256(import_source_file);imported_legacy=true;last_error="将导入旧版旅行；原存档保持不变。"
	if state.is_empty():last_error="没有可用存档。"
	return state
