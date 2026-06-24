extends Node2D
# ============================================================
#  天气小人 · 主场景
#  - 背景天空(按时间渐变) / 星空 / 地平线辉光 / 月亮
#  - 子系统: 城市 / 天气特效 / 道具 / 小人 / 状态机
#  - 信息 HUD: 时间 / 城市 / 温度 / 天气 / 电量 / 信号 / 状态
#  - 触摸交互: 点击/长按/双击触发动作 + 涟漪反馈
#  - 演示模式开关 + 城市手动切换
# ============================================================

var _scale_factor: float = 1.0
var _time: float = 0.0

var _top_bg_color: Color = Color(0.1, 0.1, 0.15)
var _mid_bg_color: Color = Color(0.15, 0.15, 0.22)
var _bottom_bg_color: Color = Color(0.15, 0.15, 0.22)

var _bg_stars: Array[Dictionary] = []
var _stars_seeded: bool = false

var _cjk_font: SystemFont = null

# 触摸反馈
var _touch_particles: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []  # 涟漪圆圈

# HUD 动画
var _hud_flash: float = 0.0

# 触摸状态
var _touch_down_pos: Vector2 = Vector2.ZERO
var _touch_down_time: float = 0.0
var _is_touching: bool = false
var _last_tap_time: float = -10.0

# 演示模式
var _demo_enabled: bool = false

# 点击区域记录 (用于点击城市卡片切换)
var _city_card_rect: Rect2 = Rect2()

var cityscape_node: Node2D = null
var weather_fx_node: Node2D = null
var prop_system_node: Node2D = null
var pet_renderer_node: Node2D = null
var pet_fsm_node: Node = null

@onready var data: Node = get_node("/root/DataChannel") if has_node("/root/DataChannel") else null

func _ready():
	_init_font()
	_scale_factor = maxf(0.5, DisplayServer.screen_get_size().y / 920.0)
	_instantiate_subsystems()
	_layout_scene()
	set_process_input(true)
	if data:
		if data.has_signal("data_pushed"):
			data.data_pushed.connect(_on_data_pushed)
		# 检测是否在演示模式 (无插件)
		if "plugin_ref" in data and data.plugin_ref == null:
			_demo_enabled = true
	queue_redraw()

func _init_font():
	_cjk_font = SystemFont.new()
	_cjk_font.font_names = PackedStringArray([
		"PingFang SC", "Heiti SC", "Noto Sans CJK SC", "Source Han Sans SC",
		"Microsoft YaHei", "WenQuanYi Micro Hei", "Roboto", "sans-serif"
	])
	_cjk_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_cjk_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

func _instantiate_subsystems():
	var cs = load("res://scripts/cityscape.gd")
	if cs:
		cityscape_node = Node2D.new()
		cityscape_node.name = "Cityscape"
		cityscape_node.set_script(cs)
		cityscape_node.z_index = 1
		add_child(cityscape_node)

	var wf = load("res://scripts/weather_fx.gd")
	if wf:
		weather_fx_node = Node2D.new()
		weather_fx_node.name = "WeatherFX"
		weather_fx_node.set_script(wf)
		weather_fx_node.z_index = 4
		add_child(weather_fx_node)

	var ps = load("res://scripts/prop_system.gd")
	if ps:
		prop_system_node = Node2D.new()
		prop_system_node.name = "PropSystem"
		prop_system_node.set_script(ps)
		prop_system_node.z_index = 5
		add_child(prop_system_node)

	var pr = load("res://scripts/pet_renderer.gd")
	if pr:
		pet_renderer_node = Node2D.new()
		pet_renderer_node.name = "PetRenderer"
		pet_renderer_node.set_script(pr)
		pet_renderer_node.z_index = 3
		add_child(pet_renderer_node)

	var fsm = load("res://scripts/pet_fsm.gd")
	if fsm:
		pet_fsm_node = Node.new()
		pet_fsm_node.name = "PetFSM"
		pet_fsm_node.set_script(fsm)
		add_child(pet_fsm_node)

