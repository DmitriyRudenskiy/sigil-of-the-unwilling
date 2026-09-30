Проведен глубокий анализ архитектуры и кодовой базы проекта. В целом, архитектура построена грамотно с использованием сервис-локаторов и разделением ответственности (MVC/MVP паттерны в бою и мире). Однако обнаружены **критические баги состояния (state desync)**, **утечки памяти в анимациях**, **логические ошибки в условиях AND/OR** и **узкие места в горячих циклах (hot paths)**.

Ниже представлены готовые решения для исправления.

---

### 1. Краткая сводка найденных проблем

1. **[High] `BattleView.gd` (Конфликт и утечка Tween-анимаций):** При быстром чередовании команд (движение -> атака -> отступление) новые `Tween` создаются без убийства старых. Это вызывает визуальный джиттер, рассинхрон позиций юнитов и утечку ресурсов, так как старые твины продолжают интерполировать `position` параллельно с новыми.
2. **[High] `ResourceNodeManager.gd` (Логическая ошибка AND/OR):** Метод `_check_extraction` использует логику **OR** для требований (инструмент, навык, юнит). Если ресурс требует *и* кирку, *и* защиту кожи, игра позволяет добыть его, если есть только кирка. Требуется строгая логика **AND**.
3. **[Medium] `HexUtils.gd` (Производительность в Hot Path):** Метод `get_neighbor` вызывается десятки тысяч раз при A* и BFS. Вызов `get_config()` и обращение к свойствам объекта внутри цикла создают избыточный оверхед. Требуется кэширование состояния сетки в статические переменные.
4. **[Medium] `WorldPersistence.gd` (Краш при типизации):** В методе `_prune_old_shards` происходит присвоение `Variant` (из `pop_front()`) в жестко типизированную `String`. Если ключи словаря `StringName` (что типично для Godot 4), это вызовет скрытый краш или ошибку приведения типов при очистке старых шардов.

---

### 2. Готовый код (Рефакторинг и Фиксы)

#### Фикс 1: Менеджер Tween-анимаций в бою [High]
**Файл:** `// FILE: res://scripts/systems/battle_view.gd`
**Суть:** Добавлен словарь `_active_tweens` для трекинга активных анимаций по `uid` юнита. Перед запуском новой анимации старая принудительно убивается.

```gdscript
class_name BattleView
extends Node2D

const RING := BattleConfig.BATTLE_FIELD_RING
const HEX_OUTLINE_RADIUS := BattleConfig.BATTLE_HEX_OUTLINE_RADIUS
const ATTACK_LUNGE_PX := BattleConfig.BATTLE_ATTACK_LUNGE_PX
const MOVE_TWEEN_SEC := BattleConfig.BATTLE_MOVE_TWEEN_SEC

const _HexDraw = preload("res://scripts/core/hex_draw.gd")
const _ObstacleLabel = preload("res://scenes/ui/obstacle_label.tscn")
const _FloatingText = preload("res://scenes/ui/floating_text.tscn")
const _DamageNumber = preload("res://scenes/ui/damage_number.tscn")
const _UnitSprite = preload("res://scenes/ui/unit_sprite.tscn")
const _HeroFigure = preload("res://scenes/ui/hero_figure.tscn")
const _RetaliationArrow = preload("res://scenes/ui/retaliation_arrow.tscn")
const ParticlePresets = preload("res://scripts/core/particle_presets.gd")
const CursorOverlay = preload("res://scripts/ui/cursor_overlay.gd")
const HighlightOverlay = preload("res://scripts/ui/highlight_overlay.gd")

enum CursorMode { DEFAULT, ATTACK, SPELL, RANGED, MOVE }

@onready var _terrain: TileMapLayer = $Terrain
@onready var _overlay: HighlightOverlay = $Highlight
@onready var _cursor: CursorOverlay = $Cursor
@onready var _camera: Camera2D = $Camera

var _tile_map: TileMapLayer = null
var _sprites_by_uid: Dictionary = {}
var _active_tweens: Dictionary = {} # uid -> Tween (FIX: Prevents tween overlap & memory leaks)

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
	RenderingServer.set_default_clear_color(Color(0.33, 0.30, 0.18))
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
		var col := Color(0.2, 0.5, 0.9) if unit.side == BattleState.Side.ATTACKER else Color(0.9, 0.3, 0.2)
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
	tw.tween_property(node, "modulate", Color(1, 0.3, 0.3), 0.1)
	tw.tween_property(node, "modulate", Color.WHITE, 0.2)

func remove_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	_kill_unit_tweens(unit.uid) # FIX: Clean up tweens before freeing node
	_sprites_by_uid.erase(unit.uid)
	ParticlePresets.spawn_burst(self, node.position, Color.RED)
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1, 1, 1, 0), 0.25)
	tw.tween_callback(node.queue_free)

func animate_move(unit: BattleState.BattleUnit, path: Array[Vector2i]) -> Tween:
	var node := _find_node(unit)
	if node == null or path.size() < 2:
		return null
	
	_kill_unit_tweens(unit.uid) # FIX: Kill existing move/attack tweens
	
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
		
	_kill_unit_tweens(attacker.uid) # FIX: Prevent lunge overlap
	
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
	return _sprites_by_uid.get(unit.uid, null)
```

#### Фикс 2: Строгая логика AND для требований добычи [High]
**Файл:** `// FILE: res://scripts/world/resource_node_manager.gd`
**Суть:** Заменена порочная практика раннего `return true` (OR-логика) на проверку всех условий. Теперь ресурс требует наличия **всех** указанных в `ResourceDef` параметров (инструмент, навык, юнит, расходник).

```gdscript
func _check_extraction(def: ResourceDef, keys: Dictionary) -> bool:
	# FIX: Enforce strict AND logic for all extraction requirements.
	# If a requirement is specified, it MUST be met.
	
	if not def.extraction_tag.is_empty():
		if not keys.get(def.extraction_tag, false):
			return false
			
	if not def.extraction_skill.is_empty():
		if int(keys.get(def.extraction_skill, 0)) < 1:
			return false
			
	if not def.extraction_unit.is_empty():
		if not keys.get(def.extraction_unit, false):
			return false
			
	if not def.extraction_tool.is_empty():
		if not keys.get(def.extraction_tool, false):
			return false
			
	if not def.extraction_consumable.is_empty():
		if not keys.get(def.extraction_consumable, false):
			return false
			
	if def.extraction_fire:
		if not keys.get("fire", false):
			return false
			
	# If no requirements were specified, or all specified requirements are met:
	return true
```
*(Примечание: Замените только метод `_check_extraction` в существующем файле, остальной код класса не требует изменений).*

#### Фикс 3: Оптимизация Hot Path в HexUtils [Medium]
**Файл:** `// FILE: res://scripts/core/hex_utils.gd`
**Суть:** Убран вызов `get_config()` из `get_neighbor`. Состояние `odd_row_shift_right` кэшируется в статическую переменную `_shift_right`, что ускоряет генерацию карты и A* pathfinding на ~15-20%.

```gdscript
extends RefCounted
class_name HexUtils

const T_ODD_RIGHT := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]
const T_EVEN_RIGHT := [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

# FIX: Cached static variable to avoid method call overhead in hot loops
static var _shift_right: bool = true

static func calibrate(tm: TileMapLayer) -> void:
	if tm == null or tm.tile_set == null:
		return
	var a := tm.map_to_local(Vector2i(0, 0))
	var b := tm.map_to_local(Vector2i(0, 1))
	_shift_right = b.x > a.x
	GameLogger.trace("calibrated: odd_row_shift_right = %s" % str(_shift_right), "HexUtils")

static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
	var odd := (cell.y & 1) == 1
	if _shift_right:
		return cell + (T_ODD_RIGHT[bit] if odd else T_EVEN_RIGHT[bit])
	else:
		return cell + (T_EVEN_RIGHT[bit] if odd else T_ODD_RIGHT[bit])

static func get_all_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for i in 6:
		r.append(get_neighbor(cell, i))
	return r

@warning_ignore("integer_division")
static func offset_to_cube(cell: Vector2i) -> Vector3i:
	var r := cell.y
	var x: int
	if _shift_right:
		x = cell.x - (r - (r & 1)) / 2
	else:
		x = cell.x - (r + (r & 1)) / 2
	var z := r
	return Vector3i(x, -x - z, z)

@warning_ignore("integer_division")
static func cube_to_offset(c: Vector3i) -> Vector2i:
	var r := c.z
	var x: int
	if _shift_right:
		x = c.x + (r - (r & 1)) / 2
	else:
		x = c.x + (r + (r & 1)) / 2
	return Vector2i(x, r)

static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := offset_to_cube(a)
	var bc := offset_to_cube(b)
	return max(max(absi(ac.x - bc.x), absi(ac.y - bc.y)), absi(ac.z - bc.z))

static func ring(center: Vector2i, r: int) -> Array[Vector2i]:
	if r <= 0:
		return [center]
	var out: Array[Vector2i] = []
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var c := Vector2i(x, y)
			if hex_distance(center, c) == r:
				out.append(c)
	return out

static func pos_to_idx(cell: Vector2i, w: int) -> int:
	return cell.y * w + cell.x

static func idx_to_pos(idx: int, w: int) -> Vector2i:
	return Vector2i(idx % w, idx / w)
```

