# Листы зданий — промпт для генерации (3×4, по 12 зданий на лист)

Шаблон — лист варваров (3×4, ряды = graded-ось, колонки = ортогональная ось,
общие признаки названы один раз). Перенесено на здания: **ряды = уровень
застройки I/II/III** (в `game/assets/data/buildings.json` у 8 зданий ровно три
уровня, у остальных это лестница вида), **колонки = 4 разных здания**. 12
ячеек = 4 здания × 3 уровня, все 12 различимы силуэтом.

Канон, из которого взяты формулировки ракурса, света и палитры —
`docs/13-art-bible.md` §9.1 (изометрик 30–35°, камера сверху-слева-спереди,
объём тоном а не обводкой, тёплая полоса `C′`, один холодный кластер ≤ 8%,
без подставки-тени). Слои `frame`/`style` перекочевали из
`scripts/concept_art/spec.json` (`categories.buildings`). Разрезка листа на
кадры — `game/tools/pixelart/sheet_to_units.py` (канвас ячейки 1024, объект
75% ячейки), отсюда «контракт листа» в конце.

## Общий блок (пишется один раз на лист)

```
A 3x4 grid RPG sprite sheet of 12 distinct buildings, 2D game asset, flat
colors, pure white background. All 12 buildings are drawn under one strictly
unified camera and scale: isometric three-quarter view from the upper left,
about 30 degrees, the same eye height and the same zoom in every cell, the
building base sitting on one shared baseline at the bottom of its cell, the
whole object inside 75% of the cell with an empty margin around it, nothing
touching the cell border, no two buildings overlapping. One warm afternoon key
light from the upper left in every cell; volume reads through tone steps, not
through outlines; soft dark contour only where an edge needs it. Warm
storybook palette of terracotta roof, straw thatch, timber and pale plaster,
matte painterly surfaces, at most one small cold cluster per building (glass,
metal, shade). No cast shadow, no ground plate, no scenery, no text.

Top row (tier I, crude): rough timber frame with daub infill, patched thatch
or split-shingle roof, unglazed slit openings, plain earth floor, one small
prop, no trim and no signage.
Middle row (tier II, built): cut-stone lower storey with timber-framed upper
storey, tiled roof with a ridge cap, small leaded windows with iron frames,
one hanging sign or banner, a paved apron at the door.
Bottom row (tier III, monumental): dressed stone walls, tall steep roof with
gilded ridge trim, arched glazed windows, a banner on a pole, one cold glass
or metal accent, steps up to the door.
```

Дальше по ячейкам — только различия здания и уровня. Слово `building`, ракурс,
свет и палитра не повторяются: они заданы выше.

## Лист B1 — продовольствие и добыча

Колонки: 1 ферма · 2 мельница · 3 пекарня · 4 рудник.

```
Top row (tier I):
1st is a strip farm with a low thatched barn, two fenced crop beds and a leaning rake.
2nd is a small post mill on four posts, four bare canvas-less sails and a stubby loading ramp.
3rd is a bread oven hut with a bulb clay oven dome, a wide low door and a cooling rack under a lean-to.
4th is a mine pit head with a timber headframe, a single rope drum and a pile of grey rubble.

Middle row (tier II):
1st is a two-storey farmstead with a tiled barn, a threshing floor and a cart parked at the gate.
2nd is a tower mill with a boat-shaped cap, four cloth sails and a millstone by the door.
3rd is a bakery with a tall tiled bakehouse, a chimney stack, a round oven mouth and a dough trough outside.
4th is a mine works with a stone shaft house, a horse-gin drum, iron rails and stacked timber props.

Bottom row (tier III):
1st is a manor grange with a long tiled barn, a granary on stilts, a stone dovecote and a scythe rack.
2nd is a mill complex with a stone tower, a capped sail set, a sluice channel and a weigh-house at the base.
3rd is a guild bakery with a steep roof, two chimneys, a glazed service window and a bread market stall in front.
4th is a mine hall with a dressed-stone headframe, a counterweighted cage winch, glazed lamp windows and an ore tally board.
```

