extends "res://tests/test_base.gd"
## resource-collection-popup: unit-тесты попапа и простого пути сбора.
##
## Покрытие spec-сценариев:
## - «Popup после сбора»: структура, имя/иконка/точное кол-во;
## - «Popup content reflects the collected resource»: +N в метке;
## - «Popup auto-dismisses» / «OK dismisses»: таймер + кнопка, переиспользование;
## - «Degrade on unknown resource»: заглушка + 0, без crash;
## - «Both collection paths»: collect_resource_at шлёт единый сигнал
##   GameEventBus.resource_extracted (богатый путь уже шлёт из try_extract).

const _Popup = preload("res://scripts/ui/ResourceCollectPopup.gd")
const _Spawner = preload("res://scripts/world/WorldSpawner.gd")
const _VIC = preload("res://scripts/world/WorldInteractionController.gd")


class _SpawnerStub:
	extends WorldSpawner
	var _resources: Dictionary = {}
	func remove_resource_at(cell: Vector2i) -> bool:
		if _resources.has(cell):
			_resources.erase(cell)
			return true
		return false
	func get_chest_at(cell: Vector2i) -> ArtifactChest:
		return null
	func capture_village(cell: Vector2i) -> bool:
		return false


class _HeroStub:
	extends HeroController


## ==================== Попап: структура и отображение ====================

func test_popup_structure_and_initial_state() -> void:
	var p: ResourceCollectPopup = _Popup.new()
	assert_false(p.visible, "popup hidden initially")
	assert_not_null(p.get_node_or_null("Margin"), "Margin node")
	assert_not_null(p.get_node_or_null("Margin/VBox"), "VBox node")
	var image := p.get_node_or_null("Margin/VBox/Image")
	assert_true(image is TextureRect, "Image is TextureRect")
	var label := p.get_node_or_null("Margin/VBox/Label")
	assert_true(label is Label, "Label is Label")
	var ok := p.get_node_or_null("Margin/VBox/OKButton")
	assert_true(ok is Button, "OKButton is Button")
	var timer := p.get_node_or_null("DismissTimer")
	assert_true(timer is Timer, "DismissTimer is Timer")
	assert_true(timer.one_shot, "dismiss timer is one_shot")
	assert_approx(timer.wait_time, ResourceCollectPopup.AUTO_DISMISS_SECONDS, 0.001,
			"dismiss wait = AUTO_DISMISS_SECONDS")
	p.free()


func test_show_resource_simple_known() -> void:
	var p: ResourceCollectPopup = _Popup.new()
	p.show_resource(&"wood", 5)
	assert_true(p.visible, "popup visible after show")
	var label: Label = p.get_node("Margin/VBox/Label")
	var image: TextureRect = p.get_node("Margin/VBox/Image")
	assert_true(label.text.contains("Дерево"), "name shown: %s" % label.text)
	assert_true(label.text.contains("+5"), "exact amount shown: %s" % label.text)
	assert_not_null(image.texture, "icon texture present (atlas или заглушка)")
	p.free()


func test_show_resource_rich_vein() -> void:
	# Богатая жила (id из ResourceRegistry, нет в DATA) — имя из реестра.
	var p: ResourceCollectPopup = _Popup.new()
	p.show_resource(&"quartz", 12)
	var label: Label = p.get_node("Margin/VBox/Label")
	var image: TextureRect = p.get_node("Margin/VBox/Image")
	assert_true(label.text.contains("+12"), "rich amount: %s" % label.text)
	assert_not_null(image.texture, "rich icon texture present")
	# Реестр Resources есть в раннере — имя должно быть человекочитаемым
	# (Кварц из ResourceDef; без реестра деградирует до id — тоже ок).
	assert_true(label.text.contains("Кварц") or label.text.contains("quartz"),
			"rich name resolved: %s" % label.text)
	p.free()


func test_show_resource_unknown_degrades() -> void:
	# D5: неизвестный id → заглушка + имя = id, кол-во 0, без crash.
	var p: ResourceCollectPopup = _Popup.new()
	p.show_resource(&"bogus_xyz_42", 0)
	assert_true(p.visible, "popup visible for unknown id")
	var label: Label = p.get_node("Margin/VBox/Label")
	var image: TextureRect = p.get_node("Margin/VBox/Image")
	assert_true(label.text.contains("bogus_xyz_42"), "fallback name = id")
	assert_true(label.text.contains("+0"), "amount 0: %s" % label.text)
	assert_not_null(image.texture, "placeholder texture generated")
	p.free()


## ==================== Попап: dismissal и переиспользование ====================

func test_ok_dismisses_and_popup_reusable() -> void:
	var p: ResourceCollectPopup = _Popup.new()
	root.add_child(p)
	p.show_resource(&"gold", 50)
	assert_true(p.visible, "visible before OK")
	p._on_ok()
	assert_false(p.visible, "OK hides popup")
	assert_true(p._timer.is_stopped(), "OK stops auto-dismiss timer")
	# Повторный показ работает (переиспользование, не новый узел).
	p.show_resource(&"gems", 5)
	assert_true(p.visible, "popup re-shown")
	var label: Label = p.get_node("Margin/VBox/Label")
	assert_true(label.text.contains("+5"), "content refreshed on re-show")
	root.remove_child(p)
	p.free()


