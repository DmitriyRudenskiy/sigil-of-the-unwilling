extends BaseTest

## 7.10–7.11 (ui-mockup-parity) — полоса счётчиков и дата макета в живом
## кампейне (`scenes/main/main.tscn`).
##
## Полоса поднята поверх кампании впервые: до этого раунда на экране кампании
## не было ни одного числа, кроме служебной надписи «День: N» (её сняли — дата
## макета живёт здесь же, вторая копия дня на экране не нужна).
##
## Что гейтится:
## 1. полоса строится из реестра, а не из догадки: узлы — ровно строки реестра
##    с носителем, в порядке макета;
## 2. значения читаются из носителя (`City.resource_ctx`) при каждом обновлении,
##    собственного числа у полосы нет — мутация носителя видна без перезахода;
## 3. счётчик, который кампейн-состояние не ведёт, не рисуется нулём (спека
##    `campaign-hud`: «либо не показан, либо с явным „носителя нет“»);
## 4. дата пересчитывается из дня кампании и приходит по сигналу `day_passed`,
##    а не по ручному вызову — то есть обновится от любого драйвера хода;
## 5. второй копии дня на экране нет: снятого `CanvasLayer/DayLabel` больше нет.
## 6. «есть в модели» ≠ «видно на экране»: у даты и полосы есть ненулевой
##    прямоугольник внутри кадра (у `Label` с нижними якорями нулевая высота
##    съедает текст молча — по строке текста такой дефект не виден).
##
## Числа старта не изобретаются: кампейн поднимается сценой `main.tscn`, поэтому
## полоса сверяется с живым городом, а не с литералом.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const COUNTER_BAR_PATH := "CampaignHUD/CampaignHud/CounterBar"
const Calendar := preload("res://scripts/campaign/campaign_calendar.gd")
const Counters := preload("res://scripts/ui/campaign_counters.gd")

var _main: Node = null
var _window_size := Vector2i.ZERO
var _window_saved := false


func _root() -> Node:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	if _window_saved:
		(_root() as Window).size = _window_size
		_window_saved = false
	super.after_test()


## Кампейн поднимается так же, как его поднимает игра: сцена `main.tscn`,
## `_ready` → `_init_campaign` → привязка слоя и первый `refresh_campaign`.
func _boot_campaign() -> Node:
	var window := _root() as Window
	_window_size = window.size
	_window_saved = true
	window.size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


func _hud() -> CampaignHud:
	return _main.get_node("CampaignHUD/CampaignHud") as CampaignHud


func _city() -> City:
	return _main.composition.city


func test_counter_bar_is_built_from_registry() -> void:
	await _boot_campaign()
	# Полоса — `Control`, а не `Container`: контейнер делит ширину между
	# видимыми детьми и сдвигал бы счётчики со своих ячеек макета, когда сосед
	# скрыт по значению (D-281 3.8).
	var bar := _main.get_node_or_null(COUNTER_BAR_PATH) as Control
	assert_object(bar).is_not_null()
	var rendered := Counters.rendered_rows()
	# Дети полосы — ячейки реестра и носители рисунка (плита полосы и плита
	# каждой ячейки, T-280): ряд сверяется по ячейкам, рисунок строкой реестра
	# не является и в порядок ряда не вмешивается.
	var cells: Array[Node] = []
	for child in bar.get_children():
		if String(child.name).begins_with("Counter_"):
			cells.append(child)
	assert_int(cells.size()).is_equal(rendered.size())
	for i in rendered.size():
		var box := cells[i]
		assert_str(String(box.name)).is_equal("Counter_%s" % String(rendered[i].get("id", &"")))
		# Иконка — из реестра ресурсов, а не эмодзи в тексте: макет рисует иконки.
		assert_object(box.get_node("Icon") as TextureRect).is_not_null()


