# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 Training-действия из каталога зданий (поле `training`) — `campaign_training_service.gd` (available_training_actions)
- [x] 1.2 Class-gates по `mvp_catalog.json` — `campaign_training_service.gd` (_approved_class)
- [x] 1.3 Расовые тиры (K-M5) — `campaign_training_service.gd`
- [x] 1.4 PARTY_CAPACITY = 5, партия полна → действий нет — `campaign_training_service.gd`. **(2026-10-20, D-221/V-6):** гейт — **alive-модель** (`PartySystem.alive_members`): «полна» = живых ≥ 5; DEAD не занимают слот и не блокируют тренировку/рекрутинг (согласовано с `party_screen_model`/`campaign_composition`). Тесты: `test_campaign_training_service.gd` (+4 alive-теста).
- [x] 1.5 Валидация стоимости по `CAMPAIGN_MVP_IDS` — `campaign_training_service.gd`
- [x] 1.6 Тренировка только в городе (герой в городе — условие) — `campaign_training_service.gd`/`city_screen.gd`

## 2. SM рекрута и паузы

- [ ] 2.1 SM рекрута: REQUESTED→TRAINING→READY→(партия); STANDING при полной партии — Post-MVP (MVP: не создавать, UI «что освободит слот»).
- [ ] 2.2 PAUSED при разрыве сети (здание разрушено/продано); PAUSED→TRAINING при восстановлении, таймер не сбрасывается; пауза ≠ отмена (стоимость не возвращается).
- [ ] 2.3 Резидентная модель статусов (K-A5) в `population_system.gd`: Child/Worker/Mentor/Recruit/Fighter/Hero/Party-in-field; призыв = вакансия (производство останавливается).
- [ ] 2.4 Порог населения 10 на юнит [ПРЕДЛОЖЕНИЕ] — конфиг с пометкой, вердикт автора.
- [ ] 2.5 Сейв: рекрут-экземпляр {building_uid, class_id, progress, state} — MvpSaveSchema, миграция fail-fast.

## 3. Синк данных (C-12, C-13)

- [x] 3.1 C-12: синк GDD-таблицы «Базовые бойцы» (02-mechanics §3.3 / 07-balance §3) с K-R2-реестром: «10 оружия» → «2 железа» (или вердикт владельца по оружию как товару Layer-2 в стоимости). (2026-10-19, локальный агент: синк выполнен по канону C-12 «код = канон» — 02-mechanics §3.3 и 07-balance «Базовые бойцы MVP»: «10 оружия» → «2 железа» (код: `campaign_building_catalog.json` training costs `{food: 20, iron: 2}`); 06-economy: тренировка потребляет железо напрямую, сток оружия = upkeep+восстановление; C-12 в 09-risks.md разрешён. Вердикт владельца по оружию как товару Layer-2 в стоимости не требуется: K-R2-канон (оружие = товар Layer-2, не ресурс) сохранён, MVP-код обходит его — зафиксировано в 06-economy.)
- [ ] 3.2 C-13: маска классов тренировки MVP — 6 (GDD) vs 3 (код); базовые 3 K-M15 = fighter/ranger/wizard vs код fighter/ranger/cleric — вердикт владельца + синк.
- [ ] 3.3 T-041: статы волшебника — баланс-конфиг Ф4; до этого wizard-тренировка не генерируется.

## 4. Верификация

- [ ] 4.1 GdUnit4: SM рекрута (TRAINING→PAUSED→TRAINING, таймер сохраняется; стоимость не возвращается).
- [ ] 4.2 GdUnit4: разрыв сети (рейд по зданию, продажа здания) → PAUSED; восстановление → TRAINING.
- [ ] 4.3 GdUnit4: резидентная модель (призыв → вакансия → производство останавливается).
- [ ] 4.4 GdUnit4: порог населения (10 на юнит) → тренировка недоступна.
