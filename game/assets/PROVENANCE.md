---
title: Провенанс ассетов
tags: [assets, provenance, legal]
status: reference
date: 2026-10-18
---

# Провенанс ассетов `game/assets/`

Реестр происхождения: **кто сделал / из чего / на каких правах**. Правило
[[13-art-bible]] §12: новый ассет кладётся вместе со строкой здесь — ассет без
записи это будущий ASSET-1, найденный не вами.

Покрывает изображения, аудио и шрифты (`.png .jpg .jpeg .webp .gif .bmp .svg
.ttf .otf .mp3 .ogg .wav`). JSON-данные, `.tres` и `.gd` — авторский код репо,
не покрываются.

Чекер — `scripts/check_asset_provenance.py` (падает на ассете без строки, на
строке без файла и на файле со статусом `красный`).

**Формат.** Строка класса (путь каталога со слэшем) покрывает все файлы каталога. Если в
каталоге есть хотя бы одна строка файла, каталог считается **поимённым**: классовая
строка в нём не работает, новый файл обязан получить свою строку. Первый столбец — путь от
корня репо. Статусы: `чисто` / `неизвестно` (происхождение не установлено) /
`жёлтый` (известно, прав не хватает) / `красный` (чужой пиксель, лежать не может).

## Классы

| Путь | Кто сделал / откуда | Из чего | Права | Статус |
|---|---|---|---|---|
| `game/assets/artifacts/` | генератор репо `game/scripts/build/gen_artifact_icons.gd`; файлы пришли `8334a974` (2026-08-30, перенос кода в `game/`) | 60 растровых иконок артефактов, 32/64 px | записей нет; md5/dHash-свип [[13-art-bible]] §12.1 против `reference/` и `___STYLE_BOOK/` — совпадений нет | неизвестно |
| `game/assets/audio/music/` | не установлено — `278f5534` (2026-08-31, audio-pass) | 43 mp3 | записей нет, атрибуции нет | неизвестно |
| `game/assets/audio/sfx/` | не установлено — `278f5534` (2026-08-31) | 9 wav | записей нет | неизвестно |
| `game/assets/cursors/` | не установлено — `8334a974` (2026-08-30) | 6 png курсоров | записей нет | неизвестно |
| `game/assets/fonts/` | «ParaType» (PT Serif, PT Mono) | 3 ttf | OFL, полный текст — `game/assets/fonts/LICENSE.txt` | чисто |
| `game/assets/textures/` | не установлено — `44c5513b` (2026-09-03, astral-macro) | 3 png шардов/неба | записей нет | неизвестно |
| `game/assets/textures/objects/` | не установлено — `62dc74d2` (2026-10-07, «obj36») | 12 png объектов карты | записей нет | неизвестно |
| `game/assets/objects/` | конвейер репо `scripts/gen_map_art.py` (world-map-art-variety) | лист изолированных объектов карты `world_map_objects.webp` | comfyui/image-clone: роли из `scripts/concept_art/map_spec.json`, кадр 1024² → силуэт; права на модель Krea-2 turbo не проверялись | жёлтый |
| `game/assets/objects/world_map_objects.webp` | то же | 16 объектов 82 px, comfyui/image-clone, seed'ы в `image-clone/map/MANIFEST.json` (2026-10-19: `obj_bush` перегенерирован, добавлен `obj_undergrowth`) | права на модель не проверялись | жёлтый |
| `game/assets/tiles/` | не установлено — `44c5513b` (2026-09-03) | 1 png тайла | записей нет | неизвестно |
| `game/assets/tiles/world_map_atlas.webp` | конвейер репо `scripts/gen_map_art.py` (world-map-art-variety) | comfyui/image-clone: 8 биомов × 4 варианта базы + 6 декалей границ на биом, 82 px; материал 1024² → зашивка шва → полоса M | права на модель Krea-2 turbo не проверялись | жёлтый |
| `game/assets/ui/` | AI-генерация референса 04; `17e75cf4` как конверсия jpeg из «image-очереди» | `main_menu_bg.webp` 1920×1080 | права на генерацию не проверялись | жёлтый — перегенерация с чистой палитрой (UI-4) |
| `game/assets/ui/events/` | не установлено — `3b32788f` (2026-09-16, события) | 14 png иллюстраций событий | записей нет | неизвестно |
| `game/assets/ui/hero/` | не установлено — `8334a974` (2026-08-30) | 4 png портретов | записей нет | неизвестно |
| `game/assets/ui/icons/` | не установлено — `8334a974` (2026-08-30) | 28 png прочих иконок (армия, флаг, компас…) | записей нет | неизвестно |
| `game/assets/ui/icons/buildings/` | генератор репо `game/scripts/build/gen_building_icons.gd` (+ `gen_building_icons2.gd`); файлы — `cb9bfe49` (2026-09-16, «Update UI graphics…») | 18 png иконок зданий | связь текущих файлов с генератором не доказана; записей нет | неизвестно |
| `game/assets/ui/icons/needs/` | генератор репо `game/scripts/build/gen_need_icons.gd` | 3 png нужд | записей нет | неизвестно |
| `game/assets/ui/icons/resources/` | **ASSET-1, этот прогон** — `game/tools/gen_resource_icons.py` | 20 png 32×32 по формуле §7.1 | нарисованы в репо, прав третьих лиц нет (бывший атлас HoMM III удалён) | чисто |
| `game/assets/ui/icons/schools/` | генератор репо `game/scripts/build/gen_school_icons.gd` | 4 png школ магии | записей нет | неизвестно |
| `game/assets/ui/widgets/buttons/` | `cb9bfe49` (2026-09-16); перекрас синего семейства в канон — `game/tools/recolor_button_textures.py` | 4 png 9-slice состояний кнопки | исходник перекраса — текстура репо, но её приход — тот же `cb9bfe49` | жёлтый — ASSET-2 (своя рамка «кованый край») |
| `game/assets/ui/widgets/decorators/` | генератор репо `game/scripts/build/gen_widget_textures.gd`; файлы — `cb9bfe49` | 2 png | записей нет | неизвестно |
| `game/assets/ui/widgets/panels/` | то же | 2 png | записей нет | неизвестно |
| `game/assets/ui/widgets/progress_bars/` | то же | 5 png | записей нет | неизвестно |
| `game/assets/ui/widgets/sliders/` | то же | 2 png | записей нет | неизвестно |
| `game/assets/units/` | не установлено — `8334a974` (2026-08-30) | 190 png юнитов (обычные + `_s`) | записей нет; свип §12.1 чист | неизвестно |

