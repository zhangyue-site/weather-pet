extends RefCounted
# One simulation clock, driven only by the scene. No child _process double tick.
const Catalog = preload("res://companion/catalog.gd")
var environment: Dictionary = Catalog.preset("clear")
var activity := "idle"
var activity_time := 0.0
var activity_duration := 5.0
var queue: Array[Dictionary] = []
var wetness := 0.0
var energy := 78.0
var joy := 75.0
var bond := 0
var x := 0.57
var target_x := 0.57
var direction := 1.0
var total_time := 0.0
var thunder_in := 5.0
var lightning := 0.0
var journal: Array = []
var discovered: Array = []
var care_cooldown := 0.0
var puddle := 0.0
var rng := RandomNumberGenerator.new()
var status := "在小院里等你"
var last_day := ""
var festival: Dictionary = {}
var festival_cooldown := 0.0
var festival_index := 0

func _init() -> void:
	rng.randomize()

func set_festival(event: Dictionary) -> void:
	if event.get("id", "") == festival.get("id", ""): 
		festival = event.duplicate(true)
		return
	festival = event.duplicate(true)
	festival_cooldown = 0.0
	festival_index = 0
	if activity.begins_with("celebrate_"):
		queue.clear()
		choose_activity()
	if not festival.is_empty(): add_note(String(festival.title) + ("，又是一起的一天" if festival.get("kind", "") == "daily" else "，今天一起记住"))

func celebrate() -> bool:
	if festival.is_empty(): return false
	if Catalog.is_rain(String(environment.id)) or not bool(environment.is_day) or energy < 18 or float(environment.feels) < 0 or float(environment.feels) > 32 or environment.id in ["windy", "snow", "heavy_snow"]: return false
	var actions: Array = festival.actions
	var action: String = actions[festival_index % actions.size()]
	if festival.get("tone", "") == "solemn": action = "idle"
	if action == "walk":
		target_x = rng.randf_range(0.38,0.70)
		direction = signf(target_x-x)
	start(action, 6.0)
	festival_index += 1
	festival_cooldown = 40.0
	return true

func add_note(note: String) -> void:
	if not journal.is_empty() and String(journal[0].text) == note: return
	journal.push_front({"text": note, "time": Time.get_datetime_string_from_system(false, true).substr(5, 11)})
	if journal.size() > 30: journal.resize(30)

func set_environment(e: Dictionary) -> void:
	var old: String = environment.id
	environment = e.duplicate(true)
	var id: String = environment.id
	if not discovered.has(id):
		discovered.append(id)
		add_note("一起遇见了" + Catalog.preset(id).title)
	if old == id:
		return
	queue.clear()
	if Catalog.is_rain(id) and not Catalog.is_rain(old):
		sequence([["notice", 1.8], ["take_umbrella", 1.2], ["open_umbrella", 0.8], ["umbrella", 8.0]])
	elif Catalog.is_rain(old) and not Catalog.is_rain(id):
		sequence([["umbrella", 1.1], ["open_umbrella", 0.7], ["shake", 2.5]])
		add_note("雨停了，甩甩伞上的水")
	else:
		choose_activity()

func sequence(steps: Array) -> void:
	queue.clear()
	for step in steps: queue.append({"name": step[0], "duration": step[1]})
	next_action()

func start(name: String, duration: float) -> void:
	activity = name
	activity_time = 0.0
	activity_duration = duration
	status = {"idle":"发会儿呆，也很好", "blink":"眯起眼睛笑了", "wave":"看到你就开心", "stretch":"伸个懒腰，慢慢来", "notice":"咦，好像下雨了", "take_umbrella":"把小伞拿出来", "open_umbrella":"撑开伞，别淋湿啦", "umbrella":"伞下的小小世界", "shake":"雨停啦，甩掉水珠", "cold":"围巾裹紧一点", "hot":"扇扇风，慢一点", "wind":"呼——抓紧衣角", "snow":"雪花落在手心里", "scared":"刚才的雷有点响", "drink":"捧着杯子暖暖手", "sleep":"呼吸慢下来，睡一会儿", "walk":"在小院里散散步", "pet":"喜欢你轻轻摸我的头", "water":"看看小植物长大了没有"}.get(name, "和你待在一起")

	if name.begins_with("celebrate_"): status = String(festival.get("title", "一起庆祝"))

