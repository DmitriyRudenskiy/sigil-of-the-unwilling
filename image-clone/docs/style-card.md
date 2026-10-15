---
title: Словарь стиля (Style Card)
tags: [image-clone, style]
status: draft
date: 2026-10-15
---

# Словарь стиля

Единый словарь для двух мест: блок `STYLE+` / `STYLE−` промпт-шаблона и вердикт
слоя стиля. Признак попадает сюда после подтверждённого наблюдения на эталоне;
в промпт и в вердикт он идёт одними словами. Строка отменённая — помечается, а
не удаляется.

Проверено на: лист unit-01 (IMG-001..012), оригиналы `references/crops/`.

## 1. Линия

| Признак | Формулировка | Источник |
| --- | --- | --- |
| Тёмный тёплый контур | `clean dark warm-brown contour line of even thickness around every shape` | IMG-001, 2026-10-15 |
| Внутренние линии тоньше контура, того же тона | `thinner interior lines of the same hue for muscles, seams and folds` | IMG-001, 2026-10-15 |
| Контур замкнут на каждой форме, нигде не растворён | `every shape fully outlined, no outline-less airbrushed edges` | IMG-001 v3, 2026-10-15 |

Отменённое:

- ~~`no ink outlines`~~ (слой варианта, правки до 2026-10-15) — **отменено**.
  Убирает ровно тот признак, который держит семейство: на оригинале контур есть
  на каждой форме. IMG-001 v3: границы лепятся светотенью → вердикт «не та рука».

## 2. Цвет как манера

| Признак | Формулировка | Источник |
| --- | --- | --- |
| Плоский локальный цвет + мягкая светотень поверх | `flat local colour with soft airbrushed shading over it` | IMG-001, 2026-10-15 |
| Тёплая кожа, одна холодная доминанта одежды, коричневая кожа/дерево | `warm ochre skin, one saturated cold garment colour, brown leather accents` | IMG-001, 2026-10-15 |
| Блик маленький и мягкий, только на металле и коже | `small soft highlights on metal and leather only` | IMG-001, 2026-10-15 |

## 3. Манера светотени

| Признак | Формулировка | Источник |
| --- | --- | --- |
| Матово, без глянца и 3D-рендера | `matte painted surface, no glossy plastic sheen, no 3d render look` | IMG-001 v3, 2026-10-15 |
| Тени тёплые, закраины не чёрные | `warm shadows, never black` | IMG-001, 2026-10-15 |
| Зеркальная тень-пятно под обувью, не под всей фигурой | `single soft contact shadow under the boots` | IMG-001, 2026-10-15 |

## 4. Комиксовая гиперболизация формы

| Признак | Формулировка | Источник |
| --- | --- | --- |
| Голова ~1:5.5, массивные трапеции, толстая шея | `heroic stocky build, head about one fifth and a half of the height, huge traps, thick neck` | IMG-001, 2026-10-15 |
| Кисти крупнее реалистичных, кулаки читаются массой | `oversized hands, fists read as solid masses` | IMG-001, 2026-10-15 |
| Черты лица укрупнены, нос блоком, рот небольшой | `mature stylized cartoon face, simplified exaggerated features, blocky nose, small mouth` | IMG-001, 2026-10-15 |

## Что ещё не проверено

- Плотность фактуры (канвас-грейн) — на референсе зерна нет, в промпте было.
- Ракурсы, отличные от анфаса.
- Групповые ячейки и ячейки с текстом.
