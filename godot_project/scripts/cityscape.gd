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
var lantern_positions: Array[Dictionary] = []  # 小灯笼
var _decor_x: float = 0.0                 # 装饰物区域 x
var _decor_ground_y: float = 0.0          # 地面 y
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

	# ---- 生活装饰物 (晴天娃娃/风车/晾衣绳/灯笼) ----
	_decor_x = view_width * 0.12  # 装饰物集中在左侧院子
	_decor_ground_y = ground_y
	lantern_positions.clear()
	# 2-3 个小灯笼挂在屋檐
	for i in range(2):
		lantern_positions.append({
			"x": view_width * (0.06 + i * 0.05),
			"y": ground_y - randf_range(120, 160)
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
	# ---- 生活装饰物 (随天气变化, 营造童趣生活感) ----
	_draw_teruteru(view_width, view_height)   # 晴天娃娃
	_draw_windmill(ground_y)                  # 风车
	_draw_clothesline(ground_y)               # 晾衣绳 (晴天)
	_draw_lanterns()                          # 小灯笼 (傍晚亮)
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

# ============================================================
#  当前天气/时间状态 (从 DataChannel 读取)
# ============================================================
func _get_weather() -> String:
	if _data and "current_weather" in _data:
		var w = _data.current_weather
		if typeof(w) == TYPE_DICTIONARY:
			return String(w.get("condition", "clear"))
	return "clear"

func _get_hour() -> int:
	if _data and "current_hour" in _data:
		return int(_data.current_hour)
	return 12

func _is_rainy() -> bool:
	var w := _get_weather()
	return w.begins_with("rain") or w == "drizzle" or w == "heavy_rain" or w == "thunderstorm"

func _is_sunny() -> bool:
	var w := _get_weather()
	return w == "clear" or w == "cloudy"

# ============================================================
#  晴天娃娃 (てるてる坊主)
#  晴天: 正挂, 随风摆动, 笑脸
#  雨天: 翻转180°(头朝下), 哭脸 (传说被淋哭就会下雨)
#  夜晚: 闭眼
# ============================================================
func _draw_teruteru(view_width: float, view_height: float):
	# 挂在左上屋檐位置
	var hang_x := view_width * 0.10
	var hang_y := view_height * 0.16
	var rainy := _is_rainy()
	var hour := _get_hour()
	var is_night_time := hour < 6 or hour >= 19

	# 悬挂绳
	var swing := sin(_time * 1.8) * 8.0 if not rainy else sin(_time * 4.0) * 14.0
	var rope_top := Vector2(hang_x, hang_y - 40)
	var doll_center := Vector2(hang_x + swing, hang_y + 40)
	draw_line(rope_top, doll_center, Color(0.3, 0.25, 0.2, 0.7), 1.5)

	# 娃娃身体 (白色圆头 + 布裙)
	var r := 16.0
	var body_col := Color(0.96, 0.95, 0.90)
	var body_shadow := Color(0.80, 0.78, 0.72)
	# 雨天娃娃被淋湿, 颜色稍暗 + 翻转
	if rainy:
		body_col = Color(0.85, 0.86, 0.90)
		body_shadow = Color(0.65, 0.67, 0.72)

	# 翻转处理: 雨天头朝下
	var flip_y := 1.0 if not rainy else -1.0
	var head_y := doll_center.y - r * 0.3 * flip_y
	var skirt_y := doll_center.y + r * 0.8 * flip_y

	# 裙子 (梯形布料)
	var skirt_pts := PackedVector2Array([
		Vector2(doll_center.x - r * 0.7, skirt_y - r * 0.3 * flip_y),
		Vector2(doll_center.x + r * 0.7, skirt_y - r * 0.3 * flip_y),
		Vector2(doll_center.x + r * 1.1, skirt_y + r * 0.8 * flip_y),
		Vector2(doll_center.x - r * 1.1, skirt_y + r * 0.8 * flip_y),
	])
	draw_colored_polygon(skirt_pts, body_shadow)
	# 头 (圆)
	draw_circle(Vector2(doll_center.x, head_y), r, body_col)
	# 头部高光
	draw_circle(Vector2(doll_center.x - r * 0.3, head_y - r * 0.3 * flip_y), r * 0.3,
		Color(1, 1, 1, 0.3))

	# 脸部表情
	if rainy:
		# 哭脸: X 眼 + 眼泪
		var eye_off := r * 0.35
		for sign in [-1, 1]:
			var ex: float = doll_center.x + sign * eye_off
			var ey := head_y - r * 0.05
			# X 眼
			draw_line(Vector2(ex - 2, ey - 2), Vector2(ex + 2, ey + 2), Color(0.2, 0.15, 0.15), 1.2)
			draw_line(Vector2(ex - 2, ey + 2), Vector2(ex + 2, ey - 2), Color(0.2, 0.15, 0.15), 1.2)
			# 眼泪滴
			var tear_y := ey + 4 + (sin(_time * 3.0 + sign) * 2)
			draw_circle(Vector2(ex, tear_y + 3), 1.5, Color(0.5, 0.7, 1.0, 0.8))
		# 哭嘴 (倒弧)
		draw_arc(Vector2(doll_center.x, head_y + r * 0.35 * flip_y), r * 0.2,
			deg_to_rad(200), deg_to_rad(340), 6, Color(0.2, 0.15, 0.15), 1.2)
	elif is_night_time:
		# 闭眼睡觉 (弧线)
		for sign in [-1, 1]:
			var ex: float = doll_center.x + sign * r * 0.35
			var ey := head_y - r * 0.05
			draw_arc(Vector2(ex, ey), 2.5, deg_to_rad(20), deg_to_rad(160), 6,
				Color(0.2, 0.15, 0.15), 1.2)
		# 安详小嘴
		draw_arc(Vector2(doll_center.x, head_y + r * 0.3 * flip_y), r * 0.15,
			deg_to_rad(20), deg_to_rad(160), 6, Color(0.3, 0.2, 0.2), 1.0)
	else:
		# 晴天笑脸: 弯月眼 + 微笑
		for sign in [-1, 1]:
			var ex: float = doll_center.x + sign * r * 0.35
			var ey := head_y - r * 0.05
			draw_arc(Vector2(ex, ey), 2.5, deg_to_rad(200), deg_to_rad(340), 6,
				Color(0.2, 0.15, 0.15), 1.2)
		# 微笑
		draw_arc(Vector2(doll_center.x, head_y + r * 0.2 * flip_y), r * 0.2,
			deg_to_rad(20), deg_to_rad(160), 6, Color(0.3, 0.2, 0.2), 1.2)
		# 腮红
		for sign in [-1, 1]:
			draw_circle(Vector2(doll_center.x + sign * r * 0.55, head_y + r * 0.15 * flip_y),
				r * 0.15, Color(1.0, 0.6, 0.6, 0.35))

# ============================================================
#  小风车 (晴天转得快, 阴天慢, 雨天停)
# ============================================================
func _draw_windmill(ground_y: float):
	var cx := _decor_x + 20
	var cy := ground_y - 60
	var pole_h := 80.0
	# 杆子
	draw_line(Vector2(cx, cy), Vector2(cx, cy + pole_h), Color(0.4, 0.3, 0.2), 2.5)
	# 转速根据天气
	var w := _get_weather()
	var speed := 3.0 if _is_sunny() else (1.0 if w == "overcast" or w == "fog" else 0.0)
	var angle := _time * speed
	# 4 片叶子
	var blade_len := 22.0
	var blade_col := Color(0.9, 0.4, 0.4) if _is_sunny() else Color(0.7, 0.7, 0.75)
	for i in range(4):
		var a := angle + i * PI / 2
		var tip := Vector2(cx + cos(a) * blade_len, cy + sin(a) * blade_len)
		var side := Vector2(cx + cos(a + 0.4) * blade_len * 0.6, cy + sin(a + 0.4) * blade_len * 0.6)
		var pts := PackedVector2Array([Vector2(cx, cy), tip, side])
		draw_colored_polygon(pts, blade_col if i % 2 == 0 else blade_col.lerp(Color.WHITE, 0.2))
	# 中心圆
	draw_circle(Vector2(cx, cy), 3.0, Color(0.3, 0.25, 0.2))

# ============================================================
#  晾衣绳 (晴天才有, 衣服随风摆动)
# ============================================================
func _draw_clothesline(ground_y: float):
	if not _is_sunny():
		return  # 非晴天收起
	var hour := _get_hour()
	if hour < 7 or hour >= 18:
		return  # 太早太晚不晾
	var y := ground_y - 130
	var x1 := _decor_x + 5
	var x2 := _decor_x + 90
	# 绳子 (略下垂)
	var sag := 6.0
	var mid := Vector2((x1 + x2) / 2, y + sag)
	draw_line(Vector2(x1, y), mid, Color(0.3, 0.25, 0.2, 0.6), 1.0)
	draw_line(mid, Vector2(x2, y), Color(0.3, 0.25, 0.2, 0.6), 1.0)
	# 晾晒的小衣服 (彩色, 随风摆动)
	var clothes := [
		{"x": x1 + 15, "col": Color(0.9, 0.5, 0.5)},
		{"x": x1 + 45, "col": Color(0.5, 0.7, 0.9)},
		{"x": x2 - 18, "col": Color(0.9, 0.85, 0.5)},
	]
	for c in clothes:
		var sway := sin(_time * 2.0 + c["x"] * 0.1) * 2.0
		var cw := 14.0
		var ch := 22.0
		var cxx: float = c["x"] + sway
		var cyy: float = y + 2
		# 衣服身体
		draw_rect(Rect2(cxx - cw / 2, cyy, cw, ch), c["col"], true)
		# 衣领 (三角)
		var collar := PackedVector2Array([
			Vector2(cxx - cw * 0.2, cyy),
			Vector2(cxx + cw * 0.2, cyy),
			Vector2(cxx, cyy + 4),
		])
		draw_colored_polygon(collar, c["col"].darkened(0.15))
		# 衣夹
		draw_line(Vector2(cxx, cyy - 1), Vector2(cxx, cyy + 3), Color(0.3, 0.25, 0.2), 2.0)

# ============================================================
#  小灯笼 (傍晚自动亮起)
# ============================================================
func _draw_lanterns():
	var hour := _get_hour()
	var lit := hour >= 17 or hour < 7  # 傍晚到清晨亮
	for l in lantern_positions:
		var lx: float = l["x"]
		var ly: float = l["y"]
		var hang_sway := sin(_time * 1.2 + lx * 0.05) * 3.0
		lx += hang_sway
		# 悬挂绳
		draw_line(Vector2(lx - hang_sway, ly - 25), Vector2(lx, ly - 10),
			Color(0.2, 0.18, 0.15, 0.5), 1.0)
		# 灯笼身体 (椭圆)
		var lan_col := Color(0.7, 0.2, 0.15) if not lit else Color(1.0, 0.6, 0.3)
		var glow_col := Color(1.0, 0.7, 0.35, 0.4) if lit else Color(0, 0, 0, 0)
		# 光晕
		if lit:
			for i in range(3):
				var gr := 14.0 + i * 6
				var ga := 0.3 - i * 0.08
				draw_circle(Vector2(lx, ly), gr, Color(1.0, 0.65, 0.3, ga))
		# 灯笼
		var r := 9.0
		var pts := PackedVector2Array()
		for i in range(16):
			var a := TAU * i / 16.0
			var rx := r
			var ry := r * 1.3
			if i % 2 == 1:
				rx *= 0.85  # 褶皱感
			points_append(pts, Vector2(lx + cos(a) * rx, ly + sin(a) * ry))
		draw_colored_polygon(pts, lan_col)
		# 上下盖
		draw_rect(Rect2(lx - r * 0.7, ly - r * 1.4, r * 1.4, 3), Color(0.2, 0.18, 0.15), true)
		draw_rect(Rect2(lx - r * 0.7, ly + r * 1.2, r * 1.4, 3), Color(0.2, 0.18, 0.15), true)
		# 流苏
		draw_line(Vector2(lx, ly + r * 1.5), Vector2(lx, ly + r * 1.5 + 6),
			Color(0.8, 0.7, 0.2), 1.5)

# 辅助: 追加点到数组 (避免重复代码)
func points_append(arr: PackedVector2Array, p: Vector2):
	arr.append(p)
