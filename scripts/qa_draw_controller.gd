extends RefCounted
## QA-only fallback: request a real draw only when no natural callback followed the last sample.
var probe=preload("res://scripts/render_coverage.gd").new()
var fallback_used:=false
var requests:=0
var expected_draw_count:=0

func start():probe.start();expected_draw_count=0

func sample():
	probe.sample()
	var current:int=probe.draw_count
	var natural_draw:bool=current>expected_draw_count
	if Time.get_ticks_usec()-probe.last_draw_usec>120000:fallback_used=true
	if fallback_used and not natural_draw:
		# Count the requested callback even if signal delivery is deferred.
		expected_draw_count=current+1;requests+=1
		RenderingServer.force_draw(false)
	else:expected_draw_count=current

func stop():probe.stop()

func report()->Dictionary:
	var result:Dictionary=probe.report()
	result.forced_draw_requests=requests
	result.fallback_used=fallback_used
	result.policy="Conditional real draw only when no natural callback follows the preceding sample; no ordinary-game change. Callback gaps are not GPU/presentation timestamps."
	return result
