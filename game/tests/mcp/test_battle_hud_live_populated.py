"""T-241: живой бой наполняет боевой HUD — карточка героя, карточка противника, кегль.

Чем уровень отличается от GdUnit-кейса
`tests/unit/ui/test_battle_hud_populated_at_full_hd.gd`: тот поднимает `battle.tscn`
и зовёт `start_battle` из теста. Здесь бой стартует в живом процессе под Xvfb, а
состояние экрана читается ТЕМ ЖЕ кодом, каким его наполняет фикстура съёмки
`game/tools/capture/battle_hud_full.gd`. Один носитель состояния на два уровня:
расхождение «тест наполнил сам» против «экран наполнен» здесь невозможно — если
фикстура врёт, краснеют и кадр, и тест.

Что здесь сознательно НЕ меряется: пиксели канонических 1920×1080. `game/run_tests.sh:195`
поднимает Xvfb 1024×768, поэтому канонический кадр снимает `tools/shot_scene.gd`
(резерв `battle-hud-t241`), а этот уровень отвечает за «живой путь вообще доводит экран
до наполненного состояния» и за геометрию/кегль в том кадре, который дал дисплей.
"""

from __future__ import annotations

from pathlib import Path

import pytest

pytestmark = pytest.mark.timeout(900)

## Нижняя граница кегля — UI-AC7 ([[17-ui-style-guide]] §2), то же число, что в
## `tests/functional/ui/test_live_font_hygiene.gd`.
MIN_FONT = 16

FIXTURE = Path(__file__).resolve().parents[2] / "tools" / "capture" / "battle_hud_full.gd"

## Геометрия и кегль читаются с живых узлов; пути — из сцены `scenes/ui/battle_ui.tscn`.
GEOMETRY = """
var battle = get_tree().current_scene
var ui = battle.get_node("BattleUI")
var vp = get_tree().root.get_visible_rect().size
var out = []
for p in ["BattleUI/target_card", "BattleUI/hero_cards/hero_left", "BattleUI/bottom_bar"]:
    var c = ui.get_node(p.replace("BattleUI/", ""))
    var r = (c as Control).get_global_rect()
    out.append({"path": p, "x": r.position.x, "y": r.position.y,
                "right": r.end.x, "bottom": r.end.y})
var labels = {}
for p in ["target_card/tc_box/tc_name", "target_card/tc_box/tc_caption",
          "target_card/tc_box/tc_hp_row/tc_hp", "target_card/tc_box/tc_def_row/tc_def",
          "hero_cards/hero_left/row/info/name",
          "hero_cards/hero_left/row/info/mana_row/mana_num",
          "bottom_bar/info_box/log_row/log_line"]:
    labels[p] = int(ui.get_node(p).get_theme_font_size("font_size"))
return {"viewport": [vp.x, vp.y], "rects": out, "fonts": labels}
"""


def _setup(mcp) -> dict:
    """Наполнение экрана — файлом-фикстурой, а не копией её кода (см. докстринг)."""
    body = FIXTURE.read_text(encoding="utf-8").strip()
    assert body, f"фикстура пуста: {FIXTURE}"
    result = mcp.execute_code(body)
    assert isinstance(result, dict), f"фикстура вернула не словарь: {result!r}"
    return result


def test_live_battle_populates_hero_and_enemy_cards(battle_scene):
    """Бой, запущенный живым путём, обязан наполнить обе карточки до первого мышиного наведения."""
    state = _setup(battle_scene)
    assert state.get("ok"), f"фикстура отказала: {state}"
    assert int(state.get("atk_units", 0)) > 0 and int(state.get("def_units", 0)) > 0, (
        f"армии не расставлены: {state} — проверять наполненность не на чем"
    )
    assert state.get("hero_left_visible"), (
        f"в ростере есть герой (ключ HERO_BATTLE_KEY), а карточка героя скрыта: {state}"
    )
    assert str(state.get("hero_name", "")) == "Герой", state
    assert state.get("hero_mana_visible") and str(state.get("hero_mana", "")) == "12/20", (
        f"герою передана мана 12/20, карточка её не показывает: {state}"
    )
    assert state.get("target_card_visible"), (
        "бой идёт, враг жив, а карточка противника скрыта — до первого наведения "
        f"игрок не видит ни AC, ни HP: {state}"
    )
    assert str(state.get("tc_caption", "")) == "Противник", state
    assert str(state.get("tc_name", "")), f"имя противника пустое: {state}"
    assert str(state.get("tc_hp", "")), f"HP противника пустые: {state}"
    assert str(state.get("tc_def", "")), f"AC противника пустой: {state}"


def test_hud_blocks_sit_inside_the_frame(battle_scene):
    """Карточки не вылезают за кадр и не лежат под полосой команд."""
    _setup(battle_scene)
    battle_scene.wait_frames(30)
    geo = battle_scene.execute_code(GEOMETRY)
    vw, vh = [float(v) for v in geo["viewport"]]
    rects = {str(r["path"]): r for r in geo["rects"]}
    band = rects["BattleUI/bottom_bar"]
    assert float(band["bottom"]) - float(band["y"]) > 0, f"полоса команд не разложена: {band}"
    for path in ["BattleUI/target_card", "BattleUI/hero_cards/hero_left"]:
        r = rects[path]
        w = float(r["right"]) - float(r["x"])
        h = float(r["bottom"]) - float(r["y"])
        assert w > 0 and h > 0, f"{path} не разложен ({r}) — элемент невидим"
        assert float(r["x"]) >= -0.5 and float(r["y"]) >= -0.5, f"{path} вылез за левый/верхний край: {r}"
        assert float(r["right"]) <= vw + 0.5 and float(r["bottom"]) <= vh + 0.5, (
            f"{path} выходит за кадр {vw:.0f}x{vh:.0f}: {r}"
        )
        overlaps = not (
            float(r["bottom"]) <= float(band["y"])
            or float(r["y"]) >= float(band["bottom"])
            or float(r["right"]) <= float(band["x"])
            or float(r["x"]) >= float(band["right"])
        )
        assert not overlaps, f"{path} ({r}) пересекается с полосой команд ({band}) — текст под панелью"


def test_card_labels_meet_the_font_floor(battle_scene):
    """Кегль подписей карточек — не ниже канона UI-AC7 (живое чтение темы)."""
    _setup(battle_scene)
    fonts = battle_scene.execute_code(GEOMETRY)["fonts"]
    assert fonts, "подписей карточек не найдено — проверка кегля пуста"
    below = {p: int(px) for p, px in fonts.items() if int(px) < MIN_FONT}
    assert not below, f"кегль ниже {MIN_FONT} px: {below}"
