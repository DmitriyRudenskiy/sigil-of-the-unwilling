# CAPTURE_SETUP для кадра «принятые кадры героев на поле» (T-318).
#
# Зачем отдельная фикстура: `battle_field.gd` и `battle_hud_full.gd` зовут
# стеки `swordsmen/archers/wolves`, то есть из трёх переснятых героев в кадр
# попадает один. Приёмка T-318 — про то, что в бою стоит РОВНО тот персонаж,
# чей профиль утверждён контактным листом, поэтому фикстура кладёт на поле всех
# героев с собственными дорожками (`CharacterFrames.ANIMATED`: `swordsmen`,
# `knights`, `battle_dwarf`) и возвращает, каким комплектом каждый юнит ожил.
#
# `paladin` в списке быть не может: ключа юнита у него нет (строки в
# `UnitRegistry.UNITS_BASE` не существует), в игру его дорожки не входят —
# см. docs/mvp/HERO-ANIM.md §«Реестр и приоритет носителей».
#
# Диагноз важен сильнее кадра: «анимация есть» не отличить от «AnimationSprite
# показывает вырез владельца». Отдаём путь `.tres` на каждом юните — это и есть
# доказательство, что игра взяла переснянный комплект, а не запасную ветвь.
var battle: Node = get_tree().current_scene
if battle == null or not battle.has_method("start_battle"):
	return {"ok": false, "reason": "текущая сцена — не бой"}
var state = battle.get("_state")
if state == null:
	return {"ok": false, "reason": "у боя нет BattleState"}
if state.get_units_by_side(BattleState.Side.ATTACKER).size() > 0:
	return {"ok": false, "reason": "бой уже идёт"}

var atk: Array[UnitStack] = []
for kind in ["swordsmen", "knights", "battle_dwarf"]:
	var s: UnitStack = Units.make_fixed_stack(kind, 1)
	if s == null:
		return {"ok": false, "reason": "регистр юнитов не отдал стек " + kind}
	atk.append(s)
var dfn: Array[UnitStack] = [Units.make_fixed_stack("goblins", 6)]
if dfn[0] == null:
	return {"ok": false, "reason": "регистр юнитов не отдал вражеский стек"}

battle.start_battle(atk, dfn, {}, {}, {}, {}, 7, null, "grass")

var view = battle.get("_view")
if view == null:
	return {"ok": false, "reason": "у боя нет BattleView"}
var by_uid: Dictionary = view.get("_sprites_by_uid")
var units: Array = []
for u in state.get_units_by_side(BattleState.Side.ATTACKER):
	var n: Node = by_uid.get(u.uid, null)
	var row := {"key": str(u.get_key()), "node": "нет узла" if n == null else "есть"}
	var an = null if n == null else n.get_node_or_null("Anim")
	row["pos"] = "—" if n == null else str((n as Node2D).get_global_transform_with_canvas().origin.round())
	if an == null:
		row["track"] = "нет AnimatedSprite2D"
		row["set"] = "—"
	else:
		row["track"] = str(an.animation)
		row["visible"] = an.visible
		row["set"] = "—" if an.sprite_frames == null else str(an.sprite_frames.resource_path)
	units.append(row)
return {"ok": true, "hero_sets": units}
