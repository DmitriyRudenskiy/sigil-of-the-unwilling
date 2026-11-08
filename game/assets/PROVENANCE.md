---
title: Провенанс ассетов
tags: [assets, provenance, legal]
status: reference
date: 2026-10-29
---

# Провенанс ассетов `game/assets/`

Реестр происхождения: **кто сделал / из чего / на каких правах**. Правило
[[13-art-bible]] §12: новый ассет кладётся вместе со строкой здесь — ассет без
записи это будущий ASSET-1, найденный не вами.

Покрывает изображения, аудио и шрифты (`.png .jpg .jpeg .webp .gif .bmp .svg
.ttf .otf .mp3 .ogg .wav`). JSON-данные, `.tres` и `.gd` — авторский код репо,
не покрываются.

Чекер — `scripts/check_asset_provenance.py` (падает на ассете без строки, на
строке без файла и на файле со статусом `красный`). С 2026-10-29 он играет
уровнем в `scripts/doc_gates.sh` (T-261); до этого был только ручным и молча
краснел на 201 ассете — «зелёный провенанс» значился в задачах смен, где его
никто не мерил.

**Формат.** Строка класса (путь каталога со слэшем) покрывает все файлы каталога. Если в
каталоге есть хотя бы одна строка файла, каталог считается **поимённым**: классовая
строка в нём не работает, новый файл обязан получить свою строку. Первый столбец — путь от
корня репо. Статусы: `чисто` / `неизвестно` (происхождение не установлено) /
`жёлтый` (известно, прав не хватает) / `красный` (чужой пиксель, лежать не может).

## Классы

