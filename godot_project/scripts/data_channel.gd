extends Node

signal weather_updated(condition: String, temperature: float, humidity: float, wind_speed: float)
signal time_updated(hour: int, minute: int)
signal festival_today(name: String, emoji: String)
signal signal_changed(strength: int)
signal sms_received(sender: String, preview: String)
signal battery_changed(percent: int, charging: bool)
signal touch_occurred(mode: String, x: float, y: float)
signal data_pushed()

var http: HTTPRequest = null
var plugin_ref: Object = null

var current_hour: int = 8
var current_minute: int = 0

# ---- PC 演示循环 (无插件时轮播天气 + 加速时间, 便于预览各种效果) ----
var _demo_mode: bool = false
var _demo_timer: float = 0.0
const _DEMO_WEATHER_CYCLE: Array[String] = [
	"clear", "cloudy", "overcast", "rain", "heavy_rain", "thunderstorm",
	"snow", "heavy_snow", "fog", "windy"
]
const _DEMO_WEATHER_TEMP: Dictionary = {
	"clear": 24.0, "cloudy": 21.0, "overcast": 18.0,
	"rain": 16.0, "heavy_rain": 14.0, "thunderstorm": 13.0,
	"snow": -2.0, "heavy_snow": -5.0, "fog": 10.0, "windy": 19.0
}
var _demo_cycle_index: int = 0
var current_weather: Dictionary = {
	"condition": "clear",
	"temperature": 22.0,
	"humidity": 50.0,
	"wind_speed": 5.0
}
var city_name: String = "深圳"
var phone_signal: int = 4
var battery_percent: int = 85
var is_charging: bool = false
var current_festival: Dictionary = {"name": "", "emoji": ""}

# ---- 位置模式 ----
# location_mode: "gps"(实时定位) / "custom"(自定义) / "demo"(PC演示轮播)
var location_mode: String = "gps"
var current_coord: String = ""  # "经度,纬度"
# 预设城市 (PC演示模式 + 真机自定义位置共用)
const PRESET_CITIES: Array[Dictionary] = [
	{"name": "北京", "lon": 116.41, "lat": 39.92},
	{"name": "上海", "lon": 121.47, "lat": 31.23},
	{"name": "深圳", "lon": 114.06, "lat": 22.55},
	{"name": "广州", "lon": 113.26, "lat": 23.13},
	{"name": "杭州", "lon": 120.16, "lat": 30.27},
	{"name": "成都", "lon": 104.07, "lat": 30.67},
	{"name": "武汉", "lon": 114.31, "lat": 30.59},
	{"name": "西安", "lon": 108.94, "lat": 34.34},
	{"name": "哈尔滨", "lon": 126.64, "lat": 45.75},
	{"name": "昆明", "lon": 102.83, "lat": 24.88},
	{"name": "乌鲁木齐", "lon": 87.62, "lat": 43.83},
	{"name": "拉萨", "lon": 91.13, "lat": 29.65},
	{"name": "香港", "lon": 114.17, "lat": 22.32},
	{"name": "台北", "lon": 121.56, "lat": 25.03}
]
var _city_index: int = 2  # 默认深圳

func _ready():
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_http_request_completed)

	_connect_plugin()
	_update_system_time()
	feed_weather('{"condition":"clear","temperature":22,"humidity":50,"wind_speed":5,"city_name":"深圳"}')
	_feed_local_festival()

	if plugin_ref == null:
		_demo_mode = true
		location_mode = "demo"
		_push_demo()

func _process(delta: float):
	if plugin_ref == null:
		_connect_plugin()
	if plugin_ref != null:
		# 真机: 不每帧 push (避免干扰), 时间/天气靠插件信号推送
		# 仅在启动后 3 秒内补一次系统时间 (插件 on_time 可能延迟)
		if _time_since_start < 3.0:
			_update_system_time()
	elif _demo_mode:
		# PC 演示: 加速时间 (1 秒 = 演示 2 分钟) + 每 8 秒切换天气
		_demo_timer += delta
		var demo_min_step := int(_demo_timer * 2.0)
		if demo_min_step > 0:
			_demo_timer -= demo_min_step / 2.0
			var total := current_hour * 60 + current_minute + demo_min_step
			total = total % 1440  # 24 小时循环
			feed_time(int(total / 60), total % 60)
		# 天气轮播: 每 8 秒切换一种天气 (保留用户手动选的城市, 不覆盖)
		var weather_slot := int(_time_since_start / 8.0) % _DEMO_WEATHER_CYCLE.size()
		if weather_slot != _demo_cycle_index:
			_demo_cycle_index = weather_slot
			var w := _DEMO_WEATHER_CYCLE[_demo_cycle_index]
			var t: float = _DEMO_WEATHER_TEMP.get(w, 22.0)
			feed_weather('{"condition":"%s","temperature":%.1f,"humidity":50,"wind_speed":5,"city_name":"%s"}' % [w, t, city_name])
		push_data()

