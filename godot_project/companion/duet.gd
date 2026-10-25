extends RefCounted
# One timeline owns both characters until completion or an interruption.
var active := false
var phases: Array = []
var elapsed := 0.0
var index := -1
var caption := ""
var original_x := 0.0
var meeting_x := 0.0
var current: Dictionary = {}
var fish_meeting_x := 0.0
var shared_time := 0.0
var quiet_pair := false
var event_id := ""

func _phase(fish_action: String, actor_action: String, duration: float, text: String, keep: bool = false) -> Dictionary:
	return {"fish":fish_action,"actor":actor_action,"duration":duration,"text":text,"keep":keep,"cue":"","prop":""}

func start(world, fish, greet: bool = true) -> bool:
	if not fish._safe_for_show() and not fish._safe_for_quiet_pair() and not fish.preview_context: return false
	if world.festival.get("tone", "") == "solemn": return false
	cancel(world,fish)
	quiet_pair = bool(fish.current_show.get("quiet",false)) and fish._safe_for_quiet_pair()
	original_x = world.x
	var side := 1.0 if fish.pos_x >= world.x else -1.0
	var center := clampf((world.x+fish.pos_x)*0.5,0.36,0.64)
	meeting_x = center-side*0.16
	fish_meeting_x = center+side*0.16
	shared_time = 0.0
	event_id = String(world.festival.get("id",""))
	phases = [
		_phase("wave","notice",1.8,"大肥鱼：阿晴，过来一起玩呀"),
		_phase("notice","wave",2.0,"阿晴：来啦，今天一起做什么？")
	]
	if quiet_pair:
		phases=[_phase("notice","notice",1.6,"夜深了，两人转头互道晚安"),_phase("idle","sleep",3.0,"阿晴先坐下，大肥鱼在身边陪一会儿"),_phase("sleep","sleep",5.0,"两人一起安静休息")]
		phases[0].cue="look"; phases[1].cue="rest"; phases[2].cue="rest"
		fish.steps.clear()
		if not fish.preview_context and not fish.previewing:fish.memory[fish.date+":quiet_pair"]=true
		_begin(world,fish);return true
	if not greet: phases.clear()
	# Every ordinary day has an actual shared hand-off, independent of special dates.
	if greet and (String(world.festival.get("kind","daily")) == "daily" or fish.steps.is_empty()):
		var ritual := _phase("notice","notice",1.4,"两人转过身，先看向对方")
		ritual.cue = "look"; phases.append(ritual)
		ritual = _phase("notice","notice",2.0,"阿晴把热饮递过去，大肥鱼伸手接住")
		ritual.cue = "offer"; ritual.prop = "cup_offer"; phases.append(ritual)
		ritual = _phase("happy","notice",2.2,"大肥鱼接过杯子喝一口，再抬头向阿晴点头回应")
		ritual.cue = "share"; ritual.prop = "shared_drink"; phases.append(ritual)
	for step in fish.steps:
		var id: String = String(step.id)
		var label: String = String(fish.anim_info[id].get("label",id))
		var duration: float = maxf(2.0,float(step.duration))
		var watch := "notice"
		var reply := "celebrate_cheer"
		var text := "大肥鱼表演"+label+"，阿晴在旁边认真看"
		var answer := "阿晴欢呼叫好，大肥鱼继续把这段演完"
		if label.begins_with("吃") or label.contains("月饼") or label == "涮火锅":
			watch = "drink"; reply = "wave"
			text = "大肥鱼：一起吃点吧！阿晴举起杯子作陪"
			answer = "阿晴：和你一起吃，今天更开心了"
		elif label.contains("花") or label.contains("动物"):
			watch = "water"; reply = "notice"
			text = "大肥鱼招呼阿晴一起看花，阿晴照看小植物"
			answer = "阿晴：看，小院又热闹起来了"
		elif label.contains("舞"):
			reply = "drum" if label.contains("舞狮") else "celebrate_dance"
			answer = "阿晴敲起小鼓，大肥鱼应着鼓点舞狮" if label.contains("舞狮") else "两人看着对方，一起跟着节奏摇摆"
		elif label.contains("小憩") or label.contains("哈欠"):
			watch = "sleep"; reply = "sleep"
			text = "大肥鱼打起瞌睡，阿晴也陪着安静休息"
			answer = "两人一起歇息，先不打扰她们"
		elif label.contains("记录") or label.contains("代码") or label.contains("思考"):
			reply = "notice"; answer = "阿晴凑过来看看，陪大肥鱼琢磨一会儿"
		var first := _phase(id,watch,duration*0.35,text)
		var second := _phase(id,reply,duration*0.65,answer,true)
		first.cue = "watch"; second.cue = "reply"
		if label.contains("舞狮"):
			first.prop = "drum"; second.prop = "drum"; second.cue = "beat"
		phases.append(first); phases.append(second)
		if label.contains("吃") or label == "涮火锅":
			var offer := _phase("notice","notice",2.0,"大肥鱼把一份点心递给阿晴，阿晴伸手接住")
			offer.prop = "mooncake_offer" if label.contains("月饼") else "snack_offer"; offer.cue = "receive"; phases.append(offer)
			var eat := _phase("happy","drink",2.2,"阿晴尝一口，抬头向大肥鱼点点头；大肥鱼开心回应")
			eat.prop = "mooncake_eat" if label.contains("月饼") else "snack_eat"; eat.cue = "eat"; phases.append(eat)
	phases.append(_phase("happy","wave",2.2,"大肥鱼：谢谢你陪我！阿晴挥手回应"))
	phases.append(_phase("wave","wave",1.8,"两人挥挥手，约好一会儿再见"))
	fish.steps.clear()
	_begin(world,fish)
	return true

