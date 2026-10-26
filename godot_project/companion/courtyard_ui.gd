extends RefCounted
# Shared presentation for iOS and Android; scene behavior remains in main.gd.
var app: Node

func label(text: String, size: int = 18, color: Color = Color("293e42")) -> Label:
	return app._label(text, size, color)

func button(text: String, callback: Callable, primary: bool = false) -> Button:
	return app._button(text, callback, primary)

func build() -> void:
	var layer := CanvasLayer.new(); layer.layer = 10; app.add_child(layer)
	app.ui = Control.new(); app.ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(app.ui)
	app.top = Control.new(); app.top.mouse_filter = Control.MOUSE_FILTER_IGNORE; app.ui.add_child(app.top)
	app.city_button = button("选择城市  ›", func(): app._open_sheet("city"))
	app.city_button.name = "CityButton"; app.top.add_child(app.city_button)
	var settings := button("设置", func(): app._open_sheet("settings"))
	settings.text = ""; settings.icon = icon("gear"); settings.tooltip_text = "小院设置"
	settings.name = "SettingsButton"; app.top.add_child(settings)
	app.title_label = label("", 12); app.title_label.hide(); app.top.add_child(app.title_label)
	app.weather_label = home_label("--°", 76)
	app.details_label = home_label("正在获取天气", 22)
	app.weather_meta = home_label("", 16)
	app.source_label = home_label("", 13)
	app.location_label = home_label("", 13)
	app.clock_label = home_label("", 12); app.clock_label.hide()
	app.calendar_label = label("", 14, app.INK)
	app.date_chip = PanelContainer.new()
	app.date_chip.add_theme_stylebox_override("panel", app._style(Color("fffaf0ed"), 14))
	app.date_chip.add_child(app.calendar_label); app.top.add_child(app.date_chip)
	app.festival_label = home_label("", 14); app.festival_label.hide()
	app.preview_button = button("体验场景 · 回到今天", func(): app._use_live(), true)
	app.preview_button.name = "ReturnToday"; app.ui.add_child(app.preview_button); app.preview_button.hide()
	app.bottom = PanelContainer.new()
	app.bottom.add_theme_stylebox_override("panel", StyleBoxEmpty.new()); app.ui.add_child(app.bottom)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 12); app.bottom.add_child(box)
	var caption := PanelContainer.new(); caption.add_theme_stylebox_override("panel", app._style(Color("fffaf0f2"), 20))
	box.add_child(caption)
	app.caption_label = label("今天也在小院里陪你", 17)
	app.caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; caption.add_child(app.caption_label)
	app.status_label = label(""); app.status_label.hide(); box.add_child(app.status_label)
	app.bond_label = label(""); app.bond_label.hide(); box.add_child(app.bond_label)
	var actions := HBoxContainer.new(); actions.name = "HomeActions"
	actions.add_theme_constant_override("separation", 12); box.add_child(actions)
	var care := button("陪一会儿", func(): app._open_sheet("care"), true)
	care.icon = icon("cup", "ffffff")
	care.custom_minimum_size.y = 62; actions.add_child(care)
	var notebook := button("小院手记", func(): app._open_sheet("journal"))
	notebook.icon = icon("book")
	notebook.custom_minimum_size.y = 62; actions.add_child(notebook)
	app.quiet_exit = button("退出观赏", func(): app.quiet_mode = false; app._layout())
	app.quiet_exit.name = "QuietExit"; app.ui.add_child(app.quiet_exit); app.quiet_exit.hide()
	app.shade = ColorRect.new(); app.shade.color = Color(0.04, 0.10, 0.12, 0.33)
	app.shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed: app._close_sheet())
	app.ui.add_child(app.shade); app.shade.hide()
	app.sheet = PanelContainer.new(); app.sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	app.sheet.add_theme_stylebox_override("panel", app._style(app.CREAM, 26)); app.ui.add_child(app.sheet)
	app.sheet_scroll = ScrollContainer.new(); app.sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	app.sheet.add_child(app.sheet_scroll)
	app.sheet_content = VBoxContainer.new(); app.sheet_content.add_theme_constant_override("separation", 18)
	app.sheet_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.sheet_scroll.add_child(app.sheet_content); app.sheet.hide()

