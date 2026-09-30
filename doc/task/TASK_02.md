# 🚀 ГОТОВАЯ ИНСТРУКЦИЯ И КОД ДЛЯ ЛОКАЛЬНОГО АГЕНТА

Ниже представлен финальный, систематизированный набор файлов для глобального рефакторинга. Код использует **Стратегию** (потребности), **Наследование** (базовые классы стратегий), **Композицию** (глобальная тема Godot + UITheme) и современные фишки GDScript 4.7.

---

## 📂 ЭТАП 1: Data Layer & Стратегии (Паттерн Strategy)

Создайте базовый класс и наследников для инкапсуляции логики потребностей.

```gdscript
// FILE: res://scripts/data/needs/need_strategy.gd
class_name NeedStrategy
extends RefCounted

var decay_rate: float

func _init(p_decay: float) -> void:
   decay_rate = p_decay

func get_recovery_hero(in_city: bool, city: City) -> float:
   return 0.0

func get_recovery_pop(city: City, pop: PopUnit) -> float:
   return 0.0

func get_death_cause() -> StringName:
   return &""
```

```gdscript
// FILE: res://scripts/data/needs/rest_strategy.gd
class_name RestStrategy
extends NeedStrategy

func _init() -> void:
   super._init(0.10)

func get_recovery_hero(in_city: bool, city: City) -> float:
   return 0.36 if in_city else 0.0

func get_recovery_pop(city: City, pop: PopUnit) -> float:
   if pop != null and pop.state == PopUnit.State.MILITIA: return 0.0
   return 0.12

func get_death_cause() -> StringName:
   return &"exhaustion"
```

```gdscript
// FILE: res://scripts/data/needs/social_strategy.gd
class_name SocialStrategy
extends NeedStrategy

func _init() -> void:
   super._init(0.08)

func get_recovery_hero(in_city: bool, city: City) -> float:
   if in_city and city != null and city.pop.size() >= 3: return 0.30
   return -0.05

func get_recovery_pop(city: City, pop: PopUnit) -> float:
   if city != null and city.pop.size() >= 3: return 0.10
   return -0.05

func get_death_cause() -> StringName:
   return &"isolation"
```

```gdscript
// FILE: res://scripts/data/needs/inspiration_strategy.gd
class_name InspirationStrategy
extends NeedStrategy

func _init() -> void:
   super._init(0.05)

func get_recovery_hero(in_city: bool, city: City) -> float:
   return 0.15 if in_city else 0.0

func get_recovery_pop(city: City, pop: PopUnit) -> float:
   return 0.05

func get_death_cause() -> StringName:
   return &"burnout"
```

Создайте Enum'ы. В `NeedType` регистрируем стратегии.

```gdscript
// FILE: res://scripts/data/school_type.gd
class_name SchoolType
extends RefCounted

enum ID { AIR = 0, FIRE = 1, WATER = 2, EARTH = 3 }
const COUNT := 4

static func to_key(id: int) -> String:
   match id:
      ID.AIR: return "air"
      ID.FIRE: return "fire"
      ID.WATER: return "water"
      ID.EARTH: return "earth"
   return ""

static func to_display(id: int) -> String:
   return to_key(id).capitalize()

static func from_key(value: Variant) -> int:
   if value is int: return value if is_valid(value) else -1
   match str(value).to_lower():
      "air": return ID.AIR
      "fire": return ID.FIRE
      "water": return ID.WATER
      "earth": return ID.EARTH
   return -1

static func is_valid(id: int) -> bool: return id >= 0 and id < COUNT
static func all_ids() -> Array[int]: return [ID.AIR, ID.FIRE, ID.WATER, ID.EARTH]
```

