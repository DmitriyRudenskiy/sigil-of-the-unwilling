extends Control
class_name ArtifactInventoryScreen



var _hero: HeroController = null

var _tex_cache: Dictionary = {}

var _selected_slot: Artifact.Slot = Artifact.Slot.WEAPON

# Выбор в сетке: наведение показывает предмет, клик выбирает его для действий.
# -1 — ничего; раньше кнопки действовали на «первый попавшийся», что в сетке
# без порядка читается как «непонятно что».
var _hover_backpack := -1
var _picked_backpack := -1

var _right: Control = null

const TEXT_GOLD := ThemeConfig.C_TEXT_GOLD_SOFT
const TEXT_LIGHT := ThemeConfig.C_TEXT_LIGHT_SOFT

# Геометрия сетки снаряжения (grid-inventory-and-merchant 4.1): 6×4 клеток по
# 56 px с шагом 60. Единственный источник для генератора сцены
# (gen_inventory_scene.gd читает эти же константы) и для `_refresh_grid()`.
const GRID_ORIGIN := Vector2i(900, 26)
const GRID_COLS := 6
const GRID_ROWS := 4
const CELL_PITCH := 60
const CELL_SIZE := 56
const OVERFLOW_ORIGIN := Vector2i(900, 310)
const CELL_EMPTY := Color(1.0, 1.0, 1.0, 0.05)
const CELL_FILLED := Color(1.0, 1.0, 1.0, 0.13)
const CELL_HOVER := Color(0.9, 0.75, 0.4, 0.3)

const _STAT_ICON := {
	"attack": "atk_sword", "defense": "helm", "spell_power": "spell",
	"knowledge": "compass", "specialty": "scout", "morale": "heart",
	"luck": "clover", "stack_hp": "hp_orb", "stack_hp_percent": "hp_orb",
	"secondary1": "horse", "secondary2": "battle_flag_s",
	"exp": "flag", "mana": "scroll", "main1": "arrow", "main2": "helm",
	"arrows": "arrow_s", "action_scroll": "scroll", "kit": "compass",
}

const _DOLL_SLOTS := [
	Vector2i(258, 6), Vector2i(318, 6), Vector2i(180, 66), Vector2i(6, 58),
	Vector2i(68, 58), Vector2i(318, 68), Vector2i(180, 146), Vector2i(318, 130),
	Vector2i(6, 160), Vector2i(22, 230), Vector2i(318, 218), Vector2i(46, 300),
	Vector2i(258, 298), Vector2i(6, 370), Vector2i(68, 370), Vector2i(318, 392)
]

const _DOLL_MAP := {
	Artifact.Slot.HEAD: 0, Artifact.Slot.NECK: 2, Artifact.Slot.SHIELD: 3,
	Artifact.Slot.WEAPON: 5, Artifact.Slot.TORSO: 6, Artifact.Slot.MISC_A: 7,
	Artifact.Slot.MISC_B: 8, Artifact.Slot.RING_R: 10, Artifact.Slot.LEGS: 11,
	Artifact.Slot.RING_L: 12, Artifact.Slot.BOOTS: 13, Artifact.Slot.SPELLBOOK: 14,
}

const _SKILL_ICON := [
	"res://assets/ui/icons/nature_sense.png",
	"res://assets/ui/icons/keen_eye.png",
	"res://assets/ui/icons/navigation.png",
	"res://assets/ui/icons/geology.png",
	"res://assets/ui/icons/alchemy.png",
]

const _ICON := {
	"formation": [
		"res://assets/ui/icons/army_s.png",
		"res://assets/ui/icons/arrow_s.png",
		"res://assets/ui/icons/flag_s.png",
		"res://assets/ui/icons/compass_s.png",
	],
}

signal closed

func set_hero(hero: HeroController) -> void:
	_hero = hero
	_build()

func close() -> void:
	closed.emit()
	hide()

func _ready() -> void:
	add_theme_color_override("font_color", TEXT_GOLD)
	_connect_signals()
	_build()

func _theme_font_size(path: String, name_: String) -> void:
	var sizes := {"small": 14, "default": 16, "large": 22, "stat": 16}
	var sz: int = int(sizes.get(name_, 16))
	var n := get_node_or_null(path)
	if n is Label and sz > 0:
		n.add_theme_font_size_override("font", sz)

