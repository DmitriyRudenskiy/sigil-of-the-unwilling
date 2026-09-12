extends PanelContainer
class_name ResourcesPanel




var _labels: Dictionary = {}
var _resource_registry: Node = null

static func _row_names() -> Dictionary:
    return {
        &"oak": "OakRow", &"silver": "SilverRow", &"quartz": "QuartzRow",
        &"saltpeter": "SaltpeterRow", &"turquoise": "TurquoiseRow",
        &"limonite": "LimoniteRow", &"coal": "CoalRow", &"gold_ore": "GoldOreRow",
        &"coal_swamp": "CoalSwampRow", &"bog_iron": "BogIronRow",
        &"cinnabar": "CinnabarRow",
        ResourceType.to_name(ResourceType.ID.WOOD): "WoodRow",
        ResourceType.to_name(ResourceType.ID.STONE): "StoneRow",
    }

func setup_registry(registry: Node) -> void:
    _resource_registry = registry

func _ready() -> void:
    var title := $VBox/Title as Label
    title.add_theme_font_size_override("font_size", 14)
    title.text = GameText.resource_panel_title()
    var container := $VBox/ResourceContainer as VBoxContainer
    var reg: Node = _resource_registry if _resource_registry != null else Resources
    var all: Array[ResourceDef] = reg.get_all()
    var row_names: Dictionary = _row_names()
    for def in all:
        var row_name: String = row_names.get(def.id, "")
        if row_name.is_empty():
            continue
        var row := container.get_node(row_name) as HBoxContainer
        if row == null:
            continue
        var label := row.get_node("Label") as Label
        if label == null:
            continue
        label.text = "%s %d/%d" % [def.icon, 0, GameNumbers.RESOURCE_CAPACITY]
        label.tooltip_text = def.display_name
        label.add_theme_font_size_override("font_size", 12)
        _labels[def.id] = label

func update_resources(resources: Dictionary) -> void:
    var total := 0
    for id in _labels:
        var label: Label = _labels[id]
        var amount: int = int(resources.get(ResourceType.from_name(id), 0))
        total += amount
        var reg: Node = _resource_registry if _resource_registry != null else Resources
        var def: ResourceDef = reg.get_resource(id) as ResourceDef
        if def:
            label.text = "%s %d" % [def.icon, amount]
        else:
            label.text = "⛏️ %d" % amount
    var title := $VBox/Title as Label
    # Ранняя игра: общий лимит рюкзака (early-game-foundation)
    var cap: int = GameNumbersHero.BACKPACK_TOTAL_CAP
    if hero_resources != null:
        cap = hero_resources.total_cap()
    title.text = "%s — %s" % [GameText.resource_panel_title(), GameText.resource_total(total, cap)]

var hero_resources: HeroStrategicResources = null
