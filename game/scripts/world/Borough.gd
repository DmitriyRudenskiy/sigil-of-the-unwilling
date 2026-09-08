class_name Borough
extends RefCounted

var cell := Vector2i(-1, -1)
var level := 1
var uid := 0


func net_approval() -> int:
	if level < 1 or level > GameNumbers.APPROVAL_NET_PER_BOROUGH_LEVEL.size():
		return 0
	return GameNumbers.APPROVAL_NET_PER_BOROUGH_LEVEL[level - 1]
