extends BaseTest
## T17 / D2: разрешение боя по лестнице перевеса (02d v1.2 §3.2).
## Без ГСЧ: два вызова с теми же входами = идентичный результат (K2).

func _unit(stats: UnitStats, count := 5) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(UnitStack.new(stats, count))
	u.max_count = count
	return u

# ═══════════ Лестница (зоны по перевесу) ═══════════

func test_ladder_zone_base_thresholds() -> void:
	assert_str(BattleRules.ladder_zone(4)).is_equal(str(BattleRules.ZONE_TRIUMPH))
	assert_str(BattleRules.ladder_zone(10)).is_equal(str(BattleRules.ZONE_TRIUMPH))
	assert_str(BattleRules.ladder_zone(3)).is_equal(str(BattleRules.ZONE_SUCCESS))
	assert_str(BattleRules.ladder_zone(0)).is_equal(str(BattleRules.ZONE_SUCCESS))
	assert_str(BattleRules.ladder_zone(-3)).is_equal(str(BattleRules.ZONE_PARTIAL))
	assert_str(BattleRules.ladder_zone(-4)).is_equal(str(BattleRules.ZONE_FAILURE))
	assert_str(BattleRules.ladder_zone(-7)).is_equal(str(BattleRules.ZONE_FAILURE))
	assert_str(BattleRules.ladder_zone(-8)).is_equal(str(BattleRules.ZONE_FUMBLE))
	assert_str(BattleRules.ladder_zone(-20)).is_equal(str(BattleRules.ZONE_FUMBLE))

func test_ladder_zone_luck_shifts_thresholds() -> void:
	# Удачливый (мод +3): триумф уже при перевесе +1 (не ниже +1),
	# частичная зона до −6, критпровал при −11.
	assert_str(BattleRules.ladder_zone(1, 3)).is_equal(str(BattleRules.ZONE_TRIUMPH))
	assert_str(BattleRules.ladder_zone(0, 3)).is_equal(str(BattleRules.ZONE_SUCCESS))
	assert_str(BattleRules.ladder_zone(-6, 3)).is_equal(str(BattleRules.ZONE_PARTIAL))
	assert_str(BattleRules.ladder_zone(-7, 3)).is_equal(str(BattleRules.ZONE_FAILURE))
	assert_str(BattleRules.ladder_zone(-11, 3)).is_equal(str(BattleRules.ZONE_FUMBLE))
	# Непослушный (мод −1): триумф при +5, частичной зоны до −2 нет при −3.
	assert_str(BattleRules.ladder_zone(4, -1)).is_equal(str(BattleRules.ZONE_SUCCESS))
	assert_str(BattleRules.ladder_zone(5, -1)).is_equal(str(BattleRules.ZONE_TRIUMPH))
	assert_str(BattleRules.ladder_zone(-3, -1)).is_equal(str(BattleRules.ZONE_FAILURE))
	assert_str(BattleRules.ladder_zone(-7, -1)).is_equal(str(BattleRules.ZONE_FUMBLE))

# ═══════════ Разрешение атаки (детерминизм) ═══════════

func test_calculate_attack_is_deterministic() -> void:
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 10))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var r1 := BattleRules.calculate_attack(atk, def, true, 0, 0)
	var r2 := BattleRules.calculate_attack(atk, def, true, 0, 0)
	assert_dict(r1).is_equal(r2)

func test_calculate_attack_zone_success_full_damage() -> void:
	# margin = 10 − 10 = 0 → Успех: полный урон base_damage × count.
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 10), 4)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var r := BattleRules.calculate_attack(atk, def, true, 0, 0)
	assert_str(r["zone"]).is_equal(str(BattleRules.ZONE_SUCCESS))
	assert_int(r["damage"]).is_equal(20)
	assert_int(r["kills"]).is_equal(2)  # 20 / hp 10 = 2

func test_calculate_attack_zone_triumph_double_damage() -> void:
	# margin = 14 − 10 = 4 → Триумф: урон ×2.
	var atk := _unit(UnitStats.new("a", "A", 14, 5, 1, 1, 10), 4)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var r := BattleRules.calculate_attack(atk, def, true, 0, 0)
	assert_str(r["zone"]).is_equal(str(BattleRules.ZONE_TRIUMPH))
	assert_int(r["damage"]).is_equal(40)

func test_calculate_attack_zone_partial_half_damage() -> void:
	# margin = 7 − 10 = −3 → Частичный: половина урона.
	var atk := _unit(UnitStats.new("a", "A", 7, 5, 1, 1, 10), 4)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var r := BattleRules.calculate_attack(atk, def, true, 0, 0)
	assert_str(r["zone"]).is_equal(str(BattleRules.ZONE_PARTIAL))
	assert_int(r["damage"]).is_equal(10)

func test_calculate_attack_zone_failure_no_damage() -> void:
	# margin = 5 − 10 = −5 → Провал: промах, урона нет, никто не мёртв.
	var atk := _unit(UnitStats.new("a", "A", 5, 5, 1, 1, 10), 4)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var r := BattleRules.calculate_attack(atk, def, true, 0, 0)
	assert_str(r["zone"]).is_equal(str(BattleRules.ZONE_FAILURE))
	assert_int(r["damage"]).is_equal(0)
	assert_int(r["kills"]).is_equal(0)
	assert_bool(r.get("fumble", false)).is_false()

