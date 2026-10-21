extends SceneTree
func _initialize():run.call_deferred()
func run():
	for file in ["cell_0_0.scn","far.scn"]:
		var scene:PackedScene=load("res://assets/world/stream_r4/"+file)
		var node:=scene.instantiate();root.add_child(node)
		var totals:={"batches":0,"instances":0,"examples":[]}
		for item in node.find_children("*","MultiMeshInstance3D",true,false):
			totals.batches+=1;totals.instances+=item.multimesh.instance_count
			if totals.examples.size()<3:totals.examples.append({"mesh":str(item.multimesh.mesh),"count":item.multimesh.instance_count,"visible_count":item.multimesh.visible_instance_count,"buffer":item.multimesh.buffer.size(),"first":str(item.multimesh.get_instance_transform(0)),"position":str(item.position),"visible":item.visible,"aabb":str(item.get_aabb())})
		print(file," ",JSON.stringify(totals))
		node.queue_free();await process_frame
	quit()
