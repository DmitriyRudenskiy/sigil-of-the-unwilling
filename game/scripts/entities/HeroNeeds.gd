extends RefCounted
class_name HeroNeeds
## hero-survival: core-потребности героя (rest/social/inspiration).
## remove-hunger-mechanic: голод удалён — еда не влияет на выживание.
##
## Чистый RefCounted-компонент (паттерн HeroMagic/HeroSkills): считает только.
## Распад — каждый ход; восстановление — только в дружественном городе
## (таблица та же, что у citizens в DemographicTurnProcessor, без трейтов).
## Потребность в нуле DEATH_STREAK ходов подряд = смерть: tick() возвращает
## cause (StringName), а HeroController шлёт GameEventBus.hero_died(cause).

## Ключи — один канонический набор на проект (demographics.Character).
const NEED_KEYS: Array[StringName] = Character.NEED_KEYS

## Базовый ежедневный распад (дефолт DemographicTurnProcessor.DECAY).
const DECAY: Dictionary = {
	&"rest": 0.10,
	&"social": 0.08,
	&"inspiration": 0.05,
}

## Нулевая потребность DEATH_STREAK ходов подряд = смерть.
const DEATH_STREAK := 3
## Критический порог (UI-подсветка, Character.is_need_critical дефолт).
const CRITICAL_THRESHOLD := 0.2

var needs: Dictionary = {}      # StringName -> float 0..1
var zero_streak: Dictionary = {}  # StringName -> int


func _init() -> void:
	for k in NEED_KEYS:
		needs[k] = 1.0
		zero_streak[k] = 0


## Прогнать один ход. in_city=true и city!=null — герой в городе:
## recovery по таблице citizens. Возвращает cause смерти (&"" — жив).
func tick(in_city: bool, city: City = null) -> StringName:
	for k in NEED_KEYS:
		var delta := -float(DECAY[k])
		if in_city and city != null:
			delta += _recovery(k, city)
		needs[k] = clampf(float(needs[k]) + delta, 0.0, 1.0)
		if float(needs[k]) <= 0.0001:
			zero_streak[k] = int(zero_streak[k]) + 1
		else:
			zero_streak[k] = 0
	for k in NEED_KEYS:
		if int(zero_streak[k]) >= DEATH_STREAK:
			return _death_cause(k)
	return &""


## Таблица восстановления героя в городе: темп героя, не citizens.
## (В citizens-таблице герой в поле выжить математически не может: inspiration
## net 0.00 даже в городе — гарантированный burnout-дедлайн ~день 20, и
## сценарии 1–4 умирали на днях 8–20.)
func _recovery(need_id: StringName, city: City) -> float:
	match need_id:
		&"rest":
			return 0.36
		&"social":
			# Компания есть, если население прилично.
			if city.pop.size() >= 3:
				return 0.30
			return -0.05
		&"inspiration":
			return 0.15
	return 0.0


func _death_cause(need_id: StringName) -> StringName:
	match need_id:
		&"rest":
			return &"exhaustion"
		&"social":
			return &"isolation"
		&"inspiration":
			return &"burnout"
	return &""


func get_need(id: StringName) -> float:
	return float(needs.get(id, 0.0))


func is_critical(id: StringName) -> bool:
	return float(needs.get(id, 0.0)) < CRITICAL_THRESHOLD


func reset() -> void:
	for k in NEED_KEYS:
		needs[k] = 1.0
		zero_streak[k] = 0


func serialize() -> Dictionary:
	var out := {}
	for k in NEED_KEYS:
		out[String(k)] = float(needs.get(k, 1.0))
	return out


func deserialize(d: Dictionary) -> void:
	for k in NEED_KEYS:
		# Старые сейвы без needs — дефолт 1.0 (ключ может отсутствовать).
		if d.has(String(k)):
			needs[k] = clampf(float(d[String(k)]), 0.0, 1.0)
		else:
			needs[k] = 1.0
		# Streak не сериализуется: после загрузки счётчик заново.
		zero_streak[k] = 0