func _process(delta: float):
	if Engine.is_editor_hint():
		return
	_time += delta
	_update_background()
	_update_scale()
	_layout_scene()
	_update_touch_anim(delta)
	if _hud_flash > 0.0:
		_hud_flash = maxf(0.0, _hud_flash - delta * 1.6)
	queue_redraw()

func _draw():
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_draw_gradient_sky(viewport_size)

	var hour: int = data.current_hour if data and "current_hour" in data else 12
	if hour < 6 or hour >= 19:
		_draw_bg_stars(viewport_size)

	_draw_horizon_glow(viewport_size)

	# 涟漪 (画在小人之上, HUD 之下)
	_draw_ripples()
	# 触摸粒子
	_draw_touch_particles()
	# HUD 最上层
	_draw_hud(viewport_size)

# ============================================================
#  背景
# ============================================================
func _draw_gradient_sky(viewport_size: Vector2):
	var strips := 20
	for i in range(strips):
		var t := float(i) / float(strips)
		var y := viewport_size.y * t
		var h := viewport_size.y / float(strips) + 1.0
		draw_rect(Rect2(Vector2(0, y), Vector2(viewport_size.x, h)), _get_sky_color_at(t), true)

func _get_sky_color_at(t: float) -> Color:
	var hour: int = data.current_hour if data and "current_hour" in data else 12
	var is_night: bool = hour < 6 or hour >= 19
	var is_dusk: bool = hour >= 17 and hour < 19
	var is_dawn: bool = hour >= 5 and hour < 7

	if is_night:
		var top := Color(0.04, 0.04, 0.12)
		var mid := Color(0.06, 0.06, 0.16)
		var bot := Color(0.08, 0.08, 0.18)
		return top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(bot, (t - 0.5) * 2.0)
	elif is_dawn:
		var top := Color(0.25, 0.35, 0.6)
		var mid := Color(0.55, 0.45, 0.5)
		var bot := Color(0.85, 0.55, 0.35)
		return top.lerp(mid, t / 0.4) if t < 0.4 else mid.lerp(bot, (t - 0.4) / 0.6)
	elif is_dusk:
		var top := Color(0.15, 0.15, 0.35)
		var mid := Color(0.4, 0.25, 0.35)
		var bot := Color(0.8, 0.4, 0.2)
		return top.lerp(mid, t / 0.4) if t < 0.4 else mid.lerp(bot, (t - 0.4) / 0.6)
	else:
		var top := Color(0.35, 0.5, 0.75)
		var mid := Color(0.5, 0.65, 0.85)
		var bot := Color(0.65, 0.78, 0.9)
		return top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(bot, (t - 0.5) * 2.0)

func _draw_bg_stars(viewport_size: Vector2):
	if not _stars_seeded:
		_seed_bg_stars(viewport_size)
		_stars_seeded = true
	for s in _bg_stars:
		var bright: float = (sin(_time * 1.5 + s["phase"]) + 1.0) * 0.5
		var sz: float = s["size"]
		draw_circle(s["pos"], sz * 2.0, Color(0.8, 0.85, 1.0, bright * 0.08))
		draw_circle(s["pos"], sz, Color(1, 1, 0.9, bright * 0.7))
		if sz > 1.8 and bright > 0.6:
			var len := sz * 2.0
			draw_line(s["pos"] + Vector2(-len, 0), s["pos"] + Vector2(len, 0), Color(1, 1, 0.9, bright * 0.2), 0.6)
			draw_line(s["pos"] + Vector2(0, -len), s["pos"] + Vector2(0, len), Color(1, 1, 0.9, bright * 0.2), 0.6)

func _seed_bg_stars(viewport_size: Vector2):
	_bg_stars.clear()
	for i in range(40):
		_bg_stars.append({
			"pos": Vector2(randf_range(0, viewport_size.x), randf_range(0, viewport_size.y * 0.55)),
			"size": randf_range(0.5, 2.5),
			"phase": randf_range(0.0, TAU)
		})

