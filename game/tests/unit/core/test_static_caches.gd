extends GdUnitTestSuite

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