func home_label(text: String, size: int) -> Label:
	var result := label(text, size, Color.WHITE)
	result.add_theme_color_override("font_shadow_color", Color(0.02, 0.10, 0.12, 0.65))
	result.add_theme_constant_override("shadow_offset_y", 1)
	app.top.add_child(result); return result

func layout() -> void:
	var size: Vector2 = app.get_viewport_rect().size
	var insets := Vector2.ZERO
	if OS.has_feature("ios") or OS.has_feature("android"):
		var pixels := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if pixels.y > 0 and safe.size.y > 0:
			insets = Vector2(maxf(0, safe.position.y), maxf(0, pixels.y - safe.end.y)) * size.y / pixels.y
	var margin := maxf(20, size.x * 0.055)
	app.top.position = Vector2(0, insets.x); app.top.size = size
	app.city_button.position = Vector2(margin, 20)
	app.city_button.size = Vector2(minf(size.x - margin * 2 - 88, 220), 48)
	app.city_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var settings: Button = app.top.get_node("SettingsButton")
	settings.position = Vector2(size.x - margin - 76, 20); settings.size = Vector2(76, 48)
	app.weather_label.position = Vector2(margin, 82)
	app.details_label.position = Vector2(margin + 2, 180)
	app.details_label.size = Vector2(size.x - margin * 2, 32)
	app.weather_meta.position = Vector2(margin + 2, 218)
	app.source_label.position = Vector2(margin + 2, 249)
	app.source_label.size.x = size.x - margin * 2
	app.source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	app.location_label.position = Vector2(margin + 2, 278)
	app.location_label.size = Vector2(size.x - margin * 2, 24)
	app.location_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	app.date_chip.position = Vector2(margin, 314)
	app.date_chip.size = Vector2(minf(size.x - margin * 2, 330), 46)
	app.calendar_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	app.preview_button.position = Vector2(margin, insets.x + (80 if app.quiet_mode else 375)); app.preview_button.size = Vector2(size.x - margin * 2, 48)
	app.preview_button.visible = app.mode == "demo"
	app.bottom.position = Vector2(margin, size.y - 159 - insets.y)
	app.bottom.size = Vector2(size.x - margin * 2, 135)
	app.top.visible = not app.quiet_mode; app.bottom.visible = not app.quiet_mode
	app.quiet_exit.visible = app.quiet_mode
	app.quiet_exit.position = Vector2(size.x - margin - 136, insets.x + 20)
	app.quiet_exit.size = Vector2(136, 48)
	var full: bool = app.opened_sheet not in ["care", "city", "discard_draft", "delete_anniversary"]
	if full:
		app.sheet.position = Vector2(0, insets.x)
		app.sheet.size = Vector2(size.x, size.y - insets.x - insets.y)
	else:
		var height := minf(size.y * 0.43, 460) if app.opened_sheet == "care" else minf(size.y * 0.68, 620)
		app.sheet.position = Vector2(10, size.y - height - insets.y)
		app.sheet.size = Vector2(size.x - 20, height)
	app.sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

