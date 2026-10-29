extends Control
class_name ArtifactInventoryScreen



var _hero: HeroController = null

var _tex_cache: Dictionary = {}

var _selected_slot: Artifact.Slot = Artifact.Slot.WEAPON

# Выбор в сетке: наведение показывает предмет, клик выбирает его для действий.
# -1 — ничего; раньше кнопки действовали на «первый попавшийся», что в сетке
# без порядка читается как «непонятно что».
var _hover_backpack := -1
## Индекс в `inventory.backpack` — предмет, над которым работают «Equip»/«Dispose».
var _selected_bp: int = -1

var _right: Control = null

## Узлы предметов по индексу сумки — чтобы смена выбора перекрашивала рамки, не
## пересобирая иконки (`_refresh_grid` их всё равно чистит и строит заново).
var _icons: Dictionary = {}

const TEXT_GOLD := ThemeConfig.C_TEXT_GOLD_SOFT
const TEXT_LIGHT := ThemeConfig.C_TEXT_LIGHT_SOFT

# Геометрия сетки снаряжения (grid-inventory-and-merchant 4.1): 6×4 клеток по
# 56 px с шагом 60. Единственный источник для генератора сцены
# (gen_inventory_scene.gd читает эти же константы) и для `_refresh_grid()`.
# Сетка и кукла — из HeroLayout (геометрия макета 12) и GameNumbers (вместимость):
# литерал здесь был бы вторым носителем той же чиселки.
const GRID_COLS: int = GameNumbers.INVENTORY_GRID.x
const GRID_ROWS: int = GameNumbers.INVENTORY_GRID.y
const DOLL_SLOTS_N: int = 16
const ARMY_CARDS_N: int = 4
# Зазор предмета внутри клетки — чтобы соседние предметы не слипались.
const ITEM_GAP := 4.0
const CELL_EMPTY := Color(1.0, 1.0, 1.0, 1.0)
const CELL_FILLED := Color(0.62, 0.55, 0.45, 1.0)
const CELL_HOVER := Color(1.3, 1.05, 0.6, 1.0)

## Маркеры предмета — непрозрачная рамка поверх иконки, а не `modulate` и не
## полупрозрачная плашка: иконки артефактов — плейсхолдеры со средним каналом
## 15–75 из 255, а плашка зависит от фона под ней (на витраже золотая плашка
## тонула). Рамка видна на любом фоне. Выбор — золото, предмет без свободного
## слота — красный: игрок обязан видеть и «что выбрано», и «почему «Equip» ничего
## не сделает».
const _MARK_SELECTED := "BpSelectedMark"
const _MARK_BLOCKED := "BpBlockedMark"
const _MARK_THICKNESS := 2.0
## Отступ второй рамки от края: когда оба знака включены, они не сливаются в одну полосу.
const _MARK_INSET := 4.0

## Иконка надетой вещи лежит **рядом** с рамкой куклы, а не внутри неё:
## предмет — `Doll/DollIcon_%d`, рамка — `Doll/DollSlot_%d` (декор камня).
## Прежний путь `DollSlot_%d/EquipIcon` не существовал ни одной версии сцены
## после переезда под Sheet (D-280), а сторож `is TextureRect` глушил запись
## молча — кукла не показывала надетое никогда (T-294).
const SLOT_ICON := "Center/Window/Sheet/Stone/Doll/DollIcon_%d"

const _STAT_ICON := {
	"attack": "hero/stat_attack", "defense": "hero/stat_defense",
	"spell_power": "hero/stat_magic", "knowledge": "hero/stat_knowledge",
	"specialty": "scout", "morale": "heart",
	"luck": "clover", "stack_hp": "hp_orb", "stack_hp_percent": "hp_orb",
	"secondary1": "horse", "secondary2": "battle_flag_s",
	"exp": "flag", "mana": "scroll", "main1": "arrow", "main2": "helm",
	"arrows": "arrow_s", "action_scroll": "scroll", "kit": "compass",
}

# Карта слотов и их места — HeroLayout.DOLL_SLOTS / DOLL_MAP (один носитель).

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
	_unwatch_inventory()
	_hero = hero
	_build()
	_watch_inventory()


