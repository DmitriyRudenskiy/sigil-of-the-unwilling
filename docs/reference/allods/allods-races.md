---
title: Allods Online: расы и промпты генерации
tags:
  - reference
  - allods
status: reference
date: 2026-10-16
---

> [warning] Референс — не канон Sigil
> Это референс чужой игры *Allods Online* — расы и промпты генерации изображений.
>
> **Источник:** `allods/races.md` концепт-вольта `/Users/user/sigil-of-the-unwilling-doc` (внешний каталог, не в git).
> **Получено:** 2026-10-16. **Сверка:** снято Q&A-чатом по официальной странице allods.ru, не вычитано.
> **Сверка:** расовый состав Sigil — Приложение А и [[02e3-races]]; этот файл их не подменяет ([[CONFLICTS]] К-14).
> **Статус:** справочник. Числа отсюда не переносятся в [[07-balance]] и баланс-конфиги
> иначе как решение владельца; расхождения с каноном — [[CONFLICTS]].

# Allods Online: расы и промпты генерации персонажей

> Источник: Q&A (шар DeepSeek) по официальной странице https://allods.ru/about.php?show=all-races. Задание: промпты для генерации изображений представителей каждой расы (мужской и женский, **белый фон**, **поза в три четверти вправо**).

## Фракции и расы

### Лига (союзники)

| Раса | Ключевые ценности | Взгляд на мир |
|------|-------------------|---------------|
| **Гибберлинги** | Свобода, Оптимизм, Дорога | Жизнь — веселье, смерть — обидно, счастье — свобода. Лига — привал, Империя — недоразумение, Астрал — дорога |
| **Канийцы** | Добро, Вера, Порядок | Жизнь — служение, смерть — отдых, счастье — награда. Лига — будущее, Империя — заблудшие овцы, Астрал — поле битвы |
| **Эльфы** | Удовольствие, Красота, Идеал | (краткое описание, без развёрнутых тезисов) |

### Империя (союзники)

| Раса | Ключевые ценности | Взгляд на мир |
|------|-------------------|---------------|
| **Хадаган** | Родина, Вождь, Победа | Жизнь — борьба, смерть — помеха, счастье — единство. Империя — Родина, Лига — атавизм, Астрал — реальность |
| **Орки** | Добыча, Ярость, Сила | Жизнь — соревнование, смерть — проигрыш, счастье — победа. Империя — мачеха, Лига — пища, Астрал — «хрен знает что» |

### Нейтральные / внефракционные

| Раса | Ключевые ценности | Взгляд на мир |
|------|-------------------|---------------|
| **Восставшие (нежить)** | Знание, Смерть, Идеал | Жизнь — смерть, смерть — бессмертие, счастье — мы. Империя — материал, Лига — тоже материал, Астрал — познаваемое |
| **Прайдены** | Жизнь, Честь, Гармония | Жизнь — выживание, смерть — рождение, счастье — охота. Лига — бесхвостые, Империя — ещё больше бесхвостых, Астрал — ничто |
| **Аэды** | Знание, Талант, Совершенство | Жизнь — дар, смерть — трагедия, счастье — творчество. Лига — один из путей, Империя — другой путь, Астрал — начало |

### Общие выводы (анализ источника)

1. **Чёткое фракционное деление**: каждая раса жёстко привязана к Лиге или Империи (кроме нейтральных); мировоззрение отражает идеологию фракции.
2. **Философский подход**: описание построено не на сухих характеристиках, а на мировоззренческих тезисах (жизнь, смерть, счастье, Астрал, противоположная фракция).
3. **Астрал как ключевая метафора**: у каждой расы Астрал трактуется по-своему — это не просто локация, а философская категория.
4. **Tone of voice**: ироничный, лёгкий стиль (особенно у орков и прайденов) — страница имиджевая, не энциклопедическая.
5. **Навигация**: страница — оглавление-тизер, у каждой расы ссылка «Всё самое интересное о…» на детальное описание.

## Физические особенности (финальная версия)

> По заданию промпты **без одежды и оружия** — нейросеть опирается только на физические отличительные черты.

⚠️ **Противоречие в источнике:** в первой ревизии ответов (см. «Первая ревизия промптов» ниже) внешность некоторых рас описана иначе: хадаган — как рептилоиды с чешуей и гребнями, восставшие — как скелеты с гниющей плотью, гибберлинги — как карлики в стимпанк-объектах. Финальная (пересмотренная) ревизия: хадаган — смуглые южные люди, восставшие — механические фигуры в масках, гибберлинги — покрытые пушистой шерстью. Ниже — финальная версия. ❓ Сверить с каноничным лором Allods.

