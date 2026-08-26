extends SceneTree
## test_socket_protocol.gd - Round-trip framing test

func _init() -> void:
	print("🧪 Testing Socket Protocol Framing...")
	var SocketControllerScript = load("res://scripts/SocketController.gd")
	var controller = SocketControllerScript.new()
	
	# Test decode_u32
	var len_bytes := PackedByteArray([0x05, 0x00, 0x00, 0x00])
	var len: int = controller._decode_u32(len_bytes)
	if len == 5:
		print("✅ decode_u32 passed")
	else:
		print("❌ decode_u32 failed: got %d" % len)

	# Test encode_u32
	var enc_bytes: PackedByteArray = controller._encode_u32(1234)
	if enc_bytes[0] == 0x42 and enc_bytes[1] == 0x04: # 1234 = 0x04D2. Wait, 1234 is 0x4D2. 
		# 1234 / 256 = 4, rem 210 (0xD2). So [0xD2, 0x04, 0x00, 0x00]
		pass
	
	# Proper check for 1234
	var expected := PackedByteArray([0xD2, 0x04, 0x00, 0x00])
	if enc_bytes == expected:
		print("✅ encode_u32 passed")
	else:
		print("❌ encode_u32 failed: got %s" % str(enc_bytes))

	# Test JSON roundtrip
	var req := {"id": 1, "cmd": "ping", "args": {}}
	var json_str := JSON.stringify(req)
	var body := json_str.to_utf8_buffer()
	var header: PackedByteArray = controller._encode_u32(body.size())
	
	var packet: PackedByteArray = header + body
	var read_len: int = controller._decode_u32(packet.slice(0, 4))
	var read_body: String = packet.slice(4, 4 + read_len).get_string_from_utf8()
	var read_json: Variant = JSON.parse_string(read_body)
	
	if read_json == req:
		print("✅ JSON roundtrip passed")
	else:
		print("❌ JSON roundtrip failed")

	quit()
