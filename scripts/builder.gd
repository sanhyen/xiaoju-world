extends RefCounted
## Box modules are batched by material in spatial cells. Collision is simplified.
var venue_context:=""
var root: Node3D
var batches: Dictionary = {}
var mats: Dictionary = {}
var box_mesh := BoxMesh.new()
var font: Font
var box_count := 0
var collision_count := 0
var primitive_meshes: Dictionary = {}
var tree_counts:Dictionary={}
const SURFACE_TONES={
	"786047":"wood","947255":"wood",
	"b9a17b":"wood","a98c67":"wood","866e51":"wood","aa906c":"wood","ba9b73":"wood",
	"ad8760":"wood","655645":"wood","77634f":"wood","a08a67":"wood","ac936e":"wood",
	"947359":"wood","947558":"wood","9b7d5e":"wood","bda37c":"wood","b8a17d":"wood",
	"b39a72":"wood","695e4b":"wood","aa8863":"wood","8e7157":"wood","b29a72":"wood",
	"e4dfcf":"plaster","e6e0d1":"plaster","d8d2c2":"plaster","e7deca":"plaster",
	"d9d1bc":"stone","b7ad96":"stone","c5bca5":"stone","aaa18c":"stone","87907b":"stone",
	"607a79":"slate","627e91":"slate","596b72":"slate","5b7374":"slate",
	"b5a6b7":"fabric","c2b69e":"fabric"
}

func _init(target: Node3D):
	root = target
	box_mesh.size = Vector3.ONE
	if ResourceLoader.exists("res://assets/fonts/NotoSansSC-Medium.ttf"):
		font=load("res://assets/fonts/NotoSansSC-Medium.ttf")
	elif ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
		var variation := FontVariation.new()
		variation.base_font = load("res://assets/fonts/NotoSansSC.ttf")
		variation.variation_opentype = {"wght": 500.0}
		font = variation
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
		font = sf

func material(color: String) -> StandardMaterial3D:
	if not mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color)
		m.roughness = 0.86
		mats[color] = m
	return mats[color]

func box(pos: Vector3, size: Vector3, color: String, solid: bool = false, angle: float = 0.0, surface_kind: String = ""):
	oriented_box(pos,size,color,Basis(Vector3.UP,angle),solid,surface_kind)

func oriented_box(pos: Vector3,size: Vector3,color: String,basis: Basis,solid: bool=false,surface_kind:String=""):
	if surface_kind.is_empty():surface_kind=SURFACE_TONES.get(color,"")
	var key := "%d_%d_box" % [floori(pos.x / 96), floori(pos.z / 96)]
	if not surface_kind.is_empty():key+="_"+surface_kind
	if not solid and minf(size.x,minf(size.y,size.z))<=0.065:key+="_detail"
	if not batches.has(key): batches[key] = []
	batches[key].append([Transform3D(basis.scaled_local(size),pos),Color(color)])
	box_count += 1
	if solid:
		var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var form:=BoxShape3D.new()
		form.size=size;shape.shape=form;body.add_child(shape);root.add_child(body)
		body.transform=Transform3D(basis,pos);collision_count+=1

func beam(a: Vector3,c: Vector3,width: float,color: String,solid:bool=false):
	var y:Vector3=(c-a).normalized()
	var x:Vector3=Vector3.UP.cross(y).normalized() if absf(y.y)<0.99 else Vector3.RIGHT
	oriented_box((a+c)/2,Vector3(width,a.distance_to(c),width),color,Basis(x,y,x.cross(y)),solid)

func glow_box(pos:Vector3,size:Vector3):
	var key:="%d_%d_glow"%[floori(pos.x/96),floori(pos.z/96)]
	if not batches.has(key):batches[key]=[]
	batches[key].append([Transform3D(Basis.IDENTITY.scaled(size),pos),Color("f4d6a0")])
	box_count+=1