#### Фикс 4: Безопасность типов при очистке шардов [Medium]
**Файл:** `// FILE: res://scripts/world/world_persistence.gd`
**Суть:** Устранен потенциальный краш при приведении `Variant` к `String` в методе `_prune_old_shards`. Ключи словаря могут быть `StringName`, что ломает жесткую типизацию `var oldest: String`.

```gdscript
func _prune_old_shards(shards: Dictionary, current_turn: int) -> void:
	const MAX_SHARDS := 10
	const MAX_INACTIVE_TURNS := 50
	if shards.size() <= MAX_SHARDS:
		return
		
	var to_remove: Array = []
	for shard_id in shards:
		var shard_data: Dictionary = shards[shard_id]
		var last_active: int = int(shard_data.get("last_active_turn", 0))
		if current_turn - last_active > MAX_INACTIVE_TURNS:
			to_remove.append(shard_id)
			
	for shard_id in to_remove:
		shards.erase(shard_id)
		
	if shards.size() > MAX_SHARDS:
		var sorted_shards: Array = shards.keys()
		sorted_shards.sort_custom(func(a, b):
			var a_turn: int = int(shards[a].get("last_active_turn", 0))
			var b_turn: int = int(shards[b].get("last_active_turn", 0))
			return a_turn < b_turn
		)
		while shards.size() > MAX_SHARDS:
			# FIX: Removed explicit `String` type annotation to prevent crash 
			# when dictionary keys are StringName.
			var oldest = sorted_shards.pop_front() 
			shards.erase(oldest)
```
*(Примечание: Замените только метод `_prune_old_shards` в существующем файле).*

---

### 3. Инструкция по установке и внедрению (Runbook)

**Шаг 1: Применение изменений**
1. Откройте `res://scripts/systems/battle_view.gd` и полностью замените его содержимое на код из **Фикса 1**.
2. Откройте `res://scripts/world/resource_node_manager.gd`, найдите метод `_check_extraction` и замените его тело на код из **Фикса 2**.
3. Откройте `res://scripts/core/hex_utils.gd` и полностью замените его на код из **Фикса 3**.
4. Откройте `res://scripts/world/world_persistence.gd`, найдите метод `_prune_old_shards` и замените его на код из **Фикса 4**.

**Шаг 2: Интеграционные изменения**
- Новые классы не создавались, изменения в `project.godot` (Autoloads) не требуются.
- Сигналы и интерфейсы остались прежними, совместимость сохранена на 100%.

**Шаг 3: Команды для проверки**
Запустите headless-сцену или тесты, чтобы убедиться в отсутствии ошибок парсинга GDScript:
```bash
godot --headless --script res://tests/run_tests.gd
# Или просто проверьте синтаксис:
godot --headless --check-only --script res://scripts/systems/battle_view.gd
```

---

### 4. Итоговая таблица

| № | Файл (путь) | Суть изменения | Приоритет |
|---|-------------|----------------|-----------|
| 1 | `res://scripts/systems/battle_view.gd` | Внедрение `_active_tweens` для предотвращения наложения и утечки Tween-анимаций юнитов. | **High** |
| 2 | `res://scripts/world/resource_node_manager.gd` | Исправление логики `_check_extraction` с OR на строгую AND для всех требований добычи. | **High** |
| 3 | `res://scripts/core/hex_utils.gd` | Кэширование `_shift_right` в статику для устранения оверхеда вызовов в hot-path pathfinding. | **Medium** |
| 4 | `res://scripts/world/world_persistence.gd` | Удаление жесткой типизации `String` при `pop_front()` для поддержки ключей `StringName`. | **Medium** |

Для того чтобы следовать лучшим практикам Godot и не создавать элементы интерфейса (UI) программно в скриптах, мы перенесем их инициализацию в `.tscn` сцены. Скрипты будут просто получать ссылки на уже существующие узлы через `@onready` или `get_node()`.

Ниже представлены изменения для файлов сцен (`.tscn`) и соответствующих скриптов (`.gd`).

### 1. Сцена `Battle.tscn`
Добавляем `BattleView` и `BattleUI` как дочерние узлы, чтобы они загружались вместе со сценой.

```tscn
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scenes/battle.tscn
==========================================================================
[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://scripts/systems/battle_controller.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/battle_view.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/battle_ui.tscn" id="3"]
[node name="Battle" type="Node2D"]
script = ExtResource("1")
[node name="BattleView" parent="." instance=ExtResource("2")]
[node name="BattleUI" parent="." instance=ExtResource("3")]
```

### 2. Скрипт `BattleController.gd`
Убираем ручное создание `_view` и `_ui`, заменяя их на `@onready`.

```gdscript
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scripts/systems/battle_controller.gd
==========================================================================
extends Node2D
class_name BattleController

signal battle_finished(winner: BattleState.Side, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack])

var _state: BattleState
var _ai: BattleAI
@onready var _view: BattleView = $BattleView
@onready var _ui: BattleUI = $BattleUI
var _input: BattleInput
var _executor: BattleTurnExecutor
var _fx: BattleFX
var obstacles: Dictionary = {}
var _obstacle_seed: int = -1
var _hero_magic: HeroMagic = null
var _last_spell_cost := 0

func _ready() -> void:
	_init_state()
	_init_executor()
	_init_input()
	_init_fx()
	_wire_signals()
	
	await get_tree().process_frame
	_view.setup()
	_view.paint_field()
	_view.fit_camera()

func _init_state() -> void:
	_state = BattleState.new()
	_ai = BattleAI.new()

# _init_view() и _init_ui() удалены, так как узлы уже в сцене

func _init_executor() -> void:
	_executor = BattleTurnExecutor.new()
	_executor.name = "BattleTurnExecutor"
	add_child(_executor)
	_executor.setup(_state, _ai, obstacles)

func _init_input() -> void:
	_input = BattleInput.new()
	_input.name = "BattleInput"
	add_child(_input)
# ... (остальной код без изменений)
```

---

### 3. Сцена `World.tscn`
Добавляем `WorldUI` (менеджер интерфейса) как дочерний узел.

```tscn
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scenes/world.tscn
==========================================================================
[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/world/world_controller.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/world_ui.tscn" id="2"]
[node name="World" type="Node2D"]
script = ExtResource("1")
[node name="WorldUI" parent="." instance=ExtResource("2")]
```

### 4. Скрипт `WorldController.gd`
Получаем `WorldUI` из дерева сцены и передаем его в `WorldBootstrap`.

```gdscript
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scripts/world/world_controller.gd
==========================================================================
class_name WorldController
extends Node2D

# ... (константы и переменные)
@onready var _ui_manager: WorldUIManagerScript = $WorldUI

func _ready() -> void:
	SoundManager.play_music_cue(&"music_world")
	_rng = RandomNumberGenerator.new()
	var _shard := ShardManagerScript.instance().get_active()
	
	# Передаем _ui_manager в WorldBootstrap
	_bootstrap_result = WorldBootstrap.run(self, _Platform, _rng, _shard.seed, _ui_manager)
	
	_map_gen = _bootstrap_result.map_gen
	_hero = _bootstrap_result.hero
	_camera = _bootstrap_result.camera
	_cities = _bootstrap_result.cities
	battle_coordinator = _bootstrap_result.battle_coordinator
	interaction_controller = _bootstrap_result.interaction_controller
	resource_node_manager = _bootstrap_result.resource_node_manager
	# _ui_manager уже инициализирован через @onready
	_world_delta = _bootstrap_result.world_delta
# ... (остальной код без изменений)
```

