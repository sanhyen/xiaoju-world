extends RefCounted
## Current-package required screenshots and local playback-bus measurements. No microphone/system audio.
var main
var views:Array=[]
var checks:Array=[]
var audio:Array=[]
func sample(_delta):pass
func check(name:String,ok:bool,detail:Dictionary={}):
	checks.append({"test":name,"passed":ok,"detail":detail});print("RELEASE_EVIDENCE ",name," ",ok," ",JSON.stringify(detail))
func point(name:String,eye:Vector3,look:Vector3):
	await main.qa_capture(main.qa_mode+"_"+name,eye,look)
	views.append({"name":name,"eye":[eye.x,eye.y,eye.z],"target":[look.x,look.y,look.z],"time":main.state.time,"fov":main.watch_camera.fov,"resolution":[main.get_viewport().size.x,main.get_viewport().size.y],"internal_scale":main.get_viewport().scaling_3d_scale,"kind":"real_game_camera"})
func ui(name:String):
	var ready:bool=await main.qa_frame()
	var error:int=main.get_viewport().get_texture().get_image().save_png(main.evidence_root+"screenshots/"+main.qa_mode+"_"+name+".png") if ready else ERR_UNAVAILABLE
	check("capture_"+name,error==OK)
	views.append({"name":name,"time":main.state.time,"resolution":[main.get_viewport().size.x,main.get_viewport().size.y],"kind":"actual_viewport_ui"})
func move(p:Vector3):
	await main.world.prepare_region(p);main.player.position=p;main.player.velocity=Vector3.ZERO
	main.player.enabled=false;main.player.program_driven=true;main.player.camera.current=true
func bus_probe(bus_name:String,id:String,seconds:float=6.0):
	var bus:int=AudioServer.get_bus_index(bus_name)
	var effect:=AudioEffectCapture.new();effect.buffer_length=2.0
	var effect_index:int=AudioServer.get_bus_effect_count(bus);AudioServer.add_bus_effect(bus,effect)
	var samples:=PackedVector2Array();var sum_squares:=0.0;var peak:=0.0;var clips:=0
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await main.get_tree().create_timer(0.03).timeout
		var frames:PackedVector2Array=effect.get_buffer(effect.get_frames_available())
		for frame in frames:
			sum_squares+=frame.x*frame.x+frame.y*frame.y;peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
			if maxf(absf(frame.x),absf(frame.y))>=0.999:clips+=1
		samples.append_array(frames)
	var rms:float=sqrt(sum_squares/maxi(1,samples.size()*2))
	var discarded:int=effect.get_discarded_frames();AudioServer.remove_bus_effect(bus,effect_index)
	var bytes:=PackedByteArray();bytes.resize(samples.size()*4)
	for i in samples.size():
		bytes.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767));bytes.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=true;wav.mix_rate=int(AudioServer.get_mix_rate());wav.data=bytes
	DirAccess.make_dir_recursive_absolute(main.evidence_root+"audio")
	var path:String=main.evidence_root+"audio/"+main.qa_mode+"_"+id+".wav";var saved:int=wav.save_to_wav(path)
	var row:={"id":id,"bus":bus_name,"frames":samples.size(),"rate":wav.mix_rate,"rms":rms,"peak":peak,"clipped_frames":clips,"discarded_frames":discarded,"file":path,"saved":saved==OK,"scope":"Actual output from this game's playback bus; not microphone, OS speaker loopback or subjective hearing/AV sync."}
	audio.append(row);check(id+"_decoded_bus_non_silent",samples.size()>int(wav.mix_rate*seconds*0.8) and rms>0.00001 and discarded==0 and saved==OK,row)
func run(target):
	main=target;main.store.directory="user://qa_isolated/"+main.qa_mode;main.watch_camera.fov=75;main.set_time(0)
	await point("V01_menu",Vector3(32,17,93),Vector3(0,9,40))
	await main.start_game(false);main.player.enabled=false;main.player.program_driven=true
	await main.get_tree().process_frame
	var eye:Vector3=main.player.camera.global_position;var look:Vector3=eye-main.player.camera.global_basis.z*250
	await point("V02_opening_player",eye,look)
	main.hud.hide()
	await point("V06_portrait_detail",Vector3(0,15,46.5),Vector3(0,15,39.44))
	main.set_time(2);await point("V07_portrait_night",Vector3(0,3,75),Vector3(0,10,39.44));main.set_time(0)
	await point("V09_cafe_ground",Vector3(-65,2.2,292),Vector3(-70,1.7,282))
	await point("V09_cafe_upper",Vector3(-69,5.55,288.5),Vector3(-66,4.9,330))
	var w=main.world
	await move(w.surface(245,-78.3,0.5));await main.show_video("B06","sunset")
	await main.get_tree().create_timer(3).timeout
	check("cinema_actual_video_begins",main.video.is_playing() and main.video.stream_position>0.5 and main.video.get_video_texture()!=null)
	await ui("V12_cinema_playing");await bus_probe("Media","cinema_sunset")
	main.close_modal();main.player.enabled=false;check("cinema_releases_stream",main.video.stream==null and main.watch_screen==null)
	await move(w.surface(-291,17,0.5));await main.show_video("B10","wall_stage")
	await main.get_tree().create_timer(3).timeout;await ui("V13_stage_playing");main.close_modal();main.player.enabled=false
	main.show_audio("wall_audio");await main.get_tree().create_timer(0.7).timeout;await bus_probe("Music","wall_audio")
	main.close_modal();main.player.enabled=false;check("music_releases_stream",main.audio_player.stream==null and not main.audio_player.playing)
	await point("V14_gallery",w.surface(173,-35,2.4),w.surface(173,-46,2.3))
	await move(w.surface(225,-146,0.5));main.show_pb(0);await ui("V14_pb_page");main.close_modal();main.player.enabled=false
	await move(w.surface(-236.5,-168.5,0.4));main.state.bouquet=2;main.state.home_photo=2
	w.update_home(2,"res://"+main.assets[2].runtime_path);check("V15_saved_home",main.save_game(false))
	await point("V15_home_saved",w.surface(-237,-169)+Vector3(3,2.4,3.5),w.surface(-237,-169)+Vector3(0,2,-4))
	main.show_home();await ui("V15_home_controls");main.close_modal();main.player.enabled=false
	await move(w.surface(260,194,0.5));main.show_map();await ui("V18_map");main.close_modal();main.player.enabled=false
	for action in w.interactions:
		if action.id=="Z01":main.activate(action);break
	main.claim_card("Z01");main.show_souvenirs();await ui("V19_collection");main.close_modal();main.player.enabled=false
	main.show_sources();await ui("V19_sources");main.close_modal();main.player.enabled=false
	main.hud.show();main.watch_camera.current=false;main.player.camera.current=true;await ui("V20_native_player")
	var failed:=0
	for row in checks:failed+=0 if row.passed else 1
	var report:={"version":ProjectSettings.get_setting("application/config/version"),"runtime":"editor_binary" if OS.has_feature("editor") else "export_release","checks":checks,"failures":failed,"views":views,"audio":audio,"scope":"Current native missing screenshot/UI evidence and isolated saved home plus actual decoded Media/Music bus samples. No full route/performance, manual input, OS speaker or subjective hearing claim."}
	var file:=FileAccess.open(main.evidence_root+"reports/"+main.qa_mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();main.get_tree().quit(1 if failed else 0)
