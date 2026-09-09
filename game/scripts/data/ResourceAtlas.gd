
class_name ResourceAtlas
extends RefCounted

const ResourceType = preload("res://scripts/data/ResourceType.gd")

const SHEET_PATH := "res://assets/textures/resources.png"
const GRID_COLS := 4
const GRID_ROWS := 4

static var _map: Dictionary = {}

static func _ensure_map() -> Dictionary:
    if _map.is_empty():
        _map = {
            ResourceType.to_name(ResourceType.ID.WOOD): Vector2i(0, 0),
            ResourceType.to_name(ResourceType.ID.MERCURY): Vector2i(1, 0),
            ResourceType.to_name(ResourceType.ID.ORE): Vector2i(3, 0),
            ResourceType.to_name(ResourceType.ID.SULFUR): Vector2i(0, 2),
            ResourceType.to_name(ResourceType.ID.CRYSTAL): Vector2i(0, 1),
            ResourceType.to_name(ResourceType.ID.GEMS): Vector2i(1, 2),
            ResourceType.to_name(ResourceType.ID.GOLD): Vector2i(3, 1),
            ResourceType.to_name(ResourceType.ID.STONE): Vector2i(3, 0),

            &"oak": Vector2i(0, 0),
            &"silver": Vector2i(1, 0),
            &"quartz": Vector2i(2, 0),
            &"saltpeter": Vector2i(1, 1),
            &"coal": Vector2i(2, 1),
            &"gold_ore": Vector2i(3, 1),
            &"cinnabar": Vector2i(2, 2),
            &"limonite": Vector2i(0, 3),
            &"bog_iron": Vector2i(1, 3),
            &"turquoise": Vector2i(2, 3),
            &"coal_swamp": Vector2i(3, 3),
        }
    return _map

const TYPE_TO_CELL := [
    Vector2i(0, 0),
    Vector2i(1, 0),
    Vector2i(3, 0),
    Vector2i(0, 2),
    Vector2i(0, 1),
    Vector2i(1, 2),
    Vector2i(3, 1),
]

static var _sheet: Texture2D = null
static var _cache: Dictionary = {}

static func clear() -> void:
    _map = {}
    _sheet = null
    _cache = {}

static func _load_sheet() -> Texture2D:
    if _sheet == null:
        var tex := load(SHEET_PATH)
        if tex is Texture2D:
            _sheet = tex
        else:
            push_warning("ResourceAtlas: лист не найден: %s" % SHEET_PATH)
    return _sheet

static func _cell_size() -> Vector2:
    var tex := _load_sheet()
    if tex == null:
        return Vector2(100, 100)
    return Vector2(
        tex.get_width() / float(GRID_COLS),
        tex.get_height() / float(GRID_ROWS)
    )

static func texture_for_cell(cell: Vector2i) -> AtlasTexture:
    var tex := _load_sheet()
    if tex == null:
        return null
    var key := "%d_%d" % [cell.x, cell.y]
    if _cache.has(key):
        return _cache[key]
    var cs := _cell_size()
    var at := AtlasTexture.new()
    at.atlas = tex
    at.region = Rect2(cell.x * cs.x, cell.y * cs.y, cs.x, cs.y)
    _cache[key] = at
    return at

static func texture_for_id(res_id: StringName) -> AtlasTexture:
    var cell: Vector2i = _ensure_map().get(res_id, Vector2i(-1, -1))
    if cell.x < 0:
        return null
    return texture_for_cell(cell)

static func texture_for_type(res_type: int) -> AtlasTexture:
    if res_type < 0 or res_type >= TYPE_TO_CELL.size():
        return null
    return texture_for_cell(TYPE_TO_CELL[res_type])
