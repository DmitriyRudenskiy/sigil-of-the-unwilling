class_name CharacterRegistry
extends RefCounted

var _characters: Dictionary = {}
var _by_pop: Dictionary = {}
var _uid_seq := 0
var _trait_registry: TraitRegistry = null

const _NAMES: Array[String] = [
	"Альдо", "Берил", "Велан", "Горм", "Делия", "Эрик",
	"Фенна", "Гарет", "Хельма", "Ирена", "Касс", "Лора",
	"Малк", "Нора", "Одо", "Перн", "Рогна", "Севен",
	"Торм", "Ульда", "Веран", "Яра", "Зев", "Линна",
	"Моро", "Нель", "Окта", "Пирр", "Ренн", "Сель",
	"Тара", "Умбр", "Финн", "Хель", "Цера", "Эола",
]

func _init() -> void:
	_trait_registry = TraitRegistry.new()

func trait_registry() -> TraitRegistry:
	return _trait_registry

func _next_uid() -> int:
	var uid := _uid_seq
	_uid_seq += 1
	return uid

func create(city_uid: int, pop: PopUnit, rng: RandomNumberGenerator = null) -> Character:
	var existing := get_by_pop(pop.uid)
	if existing != null and existing.alive:
		return existing
	if rng == null:
		rng = RandomNumberGenerator.new()
	var ch := Character.new()
	ch.uid = _next_uid()
	ch.name = make_name(rng)
	ch.icon = _pick_icon(rng)
	ch.birth_turn = maxi(pop.born_turn, 0)
	ch.city_uid = city_uid
	ch.pop_uid = pop.uid
	ch.alive = true
	ch.traits = _trait_registry.roll_traits(rng)
	_characters[ch.uid] = ch
	_by_pop[pop.uid] = ch.uid
	pop.character_uid = ch.uid
	return ch

func make_name(rng: RandomNumberGenerator = null) -> String:
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	return _NAMES[r.randi_range(0, _NAMES.size() - 1)]

const _ICONS: Array[String] = ["🙂", "🧔", "👩", "🧓", "👦", "👧", "🧙", "👨‍🌾", "👵", "🧑‍🌾"]

func _pick_icon(rng: RandomNumberGenerator) -> String:
	return _ICONS[rng.randi_range(0, _ICONS.size() - 1)]

func get_by_uid(uid: int) -> Character:
	return _characters.get(uid, null)

func get_by_pop(pop_uid: int) -> Character:
	if not _by_pop.has(pop_uid):
		return null
	var ch := get_by_uid(int(_by_pop[pop_uid]))
	return ch if ch != null and ch.alive else null

func all() -> Array[Character]:
	var out: Array[Character] = []
	for uid in _characters:
		out.append(_characters[uid])
	return out

func alive_in_city(city_uid: int) -> Array[Character]:
	var out: Array[Character] = []
	for ch in all():
		if ch.alive and ch.city_uid == city_uid:
			out.append(ch)
	return out

func on_pop_removed(pop_uid: int) -> Character:
	if not _by_pop.has(pop_uid):
		return null
	var ch := get_by_uid(int(_by_pop[pop_uid]))
	_by_pop.erase(pop_uid)
	return ch

func remove(uid: int) -> void:
	var ch := get_by_uid(uid)
	if ch == null:
		return
	_by_pop.erase(ch.pop_uid)
	_characters.erase(uid)

func serialize() -> Array:
	var out: Array = []
	for uid in _characters:
		out.append(_characters[uid].serialize())
	return out

func deserialize(data: Array) -> void:
	_characters.clear()
	_by_pop.clear()
	var max_uid := -1
	for d in data:
		var ch := Character.deserialize(d)
		_characters[ch.uid] = ch
		if ch.alive and ch.pop_uid >= 0:
			_by_pop[ch.pop_uid] = ch.uid
		max_uid = maxi(max_uid, ch.uid)
	_uid_seq = max_uid + 1
