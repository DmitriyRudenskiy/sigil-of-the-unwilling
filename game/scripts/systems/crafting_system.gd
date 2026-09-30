class_name CraftingSystem
extends RefCounted
## scarce-crafting-system: крафт артефактов из дефицитных стратегических
## ресурсов. Headless-safe (RefCounted, без дерева сцен).
##
## Требования рецепта: сырьё (HeroStrategicResources), технология
## (tech_tier 1..5, источник — WeaponTechService) и кузница (smithy).
## Результат: Artifact с весом в HeroInventory (backpack).
##
## Контекст крафта передаётся явно (CraftingContext) — система не знает
## про героя/город напрямую, что делает её тестируемой без сцены.

signal item_crafted(recipe_id: StringName, artifact: Artifact)
signal recipe_unlocked(recipe_id: StringName)

const RECIPES_PATH := "res://data/config/crafting_recipes.json"
const VALID_SLOTS: Array[String] = [
	"HEAD", "NECK", "TORSO", "WEAPON", "SHIELD",
	"LEGS", "BOOTS", "RING_L", "RING_R",
	"MISC_A", "MISC_B", "SPELLBOOK",
]
const VALID_RARITIES: Array[String] = ["minor", "major", "relic"]
const RARITY_MAP: Dictionary = {"minor": 0, "major": 1, "relic": 2}
## Fallback без реестра (чистые unit-тесты): базовый набор стратегических.
const _FALLBACK_RESOURCES: Array[StringName] = [
	&"oak", &"silver", &"quartz", &"saltpeter", &"turquoise", &"limonite",
	&"coal", &"gold_ore", &"coal_swamp", &"bog_iron", &"cinnabar", &"wood", &"stone",
]

## Рецепты: id -> CraftingRecipe.
var recipes: Dictionary = {}
## Разблокированные рецепты: id -> true.
var unlocked: Dictionary = {}
## Ресурсный реестр для валидации сырья (инжект; null → валидация по
## локальному списку, см. _validate_resource_ids).
var resource_registry: Node = null


class CraftingRecipe extends RefCounted:
	var id: StringName = &""
	var display_name := ""
	var slot: String = "MISC_A"
	var rarity: String = "minor"
	var weight: float = 0.0
	var tier: int = 1
	var two_handed: bool = false
	var requires_tech: int = 1
	var requires_workshop: bool = false
	var resources: Dictionary = {}  # StringName -> int
	var modifiers: Dictionary = {}
	var combat: Dictionary = {}
	var description := ""


class CraftingContext extends RefCounted:
	var strategic: HeroStrategicResources = null
	var inventory: HeroInventory = null
	var tech_tier: int = 1
	var has_workshop: bool = false


func set_resource_registry(reg: Node) -> void:
	resource_registry = reg


func get_recipe(id: StringName) -> CraftingRecipe:
	return recipes.get(id, null)


func get_recipes() -> Array[CraftingRecipe]:
	var out: Array[CraftingRecipe] = []
	for id in recipes:
		out.append(recipes[id])
	return out


func is_unlocked(id: StringName) -> bool:
	return bool(unlocked.get(id, false))


## Загрузка рецептов из JSON с валидацией.
## Возвращает число загруженных рецептов. Невалидные пропускаются (push_error).
func load_recipes(path: String = RECIPES_PATH) -> int:
	recipes.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CraftingSystem: нет файла рецептов: %s" % path)
		return 0
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not (data.get("recipes", null) is Array):
		push_error("CraftingSystem: некорректная структура %s" % path)
		return 0
	var loaded := 0
	for entry in data["recipes"]:
		if not (entry is Dictionary):
			continue
		var recipe := _validate_recipe(entry)
		if recipe == null:
			continue
		recipes[recipe.id] = recipe
		loaded += 1
	return loaded


## Проверка требований. Возвращает {ok: bool, reason: String, missing: Array}.
func can_craft(id: StringName, ctx: CraftingContext) -> Dictionary:
	var recipe: CraftingRecipe = recipes.get(id, null)
	if recipe == null:
		return {"ok": false, "reason": "unknown_recipe", "missing": []}
	if ctx == null or ctx.strategic == null:
		return {"ok": false, "reason": "no_context", "missing": []}
	if not ctx.has_workshop and recipe.requires_workshop:
		return {"ok": false, "reason": "workshop_required", "missing": []}
	if ctx.tech_tier < recipe.requires_tech:
		return {"ok": false, "reason": "tech_required", "missing": []}
	var missing: Array[StringName] = []
	for res_id in recipe.resources:
		var need: int = int(recipe.resources[res_id])
		var have: int = int(ctx.strategic.get_all().get(StringName(res_id), 0))
		if have < need:
			missing.append(StringName(res_id))
	if not missing.is_empty():
		return {"ok": false, "reason": "missing_resources", "missing": missing}
	return {"ok": true, "reason": "", "missing": []}


