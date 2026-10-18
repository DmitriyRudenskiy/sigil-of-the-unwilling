extends BaseTest
## party-characters 3.1 (Q-M56→(а), K-M10, D-189): Ветеран — статус
## пережившего бойца (не юнит/ярус). Счётчик battles_survived, порог N (F4),
## +1 ступень к спасам/проверкам до конца боя (применение — T-116, за срезом).


func _member(battles: int = 0, state: String = "READY") -> Dictionary:
	return {"id": "hero", "class": "fighter", "level": 1, "xp": 0,
		"stats": {"str": 14, "dex": 10, "con": 12, "int": 10, "wis": 10, "cha": 10},
		"luck": 10, "state": state, "battles_survived": battles}


## Новый боец — не Ветеран (0 < N).
func test_not_veteran_initially() -> void:
	var m := _member(0)
	assert_that(PartySystem.is_veteran(m)).is_false()
	assert_that(PartySystem.veteran_bonus(m)).is_equal(0)


## Ветеран на пороге N (battles_survived == N).
func test_veteran_at_threshold() -> void:
	var n := PartySystem.veteran_threshold()
	var m := _member(n)
	assert_that(PartySystem.is_veteran(m)).is_true()
	assert_that(PartySystem.veteran_bonus(m)).is_equal(PartySystem.veteran_save_step())


## Не Ветеран за один бой до порога (N−1).
func test_not_veteran_below_threshold() -> void:
	var n := PartySystem.veteran_threshold()
	var m := _member(n - 1)
	assert_that(PartySystem.is_veteran(m)).is_false()
	assert_that(PartySystem.veteran_bonus(m)).is_equal(0)


## Бонус Ветерана = +1 ступень (канон K-M10).
func test_veteran_bonus_value() -> void:
	assert_that(PartySystem.veteran_save_step()).is_equal(1)
	var m := _member(PartySystem.veteran_threshold())
	assert_that(PartySystem.veteran_bonus(m)).is_equal(1)


## record_battle_survival: +1 к battles_survived у живых.
func test_record_battle_survival_increments() -> void:
	var party: Array = [_member(0), _member(0)]
	var marked := PartySystem.record_battle_survival(party)
	assert_that(marked).is_equal(2)
	assert_that(int(party[0]["battles_survived"])).is_equal(1)
	assert_that(int(party[1]["battles_survived"])).is_equal(1)


## Павшие в бою неincrement-ятся (вызов после apply_losses).
func test_dead_members_not_incremented() -> void:
	var party: Array = [_member(0, "READY"), _member(0, "DEAD")]
	var marked := PartySystem.record_battle_survival(party)
	assert_that(marked).is_equal(1)
	assert_that(int(party[0]["battles_survived"])).is_equal(1)
	assert_that(int(party[1].get("battles_survived", 0))).is_equal(0)


## Счётчик накапливается до статуса Ветеран.
func test_accumulates_to_veteran() -> void:
	var n := PartySystem.veteran_threshold()
	var party: Array = [_member(0)]
	for i in range(n):
		PartySystem.record_battle_survival(party)
	assert_that(PartySystem.is_veteran(party[0])).is_true()
	assert_that(int(party[0]["battles_survived"])).is_equal(n)


## Сериализация: battles_survived — входная величина, переживает roundtrip.
func test_serialization_preserves_counter() -> void:
	var m := _member(3)
	var save: Dictionary = m.duplicate(true)
	var loaded: Dictionary = save.duplicate(true)
	assert_that(int(loaded.get("battles_survived", 0))).is_equal(3)
	assert_that(PartySystem.is_veteran(loaded)).is_equal(PartySystem.is_veteran(m))


## Порог из конфига (F4): battles_to_veteran = 5.
func test_config_threshold() -> void:
	assert_that(PartySystem.veteran_threshold()).is_equal(5)


## Интеграция: composition — после боя счётчик живых партии растёт.
func test_composition_battle_increments_survival() -> void:
	var c: CampaignComposition = CampaignComposition.from_campaign_config(424242)
	var before: int = int((c.party[0] as Dictionary).get("battles_survived", 0))
	# Симулируем бой (tier 1, CR героя ≤ рейдера → parity; исход неважен для счётчика).
	c._request_battle({"tier": 1, "source": "test"})
	var after: int = int((c.party[0] as Dictionary).get("battles_survived", 0))
	# Герой жив (tier 1 не убивает) → счётчик +1.
	assert_that(after).is_equal(before + 1)
