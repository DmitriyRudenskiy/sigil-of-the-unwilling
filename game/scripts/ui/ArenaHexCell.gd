extends Node2D
class_name ArenaHexCell

signal cell_input(viewport: Node, event: InputEvent, shape_idx: int, pos: Vector2, normal: Vector2, cell: Vector2i)
signal cell_entered(cell: Vector2i)
signal cell_exited()
const _ArenaRingSystem = preload("res://scripts/city/ArenaRingSystem.gd")

var cell: Vector2i = Vector2i.ZERO
var ring: int = 0
var feature_id: StringName = &""
var mark_id: StringName = &""
var selected: bool = false
var badge_id: StringName = &""

var _poly: Polygon2D
var _mark: Label
var _ylab: Label
var _feat: Label
var _badge: Label

func _ready() -> void:
    _poly = $Hex
    _mark = $Mark
    _ylab = $Yield
    _feat = $Feature
    _badge = $Badge
    _poly.color = _ring_color(ring)
    _mark.text = _mark_label_text()
    _mark.add_theme_font_size_override("font_size", 18 if ring == 0 else 13)
    _ylab.visible = ring > 0
    _ylab.text = _ArenaRingSystem.ring_yield_label(ring)
    _feat.visible = feature_id != &""
    if feature_id != &"":
        _feat.text = ArenaRingSystem.feature_glyph(feature_id)

func get_poly() -> Polygon2D:
    return _poly

func update() -> void:
    if _mark != null:
        _mark.text = _mark_label_text()
    if _ylab != null:
        _ylab.text = _ArenaRingSystem.ring_yield_label(ring)
    if _badge != null:
        _badge.text = badge_id

func _mark_label_text() -> String:
    if ring == 0:
        return "🏰"
    return mark_id

func _on_area_input(viewport: Node, event: InputEvent, shape_idx: int) -> void:

    cell_input.emit(viewport, event, shape_idx, Vector2.ZERO, Vector2.ZERO, cell)

func _on_mouse_entered() -> void:
    cell_entered.emit(cell)

func _on_mouse_exited() -> void:
    cell_exited.emit()

func _ring_color(ring: int) -> Color:
    return ArenaRingSystem.ring_color(ring)
