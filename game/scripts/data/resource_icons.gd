
class_name ResourceIcons
extends RefCounted

const _RT := preload("res://scripts/data/resource_type.gd")

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
	# Ветка не промах, а унаследованное решение (его комментарий срезан `520a5ae8`,
	# 2026-09-09, «strip all comments»): «классические — null: попап рисует кружок
	# из get_color; теренные ресурсы — фолбэк в спрайт-лист». Поведение закреплено
	# тестами (tests/functional/test_resource_collect_popup.gd, test_perf_resource_icons.gd).
	# Предпосылка ветки устарела: ASSET-1 (`aaa2a4aa`, 2026-10-14) нарисовал
	# классическим ресурсам свои icon_resource_*.png. Открытый вопрос (а)/(б) — T-284;
	# менять ветку молча нельзя, сначала акт.
	var entry := _entry_for(resource_id)
	var path: String = str(entry.get("texture", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D

	var rid := _RT.from_name(resource_id)
	if rid >= 0 and rid < _RT.CLASSIC_COUNT:
		return null
	return ResourceAtlas.texture_for_id(resource_id)

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

	var resolved: Object = Services.resolve(&"resources")
	if resolved is Node:
		_registry_cache = resolved
	return _registry_cache
