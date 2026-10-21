extends RefCounted
## Original, readable object silhouettes. All supplied photographs are loaded read-only.
var materials:Dictionary={}
var textures:Dictionary={}
func material(tone:String,glow:bool=false)->StandardMaterial3D:
	var key:String=tone+str(glow)
	if materials.has(key):return materials[key]
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(tone);mat.roughness=.82
	if glow:mat.emission_enabled=true;mat.emission=Color(tone);mat.emission_energy_multiplier=.45
	materials[key]=mat;return mat
func box(root:Node3D,p:Vector3,s:Vector3,tone:String,angle:float=0,glow:bool=false)->MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=s;node.mesh=mesh;node.material_override=material(tone,glow);root.add_child(node);node.position=p;node.rotation.z=angle;return node
func cylinder(root:Node3D,p:Vector3,r:float,h:float,tone:String)->MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=h;mesh.radial_segments=12;node.mesh=mesh;node.material_override=material(tone);root.add_child(node);node.position=p;return node
func leaf(root:Node3D,p:Vector3,tone:String,angle:float=0):
	var l:MeshInstance3D=box(root,p,Vector3(.12,.24,.035),tone,angle);l.rotation.y=.18
func photo(root:Node3D,p:Vector3,s:Vector2,variant:Dictionary):
	var path:String=str(variant.get("file",variant.get("photo","")));var texture:Texture2D
	if textures.has(path):texture=textures[path]
	elif path.begins_with("res://") and ResourceLoader.exists(path):texture=load(path);textures[path]=texture
	elif not path.is_empty():
		if path.begins_with("user://") or path.is_absolute_path():
			var pic:=Image.load_from_file(path)
			if pic!=null and not pic.is_empty():
				if maxf(pic.get_width(),pic.get_height())>768:
					var ratio:float=768.0/maxf(pic.get_width(),pic.get_height());pic.resize(maxi(1,roundi(pic.get_width()*ratio)),maxi(1,roundi(pic.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
				texture=ImageTexture.create_from_image(pic)
		elif ResourceLoader.exists(path):texture=load(path)
		if texture!=null:
			if textures.size()>=32:textures.erase(textures.keys()[0])
			textures[path]=texture
	if texture!=null:
		var crop=variant.get("crop",[])
		if crop is Array and crop.size()==3 and (crop[0] is int or crop[0] is float) and (crop[1] is int or crop[1] is float) and (crop[2] is int or crop[2] is float) and is_finite(float(crop[0])) and is_finite(float(crop[1])) and is_finite(float(crop[2])):
			var scale_value:float=clampf(float(crop[2]),.1,1);var center:Vector2=Vector2(crop[0],crop[1]).clamp(Vector2.ONE*scale_value*.5,Vector2.ONE*(1-scale_value*.5));var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2((center-Vector2.ONE*scale_value*.5)*Vector2(texture.get_size()),Vector2(texture.get_size())*scale_value);texture=atlas
		var ratio:float=float(texture.get_width())/maxi(1,texture.get_height());var width:float=minf(s.x,s.y*ratio)
		var node:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(width,width/ratio);node.mesh=mesh;var mat:=StandardMaterial3D.new();mat.albedo_texture=texture;mat.roughness=.85;node.material_override=mat;root.add_child(node);node.position=p
	else:
		box(root,p,Vector3(s.x,s.y,.012),"b7d3d0")
		for i in 3:box(root,p+Vector3(-s.x*.28+i*s.x*.24,-s.y*.15+i%2*s.y*.05,.012),Vector3(s.x*.25,s.y*(.25+i%2*.15),.02),["e4d8bf","7b9e78","f5e9cc"][i])
		cylinder(root,p+Vector3(s.x*.24,s.y*.22,.012),s.x*.09,.025,"efd39b").rotation.x=PI*.5

func make(id:String,variant:Dictionary={})->Node3D:
	var root:=Node3D.new();root.name="Work_"+id
	var tone:String=["8aa8a2","bd9baf","d4bb85"][posmod(int(variant.get("tone",0)),3)]
	match id:
		"everyday_cover","legacy_frame":
			box(root,Vector3(0,.35,0),Vector3(.7,.7,.07),"e6dbc1");box(root,Vector3(0,.35,.041),Vector3(.58,.58,.025),tone)
			var disc:MeshInstance3D=cylinder(root,Vector3(0,.35,.067),.23,.025,"344b49");disc.rotation.x=PI*.5;cylinder(root,Vector3(0,.35,.085),.07,.02,"e2c68f").rotation.x=PI*.5
			for i in 3:box(root,Vector3(-.22+i*.22,.08,.06),Vector3(.13,.025,.015),"f1e4c7")
		"record_stand":
			for x in [-.49,.49]:box(root,Vector3(x,.50,0),Vector3(.08,1,.42),"947956");box(root,Vector3(x,.08,0),Vector3(.2,.08,.5),"705a44")
			for y in [.18,.6]:box(root,Vector3(0,y,0),Vector3(1.13,.08,.45),"a58b65")
			for i in 3:
				var cover:Node3D=make("everyday_cover",{"tone":i});root.add_child(cover);cover.position=Vector3(-.34+i*.34,.22,0);cover.scale=Vector3.ONE*.44
		"street_box":
			box(root,Vector3(0,.07,0),Vector3(1.1,.14,.7),"a48b67");box(root,Vector3(0,.15,.20),Vector3(1,.03,.15),"7d8e8c")
			for i in 3:
				var p:=Vector3(-.33+i*.33,.33+i%2*.1,-.1);box(root,p,Vector3(.25,.36+i%2*.2,.28),["d1bdb0","9eb8af","e2d2ab"][i]);box(root,p+Vector3(0,.20+i%2*.1,0),Vector3(.3,.07,.34),"697e74")
				for j in 2:box(root,p+Vector3(0,-.07+j*.14,.15),Vector3(.1,.07,.015),"f4db9e",0,true)
		"street_lamp":
			cylinder(root,Vector3(0,.08,0),.22,.16,"8d826a");cylinder(root,Vector3(0,.70,0),.045,1.3,"6d7868");box(root,Vector3(0,1.27,0),Vector3(.45,.07,.42),"756c50");box(root,Vector3(0,1.35,0),Vector3(.28,.24,.28),"f4dca0",0,true);box(root,Vector3(0,1.5,0),Vector3(.4,.06,.4),"667b70")
		"poem_journal","star_bookmark","legacy_bookmark":
			var bookmark:bool=id!="poem_journal";box(root,Vector3(0,.04,0),Vector3(.18 if bookmark else .55,.08,.6 if bookmark else .75),tone)
			box(root,Vector3(0,.086,0),Vector3(.14 if bookmark else .48,.015,.53 if bookmark else .68),"f3e6cb")
			for i in 5:box(root,Vector3(0,.10,-.21+i*.09),Vector3(.11 if bookmark else .32,.008,.014),"a29880")
			for angle in [0,PI*.5]:box(root,Vector3(.0,.105,-.08),Vector3(.06,.018,.20),"c4aa71").rotation.y=angle+PI*.25
		"frost_light":
			for x in [-.62,.62]:box(root,Vector3(x,.79,0),Vector3(.055,1.58,.055),"697b7d");box(root,Vector3(x,.04,0),Vector3(.45,.08,.6),"8c9b95")
			box(root,Vector3(0,1.55,0),Vector3(1.5,.07,.07),"6c8182")
			for i in 3:
				box(root,Vector3(-.45+i*.45,1.40,.0),Vector3(.25,.24,.28),"7b8594");box(root,Vector3(-.45+i*.45,1.37,.15),Vector3(.18,.14,.03),["d4bddd","c4d9e5","e8d2a3"][i],0,true)
		"mini_stage":
			box(root,Vector3(0,.16,0),Vector3(1.5,.32,1),"a58c6b");box(root,Vector3(0,.4,-.39),Vector3(1.45,.07,.12),"e0d0b2")
			for x in [-.66,.66]:box(root,Vector3(x,.58,-.36),Vector3(.08,.8,.08),"70696b")
			for i in 8:box(root,Vector3(-.57+i*.16,.63,-.37),Vector3(.15,.47,.045),"c0b3ca" if i%2 else "a3b5c4")
			for i in 4:box(root,Vector3(-.52+i*.35,.335,.12),Vector3(.27,.025,.3),["bbccda","d3bfd6"][i%2],0,true)
		"flower_screen","castle_screen":
			for x in [-.74,.74]:box(root,Vector3(x,.88,0),Vector3(.09,1.76,.22),"8c7456");box(root,Vector3(x,.06,0),Vector3(.25,.12,.35),"806848")
			for y in [.22,1.65]:box(root,Vector3(0,y,0),Vector3(1.5,.07,.08),"987c57")
			box(root,Vector3(0,.94,0),Vector3(1.32,1.3,.035),"dddbc2")
			for i in 5:box(root,Vector3(-.53+i*.265,.94,.04),Vector3(.025,1.3,.025),"a08e6e")
			if id=="flower_screen":
				for i in 7:
					var p:=Vector3(sin(i*2.399)*.45,.43+i*.14,.065);leaf(root,p,"9caf87",i*.6);box(root,p+Vector3(.10,.05,.025),Vector3(.12,.12,.05),["dfb2bf","d5bd79","d6d8c2"][i%3],PI*.25)
		"flower_token":
			box(root,Vector3(0,.45,0),Vector3(.035,.55,.025),"c4ad80");box(root,Vector3(0,.31,0),Vector3(.36,.36,.05),"c8b39a",PI*.25)
			for i in 5:
				var a:float=i*TAU/5;box(root,Vector3(sin(a)*.10,.31+cos(a)*.10,.045),Vector3(.12,.12,.035),"e5bfcb",a)
			for x in [-.08,.08]:box(root,Vector3(x,.09,.02),Vector3(.045,.18,.025),"bba5c0",x)
		"photo_print","travel_frame","legacy_photo","forest_print","glass_tile":
			var s:=Vector2(.55,.7) if id in ["photo_print","legacy_photo"] else Vector2(.8,.95) if id=="travel_frame" else Vector2(.65,.85)
			box(root,Vector3(0,s.y*.5,0),Vector3(s.x,s.y,.04),"b99c76" if id=="travel_frame" else "e9dfc7")
			if id=="forest_print":
				for i in 5:leaf(root,Vector3(sin(i*2)*.18,.18+i*.12,.04),["718d6c","9aa47c","607c70"][i%3],sin(i)*.6)
			elif id=="glass_tile":
				for i in 9:box(root,Vector3(-.2+i%3*.2,.20+(i/3)*.20,.04),Vector3(.18,.18,.035),["82c8c3","b0d7cf","9cbacb","d7b8be"][i%4],i*.05)
			else:photo(root,Vector3(0,s.y*.51,.028),s*Vector2(.85,.84),variant)
		"coral_lamp":
			cylinder(root,Vector3(0,.07,0),.27,.14,"a9916c")
			for i in 5:
				var p:=Vector3(sin(i*2.4)*.16,.37+i%2*.13,cos(i*2.4)*.13);box(root,p,Vector3(.12,.50,.12),["98d6cd","b8cddc","d9b6c2"][i%3],sin(i)*.35,true)
			cylinder(root,Vector3(0,.24,0),.14,.18,"f2d5a5")
		"drift_chime","legacy_windchime","legacy_house_chime":
			box(root,Vector3(0,.95,0),Vector3(.8,.10,.15),"a28a65",.06)
			for i in 5:
				var y:float=.55-absf(i-2)*.06;box(root,Vector3(-.32+i*.16,(y+.92)*.5,0),Vector3(.012,.92-y,.012),"bda57c");cylinder(root,Vector3(-.32+i*.16,y,0),.07,.22,"eadbc2")
		"tidal_pack","leaf_pack","woodbuckle_pack","starter_basic_pack":
			var pack_tone:String={"tidal_pack":"8fb5b7","leaf_pack":"a2b18b","woodbuckle_pack":"b49b7c","starter_basic_pack":"d3c6a3"}[id]
			box(root,Vector3(0,.33,0),Vector3(.48,.60,.24),pack_tone);box(root,Vector3(0,.52,.14),Vector3(.5,.18,.035),"e8ddbc");box(root,Vector3(0,.24,.15),Vector3(.34,.20,.06),pack_tone)
			for x in [-.16,.16]:box(root,Vector3(x,.34,-.16),Vector3(.055,.52,.05),"887b5f");box(root,Vector3(x,.46,.175),Vector3(.055,.12,.03),"9e8058")
			if id=="leaf_pack":
				for i in 3:leaf(root,Vector3(-.11+i*.11,.27,.19),"627e5e",i*.4-.4)
			elif id=="tidal_pack":
				for i in 3:box(root,Vector3(0,.18+i*.06,.19),Vector3(.28,.018,.018),"dbe9dc",sin(i)*.1)
			match str(variant.get("pattern_style","")):
				"海湾波纹":
					for i in 5:box(root,Vector3(-.12+i*.06,.36+sin(i*1.4)*.018,.19),Vector3(.075,.018,.018),"e6ead0",sin(i*1.4)*.25)
				"林间叶脉":
					for i in 3:leaf(root,Vector3(-.09+i*.09,.35,.19),"627e5e",i*.4-.4)
				"城郭窗纹":
					for i in 3:box(root,Vector3(-.09+i*.09,.34,.19),Vector3(.018,.15,.018),"896f50");box(root,Vector3(0,.28+i*.06,.19),Vector3(.22,.018,.018),"896f50")
		"woodgrain_lamp","paper_lamp","legacy_lamp":
			box(root,Vector3(0,.06,0),Vector3(.6,.12,.5),"a48a65");box(root,Vector3(0,.43,0),Vector3(.42,.6,.34),"efdeb6",0,true)
			for x in [-.23,.23]:
				for z in [-.18,.18]:box(root,Vector3(x,.43,z),Vector3(.045,.65,.045),"8d7558")
			box(root,Vector3(0,.77,0),Vector3(.57,.07,.45),"967e5c")
			if id=="woodgrain_lamp":
				for i in 4:box(root,Vector3(-.14+i*.095,.44,.19),Vector3(.02,.53,.018),"ab9474",sin(i)*.04)
		"castle_table":
			box(root,Vector3(0,.6,0),Vector3(1.6,.10,1.0),"a98d67")
			for x in [-.62,.62]:
				for z in [-.34,.34]:box(root,Vector3(x,.29,z),Vector3(.10,.58,.1),"816949")
			for x in [-.62,.62]:box(root,Vector3(x,.18,0),Vector3(.08,.06,.75),"907451")
		"castle_cushion":
			box(root,Vector3(0,.075,0),Vector3(.75,.15,.75),tone);box(root,Vector3(0,.16,0),Vector3(.68,.035,.68),"d7cbb4");box(root,Vector3(0,.18,0),Vector3(.055,.02,.055),tone)
		"flower_stand":
			for x in [-.51,.51]:box(root,Vector3(x,.68,0),Vector3(.08,1.36,.5),"a38b62")
			for i in 3:
				box(root,Vector3(0,.18+i*.5,0),Vector3(1.15,.07,.6),"aa946e")
				for j in 2:
					cylinder(root,Vector3(-.28+j*.56,.32+i*.5,0),.12,.22,"ba9b7c");leaf(root,Vector3(-.28+j*.56,.50+i*.5,0),"8aa079",j*.3)
		"water_garden":
			box(root,Vector3(0,.07,0),Vector3(1.2,.14,.9),"c4bca3")
			for i in 3:
				box(root,Vector3(-.38+i*.38,.18+i*.14,0),Vector3(.34,.24+i*.28,.72),"ded9c2");box(root,Vector3(-.38+i*.38,.31+i*.28,.0),Vector3(.28,.018,.64),"94cac5",0,true)
		"bay_model":
			box(root,Vector3(0,.07,0),Vector3(1.4,.14,1),"a9cfc7");box(root,Vector3(0,.16,-.18),Vector3(1.34,.10,.55),"e3d9b9")
			var pattern:Array=variant.get("pattern",[])
			if pattern.size()==9:
				for i in 9:
					var p:=Vector3(-.45+i%3*.45,.17,-.30+(i/3)*.30);var part:int=int(pattern[i]);box(root,p,Vector3(.42,.06,.27),["95c8c3","e9dfbf","99af8c","e8dec4","c9d4b1"][posmod(part,5)])
					if part==3:box(root,p+Vector3.UP*.18,Vector3(.23,.32,.19),"f1e8d3");box(root,p+Vector3.UP*.37,Vector3(.25,.05,.22),"8dafb1")
					elif part==2:box(root,p+Vector3.UP*.10,Vector3(.30,.20,.21),"98ab8c")
					elif part==4:box(root,p+Vector3.UP*.20,Vector3(.045,.4,.045),"9c8562");box(root,p+Vector3.UP*.42,Vector3(.30,.08,.24),"86a17a")
			else:
				for i in 5:
					var p:=Vector3(-.5+i*.25,.3+i%2*.12,-.28);box(root,p,Vector3(.20,.25+i%2*.24,.23),"eee5cf");box(root,p+Vector3(0,.16+i%2*.12,0),Vector3(.21,.07,.25),"91b3b6")
		"sail_flag":
			cylinder(root,Vector3(0,.06,0),.17,.12,"b29b77");cylinder(root,Vector3(0,.55,0),.027,1.1,"8b7759")
			for i in 6:box(root,Vector3(.05+i*.055,.93-i*.055,0),Vector3(.13,.12,.028),tone)
			box(root,Vector3(.12,.48,0),Vector3(.4,.04,.04),"b0a07d")
		"legacy_bouquet":
			var palette:Array=variant.get("colors",["e5bac7","e4c576","a9c4dc","b5a2d6","f3ecdc"])
			if palette.is_empty():palette=["e5bac7"]
			for i in 7:
				box(root,Vector3(sin(i*2.4)*.12,.21,cos(i*2.4)*.12),Vector3(.018,.42,.018),"7a916e")
				var color=palette[i%palette.size()];var color_word:String=["f4b8c4","f2c14e","6ba4d6","9b7ede","faf6f0"][posmod(int(color),5)] if color is int or color is float else str(color)
				box(root,Vector3(sin(i*2.4)*.17,.48+i%2*.05,cos(i*2.4)*.17),Vector3(.18,.18,.18),color_word,PI*.25)
			box(root,Vector3(0,.16,0),Vector3(.27,.27,.27),"d6c19c")
		"legacy_pottery":
			var shape:int=int(variant.get("shape",0));var glaze:int=int(variant.get("glaze",0));cylinder(root,Vector3(0,.12,0),.17,.24,["8cbdb7","d9afbd","738ba8"][posmod(glaze,3)]);cylinder(root,Vector3(0,.32 if shape==0 else .20,0),.12 if shape==0 else .24,.24 if shape==0 else .12,["8cbdb7","d9afbd","738ba8"][posmod(glaze,3)])
		"legacy_conchbox":
			box(root,Vector3(0,.08,0),Vector3(.55,.16,.45),"b39c77")
			for i in 5:cylinder(root,Vector3(-.15+i*.065,.25-i*.015,0),.16-i*.02,.18,"e5d2b3")
		"legacy_bread","legacy_harvest":
			box(root,Vector3(0,.1,0),Vector3(.7,.2,.5),"b29a72")
			for i in 5:cylinder(root,Vector3(-.24+i%3*.22,.26+i/3*.12,0),.12,.16,"dcb172" if id=="legacy_bread" else "c7a27a")
		"legacy_wax":cylinder(root,Vector3(0,.08,0),.23,.16,"ead8bb");leaf(root,Vector3(0,.18,0),"baa0b5",.4)
		"legacy_fruit","legacy_drink":cylinder(root,Vector3(0,.15,0),.13,.30,"e9dec4");cylinder(root,Vector3(0,.31,0),.115,.012,"c8ad7a")
		_:
			box(root,Vector3(0,.15,0),Vector3(.32,.3,.28),"b4a184")
	if variant.has("tone") and not id.begins_with("legacy_"):apply_palette(root,int(variant.tone))
	return root

func apply_palette(root:Node3D,index:int):
	var palette:Color=[Color("93b9b4"),Color("c79daf"),Color("d7be86")][posmod(index,3)]
	for node in root.find_children("*","MeshInstance3D",true,false):
		var source:Material=node.material_override
		# Photograph pixels are never recolored; the surrounding frame can change finish.
		if not source is StandardMaterial3D or source.albedo_texture!=null:continue
		var key:String="palette:"+source.albedo_color.to_html()+":"+str(index)+":"+str(source.emission_enabled)
		if not materials.has(key):
			var copy:StandardMaterial3D=source.duplicate();copy.albedo_color=source.albedo_color.lerp(palette,.36)
			if copy.emission_enabled:copy.emission=source.emission.lerp(palette,.22)
			materials[key]=copy
		node.material_override=materials[key]
