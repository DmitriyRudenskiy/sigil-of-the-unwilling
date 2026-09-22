class_name TeamDialogSystem
extends RefCounted
## team-romance-roleplay D6: движок диалогов с последователями.
## static: сцены загружаются TeamDialogData.load_all, контекст — из героя/последователя.
## Детерминизм: выбор вариантов — чистая функция (контекст + настройки).

static var _dialogs: Dictionary = {}

static func load_dialogs(dir: String = TeamDialogData.DIR) -> void:
	_dialogs = TeamDialogData.load_all(dir)

static func has_dialog(id: String) -> bool:
	return _dialogs.has(id)

static func get_dialog(id: String) -> Dictionary:
	return _dialogs.get(id, {})

# ═══════════════════════════════════════════
#  КОНТЕКСТ И ФИЛЬТРЫ (D6)
# ═══════════════════════════════════════════

## Контекст для cond-фильтров.
static func make_context(hero, follower: Follower) -> Dictionary:
	var pair: Dictionary = {}
	var rel = hero.relationships if hero != null else null
	if rel != null and follower != null:
		pair = rel.pair(follower.uid)
	var stats: Dictionary = {}
	var hero_sex := "male"
	if hero != null and hero.stats_comp != null:
		stats = hero.stats_comp.stats
		hero_sex = String(hero.stats_comp.sex)
	return {
		"sex_h": hero_sex,
		"sex_f": String(follower.gender) if follower != null else "male",
		"race": String(follower.race) if follower != null else "",
		"path": String(follower.path) if follower != null else "",
		"traits": (follower.trait_ids if follower != null else []) as Array,
		"bond": int(pair.get("bond", 0)),
		"trust": int(pair.get("trust", 50)),
		"romance": int(pair.get("romance", 0)),
		"stage": RelationshipSystem.stage_of(int(pair.get("bond", 0))),
		"romance_stage": RelationshipSystem.romance_stage(int(pair.get("romance", 0))),
		"orientation_compatible": RelationshipSystem.compatible(
			hero_sex, follower.gender, follower.orientation) if follower != null else false,
		"spouse": bool(pair.get("spouse", false)),
		"cha": int(stats.get("cha", 2)),
		"wis": int(stats.get("wis", 2)),
		"int": int(stats.get("int", 2)),
		"luk": int(stats.get("luk", 2)),
	}

## cond: все условия должны быть выполнены (пустой cond → true).
static func cond_ok(cond: Dictionary, ctx: Dictionary) -> bool:
	if cond.is_empty():
		return true
	if cond.has("sex_h") and String(ctx.get("sex_h", "")) != String(cond["sex_h"]):
		return false
	if cond.has("sex_f") and String(ctx.get("sex_f", "")) != String(cond["sex_f"]):
		return false
	if cond.has("race") and String(ctx.get("race", "")) != String(cond["race"]):
		return false
	if cond.has("path") and String(ctx.get("path", "")) != String(cond["path"]):
		return false
	if cond.has("trait") and not (ctx.get("traits", []) as Array).has(StringName(cond["trait"])):
		return false
	if cond.has("min_bond") and int(ctx.get("bond", 0)) < int(cond["min_bond"]):
		return false
	if cond.has("max_bond") and int(ctx.get("bond", 0)) > int(cond["max_bond"]):
		return false
	if cond.has("min_trust") and int(ctx.get("trust", 0)) < int(cond["min_trust"]):
		return false
	if cond.has("min_romance") and int(ctx.get("romance", 0)) < int(cond["min_romance"]):
		return false
	if cond.has("stage") and int(ctx.get("stage", 0)) != int(cond["stage"]):
		return false
	if cond.has("romance_stage") and int(ctx.get("romance_stage", 0)) != int(cond["romance_stage"]):
		return false
	if cond.has("orientation_compatible") \
			and bool(ctx.get("orientation_compatible", false)) != bool(cond["orientation_compatible"]):
		return false
	if cond.has("spouse") and bool(ctx.get("spouse", false)) != bool(cond["spouse"]):
		return false
	if cond.has("min_cha") and int(ctx.get("cha", 0)) < int(cond["min_cha"]):
		return false
	if cond.has("min_wis") and int(ctx.get("wis", 0)) < int(cond["min_wis"]):
		return false
	if cond.has("min_int") and int(ctx.get("int", 0)) < int(cond["min_int"]):
		return false
	if cond.has("min_luk") and int(ctx.get("luk", 0)) < int(cond["min_luk"]):
		return false
	return true

