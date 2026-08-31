# Концепция: Механика авто-слияния ×4 (TerraScape: Hex Core)

> Образец: прототип **TerraScape: Hex Core** — гексовый градостроительный
> симулятор в стиле *Against the Storm* / *Manor Lords*. Источник — файл-транскрипт
> с HTML-прототипом (`tryAutoMerge`) и его портом на **Godot 4.7**
> (`building_manager.gd`, `func try_auto_merge`).
>
> Механика: **четыре одинаковые одноклеточные постройки, стоящие вплотную в
> связном кластере, автоматически превращаются в «здание II» (_BIG)**.
>
> Это **отдельная** механика от рецептурного слияния — см.
> [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md) §4 (Школа+Библиотека→
> Университет) и [`TASK_BUILDING_SCORING_GODOT47.md`](TASK_BUILDING_SCORING_GODOT47.md).
> Здесь не нужно задавать рецепт: достаточно **4 одинаковых в кластере**.

---

## 1. Что это и чем отличается

| | Рецептурное слияние | Авто-слияние ×4 (этот документ) |
| :--- | :--- | :--- |
| **Триггер** | По рецепту (напр. Школа + Библиотека) | 4 одинакие здания вплотную |
| **Состав** | Разные типы (по `merges`-рецепту) | Один и тот же тип |
| **Управление** | Явное (кнопка/рецепт) | Автоматическое при размещении 4-го |
| **Результат** | Фиксированное здание (`University`) | `_BIG`-версия того же типа |
| **Где описано** | `CONCEPT_BUILDING_SYNERGY.md` §4 | Этот документ |

Результат авто-слияния — **не новое «имя» здания, а усиленная копия** исходного
типа: тот же `deck`, больше слотов под работников, увеличенный базовый счёт.

---

## 2. Условия срабатывания (guard clause)

Авто-слияние запускается **только** для только-что размещённого здания и **только**
если выполняются все три условия:

```gdscript
func try_auto_merge(start_cell) -> Dictionary:
	if start_cell.building.is_empty():          # 1. клетка занята зданием
		return {}
	if start_cell.building.is_merged:            # 2. уже «здание II»
		return {}
	if start_cell.building.cells.size() > 1:     # 3. не одноклеточное (уже merged/большое)
		return {}
```

То есть слиянию подвергается **одна** одноклеточная постройка, которой ещё никто
не является результатом слияния.

---

## 3. Алгоритм: BFS связного компонента

Поиск — обход в ширину по **4-связному** соседству в гекс-сетке `odd-r`.
Направления из `Globals.HEX_DIRECTIONS` (6 соседей odd-r, но в компонент заходим
только по уже поставленной постройке того же типа):

```gdscript
var target_type = start_cell.building.type
var connected = []
var queue = [start_cell]
var visited = {start_cell.key: true}

while not queue.is_empty():
    var current = queue.pop_front()
    connected.append(current)
    for dir in Globals.HEX_DIRECTIONS:
        var neighbor = GridManager.get_cell(current.q + dir[0], current.r + dir[1])
        if neighbor and not visited.has(neighbor.key):
            visited[neighbor.key] = true
            # Только одноклеточное, не merged, того же типа
            if not neighbor.building.is_empty()
               and not neighbor.building.is_merged
               and neighbor.building.type == target_type:
                queue.append(neighbor)
```

Триггер:

```gdscript
if connected.size() >= 4:
    var to_merge = connected.slice(0, 4)   # берём ровно 4
    ...
```

> **Важно про связность:** в компонент добавляется сосед **того же `type`**.
> Пропуски (пустые клетки, здания других типов) разрывают кластер — нужно 4
> вплотную, «лесенка»/квадрат/линия без разрывов.

---

## 4. Результат — «Здание II» (`_BIG`)

Собираем данные **до удаления**, затем demolish 4 зданий и ставимmerged:

```gdscript
var carried_workers = []
var house_sp = to_merge[0].building.house_sp
for b in to_merge:
    carried_workers.append_array(PopulationManager.get_workers_of(b.building))
    demolish(b.building)

var base_data = Globals.BUILDINGS[target_type]
var merged_building = {
    "type":      target_type + "_BIG",
    "type_deck": base_data.deck,
    "cells":     cells_to_use,          # 4 клетки
    "is_merged": true,
    "base_type": target_type,           # для скорнинга/adjacency
    "workers":   0,
    "score":     int(base_data.base * 5.5),   # базовый счёт ×5.5
    "house_sp":  house_sp,
    "last_parts": []
}

for cell in cells_to_use:
    cell.building = merged_building
    cell.update_visuals()
buildings.append(merged_building)
```

