class_name HeroTactics
extends RefCounted
## Phase 9: тактические проявления классов и расы героя в тактическом бою.
## Чистый статический модуль (headless-тестируемый): бонусы определяются
## тегами бойца-героя (класс + раса), местностью и фланговым аспектом.
## Боец-герой получает теги класса и расы в HeroController.get_hero_battle_stack.

## 9.1 Следопыт (ranger): +движение в лесу.
const RANGER_FOREST_SPEED := 1

## 9.1 Воин (fighter): +урон при атаке с фронта.
const FIGHTER_FRONT_BONUS := 2

## 9.2 Дварф (dwarf, "гномы"): +защита на холмах.
const DWARF_HILL_DEF_MULT := 1.25

## 9.2 Эльф (elf): +шанс крита в лесу.
const ELF_FOREST_CRIT := 0.15

## Аспект фланга: 0 = фронт (см. BattleState.attack_aspect).
const ASPECT_FRONT := 0

static func terrain_is_forest(t: int) -> bool:
	return t == BattleTerrain.TerrainType.FOREST

static func terrain_is_hill(t: int) -> bool:
	return t == BattleTerrain.TerrainType.HILL

## 9.1 Следопыт: +RANGER_FOREST_SPEED к движению, пока стоит в лесу.
static func movement_bonus(unit, terrain: int) -> int:
	if unit == null:
		return 0
	if unit.has_tag("ranger") and terrain_is_forest(terrain):
		return RANGER_FOREST_SPEED
	return 0

## 9.1 Воин: +FIGHTER_FRONT_BONUS к атаке при ударе с фронта (aspect == 0).
static func front_attack_bonus(unit, aspect: int) -> int:
	if unit == null:
		return 0
	if unit.has_tag("fighter") and aspect == ASPECT_FRONT:
		return FIGHTER_FRONT_BONUS
	return 0

## 9.2 Дварф: множитель защиты DWARF_HILL_DEF_MULT на холмах.
static func hill_defense_mult(unit, terrain: int) -> float:
	if unit == null:
		return 1.0
	if unit.has_tag("dwarf") and terrain_is_hill(terrain):
		return DWARF_HILL_DEF_MULT
	return 1.0

## 9.2 Эльф: +ELF_FOREST_CRIT к шансу крита, пока стоит в лесу.
static func forest_crit_bonus(unit, terrain: int) -> float:
	if unit == null:
		return 0.0
	if unit.has_tag("elf") and terrain_is_forest(terrain):
		return ELF_FOREST_CRIT
	return 0.0
