extends Node2D
# ============================================================
#  天气小人 · 主场景
#  - 背景天空(按时间渐变) / 星空 / 地平线辉光 / 月亮
#  - 子系统: 城市 / 天气特效 / 道具 / 小人 / 状态机
#  - 信息 HUD: 时间 / 城市 / 温度 / 天气 / 电量 / 信号 / 状态
#  - 触摸交互: 点击/长按/双击触发动作 + 涟漪反馈
#  - 演示模式开关 + 城市手动切换
# ============================================================

const DW := 1280.0
const DH := 720.0
const DS := 0.78

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

# 点击区域记录
var _city_card_rect: Rect2 = Rect2()
var _demo_btn_rect: Rect2 = Rect2()

# 设置面板
var _settings_open: bool = false
var _settings_rect: Rect2 = Rect2()
var _settings_tab: int = 0  # 0=城市 1=小人 2=关于

var cityscape_node: Node2D = null
var weather_fx_node: Node2D = null
var prop_system_node: Node2D = null
var pet_renderer_node: Node2D = null
var pet_fsm_node: Node = null

@onready var data: Node = get_node("/root/DataChannel") if has_node("/root/DataChannel") else null

func _ready():
	_init_font()
	_instantiate_subsystems()
	_layout_scene_once()
	set_process_input(true)
	if data:
		if data.has_signal("data_pushed"):
			data.data_pushed.connect(_on_data_pushed)
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
	_update_touch_anim(delta)
	if _hud_flash > 0.0:
		_hud_flash = maxf(0.0, _hud_flash - delta * 1.6)
	queue_redraw()

func _draw():
	var viewport_size := Vector2(DW, DH)
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
	# 右上角设置按钮
	_draw_settings_button(viewport_size)
	# 设置面板 (打开时)
	if _settings_open:
		_draw_settings_panel(viewport_size)

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
			_draw_ellipse_shape(Vector2(viewport_size.x * 0.5, horizon_y), Vector2(r, r * 0.3), Color(glow_col.r, glow_col.g, glow_col.b, a))
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

func _layout_scene_once():
	if cityscape_node:
		cityscape_node.position = Vector2.ZERO
	if weather_fx_node:
		weather_fx_node.position = Vector2(640, 108)
	if pet_renderer_node:
		var pet_base := Vector2(640, 416)
		if pet_renderer_node.has_method("set_base_position"):
			pet_renderer_node.call("set_base_position", pet_base)
		else:
			pet_renderer_node.position = pet_base
		pet_renderer_node.scale = Vector2.ONE * 0.8
	if prop_system_node:
		prop_system_node.position = Vector2(640, 416)

