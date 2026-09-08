class_name BattleView
extends Node2D

const RING := GameNumbers.BATTLE_FIELD_RING
const HEX_OUTLINE_RADIUS := GameNumbers.BATTLE_HEX_OUTLINE_RADIUS
const ATTACK_LUNGE_PX := GameNumbers.BATTLE_ATTACK_LUNGE_PX
const MOVE_TWEEN_SEC := GameNumbers.BATTLE_MOVE_TWEEN_SEC
const _HexDraw = preload("res://scripts/core/HexDraw.gd")
const _ObstacleLabel = preload("res://scenes/ui/ObstacleLabel.tscn")
const _FloatingText = preload("res://scenes/ui/FloatingText.tscn")
const _DamageNumber = preload("res://scenes/ui/DamageNumber.tscn")
const _UnitSprite = preload("res://scenes/ui/UnitSprite.tscn")
const _HeroFigure = preload("res://scenes/ui/HeroFigure.tscn")
const _RetaliationArrow = preload("res://scenes/ui/RetaliationArrow.tscn")
const ParticlePresets = preload("res://scripts/core/ParticlePresets.gd")
const CursorOverlay = preload("res://scripts/ui/CursorOverlay.gd")
const HighlightOverlay = preload("res://scripts/ui/HighlightOverlay.gd")

enum CursorMode { DEFAULT, ATTACK, SPELL, RANGED, MOVE }

@onready var _terrain: TileMapLayer = $Terrain
@onready var _overlay: HighlightOverlay = $Highlight
@onready var _cursor: CursorOverlay = $Cursor
@onready var _camera: Camera2D = $Camera
var _tile_map: TileMapLayer = null
var _sprites_by_uid: Dictionary = {}
var _active_tweens: Dictionary = {} # uid -> Tween (FIX: prevent tween overlap & leaks)

# FIX: kill the active tween for a uid before starting a new one for the same unit.
func _kill_unit_tweens(uid: int) -> void:
	if _active_tweens.has(uid):
		var tw = _active_tweens[uid]
		if tw is Tween and tw.is_valid():
			tw.kill()
		_active_tweens.erase(uid)

func setup() -> void:
	_tile_map = _terrain
	_tile_map.name = "BattleTerrain"
	_tile_map.tile_set = TileAtlas.build_hex_tileset()
	RenderingServer.set_default_clear_color(ThemeConfig.C_BATTLE_BG_VIEW)
	HexUtils.calibrate(_tile_map)

	_overlay.tm = _tile_map
	_overlay.z_index = 5

	_camera.make_current()

	_cursor.name = "BattleCursor"
	_cursor.z_index = 30
	_cursor.visible = false


func paint_field() -> void:
	var grass: Vector2i = TileAtlas.BASE_COORDS[TileAtlas.Biome.GRASS][0]
	for y in range(-RING, BattleState.BH + RING):
		for x in range(-RING, BattleState.BW + RING):
			_tile_map.set_cell(Vector2i(x, y), TileAtlas.SOURCE_ID, grass)


func add_obstacle(cell: Vector2i, emoji: String) -> void:
	var lbl: Label = _ObstacleLabel.instantiate()
	lbl.text = emoji
	lbl.position = _tile_map.map_to_local(cell) + Vector2(-14, -16)
	lbl.z_index = 4
	add_child(lbl)


func spawn_hero_figure() -> void:
	var path := UnitSprites.find_portrait("hero_knight")
	if path == "":
		path = UnitSprites.find_portrait("knight")
	if path == "":
		return
	var hero: Sprite2D = _HeroFigure.instantiate()
	hero.texture = load(path)
	hero.scale = Vector2(1.0, 1.0)
	hero.position = _tile_map.map_to_local(Vector2i(1, 1))
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


