# Fission AI: Strategy Game Project

[![OpenSpec](https://img.shields.io/badge/OpenSpec-enabled-blue)](https://github.com/Fission-AI/OpenSpec)
[![Godot Engine](https://img.shields.io/badge/Godot-4.7-blue.svg)](https://godotengine.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📖 Описание проекта

**Fission AI** — это стратегическая игра с элементами RPG, разработанная на движке Godot 4.7. Проект включает в себя систему управления городом, тактические сражения, исследование мира, магическую систему и экономику ресурсов.

### 🎮 Ключевые особенности

- **Управление городом**: Строительство зданий, управление ресурсами, развитие инфраструктуры
- **Тактические бои**: Пошаговые сражения на гексагональной карте с использованием магии и юнитов
- **Система магии**: 4 школы магии (огонь, вода, земля, воздух) с уникальными заклинаниями
- **Экономика**: Добыча и торговля 10+ ресурсами (дерево, камень, ртуть, руда, сера, кристаллы и др.)
- **Герои и потребности**: Система потребностей героев (отдых, общение, вдохновение)
- **Процедурная генерация**: Генерация карты с горами, лесами, реками и дорогами
- **Квесты и репутация**: Система заданий и отношений с фракциями

## 🚀 Быстрый старт

### Требования

- **Godot Engine 4.7** (стандартная версия, не .NET)
- Python 3.8+ (для инструментов разработки)
- Git

### Установка и запуск

1. **Клонируйте репозиторий**:
   ```bash
   git clone <repository-url>
   cd fission-ai
   ```

2. **Установите Godot 4.7**:
   - Скачайте с [официального сайта](https://godotengine.org/download)
   - Или используйте пакетный менеджер вашей ОС

3. **Запустите проект**:
   ```bash
   # Способ 1: Через Godot GUI
   # Откройте Godot → Import → выберите game/project.godot
   
   # Способ 2: Через командную строку
   godot --path game --editor  # Для редактора
   godot --path game           # Для запуска игры
   ```

4. **Запуск тестов**:
   ```bash
   cd game && bash tests/run_all.sh   # полный прогон: gdUnit4 + MCP + структурные
   ```
   Подробности (требования, правила, baseline) — в [doc/testing.md](doc/testing.md).

5. **MCP-сервер (опционально, для AI-интеракции и MCP-тестов)**: вендорный
   проект [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp)
   **не коммитится** (gitignored) и ставится локально один раз:
   ```bash
   cd game
   git clone https://github.com/tugcantopaloglu/godot-mcp.git addons/godot-mcp
   cd addons/godot-mcp && npm install && npm run build
   ```
   Точка входа: `game/addons/godot-mcp/build/index.js` (interaction-порт 9090).
   Без него игра и gdUnit4-тесты работают; MCP-секция `run_all.sh` пропускается.
   Сервер на время теста инжектит `game/mcp_interaction_server.gd` — транзиентный
   артефакт (gitignored, чистится в конце прогона).

## 📁 Структура проекта

```
fission-ai/
├── game/                      # Основной проект Godot
│   ├── assets/                # Ресурсы игры
│   │   ├── ui/                # UI элементы (иконки, курсоры, виджеты)
│   │   ├── tilesets/          # Гексагональные тайлсеты
│   │   ├── data/              # JSON данные (заклинания, баланс)
│   │   └── ...                # Спрайты, аудио
│   ├── scenes/                # Сцены Godot
│   │   ├── MainMenu.tscn      # Главное меню
│   │   ├── World.tscn         # Карта мира
│   │   ├── Battle.tscn        # Боевая сцена
│   │   └── CityArena.tscn     # Сцена города
│   ├── scripts/               # Исходный код GDScript
│   │   ├── autoload/          # Синглтоны (глобальные скрипты)
│   │   ├── core/              # Базовые системы
│   │   ├── systems/           # Игровые системы
│   │   ├── entities/          # Сущности (юниты, здания)
│   │   ├── world/             # Генерация мира
│   │   ├── city/              # Логика города
│   │   ├── ui/                # UI логика
│   │   ├── economy/           # Экономика
│   │   └── demographics/      # Демография
│   ├── tests/                 # Тесты (gdUnit4 4.x); полный прогон: tests/run_all.sh
│   ├── tools/                 # Инструменты разработки
│   ├── project.godot          # Конфигурация проекта
│   └── run_tests.sh           # Скрипт запуска тестов
├── openspec/                  # Спецификации OpenSpec
│   ├── changes/               # Предложения по изменениям
│   │   ├── ui-icons-cursors-improvement/
│   │   ├── quests-reputation-system/
│   │   └── map-generation-enhancements/
│   ├── specs/                 # Технические спецификации
│   └── config.yaml            # Конфигурация OpenSpec
├── doc/                       # Документация
│   └── task/                  # Задачи и требования
└── tmp/                       # Временные файлы
```

## 🛠️ Разработка

### Открытые изменения (OpenSpec Changes)

Проект использует методологию [OpenSpec](https://github.com/Fission-AI/OpenSpec) для управления изменениями:

| Изменение | Статус | Описание |
|-----------|--------|----------|
| `ui-icons-cursors-improvement` | ✅ Реализовано | Улучшение UI, иконок и курсоров |
| `quests-reputation-system` | 📋 Предложено | Система квестов и репутации |
| `map-generation-enhancements` | 🚧 В разработке | Генерация рек, дорог, гор и лесов |

### Создание нового изменения

```bash
# Создайте директорию для изменения
mkdir -p openspec/changes/<change-name>/

# Добавьте proposal.md и specs/
# Следуйте шаблону из существующих изменений
```

### Запуск инструментов разработки

```bash
# Генерация иконок
godot --path game --script scripts/build/gen_resource_icons.gd

# Валидация заклинаний
godot --path game --script tools/spell_validation/validate_spells.gd

# Запуск сценариев тестирования
godot --path game --script tools/scenarios/<scenario>.gd
```

### Тестирование

Проект использует **gdUnit4 4.x** (аддон `game/addons/gdunit4`).

```bash
# Полный прогон (gdUnit4 + MCP + структурные проверки) — единственная точка входа
cd game && bash tests/run_all.sh

# Только gdUnit4 (headless)
cd game && godot --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests
```

Подробное руководство (требования, структура, правила именования, baseline,
известные skip) — в [doc/testing.md](doc/testing.md).

## 📚 Документация

Документация живёт в `doc/`:

- [Тестирование](doc/testing.md) — требования, правила, baseline
- [Задачи и требования](doc/task/) — `TASK_*.md`
- [Система магии](game/assets/data/spells.json)
- [Спецификации OpenSpec](openspec/specs/)

### Формат задачи (`doc/task/TASK_*.md`)

```markdown
# TASK_XX: Название задачи

## Описание
## Требования
## Критерии приёмки
## Ресурсы
## Статус          # Не начата / В работе / На проверке / Завершена
```

## 🎨 Ассеты

### Иконки и графика
- **Ресурсы**: 10+ иконок (дерево, камень, ртуть, руда, сера, кристаллы, самоцветы, золото, серебро, кварц, уголь)
- **Здания**: 12+ иконок (ферма, мельница, пекарня, шахта, кузница, таверна, школа, рынок и др.)
- **Потребности**: отдых, общение, вдохновение
- **Школы магии**: огонь, вода, земля, воздух

### Курсоры
6 режимов курсора с уникальными спрайтами:
- DEFAULT, WALK, COLLECT, ATTACK, CAST_SPELL, TALK

### UI Виджеты
- Кнопки (normal, hover, pressed, disabled)
- Панели и рамки
- Прогресс-бары (здоровье, мана, опыт)
- Слайдеры и чекбоксы
- Декоративные элементы

### Система загрузки иконок
- Пути каталогов — константы `ICON_DIR_*` в `scripts/theme/ThemeConfig.gd`
- `ThemeConfig.icon_texture(path)` — кэшированная загрузка, fallback на `fallback.png` при отсутствии файла
- `ResourceRegistry.get_icon(id)` и `BuildingDefs.get_icon(id)` — текстура по id ресурса/здания
- `game_theme.tres` использует 9-slice `StyleBoxTexture` для кнопок, панелей, слотов и прогресс-баров
- Тесты: `tests/unit/theme/` (загрузка, курсоры, кэш, fallback)

## 🤝 Вклад в проект

Мы приветствуем вклад в проект! Пожалуйста, следуйте правилам [OpenSpec](https://github.com/Fission-AI/OpenSpec):

1. Создайте предложение (`proposal.md`) в `openspec/changes/<change-name>/`
2. Опишите спецификации в `openspec/changes/<change-name>/specs/`
3. Реализуйте изменения
4. Добавьте тесты
5. Отправьте pull request

### Стандарты кода

- Используйте `.editorconfig` для форматирования
- Следуйте стилю GDScript из [официальной документации Godot](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- Добавляйте тесты для новых функций

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для деталей.

## 🔗 Ссылки

- [Godot Engine](https://godotengine.org/)
- [OpenSpec](https://github.com/Fission-AI/OpenSpec)
- [gdUnit4](https://github.com/MikeSchulze/gdUnit4)
- [Документация Godot](https://docs.godotengine.org/)

## 📞 Контакты

- GitHub: [@Fission-AI](https://github.com/Fission-AI)
- Issues: [Сообщить о проблеме](../../issues)
- Discussions: [Обсуждения](../../discussions)

---

**Версия проекта**: 0.1.0  
**Последнее обновление**: 2024  
**Статус**: Alpha (активная разработка)
