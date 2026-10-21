# ui-verification-gates — дизайн и журнал первых прогонов

## Адаптив-гейт: решения

### Носитель
`game/tests/functional/ui/test_ui_responsive.gd` (GdUnit4 functional, headless).
8 экранов × 5 разрешений (1280×720, 1920×1080, 2560×1440, 3440×1440, 3840×2160).

### Смысл «вьюпорта»
Ссылка bounds-проверки — `get_viewport().get_visible_rect()` (layout-размер),
не размер окна: stretch mode `canvas_items` + `aspect=expand` держит layout
1920×1080 на всех 16:9-разрешениях (3440×1440 → 2580×1080). Проверка по
оконному размеру ложно красила бы 3440×1440.

### Успокоение анимаций
Экраны с intro-анимацией (`_UIAnimator.animate_in`, 0.2 с tween TRANS_BACK,
overshoot ~22 px) меряются только после 40 кадров (`_SETTLE_FRAMES` ≈ 0.67 с
@60 fps) — иначе замеры ловят позицию посреди tween.

### Рецепты старта (отражают хостов, не изобретают layout)
- `settings_screen`: `setup(Settings)` ДО `add_child` (Settings — autoload;
  standalone без setup сам освобождается в `_ready`).
- `artifact_inventory_screen`: корню — полные якоря (оба хоста:
  `main_menu.tscn:HeroModelWindow`, `world_ui.tscn:WorldUILayer/
  ArtifactInventoryScreen` делают ровно это).

### Правила проверок
1. **Bounds**: rect видимого Control внутри layout-вьюпорта (допуск 2 px).
   Исключения: (а) элементы под `ScrollContainer` — выход за вьюпорт
   достижим скроллом (world_ui: `RightColumn/Box`, контент 1695 px при
   вьюпорте 1080 px); (б) явный список `_BLEED_ALLOWED` (main_menu
   `TitleLine1`, offset_top=-10 в сцене, глифы видны — принято в дизайне,
   smoke-скрин 2026-10-13).
2. **Перекрытия**: sibling-пары, пересечение > 20% площади меньшего элемента.
   Исключения: (а) явный whitelist `_OVERLAYS` (скроп по экрану, каждое имя
   с комментарием-основанием); (б) пересечения < 100 px² — субпиксельные
   срезы (party-строки `Icon`/`Avatar` × `Name`, 17–18 px²; наименьшее
   реальное перекрытие в кодовой базе — 650 px²).

### Известные дефекты (механизм `_KNOWN_VIOLATIONS`)
Нарушения, совпадающие с префиксами `_KNOWN_VIOLATIONS`, печатаются в лог,
но не краснят гейт; после фикса запись удаляется, устаревшая запись
(нарушение не воспроизводится) печатается предупреждением. Текущая запись —
T-154 (см. ниже).

### Нюанс движка Godot 4.7.2
Свойство `Control.global_rect` даёт «Invalid access to property or key»
(проверено на голом Control вне GdUnit) — гейт использует метод
`get_global_rect()`.

## Первый прогон (1.3, 2026-10-21, `main` 361d7b2a)

Итог: **гейт зелёный 8/8** (0 ошибок, 0 падений, 0 сирот, ~13 с).
Находки классифицированы:

### Осознанный дизайн → whitelist (постоянные записи)
| Экран | Узлы | Основание |
| --- | --- | --- |
| main_menu | `Background`; `TitleLine1/2/3` | фон; стэк заголовка (offset_top 204/224 против 0..263) |
| settings_screen | `Background` | затемнение под окном |
| save_load_screen | `Dim` | затемнение под окном слотов |
| character_creation | `Overlay` | полноэкранный слой формы |
| city_screen | `ScreenShade`; `BoardPlaceholder`; `CityInspector`; `TerrainLegend` | затемнение; подложка под доску; плавающие панели над доской |
| artifact_inventory_screen | `Figure`; `Left`; `Side`; `Bottom` | слоты экипировки на кукле; нижняя полоса на всю ширину окна |
| world_ui | `end_overlay`; `Frame`; `MapBox`; `N/S/E/W`; `TextureRect`; `Overlay` | оверлей конца похода; рамка под картой; nav-стрелки на гранях; текстура + туман миникарты |

### Scroll-контент → правило (не whitelist)
- world_ui `RightColumn/Box/PanelsBox` (VBox 1695 px в ScrollContainer) —
  выход за вьюпорт достижим скроллом; элементы под ScrollContainer
  исключены из bounds-проверки.

### Субпиксельные срезы → порог 100 px²
- world_ui party-строки (`info_panel.tscn` hero_slot_*): `Avatar × Name`
  18 px², `Icon × Name` 17 px² (1-px срез 17–18 px высотой).

### Реальный дефект → T-154 (визуальная зона владельца)
`artifact_inventory_screen.tscn`:
- **(а)** `Center` (CenterContainer) сворачивает `Window` (обычный Control без
  min-size) в 0×0 → контент окна разбросан от (500,350); строка `Inventory`
  уходит 26–28 px за правый край на 16:9 (4 из 5 разрешений).
- **(б)** `Bottom` — PanelContainer с 8 детьми: все ArmySlot_* + Formations
  наложены в один content-rect 908×148 (offset-ы сцены игнорируются);
  кнопки Formations пересекаются на 12 px (min-высота 48 > шаг строк 36).

Гейт несёт 154 известных нарушения (T-154) в логе, не краснея; протокол
мутаций пройден (сдвиг `RightColumn` в main_menu.tscn → 30 violations «вне
вьюпорта», откат → зелёный).
