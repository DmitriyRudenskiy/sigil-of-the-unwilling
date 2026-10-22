extends Node2D
class_name ResourceNode

const HIDDEN_ICON_SCALE := 0.4

## Носитель добычи (world-map-art-variety 7.3): тип добычи → объект-лагерь из
## листа `world_map_objects.webp` (группа `camp`). Лесопилка/шахта/ферма/алхимия —
## по типу добычи, не по id ресурса (один лагерь на группу). Маппинг — дизайн-
## решение, зафиксировано для ux-review.
const RESOURCE_TO_CAMP := {
	&"oak": "obj_camp_wood",
	&"wood": "obj_camp_wood",
	&"silver": "obj_camp_stone",
	&"quartz": "obj_camp_stone",
	&"turquoise": "obj_camp_stone",
	&"limonite": "obj_camp_stone",
	&"coal": "obj_camp_stone",
	&"gold_ore": "obj_camp_stone",
	&"coal_swamp": "obj_camp_stone",
	&"bog_iron": "obj_camp_stone",
	&"stone": "obj_camp_stone",
	&"saltpeter": "obj_camp_herb",
	&"cinnabar": "obj_camp_herb",
	&"food": "obj_camp_food",
}

enum State { HIDDEN, DISCOVERED, EXHAUSTED }

signal state_changed(node: ResourceNode)
signal exhausted(node: ResourceNode)

var resource_id: StringName
var cell: Vector2i
var _state: int = State.HIDDEN
var _days_until_removal: int = 0
var _yield_amount: int = 0

var sprite: Sprite2D = null
var outline: Sprite2D = null

## id объекта-носителя в листе объектов (пусто — ресурса нет в маппинге).
func carrier_id() -> String:
	return String(RESOURCE_TO_CAMP.get(resource_id, ""))

## Спрайт-текстура носителя: область листа по координатам манифеста. null —
## носителя нет (ресурс не в маппинге или объект не в листе).
func carrier_texture() -> Texture2D:
	var camp := carrier_id()
	if camp == "":
		return null
	var coords := MapObjects.coords_for(camp)
	if coords == Vector2i(-1, -1):
		GameLogger.error("ResourceNode: носитель '%s' не в листе объектов" % camp, "World")
		return null
	var atlas := load(MapObjects.SHEET_PATH)
	if not (atlas is Texture2D):
		return null
	var region := AtlasTexture.new()
	region.atlas = atlas
	region.region = Rect2(coords, Vector2i(MapObjects.TILE, MapObjects.TILE))
	return region

## Смещение спрайта, чтобы якорь объекта (низ-центр) совпал с центром клетки:
## -(якорь - центр тайла) из манифеста.
func _carrier_offset() -> Vector2:
	var camp := carrier_id()
	if camp == "":
		return Vector2.ZERO
	for c in MapObjects.manifest().get("cells", []):
		if String(c.get("id", "")) == camp:
			var anchor: Array = c.get("anchor", [MapObjects.TILE / 2, MapObjects.TILE - 2])
			var a := Vector2(float(anchor[0]), float(anchor[1]))
			return -(a - Vector2(MapObjects.TILE / 2.0, MapObjects.TILE / 2.0))
	return Vector2.ZERO

func init_node(r_id: StringName, c: Vector2i, initial_yield: int) -> void:
	resource_id = r_id
	cell = c
	_yield_amount = initial_yield
	_setup_visual()

func get_state() -> int:
	return _state

func is_hidden() -> bool:
	return _state == State.HIDDEN

func is_discovered() -> bool:
	return _state == State.DISCOVERED

func is_exhausted() -> bool:
	return _state == State.EXHAUSTED

func discover() -> void:
	if _state != State.HIDDEN:
		return
	_state = State.DISCOVERED
	state_changed.emit(self)
	_update_visual()

func exhaust() -> void:
	if _state != State.DISCOVERED:
		return
	_state = State.EXHAUSTED
	_days_until_removal = 3
	exhausted.emit(self)
	state_changed.emit(self)
	_update_visual()

func tick_day() -> int:
	_days_until_removal -= 1
	return _days_until_removal

func get_yield() -> int:
	return _yield_amount

func reduce_yield(amount: int) -> void:
	_yield_amount = max(0, _yield_amount - amount)
	if _yield_amount <= 0:
		exhaust()

func _setup_visual() -> void:

	sprite = $Sprite
	outline = $Outline
	_update_visual()

## Визуал по состоянию (7.3 «Носитель добычи»):
## - HIDDEN: приглушённая иконка ресурса (подсказка о скрытом узле, не носитель);
## - DISCOVERED: объект-носитель типа добычи (лагерь), полный масштаб, якорь в центре клетки;
## - EXHAUSTED: тот же носитель, затемнён — клетка не выглядит разрабатываемой.
func _update_visual() -> void:
	var carrier := carrier_texture()
	match _state:
		State.HIDDEN:
			var tex: Texture2D = ResourceAtlas.texture_for_id(resource_id)
			sprite.texture = tex
			sprite.scale = Vector2(HIDDEN_ICON_SCALE, HIDDEN_ICON_SCALE)
			sprite.position = Vector2.ZERO
			outline.texture = tex
			outline.scale = sprite.scale
			sprite.modulate = ThemeConfig.C_WHITE_DIM_30
			outline.visible = false
		State.DISCOVERED, State.EXHAUSTED:
			if carrier != null:
				sprite.texture = carrier
				sprite.scale = Vector2.ONE
				sprite.position = _carrier_offset()
			else:
				# носителя нет в листе — остаёмся на иконке (деградация, не пустота)
				var tex: Texture2D = ResourceAtlas.texture_for_id(resource_id)
				sprite.texture = tex
				sprite.scale = Vector2.ONE
				sprite.position = Vector2.ZERO
			outline.visible = false
			sprite.modulate = Color.WHITE if _state == State.DISCOVERED else ThemeConfig.C_GRAY_DIM_40
