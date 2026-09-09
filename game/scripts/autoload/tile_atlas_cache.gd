extends Node

var _hex_tileset: TileSet = null

func build_hex_tileset() -> TileSet:
	if _hex_tileset != null:
		return _hex_tileset

	_hex_tileset = _build_tileset()
	return _hex_tileset

func clear_cache() -> void:
	_hex_tileset = null

func _build_tileset() -> TileSet:
	var atlas_script := load("res://scripts/world/tile_atlas.gd")
	if atlas_script == null:
		push_error("TileAtlasCache: не найден скрипт тайл-атласа.")
		return null

	var atlas = atlas_script.new()
	if atlas == null:
		push_error("TileAtlasCache: не удалось создать экземпляр тайл-атласа.")
		return null

	if atlas.has_method("build_hex"):
		var ts: Variant = atlas.call("build_hex")
		if ts is TileSet:
			return ts

	push_error("TileAtlasCache: тайл-атлас не вернул тайл-сет.")
	return null
