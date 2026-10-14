---
title: Индекс документации
tags:
  - index
status: reference
date: 2026-10-14
---

> **Автогенерат — руками не редактировать.** Перегенерация:
> `python3 scripts/gen_docs_index.py`; проверка устаревания — тот же файл
> с `--check`. Зона та же, что у `scripts/check_docs_links.py`:
> банковская зона `docs/bank/` вне индекса (D-102).

> Статусы: `canon` / `deepened` / `draft` / `reference` / `redirect` /
> `snapshot` / `archived`. `redirect` — файл-перенаправление, читать цель.

## Реестры и процессы (14)

| Заметка | Название | Статус | Дата |
| --- | --- | --- | --- |
| [[BANK]] | Банк контента | reference | 2026-10-03 |
| [[CHANGELOG]] | Журнал изменений docs/ | reference | 2026-10-15 |
| [[DECISIONS]] | Реестр решений и открытых вопросов | canon | 2026-10-14 |
| [[QUESTIONS]] | Открытые вопросы — Фаза 4 (MVP и тикеты) | reference | 2026-10-15 |
| [[ACTOR-ARMY]] | Актёрная модель армии (K-канон) | canon | 2026-10-11 |
| [[GAP-LIST]] | Gap-лист GDD ↔ код (корзины A/B/C) | draft | 2026-10-15 |
| [[GDLINT-PROPOSAL]] | gdlint-конфиг — предложение (раунд 12 §3) | reference | 2026-10-12 |
| [[GDUNIT4-VACUOUS-ASSERT-ISSUE]] | Draft: upstream issue gdUnit4 — silent no-op assert without check method | draft | 2026-10-13 |
| [[MVP_SCOPE]] | MVP-скоуп — итог Фазы 4 | reference | 2026-10-13 |
| [[PR-ASSET-1]] | Тело PR ASSET-1 (feat/asset-1-resources) | draft | 2026-10-15 |
| [[PR-DOCS-ARTBIBLE]] | Тело PR docs (feat/art-bible-rev2) | archived | 2026-10-14 |
| [[PR-UI-PHASE5]] | Тело PR фазы 5 (feat/ui-phase5) | archived | 2026-10-14 |
| [[TICKETS]] | Тикеты MVP (T-001…T-113) | reference | 2026-10-14 |
| [[f-plan]] | F-план — приёмка Д1/Д2 и сведение расхождений | draft | 2026-10-04 |

## GDD и стиль (46)

| Заметка | Название | Статус | Дата |
| --- | --- | --- | --- |
| [[00-glossary]] | Глоссарий — единая терминология | deepened | 2026-10-13 |
| [[00-overview]] | High Concept / Elevator Pitch | deepened | 2026-10-13 |
| [[01-core-loop]] | Core Loop | deepened | 2026-10-13 |
| [[02-mechanics]] | Механики и системы | deepened | 2026-10-13 |
| [[02b-binoms-terrain]] | Биномы героев и штрафы местности | deepened | 2026-10-13 |
| [[02c-signs]] | Восьмь Знаков — контент-справочник | deepened | 2026-10-13 |
| [[02d-antagonism]] | Антагонизм характеристик (02d v1.1) | deepened | 2026-09-30 |
| [[02d-classes-skills]] | Классы, навыки, характеристики — справочник (v1.0) | deepened | 2026-10-03 |
| [[02d-combat-core]] | Боевое ядро (02d combat core) — хаб | canon | 2026-10-11 |
| [[02d-luck-professions]] | Удача и матрица профессий (02d v1.2) | deepened | 2026-10-13 |
| [[02e-city]] | Карта, ресурсы, город, военка — пре-пивотный канон (хаб) | canon | 2026-10-03 |
| [[02e1-base-map-v1]] | Базовая карта v1 — граф регионов (MAP-1, Ф3) | archived | 2026-10-03 |
| [[02e1-base-map]] | Базовая карта — граф регионов v1 (MAP-1, Ф3) | canon | 2026-10-03 |
| [[02e1-map]] | Карта и пространство — канон (02e §4) | canon | 2026-10-03 |
| [[02e2-city]] | Ресурсы, здания, соседство, районы — канон (02e §5–8) | canon | 2026-10-13 |
| [[02e3-races]] | Расы и культуры — канон (02e §9) | canon | 2026-10-13 |
| [[02e4-military]] | Военная система, бой и угрозы — канон (02e §12–13) | canon | 2026-10-13 |
| [[02f-a-core]] | Социальная система — ядро (части I–XII) | draft | 2026-10-02 |
| [[02f-b-new-layers]] | Социальная система — новые слои (части XIII–XXVII) | draft | 2026-10-02 |
| [[02f-c-forest-city-economy]] | Социальная система — Лес, город, экономика (части XXVIII–XXXVI) | draft | 2026-10-02 |
| [[02f-d-world]] | Социальная система — мир и ритмы (части XXXVII–XLIII) | draft | 2026-10-02 |
| [[02f-e-society]] | Социальная система — общество и игрок (части XLIV–XLIX) | draft | 2026-10-02 |
| [[02f-f-scenarios]] | Социальная система — сценарии и сводки (части L–LII) | draft | 2026-10-02 |
| [[02f-meta]] | Социальная система — эпилог и маппинг интеграции | reference | 2026-10-02 |
| [[02f-social]] | Социальная система — хаб (рамка Q16 и индекс частей I–LII) | draft | 2026-10-02 |
| [[02g-city-hex]] | Город: hex-сборка и уровни (основная механика) | canon | 2026-10-02 |
| [[03-progression]] | Прогрессия и мета-цикл | deepened | 2026-10-13 |
| [[04-narrative]] | Нарратив / Сеттинг / Тон | deepened | 2026-10-02 |
| [[05-content]] | Контент-пайплайн | deepened | 2026-10-13 |
| [[06-economy]] | Экономика и баланс | deepened | 2026-10-13 |
| [[07-balance]] | Баланс-лист — единый источник чисел | canon | 2026-10-13 |
| [[07-ui-ux]] | UI/UX flow | deepened | 2026-10-13 |
| [[08-tech]] | Технический стек и платформы | deepened | 2026-09-30 |
| [[09-risks]] | Риски и открытые вопросы | deepened | 2026-10-13 |
| [[10-appendix-a-races]] | Приложение А — A6-R-таблица каталога 54 | canon | 2026-10-13 |
| [[12-asset-audit]] | Asset Audit — game/assets | snapshot | 2026-10-13 |
| [[13-art-bible]] | Art Bible — визуальная идентичность | deepened | 2026-10-14 |
| [[14-ux-battle-hud]] | UX-спека — боевой HUD (UI-2) | draft | 2026-10-13 |
| [[15-asset-spec-artifacts]] | Asset-spec — 29 иконок артефактов (UI-4) | draft | 2026-10-13 |
| [[16-ux-review-battle-hud]] | UX-ревью боевого HUD (UI-3, шаг 3) | draft | 2026-10-13 |
| [[17-ui-style-guide]] | UI Style Guide — Sigil of the Unwilling | deepened | 2026-10-14 |
| [[CONFLICTS_REPORT]] | — | архив (вне графа) | — |
| [[MVP-scope]] | MVP Scope — доказательство, что core loop fun | deepened | 2026-10-13 |
| [[NORMALIZATION_REPORT]] | — | архив (вне графа) | — |
| [[STRUCTURE_AUDIT]] | Аудит структуры docs/ (Фаза 2) | active | 2026-10-02 |
| [[UNIFICATION_CHANGES]] | — | архив (вне графа) | — |
