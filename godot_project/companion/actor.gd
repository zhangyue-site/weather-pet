extends Node2D
var world: RefCounted
var frames: Dictionary = {}
var atlases: Dictionary = {}
var metadata: Dictionary
var foot := Vector2.ZERO
var body_height := 245.0
var current_rect := Rect2()
var current_pose := ""
var sprite: Sprite2D
var last_tint := Color.TRANSPARENT
var pair_poses = preload("res://companion/interaction_poses.gd").new()
var pair_pose := -1

# Two strides per second; continuous body motion bridges the four source poses.
const WALK_FPS := 8.0
const WALK_CYCLE := TAU * WALK_FPS / 4.0

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://companion/art/atlas.json"))
	# Atlas cell boundaries are not exact in generated source sheets; use verified regions.
	metadata.daily[6] = {"rect":[838,513,174,453], "anchor":[91,453]}
	metadata.daily[7] = {"rect":[1138,635,270,335], "anchor":[141,335]}
	metadata.weather[1] = {"rect":[417,50,287,446], "anchor":[179,446]}
	metadata.weather[2] = {"rect":[763,29,325,467], "anchor":[193,467]}
	for sheet in ["daily", "weather", "walk"]:
		atlases[sheet] = load("res://companion/art/%s.png" % sheet)
		frames[sheet] = []
		for frame in metadata[sheet]:
			var t := AtlasTexture.new()
			t.atlas = atlases[sheet]
			var r: Array = frame.rect
			t.region = Rect2(r[0],r[1],r[2],r[3])
			t.filter_clip = true
			frames[sheet].append(t)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://companion/chroma.gdshader")
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.material = mat
	add_child(sprite)

