# CAPTURE_SETUP для кадра «карточка врага видна всегда» (dnd-battle-ladder 4.1, D-267).
#
# Кадр нужен для ux-review: окно должно быть видно БЕЗ наведения мыши, а это ровно
# то, что нельзя подтвердить ни хитбоксом, ни кадром пустой сцены — battle.tscn в
# изолированном прогоне стартует с пустым defender_units (армии кладёт кампейн).
# Состояние поднимается теми же объектами, что и в тесте: UnitStats → UnitStack →
# BattleUnit, после чего вызывается production-метод show_default_enemy_card.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var state = scene.get("_state")
if state == null:
	return {"ok": false, "reason": "нет состояния боя"}
var stats = UnitStats.new()
stats.defense = 7
stats.hp = 20
stats.attack = 5
var stack = UnitStack.new()
stack.stats = stats
stack.count = 3
var unit = BattleState.BattleUnit.new()
unit.side = 1
unit.alive = true
unit.stack = stack
state.defender_units.append(unit)
var ui = scene.get_node_or_null("BattleUI")
if ui == null:
	return {"ok": false, "reason": "слой BattleUI не поднят"}
ui.show_default_enemy_card(state)
var card = ui.get_node("target_card")
return {"ok": true, "visible": card.visible, "caption": ui.get_node("target_card/tc_box/tc_caption").text}
