## 1. Оживить adventure-слой до первого удаления

- [x] 1.1 Слить сцены в `game/scenes/ui/adventure_ui.tscn` — сделано дешевле плана: файл стал носителем мира (корень `World` (`Node2D`, `world_controller.gd`) + инстанс `world_ui.tscn`), а прежняя UI-сцена переехала в `game/scenes/ui/adventure_hud.tscn` (`git mv`); `game/scenes/archive/world.tscn` удалён, `world_ui.tscn` остался промежуточным слоем. Ни один литерал пути узла не правился: `$WorldUI` (`world_controller.gd:24`) и `$WorldUILayer/AdventureUI` (`world_ui_manager.gd:12`) остались валидны, PATH-GATE зелёный. Перевешены пути носителя в `scripts/`, `tests/`, `tools/` (~20 файлов) и три теста раскладки (`test_adventure_ui_layout.gd`, `test_infopanel_layout.gd`, `test_tail_screens_theme_carrier.gd` → `adventure_hud.tscn`)
- [x] 1.2 Репойнт потока: `sign_choice_ui.gd:9` (`_CAMPAIGN_SCENE`) → `res://scenes/ui/adventure_ui.tscn`; константа `_CAMPAIGN_SCENE` в `character_creation_ui.gd:8` переименовывается в `_SIGN_SCENE` (имя врёт: ведёт к Знаку); `save_load_screen.gd` — Continue/Load ведут на тот же путь
- [x] 1.3 Убедиться, что `pending_new_game` и `pending_sign_id` из `WorldPersistence` доживают до экрана приключения: герой на карте = созданный, Знак в состоянии (спека `pregame-flow`, сценарий «Hero and sign survive the transition»). Итог: `pending_new_game`
  читал `world_bootstrap` и раньше; `pending_sign_id` до мира не доходил — потребителя был только
  кампейн. Знак повешен на героя (`hero_controller.gd`: `sign_id` + `serialize`/`deserialize`),
  кладёт его `world_bootstrap._init_hero`; проверка — `test_hero_serialize.gd` (round-trip,
  старый сейв) и `tests/slow/test_world_bootstrap.gd` (Знак доезжает до героя мира)
- [x] 1.4b Полный прогон `game/run_tests.sh --tier=full` (2026-11-05, X 192.168.0.86): GDUnit **3683 / 0 / 0** (счётчик восстановлен с 2861: в `tests/` остались три несборные кампании-фикстуры, они в ведре 3.3), MCP **104 passed / 2 skipped / 5 failed / 14 errors** — жёлтый. Обоснование: 14 errors + `test_campaign_continue` — кампейн-e2e на `main.tscn` (`conftest.full_cycle` ждёт `scripts/main/main`, а Знак ведёт в `adventure_ui.tscn`) → ведро 2.3/3.3; 3 fail — семейство `test_threat_rings_visual` «окно носителя … за кадром» (зарегистрированная flake геометрии окна: тот же ассерт и текст в тикете к T-302, в изоляции проходит); 1 fail — `test_marker_fog_visual` (то же семейство визуальных замеров). Падений логики ботстрапа/героя/сейвов нет
- [ ] 1.4 Кадр: `tools/shot_scene.gd --scene=res://scenes/ui/adventure_ui.tscn` + каноническая съёмка; кадр кладётся в `tmp/shots/`, в репозиторий не коммитится (D-185)
      **Кадр снят 2026-11-09, каноническая съёмка — нет.**
      `game/tmp/shots/rmc-adventure-1080.png` (`tools/shot_scene.gd`, 1920×1080, без
      MCP-сервера — кадр шага разработки, канон не доказывает): носителем поднимается
      мир, герой «Прохор» на карте, миникарта, сетка умений, ресурсная строка и список
      ресурсов на месте — то есть кольцо `world_ui → adventure_ui` (снят `c6376cca`)
      кадром подтверждено. Расхождение: за кадром остаются синие колонки HUD по x≈0 и
      x≈1890 — зарегистрированное семейство геометрии окна (T-302, тот же ассерт),
      новым дефектом не заводится. Осталась каноническая ветка (`tests/mcp/test_capture.py`)
      и сверка с `design/single_window_layout/all_screens_ui.png`.
