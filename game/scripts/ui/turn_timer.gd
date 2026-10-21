class_name TurnTimer
extends Control

# Шаг 5.3 (макет боевого HUD): таймер хода — золотое кольцо, дуга убывает вместе с
# остатком времени, в центре число секунд.
#
# Носитель — `BattleState.turn_time_left` (тикает из BattleController._process),
# поэтому здесь только отображение: ни правил, ни собственного отсчёта.
# Режим без ограничения (`turn_time_limit <= 0`) — трек без дуги и прочерк вместо
# числа: элемент честно показывает «таймера нет», а не ноль вместо данных
# (правило «никаких фейковых чисел», docs/14 §3).

const RING_TRACK := ThemeConfig.C_PANEL_BG
# Шкала состояний макета (docs/17-ui-style-guide §1.2, docs/14 §«Зоны лестницы»):
# #c9a227 → нейтральный → #e05a4a; последние секунды — алый.
const RING_FILL := Color("#c9a227")  # C_GOLDEN
const RING_LOW := Color("#e05a4a")   # C_DANGER-ступень шкалы
const RING_WIDTH := 8.0
const RING_GLOW := 20.0
const RING_EDGE := Color("#f6e2b0")   # светлая кромка кольца макета (замер 255,249,226)
const RING_DISC := Color(0.06, 0.04, 0.02, 0.55)  # тёмный диск под числом
const LOW_SECONDS := 5

var seconds_left: int = 0
var limit: int = 0
var running: bool = false
var _painted: bool = false

@onready var _num: Label = get_node_or_null("num") as Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _num != null:
		_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_state(float(limit), limit, running)


# Единственная точка входа из контроллера: остаток, лимит режима, идёт ли отсчёт.
# Дёргается каждый кадр — перерисовка гасится, пока видимые значения не изменились.
func set_state(seconds: float, p_limit: int, p_running: bool) -> void:
	var s: int = int(ceil(seconds))
	if _painted and s == seconds_left and p_limit == limit and p_running == running:
		return
	_painted = true
	seconds_left = s
	limit = p_limit
	running = p_running
	if _num != null:
		_num.text = str(seconds_left) if limit > 0 else "—"
		_num.modulate = RING_LOW if (limit > 0 and seconds_left <= LOW_SECONDS) \
			else ThemeConfig.C_TEXT_GOLD_SOFT
	queue_redraw()


func _draw() -> void:
	var w: float = minf(size.x, size.y)
	if w <= RING_WIDTH * 2.0:
		return
	var center := size * 0.5
	# Макет 11: кольцо двойное — тонкая светлая кромка по внешнему краю и
	# рабочая дуга остатка внутри, между ними тёмный диск под числом.
	var outer: float = w * 0.5 - 2.0
	var radius: float = outer - RING_WIDTH - 3.0
	draw_circle(center, radius - RING_WIDTH * 0.5, RING_DISC)
	draw_arc(center, outer, 0.0, TAU, 96, Color(RING_EDGE, 0.75), 2.0, true)
	draw_arc(center, radius, 0.0, TAU, 96, RING_TRACK, RING_WIDTH, true)
	if limit <= 0:
		return
	var frac: float = clampf(float(seconds_left) / float(maxi(1, limit)), 0.0, 1.0)
	if frac <= 0.0:
		return
	var color := RING_LOW if seconds_left <= LOW_SECONDS else RING_FILL
	if not running:
		color.a = 0.55  # пауза (выбор цели, открытая книга) — кольцо гаснет, не врёт
	# Макет 11: кольцо светится — под тонкой дугой широкая полупрозрачная
	# дорожка того же цвета, без отдельного цвета и без отдельного носителя.
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * frac, 96, Color(color, 0.28), RING_GLOW, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * frac, 96, color, RING_WIDTH, true)
