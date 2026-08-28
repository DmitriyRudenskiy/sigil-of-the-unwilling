extends Node
class_name UnitSprites

## Helper to find portrait for a unit key, with caching.
static var _portrait_cache: Dictionary = {}
static var _portrait_small_cache: Dictionary = {}


static func find_portrait(key: String) -> String:
	if _portrait_cache.has(key):
		return _portrait_cache[key]

	var path := "res://assets/units/%s.png" % key

	if ResourceLoader.exists(path):
		_portrait_cache[key] = path
		return path

	var fallback := "res://assets/units/swordsmen.png"

	if ResourceLoader.exists(fallback):
		_portrait_cache[key] = fallback
		return fallback

	_portrait_cache[key] = ""
	return ""


static func find_portrait_small(key: String) -> String:
	if _portrait_small_cache.has(key):
		return _portrait_small_cache[key]

	var path := "res://assets/units/%s_s.png" % key

	if ResourceLoader.exists(path):
		_portrait_small_cache[key] = path
	else:
		_portrait_small_cache[key] = ""

	return _portrait_small_cache[key]
