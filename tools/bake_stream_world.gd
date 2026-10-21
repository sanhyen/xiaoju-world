extends SceneTree
const World=preload("res://scripts/world.gd")
const Manifest=preload("res://scripts/world_manifest.gd")
const DenseFlora=preload("res://scripts/dense_flora110.gd")
const TerrainMesh=preload("res://scripts/terrain_mesh110.gd")
const FarBoxFaces=preload("res://scripts/far_box_faces110.gd")
var folder:="res://assets/world/stream_creative110"
var world
var groups:Dictionary={}
var far_groups:Dictionary={}
var global_root:=Node3D.new()
var far_root:=Node3D.new()
var manifest=Manifest.new()
var materials:Dictionary={}
var far_batches:Dictionary={}
var far_surfaces:Dictionary={}
var far_box_mesh:=BoxMesh.new()
var far_lod_counts:Dictionary={"schema":2,"source_multi_batches":0,"merged_multi_batches":0,"selected_instances":0,"ordinary_mesh_sources":0,"ordinary_mesh_triangles":0,"merged_mesh_surfaces":0,"terrain_patches":0}

func _initialize():far_box_mesh.size=Vector3.ONE;run.call_deferred()

func owned(node:Node,scene_root:Node):
	for child in node.get_children():
		child.owner=scene_root;owned(child,scene_root)

func save_scene(node:Node,path:String)->bool:
	RenderingServer.force_sync()
	owned(node,node)
	var packed:=PackedScene.new()
	if packed.pack(node)!=OK:return false
	return ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK

func material(color:String)->StandardMaterial3D:
	if not materials.has(color):
		var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=0.86
		materials[color]=m
	return materials[color]

func classify(node:Node3D)->String:
	if node.has_meta("stream_cell"):
		var coord:Vector2i=node.get_meta("stream_cell")
		return "%d_%d"%[coord.x,coord.y]
	var center:Vector3=node.position
	if node is MeshInstance3D:
		var aabb:AABB=node.get_aabb()
		if maxf(aabb.size.x,aabb.size.z)>150:return "global"
		center=node.transform*(aabb.position+aabb.size/2)
	return "%d_%d"%[floori(center.x/96),floori(center.z/96)]

func far_material(two_sided:bool=false,emissive:bool=false)->StandardMaterial3D:
	var key:String="far_vertex_"+str(two_sided)+"_"+str(emissive)
	if not materials.has(key):
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color.WHITE
		mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX;mat.roughness=.98;mat.metallic_specular=.05
		if two_sided:mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		if emissive:mat.emission_enabled=true;mat.emission=Color("efc988");mat.emission_energy_multiplier=.3
		materials[key]=mat
	return materials[key]

func active_material(node:GeometryInstance3D,mesh:Mesh,surface:int=0)->Material:
	if node.material_override!=null:return node.material_override
	if node is MeshInstance3D:
		var surface_override:Material=node.get_surface_override_material(surface)
		if surface_override!=null:return surface_override
	return mesh.surface_get_material(surface)

func far_style(source:Material)->Dictionary:
	# Distant surfaces keep their actual color and silhouette, without subpixel grain/noise.
	if source is BaseMaterial3D:
		if source.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or source.albedo_color.a<.98 or source.albedo_texture!=null:return {}
		return {"two_sided":source.cull_mode==BaseMaterial3D.CULL_DISABLED,"emissive":source.emission_enabled,"tint":source.albedo_color,"vertex_color":source.vertex_color_use_as_albedo}
	if source is ShaderMaterial:
		if source.shader==null:return {}
		var path:String=source.shader.resource_path
		if not path.get_file() in ["voxel_surface.gdshader","terrain_strata.gdshader","garden_ground.gdshader","path_paving_079.gdshader"]:return {}
		return {"two_sided":"cull_disabled" in source.shader.code,"emissive":false,"tint":Color.WHITE,"vertex_color":true}
	return {"two_sided":false,"emissive":false,"tint":Color.WHITE,"vertex_color":false}