func create_unit_sprite(unit: BattleState.BattleUnit) -> void:
	var n: Node2D = _UnitSprite.instantiate()
	var key := unit.get_key()
	var ppath := UnitSprites.find_portrait(key)
	var sp: Sprite2D = n.get_node("Figure")
	if ppath != "":
		sp.texture = load(ppath)
	else:
		var col := ThemeConfig.C_SIDE_ATTACKER if unit.side == BattleState.Side.ATTACKER else ThemeConfig.C_SIDE_DEFENDER
		sp.texture = PlaceholderTexture.circle(22, col, Color(0.1, 0.1, 0.1))
	sp.flip_h = (unit.side == BattleState.Side.ATTACKER)

	var display_name := unit.get_display_name()
	var il: Label = n.get_node("Initial")
	il.text = display_name.left(1) if display_name != "" else "?"

	var cl: Label = n.get_node("CountLabel")
	cl.text = str(unit.get_count())

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
	tw.tween_property(node, "modulate", ThemeConfig.C_HIT_FLASH, 0.1)
	tw.tween_property(node, "modulate", Color.WHITE, 0.2)


func remove_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return

	_kill_unit_tweens(unit.uid) # FIX: clean up tweens before freeing node
	_sprites_by_uid.erase(unit.uid)
	ParticlePresets.spawn_burst(self, node.position, Color.RED)

	var tw := create_tween()
	tw.tween_property(node, "modulate", Color.TRANSPARENT, 0.25)
	tw.tween_callback(node.queue_free)


func animate_move(unit: BattleState.BattleUnit, path: Array[Vector2i]) -> Tween:
	var node := _find_node(unit)
	if node == null or path.size() < 2:
		return null
	_kill_unit_tweens(unit.uid) # FIX: kill existing move/attack tweens
	var an := node.get_node_or_null("Anim")
	if an != null:
		an.play()
	var tw := create_tween()
	_active_tweens[unit.uid] = tw
	for i in range(1, path.size()):
		tw.tween_property(node, "position", _tile_map.map_to_local(path[i]), MOVE_TWEEN_SEC)
	if an != null:
		tw.tween_callback(an.stop)
	tw.finished.connect(func(): _active_tweens.erase(unit.uid))
	return tw


func animate_attack(attacker: BattleState.BattleUnit, defender: BattleState.BattleUnit) -> void:
	var attacker_node := _find_node(attacker)
	var defender_node := _find_node(defender)

	if attacker_node == null or defender_node == null:
		return

	_kill_unit_tweens(attacker.uid) # FIX: prevent lunge overlap

	var start_pos: Vector2 = attacker_node.position
	var dir: Vector2 = (defender_node.position - start_pos).normalized() * ATTACK_LUNGE_PX

	var tw := create_tween()
	_active_tweens[attacker.uid] = tw
	tw.tween_property(attacker_node, "position", start_pos + dir, 0.08)
	tw.tween_property(attacker_node, "position", start_pos, 0.12)
	tw.finished.connect(func(): _active_tweens.erase(attacker.uid))


func show_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	var label: Label = _FloatingText.instantiate()
	label.text = text
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

	var label: Label = _DamageNumber.instantiate()
	label.text = "-%d" % damage
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

	var line: Line2D = _RetaliationArrow.instantiate()
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


func set_cursor_mode(mode: int) -> void:
	if _cursor == null:
		return
	_cursor.set_mode(mode)

func set_cursor_visible(visible: bool) -> void:
	if _cursor == null:
		return
	_cursor.visible_flag = visible
	_cursor.visible = visible
	_cursor.queue_redraw()

func clear_cursor() -> void:
	set_cursor_mode(CursorMode.DEFAULT)
	set_cursor_visible(false)

func set_highlights(move_cells: Dictionary, attack_cells: Dictionary) -> void:
	_overlay.move_cells = move_cells
	_overlay.atk_cells = attack_cells
	_overlay.refresh()

func set_unreachable_highlights(cells: Dictionary) -> void:
	_overlay.unreachable_cells = cells.duplicate()
	_overlay.refresh()


func clear_highlights() -> void:
	_overlay.move_cells.clear()
	_overlay.atk_cells.clear()
	_overlay.refresh()


func local_to_map(world_pos: Vector2) -> Vector2i:
	return _tile_map.local_to_map(world_pos)


func global_to_map(global_pos: Vector2) -> Vector2i:
	return _tile_map.local_to_map(_tile_map.to_local(global_pos))


func map_to_local(cell: Vector2i) -> Vector2:
	return _tile_map.map_to_local(cell)


func _find_node(unit: BattleState.BattleUnit) -> Node2D:
	if unit == null:
		return null
	var node: Node2D = _sprites_by_uid.get(unit.uid, null)
	if node != null and not is_instance_valid(node):
		_sprites_by_uid.erase(unit.uid)
		return null
	return node
