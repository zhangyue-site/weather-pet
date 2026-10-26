extends Node2D
# 20 drawn motifs x 10 spatial choreographies. No downloaded executable content.
const Calendar = preload("res://companion/calendar_data.gd")
var world: RefCounted
var actor: Node2D
var reduced_motion := false
var override_id := ""
var director: RefCounted
# Exposes what the canvas actually submitted for scene diagnostics.
var last_frame_recipes: Array[Dictionary] = []

func recipes_for_draw() -> Array[Dictionary]:
	var recipes: Array[Dictionary] = []
	if not override_id.is_empty():
		var chosen := Calendar.effect(override_id)
		if not chosen.is_empty(): recipes.append(chosen)
		return recipes
	if director != null: return director.recipe()
	if world == null: return recipes
	var ids: Array = world.festival.get("effect_ids",[world.festival.get("effect","")])
	for id in ids.slice(0,2):
		var chosen := Calendar.effect(String(id))
		if not chosen.is_empty(): recipes.append(chosen)
	return recipes

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	last_frame_recipes.clear()
	if world == null or actor == null: return
	var recipes := recipes_for_draw()
	last_frame_recipes = recipes.duplicate(true)
	for layer in range(recipes.size()):
		_recipe(recipes[layer],layer)

func _recipe(recipe: Dictionary, layer: int) -> void:
	var screen := get_viewport_rect().size
	var center: Vector2 = actor.foot-Vector2(0,actor.body_height*0.65)
	var static_pose: bool = reduced_motion or bool(recipe.get("static",false))
	var t: float = 0.8 if static_pose else float(recipe.get("clock",world.total_time))*float(recipe.speed)
	var count: int = mini(5,int(recipe.count)) if static_pose else int(recipe.count)
	var raining: bool = String(world.environment.id) in ["drizzle","rain","heavy_rain","thunderstorm"]
	if raining: count = maxi(4,count/2)
	var quiet: bool = world.festival.get("tone", "") == "solemn" or not bool(world.environment.is_day)
	if quiet: count = mini(count,8)
	var scale_unit: float = minf(screen.x/540.0,screen.y/960.0)
	for i in range(count):
		var seed: float = fposmod(float(i)*0.6180339887+layer*0.17,1.0)
		var phase: float = fposmod(t*0.13+float(i)/count,1.0)
		var a: float = TAU*float(i)/count
		var p := Vector2.ZERO
		var opacity := 0.8
		var rotation := sin(t+i)*0.3
		match String(recipe.motion):
			"drift":
				p = Vector2((0.08+seed*0.84)*screen.x+sin(t+i)*18,screen.y*(0.28+phase*0.47))
				opacity *= sin(phase*PI)
			"rise":
				p = Vector2((0.08+seed*0.84)*screen.x+sin(t+i)*12,screen.y*(0.78-phase*0.46))
				opacity *= sin(phase*PI)
			"orbit":
				p = center+Vector2(cos(a+t*0.4)*125,sin(a+t*0.4)*90)*scale_unit
			"spiral":
				p = center+Vector2(cos(a+t)*140*phase,-170*phase+70)*scale_unit
				opacity *= 1.0-phase*0.6
			"fountain":
				p = actor.foot+Vector2((seed-0.5)*310*phase,-310*phase+235*phase*phase)*scale_unit
				opacity *= 1.0-phase
			"burst":
				p = Vector2(screen.x*(0.28+layer*0.4),screen.y*0.40)+Vector2(cos(a),sin(a))*phase*150*scale_unit
				opacity *= 1.0-phase
			"wave":
				p = Vector2(screen.x*(0.08+seed*0.84),screen.y*(0.42+0.09*sin(seed*TAU+t)))
				rotation = sin(seed*TAU+t)*0.6
			"cascade":
				p = Vector2(screen.x*(0.1+float(i%5)*0.2),screen.y*(0.29+phase*0.48))
				opacity *= sin(phase*PI)
			"garland":
				p = Vector2(screen.x*(0.07+float(i)/maxi(count-1,1)*0.86),screen.y*0.32+sin(float(i)/maxi(count-1,1)*PI)*42)
				rotation = sin(t*0.5+i)*0.15
			"trail":
				p = Vector2(screen.x*(0.1+phase*0.8),screen.y*(0.63-phase*0.27)+sin(phase*TAU+t)*18)
				opacity *= sin(phase*PI)
		# Director local effects stay low beside the actors, clear of faces and UI.
		if recipe.get("local",false):
			p = actor.foot+Vector2((seed-0.5)*180,-20-phase*75)*scale_unit
			opacity *= 0.8
		opacity *= float(recipe.get("opacity",1.0))
		# Keep weather legible and the character face clear.
		if raining: opacity *= 0.48
		if quiet: opacity *= 0.65
		if p.distance_to(center)<40*scale_unit: opacity *= 0.3
		var c := Color(String(recipe.colors[i%2]))
		c.a = maxf(0,opacity)
		var size: float = float(recipe.size)*scale_unit*(0.7+seed*0.7)
		draw_set_transform(p,rotation,Vector2.ONE*size)
		_symbol(String(recipe.family),c,t+i)
		draw_set_transform(Vector2.ZERO)

