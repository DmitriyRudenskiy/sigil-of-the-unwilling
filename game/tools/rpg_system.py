"""
RPG System Module
Реализация механик: Интеллект/Обман, Харизма/Население, Прогрессия Оружия,
Расcы, Здания, Развитие поселения.
"""

import random
from enum import Enum
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any, Tuple
from datetime import datetime

# ==========================================
# 1. КОНСТАНТЫ И ПЕРЕЧИСЛЕНИЯ
# ==========================================

class MaterialTier(Enum):
    WOOD = 1
    STONE = 2
    IRON = 3
    STEEL = 4
    RARE = 5

class WeaponType(Enum):
    BLUNT = "Дробящее"
    SHARP = "Рубяще-режущее"
    PIERCING = "Колющее"
    RANGED = "Дальнобойное"
    SHIELD = "Защита"

@dataclass
class MaterialStats:
    damage_mult: float
    durability_mult: float
    weight_mult: float
    complexity: int
    description: str

MATERIAL_STATS = {
    MaterialTier.WOOD: MaterialStats(0.5, 0.4, 0.8, 1, "Стартовый этап. Легкое, но хрупкое."),
    MaterialTier.STONE: MaterialStats(0.8, 0.7, 1.2, 2, "Тяжелое, ломается при сильных ударах."),
    MaterialTier.IRON: MaterialStats(1.2, 1.5, 1.5, 3, "Основной боевой этап. Требует кузницы."),
    MaterialTier.STEEL: MaterialStats(1.5, 2.0, 1.3, 4, "Элитный металл. Высокая прочность."),
    MaterialTier.RARE: MaterialStats(2.5, 3.0, 1.0, 5, "Магические свойства. Уникальные эффекты."),
}

# ==========================================
# 2. СИСТЕМА ХАРАКТЕРИСТИК И ОБМАНА (Разделы 1-2)
# ==========================================

@dataclass
class CharacterStats:
    intelligence: int = 10
    wisdom: int = 10
    charisma: int = 10
    luck: int = 10
    reputation: int = 0

    def get_cheat_chance(self, base_chance: float = 10.0) -> float:
        """
        Расчет шанса обмана (Вариант 1: процентная система).
        Формула: База + (10 - Интеллект) * 4% - Компенсация * 2%
        Компенсация = max(Мудрость-10, Харизма-10, Удача-10)
        Минимум 5%, Максимум 85%.
        """
        int_penalty = (10 - self.intelligence) * 4.0
        
        # Расчет компенсации
        comp_wis = max(0, self.wisdom - 10)
        comp_cha = max(0, self.charisma - 10)
        comp_luck = max(0, self.luck - 10)
        compensation = max(comp_wis, comp_cha, comp_luck)
        
        chance = base_chance + int_penalty - (compensation * 2.0)
        
        return max(5.0, min(85.0, chance))

    def check_deception_roll(self, difficulty: int) -> tuple[bool, int]:
        """
        Проверка распознания обмана (Вариант 2: бросок d20).
        Возвращает (Успех, Значение броска).
        """
        comp_wis = max(0, self.wisdom - 10)
        comp_cha = max(0, self.charisma - 10)
        comp_luck = max(0, self.luck - 10)
        compensation = max(comp_wis, comp_cha, comp_luck)
        
        roll = random.randint(1, 20)
        total = roll + self.intelligence + compensation
        
        success = total >= difficulty
        margin = total - difficulty
        
        return success, margin

# ==========================================
# 3. НАСЕЛЕНИЕ И ОТРЯД (Раздел 3)
# ==========================================

