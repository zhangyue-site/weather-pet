extends Node2D
const CourtyardUI = preload("res://companion/courtyard_ui.gd")
const SceneEffects = preload("res://companion/scene_effects.gd")
const Catalog = preload("res://companion/catalog.gd")
const World = preload("res://companion/world.gd")
const WeatherSource = preload("res://companion/weather_source.gd")
const Events = preload("res://companion/events.gd")
const EventSource = preload("res://companion/event_source.gd")
const Calendar = preload("res://companion/calendar_data.gd")
const CalendarEffects = preload("res://companion/calendar_effects.gd")
const Ambience = preload("res://companion/ambience.gd")
const Duet = preload("res://companion/duet.gd")
const DuetProps = preload("res://companion/duet_props.gd")
const LocationName = preload("res://companion/location_name.gd")
const AndroidBridge = preload("res://companion/android_bridge.gd")
const IOSPlatform = preload("res://companion/ios_platform.gd")
const Actor = preload("res://companion/actor.gd")
const Effects = preload("res://companion/effects.gd")
const FishActor = preload("res://companion/fish_actor.gd")
const INK: = Color("293e42")
const MUTED: = Color("738181")
const CREAM: = Color("fffaf0")
const TEAL: = Color("347c7e")

var view = CourtyardUI.new()
var scene_effects = SceneEffects.new()
var real_world: RefCounted
var real_scene_effects: RefCounted
var real_effect_activity := ""
var live_target_key := ""
var location_target_key := "location:pending"
var real_fish_memory: Dictionary = {}
var city_button: Button
var date_chip: PanelContainer
var weather_meta: Label
var preview_button: Button
var quiet_exit: Button
var panel_focus_return: Control
var home_focus_modes: Dictionary = {}
var anniversary_draft: Dictionary = {}
var draft_dirty := false
var draft_exit_target := ""
var delete_anniversary_id := ""
var draft_error: Label
var system_reduced_motion := false
var effect_activity := ""
var world = World.new()
var duet = Duet.new()
var duet_props: Node2D
var ambience = Ambience.new()
var ambience_enabled := true
var ambience_low_power := false
var battery_elapsed := 10.0
var calendar_effects: Node2D
var anniversaries: Array = []
var program_key: = ""
var preview_date: = ""
var effect_page: = 0
var calendar_label: Label
var updater: Object
var update_data: Dictionary = {}
var update_text: Label
var update_url := ""
var opened_sheet: = ""
var event_source: Node
var festival_preview: = false
var festival_label: Label
var source: Node
var actor: Node2D
var effects: Node2D
var fish: Node2D
var fish_enabled: = true
var fish_page := 0
var backgrounds: Dictionary = {}
var background_now: = "day"
var background_before: = "day"
var background_mix: = 1.0
var ui: Control
var top: Control
var bottom: PanelContainer
var title_label: Label
var weather_label: Label
var details_label: Label
var source_label: Label
var clock_label: Label
var location_label: Label
var location_state := "waiting"
var location_city := ""
var location_name_pending := false
var location_name_elapsed := 0.0
var location_names: Node
var status_label: Label
var caption_label: Label
var bond_label: Label
var sheet: PanelContainer
var shade: ColorRect
var sheet_scroll: ScrollContainer
var sheet_content: VBoxContainer
var font: Font
var mode: = "live"
var city_index: = 0
var network_status: = "正在连接天气"
var live_data: Dictionary = {}
var cinematic: = false
var cinematic_time: = 0.0
var cinematic_index: = -1
var save_elapsed: = 0.0
var ui_elapsed: = 0.0
var touch_start: = Vector2.ZERO
var touch_time: = 0.0
var touching: = false
var capture_mode: = false
var reduced_motion: = false
var quiet_mode: = false
var settings: Dictionary = {}
var use_location: = true
var location_plugin: Object

func _ready() -> void :
	view.app = self
	get_tree().quit_on_go_back = false
	_load_release_config()
	font = load("res://companion/fonts/NotoSansSC.ttf")
	for id in ["day", "rain", "snow", "night"]: backgrounds[id] = load("res://companion/art/%s.png" % id)
	ambience.configure(backgrounds.day.get_size())
	if Engine.has_singleton("CompanionUpdater"):
		updater = Engine.get_singleton("CompanionUpdater")
		updater.connect("update_state", _on_update_state)
	_load_saved()
	location_names = LocationName.new()
	add_child(location_names)
	location_names.resolved.connect(_on_resolved_name)
	source = WeatherSource.new()
	add_child(source)
	source.updated.connect(_on_live_weather)
	source.status_changed.connect( func(s): network_status = s;_refresh_labels())
	if Engine.has_singleton("CompanionLocation"):
		location_plugin = Engine.get_singleton("CompanionLocation")
	elif OS.has_feature("ios") and Engine.has_singleton("CompanionIOS"):
		location_plugin = IOSPlatform.new()
		add_child(location_plugin)
	if location_plugin != null:
		location_plugin.connect("location_ready", _on_location)
		if location_plugin.has_signal("location_name_ready"):
			location_plugin.connect("location_name_ready", _on_location_name)
		location_plugin.connect("location_error", _on_location_error)
	actor = Actor.new()
	actor.world = world
	add_child(actor)
	effects = Effects.new()
	effects.world = world
	effects.actor = actor
	add_child(effects)
	fish = FishActor.new()
	fish.world = world
	fish.respond = _fish_wave_back
	fish.enabled = fish_enabled
	fish.memory = settings.get("fish_memory", {}).duplicate(true)
	add_child(fish)
	duet_props = DuetProps.new()
	duet_props.duet = duet; duet_props.actor = actor; duet_props.fish = fish
	add_child(duet_props)
	event_source = EventSource.new()
	add_child(event_source)
	event_source.changed.connect(_update_festival)
	calendar_effects = CalendarEffects.new()
	calendar_effects.world = world
	calendar_effects.actor = actor
	calendar_effects.director = scene_effects
	effects.director = scene_effects
	add_child(calendar_effects)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	capture_mode = OS.get_environment("COMPANION_SHOTS") != ""
	if capture_mode:
		mode = "demo"
		_run_capture()
	else:
		_use_live()
	_refresh_labels()

