from __future__ import annotations

def test_prune_shards_no_crash(world_scene):
    mcp = world_scene

    result = mcp.execute_code("""
        var world = get_tree().current_scene
        var persistence = world.get_node_or_null("SaveManager")
        # Используем WorldPersistence напрямую через код
        var wp = WorldPersistence.new(null)

        # Создаём 15 шардов с разными датами активности
        var shards := {}
        for i in 15:
            var shard_id := "shard_%d" % i
            shards[shard_id] = {
                "last_active_turn": 100 + i * 10,
                "world": {},
                "cities": [],
                "hero": {},
            }

        # Запускаем обрезку (должна оставить ≤ 10)
        wp._prune_old_shards(shards, 300)

        return {
            "shards_remaining": shards.size(),
            "no_crash": true,
        }
    """)

    assert result["no_crash"], "Краш при обрезке шардов"
    assert result["shards_remaining"] <= 10, (
        f"Ожидалось ≤ 10 шардов после обрезки, "
        f"получено {result['shards_remaining']}"
    )

def test_prune_shards_with_stringname_keys(world_scene):
    mcp = world_scene

    result = mcp.execute_code("""
        var wp = WorldPersistence.new(null)

        # Создаём шарды со StringName-ключами (как в реальной игре)
        var shards := {}
        for i in 12:
            # &() принимает только литералы: StringName из выражения —
            # через неявное приведение String -> StringName.
            var shard_id: StringName = "shard_%d" % i
            shards[shard_id] = {
                "last_active_turn": 50 + i * 5,
                "world": {},
                "cities": [],
                "hero": {},
            }

        # Проверяем, что ключи действительно StringName
        var first_key = shards.keys()[0]
        var is_stringname := first_key is StringName

        # Запускаем обрезку — НЕ ДОЛЖНО быть краша
        wp._prune_old_shards(shards, 200)

        return {
            "is_stringname": is_stringname,
            "shards_remaining": shards.size(),
            "no_crash": true,
        }
    """)

    assert result["is_stringname"], "Ключи должны быть StringName"
    assert result["no_crash"], "Краш при обрезке StringName-шардов"
    assert result["shards_remaining"] <= 10

def test_full_save_load_cycle_with_many_shards(world_scene):
    mcp = world_scene

    result = mcp.execute_code("""
        var world = get_tree().current_scene
        var save_manager = SaveManager.new()

        # Создаём SaveData с большим количеством шардов
        var save_data = SaveData.new()
        save_data.run_seed = 12345
        save_data.date = {"month": 1, "week": 1, "day": 1}
        save_data.hero = {
            "cell": {"x": 10, "y": 10},
            "move_points": 10.0,
            "hero_name": "TestHero",
            "stats": {"attack": 1, "defense": 1, "spell_power": 1, "knowledge": 1},
        }
        save_data.world = {}

        # 12 шардов
        var shards := {}
        for i in 12:
            shards["shard_%d" % i] = {
                "last_active_turn": i * 10,
                "world": {},
                "cities": [],
                "hero": {},
                "date": {"month": 1, "week": 1, "day": 1},
            }
        save_data.shards = shards
        save_data.active_shard_id = &"shard_1"

        # Сохраняем
        var err = save_manager.save_game(save_data)
        if err != SaveManager.SaveError.OK:
            return {"error": "save_failed", "code": err}

        # Загружаем обратно
        var load_result = save_manager.load_game()
        if load_result.get("error") != SaveManager.SaveError.OK:
            return {"error": "load_failed", "msg": load_result.get("message", "")}

        var loaded_data = load_result["data"]
        return {
            "save_ok": true,
            "load_ok": loaded_data != null,
            "run_seed": loaded_data.run_seed if loaded_data else -1,
            "shards_count": loaded_data.shards.size() if loaded_data else 0,
        }
    """)

    assert "error" not in result, f"Ошибка: {result}"
    assert result["save_ok"], "Сохранение не удалось"
    assert result["load_ok"], "Загрузка не удалась"
    assert result["run_seed"] == 12345

    assert result["shards_count"] <= 12

def test_prune_preserves_newest_shards(world_scene):
    mcp = world_scene

    result = mcp.execute_code("""
        var wp = WorldPersistence.new(null)

        var shards := {}
        # Все шарды активны (не старше 50 ходов от current_turn=150),
        # чтобы сработало только правило по количеству (MAX_SHARDS=10),
        # а не правило неактивности — оно бы удалило вообще всё.
        # Шард 0 — самый старый (turn=140), шард 14 — самый новый (turn=154)
        for i in 15:
            shards["shard_%d" % i] = {
                "last_active_turn": 140 + i,
            }

        wp._prune_old_shards(shards, 150)

        # Проверяем, что остались НОВЕЙШИЕ шарды
        var remaining := shards.keys()
        remaining.sort()
        var has_newest := shards.has("shard_14")
        var has_oldest := shards.has("shard_0")

        return {
            "remaining_count": shards.size(),
            "has_newest": has_newest,
            "has_oldest": has_oldest,
        }
    """)

    assert result["remaining_count"] <= 10
    assert result["has_newest"], "Новейший шард должен остаться"
