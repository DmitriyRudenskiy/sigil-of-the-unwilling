# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 Конструктор (класс/раса/культура/пол/внешний вид) — `character_creation_ui.gd` (T-113, K1)
- [x] 1.2 Выбор знака из 8 (T-002) — `sign_choice_ui.gd` (D-157)
- [x] 1.3 Поток: конструктор → sign_choice.tscn → main/main.tscn — `character_creation_ui.gd`, `sign_choice_ui.gd`

## 2. Разрывы

- [x] 2.1 Playable slice 3 (люди/полуорки/эльфы, C-15) — маска в конструкторе. **Готово: `PregameFlowModel.is_playable_race()` / `PLAYABLE_RACES`** (маска 3: humans/half_orcs/elves; C-15, владелец 2026-10-04). **Отложено (визуал, ux-review):** привязка маски к `character_creation_ui.gd`.
- [x] 2.2 Земной шар (граф регионов, K-T7) — region-graph-map. **Готово: требование закрыто change `region-graph-map`** (RegionMap runtime + MAP-1 data, 46 регионов; смержен в main).
- [~] 2.3 Выбор городов: сколько угодно; штраф оккупации после второго (кривая TBD, 02-mechanics §3.1). **Готово: `PregameFlowModel.occupation_penalty()`** (0 за 1–2 города, с 3-го — возрастающий; дефолт-кривая [ПРЕДЛОЖЕНИЕ], base=10). **Техдолг (вердикт владельца):** финальная кривая TBD (баланс) — дефолт [ПРЕДЛОЖЕНИЕ]; механическое применение штрафа (что именно drenирует/дебаффит) — за headless-моделью.
- [x] 2.4 Стартовая партия: до 5 попутчиков, у каждого свой класс/раса/внешний вид (§3.2). **Готово: `PregameFlowModel.validate_starting_party()`** (≤5; класс/раса/внешний вид обязательны). **Отложено (визуал, ux-review):** `pregame_party_ui.gd` (новый) / `main.gd`.
- [x] 2.5 Тренировка как база: город = база тренировки; источники — люди из города, попутчики, НПС из событий; попутчики тренируются, не нанимаются (Q18). **Готово: `PregameFlowModel.training_sources()` / `is_trainable_source()`** (city_resident/companion/event_npc; наём вытеснен). **Отложено:** проводка в `campaign_training_service.gd` (зона party-training).

## 3. Синк (C-14, C-15)

- [x] 3.1 C-14: синк терминологии GDD («1 культура (люди)» → «расы/группы», K-A6). **Готово: закрыто в `races-cultures` 3.1** (C-14 terminology sync, смержен в main; дублирование).
- [x] 3.2 C-15: playable-маска 3 в конструкторе (задача 2.1). **Готово: см. 2.1** (`PregameFlowModel.PLAYABLE_RACES`).

## 4. Верификация

- [ ] 4.1 GdUnit4: предыгровой поток (6 шагов до хода 1; порядок: конструктор → знак → земной шар → города → партия → тренировка).
- [x] 4.2 GdUnit4: playable slice 3 (конструктор: только люди/полуорки/эльфы) — `tests/campaign/test_pregame_flow_model.gd`.
- [x] 4.3 GdUnit4: штраф оккупации (3-й город → штраф; растёт с каждым) — `tests/campaign/test_pregame_flow_model.gd`.
- [x] 4.4 GdUnit4: стартовая партия (≤5 попутчиков; у каждого класс/раса/внешний вид) — `tests/campaign/test_pregame_flow_model.gd`.
- [x] 4.5 GdUnit4: тренировка как база (попутчики тренируются, не нанимаются) — `tests/campaign/test_pregame_flow_model.gd`.