func _load_release_config() -> void:
	var path := "res://companion/release.json"
	if not FileAccess.file_exists(path): return
	var config = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not config is Dictionary or config.size()!=1 or not config.get("update_url") is String: return
	var endpoint: String = config.update_url
	for character in endpoint.to_utf8_buffer():
		if character <= 32 or character == 127:return
	if endpoint.begins_with("https://") and not endpoint.contains("@") and not endpoint.contains("#") and not endpoint.contains(" ") and not endpoint.contains("\n"):
		update_url=endpoint

func _today() -> String:
	if not preview_date.is_empty(): return preview_date
	if mode == "live" and not live_data.is_empty():
		return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + int(live_data.get("utc_offset", 28800)))
	return Time.get_date_string_from_system()

func _update_festival() -> void :
	if festival_preview or event_source == null: return
	var date: = _today()
	var key: = date + ":" + str(event_source.catalog.revision) + ":" + str(anniversaries.hash())
	if key == program_key: return
	program_key = key
	world.set_festival(Events.program(event_source.catalog, date, anniversaries))

func _preview_festival(event: Dictionary) -> void :
	duet.cancel(world,fish)
	set_demo("clear")
	festival_preview = true
	var program: = event.duplicate(true)
	program["effect_ids"] = [event.get("effect", "confetti_burst")]
	program["matches"] = [event.duplicate(true)]
	world.set_festival(program)
	world.queue.clear()
	world.celebrate()
	_refresh_labels()
	fish.request_show(true)
	_close_sheet()

func _preview_date(date: String) -> void :
	duet.cancel(world,fish)
	set_demo("clear")
	preview_date = date
	program_key = ""
	_update_festival()
	world.queue.clear()
	world.celebrate()
	_refresh_labels()
	fish.request_show(true)
	_close_sheet()

