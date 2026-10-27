# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 Training-действия из каталога зданий (поле `training`) — `campaign_training_service.gd` (available_training_actions)
- [x] 1.2 Class-gates по `mvp_catalog.json` — `campaign_training_service.gd` (_approved_class)
- [x] 1.3 Расовые тиры (K-M5) — `campaign_training_service.gd`
- [x] 1.4 PARTY_CAPACITY = 5, партия полна → действий нет — `campaign_training_service.gd`. **(2026-10-20, D-221/V-6):** гейт — **alive-модель** (`PartySystem.alive_members`): «полна» = живых ≥ 5; DEAD не занимают слот и не блокируют тренировку/рекрутинг (согласовано с `party_screen_model`/`campaign_composition`). Тесты: `test_campaign_training_service.gd` (+4 alive-теста).
- [x] 1.5 Валидация стоимости по `CAMPAIGN_MVP_IDS` — `campaign_training_service.gd`
- [x] 1.6 Тренировка только в городе (герой в городе — условие) — `campaign_training_service.gd`/`city_screen.gd`

## 2. SM рекрута и паузы

- [x] 2.1 SM рекрута: REQUESTED→TRAINING→READY→(партия); STANDING при полной партии — Post-MVP (MVP: не создавать, UI «что освободит слот»).
  → **Снято с T-170 вариантом (а) (2026-10-24):** носитель — живой `City`, очередь
  `City.campaign_training` (`{uid, class_id, race_id, trainee, training_building_uid, state,
  progress, cost}`), тик — production-фаза `campaign_composition._process_city_training()`
  (после достройки: слоты партии считает композиция, не сервис). Переходы: заявка →
  REQUESTED (стоимость списана с `city.resource_ctx` — тем же путём, что стройка города),
  живой инстанс здания → TRAINING, `progress ≥ 1` → READY, свободный слот → выдача члена
  партии и запись уходит из очереди. STANDING не заводится (Post-MVP): при полной партии
  рекрут стоит в READY и ждёт слота (spec: «does not enter party»). Инстанс здания —
  `state == "active" && construction_turns_remaining <= 0` (стройкам тик не идёт).
  Наблюдаемость TRAINING при канон-времени 0.6 дня — всё ещё вопрос владельцу **Q-M101**
  (тест `test_canon_training_time_fits_into_single_turn` фиксирует следствие, а не мечту).
- [x] 2.2 PAUSED при разрыве сети (здание разрушено/продано); PAUSED→TRAINING при восстановлении, таймер не сбрасывается; пауза ≠ отмена (стоимость не возвращается).
  → Разрыв = инстанса нет (`uid` не найден — продажа) или он не активен (рейд/руина).
  Прогресс стоит, стоимость не возвращается; возврат инстанса → TRAINING с того же
  прогресса. Тест: 4.2.
- [x] 2.3 Резидентная модель статусов (K-A5) в `population_system.gd`: Child/Worker/Mentor/Recruit/Fighter/Hero/Party-in-field; призыв = вакансия (производство останавливается). **Закрытие 2026-10-27 (автономный аудит не заархивированных смен):** Блокаторы T-183/T-184 подтверждены сверкой 2026-10-27: в `game/scripts/campaign/population_system.gd` набора статусов K-A5 нет (grep `Child|Worker|Mentor|Recruit|Fighter|Hero` — 0 совпадений), носителей населения по-прежнему два (`city.pop` у экономики, реестр жителей у `PopulationSystem`). Реализация до сведения носителей написала бы ответ за владельца.
  → Блокатор сменился: носитель-очередь есть (T-170, вариант (а)), нет набора статусов.
  → Замер 2026-10-24 (**T-183**): носителей населения **два** и они расходятся —
    `city.pop` (его читает экономика: спрос еды, рабочие зданий; за 14 ходов не меняется)
    и `PopulationSystem.residents` (рождения/смерти, его читает `settlement.population`);
    `conscript()` не вызывается ниоткуда, у партии uid жителя = −1, uid-пространства
    пересекаются. Статусы K-A5 нельзя положить «куда-нибудь» — нужен выбор носителя.
    Он сделан: **Q-M102 → D-242 (а)**, канон = реестр; переезд экономики — **T-184**,
    до него задача не берётся (иначе код выберет носитель молча). Pin шва —
    `game/tests/campaign/test_population_carriers_seam.gd` (4 кейса, мутации M1–M2).
  У `PopUnit.State` легаси-набор `{WORKER, FOLLOWER, MILITIA, SCHOLAR}` (`scripts/world/pop_unit.gd:4`), не K-A5; сводить два набора надо решением, а не молча переписывать enum.
