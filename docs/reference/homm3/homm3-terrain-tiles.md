---
title: HoMM III: промпты террейн-тайлов
tags:
  - reference
  - homm3
status: reference
date: 2026-10-16
---

> [warning] Референс — не канон Sigil
> Это референс чужой игры *Heroes of Might and Magic III* — **промпты** текстур местности, не ассеты.
>
> **Источник:** `textures/terrain-tiles.md` концепт-вольта `/Users/user/sigil-of-the-unwilling-doc` (внешний каталог, не в git).
> **Получено:** 2026-10-16. **Сверка:** не сверялось.
> **Адресат:** [[13-art-bible]] §9.1 «Здания и тайлы» и «Префикс-промпт генерации новых ассетов»; это промпты, а не ассеты ([[CONFLICTS]] К-19).
> **Статус:** справочник. Числа отсюда не переносятся в [[07-balance]] и баланс-конфиги
> иначе как решение владельца; расхождения с каноном — [[CONFLICTS]].

# HOMM3: промпты текстур местности (террейн-тайлы)

> Источник: Q&A (шар DeepSeek) о генерации тайловых текстур местности в стиле *Heroes of Might and Magic 3*. Исходный контекст — задание «Create a 3×4 grid of 12 units (Human Barbarian, Human Bard, Human Cleric, Human Druid, Human Fighter, Human Monk, Human Paladin, Human Ranger, Human Rogue, Human Sorcerer, Human Wizard, Human Artificer) in full size on a white background in the style of the game Heroes of Might and Magic 3»; задача — перенести формат на текстуры биомов и пограничных состояний.

💡 **О источнике:** в вопросах «биом» напечатано как «бином» (опечатка, ассистент указал на это); конец 4-го вопроса заминирован раскладкой клавиатуры — смысл понятен из контекста: перечислить типы вариаций внутри одного биома (трава, трава с кустом, трава с двумя кустами, трава с камнем, трава с камнем слева…).
⚠️ **Эволюция требований:** первые промпты (базовый набор, отдельные тайлы) — **на белом фоне**; начиная с вариаций травяного биома — **без белого фона, тайл занимает всю квадратную область** (итоговое требование).

## 1. Базовый набор: 4 биома + 8 переходов (сетка 3×4)

**Задание (рус):**

> Создай набор тайловых текстур для стратегической карты в стиле игры Heroes of Might and Magic 3. Нужны текстуры разных биомов и их пограничных состояний.
>
> Формат: сетка 3×4 из 12 тайлов. Каждый тайл — полноразмерный, вид сверху, без интерфейса, на белом фоне, в едином масштабе и перспективе HOMM3.
>
> Список тайлов: 1. Трава — базовый тайл; 2. Песок; 3. Снег; 4. Болото; 5. Переход «трава–песок»; 6. Переход «трава–снег»; 7. Переход «трава–вода»; 8. Переход «песок–вода»; 9. Переход «снег–камень»; 10. Переход «болото–грязь»; 11. Переход «лава–камень»; 12. Переход «дорога–трава».
>
> Все переходы должны выглядеть естественно, с рваными/органическими краями, как в оригинальных картах HOMM3.

**English prompt:**

> Create a 3×4 grid of 12 terrain texture tiles in the style of Heroes of Might and Magic 3. The tiles should represent different biomes and their boundary transition states. Full-size tiles, top-down view, white background, no UI, consistent perspective and scale.
> Tiles:
> 1. Grass base
> 2. Sand base
> 3. Snow base
> 4. Swamp base
> 5. Grass-to-sand transition
> 6. Grass-to-snow transition
> 7. Grass-to-water transition
> 8. Sand-to-water transition
> 9. Snow-to-rock transition
> 10. Swamp-to-dirt transition
> 11. Lava-to-rock transition
> 12. Road-to-grass transition
> All transitions should have natural, organic edges like classic HOMM3 map tiles.

**Расширенный вариант сетки (англ, из ответа «готовые задания»):**

