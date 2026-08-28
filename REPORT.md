# Открытые вопросы (после аудита)

## РФ3-7: `already_reborn` сбрасывается каждый раунд

**Файл:** `scripts/BattleState.gd` → `start_new_round()`

**Проблема:** `already_reborn` сбрасывается при старте нового раунда боя, что позволяет фениксу воскресать повторно в каждом раунде.

**Текущее поведение:** феникс может воскреснуть раз в раунд.

**Варианты решения:**
- Раз в бой: добавить флаг `already_reborn_this_battle` в `BattleState`, который не сбрасывается.
- Оставить как есть: дизайн-решение, что феникс — редкий юнит, и многократное воскрешение добавляет динамики.

**Решение:** TBD (ожидание решения геймдизайнера).

## РФ5-6 / РФ6-8: Дрейф константы морали

**Файлы:** `scripts/core/GameSettings.gd`, `scripts/util/BattleRules.gd`

**Проблема:** `GameSettings.BATTLE_MORALE_EXTRA_TURN_CHANCE = 0.5` (50%) vs `BattleRules.MORALE_CHANCE = 0.08` (8%). Расхождение в 6×. Код использует `BattleRules.MORALE_CHANCE` (0.08) — это рабочее значение.

**Статус:** Мёртвая константа в `GameSettings` удалена (РФ6-8). В `BattleRules` добавлен комментарий-ссылка на REPORT.md. Код работает на `BattleRules.MORALE_CHANCE = 0.08`.

**Решение:** TBD (ожидание решения геймдизайнера: 50% или 8%?).

## РФ3-4 / РФ5-8: Прогрессия школ магии отсутствует

**Файлы:** `HeroMagic.gd`, `GameSettings.gd`

**Проблема:** `can_cast_def` требует `schools[school] >= spell.level`, но прогрессии школ нет в игре. `HERO_LEVEL_UP_EXP = 100` не используется. Все спеллы уровня 2+ (Lightning Bolt, Fireball, Curse, Stoneskin, Resurrection и т.д.) недоступны без внешнего вмешательства.

**Статус:** `SpellbookScreen.gd` удалён как мёртвый код (нет сцены, нет инстанцирования). `HERO_LEVEL_UP_EXP` оставлен в `GameSettings` как заглушка.

**Решение:** В бэклог геймдизайна. Нужна механика левелапа героя и школ магии.

## РФ6-5: Городская система не сохраняется

**Файлы:** `CityManager.gd`, `City.gd`, `WorldPersistence.gd`

**Проблема:** `City`/`CityManager` не сериализуются. F9 полностью сбрасывает города, население, славу, счётчик ходов.

**Выбран вариант A:** зафиксировать как известное ограничение. Сериализация `City`/`CityManager` (pop/boroughs/buildings/storage/`current_turn`/glory) — отдельная Фаза 10 с миграцией `SaveData` на версию 3.

**Решение:** Бэклог (Фаза 10).

## РФ6-9: 5 special_effect артефактов не реализованы

**Список:** `undead_morale`, `hero_flight`, `level_5_spells`, `retaliation_weakness`, `magic_immunity_low`

**Статус:** `has_artifact_effect()` в `HeroController` корректно проверяет эффекты, но ни один из этих 5 эффектов не используется нигде в коде.

**Решение:** Бэклог геймдизайна.

## РФ7-4: Сессионный RNG не сериализуется

**Файл:** `WorldPersistence.gd`

**Проблема:** Состояние сессионного RNG не сохраняется. После загрузки середины партии броски `get_enemy_defender_bonus`/дропа расходятся с исходным прогоном.

**Статус:** Известное ограничение этой версии.

**Решение:** Бэклог. Сериализация seed + последовательности бросков при сохранении.

## Фаза 10: Первый полный прогон, фикс падений и устранение ложных зелёных

**Контекст:** Фазы 8–9 приняты, но код после ~32 фиксов ни разу не компилировался и не прогонялся. Фаза 10 — первый реальный запуск `tools/compile_all.gd`, `tools/check_scene_refs.gd` и `tests/run_tests.gd` под Godot 4.7.2.stable (headless).

### РФ10-1: Бесконечный цикл в `SlicerCore.hamming_distance` (весь раннер вешался)

**Файл:** `tools/texture_slicer/SlicerCore.gd`

**Проблема:** `compute_dhash` возвращает подписанный 64-битный int — для градиентной текстуры хэш = `-1` (все биты установлены). Старый код `while x != 0: x >>= 1` использует арифметический сдвиг: `-1 >> 1 == -1`, цикл никогда не завершался. Любой `hamming_distance`, где XOR отрицателен, вешал процесс — в тестах это останавливало весь раннер на `test_deduplication.gd`.

