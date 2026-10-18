class_name RegionMap
extends RefCounted
## T-020/T-021/T-022 — регион-граф кампании (K-T7, 02e1-base-map-v1): «карта —
## это граф; узлы — атрибуты регионов; движение — по рёбрам». MVP-маска S1
## (5 регионов) — единый источник данных в movement.json (K-R4).
## T-020 — туман (радиус 1, город всегда видим); T-021 — движение по рёбрам
## (D-191, K-M4, еда 1/персонаж/переход Q-M75→(б)); T-022 — узлы + one-time loot (Y4).
##
## Туман (Q-M54 → (а)): множество открытых регионов, радиус 1; свой город
##   (стартовый регион) всегда видим.
## Движение (D-191, K-M4): переход = рёберный шаг; стоимость входа =
##   entry_cost_days[биом]; еда 1/персонаж/переход (Q-M75 → (б)), ёмкость 10.
## SM героя: EXPLORE / ENGAGE / BATTLE / VICTORY / DEFEAT / RETREAT;
##   авто-режим при 2 днях без выбора; отступление = авто-возврат за 1 день
##   без боёв (Y10).
##
## Детерминизм (I1): порядок регионов/соседей — из данных; ГСЧ не нужен для
## тумана и движения (чистые функции состояния). Боевые швы (BATTLE/VICTORY/
## DEFEAT) — в campaign_battle.gd (dnd-battle-ladder); здесь — только SM-состояния.

const MOVEMENT_CONFIG_PATH := "res://data/config/balance/movement.json"
const SCHEMA_VERSION: int = 1  # v1 — текущая: позиция, туман, visited-узлы.

const STATE_EXPLORE := "EXPLORE"
const STATE_ENGAGE := "ENGAGE"
const STATE_BATTLE := "BATTLE"
const STATE_VICTORY := "VICTORY"
const STATE_DEFEAT := "DEFEAT"
const STATE_RETREAT := "RETREAT"

const AUTO_MODE_DAYS := 2  # 2 дня без выбора → авто-режим (Y10)
const RETREAT_DAYS := 1  # отступление = авто-возврат за 1 день (Y10)

# MVP-маска (movement.json → mvp_mask)
var mask_id: String = ""
var start_region: String = ""
var regions: Array[String] = []
var biomes: Dictionary = {}
var edges: Array = []  # [[a, b], …]
var nodes: Dictionary = {}  # {region: node_type | [node_types]}

# Баланс (movement.json)
var entry_cost_days: Dictionary = {}
var base_steps_per_day: Dictionary = {}

# Туман + visited-узлы one-time loot
var open_regions: Array[String] = []
var visited_nodes: Array[String] = []

# Герой
var hero_region: String = ""
var hero_state: String = STATE_EXPLORE
var days_without_choice: int = 0
var party_size: int = 2
var food: float = 0.0
var capacity_food: float = 10.0

var adjacency: Dictionary = {}  # {region: [neighbors]}
var _event_log: Array[String] = []


func _init() -> void:
	_load_config()