func heading(title: String, subtitle: String = "") -> void:
	var row := HBoxContainer.new(); app.sheet_content.add_child(row)
	var back := button("‹", func(): app._back_sheet()); back.custom_minimum_size = Vector2(48, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; row.add_child(back)
	var name := label(title, 27); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; row.add_child(name)
	var close := button("×", func(): app._close_sheet()); close.custom_minimum_size = Vector2(48, 48)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END; row.add_child(close)
	if not subtitle.is_empty():
		var sub := label(subtitle, 15, app.MUTED); sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		app.sheet_content.add_child(sub)

func section(text: String) -> void:
	app.sheet_content.add_child(label(text, 16, app.TEAL))

func row(text: String, callback: Callable, hint: String = "") -> void:
	var item := button(text + "  ›", callback); item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 64; app.sheet_content.add_child(item)
	if not hint.is_empty():
		var sub := label(hint, 13, app.MUTED); sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		app.sheet_content.add_child(sub)

func toggle(text: String, value: bool, callback: Callable) -> void:
	var check := CheckButton.new(); check.text = text; check.button_pressed = value
	check.custom_minimum_size.y = 64; check.add_theme_font_override("font", app.font)
	check.add_theme_font_size_override("font_size", 19); check.add_theme_color_override("font_color", app.INK)
	for state in ["font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		check.add_theme_color_override(state, app.INK)
	check.add_theme_icon_override("checked", switch_icon(true))
	check.add_theme_icon_override("unchecked", switch_icon(false))
	check.toggled.connect(callback); app.sheet_content.add_child(check)

func switch_icon(enabled: bool) -> Texture2D:
	var fill := "347c7e" if enabled else "9b9f98"
	var x := 35 if enabled else 15
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="50" height="30"><rect x="1" y="1" width="48" height="28" rx="14" fill="#%s"/><circle cx="%d" cy="15" r="11" fill="#fffaf0"/></svg>' % [fill, x]
	var image := Image.new(); image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

func icon(kind: String, color: String = "293e42") -> Texture2D:
	var path := ""
	match kind:
		"gear": path = '<circle cx="12" cy="12" r="4"/><path d="m10 2 4 0 1 3 3 1 3-1 2 4-2 2 0 3 2 2-2 4-3-1-3 1-1 3-4 0-1-3-3-1-3 1-2-4 2-2 0-3-2-2 2-4 3 1 3-1z" transform="translate(1 0) scale(.85)"/>'
		"cup": path = '<path d="M4 8h13v8a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5zm13 1h2a3 3 0 0 1 0 6h-2M7 2v3m4-4v4m4-3v3"/>'
		"book": path = '<rect x="5" y="2" width="15" height="20" rx="3"/><path d="M9 2v20m3-14h5m-5 4h5m-5 4h3"/>'
		"hand": path = '<path d="M7 13V6a2 2 0 0 1 4 0v6-9a2 2 0 0 1 4 0v9-6a2 2 0 0 1 4 0v8c0 5-3 8-7 8-3 0-5-2-7-5l-2-3a2 2 0 0 1 3-2l2 2"/>'
		"moon": path = '<path d="M20 15A9 9 0 0 1 9 3a9 9 0 1 0 11 12z"/>'
		_: path = '<path d="M3 5h18v13H9l-5 3v-3H3zM7 10h1m3 0h1m3 0h1"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [color, path]
	var image := Image.new(); image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

func notebook_tabs(active: String) -> void:
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8)
	app.sheet_content.add_child(tabs)
	tabs.add_child(button("日记", func(): app._open_sheet("journal"), active == "journal"))
	tabs.add_child(button("纪念日", func(): app._open_sheet("anniversaries"), active == "anniversaries"))

func panel(kind: String) -> bool:
	match kind:
		"care":
			heading("陪一会儿", "点点阿晴，也能打个招呼。")
			var grid := GridContainer.new(); grid.columns = 2
			grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 14)
			app.sheet_content.add_child(grid)
			for entry in [["摸摸头", "pet"], ["打招呼", "wave"], ["喝热饮", "drink"], ["休息一下", "sleep"]]:
				var action: String = entry[1]
				var item := button(entry[0], func(): app._care(action); app._close_sheet())
				item.icon = icon({"pet":"hand", "wave":"chat", "drink":"cup", "sleep":"moon"}.get(action, "chat"))
				item.custom_minimum_size.y = 78; grid.add_child(item)
			var note := label("回应会留下今天的一条小记。", 14, app.MUTED)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; app.sheet_content.add_child(note)
		"city":
			heading("小院在哪里", "取消不会改变当前城市。定位失败时保留手动城市。")
			app.sheet_content.add_child(button("使用当前位置", func(): app.use_location = true; app._save(); app._use_live(), app.use_location))
			var grid := GridContainer.new(); grid.columns = 3
			grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 10)
			app.sheet_content.add_child(grid)
			for index in range(app.Catalog.CITIES.size()):
				var selected: int = index
				grid.add_child(button(app.Catalog.CITIES[index].name, func(): app.city_index = selected; app.use_location = false; app._save(); app._use_live(), index == app.city_index and not app.use_location))
			app.sheet_content.add_child(button("刷新天气 / 重试定位", func(): app._use_live()))
		"journal":
			heading("小院手记", "和阿晴、大肥鱼一起")
			notebook_tabs("journal")
			section("今天 · " + app._real_today().substr(5).replace("-", "月") + "日")
			if app.world.journal.is_empty():
				app.sheet_content.add_child(label("今天会留下第一件小事。", 18, app.MUTED))
			for entry in app._real_journal():
				if not entry is Dictionary or not entry.has("text"): continue
				var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", app._style(Color("f5f1e8"), 20))
				var content := VBoxContainer.new(); content.add_theme_constant_override("separation", 8); card.add_child(content)
				content.add_child(label(String(entry.get("time", "")), 13, app.MUTED))
				var text := label(String(entry.text), 19); text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				content.add_child(text); app.sheet_content.add_child(card)
			section("今天的小院")
			var program: Dictionary = app.Events.program(app.event_source.catalog, app._real_today(), app.anniversaries)
			var theme := label(String(program.get("title", "平常的日子也很好")), 18)
			theme.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; app.sheet_content.add_child(theme)
		"settings":
			heading("小院设置")
			section("小院偏好")
			toggle("大肥鱼住在小院", app.fish_enabled, func(value): app.fish_enabled = value; app._save(); app._apply_fish())
			row("动态效果", func(): app._open_sheet("motion"), "跟随天气与节日 · " + ("减少动态" if app.reduced_motion else "自动"))
			toggle("安静观赏", app.quiet_mode, func(value): app.quiet_mode = value; app._close_sheet(); app._layout())
			section("场景探索")
			row("天气与节日体验", func(): app._open_sheet("explore"))
			row("动作与特效图鉴", func(): app._open_sheet("library"), "预览不会改变真实天气和陪伴记录")
			section("关于")
			row("应用更新", func(): app._open_sheet("updates"))
			row("数据来源与开源许可", func(): app._open_sheet("licenses"))
			app.sheet_content.add_child(label("Godot · iOS / Android · " + str(ProjectSettings.get_setting("application/config/version", "")), 13, app.MUTED))
		"motion":
			heading("动态效果", "天气、互动和节日按场景呈现；夜间和低电量时自动减少。")
			toggle("背景微动", app.ambience_enabled, func(value): app.ambience_enabled = value; app._save())
			toggle("减少动态效果", app.reduced_motion, func(value): app.reduced_motion = value; app._save())
			app.sheet_content.add_child(label("系统的减少动态设置优先；关闭上面的开关不会覆盖系统偏好。", 15, app.MUTED))
		"explore":
			heading("天气与节日体验", "这里使用示例场景，不改变真实天气，也不写入真实日记。")
			row("看看不同天气", func(): app._open_sheet("weather"))
			row("节日与节气", func(): app._open_sheet("festival_library"))
			row("看看指定日期", func(): app._open_sheet("festivals"))
			app.sheet_content.add_child(button("回到今天 · 真实天气", func(): app._use_live(), true))
		"library":
			heading("动作与特效图鉴", "按实际场景分组；预览不会消耗真实节目次数。")
			row("阿晴与大肥鱼的动作", func(): app._open_sheet("fish_library"))
			row("场景特效", func(): app._open_sheet("effect_library"))
		"discard_draft":
			heading("纪念日还没有保存", "选择保存、丢弃，或继续编辑。")
			app.sheet_content.add_child(button("保存后离开", func(): app._save_anniversary(true), true))
			app.sheet_content.add_child(button("丢弃修改", func(): app.anniversary_draft = {}; app.draft_dirty = false; app._finish_draft_exit()))
			app.sheet_content.add_child(button("继续编辑", func(): app._open_sheet("anniversaries")))
		"delete_anniversary":
			heading("删除这个纪念日？", "只删除当前纪念日，不删除已经留下的日记。")
			app.sheet_content.add_child(button("取消", func(): app._open_sheet("anniversaries"), true))
			app.sheet_content.add_child(button("删除纪念日", func(): app._delete_anniversary()))
		_:
			return false
	return true
