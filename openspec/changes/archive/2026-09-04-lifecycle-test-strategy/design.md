# Design: lifecycle-test-strategy

## Контекст

Система death/succession/resurrection — RefCounted, headless-safe по замыслу, но
её `setup()` принимает 12 рефов. Тестировать «без мира» нельзя: `_install_hero`
делает `world.add_child(hero)`, `_show_death_sequence` создаёт экран в дереве,
`_find_resurrection_city` ходит по `_cities.cities`. Задача — не абстрагировать
всё до смерти, а дать среднему слою минимальные подмены.

## D1. Слои и где что живёт

| Слой | Что тестирует | Инструмент | Статус |
|---|---|---|---|
| L1 | SuccessionController: выбор преемника, стоимость воскрешения, `can_resurrect` | чистый RefCounted, реальные City-объекты | есть (test_succession.gd) |
| L2 | HeroLifecycleSystem: on_hero_died → последовательность, ветки successor/terminal/resurrection, запись в летопись, освобождение трупа | система + duck-стабы + реальный Node2D-корень | НЕТ — создаём (test_hero_lifecycle.gd) |
| L3 | Связка: реальные подсистемы получают нового героя (реестр потребителей), реальные сигналы GameEventBus | живой WorldController | есть (test_worldcontroller_succession_wiring.gd) |
| L4 | Сценарий смерти через сокет (HERO_DIE → преемник в живом headless-процессе) | play_scenario 12 | есть |

Правило (a): L2 никогда не инстанцирует WorldController. Если сценарий «нужен
живой мир, чтобы проверить X» — значит X не про логику системы, а про связку →
это L3, и он должен влезть в ОДИН существующий файл.

## D2. Duck-стабы: что именно подменять

Стаб подменяет только то, к чему система обращается по имени. Инвентарь
(по HeroLifecycleSystem.gd):

- `world: Node2D` — РЕАЛЬНЫЙ узел (добавлен в дерево тестом): нужны
  `add_child` и в L3 `change_scene_to_file` (в L2 «В меню» не жмём, кроме
  отдельного сценария с фейком сцены — опционально).
- `persistence` — Fake: `.session` (FakeSession: `is_terminal()`, `battles_won/lost`,
  `successions`), `.chronicle` (реальный Chronicle — RefCounted, бесплатно),
  `.get_date()`.
- `cities` — Fake: `.cities` (массив реальных City — они RefCounted-совместимые
  модели, дешевле и честнее фейка), `.current_turn`, `.glory`.
- `map_gen` — null допустим (в `_install_hero` уже guard' `if _map_gen != null`);
  для сценариев позиции — фейк с `has_valid_tilemap()/map_to_local`.
- `event_router` — Fake: поле `hero`, метод `_connect_hero_signals()` (no-op,
  счётчик вызовов).
- `ui_manager` — Fake: `_hero`, `.ui.reattach_hero`, `.inventory_screen`,
  `.city_screen`. После hero-lifecycle-boundary (реестр) этот стаб сжимается:
  координатор в L2 вообще не существует — стабы регистрируются как Callable.
- `battle_coordinator` / `interaction_controller` — Fake с полем `hero`.
- `bootstrap_result` — Fake: `.enemy_proc` (поле `_hero`), `.input_controller`
  (поле `hero`), `.shortcuts` (поле `_hero`); допустимо null (guard' есть).
- `camera` — реальный Node2D.
- HeroController — реальный, паттерн `_make_hero()` из test_hero_survival.gd
  (явный `_ready()`: в headless при синхронном add_child `_ready` не fires).

## D3. Сценарии L2 (минимум 6)

1. Смерть с преемником: `hero_died` → pending successor, DeathSequence открыт,
   труп удержан только если есть город воскрешения, иначе освобождён.
2. «Знак переходит»: successor установлен, `hero_successor` эмитирован, в
   Chronicle запись `outcome: "succession"`, труп освобождён.
3. Смерть без преемника: run-конец путь, труп освобождён, запись в летопись не
   пишется.
4. Terminal-сессия (sticky DEFEAT): преемник НЕ выбирается, только последовательность
   смерти.
5. Воскрешение: `resurrection_chosen` → `revive_at(city)`, `resurrected_once`,
   pending преемник освобождён, `hero_successor` НЕ эмитирован.
6. Реестр потребителей (после cycle 1): каждый зарегистрированный Callable
   получил нового героя; в `_install_hero` нет жёстких потребителей.

Рандом: `_rng` — реальный RandomNumberGenerator с фиксированным seed
(воспроизводимость выбора преемника).

## D4. Аудит дублирования (не чистка ради чистки)

test_hero_survival.gd (552) после появления L2 будет дублировать сценарии 1–5
в тяжёлой обёртке. Политика: оставляем его (он проверяет реальные
HeroController/City/хранилище, чего нет в L2), из него вычленяем ТОЛЬКО
тривиально избыточные assert'ы (те, где проверяется то же самое, что в L2, без
реального объекта). Если дублирование не тривиально — не трогаем.

## Риски

- Стабы расходятся с реальными классами при рефакторинге: защита — L3-тест
  (живой мир) + сценарий 12 (L4). Стаб, потерявший поле, падает с
  «Invalid get/set» в L2 — это feature.
- Godot 4.7: авто-имена runtime-узлов (`@Node@5`) — стабы и создаваемые экраны
  получать только по рефу, не по пути.
