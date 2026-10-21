extends RefCounted
## N07: layered channel geology and a single opaque animated fall, sharing the real river.
var w
var b
var rock_blocks:=0

func _init(world):
	w=world;b=w.b

func rock(position:Vector3,size:Vector3,tone:String,solid:bool=true):
	b.box(position,size,tone,solid,0,"stone");rock_blocks+=1

func build():
	var x:float=307+18*sin(-332*0.014)
	var top:float=w.land_height(x,-332)-1.5
	# Each ledge has a full body embedded in the existing river banks. The channel stays open.
	for side in [-1,1]:
		for level in 8:
			var yy:float=top-20+level*2.5
			var offset:float=0.45*sin(level*1.7+side)
			var inner:float=5.4+offset
			var width:float=5.6+float(posmod(level+side,3))*0.8
			var face_z:float=-329.8+sin(level*1.3+side)*0.75
			var center:=Vector3(x+side*(inner+width/2),yy+1.05,face_z-3.2)
			rock(center,Vector3(width,2.65,6.4),["687b7b","788783","84918a"][posmod(level+side,3)])
			# Recessed dark seams and narrow overhanging shelves clarify the wet rock strata.
			rock(center+Vector3(side*0.25,1.39,0.16),Vector3(width+0.5,0.22,6.7),"929d93",false)
			if level%2==0:
				b.box(center+Vector3(side*0.8,1.54,1.1),Vector3(width*0.57,0.10,2.5),"687e64",false,0,"leaf")
			# Outer buttresses step back towards each bank instead of repeating tall slanted prisms.
			var outer:=Vector3(x+side*(inner+width+2.0),yy+0.95,face_z-4.7)
			rock(outer,Vector3(4.4,2.5,7.2),["839087","9b9f94","77857d"][posmod(level,3)])
		# Fallen blocks at the foot form a loose apron; none intersect the viewing boardwalk.
		for i in 4:
			var p:=Vector3(x+side*(6.5+i*2.3),top-19.2+i*0.16,-325.8+i*0.55)
			rock(p,Vector3(2.7-i*0.22,1.8+i*0.2,2.1),"7d9089")
	# Four narrow connected ribbons make the lip and bottom irregular while remaining opaque.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strip in 4:
		var xa:float=x-5.0+strip*2.5;var xb:float=xa+2.5
		var front:float=-331.0+0.12*sin(strip*2.1)
		var bottom:float=top-20.0+0.16*sin(strip*1.8)
		var vertices:=[Vector3(xa,top,-332),Vector3(xb,top,-332),Vector3(xb,top-0.55,front),Vector3(xa,top-0.55,front),Vector3(xb,bottom,-330.5),Vector3(xa,bottom,-330.5)]
		var uv:=[Vector2(strip*0.25,0),Vector2((strip+1)*0.25,0),Vector2((strip+1)*0.25,0.025),Vector2(strip*0.25,0.025),Vector2((strip+1)*0.25,1),Vector2(strip*0.25,1)]
		for index in [0,1,2,0,2,3,3,2,4,3,4,5]:
			st.set_uv(uv[index]);st.add_vertex(vertices[index])
	st.generate_normals()
	var falling:=MeshInstance3D.new();falling.name="N07LayeredWaterfall";falling.mesh=st.commit()
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode cull_disabled;
void fragment(){
    float stream=pow(sin(UV.x*73.0+sin(UV.y*12.0-TIME*3.0)*0.30)*0.5+0.5,5.0);
    float wash=sin(UV.y*41.0-TIME*10.0)*0.5+0.5;
    float foam=smoothstep(0.80,1.0,UV.y)*0.18;
    ALBEDO=mix(vec3(0.31,0.53,0.53),vec3(0.72,0.82,0.77),stream*0.33+wash*0.06+foam);
    ROUGHNESS=0.52;
}
"""
	var material:=ShaderMaterial.new();material.shader=shader;falling.material_override=material
	falling.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;w.add_child(falling)
	for i in 13:
		var q:=Vector3(x-4.7+i*0.79,top-19.8,-329.9+sin(i*2.3)*0.6)
		b.box(q,Vector3(0.66+0.18*sin(i),0.12,0.55+0.25*cos(i)),"b8d0c4",false)
		if i%3==0:b.box(q+Vector3(0,0.08,0.7),Vector3(0.4,0.11,0.7),"ceddd1",false)
	w.set_meta("waterfall_v12",{"layered_blocks":rock_blocks,"fall_height_m":20,"opaque_water_meshes":1,"transparent_particles":0,"scope":"N07 river-connected geology; existing viewing paths and interaction retained"})
	build_side_view()

func build_side_view():
	# A short supported gallery leaves the main path at its existing northern endpoint.
	# It supplies the required side view without relocating the player or the old overlook.
	var start:Vector3=w.surface(287,-312,0.08)
	var end:=Vector3(303,start.y+2.0,-317)
	b.ramp(start,end,3.2,"b8a17d")
	var forward:Vector3=(end-start).normalized()
	var right:=Vector3(-forward.z,0,forward.x).normalized()
	for side in [-1,1]:
		var a:Vector3=start+right*side*1.54+Vector3(0,1.08,0)
		var c:Vector3=end+right*side*1.54+Vector3(0,1.08,0)
		b.beam(a,c,0.12,"817d65")
		for i in 5:
			var p:Vector3=start.lerp(end,i/4.0)+right*side*1.54
			var soil:float=w.height_at(p.x,p.z)-0.15
			b.box(Vector3(p.x,(soil+p.y)/2,p.z),Vector3(0.26,maxf(0.3,p.y-soil),0.26),"827861")
			b.box(p+Vector3(0,0.58,0),Vector3(0.13,1.15,0.13),"817d65")
		var center:Vector3=(start+end)/2+right*side*1.54+Vector3(0,0.57,0)
		# The guard collision follows the ramp's pitch as well as its yaw.
		var body:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new()
		shape.size=Vector3(0.15,1.2,start.distance_to(end));collider.shape=shape;body.add_child(collider);w.add_child(body)
		var axis:=Vector3.UP.cross(forward).normalized()
		body.transform=Transform3D(Basis(axis,forward.cross(axis).normalized(),forward),center);b.collision_count+=1
	b.box(end-Vector3(0,0.10,0),Vector3(3.7,0.2,4.2),"b8a17d",true)
	# Guard three outside edges, leaving the approach from the west open.
	for z in [-2.03,2.03]:
		b.box(end+Vector3(0,1.08,z),Vector3(3.7,0.12,0.12),"817d65")
		b.collision(end+Vector3(0,0.57,z),Vector3(3.7,1.2,0.14))
	b.box(end+Vector3(1.78,1.08,0),Vector3(0.12,0.12,4.2),"817d65")
	b.collision(end+Vector3(1.78,0.57,0),Vector3(0.14,1.2,4.2))
	for z in [-1.9,1.9]:
		var p:=end+Vector3(1.65,0,z);var soil:float=w.height_at(p.x,p.z)-0.2
		b.box(Vector3(p.x,(soil+p.y)/2,p.z),Vector3(0.32,maxf(0.3,p.y-soil),0.32),"827861")
		b.box(p+Vector3(0,0.58,0),Vector3(0.15,1.15,0.15),"817d65")