> Create a 3×4 grid of 12 full-size terrain texture tiles in the style of Heroes of Might and Magic 3. Top-down view, white background, no UI, consistent perspective and scale.
> Tiles:
> 1 – Grass base
> 2 – Sand base
> 3 – Snow base
> 4 – Swamp base
> 5 – Grass-to-sand transition
> 6 – Grass-to-snow transition
> 7 – Grass-to-water transition
> 8 – Sand-to-water transition
> 9 – Snow-to-rock transition
> 10 – Swamp-to-dirt transition
> 11 – Lava-to-rock transition
> 12 – Road-to-grass transition
> All transitions must have natural, organic edges like classic HOMM3 map tiles. High detail, hand-painted fantasy style, muted earthy colors, crisp edges, no text.

💡 В базовой сетке — только 4 «чистых» биома (трава, песок, снег, болото), хотя в переходах фигурируют также вода, камень, лава, дорога, грязь. Их отдельные базовые тайлы не даны (покрываются разделами вариаций ниже).

## 2. Отдельные тайлы (из базового набора)

### Базовые биомы

**Трава**
> A single square tile of lush green grass terrain for a fantasy strategy map, top-down view, in the style of Heroes of Might and Magic 3. Hand-painted texture, vibrant but natural colors, small details like tiny flowers and grass blades, no grid, no UI, white background around the tile, full tile size, crisp edges.

**Песок**
> A single square tile of sandy desert terrain for a fantasy strategy map, top-down view, in the style of Heroes of Might and Magic 3. Hand-painted texture, warm beige and light brown tones, subtle dunes and small pebbles, no grid, no UI, white background around the tile, full tile size.

**Снег**
> A single square tile of snowy terrain for a fantasy strategy map, top-down view, in the style of Heroes of Might and Magic 3. Hand-painted texture, white and pale blue shades, soft snowdrifts, slight sparkle, no grid, no UI, white background around the tile.

**Болото**
> A single square tile of swamp terrain for a fantasy strategy map, top-down view, in the style of Heroes of Might and Magic 3. Hand-painted texture, dark green and brown muddy colors, small puddles, twisted roots, no grid, no UI, white background around the tile.

### Переходы (два биома на одном тайле)

**Трава–песок**
> A single square tile showing a natural transition between green grass and sandy desert terrain, for a fantasy strategy map, top-down view, in the style of Heroes of Might and Magic 3. The border between the two biomes is organic and irregular, hand-painted, no grid, no UI, white background around the tile.

**Трава–снег**
> A single square tile showing a natural transition between green grass and snowy terrain, fantasy strategy map, top-down view, HOMM3 style. Organic irregular border between grass and snow, hand-painted, white background around tile.

**Трава–вода**
> A single square tile showing a natural transition between green grass and water (riverbank or lake shore), fantasy strategy map, top-down view, HOMM3 style. The water edge is irregular with foam or sand, hand-painted, white background.

**Песок–вода**
> A single square tile showing a natural transition between sandy beach and water, fantasy strategy map, top-down view, HOMM3 style. Irregular shoreline, hand-painted, white background.

**Снег–камень**
> A single square tile showing a natural transition between snowy ground and grey rocky mountain terrain, fantasy strategy map, top-down view, HOMM3 style. Irregular border, hand-painted, white background.

**Болото–грязь**
> A single square tile showing a natural transition between swamp and dark muddy dirt terrain, fantasy strategy map, top-down view, HOMM3 style. Irregular muddy border, hand-painted, white background.

**Лава–камень**
> A single square tile showing a natural transition between glowing lava and dark volcanic rock, fantasy strategy map, top-down view, HOMM3 style. The lava edge is bright orange with cracks, hand-painted, white background.

**Дорога–трава**
> A single square tile showing a dirt road crossing green grass, fantasy strategy map, top-down view, HOMM3 style. The road has irregular edges, wheel ruts and small stones, hand-painted, white background.

## 3. Биом «Трава» (12 вариаций)

Типы тайлов в рамках одного биома:

1. Трава базовая (чистая)
2. Трава с одним кустом
3. Трава с двумя кустами
4. Трава с большим кустом
5. Трава с камнем (по центру)
6. Трава с камнем слева
7. Трава с камнем справа
8. Трава с мелкими камнями
9. Трава с цветами
10. Трава с высокой травой / пучками
11. Трава с лужей
12. Трава с проплешиной земли

**Промпт сетки (англ):**

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same grass biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, muted earthy colors, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain grass
> 2 – Grass with one small bush
> 3 – Grass with two small bushes
> 4 – Grass with a large bush
> 5 – Grass with a central rock
> 6 – Grass with a rock on the left side
> 7 – Grass with a rock on the right side
> 8 – Grass with scattered small stones
> 9 – Grass with small flowers
> 10 – Grass with tall grass tufts
> 11 – Grass with a small puddle
> 12 – Grass with a dirt patch