- [ ] 1.5 Ручной проход игрока: движение героя, вход в город, выход в карту, миникарта, кнопка хода. **Стоп-условие: если не играбелно — снос (группы 3–5) не начинается**, находка идёт в TICKETS отдельным тикетом
- [x] 1.6 `game/run_tests.sh --tier=smoke` зелёный — **2026-11-09: 40 кейсов / 0 ошибок /
      0 падений, exit 0** (`TIER COVERAGE: OK, собрано 6 из 6`). До зелёного общий
      прогон красил единственный FAIL не логики, а сора: `game/concept_art/` (копия
      канонического `concept_art/krea2/`, 45 `.webp` + 45 `.import`) попадал в
      Godot-проект и красил `SCAN/SKIP`-прогон `tests/smoke/test_compile_all.gd:57`.
      Копия сверена `md5` с каноном (45/45 совпали, расхождений нет) и вынесена в
      `/tmp/sotu_stray_concept_art_2026-11-09/`; на голом HEAD срез тоже не проверялся
      отдельно — полный прогон на нём зелёный (`c6376cca`,
      `artifacts/head_export_gate_2026-11-09.log`).

## 2. Перевесить носители тестов на новый путь

- [ ] 2.1 Разложить 39 файлов, цепляющих кампанию, на два ведра — «удаляется» (кампейн-правила: ход, провизия, туман, кампейн-HUD, якоря T-041) и «перезаписывается на world-носитель» (общие системы: город, партия, сейв) — списком в `docs/mvp/TICKETS.md` под тикетом сноса; пересмотр списка только явной записью
- [ ] 2.2 Переписать ведро «перезаписывается»: конструктор состояния — world-слой вместо `CampaignComposition`
- [x] 2.3 MCP-e2e: `tests/mcp/conftest.py` (путь `меню → создание → Знак → экран`), `test_campaign_carrier.py`, `test_scene_transitions.py` — carrier-тесты на world-путь; кампейн-специфичные e2e-файлы в ведро удаления. **Закрыто 2026-11-09.** `full_cycle` ведёт по потоку до экрана приключения и ждёт героя (`scripts/world/world_controller`), `test_full_cycle.py` проверяет то, что поток обязан донести: `hero_name` (T-110) и `sign_id` (T-002 + 1.3); assertion «ход 1→2» снят — хода как кампейн-операции в мире нет (D-229). 12 тестов `test_campaign_carrier.py` поднимают `main.tscn` **напрямую** (новый fixture `campaign_game`): кампейн как сцена живёт до 3.3, а из потока вышел, — меню-путь им больше не нужен. `test_scene_transitions.py` переведён на `adventure_ui.tscn` раньше (`c6376cca`). Замер: `pytest tests/mcp/test_full_cycle.py test_campaign_carrier.py test_campaign_continue.py` → **14 passed / 41.42 с**. Кампейн-специфичные файлы (тот же `test_campaign_carrier.py`) в ведро удаления не перенесены — это 2.1, список ведра не написан.
- [ ] 2.4 Манифест съёмки и `tools/theme_smoke.gd`: носители `world_ui.tscn`/`adventure_ui.tscn`/`world.tscn` вместо `main.tscn` и кампейн-HUD; 10 фикстур `game/tools/capture/campaign*.gd` — в ведро удаления, их место в манифесте — за миром
- [ ] 2.5 `game/run_tests.sh --tier=fast` зелёный (оба ведра уже перевешены, кампейн ещё жив)

## 3. Снести кампейн-механику

