extends BaseTest

## T-309 / Q-M120: шов двух регистров кампейн-запасов (pin состояния, не приёмка).
##
## У запасов поселения в живом кампейне **два** живых регистра, и они не сведены:
##   * `settlement.stocks` — вектор K-D5, его каждый тик двигает
##     `SettlementProcessor._process_day` (`settlement_processor.gd:129`,
##     `stocks[r] += prod − cons`), его же вычитает охотник рейдов
##     (`threat_system._resolve_raid`, строка 335) и его пишет в сейв секцией
##     `resources` (`campaign_composition.gd:710`);
##   * `city.resource_ctx` — реестр города-носителя: из него платят за постройку
##     (`campaign_building_construction_service.gd:78`), за тренировку
##     (`campaign_training_service.gd:149`) и корону (`city_income_processor.gd:24`),
##     его показывает полоса ресурсов (`campaign_counters.gd:145`).
##
## Что зафиксировано (замер 2026-10-29, сид 12345, `game/tools/diag_stocks_registers.gd`):
## день 0 — регистры равны (город сеется значением вектора:
## `campaign_composition.gd:490` → `campaign_city.gd:72`); день 5 — `stocks` food
## 292.0 / wood 66.0 / iron 28.8 при `ctx` 600.0 / 20.0 / 10.0; день 20 — `stocks`
## food **−651.9** при тех же 600.0 (ход 21 — финальный рейд, дальше тики пустые).
##
## Иными словами постановка T-309 была неточна в две стороны: «регистр, который никто
## не тратит» — ложь (его тратят три сервиса), и «регистры разные уже на старте» —
## ложь (на старте они равны; расходятся на первом же тике).
## Верный диагноз: продукция и потребление не доходят до реестра города, траты
## города не доходят до вектора поселения — игрок видит 600 еды бесконечно,
## пока канонический вектор голодает. Сведение в один носитель — вопрос владельцу
## Q-M120 (варианты и цена — там же), здесь шов закреплён тестом, как это сделано
## для параллельной проблемы носителей населения (`test_population_carriers_seam.gd`).
##
## Кейсы 1–3 краснеют при любой половине сведения (синхронизация в одну сторону),
## кейс 4 краснеет, когда трата города начинает попадать в секцию `resources`
## (тогда же закрывается AC-2 тикета и правится Q-M120).

const SEED := 12345
const DAYS := 5
const RESOURCES: Array[String] = ["food", "wood", "iron"]


func _stocks(comp: CampaignComposition, resource_id: String) -> float:
	return float(comp.settlement.stocks.get(resource_id, 0.0))


func _ctx(comp: CampaignComposition, resource_id: String) -> float:
	return comp.city.resource_ctx.amount(StringName(resource_id))


## 1) На старте регистры равны: город сеется из вектора поселения, а не живёт своей
## стартовой раздачей. Это опровергает исходную формулировку T-309 о «700 против 600
## на старте» (700 — число после тиков продукции, а не стартовое).
func test_both_registers_start_from_the_same_seed() -> void:
	var comp: CampaignComposition = CampaignComposition.from_campaign_config(SEED)
	for r in RESOURCES:
		assert_float(_ctx(comp, r)).override_failure_message(
			"%s: реестр города обязан стартовать значением вектора поселения" % r
		).is_equal_approx(_stocks(comp, r), 0.001)


## 2) Тик кампании двигает только вектор поселения; реестр города за те же дни
## не меняется ни на единицу. Это и есть дыра: продукция/потребление/рейды не
## доходят до носителя, которым платят и который показывает полоса ресурсов.
func test_daily_tick_moves_only_the_settlement_vector() -> void:
	var comp: CampaignComposition = CampaignComposition.from_campaign_config(SEED)
	var start: Dictionary = {}
	for r in RESOURCES:
		start[r] = _stocks(comp, r)
	for _day in DAYS:
		comp.advance_turn()
	var moved := false
	for r in RESOURCES:
		var now := _stocks(comp, r)
		assert_float(_ctx(comp, r)).override_failure_message(
			"%s: реестр города не должен меняться от тика экономики — мост между регистрами не построен" % r
		).is_equal_approx(float(start[r]), 0.001)
		if absf(now - float(start[r])) > 0.001:
			moved = true
	assert_bool(moved).override_failure_message(
		"за %d тиков ни один ресурс вектора поселения не сдвинулся — зонд больше не измеряет того, что описано здесь" % DAYS
	).is_true()


