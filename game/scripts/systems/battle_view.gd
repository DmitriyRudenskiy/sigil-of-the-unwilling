class_name BattleView
extends Node2D

const RING := GameNumbers.BATTLE_FIELD_RING
const HEX_OUTLINE_RADIUS := GameNumbers.BATTLE_HEX_OUTLINE_RADIUS
const ATTACK_LUNGE_PX := GameNumbers.BATTLE_ATTACK_LUNGE_PX
const MOVE_TWEEN_SEC := GameNumbers.BATTLE_MOVE_TWEEN_SEC

## Амплитуда процедурных поз выреза (3.9): подпрыгивание в пути и отдача от удара.
const STILL_BOB_PX := 5.0
const STILL_RECOIL_PX := 6.0

## Порядок отрисовки фигур по ряду (3.8): ближний к нижнему краю перекрывает
## дальнего, и перекрывающиеся силуэты читаются глубиной, а не кашей. База 6 —
## над подсветкой поля (`_overlay` = 5), ниже подписей урона (20) и курсора (30).
const UNIT_Z_BASE := 6
const _HexDraw = preload("res://scripts/core/hex_draw.gd")
const _ObstacleLabel = preload("res://scenes/ui/obstacle_label.tscn")
const _FloatingText = preload("res://scenes/ui/floating_text.tscn")
const _DamageNumber = preload("res://scenes/ui/damage_number.tscn")
const _UnitSprite = preload("res://scenes/ui/unit_sprite.tscn")
const _HeroFigure = preload("res://scenes/ui/hero_figure.tscn")
const _RetaliationArrow = preload("res://scenes/ui/retaliation_arrow.tscn")

## Ключ мировой местности выбирает и носитель, и режим поля (T-269 → (б),
## `alpha-battle-field`). Выбор делает сам носитель, а не флаг.
##
## `FIELD_ART` — кадр, который СТАНОВИТСЯ ПОЛЕМ: у него нет собственной
## гекс-сетки, поэтому он вписывается в многоугольник доски, а тайлы гаснут
## (`uses_art_field`). Претензия T-269 «у арта своя сетка, она расходится с
## нашей» снята самим носителем: луг владельца сетки не имеет.
##
## `BACKDROP_ART` — пейзаж ЗА краями поля: у него своя нарисованная сетка и
## декор внутри кадра, поэтому полем правит плитка. Местность без утверждённого
## кадра идёт тем же путём автоматически — пустой путь = clear color + тайлы.
const FIELD_ART := {
	"grass": "res://assets/ui/backgrounds/battle_meadow.png",
}
const BACKDROP_ART := {
	"snow": "res://assets/ui/backgrounds/battle_snow.png",
	"swamp": "res://assets/ui/backgrounds/battle_swamp.png",
}
const BIOMES := {
	"snow": TileAtlas.Biome.SNOW,
	"swamp": TileAtlas.Biome.SWAMP,
}

## Наклон плоскости поля: 1.0 — соты лежат плашмя (вид до alpha-battle-field),
## меньше — поле читается скошенной плоскостью. Это только рисунок: правила боя
## (соседство, дистанция, путь) считаются на локальной сетке тайлмапа.
const TILT := GameNumbers.BATTLE_FIELD_TILT

enum CursorMode { DEFAULT, ATTACK, SPELL, RANGED, MOVE }

@onready var _background: Sprite2D = $Background
@onready var _terrain: TileMapLayer = $Terrain
@onready var _overlay: HighlightOverlay = $Highlight
@onready var _cursor: CursorOverlay = $Cursor
@onready var _board_edge: BoardOutline = $BoardEdge
@onready var _camera: Camera2D = $Camera
var _tile_map: TileMapLayer = null
var _background_terrain := "grass"  # ключ фона, заданный хостом (`set_background`)
var _sprites_by_uid: Dictionary = {}
var _active_tweens: Dictionary = {}

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
	# Узел тайлмапа — единственный носитель наклона для тайлов: соты укорочены по
	# вертикали, `project()` переносит тот же наклон на подсветки, курсор, обводку,
	# фигуры и камеру. `HexGrid.calibrate` ниже считает локальную сетку, где
	# наклона нет, — поэтому наклон не меняет правила.
	_tile_map.scale = Vector2(1.0, TILT)
	RenderingServer.set_default_clear_color(ThemeConfig.C_BATTLE_BG_VIEW)
	HexGrid.calibrate(_tile_map)

	_overlay.tm = _tile_map
	_overlay.z_index = 5
	_board_edge.tm = _tile_map

	_camera.make_current()
	set_background(_background_terrain)

	_cursor.name = "BattleCursor"
	_cursor.z_index = 30
	_cursor.visible = false

	if not get_viewport().size_changed.is_connected(fit_camera):
		get_viewport().size_changed.connect(fit_camera)

