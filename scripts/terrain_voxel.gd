extends RefCounted
## One heightfield for visible faces, collision, rooted planting and character ground queries.
var w
var config:Dictionary
var routes:Dictionary={}
var tiles:Dictionary={}
var smooth_cells:Dictionary={}
var material:ShaderMaterial
var ridge_noise:=FastNoiseLite.new()
var rock_normals_094:=0
var inward_normals_094:=0
var rock_panels_094:=0
var rock_faces_094:=0
var roadcut_art
const CELL=2.0
const INDICES=[0,1,2,0,2,3]
const EDGES=[[0,1,Vector2i(0,-1),3,2],[1,2,Vector2i(1,0),0,3],[2,3,Vector2i(0,1),1,0],[3,0,Vector2i(-1,0),2,1]]

func _init(target):
	w=target
	roadcut_art=preload("res://scripts/roadcut_art.gd").new(self)
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/environment_v12.json"))
	ridge_noise.seed=int(config.seed)+41
	ridge_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge_noise.frequency=0.022
	ridge_noise.fractal_type=FastNoiseLite.FRACTAL_FBM
	ridge_noise.fractal_octaves=3
	ridge_noise.fractal_gain=0.45
	material=ShaderMaterial.new();material.shader=load("res://assets/materials/terrain_strata.gdshader")
	material.render_priority=120
	if w.layout!=null:
		preload("res://scripts/bay_authoring.gd").new(w).set_water_curve(material)
		material.set_shader_parameter("bay_enabled",true)
		for segment in w.layout.segments:
			if not segment.bridge:index_route(Vector2(segment.a.x,segment.a.z),Vector2(segment.c.x,segment.c.z),segment.width)
		return
	var authored:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain_routes_v12.json"))
	for record in authored.corridors:
		var a:=Vector2(record.a[0],record.a[1]);var c:=Vector2(record.c[0],record.c[1])
		index_route(a,c,float(record.width))
	for zone in w.spec.zones:
		var access:Array[Vector2]=w.stamp_access_points(zone)
		for i in access.size()-1:index_route(access[i],access[i+1],3.0)
	# The shorter supported timber approach now begins on an actual arrival terrace.
	index_route(Vector2(-237,-148.5),Vector2(-237,-157),3.0)
	index_route(Vector2(-237,-157),Vector2(-237,-160.36),2.6)
	index_route(Vector2(-246,-174),Vector2(-256,-185),2.4)
	index_route(Vector2(-256,-185),Vector2(-266,-201),2.4)
	index_route(Vector2(-266,-201),Vector2(-278,-211),2.4)
	index_route(Vector2(284,-295.5),Vector2(286,-302),5.0)
	index_route(Vector2(287,-312),Vector2(303,-317),3.2)
	var coast_route:Array=config.get("coast_garden_route",[])
	for i in coast_route.size()-1:index_route(Vector2(coast_route[i][0],coast_route[i][1]),Vector2(coast_route[i+1][0],coast_route[i+1][1]),2.8)
	index_route(Vector2(-146,282.8),Vector2(-146,286),2.8)
	material=ShaderMaterial.new();material.shader=load("res://assets/materials/terrain_strata.gdshader")
	material.render_priority=120

func index_route(a:Vector2,c:Vector2,width:float):
	var pad:float=width/2+15
	for x in range(floori((minf(a.x,c.x)-pad)/16),floori((maxf(a.x,c.x)+pad)/16)+1):
		for z in range(floori((minf(a.y,c.y)-pad)/16),floori((maxf(a.y,c.y)+pad)/16)+1):
			var key:=Vector2i(x,z)
			if not routes.has(key):routes[key]=[]
			routes[key].append({"a":a,"c":c,"width":width})

