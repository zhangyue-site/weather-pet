extends SceneTree
const Source = preload("res://companion/event_source.gd")
const Events = preload("res://companion/events.gd")
var failures: Array[String] = []
func expect(ok: bool, name: String) -> void:
	if not ok: failures.append(name)
func _init() -> void: call_deferred("run")
func run() -> void:
	var source = Source.new()
	root.add_child(source)
	var original: Dictionary = source.catalog.duplicate(true)
	expect(Events.valid(original), "local content loads without server")
	source._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	expect(source.catalog == original, "network failure preserves local content")
	source._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer())
	expect(source.catalog == original, "invalid response preserves local content")
	var invalid: Dictionary = original.duplicate(true)
	invalid.events[0].actions = ["unknown"]
	source._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(invalid).to_utf8_buffer())
	expect(source.catalog == original, "invalid action preserves local content")
	# Success uses the same callback but writes only to an isolated test cache.
	var previous_cache := ""
	var existed := FileAccess.file_exists("user://events_cache.json")
	if existed: previous_cache = FileAccess.get_file_as_string("user://events_cache.json")
	var fresh: Dictionary = original.duplicate(true)
	fresh.revision = original.revision + 1
	fresh.events[0].title = "测试活动"
	source._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(fresh).to_utf8_buffer())
	expect(source.catalog.revision == fresh.revision, "valid revision accepted")
	var cached = JSON.parse_string(FileAccess.get_file_as_string("user://events_cache.json"))
	expect(Events.valid(cached) and cached.revision == fresh.revision, "successful content cached")
	source._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(original).to_utf8_buffer())
	expect(source.catalog.revision == fresh.revision, "older revision rejected")
	if existed:
		var f := FileAccess.open("user://events_cache.json",FileAccess.WRITE)
		f.store_string(previous_cache)
	else: DirAccess.remove_absolute("user://events_cache.json")
	source.queue_free()
	await process_frame
	if failures.is_empty(): push_warning("PASS test_event_source: local fallback, invalid response, cache, revision rollback")
	else:
		for failure in failures: push_error("FAIL " + failure)
	quit(0 if failures.is_empty() else 1)
