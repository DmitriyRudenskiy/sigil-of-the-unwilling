---
title: Снимок матрицы автопилота 2026-10-26
tags:
  - mvp
  - balance
  - evidence
status: reference
date: 2026-10-26
---

# Матрица 5×11, пересъёмка 2026-10-26 (T-207, D-257)

Доказательная база для чисел в `openspec/changes/scenario-matrix-behavior-reliability/`
(задачи 3.3, 8.1, 9.3, 9.4), в `design.md` и в билетах T-207/T-208. Пиксели и логи в git
обычно не идут (D-185), но **цифры вердикта обязаны иметь снимаемый источник** (D-192 §2),
поэтому здесь лежат матричные строки целиком.

## Как воспроизвести

```sh
godot --headless --path game -s res://tools/matrix_report.gd -- <role> <turns> [class,class,…]
# roles: trader | builder | adventurer | traveler | collector
```

Инструмент — `game/tools/matrix_report.gd`; трасса кадров — `MATRIX_TRACE=1`,
снимок зависшего боя — `MATRIX_TRACE=1` + `MATRIX_BEAT_FRAMES`. Проверка идентичности
повторного прогона того же seed (задачи 4.3/5.3/7.3) — `MATRIX_REPEAT=2`: каждый профиль
гонится N раз в одном процессе, печатается `MATRIX-DETERMINISM|class=…|same=…|hashes=…`,
при расхождении — `MATRIX-DIFF` с обеими строками. Каждый лог ниже — один процесс Godot
на роль (11 классов), движок 4.7.stable.official.5b4e0cb0f.

## Состав

| файл | дерево | что в нём |
| --- | --- | --- |
| `traveler-crash-before-fix.txt` | `af5b7d33`, до стража `_hero_cell()` | падение процесса: `handle_crash: signal 11`, бэктрейс `_hero_cell ← goal_met ← metrics`; матрица оборвалась на 3-м классе |
| `traveler-90.txt` | `437b8a13`, после стража | 11/11 строк: `arrived`, `distance`, `biomes`, `hero=alive\|dead\|freed\|null` |
| `builder-90.txt` | `437b8a13` | 11/11 строк: `city_level`, `buildings`, `population`, ходы 90…93 |
| `collector-90.txt` | `437b8a13` | 11/11 строк: `rare_extracted`, `resources_per_day` |
| `adventurer-60.txt` | `af5b7d33` (счётчик убийств уже в инструменте) | `kills`, `kill_goal`, 9/11 с ≥1 убийством |
| `trader-90.txt` | `af5b7d33` | 11 профилей Торговца за один процесс + **шум T-206** (см. ниже) |
| `collector-90-repeat2.txt` | `8155d61a` (`MATRIX_REPEAT=2`) | Собиратель, 22 прогона (11 классов × 2): `same=true` у всех 11 |
| `collector-90-nodes.txt` | `8155d61a` (счётчики узлов) | те же 11 профилей с `rare_nodes`, `rare_targets_seen`, `resource_nodes_extracted` → **T-209** |
| `traveler-60-repeat2.txt` | `683b09e5` (`MATRIX_REPEAT=2`) | Путешественник, 60 ходов, 22 прогона: `same=true` у всех 11; `arrived` 9/11, `biomes` 1…5 |

Из логов оставлены строки `MATRIX*`, заголовок движка и строки падения/ошибок; остальной шум
отброшен. Формат строки: `MATRIX|key=value|…` (ключи упорядочены), `MATRIX-START`/
`MATRIX-SUMMARY` — границы прогона.

## Что видно из этих логов

1. **Неполнота матрицы была падением процесса, а не «медленным профилем».** До фикса
   `traveler 90` печатал 2 строки из 11 и умирал по сигналу 11; после — 11 строк без падения.
2. **T-206 подтверждён в бою, а не только тестом:** в `trader-90.txt` (дерево до фикса
   `battle_view`) 54 строки `Attempted to erase an invalid (previously freed?) object` и
   108 фреймов `_register_number`; в трёх логах после фикса — **ноль**.
3. **Бюджет ходов не является верхней границей прогона:** ходы 91…93 при заказе 90 в двух
   ролях подряд (Builder: Barbarian 92, Priest 91, Rogue 93; Traveler: Wizard 93) → T-208.
4. **Цель Путешественника — точное совпадение клетки:** Wizard ушёл на `distance=42` при
   кольце цели 25 и остался `arrived=false`.
5. **Форма «урон есть, убийств мало»** (Adventurer: Ranger 35 боёв → 1 убийство; Chanter и
   Wizard → 0) — тот же профиль сил, что даёт бой-пат T-205, только в дозе поменьше.
6. **Цель Собирателя закрывается одним узлом.** В `collector-90-nodes.txt` у всех 11
   профилей `rare_nodes` = 1…2 при `rare_goal = 10`: Fighter и Wizard сняли **по одному
   узлу** (`rare_nodes=1`, `resource_nodes_extracted=1`) и закончили забег на первом ходе,
   потому что `ResourceType.pickup_amount(GOLD) = 50` единиц на узел → **T-209**.
7. **Прогон детерминирован:** 22 + 22 повтора того же seed в одном процессе дали
   байт-в-байт совпадающие строки (`same=true`, 22/22 и 22/22 ключей). Матрица воспроизводима
   без «проверено глазами».
8. **Путешественник доходит за 4–17 ходов из бюджета 90** (`distance=39` при кольце 25),
   а `biome_goal = 2` из переносчика не проверяется никем: Priest прибыл с `biomes=1`
   и `arrived=true` (задача 5.3 просит ≥3) → **T-210**.
