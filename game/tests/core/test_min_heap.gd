extends GdUnitTestSuite

func test_min_heap_pop_empty_guard() -> void:
	print("[test] min_heap empty-pop guard")
	var heap = MinHeap.new()
	var popped = heap.pop()
	assert_bool(popped is Array and popped.is_empty()).is_true()

func test_min_heap_ordering() -> void:
	print("[test] min_heap ordering")
	var heap = MinHeap.new()
	heap.push([5, "e"])
	heap.push([1, "a"])
	heap.push([3, "c"])
	var p1 = heap.pop()
	assert_bool(p1[1] == "a").is_true()
	var p2 = heap.pop()
	assert_bool(p2[1] == "c").is_true()
	var p3 = heap.pop()
	assert_bool(p3[1] == "e").is_true()
	assert_bool(heap.pop().is_empty()).is_true()
