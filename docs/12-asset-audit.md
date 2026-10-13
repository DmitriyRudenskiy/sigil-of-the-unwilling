---
title: Asset Audit — game/assets
tags:
  - audit
  - assets
  - ui
status: snapshot
date: 2026-10-13
---

# Asset Audit Report — game/assets — 2026-10-13

Read-only аудит визуальных ассетов (`game/assets/**/*.{png,jpg,jpeg,webp}`) перед работой
над интерфейсом и графикой ([[07-ui-ux]]). Реестр целиком — CSV рядом с документом:
`docs/12-asset-audit-registry.csv` (путь, категория, байты, w×h, grid8, вид ссылки, md5-префикс).

## Summary

- **Total assets scanned**: 402 (PNG 363, JPG 25, WEBP 12, **SVG — 0**; 12.1 МБ)
  - по категориям: units 190, ui 105, artifacts 54, textures 39, cursors 11, raw 2, tiles 1
- **Naming violations**: 0 (все имена `^[a-z0-9_]+\.[a-z]+$`)
- **Size violations**: NOT ASSESSED — бюджета размеров нет (art bible отсутствует; см. `/art-bible`)
- **Format violations**: 12 пар jpg/webp-двойников (см. «Дубликаты»)
- **Orphaned assets**: **35 файлов (~3.7 МБ)** — каждый подтверждён поиском по всему репо
- **Missing assets**: **4** (мёртвые fallback-пути в `main_menu.gd`)
- **Grid anomalies (кратность 8)**: 40 файлов — факт, бюджет не задан
- **Sections not assessed**: Size (нет бюджета — `/art-bible`); аудио (52 файла mp3/wav — вне заказа)

Методика ссылок: корпус = `*.gd, *.tscn, *.tres, *.godot, *.cfg, *.py, *.sh` + `assets/theme/*.tres`;
`.import`-файлы исключены (генерируются на каждый ассет, не использование); динамическая загрузка
учтена по лoader-ам: `units/%s.png` (UnitSprites), `artifacts/%s.png` (artifact_inventory_screen),
`textures/objects/` + `BUILDING_ART_BY_ID` (campaign_city_board), `icon_path` из `data/events/*.json`,
`ICON_DIR*` (theme_config), autoload `CursorController` (жив через подписку на GameEventBus).

## Orphaned Assets (подтверждено нулём ссылок во всём репо)

| Файл | Размер | Доказательство орфанства | Рекомендация |
|---|---|---|---|
| ui/events/bandit_event.png, herbalist_event.png | 2 файла | ни в одном `data/events/*.json` в `icon_path`; 0 в коде | удалить (или прописать в JSON существующих событий) |
| ui/widgets/decorators/divider_horizontal.png, divider_vertical.png, corner_decor.png | 3 файла | 0 ссылок; генератор `gen_widget_textures.gd` их не пишет и не называет | удалить |
| ui/widgets/progress_bars/fill_mana.png, fill_exp.png | 2 файла | 0 ссылок; код/генератор используют `bar_mana_fill`/`bar_xp_fill` — старые имена | удалить |
| textures/objects/building_*.jpg ×12 (academy, apothecary, archery_range, barracks, farmhouse, greenhouse, longhouse, palace, sawmill, stable, temple, town_hall) | ~3.3 МБ | `BUILDING_ART_BY_ID` маппит **только .webp**; `*.jpg` — 0 ссылок | удалить jpg-двойники |
| textures/objects/portrait_*.jpg ×9 (beaver, felid, felid_2, fox, frogfolk, harpy, human_boy, lizardfolk, silhouette_hat) | ~0.2 МБ | UnitSprites грузит только `units/%s.png`; в `team_dialogs/*.json` поля portrait нет; 0 ссылок | удалить (если не под них задуман TeamDialog — тогда wire-тикет) |
| cursors/cursor_01/02/03/10/32.png ×5 | ~0.1 МБ | `MODE_ASSETS` CursorController перечисляет только walk/collect/attack/spell/talk/default; этих имён нет нигде | удалить |
| ui/main_menu_bg.jpeg | 0.1 МБ | main_menu грузит `main_menu_bg.png`; `.jpeg` — 0 ссылок | удалить |
| raw/hero_knight.png | ~0.1 МБ | `SPRITE_HERO_KNIGHT` и `HERO_SHEET_PATH` = `hero_knight.jpg` | удалить png (источник — jpg) |

