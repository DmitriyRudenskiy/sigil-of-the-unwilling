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

## Реестры и процессы (23)

| Заметка | Название | Статус | Дата |
| --- | --- | --- | --- |
| [[BANK]] | Банк контента | reference | 2026-10-03 |
| [[CHANGELOG]] | Журнал изменений docs/ | reference | 2026-10-29 |
| [[DECISIONS]] | Реестр решений и открытых вопросов | canon | 2026-10-21 |
| [[QUESTIONS]] | Открытые вопросы — Фаза 4 (MVP и тикеты) | reference | 2026-10-24 |
| [[ACTOR-ARMY]] | Актёрная модель армии (K-канон) | canon | 2026-10-11 |
| [[CAPTURE-HELPER]] | Хелпер съёмки экрана (capture helper) | reference | 2026-10-25 |
| [[EPICS]] | Эпики MVP + вертикальный срез (этап 3 цепочки) | draft | 2026-10-17 |
| [[GAP-LIST]] | Gap-лист GDD ↔ код (корзины A/B/C) | draft | 2026-10-17 |
| [[GDLINT-PROPOSAL]] | gdlint-конфиг — предложение (раунд 12 §3) | reference | 2026-10-12 |
| [[GDUNIT4-VACUOUS-ASSERT-ISSUE]] | Draft: upstream issue gdUnit4 — silent no-op assert without check method | draft | 2026-10-13 |
| [[MVP_SCOPE]] | MVP-скоуп — итог Фазы 4 | reference | 2026-10-15 |
| [[PR-ASSET-1]] | Тело PR ASSET-1 (feat/asset-1-resources) | draft | 2026-10-15 |
| [[PR-DOCS-ARTBIBLE]] | Тело PR docs (feat/art-bible-rev2) | archived | 2026-10-14 |
| [[PR-UI-PHASE5]] | Тело PR фазы 5 (feat/ui-phase5) | archived | 2026-10-14 |
| [[TEST-MAP]] | Карта тестов: покрытие меньшим количеством тестов | reference | 2026-10-28 |
| [[TICKETS]] | Тикеты MVP (T-001…T-113) | reference | 2026-10-25 |
| [[VERDICT-REQUEST]] | Вердикты владельца — блокирующие решения (verdict-request) | reference | 2026-10-26 |
| [[f-plan]] | F-план — приёмка Д1/Д2 и сведение расхождений | draft | 2026-10-04 |
| [[README]] | Снимок матрицы автопилота 2026-10-26 | reference | 2026-10-26 |
| [[README]] | — | — | — |
| [[t172-readiness-failure-evidence]] | — | — | — |
| [[ux-battle-99]] | UX-review поля боя 11×9 (battle-99-hex-clean-hud) | reference | 2026-10-28 |
| [[ux-theme-t228]] | UX-review T-228 — витрина §4.8 (пластина подсказки) и экран инвентаря | reference | 2026-10-28 |

## GDD и стиль (87)

