extends SceneTree
# Local deterministic rendering probe. The shipped scene has no test-data entry.
class Probe extends "res://companion/main.gd":
	func _load_saved() -> void:
		settings = {}; anniversaries = []; use_location = false
	func _save() -> void: pass
var app: Node
var output := ""
var traces: Array = []
func _init() -> void: call_deferred("run")
func shot(name: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	traces.append({"scene":name,"weather":app.world.environment.id,"activity":app.world.activity,"effects":app.calendar_effects.last_frame_recipes,"panel":app.opened_sheet})
func run() -> void:
	output = ProjectSettings.globalize_path("res://../.local/qa/screens")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(540, 1100)
	app = Probe.new(); root.add_child(app); app.capture_mode = true
	app.source.stop(); app.event_source.set_process(false)
	var data: Dictionary = app.Catalog.preset("clear")
	data.merge({"temperature":23.0,"feels":24.0,"humidity":62,"wind":8.0,"is_day":true,"hour":14,"city":"上海","source":"验证数据","observed":"2026-10-26T14:00","saved_at":Time.get_unix_time_from_system(),"utc_offset":28800}, true)
	app._on_live_weather(data); app._update_festival(); app._refresh_labels()
	app.world.environment.is_day = true; app.world.start("idle", 20)
	await shot("01-home")
	app._open_sheet("care"); await shot("02-care")
	app._close_sheet(); app.world.care_cooldown = 0; app._care("drink")
	await shot("03-drink-scene")
	app._open_sheet("journal"); await shot("04-notebook")
	app._open_sheet("settings"); await shot("05-settings")
	app._open_sheet("anniversaries"); await shot("06-anniversaries")
	app._close_sheet()
	for weather in ["drizzle", "heavy_rain", "snow", "windy", "fog", "night"]:
		app.set_demo(weather); app._update_festival(); await shot("weather-" + weather)
	app._preview_date("2026-02-17"); await shot("festival-spring")
	app._preview_date("2026-04-05"); await shot("festival-solemn")
	app._open_sheet("effect_library"); await shot("07-effect-families")
	app._use_live(); app.source.stop(); await shot("08-return-live")
	var file := FileAccess.open(output.path_join("scene-trace.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(traces, "  "))
	print("CAPTURE_DONE " + output)
	app.queue_free(); await process_frame; quit()
