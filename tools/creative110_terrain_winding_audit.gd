extends SceneTree
## Offline real-cache winding audit. No game, renderer bake, shader or cache mutation.
const FOLDER="res://assets/world/stream_creative110"
var totals:Dictionary={"cells":0,"terrain_meshes":0,"triangles":0,"top_triangles":0,"side_triangles":0,"zero_area":0,"front_normal_opposed":0,"top_faces_downward":0,"missing_normals":0,"missing_colors":0,"variable_normal_triangles":0,"variable_color_triangles":0,"minimum_front_normal_dot":1.0,"minimum_y":INF,"maximum_y":-INF}
var cells:Array=[]
var regions:Dictionary={}
var examples:Array=[]
var sea:=-2.4

func _initialize():run.call_deferred()
func bucket()->Dictionary:return {"triangles":0,"top":0,"side":0,"zero":0,"opposed":0,"downward_top":0,"variable_normal":0,"variable_color":0,"min_dot":1.0}
func region(at:Vector3)->String:
	if at.x>219 and at.x<354 and at.z> -49 and at.z<105:return "Z09_carved_cliff_and_tunnel_floor"
	if at.z>405 and at.x>210:return "island1_coral_and_hotel_seabed"
	if at.z>405:return "island2_forest_and_hot_springs"
	if at.y<sea:return "river_or_coastal_seabed"
	return "mainland"
func inspect(mesh_node:MeshInstance3D,frame:Transform3D,id:String)->Dictionary:
	var record:Dictionary=bucket();record["cell"]=id;record["surfaces"]=mesh_node.mesh.get_surface_count();record["top_expected"]=int(mesh_node.get_meta("terrain_v12",{}).get("top_faces",0))*2;record["y_min"]=INF;record["y_max"]=-INF
	for surface in mesh_node.mesh.get_surface_count():
		var arrays:Array=mesh_node.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray();var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if normals.size()!=vertices.size():totals.missing_normals+=vertices.size();continue
		if colors.size()!=vertices.size():totals.missing_colors+=vertices.size();continue
		if indices.is_empty():for index in vertices.size():indices.append(index)
		var normal_basis:Basis=frame.basis.inverse().transposed()
		for triangle in indices.size()/3:
			var at:int=triangle*3;var a:Vector3=frame*vertices[indices[at]];var b:Vector3=frame*vertices[indices[at+1]];var c:Vector3=frame*vertices[indices[at+2]]
			var center:Vector3=(a+b+c)/3;var key:String=region(center)
			if not regions.has(key):regions[key]=bucket()
			var subset:Dictionary=regions[key];var cross:Vector3=(b-a).cross(c-a);var length_squared:float=cross.length_squared()
			record.triangles+=1;totals.triangles+=1;subset.triangles+=1
			if normals[indices[at]]!=normals[indices[at+1]] or normals[indices[at]]!=normals[indices[at+2]]:record.variable_normal+=1;totals.variable_normal_triangles+=1;subset.variable_normal+=1
			if colors[indices[at]]!=colors[indices[at+1]] or colors[indices[at]]!=colors[indices[at+2]]:record.variable_color+=1;totals.variable_color_triangles+=1;subset.variable_color+=1
			var low:float=minf(a.y,minf(b.y,c.y));var high:float=maxf(a.y,maxf(b.y,c.y));record.y_min=minf(record.y_min,low);record.y_max=maxf(record.y_max,high);totals.minimum_y=minf(totals.minimum_y,low);totals.maximum_y=maxf(totals.maximum_y,high)
			if length_squared==0:record.zero+=1;totals.zero_area+=1;subset.zero+=1;continue
			# All actual 2m cap triangles have exactly 4m² projected cross magnitude;
			# relief panels are vertical strips with <=0.22m² projected magnitude.
			var is_top:bool=absf(absf(cross.y)-4.0)<.000001
			if is_top:record.top+=1;totals.top_triangles+=1;subset.top+=1
			else:record.side+=1;totals.side_triangles+=1;subset.side+=1
			# Godot front faces are clockwise, so geometric front is -cross.
			var front:Vector3=-cross.normalized();var supplied:Vector3=(normal_basis*(normals[indices[at]]+normals[indices[at+1]]+normals[indices[at+2]])).normalized();var dot:float=front.dot(supplied)
			record.min_dot=minf(record.min_dot,dot);totals.minimum_front_normal_dot=minf(totals.minimum_front_normal_dot,dot);subset.min_dot=minf(subset.min_dot,dot)
			if dot< -0.00001:
				record.opposed+=1;totals.front_normal_opposed+=1;subset.opposed+=1
				if examples.size()<24:examples.append({"cell":id,"kind":"normal_opposes_clockwise_front","vertices":[a,b,c],"normal":supplied,"front":front,"dot":dot})
			if is_top and front.y<=0:
				record.downward_top+=1;totals.top_faces_downward+=1;subset.downward_top+=1
				if examples.size()<24:examples.append({"cell":id,"kind":"top_wound_downward","vertices":[a,b,c]})
	return record