func biome(p:Vector2)->String:
	if w.layout!=null:
		for river in w.layout.near(w.layout.river_index,p):
			var q:Vector3=w.layout.projection(p,river)
			if p.distance_to(Vector2(q.x,q.z))<river.width*0.5+8.0:return "river"
		var forest:Dictionary=w.layout.config.get("island2",{})
		if not forest.is_empty():
			var r:float=Vector2((p.x-forest.center[0])/forest.radius[0],(p.y-forest.center[1])/forest.radius[1]).length()
			if r<.85:return "woodland"
		if p.y>w.layout.shore_z(p.x)-22.0:return "sand"
		if p.y>245.0:return "coast"
		if p.y< -345.0:return "summit"
		if p.y< -290.0:return "montane"
		if p.distance_to(Vector2(-225,-230))<70.0:return "garden"
		return "woodland" if p.y< -120.0 else "town"
	var river_x:float=307+18*sin(p.y*0.014)
	if absf(p.x-river_x)<30:return "river"
	if p.y>290:return "sand"
	if p.y>255:return "coast"
	if p.y< -345:return "summit"
	if p.y< -240:return "montane"
	if p.distance_to(Vector2(-237,-169))<38:return "garden"
	if p.y< -150:return "woodland"
	return "town"

func voxel_at(p:Vector2)->bool:
	if w.layout!=null:return p.y< -115 or (w.layout.height_at(p)>5.0 and biome(p) not in ["sand","coast"])
	if str(config.coverage)=="home_hillside":return p.y< -145 and p.distance_to(Vector2(-237,-169))<float(config.sample_radius_m)
	return p.y< -152 or (biome(p)=="river" and p.y<250) or dune_height(p)>0.28

func dune_height(p:Vector2)->float:
	if p.y<255 or p.y>298:return 0.0
	var rise:=0.0
	for dune in config.get("coast_dunes",[]):
		var delta:=Vector2((p.x-dune.center[0])/dune.radius[0],(p.y-dune.center[1])/dune.radius[1])
		var contour:float=delta.length()+0.07*sin(p.x*0.27+p.y*0.12)
		rise=maxf(rise,float(dune.height)*(1.0-smoothstep(0.0,1.0,contour)))
	return rise

func protected(p:Vector2)->bool:
	if w.layout!=null:return w.layout.protected(p)
	if p.y>255 and absf(p.y-(303+10*sin(p.x*0.015)))<9.0:return true
	for terrace in config.get("protected_terraces",[]):
		if absf(p.x-terrace.center[0])<terrace.size[0]/2 and absf(p.y-terrace.center[1])<terrace.size[1]/2:return true
	for item in w.spec.buildings:
		var pad:float=1.8 if item.type=="home" else 9.0
		if absf(p.x-item.x)<item.w/2+pad and absf(p.y-item.z)<item.d/2+pad:return true
	if absf(p.x+237)<6.5 and p.y> -161.5 and p.y< -154.5:return true
	for road in routes.get(Vector2i(floori(p.x/16),floori(p.y/16)),[]):
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,road.a,road.c))<road.width/2+2.3:return true
	return false

func road_clearance(p:Vector2)->float:
	var result:=12.0
	for road in routes.get(Vector2i(floori(p.x/16),floori(p.y/16)),[]):
		var distance:float=p.distance_to(Geometry2D.get_closest_point_to_segment(p,road.a,road.c))-road.width/2-2.3
		result=minf(result,maxf(0,distance))
	return result

func smooth_height(p:Vector2)->float:
	if w.layout!=null:return w.layout.height_at(p)
	if absf(p.x)<4.5 and p.y< -365 and p.y> -379:
		return lerpf(w.legacy_height_at(0,-365),w.legacy_height_at(0,-385),clampf((-p.y-365)/11.0,0,1))
	for terrace in config.get("protected_terraces",[]):
		if absf(p.x-terrace.center[0])<terrace.size[0]/2 and absf(p.y-terrace.center[1])<terrace.size[1]/2:return w.legacy_height_at(terrace.center[0],terrace.center[1])
	var home_y:float=w.legacy_height_at(-237,-169)
	if absf(p.x+237)<6.5 and p.y>= -161.5 and p.y<= -154.5:return home_y-0.45
	if absf(p.x+237)<3.7 and p.y> -154.5 and p.y<= -148.5:
		return lerpf(home_y-0.45,w.legacy_height_at(-237,-148.5),(p.y+154.5)/6.0)
	return w.legacy_height_at(p.x,p.y)+garden_road_relief(p)