# ============================================================
#  信息 HUD (苹果风格: 顶部居中天气 + 底部毛玻璃状态栏)
# ============================================================
func _draw_hud(viewport_size: Vector2):
	if not data:
		return
	var s := DS
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

	# ==================== 顶部: 左=时间+城市  右=温度+天气 ====================
	var top_y := 30.0 * s
	var margin := 24.0 * s

	# --- 左侧: 时间 + 城市 ---
	var time_size := 48 * s
	draw_string(_cjk_font, Vector2(margin, top_y + time_size * 0.8), time_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, time_size, Color(1, 1, 1, 0.95))
	if _hud_flash > 0.0:
		draw_string(_cjk_font, Vector2(margin, top_y + time_size * 0.8), time_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, time_size,
			Color(1.0, 0.95, 0.5, _hud_flash * 0.6))

	var loc_mode: String = data.location_mode if "location_mode" in data else "gps"
	var city_text := city + " · " + period
	var city_size := 14 * s
	var city_y := top_y + time_size + 4 * s
	draw_string(_cjk_font, Vector2(margin, city_y + city_size * 0.75), city_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, city_size, Color(1, 1, 1, 0.6))
	_city_card_rect = Rect2(margin - 8 * s, city_y - city_size * 0.3,
		160 * s, city_size * 1.6)

	# --- 右侧: 温度 + 天气描述 ---
	var temp_str := "%.0f°" % temp
	var temp_size := 52 * s
	var temp_w := _cjk_font.get_string_size(temp_str, HORIZONTAL_ALIGNMENT_LEFT, -1, temp_size).x
	draw_string(_cjk_font, Vector2(vp_w - margin - temp_w, top_y + temp_size * 0.8), temp_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, temp_size, Color(1, 1, 1, 0.95))

	var cond_text := cond_icon + " " + cond_label
	var cond_size := 14 * s
	var cond_y := top_y + temp_size + 4 * s
	var cond_w := _cjk_font.get_string_size(cond_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cond_size).x
	draw_string(_cjk_font, Vector2(vp_w - margin - cond_w, cond_y + cond_size * 0.75), cond_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, cond_size, Color(1, 1, 1, 0.6))

	# --- 中间: 体感 + 湿度 (小字, 居中) ---
	var detail := "体感%.0f° 湿度%.0f%%" % [feels, hum]
	var detail_y := top_y + time_size + city_size + 10 * s
	draw_string(_cjk_font, Vector2(0, detail_y + 10 * s), detail,
		HORIZONTAL_ALIGNMENT_CENTER, vp_w, 11 * s, Color(1, 1, 1, 0.4))

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

	# ==================== 演示模式切换按钮 (左上角) ====================
	var demo_label := "🎮 演示" if _demo_enabled else "🎮 真机"
	var demo_size := 12 * s
	var demo_w := _cjk_font.get_string_size(demo_label, HORIZONTAL_ALIGNMENT_LEFT, -1, demo_size).x
	_demo_btn_rect = Rect2(margin - 4 * s, 14 * s, demo_w + 12 * s, demo_size + 8 * s)
	var demo_col := Color(1.0, 0.82, 0.35, 0.8) if _demo_enabled else Color(0.6, 0.8, 1.0, 0.5)
	_draw_glass_pill(_demo_btn_rect, 0.7)
	draw_string(_cjk_font, Vector2(margin, 14 * s + demo_size + 2 * s), demo_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, demo_size, demo_col)

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
	if moved > 50.0 * DS:
		return

	# 设置面板已打开: 处理面板内点击
	if _settings_open:
		_handle_settings_tap(pos)
		_spawn_ripple(pos, Color(0.6, 0.9, 1.0))
		return

	var vp := Vector2(DW, DH)
	# 右上角长按 → 打开设置面板
	var settings_btn := Rect2(vp.x - 60 * DS, 20 * DS, 44 * DS, 44 * DS)
	if settings_btn.has_point(pos) and dt >= 0.5:
		_settings_open = !_settings_open
		_spawn_ripple(pos, Color(0.6, 0.9, 1.0))
		return

	# 优先: 演示模式切换按钮
	if _demo_btn_rect.has_point(pos):
		_toggle_demo_mode()
		_spawn_ripple(pos, Color(0.6, 0.9, 1.0))
		return

	# 优先: 点击/长按城市卡片
	if _city_card_rect.has_point(pos):
		if dt >= 0.55:
			_switch_to_gps()
		else:
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

func _toggle_demo_mode():
	_demo_enabled = !_demo_enabled
	if data:
		data._demo_mode = _demo_enabled
		if _demo_enabled:
			data.location_mode = "demo"
		else:
			data.location_mode = "gps"
	_hud_flash = 0.8

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
		"r": 8.0 * DS,
		"max_r": 70.0 * DS,
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
		var spd := randf_range(60, 140) * DS
		_touch_particles.append({
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": randf_range(0.7, 1.1),
			"max_life": 1.0,
			"sym": symbols[i % symbols.size()],
			"col": base_col,
			"rot": randf_range(0, TAU),
			"rot_vel": randf_range(-4, 4),
			"size": randf_range(14, 22) * DS
		})

func _update_touch_anim(delta: float):
	# 涟漪扩散
	var alive_rip: Array[Dictionary] = []
	for r in _ripples:
		r["life"] -= delta
		if r["life"] <= 0.0:
			continue
		var t: float = 1.0 - float(r["life"]) / float(r["max_life"])
		r["r"] = lerpf(8.0 * DS, r["max_r"], t)
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
		p["vel"].y += 240.0 * delta * DS
		p["rot"] += p["rot_vel"] * delta
		alive.append(p)
	_touch_particles = alive

