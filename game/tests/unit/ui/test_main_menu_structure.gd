extends BaseTest
const _Scene := preload("res://scenes/main_menu.tscn")

## Порядок колонки по макету 09 (ui-mockup-parity, шаг 3) — сверяется построчно.
const MOCKUP_ORDER := [
	"NewGameButton", "ContinueButton", "SettingsButton", "CreditsButton", "ExitButton",
]

var _menu: Node = null

func after_test() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
	_menu = null

func _spawn() -> MainMenu:
	var m: MainMenu = _Scene.instantiate()
	_menu = m
	get_tree().root.add_child(m)
	await get_tree().process_frame
	return m

func test_main_menu_column_has_five_buttons() -> void:
	var ui := await _spawn()
	var col: Node = ui.get_node_or_null("RightColumn")
	assert_object(col).is_not_null()
	var names: Array = []
	for child in col.get_children():
		names.append(child.name)
	assert_array(names).is_equal(MOCKUP_ORDER).override_failure_message(
		"колонка меню обязана совпадать с макетом 09 по составу и порядку: %s" % [names])
	assert_int(col.get_child_count()).is_equal(5).override_failure_message("ровно 5 кнопок, без Spacer")

func test_main_menu_removed_buttons_absent() -> void:
	var ui := await _spawn()
	var col: Node = ui.get_node_or_null("RightColumn")
	for name in ["ArenaButton", "ModelWarriorButton", "ModelMageButton",
			"ChronicleButton", "LoadGameButton", "Spacer"]:
		assert_object(col.get_node_or_null(name)).is_null().override_failure_message("%s должен быть убран из меню" % name)

func test_main_menu_version_and_lock_on_root() -> void:
	var ui := await _spawn()
	assert_object(ui.get_node_or_null("VersionLabel")).is_not_null()
	assert_object(ui.get_node_or_null("LockPanel")).is_not_null()

func test_main_menu_signals_and_locale() -> void:
	var ui := await _spawn()
	assert_str(ui._loc()).is_equal(TranslationServer.get_locale())
	var settings: Node = ui.get_node_or_null("SettingsScreen")
	assert_object(settings).is_not_null()
	assert_bool(settings.has_signal("arena_requested")).is_true()
	assert_bool(settings.has_signal("chronicle_requested")).is_true()
	assert_bool(settings.has_signal("model_requested")).is_true()
	assert_bool(ui._on_arena.is_valid()).is_true()
	assert_bool(ui._on_chronicle.is_valid()).is_true()
	assert_bool(ui._on_model_variant.is_valid()).is_true()

func test_main_menu_continue_button_state() -> void:
	var ui := await _spawn()
	assert_bool(ui._continue_btn != null).is_true()
	# Cutover-проводка (раунд 6, T-110): Continue — кампанийный MVP-слот 1.
	assert_bool(ui._continue_btn.disabled).is_equal(not MvpSaveManager.has_save_in_slot(1))

func test_game_text_new_keys_localized() -> void:
	assert_str(GameText.menu_continue()).is_not_empty()
	assert_str(GameText.menu_credits()).is_not_empty()
	assert_str(GameText.settings_additional()).is_not_empty()
	assert_str(GameText.settings_button_arena()).is_not_empty()
	assert_str(GameText.settings_button_chronicle()).is_not_empty()
	assert_str(GameText.settings_button_model()).is_not_empty()


## ui-mockup-parity, шаг 3 (треб. «Кнопки стартового экрана»): нажатие доступного
## пункта ведёт в существующую сцену — цели перехода проверяются на существование
## файла сцены; сам переход живьём покрыт MCP e2e (test_full_cycle).
func test_main_menu_navigation_targets_exist() -> void:
	assert_bool(ResourceLoader.exists(MainMenu.SCENE_CONTINUE)).is_true().override_failure_message(
		"«Продолжить» ведёт в несуществующую сцену: %s" % MainMenu.SCENE_CONTINUE)
	var new_game_target: String = MainMenu._CharacterCreation.resource_path
	assert_bool(ResourceLoader.exists(new_game_target)).is_true().override_failure_message(
		"«Новая игра» ведёт в несуществующую сцену: %s" % new_game_target)


