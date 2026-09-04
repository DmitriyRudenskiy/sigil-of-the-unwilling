# Tasks: project audit — worthwhile findings

## 1. ArtifactChestDialog Close button wired (R1)
- [x] Connect `cancel` button to `_on_close()` in `_connect_buttons()`
- [x] Confirm clicking "Close" hides the dialog WITHOUT emitting `choice_made` (chest stays in the world)

```gdscript
# game/scripts/ui/ArtifactChestDialog.gd — _connect_buttons()
var cancel := get_node_or_null("Margin/VBox/cancel")
if cancel != null and not cancel.pressed.is_connected(_on_close):
    cancel.pressed.connect(_on_close)
```

## 2. BattleUI collapse button usable (R2)
- [x] In `BattleUI.tscn` move `[node name="collapse_btn" type="Button" parent="bottom_bar"]` → `parent="."` (root CanvasLayer)
- [x] In `BattleUI.gd` change `_connect_btn("collapse_btn", _on_collapse, false)` lookup to `get_node_or_null("collapse_btn")`
- [x] Confirm collapsing hides the bar and the button stays visible/clickable to expand

## 3. ArenaClusterSystem cache invalidated on City.deserialize (R5)
- [x] In `City.deserialize`, after repopulating `buildings`, call `ArenaClusterSystem.invalidate(_uid)`
- [x] Confirm a deserialized city reports correct clusters on first read

```gdscript
# game/scripts/world/City.gd — deserialize()
for bl in data.get("buildings", []):
    ...
ArenaClusterSystem.invalidate(_uid)   # NEW: loaded buildings must refresh clusters
```

## 4. Remove dead MapRenderer.diversify() (R8)
- [x] Delete `func diversify(_tile_map: TileMapLayer) -> void: pass` from `MapRenderer.gd`
- [x] Delete the `renderer.diversify(_tile_map)` call from `MapGenerator.gd` (line 92)

## 5. Spell validator class_name strip regex-aware (R9)
- [x] Replace the `begins_with("class_name ")` strip in `_load_src` with a regex that only removes a leading `class_name X` line
- [x] Confirm spell validation still works for normal spell scripts

## Verification
- [x] Run GUT: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- [x] Confirm zero new failures vs baseline (diff `[Failed]:` lines)
- [x] Confirm R1/R2/R5 behaviors pass; R8/R9 leave counts unchanged
