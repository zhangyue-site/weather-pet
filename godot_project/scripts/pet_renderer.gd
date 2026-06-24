class_name PetRenderer
extends Node2D

enum FaceExpr { SMILE, HAPPY, SLEEP, SLEEPY, OPEN, SCARED, SAD, ANGRY, SURPRISE, LAUGH, WINK, BLUSH }

var _scale_factor: float = 1.0
var _is_walking: bool = false
var _walk_cycle: float = 0.0
var _base_position: Vector2 = Vector2.ZERO
var _left_arm_angle: float = 30.0
var _right_arm_angle: float = 30.0
var _left_arm_offset: float = 0.0
var _right_arm_offset: float = 0.0

var _body_color: Color = Color(0.95, 0.95, 0.65)
var _breath_cycle: float = 0.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _current_expr: int = FaceExpr.SMILE

var body: ColorRect = null
var head: ColorRect = null
var left_eye: ColorRect = null
var right_eye: ColorRect = null
var mouth: ColorRect = null
var left_leg: ColorRect = null
var right_leg: ColorRect = null
var left_arm: ColorRect = null
var right_arm: ColorRect = null
var blush_left: ColorRect = null
var blush_right: ColorRect = null

func _ready():
	_build_body()
	queue_redraw()

func _build_body():
	var cx = 0.0
	var cy = 0.0

	body = ColorRect.new()
	body.size = Vector2(80, 100)
	body.color = _body_color
	body.position = Vector2(cx - 40, cy + 80)
	add_child(body)

	head = ColorRect.new()
	head.size = Vector2(70, 65)
	head.color = _body_color
	head.position = Vector2(cx - 35, cy + 22)
	add_child(head)

	left_eye = ColorRect.new()
	left_eye.size = Vector2(6, 6)
	left_eye.color = Color.BLACK
	left_eye.position = Vector2(cx - 12, cy + 38)
	add_child(left_eye)

	right_eye = ColorRect.new()
	right_eye.size = Vector2(6, 6)
	right_eye.color = Color.BLACK
	right_eye.position = Vector2(cx + 6, cy + 38)
	add_child(right_eye)

	mouth = ColorRect.new()
	mouth.size = Vector2(8, 3)
	mouth.color = Color(0.6, 0.3, 0.3)
	mouth.position = Vector2(cx - 4, cy + 56)
	add_child(mouth)

	left_leg = ColorRect.new()
	left_leg.size = Vector2(10, 20)
	left_leg.color = Color(0.85, 0.85, 0.55)
	left_leg.position = Vector2(cx - 22, cy + 175)
	add_child(left_leg)

	right_leg = ColorRect.new()
	right_leg.size = Vector2(10, 20)
	right_leg.color = Color(0.85, 0.85, 0.55)
	right_leg.position = Vector2(cx + 12, cy + 175)
	add_child(right_leg)

	left_arm = ColorRect.new()
	left_arm.size = Vector2(8, 40)
	left_arm.color = _body_color
	left_arm.position = Vector2(cx - 50, cy + 95)
	left_arm.pivot_offset = Vector2(4, 40)
	add_child(left_arm)

	right_arm = ColorRect.new()
	right_arm.size = Vector2(8, 40)
	right_arm.color = _body_color
	right_arm.position = Vector2(cx + 42, cy + 95)
	right_arm.pivot_offset = Vector2(4, 40)
	add_child(right_arm)

	blush_left = ColorRect.new()
	blush_left.size = Vector2(10, 6)
	blush_left.color = Color(1.0, 0.6, 0.6, 0.5)
	blush_left.position = Vector2(cx - 22, cy + 48)
	blush_left.visible = false
	add_child(blush_left)

	blush_right = ColorRect.new()
	blush_right.size = Vector2(10, 6)
	blush_right.color = Color(1.0, 0.6, 0.6, 0.5)
	blush_right.position = Vector2(cx + 12, cy + 48)
	blush_right.visible = false
	add_child(blush_right)

	_reset_face_positions()

func _process(delta: float):
	_breath_cycle += delta * 2.5
	_blink_timer += delta
	if _blink_timer > 3.5 + randf() * 2.0 and not _is_blinking:
		_is_blinking = true
		_blink_timer = 0.0
	if _is_blinking and _blink_timer > 0.15:
		_is_blinking = false
		_blink_timer = 0.0

	if _is_walking:
		_walk_cycle += delta * 6.0
		var leg_swing = sin(_walk_cycle) * 15.0
		if left_leg: left_leg.rotation = deg_to_rad(leg_swing)
		if right_leg: right_leg.rotation = deg_to_rad(-leg_swing)
	else:
		if left_leg: left_leg.rotation = 0
		if right_leg: right_leg.rotation = 0
	queue_redraw()