- [x] 2.4 Порог населения 10 на юнит [ПРЕДЛОЖЕНИЕ] — конфиг с пометкой, вердикт автора.
  → **Carrier-note.** Число легло в `data/config/balance/campaign.json` → `training`:
  `population_per_unit: 10` + `_note` с пометкой «[ПРЕДЛОЖЕНИЕ] (02-mechanics §3.3 EC3),
  вердикт автора»; фолбэк в коде — `DEFAULT_POPULATION_PER_UNIT`. Заодно там же канон
  времени тренировки (`days: {fighter: 0.6, ranger: 0.5}` — `07-balance` «Базовые бойцы MVP»,
  K-M15; волшебника нет — T-041 → `training_days() == 0.0`) и `concurrency_n: 1`
  (множитель N формулы 02-mechanics: числа в GDD нет, строка в реестре `07-balance` §10).
  Гейт: `CampaignTrainingService.population_gate` — порог = `per_unit × (живые в партии +
  тренируемый)`; `available_training_actions` при недоборе возвращает `[]` (опция скрыта),
  `train()` → `population_below_threshold:N<M`; текст «нужно +N жителей» берётся из `missing`
  того же гейта (spec: «UI shows the population constraint»).
- [x] 2.5 Сейв: рекрут-экземпляр {building_uid, class_id, progress, state} — MvpSaveSchema, миграция fail-fast.
  → Ключ — `City.campaign_training` (не отдельная секция: `MvpSaveSchema.SECTIONS` закрыт,
  `city` — свободная форма, а живой город и так сериализуется блобом `city.campaign_city`).
  `CitySerializer`: запись + строгое чтение (запись без `class_id`/`state` → `push_error` и
  отбрасывание, молчаливого «починили» нет), `SERIALIZATION_VERSION` 5 → 6, миграция
  `from_version < 6` → пустая очередь. Тесты: roundtrip, старый сейв, битая запись.

## 3. Синк данных (C-12, C-13)