func _connect_signals() -> void:
	# Подписи кнопок: в сцене их не задаёт никто (ни .tscn, ни генератор), и до
	# этого шага Экранировать/Снять/Уничтожить/Закрыть рисовались пустыми.
	_set_btn_text("Center/Window/Right/Equip", GameText.artifact_equip())
	_set_btn_text("Center/Window/Right/Remove", GameText.artifact_remove())
	_set_btn_text("Center/Window/Right/Dispose", GameText.artifact_dispose())
	_set_btn_text("Center/Window/Side/Ok", GameText.ui_close())
	var dlbl := get_node_or_null("Center/Window/Right/Desc_lbl")
	if dlbl is Label:
		dlbl.text = GameText.artifact_description()

	_connect_btn("Center/Window/Right/Equip", _on_equip)
	_connect_btn("Center/Window/Right/Remove", _on_remove)
	_connect_btn("Center/Window/Right/Dispose", _on_dispose)
	_connect_btn("Center/Window/Side/Ok", close)

	for i in 4:
		var b := get_node_or_null("Center/Window/Bottom/Formations/Form_%d" % i)
		if b is Button:
			var cb := _on_form.bind(i)
			if not b.pressed.is_connected(cb):
				b.pressed.connect(cb)

func _set_btn_text(path: String, value: String) -> void:
	var b := get_node_or_null(path)
	if b is Button:
		b.text = value

func _connect_btn(path: String, handler: Callable) -> void:
	var b := get_node_or_null(path)
	if b is Button:
		if not b.pressed.is_connected(handler):
			b.pressed.connect(handler)

func _build() -> void:
	_build_left()
	_build_right()
	_build_side()
	_build_bottom()
	_refresh()

func _build_left() -> void:
	var left := get_node_or_null("Center/Window/Left")
	if left == null:
		return
	var portrait := get_node_or_null("Center/Window/Left/Portrait")
	if portrait is TextureRect:
		portrait.texture = _tex("res://assets/ui/hero/portrait.png", 80, 80)
	var name_ := get_node_or_null("Center/Window/Left/Name")
	if name_ is Label:
		name_.text = _hero.hero_name if _hero else GameText.artifact_default_name()
	_theme_font_size("Center/Window/Left/Name", "large")
	var primary := [
		["attack", GameText.stat_label("attack"), _hero.stats.get("attack", 0) if _hero else 0],
		["defense", GameText.stat_label("defense"), _hero.stats.get("defense", 0) if _hero else 0],
		["spell_power", GameText.stat_label("spell_power"), _hero.stats.get("spell_power", 0) if _hero else 0],
		["knowledge", GameText.stat_label("knowledge"), _hero.stats.get("knowledge", 0) if _hero else 0],
	]
	for i in 4:
		var key: String = primary[i][0]
		var label: String = primary[i][1]
		var val: int = int(primary[i][2])
		var icon_path := "res://assets/ui/icons/%s.png" % _STAT_ICON.get(key, "dot")
		var ic := get_node_or_null("Center/Window/Left/StatIcon_%d" % i)
		if ic is TextureRect:
			ic.texture = _tex(icon_path, 46, 46)
		var sn := get_node_or_null("Center/Window/Left/StatName_%d" % i)
		if sn is Label:
			sn.text = label
			_theme_font_size("Center/Window/Left/StatName_%d" % i, "small")
		var sv := get_node_or_null("Center/Window/Left/StatValue_%d" % i)
		if sv is Label:
			sv.text = str(val)
			_theme_font_size("Center/Window/Left/StatValue_%d" % i, "stat")
	var ml := get_node_or_null("Center/Window/Left/Mana_lbl")
	if ml is Label:
		ml.text = GameText.stat_label("mana")
		_theme_font_size("Center/Window/Left/Mana_lbl", "default")
	var mv := get_node_or_null("Center/Window/Left/Mana_val")
	if mv is Label:
		mv.text = "%d/%d" % [_mana_cur(), _mana_max()]
		_theme_font_size("Center/Window/Left/Mana_val", "default")
	var el := get_node_or_null("Center/Window/Left/Exp_lbl")
	if el is Label:
		el.text = GameText.stat_label("xp")
		_theme_font_size("Center/Window/Left/Exp_lbl", "default")
	var ev := get_node_or_null("Center/Window/Left/Exp_val")
	if ev is Label:
		ev.text = "0"
		_theme_font_size("Center/Window/Left/Exp_val", "default")
	var sl := get_node_or_null("Center/Window/Left/School_lbl")
	if sl is Label:
		sl.text = GameText.stat_label("school")
		_theme_font_size("Center/Window/Left/School_lbl", "default")
	var sv2 := get_node_or_null("Center/Window/Left/School_val")
	if sv2 is Label:
		sv2.text = _magic_school()
		_theme_font_size("Center/Window/Left/School_val", "default")
	var st := get_node_or_null("Center/Window/Left/Skills_lbl")
	if st is Label:
		st.text = GameText.stat_label("skills")
		_theme_font_size("Center/Window/Left/Skills_lbl", "large")
	for i in 6:
		var slot := get_node_or_null("Center/Window/Left/Skill_%d" % i)
		if slot is not Button:
			continue
		var lvl := _skill_level(i)
		var has := lvl > 0
		var sic := get_node_or_null("Center/Window/Left/Skill_%d/SkillIcon" % i)
		if sic is TextureRect:
			sic.texture = _tex(_SKILL_ICON[i], 40, 40) if i < _SKILL_ICON.size() else null
		var ll := get_node_or_null("Center/Window/Left/Skill_%d/SkillLevel" % i)
		if ll is Label:
			ll.text = str(lvl)
			ll.visible = has

