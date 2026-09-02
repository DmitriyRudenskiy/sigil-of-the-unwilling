extends "res://tests/test_base.gd"
## legend-chronicle: Chronicle (append/roundtrip/сигнал), save v6 (миграция
## v5), HeroStatusPanel (graceful), DeathSequence (оба режима),
## ChronicleScreen (newest-first), отложенная succession в WorldController
## (снапшот → «Знак переходит» → hero_successor + запись в летопись).

const _WorldController = preload("res://scripts/world/WorldController.gd")
const _Succession = preload("res://scripts/world/SuccessionController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _Chronicle = preload("res://scripts/core/Chronicle.gd")
const _SaveData = preload("res://scripts/core/SaveData.gd")
const _WorldPersistence = preload("res://scripts/world/WorldPersistence.gd")
const _GameSession = preload("res://scripts/core/GameSession.gd")
const _DeathSequence = preload("res://scripts/ui/DeathSequence.gd")
const _ChronicleScreen = preload("res://scripts/ui/ChronicleScreen.gd")
const _HeroStatusPanel = preload("res://scripts/ui/HeroStatusPanel.gd")


# ==================== Chronicle ====================

func test_chronicle_append_numbers_generations_and_emits() -> void:
	var c: _Chronicle = _Chronicle.new()
	var got: Array = []
	# ponytail: lambda-переприсваивание локалов не прокидывается (GDScript),
	# мутация (append) — да.
	var conn := func(id, text): got.append([id, text])
	GameEventBus.chronicle_entry_added.connect(conn)
	c.append({"hero_name": "Darkstorn", "path": "archivist", "outcome": "succession", "glory": 10})
	c.append({"hero_name": "Nyx", "path": "warrior", "outcome": "DEFEAT", "glory": 50})
	GameEventBus.chronicle_entry_added.disconnect(conn)
	assert_eq(c.entries.size(), 2, "две записи")
	assert_eq(c.entries[0]["generation"], 1, "поколение 1")
	assert_eq(c.entries[1]["generation"], 2, "поколение 2")
	assert_eq(got.size(), 2, "сигнал с id и текстом")
	assert_true(str(got[1]).find("Nyx") != -1, "текст события про свежую запись")

func test_chronicle_roundtrip_and_garbage() -> void:
	var c: _Chronicle = _Chronicle.new()
	c.append({"hero_name": "A", "path": "x", "outcome": "succession"})
	var c2: _Chronicle = _Chronicle.new()
	c2.from_array(c.to_array())
	assert_eq(c2.entries.size(), 1, "roundtrip: одна запись")
	assert_eq(str(c2.entries[0]["hero_name"]), "A", "roundtrip: имя")
	# мутация копии не бьёт по оригиналу (duplicate(true) при append)
	c2.entries[0]["hero_name"] = "MUTATED"
	assert_eq(str(c.entries[0]["hero_name"]), "A", "копия не связана с оригиналом")
	c2.from_array([42, "junk", {"hero_name": "B"}])
	assert_eq(c2.entries.size(), 1, "from_array оставляет только Dictionary")
	assert_eq(str(c2.entries[0]["hero_name"]), "B", "from_array: новая запись")


# ==================== SaveData v6 ====================

func test_savedata_v5_migrates_to_v6_with_empty_chronicle() -> void:
	var v5 := {
		"version": 5,
		"generator_version": 1,
		"run_seed": 7,
		"date": {"month": 2, "week": 3, "day": 4},
		"hero": {"cell": [1, 2]},
		"world": {},
		"cities": [],
		"characters": [],
		"successor": {},
		"legend": {},
		"session": {},
	}
	var sd: _SaveData = _SaveData.new()
	sd.from_dict(v5)
	assert_eq(int(sd.version), 6, "v5 → v6")
	assert_true(sd.chronicle.is_empty(), "u v5-сейва летопись пуста")
	var sd2: _SaveData = _SaveData.new()
	sd2.from_dict(sd.to_dict())
	assert_eq(int(sd2.version), 6, "v6 roundtrip: версия")
	assert_true(sd2.chronicle.is_empty(), "v6 roundtrip: пусто")

func test_savedata_v6_chronicle_roundtrip() -> void:
	var sd: _SaveData = _SaveData.new()
	sd.version = 6
	sd.chronicle.append({"hero_name": "A", "path": "x", "outcome": "succession", "generation": 1})
	var sd2: _SaveData = _SaveData.new()
	sd2.from_dict(sd.to_dict())
	assert_eq(sd2.chronicle.size(), 1, "v6: запись пережила roundtrip")
	assert_eq(str(sd2.chronicle[0]["hero_name"]), "A", "v6: имя записи")


# ==================== HeroStatusPanel ====================

func _make_follower(uid: int, name: String, path: StringName) -> _Follower:
	var f: _Follower = _Follower.new()
	f.uid = uid
	f.name = name
	f.path = path
	return f

func test_hero_status_panel_with_hero() -> void:
	var h: _Hero = _Hero.new()
	h.hero_name = "Darkstorn"
	h.path_id = &"archivist"
	h.combat_hp = 5
	h.max_combat_hp = 10
	h.followers = [_make_follower(1, "Nyx", &"archivist")]
	var panel: _HeroStatusPanel = _HeroStatusPanel.new()
	root.add_child(panel)
	panel.set_hero(h)
	var title: String = str(panel.get_node("VBox/Title").text)
	assert_true(title.find("Darkstorn") != -1, "имя в заголовке: %s" % title)
	assert_true(title.find("archivist") != -1, "путь в заголовке: %s" % title)
	var followers: String = str(panel.get_node("VBox/FollowersLabel").text)
	assert_true(followers.find("Nyx") != -1, "последователь в списке: %s" % followers)
	h.free()
	panel.free()

func test_hero_status_panel_without_hero() -> void:
	var panel: _HeroStatusPanel = _HeroStatusPanel.new()
	root.add_child(panel)
	var title: String = str(panel.get_node("VBox/Title").text)
	assert_true(title.find("Герой") != -1, "пустая панель: %s" % title)
	var cond: String = str(panel.get_node("VBox/ConditionLabel").text)
	assert_eq(cond, "", "без героя кондиции нет")
	panel.free()


# ==================== DeathSequence ====================

func test_death_sequence_with_successor() -> void:
	var ds: _DeathSequence = _DeathSequence.new()
	root.add_child(ds)
	var succ: _Hero = _Hero.new()
	succ.hero_name = "Nyx"
	succ.path_id = &"warrior"
	ds.show_death("Darkstorn", &"battle", {"turns": 10, "date": {"month": 1, "week": 2, "day": 3}}, succ)
	var title: String = str(ds.get_node("Root/Panel/VBox/Title").text)
	assert_true(title.find("цикл продолжится") != -1, "заголовок: %s" % title)
	assert_true(ds.get_node("Root/Panel/VBox/Buttons/SuccessorButton").visible, "кнопка преемника видна")
	assert_false(ds.get_node("Root/Panel/VBox/Buttons/MenuButton").visible, "«В меню» спрятана")
	var reason: String = str(ds.get_node("Root/Panel/VBox/Reason").text)
	assert_true(reason.find("в бою") != -1, "причина: %s" % reason)
	succ.free()
	ds.free()

func test_death_sequence_terminal() -> void:
	var ds: _DeathSequence = _DeathSequence.new()
	root.add_child(ds)
	ds.show_death("Darkstorn", &"battle", {}, null)
	var title: String = str(ds.get_node("Root/Panel/VBox/Title").text)
	assert_true(title.find("цикл оборвался") != -1, "заголовок: %s" % title)
	assert_true(ds.get_node("Root/Panel/VBox/Buttons/MenuButton").visible, "«В меню» видна")
	assert_false(ds.get_node("Root/Panel/VBox/Buttons/SuccessorButton").visible, "кнопка преемника спрятана")
	ds.free()

func test_death_sequence_successor_signal() -> void:
	var ds: _DeathSequence = _DeathSequence.new()
	root.add_child(ds)
	var fired: Array = []
	ds.successor_chosen.connect(func(): fired.append(1))
	var succ: _Hero = _Hero.new()
	ds.show_death("A", &"battle", {}, succ)
	ds.get_node("Root/Panel/VBox/Buttons/SuccessorButton").pressed.emit()
	assert_eq(fired.size(), 1, "successor_chosen по клику")
	succ.free()
	ds.free()


# ==================== ChronicleScreen ====================

func test_chronicle_screen_newest_first() -> void:
	var cs: _ChronicleScreen = _ChronicleScreen.new()
	root.add_child(cs)
	var entries: Array = [
		{"hero_name": "First", "path": "a", "outcome": "succession", "generation": 1, "end_turn": 5, "glory": 1, "battles_won": 0, "battles_lost": 0},
		{"hero_name": "Last", "path": "b", "outcome": "DEFEAT", "generation": 2, "end_turn": 9, "glory": 9, "battles_won": 1, "battles_lost": 1},
	]
	cs.show_entries(entries)
	var list: VBoxContainer = cs.get_node("Root/Panel/VBox/Scroll/List")
	var first: String = str(list.get_child(0).text)
	assert_true(first.find("Last") != -1, "свежая запись первой: %s" % first)
	assert_true(first.find("2.") != -1, "номер поколения: %s" % first)
	cs.free()

func test_chronicle_screen_empty() -> void:
	var cs: _ChronicleScreen = _ChronicleScreen.new()
	root.add_child(cs)
	cs.show_entries([])
	var list: VBoxContainer = cs.get_node("Root/Panel/VBox/Scroll/List")
	var txt: String = str(list.get_child(0).text)
	assert_true(txt.find("Летопись пуста") != -1, "пустая летопись: %s" % txt)
	cs.free()


# ==================== WorldController: deferred succession ====================

## WorldController вне дерева (без _ready/bootstrap) — только инжект
## зависимостей, как в test_worldcontroller_succession_wiring.
func _make_wc() -> _WorldController:
	var wc: _WorldController = _WorldController.new()
	wc._rng = RandomNumberGenerator.new()
	var mgr: _CityManager = _CityManager.new()
	var c: _City = _City.new()
	c.uid = 1
	c.display_name = &"Highhold"
	c.owner = &"player"
	mgr.register_city(c)
	wc._cities = mgr
	wc._succession = _Succession.new()
	var persistence: _WorldPersistence = _WorldPersistence.new(null)
	persistence.session = _GameSession.new(42)
	wc._persistence = persistence
	return wc

func test_on_hero_died_defers_succession() -> void:
	var wc := _make_wc()
	var h: _Hero = _Hero.new()
	h.hero_name = "Darkstorn"
	h.path_id = &"archivist"
	h.followers = [_make_follower(1, "Nyx", &"archivist")]
	wc._hero = h
	wc._on_hero_died(&"battle")
	assert_null(wc.get_hero(), "труп убран сразу (hero == null)")
	assert_true(wc.is_death_sequence_open(), "последовательность смерти открыта")
	assert_not_null(wc._pending_successor, "преемник отложен до кнопки")
	assert_eq(str(wc._deceased_snapshot.get("hero_name", "")), "Darkstorn", "снапшот имени")
	# «Знак переходит»: перерождение + сигнал + запись в летопись.
	var fired: Array = []
	var conn := func(hero): fired.append(hero)
	GameEventBus.hero_successor.connect(conn)
	var entries: Array = []
	var entry_conn := func(_id, _text): entries.append(1)
	GameEventBus.chronicle_entry_added.connect(entry_conn)
	wc._execute_succession()
	GameEventBus.hero_successor.disconnect(conn)
	GameEventBus.chronicle_entry_added.disconnect(entry_conn)
	assert_eq(fired.size(), 1, "hero_successor эмитнут")
	assert_true(wc.get_hero() == fired[0], "активный герой — преемник")
	assert_false(wc.is_death_sequence_open(), "последовательность закрыта")
	assert_eq(wc._persistence.chronicle.entries.size(), 1, "запись цикла в летописи")
	var e: Dictionary = wc._persistence.chronicle.entries[0]
	assert_eq(entries.size(), 1, "chronicle_entry_added при записи цикла")
	assert_eq(str(e.get("outcome", "")), "succession", "outcome = succession")
	assert_eq(str(e.get("hero_name", "")), "Darkstorn", "запись про умершего")
	assert_eq(int(e.get("generation", -1)), 1, "поколение 1")
	# Очистка: преемник — дитя wc (add_child в _reincarnate), wc.free() берёт
	# его с собой. h — не дитя (труп без родителя) — свободим явно.
	# mgr — Node вне дерева (референс, не дитя) — паттерн wiring-теста.
	h.free()
	wc._cities.free()
	wc.free()

func test_on_hero_died_terminal_no_succession() -> void:
	var wc := _make_wc()
	wc._persistence.session.state = 2  # DEFEAT (enum DEFEAT) — sticky
	var h: _Hero = _Hero.new()
	h.hero_name = "Last"
	h.path_id = &"archivist"
	h.followers = [_make_follower(1, "Nyx", &"archivist")]
	wc._hero = h
	wc._on_hero_died(&"battle")
	assert_null(wc.get_hero(), "герой убран")
	assert_true(wc.is_death_sequence_open(), "последовательность открыта")
	assert_null(wc._pending_successor, "терминально: преемника не выбираем")
	assert_true(wc._persistence.chronicle.entries.is_empty(), "терминальная смерть — без записи цикла")
	h.free()
	wc._cities.free()
	wc.free()
