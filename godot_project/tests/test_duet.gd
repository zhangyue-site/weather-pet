extends SceneTree
const Duet = preload("res://companion/duet.gd")
const Fish = preload("res://companion/fish_actor.gd")
const World = preload("res://companion/world.gd")
const Catalog = preload("res://companion/catalog.gd")
var failures: Array[String] = []
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _init() -> void: call_deferred("run")
func run() -> void:
	var world = World.new()
	var fish = Fish.new(); fish.world = world; root.add_child(fish); fish.set_process(false)
	var duo = Duet.new()
	fish.set_context("2026-02-17",12,true)
	world.festival = {"id":"spring_festival","title":"春节","kind":"festival","tone":"joyful","actions":["celebrate_cheer"]}
	fish.steps = [{"id":fish.action_id("舞狮头"),"duration":10.0}]
	expect(duo.start(world,fish),"start shared timeline")
	expect(world.duet_active and world.activity == "notice" and fish.action == "wave","fish calls actor watches")
	for i in range(20): world.step(0.1); duo.step(0.1,world,fish)
	expect(world.activity == "wave" and fish.action == "notice","actor replies, fish listens")
	for i in range(22): world.step(0.1); duo.step(0.1,world,fish)
	expect(fish.action == fish.action_id("舞狮头") and world.activity == "drum" or world.activity == "notice","lion has audience")
	world.activity_time = 999; world.step(0.1)
	expect(world.duet_active and world.activity in ["notice","drum"],"autonomy cannot interrupt partner")
	var pose: String = fish.action
	for i in range(70): world.step(0.1); duo.step(0.1,world,fish)
	expect(fish.action == pose and world.activity == "drum","actor joins rhythm without restarting fish clip")
	for i in range(100): world.step(0.1); duo.step(0.1,world,fish)
	expect(not duo.active and not world.duet_active and fish.state == "around","both return to daily life")
	expect(duo.touch(world,fish,"actor"),"touch actor includes neighbour")
	expect(world.activity == "pet" and fish.action == "notice","neighbour notices touch")
	world.festival.tone = "solemn"; duo.step(0.1,world,fish)
	expect(not duo.active and not world.duet_active,"memorial releases both")
	world.festival.tone = "joyful"; fish.preview_context = false
	duo.touch(world,fish,"fish")
	world.set_environment(Catalog.preset("rain")); duo.step(0.1,world,fish)
	expect(not duo.active and world.activity == "notice" and not world.queue.is_empty(),"rain preserves umbrella sequence")
	fish.queue_free(); await process_frame
	if failures.is_empty(): push_warning("PASS test_duet: call/reply, shared timing, joining, autonomy lock, touch, completion, memorial/rain cancellation")
	for f in failures: push_error("FAIL "+f)
	quit(0 if failures.is_empty() else 1)
