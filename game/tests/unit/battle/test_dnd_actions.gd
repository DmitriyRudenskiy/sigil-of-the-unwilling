extends BaseTest

## Unit-тесты D&D 5e action economy (dnd-battle-system Phase 3, TASK_13..15):
## action_economy, opportunity_attack.

# ---------- TASK_13: Action Economy ----------

func test_one_action_per_turn() -> void:
	var e = DNDActionEconomy.new()
	assert_that(e.can_take_action()).is_true()
	assert_that(e.take_action(DNDActionEconomy.StandardAction.ATTACK)).is_true()
	assert_that(e.can_take_action()).is_false()
	assert_that(e.take_action(DNDActionEconomy.StandardAction.DODGE)).is_false()

func test_bonus_action_requires_source() -> void:
	var e = DNDActionEconomy.new()
	assert_that(e.can_take_bonus_action(false)).is_false()
	assert_that(e.can_take_bonus_action(true)).is_true()
	assert_that(e.take_bonus_action()).is_true()
	assert_that(e.can_take_bonus_action(true)).is_false()

func test_reaction_resets_at_turn_start() -> void:
	var e = DNDActionEconomy.new()
	assert_that(e.use_reaction()).is_true()
	assert_that(e.can_use_reaction()).is_false()
	e.reset_turn()
	assert_that(e.can_use_reaction()).is_true()
	# reset_turn also clears the spent action
	assert_that(e.can_take_action()).is_true()

func test_cannot_take_same_action_twice() -> void:
	var e = DNDActionEconomy.new()
	e.take_action(DNDActionEconomy.StandardAction.DASH)
	assert_that(e.has_taken(DNDActionEconomy.StandardAction.DASH)).is_true()
	assert_that(e.has_taken(DNDActionEconomy.StandardAction.DODGE)).is_false()
	# second action of any kind is blocked
	assert_that(e.take_action(DNDActionEconomy.StandardAction.DODGE)).is_false()

func test_all_ten_standard_actions_defined() -> void:
	var values = DNDActionEconomy.StandardAction.values()
	assert_that(values.size()).is_equal(10)
	for a in values:
		assert_that(DNDActionEconomy.ACTION_NAMES.has(a)).is_true()

func test_available_actions_listing() -> void:
	var e = DNDActionEconomy.new()
	var avail = e.available_actions()
	assert_that(avail.size()).is_equal(12)  # 10 actions + bonus + reaction
	e.take_action(DNDActionEconomy.StandardAction.ATTACK)
	e.use_reaction()
	assert_that(e.available_actions().size()).is_equal(1)  # only bonus action

func test_action_economy_serialization() -> void:
	var e = DNDActionEconomy.new()
	e.take_action(DNDActionEconomy.StandardAction.CAST_A_SPELL)
	e.use_reaction()
	var e2 = DNDActionEconomy.from_dict(e.to_dict())
	assert_that(e2.action_used).is_true()
	assert_that(e2.action_taken).is_equal(DNDActionEconomy.StandardAction.CAST_A_SPELL)
	assert_that(e2.reaction_available).is_false()

# ---------- TASK_15: Opportunity Attacks ----------

func test_oa_triggers_when_leaving_reach() -> void:
	var r = DNDOpportunityAttack.should_trigger(true, false, false, false, true, true)
	assert_that(r.triggered).is_true()

func test_oa_no_trigger_still_in_reach() -> void:
	var r = DNDOpportunityAttack.should_trigger(false, false, false, false, true, true)
	assert_that(r.triggered).is_false()

func test_oa_disengage_prevents() -> void:
	var r = DNDOpportunityAttack.should_trigger(true, true, false, false, true, true)
	assert_that(r.triggered).is_false()

func test_oa_forced_movement_no_trigger() -> void:
	var r = DNDOpportunityAttack.should_trigger(true, false, true, false, true, true)
	assert_that(r.triggered).is_false()

func test_oa_teleport_no_trigger() -> void:
	var r = DNDOpportunityAttack.should_trigger(true, false, false, true, true, true)
	assert_that(r.triggered).is_false()

func test_oa_requires_sight_and_reaction() -> void:
	var no_sight = DNDOpportunityAttack.should_trigger(true, false, false, false, false, true)
	assert_that(no_sight.triggered).is_false()
	var no_reaction = DNDOpportunityAttack.should_trigger(true, false, false, false, true, false)
	assert_that(no_reaction.triggered).is_false()

func test_oa_is_single_attack() -> void:
	# Opportunity attack is one attack roll, not the Attack action.
	assert_that(DNDOpportunityAttack.IS_SINGLE_ATTACK).is_true()
