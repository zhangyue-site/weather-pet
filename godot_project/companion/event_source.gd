extends Node
signal changed
const Events = preload("res://companion/events.gd")
var catalog: Dictionary = {}
var request_node: HTTPRequest
var status := "本地节日日历"
var url := ""
var elapsed := 0.0

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://companion/content/events.json"))
	if FileAccess.file_exists("user://events_cache.json"):
		var cached = JSON.parse_string(FileAccess.get_file_as_string("user://events_cache.json"))
		if Events.valid(cached) and cached.revision > catalog.revision:
			catalog = cached
			status = "已缓存节日日历"
	request_node = HTTPRequest.new()
	request_node.timeout = 12
	request_node.body_size_limit = Events.MAX_BYTES
	request_node.max_redirects = 0
	add_child(request_node)
	request_node.request_completed.connect(_completed)
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://companion/content/server.json"))
	if config is Dictionary and config.get("events_url") is String: url = config.events_url
	refresh()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 21600:
		elapsed = 0
		refresh()

func refresh() -> void:
	if url.is_empty(): return
	if not url.begins_with("https://"):
		status = "活动地址需使用 HTTPS · 继续本地日历"
		return
	if request_node.request(url) != OK: status = "活动更新失败 · 继续本地日历"

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status = "活动暂未更新 · 继续已存日历"
		return
	var incoming = JSON.parse_string(body.get_string_from_utf8())
	if not Events.valid(incoming) or incoming.revision < catalog.revision:
		status = "活动内容未通过校验 · 继续已存日历"
		return
	catalog = incoming
	status = "服务器节日日历"
	var f := FileAccess.open("user://events_cache.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(catalog))
	changed.emit()
