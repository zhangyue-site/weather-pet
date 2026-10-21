extends SceneTree
const Events = preload("res://companion/events.gd")
const World = preload("res://companion/world.gd")
const Catalog = preload("res://companion/catalog.gd")
var failures: Array[String] = []
func expect(ok: bool, name: String) -> void:
	if not ok: failures.append(name)
func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://companion/content/events.json"))
	expect(Events.valid(data), "bundled content valid")
	var event: Dictionary = Events.current(data, "2026-10-01")
	# Expiry tests isolate National Day; other real observances can share dates.
	var national_only := {"events":[data.events[0]]}
	expect(event.get("id") == "national_day", "National Day October 1")
	expect(Events.current(data, "2026-10-07").get("id") == "national_day", "last celebration day")
	expect(Events.current(national_only, "2026-10-08").is_empty(), "event expires")
	expect(Events.current(national_only, "2026-09-30").is_empty(), "no early celebration")
	var invalid: Dictionary = data.duplicate(true)
	invalid.events[0].actions = ["execute_script"]
	expect(not Events.valid(invalid), "reject unshipped actions")
	invalid = data.duplicate(true)
	invalid.events[0].month_day = "02-30"
	expect(not Events.valid(invalid), "reject impossible date")
	invalid = data.duplicate(true)
	invalid.events[0].days = -1
	expect(not Events.valid(invalid), "reject invalid duration")
	invalid = data.duplicate(true)
	invalid.events[0].date = 20261001
	expect(not Events.valid(invalid), "reject malformed date field")
	var dated: Dictionary = data.duplicate(true)
	dated.events = [data.events[0].duplicate(true)]
	dated.events[0].erase("month_day")
	dated.events[0].date = "2026-12-31"
	dated.events[0].days = 2
	expect(Events.valid(dated), "specific-year event")
	expect(not Events.current(dated,"2027-01-01").is_empty(), "cross-year event")
	expect(Events.current(dated,"2027-12-31").is_empty(), "dated event not annual")
	var w = World.new()
	w.set_festival(event)
	w.choose_activity()
	expect(w.activity.begins_with("celebrate_"), "auto celebration")
	for i in range(140): w.step(0.05)
	expect(not w.activity.begins_with("celebrate_"), "celebration cooldown")
	w.set_environment(Catalog.preset("rain"))
	expect(w.activity == "notice", "rain interrupts celebration")
	expect(not w.celebrate(), "cannot celebrate instead of umbrella")
	w.set_environment(Catalog.preset("night"))
	expect(not w.celebrate(), "sleep takes priority")
	w.set_environment(Catalog.preset("clear"))
	w.celebrate()
	w.set_festival({})
	expect(not w.activity.begins_with("celebrate_"), "midnight expires active celebration")
	if failures.is_empty(): push_warning("PASS test_events: dates, remote validation, weather priority, cooldown, expiry")
	else:
		for failure in failures: push_error("FAIL " + failure)
	quit(0 if failures.is_empty() else 1)
