class_name IconRegistry
extends RefCounted
## Task 9: кэш текстур иконок + fallback. Пути — из ThemeConfig.

const TC = preload("res://scripts/theme/theme_config.gd")
const CURSOR_DIR := "res://assets/cursors/"

static var _cache: Dictionary = {}
static var _fallback: Texture2D = null

static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path)
	_cache[path] = tex
	return tex

static func fallback() -> Texture2D:
	if _fallback == null:
		_fallback = _load(TC.ICON_FALLBACK)
	return _fallback

static func resource_texture(id: String) -> Texture2D:
	var path := "%s%s.png" % [TC.ICON_DIR_RESOURCES, id]
	var tex: Texture2D = _load(path) if ResourceLoader.exists(path) else null
	return tex if tex != null else fallback()

static func building_texture(id: String) -> Texture2D:
	var path := "%s%s.png" % [TC.ICON_DIR_BUILDINGS, id]
	var tex: Texture2D = _load(path) if ResourceLoader.exists(path) else null
	return tex if tex != null else fallback()

static func need_texture(id: String) -> Texture2D:
	var path := "%s%s.png" % [TC.ICON_DIR_NEEDS, id]
	var tex: Texture2D = _load(path) if ResourceLoader.exists(path) else null
	return tex if tex != null else fallback()

static func school_texture(id: String) -> Texture2D:
	var path := "%s%s.png" % [TC.ICON_DIR_SCHOOLS, id]
	var tex: Texture2D = _load(path) if ResourceLoader.exists(path) else null
	return tex if tex != null else fallback()

static func cursor_texture(mode: String) -> Texture2D:
	var path := "%scursor_%s.png" % [CURSOR_DIR, mode]
	var tex: Texture2D = _load(path) if ResourceLoader.exists(path) else null
	return tex if tex != null else fallback()
