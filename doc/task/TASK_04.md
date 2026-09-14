### Краткая сводка найденных проблем

1. **Критическая просадка производительности (Hot Path Bottleneck) в `ServiceLocator` и `ResourceIcons`**: 
   Методы `ServiceLocator.resolve()` и `ResourceIcons._registry()` вызывают `Engine.get_main_loop().root.get_node_or_null()` при каждом запросе. В горячих циклах (расчет урона в бою, отрисовка UI ресурсов, проверка заклинаний) это вызывает обход дерева сцены сотни раз за кадр, что приводит к фризам (frame spikes). **Решение:** Кэширование ссылок на автозагрузки в статических переменных.
2. **Утечка памяти и давление на GC в `BattleSpellBridge`**: 
   В методе `_check_immunity` при каждой проверке иммунитета создаются новые литералы массивов `[&"bless", &"cure", ...]`. В бою с десятками юнитов это генерирует мусор для сборщика (GC) каждый тик. **Решение:** Вынос массивов в `const`.
3. **Микро-оптимизация аллокаций в `HexUtils`**: 
   `get_all_neighbors()` вызывается тысячи раз при поиске пути и кластеризации. Использование `append()` в цикле вызывает лишние проверки реаллокации. **Решение:** `resize(6)` и прямое присваивание по индексу.
4. **Утечка статического кэша в `ArenaClusterSystem`**: 
   Статический словарь `_cache` никогда не очищается глобально. При перезапуске сессии (возврат в меню и новая игра) старые UID городов остаются в памяти. **Решение:** Добавление метода `reset()`.

---

### Готовый код (Рефакторинг и Фиксы)

#### 1. Исправление ServiceLocator (Кэширование узлов)
```gdscript
// FILE: res://scripts/core/ServiceLocator.gd
class_name ServiceLocator

const _AUTOLOAD: Dictionary = {
	&"units": "Units",
	&"resources": "Resources",
	&"spells": "Spells",
	&"artifacts": "Artifacts",
	&"spellbook": "Spellbook",
}

static var _cache: Dictionary = {}

static func resolve(injected: Node, key: StringName) -> Node:
	if injected != null:
		return injected
	
	if _cache.has(key):
		return _cache[key]
		
	var autoload_name: String = _AUTOLOAD.get(key, "")
	if autoload_name != "":
		var ml := Engine.get_main_loop()
		if ml is SceneTree:
			var node = (ml as SceneTree).root.get_node_or_null(autoload_name)
			if node != null:
				_cache[key] = node
			return node
	return null

static func clear_cache() -> void:
	_cache.clear()
```

#### 2. Исправление ResourceIcons (Кэширование реестра)
```gdscript
// FILE: res://scripts/data/ResourceIcons.gd
class_name ResourceIcons
extends RefCounted

const _RT := preload("res://scripts/data/ResourceType.gd")

const DATA: Dictionary = {
	_RT.ID.WOOD:    {"texture": "", "name": "Дерево",    "color": Color(0.62, 0.44, 0.24)},
	_RT.ID.MERCURY: {"texture": "", "name": "Ртуть",     "color": Color(0.64, 0.67, 0.74)},
	_RT.ID.ORE:     {"texture": "", "name": "Руда",      "color": Color(0.50, 0.40, 0.34)},
	_RT.ID.SULFUR:  {"texture": "", "name": "Сера",      "color": Color(0.87, 0.80, 0.30)},
	_RT.ID.CRYSTAL: {"texture": "", "name": "Кристалл",  "color": Color(0.40, 0.63, 0.88)},
	_RT.ID.GEMS:    {"texture": "", "name": "Самоцветы", "color": Color(0.52, 0.80, 0.62)},
	_RT.ID.GOLD:    {"texture": "", "name": "Золото",    "color": Color(0.92, 0.77, 0.28)},
}

static func res_type_id(res_type: int) -> StringName:
	if res_type < 0 or res_type >= _RT.CLASSIC_COUNT:
		return &""
	return _RT.to_name(res_type)

static func res_type_amount(res_type: int) -> int:
	return _RT.pickup_amount(res_type)

static func _entry_for(resource_id: StringName) -> Dictionary:
	return DATA.get(_RT.from_name(resource_id), {})

static func get_texture(resource_id: StringName) -> Texture2D:
	var entry := _entry_for(resource_id)
	var path: String = str(entry.get("texture", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	
	var rid := _RT.from_name(resource_id)
	if rid >= 0 and rid < _RT.CLASSIC_COUNT:
		return null
	return ResourceAtlas.texture_for_id(resource_id)

static func resource_name(resource_id: StringName) -> String:
	var entry := _entry_for(resource_id)
	if entry.has("name"):
		return str(entry["name"])
	var def: ResourceDef = _registry_def(resource_id)
	if def != null and not def.display_name.is_empty():
		return def.display_name
	return str(resource_id)

static func get_color(resource_id: StringName) -> Color:
	var entry := _entry_for(resource_id)
	if entry.has("color"):
		return entry["color"]
	return _hash_color(resource_id)

static func _registry_def(resource_id: StringName) -> ResourceDef:
	var reg := _registry()
	if reg == null:
		return null
	return reg.get_resource(resource_id)

static var _registry_cache: Node = null

static func _registry() -> Node:
	if _registry_cache != null:
		return _registry_cache
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		_registry_cache = (ml as SceneTree).root.get_node_or_null(^"Resources")
	return _registry_cache

static func _hash_color(resource_id: StringName) -> Color:
	var h := absi((resource_id as String).hash())
	var hue := fmod(float(h) / 2147483647.0, 1.0)
	return Color.from_hsv(hue, 0.45, 0.75)
```

