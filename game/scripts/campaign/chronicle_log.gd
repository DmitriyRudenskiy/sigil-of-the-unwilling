## Хроника поселения (04-narrative «Доставка нарратива», T-175 → D-240): лента
## событий «что случилось и почему» — главный канал нарратива MVP.
##
## Формат записи задаёт канон, а не `TelemetryLog` (T-175 → D-240: лента —
## кампанийное состояние, метрика сессии остаётся метрикой сессии):
##   • событие = запись (не «ход N: event_id»), до 3 строк (EC «один текстовый
##     блок за событие ≤3 строки»);
##   • до 5 записей за ход, дальше — сводка (EC2 «лимит 5 записей/день»);
##   • бит = запись хроники, одноразовая (правило битов, K-M9: каркас 1/7/14/17/21).
##
## Запись хранит ключ перевода и именованные аргументы, а не готовую строку:
## лента — состояние кампании, а язык — настройка, которая может смениться между
## сеансами. Ключи закрыты множеством `KNOWN_KEYS`: запись с неизвестным ключом
## (ручная правка сейва, опечатка) в ленту не попадает — иначе игрок увидел бы
## сырой ключ.
##
## I1: чистый RefCounted, ГСЧ нет, порядок детерминирован — записи добавляются по ходу.
class_name ChronicleLog
extends RefCounted

## EC2 (04-narrative): «лимит 5 записей/день, дальше — сводка».
const MAX_RECORDS_PER_DAY := 5
## «Один текстовый блок за событие ≤3 строки» (04-narrative «Правила»).
const MAX_LINES_PER_RECORD := 3
## Строка сводки дня (счётчик свёрнутых событий).
const SUMMARY_KEY := "chronicle.day_summary"
## Ключи, которые хронике писать имеет право. Их пишут системы-носители событий;
## множество закрыто, потому что строка ленты обязана существовать в `locale/`
## (иначе в кадре будет ключ, а не предложение).
const KNOWN_KEYS: Array[String] = [
	"chronicle.bit_sign",
	"chronicle.bit_first_raid",
	"chronicle.bit_district",
	"chronicle.bit_strong_raid",
	"chronicle.bit_final_raid",
	"chronicle.raid_repelled",
	"chronicle.raid_deficit",
	"chronicle.raid_party_away",
	"chronicle.raids_all_ruined",
	"chronicle.wave_warning",
	"chronicle.food_warn",
	"chronicle.district_created",
	"chronicle.district_disbanded",
	SUMMARY_KEY,
]

## Дни ленты: [{turn: int, records: [запись]}] в порядке записи.
## Запись: {summary: bool, lines: [{key: String, args: Dictionary}]}.
## Флага «это бит» у записи нет: он нигде не читается (экрану всё равно, чем
## рисовать строку), а одноразовость бита держится в `_bits`, а не в ленте.
var _days: Array = []
## Сработавшие биты (id) — гарантия «бит = одна запись за кампанию».
var _bits: Array[String] = []


## Записать событие: `lines` = [{key, args}]. Лишние строки (сверх канонических
## трёх) отбрасываются, пустое событие не пишется. Возвращает false, если
## событие в ленту не попало (пустые или неизвестные ключи).
## `bypass_cap` — событие вне дневного лимита (им пользуется бит, см. ниже).
func record_event(turn: int, lines: Array, bypass_cap: bool = false) -> bool:
	var kept: Array = []
	for line in lines:
		if not (line is Dictionary):
			continue
		var key := str((line as Dictionary).get("key", ""))
		if not KNOWN_KEYS.has(key):
			continue
		var raw_args: Variant = (line as Dictionary).get("args", {})
		var args: Dictionary = raw_args if raw_args is Dictionary else {}
		kept.append({"key": key, "args": args.duplicate()})
		if kept.size() >= MAX_LINES_PER_RECORD:
			break
	if kept.is_empty():
		return false
	var day: Dictionary = _day_for(turn)
	var records: Array = day["records"]
	if not bypass_cap and records.size() >= MAX_RECORDS_PER_DAY:
		# Сводка дня: шестое и последующие события того же хода сворачиваются
		# в одну строку-счётчик (EC2). Бит сводке не отдаётся: он и есть причина
		# открыть хронику (правило битов), поэтому дописывается мимо лимита —
		# расхождение с буквальной «пятью записями» зафиксировано в D-240.
		var last: Variant = records[records.size() - 1]
		if last is Dictionary and bool((last as Dictionary).get("summary", false)):
			var summary_line: Dictionary = ((last as Dictionary)["lines"] as Array)[0]
			var counts: Dictionary = summary_line["args"]
			counts["count"] = int(counts.get("count", 0)) + 1
			return true
		records.append({
			"summary": true,
			"lines": [{"key": SUMMARY_KEY, "args": {"count": 1}}],
		})
		return true
	records.append({"summary": false, "lines": kept})
	return true


