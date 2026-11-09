"""ЗОНД remove-campaign-mechanic 1.5 (не тест): ручной проход игрока по world-носителю.

Имя файла намеренно не `test_*`: уровень (`pytest tests/mcp/`) его не собирает —
зонд запускается руками и только по запросу:

    MCP_SSH_HOST= GODOT_PATH=<godot-4.7> MCP_PORT=9477 \
        pytest tests/mcp/probe_rmc_walkthrough.py -q -s --timeout=900

`MCP_SSH_HOST=` гасит делегацию на X-контур (прогон агента — только локально, D-315),
`MCP_PORT` — свободный порт, чтобы не спорить с чужой сессией за 9090.

Зачем: 1.5 — стоп-условие всего сноса. Пока игрок, попавший после Знака в мир, не
пройдёт «движение → город → карта → миникарта → ход», группы 3–5 не начинаются.
Проверяется ровно то, что делает игрок, а не то, что метод существует: движение и
вход в город — кликом по клетке (`hero.on_map_clicked`, тот же путь, что у
`world_input.gd`), закрытие города — нажатием штатной кнопки `Close`, ход —
нажатием `EndTurnButton`.

Каждый шаг печатает `WALKTHROUGH <шаг>: PASS|FAIL …` и снимает кадр в `tmp/shots/`.
Кадр — кадр разработки (пиксели в git не идут, D-185): размер получается канонным
(пин borderless-окном), но канон-подтверждение кадра — шаг владельца (D-315), а
вердикт шага — ответы движка, не пиксели. Окно перед каждым снимком поднимается на
передний план: на macOS окно за чужим перестаёт презентовать кадры, и снимок
замеряет прошлый экран (`_shoot` ловит это хэшем и помечает STALE).
"""

from __future__ import annotations

import time
from pathlib import Path

import capture

SCENE = "res://scenes/ui/adventure_ui.tscn"
SHOTS = Path("tmp/shots")
# Хэши уже снятых кадров — ловушка «текстура окна замерла» (см. `_shoot`).
_SHOTS: dict[str, str] = {}

BOOT = """
var w = get_tree().current_scene
return {"hero": w.get_hero() != null, "map": w.get_map_gen() != null}
"""

# Срез состояния, без которого отказ шага не читается (клетка героя, ход, туман).
DIAG = """
var w = get_tree().current_scene
var hero = w.get_hero()
var mov = hero.get_component("Movement")
var map = w.get_map_gen()
var c: Vector2i = mov.get_current_cell()
var cities: Array = []
for city in w.get_cities().cities:
	cities.append({"name": city.display_name, "cx": city.center.x, "cy": city.center.y,
		"core": city.core_cells.size(), "core_walkable": map.is_walkable(city.center)})
return {"cell": [c.x, c.y], "pos": [int(hero.global_position.x), int(hero.global_position.y)],
	"mp": mov.get_move_points(), "moving": mov.is_moving(),
	"tilemap": map.has_valid_tilemap(), "map": [map.map_width, map.map_height],
	"terminal": w.is_terminal(), "cities": cities}
"""

# Клик по клетке — тот же вход, что у ЛКМ (`world_input.gd` → `hero.on_map_clicked`).
CLICK = """
var w = get_tree().current_scene
w.get_hero().on_map_clicked(Vector2i(%d, %d))
return {"ok": true}
"""

# Состояние движения: `pending`/`planned` показывают, на какой ноге двухшагового
# клика мы находимся (первый клик — предпросмотр, дальше — коммит маршрута).
MOVE_STATE = """
var w = get_tree().current_scene
var ctl = w.get_hero().get_component("Movement").get_controller()
var c: Vector2i = ctl.current_cell
var p: Vector2i = ctl.pending_cell
return {"x": c.x, "y": c.y, "moving": ctl.is_moving, "mp": ctl.move_points,
	"pending": [p.x, p.y], "planned": ctl.planned_path.size(),
	"path": ctl.path.size()}
"""