func _draw_horizon_glow(viewport_size: Vector2):
	var hour: int = data.current_hour if data and "current_hour" in data else 12
	var is_night: bool = hour < 6 or hour >= 19
	var is_dusk: bool = hour >= 17 and hour < 19
	var is_dawn: bool = hour >= 5 and hour < 7

	if is_dusk or is_dawn:
		var glow_col := Color(0.9, 0.5, 0.2, 0.15) if is_dusk else Color(0.9, 0.6, 0.3, 0.12)
		var horizon_y := viewport_size.y * 0.65
		for i in range(5):
			var r := 200.0 + i * 60.0
			var a := glow_col.a * (1.0 - float(i) / 5.0)
			draw_ellipse(Vector2(viewport_size.x * 0.5, horizon_y), Vector2(r, r * 0.3), Color(glow_col.r, glow_col.g, glow_col.b, a))
	elif is_night:
		var moon_x := viewport_size.x * 0.75
		var moon_y := viewport_size.y * 0.12
		draw_circle(Vector2(moon_x, moon_y), 18.0, Color(0.95, 0.93, 0.85, 0.9))
		draw_circle(Vector2(moon_x + 4, moon_y - 2), 16.0, Color(0.06, 0.06, 0.16, 0.95))
		for i in range(4):
			var r := 30.0 + i * 20.0
			var a := 0.06 - i * 0.012
			draw_circle(Vector2(moon_x, moon_y), r, Color(0.8, 0.85, 1.0, a))

func _update_background():
	if not data:
		return
	var hour: int = data.current_hour
	var is_night: bool = hour < 6 or hour >= 19
	if is_night:
		_top_bg_color = Color(0.04, 0.04, 0.12)
		_mid_bg_color = Color(0.06, 0.06, 0.16)
		_bottom_bg_color = Color(0.08, 0.08, 0.18)
	else:
		_top_bg_color = Color(0.35, 0.5, 0.75)
		_mid_bg_color = Color(0.5, 0.65, 0.85)
		_bottom_bg_color = Color(0.65, 0.78, 0.9)

func _update_scale():
	var new_s = maxf(0.5, DisplayServer.screen_get_size().y / 920.0)
	if absf(new_s - _scale_factor) > 0.01:
		_scale_factor = new_s
		_stars_seeded = false

func _layout_scene():
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	if cityscape_node:
		cityscape_node.position = Vector2.ZERO

	if weather_fx_node:
		weather_fx_node.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.15)

	if pet_renderer_node:
		var pet_base := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.58)
		if pet_renderer_node.has_method("set_base_position"):
			pet_renderer_node.call("set_base_position", pet_base)
		else:
			pet_renderer_node.position = pet_base
		pet_renderer_node.scale = Vector2.ONE * maxf(1.6, viewport_size.y / 900.0)

	if prop_system_node:
		prop_system_node.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.58)

