extends SceneTree
func _initialize():
	var first:Dictionary={"a":1,"b":[2]};var second:Dictionary=JSON.parse_string(JSON.stringify(first))
	print("STATE_TYPE_PROBE ",JSON.stringify({"has_float":[1.0].has(1),"direct":1==1.0,"dictionary":first==second,"array":[1]==[1.0],"before":first,"after":second}))
	quit()
