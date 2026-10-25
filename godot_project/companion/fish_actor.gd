extends Node2D
const Program = preload("res://companion/fish_program.gd")
const H := 304
const CACHE_MAX := 5
const FRAME_MAX := 40
const BYTE_MAX := 24 * 1024 * 1024
var world: RefCounted
var respond: Callable = Callable()
var enabled := true
var reduced := false
var anim_info: Dictionary = {}
var labels: Dictionary = {}
var cache: Dictionary = {}
var cache_order: Array = []
var frame_order: Array = []
var cache_bytes := 0
var body_height := 150.0
var pos_x := 0.82
var foot := Vector2.ZERO
var action := "idle"
var action_time := 0.0
var action_duration := 5.0
var state := "around"
var visit_cd := 10.0
var target_x := 0.86
var direction := -1.0
var rng := RandomNumberGenerator.new()
var display_texture: Texture2D
var display_region := Rect2()
var decoded_frames := 0
var date := ""
var hour := 12
var memory: Dictionary = {}
var show_cd := 8.0
var show_index := 0
var current_show: Dictionary = {}
var steps: Array = []
var response_action := "wave"
var previewing := false
var preview_context := false
var last_texture: Texture2D
var last_foot := Vector2.INF
var last_direction := 0.0
var last_height := 0.0
var last_tone := ""
var context_key := ""
var lightning_cd := 0.0
var duet_blend := 0.0
var duet_lean := 0.0
var pair_poses = preload("res://companion/interaction_poses.gd").new()
var pair_pose := -1

func _ready() -> void:
	rng.randomize()
	visit_cd = rng.randf_range(8.0, 12.0)
	show_cd = visit_cd
	anim_info = JSON.parse_string(FileAccess.get_file_as_string("res://companion/fish/manifest.json"))
	for id in anim_info:
		labels[String(anim_info[id].get("label", id))] = id

func set_context(day: String, local_hour: int, is_preview: bool = false) -> void:
	var leaving_preview := preview_context and not is_preview
	preview_context = is_preview
	if leaving_preview:
		steps.clear(); current_show.clear(); previewing = false; state = "around"
		_step_action(_env_action(),8)
	if date != day:
		date = day
		# Retain only today's seen/noted keys; state is persisted with the normal save.
		for key in memory.keys():
			if not is_preview and not String(key).begins_with(day+":"): memory.erase(key)
	hour = local_hour
	var key := day+":"+String(world.festival.get("id","daily"))+":"+Program.slot(hour)
	if key != context_key:
		context_key = key
		show_cd = rng.randf_range(180,300) if memory.has(key) else 5.0

func action_id(label: String) -> String:
	return String(labels.get(label, "idle"))

func _drop_frame(key: String) -> void:
	var parts := key.split(":")
	var name: String = parts[0]
	var idx := int(parts[1])
	if cache.has(name) and cache[name][idx] != null:
		var tex: Texture2D = cache[name][idx]
		cache_bytes -= tex.get_width()*tex.get_height()*4
		cache[name][idx] = null
	frame_order.erase(key)

func _prepare_frame() -> void:
	var name: String = action if anim_info.has(action) else "idle"
	var info: Dictionary = anim_info.get(name, {})
	var count: int = int(info.get("frames", 0))
	if count <= 0: return
	if not cache.has(name):
		var slots: Array = []
		slots.resize(count)
		cache[name] = slots
	cache_order.erase(name)
	cache_order.push_front(name)
	while cache_order.size() > CACHE_MAX:
		var old: String = cache_order.pop_back()
		for key in frame_order.duplicate():
			if String(key).begins_with(old+":"): _drop_frame(key)
		cache.erase(old)
	var list: Array = cache[name]
	var idx: int = 0 if reduced else int(action_time*float(info.get("fps", 12)))%count
	var selected := name+":"+str(idx)
	var missing := -1
	# Warm only nearby frames; never decode a whole ten-second clip on a switch.
	for offset in range(3):
		var candidate: int = (idx+offset)%count
		if list[candidate] == null: missing = candidate; break
	if missing >= 0:
		var image := Image.new()
		var path := "res://companion/fish/%s/f%03d.webp" % [name, missing]
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and not image.is_empty():
			list[missing] = ImageTexture.create_from_image(image)
			cache_bytes += image.get_width()*image.get_height()*4
			frame_order.push_back(name+":"+str(missing))
			decoded_frames += 1
	if list[idx] != null:
		display_texture = list[idx]
		var crop: Array = info.get("crop",[0,0,display_texture.get_width(),display_texture.get_height()])
		display_region = Rect2(crop[0],crop[1],crop[2],crop[3])
		frame_order.erase(selected)
		frame_order.push_back(selected)
	elif display_texture == null and missing >= 0: display_texture = list[missing]
	while frame_order.size() > FRAME_MAX or cache_bytes > BYTE_MAX:
		var old: String = frame_order[0]
		if old == selected: break
		_drop_frame(old)

