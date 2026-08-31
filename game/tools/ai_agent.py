import socket
import json
import time
import argparse
import sys
import math

class GodotClient:
    def __init__(self, host='127.0.0.1', port=9095):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            self.sock.connect((host, port))
        except ConnectionRefusedError:
            print("❌ Could not connect to Godot server. Is the game running?")
            sys.exit(1)
        self.buffer = ""

    def send_command(self, cmd):
        self.sock.sendall((json.dumps(cmd) + "\n").encode('utf-8'))
        while "\n" not in self.buffer:
            data = self.sock.recv(4096).decode('utf-8')
            if not data:
                raise ConnectionError("Server disconnected")
            self.buffer += data
        
        idx = self.buffer.find("\n")
        resp_str = self.buffer[:idx]
        self.buffer = self.buffer[idx+1:]
        return json.loads(resp_str)

def print_status(current, total, target, pos, mode="Resources"):
    percent = (current / total) * 100 if total > 0 else 0
    bar_len = 20
    filled_len = int(bar_len * current // total) if total > 0 else 0
    bar = "█" * filled_len + "-" * (bar_len - filled_len)
    
    status = f"\r🚀 [{mode}] {bar} {percent:.1f}% | Pos: {pos} | Target: {target} | {current}/{total}"
    sys.stdout.write(status)
    sys.stdout.flush()

def hex_dist(p1, p2):
    """Calculates the distance between two hex cells in odd-r offset coordinates."""
    def offset_to_cube(p):
        x = p[0] - (p[1] - (p[1] & 1)) // 2
        z = p[1]
        y = -x - z
        return (x, y, z)
    
    c1 = offset_to_cube(p1)
    c2 = offset_to_cube(p2)
    return max(abs(c1[0] - c2[0]), abs(c1[1] - c2[1]), abs(c1[2] - c2[2]))

def calculate_avg_distance(points):
    if len(points) < 2:
        return 0.0
    total_dist = 0
    count = 0
    for i in range(len(points)):
        for j in range(i + 1, len(points)):
            total_dist += hex_dist(points[i], points[j])
            count += 1
    return total_dist / count

def wait_for_movement(client, target_x, target_y, current_idx, total_count, mode, will_reach=True, timeout=60):
    """Ждём завершения движения.
    will_reach=True  → ждём прибытия на целевую клетку.
    will_reach=False → частичное движение: герой идёт в сторону цели
                       и остановится сам (moving == false) — ждём остановки,
                       а не прибытия (баг "Movement timeout": 30с ожидания).
    Возвращает: arrived | stopped | no_mp | battle_started | unknown_mode | timeout
    """
    start_time = time.time()
    while True:
        elapsed = time.time() - start_time
        if elapsed > timeout:
            return "timeout"

        state = client.send_command({"action": "GET_STATE"})
        hero_pos = state.get("hero_pos", {"x": 0, "y": 0})

        print_status(current_idx, total_count, f"({target_x},{target_y})", f"({hero_pos['x']},{hero_pos['y']})", mode)

        if state["mode"] == "battle":
            return "battle_started"
        if state["mode"] != "world":
            return "unknown_mode"
        if hero_pos["x"] == target_x and hero_pos["y"] == target_y:
            return "arrived"
        if not state.get("moving", False):
            # Герой стоит: либо вышагал ОД (частичное движение), либо уже был на месте
            if not will_reach:
                return "stopped"
            if state.get("move_points", 1) <= 0:
                return "no_mp"
            # will_reach=True, но герой стоит и ОД есть — движок не запустил шаг;
            # дальше ждать бессмысленно
            return "stopped"
        if state.get("move_points", 1) <= 0 and not state.get("moving", False):
            return "no_mp"
        time.sleep(0.2)

def task1_collect_resources(client):
    print("\n--- 🎯 TASK 1: Full Map Resource Sweep & Analytics ---")
    
    print("🎮 Starting game world...")
    client.send_command({"action": "START_GAME"})
    time.sleep(2)
    
    state = client.send_command({"action": "GET_STATE"})
    if state["mode"] != "world":
        print(f"\nError: Game is in mode {state.get('mode', 'unknown')}, but world mode is required!")
        return
        
    initial_resources = state["basic_resources"]
    all_resources = state["map_resources"]
    total_res = len(all_resources)
    
    print(f"📊 TOTAL RESOURCE POINTS FOUND: {total_res}")
    coords = [(r['x'], r['y']) for r in all_resources]
    avg_dist = calculate_avg_distance(coords)
    print(f"📏 Average distance between resources: {avg_dist:.2f} hexes")
    print(f"📦 Starting collection process (Limited to 10 turns)...\n")
    
    collected_count = 0
    turn_count = 1
    while True:
        state = client.send_command({"action": "GET_STATE"})
        if state["mode"] != "world": 
            if state["mode"] == "battle":
                client.send_command({"action": "RETREAT"})
                time.sleep(1)
            continue
            
        resources = state["map_resources"]
        if not resources:
            break

        hero_pos = state.get("hero_pos", {"x": 0, "y": 0})
        resources.sort(key=lambda r: hex_dist((hero_pos["x"], hero_pos["y"]), (r["x"], r["y"])))
        target = resources[0]
        resp = client.send_command({"action": "MOVE_TO", "x": target["x"], "y": target["y"]})
        if resp.get("status") == "already_at":
            collected_count += 1
            time.sleep(0.2)
            continue
        if "error" in resp:
            print(f"\n⚠️ MOVE_TO error: {resp['error']}")
            # error = пути нет вообще (не только не хватает ОД). Сменим цель.
            if turn_count >= 10:
                print(f"\n🛑 Reached turn limit (10). Stopping collection.")
                break
            client.send_command({"action": "END_TURN"})
            turn_count += 1
            time.sleep(0.5)
            continue

        will_reach = resp.get("will_reach", True)
        result = wait_for_movement(client, target["x"], target["y"], collected_count, total_res, f"Turns:{turn_count}/10", will_reach=will_reach)
        if result in ("no_mp", "stopped"):
            # Герой сближался с целью и остановился (ОД кончились).
            if not will_reach:
                print(f"\n...partial walk on turn {turn_count}: hero stopped short, ending turn.")
            if turn_count >= 10:
                print(f"\n🛑 Reached turn limit (10). Stopping collection.")
                break
            client.send_command({"action": "END_TURN"})
            turn_count += 1
            time.sleep(0.5)
        elif result == "arrived":
            collected_count += 1
            time.sleep(0.2)
        elif result == "battle_started":
            client.send_command({"action": "RETREAT"})
            time.sleep(1)
        elif result == "timeout":
            print(f"\n⚠️ Movement timeout on turn {turn_count}! Trying to end turn...")
            if turn_count >= 10:
                break
            client.send_command({"action": "END_TURN"})
            turn_count += 1
            time.sleep(0.5)
            
    print(f"\n✅ Process stopped after {turn_count} turns.")
    final_state = client.send_command({"action": "GET_STATE"})
    final_resources = final_state["basic_resources"]
    print(f"\n🏁 FINAL RESOURCE COUNT VERIFICATION:")
    print(f"Initial: {initial_resources}")
    print(f"Final:   {final_resources}")
    
    # Calculate delta
    diff = {k: final_resources.get(k, 0) - initial_resources.get(k, 0) for k in final_resources}
    collected = {k: v for k, v in diff.items() if v > 0}
    print(f"Collected during 10 turns: {collected}")
    print(f"Strategic resources: {final_state['strategic_resources']}")

def task2_challenge_and_flee(client):
    print("\n--- ⚔️ TASK 2: Full Map Monster Challenge & Analytics ---")
    
    print("🎮 Starting game world...")
    client.send_command({"action": "START_GAME"})
    time.sleep(2)
    
    state = client.send_command({"action": "GET_STATE"})
    if state["mode"] != "world":
        print(f"\nError: Game is in mode {state.get('mode', 'unknown')}, but world mode is required!")
        return
        
    all_enemies = state["map_enemies"]
    total_enemies = len(all_enemies)
    
    print(f"📊 TOTAL ENEMY STACKS FOUND: {total_enemies}")
    coords = [(e['x'], e['y']) for e in all_enemies]
    avg_dist = calculate_avg_distance(coords)
    print(f"📏 Average distance between enemies: {avg_dist:.2f} hexes")
    print("🛡️ Starting challenge process...\n")
    
    challenged = set()      # координаты врагов, с которыми уже сражались
    # (RETREAT не удаляет врага с карты — без этого агент зацикливается на ближайшем)
    challenged_count = 0
    max_iterations = 500    # защита от бесконечного цикла
    iterations = 0
    stuck_target = None     # цель, к которой путь не строится
    stuck_count = 0         # сколько ходов подряд MOVE_TO по ней ошибался
    noskip_target = None    # цель «вплотную»: герой не двигается и бой не стартует
    noskip_count = 0
    while iterations < max_iterations:
        iterations += 1
        state = client.send_command({"action": "GET_STATE"})
        if state["mode"] == "battle":
            # Бой мог начаться самопроизвольно (контакт при движении) — отступаем.
            client.send_command({"action": "RETREAT"})
            time.sleep(1)
            continue
        if state["mode"] != "world":
            break

        enemies = state["map_enemies"]
        remaining = [e for e in enemies if (e["x"], e["y"]) not in challenged]
        if not remaining:
            break

        hero_pos = state.get("hero_pos", {"x": 0, "y": 0})
        remaining.sort(key=lambda e: hex_dist((hero_pos["x"], hero_pos["y"]), (e["x"], e["y"])))
        target = remaining[0]
        move_resp = client.send_command({"action": "MOVE_TO", "x": target["x"], "y": target["y"]})
        if move_resp.get("status") == "already_at":
            # Герой стоит на клетке врага (остаточное состояние) — считаем контакт.
            challenged.add((target["x"], target["y"]))
            time.sleep(0.5)
            continue
        if "error" in move_resp:
            print(f"\n⚠️ MOVE_TO error: {move_resp['error']}")
            key = (target["x"], target["y"])
            stuck_count = stuck_count + 1 if stuck_target == key else 1
            stuck_target = key
            if stuck_count >= 3:
                # Три хода подряд нет пути — цель недостижима (например, враг на
                # недосягаемой высоте/острове). Пропускаем, чтобы не сжигать все
                # 500 итераций.
                print(f"⏭️  Enemy {key} unreachable for {stuck_count} turns — skipping")
                challenged.add(key)
                stuck_target, stuck_count = None, 0
            client.send_command({"action": "END_TURN"})
            time.sleep(0.5)
            continue

        # Путь построен — счётчики «застрявших» целей сбрасываются.
        stuck_target, stuck_count = None, 0
        noskip_target, noskip_count = None, 0
        will_reach = move_resp.get("will_reach", True)
        result = wait_for_movement(client, target["x"], target["y"], challenged_count, total_enemies, "Combat", will_reach=will_reach)
        if result in ("no_mp", "stopped"):
            if result == "stopped":
                # Герой не сдвинулся с места (стоял вплотную к врагу, но бой не
                # стартовал — вырожденное состояние, напр. пустая армия: бой
                # заканчивается мгновенно до появления battle-режима). Три раза
                # подряд — пропускаем цель, иначе упрёмся в 500 итераций.
                now = client.send_command({"action": "GET_STATE"})
                np = (now["hero_pos"]["x"], now["hero_pos"]["y"])
                key = (target["x"], target["y"])
                noskip_count = noskip_count + 1 if (np == (hero_pos["x"], hero_pos["y"]) and noskip_target == key) else 1
                noskip_target = key
                if noskip_count >= 3:
                    print(f"⏭️  Enemy {key}: hero stuck adjacent, no battle — skipping")
                    challenged.add(key)
                    noskip_target, noskip_count = None, 0
            # Hero closed in but stopped short of the enemy (MP spent).
            # End turn, resume approach next turn → eventually adjacent → battle.
            client.send_command({"action": "END_TURN"})
            time.sleep(0.5)
        elif result == "battle_started":
            # Контакт с врагом: бой начался.
            # При отступлении армия сохраняется, но вражеский стек остаётся на карте.
            # Поэтому помечаем цель, чтобы не атаковать её повторно (иначе агент
            # зациклится на ближайшем враге).
            challenged.add((target["x"], target["y"]))
            challenged_count += 1
            print(f"\n⚔️ Battle {challenged_count}/{total_enemies} with enemy at ({target['x']},{target['y']}) — retreating...")
            time.sleep(0.5)
            # Отступление из боя: шлём RETREAT; на сервере executor принимает его
            # только в WAITING_INPUT (на старте боя думает ИИ) — поэтому ретраем
            # в цикле. Если бой завис (напр. SCRIPT ERROR во view-слое) — после
            # 30с эскалируем в FORCE_RETREAT.
            got_world = False
            for _ in range(60):  # до 30с
                client.send_command({"action": "RETREAT"})
                if client.send_command({"action": "GET_STATE"})["mode"] == "world":
                    got_world = True
                    break
                time.sleep(0.5)
            if not got_world:
                print("\n⚠️ RETREAT not processed for 30s — escalating to FORCE_RETREAT")
                client.send_command({"action": "FORCE_RETREAT"})
                for _ in range(10):  # до 5с на аварийный выход
                    if client.send_command({"action": "GET_STATE"})["mode"] == "world":
                        break
                    time.sleep(0.5)
                else:
                    print("⚠️ FORCE_RETREAT did not help — battle stuck, aborting scenario")
            # Контактный бой мог начаться не с запланированной цели, а со СМЕЖНЫМ
            # врагом (путь героя проходит через контактную клетку). После
            # отступления герой стоит на pre-battle клетке — в 1 клетке от
            # РЕАЛЬНОГО противника. Помечаем всех врагов в радиусе 2, чтобы не
            # зациклиться на неучтённом.
            post_state = client.send_command({"action": "GET_STATE"})
            if post_state.get("mode") == "world":
                hp = post_state.get("hero_pos", {"x": 0, "y": 0})
                for e in post_state.get("map_enemies", []):
                    ek = (e["x"], e["y"])
                    if ek not in challenged and hex_dist((hp["x"], hp["y"]), ek) <= 2:
                        challenged.add(ek)
                        print(f"🏁 Enemy {ek} marked processed (contact battle)")
        elif result == "arrived":
            # Герой стоит вплотную к врагу, но бой не стартовал (крайний случай) —
            # помечаем, чтобы не зациклиться.
            challenged.add((target["x"], target["y"]))
            challenged_count += 1
            print(f"\n⚠️ Arrived at enemy ({target['x']},{target['y']}) but no battle started — marking processed.")
            time.sleep(0.5)
        elif result == "timeout":
            print("\n⚠️ Movement timeout! Trying to end turn...")
            client.send_command({"action": "END_TURN"})
            time.sleep(0.5)

    if iterations >= max_iterations:
        print(f"\n⚠️ Reached max iterations ({max_iterations}) — stopping challenge process")

    print("\n✅ All monsters on the map have been challenged and cleared!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Godot AI Agent")
    parser.add_argument("--scenario", type=int, choices=[1, 2], help="Scenario to run: 1-Resources, 2-Combat")
    args = parser.parse_args()

    if args.scenario is None:
        print("❌ Please specify a scenario: python3 ai_agent.py --scenario [1|2]")
        sys.exit(1)

    print(f"Connecting to Godot TCP Server... Scenario: {args.scenario}")
    client = GodotClient()
    try:
        if args.scenario == 1:
            task1_collect_resources(client)
        elif args.scenario == 2:
            task2_challenge_and_flee(client)
        print("\n🎉 SCENARIO COMPLETED SUCCESSFULLY!")
    except Exception as e:
        print(f"\n❌ Error: {e}")
    finally:
        client.sock.close()