func queue_far_instance(key:String,mesh:Mesh,transform:Transform3D,color:Color,style:Dictionary):
	var primitive:Mesh=mesh;var at:Transform3D=transform
	# All box surfaces and real BoxMesh ramps share a unit box, irrespective of near material.
	if mesh is BoxMesh:
		primitive=far_box_mesh;at=Transform3D(transform.basis.scaled_local(mesh.size),transform.origin)
	var id:String=key+":"+str(primitive.get_instance_id())+":"+str(style.two_sided)+":"+str(style.emissive)
	if not far_batches.has(id):far_batches[id]={"cell":key,"mesh":primitive,"style":style,"transforms":[],"colors":[]}
	far_batches[id].transforms.append(at);far_batches[id].colors.append(color)
	far_lod_counts.selected_instances+=1

func add_far_batch(node:MultiMeshInstance3D,key:String):
	if not node.is_visible_in_tree() or node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or node.multimesh==null or node.multimesh.mesh==null:return
	var mm:MultiMesh=node.multimesh;var style:Dictionary=far_style(active_material(node,mm.mesh))
	if style.is_empty():return
	far_lod_counts.source_multi_batches+=1
	var space:Transform3D=far_groups[key].global_transform.affine_inverse()*node.global_transform
	for i in mm.instance_count:
		var transform:Transform3D=mm.get_instance_transform(i);var scale:Vector3=transform.basis.get_scale().abs()
		if maxf(scale.x,maxf(scale.y,scale.z))<.8 or scale.x*scale.y*scale.z<.18:continue
		var color:Color=mm.get_instance_color(i) if mm.use_colors and style.vertex_color else Color.WHITE
		queue_far_instance(key,mm.mesh,space*transform,color*style.tint,style)

func add_far_mesh(node:MeshInstance3D,key:String):
	if not node.is_visible_in_tree() or node.mesh==null or node.has_meta("stream_terrain") or node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:return
	var mesh:Mesh=node.mesh;var space:Transform3D=far_groups[key].global_transform.affine_inverse()*node.global_transform
	if absf(space.basis.determinant())<.00000001:return
	var bounds:AABB=space*mesh.get_aabb()
	if maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))<.8:return
	var kept:=false
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:continue
		var style:Dictionary=far_style(active_material(node,mesh,surface))
		if style.is_empty():continue
		if mesh is BoxMesh and mesh.get_surface_count()==1:
			queue_far_instance(key,mesh,space,style.tint,style);kept=true;continue
		var arrays:Array=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():continue
		var indices=arrays[Mesh.ARRAY_INDEX];var normals=arrays[Mesh.ARRAY_NORMAL];var colors=arrays[Mesh.ARRAY_COLOR]
		var indexed:bool=indices is PackedInt32Array and not indices.is_empty()
		var count:int=indices.size() if indexed else vertices.size()
		var id:String=key+":"+str(style.two_sided)+":"+str(style.emissive)
		if not far_surfaces.has(id):
			var surface_tool:=SurfaceTool.new();surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			far_surfaces[id]={"cell":key,"style":style,"builder":surface_tool}
		var builder:SurfaceTool=far_surfaces[id].builder
		var normal_basis:Basis=space.basis.inverse().transposed()
		var order:Array=[0,2,1] if space.basis.determinant()<0 else [0,1,2]
		for triangle in range(0,count-2,3):
			var face:Array=[]
			for corner in 3:face.append(int(indices[triangle+corner]) if indexed else triangle+corner)
			var fallback:Vector3=(vertices[face[2]]-vertices[face[0]]).cross(vertices[face[1]]-vertices[face[0]]).normalized()
			for corner in order:
				var at:int=face[corner]
				var normal:Vector3=normals[at] if normals is PackedVector3Array and normals.size()>at else fallback
				var color:Color=colors[at] if style.vertex_color and colors is PackedColorArray and colors.size()>at else Color.WHITE
				builder.set_normal((normal_basis*normal).normalized());builder.set_color(color*style.tint);builder.add_vertex(space*vertices[at])
			far_lod_counts.ordinary_mesh_triangles+=1
		kept=true
	if kept:far_lod_counts.ordinary_mesh_sources+=1