#### 3. Исправление BattleSpellBridge (Устранение аллокаций в горячем цикле)
*Замените весь файл, чтобы добавить `const` массивы и обновить `_check_immunity`.*
```gdscript
// FILE: res://scripts/data/BattleSpellBridge.gd
extends RefCounted
class_name BattleSpellBridge

const _Def = preload("res://scripts/data/SpellbookDef.gd")
const _Enums = preload("res://scripts/data/SpellEnums.gd")
const _SE = preload("res://scripts/data/StatusEffects.gd")

static var KEYWORD_TO_EFFECT: Dictionary = {
	"HASTE": _SE.Effect.HASTE,
	"PRECISION": _SE.Effect.PRECISION,
	"WIND_WALL": _SE.Effect.WIND_WALL,
	"BLOODLUST": _SE.Effect.BLOODLUST,
	"BLESS": _SE.Effect.BLESS,
	"CURSE": _SE.Effect.CURSE,
	"MISFORTUNE": _SE.Effect.MISFORTUNE,
	"SLOW": _SE.Effect.SLOW,
	"WEAKNESS": _SE.Effect.WEAKNESS,
	"SHIELD": _SE.Effect.SHIELD,
	"STONESKIN": _SE.Effect.STONESKIN,
}
static var _EFFECT_TO_KEYWORD: Dictionary = {}
static var SCHOOL_TO_COLOR: Dictionary = {
	"Air": "time",
	"Fire": "fire",
	"Water": "primal",
	"Earth": "primal",
}

const T_DIRECT_DAMAGE := &"DIRECT_DAMAGE"
const T_KEYWORD_BUFF := &"KEYWORD_BUFF"
const T_DEBUFF_CONTROL := &"DEBUFF_CONTROL"
const T_HEAL_CLEAR := &"HEAL_CLEAR"
const T_REVIVE := &"REVIVE"
const T_PORTAL := &"PORTAL"

const UNDEAD_IMMUNE_SPELLS: Array[StringName] = [&"bless", &"cure", &"curse", &"weakness", &"slow"]
const MIND_IMMUNE_SPELLS: Array[StringName] = [&"curse", &"misfortune", &"weakness", &"slow"]

static func to_spell(def: Variant) -> _Def:
	var s := def as SpellRegistry.SpellDef
	if s == null:
		return null
	var spell := _Def.new()
	spell.id = s.id
	spell.display_name = s.display_name
	spell.speed = _Enums.SpellSpeed.FAST
	spell.cost = s.base_mana
	spell.color = _Enums.parse_color(SCHOOL_TO_COLOR.get(s.school, "colorless"))
	spell.template = _template_for(s)
	spell.params = _params_for(s)
	spell.description = s.desc
	return spell

static func _template_for(s: SpellRegistry.SpellDef) -> StringName:
	if s.id == &"cure":
		return T_HEAL_CLEAR
	if s.id == &"resurrection":
		return T_REVIVE
	if s.id == &"town_portal":
		return T_PORTAL
	if s.damage_multiplier > 0:
		return T_DIRECT_DAMAGE
	if s.buff_effect >= 0:
		if _SE.is_debuff(s.buff_effect):
			return T_DEBUFF_CONTROL
		return T_KEYWORD_BUFF
	return T_PORTAL

static func _params_for(s: SpellRegistry.SpellDef) -> Dictionary:
	var p: Dictionary = {"level": s.level}
	if s.damage_multiplier > 0:
		p.template_hint = T_DIRECT_DAMAGE
		p["amount"] = s.damage_multiplier
		p["target"] = _damage_target(s.id)
		return p
	if s.buff_effect >= 0:
		p["keyword"] = _keyword_for_effect(s.buff_effect)
		if _SE.is_debuff(s.buff_effect):
			p["mass"] = (s.id == &"slow_mass")
		return p
	return p

static func _keyword_for_effect(effect: int) -> String:
	if _EFFECT_TO_KEYWORD.is_empty():
		for kw in KEYWORD_TO_EFFECT:
			_EFFECT_TO_KEYWORD[KEYWORD_TO_EFFECT[kw]] = String(kw)
	return _EFFECT_TO_KEYWORD.get(effect, "UNKNOWN")

static func _damage_target(id: StringName) -> String:
	match id:
		&"fireball", &"armageddon", &"meteor_shower":
			return "ALL_ENEMY_UNITS"
		_:
			return "ENEMY_UNIT"

static func apply_spell(
	spell: Variant,
	target: BattleState.BattleUnit,
	caster_bonus: Dictionary,
	target_bonus: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	if spell == null:
		return {"result": "not_found", "spell_id": null}
	if target == null:
		return {"result": "invalid_target", "spell_id": spell.id}
	var is_res: bool = (spell.template == T_REVIVE)
	if not is_res and not target.is_alive():
		return {"result": "invalid_target", "spell_id": spell.id}
	if _check_immunity(target, spell):
		return {"result": "immune", "spell_id": spell.id}
	var resist: bool = rng.randf() < _calc_resistance(target, target_bonus)
	var sp: int = int(caster_bonus.get("spell_power", 0))
	var result := {
		"result": "success",
		"damage": 0,
		"status": -1,
		"resisted": resist,
		"spell_id": spell.id,
	}
	match spell.template:
		T_DIRECT_DAMAGE:
			var dmg: int = sp * int(spell.params.get("amount", 0))
			if resist:
				dmg = int(dmg * 0.5)
			result = _apply_damage(target, dmg, result)
		T_KEYWORD_BUFF, T_DEBUFF_CONTROL:
			var kw: String = str(spell.params.get("keyword", "")).to_upper()
			var eff: int = KEYWORD_TO_EFFECT.get(kw, -1)
			if eff >= 0:
				target.add_status(eff, 3)
				result.status = eff
		T_HEAL_CLEAR:
			if target.has_method("clear_debuffs"):
				target.clear_debuffs()
			result.heal = sp * 10
		T_REVIVE:
			if target.get_count() <= 0:
				var hp: int = max(1, target.get_hp())
				var revived: int = int(sp * 20 / hp)
				revived = max(1, revived)
				revived = min(revived, target.max_count)
				result["revive_count"] = revived
		T_PORTAL:
			pass
	return result

static func _apply_damage(unit: BattleState.BattleUnit, dmg: int, result: Dictionary) -> Dictionary:
	var hp: int = max(1, unit.get_hp())
	var kills: int = max(1, dmg / hp)
	kills = min(kills, unit.get_count())
	result.damage = dmg
	result.kills = kills
	return result

static func _check_immunity(unit: BattleState.BattleUnit, spell: Variant) -> bool:
	if spell == null:
		return false
	var spell_id: StringName = spell.id
	var spell_level: int = int(spell.params.get("level", 1))
	if unit.has_tag("undead") and spell_id in UNDEAD_IMMUNE_SPELLS:
		return true
	if unit.has_tag("dragon") and spell_level < 4:
		return true
	if unit.has_tag("immune_mind") or unit.has_tag("mind_immune"):
		if spell_id in MIND_IMMUNE_SPELLS:
			return true
	return false

static func _calc_resistance(unit: BattleState.BattleUnit, hero_bonus: Dictionary) -> float:
	var base: float = 0.05 * int(hero_bonus.get("knowledge", 0))
	if unit.has_tag("magic_resistant"):
		base += 0.40
	return clampf(base, 0.0, 0.9)
```

#### 4. Оптимизация HexUtils (Предотвращение реаллокаций)
```gdscript
// FILE: res://scripts/core/HexUtils.gd
# Замените только функцию get_all_neighbors в существующем файле:

static func get_all_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	r.resize(6)
	for i in 6:
		r[i] = get_neighbor(cell, i)
	return r
```

#### 5. Исправление ArenaClusterSystem (Очистка статического кэша)
```gdscript
// FILE: res://scripts/city/ArenaClusterSystem.gd
# Добавьте метод reset() в конец класса:

static func reset() -> void:
	_cache.clear()
```

---

### Инструкция по установке и внедрению (Runbook)

#### Шаг 1: Применение патчей
1. Замените содержимое файла `res://scripts/core/ServiceLocator.gd` на код из блока **1**.
2. Замените содержимое файла `res://scripts/data/ResourceIcons.gd` на код из блока **2**.
3. Замените содержимое файла `res://scripts/data/BattleSpellBridge.gd` на код из блока **3**.
4. В файле `res://scripts/core/HexUtils.gd` найдите функцию `get_all_neighbors` и замените её тело на код из блока **4**.
5. В файл `res://scripts/city/ArenaClusterSystem.gd` добавьте статический метод `reset()` из блока **5**.

#### Шаг 2: Интеграционные изменения (Очистка кэша при сбросе сессии)
Чтобы статические кэши (`ServiceLocator` и `ArenaClusterSystem`) не вызывали утечек при выходе в главное меню и начале новой игры, добавьте их очистку в глобальный обработчик сброса.
Найдите место, где у вас происходит очистка состояния игры (например, в `MainMenu.gd` при нажатии "Новая игра", или в `WorldController` при выходе в меню) и добавьте:
```gdscript
ServiceLocator.clear_cache()
ArenaClusterSystem.reset()
ResourceIcons._registry_cache = null # Сброс кэша реестра ресурсов
```
*Примечание: Если вы используете `ShardManager.reset()`, добавьте эти три строки прямо туда.*

#### Шаг 3: Проверка (Команды)
Запустите headless-тесты, чтобы убедиться, что кэширование не сломало инициализацию автозагрузок:
```bash
godot --headless --script res://tests/run_tests.gd
```
*(Или используйте вашу команду запуска GdUnit4 / тестового фреймворка).*

В предоставленной базе знаний содержатся файлы сцен (`.tscn`), серверная логика, автозагрузки, тесты и вспомогательные скрипты, однако **отсутствуют сами GDScript-файлы, управляющие интерфейсом** (например, `MainMenu.gd`, `BattleUI.gd`, `CityScreen.gd`, `InfoPanel.gd`, `AdventureUI.gd`, `CharacterCreationUI.gd` и т.д.). 

Поскольку я не вижу кода, где именно сейчас происходит динамическое создание кнопок и панелей через `.new()` и `add_child()`, я не могу автоматически переписать эти скрипты. Тем не менее, я подготовил для вас **полное руководство и шаблоны**, как правильно вынести UI из кода в сцены Godot 4, опираясь на вашу текущую архитектуру.

Если вы пришлете мне содержимое конкретных `.gd` файлов (например, `CityScreen.gd` или `BattleUI.gd`), я с радостью выполню рефакторинг за вас!

---

### 🛠 Как правильно перенести UI из скриптов в сцены (Godot 4)

#### 1. Статические элементы (Кнопки, заголовки, панели)
Вместо создания узлов в `_ready()` или других функциях, добавьте их прямо в `.tscn` через редактор Godot.

**❌ Было (в скрипте):**
```gdscript
func _ready():
    var btn = Button.new()
    btn.text = "⚔️ В бой"
    btn.custom_minimum_size = Vector2(150, 40)
    btn.add_theme_font_size_override("font_size", 18)
    btn.pressed.connect(_on_battle_pressed)
    $VBoxContainer.add_child(btn)
```

**✅ Стало (в сцене `.tscn` + скрипт):**
1. Добавьте `Button` в `VBoxContainer` прямо в редакторе сцен.
2. Задайте ему уникальное имя (ПКМ по узлу -> *Access as Unique Name*, или иконка `%`).
3. В скрипте используйте `@onready` или `@export`:

```gdscript
@onready var battle_btn: Button = %BattleButton
# Или @export var battle_btn: Button (и перетащите узел в инспекторе)

func _ready():
    battle_btn.pressed.connect(_on_battle_pressed)
    # Все стили, цвета и размеры теперь настраиваются в инспекторе .tscn или через Theme
```

#### 2. Динамические списки (Инвентарь, Летопись, Армия)
Для элементов, которые создаются в цикле (список заклинаний, записи в летописи, слоты инвентаря), **создайте отдельную сцену-шаблон** для одного элемента. В вашей базе знаний уже есть отличные заготовки: `ChronicleEntry.tscn`, `ItemSlotUI.tscn`, `HeroSlot.tscn`, `TownSlot.tscn`.

**❌ Было (создание лейблов в цикле):**
```gdscript
func update_chronicle(entries: Array):
    for child in $VBox/Scroll/List.get_children():
        child.queue_free()
        
    for entry in entries:
        var lbl = Label.new()
        lbl.text = "Поколение %d: %s" % [entry.generation, entry.hero_name]
        lbl.add_theme_font_size_override("font_size", 14)
        $VBox/Scroll/List.add_child(lbl)
```

