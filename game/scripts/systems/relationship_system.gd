class_name RelationshipSystem
extends RefCounted
## team-romance-roleplay D4/D5: отношения команды — связи, стадии, тик хода.
## Паттерн CharismaEvents: static + set_rng — детерминизм через session seed.
## process_turn() чистый: возвращает список событий, применение последствий —
## в HeroRelationshipsComponent.end_turn (сигналы GameEventBus, сцены).

const BOND_MIN := -100
const BOND_MAX := 100
const TRUST_MIN := 0
const TRUST_MAX := 100
const ROMANCE_MIN := 0
const ROMANCE_MAX := 100

# Социальные стадии (bond)
const STAGE_STRANGER := 0
const STAGE_FRIEND := 1
const STAGE_CLOSE_FRIEND := 2
# Романтические стадии (romance)
const ROM_NONE := 0
const ROM_FLIRT := 1
const ROM_RELATIONSHIP := 2
const ROM_ENGAGED := 3
const ROM_MARRIED := 4

const BOND_FRIEND := 30
const BOND_CLOSE := 60
const BOND_CONFLICT := -30
const ROM_FLIRT_AT := 25
const ROM_RELATIONSHIP_AT := 50
const ROM_ENGAGED_AT := 75
const ROM_MARRIED_AT := 100
const TRUST_BETRAYAL := 20
const PASSIVE_BOND_PER_TURN := 1
const PASSIVE_ROMANCE_PER_TURN := 1
const JEALOUSY_BOND_PENALTY := -20
const JEALOUSY_TRUST_PENALTY := -15
const CONFLICT_ROLL_DC := 3  # r20 < 3 → конфликт (при bond < -30)
const RECONCILE_DC := 12     # примирение: d20 + cha/2 vs 12

static var _rng := RandomNumberGenerator.new()

static func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng

# ═══════════════════════════════════════════
#  ОРИЕНТАЦИИ И СОВМЕСТИМОСТЬ (D4)
# ═══════════════════════════════════════════

## Совместима ли романтика: ориентация последователя × пол героя.
static func compatible(hero_sex: String, follower_sex: StringName, orientation: StringName) -> bool:
	if orientation == &"bi":
		return true
	var same := String(follower_sex) == hero_sex
	if orientation == &"homo":
		return same
	return not same  # hetero (дефолт)

# ═══════════════════════════════════════════
#  СТАДИИ (вычисляемые, D3)
# ═══════════════════════════════════════════

static func stage_of(bond: int) -> int:
	if bond >= BOND_CLOSE:
		return STAGE_CLOSE_FRIEND
	if bond >= BOND_FRIEND:
		return STAGE_FRIEND
	return STAGE_STRANGER

static func romance_stage(romance: int) -> int:
	if romance >= ROM_MARRIED_AT:
		return ROM_MARRIED
	if romance >= ROM_ENGAGED_AT:
		return ROM_ENGAGED
	if romance >= ROM_RELATIONSHIP_AT:
		return ROM_RELATIONSHIP
	if romance >= ROM_FLIRT_AT:
		return ROM_FLIRT
	return ROM_NONE

static func stage_name(stage: int, is_romance: bool = false) -> String:
	if is_romance:
		match stage:
			ROM_FLIRT: return "Флирт"
			ROM_RELATIONSHIP: return "Отношения"
			ROM_ENGAGED: return "Помолвка"
			ROM_MARRIED: return "Брак"
		return "—"
	match stage:
		STAGE_FRIEND: return "Друг"
		STAGE_CLOSE_FRIEND: return "Близкий друг"
	return "Незнакомец"

# ═══════════════════════════════════════════
#  ИЗМЕНЕНИЕ СВЯЗЕЙ (клины, гейт романтики)
# ═══════════════════════════════════════════

## Применяет deltas {bond, trust, romance} к паре. Возвращает фактически
## применённые дельты (romance при несовместимой ориентации → 0).
static func modify(
	rel: HeroRelationshipsComponent,
	hero_sex: String,
	follower: Follower,
	deltas: Dictionary
) -> Dictionary:
	var applied := {"bond": 0, "trust": 0, "romance": 0}
	if rel == null or follower == null:
		return applied
	var p: Dictionary = rel.pair(follower.uid)
	if deltas.has("bond"):
		var before := int(p["bond"])
		p["bond"] = clampi(before + int(deltas["bond"]), BOND_MIN, BOND_MAX)
		applied["bond"] = int(p["bond"]) - before
	if deltas.has("trust"):
		var before_t := int(p["trust"])
		p["trust"] = clampi(before_t + int(deltas["trust"]), TRUST_MIN, TRUST_MAX)
		applied["trust"] = int(p["trust"]) - before_t
	if deltas.has("romance"):
		var d := int(deltas["romance"])
		if not compatible(hero_sex, follower.gender, follower.orientation):
			applied["romance"] = 0  # гейт: romance фиксируется
		else:
			var before_r := int(p["romance"])
			p["romance"] = clampi(before_r + d, ROMANCE_MIN, ROMANCE_MAX)
			applied["romance"] = int(p["romance"]) - before_r
	return applied

## Брак: помечает пару как spouse (неотменяемо, D3).
static func marry(rel: HeroRelationshipsComponent, uid: int) -> void:
	if rel == null:
		return
	var p: Dictionary = rel.pair(uid)
	p["spouse"] = true
	p["romance"] = ROMANCE_MAX
	p["last_romance_stage"] = ROM_MARRIED

# ═══════════════════════════════════════════
#  ТИК ХОДА (D5)
# ═══════════════════════════════════════════

