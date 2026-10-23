"""ui-mockup-parity §7.1 (Q-M87 → (б), D-204): носитель экрана города в игровом пути.

Граница уровня (тот же урок, что у `test_main_menu_buttons_live`): настоящего
попадания мышью из скрипта в Godot 4.7 нет — `push_input` из команды MCP-сервера
обрывает сокет interaction server, а путь BaseButton «отпустил → pressed» требует
мышиного фокуса viewport. Здесь поэтому: доводка носителя по полному игровому
пути (меню → создание персонажа → Знак → `main.tscn`), состояние кнопки и экрана,
и проводка сигналов эмитом `pressed` / `close_requested` вместо клика.

Что именно это покрывает и не покрывает GdUnit: в юнит-тестах экран города
существует сам по себе, а `main.tscn` с поднятым слоем HUD и привязанным
кампейн-городом живёт только здесь — четвёртый уровень (живой Godot).
"""
from __future__ import annotations

HUD = "CampaignHUD/CampaignHud"
BUTTON = "CampaignHUD/CampaignHud/TopButtons/CityButton"
SCREEN = "CampaignHUD/CampaignHud/CityScreen"


def _state(mcp) -> dict:
    """Состояние носителя одной командой: слой, кнопка, экран, кампейн-город."""
    return mcp.execute_code(
        f"var s = get_tree().current_scene\n"
        f'var hud = s.get_node_or_null("{HUD}")\n'
        'var comp = s.get("composition") if s != null else null\n'
        "return {"
        '"hud": hud != null, '
        '"layer": hud.get_parent().layer if hud != null else -1, '
        '"button": hud != null and hud.get_node_or_null("TopButtons/CityButton") != null, '
        '"disabled": hud.get_node("TopButtons/CityButton").disabled if hud != null else null, '
        '"screen": hud != null and hud.city_screen != null, '
        '"visible": hud.city_screen.visible if hud != null and hud.city_screen != null else null, '
        '"open": hud.is_city_screen_open() if hud != null else null, '
        '"city": hud.city != null if hud != null else null, '
        '"city_name": hud.city.display_name if hud != null and hud.city != null else "", '
        '"turn": comp.campaign.current_turn if comp != null else -1}'
    )


def test_carrier_bound_after_new_game(full_cycle):
    """Полный путь до `main.tscn`: слой поднят, город привязан, кнопка активна, экран закрыт."""
    st = _state(full_cycle)
    assert st["turn"] >= 1, f"кампания не стартовала: {st}"
    assert st["hud"], f"слой носителя отсутствует в main.tscn: {st}"
    assert st["layer"] == 5, f"слой носителя должен быть 5 (над DayLabel): {st}"
    assert st["button"], f"кнопка «Город» не построена: {st}"
    assert st["disabled"] is False, (
        "кнопка «Город» обязана стать доступной после привязки города — "
        f"иначе носитель не имеет входа из игры: {st}"
    )
    assert st["city"] and st["city_name"], f"кампейн-город не привязан: {st}"
    assert st["screen"], f"экран города не создан при привязке: {st}"
    assert st["visible"] is False and st["open"] is False, (
        "экран города не имеет права быть открытым до нажатия — он лёг бы "
        f"поверх кампании сразу после загрузки: {st}"
    )


def test_button_press_opens_city_screen(full_cycle):
    """Нажатие «Город» открывает экран поверх кампании (вход носителя в живом рантайме)."""
    full_cycle.execute_code(
        f'get_tree().current_scene.get_node("{BUTTON}").emit_signal("pressed")\n'
        "return true"
    )
    full_cycle.wait_frames(30)
    st = _state(full_cycle)
    assert st["open"] and st["visible"], f"экран города не открылся по нажатию: {st}"


def test_second_press_closes_city_screen(full_cycle):
    """Кнопка — переключатель: второе нажатие закрывает экран (тот же обработчик)."""
    for _ in range(2):
        full_cycle.execute_code(
            f'get_tree().current_scene.get_node("{BUTTON}").emit_signal("pressed")\n'
            "return true"
        )
        full_cycle.wait_frames(15)
    st = _state(full_cycle)
    assert not st["open"], f"второе нажатие не закрыло экран: {st}"
    assert st["visible"] is False, f"экран остался видимым после закрытия: {st}"


def test_close_requested_signal_closes_carrier(full_cycle):
    """Проводка `close_requested` (её эмитирует Esc экрана) закрывает экран носителем."""
    full_cycle.execute_code(
        f'get_tree().current_scene.get_node("{SCREEN}").emit_signal("close_requested")\n'
        "return true"
    )
    full_cycle.wait_frames(15)
    assert _state(full_cycle)["open"] is False, "Esc-путь экрана не закрыт носителем"


def test_carrier_survives_turn_tick(full_cycle):
    """Смена хода не роняет носитель: город переживает тик, кнопка остаётся доступной."""
    full_cycle.execute_code(
        "var comp = get_tree().current_scene.composition\n"
        "comp.advance_turn()\n"
        "return {\"turn\": comp.campaign.current_turn}"
    )
    full_cycle.wait_frames(30)
    st = _state(full_cycle)
    assert st["turn"] >= 2, f"ход не прошёл: {st}"
    assert st["hud"] and st["screen"] and st["disabled"] is False, (
        f"носитель потерял город или кнопку после смены хода: {st}"
    )


def test_carrier_is_standalone_host(full_cycle):
    """Слой — самостоятельный хост: `CampaignUIManager` в `main.tscn` не поднят.

    Зафиксировано, а не подразумевается: открытый вопрос владельцу (регистрировать
    ли экраны в `CampaignUIManager` ради SM-переходов) решается с полным знанием
    о том, что носитель сегодня работает и без него.
    """
    children = full_cycle.execute_code(
        "var out = []\n"
        "for c in get_tree().current_scene.get_children():\n"
        '    out.append(str(c.name))\n'
        "return {\"children\": out}"
    )["children"]
    assert "UIManager" in children, f"в main.tscn должен быть узел UIManager: {children}"
    assert "CampaignUIManager" not in children, (
        f"CampaignUIManager поднят — носитель больше не самостоятельный хост: {children}"
    )