## Поле рисует арт выбранной местности (`FIELD_ART`) — тайлы и обводка доски
## тогда только спорят с кадром.
func uses_art_field() -> bool:
	return FIELD_ART.has(_background_terrain) and _background != null and _background.texture != null


func paint_field() -> void:
	# Координаты читаются из манифеста атласа; вариант берётся по клетке, чтобы
	# поле боя не выглядело одним штампованным тайлом. Поле перерисовывается
	# целиком: `set_background` приходит позже первого `paint_field()` и меняет
	# ширину обводки, а старые клетки обводки иначе останутся в `get_used_rect()`
	# — на них смотрит `field_size()`, то есть в камере останется фантомное поле.
	_tile_map.clear()
	var biome: int = BIOMES.get(_background_terrain, TileAtlas.Biome.GRASS)
	var variants: Array = TileAtlas.base_coords(biome)
	if variants.is_empty():
		push_error("TileAtlas: у биома %s нет базовых тайлов" % TileAtlas.BIOME_NAMES[biome])
		return
	# Два вида поля выбирает ключ местности: `FIELD_ART` — кадр становится полем
	# и тайлы гаснут, `BACKDROP_ART` (или местность без кадра) — полем правит
	# плитка, кадр остаётся пейзажем за краями. Геометрия поля в обоих случаях на
	# тайлмапе: `field_size()` и `fit_camera` считают её по залитым клеткам.
	var art_field := uses_art_field()
	_tile_map.modulate.a = 0.0 if art_field else 1.0
	# Декоративная обводка ±RING нужна, когда вокруг поля только clear color: она
	# прячет обрезанный край тайлсета. Когда под полем кадр местности, его же
	# пейзаж и работает оправой, а обводка съедает кадр и раздувает камеру.
	var ring: int = RING if _background.texture == null else 0
	for y in range(-ring, BattleState.BH + ring):
		for x in range(-ring, BattleState.BW + ring):
			var cell := Vector2i(x, y)
			_tile_map.set_cell(cell, TileAtlas.SOURCE_ID,
				variants[TileAtlas.variant_for(cell, 0, variants.size())])
	_board_edge.cells.clear()
	if art_field:
		for x in BattleState.BW:
			_board_edge.cells.append(Vector2i(x, 0))
			_board_edge.cells.append(Vector2i(x, BattleState.BH - 1))
		for y in range(1, BattleState.BH - 1):
			_board_edge.cells.append(Vector2i(0, y))
			_board_edge.cells.append(Vector2i(BattleState.BW - 1, y))
	_board_edge.refresh()

func add_obstacle(cell: Vector2i, emoji: String) -> void:
	var lbl: Label = _ObstacleLabel.instantiate()
	lbl.text = emoji
	lbl.position = field_point(cell) + Vector2(-14, -16)
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
	hero.position = field_point(Vector2i(1, 1))
	add_child(hero)

## Концы используемой части поля в локальных координатах тайлмапа; пустой массив —
## тайлсет ещё не готов (`setup()` не вызван) либо поле не залито.
func _field_ends() -> Array:
	if _tile_map.tile_set == null:
		return []
	# Геометрия поля — игровое поле BW×BH, а не `get_used_rect()`: в залитые
# клетки входит декоративная обводка, и камера, нацеленная на used_rect,
# вписывает в кадр её, уменьшая юнитов вдвое.
	if _tile_map.get_cell_source_id(Vector2i(0, 0)) == -1:
		return []
	return [
		field_point(Vector2i.ZERO),
		field_point(Vector2i(BattleState.BW - 1, BattleState.BH - 1)),
	]