# Цель движения: соседняя проходимая клетка вне города + диагноз недоступности.
PICK_NEIGHBOUR = """
var w = get_tree().current_scene
var mov = w.get_hero().get_component("Movement")
var map = w.get_map_gen()
var start: Vector2i = mov.get_current_cell()
var target: Vector2i = start
for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
	var c: Vector2i = start + d
	if map.is_walkable(c) and w.get_cities().city_at(c) == null:
		target = c
		break
return {"sx": start.x, "sy": start.y, "tx": target.x, "ty": target.y,
	"found": target != start, "why": mov.reach_problem(target),
	"can_reach": mov.can_reach(target)}
"""

CELL = """
var w = get_tree().current_scene
var ctl = w.get_hero().get_component("Movement").get_controller()
var c: Vector2i = ctl.current_cell
return {"x": c.x, "y": c.y, "moving": ctl.is_moving, "mp": ctl.move_points}
"""

# Встать рядом с городом и кликнуть по его ядру — путь входа через `_on_hero_moved`.
ENTER_CITY = """
var w = get_tree().current_scene
var cities = w.get_cities()
var mov = w.get_hero().get_component("Movement")
var map = w.get_map_gen()
if cities.cities.is_empty():
	return {"ok": false, "reason": "в мире нет городов"}
var city = cities.cities[0]
var core: Vector2i = city.center
for c in city.core_cells:
	if map.is_walkable(c):
		core = c
		break
var stand: Vector2i = city.center
for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
	var c: Vector2i = city.center + d
	if map.is_walkable(c):
		stand = c
		break
mov.teleport(stand)
return {"ok": true, "city": city.display_name, "core": [core.x, core.y],
	"stand": [stand.x, stand.y], "core_walkable": map.is_walkable(core),
	"city_at_core": cities.city_at(core) != null,
	"why": mov.reach_problem(core)}
"""

OVERLAY = """
var w = get_tree().current_scene
var um = w.get_ui_manager()
return {"open": um.city_overlay_open(), "visible": um.city_screen.visible}
"""

# Закрытие — штатной кнопкой города (её `pressed` → `close_requested` → менеджер).
CLOSE_CITY = """
var w = get_tree().current_scene
var cs = w.get_ui_manager().city_screen
var btn = cs.find_child("Close", true, false)
if btn == null:
	return {"ok": false, "reason": "кнопка Close не найдена"}
btn.emit_signal("pressed")
return {"ok": true, "name": str(btn.name)}
"""

# `get_node_or_null` отдаёт Node, а у Node нет ни size, ни visible: поля читаются
# get'ом, иначе eval падает «Failed to compile GDScript (error 43)». Каждый шаг
# проверяется отдельно: рантайм-ошибка внутри eval рвёт сокет interaction server,
# поэтому вариант «одной строкой» здесь не пишется.
MINIMAP = """
var w = get_tree().current_scene
var um = w.get_ui_manager()
if um == null:
	return {"ok": false, "reason": "ui_manager null"}
var ui = um.get("ui")
if ui == null:
	return {"ok": false, "reason": "ui null"}
var mm = ui.get_node_or_null("RightColumn/Box/PanelsBox/MinimapPanel")
if mm == null:
	return {"ok": false, "reason": "MinimapPanel не найден", "ui": str(ui.name)}
var sz: Vector2 = mm.get("size")
return {"ok": true, "cls": mm.get_class(), "visible": mm.get("visible"),
	"size": [int(sz.x), int(sz.y)], "has_signal": mm.has_signal("minimap_clicked")}
"""

# Ход — нажатием кнопки, а не вызовом do_end_turn: проверяется вся цепочка
# InfoPanel → AdventureUI → WorldEventRouter. Дата живёт в WorldPersistence и наружу
# носителем не отдаётся — читаем тем же приёмом, каким её читает маршрутизатор.
END_TURN = """
var w = get_tree().current_scene
var ui = w.get_ui_manager().get("ui")
if ui == null:
	return {"ok": false, "reason": "ui null"}
var btn = ui.get_node_or_null(
	"RightColumn/Box/PanelsBox/InfoPanel/columns/btn_col_right/EndTurnButton")
if btn == null:
	return {"ok": false, "reason": "EndTurnButton не найден"}
var p = w.get("_persistence")
if p == null:
	return {"ok": false, "reason": "persistence null"}
var d: Dictionary = p.get_date()
var before = {"month": int(d.get("month", 0)), "day": int(d.get("day", 0)),
	"turn": w.get_cities().current_turn}
btn.emit_signal("pressed")
return {"ok": true, "before": before}
"""