func _load_saved() -> void :
	var f: = FileAccess.open("user://companion_save.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			settings = d
			if d.get("anniversaries") is Array:
				for event in d.anniversaries.slice(0, 64):
					if Events.valid_event(event): anniversaries.append(event)
			city_index = clampi(int(d.get("city", 0)), 0, Catalog.CITIES.size() - 1)
			use_location = bool(d.get("use_location", true))
			fish_enabled = bool(d.get("fish_enabled", true))
			ambience_enabled = bool(d.get("ambience_enabled",true))
			reduced_motion = bool(d.get("reduced_motion", false))
			if d.get("world") is Dictionary: world.restore(d.world)
	if settings.is_empty(): world.restore({})

func _save() -> void :
	if capture_mode: return
	var f: = FileAccess.open("user://companion_save.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"city": city_index, "use_location": use_location, "world": (real_world if real_world != null else world).save_data(), "reduced_motion": reduced_motion, "anniversaries": anniversaries, "fish_enabled": fish_enabled, "ambience_enabled": ambience_enabled, "fish_memory": real_fish_memory if real_world != null else (fish.memory if fish != null else settings.get("fish_memory", {}))}))

func _notification(what: int) -> void :
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
		if location_plugin != null and location_plugin.has_method("cancel_location"):
			location_plugin.cancel_location()
	elif what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready():
		_layout()
		if mode == "live": _use_live()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if opened_sheet.is_empty() and not quiet_mode:
			_save(); get_tree().quit()
		else: _back_sheet()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()

func _process(delta: float) -> void :
	if location_name_pending:
		location_name_elapsed += delta
		if location_name_elapsed >= 10:
			location_name_pending = false; location_names.cancel(); _refresh_labels()
	world.step(delta)
	duet.step(delta,world,fish)
	background_mix = minf(1.0, background_mix + delta * 0.6)
	save_elapsed += delta
	ui_elapsed += delta
	if save_elapsed >= 20: save_elapsed = 0;_save()
	if ui_elapsed > 0.15: ui_elapsed = 0;_update_festival();_refresh_labels()
	if cinematic:
		cinematic_time += delta
		var slot: = int(cinematic_time / 18) % Catalog.IDS.size()
		if slot != cinematic_index:
			cinematic_index = slot
			set_demo(Catalog.IDS[slot], false)
	_update_background()
	battery_elapsed += delta
	if battery_elapsed >= 10:
		battery_elapsed = 0
		ambience_low_power = _android_low_power()
		system_reduced_motion = _system_reduced_motion()
	var reduce := reduced_motion or system_reduced_motion
	ambience.update(delta,self,ambience_enabled,reduce,ambience_low_power,background_now == "day",duet.active)
	scene_effects.set_policy(reduce, ambience_low_power or ambience.reason == "frame_budget")
	scene_effects.update_context(world.environment, world.festival, _today())
	scene_effects.step(delta)
	if effect_activity != world.activity:
		effect_activity = world.activity
		if effect_activity in ["drink", "water"]: scene_effects.trigger(effect_activity)
	var size: = get_viewport_rect().size
	actor.foot = Vector2(world.x * size.x, size.y * 0.78)
	actor.body_height = minf(size.y * 0.27, 265)
	var show_care := sheet.visible and opened_sheet == "care"
	if show_care:
		actor.foot.y = minf(actor.foot.y, sheet.position.y - 14)
		actor.body_height = minf(size.y * 0.20, 200)
	fish.presentation_floor = actor.foot.y if show_care else -1.0
	fish.presentation_scale = 0.85 if show_care else 1.0
	calendar_effects.reduced_motion = reduce
	effects.visible = not reduce and not ambience_low_power
	fish.reduced = reduce or ambience_low_power
	actor.update_visual()
	queue_redraw()

func _android_low_power() -> bool:
	if OS.has_feature("ios") and location_plugin != null and location_plugin.has_method("low_power"):
		return bool(location_plugin.low_power())
	if not AndroidBridge.mutex.try_lock(): return ambience_low_power
	var value := _read_android_low_power()
	AndroidBridge.mutex.unlock()
	return value

func _read_android_low_power() -> bool:
	# Godot 4.4 has no portable battery API. Use its existing Android runtime bridge.
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"): return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	var context = runtime.getApplicationContext()
	if JavaClassWrapper.get_exception() != null or context == null: return false
	var power = context.getSystemService("power")
	if JavaClassWrapper.get_exception() != null: return false
	if power != null:
		var saver = power.isPowerSaveMode()
		if JavaClassWrapper.get_exception() != null: return false
		if bool(saver): return true
	var battery = context.getSystemService("batterymanager")
	if JavaClassWrapper.get_exception() != null or battery == null: return false
	var percent = battery.getIntProperty(4) # BATTERY_PROPERTY_CAPACITY, Android API21+
	if JavaClassWrapper.get_exception() != null: return false
	return int(percent) >= 0 and int(percent) <= 20

func _update_background() -> void :
	var id: String = world.environment.id
	var next: = "day"
	if Catalog.is_rain(id) or id in ["overcast", "fog"]: next = "rain"
	elif Catalog.is_snow(id) or id == "cold": next = "snow"
	elif not bool(world.environment.is_day): next = "night"
	if next != background_now:
		background_before = background_now
		background_now = next
		background_mix = 0

func _background_rect(tex: Texture2D) -> Rect2:
	var size: = get_viewport_rect().size
	var factor: = maxf(size.x / tex.get_width(), size.y / tex.get_height())
	var scaled: = tex.get_size() * factor
	return Rect2((size - scaled) * 0.5, scaled)

func _draw() -> void :
	if backgrounds.is_empty(): return
	var size: = get_viewport_rect().size
	var tint: = Color.WHITE
	var id: String = world.environment.id
	if id == "cloudy": tint = Color(0.88, 0.93, 0.98)
	if id == "dawn": tint = Color(1, 0.91, 0.86)
	if id == "dusk": tint = Color(1, 0.77, 0.59)
	if mode == "live" and world.environment.get("phase", "") == "dawn": tint = Color(1, 0.91, 0.86)
	if mode == "live" and world.environment.get("phase", "") == "dusk": tint = Color(1, 0.77, 0.59)
	if id == "hot": tint = Color(1, 0.96, 0.82)
	if not bool(world.environment.is_day) and background_now != "night": tint = Color(0.43, 0.5, 0.67)
	if background_mix < 1.0:
		var previous: Texture2D = backgrounds[background_before]
		draw_texture_rect(previous, _background_rect(previous), false, tint)
	var current: Texture2D = backgrounds[background_now]
	draw_texture_rect(current, _background_rect(current), false, Color(tint, background_mix))

	if background_now == "day" and world.puddle > 0.01:
		var rain: Texture2D = backgrounds.rain
		draw_texture_rect(rain, _background_rect(rain), false, Color(1, 1, 1, world.puddle * 0.14))

	for i in range(24):
		var alpha: = (1.0 - float(i) / 24.0) * 0.25
		draw_rect(Rect2(0, i * 12, size.x, 12), Color(0.05, 0.13, 0.2, alpha))
	draw_set_transform(actor.foot + Vector2(0, 2), 0, Vector2(1, 0.24))
	draw_circle(Vector2.ZERO, actor.body_height * 0.25, Color(0.08, 0.12, 0.13, 0.2))
	draw_set_transform(Vector2.ZERO)

func _style(color: Color, radius: int = 20, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s: = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.border_color = border
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func _label(text: String, size: int = 18, color: Color = INK) -> Label:
	var l: = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, callback: Callable, active: = false) -> Button:
	var b: = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color.WHITE if active else INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE if active else INK)
	b.add_theme_color_override("font_focus_color", Color.WHITE if active else INK)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _style(TEAL if active else Color("f0eee6"), 14))
	b.add_theme_stylebox_override("hover", _style(Color("588e89") if active else Color("dce8df"), 14))
	b.add_theme_stylebox_override("pressed", _style(Color("245e62"), 14))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 14, Color("d8b066")))
	b.pressed.connect(callback)
	return b

func _build_ui() -> void:
	view.build()

func _layout() -> void:
	if ui != null: view.layout()

