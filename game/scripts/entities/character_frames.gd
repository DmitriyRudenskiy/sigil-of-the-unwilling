extends RefCounted
class_name CharacterFrames

## Анимированные фигурки на поле боя.
##
## Носитель кадров — комплект `battle-demo` (задачи 8.1–8.3, ADR-008): холст 512×512,
## ступни в (256, 448), дорожки `idle/walk/attack/hit/turn` собраны принятыми клипами
## (`battle-demo/tools/build_sprite_frames.py`). В игру файлы переезжают без правок:
## путь внутри `.tres` (`res://assets/sprites/<имя>/…`) совпадает с игровым `res://`.
##
## Таблица — не «все юниты», а только те, кому кадр подходит силуэтом. Всадники
## (`cavalry`, `lancer`), драконы, нежить и прочая нечеловеческая сотня остаются
## портретом `UnitSprites.find_portrait`: анимированного носителя у них нет, а
## подставлять вместо них человеческий силуэт — врать игроку о том, кто стоит в клетке.
## Проверено тестом `tests/unit/ui/test_battle_figures_animated.gd`.
const ANIMATED := {
	"swordsmen": "knight",
	"knights": "knight",
	"champions": "knight",
	"guardians": "knight",
	"archers": "archer",
	"pikeman": "spearman",
	"halberdier": "spearman",
	"berserker": "barbarian",
	"mages": "wizard",
	"archmages": "sorcerer",
	"magus": "stormmage",
	"druid": "priest",
	"great_druid": "priest",
	"wolves": "wolf",
}

## ADR-008: холст комплекта 512 → холст движка 128 (силуэт 96 px на поле).
## `centered = false` + этот offset означают «позиция узла = точка опоры на полу»,
## поэтому фигура стоит ровно в своей клетке при любом кадре дорожки.
const FEET_OFFSET := Vector2(-256, -448)
const SCALE := 0.25

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## SpriteFrames персонажа юнита; `null` — анимированного носителя нет, потребитель
## остаётся на портрете. Пустой путь и отсутствующий ресурс молча дают `null`:
## отсутствие картинки не имеет права ронать бой.
static func frames_for(unit_key: String) -> SpriteFrames:
	if _cache.has(unit_key):
		return _cache[unit_key]
	var frames: SpriteFrames = null
	var character := str(ANIMATED.get(unit_key, ""))
	if character != "":
		var path := "res://assets/sprites/%s.sprite_frames.tres" % character
		if ResourceLoader.exists(path):
			frames = load(path) as SpriteFrames
	_cache[unit_key] = frames
	return frames
