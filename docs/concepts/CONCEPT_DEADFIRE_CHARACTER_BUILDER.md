# Концепт: конструктор персонажа (Pillars of Eternity II: Deadfire)

Референс data-driven конструктора персонажа для Godot 4 в стиле **Pillars of
Eternity II: Deadfire**. Идея — отдельная от текущей matrices рас/классов
(`RACE_CLASS_MATRIX.md`, Pathfinder 1e): здесь другие расы, другой подход к
классам (мультикласс вместо архетипов), атрибуты, навыки, оружие, культура и
предыстория. Документ — **дизайн-справочник** (без привязки к коду), фиксирует
весь объём информации из исходного референса и показывает, что из него можно
занять для текущей игры.

> **Откуда:** выписка из `chat-Godot Character Builder.txt` — проект Godot 4
> «Deadfire Character Constructor», где **вся игровая информация вынесена в
> `data/*.json`**, а код только читает их и строет интерфейс.

---

## 0. Ключевые принципы (почему «проще, чем Kingmaker»)

- **Единая система атрибутов без «дамп-статов»**: каждое очко выше 10 даёт
  +1 к Точности, всем классам полезны все атрибуты.
- **Мультикласс** — просто выбор двух классов сразу, без требований и
  престиж-классов, доменов, родословных.
- **Всё правится в JSON без стр кода**: новый класс/предмет/подвид — один
  объект в JSON, список в интерфейсе перестроится сам.
- **Культура + Предыстория** влияют на диалоги, атрибуты и навыки.

---

## 1. Атрибуты (6) и пул очков

**Правило:** `base_value=10`, `min=8`, `max=18`, пул = `19` очков, `soft_cap=14`
(до 14 — 1 очко за шаг, выше — по 2 очка за шаг).

| ID | Name RU | Name EN | Short | Что даёт |
| --- | --- | --- | --- | --- |
| `might` | Могущество | Might | Урон | +2,5% урона всех атак/способностей/заклинаний за очко > 10. |
| `constitution` | Телосложение | Constitution | Здоровье | Макс HP, защита от тела, концентрация при уроне. |
| `dexterity` | Ловкость | Dexterity | Скорость | Скорость атак/перезарядки/заклинаний, защита от реакции. |
| `perception` | Восприятие | Perception | Меткость | Точность атак, шанс прервать действие врага. |
| `intellect` | Интеллект | Intellect | Разум | Длительность/обратность эффектов, запас заклинаний чародеев. |
| `resolve` | Решимость | Resolve | Воля | Защите воли, шанс крита, стойкость к эффектам разума. |

`universal_rule`: «Все атрибуты полезны всем классам: каждое очко выше 10 даёт
+1 к Точности. Дамп-статов нет, штрафов за распределение нет.»

---

## 2. Классы (11) — роль и ключевые атрибуты

Мультикласс — любые два класса сразу (55 комбинаций, см. §3).

| ID | Name RU | Name EN | Роль | Primary атрибуты |
| --- | --- | --- | --- | --- |
| `barbarian` | Варвар | Barbarian | Ярость и натиск | might, constitution, dexterity |
| `chanter` | Певчий | Chanter | Песни и призыв | constitution, resolve, intellect |
| `cipher` | Шифр | Cipher | Контроль разума | intellect, dexterity, resolve |
| `druid` | Друид | Druid | Облик и стихии | might, intellect, constitution |
| `fighter` | Воин | Fighter | Дисциплина боя | might, dexterity, constitution |
| `monk` | Монах | Monk | Ки и раны | might, dexterity, constitution |
| `paladin` | Паладин | Paladin | Клятва и кара | might, resolve, constitution |
| `priest` | Жрец | Priest | Молитвы и свет | might, intellect, resolve |
| `ranger` | Следопыт | Ranger | Выстрел и зверь | dexterity, perception, might |
| `rogue` | Плут | Rogue | Тень и точность | dexterity, perception, intellect |
| `wizard` | Волшебник | Wizard | Гримуар и формулы | intellect, resolve, dexterity |

---

