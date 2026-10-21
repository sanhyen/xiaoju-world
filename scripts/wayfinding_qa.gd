extends RefCounted
var main
var checks:Array=[]
func sample(_delta:float):pass
func check(name:String,ok:bool,detail:Dictionary={}):
	checks.append({"test":name,"passed":ok,"detail":detail});print("WAYFINDING_CHECK ",name," ",ok)
func run(target):
	main=target;main.store.directory="user://qa_isolated/"+main.qa_mode
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	main.menu.hide();main.hud.hide();main.watch_camera.fov=75;main.set_time(0)
	var counts:Dictionary=main.world.streamer.manifest.authored_counts
	var summary:Dictionary=counts.get("venue_wayfinding_089",{})
	check("thirteen_real_door_exit_faces",summary.size()==13)
	check("retained_scope_and_collision",main.world.spec.zones.size()==8 and counts.buildings==13 and counts.colliders==2853 and counts.interactions==87)
	check("two_theater_roof_joints_baked",counts.get("theater_roof_joints_089",{}).get("valleys",0)==2)
	var views:Array=[];var sampled_labels:=0;var mirrored_labels:=0
	for item in main.world.spec.buildings:
		var center:Vector3=main.world.surface(item.x,item.z,0.08)
		await main.world.prepare_region(center)
		var labels:Array=main.world.streamer.find_children("VenueExit_"+str(item.id),"Label3D",true,false)
		check(str(item.id)+"_exit_node_present",labels.size()==1)
		if labels.size()==1:
			check(str(item.id)+"_exit_faces_inside",labels[0].global_basis.z.z< -0.9 and not labels[0].double_sided)
			check(str(item.id)+"_exit_at_real_door",absf(labels[0].global_position.z-(center.z+item.d/2))<0.6)
		var eye:Vector3=center+Vector3(0,1.75,item.d/2-4.5)
		var look:Vector3=center+Vector3(0,2.65,item.d/2-0.3)
		var name:String=main.qa_mode+"_"+str(item.id)+"_return"
		if OS.has_feature("editor"):await main.qa_capture(name,eye,look)
		views.append({"name":name,"eye":[eye.x,eye.y,eye.z],"target":[look.x,look.y,look.z]})
		for node in main.world.streamer.find_children("*","Label3D",true,false):
			if node.global_position.distance_to(center)>float(item.w):continue
			sampled_labels+=1
			if node.double_sided:mirrored_labels+=1
	check("all_sampled_labels_have_one_reading_face",mirrored_labels==0,{"sampled":sampled_labels,"double_sided":mirrored_labels})
	# The generic earlier cinema interior camera was in the lobby against its programme board.
	# This actual side aisle, not that unusable camera, shows the retained auditorium.
	var cinema:Vector3=main.world.surface(245,-87,0.08)
	await main.qa_capture(main.qa_mode+"_cinema_auditorium",cinema+Vector3(11.3,3.0,3),cinema+Vector3(0,4.6,-10))
	var theater:Vector3=main.world.surface(-291,8)
	await main.qa_capture(main.qa_mode+"_theater_roof",theater+Vector3(22,18,26),theater+Vector3(0,12,0))
	await main.qa_capture(main.qa_mode+"_records_inside",main.world.surface(-97,188,0.08)+Vector3(0,1.75,4.42),main.world.surface(-97,188,0.08)+Vector3(0,1.8,-3.64))
	var failures:=0
	for row in checks:failures+=0 if row.passed else 1
	var f:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"views":views,"wayfinding":summary,"roof":counts.get("theater_roof_joints_089",{}),"scope":"Changed thirteen interior exit faces, global label backs and theater roof joints; actual rendered resource checks and fixed door/roof views. No full-world/human/media/performance acceptance."},"\t"));f.close();main.get_tree().quit(1 if failures else 0)
