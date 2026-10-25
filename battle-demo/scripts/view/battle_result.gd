class_name BattleResult extends CanvasLayer

# [AI]: сгенерировано по задаче 9.7 tasks.md, проверено человеком.
#
# Экран результата (спека `battle-demo-ui`, «Экран результата»): исход, число
# ходов и два выхода — повтор того же набора и смена набора. Лежит слоем
# поверх боя, а не отдельной сценой: бой к этому моменту уже отыгран, и вторая
# сцена означала бы второй экземпляр `CombatState` только ради надписи.
#
# Боевые действия после результата не гасятся здесь — их не предлагает HUD
# (`refresh` снимает кнопки, когда бой окончен), а `CombatState.perform` на
# финише утверждает. Экран лишь то, что видит игрок.

signal replay
signal change_roster

const GOLD := Color(0.85, 0.68, 0.32)
const TEXT := Color(0.93, 0.9, 0.84)
const MUTED := Color(0.66, 0.64, 0.6)
const FONT := 24
const FONT_HEAD := 64
const ROSTER_SCENE := "res://scenes/roster_select.tscn"

var _head := Label.new()
var _note := Label.new()


func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	# На весь вьюпорт, а не «1920×1080»: при `stretch/aspect="expand"` окно шире
	# 16:9 показывает за правым краем непрокрытую полосу (кадр `a_result`).
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(600, 360)
	panel.size = Vector2(720, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 0.97)
	style.set_corner_radius_all(20)
	style.set_border_width_all(3)
	style.border_color = GOLD
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_head.add_theme_font_size_override("font_size", FONT_HEAD)
	_head.add_theme_color_override("font_color", GOLD)
	_head.position = Vector2(0, 48)
	_head.size = Vector2(720, 80)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_head)
	_note.add_theme_font_size_override("font_size", FONT)
	_note.add_theme_color_override("font_color", MUTED)
	_note.position = Vector2(0, 140)
	_note.size = Vector2(720, 40)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_note)
	var again := _button("Повтор", Vector2(60, 216))
	again.pressed.connect(func() -> void: replay.emit())
	panel.add_child(again)
	var other := _button("Сменить набор", Vector2(380, 216))
	other.pressed.connect(func() -> void: change_roster.emit())
	panel.add_child(other)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and visible:
		replay.emit()
		get_viewport().set_input_as_handled()


## Показать итог: `result` — сторона-победитель из ядра (`BattleUnit.SIDE_*`)
## или `CombatState.NO_RESULT`, `rounds` — сколько ходов сыграно.
func show_outcome(result: int, rounds: int) -> void:
	_head.text = {
		BattleUnit.SIDE_PLAYER: "Победа",
		BattleUnit.SIDE_ENEMY: "Поражение",
	}.get(result, "Бой не окончен")
	_note.text = "Ходов: %d" % rounds
	visible = true


func outcome_text() -> String:
	return _head.text


func _button(text: String, at: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(280, 64)
	# Без фокуса: кнопка, перехватившая Enter, лишила бы клавиатурный выход
	# («Повтор» с клавиатуры — тот же Enter).
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT)
	button.add_theme_color_override("font_color", TEXT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.09, 1.0)
	style.set_corner_radius_all(30)
	style.set_border_width_all(2)
	style.border_color = GOLD
	button.add_theme_stylebox_override("normal", style)
	return button
