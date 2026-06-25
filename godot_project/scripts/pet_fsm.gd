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
	OVERCAST_IDLE, SANDSTORM_HUDDLE,
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
	if _is_transient(current_state) and state_time > 2.5:
		current_state = PetState.IDLE
		state_time = 0.0
		state_timer = 0.0
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
	if weather == "sandstorm":
		try_transition(PetState.SANDSTORM_HUDDLE, 0)
		return
	if weather == "overcast":
		try_transition(PetState.OVERCAST_IDLE, 0)
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
	var cur_prio := _state_priority(current_state)
	var new_prio := _state_priority(new_state)
	if new_prio <= cur_prio:
		if current_state != PetState.IDLE and state_time < min_duration:
			return
	enter_state(new_state)
	if not _is_transient(new_state):
		state_timer = randf_range(6.0, 12.0)

func _state_priority(s: PetState) -> int:
	match s:
		PetState.LOW_BATTERY, PetState.STORM_SCARED: return 5
		PetState.RAIN_UMBRELLA, PetState.SNOW_CATCH, PetState.SNOW_FIGHT: return 4
		PetState.RAIN_PUDDLE_JUMP, PetState.COLD_SHIVER, PetState.HOT_MELT: return 4
		PetState.WIND_LEAN, PetState.FOG_WANDER: return 4
		PetState.SANDSTORM_HUDDLE: return 4
		PetState.OVERCAST_IDLE: return 3
		PetState.PHONE_SCROLL, PetState.FESTIVAL: return 3
		PetState.SLEEP_DEEP, PetState.SLEEP_RESTLESS, PetState.WAKE_UP: return 2
		PetState.WALKING, PetState.EAT, PetState.MORNING_WASH, PetState.IDLE: return 1
		_: return 1

func enter_state(state: PetState):
	prev_state = current_state
	current_state = state
	state_time = 0.0
	state_timer = 0.0

	if pet and pet.has_method("play_anim"):
		match state:
			PetState.WALKING:
				pet.play_anim("walk")
				pet.face_front()
			PetState.FOG_WANDER:
				pet.play_anim("walk")
				pet.face_front()
			PetState.WAVE:
				pet.play_anim("wave")
				pet.face_front()
			PetState.SMS_REACT:
				pet.play_anim("wave")
				pet.face_front()
			PetState.FESTIVAL:
				pet.play_anim("wave")
				pet.face_front()
			PetState.SNOW_FIGHT:
				pet.play_anim("wave")
				pet.face_front()
			PetState.MORNING_WASH:
				pet.play_anim("wave")
				pet.face_front()
			PetState.JUMP:
				pet.play_anim("up")
				pet.face_front()
			PetState.WAKE_UP:
				pet.play_anim("up")
				pet.face_front()
			PetState.SPIN:
				pet.play_anim("wave")
				pet.face_front()
			PetState.PLAY_DEAD:
				pet.play_anim("fall")
				pet.face_front()
			PetState.FALL_DOWN:
				pet.play_anim("fall")
				pet.face_front()
			PetState.STORM_SCARED:
				pet.play_anim("fall")
				pet.face_front()
			PetState.LOW_BATTERY:
				pet.play_anim("fall")
				pet.face_front()
			PetState.COLD_SHIVER:
				pet.play_anim("fall")
				pet.face_front()
			PetState.HOT_MELT:
				pet.play_anim("fall")
				pet.face_front()
			PetState.SANDSTORM_HUDDLE:
				pet.play_anim("fall")
				pet.face_front()
			PetState.WIND_LEAN:
				pet.play_anim("tilt_l")
				pet.face_front()
			PetState.TILT_LEFT:
				pet.play_anim("tilt_l")
			PetState.TILT_RIGHT:
				pet.play_anim("tilt_r")
			PetState.RAIN_UMBRELLA:
				pet.play_anim("tilt_l")
				pet.face_front()
			PetState.SLEEP_DEEP:
				pet.play_anim("idle")
				if randi() % 2 == 0:
					pet.face_left()
				else:
					pet.face_right()
			PetState.SLEEP_RESTLESS:
				pet.play_anim("idle")
				if randi() % 2 == 0:
					pet.face_left()
				else:
					pet.face_right()
			PetState.GET_UP:
				pet.play_anim("idle")
				pet.face_front()
			_:
				pet.play_anim("idle")
				pet.face_front()

	state_changed.emit(state, prev_state)

