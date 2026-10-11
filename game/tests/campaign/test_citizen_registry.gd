extends BaseTest
## T-116 (старт, раунд 8 §4.4): модель населения — жители (uid, возраст, семья).
## Возраст (1 ход = DAYS_PER_SEASON дней, Q-M26), рождения (K-M12-схема:
## int(k_pop × days)), семьи (инициал — свои; новорождённые — семья-основатель),
## T-050 шов (losses — по character_uid; раненые ≠ потери), миграция
## (Репутация — единственный вход, Э1-3; MVP — no-op, Q-M32), сериализация, I1.

const Registry = preload("res://scripts/campaign/citizen_registry.gd")
const CampaignBattle = preload("res://scripts/campaign/campaign_battle.gd")


func test_initial_state() -> void:
	var r := Registry.new()
	r.create_initial(20)
	assert_int(r.count()).is_equal(20)
	# uids 0..19 (детерминированно, I1).
	for i in 20:
		assert_that(r.has(i)).is_true()
	assert_that(r.has(20)).is_false()
	# Каждый инициал-житель — в своей семье (MVP-упрощение).
	assert_int(r.families().size()).is_equal(20)
	assert_that(r.citizen(0)["family_id"]).is_equal("family_0")
	assert_that(r.citizen(1)["family_id"]).is_equal("family_1")


func test_aging_one_turn() -> void:
	var r := Registry.new()
	r.create_initial(5)
	r.age_turn(WorldSeasons.DAYS_PER_SEASON)  # 20 дней (Q-M26: единственная конверсия)
	for i in 5:
		assert_float(r.citizen(i)["age_days"]).is_equal_approx(20.0, 1e-6)
	r.age_turn(WorldSeasons.DAYS_PER_SEASON)
	assert_float(r.citizen(3)["age_days"]).is_equal_approx(40.0, 1e-6) \
		.override_failure_message("2 хода = 40 дней (возраст накапливается)")


func test_births_k_pop_scheme() -> void:
	# K-M12: n = int(k_pop × days) = int(0.1 × 20) = 2 (MVP: m = 1).
	var r := Registry.new()
	r.create_initial(20)
	var n: int = r.births(0.1, WorldSeasons.DAYS_PER_SEASON)
	assert_int(n).is_equal(2)
	assert_int(r.count()).is_equal(22)
	# Новорождённые: uids 20/21, возраст 0, семья-основатель (family_0;
	# 02f-a-core: «первый уроженец Очага»).
	assert_that(r.citizen(20)["age_days"]).is_equal(0.0)
	assert_that(r.citizen(20)["family_id"]).is_equal("family_0")
	assert_that(r.citizen(21)["family_id"]).is_equal("family_0")


func test_births_zero_when_below_one() -> void:
	# int(0.04 × 20) = int(0.8) = 0 — дробные k_pop не рождают (I1: целые).
	var r := Registry.new()
	r.create_initial(10)
	assert_int(r.births(0.04, WorldSeasons.DAYS_PER_SEASON)).is_equal(0)
	assert_int(r.count()).is_equal(10)


func test_clamp_to_cap() -> void:
	# R3-кап: избыток — последние добавленные (детерминированно, I1).
	var r := Registry.new()
	r.create_initial(20)
	r.births(0.1, WorldSeasons.DAYS_PER_SEASON)  # +2 → 22
	var removed: int = r.clamp_to(20)
	assert_int(removed).is_equal(2)
	assert_int(r.count()).is_equal(20)
	assert_that(r.has(20)).is_false() \
		.override_failure_message("кап вычитает последних (новорождённых), не старейших")
	assert_that(r.has(0)).is_true()
	# Кап выше населения — noop.
	assert_int(r.clamp_to(30)).is_equal(0)


func test_losses_by_character_uid() -> void:
	# T-050 шов: потери — вычитание жителей по character_uid.
	var r := Registry.new()
	r.create_initial(20)
	var removed: int = r.apply_losses([5])
	assert_int(removed).is_equal(1)
	assert_int(r.count()).is_equal(19)
	assert_that(r.has(5)).is_false()
	assert_that(r.has(4)).is_true()
	assert_that(r.has(6)).is_true()
	# Повторный uid — уже не житель (идемпотентно).
	assert_int(r.apply_losses([5])).is_equal(0)


func test_losses_unknown_uid_ignored() -> void:
	# Чужой uid (не житель) — игнорируется, не ошибка (I1: детерминированно).
	var r := Registry.new()
	r.create_initial(20)
	assert_int(r.apply_losses([999])).is_equal(0)
	assert_int(r.count()).is_equal(20)
	# Смесь: свой + чужой.
	assert_int(r.apply_losses([3, 999])).is_equal(1)
	assert_int(r.count()).is_equal(19)