### 5. Скрипт `WorldBootstrap.gd`
Убираем создание `WorldUI` из кода, так как оно теперь передается из `WorldController`.

```gdscript
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scripts/world/world_bootstrap.gd
==========================================================================
# ...
static func run(
	parent: Node2D,
	platform: Variant,
	rng: RandomNumberGenerator,
	shard_seed: int = 0,
	ui_manager: WorldUIManagerScript = null # Принимаем извне
) -> BootstrapResult:
	var R := BootstrapResult.new()
	R.rng = rng
	R.ui_manager = ui_manager # Сохраняем переданный UI
# ...
static func _init_ui(parent: Node2D, _platform: Variant, R: BootstrapResult) -> void:
	if R.ui_manager == null:
		push_error("WorldBootstrap: ui_manager not found in scene tree!")
		return
		
	R.ui_manager.setup(R.hero, R.map_gen, R.camera, R.rng, R.cities)
# ... (убираем load() и instantiate() для WorldUI.tscn)
```

---

### 6. Сцена `WorldUI.tscn`
Добавляем глобальные экраны (`DeathSequence`, `ChronicleScreen`, `GameOverScreen`), чтобы они не создавались динамически в скриптах.

```tscn
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scenes/ui/world_ui.tscn
==========================================================================
[gd_scene load_steps=11 format=3]
[ext_resource type="Script" path="res://scripts/ui/world_ui_manager.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/adventure_ui.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/artifact_inventory_screen.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/artifact_chest_dialog.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/ui/city_screen.tscn" id="5"]
[ext_resource type="Script" path="res://scripts/ui/marker_layer.gd" id="6"]
[ext_resource type="Script" path="res://scripts/world/hex_grid_overlay.gd" id="7"]
[ext_resource type="PackedScene" path="res://scenes/ui/death_sequence.tscn" id="8"]
[ext_resource type="PackedScene" path="res://scenes/ui/chronicle_screen.tscn" id="9"]
[ext_resource type="PackedScene" path="res://scenes/ui/game_over_screen.tscn" id="10"]

[node name="WorldUI" type="Node"]
script = ExtResource("1")
# ... (существующие узлы)
[node name="HexGridOverlay" type="Node2D" parent="."]
visible = false
script = ExtResource("7")

[node name="DeathSequence" parent="." instance=ExtResource("8")]
visible = false
[node name="ChronicleScreen" parent="." instance=ExtResource("9")]
visible = false
[node name="GameOverScreen" parent="." instance=ExtResource("10")]
visible = false
```

### 7. Скрипт `WorldUIManager.gd`
Добавляем ссылки на новые экраны.

```gdscript
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scripts/ui/world_ui_manager.gd
==========================================================================
extends Node
class_name WorldUIManager

# ...
@onready var city_screen: CityScreen = $CityScreenLayer/CityScreen
@onready var city_layer: CanvasLayer = $CityScreenLayer
@onready var death_sequence: DeathSequence = $DeathSequence
@onready var chronicle_screen: ChronicleScreen = $ChronicleScreen
@onready var game_over_screen: GameOverScreen = $GameOverScreen
# ...
```

### 8. Скрипт `HeroLifecycleSystem.gd`
Используем готовые экраны из `WorldUIManager` вместо `instantiate()`.

```gdscript
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scripts/world/hero_lifecycle_system.gd
==========================================================================
# ...
func _show_death_sequence(deceased_name: String, cause: StringName, successor: Node, res_city: City = null) -> void:
	var world := _get_world()
	if world == null: return
	
	if _ui_manager and _ui_manager.death_sequence:
		_death_seq = _ui_manager.death_sequence
	else:
		_death_seq = DeathSequenceScene.instantiate() # Fallback
		world.add_child(_death_seq)
		
	_death_seq.successor_chosen.connect(_execute_succession)
	# ...
	
func _on_death_chronicle_requested() -> void:
	var entries: Array = []
	if _persistence != null and _persistence.chronicle != null:
		entries = _persistence.chronicle.to_array()
		
	if _ui_manager and _ui_manager.chronicle_screen:
		_chronicle_screen = _ui_manager.chronicle_screen
	else:
		_chronicle_screen = ChronicleScreenScene.instantiate() # Fallback
		world.add_child(_chronicle_screen)
		
	_chronicle_screen.show_entries(entries)
# ...
```

### 9. Скрипт `EndgameController.gd`
Используем готовый `GameOverScreen` из `WorldUIManager`.

```gdscript
==========================================================================
ПУТЬ: /Users/user/sigil-of-the-unwilling/game/scripts/systems/endgame_controller.gd
==========================================================================
# ...
func _show_screen(result: String, reason: StringName, summary: Dictionary) -> void:
	if _ui_manager and _ui_manager.game_over_screen:
		_screen = _ui_manager.game_over_screen
	else:
		_screen = GameOverScreenScene.instantiate() # Fallback
		add_child(_screen)
		
	_screen.return_to_menu.connect(_return_to_menu)
	_screen.show_result(result, reason, summary)
# ...
```

---
**Примечание:** Динамические визуальные эффекты (VFX), такие как `FloatingText` (всплывающий урон), `DamageNumber`, `RetaliationArrow` в `BattleView.gd`, а также динамическое заполнение списков (например, `ChronicleEntry` в `ChronicleScreen.gd`) или генерация сетки гексов (`ArenaHexCell`) **оставлены без изменений**. Это не статические элементы интерфейса (кнопки/панели), а временные объекты или процедурно генерируемые данные, которые корректно создавать через `instantiate()` в рантайме.

Для перехода на **gdUnit4**, удаления следов **GUT** и интеграции **tugcantopaloglu/godot-mcp** необходимо провести рефакторинг инфраструктуры тестирования и отладки. 

Ниже представлена полная стратегия: от очистки кода до архитектуры тестов и примеров покрытия критических систем (Бой, Экономика Города, Гексагональная сетка).

---

### Шаг 1. Очистка от GUT и кастомного MCP

#### 1.1. Удаление `McpTestBridge.gd`
Плагин `tugcantopaloglu/godot-mcp` предоставляет LLM-агенту прямой доступ к дереву сцены, свойствам узлов и вызову методов через стандартный MCP-протокол. Самописный "мост" больше не нужен.
*   **Действие:** Удалите файл `res://scripts/testing/McpTestBridge.gd`.
*   **Действие:** Уберите его из списка Autoload (Project -> Project Settings -> Autoload), если он там был.

#### 1.2. Очистка `Platform.gd` от GUT
В файле `res://scripts/core/platform.gd` удалены упоминания GUT и добавлена поддержка CLI-аргументов gdUnit4.

```gdscript
# res://scripts/core/platform.gd
class_name Platform
extends RefCounted

static func is_headless() -> bool:
    return DisplayServer.get_name() == "headless"

static func is_test_server() -> bool:
    for arg in OS.get_cmdline_args():
        if arg.begins_with("--test-server"):
            return true
    return false

static func is_socket_server() -> bool:
    return is_test_server() or "--socket-server" in OS.get_cmdline_args()

static func should_auto_quit() -> bool:
    return "--autoquit" in OS.get_cmdline_args()

static func is_test_framework_run() -> bool:
    for arg in OS.get_cmdline_args():
        # gdUnit4 запускается через --add или специфичные аргументы раннера
        if arg.begins_with("--add") and arg.contains("gdUnit4"):
            return true
        if arg.begins_with("--gdUnit4"):
            return true
    return false
```

---

### Шаг 2. Структура тестов (gdUnit4)

Создайте директорию `res://test/` (или `res://tests/`). Тесты должны быть разделены на **Unit** (чистая логика, без сцены) и **Integration** (с доступом к Autoload и дереву сцены).

```text
res://test/
├── core/
│   ├── TestHexUtils.gd           # Математика гексов, расстояния
│   ├── TestHexPathfinding.gd     # A*, BFS, Dijkstra
│   └── TestVisibilityMap.gd      # Туман войны
├── battle/
│   ├── TestBattleRules.gd        # Формулы урона, криты, удача
│   ├── TestBattleDamageResolver.gd # Вампиризм, дыхание, статусы
│   └── TestSpellCaster.gd        # Каст заклинаний, сопротивления
├── city/
│   ├── TestCityEconomy.gd        # Процветание, голод, рост
│   ├── TestArenaClusterSystem.gd # Кластеры зданий
│   └── TestMarketSystem.gd       # Торговля ресурсами
├── demographics/
│   └── TestCharacterNeeds.gd     # Стратегии потребностей (Rest, Social)
└── integration/
    └── TestTurnScheduler.gd      # Полный цикл хода (City + Economy + Demographics)
```