## Лист B2 — жильё и знание

Колонки: 1 хижина · 2 особняк · 3 училище · 4 библиотека.

```
Top row (tier I):
1st is a one-room squat hut with a thatch roof hanging to the ground, a single low door and a smoke hole.
2nd is a laird's hall with a long timber shell, a raised dais window and a stockade of rough stakes.
3rd is a teaching shed with a thatch roof, a bench on trestles and slate tablets leaning outside.
4th is a book shed with a thatch roof, a locked chest of scrolls behind bars and a reading bench in the shade.

Middle row (tier II):
1st is a cottage with a tiled roof, a plaster chimney, a shuttered window and a vegetable plot.
2nd is a merchant house with two storeys, a jettied upper floor, a bay window and a courtyard well.
3rd is a schoolhouse with a tiled roof, a bellcote, rows of mullioned windows and a lesson board by the door.
4th is a scriptorium with a tiled roof, tall arched windows, a writing gallery and a book wheel in the yard.

Bottom row (tier III):
1st is a longhouse with a stone plinth, a steep tiled roof, a carved door surround and a drying gallery.
2nd is a town mansion with dressed stone walls, a hipped roof, a two-storey bay and a heraldic panel over the gate.
3rd is a college with a quadrangle of arcaded windows, a lecture hall oriel and a bell tower.
4th is a library with a barrel-vaulted reading hall, clerestory glazing, a stone stair and a map globe on a plinth.
```

## Лист B3 — военное

Колонки: 1 казармы · 2 стрельбище · 3 стены · 4 конюшня.

```
Top row (tier I):
1st is a barracks hut with a thatch roof, a rack of spears outside and a sleeping loft hatch.
2nd is an archery butts clearing with a straw target on a trestle, a rope gallery and a quiver stand.
3rd is a palisade segment with sharpened stakes, a wall-walk of lashed planks and a wooden gate.
4th is a lean-to stable with a thatch roof, two paddock pens and a feed trough.

Middle row (tier II):
1st is a barracks block with a tiled roof, a stone armoury wing, a drill yard and a weapon rack by the gate.
2nd is a range house with a tiled roof, a butts wall, a marked lane and a prize board on posts.
3rd is a curtain wall segment with a wall-walk, two timber hoardings and an arched gate under a barbican beam.
4th is a stone stable with a tiled roof, a tack loft hatch, a mounting block and a paddock fence.

Bottom row (tier III):
1st is a barracks keep with dressed stone walls, a bannered hall, an armoury oriel and a parade ground with a standard.
2nd is a marksmen hall with a steep roof, a glazed gallery, a butts range with stone screens and a trophy board.
3rd is a bastion segment with a stone curtain, two flanking towers with conical roofs, machicolations and a portcullis.
4th is a stud farm with a stone range, a tiled loft, a covered mounting porch and a joust rail in the yard.
```

## Лист B4 — ремесло и торг

Колонки: 1 кузница · 2 рынок · 3 торговый пост · 4 таверна.

```
Top row (tier I):
1st is a smithy shed with a thatch roof, a clay forge hearth, a quench barrel and a bellows.
2nd is a market clearing with three trestle stalls, a cloth canopy and a crate stack.
3rd is a trade post with a timber counter, a stockade of stacked barrels and a weigh beam on posts.
4th is a tavern shed with a thatch roof, a bench under a canvas awning and a gourd rack.

Middle row (tier II):
1st is a forge with a tiled roof, a brick chimney, an anvil on a stump and a tool rack under a lean-to.
2nd is a market row with tiled stalls, a covered arcade, a market cross and a merchant scale.
3rd is a trading house with a tiled roof, a counting room window, a bonded cellar hatch and a cargo crane.
4th is an inn with two storeys, a tiled roof, a sign on a bracket, a stable loop and a hearth window.

Bottom row (tier III):
1st is a guild forge with a steep roof, two chimneys, a glazed showroom window and an armour display in the porch.
2nd is an exchange hall with a long arcaded front, a weigh-house oriel, a painted guild banner and a coin stone.
3rd is a trading hall with dressed stone walls, a customs oriel, a glazed sample window and a mooring ring at the apron.
4th is a coaching inn with a hipped roof, a gated courtyard, a bay common room and a painted sign over the steps.
```