## Экран обязан жить на сигналах инвентаря, а не только на собственном `_refresh()`:
## предмет, подобранный в мире, появляется в сумке сразу, а не после пересборки экрана.
func _watch_inventory() -> void:
	var inv: HeroInventory = _hero.inventory if _hero != null else null
	if inv == null:
		return
	for sig in [inv.backpack_changed, inv.equipped_changed]:
		if not sig.is_connected(_refresh):
			sig.connect(_refresh)


## Отписка обязательна: без неё экран остаётся подписчиком инвентаря прежнего героя,
## а при смене героев такие подписки накапливаются молча.
func _unwatch_inventory() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	var inv: HeroInventory = _hero.inventory
	if inv == null or not is_instance_valid(inv):
		return
	for sig in [inv.backpack_changed, inv.equipped_changed]:
		if sig.is_connected(_refresh):
			sig.disconnect(_refresh)


func close() -> void:
	closed.emit()
	hide()


func _exit_tree() -> void:
	# Инвентарь живёт в герое, а герой — в мире: без отписки на освобождённый экран
	# прилетает вызов `_refresh` из сигнала инвентаря.
	_unwatch_inventory()

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
	_set_btn_text("Center/Window/Sheet/ItemTip/TipBox/TipButtons/Equip", GameText.artifact_equip())
	_set_btn_text("Center/Window/Sheet/ItemTip/TipBox/TipButtons/Remove", GameText.artifact_remove())
	_set_btn_text("Center/Window/Sheet/ItemTip/TipBox/TipButtons/Dispose", GameText.artifact_dispose())
	# Плитка закрытия макета 12 — знак `×`, а не слово: подпись «Закрыть» не
	# влезает в квадрат макета. Слово остаётся в подсказке (доступное имя).
	_set_btn_text("Center/Window/Sheet/Units/Close", "×")
	var cls := get_node_or_null("Center/Window/Sheet/Units/Close") as Control
	if cls != null:
		cls.tooltip_text = GameText.ui_close()
	var dlbl := get_node_or_null("Center/Window/Sheet/ItemTip/TipBox/Desc_lbl")
	if dlbl is Label:
		dlbl.text = GameText.artifact_description()

	_connect_btn("Center/Window/Sheet/ItemTip/TipBox/TipButtons/Equip", _on_equip)
	_connect_btn("Center/Window/Sheet/ItemTip/TipBox/TipButtons/Remove", _on_remove)
	_connect_btn("Center/Window/Sheet/ItemTip/TipBox/TipButtons/Dispose", _on_dispose)
	_connect_btn("Center/Window/Sheet/Units/Close", close)

	for i in 4:
		var b := get_node_or_null("Center/Window/Sheet/BandSkills/Formations/Form_%d" % i)
		if b is Button:
			var cb := _on_form.bind(i)
			if not b.pressed.is_connected(cb):
				b.pressed.connect(cb)

## Выбор предмета из сумки (индекс в `inventory.backpack`, −1 — сброс). Публичный:
## через него в экран входят и клики по сетке, и тесты действий интерфейса.
func select_backpack(idx: int) -> void:
	_selected_bp = idx
	_repaint()


func selected_backpack_index() -> int:
	return _selected_bp


## Выбор слота куклы — то, что снимет «Remove».
func select_slot(slot: Artifact.Slot) -> void:
	_selected_slot = slot
	_refresh()


func _selected_artifact() -> Artifact:
	if _hero == null or _selected_bp < 0:
		return null
	var bp: Array[Artifact] = _hero.inventory.backpack
	if _selected_bp >= bp.size():
		return null
	return bp[_selected_bp]


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
	_build_units()
	_build_bottom()
	_refresh()

## Рамка куклы для слота — поиск по HeroLayout.DOLL_SLOTS: порядок рамок задан
## один раз в таблице геометрии, вторая карта здесь обязательно бы разошлась.
func _doll_frame(slot) -> int:
	# Порядок рамок задан в HeroLayout.DOLL_SLOTS; поиск — только через него,
	# иначе карта «слот → рамка» появится здесь второй и разойдётся с таблицей.
	return HeroLayout.frame_for_slot(slot)


