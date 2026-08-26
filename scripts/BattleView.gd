class_name BattleView
extends Node2D
## Визуальное представление боя: поле, спрайты, подсветка, камера.
## Не меняет BattleState и не принимает решений.

const RING := 5
const _HexDraw = preload("res://scripts/util/HexDraw.gd")
const ParticlePresets = preload("res://scripts/util/ParticlePresets.gd")

var _tile_map: TileMapLayer
var _overlay: HighlightOverlay
var _camera: Camera2D
var _sprites_by_uid: Dictionary = {}


# ==================== ПОДСВЕТКА ====================
class HighlightOverlay extends Node2D:
	var move_cells: Dictionary = {}
	var atk_cells: Dictionary = {}
	var tm: TileMapLayer

	func refresh() -> void:
		queue_redraw()

	func _draw() -> void:
		if tm == null:
			return
		for k in move_cells:
			var c: Vector2i = k
			_hex(tm.map_to_local(c), Color(0.2, 0.9, 1.0, 0.95))
		for k in atk_cells:
			var c: Vector2i = k
			_hex(tm.map_to_local(c), Color(1.0, 0.25, 0.2, 0.95))

	func _hex(center: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 7:
			var ang := deg_to_rad(60.0 * i - 90.0)
			pts.append(center + Vector2(cos(ang), sin(ang)) * 38.0)
		draw_polyline(pts, col, 3.0)


# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func setup() -> void:
	_tile_map = TileMapLayer.new()
	_tile_map.name = "BattleTerrain"
	_tile_map.tile_set = load("res://tilesets/hex_tileset.tres")
	add_child(_tile_map)
	RenderingServer.set_default_clear_color(Color(0.33, 0.30, 0.18))
	HexUtils.calibrate(_tile_map)

	_overlay = HighlightOverlay.new()
	_overlay.tm = _tile_map
	_overlay.z_index = 5
	add_child(_overlay)

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()


func paint_field() -> void:
	var grass: Vector2i = TerrainAtlasMap.CENTER_COORDS[HexUtils.Terrain.GRASS]
	var vars: Array = TerrainAtlasMap.VARIANTS.get(HexUtils.Terrain.GRASS, [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in range(-RING, BattleState.BH + RING):
		for x in range(-RING, BattleState.BW + RING):
			var coords := grass
			if vars.size() > 0 and rng.randf() < 0.5:
				coords = vars[rng.randi_range(0, vars.size() - 1)]
			_tile_map.set_cell(Vector2i(x, y), TerrainAtlasMap.SOURCE_ID, coords)


func add_obstacle(cell: Vector2i, emoji: String) -> void:
	var lbl := Label.new()
	lbl.text = emoji
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.position = _tile_map.map_to_local(cell) + Vector2(-14, -16)
	lbl.z_index = 4
	add_child(lbl)


func spawn_hero_figure() -> void:
	var path := UnitSprites.find_portrait("hero_knight")
	if path == "":
		path = UnitSprites.find_portrait("knight")
	if path == "":
		return
	var hero := Sprite2D.new()
	hero.texture = load(path)
	hero.scale = Vector2(1.0, 1.0)
	hero.flip_h = true
	hero.position = _tile_map.map_to_local(Vector2i(1, 1))
	hero.z_index = 7
	add_child(hero)


func fit_camera() -> void:
	if _tile_map.tile_set == null:
		return
	var used: Rect2i = _tile_map.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var p0 := _tile_map.map_to_local(used.position)
	var p1 := _tile_map.map_to_local(used.position + used.size - Vector2i(1, 1))
	var field_sz := Vector2(absf(p1.x - p0.x) + 60.0, absf(p1.y - p0.y) + 60.0)
	var center := (p0 + p1) / 2.0
	var vp_sz := get_viewport().get_visible_rect().size
	var z: float = maxf(vp_sz.x / field_sz.x, vp_sz.y / field_sz.y)
	_camera.zoom = Vector2(z, z)
	_camera.position = center


# ==================== ЮНИТЫ ====================
func create_unit_sprite(unit: BattleState.BattleUnit) -> void:
	var n := Node2D.new()
	var key := unit.get_key()
	var ppath := UnitSprites.find_portrait(key)
	if ppath != "":
		var sp := Sprite2D.new()
		sp.texture = load(ppath)
		sp.scale = Vector2(1.0, 1.0)
		sp.flip_h = (unit.side == "attacker")
		n.add_child(sp)
	else:
		var col := Color(0.2, 0.5, 0.9) if unit.side == "attacker" else Color(0.9, 0.3, 0.2)
		var sp := Sprite2D.new()
		sp.texture = PlaceholderTexture.circle(22, col, Color(0.1, 0.1, 0.1))
		n.add_child(sp)

	var il := Label.new()
	var display_name := unit.get_display_name()
	il.text = display_name.left(1) if display_name != "" else "?"
	il.add_theme_font_size_override("font_size", 20)
	il.position = Vector2(-10, -14)
	n.add_child(il)

	var cl := Label.new()
	cl.name = "CountLabel"
	cl.text = str(unit.get_count())
	cl.add_theme_font_size_override("font_size", 16)
	cl.add_theme_color_override("font_color", Color.WHITE)
	cl.position = Vector2(-12, 34)
	n.add_child(cl)

	n.position = _tile_map.map_to_local(unit.cell)
	n.z_index = 6
	n.set_meta("uid", unit.uid)
	_sprites_by_uid[unit.uid] = n
	add_child(n)


func update_unit_count(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	var cl := node.get_node_or_null("CountLabel")
	if cl != null:
		cl.text = str(unit.get_count())


func flash_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1, 0.3, 0.3), 0.1)
	tw.tween_property(node, "modulate", Color.WHITE, 0.2)


func remove_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return

	_sprites_by_uid.erase(unit.uid)
	ParticlePresets.spawn_burst(self, node.position, Color.RED)

	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1, 1, 1, 0), 0.25)
	tw.tween_callback(node.queue_free)


