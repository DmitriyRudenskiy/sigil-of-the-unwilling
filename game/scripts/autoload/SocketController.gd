extends Node

const MAX_BUFFER_SIZE := 1_048_576  # 1 MB per client
const MAX_LINE_SIZE := 65_536  # 64 KB per command
const IDLE_TIMEOUT_SEC := 30.0
const BattleSpellBridge = preload("res://scripts/data/BattleSpellBridge.gd")

var server: TCPServer
# Cached controllers — avoid O(n) full tree walk on every request
var _world_ctrl_cache: Node = null
var _battle_ctrl_cache: Node = null
var _world_ctrl_script: Script = null
var _battle_ctrl_script: Script = null
var peers: Array[StreamPeerTCP] = []
var buffers: Dictionary = {}
var _last_activity: Dictionary = {}  # peer -> unix timestamp

# --- Метрики производительности ---
const SLOW_THRESHOLD_MS := 50.0  # порог "медленного" запроса
var _request_count: int = 0
var _total_time_ms: float = 0.0
var _slow_count: int = 0

func _ready():
	server = TCPServer.new()
	var err = server.listen(9095)
	if err == OK:
		GameLogger.info("✅ Listening on 127.0.0.1:9095", "SocketServer")
	else:
		GameLogger.error("❌ Failed to listen: %s" % err, "SocketServer")

	# Invalidate controller cache on scene tree changes (RF-07)
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)

func _on_tree_changed(_node: Node) -> void:
	_world_ctrl_cache = null
	_battle_ctrl_cache = null

func _process(_delta):
	# Accept new connections
	if server.is_connection_available():
		var peer = server.take_connection()
		peers.append(peer)
		buffers[peer] = ""
		_last_activity[peer] = Time.get_unix_time_from_system()
		
	var to_remove = []
	for peer in peers:
		peer.poll()
		var status = peer.get_status()
		
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available = peer.get_available_bytes()
			if available > 0:
				var res = peer.get_data(available)
				if res[0] == OK:
					buffers[peer] += res[1].get_string_from_utf8()
					_last_activity[peer] = Time.get_unix_time_from_system()
					# R7b: защита от memory exhaustion
					if buffers[peer].length() > MAX_BUFFER_SIZE:
						push_warning("[SocketServer] Buffer overflow from peer, disconnecting")
						to_remove.append(peer)
						continue
					# Process messages separated by newline
					while "\n" in buffers[peer]:
						var idx = buffers[peer].find("\n")
						var line = buffers[peer].substr(0, idx)
						buffers[peer] = buffers[peer].substr(idx + 1)
						if line.length() > 0:
							var t0 := Time.get_ticks_usec()
							var resp = _route_command(line)
							var elapsed_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
							_request_count += 1
							_total_time_ms += elapsed_ms
							if elapsed_ms > SLOW_THRESHOLD_MS:
								_slow_count += 1
								GameLogger.trace("Slow request: %.1f ms | %s" % [elapsed_ms, _extract_action(line)], "SocketServer")
							else:
								GameLogger.trace("%.2f ms | %s" % [elapsed_ms, _extract_action(line)], "SocketServer")
							peer.put_data((JSON.stringify(resp) + "\n").to_utf8_buffer())
							
		elif status != StreamPeerTCP.STATUS_CONNECTING:
			to_remove.append(peer)

		# R7a: idle timeout — disconnect peers with no recent activity
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var last_active = _last_activity.get(peer, 0)
			if Time.get_unix_time_from_system() - last_active > IDLE_TIMEOUT_SEC:
				to_remove.append(peer)
				continue
			
	# Remove disconnected clients
	for peer in to_remove:
		peers.erase(peer)
		buffers.erase(peer)
		peer.disconnect_from_host()

# ==================== COMMAND ROUTING ====================

