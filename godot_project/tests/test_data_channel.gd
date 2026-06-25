extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test: String = ""

signal all_tests_finished(passed: int, failed: int)

var dc: Node

func _ready():
	dc = preload("res://scripts/data_channel.gd").new()
	add_child(dc)
	await get_tree().process_frame

	run_test("Weather defaults to clear", test_weather_defaults)
	run_test("Feed weather updates all fields", test_feed_weather)
	run_test("Feed time updates hour/minute", test_feed_time)
	run_test("Feed festival updates name/emoji", test_feed_festival)
	run_test("Feed signal updates strength", test_feed_signal)
	run_test("Feed battery updates percent/charging", test_feed_battery)
	run_test("Preset cities has 14 entries", test_preset_cities_count)
	run_test("Preset cities first is Beijing", test_preset_cities_beijing)
	run_test("City switching cycles through cities", test_city_switching)
	run_test("set_city_by_name finds valid city", test_set_city_valid)
	run_test("set_city_by_name rejects invalid", test_set_city_invalid)
	run_test("get_city_names returns array", test_get_city_names)
	run_test("Location mode is demo on PC", test_location_mode_pc)

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

func assert_false(condition: bool, message: String = ""):
	if condition:
		var msg = message if message != "" else "Expected false but got true"
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

func test_weather_defaults():
	assert_eq(dc.current_weather.condition, "clear", "Default weather should be clear")
	assert_eq(dc.current_weather.temperature, 22.0, "Default temp should be 22")

func test_feed_weather():
	dc.feed_weather('{"condition":"rain","temperature":15.5,"humidity":80,"wind_speed":10,"city_name":"上海"}')
	assert_eq(dc.current_weather.condition, "rain", "Condition should be rain")
	assert_eq(dc.current_weather.temperature, 15.5, "Temperature should be 15.5")
	assert_eq(dc.current_weather.humidity, 80.0, "Humidity should be 80")
	assert_eq(dc.current_weather.wind_speed, 10.0, "Wind speed should be 10")
	assert_eq(dc.city_name, "上海", "City should be Shanghai")

func test_feed_time():
	dc.feed_time(14, 30)
	assert_eq(dc.current_hour, 14, "Hour should be 14")
	assert_eq(dc.current_minute, 30, "Minute should be 30")

func test_feed_festival():
	dc.feed_festival("春节", "🧨")
	assert_eq(dc.current_festival.name, "春节", "Festival name should be Spring Festival")
	assert_eq(dc.current_festival.emoji, "🧨", "Festival emoji should be correct")

func test_feed_signal():
	dc.feed_signal(2)
	assert_eq(dc.phone_signal, 2, "Signal should be 2")

func test_feed_battery():
	dc.feed_battery(50, true)
	assert_eq(dc.battery_percent, 50, "Battery should be 50")
	assert_true(dc.is_charging, "Should be charging")

func test_preset_cities_count():
	assert_eq(dc.PRESET_CITIES.size(), 14, "Should have 14 preset cities")

func test_preset_cities_beijing():
	var beijing = dc.PRESET_CITIES[0]
	assert_eq(beijing.name, "北京", "First city should be Beijing")

func test_city_switching():
	dc.switch_to_next_city()
	assert_eq(dc.city_name, "上海", "Should switch to Shanghai")
	assert_eq(dc.location_mode, "custom", "Location mode should be custom")

func test_set_city_valid():
	var result = dc.set_city_by_name("深圳")
	assert_true(result, "Should find Shenzhen")
	assert_eq(dc.city_name, "深圳", "City should be Shenzhen")

func test_set_city_invalid():
	var result = dc.set_city_by_name("不存在的城市")
	assert_false(result, "Should not find non-existent city")

func test_get_city_names():
	var names = dc.get_city_names()
	assert_true(names.size() == 14, "Should return 14 city names")
	assert_true(names[0] == "北京", "First should be Beijing")

func test_location_mode_pc():
	assert_true(dc.location_mode == "demo" or dc.location_mode == "custom", "PC mode should be demo or custom")