func garden_road_relief(p:Vector2)->float:
	# A low landscaped saddle raises the centre of the existing hillside path.
	# Endpoints remain unchanged; both terrain and paving query this same function.
	var a:=Vector2(-256,-185);var c:=Vector2(-266,-201)
	var axis:Vector2=(c-a).normalized();var distance:float=(p-a).dot(axis)
	var across:float=absf((p-a).cross(axis))
	return 0.95*smoothstep(0.0,6.5,distance)*(1.0-smoothstep(12.0,18.87,distance))*(1.0-smoothstep(2.0,7.0,across))

func mountain_relief(p:Vector2,h:float)->float:
	# Broad authored spurs and drainage hollows, with smaller irregular contour edges.
	# This changes real terrace heights; planting is rebuilt against the same surface.
	var relief:float=11.0*ridge_noise.get_noise_2d(p.x,p.y)
	for landform in config.get("mountain_landforms",[]):
		var q:=Vector2((p.x-landform.center[0])/landform.radius[0],(p.y-landform.center[1])/landform.radius[1])
		relief+=float(landform.rise)*exp(-q.length_squared()*1.7)
	var edge:float=(1.0-smoothstep(-218.0,-155.0,p.y))*smoothstep(1.0,12.0,h)
	var river_distance:float=absf(p.x-(307+18*sin(p.y*0.014)))
	# Preserve the verified waterfall/river landform and blend well outside its banks.
	var river_blend:float=smoothstep(42.0,80.0,river_distance)
	return relief*edge*river_blend

func terrace_height(h:float)->float:
	# Alternate geological bed thickness by elevation, never by an abrupt XY mask.
	var unit:float=float(config.tier_m)
	var band:float=floorf(h/(unit*6))*unit*6
	var fraction:float=h-band
	for threshold in [5.0,3.0,2.0,0.0]:
		if fraction>=threshold*unit:return band+threshold*unit
	return band

func landform_blend(p:Vector2)->float:
	# A rest pocket includes its surrounding view, not only the bench footprint.
	# Keep the former contour nearby and blend over a broad band so a new spur
	# cannot become an enclosing wall immediately outside a protected terrace.
	var result:=1.0
	for terrace in config.get("protected_terraces",[]):
		if not terrace.has("landform_clearance_m"):continue
		var edge:=Vector2(maxf(0,absf(p.x-terrace.center[0])-terrace.size[0]/2),maxf(0,absf(p.y-terrace.center[1])-terrace.size[1]/2))
		var clearance:float=terrace.landform_clearance_m
		result=minf(result,smoothstep(clearance,clearance+float(terrace.landform_blend_m),edge.length()))
	return result

func smooth_tile(coord:Vector2i)->bool:
	if smooth_cells.has(coord):return smooth_cells[coord]
	var p:=Vector2(coord.x*CELL+CELL/2,coord.y*CELL+CELL/2)
	var result:bool=not voxel_at(p) or protected(p)
	for offset in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		if protected(p+offset):result=true
	smooth_cells[coord]=result
	return result

func shared_protected_vertex(p:Vector2)->bool:
	# All four cells touching this vertex must use the same protected height.
	var key:=Vector2i(roundi(p.x/CELL),roundi(p.y/CELL))
	for offset in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i(0,0)]:
		if smooth_tile(key+offset):return true
	return false

