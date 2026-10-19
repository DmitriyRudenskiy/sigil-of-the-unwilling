"""campaign-core-loop 2.1–2.4: телеметрия лог сессии (GDD 01-core-loop).

Дизайн-решение #2: метрики = телеметрия событий, а не расчёт внутри
симуляции. События `action{type, choice_count}`, `loop_closed`,
`replan_after_tooltip` → лог сессии; отчёт — post-hoc анализ (playtest).
I1: метка времени события = ход кампании (детерминированно); wall-clock
`t` (секунды) — опциональное поле (UI/playtest).
"""
extends BaseTest


func _composition(seed: int = 12345) -> CampaignComposition:
	return CampaignComposition.from_campaign_config(seed)


## Ход, в котором ударил первый рейд (детерминированно; floor K-R3 ≈ ход 7).
func _first_raid_turn(c: CampaignComposition) -> int:
	while not c.campaign.is_done():
		var before: int = c.campaign.current_turn
		c.advance_turn()
		if not (c.last_threat_report.get("raid", {}) as Dictionary).is_empty():
			return before
	return -1


## --- TelemetryLog: базовая механика ---

func test_record_stamps_turn_and_event() -> void:
	var log := TelemetryLog.new()
	log.set_turn(5)
	log.record("action", {"type": "build", "choice_count": 2})
	assert_int(log.events.size()).is_equal(1)
	var e: Dictionary = log.events[0]
	assert_str(str(e.get("event", ""))).is_equal("action")
	assert_int(int(e.get("turn", -1))).is_equal(5)
	assert_str(str(e.get("type", ""))).is_equal("build")
	assert_int(int(e.get("choice_count", -1))).is_equal(2)


func test_count_and_events_of() -> void:
	var log := TelemetryLog.new()
	log.record("action", {"type": "build"})
	log.record("action", {"type": "move"})
	log.record("loop_closed", {})
	assert_int(log.count("action")).is_equal(2)
	assert_int(log.count("loop_closed")).is_equal(1)
	assert_int(log.events_of("action").size()).is_equal(2)
	assert_int(log.count("nope")).is_equal(0)


func test_save_roundtrip() -> void:
	var log := TelemetryLog.new()
	log.set_turn(3)
	log.record("game_start", {"turn": 1})
	log.record("action", {"type": "fight", "choice_count": 1, "t": 42})
	var restored := TelemetryLog.from_dict(log.to_dict())
	assert_int(restored.current_turn).is_equal(3)
	assert_dict(restored.to_dict()).is_equal(log.to_dict())


## --- 2.1: action{type, choice_count} ---

func test_game_start_on_build() -> void:
	var c := _composition()
	assert_int(c.telemetry.count("game_start")).is_equal(1)
	var e: Dictionary = c.telemetry.events[0]
	assert_str(str(e.get("event", ""))).is_equal("game_start")
	assert_int(int(e.get("turn", -1))).is_equal(1)


func test_record_action_emits_event() -> void:
	var c := _composition()
	c.advance_turn()  # ход 1 → current_turn = 2
	c.record_action("build", 3)
	var evs := c.telemetry.events_of("action")
	assert_int(evs.size()).is_equal(1)
	var e: Dictionary = evs[0]
	assert_str(str(e.get("type", ""))).is_equal("build")
	assert_int(int(e.get("choice_count", -1))).is_equal(3)
	assert_int(int(e.get("turn", -1))).is_equal(2)


func test_record_action_unknown_verb_rejected() -> void:
	var c := _composition()
	c.record_action("dance", 1)
	assert_int(c.telemetry.count("action")).is_equal(0)


func test_fight_action_auto_emitted_on_raid() -> void:
	# Первый рейд (floor K-R3 ≈ ход 7): герой в городе → бой → авто-fight.
	var c := _composition()
	var raid_turn := _first_raid_turn(c)
	assert_int(raid_turn).is_greater(0)
	var evs := c.telemetry.events_of("action")
	# До рейда действий не было (headless, нет UI); на ходу рейда — fight.
	assert_int(evs.size()).is_equal(1)
	var e: Dictionary = evs[0]
	assert_str(str(e.get("type", ""))).is_equal("fight")
	assert_int(int(e.get("choice_count", -1))).is_equal(1)
	assert_int(int(e.get("turn", -1))).is_equal(raid_turn)