func shape(pos: Vector3,size: Vector3,color: String,kind: String="pot",angle: float=0.0,surface_kind:String=""):
	if not primitive_meshes.has(kind):
		if kind=="rock":
			primitive_meshes[kind]=preload("res://scripts/voxel_rocks.gd").mesh()
		elif kind=="shrub":
			var sphere:=SphereMesh.new();sphere.radius=0.5;sphere.height=1;sphere.radial_segments=8;sphere.rings=3
			primitive_meshes[kind]=sphere
		else:
			# Straight cylinder/cone sides need no coplanar height subdivisions.
			var cylinder:=CylinderMesh.new();cylinder.top_radius=0.5;cylinder.bottom_radius=0.36 if kind=="pot" else 0.5;cylinder.height=1;cylinder.radial_segments=12;cylinder.rings=0
			primitive_meshes[kind]=cylinder
	var key:="%d_%d_%s"%[floori(pos.x/96),floori(pos.z/96),kind]
	if not surface_kind.is_empty():key+="_"+surface_kind
	if not batches.has(key):batches[key]=[]
	batches[key].append([Transform3D(Basis(Vector3.UP,angle).scaled_local(size),pos),Color(color)])
	box_count+=1

func glass(pos: Vector3,size: Vector3,angle: float=0.0):
	var mi:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;mi.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.61,0.79,0.77,0.12);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=0.23
	mi.material_override=mat;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(mi);mi.position=pos;mi.rotation.y=angle

func collision(pos: Vector3, size: Vector3, angle: float = 0.0):
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	root.add_child(body)
	body.position = pos
	body.rotation.y = angle
	collision_count += 1

func ramp(a: Vector3,c: Vector3,width: float,color: String):
	if root.has_method("reserve_path"):root.reserve_path(Vector2(a.x,a.z),Vector2(c.x,c.z),width)
	var forward:Vector3=(c-a).normalized()
	var right:Vector3=Vector3.UP.cross(forward).normalized()
	var up:Vector3=forward.cross(right).normalized()
	var basis:=Basis(right,up,forward)
	var size:=Vector3(width+0.04,0.24,a.distance_to(c)+0.6)
	var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.material_override=material(color)
	root.add_child(mesh);mesh.transform=Transform3D(basis,(a+c)/2-Vector3(0,0.1,0))
	var body:=StaticBody3D.new();var col:=CollisionShape3D.new();var boxshape:=BoxShape3D.new();boxshape.size=size;col.shape=boxshape;body.add_child(col);root.add_child(body);body.transform=mesh.transform
	collision_count+=1

func finish():
	for key in batches:
		var instances: Array = batches[key]
		if instances.is_empty():continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var kind:String=key.get_slice("_",2)
		mm.mesh = box_mesh if kind in ["box","glow"] else primitive_meshes[kind]
		mm.instance_count = instances.size()
		for i in instances.size():
			mm.set_instance_transform(i, instances[i][0])
			mm.set_instance_color(i, instances[i][1])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.set_meta("stream_cell",Vector2i(int(str(key).get_slice("_",0)),int(str(key).get_slice("_",1))))
		var m := material("fffffe" if kind=="glow" else "ffffff")
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		if kind=="glow":m.emission_enabled=true;m.emission=Color("efc988");m.emission_energy_multiplier=0.6
		if str(key).get_slice("_",3)=="metal":
			if not mats.has("metal120"):
				var metal:StandardMaterial3D=m.duplicate();metal.roughness=.38;metal.metallic=.6;metal.metallic_specular=.5;mats["metal120"]=metal
			node.material_override=mats["metal120"]
		elif kind=="box" and str(key).get_slice("_",3) in ["wood","plaster","slate","stone","fabric","thatch"]:
			var surface:String=str(key).get_slice("_",3)
			var surface_key:String="surface_"+surface
			if not mats.has(surface_key):
				var patterned:=ShaderMaterial.new();patterned.shader=load("res://assets/materials/voxel_surface.gdshader")
				patterned.set_shader_parameter("surface_kind",["wood","plaster","slate","stone","fabric","thatch"].find(surface)+1);mats[surface_key]=patterned
			node.material_override=mats[surface_key]
		elif kind=="box" and str(key).get_slice("_",3)=="leaf":
			if not mats.has("foliage"):
				var leaf:=StandardMaterial3D.new();leaf.vertex_color_use_as_albedo=true;leaf.vertex_color_is_srgb=true;leaf.roughness=0.98;leaf.metallic_specular=0.12;mats["foliage"]=leaf
			node.material_override=mats["foliage"]
		else:node.material_override = m
		if str(key).ends_with("_detail"):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		# Important architecture stays visible; vegetation is in separate groups in future LOD pass.
	batches.clear()

