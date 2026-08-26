extends "res://tests/test_base.gd"

const _BattleFX = preload("res://scripts/util/BattleFX.gd")

func test_fx_instantiation() -> void:
	var fx := _BattleFX.new()
	assert_not_null(fx, "fx created")

func test_setup_null() -> void:
	var fx := _BattleFX.new()
	fx.setup(null)
	assert_true(true, "setup runs without error")
