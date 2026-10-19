class_name BattleSpellbookPanel
extends Control

const MAX_SPELL_BUTTONS := 10

signal spell_chosen(spell_id: StringName)

var _hero: HeroController
var _magic: HeroMagic
var _spell_registry: Node = null
var _spell_buttons: Array[Button] = []

# Темы здесь нет намеренно (T-147). Раньше панель звала
# add_theme_stylebox_override("panel", ...) на себе и на кнопках — но `panel`
# не является stylebox-именем ни у Control, ни у Button, а движок на мокрое имя
# темы молчит (замер — test_wrong_item_name_is_silent_not_error). Оба
# переопределения были мертвым кодом и не давали никакого вида. Одеть спелбук
# по киту шага 4 — работа макета (шаг 5), а не этот фикс: здесь нет пикселя изменений.
func _ready() -> void:
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
        btn.add_theme_color_override("font_color", ThemeConfig.C_TEXT_GOLD_SOFT)

        if btn.pressed.is_connected(_on_spell_pressed):
            btn.pressed.disconnect(_on_spell_pressed)
        btn.pressed.connect(_on_spell_pressed.bind(spell_id))
        btn.visible = true
        btn_idx += 1

func _on_spell_pressed(spell_id: StringName) -> void:
    spell_chosen.emit(spell_id)
