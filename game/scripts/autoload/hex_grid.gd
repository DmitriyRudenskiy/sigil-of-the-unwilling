extends Node

var shift_right: bool = true

func calibrate(tm: TileMapLayer) -> void:
	if tm == null or tm.tile_set == null:
		return
	var a := tm.map_to_local(Vector2i(0, 0))
	var b := tm.map_to_local(Vector2i(0, 1))
	shift_right = b.x > a.x
	GameLogger.trace("calibrated: odd_row_shift_right = %s" % str(shift_right), "HexGrid")
