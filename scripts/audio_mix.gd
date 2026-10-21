extends RefCounted
## Project-owned mix buses. No microphone input or recording.
const BUSES=["Music","Media","Environment","Interface"]
static func setup():
	for name in BUSES:
		if AudioServer.get_bus_index(name)<0:
			AudioServer.add_bus();var index:=AudioServer.bus_count-1
			AudioServer.set_bus_name(index,name);AudioServer.set_bus_send(index,"Master")

static func apply(settings:Dictionary):
	setup()
	for item in [["Master","master_volume"],["Music","music_volume"],["Media","media_volume"],["Environment","environment_volume"],["Interface","interface_volume"]]:
		var level:=clampf(float(settings.get(item[1],1.0)),0,1)
		var index:=AudioServer.get_bus_index(item[0])
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(level,0.0001)))
		AudioServer.set_bus_mute(index,level<=0)
