extends Node3D
const Builder = preload("res://scripts/builder.gd")
const Buildings = preload("res://scripts/buildings.gd")
const DistrictDetail = preload("res://scripts/district_detail.gd")
var spec: Dictionary
var b
var interactions: Array = []
var screens: Dictionary = {}
var building_bounds: Array = []
var terrain_chunks: Array = []
var phase := "full"
var water_material: ShaderMaterial
var home_picture: MeshInstance3D
var home_flowers: Node3D
var ambient_sources: Array=[]
var venue_lights: Dictionary={}
var stage_presets: Dictionary={"B08":0,"B10":0}
var night_lights:Array=[]
var path_corridors:Array=[]
var streamer
var time_index:=0
var home_bouquet:=0
var home_photo_path:="res://assets/media/portrait_01.jpg"
var home_extras:Node3D
var home_card_name:=""
var home_shot_path:=""
var home_lights:Array=[]
var home_light_index:=0
var gallery_pictures:Dictionary={}
var gallery_preset:=0
var terrain_art
var path_art
var layout
var bay_props:Dictionary={}

func _exit_tree():
	# Release looped ambience explicitly before the audio server shuts down.
	for sound in ambient_sources:
		if is_instance_valid(sound):sound.stop();sound.stream=null
	ambient_sources.clear()
const GALLERY_ORDERS=[[0,1,2,3,4,5,6,7,8,9,10,11],[5,6,8,9,7,0,1,2,4,3,10,11],[3,10,11,2,4,0,1,7,5,6,8,9]]

func _ready():
	spec = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	layout=preload("res://scripts/world_layout.gd").new()
	spec=layout.apply(spec)
	terrain_art=preload("res://scripts/terrain_voxel.gd").new(self)
	b = Builder.new(self)
	path_art=preload("res://scripts/path_art.gd").new(self)
	if phase=="streamed":
		streamer=preload("res://scripts/world_stream.gd").new();streamer.world=self;add_child(streamer)
		setup_ambience()
		return
	if layout!=null:
		preload("res://scripts/bay_authoring.gd").new(self).build()
		return
	build_terrain()
	set_meta("roadcuts_084",terrain_art.roadcut_art.summary())
	build_roads()
	for zone in spec.zones:
		var access:Array[Vector2]=stamp_access_points(zone)
		for i in access.size()-1:path_between(access[i],access[i+1],3.0,"c0b79e")
	build_plaza()
	for item in spec.buildings:
		if phase == "sample" and item.id not in ["B02","B03","B04","B11","B13"]: continue
		Buildings.new().build(self,item)
	build_coast()
	DistrictDetail.new(self).street()
	DistrictDetail.new(self).night_lighting()
	if phase == "full":
		build_nature()
		DistrictDetail.new(self).other_districts()
		preload("res://scripts/landscape_detail.gd").new(self).build()
	if phase=="full":
		var coastal_route:Array=terrain_art.config.get("coast_garden_route",[])
		for i in coastal_route.size()-1:reserve_path(Vector2(coastal_route[i][0],coastal_route[i][1]),Vector2(coastal_route[i+1][0],coastal_route[i+1][1]),2.8)
		reserve_path(Vector2(-146,282.8),Vector2(-146,286),2.8)
	plant_landscape()
	if phase=="full":preload("res://scripts/coastal_garden.gd").new(self).build()
	if phase=="full":preload("res://scripts/woodland_groves.gd").new(self).build()
	if phase=="full":
		preload("res://scripts/garden_art.gd").new(self).shade_pocket()
		preload("res://scripts/garden_art.gd").new(self).planting()
		preload("res://scripts/lowland_groves.gd").new(self).build()
	if phase=="full":preload("res://scripts/groundcover_art.gd").new(self).build()
	if phase=="full":preload("res://scripts/landform_details.gd").new(self).build()
	if phase=="full":preload("res://scripts/cliff_details.gd").new(self).build()
	if phase=="full":preload("res://scripts/forest_edge.gd").new(self).build()
	if phase=="full":preload("res://scripts/landscape_composition.gd").new(self).build()
	set_meta("paths_v079",path_art.build())
	for z in spec.zones:
		var p := surface(z.x+9,z.z+14)
		b.box(p+Vector3(0,1,0),Vector3(1.5,2,0.65),"466d6b",true)
		b.text3d(z.name+"\n区域纪念章",p+Vector3(0,1.3,0.34),0.008)
		interact(z.id,p+Vector3(0,0,1.5),"领取 · "+z.name+"纪念章","stamp",z)
	b.finish()
	setup_ambience()
	print("WORLD_BUILT ",JSON.stringify({"phase":phase,"boxes":b.box_count,"colliders":b.collision_count,"interactions":interactions.size(),"buildings":building_bounds.size()}))

func setup_ambience():
	preload("res://scripts/audio_mix.gd").setup()
	for item in [["sea",Vector3(0,0,325),140.0],["wind",surface(-220,-165,3),130.0],["waterfall",surface(307,-330,4),100.0],["waterfall",Vector3(299,-1,-32),64.0,-35.0],["waterfall",Vector3(317,-1,44),64.0,-35.0],["waterfall",Vector3(325,-1,120),64.0,-35.0]]:
		var path:="res://assets/audio/"+str(item[0])+".wav"
		if not ResourceLoader.exists(path):continue
		var sound:=AudioStreamPlayer3D.new();sound.stream=load(path).duplicate();sound.bus="Environment"
		if sound.stream is AudioStreamWAV:
			sound.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.stream.loop_begin=0;sound.stream.loop_end=int(sound.stream.get_length()*sound.stream.mix_rate)
		sound.volume_db=-80;sound.set_meta("base_volume",item[3] if item.size()>3 else -25);sound.unit_size=8 if item.size()>3 else 22;sound.max_distance=item[2];add_child(sound);sound.position=item[1];sound.play();ambient_sources.append(sound)

