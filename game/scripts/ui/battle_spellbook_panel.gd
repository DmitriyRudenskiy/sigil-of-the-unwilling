class_name BattleSpellbookPanel
extends Control

const THEME_PATH := "res://assets/theme/game_theme.tres"
const MAX_SPELL_BUTTONS := 10

signal spell_chosen(spell_id: StringName)

var _hero: HeroController
var _magic: HeroMagic
var _spell_registry: Node = null
var _theme: Theme = null
var _spell_buttons: Array[Button] = []

func _ready() -> void:
    _theme = load(THEME_PATH) as Theme
    _apply_theme()
    _collect_buttons()

func _collect_buttons() -> void:
    var container := $Buttons as HBoxContainer
    _spell_buttons.clear()
    for i in MAX_SPELL_BUTTONS:
        var btn := container.get_node("SpellButton%d" % i) as Button
        if btn != null:
            _spell_buttons.append(btn)

func setup(hero: HeroController = null, magic: HeroMagic = null, registry: Node = null) -> void:
    _hero = hero
    _magic = magic

    _spell_registry = Spells if registry == null else registry
    _refresh()
    if _magic != null and not _magic.changed.is_connected(_refresh):
        _magic.changed.connect(_refresh)

func _apply_theme() -> void:
    if _theme == null:
        return
    var sb := _theme.get_stylebox("panel", "Panel")
    if sb:
        add_theme_stylebox_override("panel", sb)

func _refresh() -> void:

    for btn in _spell_buttons:
        btn.visible = false
    if _magic == null:
        return
    var btn_idx := 0
    for spell_id in _magic.spellbook:
        if btn_idx >= _spell_buttons.size():
            break
        var spell = _spell_registry.get_spell(spell_id)
        if spell == null:
            continue
        if not (spell.target_type in [SpellRegistry.TargetType.SINGLE_ENEMY, SpellRegistry.TargetType.SINGLE_ALLY]):
            continue
        if not _magic.can_cast_def(spell):
            continue
        var btn := _spell_buttons[btn_idx]
        btn.text = "%s (%d)" % [spell.display_name, _magic.get_mana_cost_def(spell)]
        btn.tooltip_text = "%s | Lv.%d" % [spell.school, spell.level]
        # ui-icons: иконка школы магии (schools/air|fire|water|earth.png)
        btn.icon = ThemeConfig.icon_texture(ThemeConfig.ICON_DIR_SCHOOLS + str(spell.school).to_lower() + ".png")
        if _theme != null:
            var bsb := _theme.get_stylebox("button", "Panel")
            if bsb:
                btn.add_theme_stylebox_override("panel", bsb)
        btn.add_theme_color_override("font_color", ThemeConfig.C_TEXT_GOLD_SOFT)

        if btn.pressed.is_connected(_on_spell_pressed):
            btn.pressed.disconnect(_on_spell_pressed)
        btn.pressed.connect(_on_spell_pressed.bind(spell_id))
        btn.visible = true
        btn_idx += 1

func _on_spell_pressed(spell_id: StringName) -> void:
    spell_chosen.emit(spell_id)
