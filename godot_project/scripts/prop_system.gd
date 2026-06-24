class_name PropSystem
extends Node2D

var current_prop: String = ""
var _timer: float = 0.0
var _drops: Array[Vector2] = []
var _stars: Array[Dictionary] = []
var _fade_a: float = 0.0

@onready var data: Node = get_node_or_null("/root/DataChannel")

func _ready():
	visible = false

func _process(delta: float):
	_refresh_prop()
	visible = _fade_a > 0.01
	if not visible:
		return
	_timer += delta
	_update_drops(delta)
	_update_stars(delta)
	queue_redraw()

func _draw():
	if not visible or current_prop == "":
		return
	match current_prop:
		"umbrella":
			_draw_umbrella()
		"scarf":
			_draw_scarf()
		"raincoat":
			_draw_raincoat()
		"sunglasses":
			_draw_sunglasses()
		"snow_hat":
			_draw_snow_hat()
		"speech_bubble":
			_draw_speech()
		"snowflakes":
			_draw_snowflakes()
		"snowball":
			_draw_snowball()
		"puddle":
			_draw_puddle()
		"starry_sky":
			_draw_stars()
		"holiday_bow":
			_draw_holiday_bow()

func _draw_umbrella():
	var al := _fade_a
	# Umbrella canopy with gradient
	var canopy_colors := [
		Color(0.2, 0.55, 0.92, al),
		Color(0.3, 0.65, 0.96, al),
		Color(0.4, 0.72, 0.98, al)
	]
	# Shadow under umbrella
	draw_ellipse(Vector2(-50, -8), Vector2(42, 8), Color(0, 0, 0, 0.1 * al))
	# Canopy (semi-circle with gradient feel)
	for i in range(3):
		var radius := 42.0 - i * 3.0
		var col: Color = canopy_colors[i]
		var points := PackedVector2Array()
		for j in range(20):
			var angle := deg_to_rad(180.0 + float(j) / 19.0 * 180.0)
			points.append(Vector2(-50, -10) + Vector2(cos(angle) * radius, sin(angle) * radius * 0.5))
		if points.size() >= 3:
			draw_colored_polygon(points, col)
	# Ribs (arc lines)
	for rib_i in range(5):
		var angle := deg_to_rad(180.0 + float(rib_i) / 4.0 * 180.0)
		var rib_end := Vector2(-50, -10) + Vector2(cos(angle) * 40.0, sin(angle) * 20.0)
		draw_line(Vector2(-50, -10), rib_end, Color(0.15, 0.4, 0.7, al * 0.5), 1.0)
	# Handle (pole)
	draw_line(Vector2(-50, -10), Vector2(-50, 40), Color(0.5, 0.5, 0.5, al), 3.0)
	# Hook end
	draw_arc(Vector2(-46, 40), 5.0, deg_to_rad(0), deg_to_rad(180), 10, Color(0.5, 0.5, 0.5, al), 2.5)
	# Highlight on canopy
	draw_circle(Vector2(-55, -18), 8.0, Color(1, 1, 1, 0.15 * al))

func _draw_scarf():
	var al := _fade_a
	var scarf_base := Color(0.85, 0.15, 0.08, al)
	var scarf_light := scarf_base.lerp(Color.WHITE, 0.2)
	var scarf_dark := scarf_base.darkened(0.3)
	# Scarf wrap around neck
	_draw_rounded_rect(Rect2(-20, 26, 40, 8), scarf_base, 3.0)
	# Highlight stripe
	draw_line(Vector2(-18, 28), Vector2(18, 28), scarf_light, 1.5)
	# Hanging tail
	_draw_rounded_rect(Rect2(12, 26, 10, 28), scarf_dark, 3.0)
	# Stripe pattern on tail
	draw_line(Vector2(14, 34), Vector2(20, 34), Color(0.9, 0.85, 0.2, al), 2.0)
	draw_line(Vector2(14, 42), Vector2(20, 42), Color(0.9, 0.85, 0.2, al), 2.0)
	# Fringe at bottom
	for f in range(3):
		draw_line(Vector2(13 + f * 3, 54), Vector2(12 + f * 3, 58), scarf_dark, 1.0)