func update_ambience(listener:Vector3,delta:float):
	for sound in ambient_sources:
		if not is_instance_valid(sound):continue
		var distance:float=sound.position.distance_to(listener)
		var fade:=1.0-smoothstep(sound.max_distance-18,sound.max_distance+18,distance)
		var target:float=linear_to_db(maxf(fade,0.0001))+float(sound.get_meta("base_volume"))
		sound.volume_db=lerpf(sound.volume_db,target,clampf(delta*1.8,0,1))

func set_water_horizon_palette(index:int):
	if water_material==null and streamer!=null:
		var sea=streamer.get_node_or_null("AlwaysVisibleWaterAndRoads/BackgroundOcean")
		if sea is MeshInstance3D:water_material=sea.material_override as ShaderMaterial
	if water_material!=null:
		water_material.set_shader_parameter("horizon_tone",[Color("d6e8df"),Color("edc8a7"),Color("4a6275")][index])

func set_night_lighting(time_index:int):
	self.time_index=time_index
	for light in night_lights:
		if is_instance_valid(light):light.light_energy=[0.0,0.5,1.4][time_index]

func set_venue_lighting(venue: String,index: int):
	stage_presets[venue]=posmod(index,3)
	var palettes:=[[Color("ffe0ab"),Color("c0dbe3")],[Color("c6acdf"),Color("94cbd3")],[Color("b6cddd"),Color("f1bead")]]
	var lights:Array=venue_lights.get(venue,[])
	for i in lights.size():
		if not is_instance_valid(lights[i]):continue
		lights[i].light_color=palettes[stage_presets[venue]][i%2]
		lights[i].light_energy=[1.8,2.3,1.5][stage_presets[venue]]

func set_home_light(index:int):
	home_light_index=clampi(index,0,2)
	for light in home_lights:
		if is_instance_valid(light):light.light_energy=[0.32,0.85,0.0][home_light_index]

func update_home(bouquet: int,photo_path: String):
	home_bouquet=bouquet;home_photo_path=photo_path
	if is_instance_valid(home_picture) and ResourceLoader.exists(photo_path):
		var tex:Texture2D=load(photo_path)
		home_picture.material_override.albedo_texture=tex
		var ratio:=float(tex.get_width())/tex.get_height()
		home_picture.mesh.size=Vector2(minf(2.1,2.0*ratio),minf(2.0,2.1/ratio))
	if is_instance_valid(home_flowers):home_flowers.queue_free()
	if not is_instance_valid(home_picture):return
	home_flowers=Node3D.new();home_picture.get_parent().add_child(home_flowers)
	var builder=Builder.new(home_flowers)
	preload("res://scripts/home_art.gd").new().bouquet(builder,(surface(-235,-171.6,0.81) if layout==null else Vector3(layout.venues.B12.x+2,layout.venues.B12.floor_y+0.89,layout.venues.B12.z-2.6)),clampi(bouquet,0,2),get_parent().bay.bouquet_palette() if get_parent().bay!=null else [])
	builder.finish()
	update_home_memories(home_card_name,home_shot_path)

func update_home_memories(card_name:String,shot_path:String):
	home_card_name=card_name;home_shot_path=shot_path
	if is_instance_valid(home_extras):home_extras.queue_free()
	if not is_instance_valid(home_picture):return
	home_extras=Node3D.new();home_picture.get_parent().add_child(home_extras)
	var detail=Builder.new(home_extras)
	var card_pos:Vector3=surface(-243.9,-166,1.35) if layout==null else Vector3(layout.venues.B12.x-6.9,layout.venues.B12.floor_y+1.43,layout.venues.B12.z+3)
	detail.box(card_pos,Vector3(1.25,0.85,0.08),"e1d8be",false,PI/2)
	detail.text3d((card_name+"\n山海旅行纪念\n同人项目原创") if not card_name.is_empty() else "旅行纪念卡展示位",card_pos+Vector3(0.06,0,0),0.0025,"41665d",PI/2)
	for side in [-1,1]:
		detail.box(card_pos+Vector3(-0.13,-0.66,side*0.43),Vector3(0.09,1.35,0.09),"887158")
		detail.box(card_pos+Vector3(0.20,-1.30,side*0.43),Vector3(0.50,0.10,0.18),"887158")
	var photo_pos:Vector3=surface(-230.05,-168.5,1.65) if layout==null else Vector3(layout.venues.B12.x+6.95,layout.venues.B12.floor_y+1.73,layout.venues.B12.z+0.5)
	detail.box(photo_pos,Vector3(1.6,1.15,0.08),"6e796c",false,-PI/2)
	for side in [-1,1]:
		detail.box(photo_pos+Vector3(0.13,-0.80,side*0.58),Vector3(0.09,1.68,0.09),"887158")
		detail.box(photo_pos+Vector3(-0.20,-1.60,side*0.58),Vector3(0.50,0.10,0.18),"887158")
	if not shot_path.is_empty() and FileAccess.file_exists(shot_path):
		var image:=Image.load_from_file(ProjectSettings.globalize_path(shot_path))
		if image!=null and not image.is_empty():
			if image.get_format()!=Image.FORMAT_RGBA8:image.convert(Image.FORMAT_RGBA8)
			var picture:=MeshInstance3D.new();var quad:=QuadMesh.new();var ratio:=float(image.get_width())/image.get_height();quad.size=Vector2(minf(1.45,1.03*ratio),minf(1.03,1.45/ratio));picture.mesh=quad
			var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(image);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;picture.material_override=mat
			home_extras.add_child(picture);picture.position=photo_pos+Vector3(-0.06,0,0);picture.rotation.y=-PI/2
		else:detail.text3d("风景照片暂不可用",photo_pos+Vector3(-0.06,0,0),0.004,"e4dccb",-PI/2)
	else:detail.text3d("我的风景相框",photo_pos+Vector3(-0.06,0,0),0.005,"e4dccb",-PI/2)
	detail.finish()

