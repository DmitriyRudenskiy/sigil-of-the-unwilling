# Tasks: ui-icons-cursors-improvement

## Task 1: Создать спецификации системы иконок, курсоров и UI графики

**Priority:** High  
**Effort:** Small  
**Status:** Done  

Созданы следующие документы спецификаций согласно правилам OpenSpec:
- `openspec/changes/ui-icons-cursors-improvement/proposal.md` - предложение по улучшению
- `openspec/changes/ui-icons-cursors-improvement/specs/icon-system/spec.md` - спецификация системы иконок
- `openspec/changes/ui-icons-cursors-improvement/specs/cursor-system/spec.md` - спецификация системы курсоров
- `openspec/changes/ui-icons-cursors-improvement/specs/ui-graphics/spec.md` - спецификация UI графики

**Acceptance Criteria:**
- [x] proposal.md содержит разделы Why, What Changes, Capabilities, Impact, Non-goals
- [x] Каждая спецификация содержит Purpose и Requirements с Scenario
- [x] Документы следуют структуре OpenSpec

---

## Task 2: Создать директорию для иконок ресурсов и генератор иконок

**Priority:** High  
**Effort:** Medium  
**Status:** Done  

Создана структура папок для иконок и скрипт генерации иконок ресурсов по аналогии с gen_artifact_icons.gd.

**Acceptance Criteria:**
- [x] Создана директория `game/assets/ui/icons/resources/`
- [x] Создан скрипт `game/scripts/build/gen_resource_icons.gd`
- [x] Генератор создаёт иконки 32x32 для всех ресурсов из ResourceDef
- [x] Цвета иконок соответствуют C_RES_* из ThemeConfig
- [x] Запуск генератора создаёт PNG файлы в директории ресурсов (выполнено через Python script)

**Implementation Notes:**
```gdscript
# Использовать подход из gen_artifact_icons.gd
# Цвета брать из ThemeConfig.C_RES_WOOD, C_RES_MERCURY, etc.
# Формы: дерево (треугольник+ствол), камень (неровный многоугольник), 
# ртуть (колба), руда (глыба), сера (кристаллы), кристаллы (октаэдр), 
# самоцветы (огранка), золото (монеты)
```

---

## Task 3: Создать генератор иконок зданий

**Priority:** Medium  
**Effort:** Medium  
**Status:** Done  

Создан скрипт генерации иконок для зданий города.

**Acceptance Criteria:**
- [x] Создана директория `game/assets/ui/icons/buildings/`
- [x] Создан скрипт `game/scripts/build/gen_building_icons.gd`
- [x] Генератор создаёт иконки для: farm, mill, bakery, mine, smithy, tavern, school, trade_post, market, shack, walls, barracks
- [x] Форма каждой иконки отражает назначение здания
- [x] Иконки в размере 32x32 (выполнено через Python script)

---

## Task 4: Создать генератор иконок потребностей героя

**Priority:** Medium  
**Effort:** Small  
**Status:** Done  

Создан скрипт генерации иконок для потребностей героя (needs).

**Acceptance Criteria:**
- [x] Создана директория `game/assets/ui/icons/needs/`
- [x] Создан скрипт `game/scripts/build/gen_need_icons.gd`
- [x] Сгенерированы иконки: rest (отдых), social (общение), inspiration (вдохновение)
- [x] Иконки в размере 32x32 (выполнено через Python script)
- [x] Цвета отражают тип потребности (синий для отдыха, зелёный для общения, жёлтый для вдохновения)

---

## Task 5: Создать иконки школ магии

**Priority:** Medium  
**Effort:** Small  
**Status:** Done  

Созданы иконки для 4 школ магии.

**Acceptance Criteria:**
- [x] Создана директория `game/assets/ui/icons/schools/`
- [x] Сгенерированы иконки: air.png, fire.png, water.png, earth.png
- [x] Цвета соответствуют C_SCHOOL_AIR, C_SCHOOL_FIRE, C_SCHOOL_WATER, C_SCHOOL_EARTH
- [x] Формы: воздух (спираль/ветер), огонь (пламя), вода (волна/капля), земля (гора/кристалл)

---

## Task 6: Добавить спрайты курсоров для всех режимов

**Priority:** High  
**Effort:** Medium  
**Status:** Done  

Созданы PNG файлы для 6 режимов курсора и обновлён CursorController.