### Переселение работников
```gdscript
var max_jobs = base_data.get("jobs", 0) * 4 + 2
for i in range(min(carried_workers.size(), max_jobs)):
    carried_workers[i]["job"] = merged_building
merged_building.workers = min(carried_workers.size(), max_jobs)
```
Работники с 4 зданий переносятся в новое здание (лимит = базовые слоты ×4 + 2).

### `house_sp` (расовое жильё)
Сохраняется, только если у всех 4 зданий **одинаковый** `house_sp`; иначе — `null`
(в Godot-порте упрощено: берётся от первого, но в HTML-прототипе — строгое
совпадение всех четырёх).

---

## 5. Триггер в цикле размещения

Авто-слияние встраено в обработчик установки здания (`on_cell_clicked`):

```gdscript
func on_cell_clicked(cell):
    if selected_building_type:
        if cell.building:
            UI.set_status("Клетка занята!"); return
        place_building(selected_building_type, [cell])
        var merged = try_auto_merge(cell)   # ← сразу после установки
        UI.update_all()
    else:
        UI.show_building_info(cell.building)
```

После слияния пересчитываются потребности и мораль
(`PopulationManager.recalc_all`), а в точке слияния всплывает «Снесено» (neg).

---

## 6. Визуализация

- Мёрдж-здания подсвечиваются **цветом `deck`** вместо белого:
  `poly.modulate = deck_color if building.is_merged else Color(1,1,1,1)`.
- В подписи здания добавляется пометка «[Слияние]» жёлтым, если `bldg.is_merged`.

---

## 7. Взаимодействие с другими системами

- **Demolish (`demolish(bldg)`):** снимает всех работников
  (`PopulationManager.unassign_all_from`), убирает здание из списка, очищает
  клетки (`cell.building = {}`), пересчитывает жильё
  (`trim_to_housing`) и потребности (`recalc_all`).
- **Скорнинг (`calculate_score`):** для мёрдж-здания считается по `base_type` —
  base + биом + фича + `per_worker × workers` + adjacency. Т.к. workers после
  слияния больше, а `min_dist_between` учитывает все клетки здания, adjacency-
  баффы/штрафы пересчитываются для всей площади.
- **Мин-расстояние (`min_dist_between`):** для многоклеточных зданий (в т.ч.
  мёрдж) — минимум по всем парам клеток; adjacency применяется, если `dist ≤ radius`.
- **Потребности/мораль:** `recalc_all` пересчитывает `needs` и `Resolve` после
  переселения работников — см. [`CONCEPT_POPULATION_RUNTIME.md`](CONCEPT_POPULATION_RUNTIME.md).

---

## 8. Связь с проектом (`Sigil of the Unwilling`)

| В прототипе | Где в проекте | Замечание |
| :--- | :--- | :--- |
| `GridManager.get_cell(q,r)` | `scripts/core/HexUtils.gd`, `scripts/world/` | Гексы — только `odd-r` через `HexUtils`, не чебышевская модель прототипа. |
| BFS-компонент | `scripts/world/City`, `game/scripts/city/AdjacencySystem.gd` | Отдельно от городского adjacency-слоя. |
| `_BIG`-здания | `scripts/data/BuildingDefs.gd` | Усиливая копия — новый `BuildingDef` (или флаг `is_merged`), баланс через `@export`. |
| Переселение работников | `scripts/world/`, `DemographicTurnProcessor` | Повторное заселение после слияния — см. демографику. |
| Пересчёт очков/потребностей | `game/scripts/city/AdjacencySystem.gd`, `DemographicTurnProcessor` | Обратное влияние на соседей и население. |

> ⚠️ **В прототипе данные — в глобальном `Globals` (харкод), результат — строка
> `type + "_BIG"` без отдельного определения.** В проекте мёрдж-здания должны
> быть отдельными `@export`-ресурсами/реестрами, а не строковыми конкатенациями.

---

## 9. Зависимости

- [`CONCEPT_POPULATION_RUNTIME.md`](CONCEPT_POPULATION_RUNTIME.md) — краткий обзор
  авто-слияния в контексте хода; потребности/мораль после слияния.
- [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md) — рецептурное слияние
  (Школа+Библиотека→Университет) и adjacency-штрафы/баффы.
- [`TASK_BUILDING_SCORING_GODOT47.md`](TASK_BUILDING_SCORING_GODOT47.md) — ТЗ на
  размещение/скорнинг/слияние в Godot 4.7.
- [`city_system.md`](../systems/city_system.md) — городская модель проекта.
