---
title: Asset-spec — 29 иконок артефактов (UI-4)
tags:
  - assets
  - artifacts
  - ui
status: draft
date: 2026-10-13
---

# Asset-spec: 29 недостающих иконок артефактов (23 дубль-плейсхолдера + 6 weapons)

Тикет UI-4 (`docs/mvp/TICKETS.md`). Вход: [[13-art-bible]] (deepened; канвас/бюджет
§8.2, редкости §4.4, non-text контраст §4.5, префикс-промпт), [[12-asset-audit]]
(md5-реестр дублей), `game/scripts/autoload/artifact_registry.gd` (60 id).

## 1. Реестр дедупликации (сверка: «да» = 23 ✓)

54 файла `assets/artifacts/*.png` → 31 уникальный рисунок (md5). 12 групп дублей;
в каждой группе плейсхолдер детерминированно сохраняет алфавитно первый id,
остальные **23** требуют уникальную иконку. Арифметика 54 − 31 = 23 сходится.

| # | Артефакт (id) | Имя | Редкость | Сейчас шарит с | Новая |
|---|---|---|---|---|---|
| 1 | boots_titan | Titan's Boots | RELIC | boots_levitation | да |
| 2 | boots_zephyr | Zephyr Boots | RELIC | boots_levitation | да |
| 3 | helm_bulwark | Bulwark Helm | RELIC | circlet_aurora | да |
| 4 | helm_heavenly | Helm of Heavenly Enlightenment | RELIC | circlet_aurora | да |
| 5 | hood_wraith | Wraith Hood | RELIC | circlet_aurora | да |
| 6 | leather_stalker | Stalker's Leather | RELIC | armor_wonder | да |
| 7 | pendant_negation | Pendant of Negation | RELIC | amulet_prescience | да |
| 8 | plate_dread | Dread Plate | RELIC | armor_wonder | да |
| 9 | ring_giant | Ring of the Giant | RELIC | ring_arcanum | да |
| 10 | ring_infinite_gems | Ring of Infinite Gems | RELIC | ring_arcanum | да |
| 11 | ring_lexicon | Ring of the Lexicon | RELIC | ring_arcanum | да |
| 12 | ring_vitality | Ring of Vitality | MINOR | ring_cunning | да |
| 13 | ring_wayfarer | Wayfarer's Ring | MAJOR | ring_mage | да |
| 14 | robes_astronomer | Astronomer's Robes | RELIC | armor_wonder | да |
| 15 | shield_damned | Shield of the Damned | RELIC | buckler_ripple | да |
| 16 | shield_greatwall | Greatwall Shield | RELIC | buckler_ripple | да |
| 17 | skirt_conjunction | Skirt of Conjunction | RELIC | greaves_juggernaut | да |
| 18 | soles_mercury | Mercury Soles | RELIC | boots_levitation | да |
| 19 | staff_void | Staff of the Void | RELIC | longbow_hawk | да |
| 20 | sword_judgment | Sword of Judgment | RELIC | greatsword_might | да |
| 21 | trinket_epoch | Trinket of Epoch | RELIC | charm_beast | да |
| 22 | ward_arcane | Arcane Ward | RELIC | buckler_ripple | да |
| 23 | wraps_peregrine | Peregrine Wraps | RELIC | greaves_juggernaut | да |

Находка вне 23 (вопрос владельцу, §5): 6 id реестра (`club`, `stone_axe`,
`iron_sword`, `steel_longsword`, `runic_blade`, `rune_sword`) не имеют файла иконок
вообще — инвентарь грузит `artifacts/%s.png` → пустая текстура.

## 2. Спецификация (общее для всех 23)

- Канвас **64×64**, грид 8, отступ содержимого 8 px; PNG-32 с альфой; бюджет **≤ 6 КБ**
  ([[13-art-bible]] §8.2 «Иконка артефакта»).
- Имя файла = id артефакта, нижний регистр (`boots_titan.png`) — конвенция загрузчика
  `artifact_inventory_screen` (`artifacts/%s.png`).
- Окантовка редкости (§4.4/§4.5): MINOR `#8a6a3a` 2px; MAJOR `#c9a227` 2px;
  RELIC — двойная: внешняя `#7a100c` 2px + внутренняя `#c9a227` 1px. Рамка рисуется
  **маппингом/темой ячейки, не пикселями иконки** (иначе смена тира = перерендер);
  в превью накладывается для проверки контраста на тайле `#281c0f`.
- Стиль: тёмный фон тайла не входит в PNG (альфа), гравюрный силуэт по центру,
  обводка 1.5 px, один акцентный цвет (§7/§8.3).
- Префикс-промпт — библия §«Префикс-промпт» + канвас 64×64; пост-процессинг §8.5
  (кроп→квантование палитры ±12 L→PNG-32→имя→бюджет).

### Предметы (субъект кадра на иконку)