func _build_right() -> void:
	var right := get_node_or_null("Center/Window/Right")
	if right == null:
		return
	_right = right
	var figure := get_node_or_null("Center/Window/Right/Figure")
	if figure is TextureRect:
		figure.texture = _tex("res://assets/ui/hero/figure.png", 240, 360)
	_rebuild_equipped()
	_refresh_grid()

func _build_side() -> void:
	var side := get_node_or_null("Center/Window/Side")
	if side == null:
		return
	var banner := get_node_or_null("Center/Window/Side/Banner")
	if banner is TextureRect:
		banner.texture = _tex("res://assets/ui/hero/banner.png", 62, 62)
	var mini_val := get_node_or_null("Center/Window/Side/Mini")
	if mini_val is TextureRect:
		mini_val.texture = _tex("res://assets/ui/hero/mini.png", 62, 46)

func _build_bottom() -> void:
	var bottom := get_node_or_null("Center/Window/Bottom")
	if bottom == null:
		return
	var army: HeroArmyController = _hero.army if _hero != null else null
	for i in 7:
		var slot := get_node_or_null("Center/Window/Bottom/ArmySlot_%d" % i)
		if slot is not TextureRect:
			continue
		var ic := slot.get_node_or_null("ArmyIcon") as TextureRect
		var ct := slot.get_node_or_null("ArmyCount") as Label
		var filled := army != null and i < army.army.size() and army.army[i] != null
		if filled:
			var key: String = str(army.army[i].get_key())
			var icon := _unit_icon(key)
			if ic != null and icon != null:
				ic.texture = icon
				ic.visible = true
			if ct != null:
				ct.text = str(army.army[i].count)
				ct.visible = true
		else:
			if ic != null:
				ic.visible = false
			if ct != null:
				ct.visible = false
	for i in 4:
		var fb := get_node_or_null("Center/Window/Bottom/Formations/Form_%d" % i)
		if fb is Button:
			fb.icon = load(_ICON["formation"][i])
			fb.add_theme_color_override("font_color", TEXT_GOLD)
			fb.add_theme_color_override("font_pressed_color", TEXT_LIGHT)

func _refresh() -> void:
	if _hero == null or _right == null:
		return
	_rebuild_equipped()
	_refresh_grid()

func _rebuild_equipped() -> void:
	if _hero == null:
		return
	var eq: HeroInventory = _hero.inventory
	var shown := {}
	for slot in eq.equipped:
		var art: Artifact = eq.equipped[slot]
		if art == null:
			continue
		var idx: int = _DOLL_MAP.get(slot, -1)
		if idx < 0 or idx >= _DOLL_SLOTS.size():
			continue
		var icon_path := _artifact_icon(art)
		if icon_path.is_empty():
			continue
		var ov := get_node_or_null("Center/Window/Right/DollSlot_%d/EquipIcon" % idx)
		if ov is TextureRect:
			ov.texture = _tex(icon_path, 56, 56)
			ov.visible = true
			shown[idx] = true
	for i in 16:
		if shown.has(i):
			continue
		var ov := get_node_or_null("Center/Window/Right/DollSlot_%d/EquipIcon" % i)
		if ov is TextureRect:
			ov.visible = false