## Лист B5 — святилища (оба требуют участка, `requires_site: true`)

Колонки: 1 великий храм на холме · 2 великий храм у воды · 3 древнее хранилище в скале · 4 древнее хранилище под руинами.

```
Top row (tier I):
1st is a hilltop shrine with a stone circle of standing stones, a fire pit and a stacked cairn.
2nd is a waterside shrine with a timber pier, a floating platform and a lantern post.
3rd is a cave-mouth vault with a timber shoring frame, a sealed stone drum and a torch bracket.
4th is a buried vault entry with a collapsed mound, a broken stair and a leaning marker stone.

Middle row (tier II):
1st is a hilltop temple with a stepped stone base, a columned porch, a roofed cella and a brazier pair.
2nd is a waterside temple with a stone quay, a columned porch over the water and a mooring stair.
3rd is a rock-cut vault with a carved façade, a sealed round door and two niches with offerings.
4th is a ruin vault with a rebuilt arch, a barrel rack, a masoned retaining wall and a lantern gutter.

Bottom row (tier III):
1st is a hilltop great temple with a wide stair, a forest of columns, a gilded roof and a reliquary chapel behind.
2nd is a great temple on a stone embankment with a monumental stair, a colonnised pier and a lighthouse lantern.
3rd is a mountain vault with a dressed-stone façade, a processional way, glazed lamp windows and a sealed treasury door.
4th is a vault under a ruined court with a vaulted gallery, a bronze-bound door, a surveyor's plumb and a sigil inlay.
```

## Негатив (один на все листы)

```
photorealism, photograph, gritty realism, desaturated muddy palette, text,
letters, numbers, labels, watermark, logo, grid lines, cell borders, frame,
table, collage, turnaround, multiple views of the same building, reference
sheet, scenery, landscape, background gradient, sky, ground plate, cast
shadow, drop shadow, reflection, aerial top-down view, front elevation,
fisheye perspective, mixed camera angles between cells, different scale
between cells, building cropped by the cell edge, buildings touching each
other, merged silhouettes, cluttered roof, thin spindly supports, interior
cutaway, blueprint, wireframe, 3d render, clay render, glossy plastic
```

## Контракт листа (иначе лист не разрежется)

| Требование | Почему |
| --- | --- |
| фон — чистый `#ffffff`, без рамок, сетки, подписей и номеров ячеек | резак бинаризует по яркости (`255 − min(RGB) > порога`), линия сетки становится «объектом» и ломает кластеры сёмен |
| ровно 3 ряда × 4 колонки, равные промежутки ≥ 10% ячейки | сетка ищется по кластерам центроидов; слипшиеся ряды дают `3×3` вместо `3×4` |
| здание целиком внутри своей ячейки, ≤ 75% её высоты, основание на общей базовой линии | канвас кадра 1024, юнит 768; вылезшее за край знамя = обрезанный кадр |
| соседние здания не соприкасаются и не перекрываются | касание склеивает два объекта в один компонент, ячейка отбрасывается |
| один и тот же ракурс, зум и свет во всех 12 ячейках | разный зум = разный масштаб в датасете, LoRA учит камеру вместо здания |
| светлый камень/металл не делать «почти белым» | `alpha_of()` считает почти-белое фоном; кадр по силуэту спасает замкнутый контур, но тонкий светлый шпиль всё равно теряет пиксели |

Запуск резак-проверки после генерации:

```sh
python3 game/tools/pixelart/sheet_to_units.py --dry-run лист.png   # вердикт по ячейкам
python3 game/tools/pixelart/sheet_to_units.py --crop лист.png --tight --flat --out <папка>/
```
