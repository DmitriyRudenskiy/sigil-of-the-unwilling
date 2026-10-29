# CAPTURE_SETUP для кадра «боевой HUD наполнен» (T-241).
#
# Чем существующие фикстуры не закрывают T-241: `battle_field.gd` и
# `battle_field_max.gd` расставляют armies и зовут `start_battle`, но не кладут
# в ростер героя и не отдают `hero_magic` — то есть карточка героя
# (`hero_cards/hero_left`) остаётся скрытой, а карточка противника
# (`target_card`) не показывается вовсе. Кадр есть, наполненного HUD — нет.
#
# Состав повторяет живой путь (world_battle_coordinator.gd:154 →
# battle_handoff.gd:97-128): личный боец героя с ключом HERO_BATTLE_KEY
# (`get_hero_battle_stack()`) + армия регистровых стеков + `HeroMagic`
# (`hero.get("magic")`) + вражеский отряд на местности клетки.
var battle: Node = get_tree().current_scene
if battle == null or not battle.has_method("start_battle"):
	return {"ok": false, "reason": "текущая сцена — не бой"}
var state = battle.get("_state")
if state == null:
	return {"ok": false, "reason": "у боя нет BattleState"}
if state.get_units_by_side(BattleState.Side.ATTACKER).size() > 0:
	return {"ok": false, "reason": "бой уже идёт"}

# Личный боец героя — те же поля, что собирает hero_controller.gd:265-270.
var hero_stats := UnitStats.new(
	GameNumbersHero.HERO_BATTLE_KEY,
	"Герой",
	4, 4, 1, 6, 5,
	[GameNumbersHero.HERO_BATTLE_KEY, "fighter", "human"]
)
var atk: Array[UnitStack] = [UnitStack.new(hero_stats, 27)]
for kind in ["swordsmen", "archers", "wolves"]:
	var s: UnitStack = Units.make_fixed_stack(kind, 8)
	if s != null:
		atk.append(s)
var dfn: Array[UnitStack] = []
for kind in ["goblins", "orc", "archers"]:
	var s2: UnitStack = Units.make_fixed_stack(kind, 9)
	if s2 != null:
		dfn.append(s2)
if dfn.is_empty():
	return {"ok": false, "reason": "регистр юнитов не отдал вражеские стеки"}

var magic := HeroMagic.new()
magic.mana_max = 20
magic.mana_current = 12
battle.start_battle(atk, dfn, {}, {}, {}, {}, 7, magic, "snow")

# Диагноз наполненности — что реально видно в кадре, а не что «должно быть».
var ui: Node = battle.get("_ui")
var out: Dictionary = {"ok": true}
if ui == null:
	return {"ok": false, "reason": "у боя нет _ui"}
var hl: Control = ui.get_node("hero_cards/hero_left")
var hr: Control = ui.get_node("hero_cards/hero_right")
var tc: Control = ui.get_node("target_card")
out["hero_left_visible"] = hl.visible
out["hero_right_visible"] = hr.visible
out["hero_name"] = str(hl.get_node("row/info/name").text)
out["hero_level_visible"] = hl.get_node("row/info/level_row").visible
out["hero_hp_visible"] = hl.get_node("row/info/hp_row").visible
out["hero_mana_visible"] = hl.get_node("row/info/mana_row").visible
out["hero_mana"] = str(hl.get_node("row/info/mana_row/mana_num").text)
out["target_card_visible"] = tc.visible
out["tc_caption"] = str(tc.get_node("tc_box/tc_caption").text)
out["tc_name"] = str(tc.get_node("tc_box/tc_name").text)
out["tc_def"] = str(tc.get_node("tc_box/tc_def_row/tc_def").text)
out["tc_hp"] = str(tc.get_node("tc_box/tc_hp_row/tc_hp").text)
out["turn_line"] = str(ui.get_node("bottom_bar/info_box/turn_line").text)
out["log_line"] = str(ui.get_node("bottom_bar/info_box/log_row/log_line").text)
out["atk_units"] = state.get_units_by_side(BattleState.Side.ATTACKER).size()
out["def_units"] = state.get_units_by_side(BattleState.Side.DEFENDER).size()
return out
