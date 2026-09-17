class_name WeaponTechService
extends RefCounted
## social-stats-weapon-tech D4: тир технологий города и ковка.
## const-загрузка (не class_name-резолюция) — как в CityScreen/ReputationSystem.

const CityService = preload("res://scripts/world/CityService.gd")
const LeadershipCheck = preload("res://scripts/systems/LeadershipCheck.gd")
const WeaponCatalog = preload("res://scripts/systems/WeaponCatalog.gd")

static var _rng := RandomNumberGenerator.new()

static func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng

## Тир оружия города: max(fallback по уровню, tech по зданиям/ресурсам).
## tech-лестница (social-systems-delta D1): кузница + железо + уголь -> 3;
## + золото -> 4; + кварц -> 5 (редкое/магия).
## Без кузницы на lvl 5+ можно нанять кузнеца (d20 + cha vs 14) — тогда tech = fallback.
static func _smithy_level(city: City) -> int:
	var lvl := 0
	for b in city.buildings:
		if b != null and b.def != null and b.def.id == &"smithy":
			lvl = maxi(lvl, b.level)
	return lvl

## social-systems-delta D3: требования переходов этапов.
## 2 — камень + дерево (крепления); 3 — кузница + уголь + руда + кузнец;
## 4 — кузница 2 (закалка); 5 — кузница 2 + кварц.
static func stage_requirements_met(city: City, target_tier: int) -> bool:
	match target_tier:
		1:
			return true
		2:
			return float(city.storage.get(&"stone", 0.0)) > 0.0 \
				and float(city.storage.get(&"wood", 0.0)) > 0.0
		3:
			return _smithy_level(city) >= 1 \
				and float(city.storage.get(&"coal", 0.0)) > 0.0 \
				and float(city.storage.get(&"bog_iron", 0.0)) > 0.0 \
				and city.smith_hired
		4:
			return _smithy_level(city) >= 2
		5:
			return _smithy_level(city) >= 2 \
				and float(city.storage.get(&"quartz", 0.0)) > 0.0
	return false

## Наём кузнеца (д20 + cha vs DC 14) — флаг city.smith_hired.
static func try_hire_smith(city: City, hero_cha: int, rng: RandomNumberGenerator) -> bool:
	if city.smith_hired:
		return true
	var check: Dictionary = LeadershipCheck.recruit_check(rng, hero_cha, city.reputation, 0, "smith")
	if str(check.get("outcome", "refused")) == "success":
		city.smith_hired = true
	return city.smith_hired

static func city_weapon_tier(city: City, hero_cha: int = -1) -> int:
	var fallback: int = CityService.weapon_tier_for_city(city.level)
	var smithy_level: int = _smithy_level(city)
	var tech: int = 1
	if smithy_level >= 1:
		if float(city.storage.get(&"bog_iron", 0.0)) > 0.0 \
				and float(city.storage.get(&"coal", 0.0)) > 0.0:
			tech = 3
			if float(city.storage.get(&"gold_ore", 0.0)) > 0.0:
				tech = 4
				if float(city.storage.get(&"quartz", 0.0)) > 0.0:
					tech = 5
	elif city.level >= 5 and hero_cha >= 0:
		# наём свободного кузнеца: успех -> tech = fallback (не выше)
		var check: Dictionary = LeadershipCheck.recruit_check(_rng, hero_cha, city.reputation, 0, "smith")
		if str(check.get("outcome", "refused")) == "success":
			tech = fallback
	return maxi(fallback, tech)

## Ковка изделия. stats — статы героя {int, wis, cha, luk}.
## Возвращает {artifact, quality, discount, notes} или {ok: false, reason}.
static func forge(item_id: String, stats: Dictionary) -> Dictionary:
	var item: Dictionary = WeaponCatalog.ITEMS.get(item_id, {})
	if item.is_empty():
		return {"ok": false, "reason": "Нет изделия: " + item_id}
	var tier: int = int(item["tier"])
	var mat: Dictionary = WeaponCatalog.MATERIALS[tier]

	var int_: int = int(stats.get("int", 2))
	var wis: int = int(stats.get("wis", 2))
	var cha: int = int(stats.get("cha", 2))
	var luk: int = int(stats.get("luk", 2))
	var notes: Array = []

	# int-изучение: д20 + int-10 vs 10 -> базовое качество 0.8…1.2
	var d20: int = _rng.randi_range(1, 20)
	var total: int = d20 + maxi(int_ - 10, 0)
	var quality: float = 0.8 if total < 10 else minf(1.2, 1.0 + (total - 10) * 0.02)
	if total >= 10:
		notes.append("Хорошая ковка (d20=%d)." % d20)
	else:
		notes.append("Кривоватая ковка (d20=%d)." % d20)

	# wis-подделка: шанс заранее заметить подвох кузнеца -> гарантирует качество >= 1.0
	if quality < 1.0 and _rng.randi_range(1, 100) <= maxi((wis - 10), 0) * 5:
		quality = 1.0
		notes.append("Мудрость: подвох кузнеца замечен.")

	# luk-удача: шанс +0.2 к качеству
	if _rng.randi_range(1, 100) <= maxi((luk - 10), 0) * 5:
		quality = minf(1.4, quality + 0.2)
		notes.append("Удача: удачная закалка.")

	# cha-кузнец: скидка на золото
	var discount: float = 0.1 if cha >= 14 else (0.05 if cha >= 12 else 0.0)
	if discount > 0.0:
		notes.append("Харизма: скидка кузнеца %.0f%%." % (discount * 100.0))

	var artifact := Artifact.from_dict({
		"id": StringName(item_id),
		"display_name": String(item["display_name"]),
		"slot": Artifact.Slot.WEAPON,
		"rarity": Artifact.Rarity.MINOR,
		"modifiers": {},
		"special_effect": &"",
		"is_two_handed": bool(item["two_handed"]),
		"value_gold": int(item["gold"]),
		"description": String(item["description"]),
		"weight": float(mat["weight"]) * quality,
		"combat": {"damage": int(mat["damage"]) * int(round(quality * 10.0)) / 10},
		"armor": {},
		"ac_bonus_type": Artifact.AcBonusType.NONE,
	})
	artifact.tier = tier
	return {"ok": true, "artifact": artifact, "quality": quality,
		"discount": discount, "notes": notes}
