class_name CampaignBattle
extends RefCounted

## T-050: бой K-канона кампании (состав акта 12-й итерации §3.4 + шов §2.2).
## Единичные комбатанты (стэков нет — A5-канон); лестница 02d (BattleRules,
## без кубиков, K2) с трассировкой ступеней; инициатива «Удача + Ловкость»
## один раз на бой (тай-брейки: Ловкость → ID); состояния prone + высотный
## статус — маска K-M7 (сосуществуют); Долг судьбы по таблице Б.4 (02d §4.2);
## лимит 20 раундов с ничьёй (D-128). Без RNG в разрешении (T-050 AC):
## те же входы → тот же battle_report байт в байт.
## Шов §2.2: battle_report обязателен к {losses: [character_uid]} и эмитится
## в хук населения с дня первого боя (потребитель зреет до T-116).
## battle_over — флаг для поллинга (D-152-семья), не таймер.

const BattleRulesScript := preload("res://scripts/core/battle_rules.gd")

const MAX_ROUNDS: int = 20  # D-128: лимит боя — ничья
const FATE_PENALTY_DIVISOR: float = 1.25  # «Судьба следит» (02d §4.2); привязка к лестнице — Ф3 ( interim: margin/1,25)
const DEATH_SAVES_NEEDED: int = 3  # death saves 3/3 (T-050 AC, mod ТЕЛ)

## SM персонажа (02-mechanics §3.2, T-116 слой): READY → WOUNDED → UNSTABLE →
## DEAD. WOUNDED/UNSTABLE — внутрибоевые состояния, не персистятся между
## боями (MVP-срез: потери = DEAD, раненые — не потери). «Следующий бой при
## HD = 0» (WOUNDED → UNSTABLE) — вход в бой с hit_dice ≤ 0.
const STATE_READY := "ready"
const STATE_WOUNDED := "wounded"
const STATE_UNSTABLE := "unstable"
const STATE_DEAD := "dead"


## Комбатант = Dictionary-рекорд. Статблоки — из баланс-конфига (K-M15:
## «ни одна позиция не хардкодится в коде»), сюда приходят готовыми.
## Обязательные поля: id, character_uid, hp, ac, attack, damage,
## luck (мод 7-й хар-ки), dex, con, proficiency; опциональные: prone,
## elevated (маска K-M7), fate_debt (Долг судьбы, Б.4).
static func make_combatant(spec: Dictionary) -> Dictionary:
	return {
		"id": str(spec.get("id", "")),
		"character_uid": int(spec.get("character_uid", -1)),
		"hp": int(spec.get("hp", 1)),
		"ac": int(spec.get("ac", 10)),
		"attack": int(spec.get("attack", 0)),
		"damage": int(spec.get("damage", 1)),
		"luck": int(spec.get("luck", 0)),
		"dex": int(spec.get("dex", 10)),
		"con": int(spec.get("con", 0)),
		"proficiency": int(spec.get("proficiency", 2)),
		"prone": bool(spec.get("prone", false)),
		"elevated": bool(spec.get("elevated", false)),
		"fate_debt": int(spec.get("fate_debt", 0)),
		"frightened": bool(spec.get("frightened", false)),  # 2.1: триггер отступления авто-режима
		"supply_bonus": int(spec.get("supply_bonus", 0)),  # 5.2: снабжение → 1-й спас (Q-M57→(а))
		"hunger_penalty": int(spec.get("hunger_penalty", 0)),  # party-characters 3.2: голод (0 еды) → −2 к атакам (P-4)
		"state": str(spec.get("state", STATE_READY)),  # T-116 SM: ready/wounded/unstable (dead — в бою)
	}


## Порог WOUNDED (02-mechanics SM): hit_dice ≤ 0 в бою → WOUNDED (падение =
## ранение, не смерть; смерть — только 3 провала death saves).
static func is_wounded_threshold(hp: int) -> bool:
	return hp <= 0


