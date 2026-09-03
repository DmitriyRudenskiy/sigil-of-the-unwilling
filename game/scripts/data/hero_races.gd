extends RefCounted
## Расы героя (RU). Адаптация GAMES_TROLES races.gd под систему характеристик
## проекта: attack / defense / spell_power / knowledge.
## Источник: GAMES_TROLES game/data/modules/races.gd.
##
## ponytail: данные в виде таблицы key -> {name, desc, bonuses, subraces}.
## UI читает ключи реестра обобщённо — замена содержания не ломает конструктор.
const RACES := {
	"human": {
		"name": "Человек",
		"desc": "Универсалы — сбалансированные и надёжные.",
		"bonuses": {"attack": 1, "defense": 1},
		"subraces": [
			{"id": "meadow", "name": "Луговичи"},
			{"id": "ocean", "name": "Приморские"},
			{"id": "savannah", "name": "Саванные"},
		],
	},
	"elf": {
		"name": "Эльф",
		"desc": "Ловкие и мудрые стражи лесов.",
		"bonuses": {"spell_power": 1, "knowledge": 1},
		"subraces": [
			{"id": "wood", "name": "Лесной"},
			{"id": "pale", "name": "Бледный"},
		],
	},
	"dwarf": {
		"name": "Дварф",
		"desc": "Крепкие горные кузнецы.",
		"bonuses": {"defense": 2, "attack": 1, "spell_power": -1},
		"subraces": [
			{"id": "mountain", "name": "Горный"},
			{"id": "boreal", "name": "Северный"},
		],
	},
	"aumaua": {
		"name": "Амауа",
		"desc": "Высокие морские воители.",
		"bonuses": {"attack": 2},
		"subraces": [
			{"id": "coastal", "name": "Прибрежный"},
			{"id": "island", "name": "Островной"},
		],
	},
	"orlan": {
		"name": "Орлан",
		"desc": "Хитрые тёмные следопыты.",
		"bonuses": {"knowledge": 2, "spell_power": 1, "attack": -1},
		"subraces": [
			{"id": "hearth", "name": "Кострищный"},
			{"id": "wild", "name": "Дикий"},
		],
	},
	"godlike": {
		"name": "Богоподобный",
		"desc": "Рождённые сверхлюди.",
		"bonuses": {"spell_power": 1, "knowledge": 1},
		"subraces": [
			{"id": "death", "name": "Смертный"},
			{"id": "fire", "name": "Огненный"},
			{"id": "nature", "name": "Природный"},
			{"id": "moon", "name": "Лунный"},
		],
	},
}