# ============================================================
#  信息 HUD (苹果风格: 顶部居中天气 + 底部毛玻璃状态栏)
# ============================================================
func _draw_hud(viewport_size: Vector2):
	if not data:
		return
	var s := _scale_factor
	var vp_w := viewport_size.x
	var vp_h := viewport_size.y

	var hour: int = data.current_hour
	var minute: int = data.current_minute
	var time_str := "%02d:%02d" % [hour, minute]
	var period := _time_period_label(hour)
	var city := String(data.city_name) if "city_name" in data else ""

	var w: Dictionary = data.current_weather if typeof(data.current_weather) == TYPE_DICTIONARY else {}
	var cond := String(w.get("condition", "clear"))
	var temp := float(w.get("temperature", 22.0))
	var hum := float(w.get("humidity", 50.0))
	var feels := float(w.get("feels_like", temp))
	var cond_label := _weather_label(cond)
	var cond_icon := _weather_icon(cond)

	var batt: int = data.battery_percent if "battery_percent" in data else 85
	var chg: bool = data.is_charging if "is_charging" in data else false
	var sig: int = data.phone_signal if "phone_signal" in data else 4

	# ==================== 顶部: 时间 + 城市 (简约居中) ====================
	# 苹果风格: 大号时间居中, 城市在下方小字
	var cx := vp_w * 0.5
	var top_y := 48.0 * s

	# 时间 (超大, 苹果 SF 风格)
	var time_size := 56 * s
	draw_string(_cjk_font, Vector2(cx, top_y + time_size * 0.75), time_str,
		HORIZONTAL_ALIGNMENT_CENTER, vp_w, time_size, Color(1, 1, 1, 0.95))
	if _hud_flash > 0.0:
		draw_string(_cjk_font, Vector2(cx, top_y + time_size * 0.75), time_str,
			HORIZONTAL_ALIGNMENT_CENTER, vp_w, time_size,
			Color(1.0, 0.95, 0.5, _hud_flash * 0.6))

	# 城市 + 时段 (小字, 可点击切换)
	var loc_mode: String = data.location_mode if "location_mode" in data else "gps"
	var city_text := city + " · " + period
	var city_size := 17 * s
	var city_y := top_y + time_size + 8 * s
	draw_string(_cjk_font, Vector2(cx, city_y + city_size * 0.75), city_text,
		HORIZONTAL_ALIGNMENT_CENTER, vp_w, city_size, Color(1, 1, 1, 0.65))
	# 记录城市点击区 (整行宽, 易点)
	_city_card_rect = Rect2(vp_w * 0.2, city_y - city_size * 0.3,
		vp_w * 0.6, city_size * 1.3)
	# 切换提示小箭头 (悬于城市右侧, 演示模式闪烁)
	var arrow_a := (0.4 + sin(_time * 2.5) * 0.2) if _demo_enabled else 0.3
	var city_w := _cjk_font.get_string_size(city_text, HORIZONTAL_ALIGNMENT_CENTER, vp_w, city_size).x
	draw_string(_cjk_font, Vector2(cx + city_w * 0.5 + 8 * s, city_y + city_size * 0.75), "⇄",
		HORIZONTAL_ALIGNMENT_LEFT, -1, city_size, Color(1.0, 0.85, 0.3, arrow_a))

	# ==================== 中部偏上: 天气信息 (大温度居中) ====================
	# 苹果天气 App 风格: 巨大温度数字 + 天气描述
	var weather_y := vp_h * 0.28
	var temp_size := 96 * s
	draw_string(_cjk_font, Vector2(cx, weather_y + temp_size * 0.7),
		"%.0f°" % temp, HORIZONTAL_ALIGNMENT_CENTER, vp_w, temp_size,
		Color(1, 1, 1, 0.92))
	# 天气描述 (图标 + 文字)
	var cond_text := cond_icon + " " + cond_label
	var cond_size := 20 * s
	draw_string(_cjk_font, Vector2(cx, weather_y + temp_size + cond_size),
		cond_text, HORIZONTAL_ALIGNMENT_CENTER, vp_w, cond_size, Color(1, 1, 1, 0.75))
	# 体感温度 + 湿度 (小字)
	var detail := "体感 %.0f°  ·  湿度 %.0f%%" % [feels, hum]
	draw_string(_cjk_font, Vector2(cx, weather_y + temp_size + cond_size + 22 * s),
		detail, HORIZONTAL_ALIGNMENT_CENTER, vp_w, 14 * s, Color(1, 1, 1, 0.5))

	# ==================== 底部: 毛玻璃状态胶囊 (苹果 Control Center 风) ====================
	var pill_h := 52.0 * s
	var pill_w := minf(vp_w - 36 * s, 360 * s)
	var pill_x := (vp_w - pill_w) * 0.5
	var pill_y := vp_h - 36 * s - pill_h
	var pill_rect := Rect2(pill_x, pill_y, pill_w, pill_h)
	_draw_glass_pill(pill_rect)

	# 状态胶囊内容: 电量 | 信号 | 小人状态 (均分三栏)
	var seg_w := pill_w / 3.0

	# 栏1: 电量
	var s1x := pill_x + seg_w * 0.5
	_draw_battery_icon(Vector2(s1x - 30 * s, pill_y + pill_h * 0.5 - 7 * s), batt, chg, s)
	draw_string(_cjk_font, Vector2(s1x + 6 * s, pill_y + pill_h * 0.5 + 6 * s),
		"%d%%" % batt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15 * s, Color(1, 1, 1, 0.9))

	# 栏1/2 分隔点
	draw_circle(Vector2(pill_x + seg_w, pill_y + pill_h * 0.5), 1.5 * s, Color(1, 1, 1, 0.25))

	# 栏2: 信号
	var s2x := pill_x + seg_w * 1.5
	_draw_signal_icon(Vector2(s2x - 20 * s, pill_y + pill_h * 0.5), sig, s)
	draw_string(_cjk_font, Vector2(s2x + 4 * s, pill_y + pill_h * 0.5 + 6 * s),
		"%dG" % [4 if sig >= 3 else 3], HORIZONTAL_ALIGNMENT_LEFT, -1, 15 * s, Color(1, 1, 1, 0.9))

	# 栏2/3 分隔点
	draw_circle(Vector2(pill_x + seg_w * 2, pill_y + pill_h * 0.5), 1.5 * s, Color(1, 1, 1, 0.25))

	# 栏3: 小人状态
	var state_label := ""
	if pet_fsm_node and pet_fsm_node.has_method("state_label"):
		state_label = pet_fsm_node.state_label()
	if state_label == "":
		state_label = "😌 发呆"
	var s3x := pill_x + seg_w * 2.5
	# 呼吸点
	var dot_pulse := (sin(_time * 2.5) + 1.0) * 0.5
	draw_circle(Vector2(s3x - _cjk_font.get_string_size(state_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15 * s).x * 0.5 - 8 * s, pill_y + pill_h * 0.5),
		4 * s, Color(0.4, 0.9, 0.6, 0.5 + dot_pulse * 0.4))
	draw_string(_cjk_font, Vector2(s3x, pill_y + pill_h * 0.5 + 6 * s),
		state_label, HORIZONTAL_ALIGNMENT_CENTER, seg_w - 10 * s, 15 * s, Color(1, 1, 1, 0.9))

	# ==================== 演示模式标记 (右上角小角标) ====================
	if _demo_enabled:
		var tag := "演示"
		var tag_size := 12 * s
		var tag_w := _cjk_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
		var tag_rect := Rect2(vp_w - tag_w - 28 * s, 24 * s, tag_w + 16 * s, tag_size + 10 * s)
		_draw_glass_pill(tag_rect, 0.85)
		var pulse := 0.6 + sin(_time * 3.0) * 0.3
		draw_string(_cjk_font, Vector2(tag_rect.position.x + 8 * s, tag_rect.position.y + tag_size + 5 * s), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color(1.0, 0.82, 0.35, pulse))

	# ==================== 操作提示 (首次启动几秒) ====================
	if _time < 6.0:
		var hint_a := clampf((6.0 - _time) / 2.0, 0.0, 1.0)
		var hint := "点城市切换  ·  长按城市GPS定位  ·  点小人互动"
		var hint_size := 14 * s
		var hint_w := _cjk_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, hint_size).x
		var hx := (vp_w - hint_w) * 0.5
		var hy := pill_y - 22 * s
		var cap := Rect2(hx - 14 * s, hy - hint_size, hint_w + 28 * s, hint_size + 12 * s)
		_draw_glass_pill(cap, hint_a * 0.9)
		draw_string(_cjk_font, Vector2(hx, hy), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(1, 1, 1, hint_a * 0.9))

