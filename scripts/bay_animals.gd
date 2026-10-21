extends Node3D
## Local companions, real pet/follow/guide states and instanced flying populations.
var m
var animals:Array=[]
var batches:Array=[]
var clock:=0.0
var tick:=0.0
var petted:=0

func setup(target):
	m=target
	spawn("cat",Vector2(-118.3,253.3),1.12)
	spawn("cat",Vector2(-110,205.5));spawn("cat",Vector2(-244,-234));spawn("cat",Vector2(30,110))
	for i in 7:
		var x:float=-210+i*72
		spawn("gull",Vector2(x,m.world.layout.shore_z(x)-4),.8)
	for i in 12:spawn("butterfly",Vector2(-230+i%4*9,-194-i/4*6))
	var west:Array=[];var east:Array=[];var tea:Array=[]
	for road in m.world.layout.config.roads:
		if road.id=="west_mountain":west=road.points
		if road.id=="east_mountain":east=road.points
		if road.id=="tea_access":tea=road.points
	for route in [west.slice(2),west.slice(5),east.slice(2),east.slice(6),tea]:
		var first:Array=route[0];spawn("squirrel",Vector2(first[0],first[2]))
		animals.back().guide=route.duplicate(true);animals.back().guide_index=1
	for p in [Vector2(-239,-188),Vector2(-218,-185)]:spawn("rabbit",p)
	instance_species("gull");instance_species("butterfly")

func block(parent:Node3D,p:Vector3,size:Vector3,tone:String)->MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(tone);mat.roughness=.9;n.material_override=mat
	parent.add_child(n);n.position=p;return n

func spawn(kind:String,site:Vector2,up:float=.03):
	var model:=Node3D.new();add_child(model)
	var tone:String="bf945e" if animals.size()%2==0 else "d9c9ad";var limbs:Array=[];var tail:Node3D
	if kind in ["cat","squirrel","rabbit"]:
		if kind=="rabbit":tone="f3eadc"
		block(model,Vector3(0,.33,0),Vector3(.34,.36,.64) if kind=="cat" else Vector3(.27,.29,.42),tone)
		block(model,Vector3(0,.62,-.31),Vector3(.34,.32,.30) if kind=="cat" else Vector3(.25,.25,.22),tone)
		for x in [-.12,.12]:
			var ear:=block(model,Vector3(x,.83 if kind!="rabbit" else .97,-.30),Vector3(.13,.17,.13) if kind!="rabbit" else Vector3(.09,.45,.11),tone)
			if kind=="rabbit":block(ear,Vector3(0,0,-.057),Vector3(.045,.29,.015),"cfb0b0")
			block(model,Vector3(x*.75,.65,-.475),Vector3(.045,.06,.03),"3b4940")
			for z in [-.22,.22]:limbs.append(block(model,Vector3(x,.16,z),Vector3(.09,.26,.11),tone))
		tail=block(model,Vector3(0,.48,.47),Vector3(.09,.25,.28) if kind=="cat" else Vector3(.22,.55,.28) if kind=="squirrel" else Vector3(.16,.15,.15),tone);tail.rotation.x=.5
		if kind=="cat" and animals.size()%2==1:
			block(model,Vector3(.175,.4,-.05),Vector3(.025,.18,.24),"725b45");block(model,Vector3(-.175,.4,.13),Vector3(.025,.21,.19),"af7f48")
		elif kind=="cat":
			for z in [-.20,0,.2]:block(model,Vector3(0,.52,z),Vector3(.36,.02,.045),"987342")
	elif kind=="gull":
		block(model,Vector3.ZERO,Vector3(.20,.18,.5),"dddcc9")
		block(model,Vector3(0,.12,-.28),Vector3(.16,.18,.17),"f0ebd7");block(model,Vector3(0,.10,-.42),Vector3(.06,.06,.16),"bfa36a")
		for side in [-1,1]:
			var pivot:=Node3D.new();model.add_child(pivot);pivot.position.x=side*.1;limbs.append(pivot)
			block(pivot,Vector3(side*.35,0,0),Vector3(.7,.065,.25),"b8c2b5")
	else:
		block(model,Vector3.ZERO,Vector3(.04,.13,.04),"5e6950")
		for side in [-1,1]:
			var pivot:=Node3D.new();model.add_child(pivot);limbs.append(pivot)
			block(pivot,Vector3(side*.11,0,0),Vector3(.21,.025,.22),["d3adbf","d8c590","a7bbc0"][animals.size()%3])
	var home:Vector3=m.world.surface(site.x,site.y,up);model.position=home
	animals.append({"node":model,"kind":kind,"home":home,"limbs":limbs,"tail":tail,"phase":animals.size()*1.7,"pet_until":0.0,"follow_until":0.0,"follow_distance":0.0,"last_sound":-20.0,"flight_until":0.0,"guide":[],"guide_index":0,"guide_started":false,"guide_distance":0.0})

