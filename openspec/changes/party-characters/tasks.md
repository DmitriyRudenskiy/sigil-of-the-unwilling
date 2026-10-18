# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 Партия ≤5, герой = лидер (R1) — `party_system.gd` (PARTY_CAPACITY в training service)
- [x] 1.2 XP-пороги 0/2700/6500/15000/38000, уровни 1–5 (K-M13, R4) — `party_system.gd` (XP_THRESHOLDS, T-060)
- [x] 1.3 Источники XP: бой 100×CR×(1+0.1n), узел 200–800, рейд 300 — `party_system.gd` (XP_RAID_SURVIVED, NODE_XP_MIN/MAX)
- [x] 1.4 ASI +2/+1, кап 16, Удача не объект ASI (K3) — `party_system.gd` (ASI_CAP, ASI_ABILITIES)
- [x] 1.5 Потери и wipe: defeat только при wipe партии (Q-M68→(а), D-190) — `party_system.gd:108`, `turn_driver.gd:76`
- [x] 1.6 Удача = 7-я хар-ка (каталог K-M5) — `mvp_catalog.json`, `party_system.gd` (luck в roster)
- [x] 1.7 Смерть героя = «утрата», не конец кампании (R1) — `party_system.gd` (K-M11)

## 2. Слой T-116: внутрибоевые состояния

- [ ] 2.1 WOUNDED/UNSTABLE в боевом контексте (`campaign_battle.gd`): порог WOUNDED, переходы READY→WOUNDED→UNSTABLE→DEAD; не персистятся между боями.
- [ ] 2.2 REST в городе: 1 день, лечение `(2 + CON) × хит-дизайн`; WOUNDED → READY при HP выше порога.
- [ ] 2.3 Замена мёртвых: попутчик того же класса через тренировку (party-training), уровень 1 (конфиг `replacement_level`; C-1 — вердикт владельца по «уровню города − 1»).

## 3. Ветеран и снабжение

- [x] 3.1 Ветеран (Q-M56→(а), K-M10): счётчик пережитых боёв, порог N (баланс-конфиг Ф4), +1 ступень к спасам/проверкам до конца боя (`party_system.gd`: battles_survived, veteran_threshold, is_veteran, veteran_bonus; порог F4 в campaign.json → veteran; инкремент в _request_battle после потерь; применение +1 в бою — T-116, MVP-бой 1v1 авто — за срезом).
- [x] 3.2 Снабжение (R7, Q-M75→(б)): ёмкость 10 еды, расход 1/персонаж/переход (переходы — region-graph-map); полный >50% → +2 к первому спасу; голод → −2 к атакам (P-4) (`supply_system.gd`, сейв-под-ключ `campaign.supply`; примирение с плейсхолдер-едой RegionMap — Q-M91).
- [ ] 3.3 Сейв: поля `wounded`/`veteran_count`/`food` в `state.party` (MvpSaveSchema, миграция fail-fast).

## 4. Верификация

- [x] 4.1 GdUnit4: пороги уровней (2699/2700), ASI-кап 16, Удача вне ASI. *(Верифицировано: test_party_system.gd — test_level_thresholds_srd_canon (2699→ур.1, 2700→ур.2), test_asi_apply_and_cap (потолок 16), test_asi_rejects_invalid (Удача — не объект ASI).)*
- [ ] 4.2 GdUnit4: wipe → defeat; смерть героя → «утрата» (−2 к спасам страха/очарования), кампания продолжается.
- [~] 4.3 GdUnit4: REST (лечение по формуле), голод (−2 к атакам), ветеран (+1 ступень, до конца боя). Голод — готов (`test_supply_system.gd: test_hunger_penalty`); ветеран — готов (`test_veteran.gd`); REST — ждёт 2.2.
- [ ] 4.4 GdUnit4: район создан → 0 XP (K-M16).
