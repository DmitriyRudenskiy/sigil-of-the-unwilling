extends GdUnitTestSuite

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
