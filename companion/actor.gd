extends Node2D
var world: RefCounted
var frames: Dictionary = {}
var atlases: Dictionary = {}
var metadata: Dictionary
var foot: = Vector2.ZERO
var body_height: = 245.0
var current_rect: = Rect2()
var current_pose: = ""

func _ready() -> void :
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://companion/art/atlas.json"))

	metadata.daily[6] = {"rect": [838, 513, 174, 453], "anchor": [91, 453]}
	metadata.daily[7] = {"rect": [1138, 635, 270, 335], "anchor": [141, 335]}
	metadata.weather[1] = {"rect": [417, 50, 287, 446], "anchor": [179, 446]}
	metadata.weather[2] = {"rect": [763, 29, 325, 467], "anchor": [193, 467]}
	for sheet in ["daily", "weather", "walk"]:
		atlases[sheet] = load("res://companion/art/%s.png" % sheet)
		frames[sheet] = []
		for frame in metadata[sheet]:
			var t: = AtlasTexture.new()
			t.atlas = atlases[sheet]
			var r: Array = frame.rect
			t.region = Rect2(r[0], r[1], r[2], r[3])
			t.filter_clip = true
			frames[sheet].append(t)
	var mat: = ShaderMaterial.new()
	mat.shader = load("res://companion/chroma.gdshader")
	material = mat

func _process(_delta: float) -> void :
	queue_redraw()

func _draw() -> void :
	if world == null or frames.is_empty(): return
	var sheet: = "daily"
	var idx: = 0
	var normal_height: = 460.0
	var a: String = world.activity
	match a:
		"blink", "pet": idx = 1
		"wave", "celebrate_wave": idx = 2
		"celebrate_cheer": idx = 3
		"celebrate_dance": idx = 2 if int(world.activity_time * 2.0) % 2 == 0 else 3
		"stretch": idx = 3
		"notice": idx = 4
		"scared": idx = 5
		"drink": idx = 6
		"sleep": idx = 7
		"take_umbrella", "open_umbrella", "umbrella", "shake", "cold", "hot", "wind", "snow":
			sheet = "weather"
			idx = ["take_umbrella", "open_umbrella", "umbrella", "shake", "cold", "hot", "wind", "snow"].find(a)
			normal_height = [440.0, 410.0, 382.0, 410.0, 420.0, 430.0, 420.0, 420.0][idx]
		"walk":
			sheet = "walk"
			idx = int(world.activity_time * 5.5) % 4
			if world.direction < 0: idx += 4
		"water": idx = 0
	if a == "idle" and fmod(world.total_time, 4.7) < 0.16: idx = 1
	var tex: AtlasTexture = frames[sheet][idx]
	var anchor: Array = metadata[sheet][idx].anchor
	if sheet == "walk":

		anchor = [tex.region.size.x * 0.5, tex.region.size.y]
	var scale_factor: float = body_height / normal_height
	var breath: float = sin(world.total_time * (1.5 if a == "sleep" else 2.6)) * (0.007 if a == "sleep" else 0.003)
	var lean: = 0.0
	var bounce: = 0.0
	if a == "cold": lean = sin(world.total_time * 37) * 0.007
	if a == "wind": lean = sin(world.total_time * 2) * 0.018
	if a in ["wave", "pet"]: bounce = - absf(sin(world.activity_time * 3)) * 3
	if a.begins_with("celebrate_"):
		bounce = - absf(sin(world.activity_time * 3.5)) * (9 if a == "celebrate_cheer" else 4)
		lean = sin(world.activity_time * 3.5) * (0.045 if a == "celebrate_dance" else 0.012)
	if world.lightning > 0: bounce -= world.lightning * 8
	var sx: float = scale_factor * (1.0 - breath * 0.3)

	if a == "walk" and world.direction > 0: sx = - sx
	draw_set_transform(foot + Vector2(0, bounce), lean, Vector2(sx, scale_factor * (1.0 + breath)))
	draw_texture(tex, - Vector2(anchor[0], anchor[1]))
	draw_set_transform(Vector2.ZERO)
	current_rect = Rect2(foot - Vector2(body_height * 0.45, body_height * 1.2), Vector2(body_height * 0.9, body_height * 1.2))
	current_pose = sheet + ":" + str(idx)
	var tint: = Color.WHITE
	if not bool(world.environment.is_day): tint = Color(0.72, 0.78, 0.92)
	elif world.environment.id in ["rain", "heavy_rain", "thunderstorm", "overcast"]: tint = Color(0.88, 0.93, 1)
	if world.wetness > 0.1: tint = tint.lerp(Color(0.68, 0.74, 0.8), world.wetness * 0.22)
	material.set_shader_parameter("environment_tint", tint)
