extends BaseTest
## autopilot-scenario-matrix: ScenarioPilot + ScenarioTargets — юнит-тесты.

func test_role_targets_table() -> void:
	var ids: Array = ScenarioTargets.role_ids()
	assert_that(ids.size() == 5)
	assert_bool(ScenarioTargets.role("collector").has("rare_goal"))
	assert_bool(ScenarioTargets.role("traveler").has("distance_goal"))
	assert_bool(ScenarioTargets.role("trader").has("gold_goal"))
	assert_bool(ScenarioTargets.role("adventurer").has("kill_goal"))
	assert_bool(ScenarioTargets.role("builder").has("population_goal"))
	assert_bool(ScenarioTargets.role("unknown").is_empty())

func test_max_turns() -> void:
	assert_that(ScenarioTargets.max_turns("collector") == 60)
	assert_that(ScenarioTargets.max_turns("traveler") == 90)
	assert_that(ScenarioTargets.max_turns("builder") == 90)
	assert_that(ScenarioTargets.max_turns("nope") == 60)

func test_seed_deterministic_and_distinct() -> void:
	var s1: int = ScenarioTargets.seed_for("wizard", "collector")
	var s2: int = ScenarioTargets.seed_for("wizard", "collector")
	var s3: int = ScenarioTargets.seed_for("rogue", "collector")
	var s4: int = ScenarioTargets.seed_for("wizard", "traveler")
	assert_that(s1 == s2)
	assert_bool(s1 != s3)
	assert_bool(s1 != s4)
	assert_bool(s1 > 0)

func test_make_role_collector() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("collector", ScenarioTargets.role("collector"))
	assert_that(role != null)
	assert_that(str(role.id) == "collector")
	var pilot := ScenarioPilot.new()
	var m: Dictionary = role.metrics(pilot)
	pilot.free()
	assert_bool(m.has("rare_extracted"))
	assert_that(int(m.get("rare_goal", 0)) == 20)

func test_make_role_unknown() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("nope", {})
	assert_that(role == null)

func test_pilot_extends_balance_probe() -> void:
	var pilot := ScenarioPilot.new()
	assert_bool(pilot is BalanceProbe)
	pilot.free()
