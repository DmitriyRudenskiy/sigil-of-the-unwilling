---
title: docs/reference — справочники чужих игр (не канон Sigil)
tags:
  - reference
  - index
status: reference
date: 2026-10-16
---

# Справочники и банк: зона `docs/reference/`

Сюда перенесён внешний концепт-вольт: числа, таблицы и промпты чужих игр, которые
канон-доки называют референсами (*Against the Storm*, *TerraScape*, *HoMM III*,
*D&D*, *Allods Online*, *Pillars of Eternity II*), но носителя которых в репо не было.

## Правила зоны

1. **Не канон.** Ни одно утверждение зоны не становится правилом игры. Канон — `00-*`…`15-*`,
   `MVP-*`, реестры. При расхождении действует канон, расхождение — в [[CONFLICTS]].
2. **Числа не переносятся.** Значения из зоны не попадают в [[07-balance]],
   `data/config/balance/*` и другие баланс-конфиги иначе как явное решение владельца.
3. **Канон не ссылается на зону из формул.** Ссылка канона сюда допустима только как
   «источник числа», не как часть правила или формулы.
4. **Побайтовый перенос.** Тело файла — копия источника; правится только шапка
   (frontmatter + provenance) и перезаписываются ссылки на переименованные файлы.
   Правки содержимого — только через канон-док, не здесь.
5. **Имена** — латиница, префикс зоны (`ats-`, `poe2-`, `dnd-`, `sigil-ats-`, …).
   Кириллица в именах запрещена общим гейтом.

## Источник

`/Users/user/sigil-of-the-unwilling-doc/` — внешний каталог, **не в git**, не бэкапится
репо. Получено 2026-10-16. Статус: **reference, не канон** — решения по вольте только
через `docs/DECISIONS.md` (раунд Q-A=3, D-187); из канона чаты ничего не меняют.

**Сырые чаты — импортированы** в `chats/` (6 корневых городских файлов, 10 613 строк, как есть,
без правок; имена переименованы в латиницу — маппинг ниже). Контрольные суммы (SHA-256) —
для сверки с исходником и против дрейфа:

| Файл вольты | `docs/reference/chats/` | SHA-256 (первые 16) |
|---|---|---|
| `chat-Городская система_ Репутация и Классы.txt` | [chat-city-reputation-classes.txt](chats/chat-city-reputation-classes.txt) | `591fe10d9bad6621` |
| `chat-Механика городов и развитие.txt` | [chat-city-mechanics-development.txt](chats/chat-city-mechanics-development.txt) | `acf06dac6e68fe6c` |
| `chat-TerraScape_ Ядро + 3 ряда.txt` | [chat-terrascape-core-3-rows.txt](chats/chat-terrascape-core-3-rows.txt) | `a97c06fc57fbee9c` |
| `chat-Библиотека в Терраскейп_ Постройки и взаимосвязи.txt` | [chat-library-terrascape-buildings.txt](chats/chat-library-terrascape-buildings.txt) | `de0a027a0ab01306` |
| `chat-Социальная механика и расы в Against the Storm.txt` | [chat-social-mechanics-races-atst.txt](chats/chat-social-mechanics-races-atst.txt) | `1166f5159934d504` |
| `chat-OpenPose Лицо Профиль Сравнение.txt` | [chat-openpose-face-profile.txt](chats/chat-openpose-face-profile.txt) | `6560a5baaf31d24d` |

**Не импортированы**: 4 чата из «Новая папка с объектами» (Godot Character Builder, Pathfinder
Constructor, Характеристики и способности, Характеристики персонажа — 9 329 строк; домен
конструктора персонажа, вне городского пакета) — по D-187 вне раунда; импорт отдельной задачей.

## Что где лежит

