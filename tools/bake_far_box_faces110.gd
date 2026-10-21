extends SceneTree
## Graphical, staged far-only rebake. Original cache, all near cells and global.scn stay untouched.
const Faces=preload("res://scripts/far_box_faces110.gd")
var input_folder:="res://assets/world/stream_creative110"
var output_base:="res://.runtime/far_box_faces110_stage"

func _initialize():run.call_deferred()

func owned(node:Node,scene_root:Node):
	for child in node.get_children():child.owner=scene_root;owned(child,scene_root)

func fail(message:String):push_error(message);quit(1)

func protected_hashes(manifest)->Dictionary:
	var result:Dictionary={}
	for record in manifest.cells:result[str(record.path)]=FileAccess.get_sha256(str(record.path))
	for file in ["global.scn","far.scn","manifest.tres"]:
		var path:String=input_folder.path_join(file);result[path]=FileAccess.get_sha256(path)
	return result

func run():
	if DisplayServer.get_name()=="headless":fail("Far partition requires the real renderer; headless MultiMesh buffers are not valid.");return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):input_folder=arg.trim_prefix("--input=").trim_suffix("/")
		if arg.begins_with("--output="):output_base=arg.trim_prefix("--output=").trim_suffix("/")
	var runtime_path:String=ProjectSettings.globalize_path("res://.runtime").replace("\\","/").simplify_path().to_lower()+"/"
	var output_path:String=ProjectSettings.globalize_path(output_base).replace("\\","/").simplify_path().to_lower()+"/"
	if not output_path.begins_with(runtime_path) or output_path==runtime_path:fail("Output must be a staging subdirectory of this project's .runtime.");return
	var input_far:String=input_folder.path_join("far.scn");var input_manifest:String=input_folder.path_join("manifest.tres")
	var manifest=ResourceLoader.load(input_manifest,"Resource",ResourceLoader.CACHE_MODE_IGNORE)
	if manifest==null:fail("Input manifest is missing.");return
	var before:Dictionary=protected_hashes(manifest)
	for path in before:
		if str(before[path]).is_empty():fail("Protected input cache is missing: "+path);return
	var source:PackedScene=ResourceLoader.load(input_far,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	if source==null:fail("Input far scene is missing.");return
	var far:Node3D=source.instantiate();root.add_child(far)
	await physics_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	var helper=Faces.new();var partition:Dictionary=helper.bake_partition(far)
	if not partition.ok:fail("Far partition failed: "+JSON.stringify(partition));return
	var lod:Dictionary=far.get_meta("far_lod_counts",{}).duplicate(true)
	if not partition.get("already_prebaked",false):lod["merged_multi_batches"]=int(lod.get("merged_multi_batches",0))+int(partition.extra_batches)
	far.set_meta("far_lod_counts",lod)
	var stamp:String=Time.get_datetime_string_from_system().replace("-","").replace(":","").replace("T","_")+"_"+str(Time.get_ticks_msec())
	var output_folder:String=output_base.path_join(stamp)
	if DirAccess.make_dir_recursive_absolute(output_folder)!=OK:fail("Unable to create staging directory.");return
	var staged_far:String=output_folder.path_join("far.scn");var staged_manifest:String=output_folder.path_join("manifest.tres")
	RenderingServer.force_sync();owned(far,far)
	var packed:=PackedScene.new()
	if packed.pack(far)!=OK or ResourceSaver.save(packed,staged_far,ResourceSaver.FLAG_COMPRESS)!=OK:fail("Staged far scene save failed.");return
	var verify_scene:PackedScene=ResourceLoader.load(staged_far,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	if verify_scene==null:fail("Unable to reload staged far scene.");return
	var verify:Node3D=verify_scene.instantiate();root.add_child(verify)
	RenderingServer.force_sync()
	var persisted:Dictionary=helper.validate_prebaked(verify)
	if not persisted.ok or int(persisted.total_instances)!=int(partition.instances_before):fail("Persisted far records changed: "+JSON.stringify(persisted));return
	var changed:Array=[]
	for path in before:
		if FileAccess.get_sha256(path)!=before[path]:changed.append(path)
	if not changed.is_empty():fail("Protected input cache changed: "+JSON.stringify(changed));return
	var source_updates:Dictionary={}
	for path in ["res://scripts/far_box_faces110.gd","res://scripts/world_stream.gd","res://tools/bake_stream_world.gd","res://scripts/creative_transport110.gd"]:
		source_updates[path]={"before":manifest.source_hashes.get(path,""),"after":FileAccess.get_sha256(path)}
		manifest.source_hashes[path]=source_updates[path].after
	manifest.authored_counts["far_box_faces110"]=partition.duplicate(true)
	manifest.authored_counts.far_box_faces110["far_scene_sha256"]=FileAccess.get_sha256(staged_far)
	manifest.authored_counts["far_lod110"]=lod.duplicate(true)
	if ResourceSaver.save(manifest,staged_manifest)!=OK:fail("Staged manifest save failed.");return
	var report:Dictionary={"staging_only":true,"reason":"Accepted forward-visible-equivalent far Box backface-index optimization; bake-time axis/rotated split prevents runtime splitting stalls","input_folder":input_folder,"output_folder":output_folder,"staged_far":staged_far,"staged_manifest":staged_manifest,"partition":partition,"persisted_native_records":persisted,"protected_cell_count":manifest.cells.size(),"protected_input_hashes":before,"protected_inputs_unchanged":changed.is_empty(),"source_hash_updates":source_updates,"far_before_sha256":before[input_far],"far_after_sha256":FileAccess.get_sha256(staged_far),"manifest_after_sha256":FileAccess.get_sha256(staged_manifest),"unchanged":"All near cell files, global.scn, original far.scn/manifest.tres, interaction IDs, media and normal saves","activation":"Review this report, then activate only staged far.scn and manifest.tres together; production cache was not overwritten by this tool"}
	report["local_baker_sha256"]=FileAccess.get_sha256("res://tools/bake_far_box_faces110.gd")
	var report_path:String="res://reports/creative110_far_box_faces_local_bake_"+stamp+".json"
	var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FAR_BOX_FACES_LOCAL_BAKE ",JSON.stringify({"report":report_path,"output_folder":output_folder,"staged_far":staged_far,"staged_manifest":staged_manifest,"partition":partition,"persisted":persisted,"protected_inputs_unchanged":true}))
	far.queue_free();verify.queue_free();await process_frame;quit()
