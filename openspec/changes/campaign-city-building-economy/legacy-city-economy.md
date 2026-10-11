# Легаси city-economy (campaign-building economy)

> [!danger] ЛЕГАСИ, НЕ КАНОН (T-121 акт 1.2, владелец, 13-я итерация §1.2).
> Перенесено из `docs/06-economy.md` актом владельца: канонические доки описывают
> только канонические системы; документация легаси-систем внутри канонического
> документа воссоздаёт болезнь основания проекта (три источника истины).
> **Статус:** к замене K-канон-линией (T-010/T-040/T-070; срез — по критерию
> T-121 §1.3, реестр D-157). До среза — только фиксы загрузочности (краши,
> гигиена); новые фичи запрещены.

> [!warning] Эта запись описывает линию `campaign-city-building-economy`
> (влита в main), а не ратифицирует баланс основной ветки. Её боевой каталог
> находится в `game/assets/data/campaign_building_catalog.json`; числовые
> значения и custom merges разработаны для правил проекта. Source references
> establish identity only. Candidate/unknown rows не входят в билд; полнота
> AtS/TerraScape roster не заявляется.

- Кампанийные здания используют существующий объект города и `ResourceContext`; запас еды в `CityData` — совместимый фасад над тем же food stock, не второй счёт.
- Turn ledger собирает потребление населения, рейдовые потери, кампанийные рецепты/upkeep и обучение персонажа. Обучение может выполнять атомарный transaction через тот же контекст; party сохраняется существующим MVP-save.
- Runtime сохраняет ancestry/archetype и состояние кампанийных зданий; миграция старого food stock выполняется при переходе city save к версии 5.
- Допустимые campaign-building и training transactions ограничены MVP-маской `{еда, дерево, железо}`. Это не меняет канонический реестр K-R2, не добавляет отдельный city/world или победный score-mode и не утверждает source-game значения. См. change-scoped контракты в `openspec/changes/campaign-city-building-economy/specs/`.
- Placement, adjacency, merge, group needs/relations, production/upkeep and static defense имеют детерминированные сервисы и тесты. Runtime catalog admits only confirmed public rows or campaign-canon baseline rows; `audit_campaign_catalog.py` verifies every confirmed external row is admitted or reason-excluded, with zero candidate/unknown rows and nulls. Публичный census остаётся неполным для AtS/TerraScape; UI/playtest не покрыты headless-тестами.

## Связанные бан-маркеры (T-121)

- 🚫 `game/scripts/city/raid_system.gd` (шансовые рейды) — в кампанийный цикл; легаси city-arena (акт 1.1); смерть — в момент среза.
- 🚫 Новые экономические системы — ни в один из циклов до акта интеграции (для K-канон-цикла запрет снимается после T-050 FINISH; для легаси — до среза).
- Скоба: `request_battle` — единственная точка входа в бой K-канон-кампании; легаси-бой огорожен внутри легаси-кампании (T-050 §2.3).
