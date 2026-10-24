extends SceneTree
const Fish = preload("res://companion/fish_actor.gd")
const World = preload("res://companion/world.gd")
var failures: Array[String] = []
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var fish = Fish.new()
	fish.world = World.new()
	root.add_child(fish)
	fish.set_process(false)
	fish.rng.seed = 200
	var waves := [0]
	fish.respond = func(): waves[0] += 1
	expect(fish.pos_x > 0.1 and fish.pos_x < 0.9, "starts inside courtyard")
	expect(fish.visit_cd >= 8.0 and fish.visit_cd <= 12.0, "first visit within 12 seconds")
	fish._process(0.016)
	expect(fish.display_texture != null, "visible on first tick")
	var decoded: int = fish.decoded_frames
	fish._prepare_frame()
	expect(fish.decoded_frames - decoded <= 1, "at most one decode per frame")
	fish.visit_cd = 0.01
	fish._process(0.1)
	expect(fish.state == "visiting", "automatic visit")
	expect(fish.visit_cd >= 25 and fish.visit_cd <= 45, "repeat interval")
	for i in range(100):
		fish._process(0.1)
		if waves[0] == 1: break
	expect(waves[0] == 1 and fish.action == "wave", "arrives and responds once")
	for i in range(40): fish._process(0.1)
	expect(fish.state == "staying" and fish.action == "idle", "stays naturally after greeting")
	expect(fish.has_point(fish.foot - Vector2(0, fish.body_height * 0.5)), "touch bounds follow movement")
	for name in fish.anim_info.keys():
		fish._step_action(name, 6)
		fish._prepare_frame()
	expect(fish.cache.size() <= fish.CACHE_MAX, "bounded cache, eviction without invalid queue_free")
	fish.enabled = false
	fish._process(0.1)
	expect(not fish.visible, "disabled neighbour hidden")
	fish.enabled = true
	fish.reduced = true
	fish._process(0.1)
	expect(fish.visible, "reduced motion keeps neighbour visible")
	fish.queue_free()
	await process_frame
	if failures.is_empty(): push_warning("PASS test_fish_actor: entry, visits, stay, decode budget, eviction, visibility, touch")
	for failure in failures: push_error("FAIL " + failure)
	quit(0 if failures.is_empty() else 1)
