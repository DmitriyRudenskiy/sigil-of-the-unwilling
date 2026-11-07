## Why

Кампейн-слой — результат cutover-акта D-157/D-163 (2026-10-11: `main_menu → character_creation → main.tscn`, `world.tscn → scenes/archive`) — за месяц не стал играбельным путём: игрок, создавший героя и выбравший Знак, попадает на экран, где **нельзя сделать ни одного хода** (стартовый запас провизии `RegionMap` = 0 при стоимости перехода `партия × дни` ≥ 1 → все соседи помечены «мало провизии»), а сама карта — MVP-маска из пяти регионов, три из которых на экране отдаются чёрными шестиугольниками. Носители слоя при этом в открытой работе: T-196 (сырые id юнитов), T-280 (медуальон перекрывает табличку отряда). Играбельный цикл, который реально проходит полный проход, живёт в world/adventure-слое (`world_ui.tscn` → `adventure_ui.tscn`, город — отдельным слоем `CityScreenLayer/CityScreen`).

Решение владельца (2026-11-05): **механику кампании удалить вместе со сценами и документацией, рантайм-путь вернуть на экран приключения, на кампейн поставить явный запрет.**

## What Changes

- **BREAKING — удаляется кампейн-механика целиком:** корень сборки `CampaignComposition`, экран `scenes/main/main.tscn`, `scripts/campaign/**` (19 `.gd`), `scripts/ui/campaign*.gd` (10), `scripts/main/main.gd`, `map_screen_model.gd`, регион-граф `RegionMap` с движением/провизией/туманом/узлами.
- **BREAKING — поток после Знака меняется:** `sign_choice_ui.gd:9` (`_CAMPAIGN_SCENE := "res://scenes/main/main.tscn"`) ведёт прямо в **`res://scenes/ui/adventure_ui.tscn`** — путь назван владельцем дважды (2026-11-05) и становится точкой входа; `main.tscn` из потока исчезает. Чтобы сцена была самодостаточной, мир монтируется внутрь неё, а `scenes/ui/world_ui.tscn` и `scenes/archive/world.tscn` как отдельные носители упраздняются (их содержимое переезжает в `adventure_ui.tscn`) — детали и цена в design.md, решение 1. Цепочка `main_menu → character_creation → sign_choice` остаётся: `character_creation_ui.gd` уходит на `sign_choice.tscn` (константа там называется `_CAMPAIGN_SCENE`, но ведёт к Знаку — имя правится заодно), профиль героя передаётся через `Services.resolve(&"persistence").pending_new_game` — world-сервис, он жив.
- **Город — отдельной сценой:** `scenes/ui/city_screen.tscn` остаётся единственным носителем города и хостится слоем `CityScreenLayer` world-носителя, а не кампейн-HUD'ом. С кампанией уходят её поля на общем `City`: `campaign_buildings`, `campaign_training`, `campaign_group_state`, `city_manager.is_campaign` и соответствующие ветки `city_serializer.gd`.
- **Запрет (новый носитель):** тест-гейт, краснеющий, если кампейн-слой возвращается в дерево (пути `scripts/campaign/`, `scenes/main/main.tscn`, вызовы `CampaignComposition`/драйвера ходов); строка запрета в `AGENTS.md` и запись в `docs/DECISIONS.md` — новый D вытесняет D-157 и D-163; рантайм-отказ: кампейн-сейвы не грузятся (fail-fast с причиной, миграции нет — переносить состояние в другую механику некорректно).
- **Тесты и съёмка:** удаляются 39 тестовых файлов, цепляющих кампанию (из них 42 по имени), 10 capture-фикстур `campaign*`, 6 pytest-файлов MCP-e2e; манифест съёмки теряет кампейн-носители и возвращает `world_ui.tscn`.
- **Документация:** 6 спек `campaign-*` и `region-graph-map` уходят как удалённые; в `docs/mvp/TICKETS.md` (116 упоминаний) кампейн-тикеты закрываются как снятые с плана с причиной и ссылкой на новый D.
- **Снимается решение владельца D-204 (Q-M87 → (б)):** «архивный `scenes/archive/world.tscn` не реанимируется, экран кампании собирается новым слоем HUD на `main.tscn`» — указание 2026-11-05 отменяет его: носитель из архива возвращается, а новым слоем HUD становится `adventure_ui.tscn`. План переноса четырёх панелей (`resource_bar`, `minimap_panel`, `army_panel`, `hero_status_panel`) из архивной цепочки в кампейн-HUD (ui-mockup-parity 7.1) становится не нужен: панели остаются на своём месте.
- Сегодняшняя правка снабжения карты (`campaign_composition.gd` + `test_campaign_start_supply.gd`) **откатывается** вместе с регион-графом — чинить нечего.

## Capabilities

### New Capabilities

- `campaign-lockout`: носитель запрета на кампейн-механику — статический гейт на возвращение файлов и вызовов в дерево, рантайм-отказ грузить кампейн-сейвы, зафиксированная в реестре решений причина запрета.

### Modified Capabilities

- `pregame-flow`: после создания героя и выбора Знака игрок попадает на экран приключения, а не на экран кампании; герой и Знак доживают до этого экрана.
- `mvp-ui-flow`: экран MAP — adventure-экран world-слоя; город — отдельная сцена, а не слой кампейн-HUD; кампейн-экрана в наборе восьми нет; после предыгры вход в MAP прямой.

Снятые с плана требования семи кампейн-возможностей описаны дельтами `REMOVED` (см. ниже). Остальные доки и носители, где кампейн упоминается как пример или как объект съёмки (`theme-type-hygiene`, `ui-screenshot-verification`, `ui-graphics`, `city-construction-districts`, `party-characters`, `signs-prestige`), правятся по факту — их контракты поведения не меняются, поэтому дельт на них нет.

### Removed Capabilities

- `campaign-core-loop`, `campaign-hud`, `campaign-city-construction`, `campaign-city-economy`, `campaign-city-level-progression`, `campaign-city-management-ui`, `region-graph-map`: механика снята с плана целиком (46 требований).

## Impact

| поверхность | объём |
| --- | --- |
| код | `scripts/campaign/**` 19 `.gd`, `scripts/ui/campaign*.gd` 10, `scripts/main/main.gd`, `scenes/main/main.tscn`; `scenes/ui/adventure_ui.tscn` становится точкой входа, `scenes/ui/world_ui.tscn` и `scenes/archive/world.tscn` упраздняются |
| общий `City` | снятие 3 полей + веток сериализатора, ветка `is_campaign` в `city_manager.gd` |
| тесты | 39 файлов GdUnit, 10 capture-фикстур, 6 pytest MCP-e2e; слои `--tier=smoke/fast` пересобираются |
| сейвы | схема T-110 теряет секции `campaign.*`; загрузка кампейн-сейвов = отказ с причиной |
| спеки/доки | 7 спек удалены, 7 изменены, 1 новая; `docs/mvp/TICKETS.md` — 116 упоминаний, `docs/DECISIONS.md` — вытеснение D-157/D-163 |
| риск | world-слой не запускался из рантайм-пути с 2026-10-11 (месяц без прогонов); первым шагом — проверка загрузки `world_ui.tscn` до удаления чего-либо |
