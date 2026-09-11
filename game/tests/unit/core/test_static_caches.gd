extends BaseTest

# TASK_20_1: HexGrid.shift_right — глобальное состояние; восстанавливаем после каждого теста,
# чтобы провал на середине не протекал в соседние тесты.
var _saved_shift_right: bool

func before_test() -> void:
	_saved_shift_right = HexGrid.shift_right

func after_test() -> void:
	HexGrid.shift_right = _saved_shift_right

func test_reset_all_clears_caches() -> void:

	HexGrid.shift_right = false
	var tex := PlaceholderTexture.circle(4, Color.WHITE, Color.BLACK)
	assert_object(tex)
	assert_bool(PlaceholderTexture._cache.size() > 0)
	assert_bool(ResourceAtlas._ensure_map().size() > 0)

	StaticCaches.reset_all()

	assert_bool(HexGrid.shift_right).is_true()
	assert_bool(PlaceholderTexture._cache.is_empty())
	assert_bool(ResourceAtlas._cache.is_empty())
	assert_bool(ResourceAtlas._map.is_empty())
	assert_bool(UnitSprites._portrait_cache.is_empty())
