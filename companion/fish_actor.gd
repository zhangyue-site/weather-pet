extends Node2D

var world: RefCounted
var respond: Callable = Callable()
var enabled: = true
var reduced: = false

const H: = 304
const CACHE_MAX: = 5
var anim_info: Dictionary = {}
var cache: = {}
var cache_order: Array = []
var body_height: = 150.0
var pos_x: = 1.14
var foot: = Vector2(1140, 800)
var action: = "idle"
var action_time: = 0.0
var action_duration: = 5.0
var state: = "around"
var visit_cd: = 40.0
var target_x: = 0.86
var home_x: = 0.86
var direction: = -1.0
var rng: = RandomNumberGenerator.new()

const NOTES = ["大肥鱼从池塘边过来串门，阿晴挥了挥手", "大肥鱼吐着泡泡来打招呼，小院热闹了一小会儿", "大肥鱼蹭过来挨着阿晴，一起看了会儿天"]

func _ready() -> void :
	rng.randomize()
	visit_cd = rng.randf_range(20.0, 30.0)
	anim_info = JSON.parse_string(FileAccess.get_file_as_string("res://companion/fish/manifest.json"))

func _load_anim(name: String) -> Array :
	if cache.has(name): 
		cache_order.erase(name)
		cache_order.push_front(name)
		return cache[name]
	var info: Dictionary = anim_info.get(name, {})
	var count: = int(info.get("frames", 0))
	if count <= 0:
		if name != "idle": return _load_anim("idle")
		return []
	var list: Array = []
	for i in range(count):
		var path: = "res://companion/fish/%s/f%03d.webp" % [name, i]
		var img: = Image.new()
		if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and not img.is_empty():
			list.append(ImageTexture.create_from_image(img))
	cache[name] = list
	cache_order.push_front(name)
	while cache_order.size() > CACHE_MAX:
		var old: String = cache_order.pop_back()
		if old != action:
			for tex in cache[old]: tex.queue_free()
			cache.erase(old)
	return list

func _step_action(name: String, duration: float) -> void :
	action = name
	action_time = 0.0
	action_duration = duration

func _env_action() -> String :
	var id: String = String(world.environment.id)
	var raining: bool = id in ["drizzle", "rain", "heavy_rain", "thunderstorm"]
	var snowing: bool = id in ["snow", "heavy_snow"]
	if not bool(world.environment.is_day): return "sleep"
	if raining: return "umbrella"
	if snowing: return "snow"
	if id == "hot": return "hot"
	if id == "cold": return "cold"
	if id in ["windy", "fog", "overcast"]: return "notice"
	var roll: = rng.randf()
	if roll < 0.55: return "idle"
	if roll < 0.7: return "water"
	if roll < 0.85: return "notice"
	return "stretch"

func visit_now() -> void :
	if not enabled or state == "visiting": return
	target_x = clampf(float(world.x) + (0.1 if pos_x > float(world.x) else - 0.1), 0.12, 0.9)
	direction = signf(target_x - pos_x)
	_step_action("walk", 12.0)
	state = "visiting"

func pet_fish() -> bool :
	if not enabled or not visible: return false
	_step_action("pet", 4.0)
	if world != null: world.add_note("摸了摸大肥鱼，它咯咯地笑")
	return true

func has_point(p: Vector2) -> bool :
	var half: = body_height * 0.42
	return p.x > foot.x - half and p.x < foot.x + half and p.y > foot.y - body_height and p.y < foot.y

func _process(delta: float) -> void :
	if not enabled:
		visible = false
		return
	visible = not reduced
	if not visible: return
	var dt: float = clampf(delta, 0.0, 0.1)
	action_time += dt
	var size: = get_viewport_rect().size
	foot = Vector2(pos_x * size.x, size.y * 0.8)
	body_height = minf(size.y * 0.16, 158.0)
	match state:
		"around":
			visit_cd -= dt
			if action_time >= action_duration: _step_action(_env_action(), rng.randf_range(6.0, 11.0))
			if visit_cd <= 0:
				visit_cd = rng.randf_range(100.0, 200.0)
				visit_now()
		"visiting":
			if absf(pos_x - target_x) > 0.004:
				pos_x = move_toward(pos_x, target_x, dt * 0.06)
				if action != "walk": _step_action("walk", 12.0)
				if absf(pos_x - target_x) <= 0.004:
					_step_action("wave", 3.2)
					if world != null:
						world.add_note(NOTES[rng.randi_range(0, NOTES.size() - 1)])
						if respond.is_valid(): respond.call()
			elif action_time >= action_duration:
				home_x = clampf(target_x + (0.17 if rng.randf() > 0.5 else - 0.17), 0.1, 0.92)
				target_x = home_x
				direction = signf(target_x - pos_x)
				_step_action("walk", 12.0)
				state = "heading_home"
		"heading_home":
			if absf(pos_x - target_x) > 0.004:
				pos_x = move_toward(pos_x, target_x, dt * 0.055)
				if action != "walk": _step_action("walk", 12.0)
				if absf(pos_x - target_x) <= 0.004:
					state = "around"
					_step_action(_env_action(), 7.0)
			else:
				state = "around"
				_step_action(_env_action(), 7.0)
	queue_redraw()

func _draw() -> void :
	if anim_info.is_empty() or not visible: return
	var list: Array = _load_anim(action)
	if list.is_empty(): return
	var fps: float = 12.0
	if anim_info.has(action): fps = float(anim_info[action].get("fps", 12.0))
	var idx: int = int(action_time * fps) % list.size()
	var tex: Texture2D = list[idx]
	var scale: float = body_height / float(H)
	var breath: = 0.0
	if action == "idle": breath = sin(world.total_time * 2.4) * 0.004
	var sx: = scale * (1.0 + breath)
	if direction > 0: sx = - sx
	draw_set_transform(foot, 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, body_height * 0.3, Color(0.08, 0.12, 0.13, 0.15))
	draw_set_transform(Vector2.ZERO)
	draw_set_transform(foot + Vector2(0, - 3), 0, Vector2(sx, scale * (1.0 - breath * 0.5)))
	draw_texture(tex, - Vector2(tex.get_width() * 0.5, tex.get_height()))
	draw_set_transform(Vector2.ZERO)