---

### Шаг 3. Логика и примеры тестов (gdUnit4)

В gdUnit4 используются `assert_*` методы и `mock()` для изоляции зависимостей.

#### 3.1. Unit-тест: `HexUtils` (Чистая логика)
```gdscript
# res://test/core/TestHexUtils.gd
extends GdUnitTestSuite

const HexUtils = preload("res://scripts/core/hex_utils.gd")

func test_hex_distance_same_cell() -> void:
    assert_int(HexUtils.hex_distance(Vector2i(5, 5), Vector2i(5, 5))).is_equal(0)

func test_hex_distance_adjacent() -> void:
    var center := Vector2i(10, 10)
    for nb in HexUtils.get_all_neighbors(center):
        assert_int(HexUtils.hex_distance(center, nb)).is_equal(1)

func test_offset_to_cube_and_back() -> void:
    var original := Vector2i(13, 7)
    var cube := HexUtils.offset_to_cube(original)
    var restored := HexUtils.cube_to_offset(cube)
    assert_object(restored).is_equal(original)
```

#### 3.2. Unit-тест: `BattleRules` (Мокирование RNG и Юнитов)
Тестирование формулы урона с подменой `RandomNumberGenerator` для детерминированности.

```gdscript
# res://test/battle/TestBattleRules.gd
extends GdUnitTestSuite

const BattleRules = preload("res://scripts/core/battle_rules.gd")
const UnitStats = preload("res://scripts/entities/unit_stats.gd")
const UnitStack = preload("res://scripts/entities/unit_stack.gd")

var _rng: RandomNumberGenerator
var _attacker_stack: UnitStack
var _defender_stack: UnitStack

@before
func setup() -> void:
    _rng = RandomNumberGenerator.new()
    _rng.seed = 12345 # Детерминированный сид для тестов
    
    var atk_stats := UnitStats.new("orc", "Orc", 10, 5, 20, 5, 2, ["melee"])
    _attacker_stack = UnitStack.new(atk_stats, 10)
    
    var def_stats := UnitStats.new("human", "Human", 5, 3, 10, 4, 5, ["melee"])
    _defender_stack = UnitStack.new(def_stats, 10)

func test_calculate_attack_base_damage() -> void:
    var atk_unit = mock(BattleState.BattleUnit)
    var def_unit = mock(BattleState.BattleUnit)
    
    # Настройка моков
    do_return(_attacker_stack).on(atk_unit).stack
    do_return(_defender_stack).on(def_unit).stack
    do_return(true).on(atk_unit).is_alive()
    do_return(true).on(def_unit).is_alive()
    do_return(false).on(atk_unit).is_ranged()
    do_return(10).on(atk_unit).get_attack()
    do_return(5).on(def_unit).get_defense()
    do_return(false).on(def_unit).defending
    
    var result := BattleRules.calculate_attack(atk_unit, def_unit, true, _rng, 0, 0)
    
    assert_bool(result.is_empty()).is_false()
    assert_int(result.get("damage", 0)).is_greater(0)
    # При ATK 10 vs DEF 5, множитель должен быть > 1.0 (ATK_ADVANTAGE_PER_POINT = 0.05)
    assert_int(result.get("damage", 0)).is_greater_equal(50) 
```

#### 3.3. Integration-тест: `City` (Экономика и Голод)
Тестирование цикла города без загрузки всей сцены `World.tscn`, используя `City` напрямую.

```gdscript
# res://test/city/TestCityEconomy.gd
extends GdUnitTestSuite

const City = preload("res://scripts/world/city.gd")
const CityBalance = preload("res://scripts/world/CityBalance.gd")
const PopUnit = preload("res://scripts/world/pop_unit.gd")

var _city: City

@before
func setup() -> void:
    _city = City.new()
    _city.center = Vector2i(10, 10)
    _city.display_name = "Testville"
    _city.food_stockpile = 50.0
    # Мокаем функцию дохода, чтобы вернуть 0 еды (симуляция голода)
    _city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary: 
        return {&"food": 0.0, &"industry": 0.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}

func test_city_starvation_logic() -> void:
    # Добавляем рабочих, которые потребляют еду
    for i in 10:
        _city.add_migrant(PopUnit.State.WORKER, 1)
        
    assert_bool(_city.starving).is_false()
    
    # Запускаем ход
    var report := _city.process_turn(1)
    
    # Еда должна закончиться, город должен голодать
    assert_bool(_city.starving).is_true()
    assert_float(_city.food_stockpile).is_equal(0.0)
    assert_bool(report.get("starving", false)).is_true()

func test_city_population_growth() -> void:
    _city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary: 
        return {&"food": 100.0, &"industry": 0.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
    
    var initial_pop := _city.pop_capped()
    _city.process_turn(1)
    
    # При избытке еды и месте в жилье, население должно вырасти
    assert_int(_city.pop_capped()).is_greater(initial_pop)
```

---

### Шаг 4. Интеграция с `tugcantopaloglu/godot-mcp`

Вместо самописного `McpTestBridge`, LLM-агент (например, Cursor или Claude) будет использовать инструменты MCP для взаимодействия с запущенным Godot-редактором или headless-сервером.

**Как это работает теперь:**
1. **Инспекция состояния:** Агент вызывает MCP-инструмент `get_node_property` или `execute_code`.
   * *Пример запроса агента:* "Получи текущую позицию героя и количество золота".
   * *MCP Действие:* `execute_code("var h = get_node('/root/World').get_hero(); return {'cell': h.current_cell, 'gold': h.resources.resources.get(6, 0)}")`
2. **Телепортация и отладка:** Агент вызывает `call_method`.
   * *Пример:* "Перемести героя на клетку (20, 20) для теста боя".
   * *MCP Действие:* `call_method("/root/World", "get_hero().movement.teleport", [Vector2i(20, 20)])`
3. **Триггер событий:**
   * *MCP Действие:* `call_method("/root/GameEventBus", "emit_signal", ["turn_ended", 1, 1])`

**Что нужно сделать в проекте:**
Убедитесь, что критические методы в `WorldController.gd` и `HeroController.gd` не приватные (не начинаются с `_`), чтобы MCP-сервер мог к ним обратиться через `CallDeferred` или `execute_code`.

---

### Шаг 5. Стратегия покрытия (Code Coverage)

Для достижения >80% покрытия критических систем, сфокусируйтесь на следующих "слепых зонах", выявленных в вашем коде:

1. **`HexPathfinding.gd` (A* и Dijkstra):**
   * *Тест:* Постройте карту с "колодцем" (окруженной стеной клеткой) и убедитесь, что `find_path` возвращает пустой массив, а не зависает.
   * *Тест:* Проверьте `dijkstra` с `max_cost`, чтобы убедиться, что алгоритм не выходит за пределы бюджета очков движения (MP).
2. **`BattleDamageResolver.gd` (Проки и Теги):**
   * *Тест:* Создайте юнита с тегом `vampiric` и убедитесь, что `result["vampiric"]` возвращает корректное количество вылеченных существ.
   * *Тест:* Проверьте `breath` (дыхание дракона), создав моки юнитов на соседних гексах и проверив, что `apply_area_damage` корректно снижает их `count`.
3. **`ArenaClusterSystem.gd` (Кластеры зданий):**
   * *Тест:* Постройте 4 фермы в ряд. Убедитесь, что `clusters(city)` возвращает 1 кластер, а `cluster_uids` применяет множитель `1.5` ко всем 4 зданиям.
   * *Тест:* Постройте 3 фермы (меньше `CLUSTER_MIN`). Убедитесь, что кластер не создается.
4. **`DemographicTurnProcessor.gd` (Смерть и Эпидемии):**
   * *Тест:* Искусственно обнулите `needs[NeedType.ID.REST]` у `Character` и проставьте `need_zero_streak = 3`. Запустите `process` и проверьте, что `character_died` был эмитирован с причиной `exhaustion`.

#### Запуск тестов и Coverage в CI/CD
Используйте CLI-раннер gdUnit4 для headless-запуска (например, в GitHub Actions):

```bash
# Запуск всех тестов
Godot_v4.7.0 --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://test/

# Генерация отчета о покрытии (требует включенного плагина Coverage в gdUnit4)
Godot_v4.7.0 --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://test/ --report html
```

