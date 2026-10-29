extends BaseTest

## T-241: боевой HUD в каноническом 1920×1080 наполненным и не залезает под
## полосу команд.
##
## Почему этот тест появился только сейчас. `test_battle_ui_hero_cards.gd` (9 кейсов)
## и `test_battle_ui_hud_zones.gd` собирали UI-сцену и вручную наполняли её состояние,
## а живой путь (`world_battle_coordinator.gd:154` → `battle_flow.gd:18`) стартует бой
## ПОСЛЕ `_ready`. Кадр, снятый фикстурой `tools/capture/battle_hud_full.gd`, показал:
## при живом старте `target_card.visible == false`, то есть правый край кадра пуст до
## первого наведения мыши. Ни один прежний тест этого не видел, потому что ни один не
## проходил через `start_battle`.
##
## Размер кадра ставится программно (`get_tree().root.size`), как в T-220
## (`test_battle_field_fit.gd`): MCP-секция поднимает Xvfb 1024×768
## (`game/run_tests.sh:195`), и «читаемо в 1920×1080» там проверить физически нельзя.
## Пиксельный канон кадра — снимок `tools/shot_scene.gd` (1920×1080), геометрия — здесь.
##
## Кегль нижняя граница — 16 px (UI-AC7, [[17-ui-style-guide]] §2): до T-241 карточки
## боя кеглем не мерились вовсе, и «подпись мелкая» в этом окне не ловилась ничем.

const _BATTLE := "res://scenes/battle.tscn"
const _MIN_FONT := 16

var _original_size := Vector2i(1920, 1080)


func before_test() -> void:
	_original_size = get_tree().root.size


func after_test() -> void:
	super.after_test()
	get_tree().root.size = _original_size
	await get_tree().process_frame


## Бой «как его кладёт живая кампания»: личный боец героя + армия + мана героя
## (тот же состав, что у фикстуры съёмки `tools/capture/battle_hud_full.gd`).
func _battle_full() -> Node:
	get_tree().root.size = Vector2i(1920, 1080)
	var battle: Node = load(_BATTLE).instantiate()
	auto_free(battle)
	add_child(battle)
	await await_millis(300)
	var hero_stats := UnitStats.new(
		GameNumbersHero.HERO_BATTLE_KEY, "Герой", 4, 4, 1, 6, 5,
		[GameNumbersHero.HERO_BATTLE_KEY, "fighter", "human"]
	)
	var atk: Array[UnitStack] = [UnitStack.new(hero_stats, 27)]
	var dfn: Array[UnitStack] = []
	for kind in ["goblins", "orc"] as Array[String]:
		var s: UnitStack = Units.make_fixed_stack(kind, 9)
		assert_bool(s != null).is_true() \
			.override_failure_message("регистр юнитов не отдал стек %s — бой не начать" % kind)
		dfn.append(s)
	atk.append(Units.make_fixed_stack("swordsmen", 8))
	var magic := HeroMagic.new()
	magic.mana_max = 20
	magic.mana_current = 12
	battle.start_battle(atk, dfn, {}, {}, {}, {}, 7, magic, "snow")
	await get_tree().process_frame
	return battle


func _ui_of(battle: Node) -> CanvasLayer:
	return battle.get_node("BattleUI") as CanvasLayer


func _rect(battle: Node, path: String) -> Rect2:
	return (battle.get_node(path) as Control).get_global_rect()


## Кадр, в котором лежит разметка: root.size мы выставляем сами, stretch — canvas_items.
func _frame() -> Vector2:
	return get_tree().root.get_visible_rect().size


func _assert_inside_frame(battle: Node, path: String) -> void:
	var f := _frame()
	assert_bool(f.x >= 1900.0 and f.y >= 1060.0).is_true() \
		.override_failure_message("кадр %.0fx%.0f, а не канон 1920×1080 — проверка «в кадре» пуста" % [f.x, f.y])
	var r := _rect(battle, path)
	assert_bool(r.size.x > 0.0 and r.size.y > 0.0).is_true() \
		.override_failure_message("%s не разложен (rect %s) — элемент невидим" % [path, r])
	assert_bool(r.position.x >= -0.5 and r.position.y >= -0.5).is_true() \
		.override_failure_message("%s вылез за левый/верхний край кадра: %s" % [path, r])
	assert_bool(r.end.x <= f.x + 0.5 and r.end.y <= f.y + 0.5).is_true() \
		.override_failure_message(
			"%s выходит за канонический кадр: rect %s при кадре %.0fx%.0f" % [path, r, f.x, f.y]
		)


