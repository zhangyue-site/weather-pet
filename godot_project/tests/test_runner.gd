extends Node

var test_scenes: Array[String] = [
	"res://tests/test_pet_fsm.gd",
	"res://tests/test_data_channel.gd",
	"res://tests/test_prop_system.gd"
]

var current_test_index: int = 0
var total_passed: int = 0
var total_failed: int = 0

func _ready():
	print("=== Weather Pet TDD Test Suite ===\n")
	run_next_test()

func run_next_test():
	if current_test_index >= test_scenes.size():
		print("\n=== Final Results ===")
		print("Total Passed: %d" % total_passed)
		print("Total Failed: %d" % total_failed)
		print("Total Tests: %d" % (total_passed + total_failed))
		if total_failed == 0:
			print("✓ All tests passed!")
		else:
			print("✗ Some tests failed!")
		get_tree().quit()
		return
	
	var test_path = test_scenes[current_test_index]
	print("Loading: %s" % test_path)
	
	var test_scene = load(test_path).new()
	test_scene.all_tests_finished.connect(_on_test_finished)
	add_child(test_scene)

func _on_test_finished(passed: int, failed: int):
	total_passed += passed
	total_failed += failed
	current_test_index += 1
	run_next_test()
