# Changelog

Формат: записи по завершённым OpenSpec-циклам. Детали — в `openspec/changes/archive/`.

## 2026-02-22

### ui-icons-cursors-improvement — завершение
- `game_theme.tres`: кнопки/панели/слоты на 9-slice `StyleBoxTexture`, стили `Button` (normal/hover/pressed/disabled) и `ProgressBar` (background/fill)
- `ThemeConfig.icon_texture()` — кэшированная загрузка иконок с fallback (`assets/ui/icons/fallback.png`)
- `ResourceRegistry.get_icon()` / `BuildingDefs.get_icon()` — текстуры по id
- UI: ResourceBar, ResourcesPanel, CityScreen, HeroStatusPanel, BattleSpellbookPanel используют PNG-иконки вместо эмодзи
- Тесты: `tests/unit/theme/` (14 тестов) — загрузка, курсоры, кэш, fallback

### dnd-battle-system — Phase 1 + фикс брони
- Фикс: тяжёлая броня (max_dex=0) полностью игнорирует DEX (`scripts/battle/dnd/armor_class.gd`)
- Тесты ядра D&D: `tests/unit/battle/test_dnd_core.gd` (27 тестов)
