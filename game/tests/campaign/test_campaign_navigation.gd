extends BaseTest
## mvp-ui-flow 5.1 (K-M8): GdUnit4 — SM навигации.
## PREGAME→MENU→MAP→(CITY/BATTLE/PARTY/CHRONICLE/SETTINGS); BATTLE→MAP;
## MAP→ХРОНИКА anytime; *→TUTORIAL 1 раз; «закрыть в никуда» отсутствует.

const Nav = preload("res://scripts/ui/campaign_navigation.gd")

const PREGAME := Nav.Screen.PREGAME
const MENU := Nav.Screen.MENU
const MAP := Nav.Screen.MAP
const CITY := Nav.Screen.CITY
const BATTLE := Nav.Screen.BATTLE
const PARTY := Nav.Screen.PARTY
const CHRONICLE := Nav.Screen.CHRONICLE
const SETTINGS := Nav.Screen.SETTINGS


func _nav() -> CampaignNavigation:
	return Nav.new()


## === Путь PREGAME → MENU → MAP ===

func test_starts_at_pregame() -> void:
	var nav := _nav()
	assert_int(nav.current).is_equal(PREGAME)


func test_pregame_to_menu() -> void:
	var nav := _nav()
	var r: Dictionary = nav.request(MENU)
	assert_bool(r["ok"]).is_true()
	assert_int(nav.current).is_equal(MENU)


func test_menu_to_map() -> void:
	var nav := _nav()
	nav.request(MENU)
	var r: Dictionary = nav.request(MAP)
	assert_bool(r["ok"]).is_true()
	assert_int(nav.current).is_equal(MAP)


func test_pregame_cannot_jump_to_map() -> void:
	var nav := _nav()
	var r: Dictionary = nav.request(MAP)
	assert_bool(r["ok"]).is_false()
	assert_int(nav.current).is_equal(PREGAME)


## === MAP — хаб: переходы во все под-экраны ===

func test_map_to_all_subscreens() -> void:
	var nav := _nav()
	nav.begin()
	nav.request(MENU)
	nav.request(MAP)
	for to: int in [CITY, BATTLE, PARTY, CHRONICLE, SETTINGS]:
		var n2 := _nav()
		n2.begin()
		n2.request(MENU)
		n2.request(MAP)
		var r: Dictionary = n2.request(to)
		assert_bool(r["ok"]).is_true().override_failure_message("MAP → %d" % to)
		assert_int(n2.current).is_equal(to)


func test_map_cannot_go_to_menu() -> void:
	var nav := _nav()
	nav.begin()
	nav.request(MENU)
	nav.request(MAP)
	var r: Dictionary = nav.request(MENU)
	assert_bool(r["ok"]).is_false()


## === Возврат в MAP из под-экранов ===

func test_subscreens_return_to_map() -> void:
	for sub: int in [CITY, BATTLE, PARTY, CHRONICLE, SETTINGS]:
		var nav := _nav()
		nav.begin()
		nav.request(MENU)
		nav.request(MAP)
		nav.request(sub)
		var r: Dictionary = nav.request(MAP)
		assert_bool(r["ok"]).is_true().override_failure_message("sub %d → MAP" % sub)
		assert_int(nav.current).is_equal(MAP)


## === BATTLE → MAP только («Продолжить», K-M8) ===

func test_battle_only_exit_is_map() -> void:
	var nav := _nav()
	nav.begin()
	nav.request(MENU)
	nav.request(MAP)
	nav.request(BATTLE)
	assert_bool(nav.can_go(MAP)).is_true()
	# Никуда, кроме MAP, из боя не уйти («закрыть в никуда» отсутствует).
	for to: int in [PREGAME, MENU, CITY, PARTY, CHRONICLE, SETTINGS]:
		assert_bool(nav.can_go(to)).is_false().override_failure_message("BATTLE → %d" % to)


## === MAP → ХРОНИКА anytime ===

func test_map_to_chronicle_anytime() -> void:
	# Хроника доступна из MAP в любой момент, сколько раз угодно.
	var nav := _nav()
	nav.begin()
	nav.request(MENU)
	nav.request(MAP)
	for i: int in range(3):
		var r: Dictionary = nav.request(CHRONICLE)
		assert_bool(r["ok"]).is_true().override_failure_message("round %d" % i)
		assert_int(nav.current).is_equal(CHRONICLE)
		nav.request(MAP)


## === * → TUTORIAL на первый вход (1 раз) ===

func test_tutorial_fires_on_first_entry_only() -> void:
	var nav := _nav()
	var fired: Array = []
	nav.tutorial_requested.connect(func(s: int) -> void: fired.append(s))
	nav.begin()  # PREGAME — первый вход
	assert_bool(nav.tutorial_needed(PREGAME)).is_false()
	nav.request(MENU)
	nav.request(MAP)
	# Каждый экран — ровно один туториал.
	assert_int(fired.size()).is_equal(3)
	assert_bool(fired.has(PREGAME)).is_true()
	assert_bool(fired.has(MENU)).is_true()
	assert_bool(fired.has(MAP)).is_true()
	# Повторный вход в MAP — без туториала.
	nav.request(CHRONICLE)
	nav.request(MAP)
	assert_int(fired.size()).is_equal(4)  # +CHRONICLE
	assert_int(fired.filter(func(s: int) -> bool: return s == MAP).size()).is_equal(1)


func test_begin_fires_initial_tutorial_once() -> void:
	var nav := _nav()
	assert_bool(nav.begin()).is_true()
	# Второй вызов begin (напр. после перезагрузки) — туториал уже показан.
	nav._tutorial_shown.clear()
	nav.mark_tutorial_shown(PREGAME)
	assert_bool(nav.begin()).is_false()


func test_tutorial_result_flag_in_request() -> void:
	var nav := _nav()
	nav.begin()
	nav.request(MENU)
	var r1: Dictionary = nav.request(MAP)
	assert_bool(r1["tutorial"]).is_true()
	nav.request(CHRONICLE)
	nav.request(MAP)
	var r2: Dictionary = nav.request(CHRONICLE)
	assert_bool(r2["tutorial"]).is_false()


## === Инвариант: «закрыть в никуда» отсутствует ===

func test_every_state_has_exit() -> void:
	for screen: int in [PREGAME, MENU, MAP, CITY, BATTLE, PARTY, CHRONICLE, SETTINGS]:
		var nav := _nav()
		nav.current = screen
		assert_bool(nav.has_exit()).is_true().override_failure_message("screen %d" % screen)


## === Сейв/загрузка ===

func test_save_load_roundtrip() -> void:
	var nav := _nav()
	nav.begin()
	nav.request(MENU)
	nav.request(MAP)
	nav.request(CITY)
	var data: Dictionary = nav.to_dict()
	var restored: CampaignNavigation = Nav.from_dict(data)
	assert_int(restored.current).is_equal(CITY)
	assert_bool(restored.tutorial_needed(CITY)).is_false()
	assert_bool(restored.tutorial_needed(BATTLE)).is_true()


func test_from_dict_empty_is_fresh() -> void:
	var nav: CampaignNavigation = Nav.from_dict({})
	assert_int(nav.current).is_equal(PREGAME)
	assert_bool(nav.tutorial_needed(PREGAME)).is_true()