func _route_command(line: String) -> Dictionary:
	if line.length() > MAX_LINE_SIZE:
		return {"error": "Command too large"}
	var req = JSON.parse_string(line)
	if req == null or not (req is Dictionary):
		return {"error": "Invalid JSON"}
	var action = req.get("action")
	if not (action is String) or action.is_empty():
		return {"error": "Field 'action' is required and must be a string"}
	
	# Find active controllers in the scene tree (cached, lazy-load scripts to avoid autoload deps)
	_ensure_scripts_loaded()
	var world_ctrl = _get_cached_controller(_world_ctrl_script, true)
	var battle_ctrl = _get_cached_controller(_battle_ctrl_script, false)
	
	if world_ctrl == null:
		GameLogger.trace("DEBUG: WorldController not found in scene tree", "SocketServer")
	else:
		GameLogger.trace("DEBUG: WorldController found: %s" % world_ctrl.name, "SocketServer")
	
	match action:
		"START_GAME":
			return _start_game()
		"GET_STATE":
			return _get_state(world_ctrl, battle_ctrl)
		"MOVE_TO":
			if world_ctrl == null or not world_ctrl.is_world_visible():
				return {"error": "Not in World mode"}
			var x = req.get("x")
			var y = req.get("y")
			if not (x is int or x is float) or not (y is int or y is float):
				return {"error": "Fields 'x' and 'y' must be numbers"}
			var tx := int(x)
			var ty := int(y)
			return _move_to(world_ctrl, tx, ty)
		"END_TURN":
			if world_ctrl == null or not world_ctrl.is_world_visible():
				return {"error": "Not in World mode"}
			return _end_turn(world_ctrl)
		"COLLECT_HERE":
			# Собрать ресурс/сундук/скролл в клетке героя (сценарий «Collect All»).
			if world_ctrl == null or not world_ctrl.is_world_visible():
				return {"error": "Not in World mode"}
			var hero = world_ctrl.get_hero()
			if hero == null:
				return {"error": "Hero not initialized"}
			var ic = world_ctrl.interaction_controller
			if ic == null:
				return {"error": "No interaction controller"}
			var removed = ic.collect_resource_at(hero.current_cell)
			return {"status": "collected" if removed else "nothing_here"}
		"CITY_BUILD":
			# city-in-world: постройка в городе мира (через реальный CityScreen).
			return _city_action(world_ctrl, req, "build")
		"CITY_LEVEL":
			# city-in-world: улучшение города (уровень — при выполнении условий).
			return _city_action(world_ctrl, req, "level")
		"CITY_HIRE":
			# city-in-world: найм последователя (FollowerSystem.recruit).
			return _city_action(world_ctrl, req, "hire")
		"CITY_CLOSE":
			# city-in-world: закрыть экран управления городом.
			if world_ctrl == null or not world_ctrl.is_world_visible():
				return {"error": "Not in World mode"}
			var ui_mgr = world_ctrl.get_ui_manager()
			if ui_mgr == null:
				return {"error": "No UI manager (city screen unavailable)"}
			ui_mgr.close_city_screen()
			return {"status": "closed", "city_screen_open": ui_mgr.city_overlay_open()}
		"RETREAT":
			if battle_ctrl == null:
				return {"error": "Not in Battle mode"}
			return _retreat(battle_ctrl)
		"FORCE_RETREAT":
			# Аварийный выход из зависшего боя (например, скрипт-ошибка рванула
			# ход и отступление до WAITING_INPUT не доходит). В обход
			# стейт-машины завершает бой отступлением игрока.
			if battle_ctrl == null:
				return {"error": "Not in Battle mode"}
			var fb = battle_ctrl.get_battle_state()
			if fb == null or fb.battle_over:
				return {"error": "Battle already over"}
			battle_ctrl.force_retreat()
			return {"status": "forced_retreat"}

		"GET_SPELLS":
			return _get_spells()
		"CAST_SPELL":
			# Тестирование заклинаний в изоляции: цель — синтетический юнит,
			# поэтому логика SpellCaster (урон/иммунитет/сопротивление/лечение/
			# воскрешение) прогоняется без живого боя, который в безголовом
			# режиме не резолвится сам. Режим «world» не требуется.
			return _cast_spell(req.get("args", {}))
		"EMULATE_BATTLE":
			# Эмуляция полного боя: две армии сражаются до победы. Проверяет
			# BattleState + BattleActionResolver (атака/урон/убийство/чардж/
			# ребёрт/мораль/check_end). Режим «world» не требуется.
			return _emulate_battle(req.get("args", {}))
		"CAST_IN_BATTLE":
			# Проверка всех цепочек заклинаний в контексте боя: юниты живут
			# в реальном BattleState, каст через apply_spell (как в игре).
			# Режим «world» не требуется.
			return _cast_in_battle(req.get("args", {}))
		"SEQUENCE_BATTLE":
			# Проверка боевых последовательностей (ротаций): серия шагов
			# (cast / attack / enemy) выполняется на ОДНОМ BattleState подряд,
			# как реальный бой. Режим «world» не требуется.
			return _sequence_battle(req.get("args", {}))
		"BATTLE_SPELL":
			# Конвертация боевого заклинания в карточное («быстрое») и его
			# применение в контексте боя (BattleSpellBridge): проверяет маппинг
			# боевое→карточное и применение как обычного заклинания.
			return _battle_spell(req.get("args", {}))
		"SPELL_REGISTRY":
			# Состояние карточной системы: сколько карт и шаблонов загружено.
			return _spell_registry()
		"GET_METRICS":
			return get_metrics()
		_:
			return {"error": "Unknown action: %s" % action}

