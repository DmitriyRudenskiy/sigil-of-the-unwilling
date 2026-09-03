extends RefCounted
class_name SuccessionController
## succession-sigil: смерть героя → выбор преемника → наследование легенды.
##
## Чистый RefCounted-оркестратор, не зависит от ServiceLocator/реестров —
## работает headless (тесты). Перенос инвентаря делает глубокий копией
## Artifact (duplicate(true)), перенос городов — перерегистрацией на
## CityManager (та же шина мира или тестовый менеджер).

## succession-sigil: стоимость воскресения в великом храме.
const RESURRECTION_INDUSTRY := 500.0
const RESURRECTION_SPECIAL := &"gold"
const RESURRECTION_SPECIAL_AMOUNT := 100.0


# ==================== ВЫБОР ПРЕЕМНИКА ====================

## Выбрать преемника из последователей умершего героя: подходит только
## последователь того же пути (follower.path == deceased.path_id). Возвращает
## старшего свободного последователя пути (по uid); seeded roll ломает ничью.
## Возвращает null, если нет достойных (run заканчивается).
func select_successor(deceased: HeroController, rng: RandomNumberGenerator = null) -> Follower:
	if deceased == null:
		return null
	var candidates: Array = []
	for f in deceased.followers:
		if f != null and f.path == deceased.path_id:
			candidates.append(f)
	if candidates.is_empty():
		return null
	# Старший последователь пути (меньший uid) — основной выбор.
	candidates.sort_custom(func(a, b): return int(a.uid) < int(b.uid))
	var idx := 0
	if rng != null:
		idx = rng.randi() % candidates.size()
	return candidates[idx]


# ==================== ПОСТРОЕНИЕ ПРЕЕМНИКА ====================

## Построить нового героя, наследующего легенду: path, HeroMagic
## (spellbook/schools/mana), HeroInventory, стратегические ресурсы.
func build_successor(deceased: HeroController, rng: RandomNumberGenerator = null) -> HeroController:
	var succ := HeroController.new()
	succ.path_id = deceased.path_id
	# HeroMagic: spellbook / школы / мана.
	if deceased.magic != null:
		succ.magic.spellbook = deceased.magic.spellbook.duplicate()
		succ.magic.schools = deceased.magic.schools.duplicate()
		succ.magic.mana_current = deceased.magic.mana_current
		succ.magic.mana_max = deceased.magic.mana_max
	# Инвентарь: глубокая копия артефактов (без реестра, headless-safe).
	_transfer_inventory(deceased, succ)
	# Стратегические ресурсы.
	if deceased.strategic_resources != null and deceased.strategic_resources.has_method("get_all"):
		succ.strategic_resources.set_all(deceased.strategic_resources.get_all())
	return succ


func _transfer_inventory(deceased: HeroController, succ: HeroController) -> void:
	var src = deceased.inventory
	if src == null:
		return
	for slot in src.equipped:
		var art: Artifact = src.equipped[slot]
		if art != null:
			succ.inventory.equipped[slot] = art.duplicate(true)
	succ.inventory.backpack.clear()
	for art in src.backpack:
		succ.inventory.backpack.append(art.duplicate(true))


# ==================== ПЕРЕНОС ГОРОДОВ (наследование) ====================

## Перенести города умершего на CityManager преемника. Если dest_manager уже
## содержит эти города (тот же мир) — перерегистрация пропускается (ссылки
## сохраняются, capital/glory/current_turn наследуются автоматически). Иначе —
## перерегистрация свежими копиями. Столица восстанавливается по is_capital.
func transfer_legend(deceased: HeroController, successor: HeroController,
                    source_cities: Array[City], dest_manager: CityManager) -> void:
	if dest_manager == null or source_cities == null:
		return
	var already_has := true
	for c in source_cities:
		if c != null and not dest_manager.cities.has(c):
			already_has = false
			break
	if not already_has:
		dest_manager.cities.clear()
		for c in source_cities:
			if c == null:
				continue
			var copy: City = City.new()
			copy.deserialize(c.serialize())
			dest_manager.register_city(copy)
	# Столица: та, что помечена is_capital.
	var cap: City = null
	for c in dest_manager.cities:
		if c != null and c.is_capital:
			cap = c
			break
	if cap != null:
		dest_manager.set_capital(cap)


# ==================== ВОСКРЕШЕНИЕ ====================

## hero-survival: стоимость воскрешения по умолчанию (формат can_resurrect).
func default_resurrection_cost() -> Dictionary:
	return {"industry": RESURRECTION_INDUSTRY, RESURRECTION_SPECIAL: RESURRECTION_SPECIAL_AMOUNT}


## воскресить героя в великом храме города. Стоит industry + спец. ресурс.
## true, если храм уровня ≥ 1 и storage хватает (и ресурсы списаны).
func resurrect_hero(city: City, cost: Dictionary = {}) -> bool:
	if city == null:
		return false
	var c := cost.duplicate()
	if not c.has(&"industry"):
		c["industry"] = RESURRECTION_INDUSTRY
	if not c.has(RESURRECTION_SPECIAL):
		c[RESURRECTION_SPECIAL] = RESURRECTION_SPECIAL_AMOUNT
	if not city.can_resurrect(c):
		return false
	# Списание ресурсов.
	for key in c:
		if city.storage.has(key):
			city.storage[key] = maxf(0.0, float(city.storage[key]) - float(c[key]))
	return true


# ==================== ОРКЕСТРАЦИЯ: СМЕРТЬ → ПРЕЕМНИК ====================

## Обработать смерть героя: выбрать преемника, перенести легенду.
## Возвращает нового HeroController, либо null, если преемника нет (run ends).
func on_hero_died(deceased: HeroController, rng: RandomNumberGenerator = null,
                  source_cities: Array[City] = [], dest_manager: CityManager = null) -> HeroController:
	if deceased == null:
		return null
	var successor_follower := select_successor(deceased, rng)
	if successor_follower == null:
		# Нет достойных последователей того же пути — легенда прервана.
		return null
	var successor := build_successor(deceased, rng)
	transfer_legend(deceased, successor, source_cities, dest_manager)
	return successor
