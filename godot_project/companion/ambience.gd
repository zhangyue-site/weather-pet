extends RefCounted
const SHADER = preload("res://companion/ambience.gdshader")
const NORMAL_INTERVAL := 1.0/15.0
const DUET_INTERVAL := 1.0/10.0
const SLOW_FRAME := 1.0/40.0
var material: ShaderMaterial
var active := false
var reason := "off"
var adaptive_enabled := true
var update_count := 0
var phase := 0.0
var accumulator := 0.0
var slow_time := 0.0
var cooldown := 0.0

func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER

func configure(texture_size: Vector2) -> void:
	# Anchor masks in the source illustration, so tall/narrow phones do not move the house.
	var reference_aspect := 540.0/960.0
	var aspect := texture_size.x/maxf(1,texture_size.y)
	var uv_scale := Vector2(aspect/reference_aspect,1) if aspect > reference_aspect else Vector2(1,reference_aspect/aspect)
	material.set_shader_parameter("reference_uv_scale",uv_scale)

func update(delta: float, canvas: CanvasItem, enabled: bool, reduced: bool, low_power: bool, day_background: bool, duet_active: bool) -> void:
	var dt := clampf(delta,0,0.1)
	cooldown = maxf(0,cooldown-dt)
	# Ignore application resume/loading gaps; only sustained low frame rate reduces effects.
	if adaptive_enabled and cooldown <= 0 and delta < 0.25:
		slow_time = slow_time+dt if delta > SLOW_FRAME else maxf(0,slow_time-dt*0.5)
		if slow_time >= 0.75: cooldown = 12; slow_time = 0
	reason = "active"
	if not enabled: reason = "off"
	elif reduced: reason = "reduced_motion"
	elif low_power: reason = "low_battery"
	elif not day_background: reason = "weather"
	elif adaptive_enabled and cooldown > 0: reason = "frame_budget"
	var next_active := reason == "active"
	var changed := next_active != active
	active = next_active
	if not active:
		if canvas.material == material: canvas.material = null
		accumulator = 0
		return
	if canvas.material != material: canvas.material = material
	phase += dt
	accumulator += dt
	var interval := DUET_INTERVAL if duet_active else NORMAL_INTERVAL
	if not changed and accumulator < interval: return
	accumulator = fmod(accumulator,interval)
	# Small fixed CPU work at 10–15 Hz; the fragment shader contains no trigonometry.
	material.set_shader_parameter("sky_shift",Vector2(sin(phase*0.19)*0.007,0))
	material.set_shader_parameter("leaf_shift",Vector2(sin(phase*1.55)*0.0018,sin(phase*1.15)*0.0012))
	material.set_shader_parameter("leaf_light",sin(phase*0.75)*0.018)
	update_count += 1