## Крафт: списывает сырьё, кладёт Artifact в рюкзак, разблокирует рецепт.
## Возвращает {ok: bool, reason: String, artifact: Artifact, recipe_id}.
func craft(id: StringName, ctx: CraftingContext) -> Dictionary:
	var check := can_craft(id, ctx)
	if not bool(check["ok"]):
		return {"ok": false, "reason": str(check["reason"]), "artifact": null, "recipe_id": id}
	var recipe: CraftingRecipe = recipes[id]
	if ctx.inventory == null:
		return {"ok": false, "reason": "no_context", "artifact": null, "recipe_id": id}

	# Списание сырья (сначала всё — потом предмет; при отказе рюкзака откат).
	var removed: Dictionary = {}
	for res_id in recipe.resources:
		var rid := StringName(res_id)
		var actual: int = ctx.strategic.remove(rid, int(recipe.resources[res_id]))
		removed[rid] = actual

	var artifact := _build_artifact(recipe)
	if not ctx.inventory.add_to_backpack(artifact):
		# Откат: вернём всё списанное.
		for rid in removed:
			ctx.strategic.add(rid, int(removed[rid]))
		return {"ok": false, "reason": "backpack_full", "artifact": null, "recipe_id": id}

	if not is_unlocked(id):
		unlocked[id] = true
		recipe_unlocked.emit(id)
	item_crafted.emit(id, artifact)
	return {"ok": true, "reason": "", "artifact": artifact, "recipe_id": id}


## Сериализация прогресса (unlocked-рецепты).
func serialize() -> Dictionary:
	var ids: Array[String] = []
	for id in unlocked:
		ids.append(str(id))
	return {"unlocked": ids}


func deserialize(data: Dictionary) -> void:
	unlocked.clear()
	var ids: Array = data.get("unlocked", [])
	for id in ids:
		if recipes.has(StringName(id)):
			unlocked[StringName(id)] = true


# ═══════════════════════════════════════════
#  ВНУТРЕННЕЕ
# ═══════════════════════════════════════════

func _validate_recipe(entry: Dictionary) -> CraftingRecipe:
	var id := StringName(str(entry.get("id", "")))
	if id == &"":
		push_error("CraftingSystem: рецепт без id")
		return null
	if recipes.has(id):
		push_error("CraftingSystem: дублирующийся id рецепта: %s" % id)
		return null

	var slot := str(entry.get("slot", "MISC_A"))
	if not VALID_SLOTS.has(slot):
		push_error("CraftingSystem: %s — неизвестный слот: %s" % [id, slot])
		return null
	var rarity := str(entry.get("rarity", "minor"))
	if not VALID_RARITIES.has(rarity):
		push_error("CraftingSystem: %s — неизвестная редкость: %s" % [id, rarity])
		return null
	var weight := float(entry.get("weight", 0.0))
	if weight <= 0.0:
		push_error("CraftingSystem: %s — вес должен быть > 0" % id)
		return null
	var tech := int(entry.get("requires_tech", 1))
	if tech < 1 or tech > 5:
		push_error("CraftingSystem: %s — requires_tech вне 1..5: %d" % [id, tech])
		return null

	var resources: Dictionary = entry.get("resources", {})
	if not (resources is Dictionary) or resources.is_empty():
		push_error("CraftingSystem: %s — пустые ресурсы" % id)
		return null
	for res_id in resources:
		var rid := StringName(res_id)
		if not _is_known_resource(rid):
			push_error("CraftingSystem: %s — неизвестный ресурс: %s" % [id, rid])
			return null
		var amount := int(resources[res_id])
		if amount <= 0:
			push_error("CraftingSystem: %s — некорректное количество %s: %d" % [id, rid, amount])
			return null

	var recipe := CraftingRecipe.new()
	recipe.id = id
	recipe.display_name = str(entry.get("display_name", str(id)))
	recipe.slot = slot
	recipe.rarity = rarity
	recipe.weight = weight
	recipe.tier = clampi(int(entry.get("tier", 1)), 1, 5)
	recipe.two_handed = bool(entry.get("two_handed", false))
	recipe.requires_tech = tech
	recipe.requires_workshop = bool(entry.get("requires_workshop", false))
	for res_id in resources:
		recipe.resources[StringName(res_id)] = int(resources[res_id])
	recipe.modifiers = (entry.get("modifiers", {}) as Dictionary).duplicate()
	recipe.combat = (entry.get("combat", {}) as Dictionary).duplicate()
	recipe.description = str(entry.get("description", ""))
	return recipe


func _is_known_resource(id: StringName) -> bool:
	if resource_registry != null and resource_registry.has_method("get_resource"):
		return resource_registry.get_resource(id) != null
	# Fallback без реестра (чистые unit-тесты): базовый набор стратегических.
	return _FALLBACK_RESOURCES.has(id)


func _build_artifact(recipe: CraftingRecipe) -> Artifact:
	var slot_val: int = Artifact.Slot[recipe.slot]
	var rarity_val: int = int(RARITY_MAP.get(recipe.rarity, 0))
	var art := Artifact.new(
		recipe.id,
		recipe.display_name,
		slot_val,
		rarity_val,
		recipe.modifiers,
		&"",
		recipe.two_handed,
		0,
		recipe.description,
		recipe.weight,
		recipe.combat
	)
	art.tier = recipe.tier
	return art