func test_hero_card_is_filled_at_full_hd() -> void:
	var battle: Node = await _battle_full()
	var ui := _ui_of(battle)
	var card: Control = ui.get_node("hero_cards/hero_left")
	assert_bool(card.visible).is_true().override_failure_message(
		"в ростере есть герой, а карточка героя скрыта"
	)
	assert_str(str(card.get_node("row/info/name").text)).is_equal("Герой")
	var mana: Control = card.get_node("row/info/mana_row")
	assert_bool(mana.visible).is_true().override_failure_message(
		"герою передана мана 12/20, а строка маны скрыта — карточка молчит о ресурсе"
	)
	assert_str(str(card.get_node("row/info/mana_row/mana_num").text)).is_equal("12/20")
	_assert_inside_frame(battle, "BattleUI/hero_cards/hero_left")


func test_enemy_card_is_filled_at_full_hd() -> void:
	var battle: Node = await _battle_full()
	var ui := _ui_of(battle)
	var card: Control = ui.get_node("target_card")
	assert_bool(card.visible).is_true().override_failure_message(
		"бой идёт, вражина жив, а карточка противника скрыта — правый край кадра пуст"
	)
	assert_str(str(card.get_node("tc_box/tc_caption").text)).is_equal("Противник")
	assert_str(str(card.get_node("tc_box/tc_name").text)).is_not_empty()
	assert_str(str(card.get_node("tc_box/tc_hp_row/tc_hp").text)).is_not_empty()
	assert_str(str(card.get_node("tc_box/tc_def_row/tc_def").text)).is_not_empty()
	_assert_inside_frame(battle, "BattleUI/target_card")


## Карточка, уехавшая под полосу команд, читается как пустое место: нижняя панель
## рисуется тем же CanvasLayer-слоем и перекрывает её целиком.
func test_cards_stay_above_the_command_band() -> void:
	var battle: Node = await _battle_full()
	var band := _rect(battle, "BattleUI/bottom_bar")
	assert_bool(band.size.y > 0.0).is_true().override_failure_message("полоса команд не разложена")
	for path in ["BattleUI/target_card", "BattleUI/hero_cards/hero_left"] as Array[String]:
		var r := _rect(battle, path)
		assert_bool(not r.intersects(band)).is_true().override_failure_message(
			"%s (%s) пересекается с полосой команд (%s) — текст под панелью" % [path, r, band]
		)


## Кегль подписей карточек — не ниже канона UI-AC7. Роль берётся из живой темы
## (`get_theme_font_size`), а не из сценевого override: код тоже может ставить кегль.
func test_card_labels_meet_the_font_floor() -> void:
	var battle: Node = await _battle_full()
	var ui := _ui_of(battle)
	var paths: Array[String] = [
		"target_card/tc_box/tc_caption",
		"target_card/tc_box/tc_name",
		"target_card/tc_box/tc_count_row/tc_count",
		"target_card/tc_box/tc_hp_row/tc_hp",
		"target_card/tc_box/tc_def_row/tc_def",
		"target_card/tc_box/tc_preview",
		"hero_cards/hero_left/row/info/name",
		"hero_cards/hero_left/row/info/hp_row/hp_num",
		"hero_cards/hero_left/row/info/mana_row/mana_num",
		"bottom_bar/info_box/log_row/log_line",
	]
	var below: Array[String] = []
	for p in paths:
		var label: Label = ui.get_node(p) as Label
		assert_bool(label != null).is_true() \
			.override_failure_message("подписи %s нет в сцене — проверка кегля пуста" % p)
		var px: int = label.get_theme_font_size("font_size")
		if px < _MIN_FONT:
			below.append("%s=%d" % [p, px])
	assert_bool(below.is_empty()).is_true().override_failure_message(
		"кегль ниже %d px: %s" % [_MIN_FONT, ", ".join(below)]
	)
