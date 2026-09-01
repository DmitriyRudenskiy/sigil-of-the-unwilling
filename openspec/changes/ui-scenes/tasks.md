## 1. Аудит динамического UI
### 1.1
Проанализировать все панели в `game/scripts/ui/` на предмет динамической сборки
(`add_child`/`.new()`/`_build`/`_refresh`).
- [x] Классифицировать каждую панель: статический скелет / динамический список / гибрид
- [x] Оценить сложность перевода (кол-во узлов, зависимость от данных)
- [x] Назначить приоритет перевода на сцену (высокий/средний/низкий)

### 1.2
Оформить аудит в `docs/systems/UI_AUDIT.md`.
- [x] Перечислить все панели с классификацией и приоритетом
- [x] Зафиксировать палитру/стили для переноса в тему
- [x] Указать точные размеры/позиции ключевых панелей (942×706 и т. д.)

### 1.3
Обновить `docs/README.md` — добавить ссылку на `docs/systems/UI_AUDIT.md` в UI-раздел.
- [x] Добавить позицию в индекс UI-слоя
- [x] Проверить, что ссылка не битая

## 2. Ресурс общей темы
### 2.1
Создать `game/assets/theme/game_theme.tres` (или папку `styles/`) с переиспользуемыми
стилями: `panel`, `slot`, `button`, `label_gold`, `label_light`, радиусы/отступы.
- [x] Перенести цвета из палитры `ArtifactInventoryScreen` (WIN_BG, OUTLINE, SLOT_BG,
      RED_BG, TEXT_GOLD, TEXT_LIGHT)
- [x] Зарегистрировать StyleBox-ы как именованные стили темы

### 2.2
Зафиксировать в аудите/документации, что тема — единый источник стилей.
- [x] Описать в `docs/systems/UI_AUDIT.md` (раздел «Стилизация»)

## 3. Сцена инвентаря
### 3.1
Создать `game/scenes/ui/ArtifactInventoryScreen.tscn` (root `Control`, скрипт
`ArtifactInventoryScreen`).
- [x] Вернуть в сцену CenterContainer, окно 942×706, под-панели Left/Right/Side/Bottom
- [x] Перенести стили из `_stylebox()` в общую тему (D3)
- [x] Повторить абсолютные координаты/размеры «по макету»

### 3.2
Перенести логику подтяжки данных из кода.
- [x] `set_hero()`/`_refresh()` заполняют статы, портрет, рюкзак, слоты куклы, навыки
- [x] Сохранить сигналы `closed` и поведение `close()`

### 3.3
Проверить поведение и верстку инвентаря.
- [ ] Скриншот «до/после» — совпадение геометрии и стилей
- [ ] Открытие/закрытие по шорткату и из меню

## 4. Сцена книги заклинаний
### 4.1
Создать `game/scenes/ui/BattleSpellbookPanel.tscn` (root `Control`, скрипт
`BattleSpellbookPanel`).
- [x] Вернуть в сцену контейнер и плейсхолдеры кнопок заклинаний
- [x] Перенести стили в общую тему (D3)

### 4.2
Перенести логику заполнения списка.
- [x] `_refresh()` заполняет кнопки из `HeroMagic.spellbook`/`SpellRegistry`
- [x] Сохранить сигнал `spell_chosen` и фильтрацию по target_type

### 4.3
Проверить открытие книги в бою.
- [ ] Скриншот «до/после»
- [ ] Кнопка 📖 → открытие → выбор заклинания

## 5. Перевод приоритетных панелей по аудиту
### 5.1
Перевести на сцены панели с высоким приоритетом (напр. `BattleUI`, `InfoPanel`,
`ArtifactChestDialog`) в соответствии с `UI_AUDIT.md`.
- [x] Сцены в `game/scenes/ui/` (InfoPanel.tscn, BattleUI.tscn, ArtifactChestDialog.tscn)
- [x] Стили из общей темы (D3: panel/slot/button)
- [x] Динамическое содержимое подтягивается в рантайме

### 5.2
Заменить инстансирование `.new()` на `.instantiate()` сцен.
- [x] BattleUI → `BattleController._init_ui` (instantiate scene)
- [x] InfoPanel → `AdventureUI` (instantiate scene)
- [x] ArtifactChestDialog → `WorldUIManager._create_chest_dialog` (instantiate scene)
- [x] Обновить регрессионный тест `test_refactoring_regression.gd` (Т10)
- [x] Сохранить сигналы/методы `setup`/`toggle`/`open_spellbook`/`set_controls_enabled`

### 5.3
Проверить переведённые панели.
- [x] Поведение (открытие, кнопки, данные) без изменений — probe-тесты + operability CLEAN
- [x] Все unit-тесты проходят (546+)
- [ ] Скриншоты «до/после» (headless-окружение: недоступно, см. 6.3)

## 6. Проверка и коммит
### 6.1
Запустить `bash game/tools/shell/run_operability.sh`, убедиться, что вердикт CLEAN.
- [ ] Исправить найденные SCRIPT ERROR/Parse Error/Run Error
- [ ] При необходимости обновить `docs/CONSOLE_ALLOWLIST.md`

### 6.2
Сделать скриншоты ключевых панелей «после» и сверить с эталоном «до».
- [ ] Инвентарь, книга заклинаний, приоритетные HUD-панели

### 6.3
Коммит только файлов цикла `ui-scenes`.
- [ ] `game/scenes/ui/*.tscn`, `game/assets/theme/*.tres`, `.gd`-изменения UI
- [ ] `docs/systems/UI_AUDIT.md`, `docs/README.md`, `openspec/changes/ui-scenes/*`
- [ ] Не выносить файлы других циклов
