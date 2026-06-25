extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test: String = ""

signal all_tests_finished(passed: int, failed: int)

var prop_system: PropSystem
var dc: Node

func _ready():
	dc = preload("res://scripts/data_channel.gd").new()
	add_child(dc)
	await get_tree().process_frame

	prop_system = PropSystem.new()
	add_child(prop_system)
	await get_tree().process_frame
	prop_system.data = dc

	run_test("Initial state - empty prop", test_initial_state)
	run_test("Show prop sets current_prop", test_show_prop)
	run_test("Rain weather shows umbrella", test_rain_umbrella)
	run_test("Snow weather shows snow_hat", test_snow_hat)
	run_test("Clear weather hides prop", test_clear_hides)
	run_test("Night time shows starry sky", test_night_stars)

	finish()

func assert_eq(actual, expected, message: String = ""):
	if actual != expected:
		var msg = message if message != "" else "Expected %s but got %s" % [expected, actual]
		push_error("FAIL: %s - %s" % [_current_test, msg])
		_tests_failed += 1
	else:
		_tests_passed += 1

func assert_true(condition: bool, message: String = ""):
	if not condition:
		var msg = message if message != "" else "Expected true but got false"
		push_error("FAIL: %s - %s" % [_current_test, msg])
		_tests_failed += 1
	else:
		_tests_passed += 1

func run_test(test_name: String, test_func: Callable):
	_current_test = test_name
	print("Running: %s" % test_name)
	test_func.call()

func finish():
	print("\n=== Test Results ===")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("Total: %d" % (_tests_passed + _tests_failed))
	all_tests_finished.emit(_tests_passed, _tests_failed)
	if _tests_failed > 0:
		push_error("Some tests failed!")

func test_initial_state():
	assert_eq(prop_system.current_prop, "", "Initial prop should be empty")

func test_show_prop():
	prop_system.show_prop("umbrella")
	assert_eq(prop_system.current_prop, "umbrella", "Should be umbrella after show")
	assert_true(prop_system.visible, "Should be visible after show")

func test_rain_umbrella():
	dc.current_weather = {"condition": "rain", "temperature": 16.0, "humidity": 80.0, "wind_speed": 5.0}
	dc.current_festival = {"name": "", "emoji": ""}
	dc.current_hour = 12
	prop_system._refresh_prop()
	assert_eq(prop_system.current_prop, "umbrella", "Should show umbrella on rain")

func test_snow_hat():
	dc.current_weather = {"condition": "snow", "temperature": -2.0, "humidity": 80.0, "wind_speed": 5.0}
	dc.current_festival = {"name": "", "emoji": ""}
	dc.current_hour = 12
	prop_system.current_prop = ""
	prop_system._refresh_prop()
	assert_eq(prop_system.current_prop, "snow_hat", "Should show snow_hat on snow")

func test_clear_hides():
	dc.current_weather = {"condition": "clear", "temperature": 22.0, "humidity": 50.0, "wind_speed": 5.0}
	dc.current_festival = {"name": "", "emoji": ""}
	dc.current_hour = 12
	prop_system.current_prop = ""
	prop_system._refresh_prop()
	assert_eq(prop_system.current_prop, "", "Should hide prop on clear weather")

func test_night_stars():
	dc.current_weather = {"condition": "clear", "temperature": 22.0, "humidity": 50.0, "wind_speed": 5.0}
	dc.current_festival = {"name": "", "emoji": ""}
	dc.current_hour = 22
	prop_system.current_prop = ""
	prop_system._refresh_prop()
	assert_eq(prop_system.current_prop, "starry_sky", "Should show starry sky at night")
