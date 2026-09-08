"""
Профилирование ServiceLocator / ArenaClusterSystem в живой сцене боя.

Сценарий:
  1. Запускаем сцену боя.
  2. Сравниваем время resolve() до и после clear_cache().
  3. Проверяем, что ArenaClusterSystem.reset() не ломает кластеры города.
"""
from __future__ import annotations

import pytest


pytestmark = pytest.mark.asyncio


async def test_service_locator_cache_in_battle_scene(battle_scene):
    """Кэшированный resolve быстрее поиска, clear_cache не ломает возврат узла."""
    mcp = battle_scene

    result = await mcp.execute_code("""
        var sl = load("res://scripts/core/ServiceLocator.gd")

        # Первый resolve — холодный путь (поиск по дереву)
        var t0 = Time.get_ticks_usec()
        var cold = sl.resolve(null, &"units")
        var cold_us = Time.get_ticks_usec() - t0

        # Кэшированный путь
        var t1 = Time.get_ticks_usec()
        var warm1 = sl.resolve(null, &"units")
        for i in 999:
            warm1 = sl.resolve(null, &"units")
        var warm_us_total = Time.get_ticks_usec() - t1

        # После очистки снова находит тот же узел
        sl.clear_cache()
        var rechecked = sl.resolve(null, &"units")

        return {
            "cold_ok": cold != null,
            "warm_ok": warm1 != null,
            "same_node": rechecked == warm1,
            "cold_us": cold_us,
            "warm_avg_us": warm_us_total / 1000.0,
        }
    """)

    assert result["cold_ok"] is True
    assert result["warm_ok"] is True
    assert result["same_node"] is True
    # Кэшированный путь — один или два dictionary-get'а, заметно быстрее поиска.
    assert result["warm_avg_us"] < 10.0


async def test_cluster_reset_in_battle_scene(battle_scene):
    """reset() не крашится в бою и пересчёт кластеров даёт тот же результат."""
    mcp = battle_scene

    result = await mcp.execute_code("""
        var acs = load("res://scripts/city/ArenaClusterSystem.gd")
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