## Видимые реплики узла: сначала совпавшие по cond, затем без cond, затем первая.
static func visible_lines(node: Dictionary, ctx: Dictionary) -> Array:
	var lines: Array = node.get("lines", [])
	var matched: Array = []
	var generic: Array = []
	for l in lines:
		if not (l is Dictionary):
			continue
		var ld: Dictionary = l
		var cond: Dictionary = ld.get("cond", {})
		if cond.is_empty():
			generic.append(ld)
		elif cond_ok(cond, ctx):
			matched.append(ld)
	var out: Array = matched if not matched.is_empty() else generic
	if out.is_empty():
		out = lines
	return out

## Видимые варианты выбора: cond + контент-гейт (adult → pg_fallback или скрыт).
static func visible_choices(node: Dictionary, ctx: Dictionary, content_adult: bool) -> Array:
	var out: Array = []
	var choices: Array = node.get("choices", [])
	for c in choices:
		if not (c is Dictionary):
			continue
		var cd: Dictionary = c
		if not cond_ok(cd.get("cond", {}), ctx):
			continue
		var tier := String(cd.get("tier", "pg"))
		if tier == "adult" and not content_adult:
			var fb: Dictionary = cd.get("pg_fallback", {})
			if fb.has("text"):
				var alt: Dictionary = cd.duplicate(true)
				alt["text"] = String(fb["text"])
				alt["effects"] = fb.get("effects", [])
				alt["next"] = fb.get("next", cd.get("next"))
				alt.erase("tier")
				out.append(alt)
			# без pg_fallback → скрыт
			continue
		out.append(cd)
	return out

## Выбор сцены по стадиям: romance ≥ 2 → romance_relationship,
## flirt → romance_flirt, bond ≥ friend → talk_friend, иначе talk_stranger.
## Фолбэк — talk_generic. (proposal — только как сцена-событие, не через pick.)
static func pick_dialog(ctx: Dictionary) -> String:
	var romance_stage := int(ctx.get("romance_stage", 0))
	var stage := int(ctx.get("stage", 0))
	var candidates: Array = []
	if romance_stage >= RelationshipSystem.ROM_RELATIONSHIP:
		candidates = ["romance_relationship", "romance_flirt"]
	elif romance_stage >= RelationshipSystem.ROM_FLIRT:
		candidates = ["romance_flirt"]
	elif stage >= RelationshipSystem.STAGE_FRIEND:
		candidates = ["talk_friend", "talk_stranger"]
	else:
		candidates = ["talk_stranger"]
	for id in candidates:
		if _dialogs.has(id):
			return String(id)
	return "talk_generic" if _dialogs.has("talk_generic") else ""

# ═══════════════════════════════════════════
#  ЭФФЕКТЫ ВЫБОРОВ (4.3)
# ═══════════════════════════════════════════

## Применяет эффекты варианта: bond/trust/romance (через RelationshipSystem.modify —
## с гейтом ориентации), stat (перманентно), buff (временный боевой дух),
## event (сцена в очередь), item (предмет в рюкзак).
static func apply_effects(hero, follower: Follower, effects: Array) -> void:
	if hero == null or follower == null:
		return
	var rel = hero.relationships
	if rel == null:
		return
	var deltas := {"bond": 0, "trust": 0, "romance": 0}
	for e in effects:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e
		if ed.has("bond"):
			deltas["bond"] += int(ed["bond"])
		if ed.has("trust"):
			deltas["trust"] += int(ed["trust"])
		if ed.has("romance"):
			deltas["romance"] += int(ed["romance"])
		if ed.has("stat") and hero.stats_comp != null:
			var s := String(ed["stat"])
			hero.stats_comp.stats[s] = int(hero.stats_comp.stats.get(s, 0)) + int(ed.get("delta", 1))
		if ed.has("buff"):
			rel.add_morale_buff(int(ed.get("value", 1)), int(ed.get("turns", 5)))
		if ed.has("event"):
			rel.pending_scenes.append({"type": String(ed["event"]), "uid": int(follower.uid)})
		if ed.has("item"):
			_grant_item(hero, String(ed["item"]))
	var hero_sex := String(hero.stats_comp.sex) if hero.stats_comp != null else "male"
	RelationshipSystem.modify(rel, hero_sex, follower, deltas)

static func _grant_item(hero, item_id: String) -> void:
	if hero == null or hero.inventory == null or item_id.is_empty():
		return
	var art := Artifact.new(StringName(item_id), item_id, Artifact.Slot.MISC_A,
		Artifact.Rarity.MINOR, {}, &"", false, 10, "")
	hero.inventory.backpack.append(art)
