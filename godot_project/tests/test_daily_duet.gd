extends SceneTree
const Duet=preload("res://companion/duet.gd")
const World=preload("res://companion/world.gd")
const Fish=preload("res://companion/fish_actor.gd")
const Program=preload("res://companion/fish_program.gd")
var failures: Array[String]=[]
func expect(ok:bool,text:String) -> void:
	if not ok:failures.append(text)
func _init() -> void:call_deferred("run")
func run() -> void:
	var world=World.new();var fish=Fish.new();fish.world=world;root.add_child(fish);fish.set_process(false);fish.preview_context=true
	for day in ["2026-01-07","2026-04-08","2026-07-09","2026-10-24"]:
		for hour in [7,12,16,19]:
			world.festival={"id":"ordinary_"+day,"kind":"daily","tone":"gentle","title":"平常的一天","actions":["notice"]}
			var plan=Program.plan(world.festival,day,hour,world.environment,0);expect(not plan.quiet,"ordinary daytime has a pair program")
			fish.set_context(day,hour,true);fish.steps=[]
			var duo=Duet.new();expect(duo.start(world,fish),"daily pair starts without holiday")
			var props: Array=[]
			for phase in duo.phases:props.append(phase.get("prop",""))
			expect(props.has("cup_offer") and props.has("shared_drink"),"every daytime slot includes real handoff, sipping and reply")
			for i in range(40):world.step(0.1);duo.step(0.1,world,fish)
			expect(absf(world.x-fish.pos_x)>0.28,"characters don't overlap while interacting")
			expect(world.look_direction==-fish.direction,"partners face one another")
			duo.cancel(world,fish);expect(world.duet_cue.is_empty() and world.duet_prop.is_empty(),"no props/gaze locks leak after cancellation")
	world.environment.is_day=false;fish.set_context("2026-10-24",23,false)
	fish.current_show={"quiet":true};fish.steps=[]
	var quiet=Duet.new();expect(quiet.start(world,fish),"night has a gentle pair interaction")
	for phase in quiet.phases:expect(phase.get("prop","").is_empty() and phase.actor not in ["drum","celebrate_dance"],"night never becomes a noisy show")
	for i in range(55):world.step(0.1);quiet.step(0.1,world,fish)
	expect(world.activity=="sleep" and quiet.active,"both settle to rest without autonomy interruption")
	quiet.cancel(world,fish)
	expect(fish.memory.has("2026-10-24:quiet_pair"),"bedtime interaction happens once per night")
	fish.queue_free();await process_frame
	if failures.is_empty():push_warning("PASS test_daily_duet: 16 ordinary-date/daytime combinations, shared objects, spacing, facing, cleanup")
	for f in failures:push_error("FAIL "+f)
	quit(0 if failures.is_empty() else 1)