func _build_left() -> void:
	# Блок переехал под Sheet (D-280); сторож по старому пути молча глушил всю
	# левую колонку — ни имени, ни характеристик, ни иконок на кадре.
	var left := get_node_or_null("Center/Window/Sheet/Left")
	if left == null:
		return
	var portrait := get_node_or_null("Center/Window/Sheet/Left/Portrait")
	if portrait is TextureRect:
		portrait.texture = _tex("res://assets/ui/hero/portrait.png")
	var name_ := get_node_or_null("Center/Window/Sheet/Left/Name")
	if name_ is Label:
		name_.text = _hero.hero_name if _hero else GameText.artifact_default_name()
	_theme_font_size("Center/Window/Sheet/Left/Name", "large")
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
		var ic := get_node_or_null("Center/Window/Sheet/Left/StatIcon_%d" % i)
		if ic is TextureRect:
			ic.texture = _tex(icon_path)
		var sn := get_node_or_null("Center/Window/Sheet/Left/StatName_%d" % i)
		if sn is Label:
			sn.text = label
			_theme_font_size("Center/Window/Sheet/Left/StatName_%d" % i, "small")
		var sv := get_node_or_null("Center/Window/Sheet/Left/StatValue_%d" % i)
		if sv is Label:
			sv.text = str(val)
			_theme_font_size("Center/Window/Sheet/Left/StatValue_%d" % i, "stat")
	var ml := get_node_or_null("Center/Window/Sheet/BandMana/Mana_lbl")
	if ml is Label:
		ml.text = GameText.stat_label("mana")
		_theme_font_size("Center/Window/Sheet/BandMana/Mana_lbl", "default")
	var mv := get_node_or_null("Center/Window/Sheet/BandMana/Mana_val")
	if mv is Label:
		mv.text = "%d/%d" % [_mana_cur(), _mana_max()]
		_theme_font_size("Center/Window/Sheet/BandMana/Mana_val", "default")
	# «Уровень» из макета: в HeroController есть опыт (get_xp), но нет уровня —
	# строку показывать нечем, а нулевой placeholder канон-макет портит (T-251).
	var lv := get_node_or_null("Center/Window/Sheet/Left/LevelRow")
	if lv is Control:
		lv.visible = false
	var sl := get_node_or_null("Center/Window/Sheet/BandMana/School_lbl")
	if sl is Label:
		sl.text = GameText.stat_label("school")
		_theme_font_size("Center/Window/Sheet/BandMana/School_lbl", "default")
	var sv2 := get_node_or_null("Center/Window/Sheet/BandMana/School_val")
	if sv2 is Label:
		sv2.text = _magic_school()
		_theme_font_size("Center/Window/Sheet/BandMana/School_val", "default")
	var st := get_node_or_null("Center/Window/Sheet/BandSkills/Skills_lbl")
	if st is Label:
		st.text = GameText.stat_label("skills")
		_theme_font_size("Center/Window/Sheet/BandSkills/Skills_lbl", "large")
	for i in 6:
		var slot := get_node_or_null("Center/Window/Sheet/BandSkills/Skill_%d" % i)
		if slot is not Button:
			continue
		var lvl := _skill_level(i)
		var has := lvl > 0
		var sic := get_node_or_null("Center/Window/Sheet/BandSkills/Skill_%d/SkillIcon" % i)
		if sic is TextureRect:
			sic.texture = _tex(_SKILL_ICON[i]) if i < _SKILL_ICON.size() else null
		var ll := get_node_or_null("Center/Window/Sheet/BandSkills/Skill_%d/SkillLevel" % i)
		if ll is Label:
			ll.text = str(lvl)
			ll.visible = has

func _build_right() -> void:
	var right := get_node_or_null("Center/Window/Sheet/Stone")
	if right == null:
		return
	_right = right
	var figure := get_node_or_null("Center/Window/Sheet/Stone/Figure")
	if figure is TextureRect:
		figure.texture = _tex("res://assets/ui/hero/figure.png")
	_rebuild_equipped()
	_refresh_grid()