func _draw():
	var breath_offset := sin(_breath_cycle) * 1.5
	var leg_offset := sin(_walk_cycle) * 6.0 if _is_walking else 0.0

	var body_col := _body_color
	var body_light := body_col.lerp(Color.WHITE, 0.18)
	var body_dark := body_col.lerp(Color(0.3, 0.25, 0.1), 0.25)
	var body_shadow := Color(0.0, 0.0, 0.0, 0.12)
	var limb_col := body_col.lerp(Color(0.3, 0.25, 0.1), 0.15)
	var leg_color := body_col.lerp(Color(0.3, 0.25, 0.1), 0.15)
	var eye_color := Color(0.08, 0.06, 0.06)
	var blush_color := Color(1.0, 0.6, 0.6, 0.4)
	var mouth_color := Color(0.55, 0.28, 0.28)

	# === SHADOW under pet ===
	draw_ellipse(Vector2(0, 198 + breath_offset * 0.3), Vector2(52, 10), Color(0.0, 0.0, 0.0, 0.15))

	# === BODY (rounded rect with gradient) ===
	var body_rect := Rect2(Vector2(-42, 82 + breath_offset * 0.5), Vector2(84, 100))
	_draw_rounded_rect_gradient(body_rect, body_col, body_light, body_dark, 18.0)

	# === HEAD (rounded with highlight) ===
	var head_rect := Rect2(Vector2(-38, 20 + breath_offset * 0.3), Vector2(76, 68))
	_draw_rounded_rect_gradient(head_rect, body_col, body_light, body_dark, 22.0)

	# Head highlight (top specular)
	draw_circle(Vector2(-5, 28 + breath_offset * 0.3), 18.0, Color(1.0, 1.0, 1.0, 0.12))

	# === EARS (little rounded bumps) ===
	_draw_ear(Vector2(-30, 18 + breath_offset * 0.3), body_col, body_dark)
	_draw_ear(Vector2(30, 18 + breath_offset * 0.3), body_col, body_dark)

	# === ARMS ===
	_draw_arm(Vector2(-48 + _left_arm_offset, 98 + breath_offset * 0.4), _left_arm_angle, limb_col, body_dark)
	_draw_arm(Vector2(48 + _right_arm_offset, 98 + breath_offset * 0.4), _right_arm_angle, limb_col, body_dark, true)

	# === LEGS ===
	var leg_w := 12.0
	_draw_rounded_rect_simple(Rect2(Vector2(-24, 178 + breath_offset * 0.2), Vector2(leg_w, 22)), leg_color, 4.0)
	_draw_rounded_rect_simple(Rect2(Vector2(12, 178 + breath_offset * 0.2), Vector2(leg_w, 22)), leg_color, 4.0)

	# Leg shoes (darker tips)
	draw_circle(Vector2(-18, 200 + breath_offset * 0.2), 7.0, body_dark.lerp(Color(0.2, 0.15, 0.1), 0.4))
	draw_circle(Vector2(18, 200 + breath_offset * 0.2), 7.0, body_dark.lerp(Color(0.2, 0.15, 0.1), 0.4))

	if _is_walking:
		draw_line(Vector2(-18, 178 + breath_offset * 0.2), Vector2(-18 + leg_offset, 200 + breath_offset * 0.2), leg_color, leg_w)
		draw_line(Vector2(18, 178 + breath_offset * 0.2), Vector2(18 - leg_offset, 200 + breath_offset * 0.2), leg_color, leg_w)

	# === EYES ===
	if left_eye and right_eye:
		var eye_y := left_eye.position.y + breath_offset * 0.3
		var le_pos := Vector2(left_eye.position.x, eye_y)
		var re_pos := Vector2(right_eye.position.x, eye_y)

		if _is_blinking and _current_expr != FaceExpr.SLEEP and _current_expr != FaceExpr.SLEEPY:
			# Blink: horizontal line
			draw_line(le_pos + Vector2(0, 3), le_pos + Vector2(6, 3), eye_color, 2.0)
			draw_line(re_pos + Vector2(0, 3), re_pos + Vector2(6, 3), eye_color, 2.0)
		else:
			var es := left_eye.size
			# Eye whites
			draw_circle(le_pos + es * 0.5, es.x * 0.7, Color.WHITE)
			draw_circle(re_pos + es * 0.5, es.x * 0.7, Color.WHITE)
			# Pupils
			draw_circle(le_pos + es * 0.5, es.x * 0.45, eye_color)
			draw_circle(re_pos + es * 0.5, es.x * 0.45, eye_color)
			# Eye highlights
			draw_circle(le_pos + es * 0.5 + Vector2(-1.5, -1.5), es.x * 0.18, Color(1, 1, 1, 0.9))
			draw_circle(re_pos + es * 0.5 + Vector2(-1.5, -1.5), es.x * 0.18, Color(1, 1, 1, 0.9))

	# === MOUTH ===
	if mouth:
		var m_pos := Vector2(mouth.position.x, mouth.position.y + breath_offset * 0.3)
		var m_size := mouth.size
		match _current_expr:
			FaceExpr.SMILE, FaceExpr.HAPPY:
				_draw_smile(m_pos, m_size, mouth_color)
			FaceExpr.SLEEP, FaceExpr.SLEEPY:
				_draw_sleep_mouth(m_pos, mouth_color)
			FaceExpr.OPEN, FaceExpr.SCARED:
				_draw_open_mouth(m_pos, m_size, mouth_color)
			FaceExpr.SAD:
				_draw_sad_mouth(m_pos, mouth_color)
			FaceExpr.LAUGH:
				_draw_laugh_mouth(m_pos, mouth_color)
			_:
				_draw_smile(m_pos, m_size, mouth_color)

	# === BLUSH ===
	if blush_left and blush_left.visible:
		var bl_pos := blush_left.position + Vector2(0, breath_offset * 0.3)
		draw_circle(bl_pos + blush_left.size * 0.5, 7.0, blush_color)
		draw_circle(bl_pos + blush_left.size * 0.5, 5.0, Color(1.0, 0.5, 0.5, 0.2))
	if blush_right and blush_right.visible:
		var br_pos := blush_right.position + Vector2(0, breath_offset * 0.3)
		draw_circle(br_pos + blush_right.size * 0.5, 7.0, blush_color)
		draw_circle(br_pos + blush_right.size * 0.5, 5.0, Color(1.0, 0.5, 0.5, 0.2))

