"""Проводка T-110 (cutover, раунд 6 §3.2): Continue → load_save_state.

Меню: Continue читает кампанийный MVP-слот (MvpSaveManager) и main.tscn
восстанавливает кампанию из сейва (ход, hero_name), а не стартует новую.
"""
from __future__ import annotations

import time


def test_continue_loads_campaign_slot(mcp):
    try:
        mcp.run_scene("res://scenes/main_menu.tscn")
        mcp.wait_ready()

        # Пишем кампанийный слот 1: ход 7, известный герой.
        w = mcp.execute_code(
            "var c = CampaignComposition.from_campaign_config(12345)\n"
            'c.hero_name = "McpContinueHero"\n'
            "for i in 6:\n"
            "    c.advance_turn()\n"
            "var r = MvpSaveManager.save_slot(1, c.build_save_state())\n"
            'return {"ok": r.ok, "msg": r.message, "turn": c.campaign.current_turn}'
        )
        assert w["ok"], f"слот не записан: {w}"
        assert w["turn"] == 7, w

        mcp.execute_code(
            "get_tree().current_scene._on_continue()\nreturn {\"ok\": true}"
        )
        deadline = time.time() + 120
        while time.time() < deadline:
            try:
                r = mcp.execute_code(
                    "var s = get_tree().current_scene\n"
                    'var c = s.get("composition") if s != null and s.get_script() != null else null\n'
                    'return {"ready": c != null and c.campaign.current_turn > 1,\n'
                    '    "turn": c.campaign.current_turn if c != null else -1,\n'
                    '    "hero": c.hero_name if c != null else ""}'
                )
                if r.get("ready"):
                    break
            except Exception:  # noqa: BLE001 — смена сцены блокирует main loop
                pass
            time.sleep(1.0)
        else:
            raise AssertionError("Continue не восстановил кампанию за 120 с")
        assert r["turn"] == 7, f"Continue стартовал новую кампанию: {r}"
        assert r["hero"] == "McpContinueHero", f"hero_name не из сейва: {r}"
    finally:
        mcp.execute_code("MvpSaveManager.delete_slot(1)\nreturn {\"ok\": true}")
