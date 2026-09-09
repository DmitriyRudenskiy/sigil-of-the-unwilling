extends Control
class_name ArtifactInventoryScreen

const SchoolType = preload("res://scripts/data/SchoolType.gd")

var _hero: HeroController = null
var _theme: Theme = null

var _tex_cache: Dictionary = {}

var bp_page := 0
var bp_slots: Array = []

var _selected_slot: Artifact.Slot = Artifact.Slot.WEAPON
var _right: Control = null

const TEXT_GOLD := ThemeConfig.C_TEXT_GOLD_SOFT
const TEXT_LIGHT := ThemeConfig.C_TEXT_LIGHT_SOFT

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
	_theme = load("res://assets/theme/game_theme.tres") as Theme
	_apply_theme()
	_connect_signals()
	_build()

func _apply_theme() -> void:
	if _theme == null:
		return
	_style("Center/Window", "panel")
	_style("Center/Window/Outline", "outline")
	_style("Center/Window/Left", "panel")
	_style("Center/Window/Right", "panel")
	_style("Center/Window/Side", "panel")
	_style("Center/Window/Bottom", "panel")
	_style("Center/Window/Left/Portrait", "portrait")
	for i in 4:
		_style("Center/Window/Left/StatIcon_%d" % i, "slot")
	for i in 16:
		_style("Center/Window/Right/DollSlot_%d" % i, "doll_slot")
	for i in 6:
		_style("Center/Window/Right/Inventory/BackpackSlot_%d" % i, "backpack_slot")
	_style("Center/Window/Right/Equip", "action_button")
	_style("Center/Window/Right/Remove", "action_button")
	_style("Center/Window/Right/Dispose", "action_button")
	_style("Center/Window/Right/Inventory/Prev", "action_button")
	_style("Center/Window/Right/Inventory/Next", "action_button")
	for i in 6:
		_style("Center/Window/Side/SideSlot_%d" % i, "side_slot")
	_style("Center/Window/Side/Ok", "action_button")
	for i in 7:
		_style("Center/Window/Bottom/ArmySlot_%d" % i, "army_slot")
	for i in 4:
		_style("Center/Window/Bottom/Formations/Form_%d" % i, "action_button")

func _style(path: String, theme_name: String) -> void:
	var n := get_node_or_null(path)
	if n is Control and _theme:
		var sb := _theme.get_stylebox(theme_name, "Panel")
		if sb:
			n.add_theme_stylebox_override("panel", sb)

func _theme_font_size(path: String, name: String) -> void:
	var sizes := {"small": 14, "default": 16, "large": 22, "stat": 16}
	var sz: int = int(sizes.get(name, 16))
	var n := get_node_or_null(path)
	if n is Label and sz > 0:
		n.add_theme_font_size_override("font", sz)

func _connect_signals() -> void:
	var prev := get_node_or_null("Center/Window/Right/Inventory/Prev")
	var next := get_node_or_null("Center/Window/Right/Inventory/Next")

	if prev is Button:
		if not prev.pressed.is_connected(_on_prev_page):
			prev.pressed.connect(_on_prev_page)
	if next is Button:
		if not next.pressed.is_connected(_on_next_page):
			next.pressed.connect(_on_next_page)

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

func _on_prev_page() -> void:
	_backpack_scroll_by(-1)

func _on_next_page() -> void:
	_backpack_scroll_by(1)

func _connect_btn(path: String, handler: Callable) -> void:
	var b := get_node_or_null(path)
	if b is Button:
		if not b.pressed.is_connected(handler):
			b.pressed.connect(handler)

func _build() -> void:
	_apply_theme()
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
	var name := get_node_or_null("Center/Window/Left/Name")
	if name is Label:
		name.text = _hero.hero_name if _hero else GameText.artifact_default_name()
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
		_set_style_slot(slot, has)
		var sic := get_node_or_null("Center/Window/Left/Skill_%d/SkillIcon" % i)
		if sic is TextureRect:
			sic.texture = _tex(_SKILL_ICON[i], 40, 40) if i < _SKILL_ICON.size() else null
		var ll := get_node_or_null("Center/Window/Left/Skill_%d/SkillLevel" % i)
		if ll is Label:
			ll.text = str(lvl)
			ll.visible = has

func _set_style_slot(slot: Button, has: bool) -> void:
	if _theme == null:
		return
	var sb := _theme.get_stylebox("action_button" if has else "slot", "Panel")
	if sb:
		slot.add_theme_stylebox_override("panel", sb)

func _build_right() -> void:
	var right := get_node_or_null("Center/Window/Right")
	if right == null:
		return
	_right = right
	var figure := get_node_or_null("Center/Window/Right/Figure")
	if figure is TextureRect:
		figure.texture = _tex("res://assets/ui/hero/figure.png", 240, 360)
	_rebuild_equipped()
	_refresh_backpack()

func _build_side() -> void:
	var side := get_node_or_null("Center/Window/Side")
	if side == null:
		return
	var banner := get_node_or_null("Center/Window/Side/Banner")
	if banner is TextureRect:
		banner.texture = _tex("res://assets/ui/hero/banner.png", 62, 62)
	var mini := get_node_or_null("Center/Window/Side/Mini")
	if mini is TextureRect:
		mini.texture = _tex("res://assets/ui/hero/mini.png", 62, 46)

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
	_refresh_backpack()

func _rebuild_equipped() -> void:
	if _hero == null:
		return
	var eq: HeroInventory = _hero.inventory
	var shown := {}
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

func _refresh_backpack() -> void:
	if _hero == null:
		return
	var bp: Array[Artifact] = _hero.inventory.backpack
	for i in 6:
		var ic := get_node_or_null(
			"Center/Window/Right/Inventory/BackpackSlot_%d/BpIcon" % i)
		if ic is not TextureRect:
			continue
		var idx := bp_page * 6 + i
		if idx < bp.size() and bp[idx] != null:
			var icon_path := _artifact_icon(bp[idx])
			if not icon_path.is_empty():
				ic.texture = _tex(icon_path, 56, 56)
				ic.visible = true
				continue
		ic.visible = false

func _backpack_scroll_by(dir: int) -> void:
	if _hero == null:
		return
	var max_page := int(floorf(float(GameNumbers.MAX_BACKPACK_SIZE - 6) / 6.0))
	bp_page = clampi(bp_page + dir, 0, max_page)
	_refresh_backpack()

func _on_equip() -> void:
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	for art in inv.backpack:
		if art != null and inv.can_equip(art):
			inv.equip(art)
		break
	_refresh()

func _on_remove() -> void:
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	if inv.has_slot(_selected_slot):
		inv.unequip(_selected_slot)
	_refresh()

func _on_dispose() -> void:
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	if not inv.backpack.is_empty():
		inv.remove_from_backpack(0)
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
		var img: Image = res.get_image()
		if img != null:

			if img.get_width() != w or img.get_height() != h:
				img.resize(w, h, Image.INTERPOLATE_BILINEAR)
			var tex := ImageTexture.create_from_image(img)
			_tex_cache[key] = tex
			return tex
		return res

	var img := Image.load_from_file(path)
	if img != null:
		if img.get_width() != w or img.get_height() != h:
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		var tex := ImageTexture.create_from_image(img)
		_tex_cache[key] = tex
		return tex

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
	return _hero.mana_current if _hero != null else 0

func _mana_max() -> int:
	return _hero.mana_max if _hero != null else 0

func _magic_school() -> String:
	var schools: Dictionary = _hero.magic_schools if _hero != null else {}
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