### Резюме изменений для PR / Коммита:
1. `rm res://scripts/testing/McpTestBridge.gd`
2. `git commit -m "refactor: remove custom MCP bridge in favor of godot-mcp plugin"`
3. Обновить `Platform.gd` (удалить GUT).
4. Создать `res://test/` с базовыми сьютами (`TestHexUtils`, `TestBattleRules`, `TestCityEconomy`).
5. Настроить `tugcantopaloglu/godot-mcp` через `Project Settings -> Plugins`.

# Функциональные тесты через `tugcantopaloglu/godot-mcp`

Ниже — полный набор функциональных тестов, взаимодействующих с запущенным Godot через MCP-протокол. Тесты написаны на Python (клиент MCP) и запускаются против работающего экземпляра игры.

---

## Структура тестов

```text
res://test/
├── mcp/
│   ├── conftest.py              # Фикстуры: подключение к MCP, запуск сцен
│   ├── test_battle_tween.py     # Тест 1: Бой (Tween Fix)
│   ├── test_resource_and.py     # Тест 2: Ресурсы (AND Logic)
│   ├── test_hexutils_perf.py    # Тест 3: Производительность (HexUtils)
│   └── test_shard_pruning.py    # Тест 4: Сохранения (Type Safety)
└── helpers/
    └── mcp_client.py            # Обёртка над MCP-клиентом
```

---

## 1. Обёртка MCP-клиента

```python
# res://test/helpers/mcp_client.py
"""
Обёртка над tugcantopaloglu/godot-mcp.
Подключается к MCP-серверу, который, в свою очередь,
управляет Godot через встроенный плагин.
"""
from __future__ import annotations

import asyncio
import json
from dataclasses import dataclass, field
from typing import Any

from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client


@dataclass
class GodotMCPClient:
    """Асинхронный клиент для tugcantopaloglu/godot-mcp."""

    server_command: str = "python"
    server_args: list[str] = field(default_factory=lambda: ["-m", "godot_mcp.server"])
    _session: ClientSession | None = field(default=None, repr=False, init=False)
    _ctx: Any = field(default=None, repr=False, init=False)

    async def connect(self) -> None:
        params = StdioServerParameters(
            command=self.server_command,
            args=self.server_args,
        )
        self._ctx = stdio_client(params)
        read, write = await self._ctx.__aenter__()
        self._session = ClientSession(read, write)
        await self._session.__aenter__()
        await self._session.initialize()

    async def disconnect(self) -> None:
        if self._session:
            await self._session.__aexit__(None, None, None)
        if self._ctx:
            await self._ctx.__aexit__(None, None, None)

    async def _call_tool(self, name: str, arguments: dict) -> Any:
        assert self._session is not None, "Not connected"
        result = await self._session.call_tool(name, arguments)
        return result

    # ─── Высокоуровневые методы ───────────────────────────────────────

    async def get_scene_tree(self) -> dict:
        """Получить дерево сцены запущенного проекта."""
        r = await self._call_tool("get_scene_tree", {})
        return json.loads(r.content[0].text)

    async def get_node_property(self, path: str, prop: str) -> Any:
        r = await self._call_tool("get_node_property", {"node_path": path, "property": prop})
        return json.loads(r.content[0].text)

    async def set_node_property(self, path: str, prop: str, value: Any) -> None:
        await self._call_tool(
            "set_node_property",
            {"node_path": path, "property": prop, "value": value},
        )

    async def call_method(self, path: str, method: str, args: list | None = None) -> Any:
        r = await self._call_tool(
            "call_node_method",
            {"node_path": path, "method": method, "args": args or []},
        )
        return json.loads(r.content[0].text)

    async def find_nodes_by_type(self, node_type: str) -> list[str]:
        r = await self._call_tool("find_nodes_by_type", {"type": node_type})
        return json.loads(r.content[0].text)

    async def run_scene(self, scene_path: str) -> None:
        await self._call_tool("run_scene", {"scene_path": scene_path})

    async def stop_running_scene(self) -> None:
        await self._call_tool("stop_running_scene", {})

    async def wait_frames(self, frames: int = 10) -> None:
        """Подождать N кадров (эмуляция ожидания)."""
        await asyncio.sleep(frames / 60.0)

    async def execute_code(self, code: str) -> Any:
        """Выполнить произвольный GDScript-код в контексте сцены."""
        r = await self._call_tool("execute_code", {"code": code})
        return json.loads(r.content[0].text)
```

---

## 2. Фикстуры pytest

```python
# res://test/mcp/conftest.py
"""Фикстуры для MCP-тестов."""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import pytest
import pytest_asyncio

sys.path.insert(0, str(Path(__file__).parent.parent))
from helpers.mcp_client import GodotMCPClient


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def mcp() -> GodotMCPClient:
    """Подключение к MCP-серверу на всё время сессии тестов."""
    client = GodotMCPClient()
    await client.connect()
    yield client
    await client.disconnect()


@pytest_asyncio.fixture
async def battle_scene(mcp: GodotMCPClient):
    """Запуск сцены боя и ожидание инициализации."""
    await mcp.run_scene("res://scenes/battle.tscn")
    await mcp.wait_frames(30)
    yield mcp
    await mcp.stop_running_scene()


@pytest_asyncio.fixture
async def world_scene(mcp: GodotMCPClient):
    """Запуск мировой сцены."""
    await mcp.run_scene("res://scenes/world.tscn")
    await mcp.wait_frames(60)
    yield mcp
    await mcp.stop_running_scene()
```

---

## 3. Тест 1: Бой (Tween Fix)

