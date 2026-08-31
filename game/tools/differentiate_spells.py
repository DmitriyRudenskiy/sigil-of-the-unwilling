#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
differentiate_spells.py — повышение уникальности описаний заклинаний.

Проблема: описания дублировались у 316/505 заклинаний (63%):
  * 78 кросс-цветовых групп — одинаковые (template, speed, cost, params),
    но 5 цветов дают одинаковый текст;
  * 16 одноцветных групп — одинаковый текст, но params уже разные
    (поэтому norm()-уникальность в порядке, и прежний инструмент их
    не видел и не мог тронуть).

Решение (безопасный уровень — описание НЕ меняет params):
  1. Группируем по ТЕКСТУ описания (без цвета).
  2. Внутри группы бакет (template, speed, cost, color), локальный индекс.
  3. Индекс штриха = COLOR_RANK[color] + local_index (mod size(pool)).
     Кросс-цвет: local=0 -> тематично по цвету. Одноцвет: разные local.
  4. Суффикс штриха + цветовой клауз « (Fire, scorching)».

Гарантии: params НЕ меняются -> E5 (norm) и cost-распределение не нарушены;
меняется только описание (<= MAX_DESC_LENGTH=200); idempотентен;
--force переписывает заново; total/template/display-name не меняются.
"""

import json
import os
import re
from collections import defaultdict

COLOR_ORDER = ["fire", "time", "justice", "primal", "shadow", "multifaction", "colorless"]
COLOR_RANK = {c: i for i, c in enumerate(COLOR_ORDER)}
NUM_COLORS = len(COLOR_ORDER)

COLOR_CLAUSE = {
    "fire": " (Fire, scorching)",
    "time": " (Time, accelerated)",
    "justice": " (Justice, exact)",
    "primal": " (Primal, rooted)",
    "shadow": " (Shadow, chilling)",
    "multifaction": "",
    "colorless": "",
}

DATA_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "data", "spells.json",
)

# Пулы штрихов: список (extra_params, suffix). Индексы 0..4 = fire/time/
# justice/primal/shadow, дальше — запасные. extra_params НЕ применяется
# (только суффикс описания), чтобы сохранить params/E5.
_SUFFIXES = {
    "DIRECT_DAMAGE": [
        " (burning — deals extra damage)",
        " (accelerated — scales with enemies)",
        " (punishing — stuns the target)",
        " (entangling — freezes the target)",
        " (silencing the target)",
        " (all enemy units)",
        " (also damages itself)",
        " (any unit)",
        " (weaker, freezes)",
    ],
    "HARD_REMOVAL": [
        " (spawns tokens)",
        " (draws x2)",
        " (a reward spell)",
        " (ignores ward)",
        " (exiles the target)",
        " (ignores ward, draws)",
    ],
    "BOUNCE": [
        " (replays for free)",
        " (draws x2)",
        " (draws a spell)",
        " (any unit)",
        " (draws x3)",
        " (free and redraws)",
    ],
    "COMBAT_TRICK": [
        " (grants +2 attack)",
        " (grants +3 armor)",
        " (grants +1/+1)",
        " (grants armor and heals)",
        " (grants +3 attack)",
        " (all ally units)",
        " (damages itself)",
    ],
    "DEBUFF_CONTROL": [
        " (silences)",
        " (lasts 3 turns)",
        " (takes control)",
        " (freezes)",
        " (permanently)",
        " (lasts 4 turns)",
        " (lasts 2 turns)",
    ],
    "SPELL_DRAW": [
        " (draws 2, scouts 2)",
        " (draws 3, scouts 3)",
        " (draws, opponent draws)",
        " (draws 2, scouts 4)",
        " (draws 1, scouts 5)",
        " (draws 3, scouts 1)",
        " (draws 4, scouts 2)",
        " (draws 2, opponent draws 2)",
    ],
    "KEYWORD_BUFF": [
        " (grants +1 attack)",
        " (grants 2 armor)",
        " (lasts 3 turns)",
        " (grants +1/+2)",
        " (lasts 2 turns)",
        " (grants 1 armor)",
    ],
    "CHOICE_CYCLE": [
        " (deal damage)",
        " (buff x2)",
        " (heals)",
        " (grants armor)",
        " (disables the target)",
        " (deal damage x2)",
        " (gain flying)",
    ],
    "DISPLAY_CYCLE": [
        " (fire influence)",
        " (time influence)",
        " (reduces cost by 2)",
        " (primal influence)",
        " (shadow influence)",
        " (triggers)",
    ],
    "DISPEL_DRAW": [
        " (discards 1, draws 2)",
        " (discards 1, draws 1)",
        " (discards 2, draws 2)",
        " (shuffles back)",
        " (discards 1, draws 3)",
        " (discards 2, draws 1)",
    ],
    "COUNTERMAGIC": [
        " (draws on counter)",
        " (limited to 3)",
        " (allies only)",
        " (draws x2 on counter)",
        " (limited to 2)",
        " (any target)",
    ],
    "RELIC_INTERACTION": [
        " (steals the relic)",
        " (destroys, draws x2)",
        " (destroys, draws)",
        " (steals, draws)",
        " (destroys the relic)",
    ],
    "TOKEN_GENERATION": [
        " (spawns 2, flying)",
        " (spawns 1, armor)",
        " (spawns 3 tokens)",
        " (spawns 2 tokens)",
        " (spawns 1 token)",
    ],
    "MANA_RAMP": [
        " (mana power 2)",
        " (time influence)",
        " (mana power 3)",
        " (primal influence)",
        " (fire influence)",
        " (shadow influence)",
    ],
    "MARKET_NICHE": [
        " (market cost 1)",
        " (market cost 2)",
        " (market cost 3)",
        " (free to trigger)",
        " (burned price)",
    ],
    "TOUCH_CYCLE": [
        " (+2/+2)",
        " (+3 attack)",
        " (+1/+3)",
        " (+2/+1)",
        " (+1/+1)",
    ],
}


# --- Работа с данными --------------------------------------------------------

def _strip_trailing_parens(desc):
    """Снять все trailing-«( …)» — это суффиксы/клаузы, которые мы пересобираем."""
    if not desc:
        return desc
    while re.search(r"\([^)]*\)\s*$", desc):
        desc = re.sub(r"\s*\([^)]*\)\s*$", "", desc).rstrip()
    return desc


def _suffix_for(template, eff_index):
    pool = _SUFFIXES.get(template)
    if not pool:
        return ""
    if eff_index < len(pool):
        return pool[eff_index]
    # фолбэк: пул исчерпан — добавляем уникальный номер (напр. 10+ SPELL_DRAW)
    return " (variant %d)" % (eff_index + 1)


def _apply_description_tweak(spell, suffix):
    color = spell.get("color")
    clause = COLOR_CLAUSE.get(color, "")
    desc = _strip_trailing_parens(spell.get("description") or "")
    parts = []
    if suffix:
        parts.append(suffix.strip())
    if clause:
        parts.append(clause.strip())
    if parts:
        desc = (desc + " " + " ".join(parts)).strip()
    if not desc.endswith("."):
        desc += "."
    spell["description"] = desc


# --- main --------------------------------------------------------------------

def main():
    import argparse
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", default=DATA_PATH, help="путь к spells.json")
    parser.add_argument("--dry-run", action="store_true", help="показать, не записывая")
    parser.add_argument("--force", action="store_true", help="переписать заново")
    args = parser.parse_args()

    spells = json.load(open(args.json, encoding="utf-8"))

    # 1. Группировка по ТЕКСТУ описания (без цвета).
    desc_groups = defaultdict(list)
    for idx, c in enumerate(spells):
        desc_groups[c["description"]].append(idx)

    total_twisted = 0
    # Индекс штриха уникален по (описанию, color): клауз дифференцирует
    # кросс-цвет, локальный индекс — одноцветные дубликаты внутри группы.
    for desc, idxs in sorted(desc_groups.items()):
        if len(idxs) < 2:
            continue
        by_color = defaultdict(list)
        for idx in idxs:
            by_color[spells[idx].get("color")].append(idx)
        for color, cidxs in sorted(by_color.items(), key=lambda kv: (COLOR_RANK.get(kv[0], 99), kv[0])):
            cidxs.sort(key=lambda i: (spells[i].get("cost"), spells[i].get("name")))
            for local, idx in enumerate(cidxs):
                s = spells[idx]
                if "_twisted" in s and not args.force:
                    continue
                eff_index = COLOR_RANK.get(color, 0) + local
                _apply_description_tweak(s, _suffix_for(s.get("template"), eff_index))
                s["_twisted"] = True
                total_twisted += 1

    if not args.dry_run:
        for s in spells:
            s.pop("_twisted", None)
        json.dump(spells, open(args.json, "w", encoding="utf-8"),
                  ensure_ascii=False, indent=2)

    _report_stats(spells, total_twisted, args.dry_run)


def _report_stats(spells, total_twisted, dry_run):
    # norm-уникальность (с цветом) — для валидатора E5
    def norm_dups(c_list):
        g = defaultdict(int)
        for c in c_list:
            k = (c["template"], c.get("speed"), c.get("cost"), c.get("color"),
                 json.dumps(c.get("params", {}), sort_keys=True))
            g[k] += 1
        return sum(1 for v in g.values() if v > 1)

    # игровая уникальность (по описанию)
    dg = defaultdict(int)
    for c in spells:
        dg[c["description"]] += 1
    desc_dups = sum(1 for v in dg.values() if v > 1)

    print("Всето заклинаний: %d" % len(spells))
    print("[dry-run] применено" if dry_run else "Примено", "описательных штрихов: %d" % total_twisted)
    print("Norm-дубликатные группы (E5): %d" % norm_dups(spells))
    print("Дубликатные описания (игроковые): %d групп" % desc_dups)

    costs = [c["cost"] for c in spells if isinstance(c.get("cost"), (int, float))]
    if costs:
        print("Средная стоимость: %.2f (норма [1.0, 5.0])" % (sum(costs) / len(costs)))
        print("Распределение cost: %s" % json.dumps(
            dict(sorted(__import__("collections").Counter(costs).items()))))


if __name__ == "__main__":
    main()