## Плитка «?» (правый нижний угол макета) остаётся без носителя: журнала квестов
## в main нет ни сценой, ни системой — кнопка скрыта, а не выдумана (T-252, D-280).
func _build_units() -> void:
	var q := get_node_or_null("Center/Window/Sheet/Units/Quests")
	if q is Control:
		q.visible = false
		q.disabled = true
		# Выключенный контрол объясняет причину (тот же закон, что у пунктов меню).
		q.tooltip_text = "Журнала квестов в игре ещё нет — задача T-252"
## Карточка юнита (макет: портрет + плашка имени + Lv/M с полосами). Из них
## носитель имеют портрет, имя и число; уровень, HP и MP отряда в main не
## существуют (current_hp живёт в кампанийном ростере, D-220) — эти три метки
## скрыты, а не обнулены (T-306, D-280).
func _build_bottom() -> void:
	var army: HeroArmyController = _hero.army if _hero != null else null
	for i in ARMY_CARDS_N:
		var card := "Center/Window/Sheet/Units/Bottom/Cards/Card_%d" % i
		var ic := get_node_or_null(card + "/ArmyIcon_%d" % i) as TextureRect
		var ct := get_node_or_null(card + "/ArmyCount_%d" % i) as Label
		var nm := get_node_or_null(card + "/CardName_%d" % i) as Label
		for key in ["Lv", "Hp", "Mp"]:
			var ph := get_node_or_null(card + "/Card%s_%d" % [key, i])
			if ph is Control:
				ph.visible = false
		var filled := army != null and i < army.army.size() and army.army[i] != null
		if ic is TextureRect:
			ic.visible = filled
			if filled:
				ic.texture = _unit_icon(str(army.army[i].get_key()))
		if ct is Label:
			ct.visible = filled
			if filled:
				ct.text = str(army.army[i].count)
		if nm is Label:
			nm.text = str(army.army[i].get_display_name()) if filled else ""
	for i in 4:
		var fb := get_node_or_null("Center/Window/Sheet/BandSkills/Formations/Form_%d" % i)
		if fb is Button:
			fb.icon = load(_ICON["formation"][i])
			fb.add_theme_color_override("font_color", TEXT_GOLD)
			fb.add_theme_color_override("font_pressed_color", TEXT_LIGHT)
			# Построений в модели нет — кнопки-носители макета стоят заглушками (T-250).
			fb.disabled = true
			fb.tooltip_text = "Построений в игре ещё нет — задача T-250"

func _refresh() -> void:
	if _hero == null or _right == null:
		return
	_refresh_stats()
	_refresh_mana()
	_rebuild_equipped()
	_refresh_equip_list()
	_refresh_grid()


## Значения левой панели. Без них панель собиралась один раз в `_build()` и после
## экипировки продолжала показывать базу: «пересчёт характеристик» был невидим.
## Формат: «12 (+3)» — база и то, что дали артефакты.
func _refresh_stats() -> void:
	if _hero == null:
		return
	var mods: Dictionary = _hero.inventory.get_total_modifiers()
	var bonus: Dictionary = _hero.get_battle_bonus()
	var keys := ["attack", "defense", "spell_power", "knowledge"]
	for i in keys.size():
		var key: String = keys[i]
		var total: int = int(bonus.get(key, 0))
		var delta: int = int(mods.get(key, 0))
		var sv := get_node_or_null("Center/Window/Sheet/Left/StatValue_%d" % i)
		if sv is Label:
			if delta == 0:
				sv.text = str(total)
			else:
				var sign_: String = "+" if delta > 0 else "-"
				sv.text = "%d (%s%d)" % [total, sign_, absi(delta)]

func _rebuild_equipped() -> void:
	if _hero == null:
		return
	var eq: HeroInventory = _hero.inventory
	var shown := {}
	for slot in eq.equipped:
		var art: Artifact = eq.equipped[slot]
		if art == null:
			continue
		var idx: int = _doll_frame(slot)
		if idx < 0 or idx >= DOLL_SLOTS_N:
			continue
		var icon_path := _artifact_icon(art)
		if icon_path.is_empty():
			continue
		var ov := get_node_or_null(SLOT_ICON % idx)
		if ov is TextureRect:
			ov.texture = _tex(icon_path)
			ov.visible = true
			shown[idx] = true
	for i in DOLL_SLOTS_N:
		if shown.has(i):
			continue
		var ov := get_node_or_null(SLOT_ICON % i)
		if ov is TextureRect:
			ov.visible = false