func collect_far_geometry(node:Node3D,key:String):
	if node is MultiMeshInstance3D:add_far_batch(node,key)
	elif node is MeshInstance3D:add_far_mesh(node,key)
	for child in node.find_children("*","GeometryInstance3D",true,false):
		if child is MultiMeshInstance3D:add_far_batch(child,key)
		elif child is MeshInstance3D:add_far_mesh(child,key)

func flush_far_geometry():
	for batch in far_batches.values():
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=batch.mesh;mm.instance_count=batch.transforms.size()
		for i in mm.instance_count:mm.set_instance_transform(i,batch.transforms[i]);mm.set_instance_color(i,batch.colors[i])
		var node:=MultiMeshInstance3D.new();node.name="FarMergedPrimitive";node.multimesh=mm;node.material_override=far_material(batch.style.two_sided,batch.style.emissive);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		far_groups[batch.cell].add_child(node);far_lod_counts.merged_multi_batches+=1
	for surface in far_surfaces.values():
		var mesh:ArrayMesh=surface.builder.commit()
		if mesh==null:continue
		var node:=MeshInstance3D.new();node.name="FarRealRoofsAndDecks";node.mesh=mesh;node.material_override=far_material(surface.style.two_sided,surface.style.emissive);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		far_groups[surface.cell].add_child(node);far_lod_counts.merged_mesh_surfaces+=1
	far_batches.clear();far_surfaces.clear()

func add_far_terrain(coord:Vector2i,key:String):
	var mi:MeshInstance3D=world.terrain_art.make_mesh(coord,true)
	mi.material_override=far_material(true)
	far_groups[key].add_child(mi);far_lod_counts.terrain_patches+=1

func add_far_portrait():
	var image:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/media/portrait_01.jpg"))
	if image==null:push_error("Real landmark image missing");return
	image.resize(roundi(512.0*image.get_width()/image.get_height()),512,Image.INTERPOLATE_LANCZOS);image.generate_mipmaps()
	var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(image);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var picture:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(16.0*4579.0/6146.0,16.0);picture.mesh=quad;picture.material_override=mat;picture.position=Vector3(0,10.5+world.layout.height_at(Vector2(0,80)),39.44)
	far_groups["0_0"].add_child(picture)

func dry_polygon_area(points:Array,level:float)->float:
	# Clip the actual top triangles at the water plane, then measure their XZ projection.
	var clipped:Array=[]
	for i in points.size():
		var a:Vector3=points[i];var c:Vector3=points[(i+1)%points.size()]
		if a.y>=level:clipped.append(a)
		if (a.y>=level)!=(c.y>=level):clipped.append(a.lerp(c,(level-a.y)/(c.y-a.y)))
	var area:=0.0
	for i in clipped.size():
		var a:Vector3=clipped[i];var c:Vector3=clipped[(i+1)%clipped.size()]
		area+=a.x*c.z-c.x*a.z
	return absf(area)*.5

func mainland_area()->Dictionary:
	var total:=0.0;var region:=0.0;var sea:float=world.layout.config.sea_y
	# Both islands start south of z=400. This clips only mainland mesh, including rivers/lagoon.
	for x in range(-480,480,2):
		for z in range(-480,400,2):
			var corners:Array=[]
			for offset in [Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(0,2)]:
				corners.append(Vector3(x+offset.x,world.height_at(x+offset.x,z+offset.y),z+offset.y))
			var area:float=dry_polygon_area([corners[0],corners[1],corners[2]],sea)+dry_polygon_area([corners[0],corners[2],corners[3]],sea)
			total+=area
			if x>=90 and x<445 and z>=-76 and z<350:
				# The odd boundary cuts a last 2 m tile in half; the half-cell estimate is explicit.
				region+=area*(.5 if x==444 else 1.0)*(.5 if z==-76 else 1.0)
	return {"method":"2m rendered terrain top triangles clipped at sea plane; mainland z<400; region boundary half-cell", "mainland_dry_m2":total,"east_dry_m2":region,"ratio":region/maxf(1,total),"within_twenty_percent":region<=total*.2}

