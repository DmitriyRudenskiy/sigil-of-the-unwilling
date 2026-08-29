extends Control
class_name ArtifactInventoryScreen
## Экран героя: попиксельная сборка по макету HTML-мокапа.
## Модульное окно 942×700 (левая/правая/боковая/нижняя панели), центрируется в
## CenterContainer, мир показывается сквозь прозрачный корень.
##
## Динамическое содержимое (портрет/артефакты/юниты/скиллы) подтягивается из
## HeroController; пустые слоты рисуются стилизованными панелями.

var _hero: HeroController = null

# Состояние прокрутки рюкзака (члены класса, а не локальные — используются в _backpack_scroll_by/_refresh_backpack).
var bp_page := 0
var bp_slots: Array = []

# Состояние инвентаря пересобирается в _refresh (см. _rebuild_equipped/_refresh_backpack).
# Экипированный слот, который «Снять» снимет по умолчанию (по макету нет UI выбора — WEAPON).
var _selected_slot: Artifact.Slot = Artifact.Slot.WEAPON
# Ссылки на динамические накладки, чтобы пересобирать их в _refresh без затрагивания фигуры/слотов.
var _eq_overlays: Array = []
var _bp_icons: Array = []
# Origin правой панели в координатах экрана — нужен _rebuild_equipped в _refresh.
var _right_origin: Vector2i = Vector2i.ZERO
# Ссылка на правую панель — нужна _rebuild_equipped в _refresh.
var _right: Control = null

# --- Палитра (из макета) ---
const WIN_BG := Color("#4a3423")
const WIN_BORDER := Color("#16100a")
const OUTLINE := Color("#8a6a3a")
const PANEL_BG := Color("#41301f")
const PANEL_BORDER := Color("#241608")
const GOLD_INSET := Color("#6b4e2e")
const RED_BG := Color("#7a100c")
const RED_BORDER := Color("#3a0806")
const SLOT_BG := Color("#3a2415")
const SLOT_BORDER := Color("#201006")
const SLOT_INSET := Color("#1a0e04")
const STATVAL_BG := Color("#3a281a")
const TEXT_GOLD := Color("#e6cf9a")
const TEXT_LIGHT := Color("#f0dcae")

# --- Иконки статов (относительные пути к assets/ui/icons) ---
const _STAT_ICON := {
	"attack": "atk_sword", "defense": "helm", "spell_power": "spell",
	"knowledge": "compass", "specialty": "scout", "morale": "heart",
	"luck": "clover", "stack_hp": "hp_orb", "stack_hp_percent": "hp_orb",
	"secondary1": "horse", "secondary2": "battle_flag_s",
	"exp": "flag", "mana": "scroll", "main1": "arrow", "main2": "helm",
	"arrows": "arrow_s", "action_scroll": "scroll", "kit": "compass",
}

# --- 16 слотов куклы (сетка 4×4, относительно правой панели) ---
const _DOLL_SLOTS := [
	Vector2i(258, 6),
	Vector2i(318, 6),
	Vector2i(180, 66),
	Vector2i(6, 58),
	Vector2i(68, 58),
	Vector2i(318, 68),
	Vector2i(180, 146),
	Vector2i(318, 130),
	Vector2i(6, 160),
	Vector2i(22, 230),
	Vector2i(318, 218),
	Vector2i(46, 300),
	Vector2i(258, 298),
	Vector2i(6, 370),
	Vector2i(68, 370),
	Vector2i(318, 392)
]

# --- Соответствие экипированных слотов индексу слота куклы ---
# Индексы 1, 4, 9, 15 — лишние слоты без привязки к типу артефакта (по макету).
const _DOLL_MAP := {
	Artifact.Slot.HEAD: 0, Artifact.Slot.NECK: 2, Artifact.Slot.SHIELD: 3,
	Artifact.Slot.WEAPON: 5, Artifact.Slot.TORSO: 6, Artifact.Slot.MISC_A: 7,
	Artifact.Slot.MISC_B: 8, Artifact.Slot.RING_R: 10, Artifact.Slot.LEGS: 11,
	Artifact.Slot.RING_L: 12, Artifact.Slot.BOOTS: 13, Artifact.Slot.SPELLBOOK: 14,
}

