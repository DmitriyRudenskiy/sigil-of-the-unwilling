class_name HeroToolsComponent
extends HeroComponent

var tools: HeroTools = HeroTools.new()

signal tools_changed()

func setup_hero(hero: HeroController) -> void:
	super(hero)
	tools.tools_changed.connect(tools_changed.emit)

func set_tools(v: HeroTools) -> void:
	tools = v

func has_tool(tool_id: int) -> bool:
	return tools.has_tool(tool_id)

func get_tool_count(tool_id: int) -> int:
	return tools.get_tool_count(tool_id)

func add_tool(tool_id: int, quantity: int = 1) -> bool:
	return tools.add_tool(tool_id, quantity)

func remove_tool(tool_id: int, quantity: int = 1) -> bool:
	return tools.remove_tool(tool_id, quantity)

func get_all() -> Array[Dictionary]:
	return tools.get_all()

func serialize() -> Dictionary:
	return {"tools": tools.serialize()}

func deserialize(data: Dictionary) -> void:
	tools.deserialize(data.get("tools", []))