# ==================== SPELL TESTING ====================

## Вернуть все заклинания из автозагруженного SpellRegistry («Spells»). ##
func _get_spells() -> Dictionary:
	var reg: SpellRegistry = ServiceLocator.resolve(null, &"spells")
	if reg == null:
		return {"error": "SpellRegistry (autoload 'Spells') not found"}
	# Защита от гонки инициализации: автозагрузка ещё не вызвала _ready.
	if reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var list := reg.get_all_spells()
	var out: Array = []
	for s in list:
		out.append({"id": str(s.id), "name": s.display_name, "school": s.school, "level": s.level, "mana": s.base_mana})
	return {"spells": out, "count": out.size()}

## Бросить заклинание по синтетическому юниту и вернуть результат SpellCaster. ##
func _cast_spell(args: Dictionary) -> Dictionary:
	var spell_id: Variant = args.get("spell_id", "")
	if not (spell_id is String) or spell_id.is_empty():
		return {"error": "Field 'spell_id' is required and must be a non-empty string"}
	var tags: Array = args.get("tags", [])
	if not (tags is Array):
		tags = []
	var hp: int = int(args.get("hp", 100))
	# count=0 допустим (мёртвый юнит для воскрешения); 10 — только по умолчанию.
	var count: int = 10 if not args.has("count") else int(args.get("count"))
	var resistant: bool = bool(args.get("resistant", false))
	if resistant and not tags.has("magic_resistant"):
		tags.append("magic_resistant")
	# Синтетический юнит: без живого боя, но с реальными статами и тегами.
	var stats := UnitStats.new("test_target", "Test Target", 3, 2, hp, 4, 5, tags)
	var stack := UnitStack.new(stats, count)
	var unit := BattleState.BattleUnit.new(stack)
	# max_count — исходный состав (для воскрешения/вампиризма); не равен
	# текущему count=0, если юнит «мёртвый» для теста resurrection.
	unit.max_count = maxi(count, 10)
	if unit.get_count() <= 0:
		unit.set_count(count)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# та же защита от гонки инициализации, что и в _get_spells.
	var reg: SpellRegistry = ServiceLocator.resolve(null, &"spells")
	if reg != null and reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var caster_bonus := {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5}
	var target_bonus := {"knowledge": int(resistant), "defense": 5}
	return SpellCaster.cast(StringName(spell_id), unit, caster_bonus, target_bonus, rng, null)

# ==================== BATTLE EMULATION ====================

## Построить UnitStack из спецификации {id, hp, count, tags, attack, ...}. ##
func _army_stack(spec: Dictionary) -> UnitStack:
	var tags: Array = []
	if spec.has("tags") and spec["tags"] is Array:
		tags = spec["tags"]
	var stats := UnitStats.new(
		str(spec.get("id", "unit")),
		str(spec.get("name", spec.get("id", "unit"))),
		int(spec.get("attack", 3)),
		int(spec.get("base_damage", 3)),
		int(spec.get("hp", 50)),
		int(spec.get("speed", 5)),
		int(spec.get("defense", 3)),
		tags
	)
	return UnitStack.new(stats, maxi(1, int(spec.get("count", 10))))

func _side_name(side: int) -> String:
	return "attacker" if side == BattleState.Side.ATTACKER else "defender"