```gdscript
// FILE: res://scripts/data/need_type.gd
class_name NeedType
extends RefCounted

enum ID { REST = 0, SOCIAL = 1, INSPIRATION = 2 }
const COUNT := 3

const STRATEGIES: Dictionary = {
   ID.REST: RestStrategy.new(),
   ID.SOCIAL: SocialStrategy.new(),
   ID.INSPIRATION: InspirationStrategy.new(),
}

static func to_name(id: int) -> StringName:
   match id:
      ID.REST: return &"rest"
      ID.SOCIAL: return &"social"
      ID.INSPIRATION: return &"inspiration"
   return &""

static func from_name(value: Variant) -> int:
   match str(value):
      "rest": return ID.REST
      "social": return ID.SOCIAL
      "inspiration": return ID.INSPIRATION
      "belief": return ID.INSPIRATION # Legacy migration
   return -1

static func is_valid(id: int) -> bool: return id >= 0 and id < COUNT
static func all_ids() -> Array[int]: return [ID.REST, ID.SOCIAL, ID.INSPIRATION]
static func all_names() -> Array[StringName]:
   var out: Array[StringName] = []
   for id in all_ids(): out.append(to_name(id))
   return out
```

```gdscript
// FILE: res://scripts/data/tool_type.gd
class_name ToolType
extends RefCounted

enum ID { SHOVEL = 0, PICKAXE = 1, CART = 2, SKIN_PROTECTION = 3, NET = 4 }
const COUNT := 5

static func to_name(id: int) -> StringName:
   match id:
      ID.SHOVEL: return &"shovel"
      ID.PICKAXE: return &"pickaxe"
      ID.CART: return &"cart"
      ID.SKIN_PROTECTION: return &"skin_protection"
      ID.NET: return &"net"
   return &""

static func from_name(value: Variant) -> int:
   match str(value):
      "shovel": return ID.SHOVEL
      "pickaxe": return ID.PICKAXE
      "cart": return ID.CART
      "skin_protection": return ID.SKIN_PROTECTION
      "net": return ID.NET
   return -1

static func is_valid(id: int) -> bool: return id >= 0 and id < COUNT
static func all_ids() -> Array[int]: return [ID.SHOVEL, ID.PICKAXE, ID.CART, ID.SKIN_PROTECTION, ID.NET]
static func all_names() -> Array[StringName]:
   var out: Array[StringName] = []
   for id in all_ids(): out.append(to_name(id))
   return out
```

---

## 📂 ЭТАП 2: Рефакторинг Бизнес-Логики (Int-ключи в Runtime)

```gdscript
// FILE: res://scripts/entities/hero_magic.gd
class_name HeroMagic
extends RefCounted

signal changed
var mana_current: int = 0
var mana_max: int = 0
var schools: Dictionary = {} # Ключи: SchoolType.ID (int)
var spellbook: Array[StringName] = []

func init_defaults() -> void:
   mana_max = 20; mana_current = 20
   schools = { SchoolType.ID.AIR: 1, SchoolType.ID.FIRE: 0, SchoolType.ID.WATER: 0, SchoolType.ID.EARTH: 0 }
   spellbook = [&"magic_arrow", &"haste"]
   changed.emit()

func school_level(school_id: int) -> int: return int(schools.get(school_id, 0))

func serialize_schools() -> Dictionary:
   var out := {}
   for id in schools: out[SchoolType.to_key(int(id))] = int(schools[id])
   return out

func deserialize_schools(data: Dictionary) -> void:
   schools.clear()
   for key in data:
      var id: int = SchoolType.from_key(key)
      if SchoolType.is_valid(id): schools[id] = int(data[key])
   for id in SchoolType.all_ids():
      if not schools.has(id): schools[id] = 0
```

