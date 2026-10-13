class_name TeamDialogData
extends RefCounted
## team-romance-roleplay D6: загрузка и валидация JSON-сцен диалогов.
## Формат: {"id": "...", "entry": "n1", "nodes": {
##   "n1": {"speaker": "follower"|"hero",
##          "lines": [{"text": "...", "cond": {...}}],
##          "choices": [{"text": "...", "tier": "pg"|"adult", "cond": {...},
##                       "effects": [...], "next": "n2"|null,
##                       "pg_fallback": {"text": "...", "effects": [...], "next": "n2"}}]}}}
## next == null → конец диалога.

const DIR := "res://assets/data/team_dialogs/"

const COND_KEYS := [
	"sex_h", "sex_f", "race", "path", "trait", "min_bond", "min_trust",
	"min_romance", "max_bond", "stage", "romance_stage",
	"orientation_compatible", "spouse", "min_cha", "min_wis", "min_int", "min_luk",
]
const EFFECT_KEYS := ["bond", "trust", "romance", "stat", "delta", "buff", "value", "turns", "event", "item"]
const TIERS := ["pg", "adult"]

## Загружает все сцены из DIR: id → dialog. Ошибки — push_warning + пропуск файла.
static func load_all(dir: String = DIR) -> Dictionary:
	var out: Dictionary = {}
	var dir_res := DirAccess.open(dir)
	if dir_res == null:
		push_warning("TeamDialogData: каталог %s не найден" % dir)
		return out
	dir_res.list_dir_begin()
	var file := dir_res.get_next()
	while file != "":
		var path := dir.path_join(file)
		if not dir_res.current_is_dir() and file.ends_with(".json"):
			var dialog: Dictionary = _load_file(path)
			if not dialog.is_empty():
				var errors: Array = validate(dialog)
				if errors.is_empty():
					out[String(dialog["id"])] = dialog
				else:
					push_warning("TeamDialogData: %s — ошибки: %s" % [file, ", ".join(errors)])
		file = dir_res.get_next()
	dir_res.list_dir_end()
	return out

static func _load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return {}
	return parsed

## Валидация сцены. Возвращает список ошибок (пусто — валидна).
static func validate(dialog: Dictionary) -> Array:
	var errors: Array = []
	if not dialog.has("id") or String(dialog["id"]).is_empty():
		errors.append("нет id")
		return errors
	if not dialog.has("entry"):
		errors.append("нет entry")
		return errors
	var nodes: Dictionary = dialog.get("nodes", {})
	if not nodes.has(dialog["entry"]):
		errors.append("entry '%s' не найден в nodes" % dialog["entry"])
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		if not (node.get("lines") is Array) or (node["lines"] as Array).is_empty():
			errors.append("узел %s: нет lines" % node_id)
		var choices: Array = node.get("choices", [])
		if not (choices is Array):
			errors.append("узел %s: choices не массив" % node_id)
			continue
		for c in choices:
			if not (c is Dictionary):
				errors.append("узел %s: choice не объект" % node_id)
				continue
			var cd: Dictionary = c
			if String(cd.get("text", "")).is_empty():
				errors.append("узел %s: choice без текста" % node_id)
			var tier := String(cd.get("tier", "pg"))
			if not TIERS.has(tier):
				errors.append("узел %s: неизвестный tier '%s'" % [node_id, tier])
			var nxt = cd.get("next", null)
			if nxt != null and not nodes.has(nxt):
				errors.append("узел %s: next '%s' не найден" % [node_id, nxt])
			var cond: Dictionary = cd.get("cond", {})
			for k in cond:
				if not COND_KEYS.has(k):
					errors.append("узел %s: неизвестный cond '%s'" % [node_id, k])
			var effects: Array = cd.get("effects", [])
			for e in effects:
				if not (e is Dictionary):
					errors.append("узел %s: effect не объект" % node_id)
					continue
				var ed: Dictionary = e
				var known := false
				for k in ed:
					if EFFECT_KEYS.has(k):
						known = true
				if not known:
					errors.append("узел %s: effect без известных полей" % node_id)
	return errors
