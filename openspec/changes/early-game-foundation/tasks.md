# Tasks: early-game-foundation

## 1. Hero Identity (hero-identity)

- [ ] 1.1 `assets/data/hero_classes.json`: 6 классов (base_atk, base_def, base_hp, move_mod, effect-ключ + параметры эффекта)
- [ ] 1.2 `HeroIdentityComponent` (раса + класс, сериализация/десериализация с дефолтами Воин/Human) и `HeroPersonalCombatComponent` (atk/def из расы+класса через маппинг ability_adjustments)
- [ ] 1.3 Подключение компонентов в HeroController + сериализация в WorldStateSerializer
- [ ] 1.4 `HeroArmyController._init_default_army()` → пустая армия (новый флаг/метод, старые тесты обновить)
- [ ] 1.5 Герой-боец в BattleState: особый BattleUnit с флагом `is_hero`, статы из личного боя; инварианты BattleState не сломаны
- [ ] 1.6 Эффекты классов: Воин (статы), Следопыт (+движение, +урон tag animals), Плут (крит), Жрец (лечение в бою), Чародей (стартовый spell), Друид (убегание животных кольца 1)
- [ ] 1.7 Смерть бойца-героя в бою → герой ранен в мире (HP 1), армия сохраняется
- [ ] 1.8 UI выбора героя (MainMenu «New Game» → экран раса×класс) + отображение класса в InfoPanel
- [ ] 1.9 Тесты: identity-сериализация, личный бой, эффекты классов (gdUnit), соло-бой e2e через MCP

## 2. Hero Logistics (hero-logistics)

- [ ] 2.1 `HeroBackpackComponent`: Dictionary {resource_id: amount}, capacity 12, add/remove/total, сериализация
- [ ] 2.2 WorldEventRouter: сбор узла → рюкзак (вместо add_strategic_resource), переполнение = остаток, узел собран, сигнал resource_extracted сохраняется
- [ ] 2.3 Action «выгрузить» в CityScreen (герой в городе → весь рюкзак в city.storage); недоступна вне города
- [ ] 2.4 Расширение провоза: рынок города → покупка (+N к capacity), цена в GameNumbers
- [ ] 2.5 UI рюкзака в AdventureUI (занято/лимит) + попап переполнения
- [ ] 2.6 Тесты: лимит/переполнение, выгрузка, покупка телеги, сейв-совместимость (старый сейв без рюкзака)

## 3. City Tech Tree (city-tech-tree)

- [ ] 3.1 buildings.json: +`min_city_level` у всех 15 зданий, +3 новых (range, library, stables) с `military_chain`
- [ ] 3.2 BuildingDefs: загрузка min_city_level/military_chain; UniqueBuilding.Def: новые поля
- [ ] 3.3 CITY_LEVEL_MAX 11; пороги ProsperitySystem 6–11 (монотонные константы); тесты уровней обновить
- [ ] 3.4 CityBuildingService: гейт по min_city_level (ошибка «нужен уровень N»); UI CityScreen — серые не-доступные здания
- [ ] 3.5 UnitRegistry: `make_recruit_stack(key, tier)`, тиры ×1.0/×1.6/×2.66 (округление вверх), тег magic_weapon у T3; UnitStack.weapon_tier поле + сериализация
- [ ] 3.6 CityService.recruit_military(city, hero, unit_key): герой в городе, здание-источник по цепочке уровня, стоимость из хранилища, army-кап; стек в HeroArmyController
- [ ] 3.7 CityScreen: панель военного найма (доступные по зданиям/тиру, стоимость, кнопка найма)
- [ ] 3.8 Тесты: гейты уровней, цепочки найма, тиры статов, списание ресурсов, армия-кап

## 4. World Threat Rings (world-threat-rings)

- [ ] 4.1 Константы: RING1_RADIUS/RING2_RADIUS, пулы THREAT_ANIMALS/HUMANOIDS/MONSTERS (отобрать по статам), HostilityRate, SeasonLength, множители сезонов
- [ ] 4.2 MapSpawner: тир по hex_distance от стартовой клетки героя вместо randi_range по FACTION_SETS; размер стаи по враждебности
- [ ] 4.3 WorldController: hostility-счётчик (+1 каждые N ходов)
- [ ] 4.4 SeasonSystem: цикл Морось/Ясный/Буря по K ходов; множитель в EconomicTurnProcessor (производство)
- [ ] 4.5 Буря: +1 юнит в вражеские стэки (или refresh существующих); причина видима в UI
- [ ] 4.6 UI: ярлык сезона + hostility (AdventureUI)
- [ ] 4.7 Тесты: кольца генерации (seed-детерминизм), рост стад, смена сезонов, множители производства

## 5. E2E и закрытие

- [ ] 5.1 MCP e2e раннего цикла: новая игра (Воин) → сбор 3 узлов → выгрузка → казарма → найм мечника → бой с волком
- [ ] 5.2 Полный прогон gdUnit (весь набор) + MCP pytest; фикс регрессий
- [ ] 5.3 Документация: README — новый ранний цикл; numbers в GameNumbers с ponytail-комментариями где калибровка
