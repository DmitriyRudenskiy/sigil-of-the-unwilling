extends RefCounted
class_name MvpSaveSchema
## T-110 (райдеры владельца, 2026-10-02): контракт MVP-сейва.
## Сейв хранит ТОЛЬКО входные величины; производные пересчитываются при загрузке
## (лестницы — из входов, баланс Престижа — из ledger, эффективные способности —
## из антагонизма/расы). Версия: major.minor — совместимость по minor.

const CURRENT_MAJOR := 1
const CURRENT_MINOR := 0
const SLOT_COUNT := 3

## Секции состояния кампании (только эти ключи разрешены на верхнем уровне).
const SECTIONS := {
	"campaign": TYPE_DICTIONARY,  # {turn, seed, phase}
	"resources": TYPE_DICTIONARY,  # {food, wood, iron, ...}
	"population": TYPE_DICTIONARY,  # {count, housing}
	"party": TYPE_ARRAY,  # [{id, class, race, level, xp, stats{}, luck}]
	"city": TYPE_DICTIONARY,  # здания, районы, гексы (T-030)
	"map": TYPE_DICTIONARY,  # регион, туман, узлы
	"prestige": TYPE_DICTIONARY,  # {ledger: [{turn, source, amount}]} — ТОЛЬКО ledger
	"sign": TYPE_DICTIONARY,  # состояние Знака (R1)
}

## Производные ключи — запрещено в сейве (рекурсивный поиск по всему состоянию).
const DERIVED_KEYS: Array[String] = [
	"ladder",
	"prestige_balance",
	"effective_stats",
	"morale",
]


static func current_version() -> Dictionary:
	return {"major": CURRENT_MAJOR, "minor": CURRENT_MINOR}


## Совместимость: major обязан совпадать, minor — любой (райдер владельца, 2026-10-02).
static func is_compatible(version: Dictionary) -> bool:
	return (
		version.has("major")
		and int(version.get("major", -1)) == CURRENT_MAJOR
		and int(version.get("minor", 0)) >= 0
	)


## Рекурсивный поиск производных ключей. Возвращает пути ("party[0].ladder").
static func find_derived_keys(state: Dictionary, path := "root") -> Array[String]:
	var found: Array[String] = []
	for key in state.keys():
		var key_str := str(key)
		var child := path + "." + key_str
		if DERIVED_KEYS.has(key_str):
			found.append(child)
		var value = state[key]
		if value is Dictionary:
			found.append_array(find_derived_keys(value, child))
		elif value is Array:
			for i in value.size():
				var item = value[i]
				if item is Dictionary:
					found.append_array(find_derived_keys(item, "%s[%d]" % [child, i]))
	return found


## Валидация состояния: "" = ок, иначе — сообщение об ошибке.
static func validate(state: Dictionary) -> String:
	var derived := find_derived_keys(state)
	if not derived.is_empty():
		return "derived keys in save state: %s" % str(derived)
	for section in SECTIONS.keys():
		if not state.has(section):
			return "missing section: %s" % section
		if not _type_ok(state[section], SECTIONS[section]):
			return "section %s has wrong type" % section
	for key in state.keys():
		if not SECTIONS.has(str(key)):
			return "unknown section: %s" % str(key)
	return ""


static func _type_ok(value, expected: int) -> bool:
	match expected:
		TYPE_DICTIONARY:
			return value is Dictionary
		TYPE_ARRAY:
			return value is Array
		_:
			return true