func set_gallery_preset(index:int):
	gallery_preset=clampi(index,0,3)
	var assets:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/assets.json"))
	var order:Array=GALLERY_ORDERS[mini(gallery_preset,2)]
	if layout!=null:
		order=[]
		for i in 12:order.append(1+posmod(i+gallery_preset*3,11))
	for slot in gallery_pictures:
		var picture:MeshInstance3D=gallery_pictures[slot]
		if not is_instance_valid(picture):continue
		var texture:Texture2D=load("res://"+str(assets[order[int(slot)]].runtime_path))
		var size:Vector2=picture.get_meta("gallery_frame_size")
		var ratio:=float(texture.get_width())/texture.get_height()
		picture.mesh=picture.mesh.duplicate();picture.mesh.size=Vector2(minf(size.x,size.y*ratio),minf(size.y,size.x/ratio))
		picture.material_override=picture.material_override.duplicate();picture.material_override.albedo_texture=texture
	for action in interactions:
		if action.id.begins_with("B05_art"):
			var slot:=int(str(action.id).trim_prefix("B05_art"));action.data.index=order[slot]

func height_at(x: float, z: float) -> float:
	if terrain_art!=null:return terrain_art.height_at(x,z)
	return legacy_height_at(x,z)

func legacy_height_at(x:float,z:float)->float:
	if layout!=null:return layout.height_at(Vector2(x,z))
	var ground:=raw_height(x,z)
	for item in spec.get("buildings",[]):
		if item.type=="home":
			var home_edge:=maxf(absf(x-item.x)-item.w/2-0.4,absf(z-item.z)-item.d/2-0.4)
			if home_edge<7:return lerpf(raw_height(item.x,item.z),ground,smoothstep(0.0,7.0,home_edge))
			continue
		var edge:=maxf(absf(x-item.x)-item.w/2-7,absf(z-item.z)-item.d/2-7)
		if edge<4:
			return lerpf(raw_height(item.x,item.z),ground,clampf(edge/4,0,1))
	return ground

func raw_height(x: float, z: float) -> float:
	if layout!=null:return layout.natural_height(Vector2(x,z))
	var h:=land_height(x,z)
	var river_x := 307.0+18*sin(z*0.014)
	var distance:=absf(x-river_x)
	if distance<24:
		var incision:=3.3+river_drop(z)
		h-=incision*(1.0-clampf((distance-12)/12,0,1))
	return h

func river_drop(z: float)->float:
	if z < -332:return 0.0
	return 20.0*clampf((-z-150)/182,0,1)

func land_height(x: float, z: float) -> float:
	if layout!=null:return layout.height_at(Vector2(x,z))
	var h := 0.0
	if z < -150:
		var t := clampf((-z-150)/260,0,1)
		h = 72.0 * t*t*(3.0-2.0*t)
		h += sin(x*0.018)*sin(t*PI)*5
	if z > 285: h -= clampf((z-285)/50,0,1)*1.8
	var shore := 344+15*sin(x*0.017)
	if z > shore: h -= minf((z-shore)*0.14,12)
	return h

func surface(x: float,z: float, offset: float = 0.0) -> Vector3:
	return Vector3(x,height_at(x,z)+offset,z)

func safe_ground_position(desired:Vector3)->Vector3:
	if layout!=null:return preload("res://scripts/bay_spawn.gd").resolve(self,desired)
	# The capsule spans more than one voxel at an edge; its footprint must clear both tops.
	var ground:float=height_at(desired.x,desired.z)
	for offset in [Vector2(0.36,0),Vector2(-0.36,0),Vector2(0,0.36),Vector2(0,-0.36),Vector2(-0.25,-0.25),Vector2(-0.25,0.25),Vector2(0.25,-0.25),Vector2(0.25,0.25)]:
		ground=maxf(ground,height_at(desired.x+offset.x,desired.z+offset.y))
	return Vector3(desired.x,maxf(desired.y,ground+0.4),desired.z)

func terrain_color_at(x:float,z:float)->Color:
	if terrain_art!=null:return terrain_art.grass_color(Vector2(x,z))
	var color:=Color("92a879").lerp(Color("748f66"),smoothstep(145,260,-z))
	color=color.lerp(Color("8c9b79"),smoothstep(345,410,-z))
	color=color.lerp(Color("d7c399"),smoothstep(282+6*sin(x*0.025),302+6*sin(x*0.025),z))
	return color.lightened(0.018*sin(x*0.067+sin(z*0.053))*sin(z*0.081))

