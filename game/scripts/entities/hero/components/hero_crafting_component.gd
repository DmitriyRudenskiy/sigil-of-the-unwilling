class_name HeroCraftingComponent
extends HeroComponent
## scarce-crafting-system: компонент героя — доступ к CraftingSystem.
## Хранит CraftingSystem (RefCounted), wire к strategic-ресурсам и
## инвентарю. Контекст крафта (технология/кузница) вычисляется из города.

const WeaponTechService = preload("res://scripts/systems/weapon_tech_service.gd")

var crafting: CraftingSystem = CraftingSystem.new()

signal item_crafted(recipe_id: StringName, artifact: Artifact)
signal recipe_unlocked(recipe_id: StringName)

func setup_hero(hero: HeroController) -> void:
	super(hero)
	crafting.item_crafted.connect(item_crafted.emit)
	crafting.recipe_unlocked.connect(recipe_unlocked.emit)

func initialize() -> void:
	var reg: Node = Services.resolve(&"resources")
	if reg != null:
		crafting.set_resource_registry(reg)
	crafting.load_recipes()


## Контекст крафта из героя и (опционально) города.
func _build_context(city: City = null) -> CraftingSystem.CraftingContext:
	var ctx := CraftingSystem.CraftingContext.new()
	var strategic_comp: HeroStrategicResourcesComponent = _hero.get_component("StrategicResources")
	var inv_comp: HeroInventoryComponent = _hero.get_component("Inventory")
	if strategic_comp != null:
		ctx.strategic = strategic_comp.strategic
	if inv_comp != null:
		ctx.inventory = inv_comp.inventory
	ctx.tech_tier = 1
	ctx.has_workshop = false
	if city != null:
		ctx.tech_tier = WeaponTechService.city_weapon_tier(city)
		for b in city.buildings:
			if b != null and b.def != null and b.def.id == &"smithy" and b.level >= 1:
				ctx.has_workshop = true
				break
	return ctx


func can_craft(id: StringName, city: City = null) -> Dictionary:
	return crafting.can_craft(id, _build_context(city))


func craft(id: StringName, city: City = null) -> Dictionary:
	return crafting.craft(id, _build_context(city))


func get_recipes() -> Array:
	return crafting.get_recipes()


func is_unlocked(id: StringName) -> bool:
	return crafting.is_unlocked(id)


func serialize() -> Dictionary:
	return {"crafting": crafting.serialize()}


func deserialize(data: Dictionary) -> void:
	var c: Dictionary = data.get("crafting", {})
	if not c.is_empty():
		crafting.deserialize(c)
