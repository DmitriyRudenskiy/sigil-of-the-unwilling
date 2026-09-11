# TASK_18 B2.2: TemplateEngine — хендлеры, условия, args.
# Глобальный реестр хендлеров делим с TemplateBootstrap: используем
# уникальные имена шаблонов и не зовём reset() без реставрации.
extends BaseTest


const MY_TPL := &"TE_TEST_HEAL"
const UNKNOWN_TPL := &"TE_DEFINITELY_NOT_REGISTERED_ZZ"


class StubTarget:
	var hp := 100
	var cost := 3
	func get_hp() -> int: return hp
	func get_cost() -> int: return cost
	func is_damaged() -> bool: return hp < 100


var _calls: Array = []

func before_test() -> void:
	TemplateEngine.register_handler(MY_TPL, _handler)
	_calls.clear()

func after_test() -> void:
	TemplateEngine._handlers.erase(MY_TPL)

func test_unknown_template() -> void:
	var r := TemplateEngine.execute(UNKNOWN_TPL, {}, {}, [], null, null, null)
	assert_that(r.get("result")).is_equal("unknown_template")
	assert_that(r.get("template")).is_equal(str(UNKNOWN_TPL))
	assert_int(Array(r.get("effects", [])).size()).is_equal(0)

func test_condition_not_met_blocks_handler() -> void:
	var target := StubTarget.new()
	var r := TemplateEngine.execute(MY_TPL, {}, {"target_hp_max": 50}, [], null, null, target)
	assert_that(r.get("result")).is_equal("condition_not_met")
	assert_int(_calls.size()).is_equal(0)

func test_condition_met_calls_handler() -> void:
	var target := StubTarget.new()
	target.hp = 10
	var r := TemplateEngine.execute(MY_TPL, {"power": 5}, {"target_hp_max": 50},
			[{"k": "v"}], "state", "caster", target)
	assert_that(r.get("result")).is_equal("ok")
	assert_int(_calls.size()).is_equal(1)
	# handler получил (params, state, caster, target, secondary)
	assert_int(int(_calls[0][0]["power"])).is_equal(5)
	assert_that(_calls[0][1]).is_equal("state")
	assert_that(_calls[0][3]).is_equal(target)
	assert_int(_calls[0][4].size()).is_equal(1)

func test_empty_condition_passes() -> void:
	var r := TemplateEngine.execute(MY_TPL, {}, {}, [], null, null, null)
	assert_that(r.get("result")).is_equal("ok")

func test_target_is_damaged_condition() -> void:
	var full := StubTarget.new()
	var r_full := TemplateEngine.execute(MY_TPL, {}, {"target_is_damaged": true}, [], null, null, full)
	assert_that(r_full.get("result")).is_equal("condition_not_met")
	var hurt := StubTarget.new()
	hurt.hp = 40
	var r_hurt := TemplateEngine.execute(MY_TPL, {}, {"target_is_damaged": true}, [], null, null, hurt)
	assert_that(r_hurt.get("result")).is_equal("ok")

func test_reset_clears_handlers() -> void:
	TemplateEngine.reset()
	var r := TemplateEngine.execute(MY_TPL, {}, {}, [], null, null, null)
	assert_that(r.get("result")).is_equal("unknown_template")
	# Реставрация глобального реестра для остальных сьюитов
	TemplateBootstrap._ready()
	assert_bool(TemplateEngine._handlers.has(&"DIRECT_DAMAGE")).is_true()

func _handler(params: Dictionary, state: Variant, caster: Variant,
		target: Variant, secondary: Array) -> Dictionary:
	_calls.append([params, state, caster, target, secondary])
	return {"result": "ok", "effects": []}