func tile(coord:Vector2i)->Dictionary:
	if tiles.has(coord):return tiles[coord]
	var p:=Vector2(coord.x*CELL+CELL/2,coord.y*CELL+CELL/2)
	var corners:=[p+Vector2(-1,-1),p+Vector2(1,-1),p+Vector2(1,1),p+Vector2(-1,1)]
	var smooth:bool=smooth_tile(coord)
	var heights:PackedFloat32Array=[]
	var h:float=w.legacy_height_at(p.x,p.y)
	if w.layout!=null and not smooth:
		var relief:float=(10.0 if p.y< -210 else 3.0)*ridge_noise.get_noise_2d(p.x,p.y)*smoothstep(1.5,12.0,road_clearance(p))
		h=floorf((h+relief)/0.8)*0.8
	elif not smooth and p.y>255:
		# Low sand/grass banks use the same actual mesh and collision, in 0.4 m steps.
		h=floorf((h+dune_height(p))/0.4)*0.4
	elif not smooth:
		# Broad interlocking ridges and hollows break long parallel contours without changing roads.
		var old_variation:float=(4.5*sin(p.x*0.025+p.y*0.012)*sin(p.y*0.019)+2.0*sin(p.x*0.061-p.y*0.021))*smoothstep(1.0,16.0,h)
		if biome(p)=="river":old_variation*=smoothstep(10.0,26.0,absf(p.x-(307+18*sin(p.y*0.014))))
		var old_spur:float=8.0*exp(-pow((p.x+305)/62,2)-pow((p.y+265)/70,2))*smoothstep(2.0,12.0,h)
		var old_tier:float=float(config.tier_m)*(2.0 if sin(p.x*0.016+p.y*0.027)>0.28 and h>6 else 1.0)
		# Keep quantized tops, but taper the added ridges beside preserved paths. Abrupt
		# 6-14 m deviations here used to create long fins along a smooth road shoulder.
		var shoulder:float=smoothstep(0.0,12.0,road_clearance(p))
		var river_distance:float=absf(p.x-(307+18*sin(p.y*0.014)))
		var old_height:float=floorf((h+(old_variation+old_spur)*shoulder)/old_tier)*old_tier
		var blend:float=smoothstep(42.0,82.0,river_distance)*(1.0-smoothstep(-220.0,-156.0,p.y))*landform_blend(p)
		if blend<=0.0:h=old_height
		else:
			var revised:float=terrace_height(h+mountain_relief(p,h)*shoulder)
			h=floorf(lerpf(old_height,revised,blend)/float(config.tier_m))*float(config.tier_m)
	for q in corners:
		var ground:float=smooth_height(q) if smooth else h
		if not smooth and (w.layout!=null or p.y< -152.0):
			# A narrow engineered verge meets the unchanged protected road. Horizontal
			# terrace tops remain beyond four metres from that protected edge.
			var verge:float=smoothstep(0.0,4.0,road_clearance(q))
			ground=smooth_height(q) if shared_protected_vertex(q) else lerpf(smooth_height(q),h,verge)
		heights.append(ground)
	var record:={"heights":heights,"smooth":smooth,"biome":biome(p),"walkable":smooth or biome(p)=="garden","buildable":protected(p),"tree_allowed":not smooth and biome(p)!="river","tier":floori(h/float(config.tier_m))}
	tiles[coord]=record
	return record

func height_at(x:float,z:float)->float:
	var coord:=Vector2i(floori(x/CELL),floori(z/CELL))
	var h:PackedFloat32Array=tile(coord).heights
	var u:=x/CELL-coord.x;var v:=z/CELL-coord.y
	# Exactly the same diagonal as the top mesh: no bilinear/triangle collision disagreement.
	if v<=u:return h[0]*(1-u)+h[1]*(u-v)+h[2]*v
	return h[0]*(1-v)+h[2]*u+h[3]*(v-u)