func _draw_glass_card(rect: Rect2, alpha: float = 1.0):
	draw_round_rect(rect, Color(0.05, 0.08, 0.15, 0.5 * alpha), 16.0)
	var top_strip := Rect2(rect.position + Vector2(0, 1), Vector2(rect.size.x, rect.size.y * 0.5))
	draw_round_rect(top_strip, Color(1, 1, 1, 0.06 * alpha), 16.0)
	_draw_round_rect_border(rect, Color(1, 1, 1, 0.2 * alpha), 16.0, 1.5)

# 苹果风格毛玻璃胶囊 (更柔和: 大圆角 + 轻背景 + 内发光)
func _draw_glass_pill(rect: Rect2, alpha: float = 1.0):
	var r := rect.size.y * 0.5  # 完全圆角 (胶囊形)
	# 主体: 极淡的玻璃感
	draw_round_rect(rect, Color(1, 1, 1, 0.12 * alpha), r)
	# 内层高光 (顶部)
	var top_strip := Rect2(rect.position + Vector2(0, 0.5), Vector2(rect.size.x, rect.size.y * 0.45))
	draw_round_rect(top_strip, Color(1, 1, 1, 0.08 * alpha), r)
	# 细边框
	_draw_round_rect_border(rect, Color(1, 1, 1, 0.18 * alpha), r, 1.0)

