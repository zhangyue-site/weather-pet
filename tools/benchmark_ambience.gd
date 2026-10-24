extends SceneTree
func _init() -> void: call_deferred("run")
func percentile(values: Array, q: float) -> float:
	if values.is_empty():return 0.0
	var sorted := values.duplicate();sorted.sort()
	return float(sorted[mini(sorted.size()-1,int(sorted.size()*q))])
func run() -> void:
	root.size = Vector2i(540,960)
	var rows: Array = []
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	for enabled in [false,true,false,true]:
		var app = load("res://companion/main.tscn").instantiate();root.add_child(app)
		app.capture_mode = true;app.source.stop();app.event_source.set_process(false)
		app.ambience_enabled = enabled;app.ambience.adaptive_enabled = false;app.ambience_low_power = false;app.battery_elapsed = -100000
		app.world.rng.seed = 99;app.fish.rng.seed = 99;app.fish.show_index = 0
		for event in app.event_source.catalog.events:
			if event.id == "spring_festival":app._preview_festival(event);break
		app.fish.steps.resize(1)
		for i in range(240):await process_frame
		var cpu: Array = [];var gpu: Array = [];var wall: Array = [];var calls: Array = []
		var previous := Time.get_ticks_usec()
		var together := false
		for i in range(1020):
			await process_frame
			var now := Time.get_ticks_usec();wall.append((now-previous)/1000.0);previous = now
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			if app.duet.active:together = true
		rows.append({"enabled":enabled,"wall_median_ms":percentile(wall,0.5),"wall_p95_ms":percentile(wall,0.95),"render_cpu_p95_ms":percentile(cpu,0.95),"render_gpu_p95_ms":percentile(gpu,0.95),"draw_calls_median":percentile(calls,0.5),"duet_seen":together,"duet_finished":not app.duet.active,"background_updates":app.ambience.update_count})
		app.queue_free();await process_frame
	var report := {"viewport":"540x960","engine":"Godot4.4.1","renderer":"desktop OpenGL","fixed_simulation_fps":60,"warmup_frames":240,"sample_frames":1020,"trials":rows,"not_phone_fps_test":true}
	var output := OS.get_environment("AMBIENCE_BENCH_REPORT")
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AMBIENCE_BENCH ",JSON.stringify(report));quit()
