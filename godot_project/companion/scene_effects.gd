extends RefCounted
# Shared scene clock. Catalogue recipes become bounded, contextual performances here.
const Calendar = preload("res://companion/calendar_data.gd")
var reduced_motion := false
var low_power := false
var environment: Dictionary = {}
var festival: Dictionary = {}
var date := ""
var _event_key := ""
var _seen: Dictionary = {}
var _festival_left := 0.0
var _impulse_left := 0.0
var _impulse_kind := ""
var _clock := 0.0

func set_policy(reduced: bool, power: bool) -> void:
	reduced_motion = reduced
	low_power = power
	if low_power: _impulse_left = 0.0

func update_context(env: Dictionary, event: Dictionary, today: String) -> void:
	var changed_day := date != today
	var changed_weather: bool = environment.get("id","") != env.get("id","") or environment.get("is_day",true) != env.get("is_day",true)
	environment = env.duplicate(true)
	festival = event.duplicate(true)
	date = today
	var key := today + ":" + String(event.get("id","")) + ":" + String(event.get("tone","")) + ":" + str(event.get("effect_ids",[]))
	if key != _event_key:
		_event_key = key
		_festival_left = 0.0
		_impulse_left = 0.0
		if not _seen.has(key) and not event.get("matches",[]).is_empty():
			_festival_left = 9.0
			_seen[key] = true
		# Keep only a small recent context history, including preview returns.
		if _seen.size()>64: _seen.erase(_seen.keys()[0])
	if changed_day or changed_weather or _solemn(): _impulse_left = 0.0

func step(delta: float) -> void:
	var dt := maxf(0.0,delta)
	_clock += dt
	_festival_left = maxf(0.0,_festival_left-dt)
	_impulse_left = maxf(0.0,_impulse_left-dt)

func trigger(kind: String) -> void:
	if _solemn() or low_power or _impulse_left>0.0: return
	if kind not in ["pet","wave","drink","sleep","water","fish","tap"]: return
	_impulse_kind = kind
	_impulse_left = 2.8

func _solemn() -> bool:
	return festival.get("tone","") == "solemn"

func _recipe(id: String, source: String, count: int, opacity: float, static_pose: bool = false) -> Dictionary:
	var result := Calendar.effect(id).duplicate(true)
	if result.is_empty(): return result
	result["source"] = source
	result["count"] = count
	result["opacity"] = opacity
	result["static"] = static_pose or reduced_motion
	result["clock"] = _clock
	result["local"] = source in ["interaction","ambience","memorial"]
	return result

func recipe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if low_power: return result
	if _solemn():
		result.append(_recipe("candle_garland","memorial",2,0.55,true))
		return result
	var night := not bool(environment.get("is_day",true))
	var weather := String(environment.get("id","clear"))
	var severe := weather in ["heavy_rain","thunderstorm","snow","heavy_snow","windy","fog"]
	var wet := weather in ["drizzle","rain"]
	if _impulse_left>0.0:
		var id := "cloud_rise" if _impulse_kind=="drink" else ("star_orbit" if _impulse_kind=="sleep" else "heart_rise")
		var item := _recipe(id,"interaction",3, minf(1.0,_impulse_left/0.6),reduced_motion)
		if _impulse_kind=="drink": item["family"]="steam"
		result.append(item)
	if _festival_left>0.0 and not night and not severe:
		var ids: Array = festival.get("effect_ids",[festival.get("effect","")])
		for id in ids.slice(0,1):
			var item := _recipe(String(id),"festival",4 if reduced_motion or wet else 8, minf(1.0,_festival_left/1.5)*(0.35 if wet else 0.7))
			if not item.is_empty() and item.family not in ["raindrop","snowflake"]: result.append(item)
	# Weather renderer owns all rain, snow, fog and wind. Ornament yields to it.
	if not severe and not wet and not reduced_motion:
		var month := int(date.substr(5,2))
		var id := ""
		if night and month in [6,7,8]: id="firefly_wave"
		elif not night and month in [3,4,5]: id="blossom_drift"
		elif not night and month in [6,7,8]: id="butterfly_wave"
		elif not night and month in [9,10,11]: id="leaf_drift"
		if not id.is_empty(): result.append(_recipe(id,"ambience",3,0.28))
	return result
