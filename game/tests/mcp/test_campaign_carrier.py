"""ui-mockup-parity §7.1/7.3 (Q-M87 → (б), D-204; регистрация — D-226/D-227):
носитель экранов кампании (город, партия) в игровом пути.

Граница уровня (тот же урок, что у `test_main_menu_buttons_live`): настоящего
попадания мышью из скрипта в Godot 4.7 нет — `push_input` из команды MCP-сервера
обрывает сокет interaction server, а путь BaseButton «отпустил → pressed» требует
мышиного фокуса viewport. Здесь поэтому: доводка носителя по полному игровому
пути (меню → создание персонажа → Знак → `main.tscn`), состояние кнопки и экрана,
и проводка сигналов эмитом `pressed` / `close_requested` вместо клика.

Что именно это покрывает и не покрывает GdUnit: в юнит-тестах экраны города и
партии существуют сами по себе, а `main.tscn` с поднятым слоем HUD,
привязанным кампейн-городом и живым ростером партии живёт только здесь —
четвёртый уровень (живой Godot).
"""
from __future__ import annotations

HUD = "CampaignHUD/CampaignHud"
BUTTON = "CampaignHUD/CampaignHud/TopButtons/CityButton"
SCREEN = "CampaignHUD/CampaignHud/CityScreen"
PARTY_BUTTON = "CampaignHUD/CampaignHud/TopButtons/PartyButton"
PARTY_SCREEN = "CampaignHUD/CampaignHud/PartyScreen"
MANAGER = "CampaignUIManager"


def _press(mcp, path: str) -> None:
    mcp.execute_code(
        f'get_tree().current_scene.get_node("{path}").emit_signal("pressed")\n'
        "return true"
    )
    mcp.wait_frames(15)


def _state(mcp) -> dict:
    """Состояние носителя одной командой: слой, кнопка, экран, машина, город."""
    return mcp.execute_code(
        f"var s = get_tree().current_scene\n"
        f'var hud = s.get_node_or_null("{HUD}")\n'
        f'var mgr = s.get_node_or_null("{MANAGER}")\n'
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
        '"manager": mgr != null, '
        '"at": str(mgr.current_screen()) if mgr != null else "", '
        '"registered": mgr.has_screen(&"city") if mgr != null else null, '
        '"party_button": hud != null and hud.get_node_or_null("TopButtons/PartyButton") != null, '
        '"party_disabled": '
        'hud.get_node("TopButtons/PartyButton").disabled if hud != null else null, '
        '"party_text": hud.get_node("TopButtons/PartyButton").text if hud != null else "", '
        '"party_screen": hud != null and hud.party_screen != null, '
        '"party_open": hud.is_party_screen_open() if hud != null else null, '
        '"party_visible": '
        'hud.party_screen.visible if hud != null and hud.party_screen != null else null, '
        '"party_header": '
        'hud.party_screen.get_header_text() '
        'if hud != null and hud.party_screen != null else "", '
        '"party_registered": mgr.has_screen(&"party") if mgr != null else null, '
        '"counters": '
        'hud.get_counter_count() if hud != null else -1, '
        '"counter_food": hud.get_counter_text(&"food") if hud != null else "", '
        '"carrier_food": str(int(hud.city.resource_ctx.amount(&"food"))) '
        'if hud != null and hud.city != null else "", '
        '"date": hud.get_date_text() if hud != null else "", '
        '"date_expected": CampaignCalendar.date_label('
        's.get_node("GameManager").get_current_day()) '
        'if s.get_node_or_null("GameManager") != null else "", '
        '"day_label": s.get_node_or_null("CanvasLayer/DayLabel") != null, '
        '"bar": hud.get_node_or_null("CounterBar") != null, '
        '"shown": mgr.visible_screens().map(func(id) -> String: return String(id)) '
        'if mgr != null else [], '
        '"turn": comp.campaign.current_turn if comp != null else -1}'
    )


def test_carrier_bound_after_new_game(full_cycle):
    """Полный путь до `main.tscn`: слой поднят, город привязан, кнопка активна, экран закрыт."""
    st = _state(full_cycle)
    assert st["turn"] >= 1, f"кампания не стартовала: {st}"
    assert st["hud"], f"слой носителя отсутствует в main.tscn: {st}"
    assert st["layer"] == 5, f"слой носителя должен быть 5 (над служебными слоями): {st}"
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
    assert st["at"] == "city", f"машина навигации не переведена в город: {st}"
    assert st["shown"] == ["city"], (
        f"инвариант одного активного экрана нарушен: {st}"
    )


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


