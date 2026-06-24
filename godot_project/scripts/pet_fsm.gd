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
	# 临时交互动作 (挥手/跳跃/转圈/趴下等) 播放约 2.5 秒后自动回到环境态
	if _is_transient(current_state) and state_time > 2.5:
		current_state = PetState.IDLE  # 强制复位, 让 _evaluate_transitions 重新决策
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
	# state_timer > 0 表示当前状态有锁定时长, 未到不切换 (防抖核心)
	if state_timer > 0: return
	# 优先级保护: 高优先级(天气/电量/节日)可打断低优先级(时间表)
	var cur_prio := _state_priority(current_state)
	var new_prio := _state_priority(new_state)
	# 同优先级或更低优先级: 需满足 min_duration
	if new_prio <= cur_prio:
		if current_state != PetState.IDLE and state_time < min_duration:
			return
	enter_state(new_state)
	# 环境态设置持续时长 (5-12秒), 避免边界抖动
	if not _is_transient(new_state):
		state_timer = randf_range(6.0, 12.0)

# 状态优先级: 越高越优先打断
func _state_priority(s: PetState) -> int:
	match s:
		PetState.LOW_BATTERY, PetState.STORM_SCARED: return 5  # 紧急
		PetState.RAIN_UMBRELLA, PetState.SNOW_CATCH, PetState.SNOW_FIGHT: return 4  # 天气
		PetState.RAIN_PUDDLE_JUMP, PetState.COLD_SHIVER, PetState.HOT_MELT: return 4
		PetState.WIND_LEAN, PetState.FOG_WANDER: return 4
		PetState.PHONE_SCROLL, PetState.FESTIVAL: return 3  # 状态
		PetState.SLEEP_DEEP, PetState.SLEEP_RESTLESS, PetState.WAKE_UP: return 2  # 日程
		PetState.WALKING, PetState.EAT, PetState.MORNING_WASH, PetState.IDLE: return 1
		_: return 1

func enter_state(state: PetState):
	prev_state = current_state
	current_state = state
	state_time = 0.0
	state_timer = 0.0

	# 3D 动画驱动: FSM 状态 → glb 动画
	# 模型动画: idle/walk/run/wave/up/fall/tilt_l/tilt_r
	if pet and pet.has_method("play_anim"):
		match state:
			# 散步类 → walk
			PetState.WALKING, PetState.FOG_WANDER:
				pet.play_anim("walk")
				pet.face_front()
			# 互动/庆祝 → wave (挥手)
			PetState.WAVE, PetState.JUMP, PetState.SPIN, PetState.FESTIVAL, PetState.SMS_REACT:
				pet.play_anim("wave")
				pet.face_front()
			# 倒下/趴下/害怕/冷/低电量 → fall (蜷缩)
			PetState.PLAY_DEAD, PetState.FALL_DOWN, PetState.STORM_SCARED, PetState.COLD_SHIVER, PetState.LOW_BATTERY:
				pet.play_anim("fall")
				pet.face_front()
			# 风吹 → tilt
			PetState.WIND_LEAN:
				pet.play_anim("tilt_l")
				pet.face_front()
			PetState.TILT_LEFT:
				pet.play_anim("tilt_l")
			PetState.TILT_RIGHT:
				pet.play_anim("tilt_r")
			# 其余 (睡觉/吃饭/刷手机/撑伞/接雪/热化/起床等) → idle (站姿)
			_:
				pet.play_anim("idle")
				# 睡觉时随机面向一侧, 增加自然感
				if state in [PetState.SLEEP_DEEP, PetState.SLEEP_RESTLESS]:
					if randi() % 2 == 0:
						pet.face_left()
					else:
						pet.face_right()
				else:
					pet.face_front()

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
			# 行走轻微上下浮动
			var bounce = sin(state_time * 8.0) * 3.0
			pet.position.y = base_pos.y + bounce
		PetState.SLEEP_DEEP:
			pet.position.y = base_pos.y + sin(state_time * 2.0) * 1.5
		PetState.SLEEP_RESTLESS:
			var shake = sin(state_time * 12.0) * 2.0
			pet.position.x = base_pos.x + shake
		PetState.STORM_SCARED:
			var shake2 = sin(state_time * 20.0) * 4.0
			pet.position.x = base_pos.x + shake2
		PetState.COLD_SHIVER:
			var shake3 = sin(state_time * 15.0) * 2.0
			pet.position.x = base_pos.x + shake3
		PetState.FESTIVAL:
			var bounce2 = abs(sin(state_time * 4.0)) * 8.0
			pet.position.y = base_pos.y - bounce2

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
