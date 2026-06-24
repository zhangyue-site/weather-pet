class_name WeatherFX
extends Node2D

var _active_effect: String = ""
var _nodes: Array[CPUParticles2D] = []
var _overlay_color: Color = Color(0, 0, 0, 0)

var _weather_sim_index: int = 0
var _weather_sim_timer: float = 0.0
var _simulated_weather: String = "clear"
var _data: Node = null

func _ready():
	visible = false
	_data = get_node_or_null("/root/DataChannel")
	if _data:
		_data.weather_updated.connect(_on_weather_data)
	else:
		_simulated_weather = "clear"

func _on_weather_data(condition: String, _temperature: float, _humidity: float, _wind_speed: float):
	if condition != _active_effect:
		_switch(condition)

func _process(delta: float):
	_weather_sim_timer += delta
	if _data:
		var weather_data: Variant = _data.current_weather
		var condition := "clear"
		if typeof(weather_data) == TYPE_DICTIONARY:
			condition = String((weather_data as Dictionary).get("condition", "clear"))
		elif typeof(weather_data) == TYPE_STRING:
			condition = String(weather_data)
		if condition != _active_effect:
			_switch(condition)
	queue_redraw()

func _switch(weather: String):
	_clear()
	_active_effect = weather
	_overlay_color = Color(0, 0, 0, 0)
	match weather:
		"rain", "drizzle", "heavy_rain", "thunderstorm":
			_make_rain()
			if weather == "heavy_rain" or weather == "thunderstorm":
				_overlay_color = Color(0.05, 0.05, 0.12, 0.15)
			else:
				_overlay_color = Color(0.08, 0.08, 0.15, 0.08)
		"snow", "heavy_snow":
			_make_snow()
			_overlay_color = Color(0.8, 0.85, 0.95, 0.06)
		"fog", "haze":
			_make_fog()
			_overlay_color = Color(0.7, 0.7, 0.72, 0.12)
		"sandstorm":
			_make_sand()
			_overlay_color = Color(0.6, 0.5, 0.3, 0.1)
		_:
			pass

func _draw():
	if _overlay_color.a > 0.001:
		var vp := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, vp), _overlay_color, true)

func _make_rain():
	var n = CPUParticles2D.new()
	n.amount = 220
	n.lifetime = 0.7
	n.emitting = true
	n.direction = Vector2(0.05, 1)
	n.spread = 3.0
	n.gravity = Vector2(0, 900)
	n.initial_velocity_min = 280
	n.initial_velocity_max = 320
	n.scale_amount_min = 0.15
	n.scale_amount_max = 0.4
	# Gradient rain: from light blue to transparent
	n.color_ramp = _make_gradient_ramp([
		Color(0.5, 0.65, 0.85, 0.9),
		Color(0.4, 0.55, 0.75, 0.7),
		Color(0.3, 0.45, 0.65, 0.0)
	])
	n.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	n.emission_rect_extents = Vector2(250, 10)
	n.position = Vector2(0, -20)
	add_child(n)
	_nodes.append(n)

func _make_snow():
	var n = CPUParticles2D.new()
	n.amount = 90
	n.lifetime = 4.0
	n.emitting = true
	n.direction = Vector2(0, 1)
	n.spread = 50.0
	n.gravity = Vector2(0, 30)
	n.initial_velocity_min = 8
	n.initial_velocity_max = 25
	n.scale_amount_min = 0.3
	n.scale_amount_max = 1.0
	# Gradient snow: soft white with fade
	n.color_ramp = _make_gradient_ramp([
		Color(1, 1, 1, 0.95),
		Color(0.95, 0.97, 1.0, 0.8),
		Color(0.9, 0.93, 1.0, 0.0)
	])
	n.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	n.emission_rect_extents = Vector2(250, 10)
	n.position = Vector2(0, -20)
	# Add slight angular velocity for snowflake rotation
	n.angular_velocity_min = -90
	n.angular_velocity_max = 90
	add_child(n)
	_nodes.append(n)

func _make_fog():
	# Multiple fog layers for depth
	for i in range(3):
		var n = CPUParticles2D.new()
		n.amount = 12
		n.lifetime = 8.0 + i * 2.0
		n.emitting = true
		n.direction = Vector2(1, 0)
		n.spread = 25.0
		n.gravity = Vector2(0, 0)
		n.initial_velocity_min = 3 + i * 2
		n.initial_velocity_max = 8 + i * 3
		n.scale_amount_min = 20.0 + i * 8.0
		n.scale_amount_max = 35.0 + i * 10.0
		n.color_ramp = _make_gradient_ramp([
			Color(0.82, 0.84, 0.88, 0.25 - i * 0.05),
			Color(0.78, 0.8, 0.85, 0.15 - i * 0.03),
			Color(0.75, 0.77, 0.82, 0.0)
		])
		n.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		n.emission_rect_extents = Vector2(120, 60 + i * 20)
		n.position = Vector2(-100 + i * 50, i * 30)
		add_child(n)
		_nodes.append(n)

func _make_sand():
	var n = CPUParticles2D.new()
	n.amount = 120
	n.lifetime = 1.8
	n.emitting = true
	n.direction = Vector2(1, 0.1)
	n.spread = 15.0
	n.gravity = Vector2(80, 10)
	n.initial_velocity_min = 100
	n.initial_velocity_max = 150
	n.scale_amount_min = 0.4
	n.scale_amount_max = 1.2
	n.color_ramp = _make_gradient_ramp([
		Color(0.76, 0.68, 0.45, 0.8),
		Color(0.7, 0.62, 0.4, 0.5),
		Color(0.65, 0.58, 0.38, 0.0)
	])
	n.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	n.emission_rect_extents = Vector2(50, 120)
	n.position = Vector2(-250, 0)
	add_child(n)
	_nodes.append(n)

func _make_gradient_ramp(colors: Array[Color]) -> Gradient:
	var grad := Gradient.new()
	if colors.size() == 2:
		grad.set_color(0, colors[0])
		grad.set_color(1, colors[1])
	elif colors.size() >= 3:
		grad.set_color(0, colors[0])
		grad.set_color(1, colors[1])
		grad.add_point(1.0, colors[2])
	return grad

func _clear():
	for nd in _nodes:
		nd.queue_free()
	_nodes.clear()
	_active_effect = ""
