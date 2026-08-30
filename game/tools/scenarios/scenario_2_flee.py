import socket
import struct
import json
import sys

def send_cmd(sock, cmd, args=None, cmd_id=0):
    if args is None: args = {}
    payload = json.dumps({"id": cmd_id, "cmd": cmd, "args": args}).encode('utf-8')
    header = struct.pack('<I', len(payload))
    sock.sendall(header + payload)
    
    # Read response header
    sock.settimeout(5.0)
    header_data = sock.recv(4)
    if not header_data: return None
    length = struct.unpack('<I', header_data)[0]
    
    body_data = b""
    while len(body_data) < length:
        chunk = sock.recv(length - len(body_data))
        if not chunk: break
        body_data += chunk
        
    return json.loads(body_data.decode('utf-8'))

def run_scenario(seed):
    print(f"--- Running Scenario 2 (Flee) with Seed: {seed} ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('localhost', 9080))
    
    # 1. New Game
    send_cmd(sock, "new_game", {"seed": seed})
    
    # 2. Get Monsters
    objs = send_cmd(sock, "get_map_objects", {"types": ["monster"]})["result"]
    monsters = objs["monster"]
    M = len(monsters)
    print(f"Monsters to challenge: {M}")
    
    fled_count = 0
    for m in monsters:
        pos = m["pos"]
        # Move to monster (instant for test)
        send_cmd(sock, "move_to", {"x": pos[0], "y": pos[1], "instant": True})
        
        # Challenge
        challenge_resp = send_cmd(sock, "challenge")
        if not challenge_resp["ok"]:
            print(f"Failed to challenge at {pos}: {challenge_resp['error']}")
            continue
            
        # Verify battle state
        battle_state = send_cmd(sock, "get_battle_state")["result"]
        if "phase" not in battle_state:
            print(f"Battle didn't start at {pos}")
            continue
            
        # Retreat
        send_cmd(sock, "battle_retreat")
        
        state = send_cmd(sock, "get_state")["result"]
        fled_count = state["battles_fled"]
        print(f"Fled {fled_count}/{M}...")

    # Final check
    state = send_cmd(sock, "get_state")["result"]
    if state["battles_fled"] == M:
        print("✅ Scenario 2 SUCCESS")
        sock.close()
        return True
    else:
        print(f"❌ Scenario 2 FAILED: Fled {state['battles_fled']}/{M}")
        sock.close()
        return False

if __name__ == "__main__":
    seeds = [1234, 777, 2025]
    all_passed = True
    for s in seeds:
        if not run_scenario(s):
            all_passed = False
    
    if not all_passed:
        sys.exit(1)
