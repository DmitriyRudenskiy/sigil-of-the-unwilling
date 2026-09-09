"""
Граничные сценарий: смена «сессии» через чистку статических кэшей.

Сценарий (в живой мировой сцене):
  1. Собираем город арены с кластером из 4 ферм.
  2. Симулируем новую сессию: Services.clear_session() +
     ArenaClusterSystem.reset() + ResourceIcons.clear_cache().
  3. Проверяем, что пересчёт кластеров даёт тот же результат,
     а resolve() снова находит автозагрузки.
"""
from __future__ import annotations





def test_session_reset_caches(world_scene):
    """Полная чистка кэшей на границе сессии не ломает игровой код."""
    mcp = world_scene

    result = mcp.execute_code("""
        var ri = load("res://scripts/data/ResourceIcons.gd")
        var acs = load("res://scripts/city/ArenaClusterSystem.gd")
        var model = load("res://scripts/city/CityArenaModel.gd")
        var runner = load("res://scripts/city/ArenaTurnRunner.gd")
        var ring = load("res://scripts/city/ArenaRingSystem.gd")
        var defs = load("res://scripts/data/BuildingDefs.gd")
        var hex = load("res://scripts/core/HexUtils.gd")

        # ── Сессия 1: город с кластером из 4 ферм ──
        acs.reset()
        var city = model.make_city()
        var neighbors = hex.get_all_neighbors(ring.center())
        for i in 4:
            var res = runner.place_building(city, defs.farm(), neighbors[i])
            if not res.ok:
                return {"ok": false, "reason": "не удалось построить ферму %d" % i}
        var clusters_before = acs.clusters(city)

        # ── Граница сессии: чистим все статические кэши ──
        Services.clear_session()
        acs.reset()
        ri.clear_cache()

        # ── Сессия 2: пересчёт даёт тот же результат ──
        var clusters_after = acs.clusters(city)
        var units = Services.resolve(&"units")
        var color_stable = ri.get_color(&"gold").a == 1.0
        return {
            "ok": true,
            "clusters_before": clusters_before.size(),
            "clusters_after": clusters_after.size(),
            "units_after_reset": units != null,
            "icons_after_reset": color_stable,
        }
    """)

    assert result["ok"] is True
    assert result["clusters_before"] == 1
    assert result["clusters_after"] == 1
    assert result["units_after_reset"] is True
    assert result["icons_after_reset"] is True