## 3. Мультикласс — 55 именованных комбинаций

C(11,2) = 55 пар. Порядок классов в паре не важен.

| Комбинация | Name EN | Name RU | Пара |
| --- | --- | --- | --- |
| War Caller | Военный глашатай | barbarian + chanter |
| Brute | Громила | barbarian + cipher |
| Mauler | Крушитель | barbarian + druid |
| Battlerager | Бешеный воин | barbarian + fighter |
| Berserker | Берсерк | barbarian + monk |
| Destroyer | Разрушитель | barbarian + paladin |
| Doomcaller | Вестник рока | barbarian + priest |
| Wildhunter | Дикий охотник | barbarian + ranger |
| Marauder | Мародёр | barbarian + rogue |
| Ruinmage | Маг руин | barbarian + wizard |
| Mindsinger | Певец разума | chanter + cipher |
| Wildcaller | Зовущий глушь | chanter + druid |
| Skald | Скальд | chanter + fighter |
| Hymnkeeper | Хранитель гимнов | chanter + monk |
| Herald of Faith | Вестник веры | chanter + paladin |
| Faithsinger | Певчий веры | chanter + priest |
| Woodherald | Лесной глашатай | chanter + ranger |
| Shadowdancer | Тенепляс | chanter + rogue |
| Sagaweaver | Ткач саг | chanter + wizard |
| Dreamwalker | Сноходец | cipher + druid |
| Psyblade | Пси-клинок | cipher + fighter |
| Mindfist | Ментальный кулак | cipher + monk |
| Soulsentinel | Страж душ | cipher + paladin |
| Mindweaver | Ткач разума | cipher + priest |
| Mindhunter | Охотник разума | cipher + ranger |
| Thoughtthief | Похититель мыслей | cipher + rogue |
| Psion | Псион | cipher + wizard |
| Warden | Страж | druid + fighter |
| Wildclaw | Дикий коготь | druid + monk |
| Groveknight | Рыцарь рощи | druid + paladin |
| Wildpriest | Жрец глуши | druid + priest |
| Beastmaster | Повелитель зверей | druid + ranger |
| Bramblestalker | Терновый следопыт | druid + rogue |
| Elementalist | Элементалист | druid + wizard |
| Battlemaster | Мастер боя | fighter + monk |
| Crusader | Крестоносец | fighter + paladin |
| Warpriest | Жрец войны | fighter + priest |
| Sentinel | Дозорный | fighter + ranger |
| Swashbuckler | Дуэлянт | fighter + rogue |
| Battlemage | Боевой маг | fighter + wizard |
| Sacredfist | Священный кулак | monk + paladin |
| Illuminated | Озарённый | monk + priest |
| Windrunner | Бегущий по ветру | monk + ranger |
| Assassin | Ассасин | monk + rogue |
| Spellfist | Чародейский кулак | monk + wizard |
| Zealot | Ревнитель веры | paladin + priest |
| Inquisitor | Инквизитор | paladin + ranger |
| Greyknight | Серый рыцарь | paladin + rogue |
| Spellknight | Рыцарь-чародей | paladin + wizard |
| Soulguide | Проводник душ | priest + ranger |
| Confessor | Исповедник | priest + rogue |
| Theurge | Теург | priest + wizard |
| Shadowhunter | Теневой охотник | ranger + rogue |
| Arcanearcher | Мистический стрелок | ranger + wizard |
| Trickster | Трикстер | rogue + wizard |

---

## 4. Расы (6) с подвидами и пассивными умениями

У каждой расы 2 подвида, у каждого — уникальное пассивное умение.

### Aumaua — Ауама
Высокие длиннорукие воины архипелага, почитающие солнце и луну.
- `coastal` — Прибрежные ауама. **«Длинные руки»**: +1 м к дистанции атак ближнего боя.
- `islander` — Островные ауама. **«Сойкость архипелага»**: +10 к защите от Опрокидывания и Отбрасывания.

