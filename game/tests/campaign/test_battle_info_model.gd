extends BaseTest

## Экран боя (3.4): все правила D&D видны без подсказок.
## CampaignBattle.strike_breakdown (чистая разбивка margin) +
## BattleInfoModel (active_rules / combatant_card / strike_info).
## Зоны (luck=0): triumph ≥4, success ≥0, partial ≥−3, failure −4..−7, fumble ≤−8.
## ADVANTAGE_MARGIN = 2.

const Battle = preload("res://scripts/campaign/campaign_battle.gd")
const Model = preload("res://scripts/ui/battle_info_model.gd")


func _atk(spec: Dictionary) -> Dictionary:
	return Battle.make_combatant(spec)


func _def(spec: Dictionary) -> Dictionary:
	return Battle.make_combatant(spec)


# --- strike_breakdown: компоненты margin ---

func test_breakdown_base() -> void:
	var b: Dictionary = Battle.strike_breakdown(_atk({"attack": 12}), _def({"ac": 15}))
	assert_int(b["base_margin"]).is_equal(-3)
	assert_int(b["state_margin"]).is_equal(0)
	assert_int(b["terrain_margin"]).is_equal(0)
	assert_int(b["total_margin"]).is_equal(-3)
	assert_str(b["zone"]).is_equal("partial")
	assert_bool(b["fate_penalty"]).is_false()
	assert_bool(b["reckoning"]).is_false()


func test_breakdown_state_prone() -> void:
	var b: Dictionary = Battle.strike_breakdown(_atk({"attack": 12, "prone": true}), _def({"ac": 15}))
	assert_int(b["state_margin"]).is_equal(-2)
	assert_int(b["total_margin"]).is_equal(-5)
	assert_str(b["zone"]).is_equal("failure")


func test_breakdown_terrain() -> void:
	var b: Dictionary = Battle.strike_breakdown(
		_atk({"attack": 12, "terrain": "swamp"}), _def({"ac": 15, "terrain": "spikes"}))
	assert_int(b["terrain_margin"]).is_equal(-4)  # −2 (болото) + −2 (шипы)
	assert_int(b["total_margin"]).is_equal(-7)
	assert_str(b["zone"]).is_equal("failure")


func test_breakdown_flank() -> void:
	var b: Dictionary = Battle.strike_breakdown(_atk({"attack": 12}), _def({"ac": 15}), 2)
	assert_int(b["flank_bonus"]).is_equal(2)
	assert_int(b["total_margin"]).is_equal(-1)
	assert_str(b["zone"]).is_equal("partial")


func test_breakdown_hunger() -> void:
	var b: Dictionary = Battle.strike_breakdown(_atk({"attack": 12, "hunger_penalty": -2}), _def({"ac": 15}))
	assert_int(b["hunger_penalty"]).is_equal(-2)
	assert_int(b["total_margin"]).is_equal(-5)
	assert_str(b["zone"]).is_equal("failure")


func test_breakdown_fate_penalty() -> void:
	# debt 1 < порог 2 → «Судьба следит»: margin / 1.25
	var b: Dictionary = Battle.strike_breakdown(_atk({"attack": 15, "fate_debt": 1}), _def({"ac": 10}))
	assert_int(b["base_margin"]).is_equal(5)
	assert_int(b["total_margin"]).is_equal(4)  # floor(5 / 1.25)
	assert_bool(b["fate_penalty"]).is_true()
	assert_bool(b["reckoning"]).is_false()
	assert_str(b["zone"]).is_equal("triumph")


func test_breakdown_reckoning() -> void:
	# debt 2 ≥ порог 2 → Расплата: зона на ступень ниже, без деления
	var b: Dictionary = Battle.strike_breakdown(
		_atk({"attack": 15, "fate_debt": 2, "proficiency": 2}), _def({"ac": 10}))
	assert_int(b["total_margin"]).is_equal(5)
	assert_bool(b["reckoning"]).is_true()
	assert_bool(b["fate_penalty"]).is_false()
	assert_str(b["zone"]).is_equal("success")  # triumph → success


func test_breakdown_no_mutation() -> void:
	var a := _atk({"attack": 15, "fate_debt": 2})
	var d := _def({"ac": 10})
	Battle.strike_breakdown(a, d)
	assert_int(a["fate_debt"]).is_equal(2)  # не сбросился (в отличие от _strike)


# --- BattleInfoModel: active_rules / combatant_card / strike_info ---

func test_active_rules_none() -> void:
	var r: Array = Model.active_rules(_atk({"attack": 12}), _def({"ac": 15}))
	assert_int(r.size()).is_equal(0)


func test_active_rules_prone() -> void:
	var r: Array = Model.active_rules(_atk({"attack": 12, "prone": true}), _def({"ac": 15}))
	assert_bool(r.has("prone")).is_true()


func test_active_rules_terrain() -> void:
	var r: Array = Model.active_rules(
		_atk({"attack": 12, "terrain": "swamp"}), _def({"ac": 15, "terrain": "spikes"}))
	assert_bool(r.has("terrain_swamp")).is_true()
	assert_bool(r.has("terrain_spikes")).is_true()


func test_active_rules_flank() -> void:
	var r: Array = Model.active_rules(_atk({"attack": 12}), _def({"ac": 15}), 2)
	assert_bool(r.has("flank")).is_true()


func test_active_rules_hunger() -> void:
	var r: Array = Model.active_rules(_atk({"attack": 12, "hunger_penalty": -2}), _def({"ac": 15}))
	assert_bool(r.has("hunger")).is_true()


func test_active_rules_fate_debt() -> void:
	var r: Array = Model.active_rules(_atk({"attack": 12, "fate_debt": 1}), _def({"ac": 15}))
	assert_bool(r.has("fate_debt")).is_true()


func test_combatant_card() -> void:
	var c: Dictionary = Model.combatant_card(_atk({
		"id": "hero", "hp": 7, "attack": 12, "ac": 14, "luck": 1,
		"terrain": "height", "prone": false, "elevated": true, "fate_debt": 3,
	}))
	assert_str(c["id"]).is_equal("hero")
	assert_int(c["hp"]).is_equal(7)
	assert_int(c["attack"]).is_equal(12)
	assert_int(c["ac"]).is_equal(14)
	assert_int(c["luck"]).is_equal(1)
	assert_str(c["terrain"]).is_equal("height")
	assert_bool(c["elevated"]).is_true()
	assert_bool(c["prone"]).is_false()
	assert_int(c["fate_debt"]).is_equal(3)
	assert_str(c["state"]).is_equal("ready")


func test_strike_info_delegates() -> void:
	var a := _atk({"attack": 12})
	var d := _def({"ac": 15})
	var via_model: Dictionary = Model.strike_info(a, d)
	var direct: Dictionary = Battle.strike_breakdown(a, d)
	assert_dict(via_model).is_equal(direct)
