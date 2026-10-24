extends Node
# Native daemon task owns blocking Android geocoding; Godot only polls short methods.
const Bridge=preload("res://companion/android_bridge.gd")
signal resolved(name: String)
var resolver: Object
var pending: Dictionary={}
var generation:=0
var active_generation:=-1
var cancel_pending:=false
var poll_elapsed:=0.0
func request_name(lat: float,lon: float) -> void:
	generation+=1
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		resolved.emit("");return
	pending={"lat":lat,"lon":lon,"generation":generation}
func cancel() -> void:
	generation+=1;pending.clear();active_generation=-1;cancel_pending=true
func _process(_delta: float) -> void:
	poll_elapsed+=_delta
	if pending.is_empty() and active_generation>=0 and not cancel_pending and poll_elapsed<0.1:return
	if not OS.has_feature("android") or (pending.is_empty() and active_generation<0 and not cancel_pending):return
	if not Bridge.mutex.try_lock():return
	poll_elapsed=0
	var emit_result:=false
	var name:=""
	if resolver!=null and cancel_pending:
		resolver.cancel();JavaClassWrapper.get_exception()
	cancel_pending=false
	if not pending.is_empty():
		var job:=pending.duplicate();pending.clear()
		if resolver==null:
			var context=Engine.get_singleton("AndroidRuntime").getApplicationContext()
			if JavaClassWrapper.get_exception()==null and context!=null:
				var type=JavaClassWrapper.wrap("com.weather.companion.LocationNameResolver")
				if JavaClassWrapper.get_exception()==null and type!=null:
					resolver=type.LocationNameResolver(context)
					if JavaClassWrapper.get_exception()!=null:resolver=null
		if resolver!=null:
			resolver.start(float(job.lat),float(job.lon))
			if JavaClassWrapper.get_exception()==null:active_generation=int(job.generation)
			else:active_generation=-1;emit_result=true
		else:emit_result=true
	elif resolver!=null and active_generation>=0:
		var complete=resolver.isDone()
		if JavaClassWrapper.get_exception()!=null:
			active_generation=-1;emit_result=true
		elif bool(complete):
			var result=resolver.getName()
			if JavaClassWrapper.get_exception()==null and active_generation==generation and result!=null:name=String(result)
			emit_result=active_generation==generation;active_generation=-1
	Bridge.mutex.unlock()
	if emit_result:resolved.emit(name)
func _exit_tree() -> void:
	cancel()
	if resolver!=null:
		# All JNI wrapper callers are on the Godot main thread. Native close does no join.
		if Bridge.mutex.try_lock():
			resolver.close();JavaClassWrapper.get_exception();Bridge.mutex.unlock()