@dataclass
class Settlement:
    population: int = 10
    max_squad_size: int = 3
    growth_rate: float = 1.0
    
    def update_demographics(self, charisma: int):
        """
        Обновление параметров поселения на основе харизмы лидера.
        """
        # Таблица влияния харизмы
        if charisma <= 3:
            modifier = -0.50
            self.max_squad_size = 1
            status = "Страх и отторжение"
        elif charisma <= 5:
            modifier = -0.35
            self.max_squad_size = 2
            status = "Недоверие"
        elif charisma <= 7:
            modifier = -0.20
            self.max_squad_size = 2
            status = "Осторожность"
        elif charisma <= 9:
            modifier = -0.05
            self.max_squad_size = 3
            status = "Нейтрально"
        elif charisma == 10:
            modifier = 0.0
            self.max_squad_size = 3
            status = "Норма"
        elif charisma <= 13:
            modifier = 0.10
            self.max_squad_size = 4
            status = "Симпатия"
        elif charisma <= 16:
            modifier = 0.20
            self.max_squad_size = 5
            status = "Доверие"
        elif charisma <= 18:
            modifier = 0.35
            self.max_squad_size = 6
            status = "Лидерство"
        else:
            modifier = 0.50
            self.max_squad_size = 7
            status = "Легендарный лидер"
            
        self.growth_rate = 1.0 + modifier
        return status

    def recruit_attempt(self, recruiter_stats: CharacterStats, recruit_type: str) -> bool:
        """
        Попытка найма в отряд.
        """
        difficulties = {
            "beggar": 8,
            "commoner": 10,
            "hunter": 12,
            "warrior": 14,
            "veteran": 16,
            "elite": 18,
            "hero": 20
        }
        
        diff = difficulties.get(recruit_type, 10)
        
        # Бонусы условий (упрощено)
        conditions_bonus = 0 
        # В реальной игре здесь проверялись бы ресурсы (еда, золото)
        
        roll = random.randint(1, 20)
        total = roll + recruiter_stats.charisma + (recruiter_stats.reputation // 5) + conditions_bonus
        
        return total >= diff

# ==========================================
# 4. ПРОГРЕССИЯ ОРУЖИЯ (Разделы 4-8)
# ==========================================

@dataclass
class WeaponBlueprint:
    name: str
    tier: MaterialTier
    w_type: WeaponType
    requirements: Dict[str, int] # {"wood": 5, "stone": 2}

WEAPON_TREE = [
    # Этап 1: Дерево
    WeaponBlueprint("Деревянная дубина", MaterialTier.WOOD, WeaponType.BLUNT, {"wood": 5}),
    WeaponBlueprint("Заостренная палка", MaterialTier.WOOD, WeaponType.PIERCING, {"wood": 3}),
    WeaponBlueprint("Простой лук", MaterialTier.WOOD, WeaponType.RANGED, {"wood": 6, "vine": 2}),
    
    # Этап 2: Камень
    WeaponBlueprint("Каменный топор", MaterialTier.STONE, WeaponType.SHARP, {"wood": 4, "stone": 5, "vine": 2}),
    WeaponBlueprint("Копье с каменным наконечником", MaterialTier.STONE, WeaponType.PIERCING, {"wood": 6, "stone": 3}),
    WeaponBlueprint("Праща", MaterialTier.STONE, WeaponType.RANGED, {"vine": 5, "stone": 1}),
    
    # Этап 3: Железо
    WeaponBlueprint("Железный меч", MaterialTier.IRON, WeaponType.SHARP, {"iron_ore": 10, "coal": 5, "wood": 2}),
    WeaponBlueprint("Железное копье", MaterialTier.IRON, WeaponType.PIERCING, {"iron_ore": 6, "coal": 3, "wood": 4}),
    
    # Этап 4: Сталь
    WeaponBlueprint("Стальной меч", MaterialTier.STEEL, WeaponType.SHARP, {"steel_ingot": 8, "coal": 10}),
    WeaponBlueprint("Арбалет", MaterialTier.STEEL, WeaponType.RANGED, {"steel_ingot": 5, "wood": 10, "vine": 5}),
    
    # Этап 5: Редкие
    WeaponBlueprint("Рунный клинок", MaterialTier.RARE, WeaponType.SHARP, {"steel_ingot": 10, "magic_crystal": 3}),
]

class CraftingSystem:
    def __init__(self):
        self.unlocked_tiers = [MaterialTier.WOOD]
        self.inventory: Dict[str, int] = {}
        self.known_blueprints: List[WeaponBlueprint] = [
            bp for bp in WEAPON_TREE if bp.tier == MaterialTier.WOOD
        ]

    def has_resources(self, requirements: Dict[str, int]) -> bool:
        for res, amount in requirements.items():
            if self.inventory.get(res, 0) < amount:
                return False
        return True

    def craft_weapon(self, blueprint: WeaponBlueprint) -> Optional['Weapon']:
        if blueprint.tier not in self.unlocked_tiers:
            raise ValueError(f"Технология {blueprint.tier.name} еще не открыта!")
        
        if not self.has_resources(blueprint.requirements):
            return None
            
        # Списание ресурсов
        for res, amount in blueprint.requirements.items():
            self.inventory[res] -= amount
            
        stats = MATERIAL_STATS[blueprint.tier]
        return Weapon(
            name=blueprint.name,
            tier=blueprint.tier,
            w_type=blueprint.w_type,
            damage=int(10 * stats.damage_mult),
            durability=int(100 * stats.durability_mult),
            weight=stats.weight_mult
        )

    def unlock_tier(self, new_tier: MaterialTier):
        if new_tier.value == max([t.value for t in self.unlocked_tiers]) + 1:
            self.unlocked_tiers.append(new_tier)
            # Добавляем чертежи нового уровня
            new_bps = [bp for bp in WEAPON_TREE if bp.tier == new_tier]
            self.known_blueprints.extend(new_bps)
            return True
        return False

@dataclass
class Weapon:
    name: str
    tier: MaterialTier
    w_type: WeaponType
    damage: int
    durability: int
    weight: float
    current_durability: int = field(init=False)
    
    def __post_init__(self):
        self.current_durability = self.durability

    def take_damage(self, amount: int):
        self.current_durability -= amount
        if self.current_durability <= 0:
            return "Оружие сломано!"
        return f"Прочность: {self.current_durability}/{self.durability}"

# ==========================================
# 5. СИСТЕМА РАС (SPECIES) - Новое из ТЗ
# ==========================================

class SpeciesType(Enum):
    HUMAN = "Люди"
    BEAVER = "Бобры"
    LIZARD = "Ящерицы"
    HARPY = "Гарпии"
    FOX = "Лисы"
    FROG = "Лягушки"
    BAT = "Летучие мыши"

@dataclass
class SpeciesStats:
    base_resolve: int  # Базовое настроение
    demand_threshold: int  # Порог требований
    decadence_rate: int  # Склонность к декадансу
    hunger_tolerance: int  # Устойчивость к голоду
    break_interval_minutes: int  # Перерыв каждые X минут
    food_preference: str  # Предпочтения в еде
    clothing_preference: str  # Предпочтения в одежде
    housing_preference: str  # Предпочтения в жилье
    specialization_bonus: str  # Бонус специализации
    
SPECIES_DATA = {
    SpeciesType.HUMAN: SpeciesStats(
        base_resolve=15, demand_threshold=30, decadence_rate=4,
        hunger_tolerance=6, break_interval_minutes=120,
        food_preference="Сложная еда", clothing_preference="Плащи",
        housing_preference="Дом людей", specialization_bonus="Адаптивность"
    ),
    SpeciesType.BEAVER: SpeciesStats(
        base_resolve=10, demand_threshold=30, decadence_rate=2,
        hunger_tolerance=6, break_interval_minutes=120,
        food_preference="Эль", clothing_preference="Рабочая одежда",
        housing_preference="Дом бобров", specialization_bonus="Трудолюбие"
    ),
    SpeciesType.LIZARD: SpeciesStats(
        base_resolve=5, demand_threshold=15, decadence_rate=7,
        hunger_tolerance=12, break_interval_minutes=100,
        food_preference="Насекомые", clothing_preference="Легкая броня",
        housing_preference="Дом ящериц", specialization_bonus="Выносливость"
    ),
    SpeciesType.HARPY: SpeciesStats(
        base_resolve=5, demand_threshold=15, decadence_rate=3,
        hunger_tolerance=4, break_interval_minutes=100,
        food_preference="Фрукты", clothing_preference="Перья",
        housing_preference="Дом гарпий", specialization_bonus="Скорость"
    ),
    SpeciesType.FOX: SpeciesStats(
        base_resolve=5, demand_threshold=15, decadence_rate=5,
        hunger_tolerance=3, break_interval_minutes=120,
        food_preference="Мясо", clothing_preference="Меха",
        housing_preference="Дом лис", specialization_bonus="Хитрость"
    ),
    SpeciesType.FROG: SpeciesStats(
        base_resolve=10, demand_threshold=25, decadence_rate=5,
        hunger_tolerance=8, break_interval_minutes=150,
        food_preference="Рыба", clothing_preference="Водонепроницаемое",
        housing_preference="Дом лягушек", specialization_bonus="Архитектура"
    ),
    SpeciesType.BAT: SpeciesStats(
        base_resolve=8, demand_threshold=20, decadence_rate=4,
        hunger_tolerance=7, break_interval_minutes=110,
        food_preference="Фрукты", clothing_preference="Темная одежда",
        housing_preference="Дом летучих мышей", specialization_bonus="Ночное зрение"
    ),
}

@dataclass
class Settler:
    species: SpeciesType
    resolve: int  # Текущее настроение
    hunger: int = 0
    needs_satisfied: Dict[str, bool] = field(default_factory=dict)
    assigned_building: Optional[str] = None
    
    def __post_init__(self):
        stats = SPECIES_DATA[self.species]
        self.resolve = stats.base_resolve
    
    def update_resolve(self, food_satisfied: bool, clothing_satisfied: bool, 
                       housing_satisfied: bool, comfort_bonus: int = 0):
        """Обновление настроения на основе удовлетворённых потребностей."""
        stats = SPECIES_DATA[self.species]
        
        if food_satisfied:
            self.resolve += 5
        else:
            if self.hunger >= stats.hunger_tolerance:
                self.resolve -= 10
        
        if clothing_satisfied:
            self.resolve += 3
        if housing_satisfied:
            self.resolve += 5
            
        self.resolve += comfort_bonus
        
        # Ограничение по макс. настроению
        max_resolve = stats.demand_threshold
        self.resolve = min(self.resolve, max_resolve)
        
        # Декаданс: снижение порога после получения репутации
        # (упрощённая реализация)
        
        return self.resolve

# ==========================================
# 6. СИСТЕМА ЗДАНИЙ (BUILDINGS) - Новое из ТЗ
# ==========================================

class BuildingType(Enum):
    STARTER = "Стартовое"
    CAMP = "Лагерь"
    PRODUCTION = "Производство"
    HOUSING = "Жилое"
    SERVICE = "Услуга"
    STORAGE = "Склад"

@dataclass
class BuildingBlueprint:
    name: str
    b_type: BuildingType
    cost: Dict[str, int]
    capacity: int  # Вместимость (для жилых) или рабочих мест
    unlock_level: int = 1  # Уровень разблокировки
    species_only: Optional[SpeciesType] = None  # Только для определённой расы
    produces: Optional[List[str]] = None  # Что производит
    radius_effect: int = 0  # Радиус эффекта (для очагов)

BUILDING_TREE = [
    # Стартовые здания
    BuildingBlueprint("Древний очаг", BuildingType.STARTER, {}, 0, 1, None, [], 5),
    BuildingBlueprint("Главный склад", BuildingType.STORAGE, {"wood": 10}, 100, 1, None, [], 0),
    
    # Лагеря
    BuildingBlueprint("Лагерь лесорубов", BuildingType.CAMP, {"wood": 5}, 3, 1, None, ["wood"], 0),
    BuildingBlueprint("Лагерь каменотесов", BuildingType.CAMP, {"wood": 5, "stone": 2}, 3, 1, None, ["stone"], 0),
    BuildingBlueprint("Лагерь сборщиков", BuildingType.CAMP, {"wood": 5}, 3, 1, None, ["raw_food"], 0),
    BuildingBlueprint("Малый лагерь собирателей", BuildingType.CAMP, {"wood": 3}, 2, 1, None, ["herbs"], 0),
    BuildingBlueprint("Малый лагерь травников", BuildingType.CAMP, {"wood": 4, "stone": 1}, 2, 2, None, ["rare_herbs"], 0),
    
    # Производства
    BuildingBlueprint("Лесопилка", BuildingType.PRODUCTION, {"wood": 15, "stone": 5}, 4, 2, None, ["planks"], 0),
    BuildingBlueprint("Пекарня", BuildingType.PRODUCTION, {"wood": 10, "stone": 8}, 3, 3, None, ["complex_food"], 0),
    BuildingBlueprint("Бондарня", BuildingType.PRODUCTION, {"wood": 12, "planks": 5}, 3, 4, SpeciesType.HARPY, ["barrels", "coats", "tea"], 0),
    BuildingBlueprint("Красильня", BuildingType.PRODUCTION, {"wood": 10, "stone": 5, "herbs": 10}, 3, 4, SpeciesType.BEAVER, ["ale", "wine", "pigment"], 0),
    
    # Жилые здания (базовые)
    BuildingBlueprint("Убежище", BuildingType.HOUSING, {"wood": 8}, 3, 1, None, [], 0),
    BuildingBlueprint("Большое убежище", BuildingType.HOUSING, {"wood": 15, "planks": 5}, 3, 5, None, [], 0),
    
    # Видовые дома
    BuildingBlueprint("Дом людей", BuildingType.HOUSING, {"planks": 4, "brick": 2}, 2, 6, SpeciesType.HUMAN, [], 0),
    BuildingBlueprint("Дом бобров", BuildingType.HOUSING, {"planks": 8}, 2, 7, SpeciesType.BEAVER, [], 0),
    BuildingBlueprint("Дом ящериц", BuildingType.HOUSING, {"cloth": 2, "brick": 2}, 2, 8, SpeciesType.LIZARD, [], 0),
    BuildingBlueprint("Дом гарпий", BuildingType.HOUSING, {"cloth": 4}, 2, 9, SpeciesType.HARPY, [], 0),
    BuildingBlueprint("Дом лис", BuildingType.HOUSING, {"planks": 6, "cloth": 3}, 2, 10, SpeciesType.FOX, [], 0),
    BuildingBlueprint("Дом лягушек", BuildingType.HOUSING, {"brick": 8, "stone": 5}, 2, 9, SpeciesType.FROG, [], 0),
    BuildingBlueprint("Дом летучих мышей", BuildingType.HOUSING, {"stone": 10, "cloth": 2}, 2, 11, SpeciesType.BAT, [], 0),
    
    # Услуги
    BuildingBlueprint("Таверна", BuildingType.SERVICE, {"wood": 20, "planks": 10}, 5, 5, None, ["ale"], 0),
]

@dataclass
class Building:
    blueprint: BuildingBlueprint
    current_workers: int = 0
    selected_recipe: Optional[str] = None
    upgrades: List[str] = field(default_factory=list)
    rainwater_bonus: bool = False  # Бонус от дождевой воды
    
    def assign_worker(self, settler: Settler) -> bool:
        if self.current_workers < self.blueprint.capacity:
            self.current_workers += 1
            settler.assigned_building = self.blueprint.name
            return True
        return False
    
    def remove_worker(self, settler: Settler):
        if self.current_workers > 0:
            self.current_workers -= 1
            settler.assigned_building = None
    
    def apply_rainwater(self):
        """Применить бонус дождевой воды."""
        self.rainwater_bonus = True
        # +скорость, +шанс двойного производства, +настроение работников

# ==========================================
# 7. РАЗВИТИЕ ПОСЕЛЕНИЯ - Новое из ТЗ
# ==========================================

@dataclass
class CitadelProgress:
    level: int = 1
    prestige_level: int = 0
    reputation: int = 0
    hostility: int = 0  # Враждебность леса
    unlocked_buildings: List[str] = field(default_factory=list)
    permanent_upgrades: List[str] = field(default_factory=list)
    
    PRESTIGE_MODIFIERS = {
        1: {"reputation_needed": 4, "orders_harder": True},
        2: {"storm_longer": True},
        5: {"desertion_double": True},
        6: {"building_cost_mult": 1.5},
        7: {"food_consumption_chance": 0.5},
        8: {"luxury_consumption_chance": 0.5},
        9: {"clearance_speed": -0.33},
        10: {"trade_prices": -0.5},
    }
    
    def add_reputation(self, amount: int):
        self.reputation += amount
        
    def increase_hostility(self, reason: str, amount: int):
        reasons = {
            "new_year": 5,
            "new_settler": 1,
            "cleared_glade": 3,
            "lumberjack_working": 2,
        }
        actual_amount = reasons.get(reason, amount)
        self.hostility += actual_amount
        
    def reduce_hostility(self, small_hearths: int):
        """Малые очаги снижают враждебность."""
        self.hostility = max(0, self.hostility - small_hearths)
    
    def check_prestige_modifier(self, modifier_name: str) -> Any:
        """Проверить модификатор текущего уровня престижа."""
        if self.prestige_level in self.PRESTIGE_MODIFIERS:
            return self.PRESTIGE_MODIFIERS[self.prestige_level].get(modifier_name)
        return None

@dataclass  
class HearthLevel:
    level: int
    bonus_description: str
    
HEARTH_LEVELS = {
    1: "+1 к Настроению для всех",
    2: "+10% к скорости производства",
    3: "+10% шанс на двойное производство",
}

# ==========================================
# 8. ТОВАРЫ И РЕСУРСЫ - Новое из ТЗ
# ==========================================

class ResourceType(Enum):
    FOOD_RAW = "Сырая еда"
    FOOD_COMPLEX = "Сложная еда"
    BUILDING_MATERIAL = "Стройматериалы"
    CLOTHING = "Одежда"
    SERVICE_GOODS = "Товары для услуг"
    FUEL = "Топливо"
    TOOLS = "Инструменты"
    TRADE = "Торговые товары"

@dataclass
class Resource:
    name: str
    r_type: ResourceType
    nutrition: int = 0  # Питательность (для еды)
    resolve_bonus: int = 0  # Бонус к настроению
    stack_size: int = 50

RESOURCE_TYPES = [
    Resource("Сырое мясо", ResourceType.FOOD_RAW, nutrition=5),
    Resource("Вяленое мясо", ResourceType.FOOD_COMPLEX, nutrition=8, resolve_bonus=2),
    Resource("Шашлык", ResourceType.FOOD_COMPLEX, nutrition=10, resolve_bonus=3),
    Resource("Печенье", ResourceType.FOOD_COMPLEX, nutrition=6, resolve_bonus=2),
    Resource("Доски", ResourceType.BUILDING_MATERIAL),
    Resource("Кирпичи", ResourceType.BUILDING_MATERIAL),
    Resource("Ткань", ResourceType.BUILDING_MATERIAL),
    Resource("Плащ", ResourceType.CLOTHING, resolve_bonus=5),
    Resource("Ботинки", ResourceType.CLOTHING, resolve_bonus=5),
    Resource("Эль", ResourceType.SERVICE_GOODS, resolve_bonus=4),
    Resource("Благовония", ResourceType.SERVICE_GOODS, resolve_bonus=3),
    Resource("Дрова", ResourceType.FUEL),
    Resource("Уголь", ResourceType.FUEL),
    Resource("Инструменты", ResourceType.TOOLS),
    Resource("Янтарь", ResourceType.TRADE),  # Валюта
    Resource("Древние таблички", ResourceType.TRADE),  # Ресурс Цитадели
]

# ==========================================
# 9. ПОЛНАЯ СИМУЛЯЦИЯ ПОСЕЛЕНИЯ
# ==========================================

def run_full_simulation():
    print("=" * 60)
    print("=== ЗАПУСК ПОЛНОЙ СИМУЛЯЦИИ RPG SYSTEM ===")
    print("=" * 60 + "\n")
    
    # 1. Создание персонажа
    print("--- 1. СОЗДАНИЕ ПЕРСОНАЖА ---")
    hero = CharacterStats(intelligence=5, wisdom=14, charisma=8, luck=10)
    print(f"Герой: Инт={hero.intelligence}, Муд={hero.wisdom}, Хар={hero.charisma}")
    
    risk = hero.get_cheat_chance(10.0)
    print(f"Риск обмана в городе: {risk:.1f}% (Мудрость компенсировала низкий Интеллект)\n")
    
    # 2. Поселение
    print("--- 2. НАСЕЛЕНИЕ И ОТРЯД ---")
    settlement = Settlement()
    status = settlement.update_demographics(hero.charisma)
    print(f"Отношение людей: {status}")
    print(f"Макс. размер отряда: {settlement.max_squad_size}")
    print(f"Прирост населения: {settlement.growth_rate:.2f}x\n")
    
    # 3. Расы
    print("--- 3. ВЫБОР РАСЫ ДЛЯ КАРАВАНА ---")
    chosen_species = [SpeciesType.HUMAN, SpeciesType.BEAVER, SpeciesType.LIZARD]
    print(f"Выбраны виды: {[s.value for s in chosen_species]}")
    
    settlers = []
    for sp in chosen_species:
        stats = SPECIES_DATA[sp]
        print(f"  {sp.value}: Настроение={stats.base_resolve}, Голод={stats.hunger_tolerance}, Перерыв={stats.break_interval_minutes}мин")
        settlers.append(Settler(species=sp, resolve=stats.base_resolve))
    print()
    
    # 4. Здания
    print("--- 4. СТРОИТЕЛЬСТВО ЗДАНИЙ ---")
    buildings = []
    
    # Стартовые
    hearth = Building(BUILDING_TREE[0])  # Древний очаг
    warehouse = Building(BUILDING_TREE[1])  # Главный склад
    buildings.extend([hearth, warehouse])
    print(f"Построено: {hearth.blueprint.name}, {warehouse.blueprint.name}")
    
    # Лагеря
    lumber_camp = Building(BUILDING_TREE[2])  # Лагерь лесорубов
    buildings.append(lumber_camp)
    print(f"Построено: {lumber_camp.blueprint.name}")
    
    # Жилое
    shelter = Building(BUILDING_TREE[10])  # Убежище
    buildings.append(shelter)
    print(f"Построено: {shelter.blueprint.name} (вместимость: {shelter.blueprint.capacity})\n")
    
    # 5. Крафт оружия
    print("--- 5. ПРОГРЕССИЯ ОРУЖИЯ ---")
    workshop = CraftingSystem()
    workshop.inventory = {"wood": 20, "vine": 5, "stone": 10}
    
    club_bp = next(bp for bp in workshop.known_blueprints if bp.name == "Деревянная дубина")
    club = workshop.craft_weapon(club_bp)
    print(f"Этап 1 (Дерево): {club.name} - Урон: {club.damage}, Прочность: {club.durability}")
    
    workshop.unlock_tier(MaterialTier.STONE)
    axe_bp = next(bp for bp in workshop.known_blueprints if bp.name == "Каменный топор")
    workshop.inventory["wood"] = 10  # Добавим ещё дерева
    axe = workshop.craft_weapon(axe_bp)
    if axe:
        print(f"Этап 2 (Камень): {axe.name} - Урон: {axe.damage}, Прочность: {axe.durability}")
    
    print("\n--- Этапы развития: ---")
    print("1. Дерево → 2. Камень → 3. Железо → 4. Сталь → 5. Редкие материалы\n")
    
    # 6. Развитие поселения
    print("--- 6. РАЗВИТИЕ ПОСЕЛЕНИЯ ---")
    citadel = CitadelProgress(level=1)
    print(f"Уровень Цитадели: {citadel.level}")
    print(f"Репутация: {citadel.reputation}")
    print(f"Враждебность леса: {citadel.hostility}")
    
    # Увеличим враждебность
    citadel.increase_hostility("new_settler", len(settlers))
    citadel.increase_hostility("lumberjack_working", 1)
    print(f"Враждебность после действий: {citadel.hostility}")
    
    citadel.reduce_hostility(small_hearths=1)
    print(f"Враждебность после постройки Малого очага: {citadel.hostility}\n")
    
    # 7. Проверка настроений
    print("--- 7. ПРОВЕРКА НАСТРОЕНИЙ ЖИТЕЛЕЙ ---")
    for settler in settlers:
        old_resolve = settler.resolve
        new_resolve = settler.update_resolve(
            food_satisfied=True,
            clothing_satisfied=False,
            housing_satisfied=True,
            comfort_bonus=0
        )
        print(f"{settler.species.value}: Настроение {old_resolve} → {new_resolve}")
    
    print("\n" + "=" * 60)
    print("=== СИМУЛЯЦИЯ ЗАВЕРШЕНА УСПЕШНО ===")
    print("=" * 60)

if __name__ == "__main__":
    run_full_simulation()
