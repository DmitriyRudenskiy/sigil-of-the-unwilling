## 1. Поиск охвата

- [x] 1.1 Полностью собрать все вхождения `belief`, `despair`, религиозных тегов/названий черт (`devout`, `skeptic`, `heretic`, `prophet_ear`, `sigil_touched`, `eternal_wanderer`) по репозиторию: `.gd`, тесты, UI, локализация, данные.
  - Охват: `demographics/Character.gd` (NEED_KEYS), `demographics/DemographicTurnProcessor.gd` (DECAY, штраф эпидемии, recovery, `_death_cause`→`despair`), `demographics/TraitRegistry.gd` (6 черт + теги), `demographics/TraitDef.gd` (комментарий), `tests/test_characters.gd`, `tests/test_demographic_processor.gd`, `tests/test_trait_registry.gd`.
  - UI/данные: рендер имён потребностей и причин смерти в UI отсутствует (только pass-through `WorldBootstrap`→`GameEventBus`), в `.tres`/`.json` ссылок нет. `GameEventBus.faith_milestone` — городская вера (другая система, не трогаем).
- [x] 1.2 Убедиться, что `core/SaveData.gd` / `core/SaveManager.gd` не держат отдельного хранения `belief` (нотация потребностей — внутри `Character`).
  - Подтверждено: `SaveData.characters` — сериализованные `Character` (через `Character.serialize`→`_needs_to_str`), отдельного поля `belief` нет. Миграция помещена в `Character.deserialize`.

## 2. Замена потребности `belief` → `inspiration`

- [x] 2.1 `demographics/Character.gd`: `NEED_KEYS` — `&"belief"` → `&"inspiration"`.
- [x] 2.2 `demographics/DemographicTurnProcessor.gd`: восстановление потребности (`+0.05`), штраф (`-0.1`) и блок recovery (`&"belief"`) → `&"inspiration"`.
  - Заменены: `DECAY[&"inspiration"] = 0.05`, штраф эпидемии `modify_need(&"inspiration", -0.1)`, recovery `&"inspiration": return 0.05`.

## 3. Замена причины смерти `despair` → `burnout`

- [x] 3.1 `demographics/DemographicTurnProcessor.gd`: `_death_cause` — ветка `&"belief"` → `&"inspiration"`, причина `&"despair"` → `&"burnout"`.

## 4. Рефрейм тегов и названий черт (secular)

- [x] 4.1 `demographics/TraitRegistry.gd`: тег `&"belief"` → `&"inspiration"` во всех чертах.
  - Нюанс: черты с тегом `&"belief"` отсутствовали (теги были soul/faith/sigil); по требованию spec («Traits MUST carry a tag identifying them as inspiration-related») добавлен тег `&"inspiration"` всем 6 чертам, влияющим на вдохновение.
- [x] 4.2 `demographics/TraitRegistry.gd`: убрать религиозный тег `&"faith"` (черты `heretic`, `prophet_ear`); тег `&"sigil"` → `&"legacy"` (черта `sigil_touched`).
  - `faith` убран у `jaded` и `path_listener`; `sigil` → `legacy` у `legacy_mark`.
- [x] 4.3 `demographics/TraitRegistry.gd`: переименовать/переформулировать черты `devout`, `skeptic`, `heretic`, `prophet_ear`, `sigil_touched`, `eternal_wanderer` — сохранить механический модификатор и знак, изменить имя и RU-текст.
  - Маппинг (эффекты сохранены 1:1): `devout` «Верующий» → **`kindled` «Разожжённый»** (+0.10); `skeptic` «Скептик» → **`unmoved` «Равнодушный»** (−0.08); `heretic` «Еретик» → **`jaded` «Выгоревший»** (−0.12); `prophet_ear` «Дар пророка» → **`path_listener` «Слышащий Путь»** (+0.20, зов ПУТИ вместо шёпота Сигилла); `sigil_touched` «Повитый Сигиллом» → **`legacy_mark` «Знак рода»** (+0.15; описательное «ко всем потребностям» исправлено на «к вдохновению» — код всегда влиял только на belief/inspiration); `eternal_wanderer` «Вечный странник» → **`path_wanderer` «Странник ПУТИ»** (rest −0.05, inspiration +0.20).
- [x] 4.4 `demographics/TraitDef.gd`: обновить комментарий с `&"belief"` на `&"inspiration"`.

