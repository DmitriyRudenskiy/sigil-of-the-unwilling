# CAPTURE_SETUP для кадров боя (battle-99-hex-clean-hud).
#
# Кадр обязан поднимать бой игрока, а не пустую сцену: `scenes/battle.tscn`
# автономно стартует без армий, поэтому поле на голой сцене — девять строк пустых
# гексов, и спор «поле 11×9 вписалось, верх кадра свободен, фон выбран по
# местности врага» на таком кадре не решается.
#
# Состав — четыре стека с каждой стороны: на 99 гексах это проверка, что
# `_resolve_blocked_placement()` размещает все стартовые позиции внутри поля и
# none из них не легло под препятствие. Местность фона — из `CAPTURE_TERRAIN`
# ("snow", "swamp", что угодно = fallback), потому что один и тот же кадр должен
# сниматься и для распознаваемого биома, и для неопознанной местности.
var battle: Node = get_tree().current_scene
if battle == null or not battle.has_method("start_battle"):
	return {"ok": false, "reason": "текущая сцена — не бой"}
var state = battle.get("_state")
if state == null:
	return {"ok": false, "reason": "у боя нет BattleState"}
if state.get_units_by_side(BattleState.Side.ATTACKER).size() > 0:
	return {"ok": false, "reason": "бой уже идёт — бой не перезапускаем"}

var terrain: String = OS.get_environment("CAPTURE_TERRAIN")
if terrain == "":
	terrain = "grass"

var atk: Array[UnitStack] = [
	Units.make_fixed_stack("swordsmen", 12),
	Units.make_fixed_stack("archers", 10),
	Units.make_fixed_stack("wolves", 14),
	Units.make_fixed_stack("orc", 8),
]
var def: Array[UnitStack] = [
	Units.make_fixed_stack("goblins", 14),
	Units.make_fixed_stack("archers", 10),
	Units.make_fixed_stack("swordsmen", 12),
	Units.make_fixed_stack("pegasus", 6),
]
battle.start_battle(atk, def, {}, {}, {}, {}, 7, null, terrain)

var view = battle.get("_view")
var placed: Array = []
var off_board := 0
for side in [BattleState.Side.ATTACKER, BattleState.Side.DEFENDER]:
	for u in state.get_units_by_side(side):
		var c: Vector2i = u.cell
		if c.x < 0 or c.x >= BattleState.BW or c.y < 0 or c.y >= BattleState.BH:
			off_board += 1
		placed.append("%s%s@%s" % ["A" if side == BattleState.Side.ATTACKER else "D", u.get_key(), str(c)])
var edge = view.get_node("BoardEdge")
var tm = view.get("_tile_map")
return {
	"diag_edge": 0 if edge == null else edge.cells.size(),
	"diag_pitch": "?" if tm == null else str(tm.map_to_local(Vector2i(1, 0)) - tm.map_to_local(Vector2i(0, 0))),
	"diag_r": str(BattleView.HEX_OUTLINE_RADIUS) + " tm=" + str(tm),
	"diag_first": "" if edge == null or edge.cells.is_empty() else str(edge.cells[0]) + " -> " + str(tm.map_to_local(edge.cells[0])),
	"ok": true,
	"terrain": terrain,
	"background": str(state.background_terrain),
	"board": "%d×%d" % [BattleState.BW, BattleState.BH],
	"units": placed.size(),
	"off_board": off_board,
	"field_px": str(view.field_size()),
	"zoom": str(view.get_node("Camera").zoom),
	"cells": ", ".join(placed),
}