**Acceptance Criteria:**
- [x] Созданы файлы в `game/assets/cursors/`:
  - cursor_default.png (стандартная стрелка)
  - cursor_walk.png (ботинок/след)
  - cursor_collect.png (рука/мешок)
  - cursor_attack.png (меч)
  - cursor_spell.png (палочка/звезда)
  - cursor_talk.png (пузырь речи)
- [x] Обновлён MODE_ASSETS в CursorController.gd с путями к файлам
- [x] Настроены hotspot для каждого курсора
- [x] Размеры курсоров 32x32 с прозрачностью
- [x] Добавлены новые режимы Mode.CAST_SPELL и Mode.TALK

---

## Task 7: Создать графику UI виджетов (кнопки, панели, прогресс-бары)

**Priority:** High  
**Effort:** Large  
**Status:** Todo  

Создать текстуры для кнопок, панелей, прогресс-баров и других UI элементов.

**Acceptance Criteria:**
- [ ] Создана директория `game/assets/ui/widgets/`
- [ ] Поддиректории: buttons/, panels/, progress_bars/, sliders/, decorators/
- [ ] Кнопки: normal, hover, pressed, disabled состояния (9-slice текстуры)
- [ ] Панели: фон + рамка с закруглёнными углами
- [ ] Прогресс-бары: фон + заполнение для здоровья, маны, опыта
- [ ] Слайдеры: дорожка + ползунок
- [ ] Чекбоксы: checked/unchecked состояния
- [ ] Интеграция с game_theme.tres

---

## Task 8: Обновить game_theme.tres для использования новых текстур

**Priority:** High  
**Effort:** Medium  
**Status:** Todo  

Заменить StyleBoxFlat заглушки на текстуры из widgets/.

**Acceptance Criteria:**
- [ ] StyleBoxFlat_button заменён на текстуры кнопок
- [ ] StyleBoxFlat_panel заменён на текстуру панели с рамкой
- [ ] StyleBoxFlat_slot заменён на текстуру слота
- [ ] Progress bar стили используют новые текстуры заполнения
- [ ] Тема загружается без ошибок

---

## Task 9: Обновить ThemeConfig для путей к иконкам

**Priority:** Medium  
**Effort:** Small  
**Status:** Todo  

Добавить методы get_icon() в Registry классы и константы путей в ThemeConfig.

**Acceptance Criteria:**
- [ ] ThemeConfig содержит пути ICON_DIR_RESOURCES, ICON_DIR_BUILDINGS, etc.
- [ ] ResourceRegistry.get_icon(id) возвращает Texture2D
- [ ] BuildingDefs.get_icon(id) возвращает Texture2D
- [ ] Кэширование загруженных текстур
- [ ] Fallback иконка для отсутствующих ресурсов

---

## Task 10: Обновить UI сцены для использования новых иконок

**Priority:** Medium  
**Effort:** Large  
**Status:** Todo  

Обновить существующие UI сцены (.tscn) для использования новых иконок вместо эмодзи.

**Acceptance Criteria:**
- [ ] ResourceBar.tscn использует иконки ресурсов из assets/ui/icons/resources/
- [ ] ResourcesPanel.tscn использует новые иконки
- [ ] CityScreen.tscn использует иконки зданий
- [ ] HeroStatusPanel.tscn использует иконки потребностей
- [ ] BattleSpellbookPanel.tscn использует иконки школ магии
- [ ] Все TextureRect узлы имеют корректные texture пути

---

## Task 11: Написать unit тесты для системы иконок и курсоров

**Priority:** Low  
**Effort:** Medium  
**Status:** Todo  

Создать тесты для проверки загрузки иконок, курсоров, кэширования.

**Acceptance Criteria:**
- [ ] test_icon_loading.gd: проверка загрузки всех иконок ресурсов
- [ ] test_cursor_sprites.gd: проверка загрузки спрайтов курсоров
- [ ] test_icon_cache.gd: проверка кэширования текстур
- [ ] test_fallback_icon.gd: проверка fallback иконки
- [ ] Все тесты проходят успешно

---

## Task 12: Документация и финальная проверка

**Priority:** Low  
**Effort:** Small  
**Status:** Todo  

Обновить документацию проекта и провести финальную проверку всех изменений.

**Acceptance Criteria:**
- [ ] README.md обновлён с информацией о новой системе иконок
- [ ] doc/task/ обновлён новыми задачами
- [ ] Все ассеты проверены на наличие артефактов сжатия
- [ ] Производительность UI проверена в игре
- [ ] Change log обновлён
