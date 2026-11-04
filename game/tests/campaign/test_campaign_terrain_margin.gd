extends BaseTest

## dnd-battle-ladder 3.3 (C3): местность 3 типа (болото/шипы/высота) —
## абстрактные модификаторы ±2 (без hex, C-3). Местность = данные
## (поле `terrain` комбатанта, K-M15), движок — `_terrain_margin` в
## перевесе атаки (стек без капа с _state_margin, 02d).
## Значения: swamp — −2 к атакам занимающего; spikes — −2 к атакам по
## занимающему; height — +2 к атакам занимающего (и −2 к атакам снизу).

const CampaignBattleScript := preload("res://scripts/campaign/campaign_battle.gd")


func _w(spec: Dictionary) -> Dictionary:
	var base := {
		"id": "hero", "character_uid": 1, "hp": 11, "ac": 12, "attack": 13,
		"damage": 5, "luck": 0, "dex": 12, "con": 1, "proficiency": 2,
	}
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


func _r(spec: Dictionary) -> Dictionary:
	var base := {
		"id": "raider", "character_uid": 77, "hp": 7, "ac": 11, "attack": 12,
		"damage": 5, "luck": 0, "dex": 12, "con": 1, "proficiency": 1,
	}
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


## Первая запись trace боя (hero ходит первым: luck+dex равны, id "hero" < "raider").
func _first_strike(report: Dictionary) -> Dictionary:
	return (report["trace"] as Array)[0]


## Без местности перевес не меняется (back-compat).
func test_terrain_none_by_default() -> void:
	var report := CampaignBattleScript.resolve(_w({"attack": 12}), _r({}))
	var hit: Dictionary = _first_strike(report)
	assert_int(int(hit["margin"])).override_failure_message("12 − 11 = 1").is_equal(1)
	assert_str(str(hit["zone"])).is_equal("success")


## Болото: −2 к атакам занимающего (1 → −1: success → partial, урон 5 → 2).
func test_terrain_swamp_minus_two_attacks() -> void:
	var report := CampaignBattleScript.resolve(_w({"attack": 12, "terrain": "swamp"}), _r({}))
	var hit: Dictionary = _first_strike(report)
	assert_int(int(hit["margin"])).override_failure_message("12 − 11 − 2 = −1").is_equal(-1)
	assert_str(str(hit["zone"])).is_equal("partial")
	assert_int(int(hit["damage"])).is_equal(2)


## Шипы: −2 к атакам по занимающему.
func test_terrain_spikes_minus_two_against_occupant() -> void:
	var report := CampaignBattleScript.resolve(_w({"attack": 12}), _r({"terrain": "spikes"}))
	var hit: Dictionary = _first_strike(report)
	assert_int(int(hit["margin"])).override_failure_message("12 − 11 − 2 = −1").is_equal(-1)
	assert_str(str(hit["zone"])).is_equal("partial")


## Высота: +2 к атакам занимающего (2 → 4: success → triumph, урон ×2).
func test_terrain_height_plus_two_attacks() -> void:
	var report := CampaignBattleScript.resolve(_w({"terrain": "height"}), _r({}))
	var hit: Dictionary = _first_strike(report)
	assert_int(int(hit["margin"])).override_failure_message("13 − 11 + 2 = 4").is_equal(4)
	assert_str(str(hit["zone"])).is_equal("triumph")
	assert_int(int(hit["damage"])).is_equal(10)


## Высота: −2 к атакам снизу по занимающему.
func test_terrain_height_minus_two_against_occupant() -> void:
	var report := CampaignBattleScript.resolve(_w({"attack": 12}), _r({"terrain": "height"}))
	var hit: Dictionary = _first_strike(report)
	assert_int(int(hit["margin"])).override_failure_message("12 − 11 − 2 = −1").is_equal(-1)
	assert_str(str(hit["zone"])).is_equal("partial")


## Стек без капа (02d): prone (−2) + болото (−2) = −4 к перевесу.
func test_terrain_stacks_with_states() -> void:
	var report := CampaignBattleScript.resolve(
		_w({"attack": 12, "prone": true, "terrain": "swamp"}), _r({}))
	var hit: Dictionary = _first_strike(report)
	assert_int(int(hit["margin"])).override_failure_message("12 − 11 − 2 − 2 = −3").is_equal(-3)
	assert_str(str(hit["zone"])).is_equal("partial")


## Multi-путь: местность действует и в resolve_multi (тот же _strike).
func test_terrain_in_multi_path() -> void:
	var party := [_w({"terrain": "height"})]
	var enemies := [_r({"hp": 30})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	var hit: Dictionary = (report["trace"] as Array)[0]
	assert_str(str(hit["actor"])).is_equal("hero")
	assert_int(int(hit["margin"])).override_failure_message("13 − 11 + 2 = 4").is_equal(4)
	assert_str(str(hit["zone"])).is_equal("triumph")
