# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 Лестница зон (Триумф/Успех/Частичный/Провал/Критпровал) — `campaign_battle.gd` (_strike, _step_down), `battle_rules.gd`
- [x] 1.2 Death saves: mod CON, 3/3 (T-050 AC) — `campaign_battle.gd` (_death_saves, DEATH_SAVES_NEEDED)
- [x] 1.3 Лимит боя 20 раундов → ничья (D-128) — `campaign_battle.gd` (MAX_ROUNDS)
- [x] 1.4 Инициатива mod DEX, тай-брейк CON, id — `campaign_battle.gd` (initiative_first)
- [x] 1.5 «Судьба следит» (FATE_PENALTY_DIVISOR = 1.25, interim до Ф3) — `campaign_battle.gd`
- [x] 1.6 Детерминизм разрешения (без RNG) — `campaign_battle.gd` (resolve)

## 2. Авто-режим и AI

- [~] 2.1 Авто-режим: детерминированный AI (мин. HP в радиусе, тай-брейк меньший id); отступление при «frightened»; тот же движок, один отчёт. *(Скелет готов: `select_target` (min HP, тай-брейк меньший id) + `resolve_multi` (N vs M, тот же движок `_strike`/`_death_saves`) + отступление при «frightened» (outcome retreat/win). 10 тестов (test_battle_auto_ai.gd), GdUnit 2682/0. НЕ подключено к кампании (там пока 1v1 `resolve`) — интеграция = следующий шаг.)*
- [ ] 2.2 AI врага (Y3): greedy; босс хода 21 (CR 6–8): greedy + способность при HP партии < 50% (детерминированная, параметры — баланс-конфиг Ф4).
- [x] 2.3 Отчёт боя (REPORT): один для обоих режимов; ничья (20 раундов) — потери, без XP/Престижа. *(Отчёт в `resolve_multi` (outcome/rounds/trace/losses/battle_over); «один для обоих режимов» тривиально в MVP (только авто-режим); ничья 20 раундов → потери [], без XP/Престижа. Тесты: test_resolve_multi_report_structure, test_resolve_multi_draw_20_rounds_no_xp_prestige.)*

## 3. Состояния, местность, бином

- [x] 3.1 Состояния: prone (−2/+2), высотный статус (полёт, hover; носитель MVP — волшебник) — `campaign_battle.gd`/`battle_rules.gd`. *(_state_margin: prone ±2, elevated ±2; сосуществование. Тесты: test_prone_and_elevated_mask_coexist, test_elevated_defender_penalizes_attacker. «Носитель = волшебник» — data/config (класс не вшит в бой в MVP).)*
- [ ] 3.2 Blink (заклинание из ячеек волшебника, K-M7) — `campaign_battle.gd`.
- [ ] 3.3 Местность 3 типа (болото/шипы/высота, C3) — абстрактные модификаторы ±2 (без hex, C-3).
- [ ] 3.4 Бином «Фланг» (fighter+ranger против одного врага, с хода 1) — единственный бином MVP (02b A.4).

## 4. UI и данные

- [ ] 4.1 Карточка врага M1: AC/HP/удача/способности видны всегда — `battle_ui.gd` (деталь в mvp-ui-flow).
- [ ] 4.2 Удача: пул ОУ = 1+modLuck, Fate Shift (1 ОУ), Save (2 ОУ), долг судьбы (K-R1) — `campaign_battle.gd`.
- [x] 4.3 Сдвиг ±2 (вверх/вниз) — MVP (K-M6); имя «преимущество/неудача» не использовать. *(Верифицировано: `ADVANTAGE_MARGIN = 2` (GameNumbersBattle); `_state_margin` в campaign_battle.gd применяет ±2 (prone/elevated). Каноническое имя — «сдвиг ±2» (K-M6), не «преимущество/неудача».)*

## 5. Верификация

- [x] 5.1 GdUnit4: зоны лестницы (границы: 4−modLuck, 0, −(3+modLuck), −(8+modLuck)); Триумф = ×2, Частичный = ½. *(Верифицировано: test_battle_rules.gd — test_ladder_zone_base_thresholds (границы 4/0/−3/−8), test_ladder_zone_luck_shifts_thresholds (4−modLuck / −(3+modLuck) / −(8+modLuck)), test_calculate_attack_zone_triumph_double_damage (×2), test_calculate_attack_zone_partial_half_damage (½).)*
- [x] 5.2 GdUnit4: death saves (margin_N формула, 3/3); лимит 20 раундов → ничья (без XP). *(margin_N = mod(CON) + supply(N=1) − (N−1), ровно 3 спаса; 3 провала = смерть, 3 успеха = WOUNDED (не погиб), смешанный = стабилизация. Тесты: test_death_saves_margin_n_con1_two_success_one_fail, test_death_saves_margin_n_con2_three_success_wounded, test_death_saves_supply_bonus_rescues_first_save, test_death_saves_supply_bonus_not_enough.)*
- [x] 5.3 GdUnit4: авто-режим (детерминизм, отступление при frightened); 100 повторов → byte-identical. *(test_battle_auto_ai.gd: test_resolve_multi_deterministic, test_resolve_multi_retreat_on_frightened, test_resolve_multi_enemy_frightened_is_win, test_resolve_multi_100_repeats_byte_identical.)*
- [ ] 5.4 GdUnit4: бином «Фланг» (fighter+ranger → бонус); prone (−2/+2); местность (±2).
- [ ] 5.5 GdUnit4: мораль аннулирована (потери = −2 ступени к спасам до конца боя; принуд. отступление при 0 HD).
