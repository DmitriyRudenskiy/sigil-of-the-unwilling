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

## P2 — 2026-10-15, блок STYLE: глянец

Правка одна, `CONTENT` не трогается. Гипотеза: глянец — не потолок модели, а
следствие того, что в плюсе стояла воздушная кисть, а в минусе не было ни
спекуляра, ни матовости.

```
STYLE+   ... flat local colour with soft volumetric shading over it, matte finish
STYLE−   no glossy highlights, no specular sheen, no plastic sheen, no airbrush,
         no 3d render look
```

Cel-плоскость — не цель: `soft volumetric shading` остаётся, семейство живёт на
мягкой светотени. Каждое отрицание защищено строкой словаря
([style-card.md](style-card.md#отрицания-каждое-обязано-ссылаться-на-строку-словаря)).

Лестница эскалации, чтобы глянец не стал вечным redraw:

| Шаг | Рычаг | Переход |
| --- | --- | --- |
| P2 | `STYLE−` / `STYLE+` | не двинулось → P2b |
| P2b | `PARAMS`: CFG ниже, сэмплер | высокий CFG сам даёт рендерный пересыщенный вид; логируется отдельным рычагом |
| P2c | Референс-кондишенинг (IP-Adapter / img2img с низким denoise) | фактура через картинку, не через слова |
| — | Чекпоинт | решение уровня батча, не юнита |

Стоп-условие: две итерации без движения по глянцу на двух юнитах →
`gloss-ceiling` для модели, метка и переход к следующему юниту.

Замер P2 — на двух юнитах сразу, иначе не отличить «промпт чинит глянец» от
«чекпоинт глянцует на этом юните»:

| Версия | Образец | Блок | Вердикт стиля | Глянец |
| --- | --- | --- | --- | --- |
| v4 | IMG-001 | P1 | почти | был |
| v5 | IMG-001 | P2 | почти | не сдвинулся |
| v2 | IMG-002 | P0 | — | был |
| v3 | IMG-002 | P2 | почти | стало глаже |

Условие остановки выполнено: две попытки на двух юнитах, движения нет, на одном
— регресс. Зафиксирован `gloss-ceiling` для промпт-рычага, юниты помечены
`model-ceiling`.

Следующий рычаг — `PARAMS`, и он поганит юнит-бюджет: CFG у qwen21 уже 1.0
(ниже некуда), остаются сэмплер (`euler`), планировщик (`simple`) и шаги (25).
Это решение уровня серии, а не юнита: параметр меняет все 60 кадров. В
журнале нет измерения «рычаг прогона», поэтому P2b нельзя запустить, не
смешав его с правками промпта в одном счётчике версий. Отложено до решения
владельца.
