class_name MinHeap
extends RefCounted
## Бинарная куча минимумов по item[0]. При равных ключах гарантирует FIFO-порядок
## извлечения (стабильный tie-break по счётчику вставки) — детерминизм симуляций
## с фиксированным seed. Элементы хранятся кортежами [key, ...payload].
var _data: Array = []
var _seq: int = 0

func push(item: Array) -> void:
	_seq += 1
	_data.append([item, _seq])
	var idx := _data.size() - 1
	while idx > 0:
		var parent: int = (idx - 1) >> 1
		if _less(idx, parent):
			var tmp: Array = _data[idx]
			_data[idx] = _data[parent]
			_data[parent] = tmp
			idx = parent
		else:
			break

func pop() -> Array:
	if _data.is_empty():
		return []
	var res: Array = _data[0][0]
	var last: Array = _data.pop_back()
	if _data.size() > 0:
		_data[0] = last
		var idx := 0
		var size := _data.size()
		while true:
			var left := idx * 2 + 1
			var right := idx * 2 + 2
			var smallest := idx
			if left < size and _less(left, smallest): smallest = left
			if right < size and _less(right, smallest): smallest = right
			if smallest != idx:
				var tmp: Array = _data[idx]
				_data[idx] = _data[smallest]
				_data[smallest] = tmp
				idx = smallest
			else:
				break
	return res

func is_empty() -> bool:
	return _data.is_empty()

func size() -> int:
	return _data.size()

func clear() -> void:
	_data.clear()

func _less(a: int, b: int) -> bool:
	var ka = _data[a][0][0]
	var kb = _data[b][0][0]
	if ka == kb:
		return _data[a][1] < _data[b][1]
	return ka < kb
