extends SceneTree
## Isolated fallback candidate. No production hook or GPU work is performed by this file.
## Candidate.apply() may be used later in one explicitly scheduled graphical comparison.
class Candidate extends RefCounted:
	var cluster_size:=Vector3(16,8,16)
	var minimum_instances:=256
	var originals:Array=[]
	var created:Array=[]
	var details:Array=[]
	var total_instances:=0
	var total_source_batches:=0
	var total_clusters:=0
	var partition_ms:=0.0

	func plan_records(buffer:PackedFloat32Array,stride:int,to_world:Transform3D=Transform3D.IDENTITY)->Dictionary:
		if stride<12 or buffer.size()%stride!=0 or minf(cluster_size.x,minf(cluster_size.y,cluster_size.z))<=0:return {"ok":false,"reason":"invalid_record_format_or_size"}
		var groups:Dictionary={};var count:int=buffer.size()/stride
		for i in count:
			# Godot TRANSFORM_3D records store three row-major vec4s, with origin at 3/7/11.
			var offset:int=i*stride
			var point:Vector3=to_world*Vector3(buffer[offset+3],buffer[offset+7],buffer[offset+11])
			if not point.is_finite():return {"ok":false,"reason":"nonfinite_origin"}
			var key:=Vector3i(floori(point.x/cluster_size.x),floori(point.y/cluster_size.y),floori(point.z/cluster_size.z))
			if not groups.has(key):groups[key]=[]
			groups[key].append(i)
		return {"ok":true,"groups":groups,"count":count,"stride":stride}

	func raw_subset(buffer:PackedFloat32Array,stride:int,indices:Array)->PackedFloat32Array:
		var result:=PackedFloat32Array()
		for index in indices:result.append_array(buffer.slice(index*stride,(index+1)*stride))
		return result

	func apply(root_node:Node,scope:String="world")->Dictionary:
		var start:int=Time.get_ticks_usec();var added_batches:=0;var added_clusters:=0;var added_instances:=0
		# Snapshot first, so clones added below are never repartitioned in the same application.
		for node in root_node.find_children("*","MultiMeshInstance3D",true,false):
			var source:MultiMesh=node.multimesh
			if source==null or not source.mesh is BoxMesh or source.instance_count<minimum_instances:continue
			if source.transform_format!=MultiMesh.TRANSFORM_3D or node.has_meta("batch_cluster110"):continue
			if node.has_meta("stream_ref") or node.get_child_count()>0 or node.get_script()!=null:continue
			if source.visible_instance_count>=0 and source.visible_instance_count<source.instance_count:continue
			var stride:int=12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0)
			var buffer:PackedFloat32Array=source.buffer
			# A headless renderer cannot supply valid MultiMesh buffers; never fabricate a split.
			if buffer.size()!=source.instance_count*stride:continue
			# Validate the renderer's actual layout before interpreting any record positions.
			if Vector3(buffer[3],buffer[7],buffer[11])!=source.get_instance_transform(0).origin:continue
			var last:int=(source.instance_count-1)*stride
			if Vector3(buffer[last+3],buffer[last+7],buffer[last+11])!=source.get_instance_transform(source.instance_count-1).origin:continue
			var split_start:int=Time.get_ticks_usec()
			var plan:Dictionary=plan_records(buffer,stride,node.global_transform)
			if not plan.ok or plan.groups.size()<2:continue
			var entry:Dictionary={"node":node,"source":source,"had_stream_instances":node.has_meta("stream_instances"),"stream_instances":node.get_meta("stream_instances",0),"parts":[]}
			originals.append(entry)
			var first:=true;var after_count:=0
			for key in plan.groups:
				var indices:Array=plan.groups[key];var mm:=MultiMesh.new()
				mm.transform_format=source.transform_format;mm.use_colors=source.use_colors;mm.use_custom_data=source.use_custom_data
				mm.mesh=source.mesh;mm.instance_count=indices.size();mm.buffer=raw_subset(buffer,stride,indices)
				var part:MultiMeshInstance3D=node if first else node.duplicate(0)
				part.multimesh=mm;part.set_meta("stream_instances",indices.size());part.set_meta("batch_cluster110",true)
				part.set_meta("batch_cluster110_size",cluster_size)
				if not first:node.get_parent().add_child(part);created.append(part)
				entry.parts.append({"node":part,"indices":indices})
				first=false;added_clusters+=1;after_count+=indices.size()
			details.append({"scope":scope,"name":str(node.name),"source_instances":source.instance_count,"result_instances":after_count,"clusters":plan.groups.size(),"cpu_ms":(Time.get_ticks_usec()-split_start)/1000.0})
			added_batches+=1;added_instances+=after_count
		var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
		total_instances+=added_instances;total_source_batches+=added_batches;total_clusters+=added_clusters;partition_ms+=elapsed
		return {"scope":scope,"cluster_size":cluster_size,"minimum_instances":minimum_instances,"source_batches":added_batches,"clusters":added_clusters,"preserved_instances":added_instances,"cpu_ms":elapsed}

	func verify_native()->Dictionary:
		var records:=0;var failures:Array=[]
		for entry in originals:
			var source:MultiMesh=entry.source
			var stride:int=12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0)
			var buffer:PackedFloat32Array=source.buffer;var count:=0
			for part in entry.parts:
				var mm:MultiMesh=part.node.multimesh
				var expected:PackedFloat32Array=raw_subset(buffer,stride,part.indices)
				if mm.buffer.to_byte_array()!=expected.to_byte_array() or mm.mesh!=source.mesh or mm.use_colors!=source.use_colors or mm.use_custom_data!=source.use_custom_data:failures.append(str(part.node.name))
				count+=mm.instance_count
			if count!=source.instance_count:failures.append(str(entry.node.name)+":instance_count")
			records+=count
		return {"passed":records>0 and failures.is_empty(),"compared_records":records,"failures":failures,"scope":"native MultiMesh buffer bytes, mesh identity and instance count; not pixels or FPS"}

	func restore():
		for node in created:
			if is_instance_valid(node):node.get_parent().remove_child(node);node.queue_free()
		for entry in originals:
			if not is_instance_valid(entry.node):continue
			entry.node.multimesh=entry.source
			entry.node.remove_meta("batch_cluster110");entry.node.remove_meta("batch_cluster110_size")
			if entry.had_stream_instances:entry.node.set_meta("stream_instances",entry.stream_instances)
			else:entry.node.remove_meta("stream_instances")
		created.clear();originals.clear()

