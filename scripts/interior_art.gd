extends RefCounted
## Local additions for retained cinema, sound booth and visitor desk; no new collision footprints.
var b
var o:Vector3

func box(p:Vector3,s:Vector3,tone:String):b.box(o+p,s,tone)
func words(value:String,p:Vector3,size:float=0.0035,tone:String="e6dac0",angle:float=0.0):b.text3d(value,o+p,size,tone,angle)
func plaque(value:String,p:Vector3,width:float=2.0,size:float=0.0035):
	box(p,Vector3(width,0.28,0.06),"5b7169");words(value,p+Vector3(0,0,0.037),size)

func build(house):
	b=house.b;o=house.origin
	match house.item.type:
		"cinema":cinema()
		"studio":studio()
		"visitor":visitor()
		"gallery":gallery()
		"dance":dance()
		"theater":theater()

func cinema():
	# Opaque backing hides the reversed rear face of the retained entrance lettering.
	for side in [-1,1]:box(Vector3(side*11.4,3.1,6.225),Vector3(1.8,0.42,0.07),"435259")
	# Source catalogue board sits on the existing lobby partition, not in either side entrance.
	box(Vector3(0,1.58,6.28),Vector3(6.4,1.58,0.07),"879087")
	box(Vector3(0,1.58,6.325),Vector3(6.16,1.36,0.035),"e1d6b9")
	words("本地节目",Vector3(0,2.0,6.352),0.0048,"465e57")
	words("海风演示 01 · 原创几何短片",Vector3(0,1.58,6.354),0.0040,"4b635b")
	words("海风演示 04 · 原创几何短片",Vector3(0,1.22,6.354),0.0037,"4b635b")
	# These exact titles correspond to the B06 catalogue; details stay in its existing selector.
	words("按 E 选片 · 来源见节目册",Vector3(0,0.52,6.36),0.0035,"e3d4b5")
	# Original props distinguish the concession counter from the film-selection point.
	for x in [-10.5,-9.6,-8.7]:
		box(Vector3(x,1.76,9),Vector3(0.29,0.045,0.34),"e6d8b8")
		for i in 3:box(Vector3(x-0.08+i*0.08,1.81,9),Vector3(0.07,0.08,0.2),"d9c59d")
	plaque("门厅服务",Vector3(-9,1.14,9.63),2.1,0.0038)
	for x in [-6.8,6.8]:
		box(Vector3(x,1.63,6.25),Vector3(2.05,0.05,0.17),"b9a787")
		for i in 3:
			box(Vector3(x-0.57+i*0.57,1.94,6.30),Vector3(0.43,0.59,0.035),["9baaa4","b7a491","a6a0ac"][i])
			words("节目册",Vector3(x-0.57+i*0.57,1.96,6.327),0.0016,"4a615a")

func studio():
	# Existing glass is already transparent. Give the booth readable depth against its dark rear wall.
	for x in [-6.45,-4.6,-2.75]:
		box(Vector3(x,1.73,-5.35),Vector3(1.26,2.23,0.07),"a2ac9b")
		for i in 5:box(Vector3(x-0.46+i*0.23,1.73,-5.297),Vector3(0.085,2.08,0.03),"728478")
	box(Vector3(-4.65,0.03,-3.85),Vector3(3.4,0.03,1.9),"8c9985")
	box(Vector3(-4.65,0.81,-4.02),Vector3(0.055,1.62,0.055),"485e55")
	box(Vector3(-4.65,1.68,-4.02),Vector3(0.13,0.31,0.13),"344c47")
	b.beam(o+Vector3(-4.65,1.31,-4.02),o+Vector3(-4.65,1.63,-3.72),0.023,"657969")
	box(Vector3(-4.65,1.70,-3.72),Vector3(0.28,0.28,0.035),"5a7163")
	for i in 3:
		var a:float=i*TAU/3
		b.beam(o+Vector3(-4.65,0.22,-4.02),o+Vector3(-4.65+sin(a)*0.38,0.05,-4.02+cos(a)*0.38),0.035,"50665b")
	box(Vector3(-4.5,3.16,-3.8),Vector3(2.1,0.045,0.16),"e3d2a7")
	var lamp:=OmniLight3D.new();b.root.add_child(lamp);lamp.position=o+Vector3(-4.5,2.65,-3.65);lamp.light_color=Color("eee2b8");lamp.light_energy=0.34;lamp.omni_range=4;lamp.shadow_enabled=false
	# The original active microphone, listening action, no-recording default and east entrance stay intact.
	plaque("练声间",Vector3(-4.5,3.42,-2.00),1.8,0.0041)

