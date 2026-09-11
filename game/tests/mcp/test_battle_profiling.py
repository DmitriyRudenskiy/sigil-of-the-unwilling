from __future__ import annotations

import pytest

def test_cluster_reset_in_battle_scene(battle_scene):
    mcp = battle_scene

    result = mcp.execute_code("""
        var acs = ArenaClusterSystem
        var world = get_tree().current_scene
        var cities_node = world.get_node_or_null("Cities")
        if cities_node == null:
            return {"skipped": true, "reason": "нет узлов городов в сцене боя"}
        # Ищем первый город и считаем кластеры до/после reset
        var city = null
        for c in cities_node.cities:
            city = c
            break
        if city == null:
            return {"skipped": true, "reason": "городов нет"}
        var before = acs.clusters(city)
        acs.reset()
        var after = acs.clusters(city)
        return {
            "skipped": false,
            "before": before.size(),
            "after": after.size(),
            "stable": before.size() == after.size(),
        }
    """)

    if result.get("skipped"):
        pytest.skip(result.get("reason", "сценарий не применим"))
    assert result["stable"] is True