```gdscript
// FILE: res://scripts/entities/hero_needs.gd
class_name HeroNeeds
extends RefCounted

var needs: Dictionary = {} # Ключи: NeedType.ID (int)
var zero_streak: Dictionary = {}

func _init() -> void: reset()

func tick(in_city: bool, city: City = null) -> StringName:
   for id in NeedType.all_ids():
      var strat: NeedStrategy = NeedType.STRATEGIES[id]
      var delta := -strat.decay_rate + strat.get_recovery_hero(in_city, city)
      needs[id] = clampf(float(needs.get(id, 1.0)) + delta, 0.0, 1.0)
      
   for id in NeedType.all_ids():
      if float(needs[id]) <= 0.0001:
         zero_streak[id] = int(zero_streak.get(id, 0)) + 1
      else:
         zero_streak[id] = 0
         
   for id in NeedType.all_ids():
      if int(zero_streak[id]) >= 3:
         return NeedType.STRATEGIES[id].get_death_cause()
   return &""

func is_critical(id: int) -> bool: return float(needs.get(id, 0.0)) < 0.2
func get_need(id: int) -> float: return float(needs.get(id, 0.0))

func reset() -> void:
   for id in NeedType.all_ids():
      needs[id] = 1.0
      zero_streak[id] = 0

func serialize() -> Dictionary:
   var out := {}
   for id in NeedType.all_ids(): out[String(NeedType.to_name(id))] = float(needs.get(id, 1.0))
   return out

func deserialize(d: Dictionary) -> void:
   for id in NeedType.all_ids():
      var key := String(NeedType.to_name(id))
      needs[id] = clampf(float(d.get(key, 1.0)), 0.0, 1.0)
      zero_streak[id] = 0
```

```gdscript
// FILE: res://scripts/demographics/demographic_turn_processor.gd (Фрагмент замены)
func _process_city(city: City, ctx: TurnContext) -> Dictionary:
   # ... (предыдущий код)
   for ch in registry.alive_in_city(city.uid).duplicate():
      var pop: PopUnit = _find_pop(city, ch.pop_uid)
      for need_id in NeedType.all_ids():
         var strat: NeedStrategy = NeedType.STRATEGIES[need_id]
         var delta := -strat.decay_rate
         delta += strat.get_recovery_pop(city, pop)
         delta += ch.trait_modifier(NeedType.to_name(need_id))
         ch.modify_need(need_id, delta)
   # ... (остальной код без изменений)
```

---

## 🎨 ЭТАП 3: Архитектура UI (Тема, Enum'ы, Иконки)

Глобальная тема и безопасные enum-обертки.

```gdscript
// FILE: res://scripts/ui/UITheme.gd
class_name UITheme
extends RefCounted

const THEME_PATH := "res://assets/theme/game_theme.tres"
const PALETTE_TYPE := &"Palette"
const SIZES_TYPE := &"FontSizes"
const BOX_TYPE := &"Panel"

enum ColorID {
   TEXT, TEXT_LIGHT, GOLD, GOLD_SOFT, GOLD_LIGHTER, VICTORY_GOLD,
   DANGER, DANGER_MUTED, WARNING, SUCCESS, INFO_BLUE, THREAT,
   TIME_DAY, TIME_NOON, TIME_EVENING, TIME_NIGHT,
   MARKER_GREEN, MARKER_YELLOW, MARKER_RED, BTN_HOVER, BTN_PRESSED
}
enum SizeID { FS_TINY, FS_SMALL, FS_BODY, FS_LABEL, FS_HEADING, FS_BIG, FS_TITLE, FS_HERO, FS_HUGE }
enum BoxID {
   PANEL, PANEL_DARK, PANEL_MID, SLOT, SLOT_DARK, ARMY_SLOT,
   ACTION_BUTTON, MENU_BUTTON, OUTLINE, PORTRAIT
}
enum ButtonState { NORMAL, HOVER, PRESSED, DISABLED, FOCUS }

static var _cache: Theme = null
static func theme() -> Theme:
   if _cache == null:
      _cache = load(THEME_PATH) as Theme
      if _cache == null: _cache = Theme.new()
   return _cache

static func _to_name(enum_class, id: int) -> StringName:
   if id < 0 or id >= enum_class.size(): return &""
   return StringName(enum_class.keys()[id].to_lower())

static func color(id: int, fallback: Color = Color.WHITE) -> Color:
   var n := _to_name(ColorID, id)
   var t := theme()
   return t.get_color(n, PALETTE_TYPE) if t.has_color(n, PALETTE_TYPE) else fallback

static func fsize(id: int, fallback: int = 14) -> int:
   var n := _to_name(SizeID, id)
   var t := theme()
   return t.get_constant(n, SIZES_TYPE) if t.has_constant(n, SIZES_TYPE) else fallback

static func box(id: int) -> StyleBox:
   var n := _to_name(BoxID, id)
   var t := theme()
   return t.get_stylebox(n, BOX_TYPE) if t.has_stylebox(n, BOX_TYPE) else null

static func style_control(ctrl: Control, box_id: int) -> void:
   if ctrl == null: return
   var sb := box(box_id)
   if sb != null: ctrl.add_theme_stylebox_override("panel", sb)

static func tint(ctrl: Control, color_id: int) -> void:
   if ctrl == null: return
   ctrl.add_theme_color_override("font_color", color(color_id))

static func font(ctrl: Control, size_id: int) -> void:
   if ctrl == null: return
   ctrl.add_theme_font_size_override("font_size", fsize(size_id))

static func button_box(state: int) -> StyleBox:
   var n := StringName(ButtonState.keys()[state].to_lower())
   return theme().get_stylebox(n, &"Button")
```

