extends SceneTree
## Headless input/logic contract only: no gameplay window, save IO or original media.
const MODES=["order","street","journal","mosaic","loom","dial","light","water","crop","model","sail","tide"]
var checks:Array=[]
var failures:Array=[]
var water_seconds:Array=[]
var input_driver_ok:=true

func _initialize():call_deferred("run")

func check(name:String,ok:bool,detail:Dictionary={}):
	checks.append({"name":name,"ok":ok,"detail":detail})
	if not ok:failures.append(name)

func button(p,at:Vector2,which:int=MOUSE_BUTTON_LEFT):
	var event:=InputEventMouseButton.new();event.position=at;event.button_index=which;event.pressed=true
	p._gui_input(event)

func cell(p,index:int,which:int=MOUSE_BUTTON_LEFT):button(p,p.cell_rect(index).get_center(),which)

func drag(p,begin:Vector2,finish:Vector2,relative:Vector2):
	# The puzzle reads the real Input held-button state during mouse motion.
	# Mouse filtering is disabled on the test Control, so only this explicit GUI call handles it.
	var down:=InputEventMouseButton.new();down.position=begin;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
	Input.parse_input_event(down);Input.flush_buffered_events();p._gui_input(down)
	input_driver_ok=input_driver_ok and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var motion:=InputEventMouseMotion.new();motion.position=finish;motion.relative=relative;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	p._gui_input(motion)
	var up:=InputEventMouseButton.new();up.position=finish;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false
	Input.parse_input_event(up);Input.flush_buffered_events();p._gui_input(up)

func tile_solution(p):
	# Click-to-select and click-to-swap; neither values nor goals are assigned by the test.
	for i in p.goal.size():
		if p.values[i]==p.goal[i]:continue
		var source:int=p.values.find(p.goal[i]);cell(p,i);cell(p,source)
	if p.kind in ["mosaic","sail"]:
		check(p.kind+"_r"+str(p.round_index)+"_wrong_angle_rejected",not p.valid() or p.rotations==p.target_rotations)
		for i in p.rotations.size():
			var attempts:int=0
			while p.rotations[i]!=p.target_rotations[i] and attempts<4:cell(p,i,MOUSE_BUTTON_RIGHT);attempts+=1
		# A legal extra quarter-turn must invalidate an otherwise correct assembly.
		cell(p,0,MOUSE_BUTTON_RIGHT)
		check(p.kind+"_r"+str(p.round_index)+"_rotation_counterexample",not p.valid())
		for n in 3:cell(p,0,MOUSE_BUTTON_RIGHT)
	else:
		# Correct identity order is not sufficient after one genuine swap.
		cell(p,0);cell(p,1)
		check(p.kind+"_r"+str(p.round_index)+"_permutation_counterexample",not p.valid())
		cell(p,0);cell(p,1)

func loom_solution(p):
	for i in p.goal.size():
		var attempts:int=0
		while p.values[i]!=p.goal[i] and attempts<3:cell(p,i);attempts+=1
	cell(p,0)
	check("loom_r"+str(p.round_index)+"_one_wrong_thread_rejected",not p.valid())
	for n in 2:cell(p,0)

func dial_solution(p):
	for i in 3:
		var center:=Vector2(315+i*210,257);var angle:float=float(p.goal[i])*TAU/16.0
		var tip:Vector2=center+Vector2(cos(angle),sin(angle))*65
		drag(p,center+Vector2(40,0),tip,tip-center)
		if i==0:check(p.kind+"_r"+str(p.round_index)+"_partial_alignment_rejected",not p.valid())
	var center:=Vector2(315,257);var wrong_angle:float=float((int(p.goal[0])+1)%16)*TAU/16.0
	drag(p,center,center+Vector2(cos(wrong_angle),sin(wrong_angle))*65,Vector2.ZERO)
	check(p.kind+"_r"+str(p.round_index)+"_one_tick_error_rejected",not p.valid())
	var right_angle:float=float(p.goal[0])*TAU/16.0
	drag(p,center,center+Vector2(cos(right_angle),sin(right_angle))*65,Vector2.ZERO)

func set_valve(p,index:int,target:int):
	var attempts:int=0
	while int(p.values[index])!=target and attempts<5:button(p,Vector2(320+index*200,405));attempts+=1