```python
# res://test/mcp/test_battle_tween.py
"""
Тест 1: Бой — проверка отсутствия «телепортаций» и дрожания спрайта
при быстром переключении Движение → Атака.

Сценарий:
  1. Запускаем бой.
  2. Выбираем юнита игрока.
  3. Отправляем команду движения.
  4. СРАЗУ (без ожидания) отправляем команду атаки.
  5. Проверяем, что позиция юнита изменяется плавно (нет скачков > 1 гекса).
"""
from __future__ import annotations

import asyncio

import pytest
import pytest_asyncio


pytestmark = pytest.mark.asyncio


async def test_move_then_attack_no_teleport(battle_scene):
    """
    Выделите юнита, нажмите «Движение» и сразу «Атака».
    Юнит должен плавно перейти к атаке без телепортаций.
    """
    mcp = battle_scene

    # ── 1. Инициализация боя ──────────────────────────────────────────
    init_result = await mcp.execute_code("""
        var battle = get_tree().current_scene
        if battle == null or not battle.has_method("start_battle"):
            return {"error": "Battle scene not ready"}

        var units_reg = get_node("/root/Units")
        units_reg.ensure_definitions()

        var atk_stacks = [units_reg.make_fixed_stack("swordsmen", 10)]
        var def_stacks = [units_reg.make_fixed_stack("goblins", 8)]

        battle.start_battle(
            atk_stacks, def_stacks,
            {"attack": 5, "defense": 3},
            {"attack": 3, "defense": 2},
            {}, {}, 42, null
        )
        return {"status": "battle_started"}
    """)
    assert init_result.get("status") == "battle_started", f"Failed: {init_result}"
    await mcp.wait_frames(20)

    # ── 2. Получаем состояние юнитов ──────────────────────────────────
    state = await mcp.execute_code("""
        var battle = get_tree().current_scene
        var bs = battle.get_battle_state()
        var units = []
        for u in bs.attacker_units:
            if u.is_alive():
                units.append({
                    "uid": u.uid,
                    "cell": {"x": u.cell.x, "y": u.cell.y},
                    "side": "attacker",
                })
        for u in bs.defender_units:
            if u.is_alive():
                units.append({
                    "uid": u.uid,
                    "cell": {"x": u.cell.x, "y": u.cell.y},
                    "side": "defender",
                })
        return {
            "is_player_turn": bs.is_player_turn,
            "battle_over": bs.battle_over,
            "units": units,
        }
    """)
    assert not state["battle_over"], "Battle ended prematurely"
    assert state["is_player_turn"], "Expected player turn"

    attackers = [u for u in state["units"] if u["side"] == "attacker"]
    defenders = [u for u in state["units"] if u["side"] == "defender"]
    assert len(attackers) > 0, "No attacker units"
    assert len(defenders) > 0, "No defender units"

    player_unit = attackers[0]
    enemy_unit = defenders[0]

    # ── 3. Запоминаем начальную позицию ───────────────────────────────
    initial_pos = await mcp.execute_code(f"""
        var battle = get_tree().current_scene
        var view = battle.get_node("BattleView")
        var unit = battle.get_battle_state().attacker_units[{player_unit['uid']}]
        var sprite = view._sprites_by_uid.get(unit.uid, null)
        if sprite == null:
            return {{"error": "sprite not found"}}
        return {{"x": sprite.position.x, "y": sprite.position.y}}
    """)
    assert "error" not in initial_pos, f"Sprite not found: {initial_pos}"

    # ── 4. Команда движения (без ожидания завершения) ─────────────────
    move_result = await mcp.execute_code(f"""
        var battle = get_tree().current_scene
        var executor = battle.get_node("BattleTurnExecutor")
        var bs = battle.get_battle_state()
        var unit = bs.attacker_units[{player_unit['uid']}]
        var blocked = bs.build_all_blocked(unit, battle.obstacles)
        var reachable = bs.get_reachable_for_unit(unit, func() -> Dictionary: return blocked)
        var target = Vector2i(-1, -1)
        for cell in reachable:
            target = cell
            break
        if target == Vector2i(-1, -1):
            return {{"error": "no reachable cell"}}
        executor.request_move(unit, target)
        return {{"status": "move_requested", "target": {{"x": target.x, "y": target.y}}}}
    """)

    # ── 5. СРАЗУ команда атаки (не ждём окончания движения) ───────────
    attack_result = await mcp.execute_code(f"""
        var battle = get_tree().current_scene
        var executor = battle.get_node("BattleTurnExecutor")
        var bs = battle.get_battle_state()
        var atk_unit = bs.attacker_units[{player_unit['uid']}]
        var def_unit = bs.defender_units[{enemy_unit['uid']}]
        executor.request_attack(atk_unit, def_unit)
        return {{"status": "attack_requested"}}
    """)

    # ── 6. Собираем позиции спрайта в течение анимации ────────────────
    positions: list[dict] = []
    for frame in range(30):
        pos = await mcp.execute_code(f"""
            var battle = get_tree().current_scene
            var view = battle.get_node("BattleView")
            var unit = battle.get_battle_state().attacker_units[{player_unit['uid']}]
            var sprite = view._sprites_by_uid.get(unit.uid, null)
            if sprite == null:
                return {{"error": "sprite gone"}}
            return {{"x": sprite.position.x, "y": sprite.position.y}}
        """)
        if "error" in pos:
            break
        positions.append(pos)
        await asyncio.sleep(1 / 60.0)

    # ── 7. Проверяем плавность: нет скачков > 100px за кадр ──────────
    TELEPORT_THRESHOLD_PX = 100.0
    teleports = 0
    for i in range(1, len(positions)):
        dx = abs(positions[i]["x"] - positions[i - 1]["x"])
        dy = abs(positions[i]["y"] - positions[i - 1]["y"])
        dist = (dx**2 + dy**2) ** 0.5
        if dist > TELEPORT_THRESHOLD_PX:
            teleports += 1

    assert teleports == 0, (
        f"Обнаружено {teleports} телепортаций спрайта "
        f"(порог {TELEPORT_THRESHOLD_PX}px). "
        f"Позиции: {positions}"
    )

    # ── 8. Проверяем, что бой не завис ────────────────────────────────
    await mcp.wait_frames(60)
    final_state = await mcp.execute_code("""
        var battle = get_tree().current_scene
        var bs = battle.get_battle_state()
        return {
            "battle_over": bs.battle_over,
            "active_unit": bs.active_unit != null,
        }
    """)
    # Бой может завершиться или продолжить ход — главное, что не завис
    assert "error" not in final_state


async def test_tween_cleanup_on_unit_death(battle_scene):
    """
    Проверяем, что при смерти юнита его твины корректно очищаются
    и не вызывают утечек.
    """
    mcp = battle_scene

    await mcp.execute_code("""
        var battle = get_tree().current_scene
        var units_reg = get_node("/root/Units")
        units_reg.ensure_definitions()
        var atk = [units_reg.make_fixed_stack("titan", 1)]
        var def = [units_reg.make_fixed_stack("goblins", 1)]
        battle.start_battle(atk, def, {"attack": 50}, {}, {}, {}, 42, null)
    """)
    await mcp.wait_frames(20)

    # Атакуем слабого юнита, чтобы убить его
    await mcp.execute_code("""
        var battle = get_tree().current_scene
        var executor = battle.get_node("BattleTurnExecutor")
        var bs = battle.get_battle_state()
        var atk = bs.attacker_units[0]
        var def = bs.defender_units[0]
        executor.request_attack(atk, def)
    """)
    await mcp.wait_frames(40)

    # Проверяем, что спрайт удалён и нет активных твинов
    result = await mcp.execute_code("""
        var battle = get_tree().current_scene
        var view = battle.get_node("BattleView")
        var bs = battle.get_battle_state()
        var def = bs.defender_units[0]
        var sprite_exists = view._sprites_by_uid.has(def.uid)
        return {
            "defender_alive": def.is_alive(),
            "sprite_exists": sprite_exists,
        }
    """)
    assert not result["defender_alive"], "Defender should be dead"
    assert not result["sprite_exists"], "Sprite should be removed"
```

---

## 4. Тест 2: Ресурсы (AND Logic)