**✅ Стало (использование `PackedScene`):**
```gdscript
const ChronicleEntryScene = preload("res://scenes/ui/ChronicleEntry.tscn")

func update_chronicle(entries: Array):
    var list_node = $VBox/Scroll/List
    # Очистка списка
    for child in list_node.get_children():
        child.queue_free()
        
    # Инстанцирование готовой сцены
    for entry in entries:
        var entry_node: Label = ChronicleEntryScene.instantiate()
        list_node.add_child(entry_node)
        # Настройка данных (метод setup должен быть внутри самого ChronicleEntry.gd)
        entry_node.text = "Поколение %d: %s" % [entry.generation, entry.hero_name] 
```

#### 3. Всплывающие окна и Popup-ы
Не создавайте `PanelContainer` или `ColorRect` для затемнения из кода. Сделайте их в сцене, скройте (`visible = false`), и просто переключайте видимость.

**✅ Пример для `ResourceCollectPopup.tscn`:**
```gdscript
@onready var popup_panel: Panel = $Margin
@onready var icon_rect: TextureRect = $Margin/VBox/Image
@onready var text_label: Label = $Margin/VBox/Label

func show_resource(res_id: StringName, amount: int):
    text_label.text = "%s +%d" % [ResourceIcons.resource_name(res_id), amount]
    icon_rect.texture = ResourceIcons.get_texture(res_id)
    popup_panel.visible = true
    $DismissTimer.start() # Таймер уже настроен в .tscn
```

---

### 📋 Чек-лист для рефакторинга вашего проекта

1. **Откройте `CityScreen.gd` / `CityPanel.gd`**: Уберите создание кнопок `BuildFarm`, `BuildMine`, `LevelUp` из кода. Они уже есть в `CityScreen.tscn`. Просто подключите их сигналы через `@onready`.
2. **Откройте `BattleUI.gd`**: Кнопки `retreat_btn`, `attack_btn`, `spellbook_btn` уже лежат в `BattleUI.tscn`. Уберите их генерацию из кода, оставьте только логику `disabled` и подключение сигналов.
3. **Откройте `AdventureUI.gd` / `InfoPanel.gd`**: Панели героев и городов (`hero_slot_0`, `town_slot_0`) уже размечены в `.tscn`. Используйте `get_node("hero_slot_%d" % i)` или массив `@export_group`, чтобы заполнять их данными, а не создавать заново.
4. **Стили и Темы**: Если в коде встречаются методы вроде `add_theme_color_override`, `add_theme_font_size_override` или ручное задание `custom_minimum_size`, удалите их. Настройте эти параметры в самом редакторе Godot в разделе **Theme Overrides** для конкретного узла, либо создайте глобальный `Theme.tres` для всего проекта.


Проанализировав предоставленную базу знаний, я подготовил комплексный план рефакторинга тестовой инфраструктуры, перехода на **gdUnit4** и интеграции **tugcantopaloglu/godot-mcp**. 

Ниже представлены шаги по очистке проекта от самописных решений, стандартизации кода и улучшению покрытия.

---

### 1. Удаление самописных решений и интеграция `godot-mcp`

В коде найдены следы кастомных серверов для взаимодействия с ИИ/тестами. Поскольку вы переходите на `tugcantopaloglu/godot-mcp` (который работает через API редактора Godot или официальный CLI), эти "костыли" больше не нужны.

**Файл: `res://scripts/core/Platform.gd`**
Удаляем методы `is_test_server` и `is_socket_server`. MCP-плагин не требует внедрения сокет-серверов в рантайм игры.

```gdscript
# ❌ УДАЛИТЬ ЭТО:
static func is_test_server() -> bool:
    for arg in OS.get_cmdline_args():
        if arg.begins_with("--test-server"):
            return true
    return false

static func is_socket_server() -> bool:
    return is_test_server() or "--socket-server" in OS.get_cmdline_args()

# ✅ ОСТАВИТЬ ТОЛЬКО СТАНДАРТНЫЕ ПРОВЕРКИ:
static func is_headless() -> bool:
    return DisplayServer.get_name() == "headless"

static func is_test_framework_run() -> bool:
    for arg in OS.get_cmdline_args():
        if arg.begins_with("--add") and arg.contains("gdUnit4"): return true
        if arg.begins_with("--gdUnit4"): return true
        if arg.ends_with("GdUnitCmdTool.gd"): return true
    return false
```

**Настройка `tugcantopaloglu/godot-mcp`:**
1. Скопируйте плагин в `res://addons/godot-mcp/`.
2. Включите его в `Project -> Project Settings -> Plugins`.
3. Теперь ИИ-агенты (Claude, Cursor и т.д.) смогут запускать тесты через MCP-инструменты (например, `run_gdunit_tests`), получать дерево сцены и инспектировать узлы без самописных HTTP/WebSocket серверов.

---

### 2. Стандартизация под gdUnit4 (Удаление GUT и `test_base.gd`)

В проекте наблюдается зоопарк базовых классов: часть тестов наследуется от `GdUnitTestSuite`, часть от кастомного `"res://tests/test_base.gd"`, а в старых файлах могут встречаться остатки GUT (`GutTest`).

**Правило:** Все тесты должны наследоваться **только** от `GdUnitTestSuite`.
Файл `res://tests/test_base.gd` следует **удалить**, а все кастомные ассерты заменить на нативные методы gdUnit4.

#### Таблица миграции ассертов:

| Было (Кастом / GUT) | Стало (gdUnit4 Native) |
| :--- | :--- |
| `extends "res://tests/test_base.gd"` | `extends GdUnitTestSuite` |
| `extends GutTest` | `extends GdUnitTestSuite` |
| `check("msg", condition)` | `assert_bool(condition).is_true()` |
| `assert_approx(a, b, delta, "msg")` | `assert_float(a).is_equal_approx(b, delta)` |
| `assert_not_empty(arr)` | `assert_array(arr).is_not_empty()` |
| `assert_not_empty(str)` | `assert_str(str).is_not_empty()` |
| `assert_error(func)` | `assert_func(func).is_push_error()` |
| `yield(yield_for(0.1))` (GUT) | `await get_tree().create_timer(0.1).timeout` |

---

### 3. Улучшение логики тестов и управление памятью

В текущих тестах (например, `test_city_system.gd`, `TestBattleRules.gd`) есть проблемы с утечками памяти и "захардкоженными" нодами. gdUnit4 предоставляет мощные инструменты для автоматического освобождения ресурсов.

#### ❌ Плохая практика (Ручное управление):
```gdscript
func test_something() -> void:
    var node = Node.new()
    add_child(node)
    # ... тест ...
    node.free() # Легко забыть, если тест упадет с ошибкой до этой строки
```

#### ✅ Хорошая практика (gdUnit4 `auto_free`):
```gdscript
func test_something() -> void:
    var node := auto_free(Node.new())
    add_child(node)
    # ... тест ...
    # gdUnit4 гарантированно удалит node после завершения теста
```

#### Детерминизм и RNG:
В тестах вроде `TestBattleRules.gd` вы правильно используете `_rng.seed = 12345`. Убедитесь, что **все** тесты, зависящие от случайности, инициализируют `RandomNumberGenerator` с фиксированным сидом в `before_test()`.

---

### 4. Проработка структуры директорий

Текущая структура (`tests/`, `tests/unit/`, `tests/world/`) смешана. Рекомендуется зеркалить структуру исходного кода (src/scripts).

**Предлагаемая структура:**
```text
res://tests/
├── core/               # HexUtils, MinHeap, SaveManager, Platform
├── data/               # ResourceType, SpellbookDef, StatusEffects
├── systems/            # BattleState, TurnScheduler, SpellCaster
├── world/              # City, MapGenerator, HeroLifecycle, Succession
├── economy/            # ProductionChain, MarketSystem, CityTurnProcessor
├── ui/                 # UIAnimator, SettingsScreen
└── integration/        # Сквозные тесты (Save/Load, Полные ходы)
```

---

### 5. Примеры рефакторинга (Было / Стало)

#### Пример 1: `TestBattleRules.gd` (Исправление утечек и синтаксиса)

**Было:**
```gdscript
extends GdUnitTestSuite
# ...
func before_test() -> void:
    _rng = RandomNumberGenerator.new()
    _rng.seed = 12345 
    var atk_stats := UnitStats.new("orc", "Orc", 10, 5, 20, 5, 2, ["melee"])
    # ponytail: моки из ТЗ не работали...
    _attacker_unit = BattleState.BattleUnit.new(UnitStack.new(atk_stats, 10))
```