def test_city_screen_registered_in_campaign_ui_manager(full_cycle):
    """Экран города живёт в машине навигации (указание владельца 2026-10-23).

    Узел экрана по-прежнему строится носителем (`CampaignHud.bind_city`), но
    активным экраном он становится только через `CampaignUIManager`: переходы
    проверяются SM, виден ровно один экран, чужой переход гасит город. До
    регистрации носитель был самостоятельным хостом, и «какой экран сейчас»
    нигде не было.
    """
    st = _state(full_cycle)
    assert st["manager"], f"CampaignUIManager не поднят в main.tscn: {st}"
    assert st["at"] == "map", (
        f"кампания обязана стартовать на карте, а не на {st['at']}: {st}"
    )
    assert st["registered"] is True, f"город не зарегистрирован в машине: {st}"
    assert st["shown"] == [], f"до открытия экрана не должно быть видно: {st}"


def test_party_screen_registered_in_campaign_ui_manager(full_cycle):
    """Экран партии поднят тем же носителем и зарегистрирован в машине (D-227).

    До этого раунда `PartyScreen` был техническим экраном без вызывающего:
    данные партии существовали, входа в них из игры — нет.
    """
    st = _state(full_cycle)
    assert st["party_button"], f"кнопка «Партия» не построена: {st}"
    assert st["party_disabled"] is False, (
        f"кнопка «Партия» обязана стать доступной после привязки ростера: {st}"
    )
    assert st["party_text"] == "Партия", (
        f"подпись кнопки из локали и по глоссарию «Партия» "
        f"(отряд — военная единица города): {st}"
    )
    assert st["party_screen"], f"экран партии не создан при привязке: {st}"
    assert st["party_registered"] is True, f"партия не зарегистрирована в машине: {st}"
    assert st["party_open"] is False and st["party_visible"] is False, (
        f"экран партии не имеет права быть открытым до нажатия: {st}"
    )


def test_button_press_opens_party_screen_with_live_roster(full_cycle):
    """Нажатие «Партия» открывает экран с живым ростером кампании."""
    _press(full_cycle, PARTY_BUTTON)
    st = _state(full_cycle)
    assert st["party_open"] and st["party_visible"], f"экран партии не открылся: {st}"
    assert st["at"] == "party", f"машина навигации не переведена в партию: {st}"
    assert st["shown"] == ["party"], f"инвариант одного активного экрана нарушен: {st}"
    assert st["party_header"] == "Партия: 2/5", (
        f"экран показывает не стартовый ростер кампании (fighter + ranger): {st}"
    )


def test_switching_city_to_party_closes_city_in_live_game(full_cycle):
    """Смена экрана слоя в живом рантайме: город закрывается, а не лежит под партией.

    Машина запрещает `CITY→PARTY`, поэтому носитель идёт через карту — иначе
    игрок, открывший город, не смог бы попасть в партию вообще.
    """
    _press(full_cycle, BUTTON)
    _press(full_cycle, PARTY_BUTTON)
    st = _state(full_cycle)
    assert st["at"] == "party", f"машина не дошла до партии: {st}"
    assert st["open"] is False and st["visible"] is False, (
        f"город не закрылся при переходе в партию: {st}"
    )
    assert st["party_open"] is True, f"партия не открылась из города: {st}"
    assert st["shown"] == ["party"], f"под партией остался видимый экран: {st}"


def test_counter_bar_shows_the_live_campaign_carrier(full_cycle):
    """Полоса счётчиков (7.10) в живом кампейне: значения — из носителя города.

    GdUnit поднимает `main.tscn` тоже, но четвёртый уровень нужен здесь потому,
    что полоса читает `City.resource_ctx` города, собранного игрой (меню →
    создание персонажа → Знак → `main.tscn`), а не город, собранный тестом.
    """
    st = _state(full_cycle)
    assert st["bar"], f"полоса счётчиков не построена: {st}"
    assert st["counters"] == 3, (
        "видимых счётчика ровно три — MVP-триада food/wood/iron; остальным "
        f"строкам реестра нечем показать значение (T-157): {st}"
    )
    assert st["counter_food"] == st["carrier_food"] and st["counter_food"] != "", (
        f"счётчик еды показывает не число носителя: {st}"
    )
    assert st["day_label"] is False, (
        f"служебный DayLabel вернулся — на экране две копии дня: {st}"
    )


def test_date_follows_the_day_in_live_game(full_cycle):
    """Дата макета (7.11) пересчитывается из дня кампании на каждый ход."""
    before = _state(full_cycle)
    assert before["date"] == before["date_expected"] and before["date"] != "", (
        f"дата не равна пересчёту дня кампании: {before}"
    )
    full_cycle.execute_code(
        "get_tree().current_scene._advance_day()\n"
        "return true"
    )
    full_cycle.wait_frames(30)
    after = _state(full_cycle)
    assert after["date"] == after["date_expected"], (
        f"после хода дата разошлась с днём кампании: {after}"
    )
    assert after["date"] != before["date"], (
        f"ход прошёл, а дата стоит на месте: было {before['date']}, "
        f"стало {after['date']}"
    )