### 1. Гибберлинги (Лига)
- **Телосложение:** очень низкий рост (карлики), коренастые, детские пропорции.
- **Особенности:** тело полностью покрыто густой пушистой шерстью.
- **Лицо:** круглое, детские черты, большие глаза, хитрая улыбка; у мужчин — небольшая борода.

### 2. Канийцы (Лига)
- **Телосложение:** люди среднего роста, плотного крепкого телосложения, сильные и статные.
- **Особенности:** кошачьи уши и длинный хвост.
- **Лицо:** человеческие черты, часто русые или рыжие волосы.

### 3. Эльфы (Лига)
- **Телосложение:** высокие, очень худые, модельная внешность, грация и изящество.
- **Особенности:** длинные заострённые уши — главный отличительный признак.
- **Лицо:** угловатое, аристократичное; глаза часто со «внеземным» свечением.

### 4. Хадаган (Империя)
- **Телосложение:** невысокие, жилистые, гибкие, поджарые.
- **Особенности:** люди южного типа; смуглая кожа, обычно чёрные волосы.
- **Лицо:** человеческие черты, более резкие, чем у канийцев.

### 5. Орки (Империя)
- **Телосложение:** огромные, мускулистые, массивные («гора мяса»).
- **Особенности:** зелёная кожа, большие выступающие клыки.
- **Лицо:** грубые, тяжёлые черты.

### 6. Восставшие (нежить, нейтральные)
- **Телосложение:** высокие, иссушенные, угловатая фигура.
- **Особенности:** тело в основном состоит из механических частей; лицо полностью скрыто маской.
- **Лицо:** технологичная маска без черт лица.

### 7. Прайдены (нейтральные)
- **Телосложение:** антропоморфные хищники; тело покрыто мехом, есть хвост.
- **Особенности:** зверолюди (волки, рыси, лисы, медведи и т.д.); голова — полностью звериная (морда).
- **Лицо:** звериная морда с ушами соответствующего животного.

### 8. Аэды (нейтральные)
- **Телосложение:** напоминают людей античности: сильные, грациозные, почти не стареющие.
- **Особенности:** большие белые крылья за спиной — главная отличительная черта.
- **Лицо:** красивые, идеальные человеческие черты.

## Промпты для генерации (финальная версия)

Единые параметры: белый фон, поворот вправо на три четверти, студийное освещение, без одежды и оружия.

### 1. Гибберлинги
- **Мужчина:** `Full-body shot of a short, stocky male humanoid creature, covered entirely in thick, fluffy fur, with a round childlike face, big eyes, and a playful smirk, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`
- **Женщина:** `Full-body shot of a short, stocky female humanoid creature, covered entirely in thick, fluffy fur, with a round childlike face and big bright eyes, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`

### 2. Канийцы
- **Мужчина:** `Full-body shot of a strong, stocky human male of medium height, with distinct feline cat ears on his head and a long feline tail, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`
- **Женщина:** `Full-body shot of a strong, stocky human female of medium height, with distinct feline cat ears on her head and a long feline tail, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`

### 3. Эльфы
- **Мужчина:** `Full-body shot of a tall, slender, and very lean male humanoid with long, sharply pointed elf ears and angular, aristocratic facial features, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`
- **Женщина:** `Full-body shot of a tall, slender, and graceful female humanoid with long, sharply pointed elf ears and delicate, aristocratic facial features, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`

### 4. Хадаган
- **Мужчина:** `Full-body shot of a short, wiry, and lean human male with dark, tanned skin and black hair, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`
- **Женщина:** `Full-body shot of a short, wiry, and lean human female with dark, tanned skin and black hair, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`

### 5. Орки
- **Мужчина:** `Full-body shot of a huge, incredibly muscular and massive humanoid with green skin and large, prominent tusks protruding from the mouth, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`
- **Женщина:** `Full-body shot of a huge, incredibly muscular and massive female humanoid with green skin and large, prominent tusks protruding from the mouth, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`

### 6. Восставшие
- **Мужчина:** `Full-body shot of a tall, gaunt, and angular humanoid figure, whose body is largely composed of mechanical parts and who wears a full face mask with no visible facial features, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`
- **Женщина:** `Full-body shot of a tall, gaunt, and angular female humanoid figure, whose body is largely composed of mechanical parts and who wears a full face mask with no visible facial features, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`

### 7. Прайдены
- **Мужчина:** `Full-body shot of a tall, anthropomorphic predator humanoid, with a full animal head (like a wolf or lynx), a body covered in fur, and a long tail, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`
- **Женщина:** `Full-body shot of a tall, anthropomorphic predator female humanoid, with a full animal head (like a wolf or lynx), a body covered in fur, and a long tail, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`

### 8. Аэды
- **Мужчина:** `Full-body shot of a strong, graceful, and athletic male humanoid with perfect, classical features, and large white feathered wings on his back, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`
- **Женщина:** `Full-body shot of a strong, graceful, and athletic female humanoid with perfect, classical features, and large white feathered wings on her back, standing in a three-quarters right turn, white background, studio lighting, fantasy character design, highly detailed.`

