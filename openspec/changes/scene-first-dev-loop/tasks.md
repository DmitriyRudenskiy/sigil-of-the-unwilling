# Tasks: scene-first-dev-loop

## 1. Съёмщик одной сцены

- [ ] 1.1 `game/tools/shot_scene.gd`: `extends SceneTree`, аргументы `--scene=`,
      `--state=<фикстура|путь.gd>`, `--out=`, `--width/--height` (дефолт — канон
      1920×1080). Повтор `add_child`/`change_scene` по кадрам (урок «Parent node is
      busy setting up children», уже учтён в `tools/ui_dump.gd`).
- [ ] 1.2 Отказы, а не молчание: `--headless` (dummy-рендер → чёрный кадр),
      сцена не загрузилась (`current_scene.scene_file_path` ≠ заказанной — тот же
      гард, что в `game/tests/mcp/capture.py: capture_scene`), кадр пустой
      (средняя яркость < 3).
- [ ] 1.3 Замер стоимости цикла: `time Godot --path game -s tools/shot_scene.gd
      -- --scene=res://scenes/ui/artifact_inventory_screen.tscn
      --state=inventory_grid --out=/tmp/shot/inventory.png` — число идёт в Metrics
      вместо «не замерялся».
- [ ] 1.4 Предупреждение о клампинге окна (на этой машине канон недостижим:
      окно выходит ~1836×1025) — кадр при этом пишется, вердикт по размеру не выносится.

## 2. Граница «разработка / гейт» в носителях

- [ ] 2.1 `AGENTS.md` § «Режим работы»: `run_tests.sh` — один прогон перед
      публикацией; в разработке не запускается. Формулировка «зелёный гейт до push
      обязателен» сохраняется.
- [ ] 2.2 `AGENTS.md` § «Верификация»: таблица быстрых проверок по шагу (один файл
      GdUnit, один pytest-узор, `scripts/ui_grid.py --self-check`, `gdlint`,
      `check_docs_links.py`) + строка про `tools/shot_scene.gd`.
- [ ] 2.3 `docs/mvp/CAPTURE-HELPER.md`: секция «чем снимать в разработке, чем —
      на гейте»; кадр из tools не входит в манифест и не доказывает канон.
- [ ] 2.4 `.pi/skills/ui-grid-review/SKILL.md` шаг 1: съёмка через
      `tools/shot_scene.gd`; pytest-путь остаётся шагом воспроизведения/вердикта.
- [ ] 2.5 `docs/CHANGELOG.md` — запись смены цикла; `python3 scripts/check_docs_links.py`.

## 3. Проверка

- [ ] 3.1 Инвентарь: кадр получен без MCP-сервера и без порта 9090, при работающей
      чужой MCP-сессии (конфликта нет).
- [ ] 3.2 Гарды проверены отрицательными прогонами: `--headless`, несуществующая
      сцена, пустой кадр — каждый даёт ненулевой exit и сообщение, а не PNG.
- [ ] 3.3 Один полный `game/run_tests.sh` в конце смены — вердикт публикации
      (сравнение с базлайном: MCP 82/2/1, падение T-178 известно).
