extends Node
class_name HeroVisualController

const _HexDraw = preload("res://scripts/core/hex_draw.gd")
const HeroVisualsScene = preload("res://scenes/entities/hero_visuals.tscn")
const DestMarkerScene = preload("res://scenes/entities/dest_marker.tscn")
const StatusOrbScene = preload("res://scenes/entities/status_orb.tscn")

# Канонический путь листа (UI-4, 2026-10-13): единственный путь поиска — эта
# константа. Эвристика _find_sheet() (кандидаты + скан assets/raw) удалена
# вместе с raw/; оверрайд листа — правка константы, не имя файла в raw/.
const HERO_SHEET_PATH := "res://assets/characters/hero_knight.png"

# Ориентация «бокового» кадра канонического PNG-листа (8x5) — вправо.
# Управляет знаком flip_h в set_facing.
var _side_faces_right := true

var _visuals: Node2D = null
var _anim: AnimatedSprite2D
var _fallback: Sprite2D
var _avatar_tex: Texture2D
var _marker: DestMarker
var _status_orb: StatusOrb
var _parent: HeroController
var _map_gen: MapGenerator
## Слой-хост для глобальных оверлеев (маркер пути); инжектируется сценой.
var _map_root: Node = null

func set_marker_host(host: Node) -> void:
	_map_root = host

func get_avatar_texture() -> Texture2D:
	return _avatar_tex

func setup(map: MapGenerator, hero: HeroController) -> void:
	_map_gen = map
	_parent = hero

func build_visual() -> void:
	if _visuals != null:
		return
	_visuals = HeroVisualsScene.instantiate()
	_parent.add_child(_visuals)
	_fallback = _visuals.get_node("Fallback")
	_anim = _visuals.get_node("Anim")
	var sheet_path := HERO_SHEET_PATH if FileAccess.file_exists(HERO_SHEET_PATH) else ""
	if sheet_path != "":
		# Лист 8x5 — нормализация по alpha-bbox (иначе анимация дрожит).
		var sf_new := KnightFramesBuilder.build_from_file(sheet_path)
		if sf_new != null and not sf_new.get_animation_names().is_empty():
			_avatar_tex = sf_new.get_frame_texture(&"side", 0)
			_anim.sprite_frames = sf_new
			_anim.scale = Vector2(0.62, 0.62)
			_anim.stop()
			_anim.frame = 0
			GameLogger.hero("Knight animation built from %s" % sheet_path)
	if _anim.sprite_frames == null or _anim.sprite_frames.get_animation_names().is_empty():
		_fallback.texture = PlaceholderTexture.circle(20, Color(0.9, 0.7, 0.1), Color(0.3, 0.2, 0.0))
		_fallback.visible = true
		_anim.visible = false
	else:
		_fallback.visible = false
		_anim.visible = true

func idle_animation() -> void:
	if _anim != null:
		_anim.stop()
		_anim.frame = 0

func set_facing(delta: Vector2i) -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	if delta.x != 0:
		_anim.animation = "side"
		_anim.flip_h = (delta.x < 0) if _side_faces_right else (delta.x > 0)
	elif delta.y < 0:
		_anim.animation = "away"
		_anim.flip_h = false
	else:
		_anim.animation = "away"
		_anim.flip_h = true
	_anim.play()

## Галоп вместо шага (ряд 2 листа; вызывается во время движения, если подключат).
func set_running(enabled: bool) -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	if not _anim.sprite_frames.has_animation(&"run"):
		return
	if _anim.animation == &"side" or _anim.animation == &"run":
		_anim.animation = &"run" if enabled else &"side"
		if enabled:
			_anim.play()

func setup_path_visual() -> void:
	if _marker == null:
		_marker = DestMarkerScene.instantiate()
		# Маркер — глобальный оверлей пути: монтируется в слой, объявленный
		# сценой (контракт @onready), а не находится обходом дерева вверх.
		var marker_host: Node = _map_root if _map_root != null else get_tree().root
		marker_host.add_child(_marker)
	if _status_orb == null:
		_status_orb = StatusOrbScene.instantiate()
		_status_orb.name = "StatusOrb"
		_parent.add_child(_status_orb)

func draw_path(_pts: Array[Vector2i]) -> void:
	pass

func clear_path_visual() -> void:
	if _marker:
		_marker.hide_marker()

func update_status_orb(mp_ratio: float) -> void:
	if _status_orb:
		_status_orb.set_ratio(mp_ratio)

func show_marker(pos: Vector2) -> void:
	if _marker:
		_marker.show_at(pos)
