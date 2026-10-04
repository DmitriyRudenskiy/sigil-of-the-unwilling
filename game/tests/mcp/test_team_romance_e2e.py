"""team-romance-roleplay 6.2–6.4: MCP e2e — романская линия, adult-гейт, ревность/предательство.

Запускается поверх full_cycle (меню → создание персонажа → мир). UI-диалоги
автоматически отключены (TeamDialogScreen.ui_enabled = false) — проверяется
логика интеграции, а не рендер.
"""
from __future__ import annotations

import time

HERO = "get_tree().current_scene.get_hero()"


AFTER_LOAD = """
var world = get_tree().current_scene
var hero = world.get_hero()
if hero == null:
    return {"ready": false}
return {"ready": true}
"""


def _wait_world(mcp, timeout: float = 120.0) -> dict:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            r = mcp.execute_code(AFTER_LOAD, timeout=5.0)
        except Exception:  # noqa: BLE001 — reload: interaction-сервер временно недоступен
            time.sleep(1.0)
            continue
        if r.get("ready"):
            return r
        time.sleep(1.0)
    raise AssertionError("Мир не завершил перезагрузку/ботстлап вовремя")


def _disable_auto_dialogs(mcp) -> None:
    # Экземпляр в группе "team_dialog" (AdventureUI → TeamDialogScreen).
    mcp.execute_code(
        "var screens = get_tree().get_nodes_in_group('team_dialog')\n"
        "for s in screens:\n"
        "    s.ui_enabled = false\n"
        "return {'count': int(screens.size())}\n"
    )


def _add_follower(mcp: object, uid: int, romance: int = 0, trust: int = 50) -> None:
    mcp.execute_code(
        "var hero = %s\n"
        "var f = Follower.new()\n"
        "f.uid = %d\n"
        "f.name = 'E2E_%d'\n"
        "f.gender = 'female' if String(hero.stats_comp.sex) == 'male' else 'male'\n"
        "f.orientation = 'hetero'\n"
        "f.race = 'human'\n"
        "f.path = hero.path_id\n"
        "hero.followers.append(f)\n"
        "hero.relationships.pair(%d)['romance'] = %d\n"
        "hero.relationships.pair(%d)['trust'] = %d\n"
        "return {'ok': true}\n" % (HERO, uid, uid, uid, romance, uid, trust)
    )