**Промпт сетки (рус):**

> Создай сетку 3×4 из 12 полноразмерных тайлов текстур местности, все — вариации одного биома «трава», в стиле Heroes of Might and Magic 3. Вид сверху, ортографическая перспектива, рисованный фэнтезийный стиль, приглушённые землистые цвета, высокая детализация. Без белого фона, без рамки, без сетки, без интерфейса, без текста — каждый тайл занимает всю свою квадратную область.
> Тайлы:
> 1 – Чистая трава
> 2 – Трава с одним небольшим кустом
> 3 – Трава с двумя небольшими кустами
> 4 – Трава с большим кустом
> 5 – Трава с камнем по центру
> 6 – Трава с камнем слева
> 7 – Трава с камнем справа
> 8 – Трава с россыпью мелких камней
> 9 – Трава с мелкими цветами
> 10 – Трава с пучками высокой травы
> 11 – Трава с небольшой лужей
> 12 – Трава с участком голой земли

### Отдельные тайлы травы

**С одним кустом**
> A single square tile of grass terrain with one small bush, top-down orthographic view, in the style of Heroes of Might and Magic 3. Hand-painted fantasy texture, muted colors, full tile, no white background, no border, no UI, no text. The bush is on the grass, natural look.

**С двумя кустами**
> A single square tile of grass terrain with two small bushes, top-down orthographic view, HOMM3 style, hand-painted, full tile, no background, no border.

**С камнем по центру**
> A single square tile of grass terrain with a central grey rock, top-down view, HOMM3 style, hand-painted, full tile, no white background, no border.

**С камнем слева**
> A single square tile of grass terrain with a grey rock on the left side, top-down view, HOMM3 style, hand-painted, full tile, no white background, no border.

**С камнем справа**
> A single square tile of grass terrain with a grey rock on the right side, top-down view, HOMM3 style, hand-painted, full tile, no white background, no border.

**С россыпью мелких камней**
> A single square tile of grass terrain with several small scattered stones, top-down view, HOMM3 style, hand-painted, full tile, no white background, no border.

**С цветами**
> A single square tile of grass terrain with small colorful flowers, top-down view, HOMM3 style, hand-painted, full tile, no white background, no border.

**С высокой травой**
> A single square tile of grass terrain with tufts of taller grass, top-down view, HOMM3 style, hand-painted, full tile, no white background, no border.

**С лужей**
> A single square tile of grass terrain with a small muddy puddle, top-down view, HOMM3 style, hand-painted, full tile, no white background, no border.

**С проплешиной земли**
> A single square tile of grass terrain with a patch of bare dirt, top-down view, HOMM3 style, hand-painted, full tile, no white background, no border.

## 4. Бесшовные тайлы (seamless) — шаблон

> Create a seamless tileable texture of [название биома или перехода] for a fantasy strategy game map, in the style of Heroes of Might and Magic 3. The texture must tile perfectly without visible seams, top-down orthographic view, hand-painted fantasy style, high detail, no border, no UI, no text.

Пример для травы:

> Create a seamless tileable texture of lush green grass for a fantasy strategy game map, HOMM3 style. Must tile perfectly, top-down orthographic view, hand-painted, high detail, no border, no UI.

## 5. Дополнительные параметры для улучшения результата

- **Стиль:** `hand-painted fantasy style, muted colors, pre-rendered 3D look, like Heroes of Might and Magic 3`.
- **Разрешение:** `high resolution, 1024x1024 px` или `ultra detailed`.
- **Перспектива:** `orthographic top-down view` (вид строго сверху без искажений).
- **Без сетки:** `no grid lines, no frame, no border, no text, no watermark`.

💡 Можем адаптировать промпты под конкретную нейросеть (Midjourney, Stable Diffusion, DALL-E) — предложение из источника.

## 6. Биом «Песок» (24 тайла = 2 сетки по 12)

