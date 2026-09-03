extends RefCounted
## HeroLifecycleSystem: succession-sigil + legend-chronicle + hero-survival.
## death -> successor -> replace active hero. Headless-safe, RefCounted.
##
## Co-located subsystem of WorldController (its coordinator-owned domain logic,
## extracted from the facade). The active-hero pointer stays on the coordinator
## (`world.get_hero()` / `world.set_hero()`); this class owns only the
## death-flow working state (death/chronicle screens, pending successor, held
## corpse, resurrection candidate) and the algorithms that move it.
##
## No `class_name`: in detached tests `class_name` is not registered in
## classdb → compilation fails. Typed via local preload const.

const DeathSequenceScript = preload("res://scripts/ui/DeathSequence.gd")
const ChronicleScreenScript = preload("res://scripts/ui/ChronicleScreen.gd")

## Node2D parent for add_child (the WorldController).
var world: Node2D = null

var _persistence = null            # WorldPersistence
var _rng: RandomNumberGenerator = null
var _cities = null                 # CityManager
var _map_gen = null                # MapGenerator
var _event_router = null           # WorldEventRouter
var _ui_manager = null             # WorldUIManager
var battle_coordinator = null      # battle coordinator (same objects as WC)
var interaction_controller = null  # interaction controller (same objects as WC)
var _bootstrap_result = null       # WorldBootstrap.BootstrapResult
var _succession = null             # SuccessionController
var _camera: Node = null

var _death_seq = null              # DeathSequence
var _chronicle_screen = null       # ChronicleScreen
var _pending_successor: HeroController = null
var _deceased_snapshot: Dictionary = {}
var _deceased_hero: HeroController = null
var _resurrection_city: City = null


## Wire the subsystem to the WorldController's references. Called once after
## bootstrap, before the hero can die.
func setup(
	p: Node2D,
	persistence,
	rng,
	cities,
	map_gen,
	event_router,
	ui_manager,
	battle_coord,
	interaction,
	bootstrap_result,
	succession,
	camera
) -> void:
	world = p
	_persistence = persistence
	_rng = rng
	_cities = cities
	_map_gen = map_gen
	_event_router = event_router
	_ui_manager = ui_manager
	battle_coordinator = battle_coord
	interaction_controller = interaction
	_bootstrap_result = bootstrap_result
	_succession = succession
	_camera = camera
	if not GameEventBus.hero_died.is_connected(on_hero_died):
		GameEventBus.hero_died.connect(on_hero_died)


# ==================== SUCCESSION-SIGIL: death -> successor ====================

## GameEventBus.hero_died(cause: StringName): выбрать преемника, перенести
## легенду, заменить активного героя. Возврат преемника = легенда
## продолжается; преемника нет → run заканчивается (EndgameController уже
## поставил DEFEAT — он подключён первым; тут только убираем труп).
func on_hero_died(cause: StringName) -> void:
	var deceased := _hero_ptr()
	if deceased == null:
		return
	# legend-chronicle: снимаем имя/пути ДО освобождения героя — запись
	# летописи строится по этому снапшоту (живой реф не держим).
	_deceased_snapshot = {
		"hero_name": str(deceased.hero_name),
		"path": String(deceased.path_id),
	}
	# endgame: sticky-терминальное состояние уже зафиксировано Endgame
	# (смерть без преемника) — преемника не выбираем, только убираем героя
	# и показываем момент смерти («цикл оборвался» + «В меню»).
	var session = _persistence.session if _persistence != null else null
	if session != null and session.is_terminal():
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, null)
		return
	var successor := _plan_succession(deceased)
	if successor == null:
		GameLogger.world("Succession: no eligible follower — run ends")
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, null)
		return
	# legend-chronicle: перерождение отложено — «Знак переходит» в
	# последовательности вызывает succession-поток (_execute_succession).
	_pending_successor = successor
	# hero-survival: кандидат на воскрешение — город с великим храмом, где
	# герой ещё не воскрешал в этом цикле. Если есть — труп держим в памяти:
	# игрок выбирает между «Воскресить» и «Знак переходит».
	var res_city: City = _find_resurrection_city(deceased)
	_resurrection_city = res_city
	if res_city != null:
		_deceased_hero = deceased
		_detach_hero(deceased)
	else:
		_remove_hero(deceased)
	# _reincarnate с _hero_ptr() == null работает (old == null → просто добавляет).
	# Труп уже освобождён (res_city == null) — имя берём из снапшота, а не из
	# freed-объекта (use-after-free). Снапшот взят в начале on_hero_died.
	_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, successor, res_city)