func _draw_raincoat():
	var al := _fade_a
	var rc_base := Color(0.95, 0.92, 0.15, al * 0.85)
	var rc_light := rc_base.lerp(Color.WHITE, 0.2)
	var rc_dark := rc_base.darkened(0.2)
	# Body
	_draw_rounded_rect(Rect2(-26, 8, 52, 46), rc_base, 6.0)
	# Hood
	draw_arc(Vector2(0, 8), 16.0, deg_to_rad(160), deg_to_rad(380), 16, rc_base, 16.0)
	# Highlight
	draw_line(Vector2(-20, 14), Vector2(-8, 14), rc_light, 1.5)
	# Buttons
	for b_i in range(3):
		draw_circle(Vector2(0, 20 + b_i * 10), 2.5, rc_dark)
	# Collar
	_draw_rounded_rect(Rect2(-14, 6, 28, 6), rc_light, 2.0)

func _draw_sunglasses():
	var al := _fade_a
	var glass_base := Color(0.08, 0.08, 0.1, al)
	var glass_lens := Color(0.15, 0.2, 0.35, al * 0.9)
	var frame_highlight := Color(0.3, 0.3, 0.35, al)
	# Frame
	draw_line(Vector2(-18, 37), Vector2(18, 37), frame_highlight, 3.0)
	# Left lens (rounded rect)
	_draw_rounded_rect(Rect2(-20, 32, 16, 11), glass_lens, 3.0)
	draw_rect(Rect2(-20, 32, 16, 11), glass_base, false, 1.5)
	# Right lens
	_draw_rounded_rect(Rect2(4, 32, 16, 11), glass_lens, 3.0)
	draw_rect(Rect2(4, 32, 16, 11), glass_base, false, 1.5)
	# Lens shine
	draw_line(Vector2(-17, 34), Vector2(-10, 34), Color(1, 1, 1, 0.2 * al), 1.0)
	draw_line(Vector2(7, 34), Vector2(14, 34), Color(1, 1, 1, 0.2 * al), 1.0)
	# Arms
	draw_line(Vector2(-20, 37), Vector2(-25, 35), frame_highlight, 2.0)
	draw_line(Vector2(20, 37), Vector2(25, 35), frame_highlight, 2.0)

func _draw_snow_hat():
	var al := _fade_a
	var hat_base := Color(0.15, 0.3, 0.5, al)
	var hat_light := hat_base.lerp(Color.WHITE, 0.15)
	var hat_dark := hat_base.darkened(0.2)
	# Brim
	_draw_rounded_rect(Rect2(-32, -14, 64, 8), Color(0.88, 0.88, 0.9, al), 3.0)
	# Hat body
	_draw_rounded_rect(Rect2(-24, -32, 48, 20), hat_base, 6.0)
	# Highlight stripe
	draw_line(Vector2(-20, -22), Vector2(20, -22), hat_light, 2.0)
	# Pom-pom
	draw_circle(Vector2(0, -34), 10.0, Color(0.9, 0.9, 0.92, al))
	draw_circle(Vector2(-2, -36), 5.0, Color(1, 1, 1, 0.3 * al))
	# Fur trim
	for f_i in range(8):
		var fx := -28.0 + f_i * 8.0
		draw_circle(Vector2(fx, -10), 4.0, Color(0.92, 0.92, 0.95, al))

func _draw_speech():
	var al := _fade_a
	# Speech bubble with shadow
	var bubble_rect := Rect2(-68, -128, 136, 65)
	# Shadow
	_draw_rounded_rect(Rect2(bubble_rect.position + Vector2(3, 3), bubble_rect.size), Color(0, 0, 0, 0.1 * al), 10.0)
	# Bubble
	_draw_rounded_rect(bubble_rect, Color(1, 1, 1, al * 0.92), 10.0)
	# Border
	_draw_rounded_rect_border(bubble_rect, Color(0.8, 0.82, 0.85, al * 0.6), 10.0, 1.5)
	# Tail
	var tail_pts := PackedVector2Array([
		Vector2(-30, -63),
		Vector2(-45, -50),
		Vector2(-25, -63)
	])
	draw_colored_polygon(tail_pts, Color(1, 1, 1, al * 0.92))
	# Inner highlight
	draw_line(Vector2(-60, -120), Vector2(-40, -120), Color(0.9, 0.95, 1.0, 0.3 * al), 2.0)

	match data.current_hour:
		6, 7:
			_draw_emoji("早安!", Vector2(-32, -102), al)
		18, 19:
			_draw_emoji("晚霞!", Vector2(-32, -102), al)
		22, 23:
			_draw_emoji("晚安!", Vector2(-32, -102), al)
		_:
			if data.current_weather.get("condition", "") == "rain":
				_draw_emoji("下雨", Vector2(-32, -102), al)
			else:
				_draw_emoji("你好!", Vector2(-32, -102), al)

