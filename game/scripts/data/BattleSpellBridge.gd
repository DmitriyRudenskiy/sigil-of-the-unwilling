extends RefCounted
class_name BattleSpellBridge
## Мост между боевой системой заклинаний (SpellRegistry, 20 заклинаний) и
## картовой («быстрой») архитектурой (SpellbookDef).
##
## Зачем нужно: боевые заклинания описаны в `SpellRegistry` (класс `SpellDef`
## с полями `damage_multiplier` / `buff_effect`), а система заклинаний работает
## с шаблонами (`template`) и параметрами (`params`). Этот класс делает два
## вещи:
##
##   1. `to_spell()` — представляет боевое заклинание как быстрое («быстрое»)
##      заклинание: `speed = FAST`, шаблон и параметры выведены из категории
##      боевого заклинания.
##   2. `apply_spell()` — применяет заклинание в контексте боя на
##      реальном `BattleState.BattleUnit` (как обычное заклинание): урон,
##      статус, лечение/очистка, воскрешение. Форма результата повторяет
##      `SpellCaster.cast`, поэтому проверки бою однотипны.
##
## Использование:
##   var spell: SpellbookDef = BattleSpellBridge.to_spell(spell_def)
##   var result: Dictionary = BattleSpellBridge.apply_spell(spell, target, caster_bonus, target_bonus, rng)

const _Def = preload("res://scripts/data/SpellbookDef.gd")
const _Enums = preload("res://scripts/data/SpellEnums.gd")
const _SE = preload("res://scripts/data/StatusEffects.gd")

# ==================== МАППИНГИ ====================

## Ключевое слово → StatusEffects.Effect.
## Система заклинаний использует свой enum StatusType, но боевые эффекты —
## в `StatusEffects.Effect`; маппинг нужен, чтобы применять статус на юните.
static var KEYWORD_TO_EFFECT: Dictionary = {
	"HASTE": _SE.Effect.HASTE,
	"PRECISION": _SE.Effect.PRECISION,
	"WIND_WALL": _SE.Effect.WIND_WALL,
	"BLOODLUST": _SE.Effect.BLOODLUST,
	"BLESS": _SE.Effect.BLESS,
	"CURSE": _SE.Effect.CURSE,
	"MISFORTUNE": _SE.Effect.MISFORTUNE,
	"SLOW": _SE.Effect.SLOW,
	"WEAKNESS": _SE.Effect.WEAKNESS,
	"SHIELD": _SE.Effect.SHIELD,
	"STONESKIN": _SE.Effect.STONESKIN,
}

## Обратный маппинг: StatusEffects.Effect → KEYWORD (верхний регистр).
static var _EFFECT_TO_KEYWORD: Dictionary = {}

## Школа SpellRegistry → цвет заклинания (палитра: fire/time/justice/primal/shadow).
static var SCHOOL_TO_COLOR: Dictionary = {
	"Air": "time",
	"Fire": "fire",
	"Water": "primal",
	"Earth": "primal",
}

# Шаблонные константы (система заклинаний знает 16 шаблонов; здесь используются
# DIRECT_DAMAGE / KEYWORD_BUFF / DEBUFF_CONTROL + 3 боевых спец-шаблона).
const T_DIRECT_DAMAGE := &"DIRECT_DAMAGE"
const T_KEYWORD_BUFF := &"KEYWORD_BUFF"
const T_DEBUFF_CONTROL := &"DEBUFF_CONTROL"
const T_HEAL_CLEAR := &"HEAL_CLEAR"     # cure: исцеление + очистка дебаффов
const T_REVIVE := &"REVIVE"             # resurrection: воскрешение
const T_PORTAL := &"PORTAL"             # town_portal: безопасный no-op

# ==================== 1. КОНВЕРТЕР: боевое заклинание → карта ====================

## Превратить `SpellRegistry.SpellDef` в быстрое («быстрое») заклинание.
static func to_spell(def: Variant) -> _Def:
	var s := def as SpellRegistry.SpellDef
	if s == null:
		return null
	var spell := _Def.new()
	spell.id = s.id
	spell.display_name = s.display_name
	spell.speed = _Enums.SpellSpeed.FAST
	spell.cost = s.base_mana
	spell.color = _Enums.parse_color(SCHOOL_TO_COLOR.get(s.school, "colorless"))
	spell.template = _template_for(s)
	spell.params = _params_for(s)
	spell.description = s.desc
	return spell

## Шаблон по категории боевого заклинания.
static func _template_for(s: SpellRegistry.SpellDef) -> StringName:
	if s.id == &"cure":
		return T_HEAL_CLEAR
	if s.id == &"resurrection":
		return T_REVIVE
	if s.id == &"town_portal":
		return T_PORTAL
	if s.damage_multiplier > 0:
		return T_DIRECT_DAMAGE
	if s.buff_effect >= 0:
		if _SE.is_debuff(s.buff_effect):
			return T_DEBUFF_CONTROL
		return T_KEYWORD_BUFF
	return T_PORTAL

