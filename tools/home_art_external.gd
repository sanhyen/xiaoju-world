extends SceneTree
## Common external QA driver for immutable pre-art and revised native Windows PCKs.
var driver
func _initialize():run.call_deferred()
func run():
	var label:="external"
	var evidence:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-label="):label=argument.trim_prefix("--evidence-label=")
		if argument.begins_with("--evidence-root="):evidence=argument.trim_prefix("--evidence-root=")
	var base:=ProjectSettings.globalize_path("res://").trim_suffix("/")
	# A frozen PCK may remap script paths to res://. Compile the common local driver
	# explicitly from its source text so the pre-art PCK cannot load its old QA copy.
	var source:=GDScript.new();source.source_code=FileAccess.get_file_as_string(base+"/scripts/home_art_qa.gd")
	if source.reload()!=OK:push_error("External GPU QA driver did not compile");quit(1);return
	driver=source.new()
	print("EXTERNAL_QA_DRIVER ",label," fixed cameras from local source")
	driver.fixed_cameras=JSON.parse_string(FileAccess.get_file_as_string(base+"/data/art_house_cameras.json"))
	var main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	print("EXTERNAL_QA_MAIN_READY")
	main.qa_mode="homeart_"+label;main.store.directory="user://qa_isolated/art_v11"
	if evidence.is_empty():push_error("Explicit local evidence directory required");quit(1);return
	main.evidence_root=evidence
	DirAccess.make_dir_recursive_absolute(main.evidence_root+"screenshots");DirAccess.make_dir_recursive_absolute(main.evidence_root+"reports")
	await driver.run(main)
