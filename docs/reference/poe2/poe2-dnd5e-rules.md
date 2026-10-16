---
title: D&D 5e: правила создания персонажа (справка PoE2-вики)
tags:
  - reference
  - poe2
status: reference
date: 2026-10-16
---

> [warning] Референс — не канон Sigil
> Это справка по *D&D 5e* внутри PoE2-вики — point-buy и шаги создания.
>
> **Источник:** `PoE2-Character-Creation/00-Meta/DnD 5e Character Creation Rules.md` концепт-вольта `/Users/user/sigil-of-the-unwilling-doc` (внешний каталог, не в git).
> **Получено:** 2026-10-16. **Сверка:** вики-данные, не сверялось; point-buy в каноне Sigil отсутствует (K3).
> **Статус:** справочник. Числа отсюда не переносятся в [[07-balance]] и баланс-конфиги
> иначе как решение владельца; расхождения с каноном — [[CONFLICTS]].


# D&D 5e — Правила создания персонажа

> [!info] Источник
> Спарсено с [dndbeyond.com/species](https://www.dndbeyond.com/species).
> Включает правила PHB 2024 (актуальные) + упоминание legacy-версий.
> Эта страница — справочник для сравнения с [[poe2-creation-flow]] из PoE2.

## 📋 7 шагов создания

1. **Species** (раса)
2. **Class** (12 классов + подклассы с 3 уровня)
3. **Ability Scores** (6 характеристик)
4. **Background** (предыстория — даёт атрибуты + skill + tool)
5. **Equipment** (стартовое снаряжение)
6. **Alignment** (мировоззрение, опционально в 2024)
7. **Personal Details** (имя, внешность)

---

## 🧬 Species (Player's Handbook 2024)

> [!warning] Ключевое отличие от PoE2
> В 2024 расовые бонусы к атрибутам **не фиксированы** — игрок свободно распределяет **+2/+1** или **+1/+1/+1** между любыми характеристиками.
> Трейты вида (Darkvision, Flight, Natural Weapon и т.д.) остаются закреплёнными.

### Основные 10 видов PHB 2024

| Species | Ключевые трейты |
|---------|-----------------|
| **Aasimar** | Celestial Resistance, Darkvision, Healing Hands, Light Bearer, Celestial Revelation |
| **Dragonborn** | Draconic Ancestry, Breath Weapon, Damage Resistance, Darkvision, Draconic Flight (поздний уровень) |
| **Dwarf** | Darkvision, Dwarven Resilience (poison resist), Dwarven Toughness (+HP), Stonecunning |
| **Elf** | Darkvision, Elven Lineage, Fey Ancestry (charm resistance), Keen Senses, Trance |
| **Gnome** | Darkvision, Gnomish Cunning (advantage on INT/WIS/CHA saves vs magic), Gnomish Lineage |
| **Goliath** | Giant Ancestry (выбор предка-гиганта), Large Form (поздний), Powerful Build |
| **Halfling** | Brave (advantage vs frightened), Halfling Nimbleness, Lucky (перебросить 1), Naturally Stealthy |
| **Human** | Resourceful (Heroic Inspiration при long rest), Skillful (1 skill), Versatile (1 Origin feat) |
| **Orc** | Adrenaline Rush (Dash + temp HP), Darkvision, Relentless Endurance (1/long rest: не упасть в 0 HP) |
| **Tiefling** | Darkvision, Fiendish Legacy (3 варианта), Otherworldly Presence |

### Расширенные виды (legacy, ~70+)
Aarakocra, Bugbear, Centaur, Changeling, Dhampir, Fairy, Firbolg, Genasi, Githyanki, Githzerai, Goblin, Hobgoblin, Harengon, Kenku, Kobold, Leonin, Lizardfolk, Minotaur, Satyr, Shadar-kai, Shifter, Tabaxi, Tortle, Triton, Warforged, Yuan-ti и др.

---

## ⚔️ 12 классов

| Класс | Primary Ability | Hit Die | Источник магии |
|-------|----------------|---------|----------------|
| **Artificer** (новый в 2024) | INT | d8 | Arcane (items) |
| **Barbarian** | STR | d12 | Rage (ресурс) |
| **Bard** | CHA | d8 | Bardic Inspiration |
| **Cleric** | WIS | d8 | Divine (spell slots) |
| **Druid** | WIS | d8 | Primal (spell slots + Wild Shape) |
| **Fighter** | STR/DEX | d10 | — |
| **Monk** | DEX + WIS | d8 | Ki (Focus Points) |
| **Paladin** | STR + CHA | d10 | Divine Smite + slots |
| **Ranger** | DEX + WIS | d10 | Primal (slots) |
| **Rogue** | DEX | d8 | Sneak Attack |
| **Sorcerer** | CHA | d6 | Innate (Sorcery Points) |
| **Warlock** | CHA | d8 | Pact Magic (slots на short rest) |
| **Wizard** | INT | d6 | Arcane (slots + Arcane Recovery) |

> [!info] Подклассы
> Выбираются на 3 уровне (в отличие от PoE2, где сразу).

---

## 📊 Ability Scores

### 6 характеристик

| Характеристика | Влияние |
|----------------|---------|
| **Strength (STR)** | Ближний бой, Athletics, carry capacity |
| **Dexterity (DEX)** | Дальний бой, AC, Initiative, Stealth, Acrobatics |
| **Constitution (CON)** | HP, Concentration checks |
| **Intelligence (INT)** | Arcana, History, Investigation, Nature, Religion |
| **Wisdom (WIS)** | Animal Handling, Insight, Medicine, Perception, Survival |
| **Charisma (CHA)** | Deception, Intimidation, Performance, Persuasion |

### 3 метода генерации

**1. Standard Array**
```
15, 14, 13, 12, 10, 8
```

**2. Point Buy (27 очков)**
| Значение | Стоимость |
|----------|-----------|
| 8 | 0 (база) |
| 9–13 | 1 очко за пункт |
| 14–15 | 2 очка за пункт |
| Макс до расовых: 15 | |

**3. Rolling (4d6 drop lowest × 6)**
Бросаешь 4d6, убираешь минимальный, суммируешь оставшиеся 3. Повторяешь 6 раз.

### Модификаторы

$$\text{modifier} = \left\lfloor \frac{\text{score} - 10}{2} \right\rfloor$$

| Score | Mod | Score | Mod |
|-------|-----|-------|-----|
| 8–9 | −1 | 16–17 | +3 |
| 10–11 | 0 | 18–19 | +4 |
| 12–13 | +1 | 20–21 | +5 |
| 14–15 | +2 | 22–23 | +6 |

> [!info] Background в 2024
> Предыстория теперь даёт **+2/+1 или +1/+1/+1 к атрибутам** (по выбору игрока) + 1 skill + 1 tool.
> Раса + Background + класс = три источника бонусов к статам.

---

## 🎓 Backgrounds (примеры)

| Background | Skill | Tool |
|------------|-------|------|
| Acolyte | Insight, Religion | — |
| Criminal | Deception, Stealth | Thieves' tools |
| Folk Hero | Animal Handling, Survival | Vehicle (land) |
| Noble | History, Persuasion | Gaming set |
| Sage | Arcana, History | — |
| Soldier | Athletics, Intimidation | Gaming set |

---

## 🔑 Ключевые механики

### Spellcasting
- **Spell slots** (Vancian system) — ограниченные применения заклинаний в день
- Восстановление: **Long Rest** (8 ч) или **Short Rest** (1 ч, часть классов)
- Warlock — уникален: слоты восстанавливаются на short rest

### Proficiency Bonus
- Старт: **+2** на 1 уровне
- Растёт каждые 4 уровня: +3 (5), +4 (9), +5 (13), +6 (17)
- Применяется ко всем атакам, спасам, skill checks, в которых персонаж proficient

### Inspiration (2024)
- Ресурс героя; тратьте для advantage на d20
- Human (PHB 2024) получает 1 при long rest; DM выдаёт за хороший RP

### Feats
- В 2024: **Origin Feat** на 1 уровне (от background или вида)
- Далее: обычные feats на 4, 8, 12, 16, 19 уровнях (вместо ASI)

---

## 🔗 Связанные страницы

- [[poe2-vs-dnd]] • [[poe2-creation-flow]]