| Путь | Кто сделал / откуда | Из чего | Права | Статус |
|---|---|---|---|---|
| `game/assets/artifacts/` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/hero_screen_spec.json`, эталон — макет 12 `~/sigil-reference/12_inventory_parchment_sheet.jpeg`; укладка кадра — `game/tools/ui_kit/place_hero_art.py` | 60 png иконок предметов 128×128, фон срезан по связным областям (2026-10-29; прежние плоские глифы `gen_artifact_icons.gd` лежали с `8334a974`) | промпт и seed'ы в `concept_art/manifest.json`; права на модель Krea-2 turbo не проверялись | жёлтый |
| `game/assets/audio/music/` | не установлено — `278f5534` (2026-08-31, audio-pass) | 43 mp3 | записей нет, атрибуции нет | неизвестно |
| `game/assets/audio/sfx/` | не установлено — `278f5534` (2026-08-31) | 9 wav | записей нет | неизвестно |
| `game/assets/cursors/` | не установлено — `8334a974` (2026-08-30) | 6 png курсоров | записей нет | неизвестно |
| `game/assets/fonts/` | «ParaType» (PT Serif, PT Mono) | 3 ttf | OFL, полный текст — `game/assets/fonts/LICENSE.txt` | чисто |
| `game/assets/textures/` | не установлено — `44c5513b` (2026-09-03, astral-macro) | 3 png шардов/неба | записей нет | неизвестно |
| `game/assets/textures/objects/` | не установлено — `62dc74d2` (2026-10-07, «obj36») | 12 png объектов карты | записей нет | неизвестно |
| `game/assets/objects/` | конвейер репо `scripts/gen_map_art.py` (world-map-art-variety) | лист изолированных объектов карты `world_map_objects.webp` | comfyui/image-clone: роли из `scripts/concept_art/map_spec.json`, кадр 1024² → силуэт; права на модель Krea-2 turbo не проверялись | жёлтый |
| `game/assets/objects/world_map_objects.webp` | то же | 22 объекта 82 px, comfyui/image-clone, seed'ы в `game/image-clone/map/MANIFEST.json` (2026-10-19: `obj_bush` перегенерирован, добавлен `obj_undergrowth`; в тот же день лист 16 → 22 — рельеф и лагеря, world-map-art-variety 7.1) | права на модель не проверялись | жёлтый |
| `game/assets/objects/world_map_objects_fog.webp` | то же, побратим «в тумане» (`gen_map_art.py --fog-twin`) | те же 22 объекта, яркость ×0.45 = `GameNumbersMap.MAP_FOG_DIM` | производный от листа объектов; права на модель не проверялись | жёлтый |
| `game/assets/objects/world_map_roads.webp` | конвейер репо `scripts/gen_map_art.py` (категория `roads`, world-map-art-variety 6.1) | лист декалей дорог 82 px: 6 полос (2 покрытия × 3 оси) + 6 мостов + 2 перекрёстка + 12 кромок; comfyui/image-clone, seed'ы в `game/image-clone/map/MANIFEST.json` | права на модель Krea-2 turbo не проверялись | жёлтый |
| `game/assets/objects/world_map_roads_fog.webp` | то же, побратим «в тумане» (`gen_map_art.py --fog-twin`) | тот же лист дорог, яркость ×0.45 = `GameNumbersMap.MAP_FOG_DIM` | производный от листа дорог; права на модель не проверялись | жёлтый |
| `game/assets/objects/world_map_threat.webp` | конвейер репо `scripts/gen_map_art.py` (категория `threat`, world-map-art-variety 8.1) | 3 носителя тира вражеских стэков 82 px (кольца 1/2/3); comfyui/image-clone, seed'ы в `game/image-clone/map/MANIFEST.json` | права на модель Krea-2 turbo не проверялись | жёлтый |
| `game/assets/ui/` | AI-генерация референса 04; `17e75cf4` как конверсия jpeg из «image-очереди» | `main_menu_bg.webp` 1920×1080 | права на генерацию не проверялись | жёлтый — перегенерация с чистой палитрой (UI-4) |
| `game/assets/ui/backgrounds/battle_meadow.png` | прислано владельцем 2026-10-28 (`~/Downloads/Interface_battle/1793181620465-…png`) | 1 png 1920×1080 — луг БЕЗ собственной гекс-сетки; носитель поля боя (`BattleView.FIELD_ART`, T-269 → (б)) | права на генерацию не проверялись; носитель предоставлен владельцем | жёлтый |
| `game/assets/ui/backgrounds/battle_snow.png` | передан владельцем 2026-10-27 (канон-арт, строка 01 `docs/style-reference-index.md`, md5 `f1f95b670d41e9f838cd16c72d8ee7cd`) | png 1679×937 — задний план снежного поля боя (`BattleView.BIOMES`, D-283) | происхождение и права на генерацию не проверялись | жёлтый |
| `game/assets/ui/backgrounds/battle_swamp.png` | передан владельцем 2026-10-27 (канон-арт, строка 02 `docs/style-reference-index.md`, md5 `0e41d641d507942501ea9332c690962c`) | png 1376×768 — задний план болотного поля боя (`BattleView.BIOMES`, D-283) | происхождение и права на генерацию не проверялись | жёлтый |
| `game/assets/ui/widgets/battle/` | прислано владельцем 2026-10-28 (`~/Downloads/Interface_battle/mai-image-2.6 (t2i)_b_A_3×3_grid_of_hand-p.png`, 1536×1536), нарезка `game/tools/ui_kit/slice_battle_buttons.py` | 7 png медальонов нижней панели боя (сетка 3×3, две ячейки пустые) | права на генерацию не проверялись; носитель предоставлен владельцем | жёлтый |
| `game/assets/units/figures/` | прислано владельцем 2026-10-28 (`~/Downloads/Interface_battle/1793072846892-…_NN_….png`, пять кадров на белом фоне), вырезка `game/tools/ui_kit/place_battle_art.py` (`place_hero_art.keyed`) | 5 png фигур юнитов с альфой (лучник, мечник, рыцарь, дворф, паладин) | права на генерацию не проверялись; носитель предоставлен владельцем | жёлтый |
| `game/assets/ui/events/` | не установлено — `3b32788f` (2026-09-16, события) | 14 png иллюстраций событий | записей нет | неизвестно |
| `game/assets/ui/hero/` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/hero_screen_spec.json`, эталон — макет 12 `~/sigil-reference/12_inventory_parchment_sheet.jpeg`; укладка кадра — `game/tools/ui_kit/place_hero_art.py` (`portrait.png`, `figure.png`) и генератор репо `game/tools/ui_kit/build_hero_kit.py` (остальные плитки, D-275/D-278); `mini.png` — старый плейсхолдер `8334a974`, читателя нет | 18 png носителей экрана «Герой» | права на модель не проверялись | жёлтый |
| `game/assets/ui/campaign_screen/` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/campaign_ui_spec.json`, эталон — кропы макета 10 `scripts/concept_art/etalons_campaign/`; укладка кадра — `game/tools/ui_kit/place_campaign_art.py` (альфа-фон и вписка — общие функции кита «Герой») | 31 png носителей экрана «Карта» (27 кадров варианта `u2_slate_brass`, 4 — `u2b_chromatic`); отбор — ux-review кадрового листа, размер и kind — `MANIFEST.json`; контактный лист отбора — `game/image-clone/campaign_ui/sheet_u2_slate_brass.webp`, `sheet_u2b_chromatic.webp` | права на модель не проверялись | жёлтый |
| `game/assets/ui/icons/` | не установлено — `8334a974` (2026-08-30) | 28 png прочих иконок (армия, флаг, компас…); 5 из них — иконки навыков, переписаны контуром, см. файловые строки ниже | записей нет | неизвестно |
| `game/assets/ui/icons/nature_sense.png` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/hero_screen_spec.json` (категория `emblems`, id `skill_nature_sense`), укладка `game/tools/ui_kit/place_hero_art.py` | иконка навыка чувства природы, фон срезан по связным областям; прежний носитель 40×40 был плоской заглушкой UI-6 | права на модель не проверялись | жёлтый |
| `game/assets/ui/icons/keen_eye.png` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/hero_screen_spec.json` (категория `emblems`, id `skill_keen_eye`), укладка `game/tools/ui_kit/place_hero_art.py` | иконка навыка внимательность, фон срезан по связным областям; прежний носитель 40×40 был плоской заглушкой UI-6 | права на модель не проверялись | жёлтый |
| `game/assets/ui/icons/navigation.png` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/hero_screen_spec.json` (категория `emblems`, id `skill_navigation`), укладка `game/tools/ui_kit/place_hero_art.py` | иконка навыка навигация, фон срезан по связным областям; прежний носитель 40×40 был плоской заглушкой UI-6 | права на модель не проверялись | жёлтый |
| `game/assets/ui/icons/geology.png` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/hero_screen_spec.json` (категория `emblems`, id `skill_geology`), укладка `game/tools/ui_kit/place_hero_art.py` | иконка навыка геология, фон срезан по связным областям; прежний носитель 40×40 был плоской заглушкой UI-6 | права на модель не проверялись | жёлтый |
| `game/assets/ui/icons/alchemy.png` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/hero_screen_spec.json` (категория `emblems`, id `skill_alchemy`), укладка `game/tools/ui_kit/place_hero_art.py` | иконка навыка алхимия, фон срезан по связным областям; прежний носитель 40×40 был плоской заглушкой UI-6 | права на модель не проверялись | жёлтый |
| `game/assets/ui/icons/army.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/army_s.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 24×24 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/arrow.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/arrow_s.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 24×24 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/atk_sword.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/battle_flag.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/battle_flag_s.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 24×24 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/compass.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/compass_s.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 24×24 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/expand.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/flag.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/flag_s.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 24×24 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/gold.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/helm.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/horse.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/hourglass.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/scout.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/scroll.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/ship.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/spell.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/swords.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/treasure.png` | не установлено — `8334a974` (2026-08-30, перенос в `game/`) | png 48×48 | каталог `ui/icons/` поимённый (в нём есть файловые строки), поэтому классовая строка на неё не действует; записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/fallback.png` | не установлено — файл добавлен `adb637c6` (2026-09-25, ui-icons-cursors-improvement) | png 16×16, 87 Б — фолбэк `ThemeConfig.icon_texture()` (`ICON_FALLBACK`): то, что рисуется вместо отсутствующей иконки | каталог поимённый, записей о происхождении нет | неизвестно |
| `game/assets/ui/icons/hero/` | comfyui krea2 (сервер 192.168.0.230:8188) по спеке `scripts/concept_art/hero_screen_spec.json`, эталон — макет 12 `~/sigil-reference/12_inventory_parchment_sheet.jpeg`; укладка кадра — `game/tools/ui_kit/place_hero_art.py` | 4 png иконок характеристик 128×128 (меч, звезда щита, звезда магии, книга) | права на модель не проверялись | жёлтый |
| `game/assets/ui/icons/buildings/` | генератор репо `game/scripts/build/gen_building_icons.gd` (+ `gen_building_icons2.gd`); файлы — `cb9bfe49` (2026-09-16, «Update UI graphics…») | 18 png иконок зданий | связь текущих файлов с генератором не доказана; записей нет | неизвестно |
| `game/assets/ui/icons/needs/` | генератор репо `game/scripts/build/gen_need_icons.gd` | 3 png нужд | записей нет | неизвестно |
| `game/assets/ui/icons/resources/` | **ASSET-1, этот прогон** — `game/tools/gen_resource_icons.py` | 20 png 32×32 по формуле §7.1 | нарисованы в репо, прав третьих лиц нет (бывший атлас HoMM III удалён) | чисто |
| `game/assets/ui/icons/schools/` | генератор репо `game/scripts/build/gen_school_icons.gd` | 4 png школ магии | записей нет | неизвестно |
| `game/assets/ui/widgets/buttons/` | генератор репо `game/tools/ui_kit/build_ui_kit.py` (шаг 4 ui-mockup-parity, 2026-10-19); прежние файлы — `cb9bfe49` (однотонные заглушки), перекрас снятым `recolor_button_textures.py` (носитель жил в `game/tools/`, убран шагом `f4de4cf3` по AC6 ASSET-2 — в индексе его нет, повторный прогон по новым ассетам запрещён) | 10 png: базовая кнопка 96×48 ×4 состояний, плита меню 120×68 ×4, чекбокс 24×24 ×2 | геометрия, цвета и зерно — замер макета `~/sigil-reference/09_start_screen_throne.jpeg` (плита 292×68, фаска 14, поле `#233F50`, σ≈11); hover/pressed/disabled выведены — в макете только normal; пофайловый след — `assets/ui/widgets/MANIFEST.json` | чисто — нарисованы в репо по своему замеру, прав третьих лиц нет (ASSET-2: носитель закрыт, §4.1 «дерево» vs сталь макета — вопрос к гайду) |
| `game/assets/ui/widgets/emblems/` | генератор репо `game/tools/ui_kit/build_round_button.py` (ui-mockup-parity §5, `de5c24e2`) | 8 png 144 px медальонов нижней панели боя (книга, флаг, шестерня, часы, кольцо, щит, пропуск, мечи) | пиксели рисуются кодом, форма и золото — числовой замер медальона `~/sigil-reference/11_battle_hex_snow.jpeg`; строка заведена этим прогоном (world-map-art-variety 8.1), потому что гейт один и без неё красный: правь не тот, кто нашёл | чисто — нарисованы в репо по своему замеру, прав третьих лиц нет |
| `game/assets/ui/widgets/panels/` | то же | 2 png (panel_bg 96×96, slot_bg 48×48) | та же мерка макета 09; рамка 7 и 6 px — отсюда маржа 9-slice в теме | чисто |
| `game/assets/ui/widgets/progress_bars/` | то же | 2 png (bar_bg, fill_health 40×20) | форма — рамка макета 09, цвет заполнения — сэмпл зелёной полосы макета 11; `fill_mana`/`fill_xp` не заведены: тема ссылается только на `fill_health`, боевые полосы — шаг 5 | чисто |
| `game/assets/ui/widgets/sliders/` | то же | 2 png (slider_track, slider_handle) | слайдера в макетах нет — вывод по грамматике рамки темы, помечено в MANIFEST как «вывод» | чисто — вывод, зафиксирован |
| `game/assets/units/` | не установлено — `8334a974` (2026-08-30) | 190 png юнитов (обычные + `_s`) | записей нет; свип §12.1 чист | неизвестно |
| `game/assets/sprites/knight/` | клип-цепочка ComfyUI (сервер 192.168.0.230:8188): edit по портрету `scripts/character_kit/portraits/knight.png` с картой позы `scripts/character_kit/poses/knight/*`, модель Qwen-Image 2.1; генератор `scripts/character_kit/gen_frames.py`, ункей и нарезка `scripts/character_kit/build_sprite_frames.py`, приёмка `scripts/character_kit/audit_sprites.py` | 20 png 512×512: idle/walk/attack/hit/turn по 4 кадра; холст, ступни и масштаб по ADR-008 (перерезка `7e6e733f`), в `game/assets/` переехали без правок (`960174c7`, 2026-10-27) | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; происхождение портрета-источника — реестр №1 `docs/archive/battle-demo/asset-spec.md`; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/spearman/` | то же, что `game/assets/sprites/knight/`, персонаж — `spearman` | 20 png 512×512: idle/walk/attack/hit/turn по 4 кадра; холст, ступни и масштаб по ADR-008 (перерезка `7e6e733f`), в `game/assets/` переехали без правок (`960174c7`, 2026-10-27) | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; происхождение портрета-источника — реестр №2 `docs/archive/battle-demo/asset-spec.md`; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/archer/` | то же, что `game/assets/sprites/knight/`, персонаж — `archer` | 20 png 512×512: idle/walk/attack/hit/turn по 4 кадра; холст, ступни и масштаб по ADR-008 (перерезка `7e6e733f`), в `game/assets/` переехали без правок (`960174c7`, 2026-10-27) | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; происхождение портрета-источника — реестр №3 `docs/archive/battle-demo/asset-spec.md`; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/wizard/` | то же, что `game/assets/sprites/knight/`, персонаж — `wizard` | 20 png 512×512: idle/walk/attack/hit/turn по 4 кадра; холст, ступни и масштаб по ADR-008 (перерезка `7e6e733f`), в `game/assets/` переехали без правок (`960174c7`, 2026-10-27) | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; происхождение портрета-источника — реестр №4 `docs/archive/battle-demo/asset-spec.md`; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/sorcerer/` | то же, что `game/assets/sprites/knight/`, персонаж — `sorcerer` | 20 png 512×512: idle/walk/attack/hit/turn по 4 кадра; холст, ступни и масштаб по ADR-008 (перерезка `7e6e733f`), в `game/assets/` переехали без правок (`960174c7`, 2026-10-27) | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; происхождение портрета-источника — реестр №5 `docs/archive/battle-demo/asset-spec.md`; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/barbarian/` | то же, что `game/assets/sprites/knight/`, персонаж — `barbarian` | 20 png 512×512: idle/walk/attack/hit/turn по 4 кадра; холст, ступни и масштаб по ADR-008 (перерезка `7e6e733f`), в `game/assets/` переехали без правок (`960174c7`, 2026-10-27) | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; происхождение портрета-источника — реестр №6 `docs/archive/battle-demo/asset-spec.md`; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/stormmage/` | то же, что `game/assets/sprites/knight/`, персонаж — `stormmage` | 20 png 512×512: idle/walk/attack/hit/turn по 4 кадра; холст, ступни и масштаб по ADR-008 (перерезка `7e6e733f`), в `game/assets/` переехали без правок (`960174c7`, 2026-10-27) | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; происхождение портрета-источника — реестр №7 `docs/archive/battle-demo/asset-spec.md`; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/priest/` | то же, что `game/assets/sprites/knight/`, персонаж — `priest` | 16 png 512×512: idle/walk/attack/turn по 4 кадра, дорожки `hit` нет — вместо кадра удара цветовая вспышка (`game/tests/unit/ui/test_battle_figures_animated.gd`); холст, ступни и масштаб по ADR-008 (перерезка `7e6e733f`), в `game/assets/` переехали без правок (`960174c7`, 2026-10-27) | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; происхождение портрета-источника — `flux-3-image_a_Перенести_стиль_с_из.png`, реестр №9 `docs/archive/battle-demo/asset-spec.md`; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/wolf/` | тот же конвейер, но источник — `scripts/character_kit/beasts/wolf.png` (t2i, `scripts/character_kit/gen_beast.py`, реестр №10) | 20 png 512×512: idle/walk/attack/hit/turn по 4 кадра, ADR-008, переезд `960174c7` | seed, промпт, модели и md5 каждого кадра — `scripts/character_kit/runs/generation-manifest.json` (184 записи), вердикты по кадрам — `docs/archive/battle-demo/generation-log.md`; волк — единственный анимированный враг, остальная сотня юнитов остаётся портретом; права на модель и на исходный портрет не проверялись | жёлтый |
| `game/assets/sprites/blackblade/` | `scripts/hero_anim/hero_anim.py` → ComfyUI (сервер 192.168.0.230:8188): профиль из выреза владельца `game/assets/units/figures/blackblade.png` (Qwen Image 2.1 + RemoveBackground), затем Wan 2.2 i2v (high/low 14B + lightx2v, 81 кадр на дорожку); ункей, общая рамка по всем дорожкам и прорежив до 12 — `scripts/hero_anim/integrate.py` | 60 png 512×512: idle/walk/attack/hit/turn по 12 кадров; холст, ступни (256, 448) и силуэт 384 px по ADR-008 — тот же носитель, что у `game/assets/sprites/knight/`; принятый вариант каждой дорожки — вердикт зрения, записан в `scripts/hero_anim/out/blackblade/<дорожка>/picked.json` (эти 25 файлов в git, сырые ролики — нет) | исходный силуэт — арт владельца (вырез 3.1); модель — Wan 2.2 (заявлена под Apache-2.0) и Qwen Image 2.1: права на веса и обучающие данные не проверялись — тот же класс риска, что у строк `sprites/knight/` | жёлтый |
| `game/assets/sprites/greenhood/` | `scripts/hero_anim/hero_anim.py` → ComfyUI (сервер 192.168.0.230:8188): профиль из выреза владельца `game/assets/units/figures/greenhood.png` (Qwen Image 2.1 + RemoveBackground), затем Wan 2.2 i2v (high/low 14B + lightx2v, 81 кадр на дорожку); ункей, общая рамка по всем дорожкам и прорежив до 12 — `scripts/hero_anim/integrate.py` | 60 png 512×512: idle/walk/attack/hit/turn по 12 кадров; холст, ступни (256, 448) и силуэт 384 px по ADR-008 — тот же носитель, что у `game/assets/sprites/knight/`; принятый вариант каждой дорожки — вердикт зрения, записан в `scripts/hero_anim/out/greenhood/<дорожка>/picked.json` (эти 25 файлов в git, сырые ролики — нет) | исходный силуэт — арт владельца (вырез 3.1); модель — Wan 2.2 (заявлена под Apache-2.0) и Qwen Image 2.1: права на веса и обучающие данные не проверялись — тот же класс риска, что у строк `sprites/knight/` | жёлтый |
| `game/assets/sprites/silverhalberd/` | `scripts/hero_anim/hero_anim.py` → ComfyUI (сервер 192.168.0.230:8188): профиль из выреза владельца `game/assets/units/figures/silverhalberd.png` (Qwen Image 2.1 + RemoveBackground), затем Wan 2.2 i2v (high/low 14B + lightx2v, 81 кадр на дорожку); ункей, общая рамка по всем дорожкам и прорежив до 12 — `scripts/hero_anim/integrate.py` | 60 png 512×512: idle/walk/attack/hit/turn по 12 кадров; холст, ступни (256, 448) и силуэт 384 px по ADR-008 — тот же носитель, что у `game/assets/sprites/knight/`; принятый вариант каждой дорожки — вердикт зрения, записан в `scripts/hero_anim/out/silverhalberd/<дорожка>/picked.json` (эти 25 файлов в git, сырые ролики — нет) | исходный силуэт — арт владельца (вырез 3.1); модель — Wan 2.2 (заявлена под Apache-2.0) и Qwen Image 2.1: права на веса и обучающие данные не проверялись — тот же класс риска, что у строк `sprites/knight/` | жёлтый |
| `game/assets/sprites/barehammer/` | `scripts/hero_anim/hero_anim.py` → ComfyUI (сервер 192.168.0.230:8188): профиль из выреза владельца `game/assets/units/figures/barehammer.png` (Qwen Image 2.1 + RemoveBackground), затем Wan 2.2 i2v (high/low 14B + lightx2v, 81 кадр на дорожку); ункей, общая рамка по всем дорожкам и прорежив до 12 — `scripts/hero_anim/integrate.py` | 60 png 512×512: idle/walk/attack/hit/turn по 12 кадров; холст, ступни (256, 448) и силуэт 384 px по ADR-008 — тот же носитель, что у `game/assets/sprites/knight/`; принятый вариант каждой дорожки — вердикт зрения, записан в `scripts/hero_anim/out/barehammer/<дорожка>/picked.json` (эти 25 файлов в git, сырые ролики — нет) | исходный силуэт — арт владельца (вырез 3.1); модель — Wan 2.2 (заявлена под Apache-2.0) и Qwen Image 2.1: права на веса и обучающие данные не проверялись — тот же класс риска, что у строк `sprites/knight/` | жёлтый |
| `game/assets/sprites/goldmace/` | `scripts/hero_anim/hero_anim.py` → ComfyUI (сервер 192.168.0.230:8188): профиль из выреза владельца `game/assets/units/figures/goldmace.png` (Qwen Image 2.1 + RemoveBackground), затем Wan 2.2 i2v (high/low 14B + lightx2v, 81 кадр на дорожку); ункей, общая рамка по всем дорожкам и прорежив до 12 — `scripts/hero_anim/integrate.py` | 60 png 512×512: idle/walk/attack/hit/turn по 12 кадров; холст, ступни (256, 448) и силуэт 384 px по ADR-008 — тот же носитель, что у `game/assets/sprites/knight/`; принятый вариант каждой дорожки — вердикт зрения, записан в `scripts/hero_anim/out/goldmace/<дорожка>/picked.json` (эти 25 файлов в git, сырые ролики — нет); ключа юнита нет, в игру кадры не входят (ждут строки `UnitRegistry`) | исходный силуэт — арт владельца (вырез 3.1); модель — Wan 2.2 (заявлена под Apache-2.0) и Qwen Image 2.1: права на веса и обучающие данные не проверялись — тот же класс риска, что у строк `sprites/knight/` | жёлтый |

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
- `game/assets/tiles/world_map_atlas.webp` + `.json` (манифест раскладки) — **сняты
  2026-11-09 носителем T-344**: клетку рисует `HexCellArt` (процедурный лист в
  памяти), файла-носителя нет, поэтому не нужна и строка провенанса — у картинки
  нет источника вне репозитория, она выводится кодом. Заодно снят
  `world_map_kit.{webp,json}` (резервный лист kit-решения): он **лежал в git** с
  коммитов T-341 без единой строки провенанса и без единого читателя в коде;
  запись «листа никогда не было в git» (CHANGELOG, 2026-11-09) верна лишь для
  исходников image-clone, отслеженные файлы были.

## Что это реестр не закрывает

- Статус `неизвестно` = происхождение не установлено, а не «прав достаточно».
  Свип §12.1 ловит побайтовый рип, пересжатие и перекрас того же кадра; он не
  ловит ни «похоже, но из другой библиотеки», ни «куплено с чеком, чек потерян».
- Классы со статусом `неизвестно` (units, artifacts, audio, cursors, ui/events,
  ui/hero, ui/icons, textures, tiles) — инвентаризация ASSET-1. Решение по ним
  принимает владелец: доказывать происхождение, менять или снимать с репо.
  Публичный билд с ними не выпускается (тикет ASSET-1, AC1).
- Девять каталогов `sprites/*` (176 кадров) — `жёлтый`, а не `чисто`: цепочка
  генерации доказана файлами репо (манифест, реестр прогонов, приёмка), но права
  на модель Qwen-Image 2.1 и на портреты-источники (реестр №1–10
  `docs/archive/battle-demo/asset-spec.md`) не проверялись. Это тоже ASSET-1, решение за
  владельцем; строка в реестре права не заменяет.