## Death saves с SM-переходами (T-116): UNSTABLE → DEAD (3 провала) или
## WOUNDED (стабилизирован — не потеря). Мутирует `fallen` (state),
## возвращает true — погиб.
static func _death_saves_resolve(fallen: Dictionary) -> bool:
	var dead := _death_saves(fallen)
	fallen["state"] = STATE_DEAD if dead else STATE_WOUNDED
	return dead


## A5-шов: юнит-рекрут при создании получает character_uid конкретного
## жителя (житель → рекрут, вакансия в производстве — учёт T-116).
static func make_recruit(stats: Dictionary, character_uid: int) -> Dictionary:
	var c := make_combatant(stats)
	c["character_uid"] = character_uid
	return c


## Инициатива «Удача + Ловкость», один раз на бой. Тай-брейки: Ловкость → ID
## (лексикографика). Возвращает id ходящего первым.
static func initiative_first(a: Dictionary, b: Dictionary) -> String:
	var sum_a: int = int(a["luck"]) + int(a["dex"])
	var sum_b: int = int(b["luck"]) + int(b["dex"])
	if sum_a != sum_b:
		return str(a["id"]) if sum_a > sum_b else str(b["id"])
	if int(a["dex"]) != int(b["dex"]):
		return str(a["id"]) if int(a["dex"]) > int(b["dex"]) else str(b["id"])
	return str(a["id"]) if str(a["id"]) < str(b["id"]) else str(b["id"])


## Ситуативный модификатор перевеса: маска состояний K-M7 (prone + высотный
## статус сосуществуют) — адвантейдж/дис-адвантейдж по образцу
## ADVANTAGE_MARGIN; высотный статус — верхний виртуальный ярус (+margin
## к атаке по наземному, −margin по носителю).
static func _state_margin(atk: Dictionary, def_: Dictionary) -> int:
	var m := 0
	if atk["prone"]:
		m -= GameNumbers.ADVANTAGE_MARGIN
	if def_["prone"]:
		m += GameNumbers.ADVANTAGE_MARGIN
	if atk["elevated"] and not def_["elevated"]:
		m += GameNumbers.ADVANTAGE_MARGIN
	if def_["elevated"] and not atk["elevated"]:
		m -= GameNumbers.ADVANTAGE_MARGIN
	return m


## Один удар по лестнице с Долгом судьбы (Б.4). Возвращает {zone, damage,
## margin, reckoning}. Порог долга = бонус мастерства; достигнут — Расплата
## (ступень ниже, долг → 0); долг ≥ 1 — штраф 1,25 (привязка — Ф3).
static func _strike(atk: Dictionary, def_: Dictionary) -> Dictionary:
	var margin: int = int(atk["attack"]) - int(def_["ac"]) + _state_margin(atk, def_) \
		+ int(atk.get("hunger_penalty", 0))  # голод (P-4): −2 к перевесу атаки
	var reckoning := false
	var debt_before: int = int(atk["fate_debt"])  # T-124: долг в trace (журнал этики)
	var threshold: int = int(atk["proficiency"])  # порог = бонус мастерства (K-R1, Б.4)
	if int(atk["fate_debt"]) >= threshold and int(atk["fate_debt"]) > 0:
		reckoning = true  # Расплата: исход принудительно на ступень ниже
	elif int(atk["fate_debt"]) >= 1:
		margin = int(floor(float(margin) / FATE_PENALTY_DIVISOR))  # «Судьба следит»
	var zone: StringName = BattleRulesScript.ladder_zone(margin, int(atk["luck"]))
	if reckoning:
		zone = _step_down(zone)
		atk["fate_debt"] = 0  # долг сбрасывается в 0
	var base: int = int(atk["damage"])
	var damage := 0
	match zone:
		BattleRulesScript.ZONE_TRIUMPH:
			damage = base * 2  # Триумф = урон ×2
		BattleRulesScript.ZONE_SUCCESS:
			damage = base
		BattleRulesScript.ZONE_PARTIAL:
			damage = maxi(1, base / 2) if base > 0 else 0  # Частичный = ½
		_:
			damage = 0  # Провал / Критпровал (фамбл) — 0
	return {"zone": zone, "damage": damage, "margin": margin,
		"reckoning": reckoning, "debt": debt_before}


