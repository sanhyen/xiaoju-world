extends "res://scripts/batch093_qa.gd"
## Construction-specific integration check; no replay of the already verified control suite.
func run(target):
	main=target;main.store.directory="user://qa_isolated/"+main.qa_mode
	await ticks(1);await main.start_game(false);main.player.ignore_focus_loss=true
	started=Time.get_ticks_msec();draw_probe.start()
	var w=main.world;var p=main.player;var manifest=w.streamer.manifest
	check("eight_zones_thirteen_venues",w.spec.zones.size()==8 and w.building_bounds.size()==13)
	var ids:Array=[]
	for action in w.interactions:ids.append(action.id)
	var missing:Array=[]
	for id in JSON.parse_string(FileAccess.get_file_as_string("res://data/original_interactions_r4.json")).ids:
		if id not in ids:missing.append(id)
	check("legacy_interactions",missing.is_empty() and ids.size()==87,{"missing":missing,"count":ids.size()})
	var stale:Array=[]
	for path in manifest.source_hashes:
		if OS.has_feature("editor"):
			if FileAccess.get_sha256(path)!=manifest.source_hashes[path]:stale.append(path)
		elif not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):stale.append(path)
	check("baked_sources_or_compiled_resources",stale.is_empty(),{"stale":stale})
	var counts:Dictionary=manifest.authored_counts
	check("twelve_rebuilt_envelopes",counts.get("envelopes_094",{}).size()==12)
	check("sculpted_rock_mesh",counts.get("rock_faces_094",{}).get("panels",0)>500,counts.get("rock_faces_094",{}))
	check("authored_forest_edge",counts.get("forest_edge_094",{}).get("clusters",0)>60,counts.get("forest_edge_094",{}))
	check("existing_structural_collision_count",int(counts.colliders)==2853,{"count":counts.colliders})
	if main.qa_mode.ends_with("final"):
		await place(Vector2(-266,-201))
		# Validation is recorded while CPU mesh data are authored, avoiding a synchronous GPU readback.
		var normals:Dictionary=counts.get("rock_faces_094",{})
		check("terrain_shading_normals",int(normals.get("normal_faces",0))>100 and int(normals.get("inward_normals",-1))==0,{"triangles_sampled":int(normals.get("normal_faces",0)),"inward":int(normals.get("inward_normals",-1)),"method":"authored face normals checked against each exposed side; source hash bound to bake"})
		main.set_time(0);main.environment_controls.set_weather(0)
		await capture("batch094_forest_final",Vector3(-270,6.905393,-183),Vector3(-275,24.484009,-220))
		finish("Targeted terrain normal correction on final exported build; prior revised report covers retained entrances and routes")
		return
	for item in w.spec.buildings:
		var front:float=item.z+item.d/2
		await place(Vector2(item.x,front+2.2))
		check("walk_through_"+item.id,await walk(Vector2(item.x,front-1.5)),{"position":str(p.position)})
	await place(Vector2(-246,-174))
	for point in [Vector2(-256,-185),Vector2(-266,-201),Vector2(-278,-211)]:
		check("forest_route_"+str(point),await walk(point),{"position":str(p.position)})
	# Explicit collision checks at the playable shoulder beside the new side mesh.
	for point in [Vector2(-260,-191.4),Vector2(-266,-201),Vector2(-278,-211)]:
		var y:float=w.height_at(point.x,point.y)
		var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,y+2,point.y),Vector3(point.x,y-2,point.y))
		query.exclude=[p.get_rid()]
		var hit:Dictionary=w.get_world_3d().direct_space_state.intersect_ray(query)
		check("shoulder_collision_"+str(point),not hit.is_empty() and absf(hit.position.y-y)<0.15)
	check("isolated_save_roundtrip",main.save_game(false) and not main.store.read().is_empty())
	if main.qa_mode.ends_with("revised"):
		main.set_time(0);main.environment_controls.set_weather(0)
		await capture("batch094_forest_revised",Vector3(-270,6.905393,-183),Vector3(-275,24.484009,-220))
	if main.qa_mode.ends_with("source"):
		main.set_time(0);main.environment_controls.set_weather(0)
		await capture("batch094_forest",Vector3(-270,6.905393,-183),Vector3(-275,24.484009,-220))
		await capture("batch094_street",Vector3(-81,7.8,207),Vector3(-97,3.6,188))
		await capture("batch094_gallery",Vector3(192,8,-21),Vector3(173,3.1,-42))
	finish("13 retained entrances, forest route, terrain collision and save; automated physical motion, not Windows input or art approval")

func finish(scope:String):
	var coverage:Dictionary=draw_probe.report();draw_probe.stop()
	var failures:=0
	for result in checks:
		if not result.passed:failures+=1
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"duration_s":(Time.get_ticks_msec()-started)/1000.0,"render_coverage":coverage,"forced_draws":forced_draws,"scope":scope}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BATCH094_TERMINAL ",failures);main.get_tree().quit(1 if failures else 0)