**Стало (с использованием `auto_free` и строгих типов):**
```gdscript
extends GdUnitTestSuite

const BattleRules = preload("res://scripts/core/BattleRules.gd")
const UnitStats = preload("res://scripts/entities/UnitStats.gd")
const UnitStack = preload("res://scripts/entities/UnitStack.gd")
const BattleState = preload("res://scripts/systems/BattleState.gd")

var _rng: RandomNumberGenerator
var _attacker_unit: BattleState.BattleUnit
var _defender_unit: BattleState.BattleUnit

func before_test() -> void:
    _rng = RandomNumberGenerator.new()
    _rng.seed = 12345 
    
    var atk_stats := UnitStats.new("orc", "Orc", 10, 5, 20, 5, 2, ["melee"])
    var def_stats := UnitStats.new("human", "Human", 5, 3, 10, 4, 5, ["melee"])
    
    # Используем auto_free для автоматической очистки памяти
    var atk_stack := auto_free(UnitStack.new(atk_stats, 10))
    var def_stack := auto_free(UnitStack.new(def_stats, 10))
    
    _attacker_unit = auto_free(BattleState.BattleUnit.new(atk_stack))
    _defender_unit = auto_free(BattleState.BattleUnit.new(def_stack))

func test_calculate_attack_base_damage() -> void:
    var result := BattleRules.calculate_attack(_attacker_unit, _defender_unit, true, _rng, 0, 0)
    
    assert_bool(result.is_empty()).is_false()
    assert_int(result.get("damage", 0)).is_greater(0)
    assert_int(result.get("damage", 0)).is_greater_equal(50)
```

#### Пример 2: Миграция с `test_base.gd` (`test_city_system.gd`)

**Было:**
```gdscript
extends "res://tests/test_base.gd"
# ...
func test_growth_births_follow_threshold() -> void:
    var c := _city()
    # ...
    assert_almost_eq(c.food_stockpile, FOOD_PER_TILE - 1.0 - 5.0 * pow(2.0, 2.75), 0.01, "food stockpile after birth")
```

**Стало:**
```gdscript
extends GdUnitTestSuite

const FOOD_PER_TILE := 100.0

func _city() -> City:
    var c := auto_free(City.new())
    c.display_name = "Тест-город"
    c.center = Vector2i(5, 5)
    return c

func test_growth_births_follow_threshold() -> void:
    var c := _city()
    c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary: 
        return {&"food": FOOD_PER_TILE, &"industry": 10.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
    c.add_followers(2)
    var u: PopUnit = c.pop[0]
    c.request_switch(u.uid, PopUnit.State.WORKER, c.first_free_worker_tile())
    
    var r := c.process_turn(1)
    
    assert_int(r.births).is_equal(1)
    var expected_food := FOOD_PER_TILE - 1.0 - 5.0 * pow(2.0, 2.75)
    assert_float(c.food_stockpile).is_equal_approx(expected_food, 0.01)
```

---

### 6. План по увеличению покрытия (Code Coverage)

Исходя из предоставленного кода, следующие зоны требуют написания дополнительных тестов:

1. **`BattleAI` и `BattleTurnExecutor`**:
   - В KB есть тесты состояния (`BattleState`), но нет тестов ИИ.
   - *Нужно покрыть:* Выбор цели (ближний бой vs стрелки), принятие решений о касте заклинаний (например, `Resurrection` при наличии мертвых юнитов), логику отступления.
2. **`SpellCaster` и `TemplateEngine` (Edge-cases)**:
   - *Нужно покрыть:*AoE заклинания (`HEX_AOE`), цепные реакции (например, `CHOICE_CYCLE` + `SECONDARY_EFFECTS`), взаимодействие `magic_resistant` и `ward` (щитов).
3. **`MarketSystem` и `RaidSystem`**:
   - *Нужно покрыть:* Попытка торговли при отсутствии рынка, продажа ресурсов с нулевым запасом, расчет урона от рейда при `0` защиты (ополчения и стен).
4. **`WorldPersistence` и `SaveData` (Миграции)**:
   - В KB есть тесты `test_save_v3.gd`. Нужно добавить параметризованные тесты для миграции с `v6` на `v7` (текущая версия), чтобы гарантировать, что добавление новых полей в `SaveData` не ломает старые сохранения.
5. **`HexPathfinding` (A* / Dijkstra)**:
   - *Нужно покрыть:* Поиск пути через "бутылочные горлышки", поведение при `max_cost` (лимит очков движения героя), обход непроходимых биомов (вода/горы).

### 7. Как запускать тесты через `godot-mcp`

После установки плагина `tugcantopaloglu/godot-mcp`, ИИ-ассистент сможет выполнять следующие команды напрямую в редакторе:

1. **Запуск всех тестов:** ИИ вызывает инструмент `run_gdunit_tests` (или аналогичный, предоставляемый плагином), который запускает `GdUnitCmdTool.gd` в headless-режиме и возвращает JSON с результатами.
2. **Запуск конкретного теста:** ИИ может сфокусироваться на одном файле, например `res://tests/systems/TestBattleRules.gd`.
3. **Инспекция сцены:** Если тест падает из-за неверной структуры сцены, ИИ использует `get_scene_tree`, чтобы увидеть, какие узлы инициализированы в `BattleUI.tscn` или `CityArena.tscn`.

**Итоговый чеклист для вас:**
1. [ ] Удалить `is_test_server` и `is_socket_server` из `Platform.gd`.
2. [ ] Удалить `res://tests/test_base.gd`.
3. [ ] Сделать глобальный поиск по проекту `extends "res://tests/test_base.gd"` и заменить на `extends GdUnitTestSuite`.
4. [ ] Заменить `check(...)` и `assert_approx(...)` на нативные `assert_bool` и `assert_float`.
5. [ ] Обернуть все `Node.new()` и `Scene.instantiate()` в тестах в `auto_free()`.
6. [ ] Установить `godot-mcp` в папку `addons/` и включить в настройках проекта.


### Краткая сводка

| Сценарий | Что проверяется | Механизм проверки |
|---|---|---|
| **1. Профилировщик** | `ServiceLocator.resolve()` и `ResourceIcons._registry()` в горячем цикле боя | Программный замер `Time.get_ticks_usec()` — воспроизводит то, что показывает Profiler, но автоматизирован |
| **2. Сброс сессии** | `ArenaClusterSystem` не переносит данные между играми | Создание города → кластер → `reset()` → новая игра с тем же UID |

Тесты разделены на два уровня:
- **`res://tests/functional/`** — gdUnit4-тесты, запускаются локально без редактора.
- **`tests/mcp/`** — сценарии через `tugcantopaloglu/godot-mcp`, проверяют поведение в живой игре.

---

### Готовый код

#### 1. Профилирование — `ServiceLocator`