func _refresh_labels() -> void :
	if weather_label == null: return
	var e: Dictionary = world.environment
	var has_live: bool = mode == "live" and not live_data.is_empty()
	if has_live:
		var clock: Dictionary = WeatherSource.clock_state(live_data)
		for field in ["hour", "minute", "is_day", "phase"]: world.environment[field] = clock[field]
	var valid: bool = mode == "demo" or has_live
	weather_label.text = ("%d°" % roundi(e.temperature)) if valid else "--°"
	details_label.text = ("%s · 体感 %d°" % [e.title, roundi(e.feels)]) if valid else "正在获取天气"
	weather_meta.text = ("湿度 %d%% · 风速 %d km/h" % [int(e.humidity), roundi(e.wind)]) if valid else "小院里先歇一会儿"
	var time: = Time.get_datetime_dict_from_system()
	if has_live:
		time = WeatherSource.clock_state(live_data)
	location_label.text = _location_text()
	var city: String = location_city if use_location and not location_city.is_empty() else String(Catalog.CITIES[city_index].name)
	city_button.text = city + "  ›"
	preview_button.visible = mode == "demo"
	location_label.visible = use_location and location_state in ["waiting", "failed", "unavailable"]
	clock_label.text = "%02d:%02d  ·  %s" % [time.hour,time.minute,"体验" if mode == "demo" else "实时"]
	if mode == "demo":
		source_label.text = "天气体验 · " + ("自动漫游中" if cinematic else "可以切换不同天气")
	elif has_live:
		var age: float = Time.get_unix_time_from_system() - float(live_data.saved_at)
		var prefix: = "过期缓存" if age > 3600 else String(live_data.source)
		source_label.text = "%s · %s 更新" % [prefix, String(live_data.observed).replace("T", " ").substr(11, 5)]
	else: source_label.text = network_status
	festival_label.text = (("日常体验 · " if world.festival.get("kind","")=="daily" else "节日体验 · ") if festival_preview else "") + String(world.festival.get("title", ""))
	if fish != null: fish.set_context(_today(), int(time.hour), mode == "demo" or festival_preview or not preview_date.is_empty())
	var lunar: = Calendar.lunar(_today())
	calendar_label.text = _today().substr(5).replace("-", "月") + "日 · " + (String(lunar.title) if not lunar.is_empty() else String(world.festival.get("title", "平常的一天")))
	if not preview_date.is_empty(): calendar_label.text += " · 体验"
	status_label.text = world.status
	caption_label.text = duet.caption if duet.active else world.status
	bond_label.text = "陪伴 %d 次" % world.bond
	if quiet_mode: caption_label.text = "轻轻点一下阿晴，打个招呼"

func _on_live_weather(data: Dictionary) -> void :
	live_target_key = ("manual:" + str(source.pending_city)) if source.custom_target.is_empty() else ("location:%.2f:%.2f" % [source.custom_target.lat, source.custom_target.lon])
	if mode != "live":
		live_data = data.duplicate(true)
		return
	if String(data.id) != String(world.environment.id): duet.cancel(world,fish)
	live_data = data
	world.set_environment(data)
	_refresh_labels()
	_save()

func set_demo(id: String, stop_tour: = true) -> void :
	_begin_preview()
	duet.cancel(world,fish)
	festival_preview = false
	preview_date = ""
	program_key = ""
	if calendar_effects != null: calendar_effects.override_id = ""
	if stop_tour: cinematic = false
	mode = "demo"
	source.stop()
	world.set_environment(Catalog.preset(id))
	_refresh_labels()
	_save()

func _use_live() -> void :
	_end_preview()
	duet.cancel(world,fish)
	festival_preview = false
	preview_date = ""
	program_key = ""
	if calendar_effects != null: calendar_effects.override_id = ""
	mode = "live"
	cinematic = false
	if use_location or live_target_key != _target_key(): live_data = {}
	if not live_data.is_empty(): world.set_environment(live_data)
	else: world.environment = Catalog.preset("clear")
	world.environment.caption = "天气更新中，先陪你安静待一会儿。"
	location_names.cancel()
	location_name_pending = false
	location_city = ""
	location_state = "waiting" if use_location and location_plugin != null else "unavailable" if use_location else "manual"
	if use_location and location_plugin != null:
		source.stop()
		network_status = "正在获取位置 · 也可在设置中选择城市"
		location_plugin.call("request_location")
	else:
		source.fetch(city_index)
	_close_sheet()
	_refresh_labels()

func _location_text() -> String:
	var selected: String = Catalog.CITIES[city_index].name
	if mode == "demo": return "体验场景 · 不是当前位置"
	if not use_location: return "城市天气 · " + selected
	if location_state == "failed": return "定位未成功 · 暂用" + selected
	if location_state == "unavailable": return "定位不可用 · 暂用" + selected
	if location_state == "waiting": return "自动定位 · 定位中…"
	if not location_city.is_empty(): return "自动定位 · " + location_city
	var name := String(live_data.get("city",""))
	if not name.is_empty() and name != "当前位置": return "自动定位 · " + name
	return "已获取位置 · 地名解析中…" if location_name_pending else "已定位 · 暂无城市名"

func _on_location(json: String) -> void :
	if mode != "live" or not use_location: return
	var coordinates = JSON.parse_string(json)
	if coordinates is Dictionary and coordinates.has("lat") and coordinates.has("lon"):
		if typeof(coordinates.lat) not in [TYPE_INT,TYPE_FLOAT] or typeof(coordinates.lon) not in [TYPE_INT,TYPE_FLOAT]:
			_on_location_error("位置数据无效"); return
		var lat := float(coordinates.lat)
		var lon := float(coordinates.lon)
		if not is_finite(lat) or not is_finite(lon) or absf(lat)>90 or absf(lon)>180:
			_on_location_error("位置数据无效"); return
		location_target_key = "location:%.2f:%.2f" % [lat, lon]
		if live_target_key != location_target_key:
			live_data = {}
			world.environment = Catalog.preset("clear")
		location_state = "located"
		location_name_pending = location_city.is_empty()
		location_name_elapsed = 0
		network_status = "已定位 · 获取天气中"
		_refresh_labels()
		source.fetch_coordinates(lat,lon)
		if location_city.is_empty() and not OS.has_feature("ios"): location_names.request_name(lat,lon)
		if not location_city.is_empty() and source.has_method("rename_current_city"):
			source.rename_current_city(location_city)
	else: _on_location_error("未获取到位置")