### Dwarf — Дворф
Коронастые и упрямые мастера камня и стали.
- `mountain` — Горный дворф. **«Каменная стойкость»**: +15 к максимуму здоровья.
- `ocean` — Океанский дворф. **«Морская закалка»**: +5 к Защите от тела и +15% к скорости восстановления.

### Elf — Эльф
Дети Древних, наследники погибшего Энгвитана.
- `pale` — Бледный эльф. **«Хладный разум»**: +5 к Защите воли.
- `wood` — Лесной эльф. **«Лёгкая поступь»**: +10% к скорости передвижения и +5 к Скрытности.

### Godlike — Богоподобный
Отмеченный богами: облик и дар зависят от покровителя.
- `nature` — Богоподобный глуши. **«Дар глуши»**: раз в бой — восстановление 20% здоровья аурой вокруг себя.
- `flame` — Богоподобный пламени. **«Внутреннее пламя»**: +10% к урону огнём и светом.

### Human — Человек
Амбициозные и многочисленные: от полей Ээдирской империи до островов Мёртвого Огня.
- `hearthling` — Земляк. **«Непоколебимость»**: +1 к Атлетике и +1 к Знаниям.
- `ocean_kindred` — Морской сородич. **«Дитя приливов»**: +1 к Выживанию и +1 к Навигации.

### Orlan — Орлан
Маленькие, быстрые и бесстрашные: рост компенсируют яростью и хитростью.
- `rautai` — Орлан Рауатаи. **«Боевой раж»**: +5 к Точности при атаках по целям, атакованным с фланга.
- `outcast` — Орлан-изгой. **«Незримый»**: +5 к Скрытности и +5 к Ловкости рук.

---

## 5. Навыки (16): 7 активных + 9 пассивных

На старте: **+1 к трём навыкам на выбор** (creation_points=3); ещё **+1 к двум**
даёт предыстория.

### Активные (7)
`alchemy` — Алхимия · `athletics` — Атлетика · `lore` — Знания ·
`mechanics` — Механика · `sleight_of_hand` — Ловкость рук ·
`stealth` — Скрытность · `survival` — Выживание.

### Пассивные (9)
`bartering` — Торговля · `cooking` — Кулинария · `smithing` — Кузнечное дело ·
`enchanting` — Зачарование · `medicine` — Медицина · `navigation` — Навигация ·
`animal_handling` — Дрессировка · `tactics` — Тактика · `cartography` — Картография.

---

## 6. Оружие и щиты (31) с модальными атакми

Категории: `melee_1h`, `melee_2h`, `ranged`, `implement`, `shield`.