func visitor():
	# Retained service counter with a modest map terminal, pen cup and folded guide trays.
	box(Vector3(-3.75,1.23,-1.50),Vector3(0.74,0.06,0.50),"60786b")
	box(Vector3(-3.75,1.48,-1.63),Vector3(0.08,0.48,0.10),"697c6c")
	box(Vector3(-3.75,1.75,-1.63),Vector3(0.92,0.60,0.075),"61776d")
	box(Vector3(-3.75,1.75,-1.578),Vector3(0.81,0.49,0.02),"ccceb0")
	words("山海导览",Vector3(-3.75,1.75,-1.563),0.0021,"4c685a")
	for x in [-2.62,-1.80]:
		box(Vector3(x,1.23,-1.48),Vector3(0.65,0.06,0.74),"c5b28e")
		box(Vector3(x,1.271,-1.48),Vector3(0.57,0.025,0.66),"e3d8b7")
		for i in 3:box(Vector3(x-0.18+i*0.18,1.29,-1.48),Vector3(0.10,0.012,0.49),["9fae94","91a69a","bcc4a4"][i])
	plaque("旅行服务 · 按 E",Vector3(-3,0.86,-0.72),2.5,0.0038)
	# Each original guide is visibly a folded booklet, independent of the interactive digital map.
	for i in 4:
		var x:float=-4.75+i*0.46
		box(Vector3(x,1.266,2.2),Vector3(0.32,0.015,0.48),"e4d8b8")
		box(Vector3(x-0.13,1.279,2.2),Vector3(0.026,0.014,0.43),"697f70")
		for row in 3:box(Vector3(x+0.015,1.28,2.04+row*0.12),Vector3(0.18,0.012,0.035),"98ab91")
	plaque("地图 · 收藏 · 操作说明",Vector3(-4,0.82,2.64),2.12,0.0028)
	# Two original flags carry a quiet information motif; no false official branding.
	for side in [-1,1]:
		var x:float=side*6+0.6
		box(Vector3(x,5.03,6.038),Vector3(0.12,0.60,0.022),"edf0d4")
		box(Vector3(x,5.48,6.038),Vector3(0.13,0.13,0.022),"edf0d4")

func gallery():
	# Slot numbers stay correct when the real works are reordered by the three presets.
	for row in [[5,-7.3,-0.29,0.0],[6,-3.7,-0.29,0.0],[7,-7.3,-0.71,PI],[8,-3.7,-0.71,PI],[9,3.7,2.01,0.0],[10,7.3,2.01,0.0],[11,3.7,1.59,PI],[12,7.3,1.59,PI]]:
		var facing:float=1.0 if row[3]==0.0 else -1.0
		var p:=Vector3(row[1],1.04,row[2]+facing*0.01)
		box(p,Vector3(1.5,0.24,0.03),"d4cfb8")
		words("%02d · 精选影像" % int(row[0]),p+Vector3(0,0,facing*0.021),0.0028,"506d65",row[3])

func dance():
	# Backings stop mirrored entrance text; the unobstructed central practice floor stays empty.
	box(Vector3(0,2.7,7.74),Vector3(1.6,0.45,0.08),"5d786c")
	words("出口",Vector3(0,2.7,7.685),0.006,"dbe1c3",PI)
	box(Vector3(-5,3.4,7.335),Vector3(4.3,0.50,0.045),"d8d1b9")

func theater():
	# Details occupy the retained console footprint and face its existing interaction point.
	box(Vector3(12,1.61,8),Vector3(2.40,0.025,1.08),"72847e")
	for i in 5:
		var x:float=11.1+i*0.38
		box(Vector3(x,1.684,8),Vector3(0.024,0.02,0.49),"415955")
		box(Vector3(x,1.710,7.88+(i%3)*0.12),Vector3(0.12,0.035,0.11),"cbbf9f")
		box(Vector3(x,1.645,7.59),Vector3(0.095,0.04,0.075),["c8b394","a99bbe","9fbbc0"][i%3])
	box(Vector3(12,1.05,7.365),Vector3(2.12,0.66,0.045),"637c73")
	words("舞台灯光 · 按 E 切换",Vector3(12,1.22,7.332),0.0034,"e5d9bc",PI)
	words("暖金   淡紫   蓝杏",Vector3(12,0.91,7.332),0.0030,"d2d9bd",PI)
