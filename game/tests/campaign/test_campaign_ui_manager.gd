extends BaseTest

## mvp-ui-flow (K-M8): CampaignUIManager — проводка SM навигации к экранам.
## Headless: экраны = Control-заглушки; проверяем show/hide, can_show (3.3),
## сигналы, инвариант одного активного экрана.

const M = preload("res://scripts/ui/campaign_ui_manager.gd")

var mgr: Node
var screens: Dictionary = {}


func _stub(id: StringName) -> Control:
	var c := Control.new()
	c.name = String(id)
	mgr.add_child(c)  # дети mgr → освобождаются вместе с ним (без orphan)
	screens[id] = c
	return c


func _register_all() -> void:
	for id in [&"pregame", &"menu", &"map", &"city",
			&"battle", &"party", &"chronicle", &"settings"]:
		mgr.register_screen(id, _stub(id))


func before_test() -> void:
	mgr = M.new()
	add_child(mgr)
	_register_all()


func after_test() -> void:
	mgr.queue_free()
	mgr = null
	screens.clear()


# --- базовое состояние ---

func test_initial_state() -> void:
	assert_str(mgr.current_screen()).is_equal("pregame")
	assert_int(mgr.visible_screens().size()).is_equal(0)  # все скрыты до show


# --- навигация по SM ---

func test_navigate_pregame_menu_map() -> void:
	var r1: Dictionary = mgr.show_screen(&"menu")
	assert_bool(r1["ok"]).is_true()
	assert_str(mgr.current_screen()).is_equal("menu")
	var r2: Dictionary = mgr.show_screen(&"map")
	assert_bool(r2["ok"]).is_true()
	assert_str(mgr.current_screen()).is_equal("map")


func test_navigate_map_to_subscreens_and_back() -> void:
	mgr.show_screen(&"menu")
	mgr.show_screen(&"map")
	for sub in [&"city", &"battle", &"party", &"chronicle", &"settings"]:
		var r: Dictionary = mgr.show_screen(sub)
		assert_bool(r["ok"]).is_true()
		assert_str(mgr.current_screen()).is_equal(String(sub))
		# из подэкрана — только в MAP
		var back: Dictionary = mgr.show_screen(&"map")
		assert_bool(back["ok"]).is_true()
		assert_str(mgr.current_screen()).is_equal("map")


func test_battle_only_to_map() -> void:
	mgr.show_screen(&"menu")
	mgr.show_screen(&"map")
	mgr.show_screen(&"battle")
	var to_city: Dictionary = mgr.show_screen(&"city")
	assert_bool(to_city["ok"]).is_false()
	assert_str(to_city["reason"]).is_equal("not_allowed")
	assert_str(mgr.current_screen()).is_equal("battle")  # не сменился


func test_show_unknown_screen() -> void:
	var r: Dictionary = mgr.show_screen(&"nope")
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("unknown_screen")


# --- can_show: инвариант «≤2 клика до причины» (3.3) ---

func test_can_show_current() -> void:
	var c: Dictionary = mgr.can_show(&"pregame")
	assert_bool(c["available"]).is_true()
	assert_str(c["reason"]).is_equal("current")


func test_can_show_allowed() -> void:
	var c: Dictionary = mgr.can_show(&"menu")
	assert_bool(c["available"]).is_true()
	assert_str(c["reason"]).is_equal("")


func test_can_show_not_allowed() -> void:
	# из PREGAME нельзя сразу в MAP
	var c: Dictionary = mgr.can_show(&"map")
	assert_bool(c["available"]).is_false()
	assert_str(c["reason"]).is_equal("not_allowed_from_pregame")


func test_can_show_unknown() -> void:
	var c: Dictionary = mgr.can_show(&"nope")
	assert_bool(c["available"]).is_false()
	assert_str(c["reason"]).is_equal("unknown_screen")


# --- инвариант одного активного экрана ---

func test_single_active_screen() -> void:
	mgr.show_screen(&"menu")
	mgr.show_screen(&"map")
	var vis: Array = mgr.visible_screens()
	assert_int(vis.size()).is_equal(1)
	assert_bool(vis.has(&"map")).is_true()
	assert_bool((screens[&"menu"] as CanvasItem).visible).is_false()
	assert_bool((screens[&"map"] as CanvasItem).visible).is_true()


# --- сигналы ---

func test_screen_changed_signal() -> void:
	var seen: Array = []
	mgr.screen_changed.connect(func(s: StringName) -> void: seen.append(s))
	mgr.show_screen(&"menu")
	mgr.show_screen(&"map")
	assert_int(seen.size()).is_equal(2)
	assert_bool(seen.has(&"menu")).is_true()
	assert_bool(seen.has(&"map")).is_true()


func test_tutorial_requested_first_entry() -> void:
	var seen: Array = []
	mgr.tutorial_requested.connect(func(s: StringName) -> void: seen.append(s))
	mgr.show_screen(&"menu")  # первый вход в MENU → туториал
	mgr.show_screen(&"map")   # первый вход в MAP → туториал
	mgr.show_screen(&"menu")  # MENU уже показывался (но из MAP нельзя в MENU)
	# вернёмся в MAP и снова — туториал не повторяется
	assert_bool(seen.has(&"menu")).is_true()
	assert_bool(seen.has(&"map")).is_true()
	# повторный вход в тот же экран не эмитит (проверим через CITY)
	mgr.show_screen(&"city")
	mgr.show_screen(&"map")
	mgr.show_screen(&"city")
	var city_count: int = 0
	for s in seen:
		if s == &"city":
			city_count += 1
	assert_int(city_count).is_equal(1)