## Размер поля боя в пикселях вместе с 30 px запасом по краям; Vector2.ZERO —
## вписывать камеру не во что. Публичный, потому что тест обязан считать
## ожидаемый зум независимо, а не копировать формулу из `fit_camera`.
func field_size() -> Vector2:
	var ends := _field_ends()
	if ends.is_empty():
		return Vector2.ZERO
	return Vector2(absf(ends[1].x - ends[0].x) + 60.0, absf(ends[1].y - ends[0].y) + 60.0)


## Запас вертикали, отнятый у поля боя полосами HUD (T-220), layout-пиксели:
## x — верхние карточки и инициатива, y — нижняя панель. Внедряет хост
## (`BattleController` читает `BattleUI.hud_bands()`): `BattleView` не должен знать про
## UI ничего, приём тот же, что с `mood_sink` у канала настроения.
var _hud_reserve := Vector2.ZERO


func set_hud_reserve(top: float, bottom: float) -> void:
	_hud_reserve = Vector2(maxf(top, 0.0), maxf(bottom, 0.0))


func hud_reserve() -> Vector2:
	return _hud_reserve


## Центр используемой части поля в локальных координатах тайлмапа; публичный по той же
## причине, что `field_size()` — тест сверяет сдвиг камеры, а не копирует формулу.
func field_center() -> Vector2:
	var ends := _field_ends()
	if ends.is_empty():
		return Vector2.ZERO
	return (ends[0] + ends[1]) / 2.0


func set_background(terrain: String) -> void:
	_background_terrain = terrain
	var path: String = str(FIELD_ART.get(terrain, BACKDROP_ART.get(terrain, "")))
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_background.texture = tex
	_background.visible = tex != null
	fit_background()
	# Биом поля зависит от того же ключа — перекрашиваем, если поле уже нарисовано
	# (`setup()` предшествует `paint_field()`, а местность приходит позже).
	if _tile_map != null and _tile_map.tile_set != null:
		paint_field()


## Кадр — задник всего видимого куска мира (вьюпорт / зум), а не поля: гексы
## поверх него рисует тайлсет, а пейзаж обязан дожить по краям поля.
func fit_background() -> void:
	if _background.texture == null:
		return
	var z: float = _camera.zoom.x if _camera != null else 1.0
	if z <= 0.0:
		z = 1.0
	var sz: Vector2 = get_viewport().get_visible_rect().size / z
	var t: Vector2 = _background.texture.get_size()
	var k: float = maxf(sz.x / t.x, sz.y / t.y)
	_background.position = field_center()
	_background.scale = Vector2(k, k)


func fit_camera() -> void:
	if _field_ends().is_empty():
		return
	var field_sz := field_size()
	var center := field_center()
	var vp_sz := get_viewport().get_visible_rect().size
	# T-220: поле вписывается в полосу между бендами HUD, а не во весь вьюпорт. Нижняя
	# панель — CanvasLayer, она рисуется поверх мира всегда, поэтому прежняя «вписка
	# впритык» означала на Full HD поле под кнопками (замер T-220: доля кадра 1.000).
	var avail_y: float = vp_sz.y - _hud_reserve.x - _hud_reserve.y
	if avail_y <= 0.0:
		# Полосы съели весь кадр (крошечное окно либо правка сцены). Молча оставить
		# нулевой зум = невидимый дефект, поэтому ругаемся и оставляем четверть кадра.
		push_error("BattleView: полосы HUD съели всю высоту кадра (%.0f px)" % vp_sz.y)
		avail_y = vp_sz.y * 0.25
	var z: float = minf(vp_sz.x / field_sz.x, avail_y / field_sz.y)
	_camera.zoom = Vector2(z, z)
	# Поле обязано стать по центру ПОЛОСЫ, а не вьюпорта: без сдвига оно вписалось бы
	# в полосу, но осталось бы отцентровано по всему кадру и нижней половиной легло бы
	# на HUD. При bottom > top камера уходит вниз по миру, то есть поле на экране — вверх.
	_camera.position = center - Vector2(0.0, (_hud_reserve.x - _hud_reserve.y) / (2.0 * z))
	fit_background()

static func unit_z(row: int) -> int:
	return UNIT_Z_BASE + row


## Поза-вырез юнита либо `null`: у юнита с дорожками (или портретом) процедурной
## анимации позы не нужно (задача 3.9).
func _still_of(node: Node) -> Sprite2D:
	if node == null or not node.has_meta("still"):
		return null
	return node.get_node_or_null("Figure") as Sprite2D