func next_action() -> void:
	if queue.is_empty():
		choose_activity()
	else:
		var s: Dictionary = queue.pop_front()
		start(s.name, float(s.duration))

func choose_activity() -> void:
	var id: String = environment.id
	if Catalog.is_rain(id): start("umbrella", rng.randf_range(7, 12))
	elif id == "cold" or float(environment.feels) < 0.0: start("cold", 8)
	elif Catalog.is_snow(id): start("snow" if rng.randf() > 0.4 else "cold", 7)
	elif id == "hot" or float(environment.feels) > 32.0: start("hot" if rng.randf() > 0.3 else "drink", 8)
	elif id == "windy": start("wind", 8)
	elif not bool(environment.is_day) or energy < 18.0: start("sleep", 12)
	elif festival_cooldown <= 0 and celebrate(): pass
	else:
		var options := ["idle", "idle", "stretch", "walk", "water", "drink"]
		var a: String = options[rng.randi_range(0, options.size() - 1)]
		if a == "walk":
			target_x = rng.randf_range(0.38, 0.70)
			direction = signf(target_x - x)
		start(a, rng.randf_range(5, 9))

func interact(kind: String) -> bool:
	if care_cooldown > 0.0: return false
	care_cooldown = 4.0
	bond += 1
	joy = minf(100.0, joy + 3.0)
	if Catalog.is_rain(String(environment.id)):
		# Keep hands on the umbrella and preserve unfinished opening sequence.
		status = "握好伞，也想和你打个招呼"
		add_note("雨里也有你的陪伴")
		return true
	queue.clear()
	if activity == "sleep" and kind == "pet":
		start("blink", 1.8)
		queue.append({"name":"sleep", "duration":10.0})
	else:
		start(kind, 5.0 if kind != "sleep" else 25.0)
	if kind == "drink": energy = minf(100, energy + 6)
	add_note({"pet":"被你轻轻摸了摸头", "wave":"和你打了个招呼", "drink":"一起喝了一杯热饮", "sleep":"你陪我安静休息", "water":"一起看了看小植物"}.get(kind, "今天又多了一点陪伴"))
	return true

func step(delta: float) -> void:
	var dt: float = clampf(delta, 0.0, 0.1)
	total_time += dt
	festival_cooldown = maxf(0, festival_cooldown - dt)
	activity_time += dt
	care_cooldown = maxf(0, care_cooldown - dt)
	lightning = maxf(0, lightning - dt * 2.5)
	var raining: bool = Catalog.is_rain(String(environment.id))
	var protected: bool = activity in ["umbrella", "open_umbrella"]
	wetness = clampf(wetness + dt * ((0.002 if protected else 0.04) if raining else -0.015), 0, 1)
	puddle = clampf(puddle + dt * (0.045 if raining else -0.008), 0, 1)
	energy = clampf(energy + dt * (0.30 if activity == "sleep" else -0.015), 0, 100)
	joy = maxf(45, joy - dt * 0.002)
	if activity == "walk":
		x = move_toward(x, target_x, dt * 0.022)
		if absf(x - target_x) < 0.003: start("idle", 4.0)
	if activity_time >= activity_duration: next_action()
	if environment.id == "thunderstorm":
		thunder_in -= dt
		if thunder_in <= 0:
			thunder_in = rng.randf_range(9, 16)
			lightning = 0.65
			status = "有点怕雷，幸好你在"
			# Umbrella remains held during surprise.
	else: thunder_in = 5.0

func save_data() -> Dictionary:
	return {"energy":energy, "joy":joy, "bond":bond, "journal":journal, "discovered":discovered, "day":last_day}

func restore(d: Dictionary) -> void:
	energy = clampf(float(d.get("energy", 78)), 0, 100)
	joy = clampf(float(d.get("joy", 75)), 0, 100)
	bond = maxi(0, int(d.get("bond", 0)))
	if d.get("journal") is Array: journal = d.journal.slice(0, 30)
	if d.get("discovered") is Array:
		for id in d.discovered:
			if Catalog.IDS.has(id) and not discovered.has(id): discovered.append(id)
	last_day = String(d.get("day", ""))
	var today := Time.get_date_string_from_system()
	if today != last_day:
		last_day = today
		add_note("新的一天，小院里等到你了")