def test_romance_line_to_marriage(full_cycle):
    """6.2: рекрут → диалог (bond↑) → друг → роман → помолвка → брак → супруг в наследовании."""
    mcp = full_cycle
    _disable_auto_dialogs(mcp)

    # 1) Следователь совместимой ориентации (определённая настройка;
    #    генерация пола/ориентации при рекруте покрыта unit-тестами).
    _add_follower(mcp, 100)
    r = mcp.execute_code(
        "var hero = %s\n"
        "var f = hero.followers[0]\n"
        "return {'compatible': RelationshipSystem.compatible("
        "String(hero.stats_comp.sex), f.gender, f.orientation)}\n" % HERO
    )
    assert r["compatible"] is True, r

    # 2) Диалог: сцена по стадиям, лучший выбор (bond↑)
    r = mcp.execute_code(
        "var hero = %s\n"
        "var f = hero.followers[0]\n"
        "TeamDialogSystem.load_dialogs()\n"
        "var ctx = TeamDialogSystem.make_context(hero, f)\n"
        "var did = TeamDialogSystem.pick_dialog(ctx)\n"
        "var d = TeamDialogSystem.get_dialog(did)\n"
        "var node: Dictionary = d['nodes'][d['entry']]\n"
        "var choices: Array = TeamDialogSystem.visible_choices(node, ctx, Settings.content_adult)\n"
        "var best: Dictionary = {}\n"
        "for c in choices:\n"
        "    var cd: Dictionary = c\n"
        "    for e in cd.get('effects', []):\n"
        "        if (e is Dictionary) and e.has('bond') and int(e['bond']) > 0:\n"
        "            best = cd\n"
        "TeamDialogSystem.apply_effects(hero, f, best.get('effects', []))\n"
        "return {'dialog': did, 'bond': int(hero.relationships.pair(100)['bond'])}\n" % HERO
    )
    assert r["dialog"] == "talk_stranger", r
    assert r["bond"] > 0, r

    # 3) Друг (bond ≥ 30) → смена сцены диалога
    mcp.execute_code(
        "var hero = %s\n"
        "hero.relationships.pair(100)['bond'] = 31\n"
        "return {'ok': true}\n" % HERO
    )
    r = mcp.execute_code(
        "var hero = %s\n"
        "var f = hero.followers[0]\n"
        "var ctx = TeamDialogSystem.make_context(hero, f)\n"
        "return {'stage': int(ctx['stage']), 'dialog': TeamDialogSystem.pick_dialog(ctx)}\n" % HERO
    )
    assert r["stage"] == 1, r  # STAGE_FRIEND
    assert r["dialog"] == "talk_friend", r

    # 4) Романская линия: flirt (romance ≥ 25)
    mcp.execute_code(
        "var hero = %s\n"
        "hero.relationships.pair(100)['romance'] = 30\n"
        "return {'ok': true}\n" % HERO
    )
    r = mcp.execute_code(
        "var hero = %s\n"
        "var f = hero.followers[0]\n"
        "var ctx = TeamDialogSystem.make_context(hero, f)\n"
        "return {'romance_stage': int(ctx['romance_stage']), 'dialog': TeamDialogSystem.pick_dialog(ctx)}\n" % HERO
    )
    assert r["romance_stage"] == 1, r
    assert r["dialog"] == "romance_flirt", r

    # 5) Помолвка: romance 80 → «Предложить руку» → сцена → confirm → engaged
    mcp.execute_code(
        "var hero = %s\n"
        "hero.relationships.pair(100)['romance'] = 80\n"
        "return {'ok': true}\n" % HERO
    )
    r = mcp.execute_code(
        "var hero = %s\n"
        "var f = hero.followers[0]\n"
        "var ctx = TeamDialogSystem.make_context(hero, f)\n"
        "var d = TeamDialogSystem.get_dialog(TeamDialogSystem.pick_dialog(ctx))\n"
        "var node: Dictionary = d['nodes'][d['entry']]\n"
        "var choices: Array = TeamDialogSystem.visible_choices(node, ctx, Settings.content_adult)\n"
        "var propose: Dictionary = {}\n"
        "for c in choices:\n"
        "    if str((c as Dictionary).get('text', '')).begins_with('Предложить'):\n"
        "        propose = c\n"
        "TeamDialogSystem.apply_effects(hero, f, propose.get('effects', []))\n"
        "return {'pending': int(hero.relationships.pending_scenes.size())}\n" % HERO
    )
    assert r["pending"] == 1, r
    r = mcp.execute_code(
        "var hero = %s\n"
        "var rel = hero.relationships\n"
        "rel.resolve_pending(0, 'confirm')\n"
        "return {'engaged': bool(rel.pair(100)['engaged']), 'pending': int(rel.pending_scenes.size())}\n" % HERO
    )
    assert r["engaged"] is True, r
    assert r["pending"] == 0, r

    # 6) Брак: romance 100 → конец хода → marriage_ready → confirm → spouse
    mcp.execute_code(
        "var hero = %s\n"
        "hero.relationships.pair(100)['romance'] = 100\n"
        "return {'ok': true}\n" % HERO
    )
    mcp.execute_code("get_tree().current_scene.do_end_turn()\nreturn {'ok': true}")
    r = mcp.execute_code(
        "var hero = %s\n"
        "var types: Array = []\n"
        "for s in hero.relationships.pending_scenes:\n"
        "    types.append(str((s as Dictionary).get('type', '')))\n"
        "return {'types': types}\n" % HERO
    )
    assert "marriage" in r["types"], r
    mcp.execute_code(
        "var hero = %s\n"
        "var rel = hero.relationships\n"
        "for i in range(rel.pending_scenes.size()):\n"
        "    if str((rel.pending_scenes[i] as Dictionary).get('type', '')) == 'marriage':\n"
        "        rel.resolve_pending(i, 'confirm')\n"
        "        break\n"
        "return {'ok': true}\n" % HERO
    )
    r = mcp.execute_code(
        "var hero = %s\n"
        "var p: Dictionary = hero.relationships.pair(100)\n"
        "return {'spouse': bool(p['spouse']), 'romance': int(p['romance'])}\n" % HERO
    )
    assert r["spouse"] is True, r
    assert r["romance"] == 100, r

    # 7) Супруг — приоритет в наследовании
    r = mcp.execute_code(
        "var hero = %s\n"
        "var succ = SuccessionController.new()\n"
        "var chosen = succ.select_successor(hero)\n"
        "return {'chosen_uid': int(chosen.uid) if chosen != null else -1}\n" % HERO
    )
    assert r["chosen_uid"] == 100, r


