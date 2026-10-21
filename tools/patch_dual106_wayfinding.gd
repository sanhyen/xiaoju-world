extends SceneTree
var old_text:="星夜森屿航线 · 远期预留"
var new_text:="星夜森屿航线 · 双岛已开放"
func _initialize():run.call_deferred()
func digest(data:PackedByteArray)->String:
	var ctx:=HashingContext.new();ctx.start(HashingContext.HASH_SHA256);ctx.update(data);return ctx.finish().hex_encode()
func signature(node:Node,rows:Array):
	var row:Dictionary={"type":node.get_class(),"name":node.name}
	if node is Node3D:row.transform=str(node.transform)
	if node is MultiMeshInstance3D:row.buffer=digest(var_to_bytes(node.multimesh.buffer));row.instances=node.multimesh.instance_count
	if node is CollisionShape3D:
		if node.shape is BoxShape3D:row.box=str(node.shape.size)
		elif node.shape is ConcavePolygonShape3D:row.faces=digest(var_to_bytes(node.shape.get_faces()))
	rows.append(row)
	for child in node.get_children():signature(child,rows)
func relabel(node:Node)->int:
	var count:=0
	if node is Label3D and node.text==old_text:node.text=new_text;count+=1
	for child in node.get_children():count+=relabel(child)
	return count
func run():
	var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_layout_bay_v1.json"));var paths:Array=[]
	for index in [3,6]:
		var at:Array=cfg.boat_docks[index].land;var cell:="cell_%d_%d.scn"%[floori((at[0]+3)/96),floori((at[2]+.09)/96)]
		paths.append("res://assets/world/stream_bay_v1/"+cell)
	var changes:Array=[];var total:=0
	for path in paths:
		var packed:PackedScene=load(path);var node:Node=packed.instantiate();root.add_child(node)
		await process_frame;RenderingServer.force_sync()
		var before:Array=[];signature(node,before);var count:int=relabel(node);assert(count>0)
		var backup:="res://checkpoints/dual106_wayfinding/"+str(path).get_file();DirAccess.make_dir_recursive_absolute(backup.get_base_dir());assert(DirAccess.copy_absolute(path,backup)==OK)
		var next:=PackedScene.new();assert(next.pack(node)==OK);RenderingServer.force_sync();assert(ResourceSaver.save(next,path,ResourceSaver.FLAG_COMPRESS)==OK)
		var reload:PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE);var fresh:Node=reload.instantiate();var after:Array=[];signature(fresh,after);assert(before==after,"Geometry or instance buffer changed")
		changes.append({"path":path,"labels":count,"nodes":before.size(),"geometry_and_instance_buffers_identical":before==after});total+=count;fresh.free();node.queue_free();await process_frame
	assert(total==2)
	var manifest=load("res://assets/world/stream_bay_v1/manifest.tres");manifest.source_hashes["res://scripts/bay_redesign_authoring.gd"]=FileAccess.get_sha256("res://scripts/bay_redesign_authoring.gd");manifest.authored_counts.redesign105.future_island_built=true
	assert(ResourceSaver.save(manifest,"res://assets/world/stream_bay_v1/manifest.tres")==OK)
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/bay_stream_bake.json"));report.source_hashes["res://scripts/bay_redesign_authoring.gd"]=manifest.source_hashes["res://scripts/bay_redesign_authoring.gd"];report.authored_counts.redesign105.future_island_built=true;report["wayfinding106_patch"]=changes
	var out:=FileAccess.open("res://reports/bay_stream_bake.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	out=FileAccess.open("res://reports/dual106_wayfinding_patch.json",FileAccess.WRITE);out.store_string(JSON.stringify({"labels":total,"changes":changes,"kind":"Graphical incremental label-only bake; geometry, transforms, collisions and instance buffers checked identical; no runtime controller changes"},"\t"));out.close();print("WAYFINDING106_PATCH_OK ",total);quit()
