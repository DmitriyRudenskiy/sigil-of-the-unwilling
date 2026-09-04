## 1. Стабы
- [ ] `tests/test_lifecycle_fakes.gd`: FakeSession, FakePersistence, FakeCities, FakeUIManager, FakeRouter, FakeBattle/FakeInteraction, FakeBootstrapResult (только члены по инвентарю D2; без class_name).

## 2. L2-тесты
- [ ] `tests/test_hero_lifecycle.gd`: сценарии D3.1–D3.4 (смерть с преемником, перерождение + летопись, смерть без преемника, terminal-сессия).
- [ ] `tests/test_hero_lifecycle.gd`: сценарий D3.5 (воскрешение: revive_at, resurrected_once, pending освобождён, hero_successor не эмитирован).
- [ ] `tests/test_hero_lifecycle.gd`: сценарий D3.6 (реестр потребителей; исполнять после hero-lifecycle-boundary, до него — помечать skipped).
- [ ] Фиксированный seed для _rng во всех сценариях выбора преемника.

## 3. Аудит дублирования
- [ ] Сравнить assert'ы test_hero_survival.gd с L2-сценариями; удалить только тривиально избыточные (без реальных объектов) — по правилу D4.

## 4. Документация
- [ ] `docs/howto/TESTING.md`: пирамида L1–L4, правила (a)–(c), headless-ловушки (явный _ready(), синхронный add_child, авто-имена Godot 4.7).

## 5. Umbrella
- [ ] `openspec/changes/world-controller-decoupling/tasks.md`: пометить 6.1 «закрыто: lifecycle-test-strategy».

## 6. Gate
- [ ] Полный тест-сьют зелёный, operability gate CLEAN, точный коммит.