## --- 2.2: loop_closed ---

func test_loop_closed_on_full_cycle() -> void:
	# Полный цикл на ходу рейда: рейд + действие игрока + поход +
	# герой в городе к концу хода + ongoing.
	var c := _composition()
	var raid_turn := -1
	for i in range(21):
		c.record_action("build", 2)
		c.record_expedition()
		var before: int = c.campaign.current_turn
		c.advance_turn()
		if not (c.last_threat_report.get("raid", {}) as Dictionary).is_empty():
			raid_turn = before
			break
	assert_int(raid_turn).is_greater(0)
	var evs := c.telemetry.events_of("loop_closed")
	assert_int(evs.size()).is_equal(1)
	assert_int(int((evs[0] as Dictionary).get("turn", -1))).is_equal(raid_turn)


func test_loop_not_closed_without_expedition() -> void:
	# acted (UI + авто-fight) + рейд, но без похода → цикл не замкнут.
	var c := _composition()
	var raid_turn := -1
	for i in range(21):
		c.record_action("build", 2)
		var before: int = c.campaign.current_turn
		c.advance_turn()
		if not (c.last_threat_report.get("raid", {}) as Dictionary).is_empty():
			raid_turn = before
			break
	assert_int(raid_turn).is_greater(0)
	assert_int(c.telemetry.count("loop_closed")).is_equal(0)
	assert_int(c.telemetry.count("action")).is_greater(0)


func test_loop_not_closed_without_raid() -> void:
	# Ход 1: действия + «поход», но рейда нет (floor: ≈ ход 7) → нет цикла.
	var c := _composition()
	c.record_action("build", 2)
	c.record_expedition()
	c.advance_turn()
	assert_bool(
		(c.last_threat_report.get("raid", {}) as Dictionary).is_empty()
	).is_true()
	assert_int(c.telemetry.count("loop_closed")).is_equal(0)


func test_loop_not_closed_hero_away_at_turn_end() -> void:
	# Поход без возврата: герой в R02 к концу хода рейда → нет цикла
	# (рейд — авто-рейд R5, бой не ведётся).
	var probe := _composition()
	var raid_turn := _first_raid_turn(probe)
	assert_int(raid_turn).is_greater(0)
	var c := _composition()
	for i in range(raid_turn - 1):
		c.advance_turn()
	c.record_action("build", 2)
	c.record_expedition()
	c.region_map.food = 10.0
	var rep: Dictionary = c.region_map.travel("R02")
	assert_bool(bool(rep.get("ok", false))).is_true()
	c.advance_turn()  # ход рейда: герой в R02 → не возврат
	assert_int(c.telemetry.count("loop_closed")).is_equal(0)
	# Рейд всё же был (авто-рейд) — «увидел угрозу» да, «возврат» нет.
	assert_bool(
		not (c.last_threat_report.get("raid", {}) as Dictionary).is_empty()
	).is_true()


## --- 2.3: replan_after_tooltip ---

func test_replan_after_tooltip_event() -> void:
	var c := _composition()
	c.advance_turn()  # ход 1 → current_turn = 2
	c.record_replan_after_tooltip()
	var evs := c.telemetry.events_of("replan_after_tooltip")
	assert_int(evs.size()).is_equal(1)
	assert_int(int((evs[0] as Dictionary).get("turn", -1))).is_equal(2)


## --- 2.4: post-hoc отчёт по метрикам ---

