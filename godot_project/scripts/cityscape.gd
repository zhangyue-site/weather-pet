class_name Cityscape
extends Node2D
# ============================================================
#  城市背景: 主建筑 + 远景建筑 + 草地 + 树木 + 云朵
#  关键: 所有随机数据在 _generate_cityscape() 里预生成一次,
#        _draw() 只读取不调用 randf, 避免每帧重绘闪烁
# ============================================================

var buildings: Array[Rect2] = []
var window_lights: Array[Dictionary] = []
var tree_positions: Array[Vector2] = []
var cloud_positions: Array[Dictionary] = []
var far_buildings: Array[Rect2] = []      # 远景建筑 (预生成, 防闪烁)
var grass_tufts: Array[Dictionary] = []   # 草丛 (预生成, 防闪烁)
var is_night: bool = false
var _generated_for_size: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _data: Node = null

func _ready():
	_data = get_node_or_null("/root/DataChannel")
	_generate_cityscape()
	queue_redraw()

func _process(delta: float):
	_time += delta
	var viewport_size := get_viewport_rect().size
	if viewport_size != _generated_for_size and viewport_size.x > 0.0 and viewport_size.y > 0.0:
		_generate_cityscape()
	# 更新昼夜状态 (根据 DataChannel 时间)
	if _data and "current_hour" in _data:
		var hour: int = _data.current_hour
		is_night = hour < 6 or hour >= 19
	queue_redraw()

func generate(is_nighttime: bool):
	if is_nighttime != is_night:
		is_night = is_nighttime
		queue_redraw()

func _generate_cityscape():
	buildings.clear()
	window_lights.clear()
	tree_positions.clear()
	cloud_positions.clear()
	far_buildings.clear()
	grass_tufts.clear()

	var viewport_size := get_viewport_rect().size
	_generated_for_size = viewport_size
	var view_width := viewport_size.x if viewport_size.length() >= 1.0 else 1080.0
	var view_height := viewport_size.y if viewport_size.y > 0.0 else 1920.0
	var ground_y := view_height * 0.78
	var x = 0.0

	# ---- 主建筑 (预生成) ----
	while x < view_width:
		var bw = randf_range(50, 100)
		var bh = randf_range(100, 280)
		var b = Rect2(x, ground_y - bh, bw, bh)
		buildings.append(b)

		var cols = int(bw / 20)
		for i in range(cols):
			for j in range(int(bh / 25)):
				var lit = randf() > 0.35
				window_lights.append({
					"rect": Rect2(x + 6 + i * 18, ground_y - bh + 12 + j * 24, 10, 14),
					"lit": lit,
					"building_idx": buildings.size() - 1,
					"flicker_speed": randf_range(0.5, 3.0),
					"flicker_phase": randf() * TAU,
					"warm": randf() > 0.3
				})

		x += bw + randf_range(3, 10)
		if randf() > 0.4:
			tree_positions.append(Vector2(x - 12, ground_y))
		x += randf_range(0, 18)

	# ---- 远景建筑 (预生成, 替代原 _draw 里的随机循环) ----
	var fx := -20.0
	while fx < view_width + 50:
		var fbw := randf_range(60.0, 130.0)
		var fbh := randf_range(150.0, 350.0)
		far_buildings.append(Rect2(fx, ground_y - fbh, fbw, fbh))
		fx += fbw + randf_range(15, 40)

	# ---- 草丛 (预生成, 替代原 _draw 里的随机循环) ----
	var gx := 5.0
	while gx < view_width:
		if randf() > 0.6:
			grass_tufts.append({
				"x": gx,
				"h": randf_range(3.0, 8.0)
			})
		gx += randf_range(8, 20)

	# ---- 云朵 ----
	for i in range(int(view_width / 180) + 2):
		cloud_positions.append({
			"x": randf_range(-50.0, view_width + 50.0),
			"y": randf_range(30.0, 180.0),
			"scale": randf_range(0.6, 1.4),
			"speed": randf_range(4.0, 12.0),
			"opacity": randf_range(0.15, 0.45)
		})

func _draw():
	var viewport_size := get_viewport_rect().size
	var view_width := viewport_size.x if viewport_size.x > 0.0 else 1080.0
	var view_height := viewport_size.y if viewport_size.y > 0.0 else 1920.0
	var ground_y := view_height * 0.78

	_draw_ground(view_width, view_height, ground_y)
	_draw_far_buildings(view_width, ground_y)
	_draw_buildings()
	_draw_windows()
	for t in tree_positions:
		_draw_tree(t)
	_draw_clouds(view_width)

func _draw_ground(view_width: float, view_height: float, ground_y: float):
	# 地面渐变
	var strips := 6
	for i in range(strips):
		var t := float(i) / float(strips)
		var y := ground_y + (view_height - ground_y) * t
		var h := (view_height - ground_y) / float(strips) + 1.0
		var col := Color(0.18, 0.22, 0.18).lerp(Color(0.12, 0.15, 0.12), t)
		draw_rect(Rect2(Vector2(0, y), Vector2(view_width, h)), col, true)

	# 草地线
	draw_line(Vector2(0, ground_y), Vector2(view_width, ground_y), Color(0.3, 0.45, 0.25), 3.0)
	# 草丛 (读取预生成数据, 不再随机)
	for g in grass_tufts:
		var gx: float = g["x"]
		var gh: float = g["h"]
		draw_line(Vector2(gx, ground_y), Vector2(gx - 2, ground_y - gh), Color(0.25, 0.5, 0.18, 0.6), 1.5)
		draw_line(Vector2(gx, ground_y), Vector2(gx + 2, ground_y - gh * 0.8), Color(0.3, 0.55, 0.2, 0.5), 1.5)

