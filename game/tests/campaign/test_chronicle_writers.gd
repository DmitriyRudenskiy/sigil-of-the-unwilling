"""D-240 (T-175): писатели хроники в кампанийной композиции.

Проверяется не формат ленты (он в test_chronicle_log), а связность: у каждой
записи есть носитель-событие, канонические биты K-M9 пишутся ровно один раз за
кампанию и ровно в том ходу, где случилось событие, а лента доживает до сейва.
Первый и последний тесты гоняют реальные 21 ходов (директивы raids.json), а не
синтетические отчёты: биты, проставленные понарошку, ничего не стоят.
"""
extends BaseTest

const WEAVERS := "Ткачи и Ремесленники"


func _composition() -> CampaignComposition:
	return CampaignComposition.from_campaign_config(12345)


func _drive(c: CampaignComposition, turns: int) -> void:
	for i in turns:
		if c.campaign.is_done():
			return
		c.advance_turn()


func _keys(log: ChronicleLog) -> Array[String]:
	var out: Array[String] = []
	for rec in log.records():
		for line in rec.get("lines", []):
			out.append(str((line as Dictionary).get("key", "")))
	return out


func _count(c: CampaignComposition, key: String) -> int:
	var hits := 0
	for k in _keys(c.chronicle):
		if k == key:
			hits += 1
	return hits


## Кампания начинается с бита 1 («Ты не просил. Знак всё равно пришёл…»):
## игрок входит в историю, а не в пустой экран со счётчиками.
func test_campaign_start_writes_the_sign_bit() -> void:
	var c := _composition()
	var records: Array = c.chronicle.records()
	assert_int(records.size()).is_equal(1)
	assert_int(int((records[0] as Dictionary)["turn"])).is_equal(1)
	assert_str(_keys(c.chronicle)[0]).is_equal("chronicle.bit_sign")


## K-M9 + K-R3: на полном 21-ходовом прогоне биты 1/7/17/21 fires ровно по разу,
## предупреждение о волне — в ход генерации (07-balance §5).
func test_canonical_bits_fire_exactly_once_across_the_campaign() -> void:
	var c := _composition()
	_drive(c, 21)
	assert_int(_count(c, "chronicle.bit_sign")).is_equal(1)
	assert_int(_count(c, "chronicle.bit_first_raid")) \
		.override_failure_message("первый рейд не оставил бита за 21 ход").is_equal(1)
	assert_int(_count(c, "chronicle.bit_strong_raid")) \
		.override_failure_message("окно тира 2 (ход 17) не оставило бита").is_equal(1)
	assert_int(_count(c, "chronicle.bit_final_raid")) \
		.override_failure_message("босс хода 21 не оставил бита").is_equal(1)
	assert_int(_count(c, "chronicle.wave_warning")) \
		.override_failure_message("ни одного предупреждения о волне").is_greater(0)
	# Бит 14 пишется по событию, а не по календарю: за прогон без построек его нет.
	assert_int(_count(c, "chronicle.bit_district")).is_equal(0)


## Причины рейда (02-mechanics «хроника называет причину») складываются в одну
## запись и не превышают трёх строк (EC «один текстовый блок за событие»).
func test_raid_cause_lines_are_one_record_of_three_lines() -> void:
	var c := _composition()
	# Синтез: все четыре причины сразу — рейд без боя (партия в пути), нулевой
	# урон, DEFICIT по еде, все районы пусты.
	c.settlement.buildings.clear()
	c.settlement.sm["food"] = {"state": "DEFICIT", "days_positive": 0, "days_negative": 0}
	c.last_threat_report = {"raid": {"turn": 9, "tier": 1, "composition": "light",
		"loss": 0.0, "battle_requested": false}}
	c._advance_chronicle()
	var records: Array = c.chronicle.records()
	var causes: Dictionary = records[records.size() - 1]
	var keys: Array[String] = []
	for line in causes.get("lines", []):
		keys.append(str((line as Dictionary).get("key", "")))
	assert_int(keys.size()) \
		.override_failure_message("причины рейда не свернулись в три строки").is_equal(3)
	assert_str(keys[0]).is_equal("chronicle.raid_repelled")
	assert_str(keys[1]).is_equal("chronicle.raid_deficit")
	assert_str(keys[2]).is_equal("chronicle.raid_party_away")
	# Четвёртая причина (все районы пусты) за каноническим лимитом — но не молча:
	# она остаётся в механике (cooldown ×2), просто не в этом текстовом блоке.
	assert_bool(keys.has("chronicle.raids_all_ruined")).is_false()


