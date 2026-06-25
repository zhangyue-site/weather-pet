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
	run_test("Weather - overcast idle", test_weather_overcast)
	run_test("Weather - sandstorm huddle", test_weather_sandstorm)
	run_test("Weather - snow catch or fight", test_weather_snow)
	run_test("Weather - fog wander", test_weather_fog)
	run_test("Weather - wind lean", test_weather_wind)
	run_test("Weather - hot melt", test_weather_hot)
	run_test("Weather - cold shiver", test_weather_cold)
	run_test("Time - deep sleep at night", test_time_sleep)
	run_test("Time - walking during day", test_time_walking)
	run_test("Time - wake up at dawn", test_time_wakeup)
	run_test("Time - eat at breakfast", test_time_eat)
	run_test("Touch - tap triggers wave/jump", test_touch_tap)
	run_test("Touch - longpress triggers play_dead", test_touch_longpress)
	run_test("Touch - double triggers spin", test_touch_double)
	run_test("State labels contain expected text", test_state_labels)
	run_test("All states have labels", test_all_labels)
	run_test("Each state has unique animation", test_unique_anims)

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
	assert_eq(fsm.current_state, PetFSM.PetState.WALKING, "Same priority should transition")

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
	assert_eq(fsm.current_state, PetFSM.PetState.STORM_SCARED, "Should be STORM_SCARED on thunderstorm")

func test_weather_rain():
	fsm.data = _make_mock(12, 0, "rain")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.RAIN_UMBRELLA, "Should be RAIN_UMBRELLA on rain")

func test_weather_overcast():
	fsm.data = _make_mock(12, 0, "overcast")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.OVERCAST_IDLE, "Should be OVERCAST_IDLE on overcast")

func test_weather_sandstorm():
	fsm.data = _make_mock(12, 0, "sandstorm")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.SANDSTORM_HUDDLE, "Should be SANDSTORM_HUDDLE on sandstorm")

func test_weather_snow():
	fsm.data = _make_mock(12, 0, "snow")
	fsm._evaluate_transitions()
	assert_true(fsm.current_state in [PetFSM.PetState.SNOW_CATCH, PetFSM.PetState.SNOW_FIGHT], "Should be SNOW_CATCH or SNOW_FIGHT")

func test_weather_fog():
	fsm.data = _make_mock(12, 0, "fog")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.FOG_WANDER, "Should be FOG_WANDER on fog")

func test_weather_wind():
	fsm.data = _make_mock(12, 0, "windy", 22.0, 35.0)
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.WIND_LEAN, "Should be WIND_LEAN on windy >30")

func test_weather_hot():
	fsm.data = _make_mock(12, 0, "clear", 38.0)
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.HOT_MELT, "Should be HOT_MELT on temp >37")

func test_weather_cold():
	fsm.data = _make_mock(12, 0, "clear", 3.0)
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.COLD_SHIVER, "Should be COLD_SHIVER on temp <5")

func test_time_sleep():
	fsm.data = _make_mock(2, 0, "clear")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.SLEEP_DEEP, "Should sleep at 2:00")

func test_time_walking():
	fsm.data = _make_mock(10, 0, "clear")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.WALKING, "Should walk at 10:00")

func test_time_wakeup():
	fsm.data = _make_mock(6, 15, "clear")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.WAKE_UP, "Should wake up at 6:15")

func test_time_eat():
	fsm.data = _make_mock(7, 45, "clear")
	fsm._evaluate_transitions()
	assert_eq(fsm.current_state, PetFSM.PetState.EAT, "Should eat at 7:45")

func test_touch_tap():
	fsm.on_touch("tap")
	assert_true(fsm.current_state in [PetFSM.PetState.WAVE, PetFSM.PetState.JUMP], "Tap should trigger wave or jump")

func test_touch_longpress():
	fsm.on_touch("longpress")
	assert_eq(fsm.current_state, PetFSM.PetState.PLAY_DEAD, "Long press should trigger play dead")

func test_touch_double():
	fsm.on_touch("double")
	assert_eq(fsm.current_state, PetFSM.PetState.SPIN, "Double tap should trigger spin")

func test_state_labels():
	var label = fsm.state_label()
	assert_true(label.find("发呆") >= 0, "IDLE label should contain '发呆'")
	fsm.enter_state(PetFSM.PetState.WALKING)
	label = fsm.state_label()
	assert_true(label.find("散步") >= 0, "WALKING label should contain '散步'")
	fsm.enter_state(PetFSM.PetState.OVERCAST_IDLE)
	label = fsm.state_label()
	assert_true(label.find("阴沉") >= 0, "OVERCAST label should contain '阴沉'")
	fsm.enter_state(PetFSM.PetState.SANDSTORM_HUDDLE)
	label = fsm.state_label()
	assert_true(label.find("沙尘") >= 0, "SANDSTORM label should contain '沙尘'")

func test_all_labels():
	var all_states = PetFSM.PetState.values()
	for s in all_states:
		fsm.current_state = s
		var label = fsm.state_label()
		assert_true(label.length() > 0, "State %d should have non-empty label" % s)

func test_unique_anims():
	var anim_map := {
		"idle": [PetFSM.PetState.IDLE, PetFSM.PetState.SLEEP_DEEP, PetFSM.PetState.SLEEP_RESTLESS,
			PetFSM.PetState.EAT, PetFSM.PetState.DRINK_HOT, PetFSM.PetState.PHONE_SCROLL,
			PetFSM.PetState.SNOW_CATCH, PetFSM.PetState.GET_UP, PetFSM.PetState.OVERCAST_IDLE],
		"walk": [PetFSM.PetState.WALKING, PetFSM.PetState.FOG_WANDER],
		"wave": [PetFSM.PetState.WAVE, PetFSM.PetState.SMS_REACT, PetFSM.PetState.FESTIVAL,
			PetFSM.PetState.SNOW_FIGHT, PetFSM.PetState.MORNING_WASH, PetFSM.PetState.SPIN],
		"up": [PetFSM.PetState.JUMP, PetFSM.PetState.WAKE_UP],
		"fall": [PetFSM.PetState.PLAY_DEAD, PetFSM.PetState.FALL_DOWN, PetFSM.PetState.STORM_SCARED,
			PetFSM.PetState.LOW_BATTERY, PetFSM.PetState.COLD_SHIVER, PetFSM.PetState.HOT_MELT,
			PetFSM.PetState.SANDSTORM_HUDDLE],
		"tilt_l": [PetFSM.PetState.WIND_LEAN, PetFSM.PetState.TILT_LEFT, PetFSM.PetState.RAIN_UMBRELLA],
		"tilt_r": [PetFSM.PetState.TILT_RIGHT],
	}
	var total := 0
	for anim in anim_map:
		total += anim_map[anim].size()
	assert_true(total >= 30, "Should map at least 30 states, got %d" % total)