func _ellipse(center: Vector2, rx: float, ry: float, angle: float, c: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a: float = TAU*i/24.0
		points.append(center+Vector2(cos(a)*rx,sin(a)*ry).rotated(angle))
	draw_colored_polygon(points,c)

func _star(radius: float, c: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		points.append(Vector2.from_angle(-PI/2+i*PI/5)*(radius if i%2==0 else radius*0.42))
	draw_colored_polygon(points,c)

func _symbol(family: String, c: Color, t: float) -> void:
	var bright := c.lightened(0.3)
	var dark := c.darkened(0.28)
	match family:
		"lantern":
			_ellipse(Vector2.ZERO,1.25,1.5,0,c)
			draw_arc(Vector2.ZERO,0.9,-PI/2,PI/2,12,bright,0.14,true)
			draw_line(Vector2(-0.6,-1.4),Vector2(0.6,-1.4),dark,0.25,true)
			draw_line(Vector2(0,1.4),Vector2(0,2.2),bright,0.17,true)
		"firework":
			for j in range(10):
				var v := Vector2.from_angle(TAU*j/10.0)
				draw_line(v*0.6,v*2.0,c,0.18,true)
				draw_circle(v*2.3,0.15,bright)
		"confetti":
			draw_rect(Rect2(-0.55,-1.3,1.1,2.6),c)
			draw_line(Vector2(-0.5,-0.6),Vector2(0.5,0.1),bright,0.16,true)
		"ribbon":
			var points := PackedVector2Array()
			for j in range(14): points.append(Vector2(j*0.35-2.2,sin(j*0.6+t)*0.6))
			draw_polyline(points,c,0.4,true)
		"blossom":
			for j in range(5):
				var v := Vector2.from_angle(TAU*j/5.0)
				_ellipse(v*0.85,0.8,0.45,TAU*j/5.0,c)
			draw_circle(Vector2.ZERO,0.3,bright)
		"leaf":
			_ellipse(Vector2.ZERO,0.65,1.6,0.4,c)
			draw_line(Vector2(0.6,-1.4),Vector2(-0.6,1.4),dark,0.12,true)
		"snowflake":
			for j in range(6):
				var v := Vector2.from_angle(TAU*j/6.0)
				draw_line(Vector2.ZERO,v*1.8,c,0.15,true)
				for side in [-1,1]: draw_line(v*1.1,v*1.3+v.rotated(side*PI/2)*0.4,c,0.12,true)
		"star": _star(1.65,c)
		"heart":
			draw_circle(Vector2(-0.55,-0.35),0.72,c)
			draw_circle(Vector2(0.55,-0.35),0.72,c)
			draw_colored_polygon(PackedVector2Array([Vector2(-1.16,0),Vector2(1.16,0),Vector2(0,1.4)]),c)
		"butterfly":
			var wing: float = 0.45+absf(sin(t*3))*0.7
			_ellipse(Vector2(-0.7,0),wing,1.25,-0.3,c)
			_ellipse(Vector2(0.7,0),wing,1.25,0.3,c)
			draw_line(Vector2(0,-0.7),Vector2(0,0.8),dark,0.18,true)
		"bubble":
			draw_arc(Vector2.ZERO,1.5,0,TAU,28,c,0.16,true)
			draw_arc(Vector2(-0.12,-0.12),1.05,PI,PI*1.5,8,bright,0.25,true)
		"firefly":
			draw_circle(Vector2.ZERO,1.6,Color(c,c.a*0.14))
			draw_circle(Vector2.ZERO,0.8,Color(c,c.a*0.3))
			draw_circle(Vector2.ZERO,0.32,bright)
		"raindrop":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-1.6),Vector2(0.7,0.15),Vector2(-0.7,0.15)]),c)
			draw_circle(Vector2(0,0.3),0.7,c)
			draw_circle(Vector2(-0.2,0.2),0.16,bright)
		"steam":
			var points := PackedVector2Array()
			for j in range(12): points.append(Vector2(sin(j*0.5+t)*0.4,-j*0.3))
			draw_polyline(points,c,0.18,true)
		"cloud":
			_ellipse(Vector2(0,0.4),2.0,0.6,0,c)
			draw_circle(Vector2(-0.8,0),0.7,c)
			draw_circle(Vector2(0.2,-0.3),1.0,c)
			draw_circle(Vector2(1.1,0.1),0.65,c)
		"sun":
			draw_circle(Vector2.ZERO,0.85,c)
			for j in range(8):
				var v := Vector2.from_angle(TAU*j/8.0+t*0.15)
				draw_line(v*1.15,v*1.65,c,0.17,true)
		"moon":
			# Crescent assembled as a non-self-intersecting outline.
			var points := PackedVector2Array()
			for j in range(25):
				var a := PI/2+PI*j/24.0
				points.append(Vector2(cos(a),sin(a))*1.5)
			for j in range(25):
				var a := -PI/2-PI*j/24.0
				points.append(Vector2(cos(a)*0.65,sin(a)*1.5))
			draw_colored_polygon(points,c)
		"kite":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-1.5),Vector2(1,0),Vector2(0,1.5),Vector2(-1,0)]),c)
			draw_line(Vector2(0,-1.4),Vector2(0,1.4),bright,0.12,true)
			draw_polyline(PackedVector2Array([Vector2(0,1.5),Vector2(0.5,2.2),Vector2(0.1,3)]),c,0.1,true)
		"music":
			_ellipse(Vector2(-0.3,0.7),0.55,0.35,-0.4,c)
			draw_line(Vector2(0.2,0.65),Vector2(0.2,-1.5),c,0.18,true)
			draw_line(Vector2(0.2,-1.5),Vector2(1.1,-1.0),c,0.3,true)
		"lotus":
			for j in range(5): _ellipse(Vector2((j-2)*0.4,0),0.4,1.25,(j-2)*0.35,c)
			_ellipse(Vector2(0,0.7),1.8,0.3,0,dark)
		"candle":
			draw_rect(Rect2(-0.45,-0.25,0.9,1.65),c)
			_ellipse(Vector2(0,-0.95),0.4,0.7,0,bright)
			draw_line(Vector2(-0.7,1.4),Vector2(0.7,1.4),dark,0.2,true)