func _summarize(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if u != null and u.is_alive():
			out.append({"name": u.get_display_name(), "count": u.get_count(), "hp": u.get_hp()})
	return out

func _nearest_enemy(ref_cell: Vector2i, units: Array) -> BattleState.BattleUnit:
	var best: BattleState.BattleUnit = null
	var best_d := 1 << 30
	for u in units:
		if u != null and u.is_alive():
			var d := HexUtils.hex_distance(ref_cell, u.cell)
			if d < best_d:
				best_d = d
				best = u
	return best

## Простой авто-ИИ: идти к ближайшему врагу и бить, когда в зоне доступа. ##
func _move_toward(state: BattleState, u: BattleState.BattleUnit, target: BattleState.BattleUnit) -> void:
	var blocked := state.build_all_blocked(u, {})
	var reachable := state.get_reachable_for_unit(u, func() -> Dictionary: return blocked)
	var best := u.cell
	var best_d := HexUtils.hex_distance(u.cell, target.cell)
	for c in reachable:
		var d := HexUtils.hex_distance(c, target.cell)
		if d < best_d:
			best_d = d
			best = c
	if best != u.cell:
		state.do_move(u, best)

## Полный цикл боя до победы или лимита ходов. ##
func _run_auto_battle(state: BattleState, rng: RandomNumberGenerator) -> Dictionary:
	state.build_queue()
	var events: Array = []
	var turn := 0
	const MAX_TURNS := 400
	while not state.battle_over and turn < MAX_TURNS:
		state.advance_turn()
		turn += 1
		if state.battle_over:
			break
		var u: BattleState.BattleUnit = state.active_unit
		if u == null or not u.is_alive():
			continue
		if u.is_stunned():
			u.has_moved = true
			continue
		var enemy_side := BattleState.Side.DEFENDER if u.side == BattleState.Side.ATTACKER else BattleState.Side.ATTACKER
		var target := _nearest_enemy(u.cell, state.get_units_by_side(enemy_side))
		if target == null:
			break
		var dist := HexUtils.hex_distance(u.cell, target.cell)
		var melee := not u.is_ranged()
		var adjacent := dist == 1
		var ranged_shot := u.is_ranged() and dist > 1
		if adjacent or ranged_shot:
			var res := state.apply_attack(u, target, melee, rng, true)
			events.append({"turn": turn, "unit": u.get_display_name(), "action": "attack", "result": res})
		else:
			_move_toward(state, u, target)
	return {
		"winner": _side_name(state.battle_winner),
		"battle_over": state.battle_over,
		"turns": turn,
		"atk_survivors": _summarize(state.get_units_by_side(BattleState.Side.ATTACKER)),
		"def_survivors": _summarize(state.get_units_by_side(BattleState.Side.DEFENDER)),
		"events": events,
	}

## Эмуляция боя: построить армии, прогнать авто-бой, вернуть результат. ##
func _emulate_battle(req: Dictionary) -> Dictionary:
	var atk_specs: Array = req.get("attacker_army", [])
	var def_specs: Array = req.get("defender_army", [])
	if not (atk_specs is Array) or not (def_specs is Array):
		return {"error": "Fields 'attacker_army' and 'defender_army' must be arrays"}
	var atk_stacks: Array[UnitStack] = []
	var def_stacks: Array[UnitStack] = []
	for s in atk_specs:
		if s is Dictionary:
			atk_stacks.append(_army_stack(s))
	for s in def_specs:
		if s is Dictionary:
			def_stacks.append(_army_stack(s))
	if atk_stacks.is_empty() or def_stacks.is_empty():
		return {"error": "Both armies must have at least one stack"}
	var atk_bonus := {"attack": 0, "defense": 0, "spell_power": 0, "knowledge": 0}
	var def_bonus := {"attack": 0, "defense": 0, "spell_power": 0, "knowledge": 0}
	if req.has("attacker_bonus") and req["attacker_bonus"] is Dictionary:
		atk_bonus = req["attacker_bonus"]
	if req.has("defender_bonus") and req["defender_bonus"] is Dictionary:
		def_bonus = req["defender_bonus"]
	var state := BattleState.new()
	state.set_hero_bonuses(atk_bonus, def_bonus)
	state.place_army(atk_stacks, def_stacks)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var report := _run_auto_battle(state, rng)
	report["atk_loss"] = _total_count(atk_specs)
	report["def_loss"] = _total_count(def_specs)
	return report

func _total_count(specs: Array) -> int:
	var total := 0
	for s in specs:
		if s is Dictionary:
			total += maxi(0, int(s.get("count", 0)))
	return total

## Проверить одно заклинание в контексте боя: юниты в реальном BattleState, ##
## каст через apply_spell (как в игре). Возвращает результат apply_spell. ##
func _cast_in_battle(args: Dictionary) -> Dictionary:
	var spell_id: Variant = args.get("spell_id", "")
	if not (spell_id is String) or spell_id.is_empty():
		return {"error": "Field 'spell_id' is required and must be a non-empty string"}
	var caster_tags: Array = args.get("caster_tags", [])
	if not (caster_tags is Array):
		caster_tags = []
	var target_tags: Array = args.get("target_tags", [])
	if not (target_tags is Array):
		target_tags = []
	var caster_hp: int = int(args.get("caster_hp", 60))
	var caster_count: int = maxi(1, int(args.get("caster_count", 10)))
	var target_hp: int = int(args.get("target_hp", 100))
	var target_count: int = int(args.get("target_count", 10))
	var resistant: bool = bool(args.get("resistant", false))
	if resistant and not target_tags.has("magic_resistant"):
		target_tags.append("magic_resistant")
	var caster_bonus: Dictionary = args.get("caster_bonus", {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5})
	var target_bonus: Dictionary = args.get("target_bonus", {"knowledge": int(resistant), "defense": 5})
	# Резолг SpellRegistry (защита от гонки инициализации, как в _cast_spell).
	var reg: SpellRegistry = ServiceLocator.resolve(null, &"spells")
	if reg != null and reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	# Строим реальный BattleState с юнитом-кастером (атакующий) и целью (защитник).
	# place_army отбрасывает мёртвые стеки (count=0), поэтому размещаем цель
	# с живым count, а затем при необходимости делаем её мертвой (resurrection).
	var caster_stack := UnitStack.new(
		UnitStats.new("caster", "Caster", 6, 3, caster_hp, 6, 5, caster_tags), caster_count)
	var target_stack := UnitStack.new(
		UnitStats.new("target", "Target", 3, 2, target_hp, 4, 5, target_tags), maxi(1, target_count))
	var state := BattleState.new()
	state.set_hero_bonuses(caster_bonus, target_bonus)
	state.place_army([caster_stack], [target_stack])
	# В бою цель — реальные юниты из state (place_army делает дубликаты статов).
	var caster_unit: BattleState.BattleUnit = state.attacker_units[0]
	var target_unit: BattleState.BattleUnit = state.defender_units[0]
	# Для воскрешения (и count=0) цель должна быть мертвой после размещения.
	if spell_id == &"resurrection" or target_count <= 0:
		target_unit.set_count(0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return state.apply_spell(
		StringName(spell_id), caster_unit, target_unit, caster_bonus, target_bonus, rng)

# ==================== SEQUENCE / ROTATION EMULATION ====================

## Выполнить последовательность шагов на ОДНО BattleState подряд (ротация):
##   {"cmd":"cast","spell":"<id>"}  — каст заклинания на цель (или на себя, если
##     "self":true); «resurrection» применяет к цели, даже если она мертва.
##   {"cmd":"attack"}                — кастер атакует цель.
##   {"cmd":"enemy"}                 — цель атакует кастера (наносит урон ему).
## Возвращает шаги с результатами + финальное состояние юнитов.
func _sequence_battle(args: Dictionary) -> Dictionary:
	var sequence: Variant = args.get("sequence", [])
	if not (sequence is Array):
		return {"error": "Field 'sequence' must be an array of steps"}
	# Спецификации юнитов (или теги как в _cast_in_battle).
	var caster_tags: Array = args.get("caster_tags", [])
	if not (caster_tags is Array):
		caster_tags = []
	var target_tags: Array = args.get("target_tags", [])
	if not (target_tags is Array):
		target_tags = []
	var caster_hp: int = maxi(1, int(args.get("caster_hp", 100)))
	# caster_start_hp — старт с пониженным HP, чтобы лечение было значимым.
	var caster_start_hp: int = maxi(1, int(args.get("caster_start_hp", caster_hp)))
	var caster_count: int = maxi(1, int(args.get("caster_count", 10)))
	var target_hp: int = maxi(1, int(args.get("target_hp", 200)))
	var target_count: int = maxi(1, int(args.get("target_count", 20)))
	var resistant: bool = bool(args.get("resistant", false))
	if resistant and not target_tags.has("magic_resistant"):
		target_tags.append("magic_resistant")
	var caster_bonus: Dictionary = args.get("caster_bonus", {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5})
	var target_bonus: Dictionary = args.get("target_bonus", {"knowledge": int(resistant), "defense": 5})
	# Защита от гонки инициализации (та же, что и в _cast_in_battle).
	var reg: SpellRegistry = ServiceLocator.resolve(null, &"spells")
	if reg != null and reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var caster_stack := UnitStack.new(
		UnitStats.new("caster", "Caster", 6, 3, caster_hp, 6, 5, caster_tags), caster_count)
	var target_stack := UnitStack.new(
		UnitStats.new("target", "Target", 3, 2, target_hp, 4, 5, target_tags), target_count)
	var state := BattleState.new()
	state.set_hero_bonuses(caster_bonus, target_bonus)
	state.place_army([caster_stack], [target_stack])
	var caster_unit: BattleState.BattleUnit = state.attacker_units[0]
	var target_unit: BattleState.BattleUnit = state.defender_units[0]
	# Пониженное стартовое HP кастера (лечение потом имеет смысл).
	if caster_start_hp < caster_unit.get_hp():
		caster_unit.stats.hp = caster_start_hp
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var steps: Array = []
	for cmd in sequence:
		if not (cmd is Dictionary):
			steps.append({"skipped": str(cmd)})
			continue
		var kind: String = cmd.get("cmd", "")
		if kind == "cast":
			var sid: Variant = cmd.get("spell", "")
			if not (sid is String) or sid.is_empty():
				steps.append({"cmd": "cast", "error": "Field 'spell' required"})
				continue
			var target_for: BattleState.BattleUnit = target_unit
			if bool(cmd.get("self", false)):
				target_for = caster_unit
			if sid == "resurrection":
				target_unit.set_count(0)
			var r = state.apply_spell(
				StringName(sid), caster_unit, target_for, caster_bonus, target_bonus, rng)
			steps.append({"cmd": "cast", "spell": sid, "result": r})
		elif kind == "attack":
			var r = state.apply_attack(caster_unit, target_unit, not caster_unit.is_ranged(), rng, true)
			steps.append({"cmd": "attack", "result": r})
		elif kind == "enemy":
			var r = state.apply_attack(target_unit, caster_unit, not target_unit.is_ranged(), rng, true)
			steps.append({"cmd": "enemy", "result": r})
	return {
		"steps": steps,
		"caster_hp": caster_unit.get_hp(),
		"caster_max_hp": caster_unit.get_hp(),
		"caster_alive": caster_unit.is_alive(),
		"caster_count": caster_unit.get_count(),
		"target_hp": target_unit.get_hp(),
		"target_alive": target_unit.is_alive(),
		"target_count": target_unit.get_count(),
	}

# ==================== BATTLE → SPELL CONVERSION ====================

## Конвертировать боевое заклинание в карточное и применить его в бою.
## Возвращает {spell: {...}, apply: {...}, registered: bool}.
func _battle_spell(args: Dictionary) -> Dictionary:
	var spell_id: Variant = args.get("spell_id", "")
	if not (spell_id is String) or spell_id.is_empty():
		return {"error": "Field 'spell_id' is required and must be a non-empty string"}
	var reg: SpellRegistry = ServiceLocator.resolve(null, &"spells")
	if reg == null:
		return {"error": "SpellRegistry (autoload 'Spells') not found"}
	if reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var def: SpellRegistry.SpellDef = reg.get_spell(StringName(spell_id))
	if def == null:
		return {"spell": null, "apply": {"result": "not_found", "spell_id": spell_id}, "registered": false}
	# 1. Боевое заклинание → карточное («быстрое»). — BattleSpellBridge.to_spell
	var spell: SpellbookDef = BattleSpellBridge.to_spell(def)
	# 2. Зарегистрировать карту в карточной системе (интеграция «как обычно»). — SpellbookRegistry.register
	var spell_reg: SpellbookRegistry = ServiceLocator.resolve(null, &"spellbook")
	var registered := false
	if spell_reg != null:
		spell_reg.register(spell)
		registered = true
	# 3. Применить карту в контексте боя на синтетическом юните. — BattleSpellBridge.apply_spell
	var tags: Array = args.get("tags", [])
	if not (tags is Array):
		tags = []
	var hp: int = int(args.get("hp", 100))
	var count: int = 10 if not args.has("count") else int(args.get("count"))
	var resistant: bool = bool(args.get("resistant", false))
	if resistant and not tags.has("magic_resistant"):
		tags.append("magic_resistant")
	var stats := UnitStats.new("test_target", "Test Target", 3, 2, hp, 4, 5, tags)
	var stack := UnitStack.new(stats, count)
	var unit := BattleState.BattleUnit.new(stack)
	unit.max_count = maxi(count, 10)
	if unit.get_count() <= 0:
		unit.set_count(count)
	# Для воскрешения цель должна быть мертвой после размещения.
	if str(spell.template) == "REVIVE":
		unit.set_count(0)
	var caster_bonus := {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5}
	var target_bonus := {"knowledge": int(resistant), "defense": 5}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var apply_result := BattleSpellBridge.apply_spell(spell, unit, caster_bonus, target_bonus, rng)
	return {"spell": spell.to_dict(), "apply": apply_result, "registered": registered}

## Состояние карточной системы (для проверки интеграции конвертации).
func _spell_registry() -> Dictionary:
	var spell_reg: SpellbookRegistry = ServiceLocator.resolve(null, &"spellbook")
	if spell_reg == null:
		return {"error": "SpellbookRegistry (autoload 'Spellbook') not found"}
	return {"count": spell_reg.get_count(), "template_count": spell_reg.get_template_count()}


func _find_controller(script: Script) -> Node:
	# Recursive search through full scene tree (script-avoid autoload compile deps)
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.get_script() == script:
			return node
		for child in node.get_children():
			stack.append(child)
	return null

func _get_cached_controller(script: Script, is_world: bool) -> Variant:
	var cached := _world_ctrl_cache if is_world else _battle_ctrl_cache
	if cached != null and is_instance_valid(cached) and cached.is_inside_tree():
		return cached
	# Re-search
	var found = _find_controller(script)
	if is_world:
		_world_ctrl_cache = found
	else:
		_battle_ctrl_cache = found
	return found

func _ensure_scripts_loaded() -> void:
	if _world_ctrl_script != null and _battle_ctrl_script != null:
		return
	_world_ctrl_script = load("res://scripts/world/WorldController.gd")
	_battle_ctrl_script = load("res://scripts/systems/BattleController.gd")

func _start_game() -> Dictionary:
	if get_node_or_null("/root/World"):
		return {"status": "already_started"}
	var world_scene = load("res://scenes/World.tscn")
	var world = world_scene.instantiate()
	get_tree().root.add_child(world)
	return {"status": "game_started"}

# ==================== API METHODS ====================

func _get_state(world_ctrl, battle_ctrl) -> Dictionary:
	var state = {"mode": "unknown"}

	# Бой приоритетен: world_ctrl существует всегда (боевая сцена добавляется
	# поверх мировой), поэтому «в бою ли» определяем по presence battle_ctrl.
	var in_battle := battle_ctrl != null
	state.mode = "battle" if in_battle else "world"

	if world_ctrl:
		var hero = world_ctrl.get_hero()
		var map_gen = world_ctrl.get_map_gen()
		
		if hero:
			state.hero_pos = {"x": hero.current_cell.x, "y": hero.current_cell.y}
			state.move_points = hero.move_points
			state.max_move_points = hero.get_daily_movement_points()
			state.basic_resources = hero.resources.resources.duplicate()
			state.strategic_resources = hero.strategic_resources.get_all()
			# Идёт ли герой прямо сейчас (для честного ожидания частичного движения)
			state.moving = hero.movement != null and hero.movement.is_moving
			# city-in-world: именованные последователи героя (CITY_HIRE).
			var followers_out: Array = []
			for f in hero.followers:
				if f != null and f.has_method("to_dict"):
					followers_out.append(f.to_dict())
				else:
					followers_out.append({"name": str(f)})
			state.followers = followers_out
		
		if map_gen:
			# Map resources
			var res_nodes = []
			for cell in map_gen.resource_cells:
				res_nodes.append({"x": cell.x, "y": cell.y, "type": map_gen.resource_cells[cell]})
			state.map_resources = res_nodes
			
			# Map enemies
			var enemies = []
			if map_gen.enemy_stacks:
				for cell in map_gen.enemy_stacks:
					var army: Array = map_gen.enemy_stacks[cell]
					var composition = ""
					if army.size() > 0:
						var parts = []
						for stack in army:
							if stack.has_method("get_key"):
								parts.append("%s x%d" % [stack.get_key(), stack.count])
						composition = ", ".join(parts)
					else:
						composition = "Empty"
					
					enemies.append({
						"x": cell.x, 
						"y": cell.y, 
						"composition": composition
					})
			state.map_enemies = enemies

			# fog-of-war: туман для сценариев — счётчики + видимые стеки.
			var fog = world_ctrl.get_fog() if world_ctrl.has_method("get_fog") else null
			if fog != null:
				state.fog = {"explored": fog.explored.size(), "visible": fog.visible.size()}
				var visible_enemies: Array = []
				for cell in map_gen.enemy_stacks:
					if fog.is_visible(cell):
						visible_enemies.append({"x": cell.x, "y": cell.y})
				state.visible_enemies = visible_enemies

		# city-in-world: города мира + экран управления (CITY_* сценарии).
		var cities_mgr = world_ctrl.get_cities()
		if cities_mgr != null:
			var city_list: Array = []
			for c in cities_mgr.cities:
				city_list.append(_city_state_dict(c))
			state.cities = city_list
			state.capital = _city_state_dict(cities_mgr.capital)
		var ui_mgr = world_ctrl.get_ui_manager()
		state.city_screen_open = ui_mgr.city_overlay_open() if ui_mgr != null else false

		# Деревни на карте (для сценария «Explore»).
		var _villages: Array = []
		for _c in map_gen.village_cells:
			_villages.append({"x": _c.x, "y": _c.y})
		state.map_villages = _villages
		
	if battle_ctrl:
		var bstate = battle_ctrl.get_battle_state()
		if bstate:
			state.battle_over = bstate.battle_over
			state.is_player_turn = bstate.is_player_turn
		
	return state

func _move_to(world_ctrl, x: int, y: int) -> Dictionary:
	var hero = world_ctrl.get_hero()
	if hero == null:
		return {"error": "Hero not initialized"}
	var map = world_ctrl.get_map_gen()
	if map == null:
		return {"error": "Map not initialized"}
	var target := Vector2i(x, y)
	if not map.is_in_bounds(target):
		return {"error": "Out of bounds: (%d, %d)" % [x, y]}
	if hero.current_cell == target:
		return {"status": "already_at", "target": {"x": x, "y": y}}
	# Семантика: цель дальше ОД — герой идёт в её сторону.
	# Честный протокол: will_reach говорит клиенту, стоит ли ждать прибытия
	# (false — герой остановится по исчерпании ОД, клиент ждёт moving==false).
	var will_reach: bool = hero.can_reach(target)
	var success: bool = hero.move_to_cell(target)
	if success:
		return {"status": "moving", "will_reach": will_reach, "target": {"x": x, "y": y}}
	var problem: String = hero.reach_problem(target)
	var reason := "unreachable" if problem == "unreachable" else "not enough movement points"
	return {"error": "Cannot move to (%d, %d): %s" % [x, y, reason]}

func _end_turn(world_ctrl) -> Dictionary:
	world_ctrl.do_end_turn()
	return {"status": "turn_ended"}

# ==================== CITY ACTIONS (city-in-world) ====================

## city-in-world: действие в городе через РЕАЛЬНЫЙ CityScreen: открыть
## экран для города → выполнить то же действие, что делает кнопка → результат.
func _city_action(world_ctrl, req: Dictionary, action: String) -> Dictionary:
	if world_ctrl == null or not world_ctrl.is_world_visible():
		return {"error": "Not in World mode"}
	var city: City = _resolve_city(world_ctrl, req)
	if city == null:
		return {"error": "City not found"}
	var ui_mgr = world_ctrl.get_ui_manager()
	if ui_mgr == null:
		return {"error": "No UI manager (city screen unavailable)"}
	var hero = world_ctrl.get_hero()
	var hero_cell: Vector2i = hero.current_cell if hero != null else Vector2i(-1, -1)
	var args: Variant = req.get("args", {})
	if not (args is Dictionary):
		args = {}
	var building := str(args.get("building", "farm"))
	var res: Dictionary = ui_mgr.city_screen_action(action, city, hero_cell, building)
	res["city"] = _city_state_dict(city)
	return res

## city-in-world: город из args: {"uid": N} или {"cell": {"x","y"}}; если
## ничего не передано — столица.
func _resolve_city(world_ctrl, req: Dictionary) -> City:
	var cities = world_ctrl.get_cities()
	if cities == null:
		return null
	var args: Variant = req.get("args", {})
	if args is Dictionary:
		if args.has("uid"):
			var c = cities.get_city_by_uid(int(args.get("uid")))
			if c != null:
				return c
			return null  # uid передан, но город не найден — не гадать по столице
		if args.has("cell") and args.get("cell") is Dictionary:
			var cell: Dictionary = args.get("cell")
			var c = cities.city_at(Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1))))
			if c != null:
				return c
	return cities.capital