func _draw_emoji(t: String, pos: Vector2, al: float):
	draw_string(ThemeDB.fallback_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.2, 0.2, 0.2, al))

func _draw_snowflakes():
	var al := _fade_a
	for i in range(12):
		var x := sin(_timer * 0.8 + i * 0.7) * 55.0
		var y := sin(_timer * 0.4 + i * 1.1) * 25.0
		var sz := 2.5 + sin(i * 2.0) * 1.5
		var brightness := (sin(_timer * 2.0 + i * 1.5) + 1.0) * 0.5
		var col := Color(1, 1, 1, al * (0.5 + brightness * 0.5))
		# Snowflake: circle + cross
		draw_circle(Vector2(x, y), sz, col)
		draw_line(Vector2(x - sz, y), Vector2(x + sz, y), col * Color(1, 1, 1, 0.5), 0.8)
		draw_line(Vector2(x, y - sz), Vector2(x, y + sz), col * Color(1, 1, 1, 0.5), 0.8)

func _draw_snowball():
	var al := _fade_a
	# Snowball with gradient
	var base := Color(0.9, 0.95, 1.0, al)
	var highlight := Color(1, 1, 1, al * 0.6)
	var shadow := Color(0.7, 0.78, 0.85, al)
	draw_circle(Vector2(30, -25), 13.0, shadow)
	draw_circle(Vector2(30, -25), 12.0, base)
	draw_circle(Vector2(27, -28), 5.0, highlight)
	# Snow sparkle
	var sparkle := (sin(_timer * 5.0) + 1.0) * 0.5
	draw_circle(Vector2(34, -30), 1.5, Color(1, 1, 1, al * sparkle))

func _draw_puddle():
	var al := _fade_a
	var r := 28.0 + sin(_timer * 1.5) * 3.0
	# Puddle with gradient rings
	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		var rx := r * 1.2
		var ry := r * 0.4
		points.append(Vector2(-30, 92) + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, Color(0.55, 0.7, 0.78, al * 0.4))
	# Inner lighter area
	var inner_pts := PackedVector2Array()
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		inner_pts.append(Vector2(-30, 92) + Vector2(cos(angle) * r * 0.8, sin(angle) * r * 0.3))
	draw_colored_polygon(inner_pts, Color(0.65, 0.8, 0.88, al * 0.3))
	# Ripple animation
	var ripple_r := fmod(_timer * 15.0, r)
	draw_arc(Vector2(-30, 92), ripple_r, 0, TAU, 20, Color(0.8, 0.9, 1.0, al * 0.3 * (1.0 - ripple_r / r)), 1.0)

func _draw_stars():
	var al := _fade_a
	for s in _stars:
		var pos: Vector2 = s["pos"]
		var sz: float = s["size"]
		var bright: float = (sin(_timer * 2.5 + s["phase"]) + 1.0) / 2.0
		# Star glow
		draw_circle(pos, sz * 2.5, Color(1, 1, 0.9, al * bright * 0.15))
		# Star core
		draw_circle(pos, sz, Color(1, 1, 0.85, al * bright))
		# Star highlight
		draw_circle(pos + Vector2(-sz * 0.3, -sz * 0.3), sz * 0.3, Color(1, 1, 1, al * bright * 0.7))
		# Cross sparkle for larger stars
		if sz > 2.0:
			var spark_len := sz * 1.5
			draw_line(pos + Vector2(-spark_len, 0), pos + Vector2(spark_len, 0), Color(1, 1, 0.9, al * bright * 0.3), 0.8)
			draw_line(pos + Vector2(0, -spark_len), pos + Vector2(0, spark_len), Color(1, 1, 0.9, al * bright * 0.3), 0.8)

