extends Node
const GameLogger := preload("res://scripts/core/game_logger.gd")

## Главная сцена игры - координирует менеджеры и игровой цикл.
## T-010 пост-условие (12-я итерация): campaign-слой — composition root
## (CampaignComposition, 14-я раунд 4: та же проводка у main.gd и у
## cutover-композита D-157); каждый ход кампании = одно нажатие кнопки хода.
## I1: seed = seed кампании (CAMPAIGN_SEED).
##
## 7.13 (ui-mockup-parity, указание владельца 2026-10-23): авто-таймера дня нет.
## Раньше ход делался сам каждые `day_duration` секунд (`_process` + `_day_timer`);
## теперь единственный драйвер — кнопка хода слоя `CampaignHud` (её сигнал
## `turn_requested` подключён к `_advance_day`). Таймер убран, а не приостановлен:
## два драйвера одного хода — это гонка за дату и счётчики (игрок видел бы, как
## ход уходит под руками).

const CAMPAIGN_SEED: int = 12345  # I1: seed = seed кампании
## Главное меню — куда уходит кампания по кнопке «В меню» (mvp-ui-flow 5.4).
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
var composition: CampaignComposition
## Экран кампании открыт — кампейн-время стоит (тот же приём, что пауза на
## кризисе: игрок не теряет ходы, пока разбирается с застройкой или ростером).
## Снимает и доступность кнопки хода (7.13).
var _campaign_screen_paused: bool = false

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager
@onready var campaign_hud: CampaignHud = $CampaignHUD/CampaignHud if has_node("CampaignHUD/CampaignHud") else null
## Машина навигации кампании (mvp-ui-flow K-M8): один активный экран. Снимается
## с узла, а не создаётся кодом: сцена — носитель состава кампании.
@onready var campaign_ui_manager: CampaignUIManager = $CampaignUIManager if has_node("CampaignUIManager") else null

## Поле карты кампании (T-194): прод-вызывающий `MapScreenModel`. Узла может не
## быть в чужой сборке, поэтому проверка `has_node` обязательна.
@onready var campaign_map_field: CampaignMapField = (
	$CampaignMap/CampaignMapField if has_node("CampaignMap/CampaignMapField") else null)


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


## Носитель экранов кампании в игровом пути (ui-mockup-parity §7.1; носитель
## выбран владельцем: Q-M87 → (б), D-204 — новый слой HUD на main.tscn, а не
## реанимация архивного world.tscn). До этого слоя CityScreen был сценой без
## вызывающего, а PartyScreen — экраном без вызывающего: из «Новой игры» в них
## было попасть нечем.
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
	campaign_hud.bind_party(composition.party)
	campaign_hud.city_screen_opened.connect(_on_campaign_screen_opened)
	campaign_hud.city_screen_closed.connect(_on_campaign_screen_closed)
	campaign_hud.party_screen_opened.connect(_on_campaign_screen_opened)
	campaign_hud.party_screen_closed.connect(_on_campaign_screen_closed)
	campaign_hud.settings_screen_opened.connect(_on_campaign_screen_opened)
	campaign_hud.settings_screen_closed.connect(_on_campaign_screen_closed)
	campaign_hud.menu_requested.connect(_on_menu_requested)
	# mvp-ui-flow 5.4: настроек у живого кампейна не было — экран жил в меню и в
	# бою, а из кампании к нему не вело ничего.
	campaign_hud.bind_settings(Services.resolve(&"settings"))
	# D-240: хроника поселения. У ленты появился носитель (`ChronicleLog` в
	# кампании, пишется системами-событиями), поэтому у слоя появилась и кнопка:
	# до этого у игрока не было способа увидеть, что случилось с поселением.
	campaign_hud.bind_chronicle(composition.chronicle)
	campaign_hud.chronicle_screen_opened.connect(_on_campaign_screen_opened)
	campaign_hud.chronicle_screen_closed.connect(_on_campaign_screen_closed)
	# mvp-ui-flow 2.3 (T-182): панель целей первых трёх дней (M3). Логика трекера
	# была написана ещё в 5.2, но ни один скрипт её не вызывал: целей у игрока не
	# было видно. Привязка — после загрузки слота, чтобы панель смотрела на тот
	# трекер, который принёс сейв, а не на вытесненный им.
	campaign_hud.bind_goals(composition.goals)
	# signs-prestige 2.3: Престиж считался с волны 1, но носителя у него не было —
	# `prestige_rank_name()` не читал никто, кроме хроники (T-187). Плита Знака
	# печатает числа композиции, своих у слоя нет (D-200).
	campaign_hud.bind_sign(composition)
	# mvp-ui-flow 2.2 (T-186): директивы первых ходов. Их принёс хост: у слоя нет
	# права самому читать баланс-конфиг, а без директив оверлей молчит.
	campaign_hud.bind_tutorial(composition.tutorial_directives())
	# 7.13: ход кампании делается кнопкой слоя. Обработчик — тот же путь,
	# что был у таймера (`advance_turn` + `on_day_passed`), чтобы кнопка не
	# заводила второй порядок фаз.
	campaign_hud.turn_requested.connect(_advance_day)
	# T-194: поле карты привязывается к тому же регион-графу, что и сейв-срез —
	# после `_apply_pending_flow`, иначе Continue показал бы карту новой игры.
	if campaign_map_field != null:
		campaign_map_field.bind_map(composition.region_map)
		# Миникарта и сброс выбора (D-281, задача 3.7) читают поле, а не свою
		# копию графа: второй носитель позиции и выбора завёлся бы молча.
		campaign_hud.bind_map_field(campaign_map_field)
	_update_turn_availability()
	# Полоса счётчиков и дата — за носителем: первый вызов сразу после привязки
	# города, дальше — по сигналу дня (`_on_day_passed`). Своего счёта дней у HUD
	# нет (D-200).
	campaign_hud.refresh_campaign(game_manager.get_current_day())