func _draw_battery_icon(pos: Vector2, percent: int, charging: bool, s: float):
	var bw := 32.0 * s
	var bh := 16.0 * s
	var col := Color(0.3, 0.85, 0.4) if percent > 40 else (Color(1.0, 0.8, 0.2) if percent > 15 else Color(0.95, 0.3, 0.3))
	if charging:
		col = Color(0.4, 0.9, 1.0)
	draw_round_rect(Rect2(pos, Vector2(bw, bh)), Color(1, 1, 1, 0.85), 3.0 * s)
	draw_rect(Rect2(pos + Vector2(bw, bh * 0.3), Vector2(3 * s, bh * 0.4)), Color(1, 1, 1, 0.85), true)
	var fill_w := (bw - 4 * s) * clampf(float(percent) / 100.0, 0.0, 1.0)
	if fill_w > 0.5:
		draw_round_rect(Rect2(pos + Vector2(2 * s, 2 * s), Vector2(fill_w, bh - 4 * s)), col, 2.0 * s)

func _draw_signal_icon(pos: Vector2, strength: int, s: float):
	for i in range(4):
		var active := i < strength
		var bar_h := (6 + i * 5) * s
		var bx := pos.x + i * 7 * s
		var by := pos.y - (3 - i) * 5.0 * s
		var col := Color(1, 1, 1, 0.9) if active else Color(1, 1, 1, 0.25)
		draw_rect(Rect2(Vector2(bx, by - bar_h), Vector2(5 * s, bar_h)), col, true)

func _draw_round_rect_border(rect: Rect2, color: Color, radius: float, width: float):
	draw_arc(rect.position + Vector2(radius, radius), radius, deg_to_rad(180), deg_to_rad(270), 10, color, width)
	draw_arc(Vector2(rect.end.x - radius, rect.position.y + radius), radius, deg_to_rad(270), deg_to_rad(360), 10, color, width)
	draw_arc(Vector2(rect.position.x + radius, rect.end.y - radius), radius, deg_to_rad(90), deg_to_rad(180), 10, color, width)
	draw_arc(rect.end - Vector2(radius, radius), radius, deg_to_rad(0), deg_to_rad(90), 10, color, width)
	draw_line(Vector2(rect.position.x + radius, rect.position.y), Vector2(rect.end.x - radius, rect.position.y), color, width)
	draw_line(Vector2(rect.position.x + radius, rect.end.y), Vector2(rect.end.x - radius, rect.end.y), color, width)
	draw_line(Vector2(rect.position.x, rect.position.y + radius), Vector2(rect.position.x, rect.end.y - radius), color, width)
	draw_line(Vector2(rect.end.x, rect.position.y + radius), Vector2(rect.end.x, rect.end.y - radius), color, width)