func test_counters_show_live_city_values() -> void:
	await _boot_campaign()
	var hud := _hud()
	var ctx := _city().resource_ctx
	for id in [&"food", &"wood", &"ore"]:
		var resource: StringName = Counters.row_by_id(id).get("resource", &"")
		var expected := str(int(ctx.amount(resource)))
		# счётчик обязан равняться числу носителя, а не «похожему»
		assert_str(hud.get_counter_text(id)).is_equal(expected)
	assert_str(hud.get_counter_text(&"food")).not_contains(".")


func test_counter_follows_the_carrier_without_restart() -> void:
	await _boot_campaign()
	var hud := _hud()
	var ctx := _city().resource_ctx
	var before := hud.get_counter_text(&"wood")
	ctx.add(&"wood", 500.0)
	hud.refresh_campaign(_main.game_manager.get_current_day())
	var after := hud.get_counter_text(&"wood")
	assert_str(after).is_not_equal(before)
	assert_str(after).is_equal(str(int(ctx.amount(&"wood"))))


## Провиант и кристаллы — ресурсы слоя 1/2: кампейн-состояние их не ведёт,
## поэтому полоса их прячет. Монеты и «красная капля» не рисуются вовсе — у них
## нет даже носителя, и их узлов на полосе быть не должно.
func test_counters_without_values_are_not_rendered() -> void:
	await _boot_campaign()
	var hud := _hud()
	var bar := _main.get_node(COUNTER_BAR_PATH) as Control
	assert_bool(bar.has_node("Counter_gold")).is_false()
	assert_bool(bar.has_node("Counter_drop_red")).is_false()
	assert_bool(bar.has_node("Counter_gem_green")).is_false()
	# Видимых ровно три — MVP-триада food/wood/iron: кампейн-состояние ведёт их.
	assert_int(hud.get_counter_count()).is_equal(3)
	assert_str(hud.get_counter_text(&"sack")).is_empty()
	assert_str(hud.get_counter_text(&"crystals")).is_empty()


func test_date_follows_the_campaign_day() -> void:
	await _boot_campaign()
	var hud := _hud()
	var day: int = _main.game_manager.get_current_day()
	assert_str(hud.get_date_text()).is_equal(Calendar.date_label(day))
	# Ход сделан драйвером — дата обновилась сама, по сигналу `day_passed`.
	_main._advance_day()
	var next_day: int = _main.game_manager.get_current_day()
	assert_int(next_day).is_equal(day + 1)
	assert_str(hud.get_date_text()).is_equal(Calendar.date_label(next_day))
	assert_str(hud.get_date_text()).is_not_equal(Calendar.date_label(day))


## Дата — пересчёт канонического счётчика дней, второго хранилища нет: ни
## служебного `DayLabel`, ни своего номера дня у слоя.
func test_there_is_only_one_day_on_screen() -> void:
	await _boot_campaign()
	assert_bool(_main.has_node("CanvasLayer/DayLabel")).is_false()
	assert_bool(_main.has_node("CanvasLayer")).is_false()
	assert_str(_hud().get_date_text()).is_equal(
		Calendar.date_label(_main.game_manager.get_current_day()))


## «Есть в модели» ≠ «видно на экране»: у `Label` с якорями по нижней границе
## нулевая высота молча съедает текст — `get_date_text()` при этом зелёный, а на
## кадре даты нет (так и поймали). Проверка — прямоугольник внутри кадра.
func test_date_and_bar_have_a_rect_on_screen() -> void:
	await _boot_campaign()
	await get_tree().process_frame
	var frame_size := (_root() as Window).size
	var date := _main.get_node("CampaignHUD/CampaignHud/CampaignDate") as Control
	var bar := _main.get_node(COUNTER_BAR_PATH) as Control
	for node in [date, bar]:
		var rect: Rect2 = (node as Control).get_global_rect()
		assert_bool(rect.size.x > 0.0).is_true()
		assert_bool(rect.size.y > 0.0).is_true()
		assert_bool(rect.position.x >= 0.0 and rect.position.y >= 0.0).is_true()
		assert_bool(rect.end.x <= float(frame_size.x)).is_true()
		assert_bool(rect.end.y <= float(frame_size.y)).is_true()
