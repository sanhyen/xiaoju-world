extends SceneTree
## Native renderer, staged local repack of exactly two near cells. Never activates output.
var input_folder:="res://assets/world/stream_creative110"
var output_base:="res://.runtime/dense_flora110_stage"
var helper_path:="res://scripts/dense_flora110.gd"
const TARGETS=["-3_-2","-3_-3"]

func _initialize():run.call_deferred()
func fail(message:String):push_error(message);quit(1)
func owned(node:Node,scene_root:Node):
	for child in node.get_children():child.owner=scene_root;owned(child,scene_root)
func protected_hashes(manifest)->Dictionary:
	var result:Dictionary={}
	for record in manifest.cells:result[str(record.path)]=FileAccess.get_sha256(str(record.path))
	for file in ["global.scn","far.scn","manifest.tres"]:
		var path:String=input_folder.path_join(file);result[path]=FileAccess.get_sha256(path)
	return result
func save_scene(node:Node3D,path:String)->bool:
	RenderingServer.force_sync();owned(node,node)
	var packed:=PackedScene.new()
	return packed.pack(node)==OK and ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK
func run():
	if DisplayServer.get_name()=="headless":fail("Dense flora repacking needs the native renderer; Dummy MultiMesh records cannot be baked.");return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):input_folder=arg.trim_prefix("--input=").trim_suffix("/")
		if arg.begins_with("--output="):output_base=arg.trim_prefix("--output=").trim_suffix("/")
		if arg.begins_with("--helper="):helper_path=arg.trim_prefix("--helper=")
	if not ResourceLoader.exists(helper_path):helper_path="res://.runtime/env_v12_workspace/overlay/scripts/dense_flora110.gd"
	if not ResourceLoader.exists(helper_path):fail("Dense flora helper is missing.");return
	var runtime_path:String=ProjectSettings.globalize_path("res://.runtime").replace("\\","/").simplify_path().to_lower()+"/"
	var output_path:String=ProjectSettings.globalize_path(output_base).replace("\\","/").simplify_path().to_lower()+"/"
	if not output_path.begins_with(runtime_path) or output_path==runtime_path:fail("Output must be a staging subdirectory of this project's .runtime.");return
	var manifest=ResourceLoader.load(input_folder.path_join("manifest.tres"),"Resource",ResourceLoader.CACHE_MODE_IGNORE)
	if manifest==null:fail("Input manifest is missing.");return
	var before:Dictionary=protected_hashes(manifest)
	for path in before:
		if str(before[path]).is_empty():fail("Protected cache input is missing: "+path);return
	var helper=load(helper_path).new();var stamp:String=Time.get_datetime_string_from_system().replace("-","").replace(":","").replace("T","_")+"_"+str(Time.get_ticks_msec())
	var output_folder:String=output_base.path_join(stamp)
	if DirAccess.make_dir_recursive_absolute(output_folder)!=OK:fail("Unable to create staging folder.");return
	var cells:Array=[];var staged_nodes:Array=[]
	for id in TARGETS:
		var path:String=input_folder.path_join("cell_"+id+".scn");var source:PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		if source==null:fail("Input cell missing: "+id);return
		var cell:Node3D=source.instantiate();root.add_child(cell);await physics_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
		var partition:Dictionary=helper.bake_cell(cell,id)
		if not partition.ok:fail("Dense flora partition failed: "+JSON.stringify(partition));return
		var staged:String=output_folder.path_join("cell_"+id+".scn")
		if not save_scene(cell,staged):fail("Staged cell save failed: "+id);return
		var packed:PackedScene=ResourceLoader.load(staged,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		if packed==null:fail("Unable to reload staged cell: "+id);return
		var verify:Node3D=packed.instantiate();root.add_child(verify);RenderingServer.force_sync()
		var persisted:Dictionary=helper.validate_prebaked(verify)
		if not persisted.ok or int(persisted.compared_instances)!=int(partition.instances_before):fail("Persisted dense flora contract failed: "+JSON.stringify(persisted));return
		var file:=FileAccess.open(staged,FileAccess.READ);var bytes:int=file.get_length();file.close();var nodes:int=verify.find_children("*","",true,false).size()
		var found:=false
		for index in manifest.cells.size():
			if str(manifest.cells[index].id)==id:manifest.cells[index]["bytes"]=bytes;manifest.cells[index]["nodes"]=nodes;found=true;break
		if not found:fail("Target is missing from manifest: "+id);return
		cells.append({"id":id,"input":path,"staged":staged,"before_sha256":before[path],"after_sha256":FileAccess.get_sha256(staged),"bytes":bytes,"nodes":nodes,"partition":partition,"persisted_native_contract":persisted});staged_nodes.append(cell);staged_nodes.append(verify)
	var changed:Array=[]
	for path in before:
		if FileAccess.get_sha256(path)!=before[path]:changed.append(path)
	if not changed.is_empty():fail("Protected source cache changed: "+JSON.stringify(changed));return
	var logical_helper:String="res://scripts/dense_flora110.gd";var helper_hash:String=FileAccess.get_sha256(helper_path)
	manifest.source_hashes[logical_helper]=helper_hash
	manifest.source_hashes["res://tools/bake_stream_world.gd"]=FileAccess.get_sha256("res://tools/bake_stream_world.gd")
	manifest.authored_counts["dense_flora110"]={"schema":1,"cells":cells,"instances_preserved":35523,"method":"Bake-only 24x16x24m partitions of the original three giant flower batches; same native record bytes and GPU vertex/attribute streams; strict zero-area pole indices only","runtime_partitioning":false}
	var staged_manifest:String=output_folder.path_join("manifest.tres")
	if ResourceSaver.save(manifest,staged_manifest)!=OK:fail("Staged manifest save failed.");return
	var report:Dictionary={"staging_only":true,"input_folder":input_folder,"output_folder":output_folder,"staged_manifest":staged_manifest,"manifest_after_sha256":FileAccess.get_sha256(staged_manifest),"cells":cells,"protected_inputs_unchanged":true,"protected_input_hashes":before,"helper_source":helper_path,"helper_sha256":helper_hash,"local_baker_sha256":FileAccess.get_sha256("res://tools/bake_dense_flora110.gd"),"activation":"Activate only these two cell files and the staged manifest together after review. Original cache is unchanged. No full world bake or runtime partitioning.","future_full_baker":"Preload dense_flora110.gd and call bake_cell(groups[key],str(key)) in the per-cell save loop AFTER far geometry collection. Add helper hash and dense_flora110 counts to manifest. Do not place this work in world_stream."}
	var detail_nodes:=0;var detail_bytes:=0
	for record in manifest.cells:detail_nodes+=int(record.nodes);detail_bytes+=int(record.bytes)
	report["detail_nodes"]=detail_nodes;report["detail_bytes"]=detail_bytes
	var report_path:String="res://reports/creative110_dense_flora_local_bake_"+stamp+".json";var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("DENSE_FLORA110_LOCAL_BAKE ",JSON.stringify({"report":report_path,"output_folder":output_folder,"staged_manifest":staged_manifest,"cells":cells,"protected_inputs_unchanged":true}))
	for node in staged_nodes:node.queue_free()
	await process_frame;quit()