1. Песок базовый (чистый)
2. Песок с рябью (волны)
3. Песок с отпечатками следов
4. Песок с камнем
5. Песок с двумя камнями
6. Песок с маленьким камнем
7. Песок с кактусом
8. Песок с мертвым деревом
9. Песок с колючим кустом
10. Песок с ракушкой
11. Песок с куском кости
12. Песок с трещинами
13. Песок с участком гравия
14. Песок с мокрой полосой (у воды)
15. Песок с мелкими камешками
16. Песок с большой ямой
17. Песок с небольшой дюной
18. Песок с кучей песка
19. Песок с камнем и тенью
20. Песок с камнем и кустом
21. Песок с кактусом и камнем
22. Песок с колючками
23. Песок с песчаником (плоский камень)
24. Песок с участком глины

### Промпт 1 (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same sand biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, warm beige and sandy tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain sand
> 2 – Sand with ripples (waves)
> 3 – Sand with footprint tracks
> 4 – Sand with a single rock
> 5 – Sand with two rocks
> 6 – Sand with a small pebble
> 7 – Sand with a cactus
> 8 – Sand with a dead tree
> 9 – Sand with a thorny bush
> 10 – Sand with a seashell
> 11 – Sand with a bone fragment
> 12 – Sand with cracked earth
> 13 – Sand with a patch of gravel
> 14 – Sand with a wet band (near water)
> 15 – Sand with scattered pebbles
> 16 – Sand with a large crater
> 17 – Sand with a small dune
> 18 – Sand with a sand mound
> 19 – Sand with a rock and shadow
> 20 – Sand with a rock and a bush
> 21 – Sand with a cactus and a rock
> 22 – Sand with thorns
> 23 – Sand with a flat sandstone slab
> 24 – Sand with a patch of clay

### Промпт 2 (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same sand biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, warm beige and sandy tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 13 – Sand with a patch of gravel
> 14 – Sand with a wet band (near water)
> 15 – Sand with scattered pebbles
> 16 – Sand with a large crater
> 17 – Sand with a small dune
> 18 – Sand with a sand mound
> 19 – Sand with a rock and shadow
> 20 – Sand with a rock and a bush
> 21 – Sand with a cactus and a rock
> 22 – Sand with thorns
> 23 – Sand with a flat sandstone slab
> 24 – Sand with a patch of clay

## 7. Биом «Снег» (24 тайла = 2 сетки по 12)

1. Снег базовый (чистый)
2. Снег с ветровыми гребнями
3. Снег со следами от лап
4. Снег с камнем
5. Снег с двумя камнями
6. Снег с маленьким камнем
7. Снег с снежной сосной
8. Снег с мёртвым деревом
9. Снег со снегом по колено (глубокий снег)
10. Снег с трещинами (наледь)
11. Снег с участком льда
12. Снег с ледяным глыбой
13. Снег со следами от копыт
14. Снег с оленем (следы)
15. Снег с катком (уплотнённый)
16. Снег со снегом и инеем
17. Снег с сугробом
18. Снег со снежной ямой
19. Снег со снежным заносом
20. Снег со снежком
21. Снег со снежинкой
22. Снег со следами от когтей
23. Снег со снегом и веткой
24. Снег со снегом и камнем

### Промпт 1 (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same snow biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, white and pale blue tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain snow
> 2 – Snow with wind-driven ridges
> 3 – Snow with animal paw prints
> 4 – Snow with a rock
> 5 – Snow with two rocks
> 6 – Snow with a small stone
> 7 – Snow with a snow-covered pine
> 8 – Snow with a dead tree
> 9 – Snow with deep drifts
> 10 – Snow with ice cracks
> 11 – Snow with a patch of ice
> 12 – Snow with an ice boulder
> 13 – Snow with hoof prints
> 14 – Snow with deer tracks
> 15 – Snow with packed snow
> 16 – Snow with frost
> 17 – Snow with a snowdrift
> 18 – Snow with a snow pit
> 19 – Snow with a snowbank
> 20 – Snow with a snowball
> 21 – Snow with a snowflake
> 22 – Snow with claw marks
> 23 – Snow with a branch
> 24 – Snow with a rock

### Промпт 2 (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same snow biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, white and pale blue tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 13 – Snow with hoof prints
> 14 – Snow with deer tracks
> 15 – Snow with packed snow
> 16 – Snow with frost
> 17 – Snow with a snowdrift
> 18 – Snow with a snow pit
> 19 – Snow with a snowbank
> 20 – Snow with a snowball
> 21 – Snow with a snowflake
> 22 – Snow with claw marks
> 23 – Snow with a branch
> 24 – Snow with a rock

