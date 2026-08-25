extends Node2D
class_name BattleController
## Бой v2: cover-зум без чёрных краёв (кольцо травы), армии с отступом,
## яркая подсветка контурами, надёжный выбор юнитов (_input + pixel fallback)

signal battle_finished(winner: String, surviving_atk: Array, surviving_def: Array)

const BW := 17
const BH := 11
const RING := 3  # декоративное кольцо клеток вокруг поля

var attacker_units: Array[Dictionary] = []
var defender_units: Array[Dictionary] = []
var active_unit: Dictionary = {}
var highlight_move: Dictionary = {}
var highlight_attack: Dictionary = {}
var obstacles: Dictionary = {}
var is_player_turn := true
var battle_over := false
var turn_queue: Array[Dictionary] = []
var turn_idx := 0

var _tile_map: TileMapLayer
var _overlay: HighlightOverlay
var _sprites: Array[Node2D] = []
var _status: Label
var _canvas: CanvasLayer
var _bottom_bar: HBoxContainer
var _camera: Camera2D
var _uid := 0


# ==================== ОВЕРЛЕЙ ПОДСВЕТКИ ====================
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


# ==================== READY ====================
func _ready() -> void:
	_tile_map = TileMapLayer.new()
	_tile_map.name = "BattleTerrain"
	_tile_map.tile_set = load("res://tilesets/hex_tileset.tres")
	add_child(_tile_map)
	HexUtils.calibrate(_tile_map)

	_overlay = HighlightOverlay.new()
	_overlay.tm = _tile_map
	_overlay.z_index = 5
	add_child(_overlay)

	_paint_field()
	_place_obstacles()

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()

	_build_ui()

	await get_tree().process_frame
	_fit_camera()


func _paint_field() -> void:
	var grass: Vector2i = TerrainAtlasMap.CENTER_COORDS[HexUtils.Terrain.GRASS]
	var vars: Array = TerrainAtlasMap.VARIANTS.get(HexUtils.Terrain.GRASS, [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in range(-RING, BH + RING):
		for x in range(-RING, BW + RING):
			var coords := grass
			if vars.size() > 0 and rng.randf() < 0.5:
				coords = vars[rng.randi_range(0, vars.size() - 1)]
			_tile_map.set_cell(Vector2i(x, y), TerrainAtlasMap.SOURCE_ID, coords)


func _place_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var n := 0
	while n < 8:
		var cell := Vector2i(rng.randi_range(4, BW - 5), rng.randi_range(1, BH - 2))
		if obstacles.has(cell):
			continue
		obstacles[cell] = true
		var lbl := Label.new()
		lbl.text = "🪨" if rng.randf() > 0.5 else "🌳"
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.position = _tile_map.map_to_local(cell) + Vector2(-14, -16)
		lbl.z_index = 4
		add_child(lbl)
		n += 1


func _fit_camera() -> void:
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


func _spawn_hero_figure() -> void:
	var path := UnitSprites.find_portrait("hero_knight")
	if path == "":
		path = UnitSprites.find_portrait("knight")
	if path == "":
		return
	var hero := Sprite2D.new()
	hero.texture = load(path)
	hero.scale = Vector2(0.7, 0.7)
	hero.flip_h = true
	hero.position = _tile_map.map_to_local(Vector2i(1, 1))
	hero.z_index = 7
	add_child(hero)


# ==================== UI ====================
func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	var tb := PanelContainer.new()
	tb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tb.offset_bottom = 48
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.1, 0.08, 0.05, 0.92)
	tb.add_theme_stylebox_override("panel", ts)
	_canvas.add_child(tb)
	_status = Label.new()
	_status.text = "Выберите существо…"
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.95, 0.89, 0.72))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(_status)

	_bottom_bar = HBoxContainer.new()
	_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.offset_top = -58
	_bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_bar.add_theme_constant_override("separation", 10)
	_canvas.add_child(_bottom_bar)

	var btns := [
		["⚙️", "Настройки/пауза", "_on_settings"],
		["🏕️", "Отступление", "_on_retreat"],
		["🏃", "Ждать", "_on_wait"],
		["⚔️", "Атака", "_on_attack_mode"],
		["▲", "Свернуть панель", "_on_collapse"],
		["📖", "Книга заклинаний", "_on_spellbook"],
		["⏳", "Пропуск хода", "_on_skip"],
		["🛡️", "Защита", "_on_defend"],
	]
	for b in btns:
		var btn := Button.new()
		btn.text = b[0]
		btn.tooltip_text = b[1]
		btn.custom_minimum_size = Vector2(56, 48)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(Callable(self, b[2]))
		_bottom_bar.add_child(btn)


