# Tasks: balance-core

## 1. Автоигрок
- [x] 1.1 `BalanceProbeScenario` (GDScript): новый мир на seed, шаги автоигрока (сбор → выгрузка → стройка → рекрутка → бой) через существующие API (CityScreen/CityService/WorldEventRouter)
- [x] 1.2 Запуск и пошаговый контроль через MCP `eval`/`call_method` (шаблон по test_battle_full_e2e.py)
- [x] 1.3 Авто-разрешение боёв: авто-исполнитель (атака ближайшего / ожидание) до конца боя
- [x] 1.4 Защита от затыков: лимит повторений действия (3) + счётчик stuck

## 2. Метрики и отчёт
- [x] 2.1 Логгер событий прогона: first_building_turn, first_recruit_turn, collision/win/loss, stuck, снапшоты состояния
- [x] 2.2 JSON-отчёт `tools/mcp/reports/balance_<seed>.json` + сводка в stdout
- [x] 2.3 `test_balance_probe.py`: полный прогон на фиксированном seed; hard-fail только на техсбоях (смерть героя, stuck-лимит, MCP-ошибка)

## 3. Прогонка Буря vs Ясный
- [x] 3.1 Замеры storm_stall_ratio: два прогона с форсированным сезоном (WorldSeasons статика)

## 4. Калибровка
- [x] 4.1 Первый прогон (до калибровки) — базовый отчёт
- [x] 4.2 Правки констант под пороги (кандидаты из design.md: backpack cap/cart, city prosperity, building costs, auto-ресурсы)
- [x] 4.3 Повторный прогон (после) — сравнение отчётов, таблица до/после
- [x] 4.4 Проверка: полный gdUnit-прогон зелёный после правок чисел

## 5. Закрытие
- [x] 5.1 Отчёт калибровки (до/после + исключения с обоснованием) — артефакт в openspec/changes/balance-core/ (calibration-report.md)
- [x] 5.2 openspec validate + commit + push (validate valid, 2026-09-25)
