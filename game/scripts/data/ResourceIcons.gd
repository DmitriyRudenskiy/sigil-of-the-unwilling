class_name ResourceIcons
extends RefCounted
## resource-collection-popup: дата-маппинг resource_id → текстура/имя/цвет.
##
## Текстуры (спрайт/атлас) предоставляет клиент; до поставки пути в
## `DATA[*]["texture"]` пустые и попап показывает заглушку — круг цвета
## ресурса (PlaceholderTexture.circle). Поставка атласа = заполнить только
## поля "texture" здесь, логика не меняется.
##
## DATA покрывает id простого сбора (wood/mercury/…/gold) — они живут в
## простом словаре hero.resources и в реестре Resources не представлены
## (или не имеют иконки). Для богатых жил (oak/quartz/…) имя берётся из
## ResourceDef.display_name, а цвет — стабильный hash от id.

## res_type (0..6, WorldSpawner/HeroResources.pickup_resource) → resource_id.
const RES_TYPE_IDS: Array[StringName] = [
	&"wood", &"mercury", &"ore", &"sulfur", &"crystal", &"gems", &"gold",
]

## Кол-во за простой сбор — зеркало HeroResources.pickup_resource
## (5 ед., золото 50). Используется в едином сигнале
## GameEventBus.resource_extracted, чтобы попап показывал то же кол-во,
## что выдаёт сбор.
const RES_TYPE_AMOUNTS: Array[int] = [5, 5, 5, 5, 5, 5, 50]

const DATA: Dictionary = {
	&"wood":    {"texture": "", "name": "Дерево",     "color": Color(0.62, 0.44, 0.24)},
	&"mercury": {"texture": "", "name": "Ртуть",      "color": Color(0.64, 0.67, 0.74)},
	&"ore":     {"texture": "", "name": "Руда",       "color": Color(0.50, 0.40, 0.34)},
	&"sulfur":  {"texture": "", "name": "Сера",       "color": Color(0.87, 0.80, 0.30)},
	&"crystal": {"texture": "", "name": "Кристалл",   "color": Color(0.40, 0.63, 0.88)},
	&"gems":    {"texture": "", "name": "Самоцветы",  "color": Color(0.52, 0.80, 0.62)},
	&"gold":    {"texture": "", "name": "Золото",     "color": Color(0.92, 0.77, 0.28)},
}


## resource_id для индекса простого сбора; &"" — если индекс вне 0..6.
static func res_type_id(res_type: int) -> StringName:
	if res_type >= 0 and res_type < RES_TYPE_IDS.size():
		return RES_TYPE_IDS[res_type]
	return &""


## Кол-во за простой сбор (см. RES_TYPE_AMOUNTS); 0 — если индекс некорректен.
static func res_type_amount(res_type: int) -> int:
	if res_type >= 0 and res_type < RES_TYPE_AMOUNTS.size():
		return RES_TYPE_AMOUNTS[res_type]
	return 0


## Текстура из клиентского атласа (DATA[*]["texture"]).
## null — пути нет или файл ещё не поставлен (попап покажет заглушку).
static func get_texture(resource_id: StringName) -> Texture2D:
	var entry: Dictionary = DATA.get(resource_id, {})
	var path: String = str(entry.get("texture", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Имя: DATA → реестр Resources (ResourceDef.display_name) → сам id.
## Имя не `get_name`: в Godot 4.7 у GDScript есть нативный get_name() (0 арг.),
## который затеняет статик и ломает статические вызовы.
static func resource_name(resource_id: StringName) -> String:
	var entry: Dictionary = DATA.get(resource_id, {})
	if entry.has("name"):
		return str(entry["name"])
	var def: ResourceDef = _registry_def(resource_id)
	if def != null and not def.display_name.is_empty():
		return def.display_name
	return str(resource_id)


## Цвет заглушки: DATA → стабильный hash от id (у каждого ресурса свой).
static func get_color(resource_id: StringName) -> Color:
	var entry: Dictionary = DATA.get(resource_id, {})
	if entry.has("color"):
		return entry["color"]
	return _hash_color(resource_id)


static func _registry_def(resource_id: StringName) -> ResourceDef:
	var reg := _registry()
	if reg == null:
		return null
	return reg.get_resource(resource_id)


## Автосинглтон Resources (ResourceRegistry): null в средах без автосинглтонов
## (изолированные тесты) — деградация по D5.
static func _registry() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null(^"Resources")
	return null


static func _hash_color(resource_id: StringName) -> Color:
	var h := absi((resource_id as String).hash())
	var hue := fmod(float(h) / 2147483647.0, 1.0)
	return Color.from_hsv(hue, 0.45, 0.75)
