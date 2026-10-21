extends RefCounted
## Venue-specific fittings on retained counters, walls and equipment; no new collision or media.
var house
var b
var o:Vector3
var details:Array=[]

func box(p:Vector3,size:Vector3,tone:String,kind:String="wood",angle:float=0.0):
	b.box(o+p,size,tone,false,angle,kind)
func beam(a:Vector3,c:Vector3,width:float,tone:String):b.beam(o+a,o+c,width,tone)
func shape(p:Vector3,size:Vector3,tone:String):b.shape(o+p,size,tone,"round")

func build(target):
	house=target;b=house.b;o=house.origin
	var before:int=b.box_count
	var collisions:int=b.collision_count
	match house.item.type:
		"station":station()
		"cafe":cafe()
		"records":records()
		"florist":florist()
		"gallery":gallery()
		"cinema":cinema()
		"pb":photobook()
		"dance":dance()
		"studio":studio()
		"theater":theater()
		"souvenir":souvenir()
		"home":home()
		"visitor":visitor()
	retained_venue_seat()
	var summary:Dictionary=house.world.get_meta("venue_finishings_084",{})
	summary[house.item.id]={"type":house.item.type,"modules":b.box_count-before,"colliders_added":b.collision_count-collisions,"details":details,"scope":"Original venue footprint, furnishings, passages, photos and all actions retained"}
	house.world.set_meta("venue_finishings_084",summary)

func suitcase(p:Vector3,tone:String):
	box(p+Vector3(0,0.23,0),Vector3(0.66,0.46,0.43),tone)
	for side in [-1,1]:
		box(p+Vector3(side*0.25,0.23,0.225),Vector3(0.035,0.43,0.025),"d0bc99")
		box(p+Vector3(side*0.15,0.50,0),Vector3(0.035,0.09,0.035),"535e53")
	box(p+Vector3(0,0.54,0),Vector3(0.30,0.035,0.035),"535e53")

func station():
	# Existing luggage counter has a top at two metres; travel props rest directly on it.
	suitcase(Vector3(-8.75,2.0,3),"9ba49a")
	suitcase(Vector3(-7.75,2.0,3),"b2a0aa")
	for x in [-8.7,-7.7]:box(Vector3(x,0.74,3.515),Vector3(0.65,0.28,0.018),"d1c4a8","fabric")
	details=["two supported luggage forms","counter front label holders"]

func cafe():
	# Add the working-face detail to the existing espresso machine, not a second machine.
	box(Vector3(-5,1.235,-2.57),Vector3(1.18,0.04,0.32),"536966","stone")
	for x in [-5.38,-5.19,-5,-4.81,-4.62]:box(Vector3(x,1.262,-2.57),Vector3(0.045,0.012,0.28),"a8b5a6","stone")
	for x in [-5.30,-4.70]:
		beam(Vector3(x,1.51,-2.68),Vector3(x,1.41,-2.60),0.045,"b6c0b2")
		shape(Vector3(x,1.26,-2.51),Vector3(0.15,0.035,0.15),"e5ddc5")
	for x in [-5.42,-5.14,-4.86]:box(Vector3(x,1.72,-2.682),Vector3(0.065,0.065,0.032),"d1bea1","stone")
	details=["espresso nozzles","slotted drip tray","supported cup saucers and controls"]

func headphones(p:Vector3):
	shape(p+Vector3(0,0.014,0),Vector3(0.24,0.028,0.24),"3e5653")
	box(p+Vector3(0,0.20,0),Vector3(0.035,0.40,0.035),"738577","stone")
	beam(p+Vector3(-0.16,0.32,0),p+Vector3(-0.11,0.48,0),0.04,"465d57")
	beam(p+Vector3(-0.11,0.48,0),p+Vector3(0.11,0.48,0),0.04,"465d57")
	beam(p+Vector3(0.11,0.48,0),p+Vector3(0.16,0.32,0),0.04,"465d57")
	for side in [-1,1]:box(p+Vector3(side*0.16,0.30,0),Vector3(0.085,0.16,0.13),"65736b","fabric")

func records():
	headphones(Vector3(0.65,1.2,-4.01))
	beam(Vector3(0.81,1.43,-4.01),Vector3(0.85,1.25,-3.70),0.018,"4e655c")
	beam(Vector3(0.85,1.25,-3.70),Vector3(0.36,1.24,-3.65),0.018,"4e655c")
	details=["headphones and weighted stand on listening console","restrained audio cable"]