func _on_location_name(city_name: String) -> void :
	if mode != "live" or not use_location: return
	var clean: = String(city_name).strip_edges()
	if clean.is_empty() or location_state in ["failed","unavailable"]: return
	location_city = clean
	location_name_pending = false
	if source.has_method("rename_current_city"): source.rename_current_city(clean)
	_refresh_labels()

func _on_resolved_name(name: String) -> void:
	if mode != "live" or not use_location or location_state != "located": return
	location_name_pending = false
	if not name.is_empty(): _on_location_name(name)
	_refresh_labels()

func _on_location_error(message: String) -> void :
	if mode != "live" or not use_location: return
	if live_target_key != "manual:" + str(city_index):
		live_data = {}
		world.environment = Catalog.preset("clear")
	location_state = "failed"
	location_names.cancel()
	location_name_pending = false
	location_city = ""
	network_status = String(message)
	source.fetch(city_index)
	_refresh_labels()

func _close_sheet() -> void:
	if opened_sheet == "anniversaries": _capture_anniversary_draft()
	if opened_sheet == "anniversaries" and draft_dirty:
		draft_exit_target = ""; _open_sheet("discard_draft"); return
	if opened_sheet == "discard_draft":
		_open_sheet("anniversaries"); return
	opened_sheet = ""
	sheet.hide(); shade.hide()
	_restore_home_focus()
	if is_instance_valid(panel_focus_return) and panel_focus_return.is_visible_in_tree(): panel_focus_return.grab_focus()
	_layout()

func _heading(title: String, subtitle: String) -> void:
	view.heading(title, subtitle)

func _open_sheet(kind: String) -> void:
	if opened_sheet == "anniversaries": _capture_anniversary_draft()
	if opened_sheet == "anniversaries" and draft_dirty and kind not in ["anniversaries", "discard_draft"]:
		draft_exit_target = kind; _open_sheet("discard_draft"); return
	if not sheet.visible:
		panel_focus_return = get_viewport().gui_get_focus_owner()
		_disable_home_focus()
	opened_sheet = kind
	for child in sheet_content.get_children():
		sheet_content.remove_child(child)
		child.queue_free()
	sheet_scroll.scroll_vertical = 0
	shade.show()
	sheet.show()
	if view.panel(kind):
		_layout(); _focus_panel(); return
	match kind:
		"updates":
			_update_panel()
		"festivals":
			_heading("今天与每一天", "全年每日主题，叠加农历、公历、节气和你的纪念日。")
			var program: = Events.program(event_source.catalog, _today(), anniversaries)
			sheet_content.add_child(_label(String(program.daily_title), 16, TEAL))
			for event in program.matches: sheet_content.add_child(_label("今天 · " + String(event.title), 16))
			if program.matches.is_empty(): sheet_content.add_child(_label("今天没有额外节日，也有日常小节目。", 14, MUTED))
			var date_input: = _field("YYYY-MM-DD", _today())
			sheet_content.add_child(date_input)
			var error_label: = _label("", 13, Color("aa5143"))
			sheet_content.add_child(error_label)
			sheet_content.add_child(_button("看看这一天", func():
				if Events._valid_date(date_input.text): _preview_date(date_input.text)
				else: error_label.text = "请输入有效公历日期，例如 2026-10-01"))
			sheet_content.add_child(_button("节日与节气目录", func(): _open_sheet("festival_library")))
			sheet_content.add_child(_button("回到今天 · 真实天气", _use_live, true))
			sheet_content.add_child(_label(event_source.status, 12, MUTED))
		"festival_library":
			_heading("节日、节气与纪念日", "自动使用真实日期；这里可以提前看看。纪念日采用安静的演出。")
			for event in event_source.catalog.events:
				var chosen: Dictionary = event
				sheet_content.add_child(_button(String(event.title), func(): _preview_festival(chosen)))
		"fish_library":
			_fish_library()
		"anniversaries":
			_anniversary_form()
		"effect_library":
			_heading("场景特效", "按真实场景展示；同类运动变体由场景调度，不再堆叠两百个入口。")
			Calendar.ensure_loaded()
			var families: Dictionary = {}
			for id in Calendar.effect_order:
				var recipe: Dictionary = Calendar.effect(id)
				if families.has(recipe.family): continue
				families[recipe.family] = true
				var chosen: String = id
				var item := _button(String(recipe.title), func():
					_preview_date(_real_today())
					calendar_effects.override_id = chosen
					festival_preview = true
					world.set_festival({"id":"effect_preview", "title":Calendar.effect(chosen).title, "caption":"特效体验", "actions":["idle"], "tone":"gentle"})
					_refresh_labels(); _close_sheet())
				sheet_content.add_child(item)
		"weather":
			_heading("小院的每一种天气", "让阿晴陪你看看，不一样的天空。")
			var grid: = GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 7)
			grid.add_theme_constant_override("v_separation", 8)
			sheet_content.add_child(grid)
			for id in Catalog.IDS:
				var chosen: String = id
				var active: bool = mode == "demo" and world.environment.id == id
				grid.add_child(_button(Catalog.preset(id).title, func(): set_demo(chosen);_close_sheet(), active))
			sheet_content.add_child(_button("自动漫游", func(): set_demo("clear");cinematic = true;cinematic_time = 0;cinematic_index = -1;_close_sheet()))
			sheet_content.add_child(_button("回到真实天气", _use_live, true))
		"licenses":
			_heading("开源许可与数据来源", "小院天气 · MIT")
			var notices := "天气数据：Open-Meteo.com（CC BY 4.0）\n大肥鱼：PC2005-cloud/dsh-pet（MIT）\n字体：Noto Sans SC（SIL OFL 1.1）\n农历数据生成：6tail/lunar-python（MIT）\n\n"
			for path in ["res://companion/licenses/MIT.txt", "res://companion/fish/LICENSE-upstream.txt", "res://companion/fonts/OFL.txt", "res://companion/licenses/lunar-python.txt"]:
				if FileAccess.file_exists(path): notices += FileAccess.get_file_as_string(path) + "\n\n"
			notices += Engine.get_license_text()
			var text := _label(notices, 12, MUTED)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sheet_content.add_child(text)
	_layout()
	_focus_panel()

