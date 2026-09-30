class_name HeroFollowersComponent
extends HeroComponent

var followers: Array = []

func add(f: Follower) -> void:
	followers.append(f)

func remove(f: Follower) -> void:
	followers.erase(f)

func clear() -> void:
	followers.clear()

func find_same_path(path_id: StringName) -> Follower:
	for f in followers:
		if f != null and f.path == path_id:
			return f
	return null

func has_eligible_successor(path_id: StringName) -> bool:
	return find_same_path(path_id) != null

func serialize() -> Dictionary:
	var out: Array = []
	for f in followers:
		if f != null:
			out.append(f.serialize())
	return {"followers": out}

func deserialize(data: Dictionary) -> void:
	followers.clear()
	for f_data in data.get("followers", []):
		var f := Follower.new()
		f.deserialize(f_data)
		followers.append(f)