## 8. Биом «Болото» (24 тайла = 2 сетки по 12)

1. Болото базовое (чистое)
2. Болото с рябью воды
3. Болото с лилиями
4. Болото с камнем
5. Болото с двумя камнями
6. Болото с маленьким камнем
7. Болото с кустом
8. Болото с мертвым деревом
9. Болото с корнями
10. Болото с тиной
11. Болото с пузырями
12. Болото с трещинами
13. Болото с участком грязи
14. Болото с лужей
15. Болото с мхом
16. Болото с кочкой
17. Болото с топким участком
18. Болото с веткой
19. Болото с листом
20. Болото с камнем и кустом
21. Болото с камнем и мхом
22. Болото с корнями и камнем
23. Болото с мертвым деревом и кустом
24. Болото с участком ила

### Промпт 1 (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same swamp biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, dark green and brown muddy tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain swamp
> 2 – Swamp with water ripples
> 3 – Swamp with water lilies
> 4 – Swamp with a rock
> 5 – Swamp with two rocks
> 6 – Swamp with a small stone
> 7 – Swamp with a bush
> 8 – Swamp with a dead tree
> 9 – Swamp with roots
> 10 – Swamp with mud
> 11 – Swamp with bubbles
> 12 – Swamp with cracks
> 13 – Swamp with a patch of dirt
> 14 – Swamp with a puddle
> 15 – Swamp with moss
> 16 – Swamp with a mound
> 17 – Swamp with a soft spot
> 18 – Swamp with a branch
> 19 – Swamp with a leaf
> 20 – Swamp with a rock and a bush
> 21 – Swamp with a rock and moss
> 22 – Swamp with roots and a rock
> 23 – Swamp with a dead tree and a bush
> 24 – Swamp with a patch of sludge

### Промпт 2 (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same swamp biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, dark green and brown muddy tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 13 – Swamp with a patch of dirt
> 14 – Swamp with a puddle
> 15 – Swamp with moss
> 16 – Swamp with a mound
> 17 – Swamp with a soft spot
> 18 – Swamp with a branch
> 19 – Swamp with a leaf
> 20 – Swamp with a rock and a bush
> 21 – Swamp with a rock and moss
> 22 – Swamp with roots and a rock
> 23 – Swamp with a dead tree and a bush
> 24 – Swamp with a patch of sludge

## 9. Биом «Вода» (12 тайлов)

1. Вода базовая (чистая)
2. Вода с рябью
3. Вода с волнами
4. Вода с камнем
5. Вода с двумя камнями
6. Вода с маленьким камнем
7. Вода с кустом
8. Вода с мертвым деревом
9. Вода с корнями
10. Вода с тиной
11. Вода с пузырями
12. Вода с трещинами

### Промпт (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same water biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, deep blue and green tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain water
> 2 – Water with ripples
> 3 – Water with waves
> 4 – Water with a rock
> 5 – Water with two rocks
> 6 – Water with a small stone
> 7 – Water with a bush
> 8 – Water with a dead tree
> 9 – Water with roots
> 10 – Water with mud
> 11 – Water with bubbles
> 12 – Water with cracks

## 10. Биом «Камень» (10 тайлов)

1. Камень базовый (чистый)
2. Камень с трещинами
3. Камень с камнем
4. Камень с двумя камнями
5. Камень с маленьким камнем
6. Камень с мхом
7. Камень с кустом
8. Камень с мертвым деревом
9. Камень с корнями
10. Камень с грязью

### Промпт (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same stone biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, grey and brown rocky tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain stone
> 2 – Stone with cracks
> 3 – Stone with a rock
> 4 – Stone with two rocks
> 5 – Stone with a small stone
> 6 – Stone with moss
> 7 – Stone with a bush
> 8 – Stone with a dead tree
> 9 – Stone with roots
> 10 – Stone with mud

⚠️ В источнике промпт говорит «3×4 grid of 12», но тайлов перечислено 10 (остаток шаблона; в реальности — 2×5 или 3×4 с двумя пустыми слотами).

💡 **О нумерации:** в источнике нумерация списков не последовательна (песок/снег/болото — с 1; камень — 15–24; вода — 25–36; лава — 37–48; дорога — 49–60; грязь — 61–72). В этом файле все списки пронумерованы с 1; названия тайлов сохранены дословно.