## Поза-вырез ставится в клетку единой мерой высоты, а не нативным размером
## кадра: вырезы пришли разными кадрами (495–569 px), а ряд обязан читаться
## одним ростом (окончательную меру решает 3.3).
static func scale_still(sp: Sprite2D, tex: Texture2D) -> void:
	sp.scale = Vector2.ONE * (CharacterFrames.STILL_HEIGHT / float(tex.get_height()))
	sp.offset = CharacterFrames.STILL_REST_OFFSET


func create_unit_sprite(unit: BattleState.BattleUnit) -> void:
	var n: Node2D = _UnitSprite.instantiate()
	var key := unit.get_key()
	var sp: Sprite2D = n.get_node("Figure")
	var anim: AnimatedSprite2D = n.get_node("Anim")
	var facing := unit.side == BattleState.Side.ATTACKER
	var still := CharacterFrames.still_texture_for(key)
	var frames := CharacterFrames.frames_for(key) if still == null else null
	if still != null:
		# Арт владельца сильнее кадра комплекта: юнит стоит своим вырезом, а не
		# чужой походкой. Опора и разворот — те же, что у дорожек (3.9).
		sp.texture = still
		scale_still(sp, still)
		# Разворот — по направлению взгляда арта, а не по стороне напрямую: комплект
		# смотрит влево, вырезы владельца нарисованы вправо (`CharacterFrames.faces_right`).
		sp.flip_h = facing != CharacterFrames.faces_right(key)
		n.set_meta("faces", Vector2.RIGHT if facing else Vector2.LEFT)
		n.set_meta("still", true)
		n.get_node("Initial").visible = false
	elif frames != null:
		# Анимированный носитель есть ⇒ портрет и буква-заглушка убираются: вторая
		# картинка того же юнита поверх фигуры — мусор, а не резервная подпись.
		anim.sprite_frames = frames
		anim.offset = CharacterFrames.FEET_OFFSET
		anim.scale = Vector2.ONE * CharacterFrames.SCALE
		# Разворот — по направлению взгляда конкретного арта, а не по стороне: волк
		# нарисован вправо, рыцарь — влево.
		anim.flip_h = facing != CharacterFrames.faces_right(key)
		anim.visible = true
		anim.play(&"idle")
		n.get_node("Initial").visible = false
	else:
		var ppath := UnitSprites.find_portrait(key)
		if ppath != "":
			sp.texture = load(ppath)
		else:
			var col := ThemeConfig.C_SIDE_ATTACKER if facing else ThemeConfig.C_SIDE_DEFENDER
			sp.texture = PlaceholderTexture.circle(22, col, Color(0.1, 0.1, 0.1))
		sp.flip_h = facing

	var display_name := unit.get_display_name()
	var il: Label = n.get_node("Initial")
	il.text = display_name.left(1) if display_name != "" else "?"

	var cl: Label = n.get_node("CountLabel")
	cl.text = str(unit.get_count())

	n.position = field_point(unit.cell)
	n.z_index = unit_z(unit.cell.y)
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
	var an := _anim_of(node)
	if an != null:
		_play_once(an, &"hit")
	var tw := create_tween()
	tw.tween_property(node, "modulate", ThemeConfig.C_HIT_FLASH, GameNumbers.HIT_FLASH_SEC)
	tw.tween_property(node, "modulate", Color.WHITE, GameNumbers.HIT_FLASH_RECOVER_SEC)
	var fig := _still_of(node)
	if fig != null:
		# Отдача от удара позой: сдвиг назад от противника (вырез развёрнут к нему)
		# и возврат в опору покоя. Поза идёт по смещению, а не по позиции узла,
		# поэтому не спорит с перемещением.
		var rest_x := CharacterFrames.STILL_REST_OFFSET.x
		# Назад = прочь от противника, за кого он стоит, говорит мета facing, а не
		# flip_h: у вырезов разворот перевёрнут относительно комплекта.
		var faces: Vector2 = node.get_meta("faces")
		var rt := create_tween()
		rt.tween_property(fig, "offset:x", rest_x - faces.x * STILL_RECOIL_PX, GameNumbers.HIT_FLASH_SEC)
		rt.tween_property(fig, "offset:x", rest_x, GameNumbers.HIT_FLASH_RECOVER_SEC)

