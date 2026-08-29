# Inventory Items — Warrior / Archer / Mage

Список артефактов для наполнения героя полным инвентарём.
Каждый тип оружия/одежды — **3 варианта** (воин / лучник / маг).
Аксесуары — **максимально различны** (по одному, все разные).
Проверка принадлежности к классу на этом этапе **игнорируется**.

## Таблица слотов (Artifact.Slot)

```
HEAD=0  NECK=1  TORSO=2  WEAPON=3  SHIELD=4
LEGS=5  BOOTS=6 RING_L=7  RING_R=8  MISC_A=9  MISC_B=10  SPELLBOOK=11
```

## Оружие и одежда — 3 варианта на тип (18 артефактов)

| Slot | Warrior (воин) | Archer (лучник) | Mage (маг) |
|------|----------------|-----------------|------------|
| WEAPON | greatsword_might — «Warlord's Greatsword» (2H, atk 8) | longbow_hawk — «Hawksey Longbow» (atk 5) | staff_void — «Staff of the Void» (spell 8, atk 1) |
| HEAD | helm_bulwark — «Bulwark Helm» (def 6) | hood_wraith — «Wraith Hood» (def 3, luck 1) | circlet_aurora — «Circlet of Aurora» (spell 5, know 2) |
| TORSO | plate_dread — «Dread Plate» (def 8) | leather_stalker — «Stalker's Leather» (def 4, mov 2) | robes_astronomer — «Astronomer's Robes» (spell 4, know 3) |
| LEGS | greaves_juggernaut — «Juggernaut Greaves» (def 5, hp 20) | wraps_peregrine — «Peregrine Wraps» (def 2, spd 2) | skirt_conjunction — «Skirt of Conjunction» (def 2, spell 3) |
| BOOTS | boots_titan — «Titan's Boots» (def 3, mov 4) | boots_zephyr — «Zephyr Boots» (mov 5, spd 1) | soles_mercury — «Mercury Soles» (mov 3, spd 2) |
| SHIELD | shield_greatwall — «Greatwall Shield» (def 7) | buckler_ripple — «Ripple Buckler» (def 4, luck 1) | ward_arcane — «Arcane Ward» (def 3, spell 2) |

## Аксесуары — максимально различны (6 артефактов)

| Slot | Name | Effect |
|------|------|--------|
| NECK | amulet_prescience — «Amulet of Prescience» | know 4, spell 3 |
| MISC_A | charm_beast — «Beast Heart Charm» | atk 3, morale 2 |
| MISC_B | trinket_epoch — «Trinket of Epoch» | daily_gems 3, mov 2 |
| RING_L | ring_giant — «Ring of the Giant» | stack_hp 50, atk 2 |
| RING_R | ring_lexicon — «Ring of the Lexicon» | spell 5, know 2 |
| SPELLBOOK | tome_infinity — «Tome of Infinity» | spell 8, daily_gems 1 |

**Итого новых артефактов: 24** (18 оружия/одежды + 6 аксесуаров).

## Все возможные комбинации расположения предметов

Каждый артефакт привязан к ровно одному слоту (`artifact.slot`), поэтому
корректные размещения — это ровно 24 пары (артефакт → его слот).
Исключения/правила, проверяемые сценарием:

- **Кольца** (RING_L / RING_R) — можно надевать в любой из двух слотов колец.
- **Двуручное оружие** (greatsword_might) при экипировке снимает щит.
- Экипировка заменяет предмет в слоте → вытесненный предмет падает в рюкзак.
- Нельзя экипировать два одинаковых предмета одновременно.

Экостальную матрицу «артефакт × слот» прогоняет сценарий
`tmp/inv_scenario.gd`: для каждой пары проверяет, что `can_equip_to_slot`
и `equip()` ведут себя правильно (принимали валидные, отклоняли невалидные).
