extends SceneTree
var m
var records:Array=[]
func _initialize():run.call_deferred()
func picture(id:String,kind:String,eye:Vector3,target:Vector3,anchor:Vector3):
	if not await m.world.prepare_region(anchor,24):push_error("Preview region failed: "+id);return
	m.watch_camera.position=eye;m.watch_camera.look_at(target);m.watch_camera.current=true
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var path:String="res://screenshots/design120/"+id+"_"+kind+".png";m.get_viewport().get_texture().get_image().save_png(path)
	records.append({"id":id,"kind":kind,"file":path,"eye":eye,"target":target});print("DESIGN120_PREVIEW ",id," ",kind)
func run():
	DirAccess.make_dir_recursive_absolute("res://screenshots/design120")
	m=load("res://scenes/world/main.tscn").instantiate();root.add_child(m);m.qa_mode="design120_preview";m.store.directory="user://design120_preview";m.store.import_directory=""
	await m.start_game(false);m.player.enabled=false;m.player.set_physics_process(false);m.player.figure.hide();m.ui.hide();m.watch_camera.fov=67;m.watch_camera.near=.08;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for id in ["B01","B04","B06","B07","H01","THEME_BLOSSOM","VILLA_0","CASTLE_MAIN","AZURE_WEAVE","H12","TREEHOUSE_4"]:
		for p in m.world.layout.creative_places:
			if str(p.id)!=id:continue
			var center:=Vector3(p.center[0],p.center[1],p.center[2]);var width:float=p.size[0];var depth:float=p.size[1];var yaw:float=p.door_yaw;var turn:=Basis(Vector3.UP,yaw);var high:float=maxf(5.5,float(p.floors[-1])-float(p.floors[0])+5);var extent:float=maxf(width,depth)
			await picture(id,"exterior",center+turn*Vector3(extent*.72,high*.72+extent*.38,extent*1.12),center+Vector3.UP*(high*.4),center)
			await picture(id,"interior",center+turn*Vector3(width*.27,1.65,depth*.25),center+turn*Vector3(-width*.20,1.35,-depth*.24),center)
	var f:=FileAccess.open("res://reports/design120_preview.json",FileAccess.WRITE);f.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"poses":records,"scope":"Raw runtime previews, not movement or art acceptance","normal_saves":"isolated profile; no imports"},"\t"));f.close();quit()