## 11. Биом «Лава» (12 тайлов)

1. Лава базовая
2. Лава с трещинами
3. Лава с камнем
4. Лава с двумя камнями
5. Лава с маленьким камнем
6. Лава с дымом
7. Лава с углями
8. Лава с искрами
9. Лава с камнем и дымом
10. Лава с камнем и углями
11. Лава с камнем и искрами
12. Лава с камнем и дымом

### Промпт (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same lava biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, bright orange and red lava tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain lava
> 2 – Lava with cracks
> 3 – Lava with a rock
> 4 – Lava with two rocks
> 5 – Lava with a small stone
> 6 – Lava with smoke
> 7 – Lava with embers
> 8 – Lava with sparks
> 9 – Lava with a rock and smoke
> 10 – Lava with a rock and embers
> 11 – Lava with a rock and sparks
> 12 – Lava with a rock and smoke

## 12. Биом «Дорога» (12 тайлов)

1. Дорога базовая
2. Дорога с колеями
3. Дорога с двумя колеями
4. Дорога с камнем
5. Дорога с двумя камнями
6. Дорога с маленьким камнем
7. Дорога с кустом
8. Дорога с мертвым деревом
9. Дорога с корнями
10. Дорога с грязью
11. Дорога с пузырями
12. Дорога с трещинами

### Промпт (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same road biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, brown and grey dirt tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain road
> 2 – Road with ruts
> 3 – Road with two ruts
> 4 – Road with a rock
> 5 – Road with two rocks
> 6 – Road with a small stone
> 7 – Road with a bush
> 8 – Road with a dead tree
> 9 – Road with roots
> 10 – Road with mud
> 11 – Road with bubbles
> 12 – Road with cracks

## 13. Биом «Грязь» (12 тайлов)

1. Грязь базовая
2. Грязь с колеями
3. Грязь с двумя колеями
4. Грязь с камнем
5. Грязь с двумя камнями
6. Грязь с маленьким камнем
7. Грязь с кустом
8. Грязь с мертвым деревом
9. Грязь с корнями
10. Грязь с грязью
11. Грязь с пузырями
12. Грязь с трещинами

### Промпт (англ)

> Create a 3×4 grid of 12 full-size terrain texture tiles, all variations of the same dirt biome, in the style of Heroes of Might and Magic 3. Top-down orthographic view, hand-painted fantasy style, dark brown muddy tones, high detail. No white background, no frame, no grid lines, no UI, no text — each tile fills its entire square area.
> Tiles:
> 1 – Plain dirt
> 2 – Dirt with ruts
> 3 – Dirt with two ruts
> 4 – Dirt with a rock
> 5 – Dirt with two rocks
> 6 – Dirt with a small stone
> 7 – Dirt with a bush
> 8 – Dirt with a dead tree
> 9 – Dirt with roots
> 10 – Dirt with mud
> 11 – Dirt with bubbles
> 12 – Dirt with cracks

## 14. Общие рекомендации

- Держите стиль последовательным во всех промптах: не меняйте ключевые слова стиля от промпта к промпту.
- Не добавляйте белый фон и рамки — каждый тайл должен занимать всю квадратную область.
- Если тайлы получаются слишком разными по стилю, добавьте: `consistent art style, same lighting, same color palette`.
- Для переходов используйте ключевое слово `organic irregular border`.
- Если генератор не делает корректную сетку, можно генерировать отдельные тайлы и собирать их вручную.

## Сводка

| Биом | Тайлов | Сеток 3×4 |
|------|--------|-----------|
| Базовый набор (4 биома + 8 переходов) | 12 | 1 |
| Трава | 12 | 1 |
| Песок | 24 | 2 |
| Снег | 24 | 2 |
| Болото | 24 | 2 |
| Вода | 12 | 1 |
| Камень | 10* | 1 |
| Лава | 12 | 1 |
| Дорога | 12 | 1 |
| Грязь | 12 | 1 |
| **Итого** | **156** | **14** |

\* в промпте заявлено 12, перечислено 10 (см. ⚠️ выше).

💡 В источнике также предложено: «Если нужны другие биомы (например, лёд, подземелье, адский ландшафт) или переходы — просто замените названия в промптах. Могу также адаптировать промпты под конкретную нейросеть (Midjourney, Stable Diffusion, DALL-E).»