func build_terrain():
	for cx in range(-480,480,96):
		for cz in range(-480,576 if layout!=null else 480,96):
			var mesh:MeshInstance3D=terrain_art.make_mesh(Vector2i(cx/96,cz/96))
			add_child(mesh)
			mesh.create_trimesh_collision()
			terrain_chunks.append(mesh)
	# One nonuniform water grid: shore density is preserved; outer rings are coarse.
	# The original inland rectangle is omitted, so no new sea covers river channels.
	# Background water is not playable land and has no collision.
	var xs:Array[float]=[-16000,-8000,-4000,-2000]
	for x in range(-1200,1201,40):xs.append(float(x))
	xs.append_array([2000.0,4000.0,8000.0,16000.0])
	var zs:Array[float]=[-16000,-8000,-4000,-2000,-1200,-480]
	for z in range(240 if layout!=null else 300,1501,40):zs.append(float(z))
	zs.append_array([2000.0,4000.0,8000.0,16000.0])
	var water_surface:=SurfaceTool.new();water_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in xs.size()-1:
		for j in zs.size()-1:
			if xs[i]>=-480 and xs[i+1]<=480 and zs[j]>=-480 and zs[j+1]<=(240 if layout!=null else 300):continue
			var points:=[Vector3(xs[i],0,zs[j]-900),Vector3(xs[i+1],0,zs[j]-900),Vector3(xs[i+1],0,zs[j+1]-900),Vector3(xs[i],0,zs[j+1]-900)]
			for index in [0,1,2,0,2,3]:
				water_surface.set_normal(Vector3.UP);water_surface.add_vertex(points[index])
	var sea:=MeshInstance3D.new();sea.name="BackgroundOcean"
	sea.mesh=water_surface.commit();sea.position=Vector3(0,-2.4,900)
	water_material=ShaderMaterial.new()
	water_material.shader=load("res://assets/materials/coastal_water.gdshader")
	if layout!=null:preload("res://scripts/bay_authoring.gd").new(self).set_water_curve(water_material)
	if layout!=null:water_material.set_shader_parameter("island_window",true)
	sea.material_override=water_material
	add_child(sea)

func path_between(a: Vector2,c: Vector2,width: float=8.0,color: String="c7bda4"):
	reserve_path(a,c,width)
	var length:=a.distance_to(c)
	var local_garden:bool=a.distance_to(Vector2(-237,-169))<65 or c.distance_to(Vector2(-237,-169))<65
	var n:=maxi(1,ceili(length/(1.0 if local_garden else 4.0)))
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var perpendicular:=Vector2(-(c-a).y,(c-a).x).normalized()*width/2
	for i in n:
		var p:=a.lerp(c,float(i)/n)
		var q:=a.lerp(c,float(i+1)/n)
		var vertices: Array=[]
		for v in [p+perpendicular,p-perpendicular,q-perpendicular,q+perpendicular]: vertices.append(surface(v.x,v.y,0.035))
		for j in [0,1,2,0,2,3]:st.set_color(Color(color));st.add_vertex(vertices[j])
	st.generate_normals()
	var mi:=MeshInstance3D.new()
	mi.mesh=st.commit()
	mi.material_override=b.material(color)
	if local_garden:
		var paving_mat:=ShaderMaterial.new();paving_mat.shader=load("res://assets/materials/voxel_surface.gdshader");paving_mat.set_shader_parameter("surface_kind",4);mi.material_override=paving_mat
	add_child(mi)
	mi.create_trimesh_collision()
	if width>=2.4:
		path_art.register(mi,a,c,width,color,local_garden,n)
	else:
		for i in range(0,n,3):
			var v:=a.lerp(c,float(i)/n)
			for s in [-1,1]:
				var k:Vector2=v+perpendicular*s
				b.box(surface(k.x,k.y,0.04),Vector3(0.32,0.16,1.4),"ded6c2",false,atan2((c-a).x,(c-a).y))

func reserve_path(a:Vector2,c:Vector2,width:float):
	path_corridors.append({"a":a,"c":c,"width":width})

func build_roads():
	for route in spec.routes:
		for i in route.size()-1:
			var a:=Vector2(route[i][0],route[i][1])
			var c:=Vector2(route[i+1][0],route[i+1][1])
			path_between(a,c,8 if a.y>-160 else 5,"c7bda4" if a.y>-160 else "baae90")
	for item in spec.buildings:
		if item.type=="home":continue # Its approach is composed with its supported garden ramp.
		var door:=Vector2(item.x,item.z+item.d/2+1)
		var nearest:=nearest_road(door)
		path_between(door,nearest,4,"d8ccb4")

func nearest_road(p: Vector2) -> Vector2:
	var near:=Vector2.ZERO
	var dist:=INF
	for route in spec.routes:
		for i in route.size()-1:
			var a:=Vector2(route[i][0],route[i][1]); var c:=Vector2(route[i+1][0],route[i+1][1])
			var v:=Geometry2D.get_closest_point_to_segment(p,a,c)
			if p.distance_to(v)<dist: dist=p.distance_to(v);near=v
	return near

func stamp_path_start(zone:Dictionary)->Vector2:
	var arrival:=Vector2(zone.x+9,zone.z+15.5)
	# The pier has existing guardrails; its stamp approach uses the verified east beach ramp.
	if zone.id=="Z02":return Vector2(15,arrival.y)
	if zone.id=="Z01":return nearest_road(Vector2(zone.x+6,zone.z+17))
	return nearest_road(arrival)