## Ступень вниз по лестнице (Расплата): Триумф→Успех→Частичный→Провал; на
## Провале — Критпровал.
static func _step_down(zone: StringName) -> StringName:
	match zone:
		BattleRulesScript.ZONE_TRIUMPH:
			return BattleRulesScript.ZONE_SUCCESS
		BattleRulesScript.ZONE_SUCCESS:
			return BattleRulesScript.ZONE_PARTIAL
		BattleRulesScript.ZONE_PARTIAL:
			return BattleRulesScript.ZONE_FAILURE
		BattleRulesScript.ZONE_FAILURE:
			return BattleRulesScript.ZONE_FUMBLE
	return zone


## Death saves (Т-050 AC: mod ТЕЛ, 3/3), детерминированно: проверка раунда =
## con ≥ 0 → успех, иначе провал; 3 успеха — стабилизация, 3 провала — смерть.
static func _death_saves(fallen: Dictionary) -> bool:  # true — погиб
	var successes := 0
	var failures := 0
	var con: int = int(fallen["con"])
	var supply_bonus: int = int(fallen.get("supply_bonus", 0))
	# Ровно DEATH_SAVES_NEEDED спасов (N=1..3); margin_N только для N≤3
	# (Q-M57→(а)). 3 провала = смерть; 3 успеха = WOUNDED (T-116, не
	# персистится в MVP); смешанный — стабилизация (не потеря).
	for n in range(1, DEATH_SAVES_NEEDED + 1):
		var margin_n: int = con + (supply_bonus if n == 1 else 0) - (n - 1)
		if margin_n >= 0:
			successes += 1
		else:
			failures += 1
	return failures >= DEATH_SAVES_NEEDED


