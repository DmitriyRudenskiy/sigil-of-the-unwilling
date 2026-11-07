# Sigil of the Unwilling: Strategy Game Project

[![OpenSpec](https://img.shields.io/badge/OpenSpec-enabled-blue)](https://github.com/Fission-AI/OpenSpec)
[![Godot Engine](https://img.shields.io/badge/Godot-4.7-blue.svg)](https://godotengine.org/)

## 📖 Описание проекта

**Sigil of the Unwilling** — это стратегическая игра с элементами RPG, разработанная на движке Godot 4.7. Проект включает в себя систему управления городом, тактические сражения, исследование мира, магическую систему и экономику ресурсов.

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
   cd sigil-of-the-unwilling
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
   Подробности (требования, правила, baseline) — в руководстве в этом README (раздел «Тестирование»).

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
sigil-of-the-unwilling/
├── game/                      # Godot-проект (корень `res://`)
│   ├── assets/                # Ресурсы игры
│   │   ├── ui/                # UI элементы (иконки, курсоры, виджеты)
│   │   ├── cursors/           # спрайты курсоров 6 режимов
│   │   ├── tilesets/          # Гексагональные тайлсеты
│   │   ├── data/              # JSON данные (заклинания, баланс)
│   │   ├── PROVENANCE.md      # Реестр происхождения ассетов (строка на файл)
│   │   └── ...                # Спрайты, аудио, шрифты
│   ├── scenes/                # Сцены Godot
│   ├── scripts/               # Исходный код GDScript (autoload/, core/,
│   │                          #   systems/, entities/, world/, city/, ui/ ...)
│   ├── image-clone/           # Лаборатория генерации ассетов (очередь, эталоны)
│   ├── tests/                 # Тесты (gdUnit4); прогон: tests/run_all.sh
│   ├── tools/                 # Инструменты проекта, в т.ч. ui_kit/ — генераторы
│   │                          #   виджет-графики (host-Python, не res://)
│   ├── project.godot          # Конфигурация проекта
│   └── run_tests.sh           # Скрипт запуска тестов
├── docs/                      # Obsidian-vault документации (GDD, ADR, журнал)
├── scripts/                   # Репозиторные гейты и сверщики (host-Python)
├── openspec/                  # Спецификации и открытые изменения OpenSpec
├── reference/                 # Референс-комплект — носитель вердиктов (D-192)
├── .pi/                       # Промпты и навыки агента
│   ├── prompts/               #   /opsx-* (propose, apply, update, archive, ...)
│   └── skills/ui-grid-review/ #   единственный местный навык: замеры кадров UI
├── battle-demo/               # Движковый демо-стенд (вне игры; судьба — Q-M139)
└── tmp/                       # Временные файлы (в git — только заглушка)
```

Граница `scripts/` ↔ `game/tools/` несущая: первое — host-Python, который судит
репозиторий (`docs/`, `openspec/`, git-индекс, `.github/`), второе — инструменты
самого Godot-проекта. Python внутри `res://scripts/` не живёт: он попадает в
чужой неймспейс и теряет покрытие `test_compile_all`. Состав корня сверяется
машиной — `python3 scripts/check_repo_layout.py`.

## 🛠️ Разработка

### Открытые изменения (OpenSpec Changes)

Проект использует методологию [OpenSpec](https://github.com/Fission-AI/OpenSpec) для управления изменениями:

| Изменение | Статус | Описание |
|-----------|--------|----------|
| `world-hex-cell-art` | 🚧 34/36 | Арт гексагональной клетки поля |
| `world-map-scene-slicing` | 🚧 12/38 | Нарезка сцены карты мира на носители |
| `repo-structure-cleanup` | 🚧 70/93 | Разрез состава корня: переезды, гейты, удаление бойлплейта |
| `remove-campaign-mechanic` | 📋 6/30 | Снятие механики кампании |

Список — это каталоги `openspec/changes/` кроме `archive/`; сводённые спеки
лежат в `openspec/specs/`, закрытые изменения — в `openspec/changes/archive/`.

### Создание нового изменения

```bash
# Создайте директорию для изменения
mkdir -p openspec/changes/<change-name>/

# Добавьте proposal.md и specs/
# Следуйте шаблону из существующих изменений
```

### Запуск инструментов разработки

```bash
# Генерация иконок ресурсов (21 PNG 32×32 по формуле арт-библии §7.1)
cd game && python3 tools/gen_resource_icons.py

# Кадр ОДНОЙ сцены для шага разработки (без MCP-сервера и порта, ~0.4 с)
godot --path game -s res://tools/shot_scene.gd -- --scene=res://scenes/main_menu.tscn --out=/tmp/shot.png

# Диагностика (регистры кампейн-запасов)
godot --headless --path game -s res://tools/diag_stocks_registers.gd
```

Валидация `data/spells.json` отдельным инструментом больше не запускается: после
`c90bf2d8` (снесены stand-alone тулзы) она живёт только как проверка юнит-теста
`tests/unit/core/test_spells_json.gd` на носителе `tests/helpers/spell_validation/`.

### Тестирование

Проект использует фреймворк **gdUnit4 6.2.1** для тестирования. Аддон
`game/addons/gdunit4/` не трекается в git — перед прогоном установите его из
репозитория вендора (полная инструкция: [инструкция ниже](#тестирование)):

```bash
cd game
git clone --depth 1 --branch v6.2.1 https://github.com/MikeSchulze/gdUnit4.git /tmp/gdunit4-install
cp -r /tmp/gdunit4-install/addons/gdunit4 addons/gdunit4
rm -rf /tmp/gdunit4-install
```

```bash
# Полный прогон (gdUnit4 + MCP + структурные проверки) — единственная точка входа
cd game && bash run_tests.sh

# Срез — быстрая обратная связь вместо «проверю потом»; НЕ основание для push (D-224)
cd game && bash run_tests.sh --tier=smoke   # ~9 с: критичный путь (tests/smoke/)
cd game && bash run_tests.sh --tier=fast    # ~2 мин: весь gdUnit4 кроме tests/slow/

# Только gdUnit4 (headless)
cd game && godot --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests
```

Подробное руководство (требования, структура, правила именования, baseline,
известные skip) — в руководстве в этом README (раздел «Тестирование»).

## 📚 Документация

Дизайн-документация игры (GDD) живёт в [`docs/`](docs/) — это Obsidian-vault:

| Документ | Содержание |
|---|---|
| [00-overview](docs/00-overview.md) | High Concept / Elevator Pitch |
| [00-glossary](docs/00-glossary.md) | Глоссарий — единая терминология |
| [01-core-loop](docs/01-core-loop.md) | Core Loop |
| [02-mechanics](docs/02-mechanics.md) | Механики и системы (+ 02b–02g: биномы, Знаки, классы, город, социум, hex) |
| [03-progression](docs/03-progression.md) | Прогрессия и мета-цикл |
| [04-narrative](docs/04-narrative.md) | Нарратив / Сеттинг / Тон |
| [05-content](docs/05-content.md) | Контент-пайплайн |
| [06-economy](docs/06-economy.md) | Экономика и баланс |
| [07-ui-ux](docs/07-ui-ux.md) | UI/UX flow |
| [08-tech](docs/08-tech.md) | Технический стек и платформы |
| [09-risks](docs/09-risks.md) | Риски и открытые вопросы |
| [MVP-scope](docs/MVP-scope.md) | MVP Scope |
| [QUESTIONS](docs/QUESTIONS.md) | Открытые вопросы к дизайнеру |
| [BANK](docs/BANK.md) | Банк контента |
| [dev-tickets](docs/dev-tickets.md) | Dev Tickets — MVP |

Техническая документация разработки:

- [AGENTS.md](AGENTS.md) — инструкции для AI-агентов
- [Спецификации OpenSpec](openspec/specs/) — технические спецификации
- [Система магии](game/assets/data/spells.json) — данные заклинаний

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

- Следуйте стилю GDScript из [официальной документации Godot](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- Добавляйте тесты для новых функций

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
