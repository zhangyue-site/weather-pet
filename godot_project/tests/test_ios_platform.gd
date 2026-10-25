extends SceneTree
const Platform = preload("res://companion/ios_platform.gd")
var failures: Array[String] = []
class NativeStub extends RefCounted:
	var events: Array = []
	var requested := -1
	var cancelled := false
	func request_location(id: int) -> void: requested = id
	func cancel_location() -> void: cancelled = true
	func low_power() -> bool: return true
	func poll_events() -> Array:
		var result := events.duplicate(true)
		events.clear()
		return result
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _init() -> void: call_deferred("run")
func run() -> void:
	var bridge = Platform.new()
	root.add_child(bridge)
	var native = NativeStub.new()
	bridge.native = native
	var received: Array = []
	bridge.location_ready.connect(func(json): received.append(JSON.parse_string(json)))
	bridge.location_name_ready.connect(func(name): received.append(name))
	bridge.location_error.connect(func(message): received.append(message))
	bridge.request_location()
	expect(native.requested == bridge.request_id, "request identity reaches native bridge")
	var id: int = bridge.request_id
	native.events = [{"request_id":id,"type":"location","lat":30.2,"lon":120.1}, {"request_id":id,"type":"name","name":"测试市 · 测试区"}]
	bridge._process(0.11)
	expect(received.size() == 2 and received[0].lat == 30.2 and received[1] == "测试市 · 测试区", "coordinates and geocoded district delivered on Godot thread")
	bridge.cancel_location()
	native.events = [{"request_id":id,"type":"name","name":"旧请求"}]
	bridge._process(0.11)
	expect(native.cancelled and received.size() == 2, "late response after cancellation ignored")
	bridge.request_location()
	native.events = [{"request_id":id,"type":"error","message":"旧失败"}, {"request_id":bridge.request_id,"type":"error","message":"定位权限未开启"}]
	bridge._process(0.11)
	expect(received.size() == 3 and received[2] == "定位权限未开启", "only current request can trigger fallback")
	expect(bridge.low_power(), "iOS power saving reaches common animation guard")
	bridge.queue_free()
	await process_frame
	for failure in failures: push_error("FAIL " + failure)
	if failures.is_empty(): push_warning("PASS test_ios_platform: current-request events, cancellation, permission fallback, native power state")
	quit(0 if failures.is_empty() else 1)
