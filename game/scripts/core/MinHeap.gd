class_name MinHeap
extends RefCounted
var _data: Array = []
func push(item: Array) -> void:
	_data.append(item)
	var idx := _data.size() - 1
	while idx > 0:
		var parent := (idx - 1) / 2
		if _data[idx][0] < _data[parent][0]:
			var tmp: Array = _data[idx]
			_data[idx] = _data[parent]
			_data[parent] = tmp
			idx = parent
		else:
			break
func pop() -> Array:
	if _data.is_empty():
		return []
	var res = _data[0]
	var last: Array = _data.pop_back()
	if _data.size() > 0:
		_data[0] = last
		var idx := 0
		var size := _data.size()
		while true:
			var left := idx * 2 + 1
			var right := idx * 2 + 2
			var smallest := idx
			if left < size and _data[left][0] < _data[smallest][0]: smallest = left
			if right < size and _data[right][0] < _data[smallest][0]: smallest = right
			if smallest != idx:
				var tmp = _data[idx]
				_data[idx] = _data[smallest]
				_data[smallest] = tmp
				idx = smallest
			else:
				break
	return res
func is_empty() -> bool:
	return _data.is_empty()