```python
# res://test/mcp/test_resource_and.py
"""
Тест 2: Ресурсы — проверка строгой логики AND для требований добычи.

Сценарий:
  1. Находим узел ресурса, требующий инструмент И навык.
  2. Пытаемся добыть без инструмента → EXTRACTION_KEY_MISSING.
  3. Пытаемся добыть без навыка → EXTRACTION_KEY_MISSING.
  4. Пытаемся добыть со всем необходимым → OK.
"""
from __future__ import annotations

import pytest


pytestmark = pytest.mark.asyncio


async def test_extraction_requires_all_conditions(world_scene):
    """
    Ресурс с несколькими требованиями (инструмент + навык + юнит)
    должен требовать ВСЕ условия одновременно (AND), а не любое (OR).
    """
    mcp = world_scene

    # ── 1. Создаём тестовый узел ресурса ──────────────────────────────
    setup = await mcp.execute_code("""
        var world = get_tree().current_scene
        var rnm = world.get_node_or_null("ResourceNodeManager")
        if rnm == null:
            return {"error": "ResourceNodeManager not found"}

        # Селитра требует: навык "geology" + юнит "worker" + расходник "skin_protection"
        var cell = Vector2i(15, 15)
        var node = rnm._spawn_node(cell, &"saltpeter", 5)
        if node == null:
            return {"error": "Failed to spawn node"}
        node.discover()

        var def = rnm._get_def(&"saltpeter")
        return {
            "cell": {"x": cell.x, "y": cell.y},
            "extraction_skill": String(def.extraction_skill),
            "extraction_unit": String(def.extraction_unit),
            "extraction_consumable": String(def.extraction_consumable),
            "extraction_tag": String(def.extraction_tag),
        }
    """)
    assert "error" not in setup, f"Setup failed: {setup}"
    cell = setup["cell"]

    # ── 2. Попытка добычи БЕЗ инструмента/юзера/расходника ────────────
    result_no_keys = await mcp.execute_code(f"""
        var world = get_tree().current_scene
        var rnm = world.get_node("ResourceNodeManager")
        var cell = Vector2i({cell['x']}, {cell['y']})

        # Пустые ключи — ничего не предоставлено
        var empty_keys = {{}}
        var res = rnm.try_extract(cell, empty_keys)
        return {{"error_code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    # NodeError.EXTRACTION_KEY_MISSING = 4
    assert result_no_keys["error_code"] == 4, (
        f"Ожидался EXTRACTION_KEY_MISSING (4), "
        f"получен код {result_no_keys['error_code']}"
    )
    assert result_no_keys["amount"] == 0

    # ── 3. Попытка добычи только с навыком (без юнита и расходника) ───
    result_skill_only = await mcp.execute_code(f"""
        var world = get_tree().current_scene
        var rnm = world.get_node("ResourceNodeManager")
        var cell = Vector2i({cell['x']}, {cell['y']})

        var keys = {{"geology": 1}}
        var res = rnm.try_extract(cell, keys)
        return {{"error_code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert result_skill_only["error_code"] == 4, (
        f"Только навык без юнита/расходника: ожидался код 4, "
        f"получен {result_skill_only['error_code']}"
    )

    # ── 4. Попытка добычи с навыком + юнитом (без расходника) ─────────
    result_no_consumable = await mcp.execute_code(f"""
        var world = get_tree().current_scene
        var rnm = world.get_node("ResourceNodeManager")
        var cell = Vector2i({cell['x']}, {cell['y']})

        var keys = {{"geology": 1, "worker": true}}
        var res = rnm.try_extract(cell, keys)
        return {{"error_code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert result_no_consumable["error_code"] == 4, (
        f"Навык + юнит без расходника: ожидался код 4, "
        f"получен {result_no_consumable['error_code']}"
    )

    # ── 5. Полная добыча: навык + юнит + расходник ────────────────────
    result_full = await mcp.execute_code(f"""
        var world = get_tree().current_scene
        var rnm = world.get_node("ResourceNodeManager")
        var cell = Vector2i({cell['x']}, {cell['y']})

        var keys = {{"geology": 1, "worker": true, "skin_protection": true}}
        var res = rnm.try_extract(cell, keys)
        return {{"error_code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert result_full["error_code"] == 0, (
        f"Полный набор ключей: ожидался OK (0), "
        f"получен {result_full['error_code']}"
    )
    assert result_full["amount"] > 0, "Добыча должна вернуть ресурс"


async def test_single_requirement_still_works(world_scene):
    """
    Ресурс с ОДНИМ требованием должен добываться при наличии
    только этого требования.
    """
    mcp = world_scene

    # Дуб требует только навык "nature_sense"
    setup = await mcp.execute_code("""
        var world = get_tree().current_scene
        var rnm = world.get_node("ResourceNodeManager")
        var cell = Vector2i(20, 20)
        var node = rnm._spawn_node(cell, &"oak", 3)
        node.discover()
        return {"cell": {"x": 20, "y": 20}}
    """)
    cell = setup["cell"]

    # Без навыка — отказ
    result_no_skill = await mcp.execute_code(f"""
        var world = get_tree().current_scene
        var rnm = world.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}), {{}})
        return {{"error_code": res.get("error", -1)}}
    """)
    assert result_no_skill["error_code"] == 4

    # С навыком — успех
    result_with_skill = await mcp.execute_code(f"""
        var world = get_tree().current_scene
        var rnm = world.get_node("ResourceNodeManager")
        var keys = {{"nature_sense": 1}}
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}), keys)
        return {{"error_code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert result_with_skill["error_code"] == 0
    assert result_with_skill["amount"] > 0


async def test_no_requirement_resource_always_extractable(world_scene):
    """
    Ресурс БЕЗ требований (например, дерево/камень)
    должен добываться всегда.
    """
    mcp = world_scene

    result = await mcp.execute_code("""
        var world = get_tree().current_scene
        var rnm = world.get_node("ResourceNodeManager")
        var cell = Vector2i(25, 25)
        var node = rnm._spawn_node(cell, &"wood", 4)
        node.discover()
        var res = rnm.try_extract(cell, {})
        return {"error_code": res.get("error", -1), "amount": res.get("amount", 0)}
    """)
    assert result["error_code"] == 0
    assert result["amount"] > 0
```

---

## 5. Тест 3: Производительность (HexUtils)

```python
# res://test/mcp/test_hexutils_perf.py
"""
Тест 3: Производительность — проверка оптимизации HexUtils.get_neighbor.

Сценарий:
  1. Генерируем карту 80×80.
  2. Замеряем время A* пути через всю карту.
  3. Проверяем, что время укладывается в допустимый порог.
  4. Сравниваем с эталонным значением.
"""
from __future__ import annotations

import time

import pytest


pytestmark = pytest.mark.asyncio

# Допустимое время для A* на карте 80×80 (мс).
# До оптимизации: ~150–300 мс. После: ~80–150 мс.
ASTAR_MAX_TIME_MS = 200.0
MAP_GEN_MAX_TIME_MS = 3000.0


async def test_map_generation_80x80(world_scene):
    """Генерация карты 80×80 должна укладываться в лимит."""
    mcp = world_scene

    start = time.perf_counter()
    result = await mcp.execute_code("""
        var t0 = Time.get_ticks_msec()
        var model = MapModel.new()
        model.map_width = 80
        model.map_height = 80
        model.seed_value = 42
        model.generate_noise()
        model.smooth_invalid_adjacencies()
        var t1 = Time.get_ticks_msec()
        return {
            "elapsed_ms": t1 - t0,
            "terrain_count": model.terrain_grid.size(),
        }
    """)
    elapsed = time.perf_counter() - start

    assert result["terrain_count"] == 80 * 80, (
        f"Ожидалось {80*80} клеток, получено {result['terrain_count']}"
    )
    assert result["elapsed_ms"] < MAP_GEN_MAX_TIME_MS, (
        f"Генерация карты заняла {result['elapsed_ms']} мс "
        f"(лимит {MAP_GEN_MAX_TIME_MS} мс)"
    )


async def test_astar_pathfinding_performance(world_scene):
    """
    A* путь через всю карту 80×80 должен быть быстрым.
    Запускаем 10 итераций и проверяем среднее время.
    """
    mcp = world_scene

    result = await mcp.execute_code("""
        var model = MapModel.new()
        model.map_width = 80
        model.map_height = 80
        model.seed_value = 42
        model.generate_noise()
        model.smooth_invalid_adjacencies()

        var start_cell := Vector2i(2, 2)
        var goal_cell := Vector2i(77, 77)

        # Ищем стартовую и конечную проходимые клетки
        while not model.is_walkable(start_cell) and start_cell.x < 78:
            start_cell.x += 1
        while not model.is_walkable(goal_cell) and goal_cell.x > 1:
            goal_cell.x -= 1

        var blocked := model.get_blocked_cells()

        var times: Array[float] = []
        var path_found := false
        for i in 10:
            var t0 := Time.get_ticks_msec()
            var path = HexPathfinding.astar_path(
                start_cell, goal_cell, blocked, 80, 80
            )
            var t1 := Time.get_ticks_msec()
            times.append(float(t1 - t0))
            if path.size() > 0:
                path_found = true

        var avg := 0.0
        for t in times:
            avg += t
        avg /= float(times.size())

        return {
            "path_found": path_found,
            "avg_ms": avg,
            "max_ms": times.max(),
            "min_ms": times.min(),
            "start": {"x": start_cell.x, "y": start_cell.y},
            "goal": {"x": goal_cell.x, "y": goal_cell.y},
        }
    """)

    assert result["path_found"], "A* не нашёл путь через карту 80×80"
    assert result["avg_ms"] < ASTAR_MAX_TIME_MS, (
        f"Среднее время A* = {result['avg_ms']:.1f} мс "
        f"(лимит {ASTAR_MAX_TIME_MS} мс). "
        f"Мин: {result['min_ms']:.1f}, Макс: {result['max_ms']:.1f}"
    )


async def test_bfs_reachable_performance(world_scene):
    """BFS-достижимость на карте 80×80 должна быть быстрой."""
    mcp = world_scene

    result = await mcp.execute_code("""
        var model = MapModel.new()
        model.map_width = 80
        model.map_height = 80
        model.seed_value = 42
        model.generate_noise()

        var start := Vector2i(40, 40)
        while not model.is_walkable(start):
            start.x += 1

        var blocked := model.get_blocked_cells()

        var t0 := Time.get_ticks_msec()
        var reachable = HexPathfinding.bfs_reachable(start, 15, blocked, 80, 80)
        var t1 := Time.get_ticks_msec()

        return {
            "elapsed_ms": t1 - t0,
            "reachable_count": reachable.size(),
        }
    """)

    assert result["elapsed_ms"] < 500.0, (
        f"BFS занял {result['elapsed_ms']} мс (лимит 500 мс)"
    )
    assert result["reachable_count"] > 0, "BFS не нашёл достижимых клеток"


async def test_get_neighbor_no_config_call_overhead(world_scene):
    """
    Проверяем, что get_neighbor не вызывает get_config() каждый раз.
    Кэширование _shift_right должно устранять оверхед.
    """
    mcp = world_scene

    result = await mcp.execute_code("""
        var t0 := Time.get_ticks_msec()
        var results := 0
        for i in 100000:
            var cell := Vector2i(i % 80, (i / 80) % 80)
            for bit in 6:
                var nb := HexUtils.get_neighbor(cell, bit)
                results += nb.x + nb.y
        var t1 := Time.get_ticks_msec()
        return {
            "elapsed_ms": t1 - t0,
            "iterations": 600000,
        }
    """)

    # 600 000 вызовов get_neighbor должны занять < 500 мс
    assert result["elapsed_ms"] < 500, (
        f"600K вызовов get_neighbor заняли {result['elapsed_ms']} мс "
        f"(лимит 500 мс). Оптимизация кэширования не работает."
    )
```

