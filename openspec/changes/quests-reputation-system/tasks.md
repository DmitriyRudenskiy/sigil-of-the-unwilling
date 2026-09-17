# Tasks: quests-reputation-system

## 1. Фракции и репутация

- [x] 1.1 `scripts/data/hero_factions.gd` — 6 фракций (по расам: human, elf, dwarf, aumaua, orlan, godlike) с name/desc
- [x] 1.2 `scripts/systems/FactionReputation.gd` — шкала −100..+100, 5 уровней (Враг/Недруг/Нейтрал/Друг/Союзник), `band()`, `band_name()`, `price_multiplier()`, `can_hire()`, `apply(state, faction, delta)` с расовым бонусом +10% (родная фракция) и классовым бонусом, `initial_state(race, class_id)` (+10 родная раса), история изменений (последние 20)
- [x] 1.3 Unit-тесты `tests/unit/systems/test_faction_reputation.gd`: уровни, модификаторы цен, расовый/классовый бонусы, clamp ±100, история

## 2. Система квестов

- [ ] 2.1 `scripts/data/quest_templates.gd` — шаблоны 4 типов (kill, gather, deliver, escort), сложность по кольцу (1–3), награды (опыт, золото, репутация)
- [ ] 2.2 `scripts/systems/QuestSystem.gd` — генерация процедурных квестов (без дублей активных), отслеживание прогресса (kill/gather/deliver/escort), награды при завершении, провал (таймер, гибель NPC эскорта), цепочки (`next_quest_id`), журнал (active/completed/failed)
- [ ] 2.3 Unit-тесты `tests/unit/systems/test_quest_system.gd`: генерация по кольцу, прогресс kill/gather, награды + репутация, провал по таймеру, цепочка, уникальность

## 3. Интеграция и сохранение

- [ ] 3.1 Интеграция в `WorldPersistence.gd`: сохранение/загрузка состояния квестов и репутации
- [ ] 3.2 Начальная репутация при создании героя (раса +10)

## 4. UI

- [ ] 4.1 `scripts/ui/QuestJournalScreen.gd` — журнал: активные (прогресс), завершённые, проваленные; "Сдать квест" при выполнении
- [ ] 4.2 `scripts/ui/FactionScreen.gd` — 6 фракций: значение, уровень, модификаторы, история изменений

## 5. Валидация

- [ ] 5.1 Полный GdUnit4 run: все тесты зелёные
- [ ] 5.2 MCP-регрессия: 27 passed
