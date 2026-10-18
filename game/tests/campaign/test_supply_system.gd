extends BaseTest
## party-characters 3.2 (R7, Q-M75→(б), P-4): снабжение героя — еда в походе.
## Ёмкость 10; расход 1/персонаж/переход; полный (>50%) → +2 к 1-му спасу;
## голод (0) → −2 к атакам (P-4). Штраф голода держится до resupply.

const CAMPAIGN_JSON := "res://data/config/balance/campaign.json"


func _cfg() -> Dictionary:
	var file := FileAccess.open(CAMPAIGN_JSON, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _supply() -> SupplySystem:
	return SupplySystem.from_config(_cfg())


## Старт с полным запасом (ёмкость 10).
func test_start_full() -> void:
	var s := _supply()
	assert_that(s.capacity()).is_equal(10)
	assert_that(s.food()).is_equal(10)
	assert_that(s.is_full()).is_true()
	assert_that(s.is_hungry()).is_false()


## Расход: 1 еда/персонаж/переход (Q-M75→(б)).
func test_consume_for_travel() -> void:
	var s := _supply()
	var spent := s.consume_for_travel(3)  # 3 персонажа → 3 еды
	assert_that(spent).is_equal(3)
	assert_that(s.food()).is_equal(7)


## Расход не уходит в минус (clamp 0).
func test_consume_clamped_at_zero() -> void:
	var s := _supply()
	s.consume_for_travel(8)  # 10 → 2
	assert_that(s.food()).is_equal(2)
	var spent := s.consume_for_travel(5)  # 2 → 0 (потрачено только 2)
	assert_that(spent).is_equal(2)
	assert_that(s.food()).is_equal(0)


## Голод (0 еды) → −2 к атакам (P-4).
func test_hunger_penalty() -> void:
	var s := _supply()
	s.consume_for_travel(10)  # 10 → 0
	assert_that(s.is_hungry()).is_true()
	assert_that(s.attack_penalty()).is_equal(-2)
	assert_that(s.first_save_bonus()).is_equal(0)  # голод → нет бонуса


## Полный запас (>50%) → +2 к первому спасброску.
func test_full_save_bonus() -> void:
	var s := _supply()
	s.consume_for_travel(4)  # 10 → 6 (>5)
	assert_that(s.is_full()).is_true()
	assert_that(s.first_save_bonus()).is_equal(2)
	assert_that(s.attack_penalty()).is_equal(0)


## ≤50% → нет бонуса (но и не голод).
func test_not_full_below_half() -> void:
	var s := _supply()
	s.consume_for_travel(5)  # 10 → 5 (=50%, не >50%)
	assert_that(s.is_full()).is_false()
	assert_that(s.first_save_bonus()).is_equal(0)
	assert_that(s.is_hungry()).is_false()
	assert_that(s.attack_penalty()).is_equal(0)


## Resupply в городе: до ёмкости, штраф голода снимается.
func test_resupply_clears_hunger() -> void:
	var s := _supply()
	s.consume_for_travel(10)  # голод
	assert_that(s.is_hungry()).is_true()
	s.resupply()
	assert_that(s.food()).is_equal(10)
	assert_that(s.is_hungry()).is_false()
	assert_that(s.attack_penalty()).is_equal(0)
	assert_that(s.is_full()).is_true()


## Сериализация: roundtrip сохраняет food/capacity.
func test_serialization_roundtrip() -> void:
	var s := _supply()
	s.consume_for_travel(3)  # 10 → 7
	var d: Dictionary = s.to_dict()
	var s2 := SupplySystem.from_dict(d)
	assert_that(s2.food()).is_equal(7)
	assert_that(s2.capacity()).is_equal(10)
	assert_that(s2.is_full()).is_true()


## from_dict пустой → старт с полным запасом (дефолт 10).
func test_from_dict_empty() -> void:
	var s := SupplySystem.from_dict({})
	assert_that(s.food()).is_equal(10)
	assert_that(s.capacity()).is_equal(10)
	assert_that(s.is_full()).is_true()


## Числа из конфига (campaign.json → supply): ёмкость 10, расход 1, штраф −2.
func test_config_values() -> void:
	var s := _supply()
	assert_that(s.capacity()).is_equal(10)  # hero_capacity_food
	assert_that(s.attack_penalty() if s.is_hungry() else 0).is_equal(0)
	# Проводим в голод и проверяем штраф из конфига.
	s.consume_for_travel(10)
	assert_that(s.attack_penalty()).is_equal(-2)  # starvation_attack_penalty


## Интеграция: composition несёт supply_system; сейв-секция "supply".
func test_composition_integration() -> void:
	var c: CampaignComposition = CampaignComposition.from_campaign_config(424242)
	assert_that(c.supply_system != null).is_true()
	assert_that(c.supply_system.food()).is_equal(10)
	# Под-ключ "supply" в секции "campaign" присутствует.
	var save: Dictionary = c.build_save_state()
	assert_that((save["campaign"] as Dictionary).has("supply")).is_true()
	# Roundtrip: загрузка сохраняет food.
	c.supply_system.consume_for_travel(4)  # 10 → 6
	var save2: Dictionary = c.build_save_state()
	var c2: CampaignComposition = CampaignComposition.from_campaign_config(424242)
	c2.load_save_state(save2)
	assert_that(c2.supply_system.food()).is_equal(6)
