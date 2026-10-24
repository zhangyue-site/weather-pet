extends SceneTree
const FPS := 60
func _init() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(540,960)
	var app=load("res://companion/main.tscn").instantiate();root.add_child(app)
	app.capture_mode=true;app.source.stop();app.event_source.set_process(false)
	app.reduced_motion=false;app.ambience_enabled=true;app.fish_enabled=true
	app.world.rng.seed=1024;app.fish.rng.seed=1024;app.fish.memory.clear();app.fish.show_index=0
	var scene:=OS.get_environment("COMPANION_RECORD_SCENE")
	var seconds:=18 if scene=="daily" else 24 if scene=="lion" else 29
	if scene=="daily":
		app.set_demo("clear");app.festival_preview=true
		var events=load("res://companion/events.gd")
		var ordinary: Dictionary={}
		for date in ["2026-10-26","2026-10-27","2026-10-28","2026-11-03"]:
			var candidate: Dictionary=events.program(app.event_source.catalog,date,[])
			if candidate.get("kind","")=="daily":ordinary=candidate;app.preview_date=date;break
		assert(not ordinary.is_empty(),"record an ordinary date, not an observance")
		app.world.set_festival(ordinary)
		app.world.festival.title="平常的一天 · 递热饮、接住回应"
		app.fish.steps.clear();app.fish.preview_context=true
		app.duet.start(app.world,app.fish)
	else:
		for event in app.event_source.catalog.events:
			if event.id==("spring_festival" if scene=="lion" else "mid_autumn"):app._preview_festival(event);break
		app.fish.steps.resize(1)
	var together:=false;var background:=0;var paired_background:=0;var cues:Array=[];var props:Array=[];var turned_poses:=false
	for frame in range(FPS*seconds):
		await process_frame
		if app.ambience.active:background+=1
		if app.duet.active:
			together=true
			if app.ambience.active:paired_background+=1
			if app.actor.pair_pose>=0 and app.fish.pair_pose>=0:turned_poses=true
			if not cues.has(app.world.duet_cue):cues.append(app.world.duet_cue)
			if not props.has(app.world.duet_prop):props.append(app.world.duet_prop)
	var report:Dictionary={"source":"unreleased interaction refinement after210","program_kind":app.world.festival.get("kind",""),"scene":scene,"simulation_fps":FPS,"seconds":seconds,"shared_timeline_seen":together,"dedicated_partner_poses_seen":turned_poses,"cues":cues,"props":props,"background_frames":background,"background_with_duet_frames":paired_background,"background_updates":app.ambience.update_count,"completed":not app.duet.active,"not_android_fps_test":true}
	print("RECORD_REPORT ",JSON.stringify(report))
	app.queue_free();await process_frame;quit()