func stamp_access_points(zone:Dictionary)->Array[Vector2]:
	var points:Array[Vector2]=[stamp_path_start(zone)]
	# The station's nearest road approaches the sign from behind. Turn round its west side.
	if zone.id=="Z01":points.append(Vector2(zone.x+6,zone.z+17))
	# The mountain approach comes from the back of the solid sign. Turn well clear of its
	# east side before reaching the front, including ordinary sub-metre walking deviations.
	if zone.id=="Z08":points.append(Vector2(zone.x+12,zone.z+17.5))
	points.append(Vector2(zone.x+9,zone.z+15.5))
	return points

func build_plaza():
	b.box(Vector3(0,0.04,80),Vector3(100,0.14,90),"ded5c1",true)
	for x in range(-48,49,4):
		b.box(Vector3(x,0.12,80),Vector3(0.04,0.01,88),"c7bfae")
	for z in range(36,125,4): b.box(Vector3(0,0.12,z),Vector3(98,0.01,0.04),"c7bfae")
	# Architectural landmark, with full back volume and stone piers.
	var width:=16.0*4579.0/6146.0
	b.box(Vector3(0,0.4,40),Vector3(width+6,0.8,7),"bcb9a9",true)
	b.box(Vector3(0,10.3,38),Vector3(width+1.8,19,2.5),"dfdccd",true)
	b.box(Vector3(0,10.5,39.32),Vector3(width+0.5,16.6,0.18),"596765")
	b.picture("res://assets/media/portrait_01.jpg",Vector3(0,10.5,39.44),16.0)
	for x in [-width/2-0.7,width/2+0.7]:
		b.box(Vector3(x,10.4,39.1),Vector3(0.75,19.3,2.6),"eee9d9",true)
		for y in [2,7,12,17]: b.box(Vector3(x,y,40.5),Vector3(0.95,0.18,0.2),"bec6c3")
	b.box(Vector3(0,20.0,38.9),Vector3(width+3.5,0.6,3.8),"e9e3d1")
	# Continue the stone piers and recessed courses around the north elevation.
	# All additions stay over the original base; the photo and two side paths keep their space.
	for side in [-1,1]:
		b.box(Vector3(side*(width/2+0.55),10.25,36.56),Vector3(0.78,18.9,0.48),"d9d1bc",false,0,"stone")
		b.box(Vector3(side*(width/2+0.55),1.0,36.50),Vector3(1.12,0.6,0.65),"b7ad96",false,0,"stone")
		b.box(Vector3(side*(width/2+0.96),10.1,38),Vector3(0.20,17.8,1.8),"c5bca5",false,0,"stone")
	for column in [-1,0,1]:
		for row in 6:
			b.box(Vector3(column*3.72,3.02+row*2.52,36.69),Vector3(3.61,2.42,0.15),"c5bca5" if row%2 else "d9d1bc",false,0,"stone")
	for x in [-5.72,-1.86,1.86,5.72]:
		b.box(Vector3(x,10.0,36.46),Vector3(0.18,16.75,0.36),"dfdccd",false,0,"stone")
	for y in [1.22,18.66,19.38]:
		b.box(Vector3(0,y,36.47),Vector3(width+1.6,0.26,0.53),"b7ad96" if y<2 else "e9e3d1",false,0,"stone")
	# A small architectural compass uses the park's existing star motif, not another portrait.
	for spoke in 4:
		b.oriented_box(Vector3(0,11,36.24),Vector3(0.16,3.1,0.13),"849b91",Basis(Vector3.BACK,spoke*PI/4),false,"stone")
	b.box(Vector3(0,4.45,36.36),Vector3(6.1,1.35,0.3),"849b91",false,0,"stone")
	b.text3d("星 光 广 场",Vector3(0,4.48,36.17),0.016,"eee9d9",PI)
	b.text3d("鞠 婧 祎",Vector3(0,1.55,42.6),0.023,"435855")
	b.text3d("星 光 在 此 相 逢",Vector3(0,0.65,43.1),0.009,"5f7069")
	interact("L01",Vector3(0,0.3,69),"巨幅肖像 · 查看作品与来源","photo",{"index":0})
	DistrictDetail.new(self).plaza()
	interact("P01",Vector3(0,0.2,81),"星光合影位 · 拍照","photo_mode",{})

func build_coast():
	DistrictDetail.new(self).coast()

func garden_loop_point(degrees:int)->Vector2:
	var angle:=posmod(degrees,360)
	# The original loop cut across B12's forecourt and corner. Keep the loop continuous,
	# but take its western branch around the real house instead of through its footprint.
	var revised:Dictionary={180:Vector2(-252,-151),200:Vector2(-254,-164),220:Vector2(-251,-184),240:Vector2(-227,-187)}
	return revised.get(angle,Vector2(-205+36*cos(deg_to_rad(angle)),-145+28*sin(deg_to_rad(angle))))