func visit(node:Node,frame:Transform3D,id:String):
	if node is Node3D:frame=frame*node.transform
	if node is MeshInstance3D and node.has_meta("stream_terrain"):
		cells.append(inspect(node,frame,id));totals.terrain_meshes+=1
	for child in node.get_children():visit(child,frame,id)
func run():
	if DisplayServer.get_name()!="headless":push_error("Winding audit is offline/headless only");quit(2);return
	var requested:Array=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cells="):requested=Array(arg.trim_prefix("--cells=").split(","))
	var previous:Dictionary={}
	if not requested.is_empty():previous=JSON.parse_string(FileAccess.get_file_as_string("res://reports/creative110_terrain_winding_audit.json"))
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_layout_bay_v1.json"));sea=float(config.sea_y)
	var manifest=load(FOLDER+"/manifest.tres");var input_hashes:Dictionary={}
	for record in manifest.cells:
		if not requested.is_empty() and not str(record.id) in requested:continue
		var path:String=record.path;var cell:Node=load(path).instantiate();visit(cell,Transform3D.IDENTITY,str(record.id));cell.free();totals.cells+=1;input_hashes[str(record.id)]=FileAccess.get_sha256(path)
	if not requested.is_empty():
		var previous_cells:Dictionary={}
		for item in previous.cells:previous_cells[str(item.cell)]=item
		for item in cells:
			if not previous_cells.has(str(item.cell)):push_error("Partial audit has no original cell record.");quit(3);return
			var old:Dictionary=previous_cells[str(item.cell)]
			for key in old:
				if not item.has(key):continue
				var a:Variant=old[key];var b:Variant=item[key]
				if ((a is int or a is float) and (b is int or b is float) and absf(float(a)-float(b))>.000001) or (not (a is int or a is float) and a!=b):push_error("Actual partial terrain audit differs: "+str(item.cell)+" "+str(key));quit(3);return
		for index in previous.cells.size():
			for item in cells:
				if str(previous.cells[index].cell)==str(item.cell):previous.cells[index]=item
		for id in input_hashes:previous.input_sha256[id]=input_hashes[id]
		if not previous.has("partial_rechecks"):previous.partial_rechecks=[]
		previous.partial_rechecks.append({"cells":requested,"actual_rescanned_triangles":totals.triangles,"normal_color_and_winding_statistics_unchanged":true,"input_sha256":input_hashes,"method":"Reload each actual current cell and re-read every terrain triangle; reuse other cell facts only after rescanned terrain statistics match."})
		var partial_file:=FileAccess.open("res://reports/creative110_terrain_winding_audit.json",FileAccess.WRITE);partial_file.store_string(JSON.stringify(previous,"\t"));partial_file.close();print("TERRAIN_WINDING110_PARTIAL ",JSON.stringify(previous.partial_rechecks[-1]));quit();return
	var expected_mismatches:Array=[]
	for cell in cells:
		if int(cell.top)!=int(cell.top_expected):expected_mismatches.append({"cell":cell.cell,"actual":cell.top,"expected":cell.top_expected})
	var report:Dictionary={"scope":"Every actual loaded-cache near terrain mesh, all 120 cells. Clockwise front versus supplied shading normal, fixed 2m cap winding, region totals. This does not by itself prove every backface is invisible from every free camera.","totals":totals,"regions":regions,"cells":cells,"top_count_mismatches":expected_mismatches,"examples":examples,"input_sha256":input_hashes,"visibility_constraints":["Terrain is a single heightfield with exposed side bands, not an undercut cave shell.","Z09 tunnel floor is carved in world_layout; its physical roof is separate Box geometry and uses another material.","Coral/river/coast seabeds have upward-facing cap triangles; playable shallow-water views remain above them.","Free orthographic observation can move below mountain height or outside the finite mesh boundary. Any cull-back candidate must fail open there.","Normal-bias and two-sided shadow coverage must remain exactly as original; color-pass culling alone is the candidate."],"normal_saves":"not loaded"}
	var file:=FileAccess.open("res://reports/creative110_terrain_winding_audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TERRAIN_WINDING110 ",JSON.stringify({"totals":totals,"regions":regions,"mismatches":expected_mismatches,"examples":examples}))
	quit(0 if int(totals.front_normal_opposed)==0 and int(totals.top_faces_downward)==0 and expected_mismatches.is_empty() else 1)
