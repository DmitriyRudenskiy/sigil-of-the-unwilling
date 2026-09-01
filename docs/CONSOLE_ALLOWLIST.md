# Console Allowlist — допустимый вывод в консоли Godot

Единый источник «чистоты» для гейтов operability-verification
(`game/tools/shell/run_operability.sh`) и console-hygiene
(`game/tools/shell/check_console_clean.sh`). Runner читает первый столбец
таблицы как набор ERE; найденные строки не считают предупреждением.

> **Ложные срабывания (app-логгер)** — лог самого приложения, намеренные
> проверки, **не** регрессия кода. Они жёстко вырезаются из скана
> (`EXCLUDE_RE` в `run_operability.sh`) независимо от allowlist:
>
> - `ERROR: [color=gray][Save ][/color] SaveManager: parse error …`
>   (SaveManager пробует распарсить битый/тестовый save)
> - `WARNING: Unknown template: NONEXISTENT`
>   (TemplateEngine проверяет неизвестный шаблон)
> - `ERROR: Failed loading resource: … File not found` (SaveManager)

## Паттерны (ERE, первый столбец)

### App-логгер (намеренные проверки, не регрессия)

| Pattern | Description |
|---|---|
| `Unknown template` | app-логгер TemplateEngine (намеренная проверка) |
| `SaveManager: parse error` | app-логгер SaveManager (намеренная проверка) |

### App-предупреждения из юнит-тестов (легитимные)

Юнит-тесты намеренно подают некорректные данные, чтобы проверить graceful
деградацию. Приложение логирует их через `push_warning`. Тесты 4696/4696
passed — это ожидаемый вывод, а не предупреждения Godot. Допустимы:

| Pattern | Description |
|---|---|
| `: unknown slot` | HeroInventory: обработка неизвестного слота |
| `SettingsScreen: .* not found` | SettingsScreen: закрытие отсутствующего экрана |
| `Season: некорректный месяц` | Season: фолбэкс на весну для некорректного месяца |
| `DemographicTurnProcessor: registry не задан` | тест без setup() |
| `SoundManager: no file` | SoundManager: отсутствует аудиофайл |
| `SoundManager: unknown .* cue` | SoundManager: неизвестный cue |
| `SoundManager: bus '.*' not found` | SoundManager: авто-загрузка, сценарии operability |
| `WARNING: [1-9] ObjectDB instances were leaked at exit` | Godot 4.7 headless: недетерминированный teardown-шум при N≤20 (зонд 200×register/free → 0; реальный leak — сотни объектов) |
| `WARNING: 1[0-9] ObjectDB instances were leaked at exit` | то же, N=10–19 |
| `WARNING: 20 ObjectDB instances were leaked at exit` | то же, N=20
  гоняются на графическом (OpenGL) сервере отображения, а не headless —
  AudioServer еще не содержит кастомных шин `SFX`/`Music`. Не регрессия,
  не связано с изменяемым кодом (проявляется и без правок) |

### Предупреждения импорта изображений (легитимные, pre-existing)

`WARNING: Loaded resource as image file …` для `res://assets/ui/hero/*.png`
и `res://assets/ui/icons/*.png`. Причина: все PNG проекта импортированы как
`CompressedTexture2D`, поэтому `load()` возвращает не `ImageTexture`, и в
`MainMenu.gd` (~53) и `ArtifactInventoryScreen.gd` (`_tex()`, ~473) срабатывает
`Image.load_from_file()`-фолбэкс для получения сырого `Image` под ресайм.

Это **pre-existing** поведение UI-кода (не связано со spell-depth / другими
изменяемыми областями), проявляется на чистом checkout, на экспорт-пайплайн не
влияет (рабочий путь — `CompressedTexture2D`). Ресайм в коде требует сырого
`Image`, поэтому без глобальной смены типа импорта (увеличит размер экспорта)
фолбэкс необходим. Не регрессия, не связано с изменяемым кодом.

| Pattern | Description |
|---|---|
| `Loaded resource as image file` | фолбэкс `Image.load_from_file` в UI (MainMenu/ArtifactInventoryScreen), pre-existing |

## Как добавить

1. Запусти `bash game/tools/shell/run_operability.sh`.
2. Если предупреждение попало в отчёт, но оно легитимно — добавь его ERE
   в таблицу выше (или, если это app-логгер — в блок «Ложные срабывания»).
3. Перепуски `run_operability.sh` — предупреждение перестанет валить гейт.

Настоящие ошибки (`SCRIPT ERROR`, `Invalid call`, `Failed to load script`,
`Could not find type …`, `Parse error`, `E 0:` и т.д.) **в allowlist не
попадают** — их нужно чинить, а не исключать.
