extends RefCounted
class_name HeroClasses
const CLASSES := {
	"barbarian": {
		"name": "Варвар",
		"desc": "Яростный разрушитель в ближнем бою.",
		"power_source": "Ярость",
		"bonuses": {"attack": 2, "defense": 1},
	},
	"fighter": {
		"name": "Воитель",
		"desc": "Дисциплинированный мастер оружия.",
		"power_source": "Дисциплина",
		"bonuses": {"attack": 1, "defense": 1},
	},
	"monk": {
		"name": "Монах",
		"desc": "Владейтель тела и внутренней силы.",
		"power_source": "Раны",
		"bonuses": {"attack": 1, "knowledge": 1},
	},
	"paladin": {
		"name": "Паладин",
		"desc": "Священный защитник и целитель.",
		"power_source": "Вера",
		"bonuses": {"defense": 2, "knowledge": 1},
	},
	"priest": {
		"name": "Священник",
		"desc": "Хранитель чудес и молитв.",
		"power_source": "Вера",
		"bonuses": {"spell_power": 2, "knowledge": 1},
	},
	"druid": {
		"name": "Друид",
		"desc": "Преобразователь природы и зверей.",
		"power_source": "Природа",
		"bonuses": {"spell_power": 2, "defense": 1},
	},
	"cipher": {
		"name": "Шифр",
		"desc": "Мастер фокуса и тёмной магии.",
		"power_source": "Фокус",
		"bonuses": {"spell_power": 2, "attack": 1},
	},
	"wizard": {
		"name": "Маг",
		"desc": "Исследователь арканных потоков.",
		"power_source": "Аркана",
		"bonuses": {"spell_power": 2, "knowledge": 1},
	},
	"ranger": {
		"name": "Следопыт",
		"desc": "Стрелок-одиночка дикой окраины.",
		"power_source": "Узел",
		"bonuses": {"attack": 2, "knowledge": 1},
	},
	"rogue": {
		"name": "Разбойник",
		"desc": "Хитрый убийца из тени.",
		"power_source": "Хитрость",
		"bonuses": {"attack": 1, "knowledge": 1},
	},
	"chanter": {
		"name": "Напевец",
		"desc": "Поддержка через священные напевы.",
		"power_source": "Фразы",
		"bonuses": {"spell_power": 1, "knowledge": 2},
	},
}
