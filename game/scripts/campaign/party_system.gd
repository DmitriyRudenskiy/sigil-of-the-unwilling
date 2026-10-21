class_name PartySystem
extends RefCounted
## T-060 (R1/R4, K-M13, K3, K-M11): развитие партии — XP, уровни 1–5, ASI,
## потери и wipe.
##
## Данные — state.party: [{id, class, race, level, xp, stats{}, luck, state?, uid?}]
## (MvpSaveSchema: party = TYPE_ARRAY; "state" — входная величина: READY/DEAD;
## "uid" — uid жителя, если член партии — житель (шов §2.2, потери по uid)).
## Чистые функции: без ГСЧ, одинаковые входы → одинаковые выходы (I1).
##
## Канон-значения — `data/config/balance/xp.json` (07-balance §3; K-M13: пороги
## никогда не правятся — при нестыковке бюджета правятся источники). Фолбэк —
## канон-константы (только при неисправном конфиге, push_warning).
##
## Срез MVP: бой — 1v1 авто-разрешение (T-050), внутрибоевые WOUNDED/UNSTABLE
## не персистятся (потери = DEAD, раненые — не потери, слой T-116); REST/лечение
## и замена мёртвых (наёмник ур. города−1) — с боем партии (за срезом).

const XP_JSON := "res://data/config/balance/xp.json"
const CAMPAIGN_JSON := "res://data/config/balance/campaign.json"

## Фолбэк — канон 07-balance §3 (SRD-пороги уровней 2–5; K-M13).
const DEFAULT_THRESHOLDS: Array[int] = [0, 2700, 6500, 15000, 38000]
const DEFAULT_MAX_LEVEL := 5
const MIN_LEVEL := 1
const DEFAULT_RAID_SURVIVED := 300
const DEFAULT_NODE_RANGE: Array[int] = [200, 800]

## ASI (K3, 5e): +2 к одной или +1 к двум; практический потолок 16.
## Удача (7-я хар-ка) — не объект ASI: расовый модификатор (каталог, K-M5).
const ASI_CAP := 16
const ASI_ABILITIES: Array[String] = ["str", "dex", "con", "int", "wis", "cha"]

const STATE_READY := "READY"
const STATE_DEAD := "DEAD"
## V-5 (D-220, D4): ростерный статус «выжил с 0 HP» (боевой WOUNDED T-116,
## перенесённый в ростер). Живой (считается в alive_members/wipe/лимите),
## без механического штрафа, снимается REST'ом.
const STATE_WOUNDED := "WOUNDED"

## V-5 (D-220, D2): max_hp всех членов партии — hp warrior-статблока
## (герой-прокси MVP-боя; класс-маппинг — вне V-5). Фолбэк — только при
## неисправном campaign.json (push_warning, прецедент DEFAULT_*).
const DEFAULT_HERO_MAX_HP := 45

static var _cfg: Dictionary = {}


