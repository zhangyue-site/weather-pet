extends Node2D
const Catalog = preload("res://companion/catalog.gd")
var world: RefCounted
var actor: Node2D
var dots: Array[Dictionary] = []
var hearts: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 23091
	for i in range(150): dots.append({"x":rng.randf(),"y":rng.randf(),"s":rng.randf_range(0.3,1.0),"phase":rng.randf_range(0,TAU)})

func affection() -> void:
	for i in range(6): hearts.append({"x":actor.foot.x + rng.randf_range(-45,45),"y":actor.foot.y-actor.body_height*0.75,"life":0.0,"phase":rng.randf_range(-1,1)})

func _process(delta: float) -> void:
	if world == null: return
	var id: String = world.environment.id
	for d in dots:
		d.y = fmod(d.y + delta * (0.70 if Catalog.is_rain(id) else 0.055) * d.s, 1.0)
		d.x = fposmod(d.x + delta * (0.15 if id == "windy" else 0.015) * d.s, 1.0)
	for h in hearts:
		h.life += delta
		h.y -= delta * 25
	hearts = hearts.filter(func(h): return h.life < 2.8)
	queue_redraw()

func _draw() -> void:
	if world == null: return
	var size := get_viewport_rect().size
	var id: String = world.environment.id
	var rain: bool = Catalog.is_rain(id)
	var snow: bool = Catalog.is_snow(id)
	var t: float = world.total_time
	if rain or snow:
		var count := 135 if id in ["heavy_rain", "heavy_snow", "thunderstorm"] else (45 if id == "drizzle" else 80)
		for i in range(count):
			var d: Dictionary = dots[i]
			var p := Vector2(d.x*size.x,d.y*size.y)
			var protected: bool = world.activity in ["umbrella", "open_umbrella"]
			# Match the character umbrella coverage and the illustrated cottage roof.
			if protected and absf(p.x-actor.foot.x)<actor.body_height*0.44 and p.y>actor.foot.y-actor.body_height*1.12 and p.y<actor.foot.y: continue
			if p.x<size.x*0.43 and p.y>size.y*0.45 and p.y<size.y*0.68: continue
			if rain:
				draw_line(p,p+Vector2(-3,15)*d.s,Color(0.80,0.90,1,0.42*d.s),1.1,true)
			else:
				p.x += sin(t + d.phase)*12
				draw_circle(p,1.4+2*d.s,Color(1,1,1,0.8))
		if rain:
			for i in range(14):
				var d: Dictionary = dots[i]
				var phase: float = fmod(t*1.5+d.phase,1.0)
				var p := Vector2(d.x*size.x, size.y*(0.70+0.18*d.s))
				draw_set_transform(p,0,Vector2(1,0.3))
				draw_arc(Vector2.ZERO,2+phase*10,0,TAU,20,Color(0.8,0.9,1,(1-phase)*0.35),1,true)
				draw_set_transform(Vector2.ZERO)
	if id == "windy":
		for i in range(24):
			var d: Dictionary = dots[i]
			var p := Vector2(d.x*size.x,(0.2+d.y*0.65)*size.y)
			draw_set_transform(p,sin(t+d.phase)*0.8,Vector2(1,0.35))
			draw_circle(Vector2.ZERO,4*d.s,Color(0.63,0.69,0.32,0.75))
			draw_set_transform(Vector2.ZERO)
	if id == "fog":
		for i in range(7):
			var y := size.y*(0.30+i*0.10)+sin(t*0.15+i)*18
			draw_set_transform(Vector2(size.x*0.5+sin(t*0.10+i)*60,y),0,Vector2(size.x/80,0.6))
			draw_circle(Vector2.ZERO,80,Color(0.85,0.9,0.92,0.075))
			draw_set_transform(Vector2.ZERO)
	if not bool(world.environment.is_day) and not rain and not snow:
		for i in range(18):
			var d: Dictionary = dots[i]
			var p := Vector2(d.x*size.x,(0.60+d.y*0.20)*size.y)
			draw_circle(p,2,Color(1,0.88,0.42,0.4+sin(t*1.3+d.phase)*0.3))
	if world.activity in ["cold", "drink", "sleep"]:
		for i in range(4):
			var phase: float = fmod(t*0.5+i*0.23,1)
			var p: Vector2 = actor.foot+Vector2(sin(t+i)*5,-actor.body_height*0.65-phase*30)
			draw_circle(p,2+phase*4,Color(1,1,1,(1-phase)*0.22))
	if world.wetness > 0.2 and not rain:
		for i in range(5):
			var phase: float = fmod(t*0.7+i*0.2,1)
			var p: Vector2 = actor.foot+Vector2((i-2)*12,-actor.body_height*0.5+phase*actor.body_height*0.5)
			draw_line(p,p+Vector2(0,3),Color(0.7,0.85,1,world.wetness*0.5),1,true)
	for h in hearts:
		var p := Vector2(h.x+sin(t*2+h.phase)*5,h.y)
		var c := Color(1,0.59,0.48,(1.0-h.life/2.8)*0.9)
		draw_circle(p+Vector2(-3,-2),4,c)
		draw_circle(p+Vector2(3,-2),4,c)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-6,0),p+Vector2(6,0),p+Vector2(0,8)]),c)
	if world.lightning > 0:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.84,0.91,1,world.lightning*0.55))