var _time_since_start: float = 0.0

func _physics_process(delta: float):
	_time_since_start += delta

func _connect_plugin():
	if not Engine.has_singleton("WeatherPetPlugin"):
		return

	plugin_ref = Engine.get_singleton("WeatherPetPlugin")
	if plugin_ref == null:
		return

	if not plugin_ref.is_connected("on_weather", Callable(self, "_on_plugin_weather")):
		plugin_ref.connect("on_weather", Callable(self, "_on_plugin_weather"))
	if not plugin_ref.is_connected("on_time", Callable(self, "_on_plugin_time")):
		plugin_ref.connect("on_time", Callable(self, "_on_plugin_time"))
	if not plugin_ref.is_connected("on_signal", Callable(self, "_on_plugin_signal")):
		plugin_ref.connect("on_signal", Callable(self, "_on_plugin_signal"))
	if not plugin_ref.is_connected("on_sms", Callable(self, "_on_plugin_sms")):
		plugin_ref.connect("on_sms", Callable(self, "_on_plugin_sms"))
	if not plugin_ref.is_connected("on_battery", Callable(self, "_on_plugin_battery")):
		plugin_ref.connect("on_battery", Callable(self, "_on_plugin_battery"))
	if not plugin_ref.is_connected("on_festival", Callable(self, "_on_plugin_festival")):
		plugin_ref.connect("on_festival", Callable(self, "_on_plugin_festival"))
	if not plugin_ref.is_connected("on_touch", Callable(self, "_on_plugin_touch")):
		plugin_ref.connect("on_touch", Callable(self, "_on_plugin_touch"))
	if plugin_ref.has_signal("on_location") and not plugin_ref.is_connected("on_location", Callable(self, "_on_plugin_location")):
		plugin_ref.connect("on_location", Callable(self, "_on_plugin_location"))

	print("DataChannel connected to WeatherPetPlugin")
	if plugin_ref.has_method("start"):
		print("DataChannel invoking WeatherPetPlugin.start")
		plugin_ref.call("start", "")

func _update_system_time():
	var system_time: Dictionary = Time.get_datetime_dict_from_system()
	feed_time(int(system_time.get("hour", 8)), int(system_time.get("minute", 0)))

func feed_weather(json_str: String):
	var parser: JSON = JSON.new()
	if parser.parse(json_str) != OK:
		return

	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed as Dictionary
	current_weather = {
		"condition": String(data.get("condition", "clear")),
		"temperature": float(data.get("temperature", 22.0)),
		"humidity": float(data.get("humidity", 50.0)),
		"wind_speed": float(data.get("wind_speed", 5.0))
	}
	city_name = String(data.get("city_name", city_name))

	weather_updated.emit(
		String(current_weather["condition"]),
		float(current_weather["temperature"]),
		float(current_weather["humidity"]),
		float(current_weather["wind_speed"])
	)

func feed_time(hour: int, minute: int):
	current_hour = hour
	current_minute = minute
	time_updated.emit(hour, minute)

func feed_festival(name: String, emoji: String):
	current_festival = {"name": name, "emoji": emoji}
	festival_today.emit(name, emoji)

func feed_signal(strength: int):
	phone_signal = strength
	signal_changed.emit(strength)

func feed_sms(sender: String, preview: String):
	sms_received.emit(sender, preview)

func feed_touch(mode: String, x: float, y: float):
	touch_occurred.emit(mode, x, y)

func feed_battery(percent: int, charging: bool):
	battery_percent = percent
	is_charging = charging
	battery_changed.emit(percent, charging)

func push_data():
	data_pushed.emit()

func _feed_local_festival():
	var today_key: int = _current_day_key()
	var local_festivals: Dictionary = {
		60: {"name": "春节", "emoji": "🧨"},
		74: {"name": "元宵节", "emoji": "🏮"},
		128: {"name": "清明节", "emoji": "🌿"},
		186: {"name": "端午节", "emoji": "🐉"},
		308: {"name": "中秋节", "emoji": "🌕"},
		311: {"name": "国庆节", "emoji": "🇨🇳"}
	}
	if local_festivals.has(today_key):
		var festival: Dictionary = local_festivals[today_key] as Dictionary
		feed_festival(String(festival.get("name", "")), String(festival.get("emoji", "")))

func _current_day_key() -> int:
	var system_time: Dictionary = Time.get_datetime_dict_from_system()
	return int(system_time.get("day", 1)) + int(system_time.get("month", 1)) * 31