func update_visual() -> void:
	if world == null or frames.is_empty(): return
	var sheet := "daily"
	var idx := 0
	var normal_height := 460.0
	var a: String = world.activity
	match a:
		"blink", "pet": idx = 1
		"wave", "celebrate_wave": idx = 2
		"celebrate_cheer": idx = 3
		"celebrate_dance": idx = 2 if int(world.activity_time * 2.0) % 2 == 0 else 3
		"stretch": idx = 3
		"notice", "drum": idx = 4
		"scared": idx = 5
		"drink": idx = 6
		"sleep": idx = 7
		"take_umbrella", "open_umbrella", "umbrella", "shake", "cold", "hot", "wind", "snow":
			sheet = "weather"
			idx = ["take_umbrella", "open_umbrella", "umbrella", "shake", "cold", "hot", "wind", "snow"].find(a)
			normal_height = [440.0, 410.0, 382.0, 410.0, 420.0, 430.0, 420.0, 420.0][idx]
		"walk":
			sheet = "walk"
			idx = int(world.activity_time * WALK_FPS) % 4
			if world.direction < 0: idx += 4
		"water": idx = 0
	if a == "idle" and fmod(world.total_time, 4.7) < 0.16: idx = 1
	pair_pose = -1
	if world.duet_active and sheet == "daily" and a != "sleep":
		pair_pose = 0
		if world.duet_cue in ["receive","beat"] or a == "wave": pair_pose = 1
		if world.duet_prop == "cup_offer": pair_pose = 2 if world.duet_progress < 0.5 else 1
		if world.duet_prop == "shared_drink": pair_pose = 0
		if world.duet_cue == "eat" or (world.duet_cue=="receive" and world.duet_progress>=0.9): pair_pose = 3
	var tex: AtlasTexture = pair_poses.texture(pair_pose) if pair_pose>=0 else frames[sheet][idx]
	var anchor: Array = metadata[sheet][idx].anchor
	if pair_pose>=0:
		anchor = [pair_poses.anchor(pair_pose).x,pair_poses.anchor(pair_pose).y]
		normal_height = 500.0
	if sheet == "walk":
		# Keep pelvis centered through stride rather than anchoring to the swinging toe.
		anchor = [tex.region.size.x * 0.5, tex.region.size.y]
	var scale_factor: float = body_height / normal_height
	var breath: float = sin(world.total_time * (1.5 if a == "sleep" else 2.6)) * (0.007 if a == "sleep" else 0.003)
	var lean := 0.0
	var bounce := 0.0
	if a == "walk":
		var gait: float = world.activity_time * WALK_CYCLE
		# Ease in/out of a stroll, avoiding a sudden jump at action boundaries.
		var remaining: float = maxf(0.0, world.activity_duration - world.activity_time)
		var weight: float = smoothstep(0.0, 0.25, minf(world.activity_time, remaining))
		bounce = -sin(gait * 2.0) * sin(gait * 2.0) * 2.0 * weight
		lean = sin(gait) * 0.009 * weight
	if a == "cold": lean = sin(world.total_time * 37) * 0.007
	if a == "wind": lean = sin(world.total_time * 2) * 0.018
	if a in ["wave", "pet"]: bounce = -absf(sin(world.activity_time * 3)) * 3
	if a.begins_with("celebrate_"):
		bounce = -absf(sin(world.activity_time * 3.5)) * (9 if a == "celebrate_cheer" else 4)
		lean = sin(world.activity_time * 3.5) * (0.045 if a == "celebrate_dance" else 0.012)
	if world.duet_active:
		# Source notice/wave face LEFT. Lean toward the partner and lower the gaze.
		lean += world.look_direction * (0.055 + sin(world.duet_time*2.4)*0.012)
		if a == "drum":
			bounce -= absf(sin(world.duet_time*5.0))*4.0
			lean += world.look_direction*sin(world.duet_time*5.0)*0.035
		elif world.duet_cue in ["receive","eat","share"]:
			lean += world.look_direction*absf(sin(world.activity_time*2.4))*0.055
	if world.lightning > 0: bounce -= world.lightning * 8
	var sx: float = scale_factor * (1.0 - breath * 0.3)
	# The generated right-walk row faces left; orient it at draw time.
	if a == "walk" and world.direction > 0: sx = -sx
	elif world.duet_active and ((pair_pose<0 and world.look_direction>0) or (pair_pose>=0 and world.look_direction<0)): sx = -sx
	# Retain the canvas item: movement does not rebuild draw commands every frame.
	position = foot + Vector2(0, bounce)
	rotation = lean
	scale = Vector2(sx, scale_factor * (1.0 + breath))
	var pose := "pair:"+str(pair_pose) if pair_pose>=0 else sheet+":"+str(idx)
	if pose != current_pose:
		sprite.texture = tex
		sprite.position = -Vector2(anchor[0], anchor[1])
	current_rect = Rect2(foot - Vector2(body_height * 0.45,body_height * 1.2), Vector2(body_height * 0.9,body_height * 1.2))
	current_pose = pose
	var tint := Color.WHITE
	if not bool(world.environment.is_day): tint = Color(0.72,0.78,0.92)
	elif world.environment.id in ["rain", "heavy_rain", "thunderstorm", "overcast"]: tint = Color(0.88,0.93,1)
	if world.wetness > 0.1: tint = tint.lerp(Color(0.68,0.74,0.80), world.wetness * 0.22)
	if tint != last_tint:
		sprite.material.set_shader_parameter("environment_tint", tint)
		last_tint = tint

func hand_point() -> Vector2:
	if sprite == null or sprite.texture == null: return foot
	if pair_pose>=0: return to_global(pair_poses.hand(pair_pose))
	var tex: AtlasTexture = sprite.texture
	var at := Vector2(128,650) if current_pose == "daily:4" else Vector2(895,723) if current_pose == "daily:6" else Vector2(tex.region.position.x+tex.region.size.x*0.5,tex.region.position.y+tex.region.size.y*0.48)
	return to_global(at-tex.region.position+sprite.position)
