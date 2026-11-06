extends Node

var _hex_tileset: TileSet = null

func build_hex_tileset() -> TileSet:
	if _hex_tileset != null:
		return _hex_tileset

	_hex_tileset = _build_tileset()
	return _hex_tileset

func clear_cache() -> void:
	_hex_tileset = null

## Единственная обязанность кэша — не пересобирать процедурный лист на каждый
## тайлсет (земля, бой, поле кампании зовут один и тот же тайлсет).
func _build_tileset() -> TileSet:
	return HexCellArt.build_hex()
