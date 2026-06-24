class_name PetFSM
extends Node

enum PetState {
	IDLE, WALKING, SLEEP_DEEP, SLEEP_RESTLESS, WAKE_UP,
	EAT, DRINK_HOT, MORNING_WASH,
	PHONE_SCROLL, SMS_REACT, LOW_BATTERY,
	RAIN_UMBRELLA, RAIN_PUDDLE_JUMP, STORM_SCARED,
	SNOW_CATCH, SNOW_FIGHT, COLD_SHIVER, HOT_MELT,
	WIND_LEAN, FOG_WANDER,
	WAVE, JUMP, SPIN, PLAY_DEAD, FALL_DOWN, GET_UP,
	FESTIVAL,
	TILT_LEFT, TILT_RIGHT,
}

var current_state: PetState = PetState.IDLE
var prev_state: PetState = PetState.IDLE
var state_time: float = 0.0
var state_timer: float = 0.0

@onready var pet = get_parent().get_node_or_null("PetRenderer")
@onready var data = get_node_or_null("/root/DataChannel")

signal state_changed(new_state: PetState, old_state: PetState)

func _ready():
	enter_state(PetState.IDLE)

func _process(delta: float):
	state_time += delta
	state_timer -= delta
	# 临时交互动作 (挥手/跳跃/转圈/趴下等) 播放约 2 秒后自动回到环境态
	if _is_transient(current_state) and state_time > 2.0:
		current_state = PetState.IDLE  # 强制复位, 让 _evaluate_transitions 重新决策
		state_time = 0.0
	_evaluate_transitions()
	_update_state(delta)

func _safe_data() -> Dictionary:
	if not data:
		return {}
	var w = data.current_weather if "current_weather" in data else {"condition": "clear", "temperature": 22.0}
	var sig = data.phone_signal if "phone_signal" in data else 4
	var batt = data.battery_percent if "battery_percent" in data else 85
	var chg = data.is_charging if "is_charging" in data else false
	var fest = data.current_festival if "current_festival" in data else ""
	return {
		"hour": data.current_hour if "current_hour" in data else 8,
		"minute": data.current_minute if "current_minute" in data else 0,
		"weather_condition": w.get("condition", "clear") if typeof(w) == TYPE_DICTIONARY else "clear",
		"temperature": float(w.get("temperature", 22.0)) if typeof(w) == TYPE_DICTIONARY else 22.0,
		"wind_speed": float(w.get("wind_speed", 5.0)) if typeof(w) == TYPE_DICTIONARY else 5.0,
		"signal": sig,
		"battery": batt,
		"charging": chg,
		"festival_name": fest if typeof(fest) == TYPE_STRING else fest.get("name", "") if typeof(fest) == TYPE_DICTIONARY else ""
	}

func _evaluate_transitions():
	if not data:
		return

	var d = _safe_data()
	var hour: int = d.hour
	var minute: int = d.minute
	var t: int = hour * 60 + minute
	var weather: String = d.weather_condition
	var temp: float = d.temperature
	var wind: float = d.wind_speed
	var sig: int = d.signal
	var batt: int = d.battery
	var charging: bool = d.charging
	var festival: String = d.festival_name

	if sig <= 1:
		try_transition(PetState.PHONE_SCROLL, 0)
		return
	if batt <= 15 and not charging:
		try_transition(PetState.LOW_BATTERY, 0)
		return
	if festival != "" and state_time > 5.0:
		try_transition(PetState.FESTIVAL, 3.0)
		return

	if weather == "thunderstorm" or weather == "heavy_rain":
		try_transition(PetState.STORM_SCARED, 0)
		return
	if weather.begins_with("rain") or weather == "drizzle":
		try_transition(PetState.RAIN_UMBRELLA, 0)
		return
	if weather == "snow" or weather == "heavy_snow":
		var which = PetState.SNOW_CATCH if randi() % 2 == 0 else PetState.SNOW_FIGHT
		try_transition(which, 0)
		return
	if weather == "fog" or weather == "haze":
		try_transition(PetState.FOG_WANDER, 0)
		return
	if weather == "windy" and wind > 30:
		try_transition(PetState.WIND_LEAN, 0)
		return
	if temp > 37:
		try_transition(PetState.HOT_MELT, 0)
		return
	if temp < 5:
		try_transition(PetState.COLD_SHIVER, 0)
		return

	if t < 330:
		try_transition(PetState.SLEEP_DEEP, 0)
		return
	elif t < 360:
		try_transition(PetState.SLEEP_RESTLESS, 0)
		return
	elif t < 390:
		try_transition(PetState.WAKE_UP, 3.0)
		return
	elif t < 450:
		try_transition(PetState.MORNING_WASH, 0)
		return
	elif t < 510:
		try_transition(PetState.EAT, 0)
		return
	elif t < 690:
		try_transition(PetState.WALKING, 0)
		return
	elif t < 750:
		try_transition(PetState.EAT, 0)
		return
	elif t < 780:
		try_transition(PetState.PHONE_SCROLL, 0)
		return
	elif t < 1080:
		try_transition(PetState.WALKING, 0)
		return
	elif t < 1170:
		try_transition(PetState.EAT, 0)
		return
	elif t < 1350:
		try_transition(PetState.PHONE_SCROLL, 0)
		return
	elif t < 1410:
		try_transition(PetState.MORNING_WASH, 0)
		return
	else:
		try_transition(PetState.SLEEP_DEEP, 0)
		return

