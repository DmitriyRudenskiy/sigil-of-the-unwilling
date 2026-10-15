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
## Срез MVP: бой — 1v1 авто-разрешение (T-050), внутрибоевые WOUNDED/UNSTABLE
## не персистятся (потери = DEAD, раненые — не потери, слой T-116); REST/лечение
## и замена мёртвых (наёмник ур. города−1) — с боем партии (за срезом).

## Пороги XP (SRD) — канон: 02-mechanics §3.2, 07-balance §3; уровни 2–5.
## K-M13: пороги никогда не правятся — при нестыковке бюджета правятся источники.
const XP_THRESHOLDS: Array[int] = [0, 2700, 6500, 15000, 38000]
const MAX_LEVEL := 5
const MIN_LEVEL := 1

## Источники XP (07-balance §3, R4): бой 100×CR×(1+0.1n); узел (one-time) 200–800;
## рейд пережит 300. «Район создан» — не источник (K-M16).
const XP_RAID_SURVIVED := 300
const NODE_XP_MIN := 200
const NODE_XP_MAX := 800

## ASI (K3, 5e): +2 к одной или +1 к двум; практический потолок 16.
## Удача (7-я хар-ка) — не объект ASI: расовый модификатор (каталог, K-M5).
const ASI_CAP := 16
const ASI_ABILITIES: Array[String] = ["str", "dex", "con", "int", "wis", "cha"]

const STATE_READY := "READY"
const STATE_DEAD := "DEAD"


## Уровень по накопленному XP (1..5, кап K-M13).
static func level_for_xp(xp: int) -> int:
	var level := MIN_LEVEL
	for i in range(1, XP_THRESHOLDS.size()):
		if xp >= XP_THRESHOLDS[i]:
			level = i + 1
	return clampi(level, MIN_LEVEL, MAX_LEVEL)


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


## XP за бой (07-balance §3): 100 × CR × (1 + 0.1n), n — число врагов.
## Победа только: ничья = Престиж/Слава/опыт 0 (07-balance §4, D-128).
static func xp_from_battle(cr: float, enemy_count: int) -> int:
	if cr <= 0.0 or enemy_count < 1:
		return 0
	return int(round(100.0 * cr * (1.0 + 0.1 * float(enemy_count))))


## XP за узел (one-time, 07-balance §3): 200–800 (лут узлов — строки P-6).
static func xp_from_node(node_xp: int) -> int:
	return clampi(node_xp, NODE_XP_MIN, NODE_XP_MAX)


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


## Живые члены партии (state != DEAD).
static func alive_members(party: Array) -> Array:
	var out: Array = []
	for member in party:
		if member is Dictionary and str(member.get("state", STATE_READY)) != STATE_DEAD:
			out.append(member)
	return out