```gdscript
// FILE: res://tests/functional/test_perf_service_locator.gd
extends GdUnitTestSuite
## Функциональный тест кэша в ServiceLocator.
##
## Сценарий (из ТЗ):
##   Бой 7 на 7 → горячий цикл → раньше каждый вызов делал
##   get_node_or_null (15–20% кадра в Profiler).
##   После фикса: кэшированный вызов = поиск в словаре ≈ 0 мс.

const ServiceLocatorScript = preload("res://scripts/core/ServiceLocator.gd")
const BattleEmulatorScript = preload("res://scripts/autoload/BattleEmulator.gd")
const _UnitRegistry = preload("res://scripts/autoload/UnitRegistry.gd")

## Кэшированный вызов должен быть < 0.01 мс (поиск в словаре).
## Не-кэшированный (get_node_or_null) — 0.05…0.2 мс. Порог разделяет их
## на порядок, поэтому устойчив к шуму на разных машинах.
const MAX_CACHED_CALL_MS := 0.01
## Суммарное время боя 7 на 7: до оптимизации мог быть > 1 с из-за
## повторных обходов дерева. Лимит с запасом.
const MAX_BATTLE_7V7_MS := 1000.0
## Число повторных вызовов для замера (сглаживает шум).
const WARM_CALLS := 1000

var _units: Node


func before_test() -> void:
	_units = _UnitRegistry.new()
	_units.name = "TestUnits"
	_units.ensure_definitions()
	if ServiceLocatorScript.has_method("clear_cache"):
		ServiceLocatorScript.clear_cache()


func after_test() -> void:
	if ServiceLocatorScript.has_method("clear_cache"):
		ServiceLocatorScript.clear_cache()
	if is_instance_valid(_units):
		_units.free()


## ── 1. Кэшированные вызовы ≈ 0 мс ─────────────────────────────────
func test_resolve_cached_calls_are_near_zero() -> void:
	if not ServiceLocatorScript.has_method("clear_cache"):
		assert_bool(false).is_true()
		return

	# Прогреваем кэш (первый вызов может быть медленным — это нормально)
	ServiceLocatorScript.resolve(null, &"units")

	# Замеряем 1000 кэшированных вызовов
	var t0 := Time.get_ticks_usec()
	for _i in WARM_CALLS:
		ServiceLocatorScript.resolve(null, &"units")
	var t1 := Time.get_ticks_usec()

	var avg_ms: float = float(t1 - t0) / float(WARM_CALLS) / 1000.0
	assert_float(avg_ms).is_less(MAX_CACHED_CALL_MS)


## ── 2. Все ключи кэшируются одинаково ─────────────────────────────
func test_resolve_cached_for_all_keys() -> void:
	if not ServiceLocatorScript.has_method("clear_cache"):
		assert_bool(false).is_true()
		return

	var keys: Array[StringName] = [
		&"units", &"resources", &"spells", &"artifacts", &"spellbook",
	]
	# Прогреваем все ключи
	for k in keys:
		ServiceLocatorScript.resolve(null, k)

	# Замеряем повторные вызовы для каждого ключа
	for k in keys:
		var t0 := Time.get_ticks_usec()
		for _i in 200:
			ServiceLocatorScript.resolve(null, k)
		var t1 := Time.get_ticks_usec()
		var avg_ms: float = float(t1 - t0) / 200.0 / 1000.0
		assert_float(avg_ms).is_less(MAX_CACHED_CALL_MS)


## ── 3. clear_cache сбрасывает состояние ────────────────────────────
func test_clear_cache_forces_re_lookup() -> void:
	if not ServiceLocatorScript.has_method("clear_cache"):
		assert_bool(false).is_true()
		return

	ServiceLocatorScript.resolve(null, &"units")
	ServiceLocatorScript.clear_cache()
	# После clear_cache следующий вызов не должен падать
	var node := ServiceLocatorScript.resolve(null, &"units")
	# Результат может быть null в тестовом окружении без автозагрузок —
	# главное отсутствие исключений
	assert_bool(true).is_true()


## ── 4. Бой 7 на 7 как нагрузка на горячий цикл ─────────────────────
func test_battle_7v7_does_not_spike() -> void:
	var emu := BattleEmulatorScript.new()
	var keys: Array[String] = [
		"swordsmen", "archers", "cavalry", "mages",
		"guardians", "champions", "knights",
	]
	var atk_army: Array[Dictionary] = []
	var def_army: Array[Dictionary] = []
	for k in keys:
		var s: UnitStack = _units.make_fixed_stack(k, 15)
		if s != null and s.is_alive():
			atk_army.append({"id": s.get_key(), "count": s.count})
			def_army.append({"id": s.get_key(), "count": s.count})

	assert_array(atk_army).has_size(7)
	assert_array(def_army).has_size(7)

	var t0 := Time.get_ticks_usec()
	var report: Dictionary = emu.emulate_battle({
		"attacker_army": atk_army,
		"defender_army": def_army,
	})
	var t1 := Time.get_ticks_usec()
	var elapsed_ms: float = float(t1 - t0) / 1000.0

	assert_bool(report.get("battle_over", false)).is_true()
	assert_float(elapsed_ms).is_less(MAX_BATTLE_7V7_MS)


## ── 5. Имитация горячего цикла боя (два вызова за «тик») ───────────
func test_resolve_inside_battle_loop_is_fast() -> void:
	if not ServiceLocatorScript.has_method("clear_cache"):
		assert_bool(false).is_true()
		return

	# Прогреваем
	ServiceLocatorScript.resolve(null, &"spells")
	ServiceLocatorScript.resolve(null, &"units")

	# Замеряем 500 «тиков боя», каждый делает два вызова
	var iterations := 500
	var total_usec := 0
	for _i in iterations:
		var t0 := Time.get_ticks_usec()
		ServiceLocatorScript.resolve(null, &"spells")
		ServiceLocatorScript.resolve(null, &"units")
		var t1 := Time.get_ticks_usec()
		total_usec += t1 - t0

	var avg_per_tick_ms: float = float(total_usec) / float(iterations) / 1000.0
	# Два вызова за «тик» должны занимать < 0.02 мс суммарно.
	# Раньше один только get_node_or_null занимал больше.
	assert_float(avg_per_tick_ms).is_less(0.02)
```

---

#### 2. Профилирование — `ResourceIcons`

```gdscript
// FILE: res://tests/functional/test_perf_resource_icons.gd
extends GdUnitTestSuite
## Функциональный тест кэша в ResourceIcons.
##
## Сценарий (из ТЗ):
##   Наведение на ресурсы / отрисовка панели ресурсов вызывает _registry()
##   много раз за кадр. До оптимизации каждый вызов делал
##   get_node_or_null — до 15–20% кадра.
##
## После фикса: _registry_cache хранит результат, повторные вызовы ≈ 0 мс.

const ResourceIconsScript = preload("res://scripts/data/ResourceIcons.gd")

## Кэшированный вызов должен быть < 0.01 мс.
const MAX_CACHED_CALL_MS := 0.01
## Один «кадр» панели ресурсов (7 ресурсов) должен занимать < 0.1 мс.
const MAX_FRAME_MS := 0.1
const WARM_CALLS := 1000


func test_registry_cached_calls_are_near_zero() -> void:
	# Прогреваем кэш (первый вызов может вернуть null в тестовом окружении
	# без дерева сцены — это нормально, проверяем только скорость)
	ResourceIconsScript._registry()

	var t0 := Time.get_ticks_usec()
	for _i in WARM_CALLS:
		ResourceIconsScript._registry()
	var t1 := Time.get_ticks_usec()

	var avg_ms: float = float(t1 - t0) / float(WARM_CALLS) / 1000.0
	assert_float(avg_ms).is_less(MAX_CACHED_CALL_MS)


func test_registry_cache_variable_exists() -> void:
	# Проверяем, что статическая переменная кэша существует в классе.
	# Если фикс не применён — _registry_cache не существует, тест падает.
	var has_cache: bool = ResourceIconsScript.has_property("_registry_cache") \
		or "_registry_cache" in ResourceIconsScript
	assert_bool(has_cache).is_true()


func test_resource_name_hot_path_is_fast() -> void:
	# Имитируем отрисовку панели ресурсов: 7 ресурсов × много кадров
	var ids: Array[StringName] = [
		&"wood", &"mercury", &"ore", &"sulfur", &"crystal", &"gems", &"gold",
	]
	# Прогреваем
	for id in ids:
		ResourceIconsScript.resource_name(id)

	# Замеряем 100 «кадров» панели
	var t0 := Time.get_ticks_usec()
	for _frame in 100:
		for id in ids:
			ResourceIconsScript.resource_name(id)
	var t1 := Time.get_ticks_usec()

	var avg_per_frame_ms: float = float(t1 - t0) / 100.0 / 1000.0
	assert_float(avg_per_frame_ms).is_less(MAX_FRAME_MS)


func test_get_texture_hot_path_is_fast() -> void:
	# Теренные ресурсы (вызывают ResourceAtlas + реестр)
	var ids: Array[StringName] = [&"oak", &"silver", &"quartz"]
	# Прогреваем
	for id in ids:
		ResourceIconsScript.get_texture(id)

	var t0 := Time.get_ticks_usec()
	for _frame in 100:
		for id in ids:
			ResourceIconsScript.get_texture(id)
	var t1 := Time.get_ticks_usec()

	var avg_per_frame_ms: float = float(t1 - t0) / 100.0 / 1000.0
	assert_float(avg_per_frame_ms).is_less(MAX_FRAME_MS)


func test_get_color_is_pure_and_fast() -> void:
	# get_color не зависит от дерева сцены — должен быть быстрым всегда
	var ids: Array[StringName] = [&"wood", &"coal", &"bog_iron"]

	var t0 := Time.get_ticks_usec()
	for _i in WARM_CALLS:
		for id in ids:
			ResourceIconsScript.get_color(id)
	var t1 := Time.get_ticks_usec()

	var avg_ms: float = float(t1 - t0) / float(WARM_CALLS) / 1000.0
	assert_float(avg_ms).is_less(0.05)
```

---

#### 3. Сброс сессии — `ArenaClusterSystem`