func try_transition(new_state: PetState, min_duration: float):
	if new_state == current_state: return
	if state_timer > 0: return
	if state_time < min_duration and current_state != PetState.IDLE: return
	enter_state(new_state)

func enter_state(state: PetState):
	prev_state = current_state
	current_state = state
	state_time = 0.0
	state_timer = 0.0

	if pet and pet.has_method("set_arms"):
		match state:
			PetState.IDLE:
				pet.set_arms(30, 30)
				if pet.has_method("set_expression"): pet.set_expression(0, true)
				if pet.has_method("set_walking"): pet.set_walking(false)
			PetState.WALKING:
				pet.set_arms(40, 15, 0, 0)
				if pet.has_method("set_expression"): pet.set_expression(0)
				if pet.has_method("set_walking"): pet.set_walking(true)
			PetState.SLEEP_DEEP:
				pet.set_arms(10, 10, 0, 0)
				if pet.has_method("set_expression"): pet.set_expression(2, true)
				if pet.has_method("set_walking"): pet.set_walking(false)
			PetState.SLEEP_RESTLESS:
				pet.set_arms(10, 10, 0, 0)
				if pet.has_method("set_expression"): pet.set_expression(3, true)
				if pet.has_method("set_walking"): pet.set_walking(false)
			PetState.WAKE_UP:
				pet.set_arms(90, 90, -30, -30)
				if pet.has_method("set_expression"): pet.set_expression(3)
			PetState.EAT:
				pet.set_arms(85, 70, 0, -20)
				if pet.has_method("set_expression"): pet.set_expression(0)
			PetState.PHONE_SCROLL:
				pet.set_arms(30, 100, 0, -30)
				if pet.has_method("set_expression"): pet.set_expression(0)
			PetState.STORM_SCARED:
				pet.set_arms(10, 10, 0, 0)
				if pet.has_method("set_expression"): pet.set_expression(5, true)
			PetState.RAIN_UMBRELLA:
				pet.set_arms(20, 150, 0, 90)
				if pet.has_method("set_expression"): pet.set_expression(0)
			PetState.SNOW_CATCH:
				pet.set_arms(140, 140, -20, -20)
				if pet.has_method("set_expression"): pet.set_expression(4)
			PetState.COLD_SHIVER:
				pet.set_arms(10, 10, 0, 0)
				if pet.has_method("set_expression"): pet.set_expression(6)
			PetState.HOT_MELT:
				pet.set_arms(80, 80, -30, -30)
				if pet.has_method("set_expression"): pet.set_expression(7)
			PetState.FESTIVAL:
				pet.set_arms(150, 150, 0, 0)
				if pet.has_method("set_expression"): pet.set_expression(4)
			_:
				pet.set_arms(30, 30)
				if pet.has_method("set_expression"): pet.set_expression(0)
				if pet.has_method("set_walking"): pet.set_walking(false)

	state_changed.emit(state, prev_state)

