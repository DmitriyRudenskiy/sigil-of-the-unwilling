class_name UILayout
extends RefCounted
## Геометрия adventure-экрана из prototype_map.html (CSS → константы).

## #game: padding 14px, gap 10px.
const FRAME_PADDING := 14.0
const FRAME_GAP := 10.0

## #sidebar: grid-column 2 width = clamp(300px, 25vw, 430px).
const SIDEBAR_W_MIN := 300.0
const SIDEBAR_W_MAX := 430.0
const SIDEBAR_W_VW := 0.25

static func sidebar_width(viewport_x: float) -> float:
	return clampf(viewport_x * SIDEBAR_W_VW, SIDEBAR_W_MIN, SIDEBAR_W_MAX)

## #datebar: height 34px.
const DATEBAR_H := 34.0

## #minimap-panel: border 3px solid var(--gold); padding 24px 32px.
const MINIMAP_BORDER := 3.0
const MINIMAP_PAD_V := 24.0
const MINIMAP_PAD_H := 32.0
## #minimap: border 2px solid var(--gold-hi); aspect-ratio 4/3 (width/height).
const MINIMAP_MAP_BORDER := 2.0
const MINIMAP_ASPECT := 4.0 / 3.0
## .compass: font-size 17; n/s top|bottom 2px; w/e left|right 9px.
const COMPASS_FONT := 17
const COMPASS_NS_INSET := 2.0
const COMPASS_WE_INSET := 9.0
const COMPASS_BTN := Vector2(24, 22)

## Цвета рамки прототипа: --gold #c9a25a, --gold-hi #f3d68c, --panel #4a0d0d.
const C_GOLD := Color("#c9a25a")
const C_GOLD_HI := Color("#f3d68c")
const C_PANEL := Color("#4a0d0d")

## Высота панели миникарты при данной ширине панели pw.
static func minimap_panel_height(pw: float) -> float:
	var map_w := pw - 2.0 * (MINIMAP_BORDER + MINIMAP_PAD_H)
	var map_h := map_w / MINIMAP_ASPECT
	return 2.0 * (MINIMAP_BORDER + MINIMAP_PAD_V) + map_h