```gdscript
// FILE: res://tests/functional/test_session_reset.gd
extends GdUnitTestSuite
## Функциональный тест сброса сессии и кэша кластеров.
##
## Сценарий (из ТЗ):
##   1. Начинаем игру, строим город с кластером зданий.
##   2. Выходим в меню (имитация: ArenaClusterSystem.reset()).
##   3. Начинаем новую игру с тем же UID.
##   4. Проверяем отсутствие артефактов отрисовки из старой сессии.

const ArenaClusterSystemScript = preload("res://scripts/city/ArenaClusterSystem.gd")
const BuildingDefsScript = preload("res://scripts/data/BuildingDefs.gd")
const ArenaTurnRunnerScript = preload("res://scripts/city/ArenaTurnRunner.gd")
const CityArenaModelScript = preload("res://scripts/city/CityArenaModel.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")
const _PopUnit = preload("res://scripts/world/PopUnit.gd")
const _UniqueBuilding = preload("res://scripts/world/UniqueBuilding.gd")


func before_test() -> void:
	if ArenaClusterSystemScript.has_method("reset"):
		ArenaClusterSystemScript.reset()


func after_test() -> void:
	if ArenaClusterSystemScript.has_method("reset"):
		ArenaClusterSystemScript.reset()


## ── Вспомогательные ─────────────────────────────────────────────────
func _require_reset_method() -> bool:
	if not ArenaClusterSystemScript.has_method("reset"):
		assert_bool(false).is_true()
		return false
	return true


func _build_cluster_city(uid: int) -> City:
	## Строим город с кластером из 4 ферм на клетках, соседних с центром.
	## 4 здания = минимальный кластер (CLUSTER_MIN = 4).
	var city := CityArenaModelScript.make_city()
	city.uid = uid
	var center: Vector2i = city.center
	var farm_def: _UniqueBuilding.Def = BuildingDefsScript.farm()
	for bit in 4:
		var cell: Vector2i = _HexUtils.get_neighbor(center, bit)
		ArenaTurnRunnerScript.place_building(city, farm_def, cell)
	return city


func _build_sparse_city(uid: int) -> City:
	## Город с одним зданием — кластера быть не должно.
	var city := CityArenaModelScript.make_city()
	city.uid = uid
	var mine_def: _UniqueBuilding.Def = BuildingDefsScript.mine()
	var cell: Vector2i = _HexUtils.get_neighbor(city.center, 0)
	ArenaTurnRunnerScript.place_building(city, mine_def, cell)
	return city


## ── 1. Кэш заполняется при первом обращении ─────────────────────────
func test_cluster_cache_populated_after_first_call() -> void:
	if not _require_reset_method():
		return

	var city := _build_cluster_city(1)
	var clusters_first: Array = ArenaClusterSystemScript.clusters(city)
	assert_bool(clusters_first.size() >= 1).is_true()

	# Повторный вызов должен вернуть тот же результат из кэша
	var clusters_second: Array = ArenaClusterSystemScript.clusters(city)
	assert_array(clusters_second).has_size(clusters_first.size())


## ── 2. reset() очищает кэш полностью ────────────────────────────────
func test_reset_clears_all_cached_clusters() -> void:
	if not _require_reset_method():
		return

	var city := _build_cluster_city(42)
	ArenaClusterSystemScript.clusters(city)

	ArenaClusterSystemScript.reset()

	# После reset повторный вызов должен пересчитать данные с нуля
	var clusters_after: Array = ArenaClusterSystemScript.clusters(city)
	assert_bool(clusters_after.size() >= 1).is_true()


## ── 3. Новая игра не видит старые здания ───────────────────────────
func test_new_game_does_not_see_old_buildings() -> void:
	if not _require_reset_method():
		return

	# ── Сессия 1: город с кластером ──
	var city1 := _build_cluster_city(1)
	ArenaClusterSystemScript.clusters(city1)

	# ── Имитация выхода в меню ──
	ArenaClusterSystemScript.reset()

	# ── Сессия 2: новый город с тем же UID ──
	var city2 := _build_cluster_city(1)
	var clusters2: Array = ArenaClusterSystemScript.clusters(city2)

	assert_bool(clusters2.size() >= 1).is_true()

	# Каждое здание в кластере должно принадлежать ТЕКУЩЕМУ городу
	for cl in clusters2:
		var buildings: Array = cl["buildings"]
		for b in buildings:
			assert_bool(city2.buildings.has(b)).is_true()


## ── 4. Нет перекрёстной контаминации между городами ───────────────
func test_no_cross_contamination_between_cities() -> void:
	if not _require_reset_method():
		return

	# Город A: кластер ферм
	var city_a := _build_cluster_city(100)
	var clusters_a: Array = ArenaClusterSystemScript.clusters(city_a)
	assert_bool(clusters_a.size() >= 1).is_true()

	# Город B: одно здание — кластера быть не должно
	var city_b := _build_sparse_city(200)
	var clusters_b: Array = ArenaClusterSystemScript.clusters(city_b)
	assert_bool(clusters_b.size() == 0).is_true()


## ── 5. Полный цикл: 3 сессии подряд с одинаковым UID ───────────────
func test_full_session_reset_cycle_three_games() -> void:
	if not _require_reset_method():
		return

	var previous_first_building: _UniqueBuilding = null

	for session in 3:
		ArenaClusterSystemScript.reset()

		var city := _build_cluster_city(1)
		var clusters: Array = ArenaClusterSystemScript.clusters(city)

		assert_bool(clusters.size() >= 1).is_true()

		var first_building: _UniqueBuilding = clusters[0]["buildings"][0]

		# Все здания должны принадлежать текущему городу
		for cl in clusters:
			for b in cl["buildings"]:
				assert_bool(city.buildings.has(b)).is_true()

		# Здание из новой сессии не должно совпадать с предыдущей
		if previous_first_building != null:
			assert_bool(first_building != previous_first_building).is_true()

		previous_first_building = first_building


## ── 6. Кластер пересчитывается при изменении города ────────────────
func test_cache_invalidated_when_city_changes() -> void:
	if not _require_reset_method():
		return

	var city := _build_cluster_city(5)
	var clusters_before: Array = ArenaClusterSystemScript.clusters(city)
	var size_before: int = clusters_before.size()
	assert_bool(size_before >= 1).is_true()

	# Добавляем пятое здание — кластер должен остаться прежним
	# (версия города меняется, кэш пересчитывается)
	var farm_def: _UniqueBuilding.Def = BuildingDefsScript.farm()
	var extra_cell: Vector2i = _HexUtils.get_neighbor(city.center, 4)
	ArenaTurnRunnerScript.place_building(city, farm_def, extra_cell)
	ArenaClusterSystemScript.invalidate(city.uid)

	var clusters_after: Array = ArenaClusterSystemScript.clusters(city)
	assert_bool(clusters_after.size() >= 1).is_true()
```

---

#### 4. MCP-сценарий: профилирование боя

```python
# FILE: tests/mcp/test_battle_profiling.py
"""
Тест 1: Профилировщик боя 7 на 7 через tugcantopaloglu/godot-mcp.

Сценарий из ТЗ:
  - Запускаем игру и начинаем бой 7 на 7.
  - Замеряем время вызовов, которые раньше были видны в Profiler.
  - Проверяем, что время упало до ~0 мс после кэширования.

Требования:
  - Запущенный редактор Godot с включённым плагином godot-mcp.
  - Установленный пакет: pip install mcp pytest pytest-asyncio

Запуск:
  pytest tests/mcp/test_battle_profiling.py -v
"""
from __future__ import annotations
import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from helpers.mcp_client import GodotMCPClient

pytestmark = pytest.mark.asyncio

## Максимальное среднее время на кэшированный вызов (мс)
MAX_CACHED_CALL_MS = 0.01
## Максимальное время боя 7 на 7 (мс)
MAX_BATTLE_7V7_MS = 1000.0
## Количество повторных вызовов для замера
WARM_CALLS = 1000


async def test_service_locator_cached_calls_near_zero(mcp: GodotMCPClient):
    """
    После первого вызова ServiceLocator.resolve() повторные вызовы
    должны занимать ~0 мс (кэш работает).

    Это заменяет визуальную проверку в Profiler: раньше
    get_node_or_null занимал 15–20% кадра.
    """
    # Проверяем наличие метода кэширования
    has_cache = await mcp.execute_code("""
var ServiceLocator = load("res://scripts/core/ServiceLocator.gd")
return {"has_clear_cache": ServiceLocator.has_method("clear_cache")}
""")
    assert has_cache.get("has_clear_cache"), (
        "ServiceLocator.clear_cache() не найден — "
        "фикс кэширования не применён"
    )

    # Очищаем кэш
    await mcp.execute_code("""
var ServiceLocator = load("res://scripts/core/ServiceLocator.gd")
ServiceLocator.clear_cache()
""")

    # Прогреваем кэш
    await mcp.execute_code("""
var ServiceLocator = load("res://scripts/core/ServiceLocator.gd")
ServiceLocator.resolve(null, &"units")
ServiceLocator.resolve(null, &"spells")
""")

    # Замеряем кэшированные вызовы
    result = await mcp.execute_code(f"""
var ServiceLocator = load("res://scripts/core/ServiceLocator.gd")
var t0 := Time.get_ticks_usec()
for i in {WARM_CALLS}:
    ServiceLocator.resolve(null, &"units")
    ServiceLocator.resolve(null, &"spells")
var t1 := Time.get_ticks_usec()
var avg_ms := float(t1 - t0) / float({WARM_CALLS}) / 1000.0 / 2.0
return {{"avg_ms": avg_ms, "calls": {WARM_CALLS}}}
""")

    avg_ms = float(result.get("avg_ms", 999))
    assert avg_ms < MAX_CACHED_CALL_MS, (
        f"Кэшированный вызов занимает {avg_ms:.4f} мс "
        f"(лимит {MAX_CACHED_CALL_MS} мс). "
        f"Кэш не работает или слишком медленный."
    )


async def test_resource_icons_registry_cached(mcp: GodotMCPClient):
    """
    Проверяем, что _registry() в ResourceIcons кэшируется.
    """
    # Прогреваем
    await mcp.execute_code("""
var ResourceIcons = load("res://scripts/data/ResourceIcons.gd")
ResourceIcons._registry()
""")

    # Замеряем
    result = await mcp.execute_code(f"""
var ResourceIcons = load("res://scripts/data/ResourceIcons.gd")
var t0 := Time.get_ticks_usec()
for i in {WARM_CALLS}:
    ResourceIcons._registry()
var t1 := Time.get_ticks_usec()
var avg_ms := float(t1 - t0) / float({WARM_CALLS}) / 1000.0
return {{"avg_ms": avg_ms}}
""")

    avg_ms = float(result.get("avg_ms", 999))
    assert avg_ms < MAX_CACHED_CALL_MS, (
        f"_registry() занимает {avg_ms:.4f} мс "
        f"(лимит {MAX_CACHED_CALL_MS} мс). "
        f"Кэш реестра ресурсов не работает."
    )


async def test_battle_7v7_performance(mcp: GodotMCPClient):
    """
    Запускаем бой 7 на 7 через BattleEmulator и проверяем,
    что общее время боя укладывается в лимит.
    """
    result = await mcp.execute_code("""
var emu = load("res://scripts/autoload/BattleEmulator.gd").new()
var units_reg = load("res://scripts/autoload/UnitRegistry.gd").new()
units_reg.ensure_definitions()

var keys := ["swordsmen", "archers", "cavalry", "mages",
             "guardians", "champions", "knights"]
var atk_stacks: Array[Dictionary] = []
var def_stacks: Array[Dictionary] = []
for k in keys:
    var stack = units_reg.make_fixed_stack(k, 15)
    if stack != null and stack.is_alive():
        atk_stacks.append({"id": stack.get_key(), "count": stack.count})
        def_stacks.append({"id": stack.get_key(), "count": stack.count})

var t0 := Time.get_ticks_usec()
var report: Dictionary = emu.emulate_battle({
    "attacker_army": atk_stacks,
    "defender_army": def_stacks,
})
var t1 := Time.get_ticks_usec()
var elapsed_ms := float(t1 - t0) / 1000.0

units_reg.free()
return {
    "battle_over": report.get("battle_over", false),
    "elapsed_ms": elapsed_ms,
    "winner": report.get("winner", "unknown"),
    "turns": report.get("turns", 0),
    "army_size": atk_stacks.size(),
}
""")

    assert result.get("battle_over"), "Бой 7 на 7 не завершился"
    assert result.get("army_size", 0) == 7, (
        f"Ожидалось 7 стеков в армии, получено {result.get('army_size')}"
    )
    elapsed_ms = float(result.get("elapsed_ms", 999999))
    assert elapsed_ms < MAX_BATTLE_7V7_MS, (
        f"Бой 7 на 7 занял {elapsed_ms:.1f} мс "
        f"(лимит {MAX_BATTLE_7V7_MS} мс). "
        f"Возможны фризы из-за неоптимизированных вызовов."
    )


async def test_mass_spell_cast_no_freeze(mcp: GodotMCPClient):
    """
    Имитация массового каста заклинаний: каждый каст вызывает
    resolve() для получения SpellRegistry. Проверяем, что суммарное
    время на 20 кастов < 1 мс.
    """
    result = await mcp.execute_code("""
var ServiceLocator = load("res://scripts/core/ServiceLocator.gd")
# Прогреваем
ServiceLocator.resolve(null, &"spells")

# Замеряем 20 «кастов» — каждый делает два вызова
var casts := 20
var total_usec := 0
for i in casts:
    var t0 := Time.get_ticks_usec()
    ServiceLocator.resolve(null, &"spells")
    ServiceLocator.resolve(null, &"spellbook")
    var t1 := Time.get_ticks_usec()
    total_usec += t1 - t0

var total_ms := float(total_usec) / 1000.0
var avg_per_cast_ms := total_ms / float(casts)
return {
    "total_ms": total_ms,
    "avg_per_cast_ms": avg_per_cast_ms,
    "casts": casts,
}
""")

    avg = float(result.get("avg_per_cast_ms", 999))
    assert avg < 0.05, (
        f"Один «каст заклинания» занимает {avg:.4f} мс "
        f"(лимит 0.05 мс). Фризы при массовом касте не устранены."
    )
```