func build_nature():
	# River follows the terrain continuously and flows out through the actual coast.
	var ribbon:=SurfaceTool.new();ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-405,361,3):
		var x:=307+18*sin(z*0.014)
		var xx:=307+18*sin((z+3)*0.014)
		var yy:=land_height(x,z)-1.5-river_drop(z)
		var y2:=land_height(xx,z+3)-1.5-river_drop(z+3)
		var points:=[Vector3(x-5,yy,z),Vector3(x+5,yy,z),Vector3(xx+5,y2,z+3),Vector3(xx-5,y2,z+3)]
		for j in [0,1,2,0,2,3]:ribbon.add_vertex(points[j])
		# Riverbank rocks and plants follow this water height in landscape_detail.gd.
	ribbon.generate_normals();var river:=MeshInstance3D.new();river.mesh=ribbon.commit()
	var river_shader:=Shader.new();river_shader.code="""shader_type spatial;
varying vec2 flow_position;
void vertex(){flow_position=VERTEX.xz;}
void fragment(){float ripples=pow(sin(flow_position.y*3.2-TIME*1.15+sin(flow_position.x*2.7)*0.8)*0.5+0.5,9.0);ALBEDO=mix(vec3(0.27,0.49,0.48),vec3(0.51,0.67,0.61),ripples*0.24);ROUGHNESS=0.48;}
"""
	var river_mat:=ShaderMaterial.new();river_mat.shader=river_shader;river.material_override=river_mat;add_child(river)
	for z in [-285,-225,-70,180]:
		var x:=307+18*sin(z*0.014)
		var y:=maxf(land_height(x-26,z),land_height(x+26,z))+0.26
		b.box(Vector3(x,y,z),Vector3(44,0.4,5),"beaf8e",true)
		for side in [-2.5,2.5]:
			b.box(Vector3(x,y+1.1,z+side),Vector3(44,0.15,0.15),"777b68",true)
			for dx in range(-21,22,3): b.box(Vector3(x+dx,y+0.5,z+side),Vector3(0.2,1.2,0.2),"777b68",true)
		path_between(Vector2(x-28,z),Vector2(x-22,z),5)
		path_between(Vector2(x+22,z),Vector2(x+28,z),5)
		b.ramp(surface(x-28,z,0.05),Vector3(x-21.95,y+0.27,z),4.8,"beaf8e")
		b.ramp(surface(x+28,z,0.05),Vector3(x+21.95,y+0.27,z),4.8,"beaf8e")
		for dx in [-18,18]:b.box(Vector3(x+dx,y-2,z),Vector3(1.2,4.2,4),"87907b")
		DistrictDetail.new(self).bridge_detail(x,y,z)
	# The fall is a real step in the carved channel, with connected upper and lower water.
	preload("res://scripts/waterfall_art.gd").new(self).build()
	path_between(Vector2(220,-170),Vector2(281,-275),5)
	path_between(Vector2(281,-275),Vector2(287,-312),5)
	path_between(Vector2(281,-275),Vector2(307+18*sin(-285*0.014)-22,-285),5)
	interact("N07_VIEW",Vector3(315,height_at(286,-302)+0.3,-302),"瀑布观景 · 记录风景","photo_mode",{})
	# Garden loops, shade, original arrangements; player cottage sits on the same terrain.
	reserve_path(Vector2(-220,-148.5),Vector2(-237,-148.5),3.8)
	reserve_path(Vector2(-237,-148.5),Vector2(-237,-162),3.2)
	for a in range(0,360,20):
		var p:=garden_loop_point(a)
		var q:=garden_loop_point(a+20)
		path_between(p,q,3,"d3c7ac")
	for a in range(0,360,20):
		var p:=garden_loop_point(a)+Vector2(4,4)
		var chosen:=p;var clear:=clear_of_paths(p,1.6)
		if not clear:
			for offset in [Vector2(-8,0),Vector2(8,-4),Vector2(-8,-4),Vector2(8,4),Vector2(-8,4)]:
				if clear_of_paths(p+offset,1.6):chosen=p+offset;clear=true;break
		if clear:b.planter(surface(chosen.x,chosen.y),3,["cbb0ce","edcea3","b9c49a"][a/20%3])
	preload("res://scripts/garden_art.gd").new(self).seating_layout()
	# Summit: structural platform and guardrails, all reachable by the two loop paths.
	var top:=surface(0,-385)
	b.box(top+Vector3(0,0.15,0),Vector3(30,0.3,19),"c4b99f",true)
	b.ramp(surface(0,-365,0.06),top+Vector3(0,0.32,9),5,"b9ab8c")
	for x in [-14.5,14.5]:
		b.box(top+Vector3(x,0.7,0),Vector3(0.25,1.4,19),"8c8972",true)
	b.box(top+Vector3(0,0.7,-9.2),Vector3(30,1.4,0.25),"8c8972",true)
	for x in [-8,8]: b.bench(top+Vector3(x,0.3,1))
	set_meta("summit_080",preload("res://scripts/summit_art.gd").new(self).build(top))
	for x in [-8.5,8.5]:
		for z in [-7,1]: b.box(top+Vector3(x,2.3,z),Vector3(0.35,4.6,0.35),"dbd6bf")
	interact("N08_TOP",top+Vector3(0,0.5,5),"山海观景台 · 合影","photo_mode",{})
	# Outdoor performance pavilion.
	var stage:=surface(-227,114)
	b.box(stage+Vector3(0,0.4,0),Vector3(17,0.8,9),"b8ac91",true)
	b.box(stage+Vector3(0,5,0),Vector3(19,0.4,10),"607a79")
	preload("res://scripts/courts_art.gd").new(self).stage(stage)
	interact("N09_STAGE",stage+Vector3(0,0,8),"海风小舞台 · 听一段音乐","audio",{})
	# Original film courtyard, not claimed to be a real production set.
	for i in 5:
		var p:=surface(174+i*4,-115)
		b.box(p+Vector3(0,3.4,0),Vector3(4.2,0.3,5),"586c6b")
		b.box(p+Vector3(0,1.7,-2),Vector3(0.3,3.4,0.3),"846a59")
		b.box(p+Vector3(0,1.7,2),Vector3(0.3,3.4,0.3),"846a59")
	interact("N10_SET",surface(180,-110),"原创光影庭院 · 取景","photo_mode",{})