| Заметка | Название | Статус | Дата |
| --- | --- | --- | --- |
| [[00-glossary]] | Глоссарий — единая терминология | deepened | 2026-10-21 |
| [[00-overview]] | High Concept / Elevator Pitch | deepened | 2026-10-21 |
| [[01-core-loop]] | Core Loop | deepened | 2026-10-16 |
| [[02-mechanics]] | Механики и системы | deepened | 2026-10-21 |
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
| [[02e4-military]] | Военная система, бой и угрозы — канон (02e §12–13) | canon | 2026-10-16 |
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
| [[06-economy]] | Экономика и баланс | deepened | 2026-10-27 |
| [[07-balance]] | Баланс-лист — единый источник чисел | canon | 2026-10-16 |
| [[07-ui-ux]] | UI/UX flow | deepened | 2026-10-29 |
| [[08-tech]] | Технический стек и платформы | deepened | 2026-09-30 |
| [[09-risks]] | Риски и открытые вопросы | deepened | 2026-10-21 |
| [[10-appendix-a-races]] | Приложение А — A6-R-таблица каталога 54 | canon | 2026-10-13 |
| [[12-asset-audit]] | Asset Audit — game/assets | snapshot | 2026-10-13 |
| [[13-art-bible]] | Art Bible — визуальная идентичность | deepened | 2026-10-18 |
| [[14-ux-battle-hud]] | UX-спека — боевой HUD (UI-2) | draft | 2026-10-28 |
| [[15-asset-spec-artifacts]] | Asset-spec — 29 иконок артефактов (UI-4) | draft | 2026-10-13 |
| [[16-ux-review-battle-hud]] | UX-ревью боевого HUD (UI-3, шаг 3) | draft | 2026-10-13 |
| [[17-ui-style-guide]] | UI Style Guide — Sigil of the Unwilling | deepened | 2026-10-18 |
| [[18-lora-style-groups]] | Теги стилей обучающей нарезки — измерено, а не на глаз | reference | 2026-10-27 |
| [[18-system-map]] | Карта систем | reference | 2026-10-29 |
| [[19-gdd-workflow]] | Контур фаз GDD | reference | 2026-10-27 |
| [[20-ux-hero-screen]] | Экран «Герой» — карта элементов макета 12 | draft | 2026-10-28 |
| [[21-ux-map-screen]] | Экран «Карта кампании» — карта элементов макета 10 | draft | 2026-10-29 |
| [[CONFLICTS_REPORT]] | — | архив (вне графа) | — |
| [[MVP-scope]] | MVP Scope — доказательство, что core loop fun | deepened | 2026-10-21 |
| [[NORMALIZATION_REPORT]] | — | архив (вне графа) | — |
| [[STRUCTURE_AUDIT]] | Аудит структуры docs/ (Фаза 2) | active | 2026-10-02 |
| [[UNIFICATION_CHANGES]] | — | архив (вне графа) | — |
| [[CONFLICTS]] | Реестр расхождений референса и канона | reference | 2026-10-16 |
| [[README]] | docs/reference — справочники чужих игр (не канон Sigil) | reference | 2026-10-16 |
| [[ats-buildings]] | Against the Storm: здания (Buildings) | reference | 2026-10-16 |
| [[ats-canon]] | Against the Storm: свод канона (референс) | reference | 2026-10-16 |
| [[ats-goods]] | Against the Storm: товары и ресурсы (Goods) | reference | 2026-10-16 |
| [[ats-notes]] | Against the Storm: заметки источника и сверка | reference | 2026-10-16 |
| [[ats-specializations]] | Against the Storm: специализации рас | reference | 2026-10-16 |
| [[ats-species]] | Against the Storm: расы (Species) | reference | 2026-10-16 |
| [[allods-races]] | Allods Online: расы и промпты генерации | reference | 2026-10-16 |
| [[dnd-classes]] | D&D: классы | reference | 2026-10-16 |
| [[dnd-races]] | D&D: расы | reference | 2026-10-16 |
| [[homm3-terrain-tiles]] | HoMM III: промпты террейн-тайлов | reference | 2026-10-16 |
| [[BASELINE]] | Базовая линия графики карты (до world-map-art-variety) | reference | 2026-10-19 |
| [[REPORT]] | Сводный отчёт world-map-art-variety (шаг 11) | reference | 2026-10-19 |
| [[MACHINE-EYE]] | 11.3 — машинное зрение: вердикт по носителям | reference | 2026-10-18 |
| [[REVIEW]] | 11.3 — носители целостного кадра для визуальной приёмки | reference | 2026-10-18 |
| [[REVIEW]] | UX-ревью перехода T-136 (что смотреть и вердикт агента) | reference | 2026-10-18 |
| [[REVIEW]] | T-138 — A/B полосы зерна на игровом зуме | reference | 2026-10-18 |
| [[REVIEW]] | T-163 — A/B перекраски скалы и дороги (кандидат, вердикт не вынесен) | reference | 2026-10-24 |
| [[poe2-attributes]] | PoE2: атрибуты | reference | 2026-10-16 |
| [[poe2-classes]] | PoE2: классы | reference | 2026-10-16 |
| [[poe2-creation-flow]] | PoE2: флоу создания персонажа | reference | 2026-10-16 |
| [[poe2-dnd5e-rules]] | D&D 5e: правила создания персонажа (справка PoE2-вики) | reference | 2026-10-16 |
| [[poe2-index]] | Pillars of Eternity II: Deadfire — вики создания персонажа | reference | 2026-10-16 |
| [[poe2-multiclassing]] | PoE2: мультикласс | reference | 2026-10-16 |
| [[poe2-races]] | PoE2: расы | reference | 2026-10-16 |
| [[poe2-skills]] | PoE2: навыки | reference | 2026-10-16 |
| [[poe2-vs-dnd]] | PoE2 против D&D: сравнение систем | reference | 2026-10-16 |
| [[sigil-ats-buildings]] | AtS-клон: здания (карантин) | reference | 2026-10-16 |
| [[sigil-ats-goods]] | AtS-клон: товары и ресурсы (карантин) | reference | 2026-10-16 |
| [[sigil-ats-implementation]] | AtS-клон: статус реализации прототипа (карантин) | reference | 2026-10-16 |
| [[sigil-ats-mechanics]] | AtS-клон: механики (карантин) | reference | 2026-10-16 |
| [[sigil-ats-merged-buildings]] | AtS-клон: объединённые здания (карантин) | reference | 2026-10-16 |
| [[sigil-ats-notes]] | AtS-клон: обзор базы знаний (карантин) | reference | 2026-10-16 |
| [[sigil-ats-races]] | AtS-клон: расы (карантин) | reference | 2026-10-16 |
| [[terrascape-merged-buildings]] | TerraScape: объединённые здания | reference | 2026-10-16 |