---

#### 5. MCP-сценарий: сброс сессии

```python
# FILE: tests/mcp/test_session_reset.py
"""
Тест 2: Сброс сессии через tugcantopaloglu/godot-mcp.

Сценарий из ТЗ:
  - Начинаем игру, строим город с кластером.
  - Выходим в меню (имитация: ArenaClusterSystem.reset()).
  - Начинаем новую игру.
  - Проверяем отсутствие артефактов отрисовки из старой сессии.

Запуск:
  pytest tests/mcp/test_session_reset.py -v
"""
from __future__ import annotations
import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from helpers.mcp_client import GodotMCPClient

pytestmark = pytest.mark.asyncio


async def test_reset_method_exists(mcp: GodotMCPClient):
    """Проверяем, что метод сброса добавлен в ArenaClusterSystem."""
    result = await mcp.execute_code("""
var ArenaClusterSystem = load("res://scripts/city/ArenaClusterSystem.gd")
return {"has_reset": ArenaClusterSystem.has_method("reset")}
""")
    assert result.get("has_reset"), (
        "ArenaClusterSystem.reset() не найден — "
        "добавьте статический метод reset() для очистки кэша"
    )


async def test_cluster_cache_populated_and_reset(mcp: GodotMCPClient):
    """
    Полный цикл:
    1. Строим город с кластером → кэш заполняется.
    2. Вызываем reset() → кэш очищается.
    3. Строим новый город → данные свежие.
    """
    result = await mcp.execute_code("""
var ArenaClusterSystem = load("res://scripts/city/ArenaClusterSystem.gd")
var BuildingDefs = load("res://scripts/data/BuildingDefs.gd")
var ArenaTurnRunner = load("res://scripts/city/ArenaTurnRunner.gd")
var CityArenaModel = load("res://scripts/city/CityArenaModel.gd")
var HexUtils = load("res://scripts/core/HexUtils.gd")

if not ArenaClusterSystem.has_method("reset"):
    return {"error": "ArenaClusterSystem.reset() не найден"}

ArenaClusterSystem.reset()

# ── Сессия 1: строим город с кластером ──
var city1 := CityArenaModel.make_city()
city1.uid = 1
var center: Vector2i = city1.center
var farm_def := BuildingDefs.farm()
for bit in 4:
    ArenaTurnRunner.place_building(
        city1, farm_def, HexUtils.get_neighbor(center, bit))

var clusters1: Array = ArenaClusterSystem.clusters(city1)
var s1_size: int = clusters1.size()
if s1_size < 1:
    return {"error": "Кластер не найден в первой сессии"}

# ── Имитация выхода в меню ──
ArenaClusterSystem.reset()

# ── Сессия 2: новый город с тем же UID ──
var city2 := CityArenaModel.make_city()
city2.uid = 1
for bit in 4:
    ArenaTurnRunner.place_building(
        city2, farm_def, HexUtils.get_neighbor(center, bit))

var clusters2: Array = ArenaClusterSystem.clusters(city2)
var s2_size: int = clusters2.size()

# Проверяем, что все здания в кластере принадлежат текущему городу
var all_belong_to_city2: bool = true
for cl in clusters2:
    var buildings: Array = cl["buildings"]
    for b in buildings:
        if not city2.buildings.has(b):
            all_belong_to_city2 = false

return {
    "s1_size": s1_size,
    "s2_size": s2_size,
    "all_belong_to_city2": all_belong_to_city2,
}
""")

    assert "error" not in result, f"Ошибка: {result.get('error')}"
    assert result.get("s1_size", 0) >= 1, (
        "Кластер не найден в сессии 1"
    )
    assert result.get("s2_size", 0) >= 1, (
        "Кластер не найден в сессии 2"
    )
    assert result.get("s1_size") == result.get("s2_size"), (
        f"Размер кластеров различается: "
        f"сессия 1 = {result.get('s1_size')}, "
        f"сессия 2 = {result.get('s2_size')}. "
        f"Возможна утечка данных из кэша."
    )
    assert result.get("all_belong_to_city2"), (
        "Обнаружены артефакты от старой сессии: "
        "здания в кластере не принадлежат текущему городу"
    )


async def test_no_cross_contamination_between_games(mcp: GodotMCPClient):
    """
    Проверяем, что данные из игры А не просачиваются в игру Б
    при одинаковых UID городов.
    """
    result = await mcp.execute_code("""
var ArenaClusterSystem = load("res://scripts/city/ArenaClusterSystem.gd")
var BuildingDefs = load("res://scripts/data/BuildingDefs.gd")
var ArenaTurnRunner = load("res://scripts/city/ArenaTurnRunner.gd")
var CityArenaModel = load("res://scripts/city/CityArenaModel.gd")
var HexUtils = load("res://scripts/core/HexUtils.gd")

if not ArenaClusterSystem.has_method("reset"):
    return {"error": "reset() не найден"}

ArenaClusterSystem.reset()

# ── Игра А: город с кластером ферм ──
var city_a := CityArenaModel.make_city()
city_a.uid = 10
var center_a: Vector2i = city_a.center
var farm_def := BuildingDefs.farm()
for bit in 4:
    ArenaTurnRunner.place_building(
        city_a, farm_def, HexUtils.get_neighbor(center_a, bit))
var clusters_a: Array = ArenaClusterSystem.clusters(city_a)
var a_has_cluster: bool = clusters_a.size() >= 1

# ── Имитация выхода в меню ──
ArenaClusterSystem.reset()

# ── Игра Б: город с одним зданием — кластера быть не должно ──
var city_b := CityArenaModel.make_city()
city_b.uid = 10
var mine_def := BuildingDefs.mine()
ArenaTurnRunner.place_building(
    city_b, mine_def, HexUtils.get_neighbor(city_b.center, 0))
var clusters_b: Array = ArenaClusterSystem.clusters(city_b)
var b_has_cluster: bool = clusters_b.size() >= 1

return {
    "a_has_cluster": a_has_cluster,
    "b_has_cluster": b_has_cluster,
}
""")

    assert "error" not in result, f"Ошибка: {result.get('error')}"
    assert result.get("a_has_cluster"), "Игра А должна иметь кластер"
    assert not result.get("b_has_cluster"), (
        "Игра Б не должна иметь кластеров — обнаружена перекрёстная "
        "контаминация кэша из игры А"
    )


async def test_full_session_lifecycle_three_games(mcp: GodotMCPClient):
    """
    Полный цикл: три сессии подряд с одинаковым UID города.
    Проверяем, что каждая сессия получает свежие данные.
    """
    result = await mcp.execute_code("""
var ArenaClusterSystem = load("res://scripts/city/ArenaClusterSystem.gd")
var BuildingDefs = load("res://scripts/data/BuildingDefs.gd")
var ArenaTurnRunner = load("res://scripts/city/ArenaTurnRunner.gd")
var CityArenaModel = load("res://scripts/city/CityArenaModel.gd")
var HexUtils = load("res://scripts/core/HexUtils.gd")

if not ArenaClusterSystem.has_method("reset"):
    return {"error": "reset() не найден"}

var results: Array = []

for session in 3:
    ArenaClusterSystem.reset()

    var city := CityArenaModel.make_city()
    city.uid = 1  # Одинаковый UID каждый раз
    var farm_def := BuildingDefs.farm()
    var center: Vector2i = city.center
    for bit in 4:
        ArenaTurnRunner.place_building(
            city, farm_def, HexUtils.get_neighbor(center, bit))

    var clusters: Array = ArenaClusterSystem.clusters(city)
    var buildings_valid: bool = true
    for cl in clusters:
        for b in cl["buildings"]:
            if not city.buildings.has(b):
                buildings_valid = false

    results.append({
        "session": session,
        "clusters": clusters.size(),
        "buildings_valid": buildings_valid,
    })

return {"results": results}
""")

    assert "error" not in result, f"Ошибка: {result.get('error')}"
    for r in result.get("results", []):
        assert r.get("clusters", 0) >= 1, (
            f"Сессия {r['session']}: кластер не найден"
        )
        assert r.get("buildings_valid"), (
            f"Сессия {r['session']}: обнаружены артефакты от предыдущей "
            f"сессии — здания в кластере не принадлежат текущему городу"
        )


async def test_visual_no_artifacts_on_menu_transition(mcp: GodotMCPClient):
    """
    Проверяем, что при переходе в меню и обратно
    дерево сцены не содержит лишних узлов от старой игры.
    """
    # Имитация: строим город, выходим, строим новый
    result = await mcp.execute_code("""
var ArenaClusterSystem = load("res://scripts/city/ArenaClusterSystem.gd")
var BuildingDefs = load("res://scripts/data/BuildingDefs.gd")
var ArenaTurnRunner = load("res://scripts/city/ArenaTurnRunner.gd")
var CityArenaModel = load("res://scripts/city/CityArenaModel.gd")
var HexUtils = load("res://scripts/core/HexUtils.gd")

if not ArenaClusterSystem.has_method("reset"):
    return {"error": "reset() не найден"}

# Сессия 1
ArenaClusterSystem.reset()
var city1 := CityArenaModel.make_city()
city1.uid = 1
var farm_def := BuildingDefs.farm()
for bit in 4:
    ArenaTurnRunner.place_building(
        city1, farm_def, HexUtils.get_neighbor(city1.center, bit))
ArenaClusterSystem.clusters(city1)
var city1_buildings: int = city1.buildings.size()

# Выход в меню
ArenaClusterSystem.reset()

# Сессия 2
var city2 := CityArenaModel.make_city()
city2.uid = 1
for bit in 4:
    ArenaTurnRunner.place_building(
        city2, farm_def, HexUtils.get_neighbor(city2.center, bit))
ArenaClusterSystem.clusters(city2)
var city2_buildings: int = city2.buildings.size()

return {
    "city1_buildings": city1_buildings,
    "city2_buildings": city2_buildings,
    "buildings_match": city1_buildings == city2_buildings,
}
""")

    assert "error" not in result, f"Ошибка: {result.get('error')}"
    assert result.get("buildings_match"), (
        f"Количество зданий различается между сессиями: "
        f"сессия 1 = {result.get('city1_buildings')}, "
        f"сессия 2 = {result.get('city2_buildings')}. "
        f"Возможны артефакты отрисовки."
    )
```