## Пункт без носителя: отключён, нажатие не меняет сцену (отличается не только цветом —
## снятые рамка и тень проверяются снимком, см. docs/mockups/after/09).
func test_main_menu_disabled_item_does_not_navigate() -> void:
	var ui := await _spawn()
	assert_bool(ui._credits_btn.disabled).is_true().override_failure_message(
		"«Титры» обязаны быть отключены: экрана-носителя нет (Т-133)")
	var before: Node = get_tree().current_scene
	ui._credits_btn.emit_signal("pressed")
	await get_tree().process_frame
	assert_object(get_tree().current_scene).is_equal(before).override_failure_message(
		"нажатие отключённого пункта не должно менять сцену")

## UI-3 шаг 3 (AC6): «Выход» — не кликабельна; доступные пункты остаются доступными
## (иначе «отключено» ничего не проверяет: отключённым в колонке может быть всё).
func test_main_menu_button_disabled_states() -> void:
	var ui := await _spawn()
	assert_bool(ui._exit_btn.disabled).is_true().override_failure_message(
		"«Выход» обязана быть отключена (AC6): выход из игры — не кликом по меню")
	assert_bool(ui._new_game_btn.disabled).is_false()
	assert_bool(ui._settings_btn.disabled).is_false()


## UI-3 шаг 3: нажатие доступного пункта доходит до обработчика — экран настроек
## становится видимым (узел — CanvasItem; слой или контрол — не проверяем).
func test_main_menu_settings_press_shows_screen() -> void:
	var ui := await _spawn()
	var layer: CanvasItem = ui.get_node("SettingsScreen")
	layer.visible = false
	ui._settings_btn.emit_signal("pressed")
	await get_tree().process_frame
	assert_bool(layer.visible).is_true().override_failure_message(
		"нажатие «Настройки» не открыло экран настроек")


## UI-3 шаг 3 (макет 09): титульный леттеринг — три строки по центру кадра, верхний
## регистр, разбивка «первое / середина / последнее». Тест поймал `split(" ", false,
## true)`: третьим аргументом в Godot 4 идёт max_splits, а не case_sensitive, и заголовок
## резался один раз — «OF THE UNWILLING» одной строкой вместо двух.
func test_main_menu_title_splits_into_three_lines() -> void:
	var ui := await _spawn()
	var lines: Array = []
	for line in ui._title_lines:
		lines.append(line.text)
	assert_array(lines).is_equal(["SIGIL", "OF THE", "UNWILLING"]).override_failure_message(
		"титул раскладывается по макету 09: первое / середина / последнее, в верхнем регистре")
	for line in ui._title_lines:
		assert_bool(line.visible).is_true().override_failure_message(
			"непустая строка титула не должна прятаться")


## Одно слово — только первая строка; два слова — средняя пустая и скрыта. Иначе
## пустой Label резервирует место и рвёт вертикальный ритм титула.
func test_main_menu_title_short_titles() -> void:
	var ui := await _spawn()
	ui._set_title("Sigil")
	assert_bool(ui._title_lines[0].visible).is_true()
	assert_bool(ui._title_lines[1].visible).is_false()
	assert_bool(ui._title_lines[2].visible).is_false()
	ui._set_title("Sigil Unwilling")
	assert_array([ui._title_lines[0].text, ui._title_lines[1].text, ui._title_lines[2].text]) \
		.is_equal(["SIGIL", "", "UNWILLING"])
	assert_bool(ui._title_lines[1].visible).is_false()


## ── Инвариант T-299: у каждого обработчика меню есть проводка ──────────────
##
## Мёртвый блок выбора героя жил месяц ровно потому, что сторожем в нём стоял
## `get_node_or_null("HeroSelection")`: отсутствующий узел, незаполненное поле и
## несоединённый обработчик выглядят одинаково — молчанием. `signal hero_selected`
## не эмитился никогда, коннекторов к нему в репозитории не было, а читающий файл
## считал выбор героя частью меню. Проверка ниже делает то же наблюдение
## измеримым для всего файла: обработчик без `.connect(` красен.
const _MENU_SOURCE := "res://scripts/ui/main_menu.gd"

