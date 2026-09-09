# Тесты

Полный прогон (единственная точка входа):

```bash
bash tests/run_all.sh
```

Секции: 1) gdUnit4 (все GDScript-тесты, XML-отчёт), 2) MCP (pytest, живой Godot
через godot-mcp), 3) структурные проверки (дубли, остатки mcp_client,
базовый набор `static var`, BattleUI без `get_node_or_null`).

## Требования

- Godot 4.7+ (headless). Путь переопределяется: `GODOT_BIN=/path/to/Godot`
- gdUnit4 4.x — аддон в `addons/gdunit4`
- Node.js 18+ — для MCP-сервера (проверяется в `run_all.sh`)
- godot-mcp **v3.1.0** — вендорен в `addons/godot-mcp`, точка входа
  `addons/godot-mcp/build/index.js`, interaction-порт 9090
- Python 3.12, venv в `addons/venv` (переопределяется `MCP_PY`):
  **mcp 2.1.1, pytest 9.1.1, anyio 4.15.0**. `pip` в venv сломан —
  версии фиксированы, не устанавливать заново.

## Структура

- `unit/` — модульные (data/, systems/, world/, entities/, ui/)
- `functional/` — запуск сцен, перф
- `integration/` — несколько систем + автозагрузки
- `core/`, `systems/`, `world/` — легаси-каталоги (26 сьютов), не переносить
  без необходимости
- `mcp/` — Python-тесты через godot-mcp (conftest.py, godot_mcp.py)
- `helpers/factories.gd` — фабрики (`TestFactories`), единственный источник
- `fakes/`, `spell_validation/` — стабы и харнесс валидации заклинаний
- `static_var_baseline.txt` — зафиксированный набор `static var`
- `run_all.sh` — полный прогон

## Базовая зелёная точка

- gdUnit4: **135 сьютов / 1266 кейсов, 0 ошибок**
- MCP: **11 passed, 1 skipped**
- Отчёты: `reports/report_*/results.xml` (gitignored, держится 20 последних)

## Известный skip (легитимный)

`test_battle_profiling.py::test_cluster_reset_in_battle_scene` —
`нет узлов городов в сцене боя`. Сцена боя по дизайну не содержит узла
`Cities`, поэтому пересчёт кластеров арены в ней неприменим. Скип
детерминированный; `-rs` в `run_all.sh` печатает причину.

## Правила

- Все `RandomNumberGenerator` в тестах — через `TestFactories.seeded(<seed>)`
  (seed по файлу; тело `seeded()` в factories.gd держать как есть —
  массовая замена рекурсирует в само определение).
- Подписки на `GameEventBus` — только через `_bus()`, отписка в `after_test`
  с гардами `is_valid() and is_connected()`.
- Стабы карт реализуют ВСЕ методы, вызываемые в `setup()`/`_ready()`
  тестируемого (включая `get_tile_size()`).
- Лямбды GDScript захватывают локальные по значению — счётчики в контейнере
  (`var clicks := [0]`).
- MCP: `READY_TIMEOUT=900s` — при устойчивой нагрузке ~3.5-4 (Chrome/Vivaldi)
  запуск сцены наблюдён > 10 мин; при низкой нагрузке — 10-15 с. Polling
  бесплатен, бюджет ограничивает только худший случай. Пер-eval timeout 60s
  (> 30s внутреннего таймаута godot-mcp), один retry только на SDK-таймаут
  (`_SdkMCPError`, сообщение `timed out`). SDK-класс не импортировать без
  алиаса — локальный `MCPError` заслоняет имя. Если секция упала по готовности —
  закрыть тяжёлые приложения и перезапустить `run_all.sh` целиком.
- Готовность мировой сцены: polling по `wc._save_svc != null`
  (настраивается последним в `_ready`).
- Новый `static var` вне `static_var_baseline.txt` — провал прогона;
  легитимный кэш добавляется в baseline с указанием имени.

## Покрытие

gdUnit4 4.x не имеет флага покрытия (в 3.x был `--includeCoverage`).
Для метрики строк/веток нужен внешний инструмент (отдельная задача).