func _draw_far_buildings(view_width: float, ground_y: float):
	# 远景建筑 (读取预生成数据, 不再随机)
	var col := Color(0.12, 0.13, 0.18, 0.6) if is_night else Color(0.55, 0.6, 0.68, 0.3)
	for b in far_buildings:
		var strips := 4
		for s in range(strips):
			var t := float(s) / float(strips)
			var sy := b.position.y + b.size.y * t
			var sh := b.size.y / float(strips) + 1.0
			var sc := col.lerp(col.darkened(0.15), t)
			draw_rect(Rect2(Vector2(b.position.x, sy), Vector2(b.size.x, sh)), sc, true)

func _draw_buildings():
	for b in buildings:
		var base_col := Color(0.15, 0.17, 0.22) if is_night else Color(0.45, 0.48, 0.55)
		var top_col := base_col.lerp(Color.WHITE, 0.08)
		var bot_col := base_col.darkened(0.15)

		# 建筑体渐变
		var strips := 5
		for s in range(strips):
			var t := float(s) / float(strips)
			var y := b.position.y + b.size.y * t
			var h := b.size.y / float(strips) + 1.0
			var c := top_col.lerp(bot_col, t)
			draw_rect(Rect2(Vector2(b.position.x, y), Vector2(b.size.x, h)), c, true)

		# 屋顶高光线
		draw_line(Vector2(b.position.x, b.position.y), Vector2(b.position.x + b.size.x, b.position.y), Color(0.4, 0.42, 0.48), 2.0)
		# 左侧阴影
		draw_rect(Rect2(b.position, Vector2(3, b.size.y)), Color(0, 0, 0, 0.15), true)

		# 屋顶天线 (用建筑 index 做确定性判断, 不用 randf)
		var bidx = buildings.find(b)
		if bidx % 2 == 0:  # 确定性: 偶数建筑有天线
			var ax := b.position.x + b.size.x * 0.5
			draw_line(Vector2(ax, b.position.y), Vector2(ax, b.position.y - 12), Color(0.3, 0.32, 0.35), 1.5)
			draw_circle(Vector2(ax, b.position.y - 12), 2.0, Color(1.0, 0.3, 0.3, 0.8) if is_night else Color(0.6, 0.3, 0.3))

func _draw_windows():
	for w in window_lights:
		if not bool(w["lit"]):
			continue
		var flicker := (sin(_time * w["flicker_speed"] + w["flicker_phase"]) + 1.0) * 0.5
		if is_night:
			var warm_col := Color(1.0, 0.88, 0.5, 0.7 + flicker * 0.3)
			var cool_col := Color(0.7, 0.82, 1.0, 0.5 + flicker * 0.2)
			var wcol := warm_col if w["warm"] else cool_col
			draw_rect(w["rect"], wcol, true)
			var glow_center: Vector2 = w["rect"].position + w["rect"].size * 0.5
			draw_circle(glow_center, 8.0, Color(wcol.r, wcol.g, wcol.b, 0.12))
		else:
			var wcol := Color(0.95, 0.9, 0.7, 0.12 + flicker * 0.08)
			draw_rect(w["rect"], wcol, true)

func _draw_tree(pos: Vector2):
	var trunk_col := Color(0.4, 0.25, 0.12)
	var trunk_dark := trunk_col.darkened(0.3)
	draw_rect(Rect2(pos.x - 2, pos.y - 28, 5, 28), trunk_col, true)
	draw_rect(Rect2(pos.x - 2, pos.y - 28, 2, 28), trunk_dark, true)

	var canopy_base := Color(0.18, 0.42, 0.12) if is_night else Color(0.22, 0.52, 0.15)
	var canopy_light := canopy_base.lerp(Color(0.4, 0.7, 0.3), 0.3)
	var canopy_dark := canopy_base.darkened(0.2)

	draw_circle(pos + Vector2(2, -28), 14.0, canopy_dark.lerp(Color.BLACK, 0.3))
	draw_circle(pos + Vector2(0, -32), 13.0, canopy_dark)
	draw_circle(pos + Vector2(-9, -38), 11.0, canopy_base)
	draw_circle(pos + Vector2(9, -38), 11.0, canopy_base)
	draw_circle(pos + Vector2(0, -45), 10.0, canopy_light)
	draw_circle(pos + Vector2(-3, -48), 5.0, canopy_light.lerp(Color.WHITE, 0.2))

func _draw_clouds(view_width: float):
	for c in cloud_positions:
		var cx : float = fmod(c["x"] + _time * c["speed"], view_width + 100.0) - 50.0
		var cy : float = c["y"]
		var s : float = c["scale"]
		var op : float = c["opacity"]
		var base_col := Color(0.85, 0.87, 0.92, op) if is_night else Color(0.95, 0.96, 0.98, op)

		_draw_cloud_puff(Vector2(cx, cy), 28.0 * s, 14.0 * s, base_col)
		_draw_cloud_puff(Vector2(cx - 22 * s, cy + 3 * s), 20.0 * s, 12.0 * s, base_col.darkened(0.05))
		_draw_cloud_puff(Vector2(cx + 22 * s, cy + 2 * s), 22.0 * s, 11.0 * s, base_col.darkened(0.03))
		_draw_cloud_puff(Vector2(cx - 5 * s, cy - 6 * s), 15.0 * s, 8.0 * s, Color(1, 1, 1, op * 0.3))

func _draw_cloud_puff(center: Vector2, rx: float, ry: float, color: Color):
	var points := PackedVector2Array()
	var steps := 20
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)