💡 Совет из источника: для единообразия стиля добавлять общий хвост к промпту (например, `same art style, high detail, 8k, photorealistic`); для Midjourney — параметры `--ar 2:3` (вертикальный портрет), `--v 6`.

## Первая ревизия промптов (устаревшая)

> Отклонена автором: нейросеть не знала названия рас (Gibberling и т.д.), а также в задании потребовалось **убрать одежду и оружие** («это база»). Сохранена для полноты источника. ⚠️ Внешность здесь отличается от финальной версии (см. примечание выше).

- **Гибберлинги:** коренастые, низкорослые (≈1,2 м), широкие носы, большие уши, густая растительность у мужчин; кожа, мех, стимпанк.
  - М: `full-body portrait of a male Gibberling, short stocky dwarf-like creature, leather vest and boots, battle axe on back, red hair and beard, turned three-quarters to the right, white background, studio lighting, fantasy art, detailed.`
  - Ж: `full-body portrait of a female Gibberling, short stocky dwarf-like creature, leather corset and skirt, holding a crossbow, chestnut hair in braids, turned three-quarters to the right, white background, studio lighting, fantasy art.`
- **Канийцы:** человекоподобные с кошачьими ушами и хвостом, гибкие, грациозные; лёгкие доспехи, кожа, капюшон.
  - М: `full-body portrait of a male Kanian, humanoid with cat ears and long tail, lean, light leather armor and cloak, dagger at belt, dark hair, yellow eyes, turned three-quarters right, white background.`
  - Ж: `full-body portrait of a female Kanian, elegant, cat ears and tail, tight leather outfit and high boots, bow on back, red hair, green eyes, turned three-quarters right, white background.`
- **Эльфы:** высокие, стройные, светловолосые, бледная кожа, острые уши; лёгкие ткани, серебряные украшения.
  - М: `full-body portrait of a male Elf, tall and slender, long blond hair, pointed ears, elegant silver fabric clothes and cape, holding a staff, turned three-quarters right, white background, studio lighting.`
  - Ж: `full-body portrait of a female Elf, graceful, long blond hair, pointed ears, light dress with golden patterns and tiara, turned three-quarters right, white background.`
- **Хадаган:** рептилоиды, чешуйчатая кожа, хвост, гребни; тяжёлые доспехи из металла и костей.
  - М: `full-body portrait of a male Hadagan, lizard-like, dark green scales, massive tail, crest on head, heavy plate armor and two-handed sword, turned three-quarters to the right, white background.`
  - Ж: `full-body portrait of a female Hadagan, lizard-like, brown scales, tail, smaller crest, leather armor and spear, turned three-quarters to the right, white background.`
- **Орки:** массивные, зелёная кожа, клыки, мощные челюсти; грубая кожа, металлические накладки.
  - М: `full-body portrait of a male Orc, huge, green skin, prominent tusks, leather armor with iron spikes, holding a giant axe, turned three-quarters to the right, white background.`
  - Ж: `full-body portrait of a female Orc, muscular, green skin, small tusks, fur cloak and heavy boots, mace on shoulder, turned three-quarters to the right, white background.`
- **Восставшие:** скелетоподобные, гнилая плоть, светящиеся глаза, лохмотья, рваные доспехи.
  - М: `full-body portrait of a male Undead (Vosstavshiy), skeleton with decaying flesh, glowing blue eyes, tattered black cloak and old breastplate, holding a skull-staff, turned three-quarters to the right, white background.`
  - Ж: `full-body portrait of a female Undead, skeleton with remnants of hair and skin, glowing red eyes, tattered dress and dagger, turned three-quarters to the right, white background.`
- **Прайдены:** зверолюди (львы/тигры), мех, кошачья морда, хвост; лёгкие доспехи из кожи и металла.
  - М: `full-body portrait of a male Praidan, anthropomorphic lion, golden fur, mane, tail, leather armor with metal plates, wielding a greatsword, turned three-quarters to the right, white background.`
  - Ж: `full-body portrait of a female Praidan, anthropomorphic tigress, striped fur, tail, light leather armor and bow, turned three-quarters to the right, white background.`
- **Аэды:** похожи на эльфов с большими белыми крыльями, светящиеся; белая/золотая магическая одежда.
  - М: `full-body portrait of a male Aed, slender, blond hair, pointed ears, large white feathered wings, golden light armor with glow, holding a wand, turned three-quarters to the right, white background.`
  - Ж: `full-body portrait of a female Aed, graceful, silver hair, white wings, white dress and gold jewelry, holding a glowing orb, turned three-quarters to the right, white background.`
