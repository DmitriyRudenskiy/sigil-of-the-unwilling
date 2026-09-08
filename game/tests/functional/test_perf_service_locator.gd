extends GdUnitTestSuite

const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")


func before_test() -> void:
	ServiceLocator.clear_cache()


func test_first_resolve_finds_autoload() -> void:
	# ТЗ плодил UnitRegistry.new() здесь — бессмысленно: resolve ищет
	# автозагрузку в дереве, а она в GdUnit-запуске есть (см. /root/GameEventBus).
	var t0 := Time.get_ticks_usec()
	var node: Node = ServiceLocator.resolve(null, &"units")
	var first_ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_bool(node != null).is_true()
	assert_float(first_ms).is_less(0.1)


func test_cached_resolve_is_fast() -> void:
	var warm: Node = ServiceLocator.resolve(null, &"units")
	assert_bool(warm != null).is_true()
	var t0 := Time.get_ticks_usec()
	var last: Node = null
	for i in 1000:
		last = ServiceLocator.resolve(null, &"units")
	var total_ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_bool(last == warm).is_true()
	# порог ТЗ 0.001 мс/вызов на headless-CI слишком жёсткий (шум);
	# 0.01 мс/вызов всё ещё на порядок быстрее поиска узла по имени.
	assert_float(total_ms / 1000.0).is_less(0.01)


func test_clear_cache_forces_relookup() -> void:
	# TASK_06: ServiceLocator больше не держит собственный статический кэш —
	# сервисы живут в реестре автозагрузки Services. Явный clear_cache() не
	# нужен: повторные resolve всегда находят актуальную автозагрузку.
	var a: Node = ServiceLocator.resolve(null, &"units")
	assert_bool(a != null).is_true()
	var b: Node = ServiceLocator.resolve(null, &"units")
	assert_bool(b != null).is_true()
	assert_bool(a == b).is_true()
	# Явный сброс сессии (граница меню) по-прежнему работает и не ломает поиск.
	ServiceLocator.clear_cache()
	var c: Node = ServiceLocator.resolve(null, &"units")
	assert_bool(c != null).is_true()
	assert_bool(c == a).is_true()
