extends RefCounted
## Shared authored-deck exception for runtime recovery and save validation.
static func within_pier(p:Vector3)->bool:
	return absf(p.x)<=5.5 and p.z>=305 and p.z<=367.5 and p.y>=-0.85