func animate_move(unit: BattleState.BattleUnit, path: Array[Vector2i]) -> Tween:
	var node := _find_node(unit)
	if node == null or path.size() < 2:
		return null
	var an := node.get_node_or_null("Anim")
	if an != null:
		an.play()
	var tw := create_tween()
	for i in range(1, path.size()):
		tw.tween_property(node, "position", _tile_map.map_to_local(path[i]), 0.15)
	if an != null:
		tw.tween_callback(an.stop)
	return tw


func animate_attack(attacker: BattleState.BattleUnit, defender: BattleState.BattleUnit) -> void:
	var attacker_node := _find_node(attacker)
	var defender_node := _find_node(defender)

	if attacker_node == null or defender_node == null:
		return

	var start_pos: Vector2 = attacker_node.position
	var dir: Vector2 = (defender_node.position - start_pos).normalized() * 26.0

	var tw := create_tween()
	tw.tween_property(attacker_node, "position", start_pos + dir, 0.08)
	tw.tween_property(attacker_node, "position", start_pos, 0.12)


func show_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.position = _tile_map.map_to_local(cell) + Vector2(-30, -60)
	label.z_index = 20

	add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 30.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(label.queue_free)


func show_damage_number(unit: BattleState.BattleUnit, damage: int) -> void:
	var node := _find_node(unit)
	if node == null:
		return

	var label := Label.new()
	label.text = "-%d" % damage
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	label.position = node.position + Vector2(-16, -50)
	label.z_index = 21

	add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 24.0, 0.5)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


func show_retaliation_arrow(from_unit: BattleState.BattleUnit, to_unit: BattleState.BattleUnit) -> void:
	var from_node := _find_node(from_unit)
	var to_node := _find_node(to_unit)

	if from_node == null or to_node == null:
		return

	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(1.0, 0.8, 0.2, 0.95)
	line.z_index = 19

	line.add_point(from_node.position)
	line.add_point(to_node.position)

	add_child(line)

	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.35)
	tw.tween_callback(line.queue_free)


func pulse_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.25, 1.25), 0.15)
	tw.tween_property(node, "scale", Vector2(1, 1), 0.15)


# ==================== ПОДСВЕТКА ====================
func set_highlights(move_cells: Dictionary, attack_cells: Dictionary) -> void:
	_overlay.move_cells = move_cells
	_overlay.atk_cells = attack_cells
	_overlay.refresh()


func clear_highlights() -> void:
	_overlay.move_cells.clear()
	_overlay.atk_cells.clear()
	_overlay.refresh()


# ==================== УТИЛИТЫ ====================
func local_to_map(world_pos: Vector2) -> Vector2i:
	return _tile_map.local_to_map(world_pos)


func global_to_map(global_pos: Vector2) -> Vector2i:
	return _tile_map.local_to_map(_tile_map.to_local(global_pos))


func map_to_local(cell: Vector2i) -> Vector2:
	return _tile_map.map_to_local(cell)


func _find_node(unit: BattleState.BattleUnit) -> Node2D:
	if unit == null:
		return null
	return _sprites_by_uid.get(unit.uid, null)