# ==================== START ====================
func start_battle(atk: Array[Dictionary], def: Array[Dictionary]) -> void:
	attacker_units = _place_army(atk, true)
	defender_units = _place_army(def, false)
	_spawn_hero_figure()
	_build_queue()
	_fit_camera()
	_next_turn()


func _place_army(army: Array[Dictionary], is_atk: bool) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	var sx := 2 if is_atk else BW - 3   # отступ от краёв, чтобы не срезало зумом
	for i in army.size():
		var s: Dictionary = army[i].duplicate()
		if s.get("count", 0) <= 0:
			continue
		if UnitRegistry.UNITS.has(s.get("key", "")):
			var ru: Array = UnitRegistry.UNITS[s["key"]]
			if not s.has("base_damage"):
				s["base_damage"] = ru[1]
			if not s.has("hp"):
				s["hp"] = ru[2]
			if not s.has("speed"):
				s["speed"] = ru[3]
			if not s.has("defense"):
				s["defense"] = ru[4]
			s["name"] = ru[0]
		var cell := Vector2i(sx + (i % 2), (i / 2) * 2 + 1)
		s["cell"] = cell
		s["side"] = "attacker" if is_atk else "defender"
		s["alive"] = true
		s["has_moved"] = false
		s["uid"] = _uid
		_uid += 1
		units.append(s)
		_make_unit_sprite(s)
	return units


func _make_unit_sprite(u: Dictionary) -> void:
	var n := Node2D.new()
	var key: String = u.get("key", "")
	var ppath := UnitSprites.find_portrait(key)
	if ppath != "":
		var sp := Sprite2D.new()
		sp.texture = load(ppath)
		sp.scale = Vector2(0.5, 0.5)
		sp.flip_h = (u["side"] == "attacker")
		n.add_child(sp)
	else:
		var col := Color(0.2, 0.5, 0.9) if u["side"] == "attacker" else Color(0.9, 0.3, 0.2)
		var img := Image.create(52, 52, false, Image.FORMAT_RGBA8)
		var c := Vector2(26, 26)
		for y in 52:
			for x in 52:
				var d := Vector2(x, y).distance_to(c)
				if d <= 22:
					img.set_pixel(x, y, col)
				elif d <= 24:
					img.set_pixel(x, y, Color(0.1, 0.1, 0.1))
		var sp := Sprite2D.new()
		sp.texture = ImageTexture.create_from_image(img)
		n.add_child(sp)
		var il := Label.new()
		il.text = u.get("icon", "?")
		il.add_theme_font_size_override("font_size", 20)
		il.position = Vector2(-10, -14)
		n.add_child(il)
	var cl := Label.new()
	cl.name = "CountLabel"
	cl.text = str(u["count"])
	cl.add_theme_font_size_override("font_size", 13)
	cl.add_theme_color_override("font_color", Color.WHITE)
	cl.position = Vector2(-10, 24)
	n.add_child(cl)
	n.position = _tile_map.map_to_local(u["cell"])
	n.z_index = 6
	n.set_meta("uid", u["uid"])
	add_child(n)
	_sprites.append(n)


# ==================== TURNS ====================
func _build_queue() -> void:
	turn_queue.clear()
	turn_queue.append_array(attacker_units)
	turn_queue.append_array(defender_units)
	turn_queue.sort_custom(func(a, b): return a.get("speed", 5) > b.get("speed", 5))


func _next_turn() -> void:
	if battle_over:
		return
	_clear_highlights()
	while turn_idx < turn_queue.size():
		var u: Dictionary = turn_queue[turn_idx]
		if u.get("alive", false) and u.get("count", 0) > 0:
			break
		turn_idx += 1
	if turn_idx >= turn_queue.size():
		turn_idx = 0
		for u in turn_queue:
			u["has_moved"] = false
			u["defending"] = false
		_next_turn()
		return
	active_unit = turn_queue[turn_idx]
	is_player_turn = (active_unit["side"] == "attacker")
	var side_txt := "Ваш ход" if is_player_turn else "Ход противника"
	_status.text = "%s: %s (%d)" % [side_txt, active_unit.get("name", ""), active_unit.get("count", 0)]
	var node := _find_node(active_unit)
	if node != null:
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector2(1.25, 1.25), 0.15)
		tw.tween_property(node, "scale", Vector2(1, 1), 0.15)
	if not is_player_turn:
		await get_tree().create_timer(0.7).timeout
		_ai_turn()