```gdscript
// FILE: res://scripts/ui/ThemeIcons.gd
class_name ThemeIcons
extends RefCounted

enum IconID {
   WOOD, MERCURY, ORE, SULFUR, CRYSTAL, GEMS, GOLD, TREE, STONE,
   REST, SOCIAL, INSPIRATION, ATTACK, DEFENSE, KNOWLEDGE, SPELL_POWER, HP, MANA, MOVEMENT,
   WORKER, MILITIA, FOLLOWER, SCHOLAR, PATROL, HERO, POPULATION,
   FARM, MILL, BAKERY, MINE, SMITHY, TAVERN, MARKET, SHACK, WALLS,
   FOOD, INDUSTRY, DUST, SCIENCE, INFLUENCE, CLOCK, CROWN, STAR, PROSPERITY,
   CASTLE, FLAG, CAMP, STABLE, SHIP, FORGE, SCOUT, ARMY, JOURNAL, END_TURN, OPTIONS,
   RETREAT, WAIT, SPELLBOOK, TURN_NEXT, AUTO_PLAY, HIRE, LEVEL_UP, RESET, HOME, CLOSE,
   FLAG_CAPTURED, TAKE, SHOVEL, PICKAXE, CART, SKIN_PROTECTION, NET,
   VICTORY, DEFEAT, SUCCESSION, OBSTACLE_ROCK, OBSTACLE_TREE, MARK_EXHAUSTED, MARK_PICK,
   COST_INDUSTRY, COST_GOLD, ARENA, MODEL_WARRIOR, MODEL_MAGE, CHRONICLE
}

const _GLYPHS: Dictionary = {
   IconID.WOOD: "🪵", IconID.MERCURY: "🧪", IconID.ORE: "🪨", IconID.SULFUR: "🟡", 
   IconID.CRYSTAL: "🔷", IconID.GEMS: "💎", IconID.GOLD: "🪙", IconID.TREE: "🌲", IconID.STONE: "🪨",
   IconID.REST: "😴", IconID.SOCIAL: "🤝", IconID.INSPIRATION: "💡",
   IconID.ATTACK: "⚔️", IconID.DEFENSE: "🛡️", IconID.KNOWLEDGE: "📖", IconID.SPELL_POWER: "🧪", 
   IconID.HP: "❤️", IconID.MANA: "✨", IconID.MOVEMENT: "🚶",
   IconID.WORKER: "⚙", IconID.MILITIA: "🛡", IconID.FOLLOWER: "👤", IconID.SCHOLAR: "🎓", 
   IconID.PATROL: "🐎", IconID.HERO: "🧙", IconID.POPULATION: "👥",
   IconID.FARM: "🌾", IconID.MILL: "🌀", IconID.BAKERY: "🍞", IconID.MINE: "⛏", 
   IconID.SMITHY: "⚒", IconID.TAVERN: "🍺", IconID.MARKET: "🏪", IconID.SHACK: "🛖", IconID.WALLS: "🧱",
   IconID.FOOD: "🌾", IconID.INDUSTRY: "🏭", IconID.DUST: "🌫", IconID.SCIENCE: "🔬", IconID.INFLUENCE: "🕊",
   IconID.CLOCK: "🕐", IconID.CROWN: "👑", IconID.STAR: "★", IconID.PROSPERITY: "⭐",
   IconID.CASTLE: "🏰", IconID.FLAG: "🚩", IconID.CAMP: "⛺", IconID.STABLE: "🐎", 
   IconID.SHIP: "🚢", IconID.FORGE: "⚒️", IconID.SCOUT: "🔍", IconID.ARMY: "🪖", 
   IconID.JOURNAL: "📜", IconID.END_TURN: "⏳", IconID.OPTIONS: "⚙️",
   IconID.RETREAT: "🏕️", IconID.WAIT: "🏃", IconID.SPELLBOOK: "📖", IconID.TURN_NEXT: "⏭", 
   IconID.AUTO_PLAY: "▶", IconID.HIRE: "🧑🌾", IconID.LEVEL_UP: "🏛", IconID.RESET: "↺", 
   IconID.HOME: "⌂", IconID.CLOSE: "✕", IconID.FLAG_CAPTURED: "🏳️", IconID.TAKE: "✋",
   IconID.SHOVEL: "🔧", IconID.PICKAXE: "⛏️", IconID.CART: "🛒", IconID.SKIN_PROTECTION: "🛡️", IconID.NET: "🥅",
   IconID.VICTORY: "👑", IconID.DEFEAT: "💀", IconID.SUCCESSION: "🔁",
   IconID.OBSTACLE_ROCK: "🪨", IconID.OBSTACLE_TREE: "🌳", IconID.MARK_EXHAUSTED: "✗", IconID.MARK_PICK: "⛏️",
   IconID.COST_INDUSTRY: "⚙", IconID.COST_GOLD: "💰",
   IconID.ARENA: "🏙", IconID.MODEL_WARRIOR: "🗡", IconID.MODEL_MAGE: "✨", IconID.CHRONICLE: "📜",
}

static func icon(id: int) -> String: return str(_GLYPHS.get(id, ""))
static func label(id: int, text: String) -> String:
   var g := icon(id)
   return (g + " " + text) if g != "" else text

static func apply(control: Control, id: int, text: String = "") -> void:
   if control == null or not ("text" in control): return
   control.set("text", label(id, text) if text != "" else icon(id))

static func classic_resource_icon(res_type: int) -> String:
   var ids := [IconID.WOOD, IconID.MERCURY, IconID.ORE, IconID.SULFUR, IconID.CRYSTAL, IconID.GEMS, IconID.GOLD]
   return icon(ids[res_type]) if res_type >= 0 and res_type < ids.size() else ""
   
static func need_icon(need_id: StringName) -> String:
   match need_id:
      &"rest": return icon(IconID.REST)
      &"social": return icon(IconID.SOCIAL)
      &"inspiration": return icon(IconID.INSPIRATION)
   return ""
```