| Файл вольты | Файл репо | Что это |
|---|---|---|
| `atts/species.md` | [ats-species.md](against-the-storm/ats-species.md) | AtS: расы, настройки, потребности |
| `atts/buildings.md` | [ats-buildings.md](against-the-storm/ats-buildings.md) | AtS: здания по 6 категориям |
| `atts/goods.md` | [ats-goods.md](against-the-storm/ats-goods.md) | AtS: товары, еда, материалы |
| `atts/specializations.md` | [ats-specializations.md](against-the-storm/ats-specializations.md) | AtS: комфорт и мастерство рас |
| `atts/README.md` | [ats-notes.md](against-the-storm/ats-notes.md) | AtS: заметки источника, флаги сверки |
| `kb/reference-att.md` | [ats-canon.md](against-the-storm/ats-canon.md) | AtS: свод канона (не сверен: вики 403) |
| `terrascape/merged-buildings.md` | [terrascape-merged-buildings.md](terrascape/terrascape-merged-buildings.md) | TerraScape: 20 слияний построек |
| `textures/terrain-tiles.md` | [homm3-terrain-tiles.md](homm3/homm3-terrain-tiles.md) | HoMM III: промпты террейн-тайлов |
| `allods/races.md` | [allods-races.md](allods/allods-races.md) | Allods Online: 8 рас + промпты генерации |
| `dnd/races.md` | [dnd-races.md](dnd/dnd-races.md) | D&D: расы по редакциям и зонам мира |
| `dnd/classes.md` | [dnd-classes.md](dnd/dnd-classes.md) | D&D: классы по редакциям |
| `PoE2-Character-Creation/index.md` | [poe2-index.md](poe2/poe2-index.md) | PoE2: навигация вики |
| `PoE2-Character-Creation/01-Races/Races Overview.md` | [poe2-races.md](poe2/poe2-races.md) | PoE2: 6 рас |
| `PoE2-Character-Creation/02-Classes/Classes Overview.md` | [poe2-classes.md](poe2/poe2-classes.md) | PoE2: 11 классов |
| `PoE2-Character-Creation/03-Attributes/Attributes System.md` | [poe2-attributes.md](poe2/poe2-attributes.md) | PoE2: 6 атрибутов, point-buy |
| `PoE2-Character-Creation/04-Skills/Skills System.md` | [poe2-skills.md](poe2/poe2-skills.md) | PoE2: навыки |
| `PoE2-Character-Creation/07-Multiclassing/Multiclassing Guide.md` | [poe2-multiclassing.md](poe2/poe2-multiclassing.md) | PoE2: мультикласс |
| `PoE2-Character-Creation/08-Guides/Character Creation Flow.md` | [poe2-creation-flow.md](poe2/poe2-creation-flow.md) | PoE2: шаги создания персонажа |
| `PoE2-Character-Creation/00-Meta/DnD 5e Character Creation Rules.md` | [poe2-dnd5e-rules.md](poe2/poe2-dnd5e-rules.md) | Справка D&D 5e внутри PoE2-вики |
| `PoE2-Character-Creation/00-Meta/System Comparison PoE2 vs DnD.md` | [poe2-vs-dnd.md](poe2/poe2-vs-dnd.md) | Сравнение PoE2 и D&D 5e |
| `kb/README.md` | [sigil-ats-notes.md](sigil-ats-prototype/sigil-ats-notes.md) | **карантин**: обзор AtS-клона |
| `kb/races.md` | [sigil-ats-races.md](sigil-ats-prototype/sigil-ats-races.md) | **карантин**: расы клона |
| `kb/buildings.md` | [sigil-ats-buildings.md](sigil-ats-prototype/sigil-ats-buildings.md) | **карантин**: здания клона |
| `kb/goods.md` | [sigil-ats-goods.md](sigil-ats-prototype/sigil-ats-goods.md) | **карантин**: товары клона |
| `kb/mechanics.md` | [sigil-ats-mechanics.md](sigil-ats-prototype/sigil-ats-mechanics.md) | **карантин**: механики клона |
| `kb/merged-buildings.md` | [sigil-ats-merged-buildings.md](sigil-ats-prototype/sigil-ats-merged-buildings.md) | **карантин**: 45 + 29 зданий |
| `kb/implementation.md` | [sigil-ats-implementation.md](sigil-ats-prototype/sigil-ats-implementation.md) | **карантин**: аудит браузерного прототипа |

Карантинная зона `sigil-ats-prototype/` описывает **не-канонический AtS-клон** и
браузерный прототип (в тексте — JS-выражения), а не `game/`. Почему — [[CONFLICTS]] (К-12).

## Сверка с каноном

Единственный список расхождений референса с каноном и внутренних дыр, которые сверка
вскрыла: **[[CONFLICTS]]**. Открытые вопросы, выросшие из вольты, зарегистрированы в
[[QUESTIONS]] как Q-M48…Q-M51.