func remove_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return

	_kill_unit_tweens(unit.uid)
	_sprites_by_uid.erase(unit.uid)
	ParticlePresets.spawn_burst(self, node.position, Color.RED)

	var tw := create_tween()
	tw.tween_property(node, "modulate", Color.TRANSPARENT, GameNumbers.UNIT_REMOVE_FADE_SEC)
	tw.tween_callback(node.queue_free)


func animate_move(unit: BattleState.BattleUnit, path: Array[Vector2i]) -> Tween:
	var node := _find_node(unit)
	if node == null or path.size() < 2:
		return null
	# Порядок отрисовки идёт за рядом: иначе юнит, сошедший в нижний ряд, остаётся
	# под силуэтом того, кого он теперь перекрывает.
	node.z_index = unit_z(path[path.size() - 1].y)
	_kill_unit_tweens(unit.uid)
	var an := _anim_of(node)
	if an != null:
		an.animation = &"walk"
		an.play()
	var tw := create_tween()
	_active_tweens[unit.uid] = tw
	var half := MOVE_TWEEN_SEC * 0.5
	var rest_y := CharacterFrames.STILL_REST_OFFSET.y
	var fig := _still_of(node)
	for i in range(1, path.size()):
		var to: Vector2 = field_point(path[i])
		if fig == null:
			tw.tween_property(node, "position", to, MOVE_TWEEN_SEC)
			continue
		# Поза-вырез не имеет походки, а голое перемещение — скольжение статичной
		# картинки: на первой половине шага фигура поднимается с опоры, на второй
		# возвращается в покой. `parallel` обязателен: без него поза ехала бы
		# отдельным шагом и темп пути удвоился. Темп пути от наличия позы не зависит.
		tw.tween_property(node, "position", field_point(path[i - 1]).lerp(to, 0.5), half)
		tw.parallel().tween_property(fig, "offset:y", rest_y - STILL_BOB_PX, half)
		tw.tween_property(node, "position", to, half)
		tw.parallel().tween_property(fig, "offset:y", rest_y, half)
	if an != null:
		# `stop()` оставил бы юнита на последнем кадре походки — шаг на месте.
		tw.tween_callback(func(): an.play(&"idle"))
	tw.finished.connect(func(): _active_tweens.erase(unit.uid))
	return tw

## Анимированная фигурка юнита либо `null`: юнит без анимированного носителя остаётся
## портретом, и гасить в нём нечего (проверка `visible`, а не наличия узла — `Anim`
## есть в сцене всегда, просто пустой).
func _anim_of(node: Node) -> AnimatedSprite2D:
	var an := node.get_node_or_null("Anim") as AnimatedSprite2D
	return an if an != null and an.visible else null


## Одноразовая дорожка (`attack`, `hit`) возвращается в `idle`: зациклить её нельзя
## (последний кадр замаха как постоянная поза выглядит застреванием), а стека
## анимаций здесь нет и заводить его ради двух дорожек не за чем.
## Дорожки может не быть — у части комплекта кадра получения удара нет (priest);
## тогда остаётся цветовая вспышка, которую делает вызывающий код.
func _play_once(an: AnimatedSprite2D, track: StringName) -> void:
	if an.sprite_frames == null or not an.sprite_frames.has_animation(track):
		return
	an.animation = track
	an.play()
	an.animation_finished.connect(func(): an.play(&"idle"), CONNECT_ONE_SHOT)


func animate_attack(attacker: BattleState.BattleUnit, defender: BattleState.BattleUnit) -> void:
	var attacker_node := _find_node(attacker)
	var defender_node := _find_node(defender)

	if attacker_node == null or defender_node == null:
		return

	_kill_unit_tweens(attacker.uid)
	var an := _anim_of(attacker_node)
	if an != null:
		_play_once(an, &"attack")

	var start_pos: Vector2 = attacker_node.position
	var dir: Vector2 = (defender_node.position - start_pos).normalized() * ATTACK_LUNGE_PX

	var tw := create_tween()
	_active_tweens[attacker.uid] = tw
	tw.tween_property(attacker_node, "position", start_pos + dir, GameNumbers.ATTACK_LUNGE_OUT_SEC)
	tw.tween_property(attacker_node, "position", start_pos, GameNumbers.ATTACK_LUNGE_BACK_SEC)
	tw.finished.connect(func(): _active_tweens.erase(attacker.uid))