func _draw_ripples():
	for r in _ripples:
		var a: float = clampf(r["life"] / r["max_life"], 0.0, 1.0)
		var col: Color = r["col"]
		# 涟漪圈
		draw_arc(r["pos"], r["r"], 0, TAU, 32,
			Color(col.r, col.g, col.b, a * 0.8), 3.0 * DS)
		# 中心点
		draw_circle(r["pos"], 4.0 * DS * a,
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

func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color):
	var points := PackedVector2Array()
	var steps := 32
	for s_i in range(steps):
		var angle := TAU * float(s_i) / float(steps)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

# ============================================================
#  设置面板 (右上角 ⚙ 长按打开)
# ============================================================

# 右上角设置按钮 (齿轮图标)
func _draw_settings_button(viewport_size: Vector2):
	var s := DS
	var bx := viewport_size.x - 52 * s
	var by := 26 * s
	var r := 18 * s
	# 圆形背景
	draw_circle(Vector2(bx, by), r, Color(1, 1, 1, 0.15))
	# 齿轮 (简化: 中心圆 + 8个小点)
	draw_circle(Vector2(bx, by), r * 0.35, Color(1, 1, 1, 0.9))
	for i in range(8):
		var a := i * PI / 4
		var px := bx + cos(a) * r * 0.65
		var py := by + sin(a) * r * 0.65
		draw_circle(Vector2(px, py), r * 0.12, Color(1, 1, 1, 0.7))

# 设置面板 (居中半透明卡片)
func _draw_settings_panel(viewport_size: Vector2):
	var s := DS
	var pw := minf(viewport_size.x - 40 * s, 340 * s)
	var ph := minf(viewport_size.y - 100 * s, 480 * s)
	var px := (viewport_size.x - pw) * 0.5
	var py := (viewport_size.y - ph) * 0.5
	_settings_rect = Rect2(px, py, pw, ph)

	# 半透明遮罩
	draw_rect(Rect2(0, 0, viewport_size.x, viewport_size.y), Color(0, 0, 0, 0.4), true)
	# 面板卡片
	draw_round_rect(_settings_rect, Color(0.08, 0.1, 0.16, 0.95), 20 * s)
	_draw_round_rect_border(_settings_rect, Color(1, 1, 1, 0.15), 20 * s, 1.0)

	var cx := px + pw * 0.5
	var cur_y := py + 20 * s

	# 标题
	draw_string(_cjk_font, Vector2(px, cur_y + 24 * s), "⚙ 设置",
		HORIZONTAL_ALIGNMENT_CENTER, pw, 22 * s, Color.WHITE)
	cur_y += 40 * s

	# Tab 栏 (城市 | 小人 | 关于)
	var tab_w := pw / 3.0
	var tab_names: Array[String] = ["🏙 城市", "🤖 小人", "ℹ 关于"]
	for i in range(3):
		var tab_name: String = tab_names[i]
		var tx := px + tab_w * i
		var active := (i == _settings_tab)
		var tab_col := Color(0.2, 0.6, 1.0, 0.3) if active else Color(1, 1, 1, 0.08)
		draw_rect(Rect2(tx + 4 * s, cur_y, tab_w - 8 * s, 32 * s), tab_col, true)
		draw_string(_cjk_font, Vector2(tx, cur_y + 22 * s), tab_name,
			HORIZONTAL_ALIGNMENT_CENTER, tab_w, 14 * s,
			Color.WHITE if active else Color(1, 1, 1, 0.6))
	cur_y += 44 * s

	# 分隔线
	draw_line(Vector2(px + 20 * s, cur_y), Vector2(px + pw - 20 * s, cur_y),
		Color(1, 1, 1, 0.1), 1.0)
	cur_y += 16 * s

	# Tab 内容
	match _settings_tab:
		0: cur_y = _draw_settings_city(px, cur_y, pw, s)
		1: cur_y = _draw_settings_pet(px, cur_y, pw, s)
		2: cur_y = _draw_settings_about(px, cur_y, pw, s)

	# 底部关闭按钮
	var close_y := py + ph - 50 * s
	var close_rect := Rect2(cx - 60 * s, close_y, 120 * s, 36 * s)
	draw_round_rect(close_rect, Color(0.9, 0.3, 0.3, 0.7), 18 * s)
	draw_string(_cjk_font, Vector2(close_rect.position.x, close_rect.position.y + 24 * s),
		"关闭", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 16 * s, Color.WHITE)

