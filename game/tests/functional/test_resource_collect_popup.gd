extends BaseTest

const _Popup = preload("res://scenes/ui/ResourceCollectPopup.tscn")


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

var _nodes: Array[Node] = []

func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()

func _track(n: Node) -> void:
	_nodes.append(n)

func test_popup_structure_and_initial_state() -> void:
	var p: ResourceCollectPopup = _Popup.instantiate() as ResourceCollectPopup
	_track(p)
	assert_bool(p.visible).is_false()
	assert_that(p.get_node_or_null("Margin")).is_not_null()
	assert_that(p.get_node_or_null("Margin/VBox")).is_not_null()
	var image := p.get_node_or_null("Margin/VBox/Image")
	assert_bool(image is TextureRect).is_true()
	var label := p.get_node_or_null("Margin/VBox/Label")
	assert_bool(label is Label).is_true()
	var ok := p.get_node_or_null("Margin/VBox/OKButton")
	assert_bool(ok is Button).is_true()
	var timer := p.get_node_or_null("DismissTimer")
	assert_bool(timer is Timer).is_true()
	assert_bool(timer.one_shot).is_true()
	assert_float(timer.wait_time).is_equal_approx(ResourceCollectPopup.AUTO_DISMISS_SECONDS, 0.001)

func test_show_resource_simple_known() -> void:
	var p: ResourceCollectPopup = _Popup.instantiate() as ResourceCollectPopup
	_track(p)
	p.show_resource(&"wood", 5)
	assert_bool(p.visible).is_true()
	var label: Label = p.get_node("Margin/VBox/Label")
	var image: TextureRect = p.get_node("Margin/VBox/Image")
	assert_bool(label.text.contains("Дерево")).is_true()
	assert_bool(label.text.contains("+5")).is_true()
	assert_that(image.texture).is_not_null()

func test_show_resource_rich_vein() -> void:
	var p: ResourceCollectPopup = _Popup.instantiate() as ResourceCollectPopup
	_track(p)
	p.show_resource(&"quartz", 12)
	var label: Label = p.get_node("Margin/VBox/Label")
	var image: TextureRect = p.get_node("Margin/VBox/Image")
	assert_bool(label.text.contains("+12")).is_true()
	assert_that(image.texture).is_not_null()
	assert_bool(label.text.contains("Кварц") or label.text.contains("quartz")).is_true()

func test_show_resource_unknown_degrades() -> void:
	var p: ResourceCollectPopup = _Popup.instantiate() as ResourceCollectPopup
	_track(p)
	p.show_resource(&"bogus_xyz_42", 0)
	assert_bool(p.visible).is_true()
	var label: Label = p.get_node("Margin/VBox/Label")
	var image: TextureRect = p.get_node("Margin/VBox/Image")
	assert_bool(label.text.contains("bogus_xyz_42")).is_true()
	assert_bool(label.text.contains("+0")).is_true()
	assert_that(image.texture).is_not_null()

func test_ok_dismisses_and_popup_reusable() -> void:
	var p: ResourceCollectPopup = _Popup.instantiate() as ResourceCollectPopup
	_track(p)
	add_child(p)
	p.show_resource(&"gold", 50)
	assert_bool(p.visible).is_true()
	p._on_ok()
	assert_bool(p.visible).is_false()
	assert_bool(p._timer.is_stopped()).is_true()
	p.show_resource(&"gems", 5)
	assert_bool(p.visible).is_true()
	var label: Label = p.get_node("Margin/VBox/Label")
	assert_bool(label.text.contains("+5")).is_true()
	remove_child(p)

func test_auto_dismiss_hides_and_re_show_works() -> void:
	var p: ResourceCollectPopup = _Popup.instantiate() as ResourceCollectPopup
	_track(p)
	add_child(p)
	p.show_resource(&"wood", 5)
	assert_bool(p.visible).is_true()
	p._on_auto_dismiss()
	assert_bool(p.visible).is_false()
	p.show_resource(&"ore", 5)
	assert_bool(p.visible).is_true()
	var label: Label = p.get_node("Margin/VBox/Label")
	assert_bool(label.text.contains("Руда")).is_true()
	p._on_ok()
	remove_child(p)

func test_icons_res_type_mapping() -> void:
	assert_that(ResourceIcons.res_type_id(0)).is_equal(&"wood")
	assert_that(ResourceIcons.res_type_id(6)).is_equal(&"gold")
	assert_that(ResourceIcons.res_type_id(-1)).is_equal(&"")
	assert_that(ResourceIcons.res_type_id(7)).is_equal(&"")
	assert_that(ResourceIcons.res_type_amount(0)).is_equal(5)
	assert_that(ResourceIcons.res_type_amount(6)).is_equal(50)
	assert_that(ResourceIcons.res_type_amount(99)).is_equal(0)

func test_icons_name_color_texture() -> void:
	assert_that(GameText.resource_name(&"wood")).is_equal("Дерево")
	assert_that(GameText.resource_name(&"no_such_id")).is_equal("no_such_id")
	assert_that(ResourceIcons.get_texture(&"wood")).is_null()
	var c1: Color = ResourceIcons.get_color(&"wood")
	assert_bool(c1.is_equal_approx(Color(0.62, 0.44, 0.24))).is_true()
	assert_bool(ResourceIcons.get_color(&"quartz")
			.is_equal_approx(ResourceIcons.get_color(&"quartz"))).is_true()

func test_spawner_get_res_type_at() -> void:
	var spawner = auto_free( WorldSpawner.new())
	var cell := Vector2i(3, 3)
	var node := Node2D.new()
	node.set_meta("res_type", 2)
	spawner._resource_nodes[cell] = node
	assert_that(spawner.get_res_type_at(cell)).is_equal(2)
	assert_that(spawner.get_res_type_at(Vector2i(1, 1))).is_equal(-1)
	node.free()
	spawner.free()

func test_collect_emits_resource_extracted() -> void:
	var vic = auto_free( WorldInteractionController.new())
	var spawner := _SpawnerStub.new()
	var hero := _HeroStub.new()
	var cell := Vector2i(2, 2)
	spawner._resources[cell] = true
	var node := Node2D.new()
	node.set_meta("res_type", 2)
	spawner._resource_nodes[cell] = node
	vic.setup(hero, spawner, null)

	var events: Array = []
	var cb := func(c: Vector2i, rid: StringName, amount: int) -> void:
		events.append([c, rid, amount])
	GameEventBus.resource_extracted.connect(cb)

	var collected = vic.collect_resource_at(cell)
	GameEventBus.resource_extracted.disconnect(cb)

	assert_bool(collected).is_true()
	assert_that(events.size()).is_equal(1)
	if events.size() == 1:
		assert_that(events[0][0]).is_equal(cell)
		assert_that(events[0][1]).is_equal(&"ore")
		assert_that(events[0][2]).is_equal(5)
	node.free()
	vic.free()
	spawner.free()
	hero.free()

func test_collect_no_node_no_signal() -> void:
	var vic = auto_free( WorldInteractionController.new())
	var spawner := _SpawnerStub.new()
	var hero := _HeroStub.new()
	vic.setup(hero, spawner, null)

	var events: Array = []
	var cb := func(_c: Vector2i, _rid: StringName, _amount: int) -> void:
		events.append(true)
	GameEventBus.resource_extracted.connect(cb)

	var collected = vic.collect_resource_at(Vector2i(9, 9))
	GameEventBus.resource_extracted.disconnect(cb)

	assert_bool(collected).is_false()
	assert_bool(events.is_empty()).is_true()
	vic.free()
	spawner.free()
	hero.free()
