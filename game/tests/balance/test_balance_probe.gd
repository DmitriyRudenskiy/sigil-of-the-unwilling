extends BaseTest

const BalanceProbe := preload("res://scripts/probe/balance_probe.gd")

func test_probe_avoids_reengaging_an_enemy_after_losing() -> void:
	var probe := BalanceProbe.new()
	var city := City.new()
	city.center = Vector2i(10, 10)
	var map := _FakeMap.new()
	map.enemy_stacks = {Vector2i(10, 10): [], Vector2i(12, 10): []}
	var world := _FakeWorld.new()
	world.map = map
	probe._player_city = city
	probe._world = world

	assert_that(probe._nearest_city_threat()).is_equal(Vector2i(10, 10))
	probe._on_battle_lost(Vector2i(10, 10))
	assert_that(probe._nearest_city_threat()).is_equal(Vector2i(12, 10))
	assert_that(probe.losses).is_equal(1)
	probe.free()
	world.free()

class _FakeMap:
	var enemy_stacks: Dictionary = {}

class _FakeWorld extends Node:
	var map: _FakeMap
	func get_map_gen(): return map

func test_balance_report_embeds_cached_campaign_city_metrics() -> void:
	var probe := BalanceProbe.new()
	var report := probe.report()
	var city_report: Dictionary = report.campaign_city

	assert_bool(city_report.ok).is_true()
	assert_bool(city_report.balance_pass).is_true()
	assert_that(city_report.construction_summary.affordability.attempted).is_equal(15)
	assert_that(city_report.construction_summary.affordability.affordable).is_equal(15)
	assert_that(city_report.summary.day21_group_coverage.size()).is_equal(7)
	assert_float(float(city_report.summary.day21_stocks.food)).is_equal_approx(1.1, 0.0001)
	assert_that(probe.report()).is_equal(report)
	probe.free()
