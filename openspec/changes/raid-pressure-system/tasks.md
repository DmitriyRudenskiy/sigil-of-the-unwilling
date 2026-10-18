# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 Функция давления (Base=4.0, Wealth, аномалия=1.0, рост, фазы) — `threat_system.gd` (K-R3)
- [x] 1.2 SM рейда (IDLE→CHARGING→INBOUND→STRIKE→RESOLVED→COOLDOWN) — `threat_system.gd`
- [x] 1.3 Тиры (пороги 30/100/250, power 15/30/60) — `raids.json` (K-T5, R6)
- [x] 1.4 Defense (барраки 0.2) — `threat_system.gd` (R6)
- [x] 1.5 Директивы 7/21 (K-M9/K-R3, BIT_TURNS) — `turn_driver.gd`
- [x] 1.6 Зима (enemy_mult 1.25, production_mult 0.4) — `world_seasons.gd`, `threat_system.gd` (Q-M27/Q-M29)
- [x] 1.7 Цель (score, видимость = константа 1, тай-брейк id) — `threat_system.gd` (I1, Q-M54→(в))

## 2. Разрывы

- [x] 2.1 Per-ресурсные капы (T-127): еда ≤40%, железо/оружие ≤30% за рейд (в пределах хода) — `threat_system.gd` (замена единого `loss_cap_fraction = 0.3`). *(Сделано: `loss_caps` {food 0.4, wood/iron 0.3} в raids.json + `loss_cap_for(resource)`; дефолт для неизвестного ресурса = `loss_cap_per_day`. Кап per-рейд. 3 теста.)*
- [x] 2.2 Cooldown ×2 при «все районы разрушены» (город выживает: производство −50%, частота −50%). *(Сделано: `effective_cooldown(all_ruined)` = cooldown_turns×2; флаг `all_districts_destroyed` в threat-context (composition: все 7 групп без зданий). «Город выживает» гарантировано (defeat = только wipe партии / все запасы ≤0). «Production −50%» — при нуле зданий производство уже 0; явный −50% к базовому производству — за срезом (нет базового производства вне зданий в MVP). 2 теста.)*
- [~] 2.3 EC: рейд по зданию на ремонте → ×0.5 к RUINED; рейд по клетке героя → бой, победа → −50% последствий. *(Сделано: часть 2 — рейд по клетке героя → бой, победа → −50% последствий. `_request_battle` возвращает исход ("win"/"lose"/"draw"); `_resolve_raid`: бой до урона, `battle_won` → loss×0.5. Отложено: часть 1 — рейд по зданию на ремонте → ×0.5 к RUINED (building-level targeting; сейчас рейды бьют по ресурсам, не по зданиям/клеткам — за срезом MVP). 1 тест.)*
- [x] 2.4 Герой в городе → бой (CR 1/2/6); герой в походе → авто-рейд (defense = здания 13.3) — проверить/добавить в `threat_system.gd`. *(Верифицировано: уже реализовано — `_resolve_raid`: hero → `battle_requested=true` + battle_handler (CR по фазам, шов T-050); hero=false → авто-рейд (R5, только loss). defense = `defense_barracks` (0.2) при казарме, иначе 0 (R6; стены/прочие здания — Post-MVP). Тест: `test_hero_in_city_battle_request`.)*

## 3. Синк (C-5, C-17)

- [ ] 3.1 C-5: пометить инертные ключи `raids.json` (`visibility_formula`/`target_score`/`target_weights`) как «1.0, не читается» или реализовать.
- [ ] 3.2 C-17: синк формулы цели (документ «случайный из 3 ресурсов (веса 0.5/0.3/0.2)» vs код score = 0.5×видимость + 0.3×уязвимость).

## 4. Верификация

- [ ] 4.1 GdUnit4: давление (Wealth clamp, фазы, рост после cooldown).
- [ ] 4.2 GdUnit4: тиры (пороги 30/100/250; power 15/30/60; defense барраки 0.2).
- [x] 4.3 GdUnit4: per-ресурсные капы (еда ≤40%, железо/оружие ≤30%). *(test_threat_system: test_per_resource_caps, test_per_resource_cap_food_vs_iron, test_cap_only_when_loss_exceeds.)*
- [ ] 4.4 GdUnit4: директивы (первый ≈ ход 7; финальный к ходу 21; floor не ломается).
- [x] 4.5 GdUnit4: AFK-каскад (капы per-рейд; все районы разрушены → город выживает). *(test_threat_system: test_afk_cascade_no_chain_collapse — 10 рейдов tier 3 подряд, запасы не уходят в минус (кап per-рейд); + cooldown ×2 из 2.2.)*
- [ ] 4.6 GdUnit4: зима (enemy_mult 1.25; production_mult 0.4).
