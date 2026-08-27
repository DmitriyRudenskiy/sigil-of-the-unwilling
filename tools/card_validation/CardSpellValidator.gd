class_name CardSpellValidator
extends RefCounted
## Полный валидатор data/card_spells.json.
## 7 уровней проверки: структура → поля → типы → enum → семантика → целостность → баланс.
##
## Коды ошибок:
##   E0xx — файловая система / парсинг
##   E1xx — структура записи
##   E2xx — типы данных
##   E3xx — недопустимые значения (вне диапазонов/множеств)
##   E4xx — семантика шаблонов
##   E5xx — целостность (уникальность, количество)
##   E6xx — баланс и распределение
##   E7xx — кросс-валидация с кодом
##   W9xx — предупреждения (стиль, рекомендации)

const _ValidationReport = preload("res://tools/card_validation/ValidationReport.gd")

# ==================== СПРАВОЧНИКИ (источник истины) ====================

## 16 шаблонов. Значение — список ОБЯЗАТЕЛЬНЫХ параметров для этого шаблона.
const TEMPLATES := {
	"DIRECT_DAMAGE":    ["amount", "target"],
	"HARD_REMOVAL":     [],
	"BOUNCE":           ["target"],
	"COUNTERMAGIC":     [],
	"COMBAT_TRICK":     [],
	"DEBUFF_CONTROL":   [],
	"CARD_DRAW":        ["count"],
	"MANA_RAMP":        ["power"],
	"TOKEN_GENERATION": ["token_id", "count"],
	"RELIC_INTERACTION":["action"],
	"KEYWORD_BUFF":     ["keyword"],
	"CHOICE_CYCLE":     ["draw"],
	"TOUCH_CYCLE":      ["atk", "hp"],
	"DISPLAY_CYCLE":    [],
	"DISCARD_DRAW":     ["discard", "draw"],
	"MARKET_NICHE":     ["action"],
}

## Допустимые цели
const VALID_TARGETS := [
	"NONE", "ALLY_UNIT", "ENEMY_UNIT", "ANY_UNIT",
	"ALLY_NEXUS", "ENEMY_NEXUS", "ANY_NEXUS",
	"ENEMY_SPELL", "ENEMY_RELIC",
	"ALL_ENEMY_UNITS", "ALL_ALLY_UNITS",
	"TWO_ALLY_UNITS", "ALLY_UNIT_IN_HAND", "ALLY_UNIT_IN_GRAVE",
	"SELF", "SAME_AS_PREVIOUS",
]

## Допустимые статусы/ключевые слова
const VALID_STATUSES := [
	"SILENCE", "FROZEN", "STUN", "QUICKDRAW", "UNBLOCKABLE",
	"OVERWHELM", "ARMORED", "WARD", "CHALLENGE",
	"CANNOT_BLOCK", "CANNOT_ATTACK", "FLYING",
]

## Допустимые цвета/фракции
const VALID_COLORS := [
	"fire", "time", "justice", "primal", "shadow",
	"multifaction", "colorless",
]

## Допустимые скорости
const VALID_SPEEDS := ["fast", "slow", "burst"]

## Допустимые ключи условий
const VALID_CONDITION_KEYS := [
	"target_hp_max", "target_cost_max", "target_is_damaged",
	"target_is_flying", "hand_size_max", "spell_cost_max",
	"attacker_unblocked", "discard_cost", "min_ally_count",
]

## Допустимые вторичные эффекты
const VALID_SECONDARY_EFFECTS := [
	"DRAW", "DEAL_DAMAGE", "HEAL_NEXUS", "APPLY_STATUS",
]

## Допустимые значения RELIC_INTERACTION.action и MARKET_NICHE.action
const VALID_RELIC_ACTIONS := ["destroy", "steal"]
const VALID_MARKET_ACTIONS := ["draw_from_market", "trigger_on_discard", "repeat_attack"]

