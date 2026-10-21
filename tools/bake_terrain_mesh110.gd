extends SceneTree
## Explicitly gated graphical-context staging only. Activation belongs to the Python transaction wrapper.
var input_folder:="res://assets/world/stream_creative110"
var output_folder:=""
var helper_path:="res://scripts/terrain_mesh110.gd"
var cluster_size:=24.0
func _initialize():run.call_deferred()
func fail(message:String):push_error(message);quit(1)
func hashes(manifest)->Dictionary:
	var result:Dictionary={}
	for record in manifest.cells:result[str(record.path)]=FileAccess.get_sha256(str(record.path))
	for file in ["global.scn","far.scn","manifest.tres"]:result[input_folder.path_join(file)]=FileAccess.get_sha256(input_folder.path_join(file))
	return result
func run():
	var apply:=false
	for arg in OS.get_cmdline_user_args():
		if arg=="--apply":apply=true
		if arg.begins_with("--input="):input_folder=arg.trim_prefix("--input=").trim_suffix("/")
		if arg.begins_with("--output="):output_folder=arg.trim_prefix("--output=").trim_suffix("/")
		if arg.begins_with("--helper="):helper_path=arg.trim_prefix("--helper=")
		if arg.begins_with("--cluster-size="):cluster_size=float(arg.trim_prefix("--cluster-size="))
	if not apply:print("TERRAIN_MESH110_PLAN explicit --apply required; no files written");quit();return
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_driver_name() not in ["vulkan","d3d12"]:fail("Real rendering context required to preserve original MultiMesh instance buffers.");return
	if output_folder.is_empty():fail("Explicit staging output directory required.");return
	var runtime:String=ProjectSettings.globalize_path("res://.runtime").replace("\\","/").simplify_path().to_lower()+"/";var output:String=ProjectSettings.globalize_path(output_folder).replace("\\","/").simplify_path().to_lower()+"/"
	if not output.begins_with(runtime) or output==runtime:fail("Stage must be a strict project .runtime subdirectory.");return
	if not ResourceLoader.exists(helper_path):helper_path="res://.runtime/env_v12_workspace/overlay/scripts/terrain_mesh110.gd"
	if not ResourceLoader.exists(helper_path):fail("Terrain helper missing.");return
	var manifest=ResourceLoader.load(input_folder.path_join("manifest.tres"),"Resource",ResourceLoader.CACHE_MODE_IGNORE)
	if manifest==null:fail("Cache manifest missing.");return
	var before:Dictionary=hashes(manifest)
	for path in before:
		if str(before[path]).is_empty():fail("Missing protected source: "+str(path));return
	if DirAccess.make_dir_recursive_absolute(output_folder)!=OK:fail("Cannot create stage directory.");return
	var helper=load(helper_path).new();var cells:Array=[];var summary:Dictionary={"processed_cells":0,"changed_cells":0,"skipped_cells":0,"source_vertices":0,"part_vertices":0,"source_triangles":0,"parts":0};var started:int=Time.get_ticks_usec()
	for index in manifest.cells.size():
		var record:Dictionary=manifest.cells[index];var id:String=str(record.id);var path:String=str(record.path);var packed:PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		if packed==null:fail("Cannot load cell "+id);return
		var cell:Node3D=packed.instantiate();var result:Dictionary=helper.bake_cell(cell,id,cluster_size)
		if not result.ok:cell.free();fail("Cell contract failed "+id+": "+JSON.stringify(result));return
		var row:Dictionary={"id":id,"input":path,"before_sha256":before[path],"changed":not bool(result.get("skipped",false)),"partition":result};summary.processed_cells+=1
		for key in ["source_vertices","part_vertices","source_triangles","parts"]:summary[key]+=int(result.get("totals",{}).get(key,0))
		if result.get("skipped",false):
			row.after_sha256=before[path];summary.skipped_cells+=1;cells.append(row);cell.free();continue
		var staged:String=output_folder.path_join("cell_"+id+".scn");var output_scene:=PackedScene.new()
		if output_scene.pack(cell)!=OK or ResourceSaver.save(output_scene,staged,ResourceSaver.FLAG_COMPRESS)!=OK:cell.free();fail("Cannot save staged cell "+id);return
		cell.free();output_scene=null;packed=null
		var reload:PackedScene=ResourceLoader.load(staged,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		if reload==null:fail("Cannot reload staged cell "+id);return
		var verify:Node3D=reload.instantiate();var persisted:Dictionary=helper.validate_prebaked(verify)
		if not persisted.ok:verify.free();fail("Persisted original/native contract failed "+id+": "+JSON.stringify(persisted));return
		var bytes:int=FileAccess.get_file_as_bytes(staged).size();var nodes:int=verify.find_children("*","",true,false).size();verify.free();reload=null
		row.staged=staged;row.after_sha256=FileAccess.get_sha256(staged);row.bytes=bytes;row.nodes=nodes;row.persisted_contract=persisted;cells.append(row);manifest.cells[index]["bytes"]=bytes;manifest.cells[index]["nodes"]=nodes;summary.changed_cells+=1
		print("TERRAIN_MESH110_CELL ",id," ",summary.processed_cells,"/",manifest.cells.size())
	if hashes(manifest)!=before:fail("Source cache changed during conversion.");return
	var source_updates:Dictionary={"res://scripts/terrain_mesh110.gd":FileAccess.get_sha256(helper_path),"res://tools/bake_stream_world.gd":FileAccess.get_sha256("res://tools/bake_stream_world.gd")}
	for path in source_updates:manifest.source_hashes[path]=source_updates[path]
	var counts:Dictionary={"schema":1,"cluster_size":cluster_size,"totals":summary,"runtime_reconstruction":false,"method":"24m triangle-centroid partitions and exact complete-native-record vertex sharing; all original triangle/winding/order record hashes retained","scope":"Incremental near terrain conversion only; global/far byte-identical","cells":cells}
	manifest.authored_counts["terrain_mesh110"]=counts
	var staged_manifest:String=output_folder.path_join("manifest.tres")
	if ResourceSaver.save(manifest,staged_manifest)!=OK:fail("Cannot save staged manifest.");return
	var detail_bytes:=0;var detail_nodes:=0
	for record in manifest.cells:detail_bytes+=int(record.bytes);detail_nodes+=int(record.nodes)
	var report:Dictionary={"ok":true,"staging_only":true,"input_folder":input_folder,"output_folder":output_folder,"staged_manifest":staged_manifest,"manifest_after_sha256":FileAccess.get_sha256(staged_manifest),"cells":cells,"summary":summary,"authored_counts":counts,"source_hash_updates":source_updates,"protected_input_hashes":before,"protected_inputs_unchanged":hashes(manifest)==before,"global_far_byte_identical":true,"detail_bytes":detail_bytes,"detail_nodes":detail_nodes,"seconds":(Time.get_ticks_usec()-started)/1000000.0,"helper_path":helper_path,"normal_saves":"Real Vulkan context with rendering loop disabled; no Main, Store or gameplay instance; isolated APPDATA","future_full_baker":"After far collection and flora, call TerrainMesh.new().bake_cell(cell,id,24.0); include helper source hash and authored counts."}
	var report_path:String=output_folder.path_join("report.json");var f:=FileAccess.open(report_path,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("TERRAIN_MESH110_STAGED ",JSON.stringify({"report":report_path,"summary":summary,"seconds":report.seconds}));quit()
