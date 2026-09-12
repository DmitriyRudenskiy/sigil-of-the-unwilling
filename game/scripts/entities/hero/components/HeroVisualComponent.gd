class_name HeroVisualComponent
extends HeroComponent

var _controller: HeroVisualController = null

func setup_hero(hero: HeroController) -> void:
	super(hero)
	_controller = HeroVisualController.new()
	_controller.name = "Visual"
	add_child(_controller)

func setup_visual(map: MapGenerator) -> void:
	_controller.setup(map, _hero)
	_controller.build_visual()
	_controller.setup_path_visual()

func get_avatar_texture() -> Texture2D:
	if _controller == null:
		return null
	return _controller.get_avatar_texture()

func set_facing(delta: Vector2i) -> void:
	if _controller != null:
		_controller.set_facing(delta)

func idle_animation() -> void:
	if _controller != null:
		_controller.idle_animation()

func draw_path(pts: Array[Vector2i]) -> void:
	if _controller != null:
		_controller.draw_path(pts)

func clear_path_visual() -> void:
	if _controller != null:
		_controller.clear_path_visual()

func show_marker(pos: Vector2) -> void:
	if _controller != null:
		_controller.show_marker(pos)

func update_status_orb(mp_ratio: float) -> void:
	if _controller != null:
		_controller.update_status_orb(mp_ratio)
