extends SceneTree
class TestActor extends Node2D:
	var foot := Vector2(270,700)
	var body_height := 180.0
var failures: Array[String] = []
func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _init() -> void: call_deferred("run")
func run() -> void:
	var path := "res://companion/scene_effects.gd"
	if not ResourceLoader.exists(path):
		push_error("FAIL scene director missing")
		quit(1)
		return
	var director = load(path).new()
	var env := {"id":"clear", "is_day":true}
	var event := {"id":"birthday", "tone":"joyful", "matches":[{"id":"birthday"}], "effect_ids":["confetti_burst", "heart_rise"]}
	director.update_context(env,event,"2026-04-01")
	var actor := TestActor.new()
	root.add_child(actor)
	var weather_effects = load("res://companion/effects.gd").new()
	weather_effects.actor=actor
	for i in range(30): weather_effects.affection()
	expect(weather_effects.hearts.size()<=6,"legacy affection remains bounded")
	weather_effects.hearts.clear()
	weather_effects.director=director
	weather_effects.affection()
	expect(weather_effects.hearts.is_empty(),"shared director owns care feedback without second particle layer")
	weather_effects.free()
	var renderer = load("res://companion/calendar_effects.gd").new()
	renderer.director = director
	renderer.actor=actor
	renderer.world=load("res://companion/world.gd").new()
	root.add_child(renderer)
	await process_frame
	await process_frame
	expect(not renderer.last_frame_recipes.is_empty(),"actual canvas draw consumes director recipes")
	expect(renderer.recipes_for_draw().size()>0,"renderer consumes live director recipes")
	director.step(15.0)
	director.update_context(env,event,"2026-04-01")
	for recipe in renderer.recipes_for_draw(): expect(recipe.get("source","")!="festival","same context does not restart finite festival")
	director.trigger("pet")
	for i in range(30): director.trigger("pet")
	var impulses := 0
	for recipe in renderer.recipes_for_draw():
		if recipe.get("source","")=="interaction": impulses+=1
	expect(impulses==1,"repeated care bounded to one impulse")
	director.step(4.0)
	for recipe in renderer.recipes_for_draw(): expect(recipe.get("source","")!="interaction","care expires")
	director.update_context(env,{"id":"memorial","tone":"solemn","effect_ids":["confetti_burst"]},"2026-04-02")
	director.trigger("pet")
	for recipe in renderer.recipes_for_draw(): expect(recipe.family=="candle","solemn cancels all celebratory recipes")
	director.update_context({"id":"clear","is_day":false},event,"2026-04-02")
	expect(renderer.recipes_for_draw().is_empty(),"night suppresses celebration")
	director.trigger("drink")
	expect(renderer.recipes_for_draw()[0].family=="steam","successful hot drink has local steam")
	director.update_context({"id":"snow","is_day":true},{},"2026-01-01")
	expect(renderer.recipes_for_draw().is_empty(),"snow has no duplicate ambient precipitation")
	director.set_policy(true,false)
	director.update_context(env,event,"2026-04-03")
	for recipe in renderer.recipes_for_draw(): expect(recipe.get("static",false),"reduced motion static feedback")
	renderer.override_id="firework_burst"
	expect(renderer.recipes_for_draw().size()==1 and renderer.recipes_for_draw()[0].family=="firework","explicit preview override preserved")
	renderer.override_id=""
	director.set_policy(false,true)
	expect(renderer.recipes_for_draw().is_empty(),"low power cancels ornament")
	await process_frame
	await process_frame
	expect(renderer.last_frame_recipes.is_empty(),"policy cancellation clears actual canvas submission")
	actor.queue_free()
	renderer.queue_free()
	await process_frame
	for failure in failures: push_error("FAIL "+failure)
	if failures.is_empty(): print("PASS test_scene_effects")
	quit(0 if failures.is_empty() else 1)
