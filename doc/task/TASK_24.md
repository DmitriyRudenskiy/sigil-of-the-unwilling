# TASK_24: Система иконок, курсоров и UI-графики

## Что сделано (change `ui-icons-cursors-improvement`, задачи 1–12)

### Иконки (32×32 PNG, генераторы в `game/scripts/build/`)
- `assets/ui/icons/resources/` — 8 иконок ресурсов (gen_resource_icons.gd)
- `assets/ui/icons/buildings/` — 18 иконок зданий (gen_building_icons.gd + gen_building_icons2.gd)
- `assets/ui/icons/needs/` — rest, social, inspiration (gen_need_icons.gd)
- `assets/ui/icons/schools/` — air, fire, water, earth
- `assets/ui/icons/fallback.png` — fallback для отсутствующих иконок

### Курсоры
- `assets/cursors/` — 6 режимов: default, walk, collect, attack, spell, talk
- `CursorController` — Mode.CAST_SPELL, Mode.TALK, hotspot на каждый курсор

### UI-виджеты (9-slice)
- `assets/ui/widgets/{buttons,panels,progress_bars,sliders,decorators}/`
- генератор: `scripts/build/gen_widget_textures.gd`
- `game_theme.tres`: StyleBoxTexture для Panel(panel/slot/button), Button(4 состояния),
  ProgressBar(bg/fill/fill_mana/fill_xp), Slider(track/grabber), CheckBox(checked/unchecked)

### Регистрация
- `scripts/theme/IconRegistry.gd` — статический кэш текстур + fallback;
  `resource_texture()`, `building_texture()`, `need_texture()`, `school_texture()`, `cursor_texture()`
- `ThemeConfig` — константы ICON_DIR_*, ICON_FALLBACK_PATH, CURSOR_DIR
- `ResourceRegistry.get_icon()`, `BuildingDefs.get_icon()`

### UI-сцены
- `ResourceBar.tscn` — TextureRect-иконки 16×16 (custom_minimum_size, expand+keep_size)
  рядом с цифрами; эмодзи убраны из текста
- `ResourcesPanel.gd` — иконка в каждой строке
- `BattleSpellbookPanel.gd` — иконка школы на кнопках заклинаний
- `HeroStatusPanel.gd` — иконки потребностей
- `CityScreen.gd` — иконки зданий

### Тесты
- `tests/unit/theme/test_icon_system.gd` — 7 тестов (загрузка, кэш, fallback)
- UI-геометрия: `tests/unit/ui/` — 23 теста (иконки не ломают layout сайдбара)

## Решения
- Иконки в ResourceBar ограничены 16×16 (`custom_minimum_size` + `expand_mode=1`),
  иначе 32×32 TextureRect раздвигает сайдбар (регрессия test_adventure_ui_layout).
- .tres формат Godot 4: `[ext_resource]` блоки строго до `[sub_resource]` — иначе
  "Unknown tag 'ext_resource'".
- MCP eval блокирует `load(`/`preload(` → в тестах через `class_name`/константы.