# ============================================================
#  触摸交互 + 反馈
# ============================================================
func _input(event: InputEvent):
	# 同时支持屏幕触摸和鼠标
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:
			_on_press(event.position)
		elif not event.pressed:
			_on_release(event.position)

func _on_press(pos: Vector2):
	_touch_down_pos = pos
	_touch_down_time = _time
	_is_touching = true

func _on_release(pos: Vector2):
	if not _is_touching:
		return
	_is_touching = false
	var dt := _time - _touch_down_time
	var moved := pos.distance_to(_touch_down_pos)
	# 滑动判定
	if moved > 50.0 * _scale_factor:
		return

	# 优先: 点击城市卡片 → 切换城市
	# 优先: 点击/长按城市卡片
	if _city_card_rect.has_point(pos):
		if dt >= 0.55:
			# 长按城市卡片 → 切回 GPS 实时定位
			_switch_to_gps()
		else:
			# 点击城市卡片 → 切换到下一个预设城市 (自定义位置)
			_switch_city()
		_spawn_ripple(pos, Color(1.0, 0.85, 0.3))
		return

	# 否则: 小人互动
	if dt >= 0.55:
		_trigger_touch("longpress", pos)
	elif _time - _last_tap_time < 0.32:
		_trigger_touch("double", pos)
		_last_tap_time = -10.0
	else:
		_trigger_touch("tap", pos)
		_last_tap_time = _time

func _switch_city():
	# 切换到下一个预设城市 (PC 演示 + 真机自定义位置 统一走 data_channel)
	if data and data.has_method("switch_to_next_city"):
		data.switch_to_next_city()
	_hud_flash = 0.8

func _switch_to_gps():
	# 切回 GPS 实时定位 (真机有效; PC 演示无 GPS 则保持 demo)
	if data and data.has_method("switch_to_gps"):
		data.switch_to_gps()
	_hud_flash = 0.8

func _trigger_touch(type: String, pos: Vector2):
	if pet_fsm_node and pet_fsm_node.has_method("on_touch"):
		pet_fsm_node.call("on_touch", type)
	if data and data.has_method("feed_touch"):
		data.feed_touch(type, pos.x, pos.y)
	# 涟漪反馈 (任何点击都有, 让用户确认交互生效)
	var rip_col := Color(1.0, 0.6, 0.7)  # 粉
	match type:
		"longpress":
			rip_col = Color(1.0, 0.8, 0.3)
		"double":
			rip_col = Color(0.6, 0.9, 1.0)
	_spawn_ripple(pos, rip_col)
	_spawn_touch_particles(pos, type)

func _spawn_ripple(pos: Vector2, color: Color):
	_ripples.append({
		"pos": pos,
		"r": 8.0 * _scale_factor,
		"max_r": 70.0 * _scale_factor,
		"life": 0.6,
		"max_life": 0.6,
		"col": color
	})

func _spawn_touch_particles(pos: Vector2, type: String):
	var symbols: Array[String] = ["❤", "✦", "✧", "★"]
	var count := 6
	var base_col := Color(1.0, 0.6, 0.7)
	match type:
		"longpress":
			symbols = ["!", "?", "💤"]
			count = 8
			base_col = Color(1.0, 0.8, 0.3)
		"double":
			symbols = ["✦", "✧", "★", "◆"]
			count = 10
			base_col = Color(0.6, 0.9, 1.0)
	for i in range(count):
		var ang := randf_range(0, TAU)
		var spd := randf_range(60, 140) * _scale_factor
		_touch_particles.append({
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": randf_range(0.7, 1.1),
			"max_life": 1.0,
			"sym": symbols[i % symbols.size()],
			"col": base_col,
			"rot": randf_range(0, TAU),
			"rot_vel": randf_range(-4, 4),
			"size": randf_range(14, 22) * _scale_factor
		})

