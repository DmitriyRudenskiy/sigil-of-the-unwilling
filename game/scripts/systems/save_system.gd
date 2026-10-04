class_name SaveSystem
extends RefCounted
## T-110. Система сейвов (спецификация D-135, Ф4-восстановление, 2026-10-03).
##
## Схема: состояние кампании = словарь секций (SECTIONS). Запрещены
## производные значения (ladder_state, prestige_balance, effective_stats,
## morale) — они пересчитываются при загрузке; prestige — только ledger.
##
## Версия "major.minor": major-несовпадение = ошибка загрузки; minor —
## совместимость: отсутствующие секции (старый минор) заполняются
## дефолтами, лишние секции (новый минор) сохраняются без интерпретации.
##
## 3 слота. Атомарная запись: tmp-файл + rename (DirAccess.rename) —
## обрыв записи не оставляет повреждённого слота.
##
## Байтовая детерминизм (I1): одинаковый вход -> байт-в-байт одинаковый
## сейв — ключи всех словарей рекурсивно сортируются перед сериализацией
## (_deterministic_json). Метки времени в сейв НЕ пишутся.
##
## «Продолжить из меню» — после T-090s: меню вызывает list_slots() +
## load(slot); сама система UI-независима.
##
## Реальное состояние кампании (T-010) подключается сюда как заполнитель
## секций; миграция по версиям — тест test_save_system.gd.

## Текущая версия схемы (major.minor).
const VERSION := "1.0"
## Допустимые слоты.
const SLOTS: Array[int] = [1, 2, 3]
## Каталог сейвов.
const SAVE_DIR := "user://saves"
## Секции схемы: id -> значение по умолчанию (заполняется при загрузке
## сейва с меньшим минором).
const SECTIONS := {
	"campaign": {}, # ход, дата, флаги (T-010)
	"party": {}, # персонажи, уровни, XP
	"city": {}, # состояние города (02g)
	"economy": {}, # запасы (06-economy)
	"map": {}, # регионы, туман, россыпи
	"prestige": {"ledger": []}, # только ledger (пересчёт при загрузке)
}
## Производные ключи, запрещённые в сейве (любой уровень вложенности
## секции): пересчитываются при загрузке.
const FORBIDDEN_KEYS := {
	"ladder": "лестница — производная, пересчитывается при загрузке (02d)",
	"ladder_state": "лестница — производная, пересчитывается при загрузке (02d)",
	"prestige_balance": "prestige — только ledger; баланс пересчитывается при загрузке",
	"effective_stats": "эффективные характеристики — производные, пересчитываются при загрузке",
	"morale": "шкала морали аннулирована (K-M11); пересчитывается при загрузке",
}


func _init() -> void:
	_ensure_dir()


## Атомарная запись состояния в слот. Возвращает Error (OK = успех).
func save(slot: int, state: Dictionary) -> Error:
	if not SLOTS.has(slot):
		push_error("SaveSystem: недопустимый слот %d (допустимы %s)" % [slot, str(SLOTS)])
		return ERR_INVALID_PARAMETER
	var err := validate(state)
	if err != OK:
		return err
	var payload := {
		"version": VERSION,
		"sections": state,
	}
	var bytes := _deterministic_json(payload)
	var path := _slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(bytes)
	f.close()
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return ERR_CANT_OPEN
	var renamed: Error = dir.rename(tmp, path)
	if renamed != OK:
		return renamed
	return OK


## Загрузка слота. Возвращает {"error": Error, "state": Dictionary,
## "version": String}. state заполнен дефолтами по SECTIONS при error == OK.
func load(slot: int) -> Dictionary:
	if not SLOTS.has(slot):
		return {"error": ERR_INVALID_PARAMETER, "state": {}, "version": ""}
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"error": ERR_FILE_NOT_FOUND, "state": {}, "version": ""}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": FileAccess.get_open_error(), "state": {}, "version": ""}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error": ERR_PARSE_ERROR, "state": {}, "version": ""}
	parsed = _restore_ints(parsed)
	var version := String(parsed.get("version", ""))
	if not _same_major(version):
		push_error("SaveSystem: major-несовпадение версий (сейв %s, ожидается %s)" % [version, VERSION])
		return {"error": ERR_INVALID_DATA, "state": {}, "version": version}
	var raw_sections: Variant = parsed.get("sections", {})
	if typeof(raw_sections) != TYPE_DICTIONARY:
		return {"error": ERR_PARSE_ERROR, "state": {}, "version": version}
	var state := {}
	for sec: String in SECTIONS:
		if (raw_sections as Dictionary).has(sec):
			state[sec] = (raw_sections as Dictionary)[sec]
		else:
			state[sec] = _clone_default(sec)
	# Секции нового минора — сохраняются без интерпретации (forward-preservation).
	for sec: String in (raw_sections as Dictionary):
		if not SECTIONS.has(sec):
			state[sec] = (raw_sections as Dictionary)[sec]
	return {"error": OK, "state": state, "version": version}


