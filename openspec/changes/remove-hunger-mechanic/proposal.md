# Удаление механики голода

## Why

Голод (`hunger`) как потребность выживания — лишний слой: герой и горожане
умирают от голода, но еда в реальности живёт только в городской экономике
(склад, рождения, approval, рынок). Убираем выживальскую обвязку вокруг еды:
механика голода исчезает, еда остаётся городским ресурсом. Это снимает
главную причину смерти героя в длинных сценариях (scenarios 1–4 умирали
именно от голода) и упрощает контур потребностей: 4 ключа → 3.

## What Changes

- **BREAKING**: `Character.NEED_KEYS` теряет `&"hunger"` — канонический набор
  потребностей становится `[rest, social, inspiration]` (общий для героя и
  горожан).
- Герой больше не умирает от голода: из `HeroNeeds` уходят распад,
  городское восстановление (включая ветку `city.starving`) и причина смерти
  `&"starvation"`.
- Горожане больше не умирают от голода: из `DemographicTurnProcessor` уходят
  распад `hunger`, ветка восстановления от города и причина смерти
  `&"starvation"`.
- Черты, модифицирующие голод, удаляются или перенацеливаются: `hardy`,
  `appetite`, `iron_stomach` — удаляемы; `gorgon_taste` — перенацеливается
  на общение (едать — социальное).
- UI: из панели героя исчезает полоса 🍞, из `DeathSequence` — «от голода»,
  из комментов `GameEventBus` — `"starvation"` в перечне причин.
- **Еда остаётся городским экономическим ресурсом без изменений**:
  `food_stockpile`, `net_food()`, `food_consumption()`, флаг `starving`
  (штраф к `approval()` — «настроение» города), рождения (порог
  `growth_threshold()` — «привлекательность» города), торговля на рынке
  (`MarketSystem`, еда продаётся из `food_stockpile`).
- **Еда не является ресурсом внешнего мира** — это фиксируется как
  документационный принцип (в коде и так так: ни узла еды на карте, ни
  базового ресурса еды у героя).
- Обновление документации механик: потребности (герой/горожане), роль еды
  в городе, перечень причин смерти.
- Гейм-тесты (GUT) и сценарный `keep_alive` подстраиваются под 3 потребности;
  сценарии 1–4 становятся легче (герой не голодает в поле).
- Старые сейвы: ключ `"hunger"` в сериализованных потребностях
  игнорируется при загрузке (паттерн миграции, как `belief`→`inspiration`).

## Capabilities

### New Capabilities

(нет — новые системы не вводятся)

### Modified Capabilities

- `inspiration`: требование «Inspiration is a core internal need» — набор
  жизненного контура меняется с «hunger, rest and social» на «rest and
  social» (hunger удалён).
- `succession`: сценарий «Hero dies from a depleted need» — перечень
  потребностей (rest/social/inspiration вместо hunger/rest/social) и
  пример причины смерти (`&"exhaustion"` вместо `&"starvation"`).

## Impact

- **Код (ядро)**: `scripts/demographics/Character.gd` (NEED_KEYS),
  `scripts/entities/HeroNeeds.gd`,
  `scripts/demographics/DemographicTurnProcessor.gd`,
  `scripts/demographics/TraitRegistry.gd`, `scripts/demographics/TraitDef.gd`
  (коммент).
- **UI/автозагрузка**: `scripts/ui/HeroStatusPanel.gd`,
  `scripts/ui/DeathSequence.gd`, `scripts/autoload/GameEventBus.gd`
  (коммент), `scripts/entities/HeroController.gd` (коммент).
- **Сценарии**: `tools/scenarios/scenario_lib.py` (`keep_alive` — комменты;
  логика не зависит от состава needs), сценарии 1–4 без правок прогона.
- **Тесты**: `tests/test_hero_survival.gd`, `tests/test_characters.gd`,
  `tests/test_demographic_processor.gd`, `tests/test_trait_registry.gd`.
- **Доки**: `docs/economy/economy_runtime.md` (фаза демографии),
  `docs/systems/city_system.md` (роль еды),
  `docs/concepts/TASK_SOCIAL_AND_BUILDINGS.md` (NEED_KEYS),
  `docs/concepts/CONCEPT_SOCIAL_RACES.md` (лисы и голод — концепт-заметка),
  `docs/concepts/CONCEPT_CHARACTER_SYSTEM.md` (при наличии упоминаний).
- **Не меняется**: городская экономика еды (`City.gd`, `MarketSystem.gd`,
  `SpecializationSystem`, `CityYieldTable`), узлы ресурсов на карте,
  базовые ресурсы героя (wood/stone), сейв-схема (ключ просто не читается).