## Записать событие из одной строки.
func record_line(
		turn: int, key: String, args: Dictionary = {}, bypass_cap: bool = false) -> bool:
	return record_event(turn, [{"key": key, "args": args}], bypass_cap)


## Записать нарративный бит (04-narrative «Ключевые биты кампании»): тот же текст
## появляется в ленте не более одного раза за кампанию.
func record_bit(turn: int, bit_id: String, key: String, args: Dictionary = {}) -> bool:
	if _bits.has(bit_id):
		return false
	if not record_line(turn, key, args, true):
		return false
	_bits.append(bit_id)
	return true


func has_bit(bit_id: String) -> bool:
	return _bits.has(bit_id)


## Плоская лента для рендера: [{turn, lines:[{key, args}]}] в порядке
## записи (в каком конце показывать — решение экрана).
func records() -> Array:
	var out: Array = []
	for day in _days:
		for rec in (day as Dictionary)["records"]:
			out.append({
				"turn": int((day as Dictionary)["turn"]),
				"lines": ((rec as Dictionary).get("lines", []) as Array).duplicate(true),
			})
	return out


## Сколько записей в ленте за ход (сводка считается записью).
func record_count_for(turn: int) -> int:
	for day in _days:
		if int((day as Dictionary)["turn"]) == turn:
			return ((day as Dictionary)["records"] as Array).size()
	return 0


func is_empty() -> bool:
	return _days.is_empty()


func to_dict() -> Dictionary:
	return {"days": _days.duplicate(true), "bits": _bits.duplicate()}


## Сейв без секции (или секция с мусором) → пустая лента; записи с неизвестными
## ключами отбрасываются на входе, а не на рендере.
static func from_dict(data: Dictionary) -> ChronicleLog:
	var log := ChronicleLog.new()
	var days: Variant = data.get("days", [])
	if days is Array:
		for raw_day in days:
			if not (raw_day is Dictionary):
				continue
			var day: Dictionary = raw_day
			var records: Array = []
			var raw_records: Variant = day.get("records", [])
			if raw_records is Array:
				for raw_rec in raw_records:
					if not (raw_rec is Dictionary):
						continue
					var rec: Dictionary = raw_rec
					var lines: Array = []
					var raw_lines: Variant = rec.get("lines", [])
					if raw_lines is Array:
						for raw_line in raw_lines:
							if not (raw_line is Dictionary):
								continue
							var key := str((raw_line as Dictionary).get("key", ""))
							if not KNOWN_KEYS.has(key):
								continue
							lines.append({
								"key": key,
								"args": _int_args((raw_line as Dictionary).get("args", {})),
							})
					if lines.is_empty():
						continue
					records.append({
						"summary": bool(rec.get("summary", false)),
						"lines": lines,
					})
			if records.is_empty():
				continue
			log._days.append({"turn": int(day.get("turn", 0)), "records": records})
	var bits: Variant = data.get("bits", [])
	if bits is Array:
		for b in bits:
			log._bits.append(str(b))
	return log


## Числа после JSON round-trip — float (`_to_json_types` в CampaignComposition):
## «придёт через 2.0 хода» игрок читать не обязан, счётчик сводки тоже.
static func _int_args(value: Variant) -> Dictionary:
	var out := {}
	if not (value is Dictionary):
		return out
	for k in (value as Dictionary).keys():
		var item: Variant = (value as Dictionary)[k]
		var key := str(k)
		if item is float and float(item) == float(int(float(item))):
			out[key] = int(float(item))
		else:
			out[key] = item
	return out


## День хода (создаётся при первом обращении).
func _day_for(turn: int) -> Dictionary:
	if not _days.is_empty() and int((_days[_days.size() - 1] as Dictionary)["turn"]) == turn:
		return _days[_days.size() - 1]
	for day in _days:
		if int((day as Dictionary)["turn"]) == turn:
			return day
	var fresh := {"turn": turn, "records": []}
	_days.append(fresh)
	return fresh
