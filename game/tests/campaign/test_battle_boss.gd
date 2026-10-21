extends BaseTest

## V-3 (D-218): минимальный босс — 2 способности, параметры в данных.
## 1. Мощный удар: детерминированный таргетинг (штатный), базовый урон ×1.5,
##    кулдаун 2 хода, без случайности.
## 2. Фаза ярости: один раз при HP ≤ 50% max_hp, +25% урона.
## Без зон/координат/сетки; не-боссы не затронуты; детерминизм (K2).

const Battle := preload("res://scripts/campaign/campaign_battle.gd")

## Босс: высокий урон и атака, большой HP. is_boss + параметры способностей.
var _boss := {
	"id": "boss", "character_uid": -1, "hp": 100, "max_hp": 100,
	"ac": 10, "attack": 20, "damage": 10, "luck": 0, "dex": 20, "con": 3,
	"proficiency": 2, "is_boss": true,
	"boss_powerful_strike_mult": 1.5, "boss_powerful_strike_cooldown": 2,
	"boss_rage_threshold": 0.5, "boss_rage_damage_mult": 1.25,
}
## Герой: много HP, не бьёт (для тестов мощного удара/кулдауна).
var _hero := {
	"id": "hero", "character_uid": 1, "hp": 10000, "ac": 10, "attack": 0,
	"damage": 0, "luck": 0, "dex": 10, "con": 1, "proficiency": 2,
}
## Герой-раннер: бьёт босса (для теста ярости).
var _hero_runner := {
	"id": "hero", "character_uid": 1, "hp": 10000, "ac": 10, "attack": 20,
	"damage": 10, "luck": 0, "dex": 10, "con": 1, "proficiency": 2,
}


func _c(spec: Dictionary) -> Dictionary:
	return Battle.make_combatant(spec)


## Удары босса из trace (actor == "boss", не death_saves/boss_rage).
func _boss_strikes(trace: Array) -> Array:
	var out: Array = []
	for t in trace:
		if str(t.get("actor", "")) == "boss" and str(t.get("zone", "")) != "boss_rage" \
				and str(t.get("zone", "")) != "death_saves":
			out.append(t)
	return out


func _rage_events(trace: Array) -> Array:
	var out: Array = []
	for t in trace:
		if str(t.get("zone", "")) == "boss_rage":
			out.append(t)
	return out


## — Мощный удар —

func test_boss_powerful_strike_first_turn() -> void:
	var boss := _c(_boss.duplicate(true))
	var hero := _c(_hero.duplicate(true))
	var report := Battle.resolve(boss, hero)
	var strikes := _boss_strikes(report["trace"])
	assert_int(strikes.size()).is_greater(0)
	# Первый удар босса — мощный (×1.5). Margin 20−10=10 → Triumph (×2):
	# базовый 10×2=20, мощный 20×1.5=30.
	assert_bool(bool(strikes[0].get("boss_powerful", false))).is_true()
	assert_int(int(strikes[0]["damage"])).is_equal(30)


func test_boss_powerful_strike_cooldown() -> void:
	var boss := _c(_boss.duplicate(true))
	var hero := _c(_hero.duplicate(true))
	var report := Battle.resolve(boss, hero)
	var strikes := _boss_strikes(report["trace"])
	# Кулдаун 2: мощный на ходу 1, обычные на 2–3, мощный снова на 4.
	assert_bool(bool(strikes[0].get("boss_powerful", false))).is_true()
	assert_int(int(strikes[0]["damage"])).is_equal(30)
	assert_bool(bool(strikes[1].get("boss_powerful", false))).is_false()
	assert_int(int(strikes[1]["damage"])).is_equal(20)
	assert_bool(bool(strikes[2].get("boss_powerful", false))).is_false()
	assert_int(int(strikes[2]["damage"])).is_equal(20)
	assert_bool(bool(strikes[3].get("boss_powerful", false))).is_true()
	assert_int(int(strikes[3]["damage"])).is_equal(30)


func test_boss_powerful_strike_no_randomness() -> void:
	# Детерминизм (K2): два одинаковых боя — одинаковый trace.
	var report1 := Battle.resolve(_c(_boss.duplicate(true)), _c(_hero.duplicate(true)))
	var report2 := Battle.resolve(_c(_boss.duplicate(true)), _c(_hero.duplicate(true)))
	assert_str(str(report1["trace"])).is_equal(str(report2["trace"]))