func _initialize():run.call_deferred()

func run():
	var candidate:=Candidate.new();var data:=PackedFloat32Array();var stride:=20
	var positions:Array=[Vector3(-.01,-.01,-.01),Vector3.ZERO,Vector3(15.99,7.99,15.99),Vector3(16,8,16),Vector3(-16,-8,-16),Vector3(-16.01,-8.01,-16.01)]
	for i in positions.size():
		var p:Vector3=positions[i]
		data.append_array(PackedFloat32Array([1+i*.125,0,0,p.x,0,1.25,0,p.y,0,0,.5,p.z,.125,.25,.5,.75,float(i),-float(i),.03125,1]))
	var plan:Dictionary=candidate.plan_records(data,stride)
	var reconstructed:=PackedFloat32Array();reconstructed.resize(data.size());var seen:Dictionary={};var duplicate:=false
	for key in plan.groups:
		var ids:Array=plan.groups[key];var subset:PackedFloat32Array=candidate.raw_subset(data,stride,ids)
		for j in ids.size():
			var original:int=ids[j]
			if seen.has(original):duplicate=true
			seen[original]=true
			for component in stride:reconstructed[original*stride+component]=subset[j*stride+component]
	var translated:Dictionary=candidate.plan_records(data,stride,Transform3D(Basis.IDENTITY,Vector3(16,8,16)))
	var checks:Array=[
		{"test":"exact_raw_transform_color_custom_record_conservation","passed":reconstructed.to_byte_array()==data.to_byte_array()},
		{"test":"every_original_instance_once","passed":not duplicate and seen.size()==positions.size()},
		{"test":"negative_coordinate_floor_and_exact_cluster_boundaries","passed":plan.groups.has(Vector3i(-1,-1,-1)) and plan.groups.has(Vector3i(-2,-2,-2)) and plan.groups.has(Vector3i(0,0,0)) and plan.groups.has(Vector3i(1,1,1))},
		{"test":"node_world_transform_applies_only_to_group_selection","passed":translated.ok and translated.count==positions.size() and translated.groups.has(Vector3i(2,2,2))},
		{"test":"truncated_record_buffer_rejected","passed":not candidate.plan_records(data.slice(0,data.size()-1),stride).ok}
	]
	var report:Dictionary={"scope":"CPU record contracts only; no GPU, native MultiMesh split or production mutation","cluster_size":candidate.cluster_size,"minimum_instances":candidate.minimum_instances,"checks":checks}
	var file:=FileAccess.open("res://reports/creative110_batch_cluster_contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BATCH_CLUSTER_CONTRACT110 ",JSON.stringify(report));quit(0 if checks.all(func(check):return check.passed) else 1)