# Tab 0: 城市切换
func _draw_settings_city(px: float, y: float, pw: float, s: float) -> float:
	var cur := y
	draw_string(_cjk_font, Vector2(px + 24 * s, cur + 20 * s), "选择城市 (点击切换)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15 * s, Color(0.7, 0.8, 0.95))
	cur += 32 * s
	if data and data.has_method("get_city_names"):
		var names: PackedStringArray = data.get_city_names()
		var current_city: String = String(data.city_name) if "city_name" in data else ""
		var cols := 3
		var btn_w := (pw - 48 * s) / cols
		var btn_h := 38 * s
		for i in range(names.size()):
			var col := i % cols
			var row := i / cols
			var bx := px + 24 * s + col * btn_w
			var byy := cur + row * (btn_h + 6 * s)
			var active := (names[i] == current_city)
			var col2 := Color(0.2, 0.6, 1.0, 0.35) if active else Color(1, 1, 1, 0.08)
			draw_round_rect(Rect2(bx + 2 * s, byy, btn_w - 4 * s, btn_h), col2, 10 * s)
			draw_string(_cjk_font, Vector2(bx, byy + 24 * s), names[i],
				HORIZONTAL_ALIGNMENT_CENTER, btn_w, 15 * s, Color.WHITE)
		cur += (names.size() / cols + 1) * (btn_h + 6 * s)
	# GPS 按钮
	cur += 10 * s
	var gps_rect := Rect2(px + 24 * s, cur, pw - 48 * s, 40 * s)
	draw_round_rect(gps_rect, Color(0.3, 0.7, 0.4, 0.5), 12 * s)
	draw_string(_cjk_font, Vector2(px, cur + 26 * s), "🛰 使用 GPS 实时定位",
		HORIZONTAL_ALIGNMENT_CENTER, pw, 16 * s, Color.WHITE)
	return cur + 50 * s

# Tab 1: 小人朝向调整
func _draw_settings_pet(px: float, y: float, pw: float, s: float) -> float:
	var cur := y
	draw_string(_cjk_font, Vector2(px + 24 * s, cur + 20 * s), "小人朝向 (脸不对就调整)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15 * s, Color(0.7, 0.8, 0.95))
	cur += 36 * s
	# 朝向按钮: ← 0° → ← 90° ← 180° ← 270°
	var dirs := [
		{"deg": 0.0, "label": "正脸\n0°"},
		{"deg": 90.0, "label": "右转\n90°"},
		{"deg": 180.0, "label": "背对\n180°"},
		{"deg": 270.0, "label": "左转\n270°"},
	]
	var btn_w := (pw - 48 * s) / 4.0
	for i in range(dirs.size()):
		var bx := px + 24 * s + i * btn_w
		draw_round_rect(Rect2(bx + 2 * s, cur, btn_w - 4 * s, 50 * s),
			Color(1, 1, 1, 0.1), 10 * s)
		draw_string(_cjk_font, Vector2(bx, cur + 22 * s), dirs[i]["label"],
			HORIZONTAL_ALIGNMENT_CENTER, btn_w, 12 * s, Color(0.9, 0.95, 1.0))
	cur += 62 * s
	# 动画预览按钮
	draw_string(_cjk_font, Vector2(px + 24 * s, cur + 20 * s), "动画演示",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15 * s, Color(0.7, 0.8, 0.95))
	cur += 32 * s
	var anims := ["idle", "wave", "walk", "fall"]
	for i in range(anims.size()):
		var bx := px + 24 * s + i * ((pw - 48 * s) / 4.0)
		var btn_rect := Rect2(bx + 2 * s, cur, (pw - 48 * s) / 4.0 - 4 * s, 36 * s)
		draw_round_rect(btn_rect, Color(1, 1, 1, 0.1), 10 * s)
		draw_string(_cjk_font, Vector2(bx, cur + 23 * s), anims[i],
			HORIZONTAL_ALIGNMENT_CENTER, btn_rect.size.x, 13 * s, Color(0.9, 0.95, 1.0))
	cur += 46 * s
	return cur

# Tab 2: 关于/状态
func _draw_settings_about(px: float, y: float, pw: float, s: float) -> float:
	var cur := y
	var lines := []
	if data:
		var w: Dictionary = data.current_weather if typeof(data.current_weather) == TYPE_DICTIONARY else {}
		lines.append("天气: %s  %.0f°C" % [String(w.get("condition", "?")), float(w.get("temperature", 0))])
		lines.append("城市: %s (%s)" % [String(data.city_name), String(data.location_mode)])
		lines.append("时间: %02d:%02d" % [int(data.current_hour), int(data.current_minute)])
		lines.append("电量: %d%%%s" % [int(data.battery_percent), " 充电中" if data.is_charging else ""])
		lines.append("信号: %d 级" % int(data.phone_signal))
		lines.append("演示模式: %s" % ("开启" if _demo_enabled else "关闭"))
	lines.append("模型: Godot Plush (MIT)")
	lines.append("天气: 和风天气 API")
	for line in lines:
		draw_string(_cjk_font, Vector2(px + 24 * s, cur + 20 * s), line,
			HORIZONTAL_ALIGNMENT_LEFT, pw - 48 * s, 14 * s, Color(0.8, 0.88, 0.98))
		cur += 26 * s
	return cur

# 设置面板点击处理
func _handle_settings_tap(pos: Vector2):
	var s := DS
	# 关闭按钮
	var close_y := _settings_rect.end.y - 50 * s
	var close_rect := Rect2(_settings_rect.position.x + _settings_rect.size.x * 0.5 - 60 * s, close_y, 120 * s, 36 * s)
	if close_rect.has_point(pos):
		_settings_open = false
		return
	# 点面板外也关闭
	if not _settings_rect.has_point(pos):
		_settings_open = false
		return

	var pw := _settings_rect.size.x
	var px := _settings_rect.position.x
	# Tab 栏位置
	var tab_y := _settings_rect.position.y + 60 * s
	var tab_w := pw / 3.0
	if pos.y >= tab_y and pos.y <= tab_y + 32 * s:
		for i in range(3):
			var tx := px + tab_w * i
			if pos.x >= tx and pos.x <= tx + tab_w:
				_settings_tab = i
				return
	# Tab 内容点击
	var content_y := tab_y + 44 * s + 16 * s
	match _settings_tab:
		0: _handle_city_tap(pos, px, content_y, pw, s)
		1: _handle_pet_tap(pos, px, content_y, pw, s)

func _handle_city_tap(pos: Vector2, px: float, y: float, pw: float, s: float):
	if not data:
		return
	var cur := y + 32 * s
	if data.has_method("get_city_names"):
		var names: PackedStringArray = data.get_city_names()
		var cols := 3
		var btn_w := (pw - 48 * s) / cols
		var btn_h := 38 * s
		for i in range(names.size()):
			var col := i % cols
			var row := i / cols
			var bx := px + 24 * s + col * btn_w
			var byy := cur + row * (btn_h + 6 * s)
			if Rect2(bx + 2 * s, byy, btn_w - 4 * s, btn_h).has_point(pos):
				data.set_city_by_name(names[i])
				return
		cur += (names.size() / cols + 1) * (btn_h + 6 * s) + 10 * s
	# GPS 按钮
	var gps_rect := Rect2(px + 24 * s, cur, pw - 48 * s, 40 * s)
	if gps_rect.has_point(pos) and data.has_method("switch_to_gps"):
		data.switch_to_gps()

func _handle_pet_tap(pos: Vector2, px: float, y: float, pw: float, s: float):
	# 朝向按钮 (4个)
	var cur := y + 36 * s
	var btn_w := (pw - 48 * s) / 4.0
	var dirs := [0.0, 90.0, 180.0, 270.0]
	for i in range(4):
		var bx := px + 24 * s + i * btn_w
		if Rect2(bx + 2 * s, cur, btn_w - 4 * s, 50 * s).has_point(pos):
			if pet_renderer_node and pet_renderer_node.has_method("set_face_offset"):
				pet_renderer_node.set_face_offset(dirs[i])
			return
	cur += 62 * s + 32 * s
	# 动画按钮
	var anims := ["idle", "wave", "walk", "fall"]
	for i in range(4):
		var bx := px + 24 * s + i * btn_w
		if Rect2(bx + 2 * s, cur, btn_w - 4 * s, 36 * s).has_point(pos):
			if pet_renderer_node and pet_renderer_node.has_method("play_anim"):
				pet_renderer_node.play_anim(anims[i])
			return
