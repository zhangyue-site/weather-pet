extends SceneTree
var failures: Array[String]=[]
class FakeSource extends Node:
	var fetched := -1
	var coordinates := Vector2.ZERO
	var resolved_city := ""
	func fetch(index: int) -> void: fetched=index
	func fetch_coordinates(lat: float,lon: float) -> void: coordinates=Vector2(lat,lon)
	func rename_current_city(name: String) -> void: resolved_city=name
	func stop() -> void: pass
func expect(ok: bool,text: String) -> void:
	if not ok: failures.append(text)
func _init() -> void: call_deferred("run")
func run() -> void:
	var app=load("res://companion/main.tscn").instantiate();root.add_child(app)
	app.capture_mode=true;app.source.stop();app.event_source.set_process(false)
	app.source.queue_free();var fake=FakeSource.new();app.add_child(fake);app.source=fake
	app.mode="live";app.use_location=true;app.location_state="waiting"
	expect(app._location_text().contains("定位中"),"waiting isn't presented as real city")
	app._on_location('{"lat":30.1,"lon":120.2}')
	expect(app.location_state=="located" and fake.coordinates.distance_to(Vector2(30.1,120.2))<0.01,"valid position targets exact weather coordinates")
	app._on_location_name("测试市 · 测试区")
	expect(app._location_text()=="自动定位 · 测试市 · 测试区" and fake.resolved_city=="测试市 · 测试区","city and district clearly marked automatic")
	app._on_location_error("permission denied")
	expect(app._location_text().contains("定位未成功 · 暂用") and fake.fetched==app.city_index,"fallback never masquerades as location")
	app._on_resolved_name("迟到的旧地名")
	expect(app.location_city.is_empty(),"late resolver cannot overwrite failed/manual location")
	app.use_location=false;app._on_location_name("旧地名")
	expect(app._location_text().begins_with("城市天气 · ") and app.location_city.is_empty(),"manual city remains manual")
	app.use_location=true;app.location_state="waiting";app._on_location('{"lat":999,"lon":10}')
	expect(app.location_state=="failed","invalid coordinates fall back explicitly")
	app.location_state="located";app.location_city="";app.live_data={};app.location_name_pending=false
	expect(app._location_text()=="已定位 · 暂无城市名","reverse geocode failure does not invent city")
	app.mode="demo";expect(app._location_text().contains("不是当前位置"),"demo never implies actual location")
	app.queue_free();await process_frame
	if failures.is_empty():push_warning("PASS test_location_labels: automatic city/district, waiting, manual, fallback, invalid position, stale name, reverse failure, demo")
	for f in failures:push_error("FAIL "+f)
	quit(0 if failures.is_empty() else 1)
