extends Node
const GameLogger := preload("res://scripts/core/game_logger.gd")

## Главная сцена игры - координирует менеджеры и игровой цикл.
## T-010 пост-условие (12-я итерация): campaign-слой — composition root
## (CampaignComposition, 14-я раунд 4: та же проводка у main.gd и у
## cutover-композита D-157); каждый тик дня = 1 ход кампании.
## I1: seed = seed кампании (CAMPAIGN_SEED).

@export var day_duration: float = 3.0

const CAMPAIGN_SEED: int = 12345  # I1: seed = seed кампании
var composition: CampaignComposition
var _day_timer: float = 0.0
var _is_day_cycle_active: bool = true
## Экран города открыт — кампейн-время стоит (тот же приём, что пауза на
## кризисе: игрок не теряет ходы, пока разбирается с застройкой).
var _city_screen_paused: bool = false

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager
@onready var day_label: Label = $CanvasLayer/DayLabel if has_node("CanvasLayer/DayLabel") else null
@onready var campaign_hud: CampaignHud = $CampaignHUD/CampaignHud if has_node("CampaignHUD/CampaignHud") else null
## Машина навигации кампании (mvp-ui-flow K-M8): один активный экран. Снимается
## с узла, а не создаётся кодом: сцена — носитель состава кампании.
@onready var campaign_ui_manager: CampaignUIManager = $CampaignUIManager if has_node("CampaignUIManager") else null


func _ready():
	_connect_ui()
	_init_campaign()
	GameLogger.info("Игра запущена. День: %d" % game_manager.get_current_day(), "Main")


## T-010 пост-условие: campaign-слой. Проводка систем, шов T-050, ledger
## Престижа, сборка сейва T-110 и победная оценка — в CampaignComposition
## (единый корень: раннер D-157 проверяет ту же игру, что видит игрок).
func _init_campaign() -> void:
	composition = CampaignComposition.from_campaign_config(CAMPAIGN_SEED)
	# Q-M78 → (а), D-197: канал настроения каталога событий (morale_change /
	# morale_penalty) сводится на настроение поселения 02g — DistrictSystem
	# composition-корня. Поле player_data["morale"] в GameManager снято.
	if game_manager != null and game_manager.event_system != null:
		game_manager.event_system.mood_sink = composition.districts
	_apply_pending_flow()
	# Кампания начинается на карте: без этого шага машина осталась бы на
	# PREGAME, и переход в город был бы запрещён.
	if campaign_ui_manager != null:
		campaign_ui_manager.begin_campaign()
	_mount_campaign_hud()


## Pending-состояния создания игры (имя героя, Знак, слот Continue). Отделены
## от подъёма HUD: Continue подменяет composition.city восстановленным из
## сейва, поэтому слой привязывается строго после этого шага.
func _apply_pending_flow() -> void:
	var persistence: WorldPersistence = Services.resolve(&"persistence")
	if persistence == null:
		return
	# Проводка T-110 (cutover, раунд 6): профиль из создания доходит до
	# кампании (hero_name — в сейв-секцию campaign); sign-слой (T-020) — за срезом.
	if persistence.pending_new_game != null:
		composition.hero_name = persistence.pending_new_game.name
		persistence.pending_new_game = null
	# T-002 «Выбор знака»: Знак новой кампании (SignChoiceUI); "" — вне UI-пути
	# (раннер D-157, тесты) — знак-механики в MVP нет, кампания работает без него.
	if persistence.pending_sign_id != "":
		composition.set_sign(persistence.pending_sign_id)  # T-124: знак = и этический референс
		persistence.pending_sign_id = ""
	# Continue: кампанийный MVP-слот → load_save_state (схема T-110).
	if persistence.pending_campaign_slot >= 0:
		var result: Dictionary = MvpSaveManager.load_slot(persistence.pending_campaign_slot)
		persistence.pending_campaign_slot = -1
		if result.get("ok", false):
			composition.load_save_state(result.get("state", {}))


## Носитель экрана города в игровом пути (ui-mockup-parity §7.1; носитель
## выбран владельцем: Q-M87 → (б), D-204 — новый слой HUD на main.tscn, а не
## реанимация архивного world.tscn). До этого слоя CityScreen был сценой без
## вызывающего: из «Новой игры» в него было попасть нечем.
func _mount_campaign_hud() -> void:
	if campaign_hud == null or composition == null:
		return
	# ГСЧ экрана — из seed кампании (I1: своей энтропии не добавляем), иначе —
	# null: броски событий города тогда идут без источника случайности, как в
	# архивном мире без героя.
	var city_rng := RandomNumberGenerator.new()
	city_rng.seed = int(composition.campaign.seed)
	# Порядок обязателен: экран регистрируется в машине внутри `bind_city`,
	# поэтому менеджер привязывается раньше.
	campaign_hud.bind_ui_manager(campaign_ui_manager)
	campaign_hud.bind_city(composition.city, city_rng)
	campaign_hud.city_screen_opened.connect(_on_city_screen_opened)
	campaign_hud.city_screen_closed.connect(_on_city_screen_closed)


func _connect_ui():
	if game_manager:
		game_manager.day_passed.connect(_on_day_passed)
		game_manager.crisis_started.connect(_on_crisis_started)
		game_manager.crisis_ended.connect(_on_crisis_ended)


func _process(delta: float):
	if not _is_day_cycle_active or _city_screen_paused or game_manager.is_crisis_active_now():
		return
	_day_timer += delta
	if _day_timer >= day_duration:
		_day_timer = 0.0
		_advance_day()


func _advance_day():
	# Ход кампании (T-010): settlement (авто) → player → threats (авто).
	# I1: сезон синхронизирован с ходом драйвера — внутри advance_turn().
	if composition != null:
		composition.advance_turn()
	if game_manager:
		game_manager.on_day_passed()
	if day_label:
		day_label.text = "День: %d" % game_manager.get_current_day()


func _on_day_passed(day: int):
	GameLogger.world("Наступил день %d" % day)


func _on_crisis_started(crisis_id: String):
	_is_day_cycle_active = false
	GameLogger.warn("КРИЗИС НАЧАЛСЯ: %s" % crisis_id, "Main")


func _on_crisis_ended(crisis_id: String, resolved: bool):
	_is_day_cycle_active = true
	GameLogger.info("Кризис завершен: %s" % ("успешно" if resolved else "провалено"), "Main")


func _on_city_screen_opened() -> void:
	_city_screen_paused = true


func _on_city_screen_closed() -> void:
	_city_screen_paused = false
