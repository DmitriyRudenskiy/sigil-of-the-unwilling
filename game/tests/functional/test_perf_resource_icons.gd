extends BaseTest


func before_test() -> void:
	ResourceIcons.clear_cache()

func test_get_color_stable_and_fast() -> void:
	var first: Color = ResourceIcons.get_color(&"wood")
	assert_bool(first.a == 1.0).is_true()
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		ResourceIcons.get_color(&"wood")
	var total_ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_float(total_ms).is_less(50.0)

func test_get_texture_null_for_classic_and_fast() -> void:

	assert_bool(ResourceIcons.get_texture(&"wood") == null).is_true()
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		ResourceIcons.get_texture(&"wood")
	var total_ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_float(total_ms).is_less(50.0)

func test_clear_cache_keeps_results_stable() -> void:
	var c1: Color = ResourceIcons.get_color(&"gold")
	ResourceIcons.clear_cache()
	var c2: Color = ResourceIcons.get_color(&"gold")
	assert_bool(c1 == c2).is_true()
	assert_str(GameText.resource_name(&"gold")).is_equal("Золото")