func _draw_rounded_rect_gradient(rect: Rect2, base: Color, top_col: Color, bot_col: Color, radius: float):
	# Draw gradient via layered strips
	var strips := 8
	for i in range(strips):
		var t := float(i) / float(strips)
		var y := rect.position.y + rect.size.y * t
		var h := rect.size.y / float(strips) + 1.0
		var col := top_col.lerp(bot_col, t)
		var strip_rect := Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, h))
		_draw_rounded_rect_simple(strip_rect, col, radius if i == 0 else 0.0 if i < strips - 1 else radius)

func _draw_rounded_rect_simple(rect: Rect2, color: Color, radius: float):
	if radius <= 0.0:
		draw_rect(rect, color, true)
		return
	var inner := Rect2(rect.position + Vector2(radius, 0), Vector2(rect.size.x - radius * 2.0, rect.size.y))
	draw_rect(inner, color, true)
	draw_rect(Rect2(rect.position + Vector2(0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color, true)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(rect.end - Vector2(radius, radius), radius, color)

func _draw_ear(pos: Vector2, base_col: Color, dark_col: Color):
	draw_circle(pos, 10.0, base_col)
	draw_circle(pos + Vector2(0, -2), 6.0, base_col.lerp(Color(1.0, 0.7, 0.7), 0.3))

func _draw_arm(shoulder: Vector2, degrees: float, col: Color, dark_col: Color, mirror: bool = false):
	var dir := Vector2.from_angle(deg_to_rad(90.0 + degrees))
	if mirror:
		dir = Vector2.from_angle(deg_to_rad(90.0 - degrees))
	# Arm with rounded ends
	var end := shoulder + dir * 42.0
	draw_line(shoulder, end, col, 10.0)
	# Hand circle
	draw_circle(end, 6.0, col.lerp(Color.WHITE, 0.1))
	# Shadow on arm
	draw_line(shoulder + Vector2(1, 2), end + Vector2(1, 2), Color(0, 0, 0, 0.08), 10.0)

func _draw_smile(pos: Vector2, size: Vector2, color: Color):
	var cx := pos.x + size.x * 0.5
	var cy := pos.y + size.y * 0.5
	var points := PackedVector2Array()
	for i in range(12):
		var t := float(i) / 11.0
		var angle := deg_to_rad(200.0 + t * 140.0)
		points.append(Vector2(cx + cos(angle) * 6.0, cy + sin(angle) * 4.0))
	if points.size() >= 2:
		draw_polyline(points, color, 2.0, true)

func _draw_sleep_mouth(pos: Vector2, color: Color):
	var cx := pos.x + 3.0
	var cy := pos.y + 2.0
	draw_line(Vector2(cx - 3, cy), Vector2(cx + 3, cy), color, 1.5, true)

func _draw_open_mouth(pos: Vector2, size: Vector2, color: Color):
	var cx := pos.x + size.x * 0.5
	var cy := pos.y + size.y * 0.5
	draw_circle(Vector2(cx, cy), maxf(size.x, size.y) * 0.5, color)
	# Inner mouth
	draw_circle(Vector2(cx, cy + 1), maxf(size.x, size.y) * 0.3, color.lerp(Color(0.3, 0.1, 0.1), 0.5))

func _draw_sad_mouth(pos: Vector2, color: Color):
	var cx := pos.x + 4.0
	var cy := pos.y + 2.0
	var points := PackedVector2Array()
	for i in range(10):
		var t := float(i) / 9.0
		var angle := deg_to_rad(20.0 + t * 140.0)
		points.append(Vector2(cx + cos(angle) * 5.0, cy - sin(angle) * 3.0))
	if points.size() >= 2:
		draw_polyline(points, color, 2.0, true)

func _draw_laugh_mouth(pos: Vector2, color: Color):
	var cx := pos.x + 4.0
	var cy := pos.y + 2.0
	draw_circle(Vector2(cx, cy), 6.0, color)
	draw_circle(Vector2(cx, cy - 1), 4.0, color.lerp(Color(0.4, 0.15, 0.15), 0.5))

func _reset_face_positions():
	if left_eye:
		left_eye.position = Vector2(-12, 38)
	if right_eye:
		right_eye.position = Vector2(6, 38)
	if mouth:
		mouth.position.x = -4

func set_arms(la: float, ra: float, lao: float = 0.0, rao: float = 0.0):
	_left_arm_angle = la
	_right_arm_angle = ra
	_left_arm_offset = lao
	_right_arm_offset = rao
	if left_arm:
		left_arm.rotation = deg_to_rad(la)
		left_arm.position.x = -50 + lao
	if right_arm:
		right_arm.rotation = deg_to_rad(ra)
		right_arm.position.x = 42 + rao

func set_expression(expr: int, persistent: bool = false):
	_current_expr = expr
	if not mouth or not left_eye or not right_eye:
		return
	_reset_face_positions()
	match expr:
		FaceExpr.SMILE:
			mouth.size = Vector2(8, 3)
			mouth.position.y = 56
			left_eye.size = Vector2(6, 6)
			right_eye.size = Vector2(6, 6)
			if blush_left: blush_left.visible = false
			if blush_right: blush_right.visible = false
		FaceExpr.HAPPY:
			mouth.size = Vector2(12, 6)
			mouth.position.y = 54
			left_eye.size = Vector2(7, 7)
			right_eye.size = Vector2(7, 7)
			if blush_left: blush_left.visible = true
			if blush_right: blush_right.visible = true
		FaceExpr.SLEEP:
			mouth.size = Vector2(6, 2)
			mouth.position.y = 57
			left_eye.size = Vector2(2, 2)
			right_eye.size = Vector2(2, 2)
			if blush_left: blush_left.visible = false
			if blush_right: blush_right.visible = false
		FaceExpr.SLEEPY:
			mouth.size = Vector2(6, 2)
			mouth.position.y = 57
			left_eye.size = Vector2(4, 2)
			right_eye.size = Vector2(4, 2)
			if blush_left: blush_left.visible = false
			if blush_right: blush_right.visible = false
		FaceExpr.OPEN:
			mouth.size = Vector2(8, 8)
			mouth.position.y = 54
			left_eye.size = Vector2(8, 8)
			right_eye.size = Vector2(8, 8)
			if blush_left: blush_left.visible = false
			if blush_right: blush_right.visible = false
		FaceExpr.SCARED:
			mouth.size = Vector2(8, 8)
			mouth.position.y = 54
			left_eye.size = Vector2(10, 10)
			right_eye.size = Vector2(10, 10)
			if blush_left: blush_left.visible = false
			if blush_right: blush_right.visible = false
		FaceExpr.SAD:
			mouth.size = Vector2(8, 2)
			mouth.position.y = 58
			left_eye.size = Vector2(5, 5)
			right_eye.size = Vector2(5, 5)
			if blush_left: blush_left.visible = false
			if blush_right: blush_right.visible = false
		FaceExpr.LAUGH:
			mouth.size = Vector2(10, 6)
			mouth.position.y = 54
			left_eye.size = Vector2(3, 5)
			right_eye.size = Vector2(3, 5)
			if blush_left: blush_left.visible = true
			if blush_right: blush_right.visible = true
	queue_redraw()

func set_walking(w: bool):
	_is_walking = w
	queue_redraw()

func set_color(c: Color):
	_body_color = c
	if body: body.color = c
	if head: head.color = c
	if left_arm: left_arm.color = c
	if right_arm: right_arm.color = c
	queue_redraw()

func set_base_position(pos: Vector2):
	_base_position = pos
	position = pos
	queue_redraw()

func draw_ellipse(center: Vector2, radii: Vector2, color: Color):
	var points := PackedVector2Array()
	var steps := 32
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