func _on_update_state(json: String) -> void :
	var data = JSON.parse_string(json)
	if not data is Dictionary: return
	var previous: String = update_data.get("state", "")
	update_data = data
	if opened_sheet == "updates":
		if data.get("state") == previous and is_instance_valid(update_text):
			update_text.text = String(data.get("message", ""))
		else: _open_sheet("updates")

func _update_panel() -> void :
	_heading("应用更新", "节日日历可以单独更新；新版应用需你确认下载和安装。")
	var installed: = {"name": ProjectSettings.get_setting("application/config/version", "1.4.1"), "code": 214}
	if updater != null:
		var actual = JSON.parse_string(updater.call("installed_version"))
		if actual is Dictionary: installed = actual
	sheet_content.add_child(_label("当前版本：" + String(installed.get("name", "未知")), 16, TEAL))
	update_text = _label(String(update_data.get("message", "点击检查更新。下载失败不会影响当前版本。")), 14)
	update_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_content.add_child(update_text)
	if updater == null:
		sheet_content.add_child(_label("请通过 App Store 或 TestFlight 更新小院天气。" if OS.has_feature("ios") else "请在 Android 安装包中使用 OTA。", 14, MUTED))
		return
	var state: String = update_data.get("state", "idle")
	if state == "available":
		var notes: = _label(String(update_data.get("notes", "")), 14, MUTED)
		notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sheet_content.add_child(notes)
		sheet_content.add_child(_button("下载更新 · %.1f MB" % (float(update_data.get("bytes", 0)) / 1048576.0), func(): updater.call("download_update"), true))
	elif state in ["ready", "permission", "installer"]:
		sheet_content.add_child(_button("继续安装" if state != "ready" else "安装更新", func(): updater.call("install_update"), true))
	elif state in ["checking", "downloading"]:
		sheet_content.add_child(_button("取消", func(): updater.call("cancel_update")))
	if state not in ["checking", "downloading"]:
		if update_url.is_empty(): sheet_content.add_child(_label("更新服务暂不可用",14,MUTED))
		else: sheet_content.add_child(_button("检查更新", func(): updater.call("check_update", update_url)))

func _field(placeholder: String, initial: = "") -> LineEdit:
	var field: = LineEdit.new()
	field.placeholder_text = placeholder
	field.text = initial
	field.custom_minimum_size.y = 44
	field.add_theme_font_override("font", font)
	field.add_theme_font_size_override("font_size", 16)
	return field

func _anniversary_form() -> void:
	view.heading("小院手记", "纪念日只保存在本机。支持公历和农历。")
	view.notebook_tabs("anniversaries")
	for event in anniversaries:
		var chosen: String = event.id
		var rule: String = "农历 " + String(event.lunar_day) if event.has("lunar_day") else String(event.get("month_day", event.get("date", "")))
		sheet_content.add_child(_label(String(event.title) + " · " + rule, 18))
		sheet_content.add_child(_button("删除这一条", func(): delete_anniversary_id = chosen; _open_sheet("delete_anniversary")))
	var name_field := _field("名称，例如生日", String(anniversary_draft.get("name", "")))
	name_field.set_meta("draft_key", "name")
	name_field.max_length = 24; sheet_content.add_child(name_field)
	name_field.text_changed.connect(func(value): anniversary_draft["name"] = value; draft_dirty = true)
	var calendar_choice := OptionButton.new()
	calendar_choice.set_meta("draft_key", "calendar")
	calendar_choice.add_theme_font_override("font", font); calendar_choice.add_theme_font_size_override("font_size", 17)
	calendar_choice.custom_minimum_size.y = 52
	for choice in ["公历 · 每年重复", "农历 · 每年普通月", "公历 · 指定日期", "农历 · 只在闰月"]: calendar_choice.add_item(choice)
	calendar_choice.selected = int(anniversary_draft.get("calendar", 0)); sheet_content.add_child(calendar_choice)
	calendar_choice.item_selected.connect(func(value): anniversary_draft["calendar"] = value; draft_dirty = true)
	var date_field := _field("日期 MM-DD 或 YYYY-MM-DD", String(anniversary_draft.get("date", "")))
	date_field.set_meta("draft_key", "date")
	sheet_content.add_child(date_field)
	date_field.text_changed.connect(func(value): anniversary_draft["date"] = value; draft_dirty = true)
	var tone_choice := OptionButton.new(); tone_choice.add_theme_font_override("font", font)
	tone_choice.set_meta("draft_key", "tone")
	tone_choice.custom_minimum_size.y = 52
	for choice in ["温暖庆祝", "安静纪念"]: tone_choice.add_item(choice)
	tone_choice.selected = int(anniversary_draft.get("tone", 0)); sheet_content.add_child(tone_choice)
	tone_choice.item_selected.connect(func(value): anniversary_draft["tone"] = value; draft_dirty = true)
	draft_error = _label("", 14, Color("aa5143")); draft_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_content.add_child(draft_error)
	sheet_content.add_child(_button("保存纪念日", func(): _save_anniversary(), true))

