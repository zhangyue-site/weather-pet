extends SceneTree
const Bridge=preload("res://companion/android_bridge.gd")
var ready_gate:=Semaphore.new()
var release_gate:=Semaphore.new()
func _init() -> void:call_deferred("run")
func hold_bridge() -> void:
	Bridge.mutex.lock();ready_gate.post();release_gate.wait();Bridge.mutex.unlock()
func run() -> void:
	var app=load("res://companion/main.tscn").instantiate();root.add_child(app)
	app.capture_mode=true;app.source.stop();app.event_source.set_process(false)
	var thread:=Thread.new();thread.start(hold_bridge)
	while not ready_gate.try_wait():await process_frame
	app.ambience_low_power=true
	var start:=Time.get_ticks_usec();var cached:bool=app._android_low_power();var elapsed:=Time.get_ticks_usec()-start
	release_gate.post();thread.wait_to_finish()
	var ok:=cached and elapsed<20000
	app.queue_free();await process_frame
	if ok:push_warning("PASS test_android_bridge: busy JNI bridge uses cached power status without blocking main thread")
	else:push_error("FAIL bridge cache/nonblocking: "+str(elapsed))
	quit(0 if ok else 1)