func _push_demo():
	_update_system_time()
	current_weather = {
		"condition": "clear",
		"temperature": 22.0,
		"humidity": 50.0,
		"wind_speed": 5.0
	}
	city_name = "深圳"
	phone_signal = 4
	battery_percent = 85
	is_charging = false
	if String(current_festival.get("name", "")) == "":
		current_festival = {"name": "", "emoji": ""}
	push_data()

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_push_demo()
		return

	var parser: JSON = JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		_push_demo()
		return

	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		_push_demo()
		return

	var response: Dictionary = parsed as Dictionary
	var current_list: Variant = response.get("current_condition", [])
	if typeof(current_list) != TYPE_ARRAY:
		_push_demo()
		return

	var current_array: Array = current_list as Array
	if current_array.is_empty():
		_push_demo()
		return

	var current: Dictionary = current_array[0] as Dictionary
	var condition_text: String = "clear"
	var descriptions_variant: Variant = current.get("weatherDesc", [])
	if typeof(descriptions_variant) == TYPE_ARRAY:
		var descriptions: Array = descriptions_variant as Array
		if not descriptions.is_empty():
			var first_desc: Dictionary = descriptions[0] as Dictionary
			condition_text = String(first_desc.get("value", "clear")).to_lower().replace(" ", "_")

	var payload: Dictionary = {
		"condition": condition_text,
		"temperature": float(current.get("temp_C", 22.0)),
		"humidity": float(current.get("humidity", 50.0)),
		"wind_speed": float(current.get("windspeedKmph", 5.0)),
		"city_name": city_name
	}
	feed_weather(JSON.stringify(payload))
	push_data()

func _on_plugin_weather(json_str: String):
	feed_weather(json_str)
	push_data()

func _on_plugin_time(hour: int, minute: int):
	feed_time(hour, minute)
	push_data()

func _on_plugin_signal(strength: int):
	feed_signal(strength)
	push_data()

func _on_plugin_sms(sender: String):
	feed_sms(sender, "")
	push_data()

func _on_plugin_battery(percent: int, charging: bool):
	feed_battery(percent, charging)
	push_data()

func _on_plugin_festival(name: String, emoji: String):
	feed_festival(name, emoji)
	push_data()

func _on_plugin_touch(mode: String, x: float, y: float):
	touch_occurred.emit(mode, x, y)
	push_data()

func _on_plugin_location(json_str: String):
	# 插件上报的位置: {"lon":..,"lat":..,"mode":"gps"|"custom"}
	var parser: JSON = JSON.new()
	if parser.parse(json_str) == OK and typeof(parser.data) == TYPE_DICTIONARY:
		var d: Dictionary = parser.data
		var lon: float = float(d.get("lon", 0.0))
		var lat: float = float(d.get("lat", 0.0))
		current_coord = "%.4f,%.4f" % [lon, lat]
		var mode: String = String(d.get("mode", "gps"))
		if mode == "gps":
			location_mode = "gps"
		if d.has("city"):
			city_name = String(d.get("city", city_name))
	push_data()

# ============================================================
#  位置切换 (供 main_scene 调用)
# ============================================================

## 切换到 GPS 实时定位模式 (真机)
func switch_to_gps():
	if plugin_ref != null and plugin_ref.has_method("useGpsLocation"):
		location_mode = "gps"
		plugin_ref.call("useGpsLocation")
	else:
		# PC 演示: GPS 不可用, 保持 demo
		location_mode = "demo"
	push_data()

## 切换到下一个预设城市 (自定义位置)
func switch_to_next_city():
	_city_index = (_city_index + 1) % PRESET_CITIES.size()
	var city: Dictionary = PRESET_CITIES[_city_index]
	city_name = String(city["name"])
	current_coord = "%.4f,%.4f" % [float(city["lon"]), float(city["lat"])]
	location_mode = "custom"
	if plugin_ref != null and plugin_ref.has_method("setCustomLocation"):
		plugin_ref.call("setCustomLocation", float(city["lon"]), float(city["lat"]), String(city["name"]))
	push_data()

## 设置指定城市 (按名称)
func set_city_by_name(city_name_arg: String) -> bool:
	for i in range(PRESET_CITIES.size()):
		if String(PRESET_CITIES[i]["name"]) == city_name_arg:
			_city_index = i
			var city: Dictionary = PRESET_CITIES[i]
			self.city_name = city_name_arg
			current_coord = "%.4f,%.4f" % [float(city["lon"]), float(city["lat"])]
			location_mode = "custom"
			if plugin_ref != null and plugin_ref.has_method("setCustomLocation"):
				plugin_ref.call("setCustomLocation", float(city["lon"]), float(city["lat"]), city_name_arg)
			push_data()
			return true
	return false

## 获取预设城市列表 (名称数组)
func get_city_names() -> PackedStringArray:
	var names := PackedStringArray()
	for c in PRESET_CITIES:
		names.append(String(c["name"]))
	return names
