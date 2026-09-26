extends Node
class_name HeroModelFactory

const _Artifact = preload("res://scripts/data/artifact.gd")
const _Registry = preload("res://scripts/autoload/artifact_registry.gd")

static func build_hero(name: String, variant: String) -> HeroController:
	var reg := _Registry.new()
	reg.ensure_definitions()

	var hero := HeroController.new()
	hero.hero_name = name
	hero.stats = {"attack": 6, "defense": 5, "spell_power": 8, "knowledge": 7}

	if variant == "mage":
		_equip(hero, reg, "mage")
	else:
		_equip(hero, reg, "warrior")
	return hero

static func _equip(hero: HeroController, reg: Object, variant: String) -> void:
	var eq: Dictionary = hero.inventory.equipped
	var bp: Array = hero.inventory.backpack

	if variant == "mage":
		eq[_Artifact.Slot.WEAPON] = reg.get_by_id(&"staff_void")
		eq[_Artifact.Slot.HEAD] = reg.get_by_id(&"crown_magi")
		eq[_Artifact.Slot.TORSO] = reg.get_by_id(&"robes_astronomer")
		eq[_Artifact.Slot.LEGS] = reg.get_by_id(&"skirt_conjunction")
		eq[_Artifact.Slot.BOOTS] = reg.get_by_id(&"soles_mercury")
		eq[_Artifact.Slot.NECK] = reg.get_by_id(&"amulet_prescience")
		eq[_Artifact.Slot.RING_L] = reg.get_by_id(&"ring_lexicon")
		bp.append(reg.get_by_id(&"tome_infinity"))
		bp.append(reg.get_by_id(&"helm_heavenly"))
		bp.append(reg.get_by_id(&"boots_levitation"))
	else:
		eq[_Artifact.Slot.WEAPON] = reg.get_by_id(&"greatsword_might")
		eq[_Artifact.Slot.HEAD] = reg.get_by_id(&"helm_bulwark")
		eq[_Artifact.Slot.TORSO] = reg.get_by_id(&"plate_dread")
		eq[_Artifact.Slot.LEGS] = reg.get_by_id(&"greaves_juggernaut")
		eq[_Artifact.Slot.BOOTS] = reg.get_by_id(&"boots_titan")
		eq[_Artifact.Slot.NECK] = reg.get_by_id(&"amulet_prescience")
		eq[_Artifact.Slot.RING_L] = reg.get_by_id(&"ring_giant")
		eq[_Artifact.Slot.RING_R] = reg.get_by_id(&"ring_lexicon")
		bp.append(reg.get_by_id(&"shield_greatwall"))
		bp.append(reg.get_by_id(&"charm_beast"))
		bp.append(reg.get_by_id(&"trinket_epoch"))