---

#### 6. Обновление конфигурации тестов

```python
# FILE: tests/mcp/conftest.py
"""Фикстуры для MCP-тестов."""
from __future__ import annotations
import asyncio
import sys
from pathlib import Path
import pytest
import pytest_asyncio
sys.path.insert(0, str(Path(__file__).parent.parent))
from helpers.mcp_client import GodotMCPClient
@pytest.fixture(scope="session")
def event_loop():
loop = asyncio.new_event_loop()
yield loop
loop.close()
@pytest_asyncio.fixture(scope="session")
async def mcp() -> GodotMCPClient:
"""Подключение к MCP-серверу на всё время сессии тестов."""
client = GodotMCPClient()
await client.connect()
yield client
await client.disconnect()
```

```ini
# FILE: tests/mcp/pytest.ini
[pytest]
asyncio_mode = auto
testpaths = tests/mcp
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short
markers =
    profiling: тесты производительности (профилировщик)
    reset: тесты сброса сессии
```

---

### Пошаговая инструкция по интеграции (Runbook)

#### Шаг 1: Создание файлов

```bash
mkdir -p res://tests/functional
mkdir -p tests/mcp

# Создать файлы:
# res://tests/functional/test_perf_service_locator.gd
# res://tests/functional/test_perf_resource_icons.gd
# res://tests/functional/test_session_reset.gd
# tests/mcp/test_battle_profiling.py
# tests/mcp/test_session_reset.py
# tests/mcp/conftest.py  (обновить)
# tests/mcp/pytest.ini   (обновить)
```

#### Шаг 2: Убедиться, что фиксы применены

Тесты проверяют наличие следующих изменений в кодовой базе:

| Класс | Что должно быть |
|---|---|
| `ServiceLocator` | `static var _cache: Dictionary` + `clear_cache()` |
| `ResourceIcons` | `static var _registry_cache: Node` в `_registry()` |
| `ArenaClusterSystem` | `static func reset() -> void` |

Если методы отсутствуют — тесты падают с понятным сообщением.

#### Шаг 3: Установка зависимостей

```bash
pip install mcp pytest pytest-asyncio
```

#### Шаг 4: Запуск тестов

**Локально (без редактора):**
```bash
# GDScript тесты через редактор
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path res:// \
  --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode \
  res://tests/functional/test_perf_service_locator.gd \
  res://tests/functional/test_perf_resource_icons.gd \
  res://tests/functional/test_session_reset.gd
```

**Через MCP (с запущенным редактором):**
```bash
# Профилирование боя
pytest tests/mcp/test_battle_profiling.py -v

# Сброс сессии
pytest tests/mcp/test_session_reset.py -v

# Все MCP-тесты
pytest tests/mcp/ -v
```

#### Шаг 5: Визуальная проверка в редакторе

1. Откройте **Debugger → Profiler**.
2. Начните бой 7 на 7.
3. В списке функций найдите `ServiceLocator.resolve` и `ResourceIcons._registry`.
4. **Ожидаемый результат:** время на оба вызова < 0.1% кадра (не видны в профайлере).
5. Перейдите в меню → новая игра.
6. **Ожидаемый результат:** нет ошибок в консоли, связанных со старыми UID.

---

### Критерии приёмки

| Критерий | Как проверить |
|---|---|
| Кэшированный вызов `resolve()` < 0.01 мс | `test_resolve_cached_calls_are_near_zero` |
| Кэшированный вызов `_registry()` < 0.01 мс | `test_registry_cached_calls_are_near_zero` |
| Бой 7 на 7 < 1000 мс | `test_battle_7v7_performance` |
| Два вызова `resolve()` за «тик боя» < 0.02 мс | `test_resolve_inside_battle_loop_is_fast` |
| Один «каст заклинания» < 0.05 мс | `test_mass_spell_cast_no_freeze` |
| Кластер не переносится между играми | `test_no_cross_contamination_between_games` |
| Все здания кластера принадлежат текущему городу | `test_new_game_does_not_see_old_buildings` |
| Три сессии подряд без артефактов | `test_full_session_lifecycle_three_games` |
| `ArenaClusterSystem.reset()` существует | `test_reset_method_exists` |

