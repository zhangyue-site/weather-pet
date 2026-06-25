extends Node

var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test: String = ""

signal all_tests_finished(passed: int, failed: int)

var fsm: PetFSM

func _ready():
	fsm = PetFSM.new()
	add_child(fsm)

	run_test("Initial state is IDLE", test_initial_state)
	run_test("State transition works", test_state_transition)
	run_test("State priority - same priority transitions", test_state_priority_same)
	run_test("State priority - high interrupts low", test_state_priority_high)
	run_test("Transient states auto-reset", test_transient_states)
	run_test("Weather - storm scared", test_weather_storm)
	run_test("Weather - rain umbrella", test_weather_rain)
	run_test("Time - deep sleep at night", test_time_sleep)
	run_test("Time - walking during day", test_time_walking)
	run_test("Touch - tap triggers wave/jump", test_touch_tap)
	run_test("Touch - longpress triggers play_dead", test_touch_longpress)
	run_test("State labels contain expected text", test_state_labels)

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
	_reset_fsm()
	test_func.call()

func _reset_fsm():
	fsm.current_state = PetFSM.PetState.IDLE
	fsm.prev_state = PetFSM.PetState.IDLE
	fsm.state_time = 10.0
	fsm.state_timer = 0.0
	fsm.data = null

func _mock_data(hour: int, minute: int, weather: String, temp: float = 22.0, wind: float = 5.0) -> Dictionary:
	return {
		"current_hour": hour,
		"current_minute": minute,
		"current_weather": {"condition": weather, "temperature": temp, "humidity": 50.0, "wind_speed": wind},
		"phone_signal": 4,
		"battery_percent": 85,
		"is_charging": false,
		"current_festival": {"name": "", "emoji": ""}
	}

class MockData extends Node:
	var current_hour: int = 8
	var current_minute: int = 0
	var current_weather: Dictionary = {"condition": "clear", "temperature": 22.0, "humidity": 50.0, "wind_speed": 5.0}
	var phone_signal: int = 4
	var battery_percent: int = 85
	var is_charging: bool = false
	var current_festival: Dictionary = {"name": "", "emoji": ""}

func _make_mock(hour: int, minute: int, weather: String, temp: float = 22.0, wind: float = 5.0) -> MockData:
	var mock = MockData.new()
	mock.current_hour = hour
	mock.current_minute = minute
	mock.current_weather = {"condition": weather, "temperature": temp, "humidity": 50.0, "wind_speed": wind}
	return mock

func finish():
	print("\n=== Test Results ===")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("Total: %d" % (_tests_passed + _tests_failed))
	all_tests_finished.emit(_tests_passed, _tests_failed)
	if _tests_failed > 0:
		push_error("Some tests failed!")

func test_initial_state():
	assert_eq(fsm.current_state, PetFSM.PetState.IDLE, "Should start in IDLE state")

func test_state_transition():
	fsm.enter_state(PetFSM.PetState.WALKING)
	assert_eq(fsm.current_state, PetFSM.PetState.WALKING, "Should be in WALKING state")
	assert_eq(fsm.prev_state, PetFSM.PetState.IDLE, "Previous state should be IDLE")

func test_state_priority_same():
	fsm.try_transition(PetFSM.PetState.WALKING, 0)
	assert_eq(fsm.current_state, PetFSM.PetState.WALKING, "Same priority (IDLE=1, WALKING=1) should transition")

func test_state_priority_high():
	fsm.try_transition(PetFSM.PetState.STORM_SCARED, 0)
	assert_eq(fsm.current_state, PetFSM.PetState.STORM_SCARED, "High priority should interrupt low")

func test_transient_states():
	fsm.current_state = PetFSM.PetState.WAVE
	fsm.state_time = 3.0
	fsm.state_timer = 0.0
	fsm._process(0.016)
	assert_eq(fsm.current_state, PetFSM.PetState.IDLE, "Transient state should auto-reset after 2.5s")

func test_weather_storm():
	fsm.data = _make_mock(12, 0, "thunderstorm")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.STORM_SCARED, "Should transition to STORM_SCARED on thunderstorm")

func test_weather_rain():
	fsm.data = _make_mock(12, 0, "rain")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.RAIN_UMBRELLA, "Should transition to RAIN_UMBRELLA on rain")

func test_time_sleep():
	fsm.data = _make_mock(2, 0, "clear")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.SLEEP_DEEP, "Should sleep deeply at 2:00")

func test_time_walking():
	fsm.data = _make_mock(10, 0, "clear")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.WALKING, "Should be walking at 10:00")

func test_touch_tap():
	fsm.on_touch("tap")
	assert_true(fsm.current_state in [PetFSM.PetState.WAVE, PetFSM.PetState.JUMP], "Tap should trigger wave or jump")

func test_touch_longpress():
	fsm.on_touch("longpress")
	assert_eq(fsm.current_state, PetFSM.PetState.PLAY_DEAD, "Long press should trigger play dead")

func test_state_labels():
	var label = fsm.state_label()
	assert_true(label.find("发呆") >= 0, "IDLE label should contain '发呆'")
	fsm.enter_state(PetFSM.PetState.WALKING)
	label = fsm.state_label()
	assert_true(label.find("散步") >= 0, "WALKING label should contain '散步'")
	fsm.enter_state(PetFSM.PetState.STORM_SCARED)
	label = fsm.state_label()
	assert_true(label.find("害怕") >= 0, "STORM_SCARED label should contain '害怕'")