func clear_of_paths(p:Vector2,margin:float=2.0)->bool:
	for corridor in path_corridors:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,corridor.a,corridor.c))<corridor.width/2+margin:return false
	return true

func plant_landscape():
	var rng:=RandomNumberGenerator.new()
	rng.seed=618
	for i in 1150:
		var x:=rng.randf_range(-455,455)
		var z:=rng.randf_range(-445,291)
		if absf(x-(307+18*sin(z*0.014)))<23: continue
		if absf(x)<57 and z>25 and z<137: continue
		if x>-115 and x<-33 and z>139 and z<249:continue
		if x>-90 and x<-37 and z>270:continue
		if Vector2(x,z).distance_to(nearest_road(Vector2(x,z)))<10: continue
		if not clear_of_paths(Vector2(x,z),3):continue
		var blocked:=false
		for item in spec.buildings:
			if absf(x-item.x)<item.w/2+8 and absf(z-item.z)<item.d/2+10: blocked=true;break
		if blocked: continue
		if x>270 and x<355 and z < -275 and z > -360:continue
		if z>-130 and rng.randf()>0.31: continue
		if z< -175:
			var patch:float=0.5+0.5*sin(x*0.037+sin(z*0.031)*1.4)*cos(z*0.023)
			if rng.randf()>0.32+patch*0.58:continue
		b.tree(surface(x,z),rng.randi_range(0,2) if z>-170 else rng.randi_range(0,1),rng.randf_range(0.75,1.55))
	# Purposeful street fixtures, with spacing varied by bends and plazas.
	for route in spec.routes:
		for i in route.size()-1:
			var a:=Vector2(route[i][0],route[i][1]);var c:=Vector2(route[i+1][0],route[i+1][1])
			var n:=int(a.distance_to(c)/30)
			for j in n:
				var p:=a.lerp(c,(j+0.5)/maxi(n,1))
				var side:=Vector2(-(c-a).y,(c-a).x).normalized()*6
				var occupied:=false
				for item in spec.buildings:
					if absf(p.x-item.x)<item.w/2+9 and absf(p.y-item.z)<item.d/2+9:occupied=true;break
				if occupied:continue
				var lamp_point:Vector2=p+side
				# The old automatic pole at (6,60) covered the face from the diagonal
				# photo position. Put square-axis lamps beside the planted side rooms.
				if absf(lamp_point.x)<18 and lamp_point.y>44 and lamp_point.y<125:
					lamp_point.x=24.0 if lamp_point.x>=0 else -24.0
				if p.y>-170 and clear_of_paths(lamp_point,0.6):b.lamp(surface(lamp_point.x,lamp_point.y))
				if j%2==0 and p.y>-160 and clear_of_paths(p-side,1.5):b.planter(surface(p.x-side.x,p.y-side.y),2.2)

func interact(id: String,pos: Vector3,title: String,kind: String,payload: Dictionary):
	interactions.append({"id":id,"pos":pos,"title":title,"kind":kind,"data":payload})

func inside_building(p: Vector3) -> String:
	if layout!=null:
		var place:Dictionary=layout.creative_at(p)
		if not place.is_empty():return str(place.id)
		for i in 4:
			var x:float=276+(4 if i in [1,2] else 0);var z:float=426+i*15
			if absf(p.x-x)<4 and absf(p.z-z)<4 and p.y>=-1.3 and p.y<2.8:return "VILLA_"+str(i)
		if absf(p.x-263.5)<5.7 and absf(p.z-421)<4.5 and p.y>=-1.2 and p.y<3.0:return "ISLAND_LOBBY"
		for h in layout.config.get("living_houses",[]):
			var at:Vector3=layout.vector(h.center)
			if absf(p.x-at.x)<h.size[0]*.5 and absf(p.z-at.z)<h.size[1]*.5 and p.y>=at.y-.5 and p.y<at.y+8:return h.id
	for item in building_bounds:
		if absf(p.x-item.x)<item.w/2 and absf(p.z-item.z)<item.d/2 and p.y>=item.y-0.5 and p.y<item.y+item.h+1: return item.id
		for extra in item.get("extra_bounds",[]):
			if absf(p.x-extra.x)<extra.w*.5 and absf(p.z-extra.z)<extra.d*.5 and p.y>=extra.y-.5 and p.y<extra.y+extra.h+1:return item.id
	return ""

func is_sheltered(p:Vector3)->bool:
	if not inside_building(p).is_empty():return true
	if layout!=null:
		for item in layout.config.get("shelters",[]):
			if absf(p.x-item.x)<item.w*.5 and absf(p.z-item.z)<item.d*.5 and p.y>=item.y-.5 and p.y<=item.y+item.h:return true
	return false

func within_pier(p:Vector3)->bool:
	# Only the actual constructed deck is exempt from the deep-water return boundary.
	if layout!=null:return absf(p.x)<5.5 and p.z>=layout.shore_z(0)-4.0 and p.z<=367.5 and p.y>=-0.85
	return preload("res://scripts/world_limits.gd").within_pier(p)

func prepare_region(point:Vector3,radius:float=110.0)->bool:
	if streamer==null:return true
	return await streamer.prepare(point,radius)

func region_ready(point:Vector3)->bool:
	return streamer==null or streamer.point_ready(point)