func _step_action(name: String, duration: float) -> void:
	action = name if anim_info.has(name) else "idle"
	action_time = 0.0
	action_duration = duration

func _quiet() -> bool:
	return world.festival.get("tone", "") == "solemn" or not bool(world.environment.is_day) or Program.slot(hour) == "night"

func _safe_for_show() -> bool:
	var id: String = String(world.environment.id)
	return bool(world.environment.is_day) and Program.slot(hour) != "night" and id not in ["drizzle","rain","heavy_rain","thunderstorm","windy","snow","heavy_snow","cold","hot"] and float(world.environment.feels) >= 0 and float(world.environment.feels) <= 32 and world.energy >= 18 and (world.activity != "sleep" or world.duet_active)

func _safe_for_quiet_pair() -> bool:
	return world.festival.get("tone","")!="solemn" and (not bool(world.environment.is_day) or Program.slot(hour)=="night") and String(world.environment.id) not in ["drizzle","rain","heavy_rain","thunderstorm","windy","snow","heavy_snow","cold","hot"] and float(world.environment.feels)>=0 and float(world.environment.feels)<=32

func _env_action() -> String:
	var id: String = String(world.environment.id)
	if not bool(world.environment.is_day) or Program.slot(hour) == "night": return "sleep"
	if world.festival.get("tone", "") == "solemn": return "idle" if rng.randf()<0.7 else "notice"
	if id in ["snow","heavy_snow"]: return "snow"
	if id == "hot" or float(world.environment.feels)>32: return "hot"
	if id == "cold" or float(world.environment.feels)<0: return action_id("涮火锅")
	if id in ["drizzle","rain","heavy_rain","thunderstorm","windy"]: return "notice"
	return ["idle","idle","notice","stretch"][rng.randi_range(0,3)]

func request_show(force: bool = false) -> bool:
	if not enabled or (reduced and not force): return false
	if not _safe_for_show() and not _safe_for_quiet_pair() and not preview_context: return false
	current_show = Program.plan(world.festival, date, 12 if force and preview_context else hour, world.environment, show_index)
	show_index += 1
	previewing = force or preview_context
	steps.clear()
	for label in current_show.labels:
		var id := action_id(String(label))
		steps.append({"id":id,"duration":float(anim_info[id].get("duration",2.0))})
	response_action = String(current_show.reply)
	if current_show.quiet:
		if _safe_for_quiet_pair() and String(world.festival.get("kind","daily"))=="daily" and respond.is_valid():
			state="show";respond.call()
			if state!="duet": _next_step()
		else:
			state="show";_next_step()
	else:
		visit_now()
	return true

func preview_action(id: String) -> void:
	if not anim_info.has(id): return
	# Preview is explicit and does not mutate daily seen markers or journal.
	previewing = true
	steps.clear()
	current_show = {"title":String(anim_info[id].get("label",id)),"quiet":false}
	state = "show"
	_step_action(id, float(anim_info[id].get("duration",2.0)))

func _next_step() -> void:
	if steps.is_empty():
		current_show.clear()
		previewing = false
		show_cd = rng.randf_range(180.0,300.0)
		state = "heading_home"
		target_x = clampf(pos_x+(-0.17 if pos_x>0.55 else 0.17),0.12,0.88)
		direction = signf(target_x-pos_x)
		_step_action("walk",12)
		return
	var step: Dictionary = steps.pop_front()
	_step_action(String(step.id),float(step.duration))

func visit_now() -> void:
	if not enabled or state == "visiting": return
	target_x = clampf(float(world.x)+(0.15 if pos_x>float(world.x) else -0.15),0.12,0.88)
	direction = signf(target_x-pos_x)
	_step_action("walk",12.0)
	state = "visiting"

func _arrive() -> void:
	if not current_show.is_empty():
		state = "show"
		if not previewing:
			memory[String(current_show.key)] = true
			var note_key := date+":"+String(world.festival.get("id","daily"))+":noted"
			if not memory.has(note_key):
				world.add_note("大肥鱼和阿晴一起："+String(current_show.title))
				memory[note_key] = true
		if respond.is_valid(): respond.call()
		if state != "duet": _next_step()
	else:
		state = "greeting"
		response_action = "idle" if _quiet() else "wave"
		_step_action("idle" if _quiet() else "wave",2.0)
		if respond.is_valid(): respond.call()

func pet_fish() -> bool:
	if not enabled or not visible: return false
	steps.clear(); current_show.clear(); previewing = false
	state = "around"
	show_cd = maxf(show_cd,20)
	visit_cd = maxf(visit_cd,5)
	_step_action("notice" if _quiet() else ["pet","happy",action_id("点击回应-害羞惊讶")][rng.randi_range(0,2)],4)
	return true

