extends BaseTest

const BalanceProbe := preload("res://scripts/probe/balance_probe.gd")

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
