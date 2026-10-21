class_name PregameFlowModel
extends RefCounted

## pregame-flow (Q18, 6 шагов до хода 1): headless-логика предыгрового потока.
## Чистая логика (без сцены) — UI (конструктор, земной шар, города, партия,
## тренировка) привязывается к этим функциям; headless-тестируемо (4.x).
##
## 6 шагов (00-overview «Предыгровой поток (Q18) [КАНОН]»):
##   конструктор → знак → земной шар → города → партия → тренировка.
## Реализовано ранее: конструктор (character_creation_ui.gd), знак (T-002),
## земной шар (region-graph-map). Здесь — headless-логика шагов: playable-маска,
## штраф оккупации, стартовая партия, тренировка-как-база.

## C-15 (владелец 2026-10-04): playable slice 3 — люди/полуорки/эльфы.
## Маска не эксплицитна в mvp_catalog.json (7 рас) → фиксируем здесь (задача 2.1).
const PLAYABLE_RACES: Array[String] = ["humans", "half_orcs", "elves"]

## 02-mechanics §3.2: партия ≤5 (попутчики).
const MAX_COMPANIONS := 5

## 02-mechanics §3.1: города — сколько угодно.
const FREE_CITIES := 2

## V-4 (D-219, 2026-10-20): штраф оккупации — ступенчатая кривая по ВРЕМЕНИ
## под оккупацией (детерминированно, с капом). Заменяет [ПРЕДЛОЖЕНИЕ] плоский
## base 10 (по числу городов). 0 ходов → 0; 1–2 → −1; 3–4 → −2; 5+ → −3 (кап).
## Штраф — модификатор (отрицательный) к городскому выходу/тренировке.
const OCCUPATION_PENALTY_MAX := 3

## 2.5 (Q18): источники юнитов для тренировки (город = база тренировки).
## «Попутчики тренируются, а не нанимаются»; модель наёмного рынка вытеснена.
const TRAINING_SOURCES: Array[String] = ["city_resident", "companion", "event_npc"]

## 4.1 (Q18, 00-overview [КАНОН]): порядок 6 шагов предыгрового потока:
## конструктор → знак → земной шар → города → партия → тренировка.
## Ход 1 начинается только после завершения всех шести (spec: Pregame sequence).
const FLOW_STEPS: Array[String] = [
	"constructor", "sign", "globe", "cities", "party", "training",
]


## 4.1: состояние предыгрового потока (headless; UI привязывается к нему —
## deferred, ux-review). Детерминированно: без RNG и UI. Шаги завершаются
## только по порядку (advance()); пропусков и повторного входа нет.
class PregameFlow:
	var _completed: int = 0

	func step_count() -> int:
		return FLOW_STEPS.size()

	## Канонический порядок шагов (снимок: мутация не затрагивает модель).
	func steps() -> Array:
		return FLOW_STEPS.duplicate()

	## Текущий шаг ("" — поток завершён).
	func current_step() -> String:
		if _completed >= FLOW_STEPS.size():
			return ""
		return FLOW_STEPS[_completed]

	func completed_steps() -> int:
		return _completed

	## Завершает текущий шаг. true — шаг завершён; false — поток уже
	## завершён (no-op, за пределами порядка не уходить).
	func advance() -> bool:
		if _completed >= FLOW_STEPS.size():
			return false
		_completed += 1
		return true

	func is_complete() -> bool:
		return _completed >= FLOW_STEPS.size()

	## Ход 1 начинается только когда все 6 шагов завершены (spec: "turn 1
	## does not start until all steps are complete").
	func can_start_turn_1() -> bool:
		return is_complete()


## 2.1/3.2 (C-15): playable-раса? (маска 3: люди/полуорки/эльфы).
static func is_playable_race(race_id: String) -> bool:
	return PLAYABLE_RACES.has(race_id)


## V-4 (D-219): штраф оккупации по времени под оккупацией. Ступенчатая кривая
## с капом: 0 ходов → 0; 1–2 → −1; 3–4 → −2; 5+ → −3 (кап −3). Детерминированно,
## без случайных штрафов и каскадной непроходимости. Возвращает модификатор
## (≤ 0), применяемый к городскому выходу/тренировке/существующим модификаторам.
static func occupation_penalty(turns_occupied: int) -> int:
	var t := maxi(turns_occupied, 0)
	if t <= 0:
		return 0
	if t <= 2:
		return -1
	if t <= 4:
		return -2
	return -OCCUPATION_PENALTY_MAX


## V-4 (D-219): после освобождения штраф уменьшается на 1 за каждый полный ход
## до 0. penalty_at_liberation — штраф в момент освобождения (≤ 0).
## Возвращает текущий модификатор (≤ 0): −3 → −2 → −1 → 0 (кап 0).
static func occupation_penalty_after_liberation(
	turns_since_liberation: int,
	penalty_at_liberation: int
) -> int:
	var p := mini(penalty_at_liberation, 0)
	var recovered := maxi(turns_since_liberation, 0)
	return mini(p + recovered, 0)


## 2.4: валидация стартовой партии: ≤5 попутчиков, у каждого класс/раса/внешний
## вид (§3.2). Возвращает {valid, errors[]}.
static func validate_starting_party(companions: Array) -> Dictionary:
	var errors: Array = []
	if companions.size() > MAX_COMPANIONS:
		errors.append("party_exceeds_%d" % MAX_COMPANIONS)
	for i in range(companions.size()):
		var c = companions[i]
		if not (c is Dictionary):
			errors.append("companion_%d_not_dict" % i)
			continue
		if str(c.get("class", "")).is_empty():
			errors.append("companion_%d_no_class" % i)
		if str(c.get("race", "")).is_empty():
			errors.append("companion_%d_no_race" % i)
		if str(c.get("appearance", "")).is_empty():
			errors.append("companion_%d_no_appearance" % i)
	return {"valid": errors.is_empty(), "errors": errors}


## 2.5: допустимые источники тренировки (канон Q18).
static func training_sources() -> Array:
	return TRAINING_SOURCES.duplicate()


## 2.5: источник допустим для тренировки (не наём)?
static func is_trainable_source(source: String) -> bool:
	return TRAINING_SOURCES.has(source)
