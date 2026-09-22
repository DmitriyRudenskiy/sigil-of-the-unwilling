# Design: team-romance-roleplay

## Context

Существующее (см. proposal.md — Why):
- `Follower` (scripts/entities/Follower.gd): uid, name, race, path, archetype, trait_ids, stat_modifiers, abilities. **Нет пола и ориентации.**
- `HeroBuildProfile.sex` ("male"/"female") выбирается на экране создания, но `HeroStatsComponent.apply_build` **не копирует** его — пол теряется.
- `FollowerSystem.recruit(city, hero, rng)` — рекрут из PopUnit FOLLOWER, ролл расы/класса/черт через `RaceClassRegistry` + `TraitRegistry` (seed-able).
- `SuccessionController.select_successor` — наследник = первый/рандомный последователь того же пути.
- `GameEventBus` (singleton) — шина событий игры; `Settings` (autoload) — настройки; `CharismaEvents` — паттерн «static + set_rng» для детерминированных событий.
- UI: `HeroStatusPanel` (вкладка героя), `decision_panel.gd` (готовый паттерн панели выбора), `CharacterCreationUI` (уже есть SexOption).
- Диалоговой системы нет. Контент-данные лежат в `assets/data/*.json` + GDScript-реестрах (`scripts/data/`).

## Goals / Non-Goals

**Goals:**
- Полноценный ролевой пласт: отношения герой↔последователь и последователь↔последователь, романтика с браком, ревность/конфликты, диалоги с выбором и последствиями.
- Пассивные эффекты: боевой дух, верность/предательство, приоритет наследования.
- Детерминизм (seed сессии) и сериализация в сейв с назад-совместимостью.
- Данные сцен — в JSON (контент расширяется без кода).

**Non-Goals:**
- Отношения с NPC города (не-последователи) — только команда героя.
- Визуальная анимация сцен (портреты, VHS-сцены) — текстовые сцены в панели.
- Гомо-/транс-идентичности за бинарный пол — только male/female + ориентация.
- Влияние на фракции/репутацию города (только внутренняя команда).
- AI-генерация реплик — только данные сцен.

## Decisions

### D1. Где хранить состояние отношений
**Решение:** новый компонент героя `HeroRelationshipsComponent` (паттерн HeroComponent, как `HeroFollowersComponent`):
- `pairs: Dictionary` — ключ `"hero-<uid>"` → `{bond, trust, romance, stage, spouse: bool}` для герой↔последователь
- `duos: Dictionary` — ключ `"<uid_a>:<uid_b>"` (uid_a < uid_b) → `{bond, trust, jealousy_to: int}` для последователь↔последователь
- `orientations: Dictionary` — uid → "hetero"/"homo"/"bi" (скрытая)

**Альтернативы:** (а) поля на самом `Follower` — отклонено: Follower — чистый RefCounted-данный объект, а отношения — состояние пары, не свойство одного; (б) отдельный autoload — отклонено: это персональное состояние героя, как и followers.

`Follower.gender: StringName` добавляется в сам объект (пол — свойство персонажа, а не пары).

### D2. Пол героя
`HeroStatsComponent.sex: String = "male"`, копируется в `apply_build` из `HeroBuildProfile.sex`. В сейв — через существующую сериализацию статов. Старые сейвы: дефолт "male".

### D3. Модель связей и стадии
- bond −100…+100 (старт 0), trust 0…100 (старт 50), romance 0…100 (старт 0, растёт только при совместимой ориентации).
- Стадии вычисляются, а не хранятся (кроме spouse — это факт, не вычисляемое): `stage_of(bond)` → stranger/friend/close_friend; `romance_stage(romance)` → none/flirt/relationship/engaged/married. Переходы детектит тик по сравнению с кэшем прошлой стадии → событие `relationship_stage_changed`.
- Брак: при romance ≥ 100 сцена-свадьба → `spouse = true` (неотменяемо; смерть супруга → вдовство, новый брак невозможен — упрощение, open Q).

### D4. Ориентация
Поле `orientation` на `Follower` (StringName: hetero/homo/bi), роллится в `FollowerSystem.recruit` через session RNG: 60/20/20. Совместимость: `compatible(hero_sex, follower_sex, orientation)`. Несовместимо → romance не растёт (клин в `RelationshipSystem.modify`), романтические реплики скрыты фильтром.

### D5. Тик и события
`RelationshipSystem` (RefCounted, паттерн CharismaEvents: static + `set_rng`):
- `process_turn(hero, relationships)` — вызывается в конце хода героя (там же, где `_end_turn` в BalanceProbe / CityTurnProcessor для мира):
  1. пассивный рост bond +1/ход за «совместное выживание» (герой жив, последователь в команде)
  2. проверка верности: trust < 20 → r20 < trust/10 → предательство (сцена + уход)
  3. ревность: для duos, где jealousy_to = hero и romance_a ≥ 50 → если romance_b ≥ 50 → событие ревности (однократно на пару, флаг `jealousy_fired`)
  4. конфликты: bond < −30 → r20 < 3 → сцена конфликта (примирение: cha-проверка d20+cha/2 vs 12; разрыв: уход)
- События → `GameEventBus` (новые сигналы: `relationship_stage_changed`, `romance_event(kind, uid)`, `follower_betrayal(uid)`, `marriage(uid)`) → UI показывает сцену.

