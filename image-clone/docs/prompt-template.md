---
title: Промпт-шаблон лаборатории
tags: [image-clone, prompt]
status: draft
date: 2026-10-15
---

# Промпт-шаблон

Кадрируется по блокам. За итерацию правится ровно один блок — иначе сравнение
вердиктов невалидно. Слова для `STYLE+` / `STYLE−` берутся из
[style-card.md](style-card.md), те же, что и в вердикте.

## Блоки

```
STYLE+   <техника, которую надо получить>
STYLE−   <чего не должно быть>
CONTENT  <кто, во что одет, поза, предметы, текст>
PARAMS   <модель, размер, сид>
```

Сборка промпта: `STYLE+` и `STYLE−` ложатся в слои стиля спека лаборатории
(`spec.json`: `variants[].style`), `CONTENT` — в `subject` очереди, `PARAMS` —
модель и сид прогона.

## P0 — до лаборатории

```
STYLE+   hand-painted comic game illustration with visible soft brush strokes,
         matte gouache-like skin texture, subtle canvas grain, warm midtones
STYLE−   no ink outlines, no glossy plastic sheen
CONTENT  (subject образца)
PARAMS   qwen21, 512x512
```

## P1 — 2026-10-15, блок STYLE

Правка: убрано `no ink outlines` и `subtle canvas grain`, добавлен контур и
плоский локальный цвет по словарю стиля.

```
STYLE+   hand-painted comic game illustration with visible soft brush strokes,
         matte gouache-like skin texture, warm midtones, clean dark warm-brown
         contour line of even thickness around every shape, thinner interior
         lines of the same hue for muscles, seams and folds, every shape fully
         outlined, flat local colour with soft airbrushed shading over it,
         matte painted surface
STYLE−   no glossy plastic sheen, no 3d render look
```

Замеры:

| Версия | Образец | Блок | Вердикт стиля |
| --- | --- | --- | --- |
| v3 | IMG-001 | P0 | нет — контур лепится светотенью |
| v4 | IMG-001 | P1 | почти — контур появился, глянец остался |

## P2 — не заполнено

Кандидат: убрать глянец. Проверять только `STYLE−`/`STYLE+` по одной фразе,
`CONTENT` IMG-001 не трогать.