## Параметры по категории. `level` несем в params для проверки иммунности
## (драконы免疫 заклинаниям < 4 уровня) в apply_spell.
static func _params_for(s: SpellRegistry.SpellDef) -> Dictionary:
	var p: Dictionary = {"level": s.level}
	if s.damage_multiplier > 0:
		p.template_hint = T_DIRECT_DAMAGE
		p["amount"] = s.damage_multiplier
		p["target"] = _damage_target(s.id)
		return p
	if s.buff_effect >= 0:
		# Эффект — StatusEffects.Effect. Ключ = верхний регистр имени
		# эффекта (маппинг KEYWORD_TO_EFFECT работает по верхнему регистру).
		p["keyword"] = _keyword_for_effect(s.buff_effect)
		if _SE.is_debuff(s.buff_effect):
			p["mass"] = (s.id == &"slow_mass")
		return p
	return p

## Верхний регистр имени эффекта StatusEffects.Effect (обратный маппинг
## для KEYWORD_TO_EFFECT). get_name() не используем — он конфликтует с
## встроенным Object.get_name() (0 аргументов).
static func _keyword_for_effect(effect: int) -> String:
	if _EFFECT_TO_KEYWORD.is_empty():
		for kw in KEYWORD_TO_EFFECT:
			_EFFECT_TO_KEYWORD[KEYWORD_TO_EFFECT[kw]] = String(kw)
	return _EFFECT_TO_KEYWORD.get(effect, "UNKNOWN")

## Куда летит урон: магия по одной/всем врагам.
static func _damage_target(id: StringName) -> String:
	match id:
		&"fireball", &"armageddon", &"meteor_shower":
			return "ALL_ENEMY_UNITS"
		_:
			return "ENEMY_UNIT"

# ==================== 2. ПРИМЕНЕНИЕ ЗАКЛИНАНИЯ В Ю ====================

## Применить заклинание к юниту в контексте боя. Возвращает словарь
## в форме, повторяющей `SpellCaster.cast`:
##   {result, damage, kills, status, resisted, heal, revive_count, spell_id}.
static func apply_spell(
	spell: Variant,
	target: BattleState.BattleUnit,
	caster_bonus: Dictionary,
	target_bonus: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	if spell == null:
		return {"result": "not_found", "spell_id": null}
	if target == null:
		return {"result": "invalid_target", "spell_id": spell.id}
	var is_res: bool = (spell.template == T_REVIVE)
	if not is_res and not target.is_alive():
		return {"result": "invalid_target", "spell_id": spell.id}

	if _check_immunity(target, spell):
		return {"result": "immune", "spell_id": spell.id}

	var resist: bool = rng.randf() < _calc_resistance(target, target_bonus)
	var sp: int = int(caster_bonus.get("spell_power", 0))
	var result := {
		"result": "success",
		"damage": 0,
		"status": -1,
		"resisted": resist,
		"spell_id": spell.id,
	}

	match spell.template:
		T_DIRECT_DAMAGE:
			var dmg: int = sp * int(spell.params.get("amount", 0))
			if resist:
				dmg = int(dmg * 0.5)
			result = _apply_damage(target, dmg, result)
		T_KEYWORD_BUFF, T_DEBUFF_CONTROL:
			var kw: String = str(spell.params.get("keyword", "")).to_upper()
			var eff: int = KEYWORD_TO_EFFECT.get(kw, -1)
			if eff >= 0:
				target.add_status(eff, 3)
				result.status = eff
		T_HEAL_CLEAR:
			if target.has_method("clear_debuffs"):
				target.clear_debuffs()
			result.heal = sp * 10
		T_REVIVE:
			if target.get_count() <= 0:
				var hp: int = max(1, target.get_hp())
				var revived: int = int(sp * 20 / hp)
				revived = max(1, revived)
				revived = min(revived, target.max_count)
				result["revive_count"] = revived
		T_PORTAL:
			pass
	return result

# ==================== ХЕЛПЕРЫ (аналог SpellCaster) ====================

static func _apply_damage(unit: BattleState.BattleUnit, dmg: int, result: Dictionary) -> Dictionary:
	var hp: int = max(1, unit.get_hp())
	var kills: int = max(1, dmg / hp)
	kills = min(kills, unit.get_count())
	result.damage = dmg
	result.kills = kills
	return result

static func _check_immunity(unit: BattleState.BattleUnit, spell: Variant) -> bool:
	if spell == null:
		return false
	var spell_id: StringName = spell.id
	var spell_level: int = int(spell.params.get("level", 1))
	# Нежить иммунна к исцелению/проклятиям/замедлению.
	if unit.has_tag("undead") and spell_id in [&"bless", &"cure", &"curse", &"weakness", &"slow"]:
		return true
	# Драконы иммунны к заклинаниям < 4 уровня.
	if unit.has_tag("dragon") and spell_level < 4:
		return true
	# Иммунитет разума: дебаффы разума.
	if unit.has_tag("immune_mind") or unit.has_tag("mind_immune"):
		if spell_id in [&"curse", &"misfortune", &"weakness", &"slow"]:
			return true
	return false

static func _calc_resistance(unit: BattleState.BattleUnit, hero_bonus: Dictionary) -> float:
	var base: float = 0.05 * int(hero_bonus.get("knowledge", 0))
	if unit.has_tag("magic_resistant"):
		base += 0.40
	return clampf(base, 0.0, 0.9)
