# FILE: res://scripts/data/ResourceIcons.gd  (ПОЛНАЯ ЗАМЕНА)
class_name ResourceIcons
extends RefCounted

const _RT := preload("res://scripts/data/ResourceType.gd")

## Текстуры теренных ресурсов (пусто — фолбэк в спрайт-лист). Имена/цвета — в GameText/ThemeConfig.
const DATA: Dictionary = {
	_RT.ID.WOOD:    {"texture": ""},
	_RT.ID.MERCURY: {"texture": ""},
	_RT.ID.ORE:     {"texture": ""},
	_RT.ID.SULFUR:  {"texture": ""},
	_RT.ID.CRYSTAL: {"texture": ""},
	_RT.ID.GEMS:    {"texture": ""},
	_RT.ID.GOLD:    {"texture": ""},
}

static func res_type_id(res_type: int) -> StringName:
	if res_type < 0 or res_type >= _RT.CLASSIC_COUNT:
		return &""
	return _RT.to_name(res_type)

static func res_type_amount(res_type: int) -> int:
	return _RT.pickup_amount(res_type)

static func _entry_for(resource_id: StringName) -> Dictionary:
	return DATA.get(_RT.from_name(resource_id), {})

static func get_texture(resource_id: StringName) -> Texture2D:
	var entry := _entry_for(resource_id)
	var path: String = str(entry.get("texture", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	# классические — null: попап рисует кружок из get_color;
	# теренные ресурсы — фолбэк в спрайт-лист
	var rid := _RT.from_name(resource_id)
	if rid >= 0 and rid < _RT.CLASSIC_COUNT:
		return null
	return ResourceAtlas.texture_for_id(resource_id)

## Имя ресурса — через локализацию (GameText.resource_name).
static func get_color(resource_id: StringName) -> Color:
	return ThemeConfig.resource_color(resource_id)

static func _registry_def(resource_id: StringName) -> ResourceDef:
	var reg := _registry()
	if reg == null:
		return null
	return reg.get_resource(resource_id)

static var _registry_cache: Node = null


static func clear_cache() -> void:
	_registry_cache = null

static func _registry() -> Node:
	if _registry_cache != null:
		return _registry_cache
	# ИСПРАВЛЕНИЕ: Services.resolve вместо get_node(\"^Resources\")
	var resolved: Object = Services.resolve(&"resources")
	if resolved is Node:
		_registry_cache = resolved
	return _registry_cache