func water_solution(p):
	for i in 3:set_valve(p,i,0)
	for frame in 600:p._process(1.0/60.0)
	check("water_r"+str(p.round_index)+"_closed_valves_reject_overflow",not p.valid() and float(p.basins[0])>.65 and float(p.basins[1])<.35)
	for i in 3:set_valve(p,i,3)
	var seconds:=0.0
	while seconds<90.0 and not p.valid():p._process(1.0/60.0);seconds+=1.0/60.0
	water_seconds.append(seconds)
	check("water_r"+str(p.round_index)+"_actual_flow_reaches_stable_band",p.valid() and seconds<90.0 and p.stable>=3.0 and p.basins.all(func(level):return float(level)>=.35 and float(level)<=.65),{"seconds":seconds,"levels":p.basins.duplicate(),"stable":p.stable})

func crop_solution(p):
	check("crop_r"+str(p.round_index)+"_wrong_scale_rejected_at_center",p.crop_offset.is_equal_approx(Vector2(.5,.5)) and not p.valid())
	var steps:int=0
	while p.crop_scale>float(p.goal[0]) and steps<25:button(p,Vector2(400,200),MOUSE_BUTTON_WHEEL_UP);steps+=1
	drag(p,Vector2(400,200),Vector2(500,300),Vector2(700,500))
	check("crop_r"+str(p.round_index)+"_correct_scale_wrong_offset_rejected",absf(p.crop_scale-float(p.goal[0]))<=.041 and p.crop_offset.distance_to(Vector2(.5,.5))>=.17 and not p.valid())
	var correction:Vector2=(p.crop_offset-Vector2(.5,.5))*Vector2(1400,1000)
	drag(p,Vector2(400,200),Vector2(300,100),correction)
	check("crop_r"+str(p.round_index)+"_wheel_and_drag_reach_target",p.valid() and p.crop_offset.is_equal_approx(Vector2(.5,.5)),{"scale":p.crop_scale,"offset":[p.crop_offset.x,p.crop_offset.y]})

func model_pattern(p,target:Array):
	for i in target.size():
		var attempts:int=0
		while int(p.values[i])!=int(target[i]) and attempts<5:cell(p,i);attempts+=1

func model_solution(p):
	model_pattern(p,[3,0,3,0,0,0,1,0,4])
	check("model_r"+str(p.round_index)+"_counts_with_disconnected_islands_rejected",p.values.count(3)==2 and p.values.count(4)==1 and p.values.count(1)==1 and p.values.count(0)>=2 and not p.valid())
	model_pattern(p,[0,0,1,0,3,4,0,3,1])
	check("model_r"+str(p.round_index)+"_connected_shore_valid",p.valid())

func run():
	var tested_modes:Array=MODES.duplicate()
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--modes="):tested_modes=Array(option.trim_prefix("--modes=").split(","))
	for mode in tested_modes:
		var p=load("res://scripts/creative_puzzle110.gd").new();root.add_child(p);p.set_process(false);p.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var completions:Array=[];p.completed.connect(func(result):completions.append(result))
		if mode=="dial":p.geographic_goals=[0,4,9];p.geographic_labels=["灯塔","海岛","城郭"]
		p.configure(mode,"isolated "+mode,11037,null,"qa_"+mode)
		var successful_rounds:int=0
		for round_no in 3:
			check(mode+"_r"+str(round_no)+"_initial_state_invalid",not p.valid())
			check(mode+"_r"+str(round_no)+"_invalid_submit_does_not_advance",not p.submit() and p.round_index==round_no and completions.is_empty())
			match mode:
				"loom":loom_solution(p)
				"dial","light":dial_solution(p)
				"water":water_solution(p)
				"crop":crop_solution(p)
				"model":model_solution(p)
				_:tile_solution(p)
			var legal:bool=p.valid();check(mode+"_r"+str(round_no)+"_legal_input_path_is_solvable",legal,{"moves":p.moves})
			if not legal:break
			var accepted:bool=p.submit();check(mode+"_r"+str(round_no)+"_round_acceptance",accepted and p.round_index==round_no+1 and completions.size()==(1 if round_no==2 else 0))
			if accepted:successful_rounds+=1
		var values_before:Array=p.values.duplicate();cell(p,0)
		check(mode+"_three_rounds_emit_exactly_once",successful_rounds==3 and p.solved and completions.size()==1 and str(completions[0].topic)=="qa_"+mode)
		check(mode+"_completed_input_and_submit_are_inert",p.solved and p.values==values_before and not p.submit() and completions.size()==1)
		p.free()
	check("drag_driver_used_real_held_mouse_state",input_driver_ok)
	print("CREATIVE_PUZZLES110_CHECK "+JSON.stringify({"ok":failures.is_empty(),"modes":tested_modes,"checks":checks,"failures":failures,"water_seconds":water_seconds,"scope":"headless puzzle input and logic; no GPU or full gameplay acceptance"}))
	quit(0 if failures.is_empty() else 1)