- [x] 3.1 C-12: синк GDD-таблицы «Базовые бойцы» (02-mechanics §3.3 / 07-balance §3) с K-R2-реестром: «10 оружия» → «2 железа» (или вердикт владельца по оружию как товару Layer-2 в стоимости). (2026-10-19, локальный агент: синк выполнен по канону C-12 «код = канон» — 02-mechanics §3.3 и 07-balance «Базовые бойцы MVP»: «10 оружия» → «2 железа» (код: `campaign_building_catalog.json` training costs `{food: 20, iron: 2}`); 06-economy: тренировка потребляет железо напрямую, сток оружия = upkeep+восстановление; C-12 в 09-risks.md разрешён. Вердикт владельца по оружию как товару Layer-2 в стоимости не требуется: K-R2-канон (оружие = товар Layer-2, не ресурс) сохранён, MVP-код обходит его — зафиксировано в 06-economy.)
- [x] 3.2 C-13: маска классов тренировки MVP — 6 (GDD) vs 3 (код); базовые 3 K-M15 = fighter/ranger/wizard vs код fighter/ranger/cleric — вердикт владельца + синк. **Решено 2026-10-24 агентом по делегированию владельца (D-236): противоречие распадулось после замера, кода-маски не завели.** Маска = 6 (02d K1-A, T-113), её носитель — `mvp_catalog.json → hireable` (уже покрыт тестами). K-M15 — таблица чисел трёх ПОЗИЦИЙ (воин/следопыт/волшебник), а не маска: строка «Волшебник» говорит «маска: 6 классов (02d K1-A)». «Код = 3» оказался про данные: training-действия есть у 64 зданий трёх классов (воин 29, следопыт 27, жрец 18), у paladin/rogue/wizard — ни одного. Обучаемых фактически **два**: живой носитель требует канон-время, а `training.days` = {fighter 0.6, ranger 0.5}; жрец и волшебник отклоняются `no_training_time:` (проверено заявкой по зданию `aoe4_abbey_of_the_trinity`). Волшебник остаётся в маске и не генерируется — это ровно формулировка 3.3 «до этого wizard-тренировка не генерируется». Статблок волшебника при этом существует (`unit_statblocks.mage`: 24 хп / КБ 13 / атака 18 / урон 10 / Удача 1, калиброван T-041 и покрыт `test_t041_anchors`), поэтому 3.3 закрыта тем же свипом отдельно; не хватает стоимости/времени (в 07-balance колонка «Наём» для волшебника — TBD) и training-действия здания. Тесты: `test_training_class_mask.gd` (5 кейсов, в т.ч. класс вне hireable → `unsupported_class`, т.е. источник маски — каталог). Измеренный остаток вынесен в **T-174** (4 класса из 6 без канон-времени; 3 класса без training-действий; у боя нет носителя ячеек заклинаний, поэтому волшебник без T-041 — просто плохой воин).
- [x] 3.3 T-041: статы волшебника — баланс-конфиг Ф4; до этого wizard-тренировка не генерируется. **Закрыто 2026-10-24 свипом 3.2: обе половины формулировки исполнены, и ни одной цифры агент не придумал.** (1) «статы» = `data/config/balance/campaign.json → unit_statblocks.mage` ({hp 24, ac 13, attack 18, damage 10, luck 1, dex 13, con 2, proficiency 3, cr 5}); «mage» = Волшебник (wizard) по 02d, синонимия id зафиксирована в `_meta` mvp_catalog.json; числа откалиброваны прогоном T-041 и закреплены `test_t041_anchors` (три позиции warrior/ranger/mage против босса). (2) «до этого не генерируется» = гейт `training_days(class) <= 0` в живом носителе: `request_training(..., "wizard", ...)` → `no_training_time:wizard`, в предложения города волшебник не попадает — закреплено `test_training_class_mask.gd`. Чего закрытая задача НЕ означает: волшебник по-прежнему не обучается. Для этого нет не статблока, а три другого — стоимости/времени (07-balance, «Наём»: TBD), training-действия хотя бы одного здания и носителя его роли в бою (бой читает `unit_statblocks.warrior` для всех членов партии, D2-прокси; ячеек заклинаний у партии нет). Всё это — **T-174**, а не 3.3.

## 4. Верификация

- [x] 4.1 GdUnit4: SM рекрута (TRAINING→PAUSED→TRAINING, таймер сохраняется; стоимость не возвращается).
  → `tests/unit/campaign/test_campaign_training_live.gd` (живой носитель) +
  `test_production_phase_ticks_queue_and_fills_party` (шов кампании: `advance_turn()` →
  рекрут в партии). Шаг тика — `speed_n` из конфига (`concurrency_n`), субсуточное время
  растягивается множителем, иначе канон-время не наблюдаемо (Q-M101).
- [x] 4.2 GdUnit4: разрыв сети (рейд по зданию, продажа здания) → PAUSED; восстановление → TRAINING.
  → `test_network_break_pauses_and_resume_keeps_progress_and_cost`: руина → PAUSED (прогресс
  и списанная стоимость стоят) → активен → TRAINING с тем же прогрессом → `campaign_buildings`
  пуст (продажа) → снова PAUSED.
- [x] 4.3 GdUnit4: резидентная модель (призыв → вакансия → производство останавливается). **Закрытие 2026-10-27 (автономный аудит не заархивированных смен):** Тот же блокатор (T-184): тест резидентной модели не может быть написан до сведения носителей населения — он зафиксирует один из двух текущих носителей как канон. Переезжает в T-184.
  → **T-170** остаётся только для этой задачи: очередь-носитель есть, резидентной модели K-A5 нет.
  → Тот же блокатор, что у 2.3: **T-184** (сведение носителей). Тест модели не может
    быть написан до выбора носителя — он напишет ответ за владельца.
- [x] 4.4 GdUnit4: порог населения (10 на юнит) → тренировка недоступна.
  → `test_campaign_training_service.gd`: `test_population_threshold_blocks_training_request`
  (опция скрыта, заявка отклонена, списаний нет), `test_population_gate_reports_missing_residents`
  (порог на юнит + «нужно +N»), `test_population_threshold_reads_balance_config` (число из конфига).
  Живая вложенность города: `test_building_instances_read_live_city_nesting`.
