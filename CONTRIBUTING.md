# CONTRIBUTING.md - Руководство по внесению вклада

Спасибо за интерес к проекту Fission AI! Мы приветствуем вклад от сообщества.

## 📋 Как внести вклад

### 1. Используем OpenSpec

Наш проект следует методологии [OpenSpec](https://github.com/Fission-AI/OpenSpec). Все изменения должны проходить через этот процесс:

#### Шаг 1: Создайте предложение (Proposal)

```bash
mkdir -p openspec/changes/<название-изменения>/
```

Создайте файл `proposal.md` со следующей структурой:

```markdown
# Proposal: <название-изменения>

## Why

Опишите проблему или необходимость изменений.

## What Changes

Опишите какие изменения будут внесены.

## Capabilities

### New Capabilities
- Список новых возможностей

### Modified Capabilities
- Список изменяемых возможностей

## Impact

- **Новые файлы**: список новых файлов
- **Изменённые файлы**: список изменяемых файлов
- **Тесты**: какие тесты нужны

## Non-goals

Что НЕ входит в scope этого изменения.
```

#### Шаг 2: Добавьте спецификации

Создайте директорию `specs/` внутри вашей папки изменения:

```bash
mkdir -p openspec/changes/<название-изменения>/specs/<компонент>/
```

Добавьте файл `spec.md` с техническими деталями реализации.

#### Шаг 3: Реализуйте изменения

- Следуйте существующим паттернам кода
- Добавляйте тесты для новых функций
- Обновляйте документацию

#### Шаг 4: Создайте Pull Request

- Ссылка на proposal в openspec/
- Описание изменений
- Скриншоты/видео для визуальных изменений
- Результаты тестов

## 🎯 Области для вклада

### Код игры
- Новые игровые механики
- Улучшение существующих систем
- Исправление багов
- Оптимизация производительности

### Графика и ассеты
- Иконки ресурсов и зданий
- Курсоры
- UI элементы
- Тайлсеты для карты

### Тестирование
- Unit-тесты для новых функций
- Интеграционные тесты
- Регрессионные тесты

### Документация
- Улучшение README
- Примеры использования
- Туториалы
- Переводы

## 📝 Стандарты кода

### GDScript

Следуйте [официальному styleguide Godot](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):

```gdscript
# Классы: PascalCase
class_name PlayerController

# Переменные: snake_case
var player_health: int = 100

# Константы: UPPER_SNAKE_CASE
const MAX_SPEED := 10.0

# Функции: snake_case
func calculate_damage(base_damage: float, multiplier: float) -> float:
    return base_damage * multiplier

# Приватные функции: _prefix
func _process(delta: float) -> void:
    pass

# Сигналы: snake_case
signal health_changed(new_value: int)
```

### Структура файлов

- Один класс на файл
- Имя файла должно совпадать с именем класса
- Используйте `.gd` для скриптов, `.tscn` для сцен

### Комментарии

```gdscript
# Плохо
# двигает игрока
player.position += velocity * delta

# Хорошо
# Применяем скорость к позиции игрока с учётом deltaTime
player.position += velocity * delta
```

### Тесты

Используйте фреймворк gdUnit4 (аддон `game/addons/gdunit4/` не трекается в git —
инструкция по установке из репозитория вендора: [doc/testing.md](doc/testing.md#установка-gdunit4)):

```gdscript
extends GdUnitTestSuite

func test_player_takes_damage() -> void:
    var player = Player.new()
    var initial_health = player.health

    player.take_damage(10)

    assert_int(player.health).is_equal(initial_health - 10)
```

## 🧪 Запуск тестов

Перед первым прогоном установите аддон gdUnit4 (см. ссылку выше):

```bash
cd game
git clone --depth 1 --branch v6.2.1 https://github.com/MikeSchulze/gdUnit4.git /tmp/gdunit4-install
cp -r /tmp/gdunit4-install/addons/gdunit4 addons/gdunit4
rm -rf /tmp/gdunit4-install
```

```bash
cd game

# Все тесты
./run_tests.sh

# Полный прогон (gdUnit4 + MCP + структурные проверки)
bash tests/run_all.sh

# Конкретный тест
godot --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/test_<name>.gd
```

## 🔀 Ветвление

- `main` - основная ветка, стабильная версия
- `develop` - ветка разработки
- `feature/<name>` - новые функции
- `fix/<name>` - исправления багов
- `docs/<name>` - документация

## 📬 Pull Request Process

1. Fork репозиторий
2. Создайте ветку (`git checkout -b feature/amazing-feature`)
3. Закоммитьте изменения (`git commit -m 'Add amazing feature'`)
4. Запушьте (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

### Чеклист PR

- [ ] Код следует стандартам проекта
- [ ] Добавлены тесты для новых функций
- [ ] Все тесты проходят
- [ ] Документация обновлена
- [ ] Proposal создан в openspec/ (для значительных изменений)
- [ ] Нет предупреждений компиляции

## 💬 Коммуникация

- Используйте Issues для багов и предложений
- Discussions для общих вопросов
- В комментариях кода будьте конструктивны

## 🎨 Вклад в графику

Для создания иконок и ассетов:

1. Используйте существующие генераторы как пример:
   - `scripts/build/gen_resource_icons.gd`
   - `scripts/build/gen_artifact_icons.gd`

2. Форматы файлов:
   - PNG для спрайтов (прозрачность поддерживается)
   - SVG для масштабируемой графики
   - Размер иконок: 32x32 или 64x64

3. Стиль:
   - Единая цветовая палитра (см. `ThemeConfig.gd`)
   - Плоский дизайн с лёгкими тенями
   - Хорошая читаемость в малом размере

## 📚 Ресурсы

- [Документация Godot](https://docs.godotengine.org/)
- [OpenSpec Guidelines](https://github.com/Fission-AI/OpenSpec)
- [gdUnit4](https://github.com/MikeSchulze/gdUnit4)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

## ❓ Вопросы?

Не стесняйтесь задавать вопросы в Issues или Discussions. Мы стараемся отвечать в течение 48 часов.

---

Спасибо за ваш вклад! 🎮✨
