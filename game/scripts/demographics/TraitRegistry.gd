class_name TraitRegistry
extends RefCounted
## Реестр черт (M2: Демография).
##
## Штатный набор определяется статически (_default_traits); реестр
## расширяем через add() (контент-пакеты). roll_traits() выдаёт 0..3
## черты с весами по редкости. Чистый RefCounted — без узлов.

var _traits: Dictionary = {}  # StringName -> TraitDef
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	for t in _default_traits():
		_traits[t.id] = t
	_rng.seed = 20260829


## (Параметр не trait: имя зарезервировано в GDScript 4.7.)
func add(t_def: TraitDef) -> void:
	if t_def == null or t_def.id == &"":
		push_error("TraitRegistry.add: пустой id")
		return
	_traits[t_def.id] = t_def


func get_trait(id: StringName) -> TraitDef:
	## (Не get(): переопределял бы Object.get() — ошибка при компиляции.)
	return _traits.get(id, null)


func has(id: StringName) -> bool:
	return _traits.has(id)


func all() -> Array[TraitDef]:
	var out: Array[TraitDef] = []
	for id in _traits:
		out.append(_traits[id])
	return out


func by_tag(tag: StringName) -> Array[TraitDef]:
	var out: Array[TraitDef] = []
	for t in all():
		if t.tags.has(tag):
			out.append(t)
	return out


func by_rarity(rarity: int) -> Array[TraitDef]:
	var out: Array[TraitDef] = []
	for t in all():
		if t.rarity == rarity:
			out.append(t)
	return out


## Выкатывает 0..3 черты с весами по редкости.
## Количество: 0 (15%), 1 (35%), 2 (35%), 3 (15%).
## Повторов одной черты нет.
func roll_traits(rng: RandomNumberGenerator = null, max_count: int = 3) -> Array[TraitDef]:
	var r: RandomNumberGenerator = rng if rng != null else _rng
	var roll: int = r.randi_range(0, 99)
	var count := 1
	if roll < 15:
		count = 0
	elif roll >= 85:
		count = 3
	count = mini(count, max_count)

	var pool: Dictionary = {}  # rarity -> Array[TraitDef]
	for t in all():
		if not pool.has(t.rarity):
			pool[t.rarity] = []
		(pool[t.rarity] as Array).append(t)

	var result: Array[TraitDef] = []
	var used: Array[StringName] = []
	for i in count:
		var picked: TraitDef = _pick_weighted(pool, used, r)
		if picked != null:
			result.append(picked)
			used.append(picked.id)
	return result


## Веса редкости: common 70 / uncommon 20 / rare 7 / legendary 3.
func _pick_weighted(pool: Dictionary, used: Array[StringName], r: RandomNumberGenerator) -> TraitDef:
	var weights: Array[int] = [70, 20, 7, 3]
	var candidates: Array[TraitDef] = []
	var cand_weights: Array[int] = []
	var total := 0
	for rarity in weights.size():
		var list: Array = pool.get(rarity, [])
		var available: Array[TraitDef] = []
		for t in list:
			if not used.has(t.id):
				available.append(t)
		if available.is_empty():
			continue
		var pick: TraitDef = available[r.randi_range(0, available.size() - 1)]
		candidates.append(pick)
		cand_weights.append(weights[rarity])
		total += weights[rarity]
	if total <= 0:
		return null
	var roll: int = r.randi_range(0, total - 1)
	for i in candidates.size():
		roll -= cand_weights[i]
		if roll < 0:
			return candidates[i]
	return candidates[candidates.size() - 1]