## Список надетого левой колонки (макет A7–D10, `HeroLayout.BLOCKS["EquipList"]`).
## Порядок — `HeroLayout.DOLL_SLOTS`, тот же, что у рамок куклы: третья строка
## списка обязана быть тем же предметом, что и третья рамка, иначе список читается
## как другой герой. Пустая строка **скрыта**, а не забита прочерком: блок без
## значения не рисуется (носитель строки — T-254).
## Число строк берёт сцена: генератор выпускает `EquipRow_%d`, собственный счётчик
## здесь был бы вторым носителем геометрии и разошёлся бы при правке макета.
func _refresh_equip_list() -> void:
	var items: Array = _equipped_in_doll_order()
	var i := 0
	while true:
		var row := get_node_or_null("Center/Window/Sheet/Left/EquipRow_%d" % i)
		if row == null:
			return
		var art: Artifact = items[i] if i < items.size() else null
		row.visible = art != null
		var icon_path := _artifact_icon(art)
		var ic := row.get_node_or_null("EquipIcon_%d" % i)
		if ic is TextureRect:
			(ic as TextureRect).texture = _tex(icon_path) if not icon_path.is_empty() else null
		var nm := row.get_node_or_null("EquipName_%d" % i)
		if nm is Label:
			var lbl := nm as Label
			lbl.text = art.display_name if art != null else ""
			# Имя предмета длиннее колонки («Сапоги-скороходы» при 0.88×74 px), а
			# Label по умолчанию переносит текст в две строки и залезает на
			# соседнюю рамку. Правило то же, что у ячеек сумки (T-229) и их
			# подписей (T-218): .tscn — нарушитель, писатель ставит гигиену сам.
			lbl.clip_text = true
			lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			_theme_font_size(
				"Center/Window/Sheet/Left/EquipRow_%d/EquipName_%d" % [i, i], "default")
		i += 1


## Надетое в порядке рамок куклы. Декоративные рамки 12–15 держат StringName-метку,
## а не слот (T-242), — они в список не попадают.
func _equipped_in_doll_order() -> Array:
	var out: Array = []
	if _hero == null or not is_instance_valid(_hero) or _hero.inventory == null:
		return out
	for f in HeroLayout.DOLL_SLOTS_N:
		var slot: int = HeroLayout.slot_at_frame(f)
		if slot < 0:
			continue
		var art: Artifact = _hero.inventory.equipped.get(slot, null)
		if art != null:
			out.append(art)
	return out


## Шаг сетки = размер Bag / (10×5): сцена на якорях-долях, пиксельный шаг был бы
## вторым носителем геометрии и расходился бы с окном. Нулевой размер (первый
## кадр, layout ещё не сошёлся) — эталон HeroLayout.
func _bag_pitch() -> Vector2:
	var bag := get_node_or_null("Center/Window/Sheet/Stone/Bag") as Control
	if bag == null or bag.size.x <= 0.0:
		return HeroLayout.grid_pitch()
	return bag.size / Vector2(GRID_COLS, GRID_ROWS)


func _refresh_grid() -> void:
	var items := get_node_or_null("Center/Window/Sheet/Stone/Bag/Items")
	var strip := get_node_or_null("Center/Window/Sheet/Stone/Overflow")
	if items == null or strip == null:
		return
	var inv := _inv()
	var pitch := _bag_pitch()
	_prune(items)
	_prune(strip)
	_icons.clear()
	var overflow_n := 0
	var used := {}
	if inv != null:
		used = inv.occupied_cells()
		for i in inv.backpack.size():
			var art: Artifact = inv.backpack[i]
			if art == null:
				continue
			if inv.is_overflow(i):
				var at := Vector2(overflow_n * pitch.x, 0)
				_apply_item_marks(
						_add_item_icon(strip, art, i, at, pitch - Vector2(ITEM_GAP, ITEM_GAP)),
						inv, art, i)
				overflow_n += 1
				continue
			var rect := item_rect(inv.placements[i], art.resolved_cells(), inv.rotated[i], pitch)
			_apply_item_marks(_add_item_icon(items, art, i, rect.position, rect.size), inv, art, i)
	var lbl := get_node_or_null("Center/Window/Sheet/Stone/Overflow_lbl")
	if lbl is Label:
		lbl.text = GameText.artifact_overflow()
		lbl.visible = overflow_n > 0
	_paint_cells(used)
	_update_desc(inv)