func grass_color(p:Vector2)->Color:
	var region:=biome(p)
	if w.layout!=null:
		var forest:Dictionary=w.layout.config.get("island2",{})
		if not forest.is_empty():
			var r:float=Vector2((p.x-forest.center[0])/forest.radius[0],(p.y-forest.center[1])/forest.radius[1]).length()
			if r<1.5:return Color("7d9866").lightened(.04*sin(p.x*.2)*sin(p.y*.15)).lerp(Color("eee4c5"),smoothstep(.78,1.04,r))
		if p.y>405:
			var island:Dictionary=w.layout.config.island
			var radius:float=Vector2((p.x-island.center[0])/island.radius[0],(p.y-island.center[1])/island.radius[1]).length()
			return Color("f5ebd6").lerp(Color("a2b67d"),(1-smoothstep(.42,.76,radius))*.7)
		var tone:Color={"sand":Color("dfca9e"),"coast":Color("a8af77"),"town":Color("98a76a"),"garden":Color("91a477"),"woodland":Color("5e805b"),"montane":Color("738866"),"summit":Color("9b9c7b"),"river":Color("6f927a")}.get(region,Color("98a76a"))
		tone=tone.lerp(Color("d4bd95"),azure_stone(p)*.92)
		return tone.lightened(0.07*sin(p.x*0.021)*sin(p.y*0.019))
	var color:=Color("82965d")
	var edge:float=8.0*sin(p.x*0.025)+5.0*sin(p.x*0.071+p.y*0.012)
	color=Color("82965d").lerp(Color("627d62"),1.0-smoothstep(-174.0+edge,-135.0+edge,p.y))
	color=color.lerp(Color("6a805d"),1.0-smoothstep(-272.0+edge,-215.0+edge,p.y))
	color=color.lerp(Color("89917a"),1.0-smoothstep(-382.0+edge,-326.0+edge,p.y))
	var river:float=absf(p.x-(307+18*sin(p.y*0.014)))
	color=color.lerp(Color("788f70"),1.0-smoothstep(18.0,44.0,river))
	if region=="garden":color=color.lerp(Color("8f9f68"),0.30)
	if region in ["sand","coast"]:
		var sand:Color=Color("d9c69f").lerp(Color("bdaa85"),smoothstep(315,350,p.y))
		var border:float=289+5*sin(p.x*0.026)+2*sin(p.x*0.063)
		color=Color("94a17e").lerp(sand,smoothstep(border-6,border+8,p.y))
	var broad:float=sin(p.x*0.019+sin(p.y*0.015))*sin(p.y*0.023)
	var hollow:float=clampf(-ridge_noise.get_noise_2d(p.x,p.y)*1.8,0,1)
	var woodland_weight:float=(1.0-smoothstep(-174.0+edge,-135.0+edge,p.y))*smoothstep(-385.0,-330.0,p.y)
	color=color.lerp(Color("435e55"),hollow*0.40*woodland_weight)
	return color.lightened(0.045*broad)

func azure_stone(p:Vector2)->float:
	if w.layout==null or p.x<101 or p.x>226 or p.y< -88 or p.y>108:return 0.0
	var radius:float=Vector2((p.x-187)/84.0,(p.y+16)/88.0).length()
	return (1.0-smoothstep(.70,1.1,radius))*(1.0-smoothstep(219,226,p.x))

func emit(st:SurfaceTool,points:Array,tone:Color,normal:Vector3):
	var order:Array=INDICES if absf(normal.y)>0.1 else [0,2,1,0,3,2]
	for index in order:
		st.set_normal(normal);st.set_color(tone);st.add_vertex(points[index])