| ID | Name RU | Cat | Урон | Скорость | Дальность | Модальная атака |
| --- | --- | --- | --- | --- | --- | --- |
| dagger | Кинжал | melee_1h | 3–7 (Колющий) | Быстрая | — | Точный укол: +15 Точности, крит → Кровотечение. |
| short_sword | Короткий меч | melee_1h | 5–11 (Рубящий) | Быстрая | — | Двойной выпад: 2 атаки −10 Точности каждая. |
| sword | Меч | melee_1h | 7–15 (Рубящий) | Средняя | — | Рассекающий взмах: дуга по целям рядом. |
| mace | Булава | melee_1h | 6–14 (Дробящий) | Средняя | — | Дробящий удар: игнорирует 5 ед. Порога урона. |
| warhammer | Боевой молот | melee_1h | 8–16 (Дробящий) | Медленная | — | Пробитие шлема: 50% Оглушить на 5 с. |
| axe | Топор | melee_1h | 7–16 (Рубящий) | Средняя | — | Кровопускание: сильное Кровотечение. |
| spear | Копьё | melee_1h | 6–14 (Колющий) | Средняя | — | Упреждающий выпад: +1 м дистанция, бонус против ближних. |
| flail | Цеп | melee_1h | 5–13 (Дробящий) | Средняя | — | Обход щита: игнорирует бонус щита. |
| morningstar | Моргенштерн | melee_1h | 7–15 (Дробящий) | Средняя | — | Размозжение: +50% урона по Оглушённым/Ошеломлённым. |
| cudgel | Дубина | melee_1h | 4–10 (Дробящий) | Быстрая | — | Оглушающий замах: слабый урон, высокий шанс Ошеломления. |
| great_sword | Двуручный меч | melee_2h | 11–21 (Рубящий) | Медленная | — | Широкий замах: AoE перед бойцом. |
| battle_axe | Секира | melee_2h | 12–24 (Рубящий) | Медленная | — | Казнь: +50% урона по целям <25% HP. |
| great_mace | Двуручная булава | melee_2h | 11–22 (Дробящий) | Медленная | — | Сокрушение: шанс сбить с ног. |
| pike | Пика | melee_2h | 10–19 (Колющий) | Медленная | — | Стена стали: контратака по впервыешедшему в ближний бой. |
| pollaxe | Полэкс | melee_2h | 11–20 (Рубящий) | Медленная | — | Подрезка: шанс Опрокинуть. |
| estoc | Эсток | melee_2h | 9–18 (Колющий) | Средняя | — | Пробитие доспеха: игнорирует 10 ед. Порога. |
| quarterstaff | Посох | melee_2h | 8–16 (Дробящий) | Средняя | — | Вихрь посоха: по врагам вокруг. |
| glaive | Глефа | melee_2h | 12–21 (Рубящий) | Медленная | — | Полумесяц: дуговая атака с Отбрасыванием. |
| bow | Лук | ranged | 6–13 (Колющий) | Средняя | 1–9 м | Точный выстрел: +25 Точности. |
| crossbow | Арбалет | ranged | 8–15 (Колющий) | Медленная | 2–10 м | Пробивной болт: частично игнорирует Порог урона. |
| arbalest | Самострел | ranged | 11–20 (Колющий) | Медленная | 2–11 м | Тяжёлый болт: шанс Опрокинуть. |
| pistol | Пистолет | ranged | 10–18 (Проникающий) | Медленная | 1–6 м | Выстрел в упор: Отбрасывание. |
| gun | Ружьё | ranged | 12–22 (Проникающий) | Медленная | 2–12 м | Меткий выстрел: +15 Точности и урона. |
| blunderbuss | Мушкетон | ranged | 9–17 (Проникающий) | Медленная | 1–5 м | Веер дроби: конус по всем в зоне. |
| rod | Жезл | implement | 5–12 (Стихийный) | Средняя | — | Разряд жезла: дальняя магическая атака стихией. |
| sceptre | Скипетр | implement | 6–13 (Дробящий) | Средняя | — | Властный удар: шанс Подавить волю. |
| wand | Волшебный жезл | implement | 4–10 (Стихийный) | Быстрая | — | Искра: быстрая магическая атака без восстановления. |
| small_shield | Малый щит | shield | — | Быстрая | — | Лёгкий таран: шанс Ошеломить. |
| medium_shield | Средний щит | shield | — | Средняя | — | Таранный удар: Отбрасывание. |
| large_shield | Большой щит | shield | — | Медленная | — | Стена: +5 к Защите на 10 с. |
| tower_shield | Башенный щит | shield | — | Медленная | — | Укрытие: +5 к Защите от дальних атак себе и соседям. |

---

## 7. Культура (6) — +2 к атрибуту + реплика в диалогах

| ID | Name RU | Бонус | Реплика |
| --- | --- | --- | --- |
| aedyran | Ээдирец | +2 Resolve | «Ээдирец» |
| vailian | Вэйлиец | +2 Intellect | «Вэйлиец» |
| deadfire_islander | Островитянин Мёртвого Огня | +2 Constitution | «Островитянин» |
| rautai | Рауатаи | +2 Perception | «Рауатаи» |
| huana | Хуана | +2 Might | «Хуана» |
| free_captain | Вольный мореход | +2 Dexterity | «Мореход» |

## 8. Предыстория (8) — +1 к двум навыкам + реплика в диалогах