func is_death_sequence_open() -> bool:
	return _death_seq != null and _death_seq.visible


func _show_death_sequence(
	deceased_name: String,
	cause: StringName,
	successor: Node,
	res_city: City = null
) -> void:
	if _death_seq == null:
		_death_seq = DeathSequenceScript.new()
		_death_seq.name = "DeathSequence"
		world.add_child(_death_seq)
		_death_seq.successor_chosen.connect(_execute_succession)
		_death_seq.return_to_menu.connect(_on_death_return_to_menu)
		_death_seq.chronicle_requested.connect(_on_death_chronicle_requested)
		_death_seq.resurrection_chosen.connect(_on_resurrection_chosen)
	_death_seq.show_death(deceased_name, cause, _run_summary(), successor, res_city)


## Кнопка «Знак переходит»: перерождение + hero_successor + запись в летопись.
func _execute_succession() -> void:
	var successor := _pending_successor
	_pending_successor = null
	if successor == null:
		return
	if is_death_sequence_open():
		_death_seq.visible = false
	# hero-survival: игрок выбрал преемника — удерживаемый труп освобождается.
	_free_deceased()
	_reincarnate(successor)
	GameEventBus.hero_successor.emit(successor)
	_append_succession_entry()


## hero-survival: первый город игрока, где доступно воскрешение (великим храмом
## + хранилище под стоимость по умолчанию). null — варианта нет.
func _find_resurrection_city(deceased: HeroController) -> City:
	if _succession == null or _cities == null:
		return null
	if deceased != null and deceased.resurrected_once:
		return null
	var cost: Dictionary = _succession.default_resurrection_cost()
	for c in _cities.cities:
		if c != null and c.owner == &"player" and c.can_resurrect(cost):
			return c
	return null


## hero-survival: «Воскресить» — герой возвращается в город с великим храмом.
## Цикл не оборвался: записи в летопись нет, hero_successor не эмитится.
func _on_resurrection_chosen() -> void:
	var city := _resurrection_city
	var hero := _deceased_hero
	_resurrection_city = null
	_deceased_hero = null
	if hero == null or city == null or _succession == null:
		return
	# Воскрешение заменяет преемника: pending-преемник освобождается.
	if _pending_successor != null and is_instance_valid(_pending_successor):
		_pending_successor.free()
	_pending_successor = null
	# Экран блокирует ходы — хранилище с момента проверки не меняется.
	_succession.resurrect_hero(city)
	hero.revive_at(city)
	hero.resurrected_once = true
	_install_hero(hero)
	if is_death_sequence_open():
		_death_seq.visible = false
	GameLogger.world("Succession: %s resurrected in %s" % [hero.hero_name, city.display_name])


## hero-survival: убрать героя из мира без free (выбор игрока ещё впереди).
func _detach_hero(deceased: Node) -> void:
	if deceased != null and is_instance_valid(deceased) and deceased.get_parent() != null:
		deceased.get_parent().remove_child(deceased)
	if _hero_ptr() == deceased:
		_set_hero_ptr(null)


## hero-survival: освободить удерживаемый труп (преемник / «В меню»).
func _free_deceased() -> void:
	if _deceased_hero != null and is_instance_valid(_deceased_hero):
		_deceased_hero.free()
	_deceased_hero = null
	_resurrection_city = null


## legend-chronicle: запись завершённого цикла (умерший герой).
func _append_succession_entry() -> void:
	if _persistence == null or _persistence.chronicle == null:
		return
	var sum := _run_summary()
	_persistence.chronicle.append({
		"hero_name": _deceased_snapshot.get("hero_name", "?"),
		"path": _deceased_snapshot.get("path", ""),
		"end_turn": sum["turns"],
		"cities": sum["cities_owned"],
		"glory": sum["glory"],
		"battles_won": sum["battles_won"],
		"battles_lost": sum["battles_lost"],
		"outcome": "succession",
	})
	_deceased_snapshot = {}


## legend-chronicle: «Летопись» из последовательности смерти.
func _on_death_chronicle_requested() -> void:
	var entries: Array = []
	if _persistence != null and _persistence.chronicle != null:
		entries = _persistence.chronicle.to_array()
	if _chronicle_screen == null:
		_chronicle_screen = ChronicleScreenScript.new()
		_chronicle_screen.name = "ChronicleScreen"
		world.add_child(_chronicle_screen)
	_chronicle_screen.show_entries(entries)


func _on_death_return_to_menu() -> void:
	# hero-survival: труп без родителя — освободить явно, иначе утечка.
	_free_deceased()
	world.get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## Сводка забега для DeathSequence (тот же формат, что у endgame).
