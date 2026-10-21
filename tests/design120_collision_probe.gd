extends SceneTree
const World=preload("res://scripts/world.gd")
var world
func _initialize():run.call_deferred()
func run():
	world=Node3D.new();world.set_script(World);world.phase="streamed";root.add_child(world);await physics_frame
	var results:Array=[]
	for value in [["B02",Vector3(-104,4.71355,242.0591),Vector3(0,0,.8)],["B07",Vector3(235.22,28.44378,-262.4821),Vector3(0,0,-.8)],["B08",Vector3(-231.6883,14.26041,-74.79533),Vector3(0,0,-.8)],["B01",Vector3(289.9114,5.80556,230.9332),Vector3(0,0,.8)]]:
		await world.prepare_region(value[1],24);await physics_frame
		for advance in [0.0,.5,1.0]:
			var capsule:=CapsuleShape3D.new();capsule.radius=.36;capsule.height=1.65
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,value[1]+value[2]*advance+Vector3.UP*.9)
			var shapes:Array=[]
			for hit in world.get_world_3d().direct_space_state.intersect_shape(query,16):
				var node:Node3D=hit.collider;var item:Dictionary={"name":node.name,"at":node.global_position,"basis":node.global_basis}
				for child in node.get_children():
					if child is CollisionShape3D:
						item["shape"]=child.shape.get_class()
						if child.shape is BoxShape3D:item["size"]=child.shape.size
				shapes.append(item)
			results.append({"id":value[0],"advance":advance,"hits":shapes})
	var file:=FileAccess.open("res://reports/design120_collision_probe.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close();print("COLLISION_PROBE ",JSON.stringify(results));quit()