func _update_state(delta: float):
	if not pet:
		return
	var base_pos: Vector2 = pet._base_position if "_base_position" in pet else pet.position
	pet.position = base_pos
	match current_state:
		PetState.IDLE:
			var breathe = sin(state_time * 2.0) * 1.5
			pet.position.y = base_pos.y + breathe
		PetState.WALKING:
			var bounce = sin(state_time * 8.0) * 3.0
			pet.position.y = base_pos.y + bounce
		PetState.FOG_WANDER:
			var drift_x = sin(state_time * 1.2) * 6.0
			var drift_y = cos(state_time * 0.8) * 2.0
			pet.position.x = base_pos.x + drift_x
			pet.position.y = base_pos.y + drift_y
		PetState.SLEEP_DEEP:
			var breathe2 = sin(state_time * 1.5) * 2.0
			pet.position.y = base_pos.y + breathe2
		PetState.SLEEP_RESTLESS:
			var toss = sin(state_time * 12.0) * 2.5
			pet.position.x = base_pos.x + toss
		PetState.WAKE_UP:
			var stretch = sin(state_time * 3.0) * 5.0
			pet.position.y = base_pos.y - abs(stretch)
		PetState.EAT:
			var nom = sin(state_time * 10.0) * 2.0
			pet.position.y = base_pos.y - abs(nom)
		PetState.DRINK_HOT:
			var sip = sin(state_time * 4.0) * 3.0
			pet.position.y = base_pos.y - abs(sip)
		PetState.MORNING_WASH:
			var scrub = sin(state_time * 14.0) * 1.5
			pet.position.x = base_pos.x + scrub
		PetState.PHONE_SCROLL:
			pet.position.y = base_pos.y + 2.0
		PetState.SMS_REACT:
			var alert_bounce = abs(sin(state_time * 6.0)) * 6.0
			pet.position.y = base_pos.y - alert_bounce
		PetState.LOW_BATTERY:
			var drain = sin(state_time * 6.0) * 1.5
			pet.position.y = base_pos.y + 3.0 + drain
		PetState.RAIN_UMBRELLA:
			var sway = sin(state_time * 2.5) * 3.0
			pet.position.x = base_pos.x + sway
		PetState.RAIN_PUDDLE_JUMP:
			var jump = abs(sin(state_time * 5.0)) * 10.0
			pet.position.y = base_pos.y - jump
		PetState.STORM_SCARED:
			var tremble = sin(state_time * 22.0) * 4.0
			pet.position.x = base_pos.x + tremble
		PetState.SNOW_CATCH:
			var reach = sin(state_time * 3.0) * 4.0
			pet.position.y = base_pos.y - abs(reach)
		PetState.SNOW_FIGHT:
			var lunge = sin(state_time * 6.0) * 5.0
			pet.position.x = base_pos.x + lunge
		PetState.COLD_SHIVER:
			var shiver = sin(state_time * 18.0) * 2.0
			pet.position.x = base_pos.x + shiver
			pet.position.y = base_pos.y + 1.0
		PetState.HOT_MELT:
			var melt = minf(state_time * 2.0, 8.0)
			pet.position.y = base_pos.y + melt
		PetState.WIND_LEAN:
			pet.position.x = base_pos.x - 6.0
		PetState.FESTIVAL:
			var party = abs(sin(state_time * 5.0)) * 10.0
			pet.position.y = base_pos.y - party
		PetState.WAVE:
			pass
		PetState.JUMP:
			var jump2 = abs(sin(state_time * 4.0)) * 12.0
			pet.position.y = base_pos.y - jump2
		PetState.SPIN:
			pet.position.y = base_pos.y - abs(sin(state_time * 4.0)) * 5.0
		PetState.PLAY_DEAD:
			pet.position.y = base_pos.y + 4.0
		PetState.FALL_DOWN:
			var impact = maxf(0.0, 3.0 - state_time * 6.0)
			pet.position.y = base_pos.y + impact
		PetState.GET_UP:
			var rise = maxf(0.0, 4.0 - state_time * 4.0)
			pet.position.y = base_pos.y + rise
		PetState.OVERCAST_IDLE:
			var mope = sin(state_time * 1.5) * 1.0
			pet.position.y = base_pos.y + mope
		PetState.SANDSTORM_HUDDLE:
			var buffeted = sin(state_time * 8.0) * 3.0
			pet.position.x = base_pos.x + buffeted
			pet.position.y = base_pos.y + 2.0

func on_touch(type: String):
	match type:
		"tap":
			try_transition(PetState.WAVE if randi() % 2 == 0 else PetState.JUMP, 0.5)
		"longpress":
			try_transition(PetState.PLAY_DEAD, 0)
		"double":
			try_transition(PetState.SPIN, 0)

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
		PetState.OVERCAST_IDLE: return "☁️ 阴沉沉"
		PetState.SANDSTORM_HUDDLE: return "🏜️ 躲沙尘"
		_: return "😊 陪伴你"

func _is_transient(state: PetState) -> bool:
	return state in [PetState.WAVE, PetState.JUMP, PetState.SPIN, PetState.PLAY_DEAD,
		PetState.FALL_DOWN, PetState.GET_UP, PetState.WAKE_UP]
