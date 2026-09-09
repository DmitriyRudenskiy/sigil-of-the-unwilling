extends GdUnitTestSuite

const _BattleFX = preload("res://scripts/core/BattleFX.gd")

func test_fx_instantiation() -> void:
	var fx := _BattleFX.new()
	assert_that(fx).is_not_null()
	fx.free()

func test_setup_null_show_calls_no_crash() -> void:
	var fx := _BattleFX.new()
	fx.setup(null)
	fx.show_spell_cast(Vector2i.ZERO, &"test")
	fx.show_heal(Vector2i.ZERO, 10)
	fx.show_damage(Vector2i.ZERO, 5)
	fx.show_status(Vector2i.ZERO, 0)
	fx.show_kill(Vector2i.ZERO, 1)
	assert_that(fx._view).is_null()
	fx.free()
