class_name RosterSelect extends Control

# [AI]: сгенерировано по задаче 9.2 tasks.md, проверено человеком.
#
# Экран выбора набора (спека `battle-demo-ui`, «Выбор набора»). Состав и
# описание отличий берутся из `DataLibrary` — экран не может соврать про набор,
# потому что другого источника у него нет. Отличия видно **до** выбора: под
# каждой карточкой то, чем она отличается, и имена всех семи юнитов.
#
# Выбор — с клавиатуры (←/→, Enter), как требует спека. Мыши здесь нет:
# стрелки и Enter покрывают экран целиком, а дублирующий клик был бы вторым
# путём, который надо синхронизировать с первым.

const BATTLE_SCENE := "res://scenes/battle.tscn"
const GOLD := Color(0.85, 0.68, 0.32)
const TEXT := Color(0.93, 0.9, 0.84)
const MUTED := Color(0.66, 0.64, 0.6)
const CARD_SIZE := Vector2(760, 620)
const FONT := 24
const FONT_TITLE := 44

var _selected := 0
var _cards := []


func _ready() -> void:
	add_child(_rect(Vector2(1920, 1080), Color(0.05, 0.05, 0.06, 1.0)))
	var title := _label(FONT_TITLE, GOLD)
	title.text = "Выбор набора"
	title.position = Vector2(0, 48)
	title.size = Vector2(1920, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var rosters := DataLibrary.load_rosters()
	for index in rosters.size():
		add_child(_card(index, rosters[index]))
	var hint := _label(FONT, MUTED)
	hint.text = "← / → — выбор, Enter — в бой"
	hint.position = Vector2(0, 1000)
	hint.size = Vector2(1920, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	_highlight()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_selected = 1 - _selected
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm()


## Выбор до подтверждения — то, что проверяет тест, не трогая маршрут сцен.
func selected_id() -> String:
	var rosters := DataLibrary.load_rosters()
	return String(rosters[_selected].id)


func select(id: String) -> void:
	for index in DataLibrary.load_rosters().size():
		if String(DataLibrary.load_rosters()[index].id) == id:
			_selected = index
			_highlight()


## Что экран показывает про набор до того, как игрок его выберет: имя, отличие,
## состав. Тест сверяет с `RosterData`, чтобы экран не рисовал свой текст.
func card_text(id: String) -> String:
	for card in _cards:
		if card["id"] == id:
			return card["head"].text + "\n" + card["body"].text
	return ""


func _confirm() -> void:
	commit_choice()
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Запись выбора в маршрут. Отдельно от перехода: тест проверяет выбор, не
## меняя сцену всего прогона.
func commit_choice() -> void:
	DemoFlow.roster_id = selected_id()


func _card(index: int, roster: RosterData) -> Control:
	var panel := Panel.new()
	panel.position = Vector2(960.0 - CARD_SIZE.x + 40.0, 160.0) + Vector2(
		index * (CARD_SIZE.x + 80.0), 0
	)
	panel.size = CARD_SIZE
	panel.add_theme_stylebox_override("panel", _style())
	var head := _label(FONT_TITLE, TEXT)
	head.position = Vector2(32, 24)
	head.size = Vector2(CARD_SIZE.x - 64, 56)
	head.text = "%s — %s" % [String(roster.id).to_upper(), roster.title]
	panel.add_child(head)
	var body := _label(FONT, MUTED)
	body.position = Vector2(32, 108)
	body.size = Vector2(CARD_SIZE.x - 64, CARD_SIZE.y - 140)
	body.text = "%s\n\n%s" % [roster.difference, _names(roster)]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(body)
	var card := {"id": String(roster.id), "panel": panel, "head": head, "body": body}
	_cards.append(card)
	return panel


func _names(roster: RosterData) -> String:
	var names: Array[String] = []
	for stats in roster.units:
		names.append(stats.display_name)
	return " · ".join(names)


func _highlight() -> void:
	for index in _cards.size():
		var style: StyleBoxFlat = _cards[index]["panel"].get_theme_stylebox("panel")
		style.border_color = GOLD if index == _selected else Color(0.35, 0.3, 0.2, 1.0)
		style.set_border_width_all(4 if index == _selected else 2)


func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 0.95)
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.3, 0.2, 1.0)
	return style


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _rect(size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.color = color
	return rect