func florist():
	box(Vector3(-3.65,1.025,-2.04),Vector3(0.85,0.018,0.56),"c4ac85","fabric")
	box(Vector3(-3.65,1.041,-2.04),Vector3(0.72,0.012,0.49),"d9c99f","fabric",0.06)
	for i in 3:shape(Vector3(-2.72+i*0.22,1.08,-2.38),Vector3(0.15,0.14,0.15),["a5b09a","c8b49a","b5a4b4"][i])
	beam(Vector3(-3.18,1.06,-1.94),Vector3(-2.88,1.06,-1.74),0.024,"6f7a6c")
	beam(Vector3(-3.12,1.06,-1.73),Vector3(-2.86,1.06,-1.98),0.024,"6f7a6c")
	shape(Vector3(-3.20,1.057,-1.99),Vector3(0.10,0.022,0.10),"687a64")
	shape(Vector3(-3.15,1.057,-1.69),Vector3(0.10,0.022,0.10),"687a64")
	details=["wrapping paper on original worktable","three ribbon spools","flower scissors"]

func gallery():
	# Quiet stone-pier detailing leaves every real exhibition image uncovered.
	for side in [-1,1]:
		for y in [0.70,1.35,2.0]:box(Vector3(side*9.9,y,8.765),Vector3(0.95,0.022,0.03),"b8b5a0","stone")
		box(Vector3(side*9.9,2.80,8.765),Vector3(0.76,0.32,0.035),"bcae88","stone")
	for side in [-1,1]:box(Vector3(8+side*0.9,1.115,5.5),Vector3(0.56,0.03,0.43),"d5c5a3","fabric")
	details=["gallery entrance pier joints","small guide holders on retained display case"]

func cinema():
	for row in 6:
		var level:float=(5-row)*0.24
		for side in [-1,1]:
			box(Vector3(side*8.48,level+0.11,3-row*1.65),Vector3(0.025,0.18,0.43),"cab48a","stone")
			b.glow_box(o+Vector3(side*8.495,level+0.14,3-row*1.65),Vector3(0.012,0.028,0.26))
	for side in [-1,1]:box(Vector3(side*12,2.92,5.50),Vector3(1.0,0.07,0.07),"9cae96","stone")
	details=["six actual raised seating row edges","low aisle guide geometry","exit lintel edge"]

func photobook():
	# Reader's spread is accompanied by bookmarks and supported pencil/reading details.
	box(Vector3(1.1,1.025,0.02),Vector3(0.62,0.02,0.40),"d2c4a6","fabric")
	for i in 3:box(Vector3(1.02+i*0.08,1.041,0.02),Vector3(0.036,0.014,0.34),["829d92","b49baf","c3ad7b"][i],"fabric")
	beam(Vector3(1.50,1.052,-0.22),Vector3(1.83,1.052,0.06),0.024,"847859")
	for side in [-1,1]:box(Vector3(side*7,0.565,4),Vector3(1.8,0.03,0.48),"b4bca5","fabric")
	details=["bookmarks and pencil on original reading table","bench seat pads"]

func dance():
	for x in [-3.5,0,3.5]:
		box(Vector3(x,0.021,2.35),Vector3(0.34,0.013,0.035),"c7b599","fabric")
		box(Vector3(x,0.022,2.35),Vector3(0.035,0.013,0.34),"c7b599","fabric")
	for x in [-7,-5,-3]:
		box(Vector3(x,1.77,6.183),Vector3(0.7,0.26,0.02),"bcc4ad","stone")
		for i in 4:box(Vector3(x-0.22+i*0.15,2.13,6.18),Vector3(0.055,0.13,0.015),"718a80","stone")
	details=["restrained rehearsal floor positions","locker ventilation and label holders"]

func studio():
	box(Vector3(-4,1.192,-1.24),Vector3(1.7,0.025,0.21),"283f44","stone")
	for i in 7:
		box(Vector3(-4.72+i*0.24,1.212,-1.24),Vector3(0.16,0.018,0.16),"829e8d","stone")
		for j in 3:box(Vector3(-4.76+i*0.24+j*0.04,1.224,-1.24),Vector3(0.015,0.009,0.12),"bdd0aa","stone")
	headphones(Vector3(-4.95,1.01,-0.76))
	details=["printed metering strip and mixer detail","supported monitoring headphones; no fake live meters"]