func test_auto_dismiss_hides_and_re_show_works() -> void:
	var p: ResourceCollectPopup = _Popup.new()
	root.add_child(p)
	p.show_resource(&"wood", 5)
	assert_true(p.visible, "visible before auto-dismiss")
	# Фреймы в синхронном раннере не крутятся — срабатывание таймера
	# эмулируем прямым вызовом обработчика (таймер one_shot, wait_time
	# проверены в test_popup_structure_and_initial_state).
	p._on_auto_dismiss()
	assert_false(p.visible, "auto-dismiss hides popup")
	# Повторный показ после dismissal работает (попап переиспользуется).
	p.show_resource(&"ore", 5)
	assert_true(p.visible, "re-shown after dismiss")
	var label: Label = p.get_node("Margin/VBox/Label")
	assert_true(label.text.contains("Руда"), "refreshed content: %s" % label.text)
	p._on_ok()
	root.remove_child(p)
	p.free()


## ==================== ResourceIcons: данные ====================

func test_icons_res_type_mapping() -> void:
	assert_eq(ResourceIcons.res_type_id(0), &"wood", "res_type 0")
	assert_eq(ResourceIcons.res_type_id(6), &"gold", "res_type 6")
	assert_eq(ResourceIcons.res_type_id(-1), &"", "res_type -1 out of range")
	assert_eq(ResourceIcons.res_type_id(7), &"", "res_type 7 out of range")
	assert_eq(ResourceIcons.res_type_amount(0), 5, "simple amount 5")
	assert_eq(ResourceIcons.res_type_amount(6), 50, "gold amount 50")
	assert_eq(ResourceIcons.res_type_amount(99), 0, "bad index → 0")


func test_icons_name_color_texture() -> void:
	assert_eq(ResourceIcons.resource_name(&"wood"), "Дерево", "data name")
	assert_eq(ResourceIcons.resource_name(&"no_such_id"), "no_such_id", "fallback name = id")
	# Атлас не поставлен → null (попап покажет заглушку).
	assert_null(ResourceIcons.get_texture(&"wood"), "no client atlas yet")
	var c1: Color = ResourceIcons.get_color(&"wood")
	assert_true(c1.is_equal_approx(Color(0.62, 0.44, 0.24)), "data color")
	# Цвет заглушки стабилен (hash от id).
	assert_true(ResourceIcons.get_color(&"quartz")
			.is_equal_approx(ResourceIcons.get_color(&"quartz")), "hash color stable")


## ==================== WorldSpawner.get_res_type_at ====================

func test_spawner_get_res_type_at() -> void:
	var spawner: WorldSpawner = _Spawner.new()
	var cell := Vector2i(3, 3)
	var node := Node2D.new()
	node.set_meta("res_type", 2)
	spawner._resource_nodes[cell] = node
	assert_eq(spawner.get_res_type_at(cell), 2, "meta res_type read")
	assert_eq(spawner.get_res_type_at(Vector2i(1, 1)), -1, "no node → -1")
	node.free()
	spawner.free()


## ==================== Простой путь: единый сигнал ====================

func test_collect_emits_resource_extracted() -> void:
	var vic := _VIC.new()
	var spawner := _SpawnerStub.new()
	var hero := _HeroStub.new()
	var cell := Vector2i(2, 2)
	spawner._resources[cell] = true
	var node := Node2D.new()
	node.set_meta("res_type", 2)  # ore
	spawner._resource_nodes[cell] = node
	vic.setup(hero, spawner, null)

	# Godot 4.7: lambda копирует value-типы — события ловим в массив-холдер.
	var events: Array = []
	var cb := func(c: Vector2i, rid: StringName, amount: int) -> void:
		events.append([c, rid, amount])
	GameEventBus.resource_extracted.connect(cb)

	var collected := vic.collect_resource_at(cell)
	GameEventBus.resource_extracted.disconnect(cb)

	assert_true(collected, "collection succeeded")
	assert_eq(events.size(), 1, "exactly one resource_extracted event")
	if events.size() == 1:
		assert_eq(events[0][0], cell, "event cell")
		assert_eq(events[0][1], &"ore", "event resource_id from res_type")
		assert_eq(events[0][2], 5, "event amount = simple collection amount")
	node.free()
	vic.free()
	spawner.free()
	hero.free()


func test_collect_no_node_no_signal() -> void:
	var vic := _VIC.new()
	var spawner := _SpawnerStub.new()
	var hero := _HeroStub.new()
	vic.setup(hero, spawner, null)

	var events: Array = []
	var cb := func(_c: Vector2i, _rid: StringName, _amount: int) -> void:
		events.append(true)
	GameEventBus.resource_extracted.connect(cb)

	var collected := vic.collect_resource_at(Vector2i(9, 9))
	GameEventBus.resource_extracted.disconnect(cb)

	assert_false(collected, "nothing to collect")
	assert_true(events.is_empty(), "no signal without resource node")
	vic.free()
	spawner.free()
	hero.free()