## Файлы

Иконки ASSET-1 — по строке на файл: форма носителя отличает их друг от друга и
от ячеек удалённого атласа (dHash ≥ 12, [[13-art-bible]] §12.1).

| Файл | Кто сделал | Из чего | Права | Статус |
|---|---|---|---|---|
| `game/assets/characters/hero_knight.png` | не установлено — пришёл `8334a974` (2026-08-30) как `game/assets/raw/hero_knight.png`; перенесён `3a35d21e` (UI-4, 2026-10-17) | лист анимаций героя-рыцаря (не портрет `units/`); `hero_knight.jpg` и каталог `assets/raw/` удалены тем же коммитом | записей нет; решение владельца по [[13-art-bible]] §8.4 не принято | жёлтый |
| `game/assets/ui/icons/resources/icon_resource_bog_iron.png` | ASSET-1 (2026-10-14) | пористая болотная железа; масса `c2`, свет `a6`, тень `d6` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_cinnabar.png` | ASSET-1 | колотый пласт с плоской гранью, алые вкрапления; `d1/d3/d5` + акцент `crimson` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_coal.png` | ASSET-1 | острый кубовидный кусок со сколами, два отломка у ноги; `c1/a5/a6` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_coal_swamp.png` | ASSET-1 | два низких куска в воде, три волны; `c1/a5` + вода `b5` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_crystal.png` | ASSET-1 | три острых столба разной высоты; `a8/b3/b5` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_food.png` | ASSET-1 | колос с зерном; `gold/b6/b2` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_gems.png` | ASSET-1 | три ромба самоцветов по тону граней; `c3/ok/d7` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_gold.png` | ASSET-1 | пирамида из трёх монет; `gold/b1/b2` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_gold_ore.png` | ASSET-1 | угловатый монолит с золотыми прожилками; `c8/b4/d6` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_iron.png` | ASSET-1 (2026-10-15) | подкова: кольцо с разрывом вниз, шесть гвоздевых отверстий; `c8/a8/b5` + акцент `d5` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_limonite.png` | ASSET-1 | почковидная масса: низкий плитняк с наросшими почками; `c2/c4/c6` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_mercury.png` | ASSET-1 | толстая капля над лужицей с зазором; `a8/b5/a7` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_oak.png` | ASSET-1 | один крупный жёлудь с чашечкой; `wood/b4/d5` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_ore.png` | ASSET-1 | округлая осыпь с вкраплениями минерала; `c8/a5/d6` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_quartz.png` | ASSET-1 | наклонная столбчатая призма с короткой парой у ноги; `b7/a7/parchment` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_saltpeter.png` | ASSET-1 | мешок-груша с собранной горловиной и перевязью; `b7/a7/parchment` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_silver.png` | ASSET-1 | штабика: нижний брусок + верхний со свесом; `a8/b5/a7` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_stone.png` | ASSET-1 | два колотых клина; `c8/a6/a7` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_sulfur.png` | ASSET-1 | три гексагональные призмы разной высоты; `gold/b6/b2` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_turquoise.png` | ASSET-1 | кабошон в тёмной оправе с матричными прожилками; `a8/b3/b5` | наше | чисто |
| `game/assets/ui/icons/resources/icon_resource_wood.png` | ASSET-1 | три бревна в срезе; `wood/b4/d5` | наше | чисто |

## Снятые позиции

Строки убраны из таблиц выше, потому что чекер падает на строке реестра без файла;
след происхождения остаётся здесь — ассет без записи это будущий ASSET-1, найденный
не вами.

- `game/assets/raw/` — каталога нет с `3a35d21e` (UI-4, 2026-10-17): `hero_knight.jpg`
  удалён, `hero_knight.png` перенесён в `characters/` (файловая строка выше). Прежняя
  строка: «не установлено — `8334a974` (2026-08-30); `hero_knight.jpg` + png-фикстура
  теста (md5 разные); решение владельца по §8.4 не принято», статус `жёлтый`.
- `game/assets/tiles/world_tiles.webp` — удалён 2026-10-18 по прямому указанию владельца
  (шаг 4.1 world-map-art-variety): единственный лист тайлset 82 px заменён
  `world_map_atlas.webp`, `TileAtlas.BASE_COORDS` снят. Прежняя строка: «не установлено —
  `44c5513b` (2026-09-03, astral-macro); md5/dHash-свип [[13-art-bible]] §12.1 совпадений
  не дал», статус `неизвестно`. Пиксель удалён, а не перекрашен: если лист вернут как
  резервный атлас (задача 4.2), строка обязана вернуться вместе с ним.

## Что это реестр не закрывает

- Статус `неизвестно` = происхождение не установлено, а не «прав достаточно».
  Свип §12.1 ловит побайтовый рип, пересжатие и перекрас того же кадра; он не
  ловит ни «похоже, но из другой библиотеки», ни «куплено с чеком, чек потерян».
- Классы со статусом `неизвестно` (units, artifacts, audio, cursors, ui/events,
  ui/hero, ui/icons, textures, tiles) — инвентаризация ASSET-1. Решение по ним
  принимает владелец: доказывать происхождение, менять или снимать с репо.
  Публичный билд с ними не выпускается (тикет ASSET-1, AC1).