## Шаг 5.4 (спека battle-hud, «Шквал событий»): предел одновременно видимых
## чисел. Сверх предела старое число снимается сразу — новое информативнее
## старого, а накопление «до бесконечности» заслоняет поле и боковые панели.
const MAX_SIMULTANEOUS_NUMBERS := 8

## Храним instance id, а не узлы. Typed-массив на этом месте и ронял ошибки движка в
## каждый бой автопрогона: `Array[Node].erase(freed)` отваливается на проверке значения
## («Condition "!_p->typed.validate(value, \"erase\")" is true»), а `var oldest: Node =
## pop_front()` на освобождённом элементе даёт «Trying to assign invalid previously freed
## instance». Метка числа умирает в tween-колбэке, то есть между регистрациями всегда,
## поэтому оба случая — штатные, а не аварийные (замер: 8 строк ошибок на профиль
## Ranger/Trader, `game/tools/matrix_report.gd`; T-206).
var _numbers: Array[int] = []


func _register_number(label: Node) -> void:
	var i := _numbers.size() - 1
	while i >= 0:
		var n := instance_from_id(_numbers[i])
		if n == null or not n.is_inside_tree():
			_numbers.remove_at(i)
		i -= 1
	while _numbers.size() >= MAX_SIMULTANEOUS_NUMBERS:
		var oldest := instance_from_id(_numbers[0])
		if oldest != null:
			oldest.queue_free()
		_numbers.remove_at(0)
	_numbers.append(label.get_instance_id())


func show_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	var label: Label = _FloatingText.instantiate()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.position = field_point(cell) + Vector2(-30, -60)
	label.z_index = 20

	add_child(label)
	_register_number(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - GameNumbers.FLOATING_TEXT_RISE_PX, GameNumbers.FLOATING_TEXT_FADE_SEC)
	tw.parallel().tween_property(label, "modulate:a", 0.0, GameNumbers.FLOATING_TEXT_FADE_SEC)
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
	_register_number(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - GameNumbers.DAMAGE_NUMBER_RISE_PX, GameNumbers.DAMAGE_NUMBER_FADE_SEC)
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
	tw.tween_property(line, "modulate:a", 0.0, GameNumbers.RETALIATION_ARROW_FADE_SEC)
	tw.tween_callback(line.queue_free)

func pulse_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(GameNumbers.PULSE_SCALE, GameNumbers.PULSE_SCALE), GameNumbers.PULSE_ANIM_SEC)
	tw.tween_property(node, "scale", Vector2(1, 1), GameNumbers.PULSE_ANIM_SEC)

func set_cursor_mode(mode: int) -> void:
	if _cursor == null:
		return
	_cursor.set_mode(mode)

func set_cursor_visible(visible_: bool) -> void:
	if _cursor == null:
		return
	_cursor.visible_flag = visible_
	_cursor.visible = visible_
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

## Клетка под мировой координатой. Наклон здесь не появляется сам собой:
## `to_local` разворачивает трансформ тайлмапа, уже включающий `TILT`, а
## `local_to_map` работает в локальной (без наклона) сетке.
func global_to_map(global_pos: Vector2) -> Vector2i:
	return _tile_map.local_to_map(_tile_map.to_local(global_pos))

## Точка клетки на наклонной плоскости поля — ЕДИНСТВЕННЫЙ перевод клетки в
## координату рисования: тайлы, подсветки, курсор, обводка, фигуры и камера
## считают её. Рисунок клетки мимо этой функции даёт расхождение с кликом.
static func project(tm: TileMapLayer, cell: Vector2i) -> Vector2:
	var p: Vector2 = tm.map_to_local(cell)
	return Vector2(p.x, p.y * TILT)

func field_point(cell: Vector2i) -> Vector2:
	return project(_tile_map, cell)

func _find_node(unit: BattleState.BattleUnit) -> Node2D:
	if unit == null:
		return null
	var node: Node2D = _sprites_by_uid.get(unit.uid, null)
	if node != null and not is_instance_valid(node):
		_sprites_by_uid.erase(unit.uid)
		return null
	return node
