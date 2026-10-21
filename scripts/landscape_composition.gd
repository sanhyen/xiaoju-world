extends RefCounted
## Side gardens define rooms beside the existing routes; scree belongs at actual cliff toes.
var w
var b
var ecology
var groves
var courts:Array=[]
var toes:Array=[]
var added_colliders:=0

func _init(target):
	w=target;b=w.b
	ecology=preload("res://scripts/ecology_detail.gd").new(w)
	groves=preload("res://scripts/woodland_groves.gd").new(w)

func supported(point:Vector2,radius:float,tolerance:float=0.18)->bool:
	var y:float=w.height_at(point.x,point.y)
	for delta in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		if absf(w.height_at(point.x+delta.x*radius,point.y+delta.y*radius)-y)>tolerance:return false
	return true

func build():
	var before:int=b.collision_count
	for item in w.spec.buildings:
		if item.type=="home":continue
		court(item)
	# Search within authored hollows, not across every slope or along a constant elevation.
	for center in [Vector2(-300,-242),Vector2(-201,-263),Vector2(-153,-326),Vector2(-49,-359),Vector2(102,-321),Vector2(224,-298)]:
		var count:=0
		for i in 45:
			if count>=4:break
			var point:Vector2=center+Vector2((i%9-4)*3.4,(i/9-2)*4.0)
			if not ecology.clear(point,3.4) or not supported(point,1.8,0.3):continue
			var y:float=w.height_at(point.x,point.y)
			var rise:=0.0
			for offset in [Vector2(0,-5),Vector2(-5,0),Vector2(5,0)]:rise=maxf(rise,w.height_at(point.x+offset.x,point.y+offset.y)-y)
			if rise<2.4 or rise>11.0:continue
			var close:=false
			for previous in toes:
				if point.distance_to(previous)<7:close=true;break
			if close:continue
			talus(point,i);toes.append(point);count+=1
	added_colliders=b.collision_count-before
	w.set_meta("composition_095",{"courts":courts,"cliff_toes":toes,"colliders_added":added_colliders,"route_guard":"existing paths, all entrances, stamps, interactions and terrace paving","terrain":"six broad crowns and drainage hollows outside protected routes"})

func court(item:Dictionary):
	var accepted:=0;var trees:=0
	var green:bool=item.type in ["florist","cafe","visitor","souvenir"]
	var stone:String="b1b6a8" if green else "929e9b"
	for sign in [-1,1]:
		# Forecourts and entrance axes stay open. Three separated strips frame a side lawn.
		var center:=Vector2(item.x+sign*(item.w/2+8.4),item.z+item.d*0.18)
		if absf(center.x)<32:continue
		for segment in 3:
			var point:Vector2=center+Vector2(0,(segment-1)*3.9)
			if not ecology.clear(point,2.2) or not supported(point,1.7):continue
			if not groves.space_available(point,1.6):continue
			var base:Vector3=w.surface(point.x,point.y)
			# Low individual coping stones and an earth bed; the clear lawn remains unpaved.
			for tile in 5:
				b.box(base+Vector3(sign*1.03,0.21,(tile-2)*0.59),Vector3(0.40,0.42,0.56),stone,false,0,"stone")
			b.collision(base+Vector3(sign*1.03,0.21,0),Vector3(0.4,0.42,2.92))
			for plant in 4:
				var root:Vector3=base+Vector3(sign*0.42,0,(plant-1.5)*0.68)
				var height:float=0.42+0.18*posmod(plant+segment,3)
				b.box(root+Vector3(0,height/2,0),Vector3(0.61,height,0.59),"506b5e" if green else "52676b",false,0,"leaf")
				b.box(root+Vector3(-sign*0.10,height+0.06,0.03),Vector3(0.43,0.16,0.40),"80936f",false,0,"leaf")
				ecology.garden.herb(root+Vector3(-sign*0.63,0,0.11),0.24+plant%2*0.12,green)
			groves.occupy(point,2.0);accepted+=1
		# One taller canopy at the rear, offset from the garden openings and old trees.
		var tree_point:Vector2=center+Vector2(sign*2.8,-9.0)
		if groves.clear(tree_point,2.8):
			groves.art.tree(b,w.surface(tree_point.x,tree_point.y),0 if green else 6,0.88)
			groves.occupy(tree_point,2.8);trees+=1
	courts.append({"venue":item.id,"planted_strips":accepted,"canopies":trees,"entrance_axis":"retained"})

func talus(point:Vector2,variant:int):
	# Buried basal blocks support smaller fractured pieces; sizes taper away from the cliff.
	for i in 3:
		var q:Vector2=point+Vector2((i-1)*1.05,0.55*i)
		var size:float=1.55-i*0.34
		var base:Vector3=w.surface(q.x,q.y)
		b.box(base+Vector3(0,size*0.31-0.10,0),Vector3(size*1.08,size*0.62,size*0.9),"828d89",true,0,"stone")
		b.box(base+Vector3(-size*0.13,size*0.65-0.10,-size*0.09),Vector3(size*0.76,size*0.20,size*0.68),"a0a599",false,0,"stone")
		if i!=1:b.box(base+Vector3(-size*0.19,size*0.765-0.10,size*0.12),Vector3(size*0.42,0.035,size*0.29),"73816a",false,0,"leaf")
		for j in 2:
			var herb_point:Vector2=q+Vector2(0.82,0.22+j*0.48)
			if ecology.clear(herb_point,0.35):ecology.garden.herb(w.surface(herb_point.x,herb_point.y),0.27)