func _draw_holiday_bow():
	var al := _fade_a
	var bow_base := Color(0.9, 0.2, 0.08, al)
	var bow_light := bow_base.lerp(Color.WHITE, 0.2)
	var bow_dark := bow_base.darkened(0.3)
	# Left loop
	draw_circle(Vector2(-12, -86), 8.0, bow_base)
	draw_circle(Vector2(-14, -88), 4.0, bow_light)
	# Right loop
	draw_circle(Vector2(12, -86), 8.0, bow_base)
	draw_circle(Vector2(10, -88), 4.0, bow_light)
	# Center knot
	draw_circle(Vector2(0, -88), 6.0, bow_dark)
	draw_circle(Vector2(-1, -90), 3.0, bow_light)
	# Ribbons
	draw_line(Vector2(-6, -82), Vector2(-10, -72), bow_base, 2.5)
	draw_line(Vector2(6, -82), Vector2(10, -72), bow_base, 2.5)
	# Gold accent
	draw_circle(Vector2(0, -88), 2.0, Color(1.0, 0.85, 0.2, al))

func _draw_rounded_rect(rect: Rect2, color: Color, radius: float):
	var inner := Rect2(rect.position + Vector2(radius, 0), Vector2(rect.size.x - radius * 2.0, rect.size.y))
	draw_rect(inner, color, true)
	draw_rect(Rect2(rect.position + Vector2(0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color, true)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(rect.end - Vector2(radius, radius), radius, color)

func _draw_rounded_rect_border(rect: Rect2, color: Color, radius: float, width: float):
	draw_arc(rect.position + Vector2(radius, radius), radius, deg_to_rad(180), deg_to_rad(270), 10, color, width)
	draw_arc(Vector2(rect.end.x - radius, rect.position.y + radius), radius, deg_to_rad(270), deg_to_rad(360), 10, color, width)
	draw_arc(Vector2(rect.position.x + radius, rect.end.y - radius), radius, deg_to_rad(90), deg_to_rad(180), 10, color, width)
	draw_arc(rect.end - Vector2(radius, radius), radius, deg_to_rad(0), deg_to_rad(90), 10, color, width)
	draw_line(Vector2(rect.position.x + radius, rect.position.y), Vector2(rect.end.x - radius, rect.position.y), color, width)
	draw_line(Vector2(rect.position.x + radius, rect.end.y), Vector2(rect.end.x - radius, rect.end.y), color, width)
	draw_line(Vector2(rect.position.x, rect.position.y + radius), Vector2(rect.position.x, rect.end.y - radius), color, width)
	draw_line(Vector2(rect.end.x, rect.position.y + radius), Vector2(rect.end.x, rect.end.y - radius), color, width)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color):
	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func show_prop(prop_name: String):
	current_prop = prop_name
	_fade_a = 0.0
	visible = true
	var tw = create_tween()
	tw.tween_property(self, "_fade_a", 1.0, 0.4)

func hide_prop():
	var tw = create_tween()
	tw.tween_property(self, "_fade_a", 0.0, 0.3)
	tw.tween_callback(func(): current_prop = ""; visible = false)

func _update_drops(delta: float):
	if current_prop != "puddle":
		return
	_timer += delta * 0.2

func _update_stars(delta: float):
	if current_prop != "starry_sky":
		return
	for s in _stars:
		s["phase"] += delta * 2.0

func _refresh_prop():
	if not data:
		return
	var weather := String(data.current_weather.get("condition", "clear"))
	var festival_name := String(data.current_festival.get("name", ""))
	var next_prop := ""
	if festival_name != "":
		next_prop = "holiday_bow"
	elif weather == "rain" or weather == "drizzle":
		next_prop = "umbrella"
	elif weather == "heavy_rain" or weather == "thunderstorm":
		next_prop = "raincoat"
	elif weather == "snow" or weather == "heavy_snow":
		next_prop = "snow_hat"
	elif data.current_hour >= 20 or data.current_hour <= 5:
		next_prop = "starry_sky"

	if next_prop == current_prop:
		return
	if next_prop == "":
		hide_prop()
		return
	if next_prop == "starry_sky" and _stars.is_empty():
		_seed_stars()
	show_prop(next_prop)

func _seed_stars():
	_stars.clear()
	for i in range(24):
		_stars.append({
			"pos": Vector2(randf_range(-200.0, 200.0), randf_range(-240.0, -30.0)),
			"size": randf_range(1.0, 3.5),
			"phase": randf_range(0.0, TAU)
		})
