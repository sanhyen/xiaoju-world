extends RefCounted
## Counts renderer-completed frames separately from main-loop intervals. Not GPU timestamps.
var begun_usec:=0
var last_draw_usec:=0
var draw_count:=0
var process_count:=0
var drawn_processes:Dictionary={}
var seconds_with_draw:Dictionary={}
var gaps_ms:Array=[]
var ended_usec:=0

func start():
	begun_usec=Time.get_ticks_usec();last_draw_usec=begun_usec
	RenderingServer.frame_post_draw.connect(on_draw)

func on_draw():
	var now:=Time.get_ticks_usec()
	if last_draw_usec>0:gaps_ms.append((now-last_draw_usec)/1000.0)
	last_draw_usec=now;draw_count+=1
	drawn_processes[Engine.get_process_frames()]=true
	seconds_with_draw[int((now-begun_usec)/1000000)]=true

func sample():process_count+=1

func stop():
	ended_usec=Time.get_ticks_usec()
	if RenderingServer.frame_post_draw.is_connected(on_draw):RenderingServer.frame_post_draw.disconnect(on_draw)

func report()->Dictionary:
	var end:int=ended_usec if ended_usec>0 else Time.get_ticks_usec()
	var duration:float=maxf((end-begun_usec)/1000000.0,0.001)
	var ordered:Array=gaps_ms.duplicate();ordered.sort()
	var tail_ms:float=(end-last_draw_usec)/1000.0
	var max_gap:float=maxf(float(ordered[-1]) if not ordered.is_empty() else 0,tail_ms)
	return {"duration_s":duration,"completed_draws":draw_count,"process_samples":process_count,"draws_per_second":draw_count/duration,"process_coverage":minf(1.0,float(drawn_processes.size())/maxi(process_count,1)),"seconds_with_draw":seconds_with_draw.size(),"observed_seconds":ceili(duration),"second_coverage":minf(1.0,float(seconds_with_draw.size())/ceili(duration)),"max_no_draw_ms":max_gap,"draw_gap_p95_ms":ordered[int(ordered.size()*0.95)] if not ordered.is_empty() else null,"draw_gap_p99_ms":ordered[int(ordered.size()*0.99)] if not ordered.is_empty() else null,"measurement":"RenderingServer.frame_post_draw callbacks; wall-clock completion gaps, not GPU execution time"}