| id | Субъект (силуэт читается с 48 px) | Акцент |
|---|---|---|
| boots_titan | тяжёлые окованные бутсы, каменные плиты-подошвы | `#8a6a3a` |
| boots_zephyr | лёгкие сапоги с завитком ветра вокруг голенища | `#7ab0d0` |
| helm_bulwark | глухой шлем-цилиндр с поперечной прорезью | `#8a6a3a` |
| helm_heavenly | остроконечный шлем с лучистым нимбом сверху | `#c9a227` |
| hood_wraith | капюшон-пустыш, тень лица спиралью | `#7a100c` |
| leather_stalker | пояс-куртка со следами-сапожками по диагонали | `#7aa85a` |
| pendant_negation | кулон-диск с перечёркнутым рунным кольцом | `#7ab0d0` |
| plate_dread | латный торс с рёбрами-дугами, череп-клёпка | `#7a100c` |
| ring_giant | перстень-глыба, необработанный камень | `#8a6a3a` |
| ring_infinite_gems | обод с россыпью мелких самоцветов | `#c9a227` |
| ring_lexicon | тонкий перстень с микроскриптом-полосой | `#c9a227` |
| ring_vitality | гладкий перстень с каплей-сердцем | `#7aa85a` |
| ring_wayfarer | перстень с дорогой-зигзагом и стрелкой | `#c9a227` |
| robes_astronomer | мантия со звёздной картой-созвездием | `#7ab0d0` |
| shield_damned | щит с трещиной и языками пламени снизу | `#7a100c` |
| shield_greatwall | прямоугольный щит-кладка с закладным камнем | `#8a6a3a` |
| skirt_conjunction | пояс-юбка с пятью подвешенными планетами-шарами | `#c9a227` |
| soles_mercury | подошвы-крылья (стиль гермовых сандалий) | `#7ab0d0` |
| staff_void | посох с «дырой»-сферой на конце (края загнуты) | `#7a100c` |
| sword_judgment | меч с чашей-весами в гарде | `#c9a227` |
| trinket_epoch | песочные часы с одной струйкой-золотом | `#c9a227` |
| ward_arcane | рунический щит-пластина с концентрическими кругами | `#7ab0d0` |
| wraps_peregrine | обернутые тканью голенища с когтевидной пряжкой | `#7aa85a` |

## 3. Превью для ревью

Контактный лист: каждая иконка 64×64 **на тайле `#281c0f`** с наложенной окантовкой
своего тира (контраст-режим §4.5 проверяется только так) + та же в 2×. Лист —
приложением к PR генерации.

## 4. План интеграции (отдельный PR, после приёмки сета)

1. Положить 23 файла в `game/assets/artifacts/` (имена = id).
2. Плейсхолдеры группы остаются до полного сета; замена — все 23 одним коммитом.
3. Маппинг менять не нужно: загрузчик резолвит `artifacts/%s.png` по id — новые
   файлы подхватываются автоматически; grep старых имён по треку (кроме
   `docs/12*` snapshot и реестра аудита) обязан быть пуст.
4. Реимпорт + смок инвентаря (artifact_inventory_screen) + GdUnit-сета артефактов.
5. После UI-4 — перегенерация реестра аудита (docs/12 остаётся snapshot).

## 5. Итоги проверок данных (гейт владельца, 2026-10-13)

1. **Obtainability 6 id — достижимы все.** Кузнечный `WeaponTechService.forge()`
   (`weapon_tech_service.gd:79`) создаёт `Artifact` с id изделия (`club`…`rune_sword`)
   → инвентарь резолвит `artifacts/%s.png` → пустая текстура: **живой баг сегодня**.
   Все 6 включены в батч → **сет 29** (одна генерация, один контакт-лист, один
   интеграционный PR).
2. **rune_sword vs runic_blade — не дубль.** Разные статы (2d8/MAJOR/90g против
   3d8/RELIC/160g), у `rune_sword` рецепт `rune_sword_crafted`, оба покрыты тестами.
   Косметика: display_name «Рунный клинок»/«Рун. меч» путаются — тикет data-audit
   на переименование, иконки — обе.
3. **Rarity — явно, не дефолтом.** Все 60 id реестра передают rarity 4-м аргументом
   `_register` (дефолт `from_dict` — MINOR, не RELIC; парсер не участвует).
   35/60 RELIC — проставленное значение → по правилу владельца баланс подтверждён,
   двойная рамка остаётся; визуальный шум оцениваем на контакт-листе всего сета.

### Дополнительные 6 иконок (weapons, батч 29)

| id | Субъект | Акцент | Редкость (источник — явный `_register`) |
|---|---|---|---|
| club | дубина с сучками | `#8a6a3a` | MINOR (registry) |
| stone_axe | топор из отщепов, костяная оплётка | `#8a6a3a` | MINOR (registry) |
| iron_sword | прямой меч, простая крестовина | `#8a6a3a` | MINOR (registry) |
| steel_longsword | длинный меч, лезвие с долами | `#c9a227` | MAJOR (registry) |
| runic_blade | клинок с рунами-сквозными прорезями | `#c9a227` | MAJOR (registry) |
| rune_sword | меч с нимбом-короной в гарде | `#c9a227` | RELIC (registry) |

**Инвариант тира:** искры RELIC — тоже уровень ячейки (или декор вовсе); пиксели
иконки от тира не зависят никогда. Смена редкости в данных = смена рамки в теме,
ноль работы по ассетам.

## DoD

29 спеко-строк со ссылками на библию ✓ (этот документ); в `game/` ничего не кладётся
мимо бюджетной проверки ✓ (PR генерации — только после ревью контакт-листа);
замена плейсхолдеров — списком в PR интеграции, не в PR генерации ✓ (§4).
