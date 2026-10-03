## MVP-инварианты (T-112) — статические проверки баланс-конфигов против K-M4/K-M9/K-M13 + Ф4 (Престиж).
## Не Monte-Carlo (это AutoBalancer): утверждения о числах в res://data/config/balance/.
## Каждый check_* возвращает Array[String] нарушений; пусто = инвариант держится.
class_name MvpInvariants
extends RefCounted

const DIR := "res://data/config/balance/"

static func load_config(name: String) -> Dictionary:
	var path := DIR + name + ".json"
	if not FileAccess.file_exists(path):
		push_error("MvpInvariants: нет файла " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("MvpInvariants: JSON-ошибка " + path)
		return {}
	return parsed

static func check_all() -> Array[String]:
	var out: Array[String] = []
	var campaign: Dictionary = load_config("campaign")
	var movement: Dictionary = load_config("movement")
	var xp: Dictionary = load_config("xp")
	var raids: Dictionary = load_config("raids")
	out.append_array(check_pacing(xp, raids, movement.get("mvp_mask", {})))
	out.append_array(check_reachability(movement, campaign))
	out.append_array(check_beats(campaign, raids))
	out.append_array(check_prestige(load_config("prestige")))
	return out

## Ф4 (2026-10-03): источники Престижа — закрытый список 02-mechanics §2 verbatim (4);
## «район» — не источник (K-M16); шкала рангов — Ф4 (волна 1). Числа — в конфиге, проверка — здесь.
static func check_prestige(prestige: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if prestige.is_empty():
		return ["prestige: prestige.json не загрузился"]
	var sources: Dictionary = prestige.get("sources", {})
	var expected := ["battle_victory", "sign_trials", "council", "monument"]
	for key in sources.keys():
		if not expected.has(str(key)):
			out.append(
				"prestige: источник вне закрытого списка Ф4: %s (район — не источник, K-M16)" % str(key)
			)
	for key in expected:
		if not sources.has(key):
			out.append("prestige: отсутствует источник закрытого списка Ф4: %s" % key)
	var ranks: Array = prestige.get("ranks", [])
	if ranks != [0, 200, 500, 1000, 2000]:
		out.append("prestige: ранги не совпадают с Ф4-шкалой 0/200/500/1000/2000: %s" % str(ranks))
	return out

## K-M13: гарантированный XP-бюджет (min-значения, только floor-гарантированные источники)
## к ходу 21 >= порог ур.5; к ходу 14 < порога (ур.5 не раньше ±1 хода).
static func check_pacing(xp: Dictionary, raids: Dictionary, mask: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if xp.is_empty():
		return ["pacing: xp.json не загрузился"]
	var need := float(xp.get("level_thresholds", {}).get("5", 0))
	var scale := float(xp.get("xp_scale", 1))
	var loot: Dictionary = xp.get("node_loot", {})
	var raid_xp := float(xp.get("sources", {}).get("raid_survived", 0))

	var node_min := _node_xp(loot, mask, true)
	var camps: Array = raids.get("camps_mvp", [])
	var camp_combat := 0.0
	for c in camps:
		camp_combat += _combat_xp(float((c as Dictionary).get("cr", 1)), int((c as Dictionary).get("enemies", 0)))
	var d: Dictionary = raids.get("directives", {})
	var first: Dictionary = d.get("first_raid", {})
	var final: Dictionary = d.get("final_raid", {})
	var first_raid := raid_xp + _combat_xp(float(first.get("cr", 1)), int(first.get("enemies", 0)))
	var final_cr: Variant = final.get("cr", 1)
	var final_cr_min := float(final_cr[0]) if final_cr is Array else float(final_cr)
	var final_raid := raid_xp + _combat_xp(final_cr_min, int(final.get("enemies", 0)))

	var by_21 := (node_min + camp_combat + first_raid + final_raid) * scale
	var by_14 := (node_min + camp_combat + first_raid) * scale
	if by_21 < need:
		out.append("pacing: гарантированный XP к ходу 21 (%.0f) < ур.5 (%.0f) — поднять xp_scale/источники (K-M13: пороги не трогать)" % [by_21, need])
	if by_14 >= need:
		out.append("pacing: гарантированный XP к ходу 14 (%.0f) >= ур.5 (%.0f) — уровень 5 слишком рано" % [by_14, need])
	return out

## K-M4: доходимость бит-якорей — ближайшая руина <= туториал-дня 3, все регионы S1 <= длительности кампании.
static func check_reachability(movement: Dictionary, campaign: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var mask: Dictionary = movement.get("mvp_mask", {})
	var biomes: Dictionary = mask.get("biomes", {})
	if biomes.is_empty():
		return ["reachability: mvp_mask.biomes пуст"]
	var dist := _distances(mask, movement.get("entry_cost_days", {}))
	for r in biomes.keys():
		if not dist.has(r):
			out.append("reachability: регион %s недостижим из %s" % [r, mask.get("start", "?")])
	var turns := int(campaign.get("campaign", {}).get("turns", 21))
	for r in dist.keys():
		if int(dist[r]) > turns:
			out.append("reachability: %s (%d дней) > длительность кампании (%d)" % [r, int(dist[r]), turns])
	var tutorial_day := int(campaign.get("tutorial", {}).get("day_3", 3))
	var ruin_dist := _min_dist_to_node(dist, mask, "ruin")
	if ruin_dist > tutorial_day:
		out.append("reachability: ближайшая руина (%d дней) > туториал «руины» (день %d)" % [ruin_dist, tutorial_day])
	return out

## K-M9: биты внутри кампании; floor-директивы рейдов совпадают с битами.
static func check_beats(campaign: Dictionary, raids: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var beats: Dictionary = campaign.get("beats", {})
	var turns := int(campaign.get("campaign", {}).get("turns", 21))
	for b in beats.keys():
		if int(b) < 1 or int(b) > turns:
			out.append("beats: бит %s вне кампании (1..%d)" % [b, turns])
	for key in ["first_raid", "final_raid"]:
		var d: Dictionary = raids.get("directives", {}).get(key, {})
		if not d.is_empty() and not beats.has(str(int(d.get("turn", 0)))):
			out.append("beats: floor-директива %s (ход %s) без бита" % [key, d.get("turn", "?")])
	return out

## --- helpers ---

static func _combat_xp(cr: float, enemies: int) -> float:
	return 100.0 * cr * (1.0 + 0.1 * enemies)

static func _node_xp(loot: Dictionary, mask: Dictionary, min_val: bool) -> float:
	var idx := 0 if min_val else 1
	var total := 0.0
	for node_type in ["ruin", "ore", "camp"]:
		var count := _count_nodes(mask, node_type)
		if count == 0:
			continue
		var entry: Variant = loot.get(node_type, {}).get("xp", 0)
		if entry is Array:
			total += float((entry as Array)[idx]) * count
		else:
			total += float(entry) * count
	return total

static func _count_nodes(mask: Dictionary, node_type: String) -> int:
	var count := 0
	for v in (mask.get("nodes", {}) as Dictionary).values():
		if v is Array:
			if node_type in v:
				count += 1
		elif v == node_type:
			count += 1
	return count

## BFS по рёбрам S1: стоимость ребра = entry_cost_days[биом целевого региона].
static func _distances(mask: Dictionary, costs: Dictionary) -> Dictionary:
	var start: String = mask.get("start", "")
	var biomes: Dictionary = mask.get("biomes", {})
	var edges: Array = mask.get("edges", [])
	var dist := { start: 0 }
	var frontier: Array[String] = [start]
	while not frontier.is_empty():
		var next: Array[String] = []
		for r in frontier:
			for e in edges:
				var a: String = (e as Array)[0]
				var b: String = (e as Array)[1]
				var to := ""
				if a == r and not dist.has(b):
					to = b
				elif b == r and not dist.has(a):
					to = a
				if to != "":
					dist[to] = int(dist[r]) + int(costs.get(biomes.get(to, ""), 0))
					next.append(to)
		frontier = next
	return dist

static func _min_dist_to_node(dist: Dictionary, mask: Dictionary, node_type: String) -> int:
	var best := 9999
	for r in (mask.get("nodes", {}) as Dictionary).keys():
		var v: Variant = (mask.get("nodes", {}) as Dictionary)[r]
		var has: bool = (v is Array and node_type in v) or (not (v is Array) and v == node_type)
		if has and dist.has(r) and int(dist[r]) < best:
			best = int(dist[r])
	return best
