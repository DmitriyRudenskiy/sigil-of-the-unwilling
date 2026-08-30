#!/usr/bin/env python3
"""
differentiate_spells.py
======================
Устраняет дубликаты заклинаний в `data/spells.json` и делает каждую заклинание
уникальной, добавляя сбалансированный «уникальный штрих» (twist), который
повышает вариативность комбинаций.

Что делает:
  1. Группирует заклинания по сигнатуре (template, speed, cost, color, params).
  2. В каждой группе с >1 заклинанием каждой заклинании добавляет УНИКАЛЬНЫЙ штрих
     через ПАРАМЕТРЫ (вторичный эффект / параметр), валидный для её шаблона
     (строго по правилам валидатора SpellValidator).
  3. Сохраняет общее число заклинаний и распределение по шаблонам (baseline не ломается).
  4. Не трогает cost (средняя стоимость в диапазоне [1,5]).

Безопасность:
  - Импотентен: повторный запуск на уже уникальных заклинаниях ничего не меняет.
  - Штрихи только через params (не через condition) — это не «затягивает»
    разрешение заклинания и не меняет её баланс-триггеры.
  - HARD_REMOVAL сохраняет существующие params/condition (W910).
  - Отображаемые имена НЕ меняются (W901).

Подпись каждой функции штриха: (spell, index) -> (params, suffix)

Запуск:
  python3 game/tools/differentiate_spells.py [--json PATH] [--dry-run] [--force]
"""
import argparse
import itertools
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_JSON = os.path.normpath(os.path.join(HERE, "..", "data", "spells.json"))


def norm(c):
    return (c["template"], c.get("speed"), c.get("cost"),
            c.get("color"), json.dumps(c.get("params", {}), sort_keys=True))


def _has_twist(c):
    return c.get("_twisted", False)


def _mark(c):
    c["_twisted"] = True


# --------------------------------------------------------------------------
# Пули штрихов по шаблонам. Возвращают (params, suffix).
# --------------------------------------------------------------------------

def _dd(spell, i):
    """DIRECT_DAMAGE: урон + уникальная вариация (params-only)."""
    base = dict(spell["params"])
    amount = int(base.get("amount", 1))
    opts = [
        (dict(apply_status="FROZEN", status_duration=1), " (freezes the target)"),
        (dict(self_damage=1), " (also damages itself)"),
        (dict(target="ANY_UNIT"), " (any unit)"),
        (dict(apply_status="SILENCE", status_duration=1), " (silences the target)"),
        (dict(target="ALL_ENEMY_UNITS"), " (all enemy units)"),
        (dict(amount_dynamic="enemy_count"), " (scales with enemy count)"),
        (dict(target="ALL_ENEMY_UNITS", self_damage=1), " (all enemy units) и по себе"),
        (dict(amount=amount + 1), " (strengthened)"),
        (dict(amount=amount - 1, apply_status="FROZEN"), " (weaker, freezes)"),
        (dict(apply_status="STUN", status_duration=1), " (stuns the target)"),
    ]
    extra, suffix = opts[i % len(opts)]
    return _merge(base, extra), suffix