func side(st:SurfaceTool,a:Vector3,c:Vector3,low_a:float,low_c:float,region:String,coord:Vector2i,far:bool=false):
	low_a=minf(low_a,a.y);low_c=minf(low_c,c.y)
	if maxf(a.y-low_a,c.y-low_c)<0.0001:return
	var normal:Vector3=Vector3((c-a).z,0,-(c-a).x).normalized()
	var cap_a:=maxf(low_a,a.y-float(config.grass_cap_m));var cap_c:=maxf(low_c,c.y-float(config.grass_cap_m))
	var soil_depth:float=float(config.topsoil_m)
	if region in ["woodland","montane","summit"]:
		var altitude:float=smoothstep(12.0,70.0,(a.y+c.y)/2)
		soil_depth*=lerpf(0.90,0.28,altitude)*(0.83+0.17*ridge_noise.get_noise_2d(a.x,a.z))
	# Thinner exposed crests, deeper soil pockets: irregular boundary on each endpoint.
	var depth_a:float=soil_depth*soil_pocket(Vector2(a.x,a.z))
	var depth_c:float=soil_depth*soil_pocket(Vector2(c.x,c.z))
	var dirt_a:=maxf(low_a,cap_a-depth_a);var dirt_c:=maxf(low_c,cap_c-depth_c)
	var tint:float=0.025*sin(coord.x*0.61+coord.y*0.17)
	var grass:=grass_color(Vector2(a.x,a.z)).darkened(0.12)
	var dirt:=Color("806048").lightened(tint)
	var rock:=Color("828d8d").lerp(Color("475f69"),0.5 if region=="river" else 0.15).lightened(tint)
	if region=="summit":dirt=Color("858577");rock=Color("9b9f94").darkened(0.10)
	var retaining:bool=roadcut_art.classify(a,c,low_a,low_c,region)
	if retaining:
		# Alpha is an opaque material ID here; the terrain shader does not output ALPHA.
		dirt=Color("8b8c78");dirt.a=0.65
		rock=Color("838977");rock.a=0.65
		roadcut_art.dress(a,c,low_a,low_c,normal,far)
	var stone_weight:float=azure_stone(Vector2((a.x+c.x)*.5,(a.z+c.z)*.5))
	dirt=dirt.lerp(Color("b58262"),stone_weight)
	rock=rock.lerp(Color("bca280"),stone_weight)
	emit(st,[a,c,Vector3(c.x,cap_c,c.z),Vector3(a.x,cap_a,a.z)],grass,normal)
	if cap_a-dirt_a>0.0001 or cap_c-dirt_c>0.0001:emit(st,[Vector3(a.x,cap_a,a.z),Vector3(c.x,cap_c,c.z),Vector3(c.x,dirt_c,c.z),Vector3(a.x,dirt_a,a.z)],dirt,normal)
	if dirt_a-low_a>0.0001 or dirt_c-low_c>0.0001:
		var upper_a:=Vector3(a.x,dirt_a,a.z);var upper_c:=Vector3(c.x,dirt_c,c.z)
		if not far and not retaining and region in ["woodland","montane","summit","river"] and maxf(dirt_a-low_a,dirt_c-low_c)>0.65:
			rock_face(st,upper_a,upper_c,low_a,low_c,rock,normal,coord)
		else:emit(st,[upper_a,upper_c,Vector3(c.x,low_c,c.z),Vector3(a.x,low_a,a.z)],rock,normal)

func soil_pocket(p:Vector2)->float:
	# Exposed ribs interrupt the brown band; deeper soil persists only in pockets.
	var mass:float=sin(p.x*0.17+sin(p.y*0.11))*sin(p.y*0.23+p.x*0.07)
	var ribs:float=sin(p.x*0.57+p.y*0.41)
	return smoothstep(-0.20,0.48,mass+0.26*ribs)*0.86

func rock_face(st:SurfaceTool,a:Vector3,c:Vector3,low_a:float,low_c:float,tone:Color,normal:Vector3,coord:Vector2i):
	# Irregular fracture planes, not a repeated masonry bevel/grid.
	# Shared outer edges remain watertight. The collision is generated from this mesh.
	rock_faces_094+=1
	var high:float=maxf(a.y-low_a,c.y-low_c)
	var rows:int=clampi(ceili(high/1.55),1,12)
	var exponent:float=0.86+0.25*(0.5+0.5*sin(coord.x*0.36+coord.y*0.59))
	for row in rows:
		var t0:float=pow(float(row)/rows,exponent);var t1:float=pow(float(row+1)/rows,exponent)
		var aa:Vector3=a.lerp(Vector3(a.x,low_a,a.z),t0);var ac:Vector3=c.lerp(Vector3(c.x,low_c,c.z),t0)
		var ba:Vector3=a.lerp(Vector3(a.x,low_a,a.z),t1);var bc:Vector3=c.lerp(Vector3(c.x,low_c,c.z),t1)
		var outer:Array[Vector3]=[aa,ac,bc,ba]
		var across:float=0.30+0.38*(0.5+0.5*sin(coord.x*1.73+coord.y*0.77+row*2.1))
		var down:float=0.38+0.24*(0.5+0.5*cos(coord.x+coord.y*1.53+row))
		var center:Vector3=aa.lerp(ac,across).lerp(ba.lerp(bc,across),down)
		# Broad low-relief planes keep silhouette readable and avoid deep black block seams.
		center-=normal*(0.04+0.07*(0.5+0.5*sin(coord.x*0.81+coord.y+row*1.4)))
		var color:Color=tone.darkened(0.035*(0.5+0.5*sin(coord.x*0.17+coord.y*0.21+row)))
		if row==0:
			var damp:float=smoothstep(0.12,0.55,ridge_noise.get_noise_2d(a.x*2,a.z*2))
			color=color.lerp(Color("667d68"),damp*0.45)
		for edge in 4:
			var next:int=(edge+1)%4
			# Godot uses clockwise front faces: the shading normal opposes the triangle cross.
			var face_normal:Vector3=(outer[next]-outer[edge]).cross(center-outer[edge]).normalized()
			if face_normal.length_squared()<0.01:continue
			rock_normals_094+=1
			if face_normal.dot(normal)<=0.0:inward_normals_094+=1
			for vertex in [outer[edge],center,outer[next]]:
				st.set_normal(face_normal);st.set_color(color);st.add_vertex(vertex)
		rock_panels_094+=1

