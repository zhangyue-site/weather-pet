extends Node
# Poll on the Godot thread; CoreLocation callbacks never touch Godot objects.
signal location_ready(json: String)
signal location_name_ready(name: String)
signal location_error(message: String)
var native: Object
var poll_elapsed := 0.0
var request_id := 0

func _ready() -> void:
	if Engine.has_singleton("CompanionIOS"):
		native = Engine.get_singleton("CompanionIOS")

func request_location() -> void:
	request_id += 1
	if native == null:
		location_error.emit("定位服务暂不可用")
		return
	native.request_location(request_id)

func cancel_location() -> void:
	request_id += 1
	if native != null: native.cancel_location()

func low_power() -> bool:
	return native != null and bool(native.low_power())

func reduced_motion() -> bool:
	return native != null and native.has_method("reduced_motion") and bool(native.reduced_motion())

func _process(delta: float) -> void:
	if native == null: return
	poll_elapsed += delta
	if poll_elapsed < 0.1: return
	poll_elapsed = 0.0
	for event in native.poll_events():
		if int(event.get("request_id", -1)) != request_id: continue
		match String(event.get("type", "")):
			"location": location_ready.emit(JSON.stringify({"lat":event.lat,"lon":event.lon}))
			"name": location_name_ready.emit(String(event.get("name", "")))
			"error": location_error.emit(String(event.get("message", "定位未成功")))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: cancel_location()

func _exit_tree() -> void:
	cancel_location()