## T-050 шов (интеграция с CampaignBattle): стабилизированный (con ≥ 0) —
## ранен, НЕ потеря: в losses не попадает, население не тронуто.
func test_wounded_are_not_losses_battle_seam() -> void:
	var r := Registry.new()
	r.create_initial(20)
	var hero := CampaignBattle.make_recruit({
		"id": "hero", "hp": 1, "ac": 10, "attack": 5, "damage": 2,
		"luck": 0, "dex": 10, "con": 2, "proficiency": 2,
	}, 7)  # житель uid 7
	var raider := CampaignBattle.make_combatant({
		"id": "raider", "hp": 50, "ac": 5, "attack": 10, "damage": 10,
		"luck": 0, "dex": 10, "con": 0, "proficiency": 2,
	})
	raider["character_uid"] = -1  # рейдер — не житель
	var hook_calls: Array = []
	var hook := func(losses: Array, report: Dictionary) -> void:
		hook_calls.append([losses.duplicate(), report])
		var removed: int = r.apply_losses(losses)
		assert_int(removed).is_equal(0) \
			.override_failure_message("стабилизированный герой — ранен, не потеря (T-116)")
	CampaignBattle.resolve(hero, raider, hook)
	assert_int(hook_calls.size()).is_equal(1) \
		.override_failure_message("эмит — с дня первого боя, даже пустой (§2.2)")
	assert_int(r.count()).is_equal(20) \
		.override_failure_message("раненый (con ≥ 0 → стабилизация) не вычитается")


## T-050 шов (интеграция): мёртвый (con < 0 → death saves 3/3 провал) —
## потеря: uid в losses, житель вычитается.
func test_dead_loss_subtracts_citizen_battle_seam() -> void:
	var r := Registry.new()
	r.create_initial(20)
	var hero := CampaignBattle.make_recruit({
		"id": "hero", "hp": 1, "ac": 10, "attack": 5, "damage": 2,
		"luck": 0, "dex": 10, "con": -2, "proficiency": 2,
	}, 7)  # житель uid 7
	var raider := CampaignBattle.make_combatant({
		"id": "raider", "hp": 50, "ac": 5, "attack": 10, "damage": 10,
		"luck": 0, "dex": 10, "con": 0, "proficiency": 2,
	})
	raider["character_uid"] = -1
	var losses_holder: Array = [[]]  # holder: lambda-перезапись не пробрасывается
	var hook := func(losses: Array, _report: Dictionary) -> void:
		losses_holder[0] = losses.duplicate()
		r.apply_losses(losses)
	CampaignBattle.resolve(hero, raider, hook)
	assert_that(losses_holder[0]).is_equal([7]) \
		.override_failure_message("mёртвый (con < 0) — в losses по character_uid")
	assert_that(r.has(7)).is_false() \
		.override_failure_message("потеря — вычитание жителя по uid")
	assert_int(r.count()).is_equal(19)


## F-3 / Э1-3: миграция — Репутация ЕДИНСТВЕННЫЙ вход (в сигнатуре нет
## prestige — структурно); MVP — no-op (Q-M32: формула TBD).
func test_migration_reputation_only_e1_3() -> void:
	var r := Registry.new()
	r.create_initial(20)
	assert_int(r.apply_migration(100.0)).is_equal(0) \
		.override_failure_message("MVP: миграция no-op (Q-M32)")
	assert_int(r.apply_migration(0.0)).is_equal(0)
	assert_int(r.count()).is_equal(20)


func test_serialization_roundtrip() -> void:
	var r := Registry.new()
	r.create_initial(20)
	r.births(0.1, WorldSeasons.DAYS_PER_SEASON)  # +2 (uids 20/21)
	r.age_turn(WorldSeasons.DAYS_PER_SEASON)
	r.apply_losses([5])
	var data: Dictionary = r.to_dict()
	var r2 := Registry.from_dict(data)
	assert_that(JSON.stringify(r2.to_dict())).is_equal(JSON.stringify(data))
	assert_int(r2.count()).is_equal(21)  # 20 + 2 births − 1 loss
	assert_that(r2.has(5)).is_false()
	# Непрерывность uid после restore (I1: следующий новорождённый — uid 22, не 0).
	r2.births(0.05, WorldSeasons.DAYS_PER_SEASON)  # int(0.05×20) = 1
	assert_that(r2.has(22)).is_true()
	assert_that(r2.citizen(22)["family_id"]).is_equal("family_0")


func test_i1_determinism() -> void:
	var a := Registry.new()
	a.create_initial(20)
	a.age_turn(WorldSeasons.DAYS_PER_SEASON)
	a.births(0.1, WorldSeasons.DAYS_PER_SEASON)
	a.clamp_to(20)
	a.apply_losses([1, 2])
	var b := Registry.new()
	b.create_initial(20)
	b.age_turn(WorldSeasons.DAYS_PER_SEASON)
	b.births(0.1, WorldSeasons.DAYS_PER_SEASON)
	b.clamp_to(20)
	b.apply_losses([1, 2])
	assert_that(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict())) \
		.override_failure_message("I1: одинаковые вводные → одинаковое состояние")


func test_config_loads() -> void:
	# population.json: k_pop 0.1 (K-M12), миграция — Репутация (F-3).
	var cfg: Dictionary = Registry.load_config()
	assert_float(float(cfg.get("k_pop_per_day", -1.0))).is_equal_approx(0.1, 1e-6) \
		.override_failure_message("k_pop — 0.1/день (K-M12) из population.json")
	var mig: Dictionary = cfg.get("migration", {})
	assert_that(str(mig.get("input", ""))).is_equal("reputation") \
		.override_failure_message("F-3: вход миграции — Репутация (не appeal, не Престиж)")
