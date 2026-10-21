extends RefCounted
## Visible modular masonry with a single continuous structural collider per panel.
static func panel(b,center:Vector3,size:Vector3,tone:String,module:float=0.6):
	b.collision(center,size)
	var along_x:bool=size.x>=size.z
	var span:float=size.x if along_x else size.z
	var rows:int=maxi(1,ceili(size.y/module))
	var course:float=size.y/rows
	var base:=Color(tone)
	for row in rows:
		var left:float=-span/2
		var column:=0
		while left<span/2-0.001:
			var width:float=minf(module*(0.5 if row%2==1 and column==0 else 1.0),span/2-left)
			var relief:float=0.014+0.009*sin(row*2.1+column*1.7)
			var block:=Vector3(width-0.012,course-0.012,size.z+relief) if along_x else Vector3(size.x+relief,course-0.012,width-0.012)
			var offset:=Vector3(left+width/2,-size.y/2+(row+0.5)*course,0) if along_x else Vector3(0,-size.y/2+(row+0.5)*course,left+width/2)
			var color:Color=base.darkened(0.035*(0.5+0.5*sin(column*1.3+row*0.7)))
			b.box(center+offset,block,color.to_html(false),false,0,"stone")
			left+=width;column+=1

static func plinth(house):
	# Ground courses and corner quoins are fitted to each retained footprint.
	# No new doorway, glazing or interior obstruction is introduced.
	var b=house.b
	var count:int=b.box_count
	for side in [-1,1]:
		for row in 2:
			var divisions:int=ceili(house.d/0.65)
			for i in divisions:
				var length:float=house.d/divisions
				b.box(house.origin+Vector3(side*(house.w/2+0.20),0.22+row*0.42,-house.d/2+(i+0.5)*length),Vector3(0.14,0.405,length-0.025),["8e978d","a1a798","929e98"][posmod(i+row,3)],false,0,"stone")
		for zside in [-1,1]:
			for row in maxi(1,floori(house.h/0.55)):
				b.box(house.origin+Vector3(side*(house.w/2+0.21),0.28+row*0.55,zside*(house.d/2-0.25)),Vector3(0.19,0.52,0.48 if row%2 else 0.70),"b7bbad",false,0,"stone")
	var stats:Dictionary=house.world.get_meta("masonry_093",{})
	stats[house.item.id]={"modules":b.box_count-count,"module_m":0.65,"scope":"base courses and corner quoins"}
	house.world.set_meta("masonry_093",stats)