## Разрешение боя единичных комбатантов. Аргументы мутируются (hp, fate_debt)
## — вызывающий слой передаёт копии при необходимости.
## population_hook: func(losses: Array /* character_uid */, report) — формат
## фиксирован сейчас (§2.2), потребитель (убыль, вакансии в производстве)
## зреет до T-116; эмит — с дня первого боя, даже пустой.
## Возвращает battle_report: {outcome, rounds, first_actor, trace[],
## losses: [character_uid], battle_over}. outcome — с точки зрения `a`.
static func resolve(a: Dictionary, b: Dictionary,
		population_hook: Callable = Callable()) -> Dictionary:
	var first_id := initiative_first(a, b)
	var order := [a, b] if first_id == str(a["id"]) else [b, a]
	var trace: Array = []
	var outcome := "draw"
	var round_no := 0
	# T-116 SM: «следующий бой при HD = 0» (WOUNDED → UNSTABLE) — комбатант
	# входит в бой с hit_dice ≤ 0: спасброски до раунда 1 (тот же
	# _death_saves, детерминизм). 3 провала → DEAD (бой кончен); стабилизирован
	# → WOUNDED (0 HP — не атакует, цикл пропускает), бой продолжается.
	for c in [a, b]:
		if is_wounded_threshold(int(c["hp"])):
			c["state"] = STATE_UNSTABLE
			var dead := _death_saves_resolve(c)
			c["dead"] = dead
			trace.append({"round": 0, "actor": str(c["id"]),
				"zone": "death_saves", "dead": dead, "state": str(c["state"])})
	if bool(a.get("dead", false)) or bool(b.get("dead", false)):
		outcome = "draw" if bool(a.get("dead", false)) and bool(b.get("dead", false)) \
			else ("lose" if bool(a.get("dead", false)) else "win")
		return _finalize(outcome, 0, first_id, trace, a, b, population_hook)
	while round_no < MAX_ROUNDS:
		round_no += 1
		for pair in [[order[0], order[1]], [order[1], order[0]]]:
			var atk: Dictionary = pair[0]
			var def_: Dictionary = pair[1]
			if is_wounded_threshold(int(atk["hp"])):
				# 0 HP — не атакует (WOUNDED/UNSTABLE: действий нет, T-116).
				continue
			# Атака по 0-HP защитнику возможна (5e: без сознания) — только в
			# случае «бой при HD = 0» (unstable-вход); в обычном потоке бой
			# кончается на падении.
			var hit := _strike(atk, def_)
			def_["hp"] = int(def_["hp"]) - int(hit["damage"])
			trace.append({
				"round": round_no,
				"actor": str(atk["id"]),
				"target": str(def_["id"]),
				"zone": str(hit["zone"]),
				"margin": int(hit["margin"]),
				"damage": int(hit["damage"]),
				"reckoning": bool(hit["reckoning"]),
				"debt": int(hit["debt"]),  # T-124: Долг судьбы у атакующего (победа с долгом)
			})
			if is_wounded_threshold(int(def_["hp"])):
				# T-116 SM: READY → WOUNDED (порог hit_dice ≤ 0) → UNSTABLE (спасы).
				def_["state"] = STATE_UNSTABLE
				var dead := _death_saves_resolve(def_)
				def_["dead"] = dead
				trace.append({
					"round": round_no, "actor": str(def_["id"]),
					"zone": "death_saves", "dead": dead,
					"state": str(def_["state"]),
				})
				# Поверженный выбывает: смерть — по death saves; стабилизированный
				# — ранен (не потеря населения; слой T-116), но бой кончен.
				outcome = "win" if str(atk["id"]) == str(a["id"]) else "lose"
				return _finalize(outcome, round_no, first_id, trace, a, b, population_hook)
		# Обопыльная смерть в раунде (оба ≤0 до проверки) — ничья.
		if is_wounded_threshold(int(a["hp"])) and is_wounded_threshold(int(b["hp"])):
			outcome = "draw"
			return _finalize(outcome, round_no, first_id, trace, a, b, population_hook)
	# Лимит 20 раундов — ничья (D-128).
	outcome = "draw"
	return _finalize(outcome, round_no, first_id, trace, a, b, population_hook)


## Собирает battle_report и эмитит losses в хук населения (§2.2: с дня первого
## боя — эмит обязателен, даже пустой; потребитель зреет до T-116).
static func _finalize(outcome: String, rounds: int, first_id: String,
		trace: Array, a: Dictionary, b: Dictionary,
		population_hook: Callable) -> Dictionary:
	var losses: Array = []
	var states: Dictionary = {}
	for c in [a, b]:
		if bool(c.get("dead", false)) and int(c["character_uid"]) >= 0:
			losses.append(int(c["character_uid"]))
		states[str(c["id"])] = str(c.get("state", STATE_READY))
	var report := {
		"outcome": outcome,
		"rounds": rounds,
		"first_actor": first_id,
		"trace": trace,
		"losses": losses,
		"states": states,  # T-116 SM: финальные состояния (внутрибоевые, не сейв)
		"battle_over": true,  # поллинг флага, не таймер (D-152-семья)
	}
	if population_hook.is_valid():
		population_hook.call(losses, report)
	return report


## ═══════════ Авто-режим (dnd-battle-ladder 2.1): политика поверх того же движка ═══════════
## Чистая лестница без координат (C-3): «в радиусе» = все живые. Детерминизм K2:
## те же входы → тот же отчёт байт в байт. Не трогает 1v1-путь (resolve).

## Выбор цели (авто-режим, 2.1): мин. HP среди живых, тай-брейк меньший id.
## Возвращает комбатанта или {} (нет живых целей).
static func select_target(foes: Array) -> Dictionary:
	var best: Dictionary = {}
	for c in foes:
		if int(c.get("hp", 0)) <= 0 or bool(c.get("dead", false)):
			continue
		if best.is_empty():
			best = c
			continue
		var hp_c: int = int(c["hp"])
		var hp_best: int = int(best["hp"])
		if hp_c < hp_best or (hp_c == hp_best and str(c["id"]) < str(best["id"])):
			best = c
	return best


