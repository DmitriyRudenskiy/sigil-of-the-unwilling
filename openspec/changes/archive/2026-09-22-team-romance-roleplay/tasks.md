# Tasks: team-romance-roleplay

## 1. Основы: пол и модель данных

- [x] 1.1 `Follower.gender` (StringName, дефолт male) + сериализация (назад-совместимо)
- [x] 1.2 `HeroStatsComponent.sex` — копировать из `HeroBuildProfile.sex` в `apply_build`, сериализация в сейв (старые сейвы → male)
- [x] 1.3 `Follower.orientation` (hetero/homo/bi) — ролл в `FollowerSystem.recruit` через session RNG (60/20/20), сериализация
- [x] 1.4 `HeroRelationshipsComponent` (паттерн HeroComponent): pairs (hero↔follower), duos (follower↔follower), сериализация/десериализация, round-trip-тест

## 2. RelationshipSystem: связи, стадии, тик

- [x] 2.1 `RelationshipSystem` (static + set_rng): modify() с клином (romance только при совместимой ориентации), старт пар (bond 0, trust 50, romance 0)
- [x] 2.2 Стадии: stage_of(bond), romance_stage(romance), детект переходов → событие `relationship_stage_changed`
- [x] 2.3 Совместимость ориентаций: compatible(hero_sex, follower_sex, orientation), гейт романтики
- [x] 2.4 process_turn(): пассивный bond +1, верность (trust < 20 → r20 предательство), ревность (duo, однократно), конфликты (bond < −30 → сцена)
- [x] 2.5 Подключение тика в конец хода героя + сигналы GameEventBus (relationship_stage_changed, romance_event, follower_betrayal, marriage)
- [x] 2.6 GdUnit4: модель связей, ориентация, стадии, ревность, предательство, детерминизм (2 прогона = идентично)

## 3. Пассивные эффекты

- [x] 3.1 Боевой дух: morale_bonus = clampi(avg_bond/20, −2, 3) в расчёт боевых бонусов героя
- [x] 3.2 Наследование: `SuccessionController.select_successor` — приоритет spouse → bond ≥ 60 (по убыванию) → остальные
- [x] 3.3 Предательство: уход из команды + событие + возврат в население города (если герой в городе)
- [x] 3.4 GdUnit4: боевой дух, приоритет наследования, предательство

## 4. Диалоги: данные и движок

- [x] 4.1 Формат JSON сцен + `TeamDialogData` (загрузка, validate() с warn+фолбэк, тесты валидации)
- [x] 4.2 `TeamDialogSystem`: фильтры cond (sex_h/sex_f, race, path, trait, min_bond/trust/romance, stage, orientation_compatible, min_cha/wis), выбор сцены по стадиям (фолбэк generic)
- [x] 4.3 Эффекты выборов: bond/trust/romance deltas, stat, buff (временный), event, item; применение через RelationshipSystem
- [x] 4.4 Контент-тиры: Settings.content_adult (persist), фильтр adult-вариантов, pg_fallback-заглушки
- [x] 4.5 Стартовые сцены: talk_stranger, talk_friend, talk_generic, romance_flirt, romance_relationship, proposal, wedding + jealousy/conflict/betrayal (JSON + pg-тексты)
- [x] 4.6 GdUnit4: фильтры, эффекты, контент-гейт, детерминизм выбора вариантов (26 тестов)

## 5. UI

- [x] 5.1 HeroStatusPanel: секция «Команда» (список, пол, путь, иконки стадий, бары bond/trust/romance, кнопка «Поговорить»)
- [x] 5.2 `TeamDialogScreen.tscn` + скрипт: реплика, варианты, индикатор последствий, Esc; блокирующий режим (pause) для сцен-событий
- [x] 5.3 Сцены-события: ревность, конфликт, предательство, предложение, свадьба (GameEventBus/pending_scenes → TeamDialogScreen, контент в JSON)
- [x] 5.4 Settings: переключатель adult-контента (UI + persist + переводы ru/en)

## 6. Интеграция и e2e

- [x] 6.1 Рекрут: `FollowerSystem.recruit` генерирует gender (по имени) + orientation; панель команды обновляется
- [x] 6.2 MCP e2e: рекрут → диалог (bond↑) → Друг → romance-линия (совместимый пол) → Помолвка → Брак → spouse в наследовании
- [x] 6.3 MCP e2e: adult-гейт (выкл → adult-варианты скрыты; вкл → видны)
- [x] 6.4 MCP e2e: ревность (два последователя, romance к герою) + предательство (trust < 20)
- [x] 6.5 Регрессия: полный прогон GdUnit4 (1705+) зелёный + сейв/загрузка с отношениями
