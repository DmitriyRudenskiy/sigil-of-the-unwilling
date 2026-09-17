extends RefCounted
## Smoldering City — meta-прогрессия (фаза 5). Д2: статик + state.
## 5.4: meta-сейв отдельным ключом, переживает прогоны.

const Upgrades = preload("res://scripts/data/smoldering_upgrades.gd")
const Num = preload("res://scripts/constants/GameNumbersSettlement.gd")

const SAVE_PATH := "user://smoldering_city.save"

static func fresh_state() -> Dictionary:
	return {
		"tablets": 0,
		"level": 1,
		"purchased": {},   # upgrade_id -> true
		"dlc": {},         # dlc_id -> true
		"victories": 0,
	}

# 5.1 Доля из поселения: поражение 50% / победа 100%
static func settle_share(settle) -> float:
	var won: bool = bool(settle.state.get("victory", false))
	var share: float = Num.SETTLE_SHARE_VICTORY if won else Num.SETTLE_SHARE_DEFEAT
	var tablets: float = float(settle.state["resources"].get("ancient_tablets", 0.0))
	return tablets * share

static func on_settlement_ended(meta: Dictionary, settle) -> void:
	meta["tablets"] = int(meta["tablets"]) + int(settle_share(settle))
	if bool(settle.state.get("victory", false)):
		meta["victories"] = int(meta["victories"]) + 1
		meta["level"] = mini(int(meta["level"]) + 1, 12)
	# ункилоки видов по уровню
	if int(meta["level"]) >= 9:
		meta["purchased"]["frog_species"] = true
	if int(meta["level"]) >= 11:
		meta["purchased"]["bat_species"] = true

static func can_buy(meta: Dictionary, upgrade_id: String) -> bool:
	var u: Dictionary = Upgrades.UPGRADES.get(upgrade_id, {})
	if u.is_empty() or bool(meta["purchased"].get(upgrade_id, false)):
		return false
	if int(meta["level"]) < int(u.get("level", 1)):
		return false
	var dlc: String = u.get("dlc", "")
	if dlc != "" and not bool(meta["dlc"].get(dlc, false)):
		return false
	return int(meta["tablets"]) >= int(u["cost"])

static func buy(meta: Dictionary, upgrade_id: String) -> bool:
	if not can_buy(meta, upgrade_id):
		return false
	var u: Dictionary = Upgrades.UPGRADES[upgrade_id]
	meta["tablets"] = int(meta["tablets"]) - int(u["cost"])
	meta["purchased"][upgrade_id] = true
	return true

# meta -> Dictionary для can_build поселения (vs-level из апгрейдов)
static func meta_for_buildings(meta: Dictionary) -> Dictionary:
	var vs := 0
	if bool(meta["purchased"].get("vanguard_spire", false)):
		vs = int(meta["level"])
	return {
		"smoldering_level": int(meta["level"]),
		"vanguard_level": vs,
		"ancient_knowledge": bool(meta["purchased"].get("ancient_knowledge", false)),
	}

# 5.4 Meta-сейв (отдельный ключ)
static func save(meta: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta))
		f.close()

static func load() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return fresh_state()
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return fresh_state()
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return fresh_state()
	var meta: Dictionary = fresh_state()
	for k in parsed:
		meta[k] = parsed[k]
	return meta