## Инициатива для N комбатантов: «Удача + Ловкость» (как 1v1), тай-брейк
## Ловкость → ID. Возвращает массив комбатантов в порядке ходов.
static func _initiative_order(combatants: Array) -> Array:
	var sorted: Array = combatants.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: int = int(a["luck"]) + int(a["dex"])
		var sb: int = int(b["luck"]) + int(b["dex"])
		if sa != sb:
			return sa > sb
		if int(a["dex"]) != int(b["dex"]):
			return int(a["dex"]) > int(b["dex"])
		return str(a["id"]) < str(b["id"])
	)
	return sorted


static func _side_wiped(side: Array) -> bool:
	for c in side:
		if int(c.get("hp", 0)) > 0:
			return false
	return true


## Разрешение боя N vs M (авто-режим, dnd-battle-ladder 2.1). party/enemies —
## массивы комбатантов (make_combatant). Тот же движок (_strike/_death_saves);
## детерминированный AI: min HP, тай-брейк меньший id; отступление при
## «frightened». Один отчёт (REPORT) для обоих режимов. outcome — с точки
## зрения партии: win/lose/retreat/draw.
static func resolve_multi(party: Array, enemies: Array,
		population_hook: Callable = Callable()) -> Dictionary:
	var party_ids: Dictionary = {}
	for c in party:
		party_ids[str(c["id"])] = true
	var all: Array = []
	all.append_array(party)
	all.append_array(enemies)
	var order := _initiative_order(all)
	var trace: Array = []
	var outcome := "draw"
	var round_no := 0
	while round_no < MAX_ROUNDS:
		round_no += 1
		for atk in order:
			if int(atk["hp"]) <= 0 or bool(atk.get("dead", false)):
				continue
			var is_party: bool = party_ids.has(str(atk["id"]))
			# Авто-режим: отступление при «frightened» (2.1).
			if bool(atk.get("frightened", false)):
				outcome = "retreat" if is_party else "win"
				return _finalize_multi(outcome, round_no, trace, party, enemies, population_hook)
			# Выбор цели: min HP, тай-брейк меньший id (в досягаемости = все).
			var foes: Array = enemies if is_party else party
			var target := select_target(foes)
			if target.is_empty():
				continue
			var hit := _strike(atk, target)
			target["hp"] = int(target["hp"]) - int(hit["damage"])
			trace.append({
				"round": round_no, "actor": str(atk["id"]), "target": str(target["id"]),
				"zone": str(hit["zone"]), "margin": int(hit["margin"]),
				"damage": int(hit["damage"]), "reckoning": bool(hit["reckoning"]),
				"debt": int(hit["debt"]),
			})
			if int(target["hp"]) <= 0:
				var dead := _death_saves(target)
				target["dead"] = dead
				trace.append({"round": round_no, "actor": str(target["id"]),
					"zone": "death_saves", "dead": dead})
			# Конец боя: одна сторона вычистлена.
			if _side_wiped(enemies):
				outcome = "win"
				return _finalize_multi(outcome, round_no, trace, party, enemies, population_hook)
			if _side_wiped(party):
				outcome = "lose"
				return _finalize_multi(outcome, round_no, trace, party, enemies, population_hook)
	# Лимит 20 раундов — ничья (D-128).
	outcome = "draw"
	return _finalize_multi(outcome, round_no, trace, party, enemies, population_hook)


static func _finalize_multi(outcome: String, rounds: int, trace: Array,
		party: Array, enemies: Array, population_hook: Callable) -> Dictionary:
	var losses: Array = []
	for c in party:
		if bool(c.get("dead", false)) and int(c.get("character_uid", -1)) >= 0:
			losses.append(int(c["character_uid"]))
	var report := {
		"outcome": outcome,
		"rounds": rounds,
		"trace": trace,
		"losses": losses,
		"battle_over": true,
	}
	if population_hook.is_valid():
		population_hook.call(losses, report)
	return report
