extends BaseTest

var _heroes: Array = []

func after_test() -> void:
	for h in _heroes:
		if is_instance_valid(h):
			h.free()
	_heroes.clear()

func _track(h: Node) -> Node:
	_heroes.append(h)
	return h

func test_cached_returns_same_result_on_hit() -> void:
	var svc := ResourceChainService.new()
	var cache: Dictionary = {}
	var counter := {"n": 0}
	var build := func() -> Dictionary:
		counter["n"] += 1
		return {"a": 1}
	var r1: Dictionary = svc._cached(1, cache, "fp1", build)
	var r2: Dictionary = svc._cached(1, cache, "fp1", build)
	assert_that(r1).is_equal({"a": 1})
	assert_that(r1 == r2).is_true()
	assert_int(counter["n"]).is_equal(1)

func test_cached_rebuilds_on_fingerprint_change() -> void:
	var svc := ResourceChainService.new()
	var cache: Dictionary = {}
	var counter := {"n": 0}
	var build := func() -> Dictionary:
		counter["n"] += 1
		return {"n": counter["n"]}
	svc._cached(1, cache, "fp1", build)
	var r2: Dictionary = svc._cached(1, cache, "fp2", build)
	assert_int(counter["n"]).is_equal(2)
	assert_that(r2).is_equal({"n": 2})

func test_cached_keys_per_instance() -> void:
	var svc := ResourceChainService.new()
	var cache: Dictionary = {}
	var counter := {"n": 0}
	var build := func() -> Dictionary:
		counter["n"] += 1
		return {"n": counter["n"]}
	svc._cached(1, cache, "fp", build)
	svc._cached(2, cache, "fp", build)
	assert_int(counter["n"]).is_equal(2)

func test_invalidate_clears_both_caches() -> void:
	var svc := ResourceChainService.new()
	assert_int(svc._extraction_cache.size()).is_equal(0)
	assert_int(svc._discovery_cache.size()).is_equal(0)
	svc.invalidate_extraction_cache()
	assert_int(svc._extraction_cache.size()).is_equal(0)
	assert_int(svc._discovery_cache.size()).is_equal(0)

func test_build_extraction_keys_null_hero() -> void:
	var svc := ResourceChainService.new()
	assert_that(svc.build_extraction_keys(null)).is_equal({})

func test_build_discovery_keys_null_hero() -> void:
	var svc := ResourceChainService.new()
	assert_that(svc.build_discovery_keys(null)).is_equal({})

func test_build_extraction_keys_hero_without_army() -> void:
	var svc := ResourceChainService.new()
	var hero := _track(TestFactories.make_hero())
	hero.army_comp = null
	hero.skills_comp = null
	hero.tools_comp = null
	var keys: Dictionary = svc.build_extraction_keys(hero)
	assert_that(keys.has("fire")).is_true()

func test_try_extract_null_mgr() -> void:
	var svc := ResourceChainService.new()
	var hero := _track(TestFactories.make_hero())
	var result: Dictionary = svc.try_extract(null, hero, Vector2i(3, 4))
	assert_that(result.get("error")).is_equal(ResourceNodeManager.NodeError.NODE_NOT_FOUND)
