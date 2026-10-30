extends Control
class_name MainMenu

const _UIAnimator = preload("res://scripts/ui/ui_animator.gd")
const _CharacterCreation = preload("res://scenes/ui/character_creation.tscn")
const _HeroModelFactory = preload("res://scripts/ui/hero_model_factory.gd")

## Цель «Продолжить» (T-110) — кампанийная сцена; путь назван константой,
## чтобы тест проверял существование сцены-цели, а не строку наугад.
const SCENE_CONTINUE := "res://scenes/main/main.tscn"

@onready var _background: TextureRect = $Background
@onready var _continue_btn: Button = $RightColumn/ContinueButton
@onready var _new_game_btn: Button = $RightColumn/NewGameButton
@onready var _credits_btn: Button = $RightColumn/CreditsButton
@onready var _settings_btn: Button = $RightColumn/SettingsButton
@onready var _exit_btn: Button = $RightColumn/ExitButton
@onready var _version_label: Label = $VersionLabel
@onready var _title_lines: Array[Label] = [$TitleLine1, $TitleLine2, $TitleLine3]
@onready var _settings_screen: SettingsScreen = $SettingsScreen
@onready var _chronicle_screen: ChronicleScreen = $ChronicleScreen
@onready var _model_screen: ArtifactInventoryScreen = $HeroModelWindow
@onready var _save_load_screen: SaveLoadScreen = $SaveLoadScreen

func _ready() -> void:
    for arg in OS.get_cmdline_args():
        if arg.begins_with("--test-server"):
            return
    _load_background()
    _style_buttons()
    _localize()
    _connect_buttons()
    _connect_settings_extras()
    _refresh_continue_button()
    # Макет 09: пункт «Титры» есть, экрана-носителя нет — кнопка видена и отключена
    # (Т-133, Q-M90). Отличается от доступной не только цветом: см. _style_buttons.
    # Причина — на месте (mvp-ui-flow 3.3, столп 1): обесцвеченная плита без ответа
    # на «почему?» выглядит сломанной точкой входа, а не отложенным экраном.
    _credits_btn.disabled = true
    _credits_btn.tooltip_text = GameText.menu_credits_unavailable()
    # «Выход» выключена самим `.tscn` по AC6 макета 09 (UI-3 шаг 3: «выход из игры —
    # не кликом по меню»): пункт инертен намеренно и навсегда. Причина показывается
    # так же, как у временных пунктов, — иначе вечная серая плита читается багом.
    _exit_btn.tooltip_text = GameText.menu_exit_unavailable()
    _create_save_load_screen()
    _UIAnimator.animate_in(self)
    SoundManager.play_music_cue(&"music_menu")

func _load_background() -> void:
    var tex := _find_bg()
    if tex != null:
        _background.texture = tex
    else:
        _background.texture = _placeholder()

func _find_bg() -> Texture2D:
    # Пути только живые (docs/12-asset-audit.md, Missing): webp — канон фона
    # (docs/13 §8.4, 1920×1080 q85); jpeg/png-предки удалены после приёмки
    # webp (smoke-скрин меню, 2026-10-13); throne.png — последний fallback.
    # webp 2026-10-19 — художественное основание макета 09 (ui-mockup-parity,
    # шаг 3): роза из восьми медальонов, трон, туман; леттеринг больше не врос
    # в фон, он тремя узлами TitleLine1…3 (см. _set_title). Провенанс кадра —
    # concept_art/manifest.json, krea2/t4_painterly/ui_plates/ui_start_screen_bg.
    var candidates := [
        "res://assets/ui/main_menu_bg.webp",
        "res://assets/ui/throne.png",
    ]
    for path in candidates:
        if ResourceLoader.exists(path):
            return load(path)
    return null

func _placeholder() -> ImageTexture:
    var img := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.05, 0.04, 0.10))
    for i in 10:
        var t := float(i) / 10.0
        var y0 := int(t * 1080)
        var h := 108
        img.fill_rect(Rect2i(0, y0, 1920, h),
            Color(lerpf(0.08, 0.02, t), lerpf(0.06, 0.01, t), lerpf(0.15, 0.05, t)))
    return ImageTexture.create_from_image(img)

func _style_buttons() -> void:
    var buttons: Array[Button] = [
        _continue_btn, _new_game_btn, _credits_btn,
        _settings_btn, _exit_btn
    ]
    # Носитель кнопок — тема (вариант MenuPlate: плита макета 09, 9-slice). Здесь
    # когда-то рисовался StyleBoxFlat из ThemeConfig.C_BTN_*: интерим фазы 5, пока
    # у темы не было настоящей графики. Оставь его — и он перекрывает тему
    # (add_theme_stylebox_override сильнее варианта темы), то есть стартовый экран
    # и дальше рисовался бы плоской заливкой вместо кита шага 4.
    for btn in buttons:
        # Недоступная кнопка отличается не только цветом: у неё свой носитель
        # (MenuPlate/disabled — обесцвеченная плита), плюс тусклый шрифт и
        # отсутствующая анимация наведения.
        btn.add_theme_color_override("font_color", ThemeConfig.C_BTN_TEXT)
        btn.add_theme_color_override("font_disabled_color", ThemeConfig.C_BTN_TEXT_DISABLED)
        btn.mouse_entered.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_hover"))
        btn.pressed.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_click"))
        _UIAnimator.setup_button(btn)

func _localize() -> void:
    _continue_btn.text = GameText.menu_continue()
    _new_game_btn.text = GameText.menu_new_game()
    _credits_btn.text = GameText.menu_credits()
    _settings_btn.text = GameText.menu_settings()
    _exit_btn.text = GameText.menu_exit()
    _version_label.text = GameText.menu_version()
    _set_title(GameText.menu_title())