## Missing Assets (referenced but not found)

| Reference Location | Expected Path | Комментарий |
|---|---|---|
| scripts/ui/main_menu.gd:49–52 | res://assets/raw/throne.png, res://assets/raw/menu_bg.png, res://assets/backgrounds/throne.png, res://assets/backgrounds/menu.png | Цепочка fallback из 6 кандидатов; 4 не существуют, выживает 1-й (`ui/main_menu_bg.png`) — работающий код с мёртвыми ветками. Убрать 4 строки или завести файлы |
| tests/unit/theme/test_fallback_icon.gd | res://assets/ui/icons/resources/no_such_resource_xyz.png | **Не дефект**: намеренный негативный фикстур-путь |

## Дубликаты

**По содержимому (md5), 12 групп / 35 файлов — все в `artifacts/`:** 54 иконки артефактов —
это ~31 уникальное изображение (например, `ring_vitality == ring_cunning`; группа из 4:
`helm_heavenly == hood_wraith == helm_bulwark == circlet_aurora`). Это **плейсхолдеры**, не мусор:
загружаются по `artifacts/%s.png % id`, орфанов нет. Рекомендация: не удалять; учесть в `/asset-spec`
как 23 недостающих уникальных иконки.

**По смыслу (jpg/webp-двойники), 14 пар:** 12 пар `building_*` (живёт webp, jpg — орфан, см. выше),
`main_menu_bg` (живёт png), `hero_knight` (живёт jpg). Двойники — источник рассинхрона: правки
«не в том файле». Рекомендация: удалить неиспользуемые половины.

## Несоответствия нейминга и структуры

- Нижнего регистра/разделителей — **0 нарушений**.
- `scenes/ui/TeamDialogScreen.gd` и `scripts/data/TeamDialogData.gd` — PascalCase в **коде**
  (вне assets/, но против godot-конвенции нижнего регистра; Linux case-sensitivity — риск для MCP-тестов).
- `assets/raw/` — свалка исходников (2 файла); категории `tiles/` — 1 файл (`world_tiles.jpeg`),
  «категория-однушка»; `textures/objects/` смешивает здания и портреты. Рекомендация: портреты —
  в отдельный каталог при первой же правке; `raw/` объявить dropbox и не трогать.

## Аномалии грида (кратность 8/16/32)

40 файлов вне кратности 8 — **все** из AI-генерации (портреты 460–689 px, здания 564–689 px,
hex-шиты 510×587/530×610, `resources.png` 410×410, `world_tiles.jpeg` 410×410, `throne.png` 820×1120,
hero-баннеры 124×124/124×92, checkbox 20×20). Тайлы и иконки — в гриде. Для спрайтовых листов
кратность важна (hex_sheet — вне, но грузится целиком как текстура, не атласом → не блокер).
Бюджета нет → факт без вердикта; при появлении art bible — нормировать.

## Рекомендации (сводка)

1. **Удалить** 35 подтверждённых орфанов (~3.7 МБ, список выше) — после ручного ревью владельцем.
2. **Убрать** 4 мёртвых fallback-пути в `main_menu.gd:49–52` (или завести файлы).
3. **Переименовать** TeamDialog* в нижний регистр — отдельным коммитом с правкой preload-путей.
4. **Не удалять** md5-дубли артефактов — это плейсхолдеры под будущую генерацию (`/asset-spec`: +23 уникальные иконки).
5. **Завести art bible** (`/art-bible`) — без него Size/грид-бюджеты остаются NOT ASSESSED.
6. Поправка к ponytail-аудиту 2026-10-13: «CursorController — 0 обращений, удалить» — **ошибка**;
   autoload жив через подписку в `_ready()` на GameEventBus (`resource_extracted` эмиттируется из
   world_interaction_controller/resource_node_manager), курсоры walk/collect/attack/spell/talk — runtime-ассеты.

## Verdict: NON-COMPLIANT

Причина: 4 ссылки кода на несуществующие файлы (main_menu fallback). Остальное — WARNINGS
(орфаны/двойники). Size-секция NOT ASSESSED (нет бюджета — `/art-bible`).