## Рюкзак — сетка 6×4 (grid-inventory-and-merchant 4.2): предмет рисуется
## прямоугольником cells[rot] со своей origin; не влезшее в носитель — полосой
## «Перевес» под сеткой. Иконки пересоздаются на каждый refresh (их мало),
## клетки — узлы сцены, их только перекрашиваем.
func _refresh_grid() -> void:
	var items := get_node_or_null("Center/Window/Right/Grid/Items")
	var strip := get_node_or_null("Center/Window/Right/Overflow")
	if items == null or strip == null:
		return
	var inv := _inv()
	_prune(items)
	_prune(strip)
	# Карта занятости — один вызов: `occupied_cells()` заодно доводит раскладку
	# до инварианта («у каждого предмета есть клетка»), и дальше клетки только
	# перекрашиваются, а не пересчитываются на каждую из 24.
	var overflow_n := 0
	var used := {}
	if inv != null:
		used = inv.occupied_cells()
		for i in inv.backpack.size():
			var art: Artifact = inv.backpack[i]
			if art == null:
				continue
			if inv.is_overflow(i):
				_add_item_icon(strip, art, i, Vector2(overflow_n * CELL_PITCH, 0), Vector2(CELL_SIZE, CELL_SIZE))
				overflow_n += 1
				continue
			var rect := item_rect(inv.placements[i], art.resolved_cells(), inv.rotated[i])
			_add_item_icon(items, art, i, rect.position, rect.size)
	var lbl := get_node_or_null("Center/Window/Right/Overflow_lbl")
	if lbl is Label:
		lbl.text = GameText.artifact_overflow()
		lbl.visible = overflow_n > 0
	_paint_cells(used)
	_update_desc(inv)

func _inv() -> HeroInventory:
	return _hero.inventory if _hero != null else null

func _picked_art(inv: HeroInventory) -> Artifact:
	if inv == null or _picked_backpack < 0 or _picked_backpack >= inv.backpack.size():
		return null
	return inv.backpack[_picked_backpack]

func _prune(parent: Node) -> void:
	for ch in parent.get_children():
		ch.free()

func _add_item_icon(parent: Control, art: Artifact, idx: int, at: Vector2, size: Vector2) -> void:
	var icon := TextureRect.new()
	icon.name = "Item_%d" % idx
	icon.position = at
	icon.size = size
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := _artifact_icon(art)
	if not path.is_empty():
		icon.texture = _tex(path, CELL_SIZE, CELL_SIZE)
	icon.mouse_entered.connect(_on_item_hover.bind(idx))
	icon.mouse_exited.connect(_on_item_hover.bind(-1))
	icon.gui_input.connect(_on_item_input.bind(idx))
	parent.add_child(icon)

func _on_item_hover(idx: int) -> void:
	_hover_backpack = idx
	_repaint()

func _on_item_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Повторный клик по выбранному снимает выбор: «что выбрано» должно быть
		# видно по подсветке, а не по догадке.
		_picked_backpack = -1 if _picked_backpack == idx else idx
		_repaint()

## Перекраска без перестройки иконок — наведение не должно дёргать всё дерево.
func _repaint() -> void:
	var inv := _inv()
	_paint_cells(inv.occupied_cells() if inv != null else {})
	_update_desc(inv)

## Подсветка клеток: занятые — тёмным, клетки выбранного (или наведённого)
## предмета — золотом. `used` — карта HeroInventory.occupied_cells(): клетка →
## индекс предмета в рюкзаке.
func _paint_cells(used: Dictionary) -> void:
	var shown := _picked_backpack if _picked_backpack >= 0 else _hover_backpack
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var cell := get_node_or_null("Center/Window/Right/Grid/GridCell_%d_%d" % [col, row])
			if cell is not ColorRect:
				continue
			var owner := int(used.get(Vector2i(col, row), -1))
			cell.color = CELL_EMPTY if owner < 0 else (CELL_HOVER if owner == shown else CELL_FILLED)