def test_adult_gate(full_cycle):
    """6.3: content_adult off → adult-вариант скрыт (pg_fallback), on → виден."""
    mcp = full_cycle
    _disable_auto_dialogs(mcp)
    _add_follower(mcp, 200, romance=30)

    def _flirt_choices() -> dict:
        return mcp.execute_code(
            "var hero = %s\n"
            "var f = hero.followers[0]\n"
            "var ctx = TeamDialogSystem.make_context(hero, f)\n"
            "var d = TeamDialogSystem.get_dialog('romance_flirt')\n"
            "var node: Dictionary = d['nodes'][d['entry']]\n"
            "var visible: Array = TeamDialogSystem.visible_choices(node, ctx, Settings.content_adult)\n"
            "var texts: Array = []\n"
            "for c in visible:\n"
            "    texts.append(str((c as Dictionary).get('text', '')))\n"
            "return {'count': int(visible.size()), 'texts': texts}\n" % HERO
        )

    # romance_flirt n1: 2 pg-варианта + 1 adult (cond: orientation_compatible)
    mcp.execute_code("Settings.content_adult = false\nreturn {'ok': true}")
    r = _flirt_choices()
    assert r["count"] == 3, r
    joined = " | ".join(r["texts"])
    assert "(18+)" not in joined, r  # adult-текст скрыт
    assert "взгляд, полный обещаний" in joined, r  # pg_fallback на месте

    mcp.execute_code("Settings.content_adult = true\nreturn {'ok': true}")
    r = _flirt_choices()
    assert r["count"] == 3, r
    assert "(18+)" in " | ".join(r["texts"]), r  # adult-вариант виден

    # pg_fallback применяется вместо adult: эффекты fallback {romance: 12, bond: 6}
    mcp.execute_code("Settings.content_adult = false\nreturn {'ok': true}")
    r = mcp.execute_code(
        "var hero = %s\n"
        "var f = hero.followers[0]\n"
        "var ctx = TeamDialogSystem.make_context(hero, f)\n"
        "var d = TeamDialogSystem.get_dialog('romance_flirt')\n"
        "var node: Dictionary = d['nodes'][d['entry']]\n"
        "var visible: Array = TeamDialogSystem.visible_choices(node, ctx, Settings.content_adult)\n"
        "var fb: Dictionary = {}\n"
        "for c in visible:\n"
        "    if str((c as Dictionary).get('text', '')).contains('обещаний'):\n"
        "        fb = c\n"
        "TeamDialogSystem.apply_effects(hero, f, fb.get('effects', []))\n"
        "var p: Dictionary = hero.relationships.pair(200)\n"
        "return {'romance': int(p['romance']), 'trust': int(p['trust'])}\n" % HERO
    )
    assert r["romance"] == 42, r  # 30 + 12 (эффекты pg_fallback)
    assert r["trust"] == 50, r  # trust не меняется
    mcp.execute_code("Settings.content_adult = false\nreturn {'ok': true}")


