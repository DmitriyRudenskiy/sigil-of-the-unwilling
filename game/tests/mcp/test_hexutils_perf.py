"""
Тест 3: Производительность — проверка оптимизации HexUtils.get_neighbor.

Сценарий:
  1. Генерируем карту 80×80.
  2. Замеряем время A* пути через всю карту.
  3. Проверяем, что время укладывается в допустимый порог.
  4. Сравниваем с эталонным значением.
"""
from __future__ import annotations

import time




# Допустимое время для A* на карте 80×80 (мс).
# До оптимизации: ~150–300 мс. После: ~80–150 мс.
ASTAR_MAX_TIME_MS = 200.0
MAP_GEN_MAX_TIME_MS = 3000.0


def test_map_generation_80x80(world_scene):
    """Генерация карты 80×80 должна укладываться в лимит."""
    mcp = world_scene

    start = time.perf_counter()
    result = mcp.execute_code("""
        var t0 = Time.get_ticks_msec()
        var model = MapModel.new()
        model.map_width = 80
        model.map_height = 80
        model.seed_value = 42
        model.generate_noise()
        model.smooth_invalid_adjacencies()
        var t1 = Time.get_ticks_msec()
        return {
            "elapsed_ms": t1 - t0,
            "terrain_count": model.terrain_grid.size(),
        }
    """)
    elapsed = time.perf_counter() - start

    assert result["terrain_count"] == 80 * 80, (
        f"Ожидалось {80*80} клеток, получено {result['terrain_count']}"
    )
    assert result["elapsed_ms"] < MAP_GEN_MAX_TIME_MS, (
        f"Генерация карты заняла {result['elapsed_ms']} мс "
        f"(лимит {MAP_GEN_MAX_TIME_MS} мс)"
    )


def test_astar_pathfinding_performance(world_scene):
    """
    A* путь через всю карту 80×80 должен быть быстрым.
    Запускаем 10 итераций и проверяем среднее время.
    """
    mcp = world_scene

    result = mcp.execute_code("""
        var model = MapModel.new()
        model.map_width = 80
        model.map_height = 80
        model.seed_value = 42
        model.generate_noise()
        model.smooth_invalid_adjacencies()

        var start_cell := Vector2i(2, 2)
        var goal_cell := Vector2i(77, 77)

        # Ищем стартовую и конечную проходимые клетки
        while not model.is_walkable(start_cell) and start_cell.x < 78:
            start_cell.x += 1
        while not model.is_walkable(goal_cell) and goal_cell.x > 1:
            goal_cell.x -= 1

        var blocked := model.get_blocked_cells()

        var times: Array[float] = []
        var path_found := false
        for i in 10:
            var t0 := Time.get_ticks_msec()
            var path = HexPathfinding.astar_path(
                start_cell, goal_cell, blocked, 80, 80
            )
            var t1 := Time.get_ticks_msec()
            times.append(float(t1 - t0))
            if path.size() > 0:
                path_found = true

        var avg := 0.0
        for t in times:
            avg += t
        avg /= float(times.size())

        return {
            "path_found": path_found,
            "avg_ms": avg,
            "max_ms": times.max(),
            "min_ms": times.min(),
            "start": {"x": start_cell.x, "y": start_cell.y},
            "goal": {"x": goal_cell.x, "y": goal_cell.y},
        }
    """)

    assert result["path_found"], "A* не нашёл путь через карту 80×80"
    assert result["avg_ms"] < ASTAR_MAX_TIME_MS, (
        f"Среднее время A* = {result['avg_ms']:.1f} мс "
        f"(лимит {ASTAR_MAX_TIME_MS} мс). "
        f"Мин: {result['min_ms']:.1f}, Макс: {result['max_ms']:.1f}"
    )


def test_bfs_reachable_performance(world_scene):
    """BFS-достижимость на карте 80×80 должна быть быстрой."""
    mcp = world_scene

    result = mcp.execute_code("""
        var model = MapModel.new()
        model.map_width = 80
        model.map_height = 80
        model.seed_value = 42
        model.generate_noise()

        var start := Vector2i(40, 40)
        while not model.is_walkable(start):
            start.x += 1

        var blocked := model.get_blocked_cells()

        var t0 := Time.get_ticks_msec()
        var reachable = HexPathfinding.bfs_reachable(start, 15, blocked, 80, 80)
        var t1 := Time.get_ticks_msec()

        return {
            "elapsed_ms": t1 - t0,
            "reachable_count": reachable.size(),
        }
    """)

    assert result["elapsed_ms"] < 500.0, (
        f"BFS занял {result['elapsed_ms']} мс (лимит 500 мс)"
    )
    assert result["reachable_count"] > 0, "BFS не нашёл достижимых клеток"


def test_get_neighbor_no_config_call_overhead(world_scene):
    """
    Проверяем, что get_neighbor не вызывает get_config() каждый раз.
    Кэширование _shift_right должно устранять оверхед.
    """
    mcp = world_scene

    result = mcp.execute_code("""
        var t0 := Time.get_ticks_msec()
        var results := 0
        for i in 100000:
            var cell := Vector2i(i % 80, (i / 80) % 80)
            for bit in 6:
                var nb := HexUtils.get_neighbor(cell, bit)
                results += nb.x + nb.y
        var t1 := Time.get_ticks_msec()
        return {
            "elapsed_ms": t1 - t0,
            "iterations": 600000,
        }
    """)

    # 600 000 вызовов get_neighbor должны занять < 500 мс
    assert result["elapsed_ms"] < 500, (
        f"600K вызовов get_neighbor заняли {result['elapsed_ms']} мс "
        f"(лимит 500 мс). Оптимизация кэширования не работает."
    )
