# Архитектура — battle-demo

## Движок

| Параметр | Значение |
| --- | --- |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| Бинарь | `/Applications/Godot.app/Contents/MacOS/Godot` (override: `GODOT_BIN`) |
| Рендер | GL Compatibility |
| Тесты | GdUnit4 v6.2.1 (`addons/gdunit4`), `./run_tests.sh` |
| Гейт | exit 0; 101 (только orphan) = зелёный; прочее = красный |

## Три слоя, одна зависимость

```
data/*.tres  →  scripts/combat/*.gd (чистая модель, RefCounted)
                       │ сигналы
                       ▼
scripts/ui/*.gd + scenes/*.tscn (только читатель)
```

Правило зависимости одностороннее: модель не знает ни о сценах, ни о спрайтах,
ни о `Node`. Проверка — тестом «бой без сцены» (задача 4.9).

## Модель (`scripts/combat/`)

| Класс | Ответственность |
| --- | --- |
| `UnitStats` (Resource) | id, имя, спрайт, max_hp, attack, defense, initiative, способности |
| `Unit` (RefCounted) | экземпляр в бою: `stats`, `hp`, `alive`, `statuses`, сторона |
| `StatusEffect` (RefCounted) | тип, длительность в ходах, эффект |
| `Action` (RefCounted) | вид, исполнитель, цель, расчёт урона |
| `TurnQueue` (RefCounted) | очередь по инициативе, детерминизм по seed |
| `CombatState` (RefCounted) | юниты, фаза, текущий ход, публикация сигналов |

Сигналы наружу: `turn_started(unit)`, `action_performed(action)`,
`unit_died(unit)`, `battle_ended(result)`.

Изменения состояния — только методами модели; прямая запись полей из UI не
предусмотрена (UI читает геттеры).

## Данные (`data/`)

`data/units/*.tres` — восемь юнитов пула + постоянный враг;
`data/rosters/a.tres`, `data/rosters/b.tres` — позиции 1–7 и 2–8 упорядоченного
пула. Загрузчик проверяет инварианты (задача 5.4–5.6) и падает с именем
нарушенного юнита/набора.

## Отображение (`scenes/`, `scripts/ui/`)

`roster_select.tscn` → `battle.tscn` → экран результата. `battle_unit.gd`
держит `AnimatedSprite2D` (`idle/walk/attack/hit/turn`), `flip_h` по стороне,
`modulate` для гибели; `hp_bar.gd`, `turn_order.gd`, `ability_panel.gd` —
подписчики сигналов модели.

## Детерминизм

`CombatState.seed` → `RandomNumberGenerator`. Тесты и съёмка кадров подают
действия списком (`tests/helpers/battle_factory.gd`), поэтому «тот же seed +
тот же ввод = тот же бой» проверяемо (спека `turn-battle-core`).

## Вне архитектуры

Аудио, полировка, сохранения, локализация, мультиплеер — см. `scope-report.md`.