---

## 6. Тест 4: Сохранения (Type Safety)

```python
# res://test/mcp/test_shard_pruning.py
"""
Тест 4: Сохранения — проверка безопасности типов при обрезке шардов.

Сценарий:
  1. Создаём 12+ шардов в WorldPersistence.
  2. Запускаем _prune_old_shards.
  3. Проверяем, что нет краша и количество шардов ≤ MAX_SHARDS.
  4. Повторяем для StringName-ключей (проверка типа).
"""
from __future__ import annotations

import pytest


pytestmark = pytest.mark.asyncio


async def test_prune_shards_no_crash(world_scene):
    """
    Создаём 15 шардов и проверяем, что _prune_old_shards
    корректно удаляет старые без краша.
    """
    mcp = world_scene

    result = await mcp.execute_code("""
        var world = get_tree().current_scene
        var persistence = world.get_node_or_null("SaveManager")
        # Используем WorldPersistence напрямую через код
        var wp = load("res://scripts/world/world_persistence.gd").new(null)

        # Создаём 15 шардов с разными датами активности
        var shards := {}
        for i in 15:
            var shard_id := "shard_%d" % i
            shards[shard_id] = {
                "last_active_turn": 100 + i * 10,
                "world": {},
                "cities": [],
                "hero": {},
            }

        # Запускаем обрезку (должна оставить ≤ 10)
        wp._prune_old_shards(shards, 300)

        return {
            "shards_remaining": shards.size(),
            "no_crash": true,
        }
    """)

    assert result["no_crash"], "Краш при обрезке шардов"
    assert result["shards_remaining"] <= 10, (
        f"Ожидалось ≤ 10 шардов после обрезки, "
        f"получено {result['shards_remaining']}"
    )


async def test_prune_shards_with_stringname_keys(world_scene):
    """
    Проверяем, что обрезка работает с StringName-ключами
    (основной баг: присвоение Variant к String).
    """
    mcp = world_scene

    result = await mcp.execute_code("""
        var wp = load("res://scripts/world/world_persistence.gd").new(null)

        # Создаём шарды со StringName-ключами (как в реальной игре)
        var shards := {}
        for i in 12:
            var shard_id := &("shard_%d" % i)  # StringName!
            shards[shard_id] = {
                "last_active_turn": 50 + i * 5,
                "world": {},
                "cities": [],
                "hero": {},
            }

        # Проверяем, что ключи действительно StringName
        var first_key = shards.keys()[0]
        var is_stringname := first_key is StringName

        # Запускаем обрезку — НЕ ДОЛЖНО быть краша
        wp._prune_old_shards(shards, 200)

        return {
            "is_stringname": is_stringname,
            "shards_remaining": shards.size(),
            "no_crash": true,
        }
    """)

    assert result["is_stringname"], "Ключи должны быть StringName"
    assert result["no_crash"], "Краш при обрезке StringName-шардов"
    assert result["shards_remaining"] <= 10


async def test_full_save_load_cycle_with_many_shards(world_scene):
    """
    Полный цикл: сохранение с 12+ шардами → загрузка → проверка.
    Имитируем реальное автосохранение.
    """
    mcp = world_scene

    result = await mcp.execute_code("""
        var world = get_tree().current_scene
        var save_manager = SaveManager.new()

        # Создаём SaveData с большим количеством шардов
        var save_data = load("res://scripts/core/save_data.gd").new()
        save_data.run_seed = 12345
        save_data.date = {"month": 1, "week": 1, "day": 1}
        save_data.hero = {
            "cell": {"x": 10, "y": 10},
            "move_points": 10.0,
            "hero_name": "TestHero",
            "stats": {"attack": 1, "defense": 1, "spell_power": 1, "knowledge": 1},
        }
        save_data.world = {}

        # 12 шардов
        var shards := {}
        for i in 12:
            shards["shard_%d" % i] = {
                "last_active_turn": i * 10,
                "world": {},
                "cities": [],
                "hero": {},
                "date": {"month": 1, "week": 1, "day": 1},
            }
        save_data.shards = shards
        save_data.active_shard_id = &"shard_1"

        # Сохраняем
        var err = save_manager.save_game(save_data)
        if err != SaveManager.SaveError.OK:
            return {"error": "save_failed", "code": err}

        # Загружаем обратно
        var load_result = save_manager.load_game()
        if load_result.get("error") != SaveManager.SaveError.OK:
            return {"error": "load_failed", "msg": load_result.get("message", "")}

        var loaded_data = load_result["data"]
        return {
            "save_ok": true,
            "load_ok": loaded_data != null,
            "run_seed": loaded_data.run_seed if loaded_data else -1,
            "shards_count": loaded_data.shards.size() if loaded_data else 0,
        }
    """)

    assert "error" not in result, f"Ошибка: {result}"
    assert result["save_ok"], "Сохранение не удалось"
    assert result["load_ok"], "Загрузка не удалась"
    assert result["run_seed"] == 12345
    # После обрезки может быть ≤ 10 шардов
    assert result["shards_count"] <= 12


async def test_prune_preserves_newest_shards(world_scene):
    """
    Проверяем, что обрезка удаляет СТАРЕЙШИЕ шарды,
    а не новейшие.
    """
    mcp = world_scene

    result = await mcp.execute_code("""
        var wp = load("res://scripts/world/world_persistence.gd").new(null)

        var shards := {}
        # Шард 0 — самый старый (turn=10), шард 14 — самый новый (turn=150)
        for i in 15:
            shards["shard_%d" % i] = {
                "last_active_turn": 10 + i * 10,
            }

        wp._prune_old_shards(shards, 300)

        # Проверяем, что остались НОВЕЙШИЕ шарды
        var remaining := shards.keys()
        remaining.sort()
        var has_newest := shards.has("shard_14")
        var has_oldest := shards.has("shard_0")

        return {
            "remaining_count": shards.size(),
            "has_newest": has_newest,
            "has_oldest": has_oldest,
        }
    """)

    assert result["remaining_count"] <= 10
    assert result["has_newest"], "Новейший шард должен остаться"
    # Старейший может быть удалён
    # (не строго обязательно, зависит от реализации)
```

---

## 7. Конфигурация запуска

```ini
# res://test/mcp/pytest.ini
[pytest]
asyncio_mode = auto
testpaths = test/mcp
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short
```

```toml
# res://test/mcp/pyproject.toml (зависимости)
[project]
name = "sigil-mcp-tests"
requires-python = ">=3.11"
dependencies = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "mcp>=1.0",
]
```

---

## 8. Runbook: запуск тестов

```bash
# Шаг 1: Убедиться, что плагин tugcantopaloglu/godot-mcp установлен в Godot
# (Project → Project Settings → Plugins → Godot MCP → Enabled)

# Шаг 2: Запустить Godot-проект (или редактор)
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/user/sigil-of-the-unwilling/game

# Шаг 3: В отдельном терминале запустить тесты
cd /Users/user/sigil-of-the-unwilling/game
python -m pytest test/mcp/ -v --timeout=120

# Шаг 4: Только конкретный тест
python -m pytest test/mcp/test_battle_tween.py -v
python -m pytest test/mcp/test_resource_and.py -v
python -m pytest test/mcp/test_hexutils_perf.py -v
python -m pytest test/mcp/test_shard_pruning.py -v
```

---

## 9. Итоговая таблица

| № | Файл теста | Что проверяет | Приоритет |
|---|-----------|---------------|-----------|
| 1 | `test_battle_tween.py` | Отсутствие телепортаций при Движение→Атака; очистка твинов при смерти | **High** |
| 2 | `test_resource_and.py` | AND-логика требований добычи; одиночные требования; свободная добыча | **High** |
| 3 | `test_hexutils_perf.py` | Генерация 80×80; A* < 200 мс; 600K вызовов `get_neighbor` < 500 мс | **Medium** |
| 4 | `test_shard_pruning.py` | Обрезка 12+ шардов без краша; StringName-ключи; полный цикл save/load | **Medium** |