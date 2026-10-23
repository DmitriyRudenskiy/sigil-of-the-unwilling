class_name MapThreat
extends RefCounted

## Визуальный носитель тира вражеского стэка (world-map-art-variety 8.1).
##
## Три кольца угрозы обязаны различаться на карте: носитель кольца 1 обязан
## отличаться от кольца 2, а кольца 2 — от кольца 3 (спека «Визуальный носитель
## тира»). Файл знает только про пиксели и их координаты: **тир он не назначает и
## не угадывает** — носитель всегда спрашивается по тиру из модели мира, а не
## наоборот. Это же закрывает сценарий «носитель не подменяет данные»: состав
## стэка для боя читается из `enemy_stacks`, а из носителя не читается ничего.
##
## Пиксели `world_map_threat.webp` и раскладка `world_map_threat.json` — продукты
## `scripts/gen_map_art.py` (категория `threat`). Отдельный лист, а не строки
## объектов: `assemble()` пишет лист только из наличных raw-кадров, сырьё объектов
## на машине сборки потеряно, и три новых носителя, вписанные в объектный лист,
## стоили бы перезапуска всех 22 объектных кадров — либо укороченного листа, который
## роняет карту (см. `whole_or_skip`).
##
## Побратима «в тумане» здесь нет намеренно: вражеские стэки в открытой, но не
## видимой клетке скрыты целиком (вердикт В2 → (в), D-205), затемнять нечего.

const SHEET_PATH := "res://assets/objects/world_map_threat.webp"
const MANIFEST_PATH := "res://assets/objects/world_map_threat.json"
const TILE := GameNumbers.TILE_SIZE

## Кольцо → id клетки листа. Соответствие задаёт код, а не порядок ролей в
## `map_spec.json`: манифест несёт поле `ring`, и тест сверяет его с этой таблицей,
## поэтому перестановка ролей в спеке не переопределит тиры молча.
const RING_WILD := 1
const RING_RAIDERS := 2
const RING_MONSTERS := 3
## Все кольца, которыми обязан уметь быть записанный тир: тир вне этого списка —
## чужие данные, а не повод рисовать «что-нить подходящее».
const RING_CELL_ID := {
	RING_WILD: "threat_ring1_wild",
	RING_RAIDERS: "threat_ring2_raiders",
	RING_MONSTERS: "threat_ring3_monsters",
}
const RINGS: Array = [RING_WILD, RING_RAIDERS, RING_MONSTERS]

static var _manifest: Dictionary = {}
static var _coords: Dictionary = {}
static var _rings: Dictionary = {}
static var _textures: Dictionary = {}


## Манифест листа: {tile, grid, cells: [{id, ring, atlas}]}.
static func manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	if not FileAccess.file_exists(MANIFEST_PATH):
		GameLogger.error("MapThreat: манифест не найден: %s" % MANIFEST_PATH)
		return _manifest
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not (parsed is Dictionary):
		GameLogger.error("MapThreat: манифест не читается: %s" % MANIFEST_PATH)
		return _manifest
	# Тайл обязан совпадать с тайлом карты: носитель кладётся в ту же сетку, и
	# разъезд молча означал бы маркер не на том стэке.
	var tile := int((parsed as Dictionary).get("tile", -1))
	if tile != TILE:
		GameLogger.error(
			"MapThreat: tile=%d != GameNumbers.TILE_SIZE=%d в %s" % [tile, TILE, MANIFEST_PATH]
		)
		return {}
	_manifest = parsed
	for cell in _manifest.get("cells", []):
		var atlas: Array = cell.get("atlas", [0, 0])
		var cid := String(cell.get("id", ""))
		_coords[cid] = Vector2i(int(atlas[0]), int(atlas[1]))
		_rings[cid] = int(cell.get("ring", 0))
	return _manifest


## Клетка носителя в листе; [-1,-1] — носителя там нет.
static func coords_for(cell_id: String) -> Vector2i:
	manifest()
	return _coords.get(cell_id, Vector2i(-1, -1))


## Кольцо, которое манифест приписывает носителю (0 — поля `ring` нет).
static func manifest_ring(cell_id: String) -> int:
	manifest()
	return int(_rings.get(cell_id, 0))


## Все id носителей листа.
static func ids() -> Array:
	manifest()
	return _coords.keys()


## id носителя кольца; "" — кольца с таким номером нет (зовущий обязан сообщить).
static func cell_id_for(ring: int) -> String:
	return String(RING_CELL_ID.get(ring, ""))


## Текстурка носителя кольца: область листа по координатам манифеста. null —
## носителя нет (несобраный лист, нет клетки); зовущий обязан сказать об этом,
## а не молча рисовать стэк без кольца.
static func carrier_texture(ring: int) -> Texture2D:
	var cell_id := cell_id_for(ring)
	if cell_id == "":
		GameLogger.error("MapThreat: несуществующее кольцо тира: %d" % ring)
		return null
	if _textures.has(cell_id):
		return _textures[cell_id]
	var coords := coords_for(cell_id)
	if coords == Vector2i(-1, -1):
		GameLogger.error("MapThreat: носитель '%s' не в листе %s" % [cell_id, MANIFEST_PATH])
		return null
	var sheet := load(SHEET_PATH)
	if not (sheet is Texture2D):
		GameLogger.error("MapThreat: не удалось загрузить %s" % SHEET_PATH)
		return null
	var region := AtlasTexture.new()
	region.atlas = sheet
	region.region = Rect2(coords * TILE, Vector2i(TILE, TILE))
	_textures[cell_id] = region
	return region


## Смещение спрайта носителя, чтобы якорь (низ-центр клетки листа) совпал с
## центром клетки карты: -(якорь - центр тайла) из манифеста.
static func carrier_offset(ring: int) -> Vector2:
	var cell_id := cell_id_for(ring)
	if cell_id == "" or not manifest().has("cells"):
		return Vector2.ZERO
	for c in _manifest.get("cells", []):
		if String(c.get("id", "")) != cell_id:
			continue
		var anchor: Array = c.get("anchor", [TILE / 2, TILE - 2])
		var a := Vector2(float(anchor[0]), float(anchor[1]))
		return -(a - Vector2(float(TILE) / 2.0, float(TILE) / 2.0))
	return Vector2.ZERO
