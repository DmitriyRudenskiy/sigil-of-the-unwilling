class_name BattleSpellbookPanel
extends Control
## Panel of castable spells during battle. Shown as a bottom bar in battle UI.
## Сцена (BattleSpellbookPanel.tscn) держит контейнер + плейсхолдеры кнопок
## (скелет); список доступных заклинаний подтягивается из HeroMagic/SpellRegistry
## в _refresh(). Стиль — из общей темы (D3).

const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")
const THEME_PATH := "res://assets/theme/game_theme.tres"

signal spell_chosen(spell_id: StringName)

var _hero: HeroController
var _magic: HeroMagic
var _spell_registry: Node = null
var _theme: Theme = null

func _ready() -> void:
	_theme = load(THEME_PATH) as Theme
	_apply_theme()

func setup(hero: HeroController = null, magic: HeroMagic = null, registry: Node = null) -> void:
	_hero = hero
	_magic = magic
	_spell_registry = ServiceLocator.resolve(registry, &"spells")
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
	# Clear buttons — наполняем контейнер «Buttons» из сцены.
	var container = get_node_or_null("Buttons")
	if not (container is BoxContainer):
		container = self
	for child in container.get_children():
		if child is Button:
			child.queue_free()

	if _magic == null:
		return

	for spell_id in _magic.spellbook:
		var spell = _spell_registry.get_spell(spell_id)
		if spell == null:
			continue

		# РФ4-4: показывать только одиночные таргеты
		if not (spell.target_type in [SpellRegistry.TargetType.SINGLE_ENEMY, SpellRegistry.TargetType.SINGLE_ALLY]):
			continue

		if not _magic.can_cast_def(spell):
			continue

		var btn := Button.new()
		btn.text = "%s (%d)" % [spell.display_name, _magic.get_mana_cost_def(spell)]
		btn.tooltip_text = "%s | Lv.%d" % [spell.school, spell.level]
		btn.custom_minimum_size = Vector2(90, 36)
		if _theme != null:
			var bsb := _theme.get_stylebox("button", "Panel")
			if bsb:
				btn.add_theme_stylebox_override("panel", bsb)
			btn.add_theme_color_override("font_color", Color("#e6cf9a"))
		btn.pressed.connect(_on_spell_pressed.bind(spell_id))
		container.add_child(btn)

func _on_spell_pressed(spell_id: StringName) -> void:
	spell_chosen.emit(spell_id)