func text3d(words: String, pos: Vector3, size: float = 0.025, color: String = "eee8d7", angle: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = words
	l.font = font
	l.font_size = 48
	l.pixel_size = size
	l.modulate = Color(color)
	l.outline_size = 0
	l.no_depth_test = false
	# Every sign has an authored reading face. Its reverse must not show mirrored glyphs.
	l.double_sided = false
	l.position = pos
	l.rotation.y = angle
	root.add_child(l)
	return l

func picture(path: String, pos: Vector3, height: float, angle: float = 0.0, framed:bool=true) -> MeshInstance3D:
	if not ResourceLoader.exists(path): return null
	var tex: Texture2D = load(path)
	var width := height * float(tex.get_width()) / float(tex.get_height())
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width,height)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	root.add_child(mi)
	mi.position = pos
	mi.rotation.y = angle
	if framed:box(pos + Basis(Vector3.UP,angle) * Vector3(0,0,-0.06),Vector3(width+0.18,height+0.18,0.10),"e0d6be",false,angle)
	return mi

func bench(p: Vector3, angle: float = 0.0):
	if venue_context.is_empty() and root.get("layout")!=null:
		var basis:=Basis(Vector3.UP,angle)
		for x in [-.9,.9]:
			for z in [-.22,.22]:
				var at:Vector3=p+basis*Vector3(x,0,z);var below:float=root.height_at(at.x,at.z)
				if at.y-below>.07:box(Vector3(at.x,(at.y+below)*.5,at.z),Vector3(.10,at.y-below,.10),"77634f",false,0,"wood")
	if not venue_context.is_empty() and venue_context!="B01":
		var art=preload("res://scripts/bay_architecture.gd").new();art.b=self;art.sofa(p,angle);return
	var basis := Basis(Vector3.UP,angle)
	for i in 4:box(p+basis*Vector3(0,0.55,-0.26+i*0.17),Vector3(2.4,0.11,0.13),"a08a67",false,angle)
	for y in [0.85,1.05]:box(p+basis*Vector3(0,y,-0.32),Vector3(2.4,0.13,0.1),"ac936e",false,angle)
	collision(p+Vector3(0,0.29,0),Vector3(2.4,0.58,0.7),angle)
	for x in [-0.9,0.9]:
		box(p+basis*Vector3(x,0.25,0),Vector3(0.1,0.5,0.55),"465c56",false,angle)
		box(p+basis*Vector3(x,0.8,-0.32),Vector3(0.08,0.75,0.08),"465c56",false,angle)

func planter(p: Vector3, width: float = 2.0, tone: String = "c3a7cf"):
	box(p+Vector3(0,0.3,0),Vector3(width,0.6,0.9),"ddd5bb",true)
	box(p+Vector3(0,0.62,0),Vector3(width-0.12,0.12,0.75),"597555")
	for i in int(width*3):
		var x := -width/2+0.22+i*0.32
		var stem:=p+Vector3(x,0.88,0.18*sin(i*2.1))
		box(stem,Vector3(0.06,0.5,0.06),"628255")
		box(stem+Vector3(0.1,-0.06,0),Vector3(0.19,0.06,0.12),"739466")
		if i%3==0:
			for j in 3:box(stem+Vector3(0,j*0.12+0.10,0),Vector3(0.14-j*0.035,0.11,0.14-j*0.035),tone)
		elif i%3==1:
			for offset in [Vector3(0.11,0.21,0),Vector3(-0.11,0.21,0),Vector3(0,0.21,0.11),Vector3(0,0.21,-0.11)]:box(stem+offset,Vector3(0.14,0.09,0.14),tone)
			box(stem+Vector3(0,0.23,0),Vector3(0.08,0.09,0.08),"e6c783")
		else:box(stem+Vector3(0,0.22,0),Vector3(0.22,0.2,0.22),tone)

func lamp(p: Vector3):
	box(p+Vector3(0,2.1,0),Vector3(0.15,4.2,0.15),"3b5354")
	box(p+Vector3(0,4.25,0),Vector3(0.65,0.12,0.65),"3b5354")
	glow_box(p+Vector3(0,3.92,0),Vector3(0.42,0.56,0.42))

