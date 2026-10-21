extends SceneTree
## Compare real streamed terrain collision with the shared ground query after baking.
var main
var results:Array=[]

func _initialize():run.call_deferred()

func check(name:String,passed:bool,details:Dictionary={}):
	results.append({"test":name,"passed":passed,"details":details})
	print("TERRAIN_SURFACE ",name," ",passed," ",JSON.stringify(details))

func run():
	main=load("res://scenes/world/main.tscn").instantiate();root.add_child(main)
	await physics_frame;await physics_frame
	main.player.enabled=false;main.player.program_driven=true
	var world=main.world
	for path in ["res://scripts/terrain_voxel.gd","res://data/environment_v12.json","res://scripts/woodland_groves.gd"]:
		check("baked_source_"+path.get_file(),world.streamer.manifest.source_hashes.get(path,"")==FileAccess.get_sha256(path))
	# Non-integer points avoid ambiguous intersections exactly on two terrace boundaries.
	for point in [Vector2(-330.37,-249.41),Vector2(-275.37,-252.41),Vector2(-223.37,-306.41),Vector2(-142.37,-296.41),Vector2(-73.37,-312.41),Vector2(104.37,-301.41),Vector2(195.37,-277.41),Vector2(-310.37,-350.41),Vector2(45.37,-359.41),Vector2(120.37,278.41),Vector2(278.37,-232.41),Vector2(-252.37,-168.41),Vector2(-255.37,-181.41),Vector2(-106.37,-269.41),Vector2(181.37,-223.41),Vector2(399.37,-277.41),Vector2(391.37,-332.41)]:
		var height:float=world.height_at(point.x,point.y)
		var location:=Vector3(point.x,height+0.5,point.y)
		main.player.position=location;main.player.velocity=Vector3.ZERO
		var ready:bool=await world.prepare_region(location)
		check("ready_"+str(point),ready)
		if not ready:continue
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,height+0.12,point.y),Vector3(point.x,height-0.5,point.y))
		ray.exclude=[main.player.get_rid()]
		var hit:Dictionary={};var skipped:Array=[]
		# Roads sit 0.035 m above terrain. Inspect the actual terrain collider rather
		# than accidentally treating that separate paving surface as terrain error.
		for attempt in 32:
			hit=world.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():break
			var node:Node=hit.collider;var is_terrain:=false
			while node!=null:
				if node.has_meta("stream_terrain"):is_terrain=true;break
				node=node.get_parent()
			if is_terrain:break
			skipped.append(str(hit.collider.get_path()))
			var excluded:Array[RID]=ray.exclude;excluded.append(hit.rid);ray.exclude=excluded
			hit={}
		check("collision_matches_ground_"+str(point),not hit.is_empty() and absf(hit.position.y-height)<0.035,{"expected_y":height,"hit":str(hit.get("position",Vector3.ZERO)),"skipped_nonterrain":skipped})
	var failures:=0
	for row in results:failures+=0 if row.passed else 1
	var file:=FileAccess.open("res://reports/terrain_surface_contract.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":results,"failures":failures,"scope":"actual streamed collision at representative terrace/ridge/hollow points; does not replace rendered route or visual review"},"\t"));file.close()
	main.stop_media();main.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)