func _run_summary() -> Dictionary:
	var turns := 0
	var glory := 0
	var cities_left := 0
	if _cities != null:
		turns = int(_cities.current_turn)
		if _cities.glory != null:
			glory = int(round(_cities.glory.total))
		for c in _cities.cities:
			if c != null and c.owner == &"player":
				cities_left += 1
	var s: GameSession = _persistence.session if _persistence != null else null
	var date: Dictionary = _persistence.get_date() if _persistence != null else {}
	return {
		"turns": turns,
		"date": {
			"month": int(date.get("month", 1)),
			"week": int(date.get("week", 1)),
			"day": int(date.get("day", 1)),
		},
		"cities_owned": cities_left,
		"glory": glory,
		"battles_won": int(s.battles_won) if s != null else 0,
		"battles_lost": int(s.battles_lost) if s != null else 0,
		"generations": (int(s.successions) if s != null else 0) + 1,
	}

## Выбрать преемника через SuccessionController. Возвращает HeroController либо
## null (преемника нет). Отдельно от _reincarnate — чтобы проверять выбор
## без полного перепричинения (тесты, headless).
func _plan_succession(deceased: HeroController) -> HeroController:
	if _succession == null or _cities == null or deceased == null:
		return null
	return _succession.on_hero_died(
		deceased, _rng, _cities.cities, _cities)

## Убрать героя из дерева (смерть без преемника / замена на преемника).
func _remove_hero(deceased: Node) -> void:
	# active-реф берём ДО free(): get_hero() вернёт freed-объект и упадёт
	# ("return a previously freed instance"), если снять реф после free).
	var active := _hero_ptr()
	if deceased != null and is_instance_valid(deceased) and deceased.get_parent() != null:
		deceased.get_parent().remove_child(deceased)
		deceased.free()
	if active == deceased:
		_set_hero_ptr(null)

## Заменить активного героя на преемника: новый в дереве, инициализирован,
## ВСЕ потребители героя переподключены на него (battle/interaction/враги/
## ввод/router/UI — иначе freed-референсы = краш на следующем кадре).
func _reincarnate(successor: HeroController) -> void:
	var old := _hero_ptr()
	_remove_hero(old)
	_install_hero(successor)
	GameLogger.world("Succession: successor took the legend")

## hero-survival: поставить героя в мир (общая часть перерождения и
## воскрешения): в дерево, setup, перенаправить рефы во всех системах.
func _install_hero(hero: HeroController) -> void:
	_set_hero_ptr(hero)
	world.add_child(hero)
	hero.city_manager = _cities
	# Гвард — для headless-тестов (карты нет); в игре _map_gen всегда есть.
	if _map_gen != null:
		hero.setup(_map_gen)
	if _map_gen != null and _map_gen.has_valid_tilemap():
		hero.position = _map_gen.map_to_local(hero.current_cell)
	if is_instance_valid(battle_coordinator):
		battle_coordinator.hero = hero
	if is_instance_valid(interaction_controller):
		interaction_controller.hero = hero
	if _bootstrap_result != null:
		# enemy-world-ai: без этого вражеский ИИ смотрит на freed-героя.
		if _bootstrap_result.enemy_proc != null:
			_bootstrap_result.enemy_proc._hero = hero
		# endgame: ввод кликов по карте тоже держит реф на героя.
		if _bootstrap_result.input_controller != null:
			_bootstrap_result.input_controller.hero = hero
		if _bootstrap_result.shortcuts != null:
			_bootstrap_result.shortcuts._hero = hero
	if _event_router != null:
		_event_router.hero = hero
		_event_router._connect_hero_signals()
	if _ui_manager != null:
		_ui_manager._hero = hero
		_ui_manager.ui.reattach_hero(hero, _camera)
		if is_instance_valid(_ui_manager.inventory_screen):
			_ui_manager.inventory_screen.set_hero(hero)
		if is_instance_valid(_ui_manager.city_screen):
			_ui_manager.city_screen.hero = hero


# ==================== active-hero pointer (owned by WorldController) ====================

## Active hero pointer lives on the coordinator; read through it.
func _hero_ptr() -> HeroController:
	if world != null and world.has_method("get_hero"):
		return world.get_hero()
	return null

## Publish the new active hero back to the coordinator (reincarnation /
## resurrection / detach). Guarded so a system wired without a full
## coordinator (detached unit test) doesn't NPE.
func _set_hero_ptr(hero: HeroController) -> void:
	if world != null and world.has_method("set_hero"):
		world.set_hero(hero)
