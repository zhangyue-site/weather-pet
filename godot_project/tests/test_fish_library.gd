extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var app = load("res://companion/main.tscn").instantiate()
	root.add_child(app); app.capture_mode = true; app.source.stop(); app.event_source.set_process(false)
	app._open_sheet("fish_library")
	expect(app.sheet.visible,"library opens")
	var clicked := false
	for child in app.sheet_content.get_children():
		if child is Button and child.text == "中秋赏月吃月饼": child.pressed.emit(); clicked = true; break
	expect(clicked and app.fish.anim_info[app.fish.action].label == "中秋赏月吃月饼","button previews real mooncake clip")
	expect(app.duet.active and app.world.duet_active and app.world.activity == "drink","gallery preview includes actor companion")
	expect(not app.sheet.visible and app.festival_preview,"preview marked and panel closed")
	app.fish_page = 8; app._open_sheet("fish_library")
	expect(app.sheet.visible,"last page opens")
	app.fish.preview_action("idle")
	for i in range(200):
		app.fish.action_time += 0.1; app.fish._prepare_frame()
		expect(app.fish.cache_bytes <= app.fish.BYTE_MAX and app.fish.frame_order.size() <= app.fish.FRAME_MAX,"full clip texture budget")
	app.queue_free(); await process_frame
	if failures.is_empty(): push_warning("PASS test_fish_library: navigation, mooncake preview, long-clip memory budget")
	for f in failures: push_error("FAIL "+f)
	quit(0 if failures.is_empty() else 1)