# --- Иконки скиллов (5 активных + 1 пустой слот) ---
const _SKILL_ICON := [
	"res://assets/ui/icons/nature_sense.png",
	"res://assets/ui/icons/keen_eye.png",
	"res://assets/ui/icons/navigation.png",
	"res://assets/ui/icons/geology.png",
	"res://assets/ui/icons/alchemy.png",
]

signal closed

# --- Иконки действий/построений (существующие ассеты) ---
const _ICON := {
	"formation": [
		"res://assets/ui/icons/army_s.png",
		"res://assets/ui/icons/arrow_s.png",
		"res://assets/ui/icons/flag_s.png",
		"res://assets/ui/icons/compass_s.png",
	],
}


func set_hero(hero: HeroController) -> void:
	_hero = hero
	_build()


func close() -> void:
	closed.emit()
	if is_inside_tree():
		queue_free()


func _ready() -> void:
	add_theme_color_override("font_color", TEXT_GOLD)


# ---------------------------------------------------------------------------
# Сборка окна
# ---------------------------------------------------------------------------
func _build() -> void:
	for child in get_children():
		child.queue_free()

	# CenterContainer — центрирует окно 942×700, мир виден сквозь прозрачность.
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var window := Control.new()
	window.name = "Window"
	_set_offsets(window, 0, 0, 942, 700)
	window.add_theme_stylebox_override("panel", _panel_stylebox())
	center.add_child(window)

	# Обводка + тень (на 4px больше окна)
	var outline := Control.new()
	outline.name = "Outline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_offsets(outline, -4, -4, 946, 704)
	outline.add_theme_stylebox_override("panel", _stylebox(OUTLINE, 2, 6, true, Color.TRANSPARENT, 12))
	center.add_child(outline)

	_build_left(window, Vector2i(6, 6))
	_build_right(window, Vector2i(424, 6))
	_build_side(window, Vector2i(862, 6))
	_build_bottom(window, Vector2i(6, 600))