## Допустимые значения CHOICE_CYCLE.secondary
const VALID_CHOICE_SECONDARY := ["DEAL_1_DAMAGE", "BUFF_1_1", "HEAL_2", "GAIN_1_ARMOR"]

## Ожидаемое распределение по шаблонам (из спецификации)
const EXPECTED_TEMPLATE_COUNTS := {
	"DIRECT_DAMAGE": 73, "HARD_REMOVAL": 32, "BOUNCE": 18, "COUNTERMAGIC": 11,
	"COMBAT_TRICK": 85, "DEBUFF_CONTROL": 76, "CARD_DRAW": 94, "MANA_RAMP": 5,
	"TOKEN_GENERATION": 28, "RELIC_INTERACTION": 8, "KEYWORD_BUFF": 12,
	"CHOICE_CYCLE": 19, "TOUCH_CYCLE": 4, "DISPLAY_CYCLE": 15,
	"DISCARD_DRAW": 5, "MARKET_NICHE": 4,
}
const EXPECTED_TOTAL := 420

# Границы допустимых значений
const COST_MIN := 0
const COST_MAX := 10
const DAMAGE_MIN := 1
const DAMAGE_MAX := 20
const STAT_MOD_MIN := -5
const STAT_MOD_MAX := 10
const TOKEN_COUNT_MIN := 1
const TOKEN_COUNT_MAX := 5
const DRAW_COUNT_MIN := 1
const DRAW_COUNT_MAX := 4

# Стиль
const MAX_NAME_LENGTH := 40
const MAX_DESC_LENGTH := 200
const ID_PATTERN := "^[a-z][a-z0-9_]*$"

var report
var _spells = []           # распарсенные записи
var _ids_seen = {}
var _names_seen = {}

func _init() -> void:
	report = _ValidationReport.new()

# ==================== ПУБЛИЧНЫЙ ВХОД ====================