func test_calculate_attack_zone_fumble_flag() -> void:
	# margin = 1 − 10 = −9 → Критпровал: фамбл.
	var atk := _unit(UnitStats.new("a", "A", 1, 5, 1, 1, 10), 4)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var r := BattleRules.calculate_attack(atk, def, true, 0, 0)
	assert_str(r["zone"]).is_equal(str(BattleRules.ZONE_FUMBLE))
	assert_int(r["damage"]).is_equal(0)
	assert_int(r["kills"]).is_equal(0)
	assert_bool(r.get("fumble", false)).is_true()

func test_calculate_attack_luck_mod_shifts_zone() -> void:
	# margin = 10 − 10 = 0: без Удачи — Успех, с УДЧ-модом +3 — тоже Успех
	# (триумф требует ≥1), но при margin +1 и моде +3 — Триумф.
	var atk0 := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 10))
	var atk1 := _unit(UnitStats.new("b", "B", 11, 5, 1, 1, 10))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	assert_str(BattleRules.calculate_attack(atk0, def, true, 0, 0, 1.0, 1.0, -1, 0, 3)["zone"]) \
		.is_equal(str(BattleRules.ZONE_SUCCESS))
	assert_str(BattleRules.calculate_attack(atk1, def, true, 0, 0, 1.0, 1.0, -1, 0, 3)["zone"]) \
		.is_equal(str(BattleRules.ZONE_TRIUMPH))

func test_flank_gives_advantage_margin() -> void:
	# margin = 6 − 10 = −4 → Провал; с флангом (+2) → −2 → Частичный.
	var atk := _unit(UnitStats.new("a", "A", 6, 5, 1, 1, 10), 4)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	assert_str(BattleRules.calculate_attack(atk, def, true, 0, 0, 1.0, 1.0, 1)["zone"]) \
		.is_equal(str(BattleRules.ZONE_PARTIAL))
	assert_str(BattleRules.calculate_attack(atk, def, true, 0, 0, 1.0, 1.0, -1)["zone"]) \
		.is_equal(str(BattleRules.ZONE_FAILURE))

func test_rear_halves_defense_and_gives_advantage() -> void:
	# margin = 8 − 10 = −2 → Провал; тыл: def ×0.5 → 8 − 5 = 3, +2 → 5 → Триумф.
	var atk := _unit(UnitStats.new("a", "A", 8, 5, 1, 1, 10), 4)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var r := BattleRules.calculate_attack(atk, def, true, 0, 0, 1.0, 1.0, 2)
	assert_str(r["zone"]).is_equal(str(BattleRules.ZONE_TRIUMPH))

func test_defending_boosts_defense() -> void:
	# margin = 10 − 10 = 0 → Успех; защита ×1.2 → 10 − 12 = −2 → Частичный.
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 10))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	def.defending = true
	assert_str(BattleRules.calculate_attack(atk, def, true, 0, 0)["zone"]) \
		.is_equal(str(BattleRules.ZONE_PARTIAL))

func test_ranged_melee_penalty_still_applies() -> void:
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var ranged := _unit(UnitStats.new("r", "R", 14, 5, 1, 1, 10, ["ranged"]), 4)
	var melee := _unit(UnitStats.new("m", "M", 14, 5, 1, 1, 10), 4)
	var melee_r := BattleRules.calculate_attack(melee, def, true, 0, 0)
	var ranged_r := BattleRules.calculate_attack(ranged, def, true, 0, 0)
	assert_int(ranged_r["damage"]).is_equal(int(melee_r["damage"] * 0.5))

func test_kills_capped_by_defender_count() -> void:
	var atk := _unit(UnitStats.new("a", "A", 100, 100, 1, 1, 0), 10)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 1, 1, 0), 3)
	var r := BattleRules.calculate_attack(atk, def, true, 0, 0)
	assert_int(r["kills"]).is_equal(3)

func test_dead_units_return_empty() -> void:
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 0))
	def.alive = false
	assert_dict(BattleRules.calculate_attack(atk, def, true, 0, 0)).is_empty()

func test_preview_text_deterministic() -> void:
	var atk := _unit(UnitStats.new("a", "A", 14, 5, 1, 1, 10), 4)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	var t1 := BattleRules.preview_text(atk, def, 0, 0)
	var t2 := BattleRules.preview_text(atk, def, 0, 0)
	assert_str(t1).is_equal(t2)
	assert_str(t1).contains("Damage:")

# ═══════════ Иммунитеты (без изменений) ═══════════

func test_can_luck_immune_tags() -> void:
	assert_bool(BattleRules.can_luck(_unit(UnitStats.new("u", "U", 1, 1, 1, 1, 1, ["undead"])))).is_false()
	assert_bool(BattleRules.can_luck(_unit(UnitStats.new("e", "E", 1, 1, 1, 1, 1, ["elemental"])))).is_false()
	assert_bool(BattleRules.can_luck(_unit(UnitStats.new("m", "M", 1, 1, 1, 1, 1, ["mind_immune"])))).is_false()
	assert_bool(BattleRules.can_luck(_unit(UnitStats.new("n", "N", 1, 1, 1, 1, 1)))).is_true()
	assert_bool(BattleRules.can_luck(null)).is_false()

func test_can_morale_dragon_immune() -> void:
	assert_bool(BattleRules.can_morale(_unit(UnitStats.new("d", "D", 1, 1, 1, 1, 1, ["dragon"])))).is_false()
	assert_bool(BattleRules.can_morale(_unit(UnitStats.new("n", "N", 1, 1, 1, 1, 1)))).is_true()