| ID | Name RU | Бонус (навыки) | Реплика |
| --- | --- | --- | --- |
| scholar | Учёный | lore, enchanting | «Учёный» |
| mercenary | Наёмник | athletics, tactics | «Наёмник» |
| sailor | Моряк | navigation, athletics | «Моряк» |
| aristocrat | Аристократ | bartering, tactics | «Аристократ» |
| smuggler | Контрабандист | sleight_of_hand, stealth | «Контрабандист» |
| artisan | Ремесленник | smithing, mechanics | «Ремесленник» |
| hunter | Охотник | survival, animal_handling | «Охотник» |
| vagabond | Бродяга | survival, cooking | «Бродяга» |

---

## 9. Архитектура референса (как устроено в Godot)

```
project.godot            # autoload GameData, main_scene = CharacterCreator.tscn
data/
  attributes.json        # 6 атрибутов + meta пула очков (base/min/max/point_pool/soft_cap)
  classes.json           # 11 классов (role, primary, description)
  multiclass.json        # 55 комбинаций (pair → name_en/name_ru)
  races.json             # 6 рас × 2 подвида, у подвида passive {name, effect}
  skills.json            # meta.creation_points=3; active[7], passive[9]
  weapons.json           # 31 оружие/щит с modal {name, effect}
  cultures.json          # 6 культур (attribute_bonus, dialogue_tag)
  backgrounds.json       # 8 предысторий (skill_bonuses, dialogue_tag)
scripts/
  game_data.gd           # autoload: читает все JSON, даёт геттеры (get_races/get_class/…)
  character_creator.gd   # только интерфейс: состояние персонажа + рендер вкладок
scenes/CharacterCreator.tscn  # TabContainer: Раса / Класс / Атрибуты / Навыки / Оружие / Происхождение / Итог
```

**Разделение ответственности:** `GameData` (autoload, `RefCounted`-подход) —
только чтение данных и удобный доступ, ничего не знает об интерфейсе.
`CharacterCreator` — только UI: состояние в `character`-словаре, привязка
`@onready`-уз (%RaceList и т.д.), `_refresh_ui()` перерисовывает сводку.

**Экспорт персонажа** → `user://deadfire_character.json` со структурой
`{game, name, race{id,name,subrace_id,subrace_name,passive}, class{multiclass,classes,combo_name}, attributes, skills, weapons{main,off}, culture, background, dialogue_tags}`.

**Валидация готовности** (`_validate`): обязательны раса+подвид, класс (+второй
для мультикласса), основное оружие, культура, предыстория.

---

## 10. Что можно занять для текущей игры

Текущая система (`RACE_CLASS_MATRIX.md`) — Pathfinder 1e: 6 рас (Aasimar,
Dwarf, Elf, Gnome, Halfling, Human), 16 классов × 4 архетипа, подсистемы
(bloodlines/domains/prestige/feats). Референс Deadfire дополняет её **идеями,
а не данными** (расы несовместимы):

- **Подвиды с пассивными умениями** — оформить `RaceDef.subraces[]` уже есть;
  добавить поле `passive {name, effect}` и подтягивать в `Follower.abilities`.
- **Атрибуты вместо «дамп-статов»** — идея «все статы полезны» для баланса
  модификаторов рас/классов.
- **Мультикласс-комбинации** — 55 именованных пар как образец для будущих
  «гибридных» архетипов/бэкенда найма.
- **Модальные атаки оружия** — структура `weapon {modal:{name,effect}}` как
  образец, если когда-то добавим оружейную систему.
- **Культура/предыстория** как отдельный слой с `dialogue_tag` — задел под
  диалоговые метки последователей.
- **Data-driven паттерн** — единый `data/*.json` + lazy-реестр уже реализован
  в `RaceClassRegistry.gd`; референс подтверждает направление.

> **Статус реализации:** в текущем коде есть аналоги — расы/классы в
> `RaceClassRegistry.gd`/`RaceDef.gd`/`ClassDef.gd`, `Follower`/`FollowerSystem`,
> data-driven JSON. Интерфейс конструктора (вкладки, пул очков) отложен — см.
> примечание в `RACE_CLASS_MATRIX.md` («UI-отображение отложено в отдельный
> цикл»).