## Валидирует файл целиком. Возвращает true, если нет ошибок.
func validate_file(path: String) -> bool:
	# Сброс состояния для нового вызова
	report = _ValidationReport.new()
	_spells = []
	_ids_seen = {}
	_names_seen = {}
	# Уровень 0: файл
	if not FileAccess.file_exists(path):
		report.error("E001", "File does not exist: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		report.error("E002", "Cannot open file for reading: %s" % path)
		return false

	var text := file.get_as_text()
	file.close()

	report.stats["file_size_bytes"] = text.length()

	# Уровень 1: парсинг
	if not _parse(text):
		return false

	# Уровень 2-4: каждая запись
	for i in _spells.size():
		_validate_entry(_spells[i], i)

	# Уровень 5: целостность
	_validate_uniqueness()
	_validate_totals()

	# Уровень 6: баланс
	_validate_balance()

	return not report.has_errors()

func _parse(text: String) -> bool:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		report.error("E010", "JSON parse error: %s at line %d" % [
			json.get_error_message(), json.get_error_line()])
		return false

	var data = json.data
	if not (data is Array):
		report.error("E011", "Root element must be an Array, got %s" % _type_name(data))
		return false

	_spells = data
	report.stats["spell_count"] = _spells.size()

	if _spells.is_empty():
		report.error("E012", "Spell list is empty")
		return false

	return true

# ==================== УРОВЕНЬ 2-4: ОДНА ЗАПИСЬ ====================

func _validate_entry(entry, index: int) -> void:
	if not (entry is Dictionary):
		report.error("E100", "Entry #%d is not a Dictionary (got %s)" % [index, _type_name(entry)])
		return

	var spell_id: String = str(entry.get("id", ""))

	# --- Обязательные поля ---
	_require_field(entry, "id", "E101", index)
	_require_field(entry, "name", "E102", index)
	_require_field(entry, "template", "E103", index)
	_require_field(entry, "speed", "E104", index)
	_require_field(entry, "cost", "E105", index)
	_require_field(entry, "color", "E106", index)

	# --- id: формат snake_case ---
	if spell_id != "":
		var regex := RegEx.new()
		regex.compile(ID_PATTERN)
		if not regex.search(spell_id):
			report.error("E300", "id must be snake_case (lowercase, digits, underscore): '%s'" % spell_id, spell_id)
		if spell_id in _ids_seen:
			report.error("E500", "Duplicate id '%s' (first seen at index %d)" % [spell_id, _ids_seen[spell_id]], spell_id)
		else:
			_ids_seen[spell_id] = index

	# --- name ---
	var name: String = str(entry.get("name", ""))
	if name.is_empty():
		report.error("E301", "name is empty", spell_id)
	elif name.length() > MAX_NAME_LENGTH:
		report.warning("W900", "name is %d chars (max %d)" % [name.length(), MAX_NAME_LENGTH], spell_id)
	if name != "":
		if name.to_lower() in _names_seen:
			report.warning("W901", "Duplicate display name '%s' (index %d)" % [name, _names_seen[name.to_lower()]], spell_id)
		else:
			_names_seen[name.to_lower()] = index

	# --- template ---
	var template: String = str(entry.get("template", ""))
	if template != "" and not TEMPLATES.has(template):
		report.error("E302", "Unknown template '%s'. Valid: %s" % [template, _template_list()], spell_id)

	# --- speed ---
	var speed: String = str(entry.get("speed", ""))
	if speed != "" and not VALID_SPEEDS.has(speed):
		report.error("E303", "Invalid speed '%s'. Valid: %s" % [speed, ", ".join(VALID_SPEEDS)], spell_id)

	# --- cost ---
	var cost = entry.get("cost")
	if cost != null:
		if not (cost is int or cost is float):
			report.error("E200", "cost must be a number, got %s" % _type_name(cost), spell_id)
		elif int(cost) < COST_MIN or int(cost) > COST_MAX:
			report.error("E304", "cost %d out of range [%d, %d]" % [int(cost), COST_MIN, COST_MAX], spell_id)

	# --- color ---
	var color: String = str(entry.get("color", ""))
	if color != "" and not VALID_COLORS.has(color):
		report.error("E305", "Invalid color '%s'. Valid: %s" % [color, ", ".join(VALID_COLORS)], spell_id)

	# --- params ---
	var params = entry.get("params", {})
	if not (params is Dictionary):
		report.error("E201", "params must be a Dictionary, got %s" % _type_name(params), spell_id)
		params = {}

	# --- condition ---
	var condition = entry.get("condition", {})
	if not (condition is Dictionary):
		report.error("E202", "condition must be a Dictionary, got %s" % _type_name(condition), spell_id)
		condition = {}
	else:
		_validate_condition(condition, spell_id)

	# --- secondary_effects ---
	var secondary = entry.get("secondary_effects", [])
	if not (secondary is Array):
		report.error("E203", "secondary_effects must be an Array, got %s" % _type_name(secondary), spell_id)
		secondary = []
	else:
		_validate_secondary_effects(secondary, spell_id)

	# --- Семантика шаблона ---
	if TEMPLATES.has(template):
		_validate_template_semantics(template, params, condition, entry, spell_id)

	# --- description (опционально, но желательно) ---
	if not entry.has("description"):
		report.info("I001", "No description provided", spell_id)
	else:
		var desc: String = str(entry.get("description", ""))
		if desc.length() > MAX_DESC_LENGTH:
			report.warning("W902", "description is %d chars (max %d)" % [desc.length(), MAX_DESC_LENGTH], spell_id)

func _require_field(entry: Dictionary, field: String, code: String, index: int) -> void:
	if not entry.has(field):
		var sid: String = str(entry.get("id", ""))
		report.error(code, "Missing required field '%s' in entry #%d" % [field, index], sid)

# ==================== УСЛОВИЯ ====================

func _validate_condition(condition: Dictionary, spell_id: String) -> void:
	for key in condition:
		if not VALID_CONDITION_KEYS.has(key):
			report.error("E310", "Unknown condition key '%s'. Valid: %s" % [key, ", ".join(VALID_CONDITION_KEYS)], spell_id)
			continue
		var val = condition[key]
		# Числовые ключи должны быть числами
		if key in ["target_hp_max", "target_cost_max", "hand_size_max",
				   "spell_cost_max", "discard_cost", "min_ally_count"]:
			if not (val is int or val is float):
				report.error("E210", "condition '%s' must be a number" % key, spell_id)
			elif int(val) < 0:
				report.error("E311", "condition '%s' must be >= 0" % key, spell_id)
		# Булевы ключи
		elif key in ["target_is_damaged", "target_is_flying", "attacker_unblocked"]:
			if not (val is bool):
				report.error("E211", "condition '%s' must be a bool" % key, spell_id)

# ==================== ВТОРИЧНЫЕ ЭФФЕКТЫ ====================

func _validate_secondary_effects(effects: Array, spell_id: String) -> void:
	for i in effects.size():
		var eff = effects[i]
		if not (eff is Dictionary):
			report.error("E212", "secondary_effects[%d] must be a Dictionary" % i, spell_id)
			continue
		var eff_type: String = str(eff.get("effect", ""))
		if not VALID_SECONDARY_EFFECTS.has(eff_type):
			report.error("E312", "Unknown secondary effect '%s'. Valid: %s" % [eff_type, ", ".join(VALID_SECONDARY_EFFECTS)], spell_id)
			continue
		# Числовые параметры вторичных эффектов
		if eff_type in ["DRAW", "DEAL_DAMAGE", "HEAL_NEXUS"]:
			var count = eff.get("count", eff.get("amount"))
			if count == null:
				report.error("E313", "Secondary effect '%s' requires 'count' or 'amount'" % eff_type, spell_id)
			elif not (count is int or count is float) or int(count) < 1:
				report.error("E314", "Secondary effect '%s' count/amount must be >= 1" % eff_type, spell_id)

# ==================== СЕМАНТИКА ШАБЛОНОВ ====================

func _validate_template_semantics(
	template: String, params: Dictionary, condition: Dictionary,
	entry: Dictionary, spell_id: String
) -> void:
	# Обязательные параметры для шаблона
	var required = TEMPLATES.get(template, [])
	for req in required:
		if not params.has(req):
			report.error("E400", "Template '%s' requires param '%s'" % [template, req], spell_id)

	match template:
		"DIRECT_DAMAGE":      _v_direct_damage(params, spell_id)
		"HARD_REMOVAL":       _v_hard_removal(params, condition, spell_id)
		"BOUNCE":             _v_bounce(params, spell_id)
		"COUNTERMAGIC":       _v_countermagic(params, spell_id)
		"COMBAT_TRICK":       _v_combat_trick(params, spell_id)
		"DEBUFF_CONTROL":     _v_debuff_control(params, spell_id)
		"CARD_DRAW":          _v_card_draw(params, condition, spell_id)
		"MANA_RAMP":          _v_mana_ramp(params, spell_id)
		"TOKEN_GENERATION":   _v_token_generation(params, spell_id)
		"RELIC_INTERACTION":  _v_relic_interaction(params, spell_id)
		"KEYWORD_BUFF":       _v_keyword_buff(params, spell_id)
		"CHOICE_CYCLE":       _v_choice_cycle(params, spell_id)
		"TOUCH_CYCLE":        _v_touch_cycle(params, spell_id)
		"DISPLAY_CYCLE":      _v_display_cycle(params, spell_id)
		"DISCARD_DRAW":       _v_discard_draw(params, spell_id)
		"MARKET_NICHE":       _v_market_niche(params, spell_id)

func _v_direct_damage(params: Dictionary, sid: String) -> void:
	var amount = params.get("amount")
	var has_dynamic: bool = params.has("amount_dynamic")
	if amount == null and not has_dynamic:
		report.error("E410", "DIRECT_DAMAGE requires 'amount' or 'amount_dynamic'", sid)
		return
	if amount != null:
		_check_int_range(amount, DAMAGE_MIN, DAMAGE_MAX, "E411", "amount", sid)
	if has_dynamic:
		var dyn: String = str(params.get("amount_dynamic"))
		if dyn not in ["ally_count", "enemy_count", "hand_size"]:
			report.error("E412", "Invalid amount_dynamic '%s'. Valid: ally_count, enemy_count, hand_size" % dyn, sid)
	_check_target(params, sid, ["ENEMY_UNIT", "ANY_UNIT", "ANY_NEXUS", "ENEMY_NEXUS", "ALL_ENEMY_UNITS"])
	# Статус при уроне (Ice Bolt → FROZEN)
	if params.has("apply_status"):
		_check_status(str(params.get("apply_status")), sid)

func _v_hard_removal(params: Dictionary, condition: Dictionary, sid: String) -> void:
	if params.has("ignore_ward") and not (params["ignore_ward"] is bool):
		report.error("E220", "ignore_ward must be bool", sid)
	if params.has("exile") and not (params["exile"] is bool):
		report.error("E221", "exile must be bool", sid)
	# Условие для условного удаления
	var has_condition: bool = condition.size() > 0
	var has_no_condition_reason: bool = params.has("unconditional")
	if not has_condition and not has_no_condition_reason:
		report.warning("W910", "HARD_REMOVAL without condition — is it unconditional?", sid)

func _v_bounce(params: Dictionary, sid: String) -> void:
	_check_target(params, sid, ["ALLY_UNIT", "ANY_UNIT"])
	if params.has("replay_free") and not (params["replay_free"] is bool):
		report.error("E222", "replay_free must be bool", sid)
	if params.has("draw_after"):
		_check_int_range(params["draw_after"], 1, DRAW_COUNT_MAX, "E413", "draw_after", sid)

func _v_countermagic(params: Dictionary, sid: String) -> void:
	if params.has("cost_max"):
		_check_int_range(params["cost_max"], 1, COST_MAX, "E414", "cost_max", sid)
	if params.has("targets_ally_only") and not (params["targets_ally_only"] is bool):
		report.error("E223", "targets_ally_only must be bool", sid)
	if params.has("draw_on_counter"):
		_check_int_range(params["draw_on_counter"], 1, DRAW_COUNT_MAX, "E415", "draw_on_counter", sid)

func _v_combat_trick(params: Dictionary, sid: String) -> void:
	# atk/hp — числа или *_dynamic
	for stat in ["atk", "hp"]:
		var has_val: bool = params.has(stat)
		var has_dyn: bool = params.has(stat + "_dynamic")
		if not has_val and not has_dyn:
			# Может быть только статус — ок
			continue
		if has_val:
			_check_int_range(params[stat], STAT_MOD_MIN, STAT_MOD_MAX, "E416", stat, sid)
		if has_dyn:
			var dyn: String = str(params.get(stat + "_dynamic"))
			if dyn not in ["ally_count", "enemy_count"]:
				report.error("E417", "Invalid %s_dynamic '%s'" % [stat, dyn], sid)
	if params.has("heal"):
		_check_int_range(params["heal"], 1, DAMAGE_MAX, "E418", "heal", sid)
	# Цель для боевых хитростей — обычно союзник или все союзники
	if params.has("target"):
		_check_target(params, sid, ["ALLY_UNIT", "ALL_ALLY_UNITS"])

func _v_debuff_control(params: Dictionary, sid: String) -> void:
	var has_status: bool = params.has("status")
	var has_stat: bool = params.has("atk") or params.has("hp")
	var has_control: bool = params.has("change_control")
	if not has_status and not has_stat and not has_control:
		report.error("E420", "DEBUFF_CONTROL requires status, atk/hp, or change_control", sid)
	if has_status:
		_check_status(str(params.get("status")), sid)
	for stat in ["atk", "hp"]:
		if params.has(stat):
			_check_int_range(params[stat], STAT_MOD_MIN, STAT_MOD_MAX, "E421", stat, sid)
			# Для дебаффа значения должны быть отрицательными (предупреждение)
			if int(params[stat]) > 0:
				report.warning("W911", "DEBUFF_CONTROL has positive %s=%s (buff?)" % [stat, params[stat]], sid)
	if has_control and not (params["change_control"] is bool):
		report.error("E224", "change_control must be bool", sid)
	if params.has("permanent") and not (params["permanent"] is bool):
		report.error("E225", "permanent must be bool", sid)
	if params.has("duration"):
		_check_int_range(params["duration"], 1, 5, "E422", "duration", sid)

func _v_card_draw(params: Dictionary, condition: Dictionary, sid: String) -> void:
	_check_int_range(params.get("count"), DRAW_COUNT_MIN, DRAW_COUNT_MAX, "E423", "count", sid)
	if params.has("scout"):
		_check_int_range(params["scout"], 1, 5, "E424", "scout", sid)
	if params.has("opponent_draw"):
		_check_int_range(params["opponent_draw"], 1, DRAW_COUNT_MAX, "E425", "opponent_draw", sid)
	# Если есть hand_max, это должно быть условие, не параметр
	if params.has("hand_max"):
		report.warning("W912", "hand_max should be in 'condition', not 'params'", sid)

func _v_mana_ramp(params: Dictionary, sid: String) -> void:
	_check_int_range(params.get("power"), 1, 3, "E426", "power", sid)
	if params.has("influence"):
		var inf: String = str(params.get("influence"))
		if not VALID_COLORS.has(inf):
			report.error("E315", "Invalid influence color '%s'" % inf, sid)

func _v_token_generation(params: Dictionary, sid: String) -> void:
	var token_id = params.get("token_id")
	if token_id == null or str(token_id).is_empty():
		report.error("E430", "TOKEN_GENERATION requires non-empty token_id", sid)
	elif str(token_id) != "random_cheap":
		# Для конкретных токенов проверяем статы
		for stat in ["atk", "hp"]:
			if params.has(stat):
				_check_int_range(params[stat], 0, STAT_MOD_MAX, "E431", stat, sid)
	_check_int_range(params.get("count"), TOKEN_COUNT_MIN, TOKEN_COUNT_MAX, "E432", "count", sid)
	if params.has("keywords"):
		var kws = params["keywords"]
		if not (kws is Array):
			report.error("E226", "keywords must be an Array", sid)
		else:
			for kw in kws:
				_check_status(str(kw), sid)

func _v_relic_interaction(params: Dictionary, sid: String) -> void:
	var action = params.get("action")
	if action == null:
		report.error("E433", "RELIC_INTERACTION requires 'action'", sid)
	elif not VALID_RELIC_ACTIONS.has(str(action)):
		report.error("E316", "Invalid relic action '%s'. Valid: %s" % [action, ", ".join(VALID_RELIC_ACTIONS)], sid)
	if params.has("draw_on_destroy"):
		_check_int_range(params["draw_on_destroy"], 1, DRAW_COUNT_MAX, "E434", "draw_on_destroy", sid)

func _v_keyword_buff(params: Dictionary, sid: String) -> void:
	_check_status(str(params.get("keyword", "")), sid)
	for stat in ["atk", "hp"]:
		if params.has(stat):
			_check_int_range(params[stat], STAT_MOD_MIN, STAT_MOD_MAX, "E435", stat, sid)
	if params.has("duration"):
		_check_int_range(params["duration"], -1, 5, "E436", "duration", sid)

func _v_choice_cycle(params: Dictionary, sid: String) -> void:
	_check_int_range(params.get("draw"), 1, DRAW_COUNT_MAX, "E437", "draw", sid)
	if params.has("secondary"):
		var sec: String = str(params.get("secondary"))
		if not VALID_CHOICE_SECONDARY.has(sec):
			report.error("E317", "Invalid choice secondary '%s'. Valid: %s" % [sec, ", ".join(VALID_CHOICE_SECONDARY)], sid)

func _v_touch_cycle(params: Dictionary, sid: String) -> void:
	_check_int_range(params.get("atk"), 0, 3, "E438", "atk", sid)
	_check_int_range(params.get("hp"), 0, 3, "E439", "hp", sid)
	# Touch cycle — перманентный бафф, оба значения должны быть >= 0
	if int(params.get("atk", 0)) < 0 or int(params.get("hp", 0)) < 0:
		report.error("E440", "TOUCH_CYCLE must be a buff (non-negative stats)", sid)

func _v_display_cycle(params: Dictionary, sid: String) -> void:
	var has_reduction: bool = params.has("cost_reduction")
	var has_influence: bool = params.has("influence")
	var has_trigger: bool = params.has("trigger")
	if not has_reduction and not has_influence and not has_trigger:
		report.error("E441", "DISPLAY_CYCLE requires cost_reduction, influence, or trigger", sid)
	if has_reduction:
		_check_int_range(params["cost_reduction"], 1, 3, "E442", "cost_reduction", sid)
	if has_influence:
		var inf: String = str(params.get("influence"))
		if not VALID_COLORS.has(inf):
			report.error("E318", "Invalid influence '%s'" % inf, sid)

func _v_discard_draw(params: Dictionary, sid: String) -> void:
	_check_int_range(params.get("discard"), 0, 3, "E443", "discard", sid)
	_check_int_range(params.get("draw"), 1, DRAW_COUNT_MAX, "E444", "draw", sid)
	if params.has("shuffle_back") and not (params["shuffle_back"] is bool):
		report.error("E227", "shuffle_back must be bool", sid)

func _v_market_niche(params: Dictionary, sid: String) -> void:
	var action = params.get("action")
	if action == null:
		report.error("E445", "MARKET_NICHE requires 'action'", sid)
		return
	var action_str: String = str(action)
	if not VALID_MARKET_ACTIONS.has(action_str):
		report.error("E319", "Invalid market action '%s'. Valid: %s" % [action_str, ", ".join(VALID_MARKET_ACTIONS)], sid)
	if action_str == "draw_from_market":
		if params.has("market_cost"):
			_check_int_range(params["market_cost"], 0, 3, "E446", "market_cost", sid)
		else:
			report.warning("W913", "draw_from_market without explicit market_cost", sid)
	if action_str == "trigger_on_discard":
		if not params.has("trigger_effect"):
			report.error("E447", "trigger_on_discard requires 'trigger_effect'", sid)

# ==================== УРОВЕНЬ 5: ЦЕЛОСТНОСТЬ ====================

func _validate_uniqueness() -> void:
	# Уникальность проверяется в _validate_entry (_ids_seen / _names_seen)
	pass

func _validate_totals() -> void:
	var actual: int = _spells.size()
	if actual != EXPECTED_TOTAL:
		report.warning("W920", "Expected %d spells, found %d (diff %+d)" % [EXPECTED_TOTAL, actual, actual - EXPECTED_TOTAL])

# ==================== УРОВЕНЬ 6: БАЛАНС ====================

func _validate_balance() -> void:
	var template_counts = {}
	var color_counts = {}
	var cost_counts = {}
	var speed_counts = {}

	for entry in _spells:
		if not (entry is Dictionary):
			continue
		var t: String = str(entry.get("template", ""))
		var c: String = str(entry.get("color", ""))
		var cost: int = int(entry.get("cost", 0))
		var sp: String = str(entry.get("speed", ""))
		template_counts[t] = int(template_counts.get(t, 0)) + 1
		color_counts[c] = int(color_counts.get(c, 0)) + 1
		cost_counts[cost] = int(cost_counts.get(cost, 0)) + 1
		speed_counts[sp] = int(speed_counts.get(sp, 0)) + 1

	# --- Распределение по шаблонам ---
	for template in EXPECTED_TEMPLATE_COUNTS:
		var expected: int = int(EXPECTED_TEMPLATE_COUNTS[template])
		var actual: int = int(template_counts.get(template, 0))
		if actual != expected:
			report.warning("W921", "Template '%s': expected %d, got %d" % [template, expected, actual])
	report.stats["template_distribution"] = template_counts

	# --- Распределение по цветам ---
	report.stats["color_distribution"] = color_counts
	var max_color := 0
	var min_color := 999999
	for c in color_counts:
		max_color = maxi(max_color, int(color_counts[c]))
		min_color = mini(min_color, int(color_counts[c]))
	if color_counts.size() > 1 and float(max_color) > float(min_color) * 4.0:
		report.warning("W922", "Color imbalance: max=%d, min=%d (ratio %.1f)" % [max_color, min_color, float(max_color) / float(min_color)])

	# --- Распределение по стоимости (кривая маны) ---
	report.stats["cost_curve"] = cost_counts
	var low_cost: int = int(cost_counts.get(1, 0)) + int(cost_counts.get(2, 0))
	var total: int = _spells.size()
	if total > 0 and float(low_cost) / float(total) > 0.6:
		report.warning("W923", "Too many low-cost spells (%.0f%% cost 1-2)" % (100.0 * float(low_cost) / float(total)))

	# --- Скорость ---
	report.stats["speed_distribution"] = speed_counts
	var fast_count: int = int(speed_counts.get("fast", 0))
	if total > 0 and float(fast_count) / float(total) > 0.85:
		report.warning("W924", "Almost all spells are 'fast' (%.0f%%)" % (100.0 * float(fast_count) / float(total)))

	# --- Средняя стоимость ---
	var sum_cost := 0
	for entry in _spells:
		if entry is Dictionary:
			sum_cost += int(entry.get("cost", 0))
	if total > 0:
		report.stats["avg_cost"] = float(sum_cost) / float(total)

# ==================== УТИЛИТЫ ====================

func _check_int_range(val, lo: int, hi: int, code: String, field: String, sid: String) -> void:
	if val == null:
		return
	if not (val is int or val is float):
		report.error("E230", "Field '%s' must be a number, got %s" % [field, _type_name(val)], sid)
		return
	var v: int = int(val)
	if v < lo or v > hi:
		report.error(code, "Field '%s' = %d out of range [%d, %d]" % [field, v, lo, hi], sid)

func _check_target(params: Dictionary, sid: String, allowed: Array) -> void:
	var target = params.get("target")
	if target == null:
		return
	var t: String = str(target)
	if not VALID_TARGETS.has(t):
		report.error("E320", "Unknown target '%s'" % t, sid)
	elif not allowed.has(t):
		report.warning("W925", "Target '%s' is unusual for this template" % t, sid)

func _check_status(status: String, sid: String) -> void:
	if status.is_empty():
		return
	if not VALID_STATUSES.has(status):
		report.error("E321", "Unknown status/keyword '%s'. Valid: %s" % [status, ", ".join(VALID_STATUSES)], sid)

func _type_name(v) -> String:
	if v == null: return "null"
	if v is bool: return "bool"
	if v is int or v is float: return "number"
	if v is String: return "String"
	if v is Array: return "Array"
	if v is Dictionary: return "Dictionary"
	return "unknown"

func _template_list() -> String:
	var keys = TEMPLATES.keys()
	return ", ".join(keys)
