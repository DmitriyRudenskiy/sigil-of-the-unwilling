extends BaseTest

# party-training 3.2 (C-13, D-236): тренировочная маска классов.
#
# Contradiction C-13 был сформулирован как «GDD-маска = 6 классов vs код = 3».
# Разбор (2026-10-24) показал, что это два разных среза, а не противоречие:
#
#   • маска = 6 классов (02d K1-A, T-113) — носитель `hireable` в
#     mvp_catalog.json, проверен test_canon_classes/test_mvp_catalog;
#   • K-M15 «Базовые бойцы MVP» — 3 ПОЗИЦИИ таблицы чисел {Хиты, КБ, урон,
#     Удача, время}, а не маска: в самой строке «Волшебник» написано
#     «маска: 6 классов (02d K1-A)» (07-balance);
#   • «код = 3» — это данные: training-действия есть только у классов
#     воин/следопыт/жрец;
#   • волшебник в маске есть, но канон-времени тренировки у него нет
#     (07-balance, колонка «Наём» — TBD), поэтому тренировка не генерируется;
#     прямое требование 3.3, исполнено: training_days() == 0. Статблок при этом
#     существует (unit_statblocks.mage, T-041) — отказа это не отменяет: SM
#     рекрута живёт на времени, а не на статах.
#
# Носитель правила — пересечение трёх проверок, а не список в коде:
#   обучаем = hireable(каталог) ∩ у здания есть training-действие ∩ days > 0.
# Тесты ниже держат именно это пересечение, чтобы чтение не уплыло.

const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")

## Здание, у которого есть РОВНО одно training-действие — на жреце
## (aoe4_abbey_of_the_trinity, prerequisites пустые).
const AbbeyBuildingId := "aoe4_abbey_of_the_trinity"
## Здание с тремя действиями (воин/следопыт/жрец) — на нём видно, что
## волшебника среди предложений нет ни при каких числах.
const PalaceBuildingId := "aoe4_khaganate_palace"


func _city(residents: int = 40) -> City:
	var city := TestFactories.make_city()
	city.center = Vector2i(20, 20)
	city.resource_ctx = ResourceContext.new()
	city.resource_ctx.setup(Resources.get_campaign_resource_defs(true), true)
	city.resource_ctx.add(&"food", 200.0)
	city.resource_ctx.add(&"wood", 200.0)
	city.resource_ctx.add(&"iron", 50.0)
	for index in range(residents):
		var resident := PopUnit.new()
		resident.uid = 1000 + index
		city.pop.append(resident)
	return city


func _building(city: City, building_id: String, uid: int) -> void:
	city.campaign_buildings.append({
		"uid": uid, "id": building_id, "state": "active",
		"construction_turns_remaining": 0, "cell": Vector2i(20, 20),
	})


func _trainee(id: String, wis: int = 10, int_: int = 10) -> Dictionary:
	return {"id": id, "race": "humans",
		"stats": {"str": 14, "dex": 10, "con": 10, "int": int_, "wis": wis, "cha": 10}}


## Маска найма (6, K1-A) как список id — носитель `hireable` mvp_catalog.json.
func _mask_ids() -> Array:
	var ids: Array = []
	for record in CanonClasses.hireable():
		ids.append(String((record as Dictionary).get("id", "")))
	return ids


## Все training-действия реального каталога зданий → множество классов.
func _catalog_training_classes() -> Array:
	var seen: Array = []
	for building in CampaignBuildingCatalog.load_catalog().get("buildings", []):
		if not (building is Dictionary):
			continue
		for action in (building as Dictionary).get("training", []):
			if action is Dictionary:
				var class_id := String((action as Dictionary).get("class_id", ""))
				if not seen.has(class_id):
					seen.append(class_id)
	return seen


## 3.2: «код = 3» — это данные, и они целиком лежат внутри маски из 6.
func test_training_actions_are_a_subset_of_the_six_class_mask() -> void:
	var actions := _catalog_training_classes()
	actions.sort()
	assert_that(actions).is_equal(["cleric", "fighter", "ranger"])
	for class_id in actions:
		assert_bool(_mask_ids().has(class_id)) \
				.override_failure_message("класс тренировки %s обязан быть в маске найма (6, K1-A)" % class_id) \
				.is_true()