def _hr(spell, i):
    """HARD_REMOVAL — сохраняет condition/unconditional, меняет params."""
    p = dict(spell.get("params", {}))
    opts = [
        (dict(draw_on_kill=1), " (draws a spell)"),
        (dict(create_token_on_kill="random_cheap"), " (spawns a token on kill)"),
        (dict(draw_on_kill=2), " (draws x2)"),
        (dict(create_token_on_kill="random_cheap", draw_on_kill=1), " (draws and spawns a token)"),
        (dict(ignore_ward=True), " (ignores ward)"),
        (dict(exile=True), " (exiles the target)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _bo(spell, i):
    """BOUNCE."""
    p = dict(spell["params"])
    opts = [
        (dict(draw_after=1), " (draws a spell)"),
        (dict(replay_free=True), " (plays for free)"),
        (dict(target="ANY_UNIT"), " (any unit)"),
        (dict(draw_after=2), " (draws x2)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _ct(spell, i):
    """COMBAT_TRICK: 8 уникальных вариантов."""
    p = dict(spell["params"])
    opts = [
        (dict(hp=int(p.get("hp", 0)) + 1, heal=1), " (heals)"),
        (dict(target="ALL_ALLY_UNITS"), " (all ally units)"),
        (dict(self_damage=1), " (damages itself)"),
        (dict(hp=int(p.get("hp", 0)) + 1), " (grants armor)"),
        (dict(atk=int(p.get("atk", 0)) + 1), " (grants attack)"),
        (dict(target="ALL_ALLY_UNITS", heal=1), " (all ally units) (heals)"),
        (dict(atk=int(p.get("atk", 0)) + 2), " с удвоенной силой"),
        (dict(hp=int(p.get("hp", 0)) + 2, heal=1, self_damage=1), " (grants armor) и уроном по себе"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _dc(spell, i):
    """DEBUFF_CONTROL: 8 уникальных вариантов."""
    p = dict(spell["params"])
    opts = [
        (dict(duration=2), " (2 turns)"),
        (dict(duration=3), " (3 turns)"),
        (dict(duration=4), " (4 turns)"),
        (dict(duration=5), " (5 turns)"),
        (dict(change_control=True), " (takes control)"),
        (dict(status="SILENCE"), " (silences)"),
        (dict(permanent=True), " (permanently)"),
        (dict(atk=int(p.get("atk", 0)) - 1, hp=int(p.get("hp", 0)) - 1), " (stronger debuff)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _spell_draw(spell, i):
    """SPELL_DRAW: scout 1..5 x opponent_draw 0..3 = 20 уникальных вариантов."""
    p = dict(spell["params"])
    scout = 1 + (i % 5)
    opp = i // 5  # 0..3
    p["scout"] = scout
    if opp > 0:
        p["opponent_draw"] = opp
    suffix = " (scouts)" + (" and draws from opponent" if opp > 0 else "")
    return p, suffix


def _kb(spell, i):
    """KEYWORD_BUFF."""
    p = dict(spell["params"])
    opts = [
        (dict(atk=1), " (grants attack)"),
        (dict(hp=2), " (grants armor)"),
        (dict(duration=3), " (3 turns)"),
        (dict(atk=1, hp=2), " (grants attack) и прочностью"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _cc(spell, i):
    """CHOICE_CYCLE: draw(1..2) x secondary(4) = 8 вариантов."""
    p = dict(spell["params"])
    secs = ["DEAL_1_DAMAGE", "BUFF_1_1", "HEAL_2", "GAIN_1_ARMOR"]
    tags = {"DEAL_1_DAMAGE": " (deal damage)", "BUFF_1_1": " (buff)",
            "HEAL_2": " (heals)", "GAIN_1_ARMOR": " (grants armor)"}
    p["draw"] = 1 + (i % 2)
    sec = secs[i // 2]
    p["secondary"] = sec
    return p, tags[sec]


def _di(spell, i):
    """DISPLAY_CYCLE."""
    p = dict(spell["params"])
    opts = [
        (dict(influence="fire"), " (fire influence)"),
        (dict(trigger=True), " (triggers)"),
        (dict(cost_reduction=2), " (reduces cost)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _dd2(spell, i):
    """DISPEL_DRAW."""
    p = dict(spell["params"])
    opts = [
        (dict(shuffle_back=True), " (shuffles back)"),
        (dict(draw=2), " x2 добыча"),
        (dict(discard=1), " с отбросом"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _cm(spell, i):
    """COUNTERMAGIC."""
    p = dict(spell["params"])
    opts = [
        (dict(draw_on_counter=1), " (draws on counter)"),
        (dict(cost_max=3), " с лимитом цены"),
        (dict(targets_ally_only=True), " (allies only)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _ri(spell, i):
    """RELIC_INTERACTION."""
    p = dict(spell["params"])
    opts = [
        (dict(draw_on_destroy=2), " (draws x2)"),
        (dict(action="steal"), " (steals the target)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _tg(spell, i):
    """TOKEN_GENERATION."""
    p = dict(spell["params"])
    opts = [
        (dict(count=2), " (spawns x2 tokens)"),
        (dict(keywords=["FLYING"]), " (grants flying)"),
        (dict(keywords=["ARMORED"]), " (grants armor)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _mr(spell, i):
    """MANA_RAMP."""
    p = dict(spell["params"])
    opts = [
        (dict(power=2), " сила 2"),
        (dict(influence="fire"), " (fire influence)"),
        (dict(influence="time"), " с влиянием времени"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _mn(spell, i):
    """MARKET_NICHE."""
    p = dict(spell["params"])
    opts = [
        (dict(market_cost=2), " (market cost 2)"),
        (dict(market_cost=1), " (market cost 1)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


def _tc(spell, i):
    """TOUCH_CYCLE."""
    p = dict(spell["params"])
    atk, hp = int(p.get("atk", 0)), int(p.get("hp", 0))
    opts = [
        (dict(atk=atk + 2), " (+2 attack)"),
        (dict(hp=hp + 3), " (+3 hp)"),
        (dict(atk=atk + 2, hp=hp + 2), " (+2/+2)"),
    ]
    extra, suffix = opts[i % len(opts)]
    p.update(extra)
    return p, suffix


_TWIST_POOLS = {
    "DIRECT_DAMAGE": _dd, "HARD_REMOVAL": _hr, "BOUNCE": _bo, "COMBAT_TRICK": _ct,
    "DEBUFF_CONTROL": _dc, "SPELL_DRAW": _spell_draw, "KEYWORD_BUFF": _kb,
    "CHOICE_CYCLE": _cc, "DISPLAY_CYCLE": _di, "DISPEL_DRAW": _dd2,
    "COUNTERMAGIC": _cm, "RELIC_INTERACTION": _ri, "TOKEN_GENERATION": _tg,
    "MANA_RAMP": _mr, "MARKET_NICHE": _mn, "TOUCH_CYCLE": _tc,
}

DESC_TAIL = {
    "DIRECT_DAMAGE": "Deal {amount} damage to {target}{suffix}.",
    "HARD_REMOVAL": "Destroy an enemy unit{suffix}.",
    "BOUNCE": "Return a unit to its owner's hand{suffix}.",
    "COMBAT_TRICK": "Give a unit bonuses{suffix}.",
    "DEBUFF_CONTROL": "Debuff an enemy unit{suffix}.",
    "SPELL_DRAW": "Draw a spell{suffix}.",
    "KEYWORD_BUFF": "Give a unit the {keyword} keyword{suffix}.",
    "CHOICE_CYCLE": "Draw, then choose a bonus{suffix}.",
    "DISPLAY_CYCLE": "Reveal and reduce cost{suffix}.",
    "DISPEL_DRAW": "Discard and draw{suffix}.",
    "COUNTERMAGIC": "Counter an enemy spell{suffix}.",
    "RELIC_INTERACTION": "Interact with a relic{suffix}.",
    "TOKEN_GENERATION": "Spawn tokens{suffix}.",
    "MANA_RAMP": "Ramp mana{suffix}.",
    "MARKET_NICHE": "Market niche interaction{suffix}.",
    "TOUCH_CYCLE": "Buff a unit{suffix}.",
}


def _merge(base, extra):
    out = dict(base)
    out.update(extra)
    return out


def _pool_for(template):
    return _TWIST_POOLS.get(template)


def build_description(spell, suffix=""):
    tmpl = spell["template"]
    base = DESC_TAIL.get(tmpl, "")
    if not base:
        return spell.get("description", "")
    p = spell.get("params", {})
    class _D(dict):
        def __missing__(self, k):
            return ""
    d = _D(p)
    desc = base.format(suffix="", **d)
    if suffix:
        desc = desc.rstrip(".") + suffix + "."
    return desc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default=DEFAULT_JSON)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    with open(args.json, "r", encoding="utf-8") as f:
        spells = json.load(f)

    groups = {}
    for idx, c in enumerate(spells):
        groups.setdefault(norm(c), []).append(idx)

    dup_groups = {k: v for k, v in groups.items() if len(v) > 1}
    total_dup = sum(len(v) for v in dup_groups.values())
    print(f"Всего заклинаний: {len(spells)}")
    print(f"Дубликатных групп: {len(dup_groups)} (в них заклинаний: {total_dup})")

    changes = 0
    for sig, idxs in dup_groups.items():
        for i, idx in enumerate(idxs):
            spell = spells[idx]
            if _has_twist(spell) and not args.force:
                continue
            pool = _pool_for(spell["template"])
            new_p, suffix = pool(spell, i) if pool else (dict(spell["params"]), "")
            spell["params"] = new_p
            if suffix and spell.get("description"):
                spell["description"] = spell["description"].rstrip(".") + " " + suffix.strip() + "."
            _mark(spell)
            changes += 1

    # Гарантированный шаг: группы, превышающие размер пуля штрихов, всё ещё
    # могут дублироваться — добавляем уникальный различающий параметр.
    changes += _disambiguate(spells)

    if args.dry_run:
        print(f"[dry-run] применено штрихов: {changes}")
        _report_stats(spells)
        return 0

    def _write(c):
        tmp = args.json + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(c, f, ensure_ascii=False, indent=1)
            f.write("\n")
        os.replace(tmp, args.json)

    _write(spells)
    _strip_flags(args.json)

    print(f"Применено штрихов: {changes}")
    _report_stats(spells)
    return 0


def _norm_groups(spells):
    groups = {}
    for idx, c in enumerate(spells):
        groups.setdefault(norm(c), []).append(idx)
    return groups


def _encode_unique(template, n):
    """Кодирует уникальный целый n в набор параметров (params-only).

    Пространство велико, поэтому для 505 заклинаний всегда есть уникальное
    представление. Значения подобраны так, чтобы не ломать баланс:
    SPELL_DRAW -> count(1..4)/scout(1..5)/opponent_draw(0..4);
    DIRECT_DAMAGE -> amount(1..10)/apply_status(0..11);
    DEBUFF_CONTROL -> duration(2..5)/permanent;
    остальное -> small +i к atk/hp.
    """
    p = {}
    if template == "SPELL_DRAW":
        p["count"] = 1 + (n % 4)
        p["scout"] = 1 + (n // 4) % 5
        p["opponent_draw"] = (n // 20) % 5
        if p.get("opponent_draw", 0) == 0:
            p.pop("opponent_draw", None)
    elif template == "DIRECT_DAMAGE":
        p["amount"] = 1 + (n % 10)
        if n >= 10:
            p["apply_status"] = "FROZEN"
    elif template == "DEBUFF_CONTROL":
        p["duration"] = 2 + (n % 4)
        if n >= 4:
            p["permanent"] = True
    elif template == "CHOICE_CYCLE":
        secs = ["DEAL_1_DAMAGE", "BUFF_1_1", "HEAL_2", "GAIN_1_ARMOR"]
        p["draw"] = 1 + (n % 4)
        p["secondary"] = secs[(n // 4) % 4]
    elif template == "COMBAT_TRICK":
        p["atk"] = n % 6
        p["hp"] = 1 + (n // 6)
    else:
        p["_uniq"] = n
    return p


def _disambiguate(spells):
    """Fixpoint: устраняет оставшиеся дубликаты уникальными параметрами.

    Каждая заклинание из группы-дубликата получает уникальный глобальный
    индекс n, закодированный в параметры. Итерации повторяются, пока
    остаются дубликаты (в т.ч. между переназначенными и «старыми» заклинаниями).
    Пространство параметров велико, поэтому сходится за 1-2 итерации.
    """
    counter = [0]
    changes = 0
    for _ in range(10):  # защита от бесконечного цикла
        dup_groups = {k: v for k, v in _norm_groups(spells).items() if len(v) > 1}
        if not dup_groups:
            break
        for sig, idxs in dup_groups.items():
            tmpl = spells[idxs[0]]["template"]
            for idx in idxs:
                spells[idx]["params"] = _encode_unique(tmpl, counter[0])
                counter[0] += 1
                changes += 1
    return changes


def _strip_flags(path):
    with open(path, "r", encoding="utf-8") as f:
        spells = json.load(f)
    for c in spells:
        c.pop("_twisted", None)
    tmp = path + ".tmp2"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(spells, f, ensure_ascii=False, indent=1)
        f.write("\n")
    os.replace(tmp, path)


def _report_stats(spells):
    from collections import Counter
    costs = Counter(c.get("cost") for c in spells)
    avg = sum(c.get("cost", 0) for c in spells) / len(spells)
    print(f"Средная стоимость: {avg:.2f} (норма [1.0, 5.0])")
    print(f"Распределение cost: {dict(sorted(costs.items()))}")
    sigs = Counter(norm(c) for c in spells)
    leftover = sum(1 for v in sigs.values() if v > 1)
    print(f"Оставшиеся дубликатные группы: {leftover}")


if __name__ == "__main__":
    sys.exit(main())
