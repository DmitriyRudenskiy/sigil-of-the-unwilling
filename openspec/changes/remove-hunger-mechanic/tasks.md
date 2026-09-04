# Tasks: remove-hunger-mechanic

## 1. Ядро: набор потребностей

- [x] 1.1 `Character.gd`: `NEED_KEYS = [&"rest", &"social", &"inspiration"]`
- [x] 1.2 `HeroNeeds.gd`: убрать `&"hunger"` из `DECAY`, ветку `&"hunger"` (включая `city.starving`) из `_recovery`, `&"starvation"` из `_death_cause`; обновить док-коммент (3 потребности)
- [x] 1.3 `DemographicTurnProcessor.gd`: то же — `DECAY`, `_recovery` (ветка `&"hunger"`/`starving`), `_death_cause` (`&"starvation"`); обновить док-комменты фазы

## 2. Черты

- [x] 2.1 `TraitRegistry.gd`: удалить `hardy`, `appetite`, `iron_stomach`; `gorgon_taste` → `{&"social": 0.10}` (текст про общение, тег `"food"` сохранить)
- [x] 2.2 `TraitDef.gd`: док-коммент — перечислить актуальные need-ключи

## 3. UI и события

- [x] 3.1 `HeroStatusPanel.gd`: убрать `&"hunger": "🍞"` из `_NEED_ICONS`, «четыре потребности» → «три» в доке
- [x] 3.2 `DeathSequence.gd`: убрать `&"starvation": "от голода"`
- [x] 3.3 `GameEventBus.gd`: перечисление причин смерти в комменте — убрать `"starvation"`, добавить `"burnout"`
- [x] 3.4 `HeroController.gd`: док-коммент про потребности без hunger

## 4. Тесты (GUT)

- [x] 4.1 `test_characters.gd`: NEED_KEYS-ассерты, clamp по `&"hunger"` → заменить на актуальный ключ, serialize/deserialize (старый ключ `"hunger"` игнорируется)
- [x] 4.2 `test_hero_survival.gd`: убрать hunger-ассерты, пересчитать city-recovery без hunger (hunger-строки из ожиданий удалить; starvation-тест → на актуальную причину смерти)
- [x] 4.3 `test_demographic_processor.gd`: распад/восстановление без hunger, смерть без starvation
- [x] 4.4 `test_trait_registry.gd`: состав черт 15 (5/3/3/4 по редкостям; исходно 18 — 3 food-черты удалены), `gorgon_taste` → social
- [x] 4.5 Прогнать `run_tests.gd` — весь GUT-набор зелёный

## 5. Сценарии

- [x] 5.1 `scenario_lib.py`: комменты `keep_alive` без hunger (логика не меняется — проверить, что `min(needs)` работает с 3 ключами)
- [ ] 5.2 Прогнать `play_scenario.sh 1` и `play_scenario.sh 4` — PASS

## 6. Документация

- [ ] 6.1 `docs/economy/economy_runtime.md` §7: распад/восстановление/причины смертей без голода (+ belief→inspiration в тексте секции)
- [ ] 6.2 `docs/systems/city_system.md`: роль еды — экономическая (склад/рождения/approval/рынок); «штраф за голод» → «штраф за нехватку еды (`starving`)»
- [ ] 6.3 `docs/concepts/TASK_SOCIAL_AND_BUILDINGS.md` + `docs/concepts/CONCEPT_SOCIAL_RACES.md`: точечные правки упоминаний голода (NEED_KEYS, лисы)
- [ ] 6.4 Прочитать `docs/concepts/CONCEPT_CHARACTER_SYSTEM.md` и `AGENT.md` — при наличии упоминаний голода/сытости поправить

## 7. Финальная проверка

- [ ] 7.1 `run_all_ci_checks.sh --fast` (компиляция + валидация)
- [ ] 7.2 `run_all_ci_checks.sh` (полный: GUT + console-clean + сценарии 1–5)