func theater():
	for x in [-10,-5,0,5,10]:beam(Vector3(x,7.96,-10),Vector3(x,7.82,-9.55),0.023,"8a9a8d")
	for side in [-1,1]:
		for i in 6:box(Vector3(side*(12.2+i*0.26),4.0,-8.465),Vector3(0.085,7.6,0.055),"857386","fabric")
		box(Vector3(side*11.3,1.214,-7.7),Vector3(0.035,0.025,7.4),"c5b393","fabric")
	box(Vector3(12,1.624,8),Vector3(2.1,0.025,0.95),"3a5154","stone")
	details=["lighting safety ties on existing stage truss","curtain folds","stage edge markings and existing console face"]

func souvenir():
	for i in 3:
		box(Vector3(2.4+i*0.55,1.226,0.05),Vector3(0.44,0.034,0.62),["9aada5","b9a0b0","c4b18b"][i],"fabric")
		box(Vector3(2.4+i*0.55,1.25,0.05),Vector3(0.36,0.015,0.51),"e1d1ad","fabric")
	shape(Vector3(3.75,1.28,-0.28),Vector3(0.13,0.16,0.13),"677d6b")
	details=["project-original paper goods on original counter","stamp-holder prop; existing real digital collection action retained"]

func home():
	# The retained writing desk has a top at0.875m; the lamp and books keep their positions.
	box(Vector3(5.12,0.887,-3.42),Vector3(0.44,0.032,0.26),"829488","fabric")
	for z in [-3.46,-3.38]:beam(Vector3(4.97,0.92,z),Vector3(5.25,0.92,z),0.023,"a28e6d")
	details=["supported pencil tray at the retained writing desk","retained collection and saved decoration slots"]

func visitor():
	box(Vector3(-3,1.223,-1.4),Vector3(0.85,0.045,0.52),"a0b5a7","fabric")
	box(Vector3(-3,1.255,-1.4),Vector3(0.76,0.025,0.46),"ddd1b0","fabric")
	for i in 3:box(Vector3(-3.29+i*0.23,1.275,-1.4),Vector3(0.18,0.009,0.27),"bcc6a9","fabric")
	box(Vector3(-1.75,1.223,-1.40),Vector3(0.54,0.04,0.39),"546e65","stone")
	for x in [-1.9,-1.65]:box(Vector3(x,1.26,-1.40),Vector3(0.035,0.055,0.035),"c8b393","stone")
	details=["supported service leaflets and desk fittings","existing real map/service interface remains primary"]

func retained_venue_seat():
	# These anchors are existing bench bases; do not add a second bench/collider.
	var seats:Dictionary={
		"B05":{"anchor":Vector3(-5,0,4.5),"approach":Vector3(-5,0,5.75),"yaw":PI,"title":"画廊长椅 · 坐下看展"},
		"B07":{"anchor":Vector3(-7,0,4),"approach":Vector3(-7,0,5.25),"yaw":PI,"title":"纪念馆长椅 · 坐下歇一会儿"},
		"B08":{"anchor":Vector3(5,0,5.8),"approach":Vector3(5,0,7.05),"yaw":PI,"title":"练习馆长椅 · 排练后休息"},
		"B09":{"anchor":Vector3(4,0,3),"approach":Vector3(4,0,4.25),"yaw":PI,"title":"声音室长椅 · 坐下聆听"},
		"B13":{"anchor":Vector3(4,0,1),"approach":Vector3(5.25,0,1),"yaw":-PI/2,"title":"游客中心 · 坐下看街景"}
	}
	if not seats.has(house.item.id):return
	var record:Dictionary=seats[house.item.id]
	house.action("rest",record.approach,record.title,"sit",{"seat":o+record.anchor,"yaw":record.yaw})
	var all_seats:Dictionary=house.world.get_meta("venue_rest_086",{})
	all_seats[house.item.id]={"id":house.item.id+"_rest","anchor":o+record.anchor,"approach":o+record.approach,"original_bench_retained":true,"colliders_added":0}
	house.world.set_meta("venue_rest_086",all_seats)