func tree(p: Vector3, kind: int, size: float):
	if root.get("terrain_art")!=null and str(root.terrain_art.config.coverage)=="home_hillside" and Vector2(p.x+237,p.z+169).length()>190:
		var previous:=posmod(kind+floori(p.x+p.z),4)
		if p.z< -260 and previous==2:previous=1
		preload("res://scripts/vegetation_v11_preserved.gd").new().tree(self,p,previous,size)
		return
	var art=preload("res://scripts/vegetation_art.gd").new()
	art.tree(self,p,art.choose(p,kind),size)
	if root.get("layout")!=null:
		# Every authored tree has a low, nonblocking root transition; paths retain clearance.
		for i in 3:
			var a:float=i*2.399+p.x*.13+p.z*.09;var q:Vector3=p+Vector3(cos(a),0,sin(a))*size*.95
			if not root.clear_of_paths(Vector2(q.x,q.z),.55):continue
			q.y=root.height_at(q.x,q.z)
			shape(q+Vector3(0,.22,0),Vector3(.85,.44,.65)*size,["69805a","879862","80906c"][i],"shrub")
			if i==1:shape(q+Vector3(.28,.10,.20),Vector3(.4,.20,.35),"a9a48f","rock")

func legacy_tree(p:Vector3,kind:int,size:float):
	# Retained only as a recovery reference; the current world uses the seven V1.2 families.
	box(p+Vector3(0,2.5*size,0),Vector3(0.6,5,0.6)*size,"75634a")
	if kind == 0:
		for j in 3: box(p+Vector3(0,(4.0+j*1.45)*size,0),Vector3(5.0-j*1.15,2.3,5.0-j*1.15)*size,["567552","63845c","789865"][j])
	elif kind == 1:
		box(p+Vector3(0,5.0*size,0),Vector3(6,2.2,4.5)*size,"7c9669")
		box(p+Vector3(-0.7,6.6,0.4)*size,Vector3(4.3,1.4,3.6)*size,"8da578")
		box(p+Vector3(1.8,4.5,0.3)*size,Vector3(3.0,1.8,3.5)*size,"67845d")
	else:
		box(p+Vector3(0,5,0)*size,Vector3(5,2,5)*size,"d3b3c1")
		box(p+Vector3(-0.9,6.5,0)*size,Vector3(3.3,1.5,3.5)*size,"e5c5cc")
		box(p+Vector3(1.6,4.6,0)*size,Vector3(2.5,1.8,3.2)*size,"c49aac")

func table(p: Vector3, width: float = 2.0):
	if venue_context=="B02":
		if not primitive_meshes.has("roundtable"):
			var top:=CylinderMesh.new();top.top_radius=.5;top.bottom_radius=.5;top.height=1;top.radial_segments=24;top.rings=0;primitive_meshes["roundtable"]=top
		shape(p+Vector3(0,.9,0),Vector3(width,.16,width),"ad8760","roundtable")
		var body:=StaticBody3D.new();var col:=CollisionShape3D.new();var form:=CylinderShape3D.new();form.radius=width*.5;form.height=.16;col.shape=form;body.add_child(col);root.add_child(body);body.position=p+Vector3(0,.9,0);collision_count+=1
		shape(p+Vector3(0,.43,0),Vector3(.24,.86,.24),"655645","post");shape(p+Vector3(0,.07,0),Vector3(.78,.14,.78),"655645","post")
		return
	box(p+Vector3(0,0.9,0),Vector3(width,0.16,1.1),"ad8760",true)
	for x in [-width/2+0.18,width/2-0.18]:
		for z in [-0.35,0.35]: box(p+Vector3(x,0.43,z),Vector3(0.12,0.86,0.12),"655645")

func shelf(p: Vector3, width: float = 2.2, books: bool = true):
	box(p+Vector3(0,1.15,0),Vector3(width,2.3,0.6),"77634f",true)
	for y in [0.35,1.05,1.75]:
		box(p+Vector3(0,y,0.34),Vector3(width-0.15,0.52,0.2),"303f43")
		if books:
			for i in int(width*4): box(p+Vector3(-width/2+0.2+i*0.23,y,0.48),Vector3(0.16,0.45,0.2),["ba9b94","c4c4a3","839ea0","d8bc8b"][i%4])