# ---------------------------------------------------------------------------
# Левая панель
# ---------------------------------------------------------------------------
func _build_left(parent: Control, origin: Vector2i) -> void:
	var left := Control.new()
	left.name = "Left"
	_set_offsets(left, origin.x, origin.y, 412, 588)
	left.add_theme_stylebox_override("panel", _stylebox(PANEL_BORDER, 2, 4, true, PANEL_BG, 8))
	parent.add_child(left)

	# Портрет
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = _tex("res://assets/ui/hero/portrait.png", 120, 120)
	_set_offsets(portrait, 12, 12, 120, 120)
	portrait.add_theme_stylebox_override("panel", _stylebox(Color("#201006"), 2, 6, true, Color("#2a1a0c")))
	left.add_child(portrait)

	# Имя героя
	_txt(left, _hero.hero_name if _hero != null else "Герой", Vector2i(140, 14), Vector2i(260, 28),
		20, TEXT_GOLD, HORIZONTAL_ALIGNMENT_LEFT)

	# Список статов (иконка + название + значение в полоске)
	var stats := _stats_rows()
	var ly := 140
	for row in stats:
		var key: String = row[0]
		var label: String = row[1]
		var val: Variant = row[2]
		var icon_path := "res://assets/ui/icons/%s.png" % _STAT_ICON.get(key, "dot")
		var ic := TextureRect.new()
		ic.texture = _tex(icon_path, 24, 24)
		_set_offsets(ic, 12, ly, 24, 24)
		left.add_child(ic)
		_txt(left, label, Vector2i(44, ly - 2), Vector2i(150, 22), 14, TEXT_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		var bar := Control.new()
		bar.name = "StatVal_%s" % key
		_set_offsets(bar, 204, ly, 196, 22)
		bar.add_theme_stylebox_override("panel", _stylebox(SLOT_BORDER, 1, 4, true, STATVAL_BG, 4))
		left.add_child(bar)
		_txt(left, str(val), Vector2i(360, ly - 2), Vector2i(40, 22), 14, TEXT_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
		ly += 28

	# Информационные строки (мана, опыт, школа)
	var iy := 140 + stats.size() * 28 + 12
	_info_row(left, "Мана", "%d/%d" % [_mana_cur(), _mana_max()], iy)
	iy += 26
	_info_row(left, "Опыт", "0", iy)
	iy += 26
	_info_row(left, "Школа", _magic_school(), iy)

	# Сетка скиллов 2×3 (5 навыков + пустой слот)
	var sy := iy + 18
	_txt(left, "Навыки", Vector2i(12, sy - 18), Vector2i(120, 20), 16, TEXT_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	sy += 14
	for i in 6:
		var slot := Control.new()
		slot.name = "Skill_%d" % i
		_set_offsets(slot, 12 + (i % 2) * 196, sy + (i / 2) * 52, 88, 44)
		var lvl := _skill_level(i)
		var has := lvl > 0
		slot.add_theme_stylebox_override("panel", _stylebox(Color("#201006"), 2, 6, true,
			(Color("#5a3a1a") if has else SLOT_BG), 6))
		left.add_child(slot)
		if i < _SKILL_ICON.size():
			var sic := TextureRect.new()
			sic.texture = _tex(_SKILL_ICON[i], 40, 40)
			_set_offsets(sic, 8, 2, 40, 40)
			slot.add_child(sic)
		if has:
			_txt(slot, str(lvl), Vector2i(48, 12), Vector2i(36, 22), 20, TEXT_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

# --- Вспомогательные источники данных ---
func _mana_cur() -> int:
	return _hero.mana_current if _hero != null else 0

func _mana_max() -> int:
	return _hero.mana_max if _hero != null else 0

func _magic_school() -> String:
	var schools: Dictionary = _hero.magic_schools if _hero != null else {}
	var active: Array = []
	for k in schools:
		if int(schools[k]) > 0:
			active.append(str(k))
	return " / ".join(active) if not active.is_empty() else "—"

func _skill_level(i: int) -> int:
	if _hero == null or _hero.skills == null:
		return 0
	var keys := _hero.skills.levels.keys()
	if i < keys.size():
		return _hero.skills.get_skill(keys[i])
	return 0

func _info_row(parent: Control, label: String, value: String, y: int) -> void:
	_txt(parent, label, Vector2i(12, y), Vector2i(150, 20), 14, TEXT_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(parent, value, Vector2i(204, y), Vector2i(196, 20), 14, TEXT_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)

func _stats_rows() -> Array:
	var hero_stats: Dictionary = _hero.stats if _hero != null else {}
	var rows := [
		["attack", "Атака", hero_stats.get("attack", 0)],
		["defense", "Защита", hero_stats.get("defense", 0)],
		["spell_power", "Магия", hero_stats.get("spell_power", 0)],
		["knowledge", "Знания", hero_stats.get("knowledge", 0)],
	]
	# Вторичные навыки как строки
	if _hero != null and _hero.skills != null:
		for k in _hero.skills.levels.keys():
			var lvl: int = _hero.skills.get_skill(k)
			if lvl > 0:
				rows.append([str(k), _secondary_label(k), lvl])
	return rows

func _secondary_label(k: String) -> String:
	var m := {
		"nature_sense": "Природа", "keen_eye": "Глаз орла", "navigation": "Навигация",
		"geology": "Геология", "alchemy": "Алхимия",
	}
	return m.get(k, k)

# ---------------------------------------------------------------------------
# Правая панель (кукла + инвентарь + действия)
# ---------------------------------------------------------------------------
func _build_right(parent: Control, origin: Vector2i) -> void:
	var right := Control.new()
	right.name = "Right"
	_set_offsets(right, origin.x, origin.y, 432, 588)
	_right_origin = origin
	_right = right
	right.add_theme_stylebox_override("panel", _stylebox(PANEL_BORDER, 2, 4, true, PANEL_BG, 8))
	parent.add_child(right)

	# Кукла-фигура — под слотами (в HTML: <svg class="fig"> идёт до слотов).
	var figure := TextureRect.new()
	figure.name = "Figure"
	figure.texture = _tex("res://assets/ui/hero/figure.png", 240, 360)
	_set_offsets(figure, origin.x + 96, origin.y + 2, 240, 360)
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(figure)

	# 16 слотов экипировки поверх фигуры
	for i in _DOLL_SLOTS.size():
		var slot := Control.new()
		slot.name = "DollSlot_%d" % i
		_set_offsets(slot, origin.x + _DOLL_SLOTS[i].x, origin.y + _DOLL_SLOTS[i].y, 56, 56)
		slot.add_theme_stylebox_override("panel", _stylebox(Color("#201006"), 2, 6, true, SLOT_BG, 8))
		right.add_child(slot)

	# Накладка экипированных артефактов на слоты куклы (вынесена в _rebuild_equipped, чтобы
	# кнопки «Взять»/«Снять»/«Сбросить» могли пересобрать её по месту без затргивания фигуры).
	_rebuild_equipped(origin)

	# Строка инвентаря (рюкзак): 6 видимых слотов + стрелки ◀ ▶ (по макету). Прокрутка по 6.
	var inv := Control.new()
	inv.name = "Inventory"
	_set_offsets(inv, 0, 454, 432, 68)
	inv.add_theme_stylebox_override("panel", _stylebox(PANEL_BORDER, 2, 4, true, PANEL_BG, 6))
	right.add_child(inv)

	# Стрелки
	var prev := TextureRect.new()
	prev.name = "Prev"
	prev.texture = _tex("res://assets/ui/icons/arrow_s.png", 22, 56)
	_set_offsets(prev, 8, 6, 22, 56)
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv.add_child(prev)

	var next := TextureRect.new()
	next.name = "Next"
	next.texture = _tex("res://assets/ui/icons/arrow_s.png", 22, 56)
	next.flip_h = true
	_set_offsets(next, 402, 6, 22, 56)
	next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv.add_child(next)

	# Невидимые кнопки-стрелки ( во весь размер строки) для обработки нажатий.
	var prev_btn := Button.new()
	prev_btn.name = "PrevBtn"
	_set_offsets(prev_btn, 0, 0, 432, 68)
	prev_btn.focus_mode = Button.FOCUS_NONE
	prev_btn.add_theme_stylebox_override("panel", _stylebox(Color("#201006"), 0, 0, true, Color(0, 0, 0, 0)))
	prev_btn.pressed.connect(func(): _backpack_scroll_by(-1))
	inv.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.name = "NextBtn"
	_set_offsets(next_btn, 0, 0, 432, 68)
	next_btn.focus_mode = Button.FOCUS_NONE
	next_btn.add_theme_stylebox_override("panel", _stylebox(Color("#201006"), 0, 0, true, Color(0, 0, 0, 0)))
	next_btn.pressed.connect(func(): _backpack_scroll_by(1))
	inv.add_child(next_btn)

	# Сетка из 6 слотов рюкзака (56x56), позиции по макету (шаг 62, центровка).
	for i in 6:
		var slot := Control.new()
		slot.name = "BackpackSlot_%d" % i
		_set_offsets(slot, 36 + i * 62, 6, 56, 56)
		slot.add_theme_stylebox_override("panel", _stylebox(SLOT_BORDER, 1, 4, true, SLOT_BG, 6))
		inv.add_child(slot)
		bp_slots.append(slot)

	# Кнопки действий (58x46, иконки, space-between). y = 522 + 10 (padding).
	_action_icon_button(right, "res://assets/ui/icons/scroll_s.png", 14, 532, _on_equip)
	_action_icon_button(right, "res://assets/ui/icons/treasure_s.png", 187, 532, _on_remove)
	_action_icon_button(right, "res://assets/ui/hero/x.png", 360, 532, _on_dispose)

func _backpack_scroll_by(dir: int) -> void:
	if _hero == null:
		return
	var max_page := int(floorf(float(GameSettings.MAX_BACKPACK_SIZE - 6) / 6.0))
	bp_page = clampi(bp_page + dir, 0, max_page)
	_refresh_backpack()

func _refresh_backpack() -> void:
	if _hero == null:
		return
	var bp: Array[Artifact] = _hero.inventory.backpack
	for i in 6:
		var slot: Control = bp_slots[i]
		for c in slot.get_children():
			slot.remove_child(c)
			c.free()
		var idx := bp_page * 6 + i
		if idx < bp.size() and bp[idx] != null:
			var icon_path := _artifact_icon(bp[idx])
			if not icon_path.is_empty():
				var ic := TextureRect.new()
				ic.name = "BpIcon_%d" % idx
				ic.texture = _tex(icon_path, 56, 56)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				# Выделение выбранного индекса рюкзака (для «Сбросить»): золотой контур.
				slot.add_child(ic)
				_bp_icons.append(ic)

# Пересобрать накладки экипированных артефактов поверх слотов куклы (очируя старые).
func _rebuild_equipped(origin: Vector2i) -> void:
	for ov in _eq_overlays:
		if ov.get_parent() != null:
			ov.get_parent().remove_child(ov)
		ov.free()
	_eq_overlays.clear()
	if _hero == null or _right == null:
		return
	var eq: HeroInventory = _hero.inventory
	for slot in eq.equipped.keys():
		var art: Artifact = eq.equipped[slot]
		if art == null:
			continue
		var idx: int = _DOLL_MAP.get(slot, -1)
		if idx < 0 or idx >= _DOLL_SLOTS.size():
			continue
		var icon_path := _artifact_icon(art)
		if icon_path.is_empty():
			continue
		var ov := TextureRect.new()
		ov.name = "Equip_%s" % str(slot)
		ov.texture = _tex(icon_path, 56, 56)
		_set_offsets(ov, origin.x + _DOLL_SLOTS[idx].x, origin.y + _DOLL_SLOTS[idx].y, 56, 56)
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_right.add_child(ov)
		_eq_overlays.append(ov)

# Пересобрать всё, что зависит от состояния инвентаря: накладки экипировки и иконки рюкзака.
func _refresh() -> void:
	if _hero == null or _right == null:
		return
	_rebuild_equipped(_right_origin)
	_refresh_backpack()

func _on_equip() -> void:
	# «Взять» (📜): экипировать первый подходящий элемент рюкзака.
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	for art in inv.backpack:
		if art != null and inv.can_equip(art):
			inv.equip(art)
		break
	_refresh()

func _on_remove() -> void:
	# «Снять» (🧰): снять выбранный экипированный элемент в рюкзак.
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	if inv.has_slot(_selected_slot):
		inv.unequip(_selected_slot)
	_refresh()

func _on_dispose() -> void:
	# «Сбросить» (⊘): удалить первый элемент рюкзака.
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	if not inv.backpack.is_empty():
		inv.remove_from_backpack(0)
	_refresh()

func _action_icon_button(parent: Control, icon_path: String, left: int, top: int,
		_handler: Callable) -> Button:
	var b := Button.new()
	b.name = "Action_%s" % icon_path
	b.add_theme_stylebox_override("panel", _stylebox(Color("#201006"), 2, 6, true, SLOT_BG))
	b.focus_mode = Button.FOCUS_NONE
	var ic := TextureRect.new()
	ic.texture = _tex(icon_path, 58, 46)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.offset_left = float(left)
	b.offset_top = float(top)
	b.offset_right = float(left + 58)
	b.offset_bottom = float(top + 46)
	b.pressed.connect(_handler)
	parent.add_child(b)
	return b

# ---------------------------------------------------------------------------
# Боковая панель (красная) и нижняя панель (армия + построения)
# ---------------------------------------------------------------------------
func _build_side(parent: Control, origin: Vector2i) -> void:
	var side := Control.new()
	side.name = "Side"
	_set_offsets(side, origin.x, origin.y, 80, 588)
	side.add_theme_stylebox_override("panel", _stylebox(Color("#3a0806"), 1, 0, true, RED_BG))
	parent.add_child(side)

	var banner := TextureRect.new()
	banner.name = "Banner"
	banner.texture = _tex("res://assets/ui/hero/banner.png", 62, 62)
	_set_offsets(banner, 9, 8, 62, 62)
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	side.add_child(banner)

	var mini := TextureRect.new()
	mini.name = "Mini"
	mini.texture = _tex("res://assets/ui/hero/mini.png", 62, 46)
	_set_offsets(mini, 9, 78, 62, 46)
	mini.stretch_mode = TextureRect.STRETCH_SCALE
	side.add_child(mini)

	for i in 7:
		var ss := Control.new()
		ss.name = "SideSlot_%d" % i
		_set_offsets(ss, 9, 132 + i * 50, 62, 42)
		ss.add_theme_stylebox_override("panel", _stylebox(Color("#241608"), 2, 4, true, Color("#4a3423"), 6))
		side.add_child(ss)

	var ok := Button.new()
	ok.name = "Ok"
	_set_offsets(ok, 9, 534, 62, 46)
	ok.add_theme_stylebox_override("panel", _stylebox(Color("#201006"), 2, 6, true, SLOT_BG))
	ok.icon = load("res://assets/ui/hero/check.png")
	ok.focus_mode = Button.FOCUS_NONE
	ok.add_theme_color_override("font_color", TEXT_GOLD)
	ok.pressed.connect(func(): close())
	side.add_child(ok)

func _build_bottom(parent: Control, origin: Vector2i) -> void:
	var bottom := Control.new()
	bottom.name = "Bottom"
	_set_offsets(bottom, origin.x, origin.y, 930, 94)
	bottom.add_theme_stylebox_override("panel", _stylebox(Color("#3a0806"), 1, 0, true, RED_BG))
	parent.add_child(bottom)

	var army: HeroArmyController = _hero.army if _hero != null else null
	for i in 7:
		var slot := Control.new()
		slot.name = "ArmySlot_%d" % i
		_set_offsets(slot, i * 82, 0, 76, 76)
		var filled := army != null and i < army.army.size() and army.army[i] != null
		var bg := Color("#241a12") if filled else Color("#8a1210")
		slot.add_theme_stylebox_override("panel", _stylebox(Color("#40080a"), 2, 8, true, bg, 8))
		bottom.add_child(slot)
		if filled:
			var key: String = str(army.army[i].get_key())
			var count: int = army.army[i].count
			var icon := _unit_icon(key)
			if icon != null:
				var ic := TextureRect.new()
				ic.texture = icon
				_set_offsets(ic, 6, 6, 64, 64)
				ic.stretch_mode = TextureRect.STRETCH_SCALE
				slot.add_child(ic)
			_txt(bottom, str(count), Vector2i(50, 56), Vector2i(24, 20), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	var forms := Control.new()
	forms.name = "Formations"
	_set_offsets(forms, 802, 8, 124, 72)
	bottom.add_child(forms)
	for i in 4:
		var fb := Button.new()
		fb.name = "Form_%d" % i
		fb.add_theme_stylebox_override("panel", _stylebox(Color("#201006"), 2, 6, true, SLOT_BG))
		fb.focus_mode = Button.FOCUS_NONE
		fb.icon = load(_ICON["formation"][i])
		fb.add_theme_color_override("font_color", TEXT_GOLD)
		fb.add_theme_color_override("font_pressed_color", TEXT_LIGHT)
		_set_offsets(fb, 802 + (i % 2) * 64, 8 + (i / 2) * 36, 60, 32)
		forms.add_child(fb)

# ---------------------------------------------------------------------------
# Хелперы
# ---------------------------------------------------------------------------
func _set_offsets(c: Control, left: int, top: int, w: int, h: int) -> void:
	c.custom_minimum_size = Vector2(w, h)
	c.size = Vector2(w, h)
	c.offset_left = float(left)
	c.offset_top = float(top)
	c.offset_right = float(left + w)
	c.offset_bottom = float(top + h)

func _stylebox(border_color: Color, border_size: int, radius: int, draw_center: bool,
		bg: Color = Color.TRANSPARENT, inset_size: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = draw_center
	if draw_center and bg != Color.TRANSPARENT:
		sb.bg_color = bg
	sb.set_border_width_all(border_size)
	sb.set_corner_radius_all(radius)
	sb.border_color = border_color
	if inset_size > 0:
		sb.shadow_size = inset_size
		sb.shadow_color = SLOT_INSET
	return sb

func _panel_stylebox() -> StyleBoxFlat:
	return _stylebox(PANEL_BORDER, 2, 4, true, PANEL_BG, 10)

func _tex(path: String, _w: int, _h: int) -> Texture2D:
	return load(path)

func _txt(parent: Control, text: String, pos: Vector2i, size: Vector2i, font_size: int,
		color: Color, h_align: HorizontalAlignment) -> Label:
	var tr := Label.new()
	tr.text = text
	tr.add_theme_font_size_override("font_size", font_size)
	tr.horizontal_alignment = h_align
	tr.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	tr.add_theme_color_override("font_color", color)
	_set_offsets(tr, pos.x, pos.y, size.x, size.y)
	parent.add_child(tr)
	return tr

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