## Подпись габарита в описании предмета (4.3): сколько клеток занимает предмет
## в текущем повороте — это игрок обязан видеть до поворота и до покупки.
func _update_desc(inv: HeroInventory) -> void:
	var desc := get_node_or_null("Center/Window/Right/Desc")
	if desc is not Label:
		return
	var idx := _picked_backpack if _picked_backpack >= 0 else _hover_backpack
	if inv == null or idx < 0 or idx >= inv.backpack.size() or inv.backpack[idx] == null:
		desc.text = ""
		return
	var art: Artifact = inv.backpack[idx]
	var cells: Vector2i = art.resolved_cells()
	var line := GameText.artifact_footprint(cells.x, cells.y, cells.x * cells.y)
	if inv.is_overflow(idx):
		line += " · " + GameText.artifact_overflow()
	desc.text = "%s\n%s\n%s" % [art.display_name, art.description, line]

## Прямоугольник предмета в координатах сетки: от origin*шаг на cells*шаг минус
## зазор между клетками. Чистая функция — на ней держится тест 4.4.
static func item_rect(origin: Vector2i, cells: Vector2i, rot: bool) -> Rect2:
	var c: Vector2i = Vector2i(cells.y, cells.x) if rot else cells
	var gap := float(CELL_PITCH - CELL_SIZE)
	return Rect2(Vector2(origin) * CELL_PITCH, Vector2(c) * CELL_PITCH - Vector2(gap, gap))

func _on_equip() -> void:
	var inv := _inv()
	if inv == null:
		return
	var art := _picked_art(inv)
	if art == null:
		# Без выбора — первая пригодная, как было до сетки.
		for candidate in inv.backpack:
			if candidate != null and inv.can_equip(candidate):
				art = candidate
				break
	if art != null and inv.can_equip(art):
		inv.equip(art)
	_picked_backpack = -1
	_refresh()

func _on_remove() -> void:
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	if inv.has_slot(_selected_slot):
		inv.unequip(_selected_slot)
	_refresh()

func _on_dispose() -> void:
	var inv := _inv()
	if inv == null or inv.backpack.is_empty():
		return
	inv.remove_from_backpack(_picked_backpack if _picked_backpack >= 0 else 0)
	_picked_backpack = -1
	_refresh()

func _on_form(_i: int) -> void:
	pass

func _set_offsets(c: Control, left: int, top: int, w: int, h: int) -> void:
	c.custom_minimum_size = Vector2(w, h)
	c.size = Vector2(w, h)
	c.offset_left = float(left)
	c.offset_top = float(top)
	c.offset_right = float(left + w)
	c.offset_bottom = float(top + h)

func _tex(path: String, w: int, h: int) -> Texture2D:
	var key := "%s_%dx%d" % [path, w, h]
	if _tex_cache.has(key):
		return _tex_cache[key]

	var res := load(path)
	if res is Texture2D:
		var timg: Image = res.get_image()
		if timg != null:
			if timg.get_width() != w or timg.get_height() != h:
				timg.resize(w, h, Image.INTERPOLATE_BILINEAR)
			var tex := ImageTexture.create_from_image(timg)
			_tex_cache[key] = tex
			return tex
		return res

	return null

func _artifact_icon(art: Artifact) -> String:
	if art == null:
		return ""
	var path := "res://assets/artifacts/%s.png" % art.id
	if ResourceLoader.exists(path):
		return path
	return ""

func _unit_icon(key: String) -> Texture2D:
	var path := "res://assets/units/%s.png" % key
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _mana_cur() -> int:
	return _hero.magic.mana_current if _hero != null else 0

func _mana_max() -> int:
	return _hero.magic.mana_max if _hero != null else 0

func _magic_school() -> String:
	if _hero == null or _hero.magic == null:
		return "—"
	var schools: Dictionary = _hero.magic.schools
	var active: Array = []
	for k in schools:
		if int(schools[k]) > 0:
			active.append(SchoolType.to_key(int(k)))
	return " / ".join(active) if not active.is_empty() else "—"

func _skill_level(i: int) -> int:
	if _hero == null or _hero.skills == null:
		return 0
	var keys := _hero.skills.levels.keys()
	if i < keys.size():
		return _hero.skills.get_skill(keys[i])
	return 0
