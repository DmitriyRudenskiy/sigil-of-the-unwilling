extends BaseTest
## scarce-crafting-system 3.3/4.3: стоки крафта не ломают экономику.
## Симуляция: герой добывает ресурсы (узел + трофеи боя) и крафтит;
## ресурсы никогда не уходят в минус, темп крафта в допуске.

const SIM_DAYS := 300
const SEED := 20260928


func _strategic() -> HeroStrategicResources:
	var s := HeroStrategicResources.new()
	s._resources = {}
	for id in [&"oak", &"silver", &"quartz", &"saltpeter", &"turquoise", &"limonite",
			&"coal", &"gold_ore", &"coal_swamp", &"bog_iron", &"cinnabar", &"wood", &"stone"]:
		s._resources[id] = 0
	return s


func test_crafting_sink_never_negative_over_300_days() -> void:
	var sys := CraftingSystem.new()
	assert_int(sys.load_recipes()).is_equal(10)
	var s := _strategic()
	# Поздняя игра: герой с телегой (cap 12 + 6 = 18).
	s.capacity_bonus = GameNumbersHero.BACKPACK_CART_BONUS
	var inv := HeroInventory.new()
	var ctx := CraftingSystem.CraftingContext.new()
	ctx.strategic = s
	ctx.inventory = inv
	ctx.tech_tier = 5
	ctx.has_workshop = true

	var crafted := 0
	for day in range(1, SIM_DAYS + 1):
		# Добыча: узлы дают базовые ресурсы (оak — для щита).
		s._add_internal(&"wood", 2)
		s._add_internal(&"stone", 2)
		s._add_internal(&"bog_iron", 2)
		s._add_internal(&"coal", 1)
		s._add_internal(&"oak", 1)
		# Каждый 3-й день — победа в бою → трофей (редкие ресурсы).
		if day % 3 == 0:
			var trophy: Dictionary = BattleTrophyService.roll_trophy()
			s.add(trophy["resource"], int(trophy["amount"]))

		# Герой крафтит доступные рецепты (жадность; при неудаче — следующий,
		# т.к. повторный id рюкзаком запрещён).
		for r in sys.get_recipes():
			var recipe: CraftingSystem.CraftingRecipe = r
			if sys.can_craft(recipe.id, ctx)["ok"]:
				var res := sys.craft(recipe.id, ctx)
				if bool(res["ok"]):
					crafted += 1

		# Инвариант: ни один ресурс не ушёл в минус, рюкзак не переполнен.
		for id in s.get_all():
			assert_that(int(s.get_all()[id])).is_greater_equal(0)
		assert_that(inv.backpack.size()).is_less_equal(HeroInventory.MAX_BACKPACK)

	# Темп: базовые рецепты (wooden_shield, stone_axe, iron_sword) доступны
	# из добычи — ≥3 крафта; повторный крафт того же id рюкзаком запрещён,
	# поэтому потолок — MAX_BACKPACK.
	assert_that(crafted).is_greater_equal(3)
	assert_that(crafted).is_less_equal(HeroInventory.MAX_BACKPACK)
	# Разблокировано рецептов ≤ общего числа.
	assert_that(sys.unlocked.size()).is_less_equal(sys.recipes.size())


func test_trophy_income_bounded() -> void:
	# Трофеи — единственный не-узел источник редких ресурсов: 1–3 единицы
	# за победу. За 100 побед максимум 300 единиц суммарно.
	BattleTrophyService.reset_for_tests()
	var total := 0
	for i in 100:
		var t: Dictionary = BattleTrophyService.roll_trophy()
		total += int(t["amount"])
	assert_that(total).is_greater_equal(100)  # минимум 1 за победу
	assert_that(total).is_less_equal(300)     # максимум 3 за победу
	# Среднее в диапазоне [1.5, 2.5] (равномерное 1..3 → 2).
	assert_float(float(total) / 100.0).is_between(1.5, 2.5)


func test_recipe_costs_are_sinks_not_sources() -> void:
	# Баланс: каждый рецепт — чистый сток (списывает сырьё, не создаёт
	# ресурсы). Суммарная стоимость сырья в рецепте > 0.
	var sys := CraftingSystem.new()
	assert_int(sys.load_recipes()).is_equal(10)
	for r in sys.get_recipes():
		var recipe: CraftingSystem.CraftingRecipe = r
		var total_cost := 0
		for res_id in recipe.resources:
			total_cost += int(recipe.resources[res_id])
		assert_that(total_cost).is_greater(0)
		assert_that(recipe.weight).is_greater(0.0)