## 3.2: обучаемое множество выводится из пересечения (маска ∩ числа), а не из
## списка в коде. Сегодня оно = {воин, следопыт}: у жреца и волшебника
## канон-времени тренировки нет (K-M15 — таблица трёх позиций, волшебник TBD).
func test_trainable_set_is_mask_intersection_with_canon_numbers() -> void:
	var trainable: Array = []
	for class_id in _mask_ids():
		if CampaignTrainingService.training_days(class_id) > 0.0:
			trainable.append(class_id)
	trainable.sort()
	assert_that(trainable).is_equal(["fighter", "ranger"])
	# Числа есть только у двух канон-позиций K-M15; у жреца времени тренировки
	# нет — он остаётся в маске найма, но заявку на него не построить.
	assert_float(CampaignTrainingService.training_days("cleric")).is_equal_approx(0.0, 0.0001)
	assert_float(CampaignTrainingService.training_days("wizard")).is_equal_approx(0.0, 0.0001)


## 3.3 (исполнено как «не генерируется»): волшебник в маске, но заявки нет.
func test_wizard_is_in_the_mask_but_never_generated() -> void:
	assert_bool(_mask_ids().has("wizard")) \
			.override_failure_message("волшебник — один из 6 классов маски K1-A").is_true()
	var city := _city()
	_building(city, PalaceBuildingId, 11)
	var options := CampaignTrainingService.available_training_actions_city(
			city, CampaignBuildingCatalog.load_catalog(), [], 0, 2)
	for option in options:
		assert_that(String(option.get("class_id", ""))).is_not_equal("wizard")
	var result := CampaignTrainingService.request_training(
			city, CampaignBuildingCatalog.load_catalog(), 11, "wizard",
			_trainee("w1", 10, 16), 2)
	assert_bool(bool(result.get("ok", false))).is_false()
	assert_that(String(result.get("reason", ""))).is_equal("no_training_time:wizard")


## 3.2 (замер, а не предположение): жрец — в маске 6 и имеет training-действия
## в данных, но канон-времени тренировки у него нет (в K-M15 чисел три позиции:
## воин, следопыт, волшебник-TBD). Живой носитель требует SM с прогрессом,
## поэтому класс без чисел не обучается: заявка отклоняется до списания.
func test_cleric_is_in_the_mask_but_has_no_canon_training_time() -> void:
	assert_bool(_mask_ids().has("cleric")) \
			.override_failure_message("жрец — один из 6 классов маски K1-A").is_true()
	var city := _city()
	_building(city, AbbeyBuildingId, 12)
	var result := CampaignTrainingService.request_training(
			city, CampaignBuildingCatalog.load_catalog(), 12, "cleric",
			_trainee("c1", 14), 2)
	assert_bool(bool(result.get("ok", false))).is_false()
	assert_that(String(result.get("reason", ""))).is_equal("no_training_time:cleric")
	assert_that(city.campaign_training.size()).is_equal(0)
	# Расхождение форм (ведётся T-171): dict-форма train() SM не имеет и чисел
	# не требует — жреца она пропускает. Она же и есть писатель без читателя.
	assert_bool(CanonClasses.gate_ok("cleric",
			{"str": 14, "dex": 10, "con": 10, "int": 10, "wis": 14, "cha": 10})) \
			.override_failure_message("гейт WIS 13 жрец проходит — отказ не в нём").is_true()


## 3.2: источник маски — каталог, а не список в коде: класс вне hireable
## отклоняется до всех остальных проверок.
func test_class_outside_the_catalog_mask_is_rejected() -> void:
	var city := _city()
	_building(city, AbbeyBuildingId, 13)
	var result := CampaignTrainingService.request_training(
			city, CampaignBuildingCatalog.load_catalog(), 13, "barbarian",
			_trainee("b1"), 2)
	assert_bool(bool(result.get("ok", false))).is_false()
	assert_that(String(result.get("reason", ""))).is_equal("unsupported_class:barbarian")