## Единственные разрешённые молчуны — с тикетом-владельцем. Список красен и в другую
## сторону: если проводка появится, устаревшая строка красна так же, как мёртвый
## обработчик (иначе allowlist превращается в кладбище).
const _SILENCE_ALLOWED := {
	"_on_load_game": "T-307 (экран 3 слотов без точки входа)",
}


func _source_lines() -> PackedStringArray:
	var f := FileAccess.open(_MENU_SOURCE, FileAccess.READ)
	assert_object(f).is_not_null().override_failure_message(
		"не читается %s — проверка проводки не может измерить ничего" % _MENU_SOURCE)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n", false)


func _ident_chars(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")


## Имена `_on_…` внутри строки (connect-сайты пишут и `x.pressed.connect(_on_x)`,
## и `Callable(self, "_on_x")`, и `is_connected(_on_x)`).
func _handlers_named(line: String) -> Array:
	var out: Array = []
	var i := 0
	while i < line.length():
		var j := line.find("_on_", i)
		if j < 0:
			break
		var k := j
		while k < line.length() and _ident_chars(line[k]):
			k += 1
		out.append(line.substr(j, k - j))
		i = k if k > j else j + 4
	return out


func test_main_menu_every_handler_is_connected() -> void:
	var defined: Array = []
	var wired := {}
	for line in _source_lines():
		var s := line.strip_edges()
		if s.begins_with("func _on_"):
			var open := s.find("(")
			if open > 0:
				defined.append(s.substr(5, open - 5))
		elif s.contains(".connect(") or s.contains("Callable(") or s.contains("is_connected("):
			for name in _handlers_named(s):
				wired[name] = true
	# Санитарная граница: пустой список определений означал бы, что разбор сломался,
	# и тогда «сирот нет» было бы зелёной ложью (тот же класс молчания, что и предмет
	# проверки).
	assert_int(defined.size()).is_greater_equal(10).override_failure_message(
		"разбор %s нашёл лишь %d обработчик(ов) — проверка больше ничего не измеряет"
		% [_MENU_SOURCE, defined.size()])
	var orphans: Array = []
	for name in defined:
		if not wired.has(name) and not _SILENCE_ALLOWED.has(name):
			orphans.append(name)
	assert_array(orphans).is_equal([]).override_failure_message(
		"обработчики меню без проводки (T-299): %s — либо соединить, либо снять блок, "
		% [orphans]
		+ "либо вписать в _SILENCE_ALLOWED с номером тикета, который ждёт носителя")


## Allowlist гниёт в обе стороны: строка живёт ровно до появления проводки.
func test_main_menu_silence_allowlist_is_not_stale() -> void:
	var wired := {}
	for line in _source_lines():
		var s := line.strip_edges()
		if s.contains(".connect(") or s.contains("Callable(") or s.contains("is_connected("):
			for name in _handlers_named(s):
				wired[name] = true
	for name in _SILENCE_ALLOWED:
		assert_bool(wired.has(name)).is_false().override_failure_message(
			"%s соединён — строка %s в _SILENCE_ALLOWED устарела (сними её)"
			% [name, _SILENCE_ALLOWED[name]])


## Снятый блок не должен возвращаться половинчато: узла в сцене нет, и код больше
## его не ищет. Проверка с двух сторон, потому что `get_node_or_null` не краснеет
## ни при каком из этих расхождений.
func test_main_menu_hero_selection_api_is_gone() -> void:
	var src := ""
	for line in _source_lines():
		src += line + "\n"
	for leftover in ["hero_selected", "_hero_selection", "_selected_hero", "HeroSelection"]:
		assert_bool(src.contains(leftover)).is_false().override_failure_message(
			"в %s остался след снятого выбора героя: %s (T-299; носителя в сцене нет)"
			% [_MENU_SOURCE, leftover])
	var ui := await _spawn()
	assert_object(ui.get_node_or_null("HeroSelection")).is_null().override_failure_message(
		"узел HeroSelection появился в сцене, а проводки к нему по-прежнему нет")

