extends SceneTree
const Program = preload("res://companion/fish_program.gd")
const Events = preload("res://companion/events.gd")
const Catalog = preload("res://companion/catalog.gd")
const Fish = preload("res://companion/fish_actor.gd")
const World = preload("res://companion/world.gd")
var failures: Array[String] = []
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companion/fish/manifest.json"))
	var labels: Array = []
	for data in info.values(): labels.append(data.label)
	expect(info.size() == 106,"complete 106-action library")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companion/content/events.json"))
	for event in data.events:
		for variant in range(3):
			var show := Program.plan(event,"2026-10-24",14,Catalog.preset("clear"),variant)
			for label in show.labels: expect(label in labels,"known asset for "+event.id+": "+label)
			if event.get("tone","") == "solemn": expect(show.quiet and show.reply == "idle","solemn guard")
	for day in ["2026-01-04","2026-04-04","2026-07-04","2026-10-04"]:
		for hour in [5,8,12,16,19,23]:
			var show := Program.plan({"kind":"daily","actions":["water","walk"]},day,hour,Catalog.preset("clear"))
			for label in show.labels: expect(label in labels,"daily asset "+label)
	var spring := Program.plan({"id":"spring_festival","kind":"festival"},"2026-02-17",12,Catalog.preset("clear"))
	expect("舞狮头" in spring.labels,"Spring Festival lion dance")
	var mid := Program.plan({"id":"mid_autumn","kind":"festival"},"2026-09-25",12,Catalog.preset("clear"))
	expect("中秋赏月吃月饼" in mid.labels,"actual mooncake asset")
	var winter := Program.plan({"kind":"solar_term","title":"小雪"},"2026-11-22",12,Catalog.preset("clear"))
	expect("堆雪人" not in winter.labels,"solar term alone cannot create snow")
	var fish = Fish.new(); fish.world = World.new(); root.add_child(fish); fish.set_process(false)
	fish.set_context("2026-02-17",12)
	fish.world.festival = {"id":"spring_festival","kind":"festival","tone":"joyful","title":"春节"}
	expect(fish.request_show(),"festival accepted")
	fish.pos_x = fish.target_x
	fish._process(0.1)
	expect(fish.state == "show" and fish.action == fish.action_id("舞狮头"),"lion actually dispatched")
	expect(not fish.memory.is_empty(),"seen show recorded")
	var memory_size: int = fish.memory.size()
	fish.preview_action("dance"); fish._process(0.1)
	expect(fish.memory.size() == memory_size,"preview does not add daily records")
	fish.world.festival = {"tone":"solemn","actions":["idle"],"title":"纪念日"}; fish._process(0.1)
	expect(fish.current_show.is_empty() and fish.action in ["idle","notice"],"memorial interrupts celebration")
	fish.world.set_environment(Catalog.preset("night")); fish._process(0.1)
	expect(not fish.request_show(),"night blocks automatic performance")
	fish.world.set_environment(Catalog.preset("clear")); fish.world.festival = {}; fish.set_context("2026-10-24",12)
	fish.set_context("2026-10-24",23); fish.state = "around"; fish._step_action("idle",0.01); fish._process(0.1)
	expect(fish.action == "sleep","late hour sleeps even with stale day flag")
	fish.world.festival = {"id":"spring_festival","kind":"festival","tone":"joyful","title":"春节","actions":["celebrate_wave"]}
	fish.set_context("2026-02-17",23,true)
	fish.show_index = 0
	expect(fish.request_show(true),"holiday preview allowed at night")
	fish.pos_x = fish.target_x; fish._process(0.01)
	expect(fish.action == fish.action_id("舞狮头"),"night preview still shows lion")
	fish.set_context("2026-10-24",23,false)
	expect(not fish.previewing and fish.steps.is_empty() and fish.state == "around","return to live cancels preview")
	fish.hour = 12
	for id in info:
		fish.preview_action(id)
		fish._process(0.1)
		expect(fish.cache_bytes <= fish.BYTE_MAX and fish.frame_order.size() <= fish.FRAME_MAX,"bounded texture memory")
	fish.queue_free(); await process_frame
	if failures.is_empty(): push_warning("PASS test_fish_program: 106 assets, 74 events, daily slots, lion/mooncake, quiet/night, dispatch, memory budget")
	for failure in failures: push_error("FAIL "+failure)
	quit(0 if failures.is_empty() else 1)
