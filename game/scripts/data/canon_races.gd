class_name CanonRaces
extends RefCounted
## Q-M100 → (а) (D-239): канон-каталог рас. Источник — assets/data/mvp_catalog.json
## (K-M5-правка: первый эшелон 7 рас; `first_tier: true`), тот же файл, что читают
## CanonClasses (классы) и ArchetypeResolver (группы/идентичности).
##
## Legacy-таблица hero_races.gd (6 рас MoM-тила: human/elf/dwarf/aumaua/orlan/godlike)
## не тронута — её диспозиция Q-M44 (корзина B, T-128). Она остаётся фолбэком подписи
## и бонусов для легаси-идов — ровно как hero_classes.gd после T-113.
##
## Чисел здесь нет намеренно: `modifiers` каталога (02e3 SRD, шесть атрибутов) сегодня
## не читает никто — носитель (применение модификаторов к статам членов партии) = T-176.

static func races() -> Array:
	var out: Array = []
	for race in ArchetypeResolver.load_catalog().get("races", []):
		if race is Dictionary:
			out.append(race)
	return out


## Первый эшелон (K-M5): 7 рас. Порядок — порядок каталога.
static func first_tier() -> Array:
	var out: Array = []
	for race in races():
		if bool(race.get("first_tier", false)):
			out.append(race)
	return out


static func by_id(race_id: String) -> Dictionary:
	for race in races():
		if str(race.get("id", "")) == race_id:
			return race
	return {}


## Канон-имя расы; неизвестный id (в т.ч. легаси `elf`) → "—".
static func name_for(race_id: String) -> String:
	var race := by_id(race_id)
	if race.is_empty():
		return "—"
	return str(race.get("name", "—"))