## 3) Сейвовая секция `resources` — вектор поселения, а не реестр города. Пока
## живут оба регистра, читатель секции (метрики, якоря, отладка) видит голод,
## а игрок на полосе ресурсов — замороженные значения.
func test_save_resources_section_is_the_settlement_vector() -> void:
	var comp: CampaignComposition = CampaignComposition.from_campaign_config(SEED)
	for _day in DAYS:
		comp.advance_turn()
	var saved: Dictionary = comp.build_save_state().get("resources", {})
	for r in RESOURCES:
		assert_float(float(saved.get(r, 0.0))).override_failure_message(
			"%s: секция resources пишется из settlement.stocks" % r
		).is_equal_approx(_stocks(comp, r), 0.001)


## 4) Трата города (заявка тренировки, прод-путь) списывается с реестра города,
## в секцию `resources` не попадает, но переживает round-trip — её несёт секция
## `city.campaign_city` (`city_serializer.gd:41` → `resource_ctx.deserialize`).
## AC-1 тикета («трата не потеряна») поэтому уже исполнен; не исполнено только
## сведение носителей, и этот кейс краснеет первым, когда его начнут делать.
func test_city_spending_skips_the_save_resources_section_but_survives_roundtrip() -> void:
	var comp: CampaignComposition = CampaignComposition.from_campaign_config(SEED)
	var city: City = comp.city
	while city.pop.size() < 40:
		city.add_migrant(PopUnit.State.WORKER, 0)
	city.resource_ctx.add(&"food", 100.0)
	city.resource_ctx.add(&"iron", 20.0)
	city.campaign_buildings.append({"uid": 7, "id": "campaign_barracks", "state": "active",
		"construction_turns_remaining": 0, "cell": city.center})
	var food_before := _ctx(comp, "food")
	var iron_before := _ctx(comp, "iron")
	var stocks_food_before := _stocks(comp, "food")

	var alive := PartySystem.alive_members(comp.party).size()
	var request := CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), 7, "fighter",
		{"id": "new_guard", "name": "Guard", "race": "humans",
			"stats": {"str": 13, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}}, alive)
	assert_bool(request.ok).override_failure_message(str(request.get("reason", ""))).is_true()

	var food_after := _ctx(comp, "food")
	var iron_after := _ctx(comp, "iron")
	assert_bool(food_after < food_before).override_failure_message(
		"тренировка обязана списать еду с реестра города: %s → %s" % [food_before, food_after]
	).is_true()
	assert_bool(iron_after < iron_before).override_failure_message(
		"тренировка обязана списать железо с реестра города: %s → %s" % [iron_before, iron_after]
	).is_true()
	assert_float(_stocks(comp, "food")).override_failure_message(
		"вектор поселения о трате города не знает — моста нет"
	).is_equal_approx(stocks_food_before, 0.001)

	var state: Dictionary = comp.build_save_state()
	assert_float(float((state.get("resources", {}) as Dictionary).get("food", 0.0))) \
		.override_failure_message("секция resources осталась вектором поселения (трата города в неё не вошла)").is_equal_approx(stocks_food_before, 0.001)

	var restored: CampaignComposition = CampaignComposition.from_campaign_config(SEED)
	restored.load_save_state(state)
	assert_float(_ctx(restored, "food")).override_failure_message(
		"реестр города восстанавливается секцией city.campaign_city: трата не потеряна (AC-1 T-309)"
	).is_equal_approx(food_after, 0.001)
	assert_float(_stocks(restored, "food")).override_failure_message(
		"вектор поселения восстанавливается секцией resources"
	).is_equal_approx(stocks_food_before, 0.001)