func _inv() -> HeroInventory:
	return _hero.inventory if _hero != null else null

func _prune(parent: Node) -> void:
	for ch in parent.get_children():
		ch.free()

func _add_item_icon(
			parent: Control, art: Artifact, idx: int, at: Vector2, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Item_%d" % idx
	icon.position = at
	icon.size = size
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := _artifact_icon(art)
	if not path.is_empty():
		icon.texture = _tex(path)
	icon.mouse_entered.connect(_on_item_hover.bind(idx))
	icon.mouse_exited.connect(_on_item_hover.bind(-1))
	icon.gui_input.connect(_on_item_input.bind(idx))
	parent.add_child(icon)
	_icons[idx] = icon
	return icon


func _apply_item_marks(icon: Control, inv: HeroInventory, art: Artifact, idx: int) -> void:
	var selected := art != null and idx == _selected_bp
	var blocked := art != null and not inv.can_equip(art)
	_set_item_mark(icon, _MARK_SELECTED, ThemeConfig.C_UI_CELL_SELECTED, selected, 0.0)
	_set_item_mark(icon, _MARK_BLOCKED, ThemeConfig.C_UI_CELL_BLOCKED, blocked, _MARK_INSET)


## Рамка собирается из четырёх полос на якорях: раскладка переживает и смену размера
## окна, и то, что на первом кадре у узла ещё нет размера (иначе маркер молча остался
## бы не нарисованным).
func _set_item_mark(icon: Control, mark_name: String, color: Color, on: bool, inset: float) -> void:
	var frame := icon.get_node_or_null(mark_name) as Control
	if frame == null:
		if not on:
			return
		frame = Control.new()
		frame.name = mark_name
		# Рамка не имеет права съедать клик по предмету: выбор идёт по `gui_input` иконки.
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(frame)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for preset in [
				Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE,
				Control.PRESET_LEFT_WIDE, Control.PRESET_RIGHT_WIDE]:
			var strip := ColorRect.new()
			strip.color = color
			strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(strip)
			_layout_mark_strip(strip, preset as Control.LayoutPreset, inset)
	frame.visible = on


func _layout_mark_strip(strip: ColorRect, preset: Control.LayoutPreset, inset: float) -> void:
	var t := _MARK_THICKNESS
	strip.set_anchors_preset(preset)
	match preset:
		Control.PRESET_TOP_WIDE:
			strip.offset_left = inset
			strip.offset_top = inset
			strip.offset_right = -inset
			strip.offset_bottom = inset + t
		Control.PRESET_BOTTOM_WIDE:
			strip.offset_left = inset
			strip.offset_top = -inset - t
			strip.offset_right = -inset
			strip.offset_bottom = -inset
		Control.PRESET_LEFT_WIDE:
			strip.offset_left = inset
			strip.offset_top = inset
			strip.offset_right = inset + t
			strip.offset_bottom = -inset
		Control.PRESET_RIGHT_WIDE:
			strip.offset_left = -inset - t
			strip.offset_top = inset
			strip.offset_right = -inset
			strip.offset_bottom = -inset

func _on_item_hover(idx: int) -> void:
	_hover_backpack = idx
	_repaint()

func _on_item_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Повторный клик по выбранному снимает выбор: «что выбрано» должно быть
		# видно по подсветке, а не по догадке.
		select_backpack(-1 if _selected_bp == idx else idx)

## Перекраска без перестройки иконок — наведение не должно дёргать всё дерево.
func _repaint() -> void:
	var inv := _inv()
	_paint_cells(inv.occupied_cells() if inv != null else {})
	_update_desc(inv)
	_refresh_marks(inv)


## Рамки «выбран»/«некуда» живут на узле предмета, а выбор меняет их без пересборки
## иконок — иначе клик по предмету подсвечивал бы клетки и молчал про сам предмет.
func _refresh_marks(inv: HeroInventory) -> void:
	if inv == null:
		return
	for idx in _icons:
		var art: Artifact = inv.backpack[idx] if idx < inv.backpack.size() else null
		_apply_item_marks(_icons[idx], inv, art, idx)

## Подсветка клеток: занятые — тёмным, клетки выбранного (или наведённого)
## предмета — золотом. `used` — карта HeroInventory.occupied_cells(): клетка →
## индекс предмета в рюкзаке.
func _paint_cells(used: Dictionary) -> void:
	var shown := _selected_bp if _selected_bp >= 0 else _hover_backpack
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var cell := get_node_or_null("Center/Window/Sheet/Stone/Bag/GridCell_%d_%d" % [col, row]) as CanvasItem
			if cell == null:
				continue
			var owner := int(used.get(Vector2i(col, row), -1))
			cell.modulate = CELL_EMPTY if owner < 0 \
					else (CELL_HOVER if owner == shown else CELL_FILLED)


func _update_desc(inv: HeroInventory) -> void:
	var desc := get_node_or_null("Center/Window/Sheet/ItemTip/TipBox/Desc")
	var tip := get_node_or_null("Center/Window/Sheet/ItemTip") as Control
	if desc is not Label:
		return
	var idx := _selected_bp if _selected_bp >= 0 else _hover_backpack
	var art: Artifact = null
	if inv != null and idx >= 0 and idx < inv.backpack.size():
		art = inv.backpack[idx]
	if tip is Control:
		# Подсказка без предмета — пустая плашка поперёк камня; в макете её там нет.
		tip.visible = art != null
	if art == null:
		desc.text = ""
		return
	var cells: Vector2i = art.resolved_cells()
	var line := GameText.artifact_footprint(cells.x, cells.y, cells.x * cells.y)
	if inv.is_overflow(idx):
		line += " · " + GameText.artifact_overflow()
	var nm := get_node_or_null("Center/Window/Sheet/ItemTip/TipBox/TipName")
	if nm is Label:
		nm.text = art.display_name
	desc.text = "%s\n%s" % [art.description, line]


static func item_rect(
			origin: Vector2i, cells: Vector2i, rot: bool, pitch: Vector2 = Vector2.ZERO) -> Rect2:
	var c: Vector2i = Vector2i(cells.y, cells.x) if rot else cells
	var p := pitch if pitch != Vector2.ZERO else HeroLayout.grid_pitch()
	var gap := Vector2(ITEM_GAP, ITEM_GAP)
	return Rect2(Vector2(origin) * p, Vector2(c) * p - gap)

func _on_equip() -> void:
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	var art: Artifact = _selected_artifact()
	if art == null:
		return
	if not inv.can_equip(art):
		# Неподходящий слот не меняет ничего — ни перестановки, ни «надень вместо
		# этого что-нибудь другое». Признак висит на предмете (`_apply_item_marks`).
		return
	if inv.equip(art):
		_selected_slot = art.slot
		_selected_bp = -1
	_refresh()

func _on_remove() -> void:
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	if not inv.has_slot(_selected_slot):
		return
	var art: Artifact = inv.unequip(_selected_slot)
	# Снятое становится выбранным: следующее действие игрока — про тот же предмет.
	_selected_bp = inv.backpack.find(art) if art != null else -1
	_refresh()

func _on_dispose() -> void:
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	var art: Artifact = _selected_artifact()
	if art == null:
		return
	var idx: int = inv.backpack.find(art)
	if idx < 0:
		return
	inv.remove_from_backpack(idx)
	_selected_bp = -1
	_refresh()

func _on_form(_i: int) -> void:
	pass

## D-275: ресемплинга нет — текстура идёт как есть, вписывает её StretchMode узла.
func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var res := load(path)
	if res is Texture2D:
		_tex_cache[path] = res
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

## Заполнение полосы маны: ширина полосы = доля от дорожки (текстура 12×12,
## рисуется растяжением — маскировать её иначе означало бы врать о запасе).
func _refresh_mana() -> void:
	var bar := get_node_or_null("Center/Window/Sheet/BandMana/ManaBar") as Control
	if bar == null:
		return
	var mx := _mana_max()
	var ratio := float(_mana_cur()) / float(mx) if mx > 0 else 0.0
	bar.anchor_right = clampf(ratio, 0.0, 1.0)


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
