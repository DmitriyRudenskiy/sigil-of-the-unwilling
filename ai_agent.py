import socket
import json
import time
import argparse
import sys
import math

class GodotClient:
    def __init__(self, host='127.0.0.1', port=9090):
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

def wait_for_movement(client, target_x, target_y, current_idx, total_count, mode, timeout=30):
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
        if state.get("move_points", 1) <= 0:
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
    print("📦 Starting collection process (Limited to 10 turns)...\n")
    
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
            
        target = resources[0]
        client.send_command({"action": "MOVE_TO", "x": target["x"], "y": target["y"]})
        
        result = wait_for_movement(client, target["x"], target["y"], collected_count, total_res, f"Turns:{turn_count}/10")
        if result == "no_mp":
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
    
    challenged_count = 0
    while True:
        state = client.send_command({"action": "GET_STATE"})
        if state["mode"] == "world":
            enemies = state["map_enemies"]
            if not enemies:
                break
            
            target = enemies[0]
            client.send_command({"action": "MOVE_TO", "x": target["x"], "y": target["y"]})
            
            result = wait_for_movement(client, target["x"], target["y"], challenged_count, total_enemies, "Combat")
            if result == "no_mp":
                client.send_command({"action": "END_TURN"})
                time.sleep(0.5)
            elif result == "battle_started":
                time.sleep(0.5)
                client.send_command({"action": "RETREAT"})
                challenged_count += 1
                while True:
                    state = client.send_command({"action": "GET_STATE"})
                    if state["mode"] == "world": 
                        break
                    time.sleep(0.5)
            elif result == "timeout":
                print("\n⚠️ Movement timeout! Trying to end turn...")
                client.send_command({"action": "END_TURN"})
                time.sleep(0.5)
        elif state["mode"] == "battle":
            client.send_command({"action": "RETREAT"})
            time.sleep(1)
        else:
            break

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
