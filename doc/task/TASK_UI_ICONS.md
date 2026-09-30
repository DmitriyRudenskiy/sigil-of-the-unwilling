# UI Icons / Cursors — интеграция (завершение цикла ui-icons-cursors-improvement)

## Что сделано

1. **Тема** (`game/assets/theme/game_theme.tres`):
   - `StyleBoxFlat_button` → `StyleBoxTexture` (9-slice, `buttons/button_normal.png`, margin 8)
   - `StyleBoxFlat_panel` → `StyleBoxTexture` (`panels/panel_bg.png`, margin 16)
   - `StyleBoxFlat_slot` → `StyleBoxTexture` (margin 12)
   - Добавлены `Button/styles/normal|hover|pressed|disabled` и `ProgressBar/styles/background|fill`

2. **API иконок**:
   - `ThemeConfig`: константы `ICON_DIR`, `ICON_DIR_RESOURCES`, `ICON_DIR_BUILDINGS`, `ICON_DIR_NEEDS`, `ICON_DIR_SCHOOLS`, `ICON_FALLBACK`; `static func icon_texture(path)` с кэшем `_icon_cache` и fallback
   - `ResourceRegistry.get_icon(id) -> Texture2D`
   - `BuildingDefs.get_icon(id) -> Texture2D`
   - `assets/ui/icons/fallback.png` (16×16, серый)

3. **UI-сцены** (эмодзи → текстуры):
   - `ResourceBar.tscn` — 7 HBox(TextureRect + Label) для классических ресурсов
   - `ResourcesPanel.tscn` — TextureRect в каждой из 13 строк (отсутствующие иконки → fallback)
   - `CityScreen.tscn` — `Button.icon` для BuildFarm/BuildMine
   - `HeroStatusPanel.tscn` — ряд `Needs` с 3 иконками; красная подсветка при критической потребности
   - `BattleSpellbookPanel` — `Button.icon` по школе заклинания

4. **Тесты** (`game/tests/unit/theme/`, 14 тестов):
   - `test_icon_loading.gd` — все иконки ресурсов/зданий/потребностей/школ + API
   - `test_cursor_sprites.gd` — спрайты из `CursorControllerAutoload.MODE_ASSETS`
   - `test_icon_cache.gd` — повторный вызов возвращает тот же экземпляр
   - `test_fallback_icon.gd` — отсутствующий файл → fallback

## Проверка

```sh
godot --headless --path game -s addons/gdunit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests/unit/theme
# 14 test cases | 0 errors | 0 failures
```

Полный набор: 1646/1646 passed.

## Примечания

- Все иконки — плоские сгенерированные PNG (без фото-контента) → артефактов сжатия нет по построению; 74 файла проверены на валидность/размеры.
- Производительность: тема + 5 UI-сцен загружаются и инстанцируются headless < 1 c; кэш текстур исключает повторные чтения с диска.
- Иконки, которых нет на диске (oak, silver, quartz, ... в ResourcesPanel), автоматически рендерятся как fallback — генератор иконок для расширенных ресурсов остаётся открытой задачей.