func instance_species(kind:String):
	var population:Array=animals.filter(func(a):return a.kind==kind)
	if population.is_empty():return
	var components:Array=population[0].node.find_children("*","MeshInstance3D",true,false)
	for i in components.size():
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=components[i].mesh;mm.instance_count=population.size()
		var node:=MultiMeshInstance3D.new();node.name=kind+"_batch_"+str(i);node.multimesh=mm;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.9;node.material_override=mat;add_child(node)
		var sources:Array=[]
		for a in population:
			var pieces:Array=a.node.find_children("*","MeshInstance3D",true,false);pieces[i].visible=false;sources.append(pieces[i])
		batches.append({"node":node,"sources":sources,"animals":population})

func nearest_cat()->Dictionary:return nearest_pet("cat")
func nearest_pet(kind:String)->Dictionary:
	var result:Dictionary={};var distance:float=2.5
	for a in animals:
		if a.kind!=kind or not a.node.visible:continue
		var d:float=m.player.position.distance_to(a.node.position)
		if d<distance:distance=d;result=a
	return result

func pet()->bool:
	var cat:Dictionary=nearest_cat()
	if cat.is_empty():cat=nearest_pet("rabbit")
	if cat.is_empty():return false
	cat.pet_until=clock+2.6;cat.follow_until=clock+20.0 if cat.kind=="cat" else 0.0;cat.follow_distance=0.0;petted+=1
	m.player.gentle_pet(cat.node.position,2.4)
	if cat.kind=="cat":m.bay.sound("cat",true,cat.node.position)
	m.notify("蹲下轻抚。猫咪会陪你慢走一小段，再回到原处。" if cat.kind=="cat" else "轻轻观察白兔。它抖了抖耳朵。")
	m.state.activities["cat_pet" if cat.kind=="cat" else "rabbit_pet"]=true
	return true

func ring(at:Vector3):
	for a in animals:
		if a.kind=="gull" and a.node.position.distance_to(at)<18:a.flight_until=clock+7

func reset():
	for a in animals:
		a.node.position=a.home;a.node.rotation=Vector3.ZERO;a.pet_until=0.0;a.follow_until=0.0;a.follow_distance=0.0;a.guide_index=1;a.guide_started=false

func walk_animal(a:Dictionary,target:Vector3,dt:float,speed:float):
	var model:Node3D=a.node;var before:Vector3=model.position;var delta:=Vector2(target.x-before.x,target.z-before.z)
	if delta.length()>.08:
		var step:Vector2=delta.normalized()*minf(speed*dt,delta.length());var next:Vector3=m.world.surface(before.x+step.x,before.z+step.y,.03)
		if a.kind in ["cat","squirrel","rabbit"]:
			var cap:=CapsuleShape3D.new();cap.radius=.17;cap.height=.52
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=cap;query.exclude=[m.player.get_rid()];query.collision_mask=1
			query.transform=Transform3D(Basis.IDENTITY,next+Vector3(0,.33,0))
			if not m.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return
		if m.world.layout.shallow_or_dry(next) and m.world.region_ready(next):
			model.position=next;model.rotation.y=atan2(-step.x,-step.y)
			if a.kind=="cat":a.follow_distance+=before.distance_to(next)
			if a.kind=="squirrel":a.guide_distance+=before.distance_to(next)
	if delta.length()<.2:model.position.y=move_toward(model.position.y,target.y,dt*1.7)
	for i in a.limbs.size():a.limbs[i].rotation.x=sin(clock*7+i*PI)*.3 if before.distance_to(model.position)>.01 else 0
	if a.tail!=null:a.tail.rotation.y=sin(clock*2.4)*.18