func _end_turn() -> void:
	turn_idx += 1
	_next_turn()


# ==================== INPUT ====================
func _input(ev: InputEvent) -> void:
	if battle_over or not is_player_turn:
		return
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT:
		_clear_highlights()
		_status.text = "Выберите существо…"
		return
	if ev.button_index != MOUSE_BUTTON_LEFT:
		return

	var world_pos := get_global_mouse_position()
	var cell := _tile_map.local_to_map(world_pos)

	if highlight_attack.has(cell):
		_do_attack(active_unit, _unit_at(cell, "defender"))
		return
	if highlight_move.has(cell):
		_do_move(active_unit, cell)
		return

	var own := _unit_at(cell, "attacker")
	if own.size() == 0:
		own = _unit_at_pixel(world_pos, "attacker")
	if own.size() > 0 and not own.get("has_moved", false):
		_select(own)
		return
	print("[Battle] click -> ", cell)


func _unit_at(cell: Vector2i, side: String) -> Dictionary:
	var units := attacker_units if side == "attacker" else defender_units
	for u in units:
		if u.get("alive", false) and u.get("cell", Vector2i(-1, -1)) == cell:
			return u
	return {}


func _unit_at_pixel(pos: Vector2, side: String) -> Dictionary:
	var units := attacker_units if side == "attacker" else defender_units
	for u in units:
		if u.get("alive", false):
			var up := _tile_map.map_to_local(u["cell"])
			if pos.distance_to(up) < 45.0:
				return u
	return {}


func _select(u: Dictionary) -> void:
	active_unit = u
	_clear_highlights()
	var blocked := _all_blocked(u)
	highlight_move = HexUtils.bfs_reachable(u["cell"], u.get("speed", 5), blocked, BW, BH)
	for nb in HexUtils.get_all_neighbors(u["cell"]):
		var en := _unit_at(nb, "defender")
		if en.size() > 0:
			highlight_attack[nb] = 1
	_overlay.move_cells = highlight_move
	_overlay.atk_cells = highlight_attack
	_overlay.refresh()
	_status.text = "%s: синий контур — ход, красный — атака." % u.get("name", "")
	print("[Battle] selected ", u.get("name"), " moves=", highlight_move.size())


func _clear_highlights() -> void:
	highlight_move.clear()
	highlight_attack.clear()
	_overlay.move_cells.clear()
	_overlay.atk_cells.clear()
	_overlay.refresh()


func _all_blocked(except: Dictionary) -> Dictionary:
	var b: Dictionary = {}
	for u in attacker_units:
		if u != except and u.get("alive", false):
			b[u["cell"]] = true
	for u in defender_units:
		if u.get("alive", false):
			b[u["cell"]] = true
	for o in obstacles:
		b[o] = true
	return b


# ==================== ACTIONS ====================
func _do_move(u: Dictionary, target: Vector2i) -> void:
	var blocked := _all_blocked(u)
	var path := HexUtils.bfs_path(u["cell"], target, blocked, BW, BH)
	u["cell"] = target
	u["has_moved"] = true
	_clear_highlights()
	_animate(u, path)
	await get_tree().create_timer(0.4).timeout
	_end_turn()


func _animate(u: Dictionary, path: Array[Vector2i]) -> void:
	var node := _find_node(u)
	if node == null or path.size() < 2:
		return
	var an := node.get_node_or_null("Anim")
	if an != null:
		an.play()
	var tw := create_tween()
	for i in range(1, path.size()):
		tw.tween_property(node, "position", _tile_map.map_to_local(path[i]), 0.12)
	if an != null:
		tw.tween_callback(an.stop)


func _do_attack(atk: Dictionary, def: Dictionary) -> void:
	if def.size() == 0:
		return
	var count: int = atk.get("count", 1)
	var bd: int = atk.get("base_damage", 3)
	var def_stat: int = def.get("defense", 0)
	var reduction := clampf(float(def_stat) * 0.03, 0.0, 0.7)
	var dmg := maxi(1, int(float(count * bd) * (1.0 - reduction)))
	if def.get("defending", false):
		dmg = maxi(1, dmg / 2)
	var hp := maxi(1, int(def.get("hp", 10)))
	var kills := maxi(1, dmg / hp)
	def["count"] = maxi(0, int(def.get("count", 0)) - kills)
	atk["has_moved"] = true
	_clear_highlights()

	var dn := _find_node(def)
	if dn != null:
		var cl := dn.get_node_or_null("CountLabel")
		if cl != null:
			cl.text = str(def["count"])
		var tw := create_tween()
		tw.tween_property(dn, "modulate", Color(1, 0.3, 0.3), 0.1)
		tw.tween_property(dn, "modulate", Color.WHITE, 0.2)
	print("[Battle] %s -> %s: урон %d, убито %d" % [atk.get("name", "?"), def.get("name", "?"), dmg, kills])
	if def["count"] <= 0:
		def["alive"] = false
		if dn != null:
			dn.queue_free()
			_sprites.erase(dn)
	_check_end()
	if not battle_over:
		await get_tree().create_timer(0.4).timeout
		_end_turn()