def test_jealousy_and_betrayal(full_cycle):
    """6.4: ревность дьюо (оба romance ≥ 50, trust −15, одна сцена) и предательство (trust < 20)."""
    mcp = full_cycle
    _disable_auto_dialogs(mcp)
    _add_follower(mcp, 300, romance=55)
    _add_follower(mcp, 301, romance=55)

    # Ход 1: ревность дьюо (оба romance ≥ 50) — trust −15 обоим, ОДНА сцена на дьюо
    mcp.execute_code("get_tree().current_scene.do_end_turn()\nreturn {'ok': true}")
    r = mcp.execute_code(
        "var hero = %s\n"
        "var rel = hero.relationships\n"
        "var types: Array = []\n"
        "for s in rel.pending_scenes:\n"
        "    types.append(str((s as Dictionary).get('type', '')))\n"
        "return {'t300': int(rel.pair(300)['trust']), 't301': int(rel.pair(301)['trust']), 'types': types}\n" % HERO
    )
    assert r["t300"] == 35, r  # 50 − 15 (JEALOUSY_TRUST_PENALTY)
    assert r["t301"] == 35, r
    assert r["types"].count("jealousy") == 1, r

    # Сцена ревности разрешена ЯВНО: иначе _auto_resolve_stale_scenes() в следующем
    # end_turn() применит дефолт "soothe" → trust +5 ДО проверки верности, и
    # «trust 0 → гарантированное предательство» перестаёт быть детерминированным
    # (roll 1..20 > 5 = 75%, баг-тикет T-119, 2026-10-04).
    mcp.execute_code(
        "var hero = %s\n"
        "hero.relationships.resolve_pending(0, 'soothe')\n"
        "return {'ok': true}\n" % HERO
    )

    # Ход 2: trust 0 у 300 → гарантированное предательство (roll 1..20 > 0)
    mcp.execute_code(
        "var hero = %s\n"
        "hero.relationships.pair(300)['trust'] = 0\n"
        "return {'ok': true}\n" % HERO
    )
    mcp.execute_code("get_tree().current_scene.do_end_turn()\nreturn {'ok': true}")
    r = mcp.execute_code(
        "var hero = %s\n"
        "var present = false\n"
        "for f in hero.followers:\n"
        "    if int(f.uid) == 300:\n"
        "        present = true\n"
        "return {'present': present, 'pair_removed': not hero.relationships.has_pair(300)}\n" % HERO
    )
    assert r["present"] is False, r
    assert r["pair_removed"] is True, r


def test_save_load_relationships(full_game):
    """6.5: сейв/загрузка сохраняет отношения (pair, engaged, pending-сцены)."""
    mcp = full_game
    _add_follower(mcp, 400, romance=62, trust=37)
    mcp.execute_code(
        "var hero = %s\n"
        "hero.relationships.pair(400)['bond'] = 45\n"
        "hero.relationships.pair(400)['engaged'] = true\n"
        "hero.relationships.pending_scenes.append({'type': 'jealousy', 'uid': 400, 'uid_b': 401})\n"
        "return {'ok': true}\n" % HERO
    )

    saved = mcp.execute_code("return get_tree().current_scene.save_game()")
    assert saved is True, f"save_game() не вернул true: {saved}"

    # Мутация после сейва — должна откатиться при загрузке
    mcp.execute_code(
        "var hero = %s\n"
        "hero.relationships.pair(400)['romance'] = 0\n"
        "return {'ok': true}\n" % HERO
    )

    mcp.execute_code(
        "var world = get_tree().current_scene\n"
        "world.call_deferred('request_load_game')\n"
        "return {'requested': true}"
    )
    r = _wait_world(mcp)
    assert r["ready"] is True, r

    r = mcp.execute_code(
        "var hero = get_tree().current_scene.get_hero()\n"
        "var p: Dictionary = hero.relationships.pair(400)\n"
        "return {'romance': int(p['romance']), 'trust': int(p['trust']), "
        "'bond': int(p['bond']), 'engaged': bool(p['engaged']), "
        "'pending': int(hero.relationships.pending_scenes.size())}\n"
    )
    assert r["romance"] == 62, r  # откатилось к моменту сейва
    assert r["trust"] == 37, r
    assert r["bond"] == 45, r
    assert r["engaged"] is True, r
    assert r["pending"] == 1, r