func run():
	if DisplayServer.get_name()=="headless":push_error("World baking requires the actual renderer; Dummy MultiMesh buffers cannot be serialized.");quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	world=Node3D.new();world.set_script(World);root.add_child(world)
	await physics_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	manifest.interactions=world.interactions.duplicate(true);manifest.building_bounds=world.building_bounds.duplicate(true);manifest.path_corridors=world.path_corridors.duplicate(true)
	manifest.authored_counts={"boxes":world.b.box_count,"colliders":world.b.collision_count,"interactions":world.interactions.size(),"buildings":world.building_bounds.size(),"terrain_cells":world.terrain_chunks.size(),"tree_families":world.b.tree_counts,"ecology_v12":world.get_meta("regional_environment_details",{}),"waterfall_v12":world.get_meta("waterfall_v12",{}),"coast_v12":world.get_meta("coastal_garden_v12",{}),"woodland_v12":world.get_meta("woodland_groves_v12",{}),"lowland_v12":world.get_meta("lowland_groves_v12",{}),"garden_077":world.get_meta("garden_077",{}),"paths_079":world.get_meta("paths_v079",{}),"summit_080":world.get_meta("summit_080",{}),"garden_seats_080":world.get_meta("garden_seats_080",{}),"groundcover_081":world.get_meta("groundcover_081",{}),"roadcuts_084":world.get_meta("roadcuts_084",{}),"venue_finishings_084":world.get_meta("venue_finishings_084",{}),"venue_rest_086":world.get_meta("venue_rest_086",{}),"landform_details_088":world.get_meta("landform_details_088",{}),"venue_wayfinding_089":world.get_meta("venue_wayfinding_089",{}),"theater_roof_joints_089":world.get_meta("theater_roof_joints_089",{}),"cliff_details_091":world.get_meta("cliff_details_091",{}),"masonry_093":world.get_meta("masonry_093",{}),"road_saddle_093":{"rise_m":0.95,"a":Vector2(-256,-185),"c":Vector2(-266,-201)}}
	manifest.authored_counts["creative110"]=world.get_meta("creative110",{})
	manifest.authored_counts["creative110"]["measured_area"]=mainland_area()
	manifest.authored_counts["design120"]=world.get_meta("design120",{})
	manifest.authored_counts["design120_devices"]=world.get_meta("design120_devices",[])
	manifest.authored_counts["outdoors120"]=world.get_meta("outdoors120",[])
	manifest.authored_counts["architecture110"]=world.get_meta("architecture110",{})
	manifest.authored_counts["entrances110"]=world.get_meta("entrances110",[])
	manifest.authored_counts["upper_routes110"]=world.get_meta("upper_routes110",[])
	manifest.authored_counts["dual106"]=world.get_meta("dual106",{})
	manifest.authored_counts["guardrails106"]=world.get_meta("guardrails106",[])
	manifest.authored_counts["forest106_trees"]=world.get_meta("forest106_trees",0)
	manifest.authored_counts["redesign105"]=world.get_meta("redesign105",{})
	manifest.authored_counts["bay_expansion"]=world.get_meta("bay_expansion",{})
	manifest.authored_counts["bay_v1"]=world.get_meta("bay_v1",{})
	manifest.authored_counts["bay_finishings"]=world.get_meta("bay_finishings",{})
	manifest.authored_counts["bay_room_light_counts"]=world.get_meta("bay_room_light_counts",{})
	manifest.authored_counts["bay_street_wings"]=world.get_meta("bay_street_wings",[])
	manifest.authored_counts["bay_village"]=world.get_meta("bay_village",{})
	manifest.authored_counts["bay_waterfall_basins"]=world.get_meta("bay_waterfall_basins",0)
	manifest.authored_counts["bay_audit_details"]=world.get_meta("bay_audit_details",{})
	manifest.authored_counts["composition_095"]=world.get_meta("composition_095",{})
	manifest.authored_counts["envelopes_094"]=world.get_meta("envelopes_094",{})
	manifest.authored_counts["forest_edge_094"]=world.get_meta("forest_edge_094",{})
	manifest.authored_counts["rock_faces_094"]={"faces":world.terrain_art.rock_faces_094,"panels":world.terrain_art.rock_panels_094,"normal_faces":world.terrain_art.rock_normals_094,"inward_normals":world.terrain_art.inward_normals_094,"collision":"same mesh; protected top heights unchanged"}
	for id in world.screens:world.screens[id].set_meta("stream_ref","screen:"+id)
	for id in world.venue_lights:
		for light in world.venue_lights[id]:light.set_meta("stream_ref","venue:"+id)
	for light in world.night_lights:light.set_meta("stream_ref","night")
	world.home_picture.set_meta("stream_ref","home_picture")
	var children:Array=world.get_children().duplicate()
	global_root.name="AlwaysVisibleWaterAndRoads";root.add_child(global_root)
	far_root.name="DistantWorld";far_root.set_meta("far_lod_schema",2);root.add_child(far_root)
	for child in children:
		if not child is Node3D:continue
		if child is AudioStreamPlayer3D:child.queue_free();continue
		if child is MultiMeshInstance3D:
			if child.multimesh.buffer.is_empty():push_error("Refusing to bake an empty MultiMesh buffer");quit(1);return
			child.set_meta("stream_instances",child.multimesh.instance_count)
		var key:=classify(child)
		if key=="global":child.reparent(global_root);continue
		if not groups.has(key):
			var cell:=Node3D.new();cell.name="Cell_"+key;root.add_child(cell);groups[key]=cell
			var far:=Node3D.new();far.name="Far_"+key;far_root.add_child(far);far_groups[key]=far
		child.reparent(groups[key])
		collect_far_geometry(child,key)
		if child.has_meta("stream_terrain"):
			var coord:Vector2i=child.get_meta("stream_cell");add_far_terrain(coord,key)
	flush_far_geometry();add_far_portrait()
	var far_faces:Dictionary=FarBoxFaces.new().bake_partition(far_root)
	if not far_faces.ok:push_error("Far box partition failed: "+JSON.stringify(far_faces));quit(1);return
	far_lod_counts.merged_multi_batches+=int(far_faces.extra_batches)
	manifest.authored_counts["far_box_faces110"]=far_faces.duplicate(true)
	far_root.set_meta("far_lod_counts",far_lod_counts.duplicate(true));manifest.authored_counts["far_lod110"]=far_lod_counts.duplicate(true)
	var total_nodes:=0;var total_bytes:=0
	var flora= DenseFlora.new();var flora_cells:Array=[];var flora_instances:=0
	var terrain_mesh=TerrainMesh.new();var terrain_cells:Array=[]
	for key in groups:
		var flora_result:Dictionary=flora.bake_cell(groups[key],str(key))
		if not flora_result.ok:push_error("Dense flora partition failed: "+JSON.stringify(flora_result));quit(1);return
		if not flora_result.get("skipped",false):flora_cells.append(flora_result);flora_instances+=int(flora_result.get("instances_before",0))
		var terrain_result:Dictionary=terrain_mesh.bake_cell(groups[key],str(key),24.0)
		if not terrain_result.ok:push_error("Exact terrain partition failed: "+JSON.stringify(terrain_result));quit(1);return
		if not terrain_result.get("skipped",false):terrain_cells.append(terrain_result)
		var path:String=folder+"/cell_"+str(key)+".scn"
		if not save_scene(groups[key],path):push_error("Cell pack failed "+key);quit(1);return
		var count:int=groups[key].find_children("*","",true,false).size()
		var coord:=Vector2i(int(str(key).get_slice("_",0)),int(str(key).get_slice("_",1)))
		var file:=FileAccess.open(path,FileAccess.READ);var bytes:=file.get_length();file.close()
		manifest.cells.append({"id":key,"path":path,"center":Vector3(coord.x*96+48,0,coord.y*96+48),"nodes":count,"bytes":bytes})
		total_nodes+=count;total_bytes+=bytes
	if not save_scene(global_root,folder+"/global.scn") or not save_scene(far_root,folder+"/far.scn"):push_error("Far/global pack failed");quit(1);return
	manifest.authored_counts.far_box_faces110["far_scene_sha256"]=FileAccess.get_sha256(folder+"/far.scn")
	manifest.authored_counts["dense_flora110"]={"schema":1,"cells":flora_cells,"instances_preserved":flora_instances,"runtime_partitioning":false,"method":"Bake-only 24x16x24m original giant flora groups; unchanged native instance/attribute records"}
	manifest.authored_counts["terrain_mesh110"]={"schema":1,"cluster_size":24.0,"cells":terrain_cells,"runtime_partitioning":false,"method":"All original ordered triangle native records retained; identical vertex records welded; 24m cached parts"}
	for name in ["creative_feedback120","floor_plan120","architecture120","craft_components120","world_design120","outdoor_design120","creative_registry110","world_stream","creative_world110","creative_architecture110","creative_transport110","bay_dual106_authoring","bay_guardrails","bay_redesign_authoring","location_registry","world_layout","bay_architecture","bay_authoring","bay_spawn","bay_expansion","bay_finishings","bay_audit_finishings","bay_sea_walk","bay_village_authoring","world","builder","buildings","architecture_detail","district_detail","venue_detail","landscape_detail","home_art","vegetation_art","terrain_voxel","environment_garden","voxel_rocks","ecology_detail","waterfall_art","coastal_garden","woodland_groves","station_art","souvenir_art","records_art","interior_art","courts_art","garden_art","lowland_groves","path_art","summit_art","groundcover_art","venue_finishings","roadcut_art","landform_details","venue_wayfinding","cliff_details","voxel_masonry","venue_envelope","forest_edge","landscape_composition"]:manifest.source_hashes["res://scripts/"+name+".gd"]=FileAccess.get_sha256("res://scripts/"+name+".gd")
	for name in ["voxel_surface","garden_ground","terrain_strata","coastal_water","coral_water_bay","path_paving_079","gauze_bay","gallery_seasons_bay","wish_reflection_bay"]:manifest.source_hashes["res://assets/materials/"+name+".gdshader"]=FileAccess.get_sha256("res://assets/materials/"+name+".gdshader")
	manifest.source_hashes["res://scripts/far_box_faces110.gd"]=FileAccess.get_sha256("res://scripts/far_box_faces110.gd")
	manifest.source_hashes["res://scripts/dense_flora110.gd"]=FileAccess.get_sha256("res://scripts/dense_flora110.gd")
	manifest.source_hashes["res://scripts/opaque_order110.gd"]=FileAccess.get_sha256("res://scripts/opaque_order110.gd")
	manifest.source_hashes["res://scripts/terrain_mesh110.gd"]=FileAccess.get_sha256("res://scripts/terrain_mesh110.gd")
	manifest.source_hashes["res://scripts/terrain_fields110.gd"]=FileAccess.get_sha256("res://scripts/terrain_fields110.gd")
	manifest.source_hashes["res://assets/materials/terrain_field110.bin"]=FileAccess.get_sha256("res://assets/materials/terrain_field110.bin")
	for name in ["design120_outdoors","creative_places110","world_layout_bay_v1","legacy_actions_095","environment_v12","terrain_routes_v12","woodland_groves","records_art_sources","lowland_groves_077","groundcover_081","landform_details_088","cliff_details_091"]:manifest.source_hashes["res://data/"+name+".json"]=FileAccess.get_sha256("res://data/"+name+".json")
	manifest.source_hashes["res://data/world.json"]=FileAccess.get_sha256("res://data/world.json")
	manifest.source_hashes["res://tools/bake_stream_world.gd"]=FileAccess.get_sha256("res://tools/bake_stream_world.gd")
	if ResourceSaver.save(manifest,folder+"/manifest.tres")!=OK:push_error("Manifest save failed");quit(1);return
	var report:={"cells":manifest.cells.size(),"detail_nodes":total_nodes,"detail_bytes":total_bytes,"far_lod":far_lod_counts,"authored_counts":manifest.authored_counts,"source_hashes":manifest.source_hashes,"preservation":"Retained 8-zone/13-venue layout and functions; far proxy retains terrain, structural instances, actual mesh roofs and decks; far has no collision and is not counted as playable content"}
	var out:=FileAccess.open("res://reports/design120_stream_bake.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	print("STREAM_BAKE ",JSON.stringify(report));quit()
