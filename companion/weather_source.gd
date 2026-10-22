extends Node
signal updated(data: Dictionary)
signal status_changed(text: String)
const Catalog = preload("res://companion/catalog.gd")
var request_node: HTTPRequest
var city_index: = 0
var cache: Dictionary = {}
var pending_city: = 0
var enabled: = false
var last_data: Dictionary = {}
var refresh_elapsed: = 0.0
var custom_target: Dictionary = {}
var pending_key: = "0"
var pending_name: = "上海"
const PROXY_URL: = "https://zz.zhangyue.site/om/v1/forecast"
const DIRECT_URL: = "https://api.open-meteo.com/v1/forecast"
var use_fallback: = false
var last_query: = ""
var req_gen: = 0

func _ready() -> void :
	request_node = HTTPRequest.new()
	request_node.timeout = 18
	add_child(request_node)
	request_node.request_completed.connect(_completed)
	var f: = FileAccess.open("user://companion_weather.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary: cache = parsed

func _process(delta: float) -> void :
	if not enabled: return
	refresh_elapsed += delta
	if refresh_elapsed >= 900:
		refresh_elapsed = 0.0
		if custom_target.is_empty(): fetch(city_index)
		else: _fetch_target(custom_target, pending_key)

func stop() -> void :
	enabled = false
	if request_node != null and is_instance_valid(request_node): request_node.cancel_request()

func fetch(index: int) -> void :
	city_index = clampi(index, 0, Catalog.CITIES.size() - 1)
	pending_city = city_index
	custom_target = {}
	_fetch_target(Catalog.CITIES[city_index], str(city_index))

func fetch_coordinates(lat: float, lon: float) -> void :
	if lat < -90 or lat > 90 or lon < -180 or lon > 180: return
	custom_target = {"lat": lat, "lon": lon, "name": "当前位置"}
	_fetch_target(custom_target, "location_%.2f_%.2f" % [lat, lon])

func _fetch_target(city: Dictionary, key: String) -> void :
	enabled = true
	pending_key = key
	pending_name = String(city.name)
	request_node.cancel_request()
	last_data = {}
	if cache.get(key) is Dictionary:
		var saved: Dictionary = cache[key].duplicate(true)
		if saved.has("id") and saved.has("temperature") and saved.has("saved_at") and saved.has("observed"):
			saved["source"] = "缓存"
			last_data = saved
			updated.emit(saved)
	status_changed.emit("正在更新天气…")
	last_query = "latitude=%.4f&longitude=%.4f&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&daily=sunrise,sunset&forecast_days=1&timezone=auto" % [city.lat, city.lon]
	use_fallback = false
	_request(PROXY_URL, 8.0)

func _failed() -> void :
	status_changed.emit("网络暂不可用 · 使用缓存" if not last_data.is_empty() else "暂无天气 · 请重试或体验场景")

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void :
	if not enabled: return
	if int(get_meta("gen", -1)) != req_gen: return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_retry_or_fail()
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json is Dictionary or not json.get("current") is Dictionary:
		_failed()
		return
	var c: Dictionary = json.current
	for required in ["temperature_2m", "apparent_temperature", "weather_code", "wind_speed_10m", "relative_humidity_2m", "is_day", "time"]:
		if not c.has(required) or c[required] == null:
			_failed()
			return
	var id: String = Catalog.from_wmo(int(c.weather_code), float(c.temperature_2m), float(c.wind_speed_10m))
	var data: Dictionary = Catalog.preset(id)
	data.merge({"temperature": float(c.temperature_2m), "feels": float(c.apparent_temperature), "wind": float(c.wind_speed_10m), "humidity": float(c.relative_humidity_2m), "is_day": bool(c.is_day), "hour": int(String(c.time).substr(11, 2)), "observed": String(c.time), "city": pending_name, "source": "实时", "saved_at": Time.get_unix_time_from_system()}, true)
	data["utc_offset"] = int(json.get("utc_offset_seconds", 28800))
	if json.get("daily") is Dictionary:
		for key in ["sunrise", "sunset"]:
			if json.daily.get(key) is Array and not json.daily[key].is_empty(): data[key] = String(json.daily[key][0])
	cache[pending_key] = data
	var f: = FileAccess.open("user://companion_weather.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(cache))
	last_data = data
	refresh_elapsed = 0
	updated.emit(data)
	status_changed.emit("天气已更新")

static func clock_state(data: Dictionary, unix_now: float = -1.0) -> Dictionary:
	var now: float = Time.get_unix_time_from_system() if unix_now < 0 else unix_now
	var local_unix: = int(now) + int(data.get("utc_offset", 28800))
	var local: = Time.get_datetime_dict_from_unix_time(local_unix)
	var minute: int = int(local.hour) * 60 + int(local.minute)
	var rise: = 6 * 60
	var setting: = 18 * 60

	var sunrise: String = String(data.get("sunrise", ""))
	var sunset: String = String(data.get("sunset", ""))
	if sunrise.length() >= 16: rise = int(sunrise.substr(11, 2)) * 60 + int(sunrise.substr(14, 2))
	if sunset.length() >= 16: setting = int(sunset.substr(11, 2)) * 60 + int(sunset.substr(14, 2))
	var phase: = "day"
	if minute < rise - 25 or minute > setting + 30: phase = "night"
	elif minute <= rise + 25: phase = "dawn"
	elif minute >= setting - 25: phase = "dusk"
	return {"hour": int(local.hour), "minute": int(local.minute), "is_day": phase != "night", "phase": phase}


func _request(base: String, timeout: float) -> void :
	req_gen += 1
	set_meta("gen", req_gen)
	request_node.timeout = timeout
	var error: = request_node.request(base + "?" + last_query)
	if error != OK: _retry_or_fail()

func _retry_or_fail() -> void :
	if not use_fallback:
		use_fallback = true
		status_changed.emit("主线路慢 · 换备用线路")
		_request(DIRECT_URL, 14.0)
	else:
		_failed()

func rename_current_city(city_name: String) -> void :
	if custom_target.is_empty(): return
	custom_target["name"] = city_name
	pending_name = city_name
	if last_data.is_empty() or String(last_data.get("city", "")) != "当前位置": return
	last_data["city"] = city_name
	if cache.has(pending_key):
		cache[pending_key]["city"] = city_name
		var f: = FileAccess.open("user://companion_weather.json", FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(cache))
	updated.emit(last_data)
