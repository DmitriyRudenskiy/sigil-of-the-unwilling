## scripts/core/UIConfig.gd
## Константы UI/камеры (аудит #16: вынесено из GameSettings).
class_name UIConfig
extends RefCounted

# --- Camera / Zoom ---
const ZOOM_LEVELS := [0.5, 0.7, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.25]

const ZOOM_DEFAULT_INDEX := 2  # 1.0

# --- World Camera ---
const CAMERA_SPEED := 600.0

const CAMERA_EDGE_ZONE := 20

const CAMERA_ZOOM_TWEEN_SEC := 0.175

# --- Main Menu UI ---
const MENU_COL_OFFSET_LEFT := -380

const MENU_COL_OFFSET_RIGHT := -60

const MENU_COL_OFFSET_TOP := 120

const MENU_COL_OFFSET_BOTTOM := -120

const MENU_COL_SEPARATION := 20

const MENU_BTN_MIN_SIZE := Vector2(300, 70)

const MENU_LOCK_MIN_SIZE := Vector2(300, 180)

# --- Adventure UI ---
const ADVENTURE_RIGHT_PANEL_W := 252

const ADVENTURE_INITIATIVE_PANEL_W := 190

const ADVENTURE_BATTLE_STATUS_H := 92

const ADVENTURE_BOTTOM_BAR_OFFSET := -58

# --- City Panel ---
const CITY_PANEL_W := 340.0

const CITY_PANEL_OFFSET := 12.0

const CITY_PANEL_TOP := 40.0

const CITY_PANEL_BOTTOM := -40.0
