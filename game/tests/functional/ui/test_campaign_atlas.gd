extends BaseTest

## T-280 — экран «Карта» надевает атлас носителей целиком (D-281 4.4).
##
## Гард поднимает живой кампейн и собирает пути всех рисунков, которые экран
## действительно использует, затем требует, чтобы в этом множестве оказался
## каждый кадр атласа `assets/ui/campaign_screen/MANIFEST.json`. Проверки «в
## реестре стоит id носителя» это не заменяет: носитель могут назвать и не надеть
## (прецедент — `decision_panel.gd`, класс которого жил без ни одного
## instantiated), а гард кадра видит только то, что лежит в дереве.
##
## Носитель приходит из трёх мест: узлы-носители `Art…` (плиты контейнеров,
## чипы, шестерня, знак героя), иконки кнопок и stylebox-оверрайды плит. Другого
## источника рисунка у экрана нет — `CampaignArt` читает единственный манифест.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const KIT_DIR := "res://assets/ui/campaign_screen/"
const BUTTON_SLOTS := ["normal", "hover", "pressed", "disabled"]
const CounterRegistryScript := preload("res://scripts/ui/campaign_counters.gd")

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
	if _window_saved:
		(_root() as Window).size = _window_size
		_window_saved = false
	super.after_test()


## Кампейн поднимается так же, как его поднимает игра (см. тот же приём в
## `test_campaign_hud_counters.gd`): сцена `main.tscn`, полный кадр 1920×1080.
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


func _keep(path: String, worn: Array[String]) -> void:
	if path.begins_with(KIT_DIR) and not worn.has(path):
		worn.append(path)


func _keep_stylebox(control: Control, slot: String, worn: Array[String]) -> void:
	var box := control.get_theme_stylebox(slot) as StyleBoxTexture
	if box != null and box.texture != null:
		_keep(String(box.texture.resource_path), worn)


func _collect(node: Node, worn: Array[String]) -> void:
	for child in node.get_children():
		if child is NinePatchRect:
			var patch := child as NinePatchRect
			if patch.texture != null:
				_keep(String(patch.texture.resource_path), worn)
		elif child is TextureRect:
			var rect := child as TextureRect
			if rect.texture != null:
				_keep(String(rect.texture.resource_path), worn)
		var button := child as Button
		if button != null:
			if button.icon != null:
				_keep(String(button.icon.resource_path), worn)
			for slot in BUTTON_SLOTS:
				_keep_stylebox(button, slot, worn)
		elif child is Panel or child is PanelContainer:
			# `PanelContainer` — не `Panel`: фон у него тот же stylebox `panel`.
			_keep_stylebox(child, "panel", worn)
		elif child is Label:
			_keep_stylebox(child, "normal", worn)
		_collect(child, worn)


## Кадры счётчиков, у которых нет носителя значения (`resource: &""`, T-159):
## полоса такой счётчик не рисует — «ноль вместо носителя» врал бы, и кадр
## надеть некуда. Список выводится из реестра счётчиков, а не пишется руками:
## как только кампейн начнёт вести ресурс, кадр вернётся в гард сам.
func _unrendered_carriers() -> Array[String]:
	var exempt: Array[String] = []
	for row in CounterRegistryScript.ROWS:
		if row.get("resource", &"") != &"":
			continue
		var cell := &"counter_%s" % String(row.get("id", &""))
		var art: StringName = CampaignScreenMap.row_by_id(cell).get("art", &"")
		if CampaignArt.has(art):
			exempt.append(String(art))
	return exempt


func test_screen_wears_the_whole_atlas() -> void:
	await _boot_campaign()
	var worn: Array[String] = []
	_collect(_main, worn)
	var exempt := _unrendered_carriers()
	var missing: Array[String] = []
	for id in CampaignArt.ids():
		var path := CampaignArt.path_of(StringName(id))
		if not worn.has(path) and not exempt.has(String(id)):
			missing.append(String(id))
	# Пустая строка = весь атлас надет; иначе в сообщении — список незадетых
	# кадров, и у каждой строки реестра есть свой id, по которому он ищется.
	assert_str(", ".join(missing)).is_equal("")
