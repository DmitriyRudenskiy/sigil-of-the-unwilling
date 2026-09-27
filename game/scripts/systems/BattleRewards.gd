class_name BattleRewards
extends RefCounted
## Phase 8: исход боя — трофеи за победу и ранение героя при поражении.
##
## Spec (tactical-combat, «Условия победы и поражения»):
##   - Полная победа → сторона «получает трофеи (ресурсы, опыт, предметы)».
##   - Герой выжил (проиграл, но отступил/остался с армией) → «статус ранен
##     (сниженные статы на N ходов)» и «не погибает в мире».
##
## Чистые статические функции — headless-тестируемы. Предметы (артефакты)
## выпадают отдельно через WorldBattleCoordinator._try_artifact_drop.

# Опыт за каждого уничтоженного солдата.
const XP_PER_SOLDIER := 5
# Базовая награда золотом + по 1 за каждого врага.
const VICTORY_GOLD_ID := &"gold"
const VICTORY_GOLD_BASE := 20
# Ранение: множитель статов героя и длительность (в ходах мира).
const WOUNDED_STAT_MULT := 0.7
const WOUNDED_TURNS := 3


## Трофеи за уничтоженную армию: {xp: int, resources: {id: amount}}.
## Детерминировано (без RNG): xp растёт с числом врагов, gold = база + 1/враг.
static func compute_trophies(defeated_army: Array) -> Dictionary:
	var xp := 0
	var gold := VICTORY_GOLD_BASE
	for s in defeated_army:
		if s == null:
			continue
		xp += int(s.count) * XP_PER_SOLDIER
		gold += int(s.count)
	return {
		"xp": xp,
		"resources": {VICTORY_GOLD_ID: gold},
	}


## Герой ранен, только если проиграл бой И выжил (отступил / остался с армией).
static func hero_should_be_wounded(hero_won: bool, hero_survived: bool) -> bool:
	return (not hero_won) and hero_survived


## Снижение статов раненого героя: {attack, defense}.
static func apply_wounded_penalty(atk: int, def: int) -> Dictionary:
	return {
		"attack": max(1, int(round(atk * WOUNDED_STAT_MULT))),
		"defense": max(0, int(round(def * WOUNDED_STAT_MULT))),
	}