- [ ] 3.1 Откатить сегодняшнюю правку снабжения: `campaign_composition.gd` (полный ранец) и `game/tests/campaign/test_campaign_start_supply.gd` вместе с `.uid` — чинить нечего
- [ ] 3.2 Удалить `game/scripts/campaign/**` (19 `.gd` + `.uid`), `game/scripts/ui/campaign*.gd` (10), `game/scripts/main/main.gd`, `game/scripts/ui/map_screen_model.gd`, `RegionMap` с регион-графом
- [ ] 3.3 Удалить `game/scenes/main/main.tscn` и ведро «удаляется» из 2.1 (тесты, фикстуры, `.uid`)
- [ ] 3.4 Снять кампейнские поля `City`: `campaign_buildings`, `campaign_training`, `campaign_group_state` (`scripts/world/city_data.gd`), ветки `city_serializer.gd`, флаг и ветку `is_campaign` в `city_manager.gd`; тесты линии тренировки T-170 правятся в этом же шаге
- [ ] 3.5 `city_screen.tscn` остаётся единственным носителем города: убрать `preload` из кампейн-HUD (был `campaign_hud.gd:40`), проверить потребителей (`world_ui.tscn`, `balance_probe.gd`)
- [ ] 3.6 `godot --headless --path game --import` (кэш глобальных классов), затем `game/run_tests.sh --tier=fast`, затем полный `game/run_tests.sh` — зелёный, включая NODE-PATHS и ORPHAN-CHECK
- [ ] 3.7 Снос — один коммит, `git mv` для возвращённых сцен сохранён; откат = revert этого коммита

## 4. Поставить запрет

- [ ] 4.1 `scripts/check_campaign_lockout.py`: запрещённые пути (`game/scripts/campaign/`, `game/scenes/main/main.tscn`, `game/scripts/ui/campaign*`) и идентификаторы (`CampaignComposition`, `res://scenes/main/main.tscn`) вне allowlist; печать числа проверенных путей; самопроверка чекера — по образцу `scripts/test_check_node_paths.py`
- [ ] 4.2 Включить чекер в список `TESTS` прогона `game/run_tests.sh`; пустой обход должен быть красным
- [ ] 4.3 Рантайм-отказ: схема T-110 теряет секции `campaign.*`, загрузка кампейн-сейва отвечает атомарным отказом с причиной «механика кампании удалена»; тест GdUnit на отказ и на «обычные сейвы грузятся как раньше»
- [ ] 4.4 `AGENTS.md`: строка запрета (работа поверх снятого слоя = нарушение правил) со ссылкой на новый D
- [ ] 4.5 `docs/DECISIONS.md`: новый D — вытесняет D-157 и D-163, причина, границы запрета, ссылка на change
- [ ] 4.6 Проверить запрет на самом себе: временно вернуть файл из-под запрета → прогон красный с путём и id решения; убрать → зелёный. Результат прогона — в тикете сноса

## 5. Документация и след в истории

- [ ] 5.1 `docs/mvp/TICKETS.md`: кампейн-тикеты (T-010, T-020, T-021, T-022, T-041, T-110, T-115, T-116, T-117, T-121, T-182, T-186, T-196, T-280 и другие из 116 упоминаний) получают статус «снят с плана (D-…)» с причиной; текст остаётся; T-196/T-280 — по решению из open questions design.md
- [ ] 5.2 Записать в TICKETS, что мера баланса отсутствует: с кампанией ушли 7 якорей T-041 и 21-ходовой каркас
- [ ] 5.3 `docs/DECISIONS.md`: новая запись D-… фиксирует снятие cutover-актов D-157/D-163 и указание владельца от 2026-11-05, снимающее силу с D-204 (Q-M87 → (б), «архивный `world.tscn` не реанимируется»); `scenes/archive/README.md` — обратная запись: носитель вернулся в рантайм-путь, трёхисходное правило D-157 к нему больше не применяется
- [ ] 5.4 Связность wikilinks проверена по диффу (сверщик `check_docs_links.py` снят); `gdlint`/`gdformat` по изменённым `.gd`
- [ ] 5.5 `openspec validate remove-campaign-mechanic --strict` зелёный; после реализации — `openspec archive` применяет `REMOVED`-дельты семи кампейн-возможностей и `ADDED` носителя запрета