func _care(kind: String) -> void :
	duet.cancel(world,fish)
	if world.interact(kind):
		scene_effects.update_context(world.environment, world.festival, _today())
		if world.festival.get("tone", "") != "solemn": scene_effects.trigger(kind)
		_save()
		if kind in ["pet","wave"]: duet.touch(world,fish,"actor")
	_refresh_labels()

func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if sheet.visible: _back_sheet()
			elif quiet_mode: quiet_mode = false;_layout()
			return
		if sheet.visible: return
		if event.keycode == KEY_SPACE: _care("pet")
		if event.keycode == KEY_RIGHT:
			var index: int = Catalog.IDS.find(world.environment.id)
			set_demo(Catalog.IDS[(index + 1) % Catalog.IDS.size()])
		if event.keycode == KEY_LEFT:
			var index: int = Catalog.IDS.find(world.environment.id)
			set_demo(Catalog.IDS[posmod(index - 1, Catalog.IDS.size())])
		if event.keycode == KEY_D: _open_sheet("weather")
	if sheet.visible: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_start = event.position
			touch_time = Time.get_ticks_msec() / 1000.0
			touching = true
		elif touching:
			touching = false
			if actor.current_rect.has_point(touch_start):
				_care("pet" if Time.get_ticks_msec() / 1000.0 - touch_time > 0.35 or touch_start.y < actor.foot.y - actor.body_height * 0.6 else "wave")
			elif fish != null and fish.has_point(event.position):
				duet.cancel(world,fish)
				if fish.pet_fish():
					duet.touch(world,fish,"fish")
					if world.festival.get("tone", "") != "solemn": scene_effects.trigger("pet")
					_save()
				_refresh_labels()
			elif event.position.y > get_viewport_rect().size.y * 0.65:
				if not Catalog.is_rain(String(world.environment.id)):
					world.target_x = clampf(event.position.x / get_viewport_rect().size.x, 0.35, 0.72)
					world.direction = signf(world.target_x - world.x)
					world.queue.clear()
					world.start("walk", 12)

func _run_capture() -> void :
	await get_tree().create_timer(0.7).timeout
	var path: = "user://companion_shots"
	DirAccess.make_dir_recursive_absolute(path)
	for id in Catalog.IDS:
		set_demo(id)
		world.queue.clear()
		world.choose_activity()
		if id == "clear": world.start("idle", 20)
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path + "/" + id + ".png")
		print("SHOT ", id)
	_preview_festival(event_source.catalog.events[0])
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path + "/national_day.png")
	_open_sheet("festivals")
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path + "/festival_menu.png")
	print("COMPANION_CAPTURE_DONE ", ProjectSettings.globalize_path(path))
	get_tree().quit()


func _fish_wave_back() -> void:
	if world == null or fish == null: return
	duet.start(world,fish)

func _fish_library() -> void:
	var names: Array = fish.anim_info.keys()
	_heading("大肥鱼 · %d 个完整动作" % names.size(), "每天按时段与节日相伴。可以提前点播舞狮、月饼、粽子等动作。")
	sheet_content.add_child(_button("播放当前日期的双人节目", func(): duet.cancel(world,fish);fish.request_show(true);_close_sheet(), true))
	sheet_content.add_child(_button("回到今天 · 真实天气", _use_live))
	var nav := HBoxContainer.new()
	sheet_content.add_child(nav)
	var pages: int = maxi(1, ceili(names.size()/12.0))
	nav.add_child(_button("上一页", func(): fish_page = posmod(fish_page-1,pages);_open_sheet("fish_library")))
	nav.add_child(_label("%d / %d" % [fish_page+1,pages],14))
	nav.add_child(_button("下一页", func(): fish_page = (fish_page+1)%pages;_open_sheet("fish_library")))
	for i in range(fish_page*12,mini(names.size(),(fish_page+1)*12)):
		var id: String = names[i]
		var label: String = String(fish.anim_info[id].get("label",id))
		sheet_content.add_child(_button(label, func():
			duet.cancel(world,fish)
			set_demo("clear")
			festival_preview = true
			world.set_festival({"id":"fish_preview","title":"动作体验 · "+label,"caption":"回到今天可恢复日常节目","kind":"daily","tone":"gentle","actions":["idle"]})
			_refresh_labels()
			fish.preview_action(id)
			fish.steps = [{"id":id,"duration":float(fish.anim_info[id].get("duration",2.0))}]
			duet.start(world,fish,false)
			_close_sheet()))

func _apply_fish() -> void :
	if not fish_enabled: duet.cancel(world,fish)
	if fish != null: fish.enabled = fish_enabled
	_refresh_labels()

func _bind_world(next_world: RefCounted) -> void:
	world = next_world
	for participant in [actor, fish, effects, calendar_effects]:
		if participant != null: participant.world = world

func _begin_preview() -> void:
	if real_world != null: return
	duet.cancel(world, fish)
	real_world = world
	real_scene_effects = scene_effects
	real_effect_activity = effect_activity
	_bind_effect_director(SceneEffects.new())
	real_fish_memory = fish.memory.duplicate(true)
	var sample = World.new()
	sample.restore(world.save_data().duplicate(true))
	sample.environment = world.environment.duplicate(true)
	_bind_world(sample)

