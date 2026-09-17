# Tasks: settlement-system

## Фаза 1: Виды и караван

- [x] 1.1 `scripts/data/settlement_species.gd` — 7 видов (статистика
  1:1: Resolve/Demand/Decadence/голод/перерыв/черты; bat — заглушка
  `available: false`; frog/bat — dlc-флаг)
- [x] 1.2 `scripts/settlement/Settlement.gd` — сущность (state:
  settlers, buildings, resources, day, hostility, reputation)
- [x] 1.3 Караван: ≤3 видов, формирование поселения
- [x] 1.4 Тесты: таблица 7 видов, караван 3/4, frog DLC-gate

## Фаза 2: Resolve и потребности

- [x] 2.1 `SettlementResolve.gd` — Resolve, голод (толерантность),
  перерывы (Break Interval → ходы)
- [x] 2.2 Потребности: еда (сырая/сложная), одежда (coats +5/+3
  шторм, boots +5/+15%), жильё, сервис (бонусы +4..+10)
- [x] 2.3 Firekeeper (вид-бонус: harpy скорость, lizard Resolve)
- [x] 2.4 Уход при Resolve 0 (освобождение жилья/места)
- [x] 2.5 Тесты: голод lizard/harpy/fox, перерыв, Firekeeper, уход

## Фаза 3: Здания

- [ ] 3.1 `settlement_buildings.gd` — здания, рецепты, цены домов,
  ункилоки
- [ ] 3.2 `SettlementBuildings.gd` — hearth (L1–3 за дома/декор),
  warehouse, лагеря (5, малые узлы), производство (1 рецепт: Lumber
  Mill, Bakery, Granary, Crude Workstation, Cooperage, Tinctury)
- [ ] 3.3 Жильё: Shelter (3, frog нет), Big Shelter (3), дома видов
  (2, цены/унлоки); радиус hearth
- [ ] 3.4 Стройка свободными поселенцами (циклы, материалы)
- [ ] 3.5 Автопереселение
- [ ] 3.6 Тесты: стартовые, 1 рецепт, малые узлы, радиус, стройка

## Фаза 4: Репутация, враждебность, штормы

- [ ] 4.1 `SettlementReputation.gd` — Demand/Decadence (Resolve >
  Demand → очки; порог −Decadence за очко), общий метр, победа
- [ ] 4.2 Hostility: рост (год/поселенец/glade/лагерь), Small
  Hearth, glade (Dangerous/Forbidden)
- [ ] 4.3 Шторм: ∝ Hostility, coats +3, увольнение лесорубов,
  массовый исход
- [ ] 4.4 Поражение: нет поселенцев / нестабильность
- [ ] 4.5 Тесты: Demand/Decadence, рост Hostility, шторм, 2
  поражения, победа

## Фаза 5: Smoldering City (meta)

- [ ] 5.1 `SmolderingCity.gd` — Citadel-ресурсы (Ancient Tablets),
  доля из поселения (поражение 50% / победа 100%)
- [ ] 5.2 `smoldering_upgrades.gd` — апгрейды (стартовые здания,
  виды, ресурсы)
- [ ] 5.3 Ункилоки: frog L9+DLC, bat L11+DLC, Unified L6, дома
  V1–6, улучшения L11/12
- [ ] 5.4 Meta-сейв (отдельный ключ, переживает прогоны)
- [ ] 5.5 Тесты: покупка, ункилоки, meta-сейв

## Фаза 6: Продвинутые + Prestige

- [ ] 6.1 Улучшения домов (2 уровня, выбор 1 из 2 бонуса)
- [ ] 6.2 Сервис (таверна) + Unified/Commons (SC L6, меньше бонус)
- [ ] 6.3 Small Warehouse, Trading Post (Amber), Rainpunk,
  дождевая вода
- [ ] 6.4 Prestige 1–10 (const-таблица модификаторов, флаг после
  победы)
- [ ] 6.5 Тесты: улучшения, Unified, торговля, каждый Prestige

## Фаза 7: Интеграция и регрессия

- [ ] 7.1 Поселение на hex-кластере (после city-hex-layout;
      дефолт [center])
- [ ] 7.2 MCP-сценарий "поселение доживает до шторма" (детерминизм)
- [ ] 7.3 GdUnit4: все тесты зелёные (регрессия 1605+)
- [ ] 7.4 MCP: 27+ passed, 60-ходовая проба RUNNING