## Базовый набор черт мира (16 шт., 4 на редкость).
static func _default_traits() -> Array[TraitDef]:
	return [
		_trait(&"hardy", "Крепкий", "Редко голодает: +0.10 к сытости в день.",
			TraitDef.Rarity.COMMON, &"hunger", 0.10, [&"body"]),
		_trait(&"sleepy", "Соня", "Сильно устаёт: -0.08 к отдыху в день.",
			TraitDef.Rarity.COMMON, &"rest", -0.08, [&"body"]),
		_trait(&"chatty", "Болтун", "Обожает компанию: +0.10 к общению.",
			TraitDef.Rarity.COMMON, &"social", 0.10, [&"mind"]),
		_trait(&"loner", "Отшельник", "Избегает толпы: -0.10 к общению.",
			TraitDef.Rarity.COMMON, &"social", -0.10, [&"mind"]),
		_trait(&"devout", "Верующий", "Вера даёт опору: +0.10 к вере.",
			TraitDef.Rarity.COMMON, &"belief", 0.10, [&"soul"]),
		_trait(&"skeptic", "Скептик", "Сомневается во всём: -0.08 к вере.",
			TraitDef.Rarity.COMMON, &"belief", -0.08, [&"soul"]),
		_trait(&"appetite", "Обжора", "Ест за троих: -0.12 к сытости в день.",
			TraitDef.Rarity.UNCOMMON, &"hunger", -0.12, [&"body", "food"]),
		_trait(&"insomniac", "Бессонница", "Не может уснуть: -0.10 к отдыху.",
			TraitDef.Rarity.UNCOMMON, &"rest", -0.10, [&"body"]),
		_trait(&"charismatic", "Обаятельный", "Сводит людей с ума: +0.15 к общению.",
			TraitDef.Rarity.UNCOMMON, &"social", 0.15, [&"mind", "social"]),
		_trait(&"heretic", "Еретик", "Вера причиняет боль: -0.12 к вере.",
			TraitDef.Rarity.UNCOMMON, &"belief", -0.12, [&"soul", "faith"]),
		_trait(&"iron_stomach", "Стальной желудок", "Еда почти не кончается: +0.25 к сытости.",
			TraitDef.Rarity.RARE, &"hunger", 0.25, [&"body", "food"]),
		_trait(&"restless", "Вечное движение", "Тело требует труда: -0.05 к отдыху, +0.10 к общению.",
			TraitDef.Rarity.RARE, &"", 0.0, [&"body", "social"], {&"rest": -0.05, &"social": 0.10}),
		_trait(&"prophet_ear", "Дар пророка", "Слышит шёпот Сигилла: +0.20 к вере.",
			TraitDef.Rarity.RARE, &"belief", 0.20, [&"soul", "faith"]),
		_trait(&"nervous", "Тревожный", "Беспокоится в любое время: -0.06 к отдыху, но компания успокаивает: +0.06 к общению.",
			TraitDef.Rarity.RARE, &"", 0.0, [&"body", "mind"], {&"rest": -0.06, &"social": 0.06}),
		_trait(&"gorgon_taste", "Горгонский вкус", "Каждый глоток — праздник: +0.10 к сытости, +0.10 к общению.",
			TraitDef.Rarity.LEGENDARY, &"", 0.0, [&"body", "food", "social"], {&"hunger": 0.10, &"social": 0.10}),
		_trait(&"sigil_touched", "Повитый Сигиллом", "Родовое клеймо: +0.15 ко всем потребностям.",
			TraitDef.Rarity.LEGENDARY, &"belief", 0.15, [&"soul", "sigil"]),
		_trait(&"eternal_wanderer", "Вечный странник", "Дом — дорога: -0.05 к отдыху, +0.20 к вере.",
			TraitDef.Rarity.LEGENDARY, &"", 0.0, [&"soul", "mind"], {&"rest": -0.05, &"belief": 0.20}),
		_trait(&"stone_heart", "Каменное сердце", "Не устаёт, но и не согревается: +0.15 к отдыху, -0.15 к общению.",
			TraitDef.Rarity.LEGENDARY, &"", 0.0, [&"body", "soul"], {&"rest": 0.15, &"social": -0.15}),
	]


static func _trait(id: StringName, name: String, desc: String, rarity: int,
		effect_type: StringName, value: float, tags: Array, effects: Dictionary = {}) -> TraitDef:
	var t := TraitDef.new()
	t.id = id
	t.display_name = name
	t.description = desc
	t.rarity = rarity
	t.effect_type = effect_type
	t.effect_value = value
	for k in effects:
		t.effects[StringName(k)] = float(effects[k])
	for tag in tags:
		t.tags.append(StringName(tag))
	return t
