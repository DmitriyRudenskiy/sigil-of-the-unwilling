## 0. Решения (приняты пользователем)
- Второй город — рядом со столицей (~15 гексов).
- Триггер навигации — оба: авто-открытие при подходе + по клику по значку.
- Значок — имя «Город 1»/«Город 2».
- Кнопка выхода — переименовать «Закрыть» → «Выход из города».
- Вход в город — герой ставится на клетку, с которой вошли.
- Значки показываются сразу по клику в меню навигации (без порога расстояния).

## 1. Два города при старте — [x]
### 1.1 [x]
Добавить второй город в `WorldBootstrap._create_cities`.
- [x] «Город 1» (столица «Перворечье»)/«Город 2» (второй, ~15 гексов от столицы)
- [x] `center` второго — через `_nearest_walkable`, рядом со столицей
- [x] `register_city(second, false)` (столица остаётся столицей)

## 2. Навигационные значки городов — [x]
### 2.1 [x]
Реализовать значки городов в `MarkerLayer` (D2).
- [x] Имена «Город 1»/«Город 2» на значках
- [x] Показываются сразу по клику в меню навигации (без порога расстояния)
- [x] Клик по значку → прокладка пути к центру города (проходимая клетка)

## 3. Открытие города у героя — [x]
### 3.1 [x]
Открытие города в `WorldUIManager` (вместо CityPanel реализовано экраном CityScreen из city-in-world, тот же контракт open/close).
- [x] `open_city_screen(city, hero_cell)` / `close_city_screen()` в `WorldUIManager`
- [x] `city_overlay_open()` guard + `refresh_city_screen()`
### 3.2 [x]
Открывать город у героя в `WorldEventRouter._on_hero_moved` (авто-открытие, D3).
- [x] Проверка `cities.city_at(hero.current_cell)` (герой на клетке города)
- [x] Открытие экрана при входе на клетку (идемпотентно)
### 3.3 [x]
Открытие по клику по значку города (D2/D3) — `_on_city_marker_clicked` → `hero.on_map_clicked(target)`.
### 3.4 [x]
Герой ставится на клетку входа: вход в город срабатывает, когда герой стоит на клетке города (hero.current_cell = центр), повторный заход — авто-открытие.

## 4. Кнопка выхода из города — [x]
### 4.1 [x]
Кнопка «✕ Выход из города» → `close()` → `close_requested.emit()`.

## 5. Проверка и коммит
### 5.1 [x]
Запустить `bash game/tools/shell/run_operability.sh`, убедиться в вердикте CLEAN.
- [x] Исправить SCRIPT ERROR/Parse/Run ошибки (ошибок: 0)
- [x] При необходимости обновить `docs/CONSOLE_ALLOWLIST.md` (добавлен teardown-шум Godot 4.7 «N ObjectDB leaked», N≤20 — зондом 200×register/free подтверждено: реальных утечек нет, N≥21 остаётся finding'ом)
### 5.2 [x]
Добавить автотесты (`game/tests/test_city_navigation.gd`):
- [x] При старте 2 города (`test_bootstrap_creates_two_cities`)
- [x] Значки показываются и резолвятся по клетке (`test_city_markers...`, `test_set_city_markers...`)
- [x] Клик по значку эмитит город (`test_city_marker_click_emits_city...`)
- [x] Роутинг клика -> прокладка пути (`test_city_marker_click_routes_path_to_city`, `..._unwalkable_center...`)
- [x] Выход закрывает панель (`test_exit_button_renamed_and_closes`)
### 5.3
Комит только файлов цикла `city-navigation`.
- [ ] `WorldBootstrap`, `MarkerLayer`, `WorldEventRouter` (+ пересечённые с city-in-world)
- [ ] Не выносить файлы других циклов

> Отложено: `WorldEventRouter.gd`/`HeroController.gd`/`WorldBattleCoordinator.gd` содержат
> незакоммиченный WIP параллельной сессии (Succession-Sigil) — коммит по частям невозможен.
> Архивационный коммит переносит только `openspec/changes/city-navigation/`.
