---
description: "Изолированное тестирование death/succession/resurrection: 4 слоя (чистый план → система со стабами → один живой мир → сокет-сценарий), минимальный набор duck-стабов, правило «WorldController в юнит-тесте = красный флаг»."
---

## Why

Логика цикла героя (смерть → преемник → воскрешение) трогает половину состояния
мира, но покрыта только тяжёлыми тестами:

- `test_hero_survival.gd` (552 строки) — полный мир через `_make_hero()` + явный
  `_ready()`;
- `test_worldcontroller_succession_wiring.gd` (87) — живой WorldController;
- `test_succession.gd` (253) — чистый SuccessionController, единственный
  изолированный слой.

Обещанный umbrella'ем `tests/test_hero_lifecycle.gd` (задача 6.1) не создан:
`HeroLifecycleSystem.setup()` принимает 12 ссылок на реальные подсистемы, и
«изолированный» тест на сегодня означает собрать полумира вручную. Вопрос
сформулирован честно: **как тестировать логику, которая влияет на полмира,
изолированно?** Ответ: layered — чистое ядро уже изолировано, среднему слою
нужны стабы, верхнему — один живой мир, а не десятки.

## Proposed Change

1. **4 слоя (пирамида):**
   - **L1 чистое планирование** — SuccessionController (RefCounted, headless):
     правила годности преемника, стоимость воскрешения. Уже есть; дорабатываем
     покрытие, не трогаем архитектуру.
   - **L2 система со стабами** — новый `tests/test_hero_lifecycle.gd`:
     HeroLifecycleSystem + duck-стабы. Стаб реализует только члены, к которым
     система реально обращается (Godot динамический — проверять это и есть
     тест).
   - **L3 один живой мир** — `test_worldcontroller_succession_wiring.gd`:
     ЕДИНСТВЕННЫЙ тест с реальным WorldController (страховка связки: реестр
     потребителей, реальные сигналы).
   - **L4 приёмка** — сценарий 12 (сокет: HERO_DIE → смерть → преемник). Уже есть.
2. **Минимальный набор стабов** (по реальному использованию системы):
   FakePersistence (session/chronicle/get_date), FakeCities (cities, current_turn,
   glory), FakeUIManager (_hero, ui.reattach_hero, inventory_screen, city_screen),
   FakeRouter (hero, _connect_hero_signals), FakeBattle/FakeInteraction (поле hero),
   FakeBootstrapResult (enemy_proc/input_controller/shortcuts); корень дерева и
   камера — реальные узлы (Node2D). HeroController — реальный (паттерн `_make_hero`
   с явным `_ready()`).
3. **Правила:**
   - (a) новый тест подсистемы НЕ инстанцирует WorldController;
   - (b) стабы — в `tests/` (preload-константы, без `class_name` — в отсоединённых
     тестах classdb не регистрирует их);
   - (c) тесту понадобился живой WC → красный флаг: чиним шов (изменяем код),
     а не пишем ещё один тяжёлый тест.
4. **Документация:** docs/howto/TESTING.md — пирамида, правила (a–c), headless-
   ловушки (явный `_ready()`, `_ready` не fires при синхронном add_child в headless,
   авто-имена runtime-узлов в Godot 4.7).

## Scope

- **In:** `tests/test_lifecycle_fakes.gd` (набор стабов), `tests/test_hero_lifecycle.gd`
  (≥6 сценариев L2), правки `docs/howto/TESTING.md`, аудит дублирования L2-
  сценариев в test_hero_survival.gd (убрать только тривиально избыточное).
- **Out:** переписывание test_hero_survival.gd (остаётся, он L3-уровневый и
  покрывает воскрешение/труп/хранилище), новые механики, фреймворки (базовый
  runner как есть).

## Dependencies

- Рекомендуется после `hero-lifecycle-boundary`: реестр упрощает L2-стабы
  (UI/router подменяются зарегистрированными фейковыми Callable, стабы
  уменьшаются). Если делать раньше — стабы подменяют поля, как сейчас.
- `world-controller-decoupling` R7 (`test_hero_lifecycle.gd`, задача 6.1) —
  закрывается этим change.