func _set_title(title: String) -> void:
    # Макет 09: титульный леттеринг — три строки по центру кадра (крупно / мелко /
    # крупно), поверх розы-окна. Строка одна (имя игры — бренд, не фраза), поэтому
    # разбивка по словам: «первое / середина / последнее»; два слова → средняя
    # строка пустая и скрыта; одно слово → только первая строка.
    # Третьим аргументом split() в Godot 4 идёт max_splits, а не case_sensitive:
    # split(" ", false, true) режет строку один раз и даёт два куска.
    var words := title.split(" ", false)
    var lines: Array[String] = [title, "", ""]
    if words.size() == 2:
        lines = [words[0], "", words[1]]
    elif words.size() > 2:
        lines = [words[0], " ".join(words.slice(1, words.size() - 1)), words[words.size() - 1]]
    for i in _title_lines.size():
        _title_lines[i].text = lines[i].to_upper()
        _title_lines[i].visible = lines[i] != ""

func _connect_buttons() -> void:
    _continue_btn.pressed.connect(_on_continue)
    _new_game_btn.pressed.connect(_on_new_game)
    _settings_btn.pressed.connect(_on_settings)
    _exit_btn.pressed.connect(_on_exit)

func _connect_settings_extras() -> void:
    if not _settings_screen.arena_requested.is_connected(_on_arena):
        _settings_screen.arena_requested.connect(_on_arena)
    if not _settings_screen.chronicle_requested.is_connected(_on_chronicle):
        _settings_screen.chronicle_requested.connect(_on_chronicle)
    if not _settings_screen.model_requested.is_connected(_on_model_variant):
        _settings_screen.model_requested.connect(_on_model_variant)

func _loc() -> String:
    return TranslationServer.get_locale()

func _refresh_continue_button() -> void:
    # Cutover-проводка (раунд 6, T-110): Continue — кампанийный MVP-слот 1
    # (MvpSaveManager), не легаси-сейв мира.
    var missing: bool = not MvpSaveManager.has_save_in_slot(MvpSaveManager.CAMPAIGN_SLOT)
    _continue_btn.disabled = missing
    # Столп 1 (mvp-ui-flow 3.3): у выключенного пункта причина читается на месте —
    # «Продолжить» молчал серой плитой, и игрок без сейва не отличал «нет сохранения»
    # от «меню сломалось». У доступной кнопки подсказки нет: она ничего не объясняет.
    _continue_btn.tooltip_text = GameText.menu_continue_unavailable() if missing else ""

func _on_continue() -> void:
    if not MvpSaveManager.has_save_in_slot(MvpSaveManager.CAMPAIGN_SLOT):
        return
    # Проводка T-110: Continue → main.tscn → load_save_state (слот 1).
    var persistence: WorldPersistence = Services.resolve(&"persistence")
    if persistence != null:
        persistence.pending_campaign_slot = MvpSaveManager.CAMPAIGN_SLOT
    get_tree().change_scene_to_file(SCENE_CONTINUE)

func _on_new_game() -> void:
    _clear_session_caches()
    get_tree().change_scene_to_file(_CharacterCreation.resource_path)

func _on_arena() -> void:
    _clear_session_caches()
    get_tree().change_scene_to_file("res://scenes/city_arena.tscn")

func _clear_session_caches() -> void:

    Services.clear_session()

## ВРЕМЕННО НЕДОСТИЖИМО (Т-133, Q-M90 → D-205 (а)): макет 09 не содержит пункта
## «Загрузить», кнопка убрана из колонки; экран выбора сохранения и его проводка
## оставлены на месте. Вердикт D-205 закрыл состав меню, но не судьбу экрана —
## она у T-307. Не удалять молча и не соединять «временно» куда-нибудь: инвариант
## «у каждого обработчика меню есть проводка» держится списком в
## tests/unit/ui/test_main_menu_structure.gd, и этот обработчик — его единственная
## строка.
func _on_load_game() -> void:
    _save_load_screen.open("load")

func _create_save_load_screen() -> void:
    _save_load_screen.load_requested.connect(_on_slot_load_requested)
    _save_load_screen.delete_requested.connect(_on_slot_delete_requested)

func _on_slot_load_requested(slot: int) -> void:
    _save_load_screen.perform_load(slot)

func _on_slot_delete_requested(slot: int) -> void:
    _save_load_screen.perform_delete(slot)

func _on_chronicle() -> void:
    var entries: Array = []
    var result: Dictionary = SaveManager.load_game()
    if result.get("error", -1) == SaveManager.SaveError.OK:
        var data: SaveData = result.get("data")
        if data != null:
            entries = data.chronicle
    _chronicle_screen.show_entries(entries)

func _on_exit() -> void:
    get_tree().quit()

func _on_settings() -> void:
    if not _settings_screen.applied.is_connected(_on_settings_applied):
        _settings_screen.applied.connect(_on_settings_applied)

    var settings_node: Object = Services.resolve(&"settings")
    _settings_screen.setup(settings_node)
    _settings_screen.show()

func _on_settings_applied() -> void:
    pass

func _on_model_variant(variant: String) -> void:
    _open_model_window(variant)

func _open_model_window(variant: String) -> void:
    var name := GameText.model_hero_warrior() if variant == "warrior" else GameText.model_hero_mage()
    _model_screen.set_hero(_HeroModelFactory.build_hero(name, variant))
    _model_screen.show()