---

## 🖥 ЭТАП 4: Чистка UI-Скриптов и Сцен

### 1. Обновление UI-Панелей
```gdscript
// FILE: res://scripts/ui/resource_bar.gd
class_name ResourceBar
extends HBoxContainer

var _labels: Dictionary = {}

func _ready() -> void:
   for id in ResourceType.classic_ids():
      var l := get_node(ResourceType.to_key(id).capitalize()) as Label
      UITheme.font(l, UITheme.SizeID.FS_SMALL)
      UITheme.tint(l, UITheme.ColorID.TEXT)
      _labels[id] = l

func update_resources(resources: Dictionary) -> void:
   for id in _labels:
      _labels[id].text = "%s%d" % [ThemeIcons.classic_resource_icon(int(id)), int(resources.get(id, 0))]
```

```gdscript
// FILE: res://scripts/ui/hero_status_panel.gd (Фрагмент)
func _needs_text(n: HeroNeeds) -> String:
   var parts: Array[String] = []
   for id in NeedType.all_ids():
      var k := NeedType.to_name(id)
      var mark := "⚠️" if n.is_critical(id) else ""
      parts.append("%s%s %.0f%%" % [ThemeIcons.need_icon(k), mark, n.get_need(id) * 100.0])
   return "\n".join(parts)
```

