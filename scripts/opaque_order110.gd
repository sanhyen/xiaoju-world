extends RefCounted
## Keep original opaque shaders and submit closer material groups first.
## Cells register once; unloading releases every node and material reference.
var groups:Dictionary={}
var cells:Dictionary={}
var dirty:=true
var last_eye:=Vector3.INF
var next_tick:=0
var updates:=0
var work:Array=[]
var work_index:=0
var work_eye:=Vector3.ZERO
var maximum_update_us:=0
const GROUPS_PER_FRAME=24

func eligible(node:GeometryInstance3D)->bool:
	if node.has_meta("stream_terrain") or node.material_overlay!=null:return false
	if not node is MultiMeshInstance3D and not node is MeshInstance3D:return false
	var material:Material=node.material_override
	if material==null or material.next_pass!=null:return false
	if groups.has(material.get_instance_id()):return true
	if material.render_priority!=0:return false
	if material is StandardMaterial3D:return material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED
	return material is ShaderMaterial and material.shader!=null and material.shader.resource_path.ends_with("voxel_surface.gdshader")

func bind_cell(cell:Node3D,id:String):
	if cells.has(id):unbind_cell(id)
	cells[id]=true
	for node in cell.find_children("*","GeometryInstance3D",true,false):
		if not eligible(node):continue
		var material:Material=node.material_override;var key:int=material.get_instance_id()
		if not groups.has(key):groups[key]={"material":material,"original":material.render_priority,"users":[]}
		groups[key].users.append({"cell":id,"node":weakref(node),"bounds":node.global_transform*node.get_aabb()})
	dirty=true

func unbind_cell(id:String):
	for key in groups.keys():
		var group:Dictionary=groups[key];group.users=group.users.filter(func(user):return user.cell!=id)
		if group.users.is_empty():group.material.render_priority=group.original;groups.erase(key)
	cells.erase(id);dirty=true

func update(camera:Camera3D,force:bool=false):
	if camera==null:return
	# Wide-view near scenes are hidden by the existing LOD. They need no reordering.
	if not force and camera.projection==Camera3D.PROJECTION_ORTHOGONAL and camera.size>=320:return
	var now:int=Time.get_ticks_msec();var eye:Vector3=camera.global_position
	if work.is_empty() and not force and not dirty and (now<next_tick or eye.distance_squared_to(last_eye)<1.0):return
	var immediate:bool=force or not last_eye.is_finite() or eye.distance_squared_to(last_eye)>1024.0
	if force or dirty or work.is_empty():work=groups.keys();work_index=0;work_eye=eye;dirty=false
	var started:int=Time.get_ticks_usec()
	# Spread moving-camera sorting across frames. Geometry does not depend on this
	# order; it only avoids shading occluded pixels. Large travel jumps refresh once.
	var finish:int=work.size() if immediate else mini(work.size(),work_index+GROUPS_PER_FRAME)
	for index in range(work_index,finish):
		if not groups.has(work[index]):continue
		var group:Dictionary=groups[work[index]]
		var distance:=INF
		for user in group.users:
			var node=user.node.get_ref()
			if node==null or not node.is_visible_in_tree():continue
			var bounds:AABB=user.bounds;distance=minf(distance,work_eye.distance_to(work_eye.clamp(bounds.position,bounds.end)))
		if is_finite(distance):group.material.render_priority=clampi(-110+floori(distance/4.0),-110,100)
	work_index=finish;maximum_update_us=maxi(maximum_update_us,Time.get_ticks_usec()-started)
	if work_index>=work.size():work.clear();last_eye=work_eye;next_tick=now+120;updates+=1

func clear():
	for group in groups.values():group.material.render_priority=group.original
	groups.clear();cells.clear();work.clear();work_index=0;dirty=true;last_eye=Vector3.INF

func diagnostics()->Dictionary:return {"registered_cells":cells.size(),"material_groups":groups.size(),"updates":updates,"groups_per_frame":GROUPS_PER_FRAME,"maximum_update_us":maximum_update_us,"geometry_and_shaders":"unchanged","scope":"opaque near-scene submission order only; no alpha or terrain changes"}
