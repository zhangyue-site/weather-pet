extends SceneTree
const Catalog=preload("res://companion/catalog.gd")
class TestMain extends "res://companion/main.gd":
	func _today() -> String:return "2026-10-26" # Ordinary day, independent of the host clock.
	func _load_saved() -> void:settings={};anniversaries=[];use_location=false
	func _save() -> void:pass # Never overwrite a developer's desktop save.
var failures:Array[String]=[]
func expect(ok:bool,message:String) -> void:
	if not ok:failures.append(message)
func _init() -> void:call_deferred("run")
func run() -> void:
	var app=TestMain.new();root.add_child(app)
	app.capture_mode=true;app.source.stop();app.event_source.set_process(false);app.set_process(false);app.fish.set_process(false)
	app.mode="live";app.live_data={};app.festival_preview=false;app.preview_date="";app.program_key=""
	var weather:Dictionary=Catalog.preset("clear")
	var now:=int(Time.get_unix_time_from_system())
	var offset:=23*3600-(now%86400)
	if offset>14*3600:offset-=86400
	weather.merge({"is_day":false,"hour":23,"city":"测试市","source":"合成测试","observed":"2026-10-26T23:00","saved_at":now,"utc_offset":offset},true)
	app.source.updated.emit(weather) # Same signal and main weather callback as production.
	app._update_festival();app._refresh_labels()
	app.fish.memory.clear();app.fish.show_cd=0
	expect(app.world.festival.get("kind","")=="daily","real catalog selects ordinary day")
	expect(not app.fish.preview_context,"production path has preview_context=false")
	expect(app.fish.request_show(false),"request real quiet program")
	expect(app.duet.active and app.duet.quiet_pair and not app.fish.previewing,"fish respond invokes main callback and starts quiet duet")
	var trace:Array=[];var actor_slept:=false;var both_slept:=false
	for tick in range(110):
		app._process(0.1);app.fish._process(0.1) # Actual parent process followed by child process.
		if tick%10==0:trace.append({"seconds":(tick+1)*0.1,"actor":app.world.activity,"fish":app.fish.action,"active":app.duet.active,"preview":app.fish.preview_context})
		if app.duet.active and app.world.activity=="sleep":actor_slept=true
		if app.duet.active and app.world.activity=="sleep" and app.fish.action=="sleep":both_slept=true
	expect(actor_slept and both_slept,"production main pipeline advances notice -> actor sleep -> both sleep")
	expect(not app.duet.active and app.fish.memory.has(app._today()+":quiet_pair"),"real bedtime completes and is recorded once")
	app.fish.show_cd=0;app._process(0.1);app.fish._process(0.1)
	expect(not app.duet.active,"same real night does not repeat")
	app.set_demo("clear");app.world.environment.is_day=false;app._refresh_labels()
	app.fish.memory.erase(app._today()+":quiet_pair")
	var before:Dictionary=app.fish.memory.duplicate(true)
	expect(app.fish.preview_context,"weather experience is explicitly a preview")
	expect(app.fish.request_show(true) and app.duet.active,"quiet preview can play")
	expect(app.fish.memory==before,"preview never consumes the real-night memory")
	var report:Dictionary={"production_callback":true,"no_preview_on_production":true,"actor_slept":actor_slept,"both_slept":both_slept,"preview_memory_unchanged":app.fish.memory==before,"trace":trace,"failures":failures}
	var output:=OS.get_environment("QUIET_TRACE_PATH")
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.queue_free();await process_frame
	if failures.is_empty():push_warning("PASS test_quiet_main_pipeline: real request_show -> main callback -> notice/sleep/both sleep, once nightly, preview memory isolated")
	for failure in failures:push_error("FAIL "+failure)
	quit(0 if failures.is_empty() else 1)