### 2. Обновление Темы `.tres`
Убедитесь, что в `res://assets/theme/game_theme.tres` добавлены недостающие цвета для enum-маппинга:
```ini
Palette/colors/btn_hover = Color(0.2, 0.45, 0.9, 1)
Palette/colors/btn_pressed = Color(0.1, 0.25, 0.6, 1)
Palette/colors/threat = Color(0.95, 0.25, 0.2, 0.85)
```

### 3. Очистка `.tscn` (КРИТИЧНО)
Агент должен открыть следующие `.tscn` файлы и **удалить все эмодзи** из поля `text` у `Button` и `Label` (сделать их пустыми `""`). Эмодзи будут применены в `_ready()` через `ThemeIcons.apply()`.
- `scenes/ui/InfoPanel.tscn` (кнопки действий)
- `scenes/ui/BattleUI.tscn` (нижние кнопки)
- `scenes/MainMenu.tscn`
- `scenes/CityArena.tscn`
- `scenes/ui/CityScreen.tscn`
- `scenes/ui/ResourcesPanel.tscn`, `SkillsPanel.tscn`, `ToolsPanel.tscn`, `HeroStatusPanel.tscn`

Пример кода, который добавляется в `_ready()` соответствующих скриптов (например, `InfoPanel.gd`):
```gdscript
func _apply_action_icons() -> void:
   ThemeIcons.apply(get_node_or_null("actions/CastleButton"), ThemeIcons.IconID.CASTLE)
   ThemeIcons.apply(get_node_or_null("actions/EndTurnButton"), ThemeIcons.IconID.END_TURN)
   # ... и так далее для всех кнопок
```

---

## 📋 ИТОГОВЫЙ ЧЕК-ЛИСТ ДЛЯ АГЕНТА (Порядок выполнения)

1. [ ] **Создать папку и файлы стратегий**: `scripts/data/needs/` (`NeedStrategy`, `RestStrategy`, `SocialStrategy`, `InspirationStrategy`).
2. [ ] **Создать Enum'ы**: `SchoolType.gd`, `NeedType.gd`, `ToolType.gd` (включая словарь `STRATEGIES`).
3. [ ] **Обновить Data-Layer**: `HeroMagic.gd`, `HeroNeeds.gd`, `HeroTools.gd`, `Character.gd` (перевод словарей на `int` ключи в памяти, сериализация в `String`).
4. [ ] **Обновить Процессоры**: `DemographicTurnProcessor.gd` (замена `match` на вызов `NeedType.STRATEGIES[id]`).
5. [ ] **Создать UI-Фасады**: `UITheme.gd` и `ThemeIcons.gd`.
6. [ ] **Дополнить `game_theme.tres`** новыми цветами из палитры.
7. [ ] **Очистить `.tscn` сцены** от хардкода эмодзи.
8. [ ] **Переписать UI-скрипты** (`ResourceBar`, `InfoPanel`, `HeroStatusPanel`, `ArmyPanel`, `MainMenu` и др.), заменив локальные константы цветов/иконок на вызовы `UITheme.color(UITheme.ColorID.X)` и `ThemeIcons.apply(node, ThemeIcons.IconID.Y)`.
9. [ ] **Запустить билд**: Проверить отсутствие крашей при загрузке сейвов (сработает миграция `from_key` / `from_name`) и корректное отображение UI в редакторе и рантайме.