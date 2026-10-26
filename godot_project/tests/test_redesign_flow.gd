extends SceneTree
class TestMain extends "res://companion/main.gd":
	func _load_saved() -> void:
		settings = {}; anniversaries = []; use_location = false
	func _save() -> void: pass
var failures: Array[String] = []
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var result := find_button(child, text)
		if result != null: return result
	return null
func _init() -> void: call_deferred("run")
func run() -> void:
	var app = TestMain.new(); root.add_child(app)
	app.capture_mode = true; app.source.stop(); app.event_source.set_process(false)
	app.fish.set_process(false); app.set_process(false)
	var dock: Node = app.bottom.find_child("HomeActions", true, false)
	expect(dock != null and dock.get_child_count() == 2, "home has exactly two frequent actions")
	expect(find_button(app.bottom, "陪一会儿") != null, "care reachable from home")
	expect(find_button(app.bottom, "小院手记") != null, "notebook reachable from home")
	app._open_sheet("care")
	var bond_before: int = app.world.bond
	var shortcut := InputEventKey.new(); shortcut.pressed = true; shortcut.keycode = KEY_SPACE
	app._unhandled_input(shortcut)
	expect(app.world.bond == bond_before, "modal blocks scene keyboard shortcuts")
	expect(find_button(app.sheet_content, "摸摸头") != null and find_button(app.sheet_content, "喝热饮") != null, "care offers direct actions")
	expect(find_button(app.sheet_content, "陪伴日记") == null, "care removes duplicate notebook entry")
	app._close_sheet()
	var selected: int = app.city_index
	app._open_sheet("city"); app._close_sheet()
	expect(app.city_index == selected, "cancel city sheet leaves selected city unchanged")
	app._open_sheet("settings")
	expect(find_button(app.sheet_content, "上海") == null, "city grid no longer duplicated in settings")
	expect(find_button(app.sheet_content, "天气与节日体验  ›") != null, "exploration lives in settings")
	app._open_sheet("journal")
	expect(find_button(app.sheet_content, "日记") != null and find_button(app.sheet_content, "纪念日") != null, "notebook has two tabs")
	app._close_sheet()
	app.world.journal = [{"text":"真实记录", "time":"10-26 09:00"}]
	app.world.bond = 12; app.fish.memory = {"2026-10-26:quiet_pair":true}
	var real_world = app.world
	var real_director = app.scene_effects
	app.scene_effects.update_context(app.world.environment, {"id":"birthday", "tone":"joyful", "effect_ids":["heart_rise"], "matches":[{}]}, "2026-10-26")
	app.scene_effects.step(2.0)
	var effect_time: float = app.scene_effects._festival_left
	app.set_demo("snow")
	app.world.care_cooldown = 0; app._care("pet")
	expect(real_world.bond == 12 and real_world.journal.size() == 1, "preview interactions do not alter real records")
	app._use_live(); app.source.stop()
	expect(app.world == real_world and app.world.bond == 12, "return to live restores real world")
	expect(app.scene_effects == real_director and app.scene_effects._festival_left == effect_time, "preview preserves real festival effect progress")
	expect(app.fish.memory.has("2026-10-26:quiet_pair"), "preview preserves real fish memory")
	app.quiet_mode = true; app._layout()
	expect(find_button(app.ui, "退出观赏") != null, "quiet mode always has visible exit")
	app.set_demo("rain"); app._layout()
	expect(app.preview_button.is_visible_in_tree(), "quiet preview keeps experience status and return-to-today visible")
	app._use_live(); app.source.stop(); app.quiet_mode = false
	app.live_data = app.Catalog.preset("clear")
	app.live_data.merge({"city":"旧城市", "source":"缓存", "saved_at":Time.get_unix_time_from_system(), "observed":"2026-10-26T10:00"}, true)
	if app.get("live_target_key") != null: app.live_target_key = "manual:" + str(app.city_index)
	app.city_index = (app.city_index + 1) % app.Catalog.CITIES.size()
	app.source.cache.clear(); app._use_live(); app.source.stop()
	expect(app.live_data.is_empty() and app.weather_label.text == "--°", "new city never labels previous city temperature as its own")
	app.use_location = true
	app.live_data = app.Catalog.preset("clear")
	app.live_data.merge({"saved_at":Time.get_unix_time_from_system(), "observed":"2026-10-26T10:00", "source":"缓存"}, true)
	app.live_target_key = "location:31.23:121.47"
	app.source.cache.clear()
	app._on_location('{"lat":39.90,"lon":116.40}')
	app.source.stop(); app.source._failed()
	app._on_location_name("测试新城市")
	expect(app.live_data.is_empty() and app.weather_label.text == "--°", "relocation failure never labels prior coordinates temperature as new city")
	app._on_location_error("测试定位失败")
	app.source.stop()
	app.source.pending_city = app.city_index
	app.source.custom_target = {}
	var fallback: Dictionary = app.Catalog.preset("clear")
	fallback.merge({"saved_at":Time.get_unix_time_from_system(), "observed":"2026-10-26T10:00", "source":"缓存"}, true)
	app._on_live_weather(fallback)
	expect(app.live_target_key == "manual:" + str(app.city_index), "location fallback retains actual manual weather target")
	app._on_location('{"lat":39.90,"lon":116.40}')
	app.source.stop(); app.source._failed(); app._on_location_name("测试重试城市")
	expect(app.live_data.is_empty() and app.weather_label.text == "--°", "same-coordinate retry never relabels fallback city weather")
	app._open_sheet("anniversaries")
	var fields: Array = app.sheet_content.find_children("*", "LineEdit", true, false)
	if fields.size() >= 2:
		fields[0].text = "未保存的生日"
		app._close_sheet()
		expect(app.sheet.visible and app.opened_sheet == "discard_draft", "dirty anniversary form requests explicit exit choice")
		var keep := find_button(app.sheet_content, "继续编辑")
		if keep != null: keep.pressed.emit()
		var restored: Array = app.sheet_content.find_children("*", "LineEdit", true, false)
		expect(restored.size() >= 2 and restored[0].text == "未保存的生日", "continue editing preserves draft")
	else: expect(false, "anniversary editor exists")
	app.queue_free(); await process_frame
	for failure in failures: push_error("FAIL " + failure)
	if failures.is_empty(): print("PASS test_redesign_flow: navigation, city cancel, preview isolation, quiet exit, protected drafts")
	quit(0 if failures.is_empty() else 1)
