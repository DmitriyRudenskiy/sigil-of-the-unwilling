extends Node
class_name HeroVisualController

const _HexDraw = preload("res://scripts/core/HexDraw.gd")
const HeroVisualsScene = preload("res://scenes/entities/HeroVisuals.tscn")
const DestMarkerScene = preload("res://scenes/entities/DestMarker.tscn")
const StatusOrbScene = preload("res://scenes/entities/StatusOrb.tscn")

const HERO_SHEET_PATH := "res://assets/raw/hero_knight.jpg"

var _visuals: Node2D = null
var _anim: AnimatedSprite2D
var _sheet_path_cache: String = ""
var _fallback: Sprite2D
var _avatar_tex: Texture2D
var _marker: DestMarker
var _status_orb: StatusOrb
var _parent: HeroController
var _map_gen: MapGenerator

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
	var sheet_path := _find_sheet()
	if sheet_path != "":
		var sheet_res := load(sheet_path)
		if sheet_res is ImageTexture:
			_build_anim_from_sheet((sheet_res as ImageTexture).get_image())
	if _anim.sprite_frames == null or _anim.sprite_frames.get_animation_names().is_empty():
		_fallback.texture = PlaceholderTexture.circle(20, Color(0.9, 0.7, 0.1), Color(0.3, 0.2, 0.0))
		_fallback.visible = true
		_anim.visible = false
	else:
		_fallback.visible = false
		_anim.visible = true

func _find_sheet() -> String:
	if _sheet_path_cache != "":
		return _sheet_path_cache
	for c in ["hero_knight.png", "knight.png", "hero.png", "knight.jpeg", "hero.jpeg", "hero_knight.jpg"]:
		var path: String = "res://assets/raw/" + str(c)
		if FileAccess.file_exists(path):
			_sheet_path_cache = path
			return path
	var dir := DirAccess.open("res://assets/raw")
	if dir == null:
		return ""
	var best := ""
	var best_w := 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var low := f.to_lower()
		if low.ends_with(".png") or low.ends_with(".jpeg") or low.ends_with(".jpg"):
			var res := load("res://assets/raw/" + f)
			var img: Image = (res as ImageTexture).get_image() if res is ImageTexture else null
			if img != null and img.get_width() >= 800 and absi(img.get_width() - img.get_height()) < 8:
				if img.get_width() > best_w:
					best_w = img.get_width()
					best = "res://assets/raw/" + f
		f = dir.get_next()
	dir.list_dir_end()
	_sheet_path_cache = best
	if best != "":
		GameLogger.hero("sheet auto-detected: %s" % best)
	return best

func _build_anim_from_sheet(sheet: Image) -> void:
	if sheet.get_format() != Image.FORMAT_RGBA8:
		sheet.convert(Image.FORMAT_RGBA8)
	sheet.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	for y in 512:
		for x in 512:
			var px := sheet.get_pixel(x, y)
			if px.r < 0.12 and px.g < 0.12 and px.b < 0.12:
				sheet.set_pixel(x, y, Color(0, 0, 0, 0))
	var fs := 128
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("side")
	sf.add_animation("away")
	for an in ["side", "away"]:
		sf.set_animation_loop(an, true)
		sf.set_animation_speed(an, 8.0)
	for c in 4:
		var f_side := Image.create(fs, fs, false, Image.FORMAT_RGBA8)
		f_side.blit_rect(sheet, Rect2i(c * fs, 0, fs, fs), Vector2i(0, 0))
		sf.add_frame("side", ImageTexture.create_from_image(f_side))
		var f_away := Image.create(fs, fs, false, Image.FORMAT_RGBA8)
		f_away.blit_rect(sheet, Rect2i(c * fs, 3 * fs, fs, fs), Vector2i(0, 0))
		sf.add_frame("away", ImageTexture.create_from_image(f_away))
	_avatar_tex = sf.get_frame_texture("side", 0)
	_anim.sprite_frames = sf
	_anim.scale = Vector2(0.62, 0.62)
	_anim.stop()
	_anim.frame = 0
	GameLogger.hero("Knight animation built from %s" % HERO_SHEET_PATH)

func idle_animation() -> void:
	if _anim != null:
		_anim.stop()
		_anim.frame = 0

func set_facing(delta: Vector2i) -> void:
	if _anim == null:
		return
	if delta.x > 0:
		_anim.animation = "side"
		_anim.flip_h = true
	elif delta.x < 0:
		_anim.animation = "side"
		_anim.flip_h = false
	elif delta.y < 0:
		_anim.animation = "away"
		_anim.flip_h = false
	else:
		_anim.animation = "away"
		_anim.flip_h = true
	_anim.play()

func setup_path_visual() -> void:
	if _marker == null:
		_marker = DestMarkerScene.instantiate()
		_parent.get_parent().add_child(_marker)
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
