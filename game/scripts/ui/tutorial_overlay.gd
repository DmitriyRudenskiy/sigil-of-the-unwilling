class_name TutorialOverlay
extends CanvasLayer

## mvp-ui-flow 2.2: туториал-оверлей первых ходов. K-M8 (07-ui-ux) держит его
## как **оверлей, а не экран**: у него нет своего состояния, навигационного
## узла и места в списке восьми экранов — только модалка поверх того экрана,
## куда игрок зашёл первым.
##
## Носитель содержимого — `campaign.json → tutorial.day_N` («строка-директива»,
## как её называет инвариант reachability в `mvp_invariants.gd`): до этого среза
## блок был писателем без читателя — его читал только инвариант, и то по
## подстроке «руин», чтобы узнать, к какому дню должны поспеть руины.
##
## Почему директива дня, а не «справка по экрану»: текста про экраны в репо нет
## ни в одном носителе (ни в данных, ни в гайде), и сочинять его здесь — значит
## изобретать канон. Директива первых дней уже канон (M3: день 1 — ферма и
## казармы, день 2 — тренировка воина, день 3 — руины), уже привязана к дням и
## уже связана с инвариантом досягаемости.
##
## Семантика «один раз» живёт в двух местах и отвечает разным вещам:
##   - `CampaignNavigation._tutorial_shown` — «не показывать туториал **экрана**
##     повторно» (спека mvp-ui-flow: «* → TUTORIAL SHALL trigger on first entry
##     to a screen (once)»), персистится в сейве;
##   - `_shown_days` здесь — «одну и ту же директиву не показывать дважды»:
##     закрыл город → вернулся на карту, это первый вход в карту, а содержимое
##     то же. Второй модалки с той же строкой за один день игрок не заслужил.
##     В сейв это не пишется: после загрузки сохранения директива может
##     повториться один раз на ещё не открытом экране — цена отсутствия
##     четвёртого под-ключа в схеме сейва.

signal dismissed(day: int)

## Выше хроники (у `chronicle_screen.tscn` `layer = 120`): директива обязана
## догнать игрока и на открытой ленте, иначе «первый вход в экран» пройдёт под
## экраном и оверлей останется невидимкой.
const OVERLAY_LAYER := 130

## Ширина карточки — кратная 8 (гайд §4, сетка); высота — по содержимому.
const CARD_WIDTH := 560.0

## Уже показанные директивы (день → true). См. заголовок файла.
var _shown_days: Dictionary = {}
var _day_label: Label = null
var _directive_label: Label = null
var _current_day: int = -1


func _ready() -> void:
	_build()


## Показать директиву дня. Возвращает false, если показывать нечего: пустая
## строка (директив кончились — после третьего дня) или этот день уже показан.
func try_show(day: int, directive: String) -> bool:
	if day < 1 or directive == "":
		return false
	if _shown_days.has(day):
		return false
	_day_label.text = GameText.campaign_goal_day(day)
	_directive_label.text = directive
	_current_day = day
	_shown_days[day] = true
	visible = true
	return true


func is_open() -> bool:
	return visible


## День текущей показанной директивы (-1 — оверлей закрыт).
func directive_day() -> int:
	return _current_day


## Текст показанной директивы ("" — оверлей закрыт).
func directive_text() -> String:
	return _directive_label.text if visible else ""


## Заголовок показанной директивы («День N»; "" — оверлей закрыт).
func directive_title() -> String:
	return _day_label.text if visible else ""


## Показанные дни (тесты и хост читают то же, что видит игрок).
func shown_days() -> Array:
	return _shown_days.keys()


func dismiss() -> void:
	if not visible:
		return
	var day := _current_day
	visible = false
	_current_day = -1
	dismissed.emit(day)


func _build() -> void:
	name = "TutorialOverlay"
	layer = OVERLAY_LAYER
	visible = false
	# Домашний паттерн модалки (city_screen/ScreenShade, chronicle_screen/Root):
	# полноэкранный Control, затемнение, карточка по центру.
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Пока директива не закрыта, кампания кликов не принимает: оверлей — модальный
	# намёк, а не плашка поверх игры.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	root.add_child(background)
	var card := PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = &"PanelCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	# Центрирование — якорями, а не size flags: родителя-контейнера у карточки
	# нет (она лежит на полноэкранном Control), поэтому `size_flags_*` не сработал
	# и карточка оставалась в (0,0) — брак поймали кадры ux-review.
	# `GROW_DIRECTION_BOTH` по обеим осям держит её по центру и при росте высоты: высота
	# контентная (директива переносится), фиксировать её нельзя.
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(card)
	var column := VBoxContainer.new()
	column.name = "DirectiveColumn"
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	_day_label = Label.new()
	_day_label.name = "DirectiveDay"
	_day_label.theme_type_variation = &"LabelStrong"
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_day_label)
	_directive_label = Label.new()
	_directive_label.name = "DirectiveText"
	_directive_label.theme_type_variation = &"LabelBody"
	_directive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_directive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_directive_label)
	var button := Button.new()
	button.name = "DismissButton"
	button.text = GameText.ui_close()
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(dismiss)
	column.add_child(button)