## 5. Миграция сохранений

- [x] 5.1 `demographics/Character.gd` (`deserialize`): при загрузке переносить ключ потребностей `&"belief"` → `&"inspiration"` (защита от «пропадающей» потребности в старых сохранениях).
  - В `deserialize`: если есть `belief` и нет `inspiration` — перенос значения; `belief` удаляется. Смешанный набор: `inspiration` побеждает, `belief` удаляется.
- [x] 5.2 Проверить, что `_needs_to_str`/`deserialize` корректно обрабатывают смешанный набор ключей после миграции.
  - Покрыто тестом `test_deserialize_migrates_belief_to_inspiration` (старое сохранение + смешанный набор).

## 6. UI / локализация (если затрагивается)

- [x] 6.1 Обновить RU-отображение названия потребности и черт в UI, если они рендерятся по тегу/названию.
  - Не затронуто: UI не рендерит имена потребностей/причин смерти (только pass-through сигналов `WorldBootstrap`→`GameEventBus`); RU-тексты живут в `TraitRegistry` (обновлены в 4.3).
- [x] 6.2 Проверить и обновить внешние источники данных (`.tres`/`.json`/таблицы черт), если они ссылаются на старые идентификаторы/теги.
  - Проверено: в `.tres`/`.json` нет ссылок на `belief`/`despair`/старые id черт — изменения не нужны.

## 7. Обновление тестов

- [x] 7.1 `tests/test_characters.gd`: `&"belief"` → `&"inspiration"` (проверки критичности потребности, `trait_modifier`).
- [x] 7.2 `tests/test_demographic_processor.gd`: `c0.needs[&"belief"]` → `&"inspiration"`.
- [x] 7.3 `tests/test_trait_registry.gd`: `t.effect_type = &"belief"` → `&"inspiration"` (и другие ссылки на тег/черты).
  - Дополнительные ссылки на старые id черт в тестах отсутствуют (поиск `devout|skeptic|heretic|prophet_ear|sigil_touched|eternal_wanderer` по `game/` чист).

## 8. Валидация и прогон

- [x] 8.1 Валидатор заклинаний: `--path game -s $PWD/game/tools/spell_validation/validate_spells.gd --strict --json` → errors 0, warnings 0.
  - Прогнано: `"errors": 0, "warnings": 0`.
- [x] 8.2 Полный набор тестов (`game/tools/shell/run_all_ci_checks.sh`) или `run_tests.gd` — без новых падений, все затронутые тесты зелёные.
  - Юниты: `4753 passed, 0 failed (76 файлов)`; `test_characters.gd` 65/0 (включая новый тест миграции).
  - Полный CI: `run_all_ci_checks.sh` → **6 passed, 0 failed (of 6 steps)**; гейт консоли: сценарии 1–5 exit 0, CLEAN (error/warning-маркеров нет).
- [x] 8.3 Проверить загрузку старого сохранения (миграция belief → inspiration) в отдельном кейсе, если возможно.
  - Тест `test_deserialize_migrates_belief_to_inspiration` в `test_characters.gd`: старое сохранение (needs с ключом `belief`) → `inspiration` = 0.4, старый ключ удалён; смешанный набор → `inspiration` (0.6) побеждает.

## Результаты

- Потребность `belief` → `inspiration` заменена во всём коде (`NEED_KEYS`, DECAY, recovery, штраф эпидемии, `_death_cause`), причина смерти `despair` → `burnout`.
- 6 черт переименованы под секулярную тематику (эффекты 1:1): `kindled` «Разожжённый» +0.10; `unmoved` «Равнодушный» −0.08; `jaded` «Выгоревший» −0.12; `path_listener` «Слышащий Путь» +0.20; `legacy_mark` «Знак рода» +0.15; `path_wanderer` «Странник ПУТИ» (rest −0.05, inspiration +0.20). Теги: `faith` убран, `sigil` → `legacy`, добавлен `inspiration` (требование spec).
- Миграция сохранений в `Character.deserialize`: `belief` → `inspiration` (смешанный набор — inspiration побеждает).
- Валидатор заклинаний: 0/0; CI: 6/6 (включая гейт консоли, сценарии 1–5 CLEAN); юниты 4753/0.
- Вне охвата (не тронуто): `GameEventBus.faith_milestone` (городская вера — другая система), UI (имена потребностей не рендерятся), `.tres`/`.json` (ссылок нет).
