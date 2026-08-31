# Задачи: Социальная составляющая + Система размещения построек

> Нарезка анализа из `docs/CONCEPT_SOCIAL_RACES.md` (расы, Against the Storm)
> и `docs/CONCEPT_BUILDING_SYNERGY.md` (взаимосвязи построек, TerraScape)
> в исполняемые задачи для Godot 4.7. Связка с существующими слоями:
> `scripts/demographics/`, `scripts/economy/`, `scripts/data/BuildingDefs.gd`, `scripts/world/Borough`, `scripts/world/City`.

---

## 🟢 Фаза 0. Каркас данных (Custom Resources)

- [ ] **0.1 `NeedType` enum + `Needs` container.**
  Ввести перечесление потребностей: shelter, housing, food(complex), clothing,
  services(religion/education/recreation/luxury/healing/brawling). Хранилище
  совокупных потребностей жителя (аналог Resolve 0–50).
- [ ] **0.2 `RacialTrait` Resource.**
  Поля: `proficiency` (эффективность), `comfort` (комфорт), `resilience`
  (×0.25 у Ящеров), `decadence` (×2.0 у Ящеров, ×0.25 у гарпий), `start_bonus`,
  `firekeeper_bonus`, `cannot_favor` (баты), `comfort_group_min` (лисы=3).
- [ ] **0.3 Реестр рас `RaceRegistry.gd`.**
  7 рас: humans, beavers, lizards, harpies, foxes, frogs, bats. Мапа
  `racial_bonus -> BuildingData.id` (какое здание даёт комфорт/эффективность расе).
- [ ] **0.4 Миграция существующей модели потребностей.**
  Текущее состояние: `Character.NEED_KEYS = [hunger, rest, social, belief]`
  (шкала 0–1, критик < 0.2), `DemographicTurnProcessor.DECAY`, сериализация
  в SaveData. Маппинг на новый набор: `hunger -> food`, `rest -> shelter`,
  `social -> services`, `belief -> services(religion)`. Шкала 0–1 сохраняется
  (слой насыщения потребностей); Resolve 0–50 — отдельная новая скалярная
  величина (см. 1.1), не замена шкале. Миграция сейвов: при загрузке старые
  ключи переводятся, новые потребности стартуют со значения 0.8.

## 🟰 Фаза 1. Социальная механика (Demographics)

- [ ] **1.1 Resolve-петля в `DemographicTurnProcessor`.**
  Ежедневная дельта: `sum(need_satisfied ? +x : -y) + trait.modifier_for(type)`.
  При Resolve ≤ 0 → ж покидает/умирает.
- [ ] **1.2 Порог репутации (Threshold).**
  Репутация начисляется только от жителей с Resolve > threshold.
  (`HeroController`/`DemographicTurnProcessor` → `EconomicTurnProcessor`).
- [ ] **1.3 Проверка потребностей.**
  `needs.check(need) -> bool` на основе назначенных зданий и доступности
  товаров (еда/одежда по расе). Блокировка доступа (Consumption Control).
  Расовые исключения: Лягушки не требуют базовый кров (только расовые дома),
  Баты не участвуют в благосклонности (`cannot_favor`).
- [ ] **1.4 Благосклонность (Favoring).**
  Кнопка расы: +5 Resolve, +Impatience (→ Hostility). Для bats — недоступна.
- [ ] **1.5 Механика «Преданность» (bats).**
  +1 Resolve за 2 смерти/ухода других рас; сгорает при смерти летучей мыши.
- [ ] **1.6 Хранители Огня (Firekeepers).**
  Модификаторы в глобальном контексте поселения (−20% топлива у бобра,
  +1 Resolve у ящера и т.д.).

## 🏗️ Фаза 2. Система размещения и скорнинга (World/Buildings)

- [ ] **2.1 `BuildingData` → ресурс с `input_radius`, `biome_bonus`,
  `adjacency_rules`, `merge_recipes`.**
  Перевести `scripts/data/BuildingDefs.gd` на модель с правилами соседства (вместо
  только `production_chain`/`default_upkeep`).
- [ ] **2.2 `GridManager` (автозагрузка).**
  Хранит `placed: Dictionary[Vector2i -> BuildingData]`. Метод
  `get_neighbors_in_radius(pos, radius)` — гексовое соседство через
  `scripts/core/HexUtils.gd` (сетка проекта — гексы; квадратная/чебышевская модель
  TerraScape не переносится как есть).
- [ ] **2.3 `ScoringManager.calculate_score(building) -> int`.**
  base_score + biome_bonus(тайл) + sum(adjacency_rules по соседям в радиусе).
  Пересчитывает само здание **и** всех соседей в его радиусе (обратное влияние).
- [ ] **2.4 Визуализация радиуса.**
  При прицеливании подсветка тайлов в `input_radius`; цвет: зелёный (бафф),
  красный (штраф, напр. −120 за соседнюю библиотеку).
- [ ] **2.5 Правило «один тип — один штраф».**
  Самоштрафы за соседство с таким же типом (библиотека −120, кузнец −80…).
- [ ] **2.6 Иерархия «Ресурс → Переработка → Город».**
  Поле `tier: enum { RESOURCE, PROCESSING, CITY }` в данных здания; в
  скоринге здание получает бонус от здания предыдущего тира в своём радиусе
  (Рудник → Кузница → Таверна) — третий уровень цепочки TerraScape.

## 🔗 Фаза 3. Слияние (Merging)

- [ ] **3.1 `MergeSystem.try_merge(pos, new_id) -> bool`.**
  Проверка рецепта (`adjacency`-компоненты в конфигурации 2×2/линейно).
  Удаление компонентов → спавн merged-здания (University, Citadel, City District…).
- [ ] **3.2 Merged-здания как хабы баффов.**
  Массивные здания (6 гексов) дают баффы окружению; пересчёт у соседей.
- [ ] **3.3 VFX/анимация слияния + обновление `GridManager`.**

## 🧬 Фаза 4. Интеграция рас с зданиями

- [ ] **4.1 Расовая эффективность/комфорт в скоринге.**
  Назначение жителя в здание: `proficiency` → ×2 шанс эффекта, `comfort` → +5 Resolve.
  Для лис: +5, если в здании ≥3 представителя расы.
- [ ] **4.2 Расовые здания.**
  Эксклюзивные здания (butcher, apothecary, druid's hut…) доступны только
  при наличии расы на карте; дроп в пуле наград/руинах.
- [ ] **4.3 Стартовые бонусы рас.**
  (плодородная почва, гейзер дождя, руины, инструменты, +50 пальто и т.п.)

## ✅ Критерии приемки (Definition of Done)

- [ ] Жителя можно назначить в здание; Resolve меняется по ежедневной петле.
- [ ] Расовое здание в эффективности/комфорте даёт заявленный бонус (+5 Resolve).
- [ ] Размещение «библиотеки» рядом с «школой» повышает её рейтинг (+35).
- [ ] Две «библиотеки» в радиусе 4 получают −120.
- [ ] Размещение на тайле Urban → +25 (библиотека).
- [ ] Слияние Школа+Библиотека → Университет (удаление компонентов, спавн).
- [ ] Bats нельзя фаворить; преданность сгорает при смерти летучей мыши.
- [ ] Код типизирован, баланс — через `@export`/ресурсы, без хардкода в логике.

> Зависимости: `docs/CONCEPT_SOCIAL_RACES.md`, `docs/CONCEPT_BUILDING_SYNERGY.md`,
> `scripts/data/BuildingDefs.gd`, `scripts/demographics/`, `scripts/economy/`, `scripts/world/Borough.gd`.
