class_name TelemetryLog
extends RefCounted
## campaign-core-loop 2.1–2.4 (GDD 01-core-loop «Метрики валидации core loop»):
## структурированная телеметрия — лог сессии. Дизайн-решение #2: метрики =
## телеметрия событий, а не расчёт внутри симуляции — события
## `action{type, choice_count}`, `loop_closed`, `replan_after_tooltip`
## пишутся в лог сессии; отчёт — post-hoc анализ (playtest). Headless
## симуляция метрики не считает (нет «игрока»).
##
## I1: метка времени события = ход кампании (детерминированно); wall-clock
## `t` (секунды) добавляет UI-слой в playtest (опциональное поле события).
## Лог сессии — артефакт сессии, НЕ часть кампанийного сейва (T-110-схема
## не расширяется).

## Цели GDD (01-core-loop, таблица метрик; D1/D7 — playtest, 09-risks):
const TTFD_MAX_SECONDS := 30.0            # старт → первое осмысленное действие
const ACTION_RATE_MIN_PER_5MIN := 8.0     # осмысленных действий / 5 мин
const ACTION_RATE_MAX_PER_5MIN := 15.0
const DECISION_RATIO_MIN := 0.6           # действия с choice_count ≥ 2
const DECISION_CHOICE_COUNT := 2
const LOOP_CLOSED_MIN_PER_SESSION := 1    # сессия с ≥1 полным циклом
const SESSION_MIN_SECONDS := 35.0 * 60.0  # длина сессии 35–50 мин
const SESSION_MAX_SECONDS := 50.0 * 60.0
const REPLAN_MAX_SECONDS := 10.0 * 60.0   # aha: первая перепланировка ≤ 10 мин
const LOOP_CLOSURE_RATE_MIN := 0.7        # сессии с ≥1 полным циклом, доля

var current_turn: int = 1
var events: Array = []


func set_turn(turn: int) -> void:
	current_turn = maxi(1, int(turn))


## Событие в лог; `turn` проставляется автоматически (I1). `data` может нести
## `t` (wall-clock секунды, UI/playtest); явный `turn` в `data` не затирается.
func record(event: String, data: Dictionary = {}) -> void:
	var e := data.duplicate()
	e["event"] = event
	if not e.has("turn"):
		e["turn"] = current_turn
	events.append(e)


func count(event: String) -> int:
	var n := 0
	for e in events:
		if e is Dictionary and str((e as Dictionary).get("event", "")) == event:
			n += 1
	return n


func events_of(event: String) -> Array:
	var out: Array = []
	for e in events:
		if e is Dictionary and str((e as Dictionary).get("event", "")) == event:
			out.append(e)
	return out


## 2.4: post-hoc отчёт по метрикам из лога сессии (GDD-псевдокод
## `on_session_end: log {duration, actions, loops_closed, ...}`).
## Wall-clock `t` (секунды) нужен для временных метрик; без него — только
## счётчики, временные метрики = -1.0, их pass = null (не вычислимо).
static func compute_metrics(events: Array) -> Dictionary:
	var first_t := -1.0
	var last_t := -1.0
	var start_t := -1.0
	var first_action_t := -1.0
	var first_replan_t := -1.0
	var actions := 0
	var decisions := 0
	var loops := 0
	for e in events:
		if not (e is Dictionary):
			continue
		var ev := e as Dictionary
		var name := str(ev.get("event", ""))
		var t := _wall_clock(ev)
		if t >= 0.0:
			if first_t < 0.0:
				first_t = t
			last_t = maxf(last_t, t)
		if name == "game_start" and start_t < 0.0 and t >= 0.0:
			start_t = t
		elif name == "action":
			actions += 1
			if int(ev.get("choice_count", 0)) >= DECISION_CHOICE_COUNT:
				decisions += 1
			if first_action_t < 0.0 and t >= 0.0:
				first_action_t = t
		elif name == "loop_closed":
			loops += 1
		elif name == "replan_after_tooltip" and first_replan_t < 0.0 and t >= 0.0:
			first_replan_t = t
	var duration := -1.0
	if first_t >= 0.0:
		duration = last_t - first_t
	var ttfd := -1.0
	if start_t >= 0.0 and first_action_t >= 0.0:
		ttfd = first_action_t - start_t
	var rate := -1.0
	if duration > 0.0:
		rate = float(actions) / (duration / 300.0)
	var decision_ratio := -1.0
	if actions > 0:
		decision_ratio = float(decisions) / float(actions)
	var replan_after := -1.0
	if start_t >= 0.0 and first_replan_t >= 0.0:
		replan_after = first_replan_t - start_t
	return {
		"actions": actions,
		"decisions": decisions,
		"loops_closed": loops,
		"duration_seconds": duration,
		"ttfd_seconds": ttfd,
		"action_rate_per_5min": rate,
		"decision_ratio": decision_ratio,
		"replan_after_tooltip_seconds": replan_after,
		"pass": {
			"ttfd": _pass(ttfd, 0.0, TTFD_MAX_SECONDS),
			"action_rate": _pass(rate, ACTION_RATE_MIN_PER_5MIN,
					ACTION_RATE_MAX_PER_5MIN),
			"decision_ratio": _pass(decision_ratio, DECISION_RATIO_MIN, INF),
			"loop_closed": loops >= LOOP_CLOSED_MIN_PER_SESSION,
			"session_length": _pass(duration, SESSION_MIN_SECONDS,
					SESSION_MAX_SECONDS),
			"replan_after_tooltip": _pass(replan_after, 0.0, REPLAN_MAX_SECONDS),
		},
	}


## Меж-сессийная агрегация (GDD: «Закрытость цикла: сессии с ≥1 полным
## циклом … ≥ 70%»): доля сессий с pass.loop_closed. `sessions` — массив
## отчётов compute_metrics(); -1.0 — пусто.
static func loop_closure_rate(sessions: Array) -> float:
	if sessions.is_empty():
		return -1.0
	var n := 0
	for s in sessions:
		if s is Dictionary:
			var pass_: Dictionary = (s as Dictionary).get("pass", {}) as Dictionary
			if bool(pass_.get("loop_closed", false)):
				n += 1
	return float(n) / float(sessions.size())


## null — метрика не вычислима (нет wall-clock), иначе bool по цели GDD.
static func _pass(value: float, min_v: float, max_v: float) -> Variant:
	if value < 0.0:
		return null
	return value >= min_v and value <= max_v


static func _wall_clock(ev: Dictionary) -> float:
	var t = ev.get("t", -1)
	if t is int:
		return float(t)
	if t is float:
		return t
	return -1.0


func to_dict() -> Dictionary:
	return {"turn": current_turn, "events": events.duplicate()}


static func from_dict(data: Dictionary) -> TelemetryLog:
	var log := TelemetryLog.new()
	log.current_turn = int(data.get("turn", 1))
	for e in data.get("events", []):
		if e is Dictionary:
			log.events.append((e as Dictionary).duplicate())
	return log
