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
	# Свои дорожки героя (генерация `scripts/hero_anim`): нарисованы вправо, поэтому
	# каждый имя стоит и в `FACES_RIGHT`.
	"swordsmen": "swordsmen",
	"knights": "knights",
	"archers": "archers",
	"battle_dwarf": "battle_dwarf",
	"champions": "knight",
	"guardians": "knight",
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

## Вырезы арт-комплекта владельца (3.1) — запасной носитель позы: `battle_view`
## берёт вырез только там, где у ключа нет своих дорожек (`frames_for` вернул null).
## Свои дорожки есть у всех трёх ключей ниже, поэтому здесь таблица стоит как
## резерв и как носитель направления взгляда, а не как то, что игрок видит в бою.
## `paladin` ключа юнита не имеет и потому остаётся портретом — подставлять ему
## чужой силуэт нельзя.
## Высота силуэта выреза на поле, world px — та же мера, что у дорожек комплекта
## (силуэт 96 px). Окончательный масштаб ряда решает 3.3.
const STILL_HEIGHT := 96.0

# `static var`, а не `const`: тесты должны мочь зарегистрировать свой вырез и
# проверить запасной путь на живом ключе — иначе ветвь «вырез без дорожек»
# остаётся кодом без проверяющего вызова.
static var still_figures := {
	"swordsmen": "res://assets/units/figures/swordsmen.png",
	"archers": "res://assets/units/figures/archers.png",
	"knights": "res://assets/units/figures/knights.png",
}


## Покой выреза: нижний край кадра — в позиции узла, то есть в центре клетки
## (3.3). Арт нарезан впритык: нижняя строка пикселей и есть линия стоп, это
## померено в файлах `assets/units/figures/` (bottom inset = 0 у всех пяти).
## Смещение — в единицах текстуры, ДО `scale`, поэтому оно считается от высоты
## кадра, а не от `STILL_HEIGHT`: константа в 48 px поставила бы стопы на
## четверть ниже клетки и тем ниже, чем выше исходный кадр.
static func still_rest_offset(tex: Texture2D) -> Vector2:
	return Vector2(0.0, -tex.get_height() / 2.0)

## Штатный взгляд комплекта — влево, и `flip_h = атакующий` разворачивает его к
## противнику. Исключения нарисованы вправо: без списка они смотрели бы от
## противника, а тестом «по стороне» этого не поймать — разворот-то есть.
const FACES_RIGHT := [
	"wolf", "swordsmen", "knights", "archers", "battle_dwarf", "paladin",
]


## Направление взгляда фигуры задаёт арт, а не сторона: комплект смотрит влево, а
## вырезы владельца и волк нарисованы вправо. Потребитель разворачивает фигуру
## условием `facing != faces_right(key)`.
static func faces_right(unit_key: String) -> bool:
	if still_figures.has(unit_key):
		return true
	return str(ANIMATED.get(unit_key, "")) in FACES_RIGHT

static var _cache: Dictionary = {}
static var _stills: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()
	_stills.clear()


## Текстура выреза юнита; `null` — выреза нет, потребитель остаётся на дорожках
## или портрете. Отсутствующий файл молча даёт `null`: отсутствие картинки не
## имеет права ронять бой.
static func still_texture_for(unit_key: String) -> Texture2D:
	if _stills.has(unit_key):
		return _stills[unit_key]
	var tex: Texture2D = null
	var path := str(still_figures.get(unit_key, ""))
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_stills[unit_key] = tex
	return tex


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