static func _config() -> Dictionary:
	if _cfg.is_empty():
		var file := FileAccess.open(XP_JSON, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_cfg = parsed
			else:
				push_warning("PartySystem: xp.json не распарсился — канон-фолбэк")
		else:
			push_warning("PartySystem: %s не найден — канон-фолбэк" % XP_JSON)
	return _cfg


## Пороги XP [0, ур.2, ур.3, ур.4, ур.5] — xp.json level_thresholds (SRD, K-M13).
static func thresholds() -> Array:
	var th: Variant = _config().get("level_thresholds", {})
	if not (th is Dictionary) or (th as Dictionary).is_empty():
		return DEFAULT_THRESHOLDS.duplicate()
	var out: Array = [0]
	for i in range(2, max_level() + 1):
		# индекс дефолта = i−1: [0(ур.1), 2700(ур.2), 6500(ур.3), 15000(ур.4), 38000(ур.5)]
		out.append(int((th as Dictionary).get(str(i), DEFAULT_THRESHOLDS[i - 1])))
	return out


## Кап уровня — xp.json level_cap (K-M13: 1–5).
static func max_level() -> int:
	return maxi(MIN_LEVEL, int(_config().get("level_cap", DEFAULT_MAX_LEVEL)))


## «Рейд пережит» — xp.json sources.raid_survived (07-balance §3: 300).
static func raid_survived_xp() -> int:
	return int((_config().get("sources", {}) as Dictionary).get(
		"raid_survived", DEFAULT_RAID_SURVIVED))


## Диапазон узлового XP (one-time) — xp.json sources.node.range (200–800).
static func node_xp_range() -> Array:
	var r: Variant = (_config().get("sources", {}) as Dictionary).get("node", {})
	if r is Dictionary:
		var range_: Variant = (r as Dictionary).get("range", [])
		if range_ is Array and (range_ as Array).size() == 2:
			return [int((range_ as Array)[0]), int((range_ as Array)[1])]
	return DEFAULT_NODE_RANGE.duplicate()


## Уровень по накопленному XP (1..max_level, кап K-M13).
static func level_for_xp(xp: int) -> int:
	var t := thresholds()
	var level := MIN_LEVEL
	for i in range(1, t.size()):
		if xp >= int(t[i]):
			level = i + 1
	return clampi(level, MIN_LEVEL, max_level())


## Начислить XP члену партии; уровень поднимается сразу (вызов — ПОСЛЕ боя,
## 02-mechanics §3.2 EC3: апгрейд в середине боя применяется после).
## Возвращает {ok, from_level, to_level, level_ups}.
static func grant_xp(member: Dictionary, amount: int) -> Dictionary:
	if amount < 0:
		return {"ok": false, "reason": "xp_negative"}
	var from_level := level_for_xp(int(member.get("xp", 0)))
	var new_xp := int(member.get("xp", 0)) + amount
	var to_level := level_for_xp(new_xp)
	member["xp"] = new_xp
	member["level"] = to_level
	return {"ok": true, "from_level": from_level, "to_level": to_level,
		"level_ups": to_level - from_level}


## XP за бой (07-balance §3, xp.json sources.combat): 100 × CR × (1 + 0.1n),
## n — число врагов. Победа только: ничья = Престиж/Слава/опыт 0
## (07-balance §4, D-128).
static func xp_from_battle(cr: float, enemy_count: int) -> int:
	if cr <= 0.0 or enemy_count < 1:
		return 0
	return int(round(100.0 * cr * (1.0 + 0.1 * float(enemy_count))))


## XP за узел (one-time, 07-balance §3): кламп в диапазон 200–800
## (xp.json sources.node.range; лут узлов — строки P-6 / node_loot).
static func xp_from_node(node_xp: int) -> int:
	var r := node_xp_range()
	return clampi(node_xp, int(r[0]), int(r[1]))


## ASI (K3): +2 к одной или +1 к двух; потолок 16. Выбор характеристики —
## за игроком (UI); здесь — применение. Ключи stats — нижний регистр (сейв).
static func apply_asi(member: Dictionary, ability: String, amount: int) -> bool:
	var key := ability.to_lower()
	if not ASI_ABILITIES.has(key) or (amount != 1 and amount != 2):
		return false
	if not member.has("stats") or not (member["stats"] is Dictionary):
		return false
	var stats: Dictionary = member["stats"]
	stats[key] = mini(int(stats.get(key, 10)) + amount, ASI_CAP)
	return true


## Потери боя (battle_report.losses — uid жителей / id членов партии):
## READY → DEAD (смерть перманентна, 02-mechanics §3.2 SM). Возвращает число
## выбывших членов партии.
static func apply_losses(party: Array, losses: Array) -> int:
	var dead := 0
	for member in party:
		if not (member is Dictionary):
			continue
		if str(member.get("state", STATE_READY)) == STATE_DEAD:
			continue
		var hit := false
		for loss in losses:
			if int(member.get("uid", -1)) == int(loss) \
					or (str(member.get("id", "")) != "" and str(member.get("id", "")) == str(loss)):
				hit = true
				break
		if hit:
			member["state"] = STATE_DEAD
			dead += 1
	return dead


## Wipe (R1): партия непуста и все DEAD → конец кампании (DEFEAT); сейв и
## Престиж сохраняются (02-mechanics §3.2 EC1: нет «game over без возврата»).
static func is_wiped(party: Array) -> bool:
	if party.is_empty():
		return false
	for member in party:
		if member is Dictionary and str(member.get("state", STATE_READY)) != STATE_DEAD:
			return false
	return true


## K-M11: смерть героя в бою → «утрата» партии: штраф 2 на спасброски
## (категория страха/очарования) до конца боя — модификатор, не шкала.
## Возвращает ступень утраты (0/1); потребитель — боевой слой (многокомбатантный
## бой партии — за срезом; в MVP 1v1 смерть героя = конец боя).
static func loss_stage(hero_alive: bool) -> int:
	return 0 if hero_alive else 1


## Живые члены партии (state != DEAD; WOUNDED — живой, D-220/D4).
static func alive_members(party: Array) -> Array:
	var out: Array = []
	for member in party:
		if member is Dictionary and str(member.get("state", STATE_READY)) != STATE_DEAD:
			out.append(member)
	return out


## ═════════════════════════════════════════════════════════════════════════
## V-5 (D-220): упрощённый персистентный HP + REST. Чистые функции (I1):
## одинаковые входы → одинаковые выходы; мутация — только переданных
## Dictionary (члены партии / массив ростера).

## max_hp всех членов партии — hp warrior-статблока (D2: герой-прокси MVP;
## класс-маппинг — вне V-5). campaign.json unit_statblocks.warrior.hp.
static func hero_max_hp() -> int:
	var sb: Variant = _campaign_config().get("unit_statblocks", {})
	if sb is Dictionary:
		var w: Variant = (sb as Dictionary).get("warrior", {})
		if w is Dictionary:
			var hp: int = int((w as Dictionary).get("hp", 0))
			if hp > 0:
				return hp
		push_warning("PartySystem: unit_statblocks.warrior.hp не найден — фолбэк %d" % DEFAULT_HERO_MAX_HP)
	return DEFAULT_HERO_MAX_HP


## V-5 (D-220): идемпотентная миграция/инициализация полей HP члена.
## Правила (план V-5 §2): нет max_hp → hero_max_hp(); DEAD — не воскрешаем;
## жив без current_hp → current_hp = max_hp; жив с current_hp ≤ 0 → 1 + WOUNDED.
## Повторный вызов не меняет валидное состояние (идемпотентность).
static func ensure_hp(member: Dictionary) -> void:
	if not (member is Dictionary):
		return
	if not member.has("max_hp") or int(member.get("max_hp", 0)) <= 0:
		member["max_hp"] = hero_max_hp()
	if str(member.get("state", STATE_READY)) == STATE_DEAD:
		return  # мёртвые не воскрешаем (боевой ресурс — 0 или отсутствует)
	if not member.has("current_hp"):
		member["current_hp"] = int(member["max_hp"])  # живой без current_hp → полный
	elif int(member["current_hp"]) <= 0:
		member["current_hp"] = 1  # живой с ≤0 → 1 + ближайшее ранение (D-220)
		member["state"] = STATE_WOUNDED


## V-5 (D-220): REST в городе. Живые (READY/WOUNDED) → current_hp = max_hp,
## state = READY (излечимые снимаются); DEAD не восстанавливаются.
## Идемпотентен. Возвращает {rested} — число восстановленных.
static func rest(party: Array) -> Dictionary:
	var rested := 0
	for member in party:
		if not (member is Dictionary):
			continue
		if str(member.get("state", STATE_READY)) == STATE_DEAD:
			continue
		member["current_hp"] = int(member.get("max_hp", hero_max_hp()))
		member["state"] = STATE_READY
		rested += 1
	return {"rested": rested}


## V-5 (D-220): результат боя → член партии (персистентный HP). Правила
## (план V-5 §4): dead → DEAD/0; hp > 0 → current_hp = hp (статус не
## меняется — WOUNDED живёт до REST'а); hp ≤ 0 (выжил по death saves) →
## 1 + WOUNDED. Мутация — только `member`.
static func apply_battle_result(member: Dictionary, final_hp: int, dead: bool) -> void:
	if not (member is Dictionary):
		return
	if dead:
		member["state"] = STATE_DEAD
		member["current_hp"] = 0
		return
	if final_hp > 0:
		member["current_hp"] = final_hp
		return
	member["current_hp"] = 1  # выжил с 0 → 1 HP + ранение (D-220)
	member["state"] = STATE_WOUNDED


## ─────────────────────────────────────────────────────────────────────────────
## Ветеран (party-characters 3.1, Q-M56→(а), K-M10, D-189): статус пережившего
## бойца (не юнит/ярус). Счётчик battles_survived — входная величина (сейв);
## порог N — баланс-кран F4 (campaign.json → veteran.battles_to_veteran);
## бонус — +1 ступень к спасам/проверкам до конца боя (применение — боевой
## слой T-116; MVP-бой 1v1 авто — за срезом, здесь — только статус и значение).
## Чистые функции: без ГСЧ, одинаковые входы → одинаковые выходы (I1).

## Фолбэк-конфиг (только при неисправном campaign.json, push_warning).
const DEFAULT_VETERAN_BATTLES := 5
const DEFAULT_VETERAN_STEP := 1

static var _campaign_cfg: Dictionary = {}


static func _campaign_config() -> Dictionary:
	if _campaign_cfg.is_empty():
		var file := FileAccess.open(CAMPAIGN_JSON, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_campaign_cfg = parsed
			else:
				push_warning("PartySystem: campaign.json не распарсился — ветеран-фолбэк")
		else:
			push_warning("PartySystem: %s не найден — ветеран-фолбэк" % CAMPAIGN_JSON)
	return _campaign_cfg


## Порог N боёв для статуса Ветеран — campaign.json veteran.battles_to_veteran
## (баланс-кран F4; Фазa 3 = ходы 14–17, 03-progression).
static func veteran_threshold() -> int:
	var v: Variant = _campaign_config().get("veteran", {})
	if v is Dictionary:
		return maxi(1, int((v as Dictionary).get("battles_to_veteran", DEFAULT_VETERAN_BATTLES)))
	return DEFAULT_VETERAN_BATTLES


## Ступень бонуса Ветерана к спасам/проверкам — campaign.json
## veteran.save_step_bonus (канон +1, K-M10).
static func veteran_save_step() -> int:
	var v: Variant = _campaign_config().get("veteran", {})
	if v is Dictionary:
		return int((v as Dictionary).get("save_step_bonus", DEFAULT_VETERAN_STEP))
	return DEFAULT_VETERAN_STEP


## Статус Ветеран: пережито боёв (battles_survived) ≥ порога N.
static func is_veteran(member: Dictionary) -> bool:
	if not (member is Dictionary):
		return false
	return int(member.get("battles_survived", 0)) >= veteran_threshold()


## Бонус Ветерана к спасам/проверкам: +N ступеней если Ветеран, иначе 0.
## Потребитель — боевой слой T-116 (до конца боя); MVP-бой 1v1 авто — за срезом.
static func veteran_bonus(member: Dictionary) -> int:
	return veteran_save_step() if is_veteran(member) else 0


## Отметить пережитый бой: +1 к battles_survived у каждого ЖИВОГО члена
## (вызов — ПОСЛЕ apply_losses: павшие в этом бою неincrement-ятся). Возвращает
## число отмеченных членов.
static func record_battle_survival(party: Array) -> int:
	var marked := 0
	for member in party:
		if not (member is Dictionary):
			continue
		if str(member.get("state", STATE_READY)) == STATE_DEAD:
			continue
		member["battles_survived"] = int(member.get("battles_survived", 0)) + 1
		marked += 1
	return marked
