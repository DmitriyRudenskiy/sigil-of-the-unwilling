extends RefCounted
class_name HeroCultures
const CULTURES := {
	"aedyr": {"name": "Эдир", "desc": "Правящая аристократия эльфов.", "bonuses": {"knowledge": 1, "spell_power": 1, "cha": 1}},
	"deadfire": {"name": "Мёртвые острова", "desc": "Заброшенная архипелаг разбойников.", "bonuses": {"attack": 1, "defense": 1, "luk": 1}},
	"ixamitl": {"name": "Равнины Иксамиль", "desc": "Воинственные племена плато.", "bonuses": {"attack": 1, "knowledge": 1}},
	"old_vailia": {"name": "Старая Вайлия", "desc": "Древние города магов.", "bonuses": {"spell_power": 2, "int": 1}},
	"rauatai": {"name": "Рауатаи", "desc": "Острова южного моря.", "bonuses": {"defense": 1, "spell_power": 1}},
	"living_lands": {"name": "Живые Земли", "desc": "Сердцевина мира.", "bonuses": {"attack": 1, "defense": 1, "spell_power": 1}},
	"white_that_wends": {"name": "Белый Предел", "desc": "Замёрзшие предгорья.", "bonuses": {"defense": 2, "knowledge": 1}},
	"dyrwood": {"name": "Дирвуд", "desc": "Старые эльфийские леса.", "bonuses": {"knowledge": 1, "spell_power": 1}},
	"naasitaq": {"name": "Нааситак", "desc": "Тундры севера.", "bonuses": {"defense": 1, "attack": 1}},
	"eir_glanfath": {"name": "Эир Гланфат", "desc": "Светящиеся поля рая.", "bonuses": {"spell_power": 1, "knowledge": 1}},
}

const BACKGROUNDS := {
	"soldier": {"name": "Солдат", "desc": "Вырос в казармах.", "bonuses": {"attack": 1, "defense": 1}},
	"scholar": {"name": "Учёный", "desc": "Провёл годы за книгами.", "bonuses": {"spell_power": 1, "knowledge": 1, "int": 1}},
	"criminal": {"name": "Преступник", "desc": "Знал улицы снизу.", "bonuses": {"attack": 1, "knowledge": 1, "luk": 1}},
	"sailor": {"name": "Мореплаватель", "desc": "Ходил между островами.", "bonuses": {"defense": 1, "knowledge": 1}},
	"zealot": {"name": "Фанатик", "desc": "Искал истину верой.", "bonuses": {"spell_power": 1, "defense": 1}},
	"merchant": {"name": "Купец", "desc": "Торговал по всему миру.", "bonuses": {"knowledge": 2, "cha": 1}},
}
