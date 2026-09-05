extends "res://tests/gut_base.gd"
## Headless tests for MinHeap (аудит #9: вынесен из HexUtils в scripts/core/MinHeap.gd).

func test_min_heap_pop_empty_guard() -> void:
	print("[test] min_heap empty-pop guard")
	var heap = MinHeap.new()
	var popped = heap.pop()
	check("pop on empty heap returns [] (no crash)",
		popped is Array and popped.is_empty(), "got %s" % str(popped))


func test_min_heap_ordering() -> void:
	print("[test] min_heap ordering")
	var heap = MinHeap.new()
	heap.push([5, "e"])
	heap.push([1, "a"])
	heap.push([3, "c"])
	var p1 = heap.pop()
	check("first pop is smallest (a)", p1[1] == "a", "got %s" % str(p1))
	var p2 = heap.pop()
	check("second pop is next (c)", p2[1] == "c", "got %s" % str(p2))
	var p3 = heap.pop()
	check("third pop is last (e)", p3[1] == "e", "got %s" % str(p3))
	check("heap now empty", heap.pop().is_empty(), "")