### D6. Диалоги: формат данных
`assets/data/team_dialogs/*.json` — граф узлов:
```json
{
  "id": "talk_friend",
  "entry": "n1",
  "nodes": {
    "n1": {
      "speaker": "follower",
      "lines": [
        {"text": "…", "cond": {"sex_f": "male", "path": ["cleric"]}},
        {"text": "…", "cond": {"min_bond": 30}}
      ],
      "choices": [
        {"text": "…", "tier": "pg", "cond": {"min_cha": 14},
         "effects": [{"bond": 10}, {"trust": 5}], "next": "n2"},
        {"text": "…", "tier": "adult", "adult_alt": "n2_pg",
         "cond": {"romance": 50, "orientation_compatible": true},
         "effects": [{"romance": 10}], "next": "n3"}
      ]
    }
  }
}
```
- `cond`: sex_h/sex_f (пол героя/последователя), race, path, trait, min_bond/min_trust/min_romance, stage, orientation_compatible, min_cha/min_wis и т.д.
- `effects`: bond/trust/romance (дeltas), stat (перманент), buff (временный, ходы), event (имя сцены), item.
- Выбор сцены: `TeamDialogSystem.pick_dialog(follower, context)` — детерминированный выбор по стадиям (stranger → talk_stranger, friend → talk_friend, romance → romance_<stage>), фолбэк — общий `talk_generic`.
- **Альтернатива:** GDScript-реестры (как quest_templates) — отклонено: диалоги — контентный пласт, JSON редактируется без пересборки скриптов, паттерн assets/data уже есть (buildings.json, races_classes.json).

### D7. Контент-тиры
`Settings` (autoload) получает `content_adult: bool = false` (persist в user://settings). Фильтр в `TeamDialogSystem`: вариант с tier=adult виден только при content_adult; если у варианта задан `adult_alt` (узел-заглушка pg) — показывается он. Adult-сцены (после брака) — отдельные JSON-файлы с префиксом `adult_`.

### D8. Пассивные эффекты
- **Боевой дух**: `HeroCombatComponent`/расчёт боевых бонусов героя получает `morale_bonus = clampi(avg_bond/20, -2, 3)` к атаке и обороне (средний bond по всем последователям; пусто → 0).
- **Верность**: см. D5.2. Предательство = уход + событие + опционально сражение (если hero ранен — open Q, базово: только уход).
- **Наследование**: `SuccessionController.select_successor` — сортировка кандидатов: spouse того же пути → bond ≥ 60 (по убыванию bond) → остальные (по uid, как сейчас).

### D9. UI
- `HeroStatusPanel`: новая вкладка «Команда» — список последователей: имя, пол, раса/путь, иконка стадии (сердце/щит/молния), bond/trust/romance-бары, кнопка «Поговорить».
- `TeamDialogScreen.tscn` — окно: портрет-заглушка (иконка), имя, реплика, список вариантов (RichText), индикатор последствий (подсказка «+привязанность»). Закрывается Esc.
- Сцены-события (ревность/свадьба/предательство) — тот же `TeamDialogScreen`, но блокирующий режим (до выбора).
- Паттерн — `decision_panel.gd` (уже есть).

### D10. Детерминизм и тесты
- Один session RNG: `RelationshipSystem.set_rng(rng)` (паттерн CharismaEvents); рекрут — уже seed-able через `FollowerSystem.recruit(..., rng)`.
- GdUnit4: модель связей (старт/клин/степени), ориентация, ревность, предательство, наследование, фильтры диалогов, эффекты, контент-гейт, сериализация, детерминизм (2 прогона = идентично).
- MCP e2e: рекрут → диалог (bond↑) → друг → (romance-линия с совместимым полом) → брак → spouse в наследовании; adult-гейт (вкл/выкл).

## Risks / Trade-offs

- [Сложность состояния: 3 числа × N пар + duo-матрица] → сериализация компактная (только ненулевые duo), тесты на round-trip.
- [Диалоги JSON без валидатора — опечатка в cond ломает сцену] → `TeamDialogData.validate()` при загрузке (warn + фолбэк на generic), тест на валидацию.
- [Романтика может «зависнуть» (romance не растёт без диалогов)] → пассивный рост romance +1/ход при bond ≥ 60 и совместимой ориентации (герой «завоёвывает» временем), иначе только диалоги.
- [Предательство ранней игры ломает прогон] → trust старт 50, порог 20, шанс trust/10 — ранние предательства маловероятны; autopilot-роли не страдают (bond-бонус только помогает).
- [Adult-контент в репозитории] → текстовый, без изображений; гейт по настройкам; реплики-заглушки pg всегда есть.
- [vдовство/второй брак] → упрощено: один брак навсегда (open Q).

## Migration Plan

1. Расширение сейва: новый блок `relationships` в SaveData + `sex` в статах — старые сейвы загружаются с дефолтами (миграция не требует действий).
2. Откат: фича изолирована (новые файлы + точечные правки recruit/apply_build/select_successor/боевой бонус) — revert коммитов не ломает сейвы (лишние поля игнорируются десериализаторами).

## Open Questions

- Второй брак после смерти супруга: разрешить (remarriage) или нет? (не блокирует реализацию — флаг в данных)
- Предательство в бою (переход на сторону врага) или только уход из команды? (базово: уход)
- Лимит размера команды для отношений (все последователи или доп. капа)? (базово: все)