DATE_AFTER = """
var w = get_tree().current_scene
var p = w.get("_persistence")
var d: Dictionary = p.get_date() if p != null else {}
return {"month": int(d.get("month", 0)), "day": int(d.get("day", 0)),
	"turn": w.get_cities().current_turn}
"""


def _eval(mcp, code: str) -> dict:
    """Один eval; падение — значение, а не разрыв прохода (шаг краснеет, зонд идёт дальше).

    `null` от eval — тоже отказ: значит рантайм упал внутри `_run()` и ответа нет.
    """
    try:
        got = mcp.execute_code(code)
    except Exception as e:  # noqa: BLE001 — вердикт шага важнее стека
        return {"ok": False, "error": str(e)}
    return got if isinstance(got, dict) else {"ok": False, "null": repr(got)}


def _shoot(mcp, name: str) -> str:
    """Кадр шага. Пин + выход на передний план обязательны: на macOS окно за
    чужим окном перестаёт презентовать кадры, и `get_texture()` отдаёт последнюю
    нарисованную картинку — `frames_drawn` растёт, пиксели нет (тот же эффект,
    что описан в докстринге `capture.pin_window_code` для полноэкранного режима).
    Поэтому кадр сверяется хэшем с предыдущими: совпал — это не кадр, а заглушка,
    и в вердикте он помечен STALE.
    """
    SHOTS.mkdir(parents=True, exist_ok=True)
    mcp.execute_code(capture.pin_window_code(capture.canonical_size())
                     + "\nget_window().move_to_foreground()\nreturn 1")
    mcp.wait_frames(10)
    raw = mcp.screenshot()
    digest = capture.sha256_hex(raw)
    same = [k for k, v in _SHOTS.items() if v == digest]
    _SHOTS[name] = digest
    path = SHOTS / f"{name}.png"
    path.write_bytes(raw)
    return (f"{path} {capture.png_size(raw)}"
            + (f" STALE — пиксели как у {same[0]}" if same else ""))


def _wait(mcp, code: str, predicate, timeout: float = 30.0, step: float = 0.5):
    deadline = time.time() + timeout
    last: dict = {}
    while time.time() < deadline:
        last = _eval(mcp, code)
        if predicate(last):
            return last
        time.sleep(step)
    return last


def _walk(mcp, target: tuple[int, int], clicks: int = 3, timeout: float = 60.0):
    """Кликает по клетке так, как игрок, и ждёт прибытия. (число кликов, состояние).

    Число кликов — часть вердикта: `on_map_clicked` двухходовой (первый клик
    рисует предпросмотр), поэтому «один клик = шаг» проверяется здесь, а не в коде.
    """
    code = CLICK % (target[0], target[1])
    per = timeout / clicks
    state: dict = {}
    trail: list[str] = []
    for used in range(1, clicks + 1):
        _eval(mcp, code)
        deadline = time.time() + per
        while time.time() < deadline:
            state = _eval(mcp, MOVE_STATE)
            if state.get("error") or state.get("null"):
                state["trail"] = trail
                return used, state
            if (state.get("x"), state.get("y")) == target and not state.get("moving"):
                state["trail"] = trail
                return used, state
            if not state.get("moving"):
                # Предпросмотр строится асинхронно (`_route_async`): второй клик
                # раньше, чем маршрут готов, — это гонка зонда, а не игрока.
                # Ждём план, потом считаем клик «ещё раз» честным.
                ready = time.time() + 5.0
                while time.time() < ready and not state.get("planned"):
                    time.sleep(0.2)
                    state = _eval(mcp, MOVE_STATE)
                trail.append(f"клик{used}: pending={state.get('pending')} "
                             f"planned={state.get('planned')}")
                break
            time.sleep(0.4)
    state["trail"] = trail
    return clicks, state