func _update_touch_anim(delta: float):
	# 涟漪扩散
	var alive_rip: Array[Dictionary] = []
	for r in _ripples:
		r["life"] -= delta
		if r["life"] <= 0.0:
			continue
		var t: float = 1.0 - float(r["life"]) / float(r["max_life"])
		r["r"] = lerpf(8.0 * _scale_factor, r["max_r"], t)
		alive_rip.append(r)
	_ripples = alive_rip

	# 粒子
	var alive: Array[Dictionary] = []
	for p in _touch_particles:
		p["life"] -= delta
		if p["life"] <= 0.0:
			continue
		p["pos"] += p["vel"] * delta
		p["vel"] *= (1.0 - delta * 1.8)
		p["vel"].y += 240.0 * delta * _scale_factor
		p["rot"] += p["rot_vel"] * delta
		alive.append(p)
	_touch_particles = alive

func _draw_ripples():
	for r in _ripples:
		var a: float = clampf(r["life"] / r["max_life"], 0.0, 1.0)
		var col: Color = r["col"]
		# 涟漪圈
		draw_arc(r["pos"], r["r"], 0, TAU, 32,
			Color(col.r, col.g, col.b, a * 0.8), 3.0 * _scale_factor)
		# 中心点
		draw_circle(r["pos"], 4.0 * _scale_factor * a,
			Color(col.r, col.g, col.b, a))

func _draw_touch_particles():
	for p in _touch_particles:
		var a: float = clampf(p["life"] / 1.0, 0.0, 1.0)
		var col: Color = p["col"]
		var c := Color(col.r, col.g, col.b, a)
		draw_set_transform(p["pos"], p["rot"], Vector2.ONE)
		draw_string(_cjk_font, Vector2(-p["size"] * 0.4, p["size"] * 0.4), p["sym"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, p["size"], c)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# ============================================================
#  文案
# ============================================================
func _time_period_label(hour: int) -> String:
	if hour < 6: return "凌晨"
	elif hour < 11: return "上午"
	elif hour < 13: return "中午"
	elif hour < 18: return "下午"
	elif hour < 22: return "傍晚"
	else: return "深夜"

func _weather_label(cond: String) -> String:
	var m := {
		"clear": "晴朗", "cloudy": "多云", "overcast": "阴天",
		"rain": "下雨", "drizzle": "小雨", "heavy_rain": "大雨", "thunderstorm": "雷阵雨",
		"snow": "下雪", "heavy_snow": "大雪", "fog": "雾", "haze": "霾",
		"sandstorm": "沙尘暴", "windy": "大风"
	}
	return m.get(cond, "晴朗")

func _weather_icon(cond: String) -> String:
	var m := {
		"clear": "☀️", "cloudy": "⛅", "overcast": "☁️",
		"rain": "🌧", "drizzle": "🌦", "heavy_rain": "🌧", "thunderstorm": "⛈",
		"snow": "❄️", "heavy_snow": "🌨", "fog": "🌫", "haze": "🌫",
		"sandstorm": "🌪", "windy": "💨"
	}
	return m.get(cond, "☀️")

func _on_data_pushed():
	_hud_flash = 0.8

# ============================================================
#  绘制工具
# ============================================================
func draw_round_rect(rect: Rect2, color: Color, radius: float):
	var inner := Rect2(rect.position + Vector2(radius, 0), Vector2(rect.size.x - radius * 2.0, rect.size.y))
	draw_rect(inner, color, true)
	draw_rect(Rect2(rect.position + Vector2(0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color, true)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(rect.end - Vector2(radius, radius), radius, color)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color):
	var points := PackedVector2Array()
	var steps := 32
	for s_i in range(steps):
		var angle := TAU * float(s_i) / float(steps)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
