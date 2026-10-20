# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 Меню — `main_menu.gd`
- [x] 1.2 Город — `city_screen.gd`, `campaign_city_board.gd`
- [x] 1.3 Бой — `battle_ui.gd`
- [x] 1.4 Хроника — `chronicle_screen.gd`
- [x] 1.5 Настройки — `settings_screen.gd`
- [x] 1.6 Предыгра (частично) — `character_creation_ui.gd`, `sign_choice_ui.gd` (не связаны — pregame-flow)

## 2. SM навигации и туториал

- [~] 2.1 SM навигации: PREGAME→MENU→MAP→(CITY/BATTLE/PARTY/CHRONICLE/SETTINGS); BATTLE→MAP («Продолжить», K-M8); MAP→ХРОНИКА anytime; *→TUTORIAL (первый вход, 1 раз). **Сделано (headless-логика):** `scripts/ui/campaign_navigation.gd` — чистый SM (граф переходов, туториал «1 раз» внутри SM, сейв/загрузка, инвариант «нет выхода в никуда»), 15 тестов (5.1). **Сделано (headless-проводка):** `scripts/ui/campaign_ui_manager.gd` — campaign-менеджер 8 экранов: привязка SM к слоям (show/hide по `current`), инвариант «≤2 клика до причины» (`can_show` → `{available, reason}`), сигналы `screen_changed`/`tutorial_requested`, инвариант одного активного экрана; 12 GdUnit4-тестов (5.5). **Отложено (визуал/ux-review):** `.tscn` с реальными экранами + раскладка.
- [ ] 2.2 Туториал-оверлей (первые ходы, не сцена) — `tutorial_overlay.gd` (новый); срабатывает на первый вход в экран (1 раз).
- [~] 2.3 Панель целей 3 дней (M3): день 1 — ферма + барраки; день 2 — тренировка воина (K-M15, Q18); день 3 — руины; панель видна, пока не выполнены все цели. **Сделано (headless-логика):** `scripts/ui/campaign_goal_tracker.gd` — цели (building/train/region), события, видимость, «не показывается снова», сейв/загрузка, 11 тестов (5.2). **Отложено (визуал):** панель в `main.gd` (отрисовка по `visible()`/`pending()`).

## 3. Экран партии и инварианты

- [~] 3.1 Экран партии (отдельный) — `party_screen.gd` (новый); данные — `party_system.gd`. **Готово: слой данных (view model) `scripts/ui/party_screen_model.gd`** (roster + ёмкость + подсказка + статы/Удача, чистая логика, headless). **Готово (технический экран, headless):** `scripts/ui/party_screen.gd` — Control-экран поверх view model: 5 слотов (занятые/пустые), строка бойца (класс/раса/уровень/XP/статы/Удача/Ветеран), состояния READY/WOUNDED/UNSTABLE/DEAD (alive-подсчёт в заголовке), подсказка 3.2, инвариант ≤capacity, явное `refresh()` + сигнал `screen_updated` (PartySystem без сигналов → хост обновляет); 13 GdUnit4-тестов (5.6). **Отложено (визуал, ux-review):** раскладка/тема/иконки по мокапам (ui-mockup-parity, зона владельца).
- [x] 3.2 ПАРТИЯ: очередь тренировки пуста и партия полна → «что освободит слот» (ссылка на бой/смерть), не пустота. **Готово: `PartyScreenModel.slot_hint()`** (alive-подсчёт: смерть в бою освобождает слот; `HINT_LINK_BATTLE_DEATH`); 15 GdUnit4-тестов. Несогласованность с гейтом `CampaignTrainingService` (total vs alive) — tech debt (CHANGELOG).
- [~] 3.3 Инвариант ≤2 клика до причины (столп 1) — все экраны. **Сделано (headless, экран карты):** `scripts/ui/map_screen_model.gd` — view model поверх RegionMap; каждое действие/опция движения возвращает `{available, reason}` (move/visit_node/retreat/field_raid + travel_options) — причина всегда на месте, UI просто показывает `reason`. 16 GdUnit4-тестов. **Остаток (визуал/другие экраны):** привязка к сцене карты + распространение паттерна `{available, reason}` на остальные экраны (город/бой/партия/хроника/настройки).
- [~] 3.4 В бою все правила D&D видны без подсказок (справка — по клавише) — `battle_ui.gd`. **Сделано (headless):** `CampaignBattle.strike_breakdown(atk, def_, flank)` — чистая разбивка перевеса удара (base/state/terrain/flank/hunger/fate/reckoning + зона, без мутации, в отличие от `_strike`) + `scripts/ui/battle_info_model.gd` (`active_rules` — список активных условий, `combatant_card`, `strike_info`). 16 GdUnit4-тестов. **Отложено (визуал/ux-review):** отрисовка разбивки/правил в `battle_ui.gd`, справка по клавише.

## 4. Разрешение

- [ ] 4.1 Низкое разрешение (1280×720 миним.): сетка масштабируется, на основных экранах нет скролла; поле боя при 720p — масштаб ×0.8 (C-10).
- [ ] 4.2 Тест на 3 разрешения: 720p/1080p/1440p (иконки не слипаются).

## 5. Верификация

- [x] 5.1 GdUnit4: SM навигации (PREGAME→MENU→MAP→...; BATTLE→MAP; MAP→ХРОНИКА anytime; *→TUTORIAL 1 раз) — `tests/campaign/test_campaign_navigation.gd` (15 тестов).
- [x] 5.2 GdUnit4: панель целей 3 дней (день 1/2/3; панель скрыта после выполнения) — `tests/campaign/test_campaign_goal_tracker.gd` (11 тестов).
- [x] 5.3 GdUnit4: экран партии («что освободит слот» при полной партии) — `tests/campaign/test_party_screen_model.gd` (15 тестов).
- [x] 5.5 GdUnit4: campaign-менеджер экранов (проводка SM: show/hide, can_show, один активный экран, сигналы) — `tests/campaign/test_campaign_ui_manager.gd` (12 тестов).
- [x] 5.6 GdUnit4: технический экран партии (roster/слоты/статы/состояния/подсказка/инвариант ≤5/сигнал/детерминизм) — `tests/campaign/test_party_screen.gd` (13 тестов) + статы/Удача в view model (`test_party_screen_model.gd`, +2).
- [ ] 5.4 UI smoke: 8 экранов (K-M8) — навигация без «закрыть в никуда».