## Данные (K-R4, единый источник): mvp_mask + баланс из movement.json.
func _load_config() -> void:
	if not FileAccess.file_exists(MOVEMENT_CONFIG_PATH):
		return
	var f := FileAccess.open(MOVEMENT_CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var cfg: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(cfg) != TYPE_DICTIONARY:
		return
	entry_cost_days = cfg.get("entry_cost_days", {})
	base_steps_per_day = cfg.get("base_steps_per_day", {})
	var mask: Dictionary = cfg.get("mvp_mask", {})
	mask_id = str(mask.get("id", ""))
	start_region = str(mask.get("start", ""))
	var raw_regions: Array = mask.get("regions", [])
	var parsed: Array[String] = []
	for r in raw_regions:
		parsed.append(str(r))
	regions = parsed
	biomes = mask.get("biomes", {})
	edges = mask.get("edges", [])
	nodes = mask.get("nodes", {})
	_build_adjacency()


func _build_adjacency() -> void:
	adjacency = {}
	for r in regions:
		adjacency[r] = []
	for e in edges:
		var a: String = str(e[0])
		var b: String = str(e[1])
		if adjacency.has(a) and adjacency.has(b):
			adjacency[a].append(b)
			adjacency[b].append(a)


## Инициализация кампании: герой в стартовом регионе, туман = радиус 1,
## город всегда видим. party_size/food — из стартового состояния (T-003).
func init_campaign(party_size_: int = 2, food_: float = 0.0) -> void:
	party_size = party_size_
	food = food_
	capacity_food = 10.0
	hero_region = start_region
	hero_state = STATE_EXPLORE
	days_without_choice = 0
	visited_nodes = []
	open_regions = _fog_radius_1(start_region)
	_log("кампания: герой в %s, туман = %s" % [start_region, str(open_regions)])


## Соседи региона (из данных; порядок — как в edges).
func neighbors(region: String) -> Array:
	return adjacency.get(region, [])


## T-025: инвариант доходимости — недостижимые из старта регионы (BFS по рёбрам).
## Пусто = граф MVP-маски связен (якоря 7/14/21 достижимы по данным, K-M4).
func unreachable_regions() -> Array[String]:
	var visited: Dictionary = {start_region: true}
	var queue: Array[String] = [start_region]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n in adjacency.get(cur, []):
			if not visited.has(n):
				visited[n] = true
				queue.append(n)
	var unreachable: Array[String] = []
	for r in regions:
		if not visited.has(r):
			unreachable.append(r)
	return unreachable


## Доступен ли переход в регион (сосед + открыт в тумане).
func can_travel(to_region: String) -> bool:
	return hero_state == STATE_EXPLORE \
			and adjacency.get(hero_region, []).has(to_region) \
			and open_regions.has(to_region)


## Стоимость входа в регион (дни) по биому (K-M4, movement.json).
func entry_days(to_region: String) -> int:
	var biome: String = str(biomes.get(to_region, "plains"))
	return int(entry_cost_days.get(biome, 1))


## Переход в соседний регион (рёберный шаг, D-191). Еда 1/персонаж/переход
## (Q-M75 → (б)): cost = party_size × entry_days. Возвращает отчёт.
func travel(to_region: String) -> Dictionary:
	var report := {"ok": false, "from": hero_region, "to": to_region,
		"days": 0, "food_cost": 0.0, "events": [] as Array}
	if hero_state != STATE_EXPLORE:
		report["error"] = "не в EXPLORE (%s)" % hero_state
		return report
	if not adjacency.get(hero_region, []).has(to_region):
		report["error"] = "%s не сосед %s" % [to_region, hero_region]
		return report
	if not open_regions.has(to_region):
		report["error"] = "%s в тумане (не открыт)" % to_region
		return report
	var days: int = entry_days(to_region)
	var food_cost: float = float(party_size) * float(days)
	if food_cost > food + 1e-9:
		report["error"] = "недостаточно еды (нужно %.0f, есть %.0f)" % [food_cost, food]
		return report
	food -= food_cost
	var from: String = hero_region
	hero_region = to_region
	days_without_choice = 0
	_open_fog_around(to_region)
	_log("переход %s → %s (%d дн., еда −%.0f)" % [from, to_region, days, food_cost], report)
	report["ok"] = true
	report["days"] = days
	report["food_cost"] = food_cost
	return report


## Туман: открыть радиус 1 вокруг региона (Q-M54 → (а)).
func _open_fog_around(region: String) -> void:
	if not open_regions.has(region):
		open_regions.append(region)
	for n in adjacency.get(region, []):
		if not open_regions.has(n):
			open_regions.append(n)


func _fog_radius_1(center: String) -> Array[String]:
	var out: Array[String] = [center]
	for n in adjacency.get(center, []):
		if not out.has(n):
			out.append(n)
	return out


## Узел региона (one-time loot). Возвращает тип узла или "" (нет узла).
## У региона может быть несколько типов — первый (MVP: жёсткая привязка).
func node_type(region: String) -> String:
	var v: Variant = nodes.get(region, "")
	if typeof(v) == TYPE_ARRAY:
		return str(v[0]) if not (v as Array).is_empty() else ""
	return str(v)


## One-time loot (Y4): первый визит — награда, второй — пусто (visited-узлы).
## Возвращает {looted, rewards} (rewards — из каталога, см. loot_catalog).
func visit_node(region: String) -> Dictionary:
	var result := {"looted": false, "rewards": {}, "node": node_type(region)}
	var key: String = "%s:%s" % [region, result["node"]]
	if result["node"] == "" or visited_nodes.has(key):
		return result
	visited_nodes.append(key)
	result["looted"] = true
	result["rewards"] = loot_catalog(result["node"]).duplicate(true)
	_log("узел %s (%s) — one-time loot" % [region, result["node"]], {"events": []})
	return result


## Каталог one-time loot (Y4, tasks 1.4). MVP-значения (02e1-base-map-v1 §4):
## руины 10 дерева + 5 железа + 300–500 XP; руда 20 железа + 300 XP;
## лагерь 5 еды + 10 железа + 400–600 XP. Детерминизм: нижняя граница XP.
func loot_catalog(node: String) -> Dictionary:
	match node:
		"ruin":
			return {"wood": 10, "iron": 5, "xp": 300}
		"ore":
			return {"iron": 20, "xp": 300}
		"camp":
			return {"food": 5, "iron": 10, "xp": 400}
		_:
			return {}


## Отступление (Y10): авто-возврат в город за 1 день, без боёв по пути.
func retreat() -> Dictionary:
	var report := {"ok": false, "events": [] as Array}
	if hero_state != STATE_ENGAGE and hero_state != STATE_BATTLE:
		report["error"] = "отступление доступно из ENGAGE/BATTLE (%s)" % hero_state
		return report
	hero_region = start_region
	hero_state = STATE_EXPLORE
	days_without_choice = 0
	_open_fog_around(start_region)
	_log("отступление: герой → %s за %d дн. (без боёв, Y10)" % [start_region, RETREAT_DAYS], report)
	report["ok"] = true
	return report


## Авто-режим (Y10): 2 дня без выбора → детерминированный ход (возврат к
## ближайшему узлу/городу). MVP: возврат в город (без боёв).
func tick_days(days: int) -> void:
	days_without_choice += days
	if days_without_choice >= AUTO_MODE_DAYS and hero_state == STATE_EXPLORE:
		# Авто-режим: герой возвращается в город (детерминированный ход).
		if hero_region != start_region:
			hero_region = start_region
			_open_fog_around(start_region)
			_log("авто-режим (%d дн. без выбора): герой → %s" % [days_without_choice, start_region])
		days_without_choice = 0


## Боевые швы (dnd-battle-ladder): BATTLE → VICTORY/DEFEAT/ENGAGE.
func engage_battle() -> void:
	if hero_state == STATE_EXPLORE:
		hero_state = STATE_ENGAGE
		_log("ENGAGE: бой в %s" % hero_region)

func battle_victory() -> void:
	hero_state = STATE_VICTORY
	_log("VICTORY в %s" % hero_region)

func battle_defeat() -> void:
	hero_state = STATE_DEFEAT
	_log("DEFEAT в %s" % hero_region)

func resolve_battle() -> void:
	# После VICTORY/DEFEAT — возврат в EXPLORE (герой в регионе).
	if hero_state == STATE_VICTORY or hero_state == STATE_DEFEAT:
		hero_state = STATE_EXPLORE
		days_without_choice = 0


func _set_state(next: String) -> void:
	if next != hero_state:
		hero_state = next


func _log(msg: String, report: Dictionary = {}) -> void:
	_event_log.append(msg)
	if report.has("events"):
		report["events"].append(msg)


func event_log() -> Array[String]:
	return _event_log


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"mask_id": mask_id,
		"hero_region": hero_region,
		"hero_state": hero_state,
		"days_without_choice": days_without_choice,
		"party_size": party_size,
		"food": food,
		"open_regions": open_regions.duplicate(),
		"visited_nodes": visited_nodes.duplicate(),
	}


static func from_dict(data: Dictionary) -> RegionMap:
	if data.is_empty():
		# Старый сейв без секции "region" — старт (герой в R01, туман радиус 1).
		var fresh := RegionMap.new()
		fresh.init_campaign(2, 0.0)
		return fresh
	var m := RegionMap.new()
	var ver: int = int(data.get("schema_version", 0))
	if ver != SCHEMA_VERSION:
		push_error("RegionMap: несовместимая версия сейва (%d != %d) — fail-fast"
				% [ver, SCHEMA_VERSION])
		return m
	m.hero_region = str(data.get("hero_region", ""))
	m.hero_state = str(data.get("hero_state", STATE_EXPLORE))
	m.days_without_choice = int(data.get("days_without_choice", 0))
	m.party_size = int(data.get("party_size", 2))
	m.food = float(data.get("food", 0.0))
	var oraw: Array = data.get("open_regions", [])
	var parsed_open: Array[String] = []
	for x in oraw:
		parsed_open.append(str(x))
	m.open_regions = parsed_open
	var vraw: Array = data.get("visited_nodes", [])
	var parsed_vis: Array[String] = []
	for x in vraw:
		parsed_vis.append(str(x))
	m.visited_nodes = parsed_vis
	return m
