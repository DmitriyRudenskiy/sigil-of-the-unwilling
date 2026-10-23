extends BaseTest

## 7.9–7.10 (ui-mockup-parity) — реестр счётчиков верхней полосы макета.
##
## Реестр — единственное место, где полоса знает, что показывать. Его инвариант
## дороже внешнего вида: **у каждой строки либо канонический носитель, либо
## зарегистрированная задача**. Без этого теста полоса в любой момент может
## обзавестись счётчиком, который рисует число, взятый неоткуда, — спека
## `campaign-hud` («живые элементы без мёртвых писателей», D-200) это считает
## дефектом, а глаз по скриншоту такого не увидит: «0» выглядит правдиво.

const Counters := preload("res://scripts/ui/campaign_counters.gd")


func test_registry_is_not_empty_and_ids_unique() -> void:
	assert_int(Counters.ROWS.size()).is_greater(0)
	var seen: Dictionary = {}
	for row in Counters.ROWS:
		var id: StringName = row.get("id", &"")
		assert_bool(id != &"").is_true()  # строка реестра обязана иметь id
		assert_bool(not seen.has(id)).is_true()  # двойной id = двойной счётчик
		seen[id] = true


## Главный инвариант: носитель или задача.
func test_every_row_has_carrier_or_ticket() -> void:
	for row in Counters.ROWS:
		var id := String(row.get("id", &""))
		if Counters.has_carrier(row):
			continue
		# без носителя — только с задачей (D-200)
		assert_str(String(row.get("ticket", ""))).is_not_empty()


## Строка, которую живой кампейн показать не может, обязана быть с задачей.
## Это и есть гейт «мёртвого писателя»: город строится тем же путём, что игра
## (`CampaignCity.start` — MVP-регистр food/wood/iron), поэтому кристаллы и
## провиант здесь не оттреканы, и их строки без задачи уронят сборку.
func test_every_row_shows_value_or_has_ticket() -> void:
	var city := CampaignCity.start({"food": 600.0, "wood": 20.0, "iron": 10.0}, 20)
	for row in Counters.ROWS:
		if Counters.value_text(row, city) != "":
			continue
		# нечем показать и задачи нет = мёртвый писатель
		assert_str(String(row.get("ticket", ""))).is_not_empty()


## Носитель обязан быть ресурсом из `ResourceRegistry`, иначе полоса ссылается на
## выдуманное поле. Проверка идёт по самому реестру, а не по списку, переписанному
## в тест: переименование ресурса должно краснить её, а не проходить молча.
func test_carrier_ids_are_known_resources() -> void:
	var registry := ResourceRegistry.new()
	for row in Counters.ROWS:
		var id: StringName = row.get("resource", &"")
		if id == &"":
			continue
		assert_bool(registry.is_campaign_resource(id)).is_true()
	registry.free()


func test_row_lookup_and_rendered_subset() -> void:
	assert_bool(not Counters.row_by_id(&"food").is_empty()).is_true()
	assert_bool(Counters.row_by_id(&"no_such_counter").is_empty()).is_true()
	var rendered := Counters.rendered_rows()
	assert_int(rendered.size()).is_less(Counters.ROWS.size())
	for row in rendered:
		assert_bool(Counters.has_carrier(row)).is_true()


func test_value_reads_the_city_carrier() -> void:
	var city := _city_with({"food": 600.0, "wood": 20.0})
	assert_str(Counters.value_text(Counters.row_by_id(&"food"), city)).is_equal("600")
	assert_str(Counters.value_text(Counters.row_by_id(&"wood"), city)).is_equal("20")


## Значение читается каждый раз заново: mutate носителя → другой текст. Это и
## есть проверка «элемент не хранит число» (D-200), а не «выглядит похоже».
func test_value_follows_the_carrier_without_restart() -> void:
	var city := _city_with({"food": 100.0})
	var row := Counters.row_by_id(&"food")
	assert_str(Counters.value_text(row, city)).is_equal("100")
	city.resource_ctx.add(&"food", 25.0)
	assert_str(Counters.value_text(row, city)).is_equal("125")


## Ресурс, который кампейн-состояние не ведёт, — пустая строка, а не «0»: ноль
## утверждает, что ресурс есть и он кончился.
func test_untracked_resource_is_not_zero() -> void:
	var city := _city_with({"food": 600.0})
	assert_str(Counters.value_text(Counters.row_by_id(&"sack"), city)).is_empty()
	assert_str(Counters.value_text(Counters.row_by_id(&"gold"), city)).is_empty()
	assert_str(Counters.value_text(Counters.row_by_id(&"food"), null)).is_empty()


## Подпись — каноническое имя ресурса из реестра ресурсов, а не строка полосы:
## переименование ресурса должно менять подпись само.
func test_label_comes_from_resource_registry() -> void:
	assert_str(Counters.label_text(Counters.row_by_id(&"food"))).is_equal("Еда")
	assert_str(Counters.label_text(Counters.row_by_id(&"ore"))).is_equal("Железо")
	# Строка без носителя подписывается тем, чем она в макете, — выдумывать имя
	# ресурса реестр не имеет права.
	assert_str(Counters.label_text(Counters.row_by_id(&"gold"))).is_equal("монеты")


func _city_with(stocks: Dictionary) -> City:
	var city := City.new()
	var registry := ResourceRegistry.new()
	var defs: Array = registry.get_campaign_resource_defs(true)
	registry.free()
	city.ensure_resource_ctx(defs)
	for id in stocks:
		city.resource_ctx.add(StringName(id), float(stocks[id]))
	return city
