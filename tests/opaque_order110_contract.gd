extends SceneTree
const Sorter=preload("res://scripts/opaque_order110.gd")
var checks:Array=[]
func _initialize():run.call_deferred()
func mark(name:String,ok:bool):checks.append({"name":name,"ok":ok})
func box(parent:Node3D,x:float,material:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=BoxMesh.new();node.material_override=material;node.position.x=x;parent.add_child(node);return node
func run():
	var holder:=Node3D.new();root.add_child(holder)
	var a:=Node3D.new();var b:=Node3D.new();holder.add_child(a);holder.add_child(b)
	var camera:=Camera3D.new();holder.add_child(camera);camera.position=Vector3(0,2,0)
	var shared:=StandardMaterial3D.new();var near:=StandardMaterial3D.new()
	box(a,2,shared);box(b,60,shared);box(a,8,near)
	var alpha:=StandardMaterial3D.new();alpha.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;box(a,1,alpha)
	var terrain:=StandardMaterial3D.new();terrain.render_priority=120;box(a,1,terrain).set_meta("stream_terrain",true)
	var authored:=StandardMaterial3D.new();authored.render_priority=7;box(a,1,authored)
	await process_frame
	var sorter=Sorter.new();sorter.bind_cell(a,"a");sorter.bind_cell(b,"b")
	mark("shared_material_one_group_two_users",sorter.groups.size()==2 and sorter.groups[shared.get_instance_id()].users.size()==2)
	sorter.update(camera,true);mark("nearer_group_draws_first",shared.render_priority<near.render_priority)
	mark("alpha_terrain_and_authored_priorities_preserved",alpha.render_priority==0 and terrain.render_priority==120 and authored.render_priority==7)
	var before:int=shared.render_priority;camera.position=Vector3(-80,2,0);sorter.update(camera,true);mark("camera_move_updates_priority",shared.render_priority>before)
	sorter.unbind_cell("a");sorter.update(camera,true);mark("unload_one_cell_retains_other_shared_user",sorter.groups.size()==1 and sorter.groups[shared.get_instance_id()].users.size()==1 and near.render_priority==0)
	sorter.unbind_cell("b");mark("last_user_unload_restores_and_releases",sorter.groups.is_empty() and shared.render_priority==0 and sorter.cells.is_empty())
	sorter.bind_cell(a,"a");sorter.update(camera,true);sorter.clear();sorter.clear();mark("shutdown_idempotent_restores_priorities",shared.render_priority==0 and near.render_priority==0 and sorter.groups.is_empty() and sorter.cells.is_empty())
	var ok:bool=checks.all(func(row):return row.ok);var report:Dictionary={"ok":ok,"checks":checks,"scope":"Shared material ownership, alpha/terrain exclusion, moving camera and cell unload/shutdown; no normal save use"}
	var f:=FileAccess.open("res://reports/creative110_opaque_order_contract.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("OPAQUE_ORDER110_CONTRACT ",JSON.stringify(report));holder.queue_free();await process_frame;quit(0 if ok else 1)