def test_walkthrough(mcp):
    results: list[tuple[str, bool, str]] = []

    def step(name: str, ok: bool, detail: str) -> None:
        results.append((name, ok, detail))
        print(f"WALKTHROUGH {name}: {'PASS' if ok else 'FAIL'} — {detail}", flush=True)

    mcp.run_scene(SCENE)
    mcp.wait_ready()
    booted = _wait(mcp, BOOT, lambda r: r.get("hero") and r.get("map"), timeout=180)
    if not (booted.get("hero") and booted.get("map")):
        step("boot", False, f"мир не собрался: {booted}")
        raise AssertionError(f"мир не собрался: {booted}")
    mcp.wait_frames(30)
    mcp.execute_code(capture.pin_window_code(capture.canonical_size()))
    mcp.wait_frames(20)
    step("boot", True, f"носитель поднят, кадр {_shoot(mcp, 'rmc-walk-1-boot')}")
    print(f"  состояние: {_eval(mcp, DIAG)}", flush=True)

    # 1) Движение героя кликом по соседней клетке.
    pick = _eval(mcp, PICK_NEIGHBOUR)
    start = (pick.get("sx"), pick.get("sy"))
    target = (pick.get("tx"), pick.get("ty"))
    used, st = _walk(mcp, target)
    step("движение героя", bool(pick.get("found")) and (st.get("x"), st.get("y")) == target,
         f"{start} → ({st.get('x')},{st.get('y')}) за {used} клик(ов), цель {target}; "
         f"why={pick.get('why')!r} can_reach={pick.get('can_reach')} mp={st.get('mp')} "
         f"trail={st.get('trail')}")
    print(f"  кадр {_shoot(mcp, 'rmc-walk-2-moved')}", flush=True)

    # 2) Вход в город: шаг на ядро города (открывает `_on_hero_moved`).
    enter = _eval(mcp, ENTER_CITY)
    if not enter.get("ok"):
        step("вход в город", False, str(enter))
    else:
        core = tuple(enter.get("core"))
        used, st = _walk(mcp, core)
        opened = _wait(mcp, OVERLAY, lambda r: r.get("open"), timeout=20.0)
        step("вход в город", bool(opened.get("open")),
             f"{enter.get('city')}: overlay={opened.get('open')} за {used} клик(ов), "
             f"клетка=({st.get('x')},{st.get('y')}) core={core} "
             f"city_at_core={enter.get('city_at_core')} why={enter.get('why')!r}")
        print(f"  кадр {_shoot(mcp, 'rmc-walk-3-city')}", flush=True)

        # 3) Выход в карту — штатной кнопкой.
        close = _eval(mcp, CLOSE_CITY)
        closed = _wait(mcp, OVERLAY, lambda r: not r.get("open"), timeout=20.0)
        step("выход в карту", bool(close.get("ok")) and not closed.get("open"),
             f"{close}: overlay={closed.get('open')}")
        print(f"  кадр {_shoot(mcp, 'rmc-walk-4-map')}", flush=True)

    # 4) Миникарта.
    mm = _eval(mcp, MINIMAP)
    # Проверка «панель поднята и жива»: переход клик→камера покрыт
    # tests/functional/ui/test_minimap_panel.gd, здесь он не повторяется.
    step("миникарта", bool(mm.get("ok")) and mm.get("visible")
         and int((mm.get("size") or [0])[0]) > 0 and mm.get("has_signal"), str(mm))

    # 5) Кнопка хода.
    turn = _eval(mcp, END_TURN)
    if not turn.get("ok"):
        step("кнопка хода", False, str(turn))
    else:
        mcp.wait_frames(30)
        after = _eval(mcp, DATE_AFTER)
        before = turn["before"]
        changed = any(after.get(k) != before[k] for k in ("day", "month", "turn"))
        step("кнопка хода", "error" not in after and changed, f"{before} → {after}")
        print(f"  кадр {_shoot(mcp, 'rmc-walk-5-turn')}", flush=True)

    bad = [name for name, ok, _ in results if not ok]
    print(f"WALKTHROUGH ИТОГ: {len(results) - len(bad)}/{len(results)} "
          f"{'PASS' if not bad else 'FAIL ' + ', '.join(bad)}", flush=True)
    assert not bad, f"непройдено: {bad}"