## — Фаза ярости —

func test_boss_rage_activation_at_threshold() -> void:
	var boss := _c(_boss.duplicate(true))
	var hero := _c(_hero_runner.duplicate(true))
	var report := Battle.resolve(boss, hero)
	var rages := _rage_events(report["trace"])
	# Ярость активируется ровно один раз.
	assert_int(rages.size()).is_equal(1)
	# Босс (dex 20) действует первым; герой бьёт на 20/раунд (Triumph ×2).
	# HP босса: 100 → 80 (х1) → 60 (х2) → 40 (х3 ≤ 50 → ярость).
	assert_int(int(rages[0]["round"])).is_equal(3)


func test_boss_rage_damage_bonus() -> void:
	var boss := _c(_boss.duplicate(true))
	var hero := _c(_hero_runner.duplicate(true))
	var report := Battle.resolve(boss, hero)
	var strikes := _boss_strikes(report["trace"])
	# Ярость активируется после хода 3 (hero бьёт босса). Удар босса на
	# ходу 4 — первый с яростью: мощный (×1.5) + ярость (×1.25):
	# 10×2=20, ×1.5=30, ×1.25=37.5 → 38.
	var strike4: Dictionary = strikes[3]
	assert_bool(bool(strike4.get("boss_rage", false))).is_true()
	assert_int(int(strike4["damage"])).is_equal(38)
	# Удар до ярости (ход 3) — без ярости.
	assert_bool(bool(strikes[2].get("boss_rage", false))).is_false()


func test_boss_rage_not_reactivated() -> void:
	var boss := _c(_boss.duplicate(true))
	var hero := _c(_hero_runner.duplicate(true))
	var report := Battle.resolve(boss, hero)
	# После активации ярость не сбрасывается и не повторяется.
	assert_bool(bool(boss.get("_boss_rage_active", false))).is_true()
	assert_int(_rage_events(report["trace"]).size()).is_equal(1)


func test_boss_rage_threshold_data_driven() -> void:
	# Порог ярости — из данных: 0.75 → активация при HP ≤ 75.
	var spec := _boss.duplicate(true)
	spec["boss_rage_threshold"] = 0.75
	var boss := _c(spec)
	var hero := _c(_hero_runner.duplicate(true))
	var report := Battle.resolve(boss, hero)
	var rages := _rage_events(report["trace"])
	# HP босса: 100 → 80 (х1 ≤ 75? нет, 80 > 75) → 60 (х2 ≤ 75 → ярость).
	# Wait: 80 > 75, so no rage after h1. 60 ≤ 75, rage after h2.
	assert_int(rages.size()).is_equal(1)
	assert_int(int(rages[0]["round"])).is_equal(2)


## — Не-боссы не затронуты —

func test_non_boss_no_powerful_strike() -> void:
	var spec := _boss.duplicate(true)
	spec["is_boss"] = false  # тот же статблок, но без флага босса
	var a := _c(spec)
	var b := _c(_hero_runner.duplicate(true))
	var report := Battle.resolve(a, b)
	for t in report["trace"]:
		assert_bool(bool(t.get("boss_powerful", false))).is_false()
		assert_bool(bool(t.get("boss_rage", false))).is_false()
	assert_int(_rage_events(report["trace"]).size()).is_equal(0)


func test_non_boss_behavior_unchanged() -> void:
	# Не-босс бьёт штатным _strike: margin 20−10=10 → Triumph, урон 10×2=20
	# (без ×1.5 мощного удара).
	var spec := _boss.duplicate(true)
	spec["is_boss"] = false
	var a := _c(spec)
	var b := _c(_hero.duplicate(true))
	var report := Battle.resolve(a, b)
	var strikes := _boss_strikes(report["trace"])
	# Переименовываем: actor = "boss" (id не меняем), но это не босс.
	assert_int(strikes.size()).is_greater(0)
	assert_int(int(strikes[0]["damage"])).is_equal(20)
	assert_bool(bool(strikes[0].get("boss_powerful", false))).is_false()