func _connect_ui():
	if game_manager:
		game_manager.day_passed.connect(_on_day_passed)
		game_manager.crisis_started.connect(_on_crisis_started)
		game_manager.crisis_ended.connect(_on_crisis_ended)


## 7.13 — единственный источник доступности кнопки хода. Ход нельзя сделать,
## когда открыт экран кампании (время стоит) или идёт кризис (модальная панель).
## Кнопка выключается, а не исчезает: игрок видит элемент управления макета и
## причину, по которой он сейчас недоступен.
func _update_turn_availability() -> void:
	if campaign_hud == null or not is_instance_valid(campaign_hud):
		return
	var blocked := _campaign_screen_paused
	if game_manager != null and game_manager.is_crisis_active_now():
		blocked = true
	campaign_hud.set_turn_enabled(not blocked)


func _advance_day():
	# 7.13: ход делается по нажатию кнопки. Кризис — не ход: панель кризиса
	# модальна, а `on_day_passed` в это время двигал бы триггеры событий под
	# ней (так же таймер останавливался раньше).
	if game_manager != null and game_manager.is_crisis_active_now():
		return
	# Ход кампании (T-010): settlement (авто) → player → threats (авто).
	# I1: сезон синхронизирован с ходом драйвера — внутри advance_turn().
	if composition != null:
		composition.advance_turn()
	if game_manager:
		game_manager.on_day_passed()


func _on_day_passed(day: int):
	GameLogger.world("Наступил день %d" % day)
	# Счётчики и дата пересчитываются из носителя на каждый день — узел HUD
	# переживает и кризис, и ручной ход (7.13), поэтому сигнал `day_passed`
	# единственный источник обновления, а не `_advance_day`.
	if campaign_hud != null:
		campaign_hud.refresh_campaign(day)
	# Туман и позиция героя меняются каждый ход: поле перерисовывается по тому же
	# сигналу, что и счётчики, — своего таймера у него нет.
	if campaign_map_field != null:
		campaign_map_field.refresh()
	# Автосохранение хода (mvp-ui-flow 5.4): у переключателя «Автосохранение» до
	# этого шага не было читателя — настройка писалась экраном настроек и не
	# читалась никем, поэтому кампанийный слот в живом прохождении не создавался,
	# а «Продолжить» в меню оставался выключенным навсегда.
	_autosave_campaign()


## Запись кампанийного слота (T-110). Возвращает результат носителя —
## `{ok, message}` — чтобы вызывающий отличил отказ записи от успеха: молча
## проглоченная ошибка сейва значит потерянный ход, о котором игрок не знает.
func save_campaign_slot() -> Dictionary:
	if composition == null:
		return {"ok": false, "message": "campaign composition is not ready"}
	return MvpSaveManager.save_slot(
		MvpSaveManager.CAMPAIGN_SLOT, composition.build_save_state())


## Автосохранение по настройке: пишет только когда оно включено (по умолчанию
## выключено — `Settings.DEFAULT_AUTO_SAVE`), иначе переключатель снова стал бы
## декорацией.
func _autosave_campaign() -> void:
	var settings: Object = Services.resolve(&"settings")
	if settings == null or not bool(settings.auto_save):
		return
	var result: Dictionary = save_campaign_slot()
	if not bool(result.get("ok", false)):
		GameLogger.warn(
			"Автосохранение хода не записано: %s" % str(result.get("message", "")), "Main")


## Выход в главное меню (mvp-ui-flow 5.4). Сохраняется всегда, а не по
## переключателю: другого пути записать кампанию у игрока нет, а потерять
## прохождение из-за нажатия «В меню» — не фича, а дефект. Меню при этом
## открывается и с отказом записи (терять из-за ошибки диска саму возможность
## выйти — второе наказание); «Продолжить» просто останется выключенным.
func _on_menu_requested() -> void:
	var result: Dictionary = save_campaign_slot()
	if not bool(result.get("ok", false)):
		GameLogger.warn(
			"Кампания не сохранена при выходе в меню: %s" % str(result.get("message", "")),
			"Main")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_crisis_started(crisis_id: String):
	_update_turn_availability()
	GameLogger.warn("КРИЗИС НАЧАЛСЯ: %s" % crisis_id, "Main")


func _on_crisis_ended(crisis_id: String, resolved: bool):
	_update_turn_availability()
	GameLogger.info("Кризис завершен: %s" % ("успешно" if resolved else "провалено"), "Main")


func _on_campaign_screen_opened() -> void:
	_campaign_screen_paused = true
	_update_turn_availability()


func _on_campaign_screen_closed() -> void:
	_campaign_screen_paused = false
	_update_turn_availability()