func has_point(p: Vector2) -> bool:
	return Rect2(foot-Vector2(body_height*0.42,body_height),Vector2(body_height*0.84,body_height)).has_point(p)

func _process(delta: float) -> void:
	if not enabled: visible = false; return
	visible = true
	var dt := clampf(delta,0,0.1)
	action_time += dt
	lightning_cd = maxf(0,lightning_cd-dt)
	show_cd = maxf(0,show_cd-dt)
	var tone: String = String(world.festival.get("tone",""))
	# Global quiet/weather constraints cancel staged celebrations, including previews.
	if (tone == "solemn" and last_tone != tone) or (not _safe_for_show() and state in ["show","visiting","greeting","staying"] and not preview_context):
		steps.clear(); current_show.clear(); previewing = false; state = "around"
		_step_action(_env_action(),8)
	last_tone = tone
	if world.lightning > 0.3 and lightning_cd <= 0 and tone != "solemn":
		steps.clear(); current_show.clear(); previewing = false; state = "around"
		_step_action("scared",2); lightning_cd = 8
	match state:
		"around":
			visit_cd -= dt if not reduced and not _quiet() else 0.0
			if not previewing and show_cd <= 0 and (_safe_for_show() or (_safe_for_quiet_pair() and not memory.has(date+":quiet_pair"))):
				request_show()
			elif visit_cd <= 0 and _safe_for_show():
				visit_cd = rng.randf_range(25,45); visit_now()
			elif action_time >= action_duration: _step_action(_env_action(),rng.randf_range(6,11))
		"visiting":
			pos_x = move_toward(pos_x,target_x,dt*0.06)
			if absf(pos_x-target_x)<=0.004: _arrive()
		"show":
			if action_time >= action_duration: _next_step()
		"greeting":
			if action_time >= action_duration:
				state = "staying"; _step_action("idle",6)
		"staying":
			if action_time >= action_duration: _next_step()
		"heading_home":
			pos_x = move_toward(pos_x,target_x,dt*0.055)
			if absf(pos_x-target_x)<=0.004:
				state = "around"; _step_action(_env_action(),7)
	var size := get_viewport_rect().size
	foot = Vector2(pos_x*size.x,size.y*0.8)
	duet_blend = move_toward(duet_blend,1.0 if world.duet_active else 0.0,dt*2.0)
	body_height = minf(size.y*0.16,158)*(1.0+duet_blend*0.30)
	duet_lean = direction*duet_blend*(0.06+sin(world.duet_time*2.4)*0.025)
	if world.duet_cue == "beat":
		foot.y -= absf(sin(world.duet_time*5.0))*5.0
	pair_pose = -1
	if world.duet_active and action in ["notice","wave","happy","idle"]:
		pair_pose=4
		if world.duet_prop=="cup_offer": pair_pose=5
		elif world.duet_prop=="shared_drink": pair_pose=7 if world.duet_progress<0.65 else 4
		elif world.duet_cue=="receive": pair_pose=6 if world.duet_progress<0.5 else 5
	if pair_pose<0: _prepare_frame()
	if duet_blend > 0 or display_texture != last_texture or foot != last_foot or direction != last_direction or body_height != last_height:
		last_texture = display_texture; last_foot = foot; last_direction = direction; last_height = body_height
		queue_redraw()

func _draw() -> void:
	if not visible: return
	if pair_pose>=0:
		var factor := body_height*0.78/470.0
		var sx := -factor if direction>0 else factor
		draw_set_transform(foot+Vector2(0,-3),duet_lean,Vector2(sx,factor))
		var tex: AtlasTexture = pair_poses.texture(pair_pose)
		draw_texture(tex,-pair_poses.anchor(pair_pose))
		draw_set_transform(Vector2.ZERO)
		return
	if display_texture == null: return
	var region := display_region if display_region.has_area() else Rect2(Vector2.ZERO, display_texture.get_size())
	var factor := body_height/region.size.y
	var sx := -factor if direction>0 else factor
	draw_set_transform(foot,0,Vector2(1,0.22))
	draw_circle(Vector2.ZERO,body_height*0.3,Color(0.08,0.12,0.13,0.15))
	draw_set_transform(foot+Vector2(0,-3),duet_lean,Vector2(sx,factor))
	draw_texture_rect_region(display_texture,Rect2(Vector2(-region.size.x*0.5,-region.size.y),region.size),region)
	draw_set_transform(Vector2.ZERO)

func hand_point() -> Vector2:
	if pair_pose>=0:
		var factor := body_height*0.78/470.0
		var hand: Vector2 = pair_poses.hand(pair_pose)*Vector2(-factor if direction>0 else factor,factor)
		return foot+Vector2(0,-3)+hand.rotated(duet_lean)
	return foot+Vector2(-signf(pos_x-world.x)*16,-body_height*0.36)
