class_name ResourceAtlas
extends RefCounted

# ASSET-1: иконки ресурса — собственные файлы 32×32
# `assets/ui/icons/resources/icon_resource_<id>.png`, нарисованные генератором
# `game/tools/gen_resource_icons.py` по формуле art-бible §7.1. Здесь только кэш
# load(): раньше класс кроил ячейки чужого атласа HoMM III (102 px, 4×4).

const ICON_DIR := "res://assets/ui/icons/resources/"
const ICON_PREFIX := "icon_resource_"

# Порядок = ResourceType.ID (0..CLASSIC_COUNT-1).
const TYPE_TO_ID: Array[StringName] = [
	&"wood", &"mercury", &"ore", &"sulfur", &"crystal", &"gems", &"gold",
]

static var _cache: Dictionary = {}


static func clear() -> void:
	_cache = {}


static func icon_path(res_id: StringName) -> String:
	return ICON_DIR + ICON_PREFIX + str(res_id) + ".png"


static func texture_for_id(res_id: StringName) -> Texture2D:
	if str(res_id) == "":
		return null
	if not _cache.has(res_id):
		var path := icon_path(res_id)
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if tex == null:
			push_warning("ResourceAtlas: нет иконки ресурса: %s" % path)
		_cache[res_id] = tex
	return _cache[res_id]


static func texture_for_type(res_type: int) -> Texture2D:
	if res_type < 0 or res_type >= TYPE_TO_ID.size():
		return null
	return texture_for_id(TYPE_TO_ID[res_type])