# ==================== AI ====================
func _ai_turn() -> void:
	if battle_over:
		return
	var u := active_unit
	var nearest: Dictionary = {}
	var nd := 999
	for au in attacker_units:
		if au.get("alive", false) and au.get("count", 0) > 0:
			var d := HexUtils.hex_distance(u["cell"], au["cell"])
			if d < nd:
				nd = d
				nearest = au
	if nearest.size() == 0:
		_end_turn()
		return
	if nd == 1:
		_do_attack(u, nearest)
		return
	var blocked := _all_blocked(u)
	var path := HexUtils.bfs_path(u["cell"], nearest["cell"], blocked, BW, BH)
	if path.size() > 1:
		var steps := mini(u.get("speed", 5), path.size() - 1)
		var target: Vector2i = path[steps]
		var victim: Dictionary = {}
		for a in HexUtils.get_all_neighbors(target):
			var au := _unit_at(a, "attacker")
			if au.size() > 0:
				victim = au
				break
		u["cell"] = target
		u["has_moved"] = true
		_animate(u, path.slice(0, steps + 1))
		await get_tree().create_timer(0.4).timeout
		if victim.size() > 0:
			_do_attack(u, victim)
			return
	_end_turn()


# ==================== BUTTONS ====================
func _on_settings() -> void:
	_status.text = "⚙️ Пауза (в прототипе не реализовано)"

func _on_retreat() -> void:
	battle_over = true
	_status.text = "Отступление!"
	battle_finished.emit("defender", _surv(attacker_units), _surv(defender_units))

func _on_wait() -> void:
	if active_unit.size() > 0 and is_player_turn:
		turn_queue.erase(active_unit)
		turn_queue.append(active_unit)
		_end_turn()

func _on_attack_mode() -> void:
	if active_unit.size() == 0 or not is_player_turn:
		return
	_clear_highlights()
	for nb in HexUtils.get_all_neighbors(active_unit["cell"]):
		var en := _unit_at(nb, "defender")
		if en.size() > 0:
			highlight_attack[nb] = 1
	_overlay.atk_cells = highlight_attack
	_overlay.refresh()
	_status.text = "⚔️ Кликните врага с красным контуром."

func _on_collapse() -> void:
	_bottom_bar.visible = not _bottom_bar.visible

func _on_spellbook() -> void:
	_status.text = "📖 Книга заклинаний: в прототипе не реализовано"

func _on_skip() -> void:
	if is_player_turn and active_unit.size() > 0:
		active_unit["has_moved"] = true
		_end_turn()

func _on_defend() -> void:
	if is_player_turn and active_unit.size() > 0:
		active_unit["has_moved"] = true
		active_unit["defending"] = true
		_status.text = "🛡️ Защита: входящий урон вдвое меньше до следующего хода."
		_end_turn()


# ==================== UTILS ====================
func _find_node(u: Dictionary) -> Node2D:
	for n in _sprites:
		if n.get_meta("uid", -1) == u.get("uid", -2):
			return n
	return null


func _check_end() -> void:
	var aa := false
	var da := false
	for u in attacker_units:
		if u.get("alive", false) and u.get("count", 0) > 0:
			aa = true
			break
	for u in defender_units:
		if u.get("alive", false) and u.get("count", 0) > 0:
			da = true
			break
	if not aa:
		battle_over = true
		_status.text = "Поражение!"
		battle_finished.emit("defender", _surv(attacker_units), _surv(defender_units))
	elif not da:
		battle_over = true
		_status.text = "Победа!"
		battle_finished.emit("attacker", _surv(attacker_units), _surv(defender_units))


func _surv(units: Array[Dictionary]) -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	for u in units:
		if u.get("alive", false) and u.get("count", 0) > 0:
			r.append(u)
	return r
