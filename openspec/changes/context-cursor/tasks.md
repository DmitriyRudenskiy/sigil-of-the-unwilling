## 0. Запрос у пользователя (блокирующий)
### 0.1
Собрать у пользователя данные по ассетам курсора перед реализацией.
- [ ] Какой размер курсора нужен (напр. 64×64 / 128×128)?
- [ ] Какие картинки за какой режим: ботинок (WALK), рука (COLLECT), два воина (ATTACK)?
      — использовать `game/assets/cursors/cursor_01..31.png` или новые файлы?
- [ ] Hotspot: где точка клича (низ центра / наконечник)?
- [ ] Бой: курсор «два воина» заменяет нарисованны меч-оверлей или работает фоном?
- [ ] COLLECT: рука держится всё время сбора или только «пик» анимации?

### 0.2
Зафиксировать ответы в конфиге `CursorController` (пути/размер/hotspot/режимы боя).
- [ ] Создать конфиг режимов в `CursorController.gd` (или `.tres`) по ответам пользователя

## 1. CursorController
### 1.1
Создать `game/scripts/autoload/CursorController.gd` (autoload) с картой режимов и
`set_mode(mode)`.
- [x] Режимы: DEFAULT, WALK, COLLECT, ATTACK
- [x] `set_mode()` вызывает `Input.set_default_mouse_cursor(texture, hotspot)`
- [x] Стандартный курсор (стрелка) по умолчанию

### 1.2
Загрузить картинки курсоров с конфигурируемым размером и hotspot.
- [x] Размер/пути/hotspot берутся из конфига (шаг 0.2) — `MODE_ASSETS`, `load_texture`
- [x] Если под режим нет картинки — не падать, оставить DEFAULT + лог (юнит-тест `test_unconfigured_mode_does_not_crash`), null-guard `_input`

## 2. Контекст: ходьба (WALK)
### 2.1
Определить движение героя.
- [x] Подписан `CursorController` на `GameEventBus.hero_moving_changed` (эмитит `HeroMovementController._set_moving`)
- [x] Старт движения → `WALK`; остановка → `DEFAULT`

### 2.2
Проверить переключение ботинка.
- [x] При ходьбом героя курсор = WALK (на стоячем = DEFAULT); юнит-тест `test_walk_moving_changes_mode` / `test_walk_still_changes_mode`
- [ ] Скриншот — отложен: ассеты курсора не загружены (пути пустые → DEFAULT)

## 3. Контекст: сбор (COLLECT)
### 3.1
Подписаться на сбор ресурсов.
- [x] `GameEventBus.resource_extracted` → `COLLECT`
- [x] По фазе сбора → возврат к `DEFAULT` через таймер `COLLECT_HOLD_SECONDS` (юнит-тест `test_collect_timer_returns_to_default`)

### 3.2
Проверить переключение руки.
- [x] При сборе курсор = COLLECT; юнит-тест `test_resource_extracted_sets_collect`
- [ ] Скриншот — отложен: ассет не загружен (path пустой → DEFAULT)

## 4. Контекст: атака (ATTACK) — ОТЛОЖЕНО
### 4.1
Дать бою сигнал режима атаки.
- [ ] `BattleController`/`BattleView` эмитят событие при `set_cursor_mode(ATTACK)`
- [x] `CursorController` ловит → `ATTACK` (set_mode доступен); выход из атаки → `DEFAULT` (связан с `battle_completed`/`battle_lost`)
- Отложено: пути ассетов пустые → ATTACK падает в DEFAULT, видимого эффекта нет; вопрос дизайна «заменяет ли „два воина“ меч-оверлей» (0.1) не закрыт. `CursorController` готов принять сигнал, когда ассеты будут мапаны.

### 4.2
Проверить переключение «два воина».
- [ ] Отложено вместе с 4.1 (ассеты не мапаны)

## 5. Проверка и коммит
### 5.1
Запустить `bash game/tools/shell/run_operability.sh`, убедиться в вердикте CLEAN.
- [x] Вердикт: CLEAN (сцены, 12 сценариев, юнит-тесты, console-clean)
- [x] SCRIPT ERROR/Parse/Run ошибки: нет
- [x] docs/CONSOLE_ALLOWLIST.md: не требовался

### 5.2
Добавить автотесты переключения режимов курсора (юнит-тесты `CursorController.set_mode`).
- [x] `game/tests/test_cursor.gd` — 12 passed, 0 failed (карта режимов, шина, таймер COLLECT, graceful fallback)

### 5.3
Комит только файлов цикла `context-cursor`.
- [x] `game/scripts/autoload/CursorController.gd`, `game/tests/test_cursor.gd`, правки `HeroMovementController`, `GameEventBus`, `game/project.godot`
- [x] Не выносить файлов других циклов