## Конец хода героя: пассивный рост, верность, ревность, конфликты, стадии.
## Возвращает события: {type: stage_changed|betrayal|jealousy|conflict|marriage_ready}
## Предательство/ревность применяются к связям сразу; уход из команды и сцены —
## на стороне вызывающего (HeroRelationshipsComponent.end_turn).
static func process_turn(hero, rel: HeroRelationshipsComponent) -> Array:
	var events: Array = []
	if hero == null or rel == null:
		return events
	var hero_sex: String = "male"
	if hero.stats_comp != null:
		hero_sex = String(hero.stats_comp.sex)
	var betrayed: Array = []
	# 1) Пассивный рост + верность + стадии + брак
	for f in hero.followers:
		if f == null:
			continue
		var p: Dictionary = rel.pair(f.uid)
		p["bond"] = clampi(int(p["bond"]) + PASSIVE_BOND_PER_TURN, BOND_MIN, BOND_MAX)
		# Пассивная романтика: близкие друзья + совместимая ориентация (риск-митигация)
		if (int(p["bond"]) >= BOND_CLOSE
				and not bool(p["spouse"])
				and compatible(hero_sex, f.gender, f.orientation)):
			p["romance"] = clampi(int(p["romance"]) + PASSIVE_ROMANCE_PER_TURN, ROMANCE_MIN, ROMANCE_MAX)
		# 2) Верность: trust < 20 → r20 > trust → предательство
		# (шанс = (20−trust)/20: trust 19 → 5%, trust 0 → 100%)
		if int(p["trust"]) < TRUST_BETRAYAL:
			var roll := _rng.randi_range(1, 20)
			if roll > int(p["trust"]):
				betrayed.append(f)
				events.append({"type": "betrayal", "uid": int(f.uid)})
				continue
		# Переходы стадий (кэш last_*_stage)
		var bond_stage := stage_of(int(p["bond"]))
		var rom_stage := romance_stage(int(p["romance"]))
		if bond_stage != int(p.get("last_bond_stage", 0)):
			events.append({"type": "stage_changed", "uid": int(f.uid), "stage": bond_stage, "is_romance": false})
			p["last_bond_stage"] = bond_stage
		if rom_stage != int(p.get("last_romance_stage", 0)):
			if rom_stage == ROM_MARRIED and not bool(p["spouse"]):
				events.append({"type": "marriage_ready", "uid": int(f.uid)})
			else:
				events.append({"type": "stage_changed", "uid": int(f.uid), "stage": rom_stage, "is_romance": true})
			p["last_romance_stage"] = rom_stage
	# Уход предавших (связи удаляются)
	for f in betrayed:
		hero.followers.erase(f)
		rel.remove_follower(int(f.uid))
	# 3) Ревность: пары последователей, у обоих romance к герою ≥ 50 (однократно)
	var uids: Array[int] = []
	for f in hero.followers:
		if f != null:
			uids.append(int(f.uid))
	uids.sort()
	for i in uids.size():
		for j in range(i + 1, uids.size()):
			var pa: Dictionary = rel.pair(uids[i])
			var pb: Dictionary = rel.pair(uids[j])
			if int(pa["romance"]) >= ROM_RELATIONSHIP_AT and int(pb["romance"]) >= ROM_RELATIONSHIP_AT:
				var d: Dictionary = rel.duo(uids[i], uids[j])
				if not bool(d["jealousy_fired"]):
					d["jealousy_fired"] = true
					pa["bond"] = clampi(int(pa["bond"]) + JEALOUSY_BOND_PENALTY, BOND_MIN, BOND_MAX)
					pa["trust"] = clampi(int(pa["trust"]) + JEALOUSY_TRUST_PENALTY, TRUST_MIN, TRUST_MAX)
					pb["bond"] = clampi(int(pb["bond"]) + JEALOUSY_BOND_PENALTY, BOND_MIN, BOND_MAX)
					pb["trust"] = clampi(int(pb["trust"]) + JEALOUSY_TRUST_PENALTY, TRUST_MIN, TRUST_MAX)
					events.append({"type": "jealousy", "uid_a": uids[i], "uid_b": uids[j]})
	# 4) Конфликты: bond < -30 → r20 < 3 → сцена (флаг conflict_pending против спама)
	for f in hero.followers:
		if f == null:
			continue
		var p2: Dictionary = rel.pair(f.uid)
		if int(p2["bond"]) < BOND_CONFLICT and not bool(p2.get("conflict_pending", false)):
			var roll2 := _rng.randi_range(1, 20)
			if roll2 < CONFLICT_ROLL_DC:
				p2["conflict_pending"] = true
				events.append({"type": "conflict", "uid": int(f.uid)})
	return events

## Примирение: d20 + cha/2 vs RECONCILE_DC. Успех → bond +30, конфликт снят.
static func try_reconcile(rel: HeroRelationshipsComponent, uid: int, cha: int) -> bool:
	if rel == null:
		return false
	var p: Dictionary = rel.pair(uid)
	p["conflict_pending"] = false
	var roll := _rng.randi_range(1, 20)
	if roll + cha / 2 >= RECONCILE_DC:
		p["bond"] = clampi(int(p["bond"]) + 30, BOND_MIN, BOND_MAX)
		return true
	p["bond"] = clampi(int(p["bond"]) - 10, BOND_MIN, BOND_MAX)
	return false

## Разрыв: последователь покидает команду.
static func sever(hero, rel: HeroRelationshipsComponent, uid: int) -> void:
	if hero == null or rel == null:
		return
	for f in hero.followers:
		if f != null and int(f.uid) == uid:
			hero.followers.erase(f)
			break
	rel.remove_follower(uid)
