extends RefCounted
## The visitor desk uses existing map, PB, collection and settings flows.
var main

func show(target):
	main=target;main.visitor_return=Callable();main.open_modal("山海游客中心 · 旅行服务",1180)
	# Keep the service origin across PB pages and nested details; explicit photo returns take precedence.
	main.visitor_return=func():show(main)
	main.label(main.modal_box,"音乐与舞台、光影收藏、海岸与山林，沿八区环线相连，东河谷新增崖湾嵌岩聚落。\n这里是非官方同人乐园，建筑与分区由本项目原创。",23)
	entry("查看地图与已探索区域",main.show_map)
	entry("打开旅行纪念册",func():main.show_pb(int(main.state.pb_page)))
	entry("查看我的收藏",main.show_collection)
	entry("操作说明",show_controls)
	entry("素材来源与关于",main.show_sources)
	entry("设置",main.show_settings)
	main.label(main.modal_box,"在地图上选择目的地后，左上角会显示方向与距离。各开放地点都可立即前往。",20)

func entry(title:String,action:Callable):
	main.button(main.modal_box,title,action)

func show_controls():
	main.open_modal("操作说明",1180)
	main.label(main.modal_box,"W / A / S / D  移动　　Shift  快走　　Space  二段跳 / 起身；骑乘时刹车\n鼠标  环顾　　滚轮  调整跟随镜头距离\nE  查看资料 / 选船　F  操作 / 上下车船　X  姿态 / 落座 / 按铃　　M  地图与快速旅行　N  收起小地图　Alt  点击小地图　Tab  收藏\nP  拍照模式　　F12  保存照片　　F5  保存旅行\nEsc  返回当前页面或打开暂停菜单",25)
	main.label(main.modal_box,"PB 影像可点击放大，滚轮缩放、左键拖动，双击或点击“完整图片”复位。\n声音体验默认不启用麦克风，不录音；关闭媒体窗口后停止播放。",23)