func test_compute_metrics_full_session() -> void:
	# Сессия 40 мин: TTFD 20с, 20 действий (10 решений), 2 цикла,
	# replan на 5-й минуте.
	var events: Array = [
		{"event": "game_start", "turn": 1, "t": 0},
	]
	var t := 20.0
	for i in range(20):
		events.append({"event": "action", "turn": 1,
			"type": "build", "choice_count": 2 if i % 2 == 0 else 1, "t": t})
		t += 120.0  # 20 × 2 мин = 40 мин
	events.append({"event": "loop_closed", "turn": 2, "t": 600.0})
	events.append({"event": "replan_after_tooltip", "turn": 2, "t": 300.0})
	events.append({"event": "loop_closed", "turn": 3, "t": 2400.0})
	var m := TelemetryLog.compute_metrics(events)
	assert_int(int(m.get("actions", -1))).is_equal(20)
	assert_int(int(m.get("decisions", -1))).is_equal(10)
	assert_int(int(m.get("loops_closed", -1))).is_equal(2)
	assert_float(float(m.get("ttfd_seconds", -1.0))).is_equal_approx(20.0, 0.01)
	assert_float(float(m.get("decision_ratio", -1.0))).is_equal_approx(0.5, 0.001)
	var pass_: Dictionary = m.get("pass", {}) as Dictionary
	assert_bool(bool(pass_.get("ttfd", false))) \
		.override_failure_message("TTFD 20с ≤ 30с — pass").is_true()
	assert_bool(bool(pass_.get("decision_ratio", true))) \
		.override_failure_message("decision 0.5 < 0.6 — fail").is_false()
	assert_bool(bool(pass_.get("loop_closed", false))) \
		.override_failure_message("≥1 цикл — pass").is_true()
	assert_bool(bool(pass_.get("replan_after_tooltip", false))) \
		.override_failure_message("replan 300с ≤ 600с — pass").is_true()
	assert_bool(bool(pass_.get("session_length", false))) \
		.override_failure_message("40 мин в цели 35–50 — pass").is_true()
	assert_bool(bool(pass_.get("action_rate", true))) \
		.override_failure_message("rate 2.5/5мин вне 8–15 — fail").is_false()


func test_compute_metrics_no_wallclock() -> void:
	# Headless: без wall-clock `t` — счётчики считаются, время не вычислимо.
	var events: Array = [
		{"event": "game_start", "turn": 1},
		{"event": "action", "turn": 1, "type": "build", "choice_count": 2},
		{"event": "loop_closed", "turn": 2},
	]
	var m := TelemetryLog.compute_metrics(events)
	assert_int(int(m.get("actions", -1))).is_equal(1)
	assert_int(int(m.get("loops_closed", -1))).is_equal(1)
	assert_float(float(m.get("ttfd_seconds", -2.0))).is_equal(-1.0)
	assert_float(float(m.get("decision_ratio", -1.0))).is_equal_approx(1.0, 0.001)
	var pass_: Dictionary = m.get("pass", {}) as Dictionary
	assert_bool(pass_.get("ttfd", null) == null) \
		.override_failure_message("без wall-clock TTFD не вычислимо → null").is_true()
	assert_bool(pass_.get("session_length", null) == null).is_true()
	assert_bool(bool(pass_.get("loop_closed", false))).is_true()
	assert_bool(bool(pass_.get("decision_ratio", false))).is_true()


func test_loop_closure_rate_cross_session() -> void:
	# GDD: «сессии с ≥1 полным циклом» ≥ 70% — меж-сессийная агрегация.
	var sessions: Array = []
	for i in range(10):
		var ev: Array = [{"event": "game_start", "turn": 1}]
		if i < 7:  # 7 из 10 сессий замкнули цикл
			ev.append({"event": "loop_closed", "turn": 3})
		sessions.append(TelemetryLog.compute_metrics(ev))
	var rate := TelemetryLog.loop_closure_rate(sessions)
	assert_float(rate).is_equal_approx(0.7, 0.001)
	assert_bool(rate >= TelemetryLog.LOOP_CLOSURE_RATE_MIN).is_true()
	assert_float(TelemetryLog.loop_closure_rate([])).is_equal(-1.0)


## --- I1: детерминизм телеметрии ---

func test_i1_telemetry_100_repeats_byte_identical() -> void:
	var first: Dictionary = {}
	for i in range(100):
		var c := _composition(4242)
		for turn in range(1, 8):
			c.record_action("build", 2)
			c.advance_turn()
		var d: Dictionary = c.telemetry.to_dict()
		if first.is_empty():
			first = d
		else:
			assert_dict(d).is_equal(first)
