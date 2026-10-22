extends RefCounted
const Calendar = preload("res://companion/calendar_data.gd")
const ACTIONS = ["celebrate_wave", "celebrate_dance", "celebrate_cheer", "idle", "notice", "wave", "stretch", "drink", "water", "pet", "walk"]
const MAX_BYTES = 131072
const TERMS = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"]

static func _integer(v: Variant, low: int, high: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and v >= low and v <= high

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if not _integer(data.get("schema"), 1, 2) or not data.get("events") is Array: return false
	if not _integer(data.get("revision"), 1, 2147483647) or data.events.size() > 128: return false
	var ids: Array = []
	for event in data.events:
		if not valid_event(event): return false
		if event.id in ids: return false
		ids.append(event.id)
	return true

static func valid_event(event: Variant) -> bool:
	if not event is Dictionary: return false
	for key in ["id", "title", "caption"]:
		if not event.get(key) is String or event[key].is_empty() or event[key].length() > 120: return false
	var rules: = 0
	for key in ["date", "month_day", "lunar_day", "lunar_eve", "week_day", "solar_term"]:
		if event.has(key): rules += 1
	if rules != 1: return false
	if event.has("date") and ( not event.date is String or not _valid_date(event.date)): return false
	if event.has("month_day") and ( not event.month_day is String or not _valid_date("2000-" + event.month_day)): return false
	if event.has("lunar_day"):
		if not event.lunar_day is String or not _valid_date("2000-" + event.lunar_day): return false
		if int(event.lunar_day.substr(3, 2)) > 30: return false
	if event.has("lunar_eve") and event.lunar_eve != true: return false
	if event.has("leap_month") and not event.leap_month is bool: return false
	if event.has("week_day"):
		if not event.week_day is Array or event.week_day.size() != 3: return false
		if not _integer(event.week_day[0], 1, 12) or not _integer(event.week_day[1], 1, 5) or not _integer(event.week_day[2], 0, 6): return false
	if event.has("solar_term") and ( not event.solar_term is String or event.solar_term not in TERMS): return false
	if not _integer(event.get("days"), 1, 14): return false
	if event.has("priority") and not _integer(event.priority, 0, 110): return false
	if event.has("tone") and event.tone not in ["gentle", "joyful", "solemn"]: return false
	if event.has("kind") and event.kind not in ["festival", "observance", "memorial", "anniversary", "solar_term", "daily"]: return false
	if event.has("effect") and ( not event.effect is String or Calendar.effect(event.effect).is_empty()): return false
	if not event.get("actions") is Array or event.actions.is_empty() or event.actions.size() > 8: return false
	for action in event.actions:
		if action not in ACTIONS: return false
	return true

static func _valid_date(date: String) -> bool:
	if date.length() != 10 or date[4] != "-" or date[7] != "-": return false
	for i in [0, 1, 2, 3, 5, 6, 8, 9]:
		if not date[i].is_valid_int(): return false
	var year: = int(date.substr(0, 4))
	var month: = int(date.substr(5, 2))
	var day: = int(date.substr(8, 2))
	if year < 1970 or month < 1 or month > 12 or day < 1: return false
	var lengths: = [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day <= lengths[month - 1]

static func _starts(event: Dictionary, date: String) -> bool:
	if event.has("date"): return event.date == date
	if event.has("month_day"): return event.month_day == date.substr(5, 5)
	if event.has("week_day"):
		var d: = Time.get_datetime_dict_from_datetime_string(date + "T12:00:00", true)
		return int(d.month) == int(event.week_day[0]) and int((int(d.day) - 1) / 7) + 1 == int(event.week_day[1]) and int(d.weekday) == int(event.week_day[2])
	var lunar: = Calendar.lunar(date)
	if lunar.is_empty(): return false
	if event.has("lunar_day"):
		return "%02d-%02d" % [lunar.month, lunar.day] == event.lunar_day and bool(lunar.leap) == bool(event.get("leap_month", false))
	if event.has("solar_term"): return event.solar_term == lunar.term
	if event.has("lunar_eve"):
		var next: = Calendar.lunar(Calendar.shift(date, 1))
		return not next.is_empty() and next.month == 1 and next.day == 1 and not next.leap
	return false

static func matching(data: Dictionary, date: String, personal: Array = []) -> Array:
	if not _valid_date(date): return []
	var result: Array = []
	var combined: Array = data.get("events", []).duplicate()
	combined.append_array(personal)
	for event in combined:
		for offset in range(int(event.days)):
			if _starts(event, Calendar.shift(date, - offset)):
				result.append(event.duplicate(true))
				break
	result.sort_custom( func(a, b): return int(a.get("priority", 70)) > int(b.get("priority", 70)))
	return result

static func current(data: Dictionary, date: String) -> Dictionary:
	var matches: = matching(data, date)
	return matches[0] if not matches.is_empty() else {}

static func program(data: Dictionary, date: String, personal: Array = []) -> Dictionary:
	var base: = Calendar.daily_program(date)
	var matches: = matching(data, date, personal)
	var result: Dictionary = base.duplicate(true) if matches.is_empty() else matches[0].duplicate(true)
	result["date"] = date
	result["daily_title"] = base.title
	result["matches"] = matches
	result["lunar"] = Calendar.lunar(date)
	result["effect_ids"] = [result.get("effect", base.effect)]

	var solemn: = false
	for event in matches:
		if event.get("tone", "joyful") == "solemn": solemn = true
	if solemn:
		result.tone = "solemn"
		result.actions = ["idle", "notice"]
		result.effect_ids = ["candle_garland"]
	else:
		for event in matches:
			var effect: String = event.get("effect", base.effect)
			if effect not in result.effect_ids and result.effect_ids.size() < 2: result.effect_ids.append(effect)
	return result
