extends SceneTree
const Actor = preload("res://companion/actor.gd")
const World = preload("res://companion/world.gd")
var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var actor = Actor.new()
	actor.world = World.new()
	root.add_child(actor)
	actor.foot = Vector2(300, 700)
	actor.body_height = 245
	for activity in ["idle", "blink", "wave", "stretch", "notice", "scared", "drink", "sleep", "take_umbrella", "open_umbrella", "umbrella", "shake", "cold", "hot", "wind", "snow", "walk", "celebrate_wave", "celebrate_cheer", "celebrate_dance"]:
		actor.world.start(activity, 10)
		for direction in [-1.0, 1.0]:
			actor.world.direction = direction
			for frame in range(8):
				actor.world.activity_time = frame * 0.2
				actor.world.total_time = frame * 0.2
				actor.update_visual()
				expect(actor.sprite.texture != null, activity + " texture")
				expect(actor.current_rect.has_point(actor.foot - Vector2(0, 100)), activity + " touch bounds")
				expect(actor.scale.y > 0, activity + " body scale")
				if activity == "walk":
					expect(signf(actor.scale.x) == -direction, "walk orientation")
					# Anchored soles stay on the ground after changing stride and direction.
					var sole: Vector2 = actor.sprite.position + Vector2(actor.sprite.texture.get_width() * 0.5, actor.sprite.texture.get_height())
					expect((actor.transform * sole).distance_to(actor.position) < 0.01, "walk sole anchor")
	actor.world.start("notice",10)
	actor.world.duet_active = true
	for side in [-1.0,1.0]:
		actor.world.look_direction = side
		actor.update_visual()
		expect(signf(actor.scale.x)==side,"dedicated interaction poses face partner")
	actor.world.duet_active = false
	actor.world.environment.is_day = false
	actor.update_visual()
	expect(actor.last_tint == Color(0.72, 0.78, 0.92), "night tint")
	var texture = actor.sprite.texture
	actor.world.total_time += 0.01
	actor.update_visual()
	expect(actor.sprite.texture == texture, "continuous movement retains texture")
	var helper=load("res://companion/interaction_poses.gd").new()
	expect(helper.texture(0).atlas==actor.pair_poses.texture(0).atlas,"pose helper shares the same static GPU atlas")
	var temporary_frame=weakref(helper.texture(0))
	helper=null
	expect(temporary_frame.get_ref()==null,"temporary pose frame wrappers are released, not accumulated")
	actor.queue_free()
	await process_frame
	if failures.is_empty(): push_warning("PASS test_actor_visual: all poses, both directions, sole anchoring, touch bounds, night tint")
	for failure in failures: push_error("FAIL " + failure)
	quit(0 if failures.is_empty() else 1)
