extends RefCounted

static var table: Dictionary = {}
static var daily: Dictionary = {}
static var effects: Dictionary = {}
static var effect_order: Array = []

static func ensure_loaded() -> void :
	if not daily.is_empty(): return
	table = JSON.parse_string(FileAccess.get_file_as_string("res://companion/content/lunar_calendar.json")).days
	daily = JSON.parse_string(FileAccess.get_file_as_string("res://companion/content/daily.json")).days
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companion/content/effects.json"))
	for effect in data.effects:
		effects[effect.id] = effect
		effect_order.append(effect.id)

static func lunar(date: String) -> Dictionary:
	ensure_loaded()
	if not table.has(date): return {}
	var row: Array = table[date]
	return {"year": int(row[0]), "month": absi(int(row[1])), "day": int(row[2]), "leap": int(row[1]) < 0, "title": String(row[3]), "term": String(row[4])}

static func shift(date: String, days: int) -> String:
	return Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(date + "T12:00:00") + days * 86400)

static func daily_program(date: String) -> Dictionary:
	ensure_loaded()
	var result: Dictionary = daily.get(date.substr(5, 5), daily["01-01"]).duplicate(true)
	result.id += "_" + date
	return result

static func effect(id: String) -> Dictionary:
	ensure_loaded()
	return effects.get(id, {})
