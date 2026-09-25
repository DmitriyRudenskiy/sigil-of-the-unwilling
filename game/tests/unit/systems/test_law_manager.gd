extends BaseTest

## Tests for the Law system (dynamic-world-crisis-system — Laws task).
## LawManager is a standalone RefCounted, so the core logic is testable
## without a scene tree. One test wires it through CrisisEventSystem.


func test_default_catalog_has_three_branches() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	assert_that(lm.get_laws_by_branch(LawManager.Branch.ORDER).size()).is_equal(2)
	assert_that(lm.get_laws_by_branch(LawManager.Branch.FAITH).size()).is_equal(2)
	assert_that(lm.get_laws_by_branch(LawManager.Branch.SURVIVAL).size()).is_equal(2)
	assert_that(lm.laws.size()).is_equal(6)


func test_unlock_root_law() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	# Roots have requires == "" and unlock without prerequisites.
	assert_that(lm.unlock_law("order_tax_code")).is_true()
	assert_that(lm.is_law_active("order_tax_code")).is_true()


func test_unlock_tier2_requires_prerequisite() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	# Tier 2 blocked until its prerequisite is active.
	assert_that(lm.unlock_law("order_standing_guard")).is_false()
	assert_that(lm.is_law_active("order_standing_guard")).is_false()
	# Unlock the prerequisite, then tier 2 succeeds.
	assert_that(lm.unlock_law("order_tax_code")).is_true()
	assert_that(lm.unlock_law("order_standing_guard")).is_true()
	assert_that(lm.is_law_active("order_standing_guard")).is_true()


func test_unlock_invalid_id_fails() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	assert_that(lm.unlock_law("does_not_exist")).is_false()


func test_unlock_is_idempotent() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	assert_that(lm.unlock_law("faith_temple")).is_true()
	# Second unlock returns false (already active), not duplicated.
	assert_that(lm.unlock_law("faith_temple")).is_false()
	assert_that(lm.active_laws.count("faith_temple")).is_equal(1)


func test_get_active_laws() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	lm.unlock_law("faith_temple")
	lm.unlock_law("survival_granary")
	var ids: Array[String] = []
	for law in lm.get_active_laws():
		ids.append(law.id)
	assert_that(ids.has("faith_temple")).is_true()
	assert_that(ids.has("survival_granary")).is_true()
	assert_that(lm.get_active_laws().size()).is_equal(2)


func test_passive_effects_merge_by_key() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	assert_that(lm.get_passive_effects()).is_empty()
	lm.unlock_law("order_tax_code")   # production +0.1, happiness -5
	lm.unlock_law("faith_temple")     # morale +8, production -0.05
	var eff: Dictionary = lm.get_passive_effects()
	# production: 0.1 + (-0.05) = 0.05
	assert_that(eff.get("production", 0.0)).is_equal_approx(0.05, 0.001)
	assert_that(eff.get("happiness", 0.0)).is_equal_approx(-5.0, 0.001)
	assert_that(eff.get("morale", 0.0)).is_equal_approx(8.0, 0.001)


func test_passive_effects_accumulate_same_key() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	lm.unlock_law("faith_temple")               # morale +8
	lm.unlock_law("faith_relic_pilgrimage")     # requires temple; morale +5
	var eff: Dictionary = lm.get_passive_effects()
	assert_that(eff.get("morale", 0.0)).is_equal_approx(13.0, 0.001)


func test_serialization_roundtrip() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	lm.unlock_law("order_tax_code")
	lm.unlock_law("order_standing_guard")
	var restored := LawManager.new()
	restored.load_default_catalog()
	restored.from_dict(lm.to_dict())
	assert_that(restored.is_law_active("order_tax_code")).is_true()
	assert_that(restored.is_law_active("order_standing_guard")).is_true()
	assert_that(restored.is_law_active("faith_temple")).is_false()


func test_from_dict_ignores_unknown_ids() -> void:
	var lm := LawManager.new()
	lm.load_default_catalog()
	lm.from_dict({"active_laws": ["order_tax_code", "bogus_law"]})
	assert_that(lm.is_law_active("order_tax_code")).is_true()
	assert_that(lm.is_law_active("bogus_law")).is_false()
	assert_that(lm.active_laws.size()).is_equal(1)


## Wiring: CrisisEventSystem owns a LawManager with the default catalog loaded,
## and an `unlock_law` choice effect value flows through to the manager.
func test_crisis_system_wires_law_manager() -> void:
	var sys := make_node(CrisisEventSystem)  # _ready runs -> law_manager + catalog
	assert_that(sys.law_manager != null).is_true()
	assert_that(sys.law_manager.laws.size()).is_equal(6)
	# Simulate the effect dispatch: a choice with {"unlock_law": id}.
	var choice := CrisisEventSystem.ChoiceData.new({"effects": {"unlock_law": "order_tax_code"}})
	sys.law_manager.unlock_law(str(choice.effects["unlock_law"]))
	assert_that(sys.law_manager.is_law_active("order_tax_code")).is_true()
