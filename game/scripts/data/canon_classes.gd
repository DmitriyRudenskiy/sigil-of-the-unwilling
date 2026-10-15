class_name CanonClasses
extends RefCounted
## T-113 (K1, 02d-classes-skills §2/§4.2): канон-каталог классов.
## Источник данных — assets/data/mvp_catalog.json (доставлен T-111):
## 11 классов, Колдуна нет, «mage» = Волшебник (wizard); MVP-наём = 6 (hireable-маска),
## Чародей и остальные — 1.0.
## Legacy-каталог hero_classes.gd (B-18, пре-пивот) не тронут — его диспозиция: Q-M44.

const CATALOG_PATH := "res://assets/data/mvp_catalog.json"

static var _cache: Dictionary = {}


static func classes() -> Array:
	var out: Array = []
	for c in _catalog().get("classes", []):
		if c is Dictionary:
			out.append(c)
	return out


## MVP-наём: 6 классов (hireable == true) — T-113 AC.
static func hireable() -> Array:
	var out: Array = []
	for c in classes():
		if bool(c.get("hireable", false)):
			out.append(c)
	return out


static func by_id(class_id: String) -> Dictionary:
	for c in classes():
		if str(c.get("id", "")) == class_id:
			return c
	return {}


## Канон-имя класса; неизвестный id → "—".
static func name_for(class_id: String) -> String:
	var c := by_id(class_id)
	if c.is_empty():
		return "—"
	return str(c.get("name", "—"))


## Гейт при взятии класса (02d §4.1 п.4, §4.2): действует только при создании/мультиклассе;
## после взятия класс не отбирается (§4.3). Режимы: "all" — все reqs, "any" — хотя бы один.
## stats — словарь характеристик (STR/DEX/CON/INT/WIS/CHA), число = значение 3–20.
static func gate_ok(class_id: String, stats: Dictionary) -> bool:
	var c := by_id(class_id)
	if c.is_empty():
		return false
	var gate: Dictionary = c.get("gate", {})
	var reqs: Array = gate.get("reqs", [])
	if reqs.is_empty():
		return true
	var met := 0
	for r in reqs:
		if r is Array and r.size() == 2 and int(stats.get(str(r[0]), 0)) >= int(r[1]):
			met += 1
	if str(gate.get("mode", "all")) == "any":
		return met >= 1
	return met == reqs.size()


static func _catalog() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		push_warning("CanonClasses: %s не найден" % CATALOG_PATH)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	_cache = parsed if parsed is Dictionary else {}
	return _cache
