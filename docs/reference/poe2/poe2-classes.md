---
title: PoE2: классы
tags:
  - reference
  - poe2
status: reference
date: 2026-10-16
---

> [warning] Референс — не канон Sigil
> Это референс *Pillars of Eternity II: Deadfire* — классы.
>
> **Источник:** `PoE2-Character-Creation/02-Classes/Classes Overview.md` концепт-вольта `/Users/user/sigil-of-the-unwilling-doc` (внешний каталог, не в git).
> **Получено:** 2026-10-16. **Сверка:** вики-данные, не сверялось.
> **Статус:** справочник. Числа отсюда не переносятся в [[07-balance]] и баланс-конфиги
> иначе как решение владельца; расхождения с каноном — [[CONFLICTS]].


# Classes Overview — PoE2: Deadfire

11 классов, не ограничены расой и полом. У каждого: **Power Source**, роли, дерево способностей и подклассы.

## 📋 Классы и подклассы

### Barbarian — Rage
- Роли: Crowd Control, Defender
- Подклассы: Berserker • Corpse-Eater • Mage Slayer • Fury Shaper

### Chanter — Phrases
- Роли: Support, Crowd Control
- Подклассы: Beckoner • Skald • Troubadour • Bellower

### Cipher — Focus
- Роли: Crowd Control, Striker
- Подклассы: Ascendant • Beguiler • Soul Blade • Psion

### Druid — Nature
- Роли: Crowd Control, Support, Striker
- Подклассы: Fury • Lifegiver • Shifter • Animist • Ancient

### Fighter — Discipline
- Роли: Defender, Striker
- Подклассы: Black Jacket • Devoted • Unbroken • Tactician

### Monk — Mortification / Wounds
- Роли: Striker, Defender
- Подклассы: Helwalker • Nalpazca • Shattered Pillar • Forbidden Fist

### Paladin — Zeal
- Роли: Support, Defender
- Подклассы: Bleak Walkers • Darcozzi Paladini • Goldpact Knights • Kind Wayfarers • Shieldbearers of St. Elcga • The Steel Garrote

### Priest — Faith
- Роли: Support
- Подклассы (божества): Berath • Eothas • Magran • Skaen • Wael • Woedica

### Ranger — Bond
- Роли: Striker, Defender
- Подклассы: Sharpshooter • Ghost Heart • Stalker • Arcane Archer

### Rogue — Guile
- Роли: Striker
- Подклассы: Assassin • Streetfighter • Trickster • Debonaire

### Wizard — Arcane
- Роли: Crowd Control, Striker
- Подклассы: Conjurer • Enchanter • Evoker • Illusionist • Transmuter • Blood Mage

---

## 📊 Базовые характеристики (ур. 1, все атрибуты 10)

| Класс | Health | Acc | Defl | Fort | Refl | Will |
|-------|--------|-----|------|------|------|------|
| Barbarian | 46 (+16/ур) | 20 | 15 | 30 | 20 | 15 |
| Chanter | 40 (+10/ур) | 20 | 20 | 20 | 20 | 25 |
| Cipher | 38 (+8/ур) | 20 | 20 | 20 | 15 | 30 |
| Druid | 40 (+10/ур) | 20 | 20 | 25 | 25 | 20 |
| Fighter | 42 (+12/ур) | 20 | 25 | 20 | 20 | 15 |
| Monk | 42 (+12/ур) | 20 | 20 | 20 | 25 | 25 |
| Paladin | 42 (+12/ур) | 20 | 20 | 25 | 15 | 25 |
| Priest | 40 (+10/ур) | 20 | 20 | 20 | 20 | 25 |
| Ranger | 42 (+12/ур) | 20 | 20 | 20 | 20 | 20 |
| Rogue | 40 (+10/ур) | 20 | 20 | 15 | 30 | 20 |
| Wizard | 38 (+8/ур) | 20 | 20 | 15 | 20 | 30 |

> [!info] Прогрессия защит
> Каждый уровень: **+3** к Deflection, Reflex, Fortitude и Will — у всех классов, single и multiclass одинаково.

---

## 🔋 Power Source и очки способностей

- Способности тратят очки своего Power Source (Rage, Arcane, Zeal…)
- Очки **восстанавливаются вне боя** — отдых не нужен
- Кастеры: лимит заклинаний **по уровням** за встречу, но без rest-механики
- **Empower** — 1 раз за встречу: усилить способность ИЛИ вернуть 50% очков

### Очки Power Source

| Тип | Старт | Прирост | На 7 уровне |
|-----|-------|---------|-------------|
| Single class | 3 | +1 каждые 2 уровня | 6 |
| Multiclass | 3+3 | +1 в оба каждые 3 уровня | 5+5 = 10 |

### Power Level (тиры способностей)

| Тип | Прирост Power Level | Доступ к 8–9 тиру |
|-----|---------------------|-------------------|
| Single class | каждые 2 уровня | ✅ |
| Multiclass | каждые 3 уровня | ❌ |

---

## 🎓 Навыки классов

- Single class: **+2** в каждый из **5 навыков** класса
- Multiclass: значения двух классов **суммируются и делятся пополам** (2+0 → 1; 0+0 → 0)
- Бонусы культуры/расы/фона добавляются **после** усреднения — не режутся

---

## ⚖️ Мультикласс: пример усреднения (Barbarian + Wizard)

| Параметр | Barbarian | Wizard | Multiclass |
|----------|-----------|--------|------------|
| Base Health | 46 | 38 | 42 |
| Health/ур | +16 | +8 | +12 |

Детали: [[poe2-multiclassing]]

## 🔗 Связанные страницы

- [[poe2-creation-flow]] • [[poe2-skills]] • [[poe2-attributes]] • [[poe2-races]]