## city-in-world: JSON-совместимый снимок города (GET_STATE / ответы CITY_*).
func _city_state_dict(city: City) -> Dictionary:
	if city == null:
		return {}
	return {
		"uid": city.uid,
		"name": city.display_name,
		"center": {"x": city.center.x, "y": city.center.y},
		"level": city.level,
		"owner": String(city.owner),
		"population": city.pop_capped(),
		"free_followers": city.free_followers(),
		"food": city.food_stockpile,
		"prosperity": city.prosperity,
		"gold": city.resource_ctx.amount(&"gold") if city.resource_ctx != null else 0.0,
		"industry": float(city.storage.get(&"industry", 0.0)),
		"buildings": city.buildings.size(),
	}

func _retreat(battle_ctrl) -> Dictionary:
	var bstate = battle_ctrl.get_battle_state()
	if bstate == null:
		return {"error": "Battle state not initialized"}
	if bstate.battle_over:
		return {"error": "Battle already over"}
	battle_ctrl.do_retreat()
	return {"status": "retreating"}


# ==================== METRICS ====================

## Парсинг action из JSON-строки для лога.
func _extract_action(line: String) -> String:
	var req = JSON.parse_string(line)
	if req is Dictionary and req.has("action"):
		return str(req["action"])
	return "UNKNOWN"

## Возвращает сводную статистику по обработанным запросам.
func get_metrics() -> Dictionary:
	var avg: float = 0.0
	if _request_count > 0:
		avg = _total_time_ms / float(_request_count)
	return {
		"total_requests": _request_count,
		"total_time_ms": roundf(_total_time_ms * 100.0) / 100.0,
		"avg_ms": roundf(avg * 100.0) / 100.0,
		"slow_requests": _slow_count,
		"slow_threshold_ms": SLOW_THRESHOLD_MS,
		"connected_peers": peers.size(),
	}
