extends GdUnitTestSuite

const _BattleFX = preload("res://scripts/core/BattleFX.gd")

func test_fx_instantiation() -> void:
	var fx := _BattleFX.new()
	assert_that(fx).is_not_null()
	fx.free()

func test_setup_null() -> void:
	var fx := _BattleFX.new()
	fx.setup(null)
	assert_bool(true).is_true()
	fx.free()