## Удаление слота.
func delete(slot: int) -> Error:
	if not SLOTS.has(slot):
		return ERR_INVALID_PARAMETER
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return ERR_CANT_OPEN
	return dir.remove(path)


## Слоты, содержащие сейв.
func list_slots() -> Array[int]:
	var result: Array[int] = []
	for slot in SLOTS:
		if FileAccess.file_exists(_slot_path(slot)):
			result.append(slot)
	return result


## Валидация состояния: структура секций + запрещённые производные ключи.
func validate(state: Dictionary) -> Error:
	for key: String in state:
		if FORBIDDEN_KEYS.has(key):
			push_error("SaveSystem: запрещённый производный ключ в корне: %s (%s)" % [key, FORBIDDEN_KEYS[key]])
			return ERR_INVALID_DATA
		var section: Variant = state[key]
		if typeof(section) == TYPE_DICTIONARY:
			for skey: String in (section as Dictionary):
				if FORBIDDEN_KEYS.has(skey):
					push_error("SaveSystem: запрещённый производный ключ в секции %s: %s (%s)" % [key, skey, FORBIDDEN_KEYS[skey]])
					return ERR_INVALID_DATA
		if key == "prestige":
			var err := _validate_prestige(section)
			if err != OK:
				return err
	return OK


## Prestige — только ledger: словарь с единственным ключом "ledger" (Array).
func _validate_prestige(section: Variant) -> Error:
	if typeof(section) != TYPE_DICTIONARY:
		push_error("SaveSystem: секция prestige должна быть Dictionary (ledger)")
		return ERR_INVALID_DATA
	var dict := section as Dictionary
	if dict.size() != 1 or not dict.has("ledger") or typeof(dict["ledger"]) != TYPE_ARRAY:
		push_error("SaveSystem: prestige — только ledger (Array); баланс пересчитывается при загрузке")
		return ERR_INVALID_DATA
	return OK


## Детерминированная сериализация: ключи словарей рекурсивно сортируются
## (I1: одинаковый вход -> байт-в-байт одинаковый сейв).
func _deterministic_json(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict := value as Dictionary
			var keys: Array = dict.keys()
			keys.sort()
			var parts: PackedStringArray = []
			for k in keys:
				parts.append(JSON.stringify(String(k)) + ": " + _deterministic_json(dict[k]))
			return "{" + ", ".join(parts) + "}"
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for item in (value as Array):
				parts.append(_deterministic_json(item))
			return "[" + ", ".join(parts) + "]"
		_:
			# Целочисленный float сериализуется как int: байтовая стабильность
			# цикла save -> load -> save (JSON.parse_string возвращает float).
			if typeof(value) == TYPE_FLOAT:
				var f := value as float
				if f == floor(f) and is_finite(f) and absf(f) < 9007199254740992.0:
					return str(int(f))
			return JSON.stringify(value)


## JSON.parse_string возвращает все числа как float; целочисленные значения
## восстанавливаются в int: типовой раундтрип (turn: 5 -> 5, не 5.0) и
## байтовая детерминизм.
func _restore_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for k in (value as Dictionary):
				result[k] = _restore_ints((value as Dictionary)[k])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in (value as Array):
				result.append(_restore_ints(item))
			return result
		TYPE_FLOAT:
			var f := value as float
			if f == floor(f) and is_finite(f) and absf(f) < 9007199254740992.0:
				return int(f)
			return f
		_:
			return value


func _slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("save_%d.json" % slot)


func _same_major(version: String) -> bool:
	var sv := version.split(".")
	var cv := VERSION.split(".")
	if sv.size() < 2 or cv.size() < 2:
		return false
	return sv[0] == cv[0]


func _clone_default(section_id: String) -> Variant:
	# Глубокое клонирование дефолта секции (чтобы записи в один сейв
	# не влияли на SECTIONS).
	return _deep_clone(SECTIONS[section_id])


func _deep_clone(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for k in (value as Dictionary):
				result[k] = _deep_clone((value as Dictionary)[k])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in (value as Array):
				result.append(_deep_clone(item))
			return result
		_:
			return value


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
