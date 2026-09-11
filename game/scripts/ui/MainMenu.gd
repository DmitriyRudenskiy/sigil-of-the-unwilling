extends Control
class_name MainMenu

const _UIAnimator = preload("res://scripts/ui/UIAnimator.gd")
const _CharacterCreation = preload("res://scenes/ui/CharacterCreation.tscn")
const _HeroModelFactory = preload("res://scripts/ui/HeroModelFactory.gd")

@onready var _background: TextureRect = $Background
@onready var _new_game_btn: Button = $RightColumn/NewGameButton
@onready var _load_game_btn: Button = $RightColumn/LoadGameButton
@onready var _arena_btn: Button = $RightColumn/ArenaButton
@onready var _model_warrior_btn: Button = $RightColumn/ModelWarriorButton
@onready var _model_mage_btn: Button = $RightColumn/ModelMageButton
@onready var _settings_btn: Button = $RightColumn/SettingsButton
@onready var _chronicle_btn: Button = $RightColumn/ChronicleButton
@onready var _exit_btn: Button = $RightColumn/ExitButton
@onready var _version_label: Label = $RightColumn/VersionLabel
@onready var _settings_screen: SettingsScreen = $SettingsScreen
@onready var _chronicle_screen: ChronicleScreen = $ChronicleScreen
@onready var _model_screen: ArtifactInventoryScreen = $HeroModelWindow
@onready var _save_load_screen: SaveLoadScreen = $SaveLoadScreen

signal hero_selected(hero_name: String, variant: String)
var _selected_hero: String = &""
@onready var _hero_selection = get_node_or_null("HeroSelection")

func _ready() -> void:
    for arg in OS.get_cmdline_args():
        if arg.begins_with("--test-server"):
            return
    _load_background()
    _style_buttons()
    _localize()
    _connect_buttons()
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
    var candidates := [
        "res://assets/ui/main_menu_bg.png",
        "res://assets/ui/throne.png",
        "res://assets/raw/throne.png",
        "res://assets/raw/menu_bg.png",
        "res://assets/backgrounds/throne.png",
        "res://assets/backgrounds/menu.png",
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
        _new_game_btn, _load_game_btn, _arena_btn,
        _model_warrior_btn, _model_mage_btn, _settings_btn,
        _chronicle_btn, _exit_btn
    ]
    for btn in buttons:
        var sn := StyleBoxFlat.new()
        sn.bg_color = ThemeConfig.C_BTN_NORMAL
        sn.set_corner_radius_all(10)
        sn.set_border_width_all(2)
        sn.border_color = ThemeConfig.C_BTN_BORDER
        sn.shadow_color = ThemeConfig.C_BTN_SHADOW
        sn.shadow_size = 4
        btn.add_theme_stylebox_override("normal", sn)
        var sh := sn.duplicate()
        sh.bg_color = ThemeConfig.C_BTN_HOVER
        btn.add_theme_stylebox_override("hover", sh)
        var sp := sn.duplicate()
        sp.bg_color = ThemeConfig.C_BTN_PRESSED
        btn.add_theme_stylebox_override("pressed", sp)
        btn.add_theme_color_override("font_color", ThemeConfig.C_BTN_TEXT)
        btn.mouse_entered.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_hover"))
        btn.pressed.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_click"))
        _UIAnimator.setup_button(btn)

func _localize() -> void:
    _new_game_btn.text = GameText.menu_new_game()
    _load_game_btn.text = GameText.menu_load_game()
    _arena_btn.text = GameText.menu_arena()
    _model_warrior_btn.text = GameText.menu_model_warrior()
    _model_mage_btn.text = GameText.menu_model_mage()
    _settings_btn.text = GameText.menu_settings()
    _chronicle_btn.text = GameText.menu_chronicle()
    _exit_btn.text = GameText.menu_exit()
    _version_label.text = GameText.menu_version()

func _connect_buttons() -> void:
    _new_game_btn.pressed.connect(_on_new_game)
    _load_game_btn.pressed.connect(_on_load_game)
    _arena_btn.pressed.connect(_on_arena)
    _model_warrior_btn.pressed.connect(_on_model_warrior)
    _model_mage_btn.pressed.connect(_on_model_mage)
    _settings_btn.pressed.connect(_on_settings)
    _chronicle_btn.pressed.connect(_on_chronicle)
    _exit_btn.pressed.connect(_on_exit)

func _on_new_game() -> void:
    _clear_session_caches()
    get_tree().change_scene_to_file(_CharacterCreation.resource_path)

func _on_arena() -> void:
    _clear_session_caches()
    get_tree().change_scene_to_file("res://scenes/CityArena.tscn")

func _clear_session_caches() -> void:

    Services.clear_session()

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

func _on_hero_selected(name: String) -> void:
    _selected_hero = name
    _apply_hero_selection()

func _on_cancel_selection() -> void:
    _selected_hero = &""
    if _hero_selection != null:
        _hero_selection.visible = false

func _apply_hero_selection() -> void:
    if _hero_selection == null or _selected_hero == null:
        return
    hero_selected.emit(_selected_hero, "warrior")

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

func _on_model_warrior() -> void:
    _open_model_window("warrior")

func _on_model_mage() -> void:
    _open_model_window("mage")

func _open_model_window(variant: String) -> void:
    var name := GameText.model_hero_warrior() if variant == "warrior" else GameText.model_hero_mage()
    _model_screen.set_hero(_HeroModelFactory.build_hero(name, variant))
    _model_screen.show()
