extends SceneTree
const REPLACEMENTS={
	"工作室视频的本地音轨 · 资料与来源请在试听台查看":"原创演示音轨 · 素材说明请在试听台查看",
	"写真资料 · 查看与收藏":"演示画作 · 查看与收藏",
	"舞台写真与节目 · 排练灯光":"演示画作与节目 · 排练灯光",
	"落日未眠\n鞠婧祎 · 工作室公开 MV 音轨":"海风演示\n原创器乐 · 本地试听",
	"落日未眠\n公开 MV · 本地试听":"海风演示\n原创器乐 · 本地试听",
	"落日未眠 · 工作室公开 MV":"海风演示 01 · 原创几何短片",
	"月鳞绮纪 · 工作室影像第八回":"海风演示 04 · 原创几何短片",
	"写真资料":"演示画作",
}
var changes:int=0
var forced:PackedStringArray=[]
func sha(data:PackedByteArray)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(data);return h.finish().hex_encode()
func _initialize():run.call_deferred()
func translated(value:String)->String:
	for old in REPLACEMENTS:value=value.replace(old,REPLACEMENTS[old])
	return value
func transform_text(node:Node):
	if node is Label3D:
		var text:String=translated(node.text)
		if text!=node.text:node.text=text;changes+=1
	elif node is MeshInstance3D and node.mesh is TextMesh:
		var text:String=translated(node.mesh.text)
		if text!=node.mesh.text:node.mesh.text=text;changes+=1
	for child in node.get_children():transform_text(child)
func geometry(node:Node,record:Dictionary):
	if node is MultiMeshInstance3D and node.multimesh!=null:
		assert(node.multimesh.instance_count==0 or not node.multimesh.buffer.is_empty())
		record[str(node.get_path())]={"instances":node.multimesh.instance_count,"buffer":sha(node.multimesh.buffer.to_byte_array())}
	for child in node.get_children():geometry(child,record)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--verify-scenes="):forced=arg.trim_prefix("--verify-scenes=").split(",")
	var folder:String="res://assets/world/stream_creative110"
	var manifest=load(folder+"/manifest.tres")
	var files:PackedStringArray=DirAccess.get_files_at(folder)
	var modified:Array=[]
	for name in files:
		if not name.ends_with(".scn"):continue
		var path:String=folder+"/"+name
		var node=load(path).instantiate();root.add_child(node)
		RenderingServer.force_sync()
		var before:Dictionary={};geometry(node,before)
		var previous:int=changes;transform_text(node)
		if changes>previous or name in forced:
			var packed:=PackedScene.new()
			assert(packed.pack(node)==OK)
			assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
			var after:Dictionary={};geometry(node,after);assert(before==after)
			node.queue_free();await process_frame
			var persisted=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate();root.add_child(persisted)
			RenderingServer.force_sync()
			var persisted_buffers:Dictionary={};geometry(persisted,persisted_buffers);assert(before==persisted_buffers)
			modified.append({"file":name,"labels":changes-previous,"persisted_instance_buffers_unchanged":true})
			persisted.queue_free();await process_frame
		else:
			node.queue_free();await process_frame
	for item in manifest.interactions:item.title=translated(str(item.title))
	for cell in manifest.cells:
		var f:=FileAccess.open(cell.path,FileAccess.READ);cell.bytes=f.get_length();f.close()
	var source_changes:Array=[]
	for path in manifest.source_hashes:
		var current:String=FileAccess.get_sha256(path)
		if current!=str(manifest.source_hashes[path]):
			source_changes.append({"path":path,"before":manifest.source_hashes[path],"after":current})
			manifest.source_hashes[path]=current
	manifest.authored_counts["public_text"]={"labels":changes,"scenes":modified.size(),"scope":"Public media wording only; MultiMesh buffers unchanged"}
	assert(ResourceSaver.save(manifest,folder+"/manifest.tres")==OK)
	var output:Dictionary={"ok":true,"changed_labels":changes,"modified_scenes":modified,"source_changes":source_changes}
	var file:=FileAccess.open("res://reports/public_text.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close()
	print("PUBLIC_TEXT_COMPLETE ",JSON.stringify({"labels":changes,"scenes":modified.size()}));quit()
