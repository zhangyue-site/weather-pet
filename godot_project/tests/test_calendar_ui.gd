extends SceneTree
var failures: Array[String] = []
func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _init() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://companion/main.tscn").instantiate()
	root.add_child(app)
	app.capture_mode = true
	app.source.stop()
	app.anniversaries = []
	app._open_sheet("anniversaries")
	var fields: Array = []
	var selectors: Array = []
	for child in app.sheet_content.get_children():
		if child is LineEdit: fields.append(child)
		if child is OptionButton: selectors.append(child)
	fields[0].text = "生日"
	fields[1].text = "08-15"
	selectors[0].selected = 1
	app.sheet_content.get_child(app.sheet_content.get_child_count()-1).pressed.emit()
	expect(app.anniversaries.size()==1 and app.anniversaries[0].lunar_day=="08-15","form saves lunar birthday")
	app._preview_date("2026-09-25")
	expect(app.world.festival.matches.size()>=2,"birthday overlays Mid Autumn")
	expect(app.calendar_label.text.contains("八月十五"),"lunar date shown on main view")
	app._open_sheet("effect_library")
	var nav = app.sheet_content.get_child(2)
	nav.get_child(1).pressed.emit()
	expect(app.effect_page==1,"effect pagination")
	app.sheet_content.get_child(3).pressed.emit()
	expect(not app.calendar_effects.override_id.is_empty(),"effect button renders chosen recipe")
	app._preview_date("2026-02-17")
	expect(app.calendar_effects.override_id.is_empty(),"date selection clears stale effect override")
	expect(app.world.festival.id=="spring_festival","date selection resolves lunar festival")
	app.queue_free()
	await process_frame
	if failures.is_empty(): push_warning("PASS test_calendar_ui: birthday form, overlapping calendar, effect browsing and reset")
	else:
		for failure in failures: push_error("FAIL "+failure)
	quit(0 if failures.is_empty() else 1)