func make_mesh(coord:Vector2i,far:bool=false)->MeshInstance3D:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step:float=4.0 if far else CELL
	var sides:=0;var tops:=0
	for x in range(coord.x*96,coord.x*96+96,int(step)):
		for z in range(coord.y*96,coord.y*96+96,int(step)):
			var key:=Vector2i(floori(x/CELL),floori(z/CELL));var info:=tile(key)
			var corners:Array=[]
			var positions:=[Vector2(x,z),Vector2(x+step,z),Vector2(x+step,z+step),Vector2(x,z+step)]
			if far:
				var p:=Vector2(x+step/2,z+step/2);var smooth:bool=not voxel_at(p) or protected(p)
				var center_y:=height_at(p.x,p.y)
				for q in positions:corners.append(Vector3(q.x,height_at(q.x,q.y) if smooth else center_y,q.y)-Vector3(0,0.035,0))
			else:
				for i in 4:corners.append(Vector3(positions[i].x,info.heights[i],positions[i].y))
			var tone:=grass_color(Vector2(x+step/2,z+step/2))
			var normal:Vector3=(corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
			emit(st,corners,tone,normal);tops+=1
			for edge in EDGES:
				var a:Vector3=corners[edge[0]];var c:Vector3=corners[edge[1]]
				var low_a:float;var low_c:float
				if far:
					var offset:=Vector2(edge[2].x,edge[2].y)*step
					var q:=Vector2(x+step/2,z+step/2)+offset
					low_a=height_at(q.x,q.y)-0.035;low_c=low_a
				else:
					var other:=tile(key+edge[2]);low_a=other.heights[edge[3]];low_c=other.heights[edge[4]]
				var da:float=a.y-low_a;var dc:float=c.y-low_c
				if minf(da,dc)>=0.0 and maxf(da,dc)>0.0001:
					side(st,a,c,low_a,low_c,str(info.biome),key,far);sides+=1
				elif maxf(da,dc)>0.0001:
					# At road/terrace crossings, each neighbour owns only its higher half.
					# Split at the exact shared height to avoid overlapping opposing triangles.
					var fraction:float=clampf(da/(da-dc),0,1)
					var crossing:Vector3=a.lerp(c,fraction)
					if da>0:side(st,a,crossing,low_a,crossing.y,str(info.biome),key,far)
					else:side(st,crossing,c,crossing.y,low_c,str(info.biome),key,far)
					sides+=1
	var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material
	mesh.name=("FarStrata_" if far else "TerrainStrata_")+str(coord.x)+"_"+str(coord.y)
	mesh.set_meta("stream_cell",coord);mesh.set_meta("stream_terrain",true)
	mesh.set_meta("terrain_v12",{"cell_m":step,"top_faces":tops,"exposed_edges":sides,"coverage":config.coverage,"geometry":"horizontal tops and exposed grass/dirt/rock side faces"})
	if far:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