func _end_preview() -> void:
	if real_world == null: return
	duet.cancel(world, fish)
	_bind_world(real_world)
	_bind_effect_director(real_scene_effects)
	real_scene_effects = null
	effect_activity = real_effect_activity
	real_world = null
	fish.memory = real_fish_memory.duplicate(true)
	real_fish_memory.clear()
	if not live_data.is_empty(): world.set_environment(live_data)

func _real_journal() -> Array:
	return (real_world if real_world != null else world).journal

func _real_today() -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + int(live_data.get("utc_offset", 28800)))

func _target_key() -> String:
	return location_target_key if use_location else "manual:" + str(city_index)

func _bind_effect_director(director: RefCounted) -> void:
	scene_effects = director
	effects.director = director
	calendar_effects.director = director

func _back_sheet() -> void:
	if opened_sheet == "discard_draft": _open_sheet("anniversaries")
	elif opened_sheet in ["motion", "explore", "library", "updates", "licenses"]: _open_sheet("settings")
	elif opened_sheet in ["weather", "festivals", "festival_library"]: _open_sheet("explore")
	elif opened_sheet in ["fish_library", "effect_library"]: _open_sheet("library")
	elif opened_sheet == "delete_anniversary": _open_sheet("anniversaries")
	elif not opened_sheet.is_empty(): _close_sheet()
	elif quiet_mode: quiet_mode = false; _layout()

func _disable_home_focus() -> void:
	home_focus_modes.clear()
	for container in [top, bottom, quiet_exit, preview_button]:
		var controls: Array = container.find_children("*", "Control", true, false)
		controls.append(container)
		for control in controls:
			if control.focus_mode != Control.FOCUS_NONE:
				home_focus_modes[control] = control.focus_mode
				control.focus_mode = Control.FOCUS_NONE

func _restore_home_focus() -> void:
	for control in home_focus_modes:
		if is_instance_valid(control): control.focus_mode = home_focus_modes[control]
	home_focus_modes.clear()

func _focus_panel() -> void:
	var controls: Array[Control] = []
	for child in sheet_content.find_children("*", "Control", true, false):
		if child.focus_mode != Control.FOCUS_NONE and child.is_visible_in_tree(): controls.append(child)
	for index in range(controls.size()):
		controls[index].focus_next = controls[(index + 1) % controls.size()].get_path()
		controls[index].focus_previous = controls[posmod(index - 1, controls.size())].get_path()
	if not controls.is_empty(): controls[0].grab_focus()

func _finish_draft_exit() -> void:
	var target := draft_exit_target
	draft_exit_target = ""
	opened_sheet = ""
	if target.is_empty(): _close_sheet()
	else: _open_sheet(target)

func _save_anniversary(exit_after: bool = false) -> void:
	if opened_sheet == "anniversaries": _capture_anniversary_draft()
	if anniversaries.size() >= 64:
		_draft_failure("最多保存 64 个个人纪念日"); return
	var calendar := int(anniversary_draft.get("calendar", 0))
	var solemn := int(anniversary_draft.get("tone", 0)) == 1
	var event := {"id":"personal_" + str(Time.get_ticks_usec()), "title":String(anniversary_draft.get("name", "")).strip_edges(), "caption":"这一天，阿晴也记得。", "kind":"anniversary", "days":1, "priority":100, "tone":"solemn" if solemn else "joyful", "actions":["idle"] if solemn else ["celebrate_wave", "celebrate_cheer"], "effect":"candle_garland" if solemn else "heart_garland"}
	var key := "date" if calendar == 2 else ("lunar_day" if calendar in [1, 3] else "month_day")
	event[key] = String(anniversary_draft.get("date", "")).strip_edges()
	if calendar == 3: event.leap_month = true
	if not Events.valid_event(event):
		_draft_failure("请填写名称和有效日期；农历日期最大三十。"); return
	anniversaries.append(event); anniversary_draft.clear(); draft_dirty = false
	program_key = ""; _save(); _update_festival()
	if exit_after: _finish_draft_exit()
	else:
		opened_sheet = ""
		_open_sheet("anniversaries")

func _draft_failure(message: String) -> void:
	if opened_sheet == "discard_draft": _open_sheet("anniversaries")
	if is_instance_valid(draft_error): draft_error.text = message

func _delete_anniversary() -> void:
	anniversaries = anniversaries.filter(func(event): return event.id != delete_anniversary_id)
	delete_anniversary_id = ""; program_key = ""; _save(); _update_festival(); _open_sheet("anniversaries")

func _capture_anniversary_draft() -> void:
	for field in sheet_content.find_children("*", "Control", true, false):
		if not field.has_meta("draft_key"): continue
		anniversary_draft[field.get_meta("draft_key")] = field.text if field is LineEdit else field.selected
	draft_dirty = not String(anniversary_draft.get("name", "")).is_empty() or not String(anniversary_draft.get("date", "")).is_empty() or int(anniversary_draft.get("calendar", 0)) != 0 or int(anniversary_draft.get("tone", 0)) != 0

func _system_reduced_motion() -> bool:
	if OS.has_feature("ios") and location_plugin != null and location_plugin.has_method("reduced_motion"):
		return bool(location_plugin.reduced_motion())
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"): return false
	if not AndroidBridge.mutex.try_lock(): return system_reduced_motion
	var runtime = Engine.get_singleton("AndroidRuntime")
	var context = runtime.getApplicationContext()
	var result := system_reduced_motion
	if JavaClassWrapper.get_exception() == null and context != null:
		var global = JavaClassWrapper.wrap("android.provider.Settings$Global")
		if global != null:
			var scale = global.getFloat(context.getContentResolver(), "animator_duration_scale", 1.0)
			if JavaClassWrapper.get_exception() == null: result = float(scale) == 0.0
	AndroidBridge.mutex.unlock()
	return result
