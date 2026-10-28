# CAPTURE_SETUP для кадра «максимальный состав» (battle-99-hex-clean-hud, задача 1.3).
#
# `battle_field.gd` поднимает четыре стека с каждой стороны — это проверка, что
# обычное размещение лежит на поле. Задача 1.3 требует максимального для носителя
# состава: герой выводит в бой `GameNumbersCity.HERO_ARMY_MAX_STACKS` (=12) стеков,
# а колонны размещения по 9 клеток (BH), значит часть стеков обязана уйти вглубь
# поля. Кадр с 4+4 этого не проверяет вообще.
#
# Местность — из `CAPTURE_TERRAIN`, как в `battle_field.gd`: кадр нужен и для
# снежного кадра, и для штатного вида тайлами.
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
	terrain = "snow"

var kinds: Array[String] = ["swordsmen", "archers", "wolves", "orc", "goblins", "pegasus"]
var per_side: int = GameNumbersCity.HERO_ARMY_MAX_STACKS
var atk: Array[UnitStack] = []
var def: Array[UnitStack] = []
for i in per_side:
	atk.append(Units.make_fixed_stack(kinds[i % kinds.size()], 6 + i))
	def.append(Units.make_fixed_stack(kinds[(i + 3) % kinds.size()], 6 + i))
battle.start_battle(atk, def, {}, {}, {}, {}, 7, null, terrain)

var placed := 0
var off_board := 0
var cells := {}
var rows_by_side := {}
for side in [BattleState.Side.ATTACKER, BattleState.Side.DEFENDER]:
	var tag := "A" if side == BattleState.Side.ATTACKER else "D"
	var cols := {}
	for u in state.get_units_by_side(side):
		placed += 1
		var c: Vector2i = u.cell
		if c.x < 0 or c.x >= BattleState.BW or c.y < 0 or c.y >= BattleState.BH:
			off_board += 1
		cells[c] = tag
		cols[c.x] = int(cols.get(c.x, 0)) + 1
	rows_by_side[tag] = cols
return {
	"ok": true,
	"terrain": terrain,
	"background": str(state.background_terrain),
	"board": "%d×%d" % [BattleState.BW, BattleState.BH],
	"asked": 2 * per_side,
	"units": placed,
	"off_board": off_board,
	"occupied": cells.size(),
	"columns": rows_by_side,
	"free": BattleState.BW * BattleState.BH - cells.size(),
}
