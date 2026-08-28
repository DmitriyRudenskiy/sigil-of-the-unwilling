extends Node
class_name HeroVisualController
## Hero visual: sprite, animation from sheet, fallback circle.
## Does not modify game state — only reacts to events.

const _HexDraw = preload("res://scripts/util/HexDraw.gd")

const HERO_SHEET_PATH := "res://assets/raw/hero_knight.jpg"

var _anim: AnimatedSprite2D
var _sheet_path_cache: String = ""
var _fallback: Sprite2D
var _avatar_tex: Texture2D
var _marker: DestMarker
var _status_orb: StatusOrb
var _parent: HeroController
var _map_gen: MapGenerator


## Public accessor
func get_avatar_texture() -> Texture2D:
	return _avatar_tex


func setup(map: MapGenerator, hero: HeroController) -> void:
	_map_gen = map
	_parent = hero


func build_visual() -> void:
	if _anim != null or _fallback != null:
		return
	var sheet_path := _find_sheet()
	if sheet_path != "":
		var sheet := Image.load_from_file(sheet_path)
		if sheet != null:
			_build_anim_from_sheet(sheet)
	if _anim == null:
		_fallback = Sprite2D.new()
		_fallback.texture = PlaceholderTexture.circle(20, Color(0.9, 0.7, 0.1), Color(0.3, 0.2, 0.0))
		_fallback.z_index = 10
		_parent.add_child(_fallback)


func _find_sheet() -> String:
	if _sheet_path_cache != "":
		return _sheet_path_cache
	# 1) explicit names — no scanning needed
	for c in ["hero_knight.png", "knight.png", "hero.png", "knight.jpeg", "hero.jpeg", "hero_knight.jpg"]:
		var path: String = "res://assets/raw/" + str(c)
		if FileAccess.file_exists(path):
			_sheet_path_cache = path
			return path
	# 2) auto-detect: large square image in assets/raw (only if explicit names missed)
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
			var img := Image.load_from_file("res://assets/raw/" + f)
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
	# Remove black background
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
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = sf
	_anim.scale = Vector2(0.62, 0.62)
	_anim.z_index = 10
	_parent.add_child(_anim)
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
		_marker = DestMarker.new()
		_parent.get_parent().add_child(_marker)
	if _status_orb == null:
		_status_orb = StatusOrb.new()
		_status_orb.name = "StatusOrb"
		_parent.add_child(_status_orb)


## Path line removed — markers now handled by MarkerLayer.
func draw_path(_pts: Array[Vector2i]) -> void:
	# no-op: markers replace path line
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


## DestMarker class (kept here to avoid a separate file)
class DestMarker extends Node2D:
	var active := false
	var _t := 0.0

	func _process(d: float) -> void:
		if active:
			_t += d
			queue_redraw()

	func show_at(pos: Vector2) -> void:
		position = pos
		active = true
		queue_redraw()

	func hide_marker() -> void:
		active = false
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var r := 36.0 + sin(_t * 6.0) * 4.0
		var pts := _HexDraw.points(r)
		draw_polyline(pts, Color(1.0, 0.25, 0.2, 0.95), 3.0)


## StatusOrb — small colored orb above hero token showing MP state.
class StatusOrb extends Node2D:
	var _ratio: float = 1.0
	var _t := 0.0

	func _ready() -> void:
		position = Vector2(0, -40)
		z_index = 11

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func set_ratio(r: float) -> void:
		_ratio = clampf(r, 0.0, 1.0)

	func _draw() -> void:
		var color: Color
		if _ratio >= 0.4:
			color = Color(0.2, 0.85, 0.2, 0.9)
		elif _ratio >= 0.1:
			color = Color(1.0, 0.85, 0.1, 0.9)
		else:
			color = Color(0.9, 0.2, 0.2, 0.9)
		var r := 6.0 + sin(_t * 3.0) * 1.5
		draw_circle(Vector2.ZERO, r, color)