func _update_state(delta: float):
	if not pet:
		return
	var base_pos: Vector2 = pet._base_position if "_base_position" in pet else pet.position
	pet.position = base_pos
	match current_state:
		PetState.IDLE:
			pass
		PetState.WALKING:
			var bounce = sin(state_time * 8.0) * 3.0
			pet.position.y = base_pos.y + bounce * (pet._scale_factor if "_scale_factor" in pet else 1.0)
		PetState.SLEEP_DEEP:
			pet.position.y = base_pos.y + sin(state_time * 2.0) * 1.5 * (pet._scale_factor if "_scale_factor" in pet else 1.0)
		PetState.SLEEP_RESTLESS:
			var shake = sin(state_time * 12.0) * 2.0
			pet.position.x = base_pos.x + shake * (pet._scale_factor if "_scale_factor" in pet else 1.0)
		PetState.STORM_SCARED:
			var shake2 = sin(state_time * 20.0) * 4.0
			pet.position.x = base_pos.x + shake2 * (pet._scale_factor if "_scale_factor" in pet else 1.0)
		PetState.COLD_SHIVER:
			var shake3 = sin(state_time * 15.0) * 2.0
			pet.position.x = base_pos.x + shake3 * (pet._scale_factor if "_scale_factor" in pet else 1.0)
		PetState.FESTIVAL:
			var bounce2 = abs(sin(state_time * 4.0)) * 8.0
			pet.position.y = base_pos.y - bounce2 * (pet._scale_factor if "_scale_factor" in pet else 1.0)

func on_touch(type: String):
	match type:
		"tap":
			try_transition(PetState.WAVE if randi() % 2 == 0 else PetState.JUMP, 0.5)
		"longpress":
			try_transition(PetState.PLAY_DEAD, 0)
		"double":
			try_transition(PetState.SPIN, 0)

# 中文状态文案 (供 HUD 显示)
func state_label() -> String:
	match current_state:
		PetState.IDLE: return "😌 发呆中"
		PetState.WALKING: return "🚶 散步中"
		PetState.SLEEP_DEEP: return "😴 深度睡眠"
		PetState.SLEEP_RESTLESS: return "😫 睡不安稳"
		PetState.WAKE_UP: return "🥱 刚睡醒"
		PetState.EAT: return "🍽 干饭中"
		PetState.DRINK_HOT: return "☕ 喝热饮"
		PetState.MORNING_WASH: return "🚿 洗漱中"
		PetState.PHONE_SCROLL: return "📱 刷手机"
		PetState.SMS_REACT: return "💌 收到消息"
		PetState.LOW_BATTERY: return "🪫 快没电了"
		PetState.RAIN_UMBRELLA: return "☂️ 撑伞挡雨"
		PetState.RAIN_PUDDLE_JUMP: return "💧 踩水坑"
		PetState.STORM_SCARED: return "⚡ 害怕打雷"
		PetState.SNOW_CATCH: return "❄️ 接雪花"
		PetState.SNOW_FIGHT: return "⛄ 打雪仗"
		PetState.COLD_SHIVER: return "🥶 冷得发抖"
		PetState.HOT_MELT: return "🥵 热化了"
		PetState.WIND_LEAN: return "💨 顶风前行"
		PetState.FOG_WANDER: return "🌫️ 雾里溜达"
		PetState.WAVE: return "👋 招手!"
		PetState.JUMP: return "🤸 跳跃!"
		PetState.SPIN: return "🌀 转圈圈!"
		PetState.PLAY_DEAD: return "💫 趴下了"
		PetState.FALL_DOWN: return "😱 摔倒啦"
		PetState.GET_UP: return "🆙 爬起来"
		PetState.FESTIVAL: return "🎉 过节啦!"
		PetState.TILT_LEFT: return "↩️ 左倾"
		PetState.TILT_RIGHT: return "↪️ 右倾"
		_: return "😊 陪伴你"

# 状态是否为交互触发的临时动作 (持续时间短)
func _is_transient(state: PetState) -> bool:
	return state in [PetState.WAVE, PetState.JUMP, PetState.SPIN, PetState.PLAY_DEAD,
		PetState.FALL_DOWN, PetState.GET_UP, PetState.WAKE_UP]
