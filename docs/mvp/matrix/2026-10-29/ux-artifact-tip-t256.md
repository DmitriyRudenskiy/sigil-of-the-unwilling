---
title: UX-review T-256 — карточка предмета (зона D экрана героя)
tags: [mvp, ux-review, t256, matrix]
status: reference
date: 2026-10-29
---

# UX-review T-256 · всплывающая карточка предмета на экране героя

Экран: `res://scenes/main_menu.tscn` → `HeroModelWindow` (`ArtifactInventoryScreen`),
зона D — «панель предмета (поверх D6–I10)».

Макет-источник. `design/single_window_layout/all_screens_ui.png` в репо нет
(зафиксировано в `docs/CHANGELOG.md` от 2026-10-26 и далее). Живой носитель
контракта зоны D — `docs/20-ux-hero-screen.md:142`: «`Desc_lbl`, `Desc`,
`Equip`, `Remove`, `Dispose` под иконкой предмета». Имена узлов в сцене —
`TipName` / `Desc_lbl` / `TipDesc` / `TipButtons/{Equip,Remove,Dispose}`:
`Desc` в генераторе всегда назывался `TipDesc`, состав и порядок зоны это
соблюдает.

## Кадры

| | канал | состояние | файл | sha256 |
| --- | --- | --- | --- | --- |
| до | `tools/shot_scene.gd` (dev) | `inventory_selection` (T-218) | `game/tmp/shots/t256_before_tip2.png` | пиксели в git не идут (D-185) |
| после | MCP / живой Godot, 1920×1080 | `tools/capture/inventory_tooltip.gd` | `~/.local/share/sigil-reserve/inventory-t256/inventory_tooltip_after.png` | `9a9b5c41d7c3a4c35f6e604136ae9180cc4bd50235bbf75bd9479b5abde1d6d8` |

Команда кадра «после» (канал вердикта, `docs/mvp/CAPTURE-HELPER.md`):

```
CAPTURE_SCENE=res://scenes/main_menu.tscn CAPTURE_LABEL="после (T-256)" \
CAPTURE_NAME=inventory_tooltip_after CAPTURE_OUT=inventory-t256 \
CAPTURE_SETUP=@tools/capture/inventory_tooltip.gd \
GODOT_PATH=… GODOT_MCP_SERVER=…/addons/godot-mcp/build/index.js \
python -m pytest tests/mcp/test_capture.py -q --timeout=900
```

Фикстура ставит живой предмет с описанием и габаритом 2×3 и открывает подсказку;
её возврат зафиксирован в `MANIFEST.md` каталога снимков:
`tip_visible=true`, `body_visible=true`,
`body_text="Латунь, что помнит рассвет над стеной: тяжёлая, тёплая, верная.\nГабарит: 2×3 (6 кл.)"`,
`caption="Описание"`, `rect=(685.2, 360.0, 552.0, 288.0)`.

## Оговорка к яркости кадра (замерена, а не «так показалось»)

Фикстура исполняется на `Engine.get_frames_drawn() == 1`: `MainMenu` в
`_ready` запускает `_UIAnimator.animate_in(self)`
(`game/scripts/ui/main_menu.gd:46`, `game/scripts/ui/ui_animator.gd:4-10`) —
туин `modulate:a 0 → 1` за 0.2 с. Кадр ловит середину туина
(замер в фикстуре: `modulate = (1,1,1,0.6667…0.75)`), поэтому **абсолютная**
светимость всего экрана кадре занижена — это относится ко всем экранам,
висящим под `MainMenu`, а не к правке T-256. Относительное сравнение «до/после»
и арифметика темы от этого не зависят; ниже контраст считается по значениям
темы, а не по пикселям затемнённого кадра.

## Разбор поэлементно (кадр «после» против `docs/20-ux-hero-screen.md` §5 D)

| Элемент | До | После | Диспозиция |
| --- | --- | --- | --- |
| Подложка блока | `ItemTip` нёс вариант `ArtifactOutline` → `StyleBoxFlat_outline` с `bg_color = Color(0,0,0,0)`; имя, текст и три кнопки рисовались прямо по камню | `ItemTip` несёт `PanelCard` → `StyleBoxFlat_card`: залитие `(0.2902, 0.2039, 0.1373, 1)` (α = 1) + золотая рамка 2 px | устранено |
| Описание (`Desc`) | экран писал в узел `TipBox/Desc` со `visible = false`, тест читал тот же узел и зелёнел | пишется в видимый `TipBox/TipDesc`; скрытый двойник удалён из генератора | устранено |
| Подпись блока (`Desc_lbl`) | скрыта, создавалась **после** тела | видима, идёт **перед** телом: `TipName → Desc_lbl → TipDesc → TipButtons` | устранено |
| Цвет/кегль текста | роли не заданы → резолвился белый цвет движка | тип-роли темы: `TipName = LabelStrong`, `Desc_lbl = LabelSecondary`, `TipDesc = LabelBody` (docs/17-ui-style-guide.md §17.6) | устранено |
| Выход за кадр, пустые слоты | — | карточка `(685, 360, 552×288)` целиком в кадре, перенос строк работает («…тёплая, верная.» перенесено), кнопок ровно три, лишних слотов нет | PASS |
| Читаемость | текст без подложки на камне — не читался | контраст по значениям темы, см. ниже | PASS |

Контраст по значениям темы (пиксели затемнённого кадра для этой строки не годятся —
см. оговорку): `LabelStrong`/`LabelBody` `#E8D5A8` на `PanelCard #4A3423` →
CR ≈ 8.1; `LabelSecondary` `#D9C48F` → CR ≈ 6.8. Порог WCAG AA для текста
карточки — 4.5, запас двукратный.

## Расхождения, отложенные этим review

| # | Расхождение | Диспозиция |
| --- | --- | --- |
| 1 | Полосы `BandMana`/`BandSkills` вылезают за камень | уже T-257, не трогается здесь |
| 2 | Кнопки `Equip/Remove/Dispose` идут базовым `Button`, а не ролью карточки кампейн-слоя | не T-256:ticket не заводит, правка входит в семью T-255…T-258 по этому экрану |
| 3 | Кадр снимается на середине туина появления меню | системно для всех кадров под `MainMenu`; в T-256 не влияет на вердикт |

## Вердикт по AC тикета (footer: «Блокирует: AC3 — носитель блока без вида»)

| AC | Формулировка | Вердикт |
| --- | --- | --- |
| AC3 | у блока предмета есть носитель (подложка+рамка), блок не выглядит артефактом отладки | **PASS** — `PanelCard`, α = 1, кадр-доказательство выше |
| AC4 (смежная, порядок зоны D) | состав и порядок зоны D соответствуют макету | **PASS** — имя → подпись → тело → кнопки |
| — | описание видно на кадре | **PASS** — `body_visible = true`, текст в `MANIFEST.md` |

Механическая часть: `game/tests/unit/ui/test_artifact_screen_theme_carrier.gd::test_item_tip_sits_on_an_opaque_plate`
(вариант, резолв стильбокса, α ≥ 0.9, видимость `TipDesc`, роли текста, порядок
четырёх узлов). Зубы проверены мутациями: возврат `ArtifactOutline` → FAIL;
снятие роли у `Desc_lbl` → FAIL; перестановка `Desc_lbl`/`TipDesc` → FAIL;
`visible = false` у `TipDesc` → FAIL.