func bind_stream_nodes(cell:Node,loading:bool):
	# A cell arriving after a floor change must also receive the active roof cutaway.
	observation_key="stream_changed_"+str(Time.get_ticks_usec())
	for node in cell.find_children("*","",true,false):
		# Shade opaque ground after opaque structures have populated depth. This
		# changes submission order only; original terrain, materials and shadows stay.
		if loading and node.has_meta("stream_terrain") and node is GeometryInstance3D and node.material_override is ShaderMaterial:
			node.material_override.render_priority=120
			preload("res://scripts/terrain_fields110.gd").bind(node.material_override)
		if not node.has_meta("stream_ref"):continue
		var ref:String=node.get_meta("stream_ref")
		if ref.begins_with("prop:"):
			var id:String=ref.trim_prefix("prop:")
			if loading:bay_props[id]=node
			elif bay_props.get(id)==node:bay_props.erase(id)
		elif ref.begins_with("screen:"):
			var id:=ref.trim_prefix("screen:")
			if loading:screens[id]=node
			elif screens.get(id)==node:screens.erase(id)
		elif ref.begins_with("venue:"):
			var id:=ref.trim_prefix("venue:")
			if not venue_lights.has(id):venue_lights[id]=[]
			if loading:venue_lights[id].append(node)
			else:venue_lights[id].erase(node)
		elif ref=="night":
			if loading:night_lights.append(node)
			else:night_lights.erase(node)
		elif ref=="home_picture":
			if loading:home_picture=node
			elif home_picture==node:home_picture=null
		elif ref=="home_light":
			if loading:home_lights.append(node)
			else:home_lights.erase(node)
		elif ref.begins_with("gallery:"):
			var slot:=int(ref.trim_prefix("gallery:"))
			if loading:gallery_pictures[slot]=node
			else:gallery_pictures.erase(slot)
	if loading:
		set_night_lighting(time_index)
		set_home_light(home_light_index)
		for id in venue_lights:set_venue_lighting(id,int(stage_presets.get(id,0)))
		if is_instance_valid(home_picture) and cell.is_ancestor_of(home_picture):update_home(home_bouquet,home_photo_path)
		if not gallery_pictures.is_empty():set_gallery_preset(gallery_preset)

var observation_original:Dictionary={}
var observation_meshes:Dictionary={}
var observation_key:=""
func set_observation_cutaway(focus:Vector3,enabled:bool):
	var p:Dictionary=layout.creative_at(focus) if layout!=null else {}
	var level:int=0
	if not p.is_empty():
		for i in p.floors.size():
			if focus.y>=float(p.floors[i])-.4:level=i
	var key:String=(str(p.get("id",""))+str(level)) if enabled else ""
	if key==observation_key:return
	observation_key=key
	for id in observation_original.keys():
		var pair:Array=observation_original[id]
		if is_instance_valid(pair[0]):pair[0].multimesh=pair[1]
		else:observation_original.erase(id)
	for id in observation_meshes.keys():
		var pair:Array=observation_meshes[id]
		if is_instance_valid(pair[0]):pair[0].visible=pair[1]
		else:observation_meshes.erase(id)
	if key.is_empty() or p.is_empty():return
	var source:Node=streamer if streamer!=null else self
	var nodes:Array=source.find_children("*","MultiMeshInstance3D",true,false)
	var ceiling:float=float(p.floors[level])+2.5
	for node in source.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null or node.has_meta("stream_terrain"):continue
		var bounds:AABB=node.global_transform*node.get_aabb()
		var middle:Vector3=bounds.get_center()
		if absf(middle.x-p.center[0])>p.size[0]*.5+2 or absf(middle.z-p.center[2])>p.size[1]*.5+2 or bounds.position.y<ceiling-.2:continue
		var id:int=node.get_instance_id()
		if not observation_meshes.has(id):observation_meshes[id]=[node,node.visible]
		node.visible=false
	for node in nodes:
		if not is_instance_valid(node) or node.multimesh==null:continue
		if node.get_parent()==(streamer.far_root if streamer!=null else null):continue
		var mm:MultiMesh=node.multimesh
		var bounds:AABB=node.global_transform*mm.get_aabb()
		if focus.x<bounds.position.x-25 or focus.x>bounds.end.x+25 or focus.z<bounds.position.z-25 or focus.z>bounds.end.z+25:continue
		var id:int=node.get_instance_id()
		if not observation_original.has(id):observation_original[id]=[node,mm]
		var copy:MultiMesh=observation_original[id][1].duplicate()
		var count:=0
		for i in copy.instance_count:
			var transform:Transform3D=copy.get_instance_transform(i)
			var v:Vector3=node.global_transform*transform.origin
			if absf(v.x-p.center[0])<p.size[0]*.5+2 and absf(v.z-p.center[2])<p.size[1]*.5+2 and v.y+transform.basis.get_scale().y*.5>ceiling:
				transform.basis=Basis.IDENTITY.scaled(Vector3.ZERO);copy.set_instance_transform(i,transform);count+=1
		if count>0:node.multimesh=copy

func transport_obstacle_height(p:Vector2)->Dictionary:
	var roof:float=height_at(p.x,p.y)
	for record in layout.near(layout.creative_index,p):
		var place:Dictionary=record.place
		if str(place.id).begins_with("CABLE_"):continue
		if absf(p.x-place.center[0])<place.size[0]*.5+2 and absf(p.y-place.center[2])<place.size[1]*.5+2:
			roof=maxf(roof,float(place.floors[-1])+7.5)
	return {"roof":roof,"canopy":height_at(p.x,p.y)+(10.0 if p.y< -100 else 7.0)}
