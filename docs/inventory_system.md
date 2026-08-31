# Система инвентаря

Инвентарь героя — это экипировка по слотам + рюкзак, и отдельная «математика»
экипировки (AC, урон, криты) по модели NWN2 / D&D 3.5.

**Корневые классы:**
- `entities/HeroInventory.gd` (`class_name HeroInventory`, `extends RefCounted`) — состояние инвентаря.
- `systems/EquipmentManager.gd` (`class_name EquipmentManager`, `extends RefCounted`) — расчёт боевых характеристик экипировки.
- `data/Artifact.gd` + `data/ArtifactRegistry.gd` — профили предметов и реестр.

Инвентарь не наследуется от `Node` — это `RefCounted`, поэтому он полностью
тестируем без сцены. Фасад `HeroController` держит `HeroInventory` и пробрасывает
вызовы/сигналы в UI.

## 1. Состояние: `HeroInventory`

**Структура:**
- `equipped: Dictionary` — карта `Artifact.Slot -> Artifact`. Слоты создаются
  пустыми при `_init()` (кроме `SPELLBOOK`, он не используется в экипировке).
- `backpack: Array[Artifact]` — рюкзак, размер ограничен `GameSettings.MAX_BACKPACK_SIZE`.

**Слоты** (`Artifact.Slot`): `HEAD, NECK, TORSO, WEAPON, SHIELD, LEGS, BOOTS,
RING_L, RING_R, MISC_A, MISC_B, SPELLBOOK`.

**Сигналы:** `equipped_changed`, `backpack_changed`, `modifiers_changed` —
эмитятся после любой мутации, чтобы UI (например `ArtifactInventoryScreen`)
перерисовался.

### Основные операции

| Метод | Поведение |
| --- | --- |
| `equip(artifact, target_slot=RING_L) -> bool` | Надевает предмет. Кольцо → выбирает свободный слот кольца (или `target_slot`). Двуручное оружие на слоте `WEAPON` снимает щит в рюкзак. Старый предмет из слота падает в рюкзак. Возвращает `false`, если нельзя (рюкзак полон, невалидный слот, дубликат). |
| `can_equip(artifact) -> bool` | Общая проверка: слот, двуручность+щит, уникальность. |
| `can_equip_to_slot(artifact, slot) -> bool` | Проверка именно для целевого слота. |
| `unequip(slot) -> Artifact` | Снимает в рюкзак (если есть место). |
| `add_to_backpack(artifact) -> bool` |кладёт в рюкзак, без дубликатов. |
| `remove_from_backpack(idx) -> Artifact` | Убирает из рюкзака. |
| `sell_artifact(idx) -> int` | Продает, возвращает `value_gold * 0.5`. |
| `get_total_modifiers() -> Dictionary` | Сумма всех модификаторов надетого: attack/defense/spell_power/knowledge/luck/morale/movement/stack_hp(+%)/stack_speed/daily_gems/castle_growth. |
| `has_special_effect(effect) -> bool` | Есть ли надетый предмет с `special_effect`. |

### Правила уникальности

Нельзя носить два одинаковых предмета (`artifact.id`) одновременно — ни в
экипировке, ни в рюкзаке. Кольца исключены из проверки на дубликат (их два
слота).

### Сериализация

`serialize() -> Dictionary` / `deserialize(Dictionary)` хранят только **id**
предметов:

```json
{"equipped": {"3": "greatsword_might", "2": ""}, "backpack": ["ring_giant"]}
```

`deserialize` терпит ключи слотов как `int` (наш формат), так и `String`
(внешние сохранения), резолвит id через `ArtifactRegistry`
(`ServiceLocator.resolve(..., "artifacts")`). Пустая строка = свободный слот.

## 2. Оценка экипировки: `EquipmentManager`

Реализует три «математических» столпа модели боя NWN2 + профиденцию оружия
по D&D 3.5. Работает с картой `equipped` (`Slot -> Artifact`), поэтому
переиспользуется и в инвентаре героя, и в бое.

### 2.1 Класс брони (AC) — стаки бонусов

`compute_ac(equipped, dex_mod) -> Dictionary` (база 10 + DEX + бонусы):

| Источник | Слоты | Правило стека |
| --- | --- | --- |
| Armor | HEAD/TORSO/LEGS/BOOTS | Суммируется, но DEX резается самым тесным `max_dex_bonus`. |
| Shield | SHIELD | Один слот, `base_ac`. |
| Natural | NECK | Применяется наивыший из всех. |
| Deflection | RING_L/RING_R | Наивыший из всех (два +1 = +1). |
| Dodge | сапоги | Суммируется аддитивно. |

`base_ac` у доспехов — вклад брони (`ac_bonus_type = NONE`); у аксессуаров
`base_ac` — сам бонус. `has_armor()` = `true` только у настоящих доспехов
(`base_ac > 0`), поэтому додж-амулеты не считаются бронёй.

### 2.2 Атака / оружие

`evaluate_attack(equipped, proficiencies, str_mod, dex_mod) -> Dictionary`:

- Не владеет оружием → штраф **−4** (D&D 3.5).
- Ближний бой: `attack = weapon + prof + STR`.
- Дальний бой: `attack = weapon + prof + DEX` (STR не применяется).

Возвращает также `damage_dice`, `damage_types`, `crit_threat`,
`crit_multiplier`, `is_ranged`, `is_two_handed`, `proficient`.

`roll_attack(d20, crit_threat)` — крит, если `d20 >= crit_threat`
(напр. 19 для 19–20).

### 2.3 Урон, DR, иммунитет

`apply_damage(damage, dt, options) -> Dictionary`:

- **Имунитет** к типу урона → 0.
- **DR** (ключи на русском: «Рубящий»/«Колющий»/«Дробящий») вычитается.
- DR обходится: магией (`is_magic`) или материалом оружия
  (`adamantine`, `silver`, `cold_iron` и т.д.).

## 3. Предметы: `Artifact`

Профиль предмета (`data/Artifact.gd`) содержит: `id`, `display_name`, `slot`,
`rarity` (`MINOR/MAJOR/RELIC`), модификаторы, `is_two_handed`, `is_ranged`,
`proficiency`, профили `combat` / `armor` / `ac_bonus_type`, `damage_types`,
`crit_threat/multiplier`, `value_gold`, `special_effect`.

Реестр `ArtifactRegistry` (заполнены оружие, броня, аксессуары; ~54 единицы)
обеспечивает `get_by_id()` и рандом.

## 4. UI

- `ui/ArtifactInventoryScreen.gd` — экран инвентаря/артефактов (экипировка,
  сортировка, продажа).
- `ui/ArtifactChestDialog.gd` — диалот сундука с артефактами.
- `ui/HeroModelFactory.gd` — собирает «модель» героя (статы/экипировка) для
  модельных экранов (стартовое меню и др.), используя `get_total_modifiers()`.

## 5. Тесты

`game/tests/test_artifact_system.gd` покрывает: статы/редкость/слоты артефактов,
реестр (~54, уникальные id, `get_by_id`), сам инвентарь (экипировка/снятие,
лимит рюкзака, без дубликатов, двуручность снимает щит, продажа, special-эффекты,
сериализация) и оценку оборудования (AC=28 для тяжёлого танка, стек deflection,
DR/иммунитет/магия, крит 19–20, владение, дальний бой на DEX).
