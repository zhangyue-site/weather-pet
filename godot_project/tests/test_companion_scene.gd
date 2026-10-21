extends SceneTree
var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene: PackedScene = load("res://companion/main.tscn")
	var app = scene.instantiate()
	root.add_child(app)
	app.capture_mode = true # Do not write to the user's desktop save.
	app.source.stop()
	app.set_demo("clear")
	await process_frame
	for size in [Vector2i(540,960),Vector2i(360,800),Vector2i(540,1200)]:
		root.size = size
		await process_frame
		app._layout()
		var viewport: Vector2 = app.get_viewport_rect().size
		expect(app.bottom.get_rect().end.x <= viewport.x+1,"bottom width " + str(size))
		expect(app.bottom.get_rect().end.y <= viewport.y+1,"bottom height " + str(size))
		for panel in ["weather","care","journal","settings","festivals","anniversaries","effect_library"]:
			app._open_sheet(panel)
			await process_frame
			expect(app.sheet.visible,"panel opens " + panel)
			expect(app.sheet.get_rect().end.x <= viewport.x+1,"sheet width " + panel)
			app._close_sheet()
	app._open_sheet("care")
	var before: int = app.world.bond
	app.world.care_cooldown = 0
	var care_button: Button = app.sheet_content.get_child(3)
	care_button.pressed.emit()
	expect(app.world.bond == before+1,"care button reaches behavior")
	expect(not app.sheet.visible,"care closes sheet")
	expect(app.effects.hearts.size()>0,"care generates visible affection")
	app.set_demo("rain")
	for i in range(100): app.world.step(0.05)
	expect(app.world.activity == "umbrella","scene rain chain")
	app._update_background()
	expect(app.background_now == "rain","scene rain background")
	app.set_demo("night")
	for i in range(160): app.world.step(0.05)
	app._update_background()
	expect(app.background_now == "night","scene night background")
	expect(app.world.activity == "sleep","scene sleep")
	app._preview_festival(app.event_source.catalog.events[0])
	expect(app.world.activity.begins_with("celebrate_"), "festival preview animates")
	expect(app.festival_label.text.contains("欢度国庆"), "festival title visible")
	app.queue_free()
	await process_frame
	if failures.is_empty(): push_warning("PASS test_companion_scene: layouts, 4 panels, care dispatch, particles, rain/night integration")
	else:
		for failure in failures: push_error("FAIL " + failure)
	quit(0 if failures.is_empty() else 1)