func touch(world, fish, who: String) -> bool:
	if not fish.enabled or fish._quiet() or not fish._safe_for_show(): return false
	cancel(world,fish)
	original_x = world.x; meeting_x = world.x; fish_meeting_x = fish.pos_x; shared_time = 0.0
	event_id = String(world.festival.get("id",""))
	phases = [
		_phase("notice" if who == "actor" else "pet","pet" if who == "actor" else "notice",2.0,"被你摸了摸，另一位也好奇地看过来"),
		_phase("happy","wave",2.5,"阿晴和大肥鱼一起回应你的招呼"),
		_phase("idle","idle",2.0,"三个人一起待一会儿，也很好")
	]
	_begin(world,fish)
	return true

func _begin(world, fish) -> void:
	active = true; world.duet_active = true
	world.queue.clear()
	fish.state = "duet"
	index = -1
	_next(world,fish)

func _next(world, fish) -> void:
	index += 1; elapsed = 0
	if index >= phases.size(): cancel(world,fish); return
	current = phases[index]
	caption = String(current.text)
	world.start(String(current.actor),float(current.duration)+0.1)
	world.status = {"notice":"在看大肥鱼的小节目", "wave":"回应大肥鱼的招呼", "drink":"一起吃点喝点", "celebrate_dance":"跟着大肥鱼的节奏", "celebrate_cheer":"给大肥鱼加油", "drum":"和大肥鱼一起敲鼓舞狮", "water":"和大肥鱼一起看花", "pet":"和你们一起真开心"}.get(String(current.actor),"和大肥鱼安静相伴")
	world.duet_cue = String(current.get("cue",""))
	world.duet_prop = String(current.get("prop",""))
	world.status = {"look":"两人转过身，互相看着打招呼","offer":"把热饮递给大肥鱼","share":"看着大肥鱼接过热饮、喝一口","receive":"伸手接住大肥鱼递来的点心","eat":"尝一口，再向朋友点头回应","beat":"和大肥鱼一起敲鼓舞狮","rest":"互道晚安，陪彼此安静休息"}.get(world.duet_cue,world.status)
	world.duet_progress = 0.0
	world.look_direction = signf(fish.pos_x-world.x)
	fish.direction = signf(world.x-fish.pos_x)
	if not current.keep: fish._step_action(String(current.fish),float(current.duration)+0.1)

func step(delta: float, world, fish) -> void:
	if not active: return
	if not fish.enabled or fish.reduced or fish.state != "duet" or world.festival.get("tone", "") == "solemn" or event_id != String(world.festival.get("id","")) or (not fish._safe_for_show() and not fish.preview_context and not (quiet_pair and fish._safe_for_quiet_pair())):
		cancel(world,fish); return
	var dt := clampf(delta,0,0.1)
	elapsed += dt; shared_time += dt
	world.duet_time = shared_time
	world.duet_progress = clampf(elapsed/float(current.duration),0,1)
	world.x = move_toward(world.x,meeting_x,dt*0.15)
	fish.pos_x = move_toward(fish.pos_x,fish_meeting_x,dt*0.15)
	world.look_direction = signf(fish.pos_x-world.x)
	fish.direction = -world.look_direction
	if elapsed >= float(current.duration): _next(world,fish)

func cancel(world, fish) -> void:
	if not active: return
	active = false; quiet_pair = false; caption = ""; phases.clear()
	world.duet_active = false; world.look_direction = 0.0; world.duet_cue = ""; world.duet_time = 0.0; world.duet_prop = ""; world.duet_progress = 0.0
	fish.steps.clear(); fish.current_show.clear(); fish.previewing = false
	fish.show_cd = 180.0; fish.visit_cd = 30.0
	fish.state = "around"; fish._step_action(fish._env_action(),7)
	# Do not overwrite a weather protection sequence already queued by the world.
	if world.queue.is_empty(): world.choose_activity()