func _process(delta:float):
	if m==null:return
	clock+=delta;tick+=delta
	if tick<.06:return
	var dt:float=tick;tick=0;var rain:bool=m.environment_controls!=null and m.environment_controls.weather==2
	for a in animals:
		var model:Node3D=a.node;var home:Vector3=a.home
		model.visible=m.active_game and Vector2(m.player.position.x-home.x,m.player.position.z-home.z).length()<125 and not (rain and a.kind in ["gull","butterfly"])
		if not model.visible:continue
		var t:float=clock+a.phase
		if a.kind=="gull":
			if model.position.distance_to(m.player.position)<7:a.flight_until=clock+6
			var flying:bool=clock<a.flight_until;var wanted:Vector3=home
			if flying:wanted=home+Vector3(sin(t*.42)*10,5+sin(t)*.4,cos(t*.42)*8)
			model.position=model.position.move_toward(wanted,dt*8);model.rotation.y=-t*.42 if flying else 0
			for i in a.limbs.size():a.limbs[i].rotation.z=sin(t*6)*.36*(-1 if i==0 else 1) if flying else 0
			if flying and clock-a.last_sound>9:a.last_sound=clock;m.bay.sound("gull",true,model.position)
		elif a.kind=="butterfly":
			model.visible=not rain and int(m.state.time)<2;model.position=m.world.surface(home.x+sin(t*.7)*2.2,home.z+cos(t*.5)*1.8,1.2+sin(t*2)*.35)
			for i in a.limbs.size():a.limbs[i].rotation.z=sin(t*15)*.8*(-1 if i==0 else 1)
		elif a.kind=="squirrel":
			var guide:Array=a.guide;var proximity:float=model.position.distance_to(m.player.position)
			if proximity<8:a.guide_started=true
			if a.guide_started and a.guide_index<guide.size() and proximity<10 and not rain:
				var wanted:Vector3=m.world.layout.vector(guide[a.guide_index]);walk_animal(a,wanted,dt,2.3);model.position.y+=absf(sin(t*6))*.10
				if Vector2(model.position.x-wanted.x,model.position.z-wanted.z).length()<.8:a.guide_index+=1
			else:
				for leg in a.limbs:leg.rotation.x=0
				if proximity<12:model.rotation.y=atan2(model.position.x-m.player.position.x,model.position.z-m.player.position.z)
		elif a.kind=="cat":
			if clock<a.pet_until:
				model.rotation.z=sin((clock-a.pet_until+2.6)/2.6*PI)*.65
				if a.tail!=null:a.tail.rotation.y=sin(t*3)*.3
			else:
				model.rotation.z=0
				if clock<float(a.get("feed_until",0)):walk_animal(a,a.feed_target,dt,2.4)
				elif clock<a.follow_until and a.follow_distance<15 and m.bay.vehicles.mounted.is_empty() and m.bay.boats.kind.is_empty() and not rain:
					var desired:Vector3=m.player.position+Basis(Vector3.UP,m.player.yaw)*Vector3(1.1,0,1.4);walk_animal(a,desired,dt,2.5)
				else:walk_animal(a,home,dt,1.8)
		else:
			var q:Vector3=home+Vector3(sin(t*.2)*.6,0,cos(t*.2)*.5);walk_animal(a,q,dt,1.1);model.position.y+=absf(sin(t*4))*.08
	for batch in batches:
		var mm:MultiMesh=batch.node.multimesh
		for i in batch.sources.size():
			var part:MeshInstance3D=batch.sources[i];var a:Dictionary=batch.animals[i];var transform:Transform3D=part.global_transform
			if not a.node.visible:transform.basis=Basis.IDENTITY.scaled(Vector3.ZERO)
			mm.set_instance_transform(i,transform);mm.set_instance_color(i,part.material_override.albedo_color)
