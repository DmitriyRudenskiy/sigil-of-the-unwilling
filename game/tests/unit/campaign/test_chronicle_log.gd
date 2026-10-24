"""D-240 (T-175): `ChronicleLog` — канонические лимиты ленты и сейв-форма.

Канон (04-narrative «Правила», EC/EC2): событие = запись до 3 строк, не более
5 записей за ход, дальше — сводка; бит = одна запись за кампанию. Плюс
требование к носителю: лента — состояние сейва, поэтому запись хранит ключ
перевода, а не готовый текст (язык — настройка, она может смениться между
сеансами), и неизвестный ключ в ленту не попадает — иначе в кадре был бы
`chronicle.…`, а не предложение.
"""
extends BaseTest


func _line(key: String, args: Dictionary = {}) -> Dictionary:
	return {"key": key, "args": args}


func _keys(rec: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for line in rec.get("lines", []):
		out.append(str((line as Dictionary).get("key", "")))
	return out


func test_event_keeps_at_most_three_lines() -> void:
	# «Один текстовый блок за событие ≤3 строки» (04-narrative).
	var log := ChronicleLog.new()
	var ok := log.record_event(3, [
		_line("chronicle.raid_repelled"),
		_line("chronicle.raid_deficit"),
		_line("chronicle.raid_party_away"),
		_line("chronicle.raids_all_ruined"),
	])
	assert_bool(ok).is_true()
	assert_int(log.record_count_for(3)).is_equal(1)
	var rec: Dictionary = log.records()[0]
	assert_int((rec["lines"] as Array).size()) \
		.override_failure_message("событие длиннее трёх канонических строк").is_equal(3)
	assert_bool(_keys(rec).has("chronicle.raids_all_ruined")) \
		.override_failure_message("четвёртая строка просочилась в ленту").is_false()


func test_unknown_keys_and_empty_events_never_reach_the_feed() -> void:
	var log := ChronicleLog.new()
	assert_bool(log.record_event(1, [_line("chronicle.not_a_real_line")])) \
		.override_failure_message("событие с неизвестным ключом записано").is_false()
	assert_bool(log.record_event(1, [])) \
		.override_failure_message("пустое событие записано").is_false()
	assert_bool(log.record_event(1, [{"key": 42}])) \
		.override_failure_message("строка без ключа записана").is_false()
	assert_bool(log.is_empty()).is_true()


func test_sixth_event_of_a_turn_collapses_into_summary_counter() -> void:
	# EC2: «лимит 5 записей/день, дальше — сводка».
	var log := ChronicleLog.new()
	for i in 5:
		assert_bool(log.record_line(4, "chronicle.district_created", {"group": "g%d" % i})).is_true()
	assert_int(log.record_count_for(4)).is_equal(5)
	assert_bool(log.record_line(4, "chronicle.food_warn")).is_true()
	assert_int(log.record_count_for(4)) \
		.override_failure_message("шестое событие не свернулось в сводку").is_equal(6)
	var rec: Dictionary = log.records()[log.records().size() - 1]
	assert_str(_keys(rec)[0]).is_equal(ChronicleLog.SUMMARY_KEY)
	assert_int(int((rec["lines"][0] as Dictionary)["args"]["count"])).is_equal(1)
	assert_bool(log.record_line(4, "chronicle.food_warn")).is_true()
	rec = log.records()[log.records().size() - 1]
	assert_int(int((rec["lines"][0] as Dictionary)["args"]["count"])) \
		.override_failure_message("счётчик сводки не вырос").is_equal(2)
	assert_int(log.record_count_for(4)) \
		.override_failure_message("сводка размножилась вместо счётчика").is_equal(6)


func test_bit_fires_once_and_is_not_folded_into_summary() -> void:
	var log := ChronicleLog.new()
	for i in 6:
		log.record_line(2, "chronicle.food_warn")
	assert_bool(log.record_bit(2, "bit_sign", "chronicle.bit_sign")).is_true()
	assert_bool(log.has_bit("bit_sign")).is_true()
	assert_bool(log.record_bit(9, "bit_sign", "chronicle.bit_sign")) \
		.override_failure_message("бит записался второй раз за кампанию").is_false()
	# Бит — не сводка: он и есть причина открыть хронику (правило битов), поэтому
	# дописывается мимо дневного лимита (расхождение с буквой EC2 — в D-240).
	var bits := 0
	var summaries := 0
	for rec in log.records():
		var key := _keys(rec)[0]
		if key == "chronicle.bit_sign":
			bits += 1
		elif key == ChronicleLog.SUMMARY_KEY:
			summaries += 1
	assert_int(bits).is_equal(1)
	assert_int(summaries).is_equal(1)


func test_records_keep_turn_and_chronological_order() -> void:
	var log := ChronicleLog.new()
	log.record_bit(1, "bit_sign", "chronicle.bit_sign")
	log.record_line(1, "chronicle.wave_warning")
	log.record_bit(7, "bit_first_raid", "chronicle.bit_first_raid")
	var records := log.records()
	assert_int(records.size()).is_equal(3)
	assert_int(int((records[0] as Dictionary)["turn"])).is_equal(1)
	assert_int(int((records[2] as Dictionary)["turn"])).is_equal(7)
	assert_str(_keys(records[2])[0]).is_equal("chronicle.bit_first_raid")
	assert_int(log.record_count_for(1)).is_equal(2)
	assert_int(log.record_count_for(2)).is_equal(0)
	assert_int(log.record_count_for(8)).is_equal(0)


func test_save_roundtrip_survives_json_and_drops_garbage() -> void:
	var log := ChronicleLog.new()
	log.record_bit(1, "bit_sign", "chronicle.bit_sign")
	log.record_line(7, "chronicle.district_created", {"group": "Ткачи и Ремесленники"})
	log.record_line(7, "chronicle.day_summary", {"count": 3})
	# Сейв проходит JSON (mvp_save_manager): int → float, типы словарей — строки.
	var via_json: Dictionary = JSON.parse_string(JSON.stringify(log.to_dict()))
	var restored := ChronicleLog.from_dict(via_json)
	var records := restored.records()
	assert_int(records.size()).is_equal(3)
	assert_bool(restored.has_bit("bit_sign")).is_true()
	var args: Dictionary = (records[1] as Dictionary)["lines"][0].get("args", {})
	assert_str(str(args["group"])).is_equal("Ткачи и Ремесленники")
	# Числа после round-trip обязаны вернуться числами: «И ещё 3.0» игрок не читает.
	var count: Variant = (records[2] as Dictionary)["lines"][0].get("args", {})["count"]
	assert_int(int(count)).is_equal(3)
	assert_bool(count is int) \
		.override_failure_message("arg после JSON остался float: %s %s" % [str(count), typeof(count)]).is_true()


func test_from_dict_drops_malformed_entries_and_old_saves() -> void:
	# Сейв до D-240: секции нет вовсе → пустая лента, а не падение и не выдумка.
	assert_bool(ChronicleLog.from_dict({}).is_empty()).is_true()
	var junk := ChronicleLog.from_dict({
		"days": [
			"не словарь",
			{"turn": 3, "records": ["не запись", {"lines": []},
					{"lines": [{"key": "chronicle.unknown"}, {"key": 7}]}]},
			{"turn": 4, "records": []},
			{"turn": 5, "records": [{"lines": [{"key": "chronicle.food_warn"}]}]},
		],
		"bits": "не массив",
	})
	assert_int(junk.records().size()).is_equal(1)
	assert_int(int((junk.records()[0] as Dictionary)["turn"])).is_equal(5)
	assert_bool(junk.has_bit("bit_sign")).is_false()