## Предупреждение — в ход генерации волны (07-balance §5), а не в каждый ход
## дороги: иначе «в пути волна» повторялась бы три хода подряд.
func test_wave_warning_written_only_on_generation_turn() -> void:
	var c := _composition()
	var turn: int = c.campaign.current_turn
	c.last_threat_report = {"wave": {"turn": turn, "tier": 1, "turns_to_arrival": 1}}
	c._advance_chronicle()
	assert_int(_count(c, "chronicle.wave_warning")).is_equal(1)
	c.last_threat_report = {"wave": {"turn": turn - 1, "tier": 1, "turns_to_arrival": 1}}
	c._advance_chronicle()
	assert_int(_count(c, "chronicle.wave_warning")) \
		.override_failure_message("волна в пути переписывается каждый ход").is_equal(1)


## WARN по еде — переход SM, а не состояние (06-economy §SM: «WARN — индикатор +
## хроника»): повторный WARN того же хода не плодит записей.
func test_food_warn_written_on_transition_only() -> void:
	var c := _composition()
	c._record_food_transitions({"sm_transitions": [{"resource": "food", "from": "OK", "to": "WARN"}]})
	assert_int(_count(c, "chronicle.food_warn")).is_equal(1)
	c._record_food_transitions({"sm_transitions": [{"resource": "wood", "from": "OK", "to": "WARN"}]})
	c._record_food_transitions({"sm_transitions": [{"resource": "food", "from": "WARN", "to": "DEFICIT"}]})
	c._record_food_transitions({})
	assert_int(_count(c, "chronicle.food_warn")) \
		.override_failure_message("не-еда и не-WARN дали запись в ленту еды").is_equal(1)


## Район: первая постройка группы — событие (бит 14 + строка), снятие — строка.
## Стартовые здания хода 1 событиями не считаются.
func test_district_birth_and_disband_are_records() -> void:
	var c := _composition()
	_drive(c, 1)  # базовая линия присутствия — без записей
	assert_int(_count(c, "chronicle.district_created")).is_equal(0)
	c.settlement.buildings.append(
			{"id": "loom", "group": WEAVERS, "output_day": {"wood": 1.0}, "efficiency": 1.0})
	_drive(c, 1)
	assert_int(_count(c, "chronicle.bit_district")) \
		.override_failure_message("первый район не дал канонический бит").is_equal(1)
	assert_int(_count(c, "chronicle.district_created")).is_equal(1)
	c.settlement.buildings = c.settlement.buildings.filter(
			func(b: Dictionary) -> bool: return str(b.get("group", "")) != WEAVERS)
	_drive(c, 4)  # окно гистерезиса disband_below_days = 3
	assert_int(_count(c, "chronicle.district_disbanded")) \
		.override_failure_message("снятие района не попало в ленту").is_equal(1)


## Лента — состояние: JSON round-trip сохраняет порядок и биты (иначе после
## загрузки игрок видел бы хронику заново с нуля).
func test_chronicle_survives_save_roundtrip() -> void:
	var c := _composition()
	_drive(c, 9)
	var before: Array = c.chronicle.records()
	assert_int(before.size()).is_greater(1)
	var restored := _composition()
	restored.load_save_state(JSON.parse_string(JSON.stringify(c.build_save_state())))
	var after: Array = restored.chronicle.records()
	assert_int(after.size()).is_equal(before.size())
	assert_str(_keys(restored.chronicle)[0]).is_equal("chronicle.bit_sign")
	assert_bool(restored.chronicle.has_bit("bit_first_raid")) \
		.override_failure_message("бит не пережил сейв").is_true()


## Сейв до D-240: ленты нет → пустая хроника, а не падение и не выдумка.
func test_old_save_without_chronicle_section_yields_empty_feed() -> void:
	var c := _composition()
	_drive(c, 3)
	var state: Dictionary = c.build_save_state()
	(state["campaign"] as Dictionary).erase("chronicle")
	var restored := _composition()
	restored.load_save_state(state)
	assert_bool(restored.chronicle.is_empty()) \
		.override_failure_message("старый сейв породил записи, которых не было").is_true()
