import socket
import struct
import json
import sys
import time

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
    
    # Read response body
    body_data = b""
    while len(body_data) < length:
        chunk = sock.recv(length - len(body_data))
        if not chunk: break
        body_data += chunk
        
    return json.loads(body_data.decode('utf-8'))

def run_scenario(seed):
    print(f"--- Running Scenario 1 (Collect) with Seed: {seed} ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('localhost', 9080))
    
    # 1. New Game
    resp = send_cmd(sock, "new_game", {"seed": seed})
    print(f"New Game: {resp}")
    
    # 2. Debug Unlock
    send_cmd(sock, "debug_unlock_all")
    
    # 3. Get Targets
    objs = send_cmd(sock, "get_map_objects")["result"]
    nodes = objs["node"]
    monsters = objs["monster"] # Monsters are not collectibles, but good to know
    
    total_targets = len(nodes)
    print(f"Targets to collect: {total_targets}")
    
    collected_count = 0
    targets_remaining = list(nodes)
    
    while targets_remaining:
        target = targets_remaining[0]
        pos = target["pos"]
        
        # Move to target
        # We use instant:true for testing efficiency as per addendum
        move_resp = send_cmd(sock, "move_to", {"x": pos[0], "y": pos[1], "instant": True})
        
        # Collect
        collect_resp = send_cmd(sock, "collect_here")
        
        # Verify if collected
        state = send_cmd(sock, "get_state")["result"]
        collected_count = state["collected"]["total"]
        
        # If we are at the cell and it's a node, we assume it's collected
        targets_remaining.pop(0)
        print(f"Collected {collected_count}/{total_targets}...")

    # Final check
    state = send_cmd(sock, "get_state")["result"]
    if state["collected"]["total"] >= total_targets:
        print("✅ Scenario 1 SUCCESS")
        sock.close()
        return True
    else:
        print(f"❌ Scenario 1 FAILED: Collected {state['collected']['total']}/{total_targets}")
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
