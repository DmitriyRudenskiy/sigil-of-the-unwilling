from __future__ import annotations

def test_extraction_strict_and(world_scene):
    mcp = world_scene

    setup = mcp.execute_code("""
        var world = get_tree().current_scene
        var rnm = world.get_node_or_null("ResourceNodeManager")
        if rnm == null:
            return {"error": "ResourceNodeManager not found"}
        var cell = Vector2i(15, 15)
        var node = rnm._spawn_node(cell, &"saltpeter", 5)
        node.discover()
        var nm = load("res://scripts/world/ResourceNodeManager.gd")
        return {
            "key_missing": int(nm.NodeError.EXTRACTION_KEY_MISSING),
            "cell": {"x": cell.x, "y": cell.y},
        }
    """)
    assert "error" not in setup, f"Setup failed: {setup}"
    cell = setup["cell"]
    KEY_MISSING = setup["key_missing"]

    r1 = mcp.execute_code(f"""
        var rnm = get_tree().current_scene.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}), {{}})
        return {{"code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert r1["code"] == KEY_MISSING
    assert r1["amount"] == 0

    r2 = mcp.execute_code(f"""
        var rnm = get_tree().current_scene.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}), {{"geology": 1}})
        return {{"code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert r2["code"] == KEY_MISSING

    r3 = mcp.execute_code(f"""
        var rnm = get_tree().current_scene.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}),
            {{"geology": 1, "worker": true}})
        return {{"code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert r3["code"] == KEY_MISSING

    r4 = mcp.execute_code(f"""
        var rnm = get_tree().current_scene.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}),
            {{"geology": 1, "worker": true, "skin_protection": true}})
        return {{"code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert r4["code"] == 0
    assert r4["amount"] > 0
