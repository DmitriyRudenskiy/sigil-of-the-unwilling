# Proposal: settlement-system

## Why

Прототип поселения (систематизированное описание рас, зданий и
развития; база — `.claude/commands/opsx/proposal-settlement-system.md`,
PR #4) описывает полноценную игру-поселение: 7 видов с Resolve и
потребностями, здания с рецептами, репутация как победа, Forest
Hostility + штормы как давление, Smoldering City как meta-прогрессия,
Prestige-уровни. Текущая игра — героический вылазочный цикл;
поселения-поселенцы, виды, Resolve, репутация-победа и meta-столица
в проекте отсутствуют.

Ключевой принцип прототипа: "вы строите временную машину для
производства Репутации, а не город для вечности" — адаптивность и
быстрая перестройка важнее оптимизации; проигранное поселение
приносит meta-ресурсы.

## What Changes

- **Виды (7)**: 5 основных (human, beaver, lizard, harpy, fox) +
  2 DLC-дополнительных (frog — SC L9 "Keepers of the Stone", bat —
  SC L11 "Nightwatchers", статистика bat TBD). Статистика: Base
  Resolve, Demand (порог Resolve для генерации репутации), Decadence
  (снижение порога за очко репутации), Hunger Tolerance, Break
  Interval, черты. Караван — ≤3 видов.
- **Поселение как сущность мира**: на hex-кластере (ядро 4 тайла +
  кольца 1–3 — сестринский change `city-hex-layout-prototype`;
  дефолт `[center]` до его готовности).
- **Resolve и потребности**: еда (сырая/сложная), одежда
  (Coats +5/+3 шторм, Boots +5/+15% скорость), жильё, сервис;
  бонусы потребностей +4..+10; специализации (Proficiency 10%
  двойное, Comfort +5); Firekeeper (вид-бонус); Resolve→0 = уход.
- **Здания**: Ancient Hearth (уровни 1–3 за дома/декор в радиусе),
  Main Warehouse, лагеря (5, малые — только малые узлы),
  производство (1 рецепт: Lumber Mill, Bakery, Granary, Crude
  Workstation, Cooperage-гарпии, Tinctury-бобры), жильё (Shelter 3,
  Big Shelter 3, дома видов 2 с ценами/унлоками), улучшения домов
  (2 уровня, выбор 1 из 2 бонусов), сервис + Unified/Commons
  (SC L6), Small Hearth (−Hostility), Small Warehouse, Trading
  Post, Rainpunk Engines.
- **Репутация и враждебность**: Demand/Decadence-механика,
  Hostility (год/поселенец/glade/лагерь), glade (Dangerous/
  Forbidden), штормы (∝ Hostility), Prestige 1–10 (не-remote).
- **Победа/поражение**: победа — Reputation-метр заполнен;
  поражение — все поселенцы ушли/умерли или критическая
  нестабильность.
- **Meta**: Smoldering City — Citadel-ресурсы (Ancient Tablets),
  перманентные апгрейды (стартовые здания, улучшения видов,
  бонусы), ункилоки видов/зданий/улучшений, meta-сейв.

## Capabilities

### New Capabilities
- `settlement-species`: виды (7), караван (≤3), специализации,
  определения статистик
- `settlement-resolve`: Resolve, потребности (числа бонусов),
  голод/перелом, Firekeeper, уход
- `settlement-buildings`: здания (hearth, warehouse, лагеря,
  производство, жильё + улучшения, сервис/Unified), рецепты,
  стройка, продвинутые (Small Warehouse, Trading Post, Rainpunk)
- `settlement-reputation`: Demand/Decadence, Hostility, glade,
  штормы, Prestige, победа/поражение
- `smoldering-city`: meta-столица, Citadel-ресурсы, апгрейды,
  ункилоки, meta-сейв

## Impact

- **Код**: `scripts/settlement/` (Species, Resolve, Buildings,
  Reputation, SmolderingCity), `scripts/data/settlement_species.gd`,
  `settlement_buildings.gd`, `smoldering_upgrades.gd`; интеграция
  с `WorldBootstrap`, meta-ключ в сейве
- **Данные**: статистика видов 1:1 из прототипа; цены домов из
  таблицы; Prestige 1–10 из описания
- **Зависимости**: `city-hex-layout-prototype` (кластер; дефолт
  `[center]`), MCP-сервер (сценарий "поселение доживает")
- **Тесты**: unit (виды, resolve, здания, репутация, prestige,
  meta), MCP-сценарий
- **Не трогается**: герой, армия, бои, города (City/Borough),
  tech tree

## Non-goals (отложены)

- Статистика bat (TBD в прототипе) — вид зарегистрирован,
  статистика появится с DLC
- Карты/биомы/трансформация ландшафта (отдельный слой геймплея)
- Prestige-уровни с remote-механиками (исключены из описания)
- Бонус "Кооперация" (3+ лисы в здании) — авторская механика,
  детали TBD
- Туториал

## Данные-пробелы (уточнить)

- Bat: все числовые характеристики
- Fox/Frog/Bat House: стоимость
- Frog: унлок SC L9 vs L13 (принято L9)