**Фикс:** ограниченный цикл `for i in 64` (popcount за 64 итерации). Поведение идентично для всех входов, всегда завершается. `dist(0, -1) == 64` — корректный popcount.

### РФ10-2: Типизированные массивы в `WorldBattleCoordinator`

**Файл:** `scripts/world/WorldBattleCoordinator.gd`

**Проблема:**
1. GDScript-квирк: `var a: Array[UnitStack] = expr if cond else []` — ветка `[]` остаётся нетипизированным `Array`, смешанный тернарник даёт Variant → runtime-ошибка «Trying to assign an array of type 'Array' to a variable of type 'Array[UnitStack]'».
2. `MapModel.enemy_stacks` — Dictionary со вложенными обычными `Array` (пишется в `MapSpawner`); прямой проход в `_start_battle(enemy_army: Array[UnitStack])` → «array does not have the same element type as the expected typed array».

**Фикс:** хелпер `static func _as_unit_stack_array(v: Variant) -> Array[UnitStack]` на границе — оба вызова `_start_battle` в `check_enemy_contact`; тернарник в `_start_battle` разведён через Variant-промежуточный.

### РФ10-3: `CardSpellDef.secondary_effects` ломал все карточные спеллы

**Файл:** `scripts/card/CardSpellDef.gd`

**Проблема:** `secondary_effects` объявлен как `Array`, а `CardTemplateEngine._Engine.execute()` ожидает `Array[Dictionary]` — тип-несовпадение роняло выполнение **каждого** карточного спелла со вторичными эффектами.

**Фикс:** поле типа `Array[Dictionary]`, `from_dict()` собирает типизированный массив.

### РФ10-4: Null-гарды в боевом коде

- `BattleTurnExecutor.resume_battle` — null-guard на `_battle_state`.
- `BattleTurnExecutor.on_move_completed` — null-guard (метод безопасен без полной инициализации боя).
- `BattleInput._clear_highlights` — null-guard.

### РФ10-5: Ложные зелёные — полное устранение

1. **~40 SCRIPT ERROR в логах тестов** — каждый триажирован: баг продукта (фиксы РФ10-1…РФ10-4 и в `BattleState`/`UnitStack`/`TimeSystem` — см. предыдущие фазы), баг теста (поправка ожиданий) или устаревший API (напр. `Window.scene_tree_changed` удалён в Godot 4.7).
2. **Автономные SceneTree self-runners** — опасные преобразованы в паттерн `test_base`; асинхронный `test_runtime_integration` (ждёт 4 с инициализации мира) перенесён в `SKIP_FILES` главного раннера и исправлен для standalone: deferred-старт после autoloads (в `-s`-режиме `_init` выполняется раньше autoloads, и скрипты мира с их идентификаторами autoloads не компилировались) + `create_timer()` вместо `Timer.start()`. Запуск: `godot --headless -s tests/test_runtime_integration.gd`.
3. **16 синхронных self-runner-файлов** (`test_battle_ai`, `test_battle_integration`, `test_battle_state`, `test_hex_utils`, `test_unit_registry` и др.) — работы выполнялись в `_init`, но раннер считал их за 0 тестов: падение любого чек-поинта не меняло итог и exit code. Подключены к счётчикам раннера (`_passed`/`_failed`): их результаты теперь входят в `=== Total ===` и exit code.
4. **Ожидание `test_card_spell_system`**: `HARD_REMOVAL` без цели корректно возвращает `{"result": "no_target"}` — ожидание расширено до `["success", "condition_not_met", "no_target"]` (фикс теста, не продукта).

### Итоговые цифры (Godot 4.7.2.stable, headless)

| Проверка | Результат |
|---|---|
| `tools/compile_all.gd` | 177 файлов OK, 0 ошибок |
| `tools/check_scene_refs.gd` | 10 сцен OK, 0 ошибок |
| `tests/run_tests.gd` | **2789 passed, 0 failed, 0 SCRIPT ERROR**, 58 файлов |
| `tests/test_runtime_integration.gd` (standalone) | exit 0, World загружается, WorldController/WorldUIManager на месте |

Остаточный шум (не ошибки тестов, зафиксирован в лог финального прогона `/tmp/run10.txt`): RID-утечки на exit (headless-харнес освобождает сцены после финализации рендерера), логирование `SaveManager` при **намеренно** битых сейвах в `test_error_handling`, `SocketServer: Failed to listen: 22` (порт занят параллельным процессом при совпадении запусков).

### Ручной smoke (требует запуска игры, не проверяется headless)

- [ ] Полноэкранные настройки: запуск в fullscreen/окне, переключение режима — UI не ломается.
- [ ] Пауза/экран настроек в бою: вход-выход без сбоя боя.

**Статус:** все автоматические проверки зелёные; ручной smoke — ожидается от пользователя.
