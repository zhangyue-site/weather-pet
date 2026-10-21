extends SceneTree
const Events = preload("res://companion/events.gd")
const Calendar = preload("res://companion/calendar_data.gd")
const World = preload("res://companion/world.gd")
const Catalog = preload("res://companion/catalog.gd")
var failures: Array[String] = []
func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func has_event(data: Dictionary, date: String, id: String) -> bool:
	return Events.matching(data,date).any(func(event): return event.id==id)
func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://companion/content/events.json"))
	Calendar.ensure_loaded()
	expect(Events.valid(data),"schema 2 validated")
	expect(Calendar.daily.size()==366,"366 daily slots includes leap day")
	expect(Calendar.effects.size()==200,"200 effect recipes")
	var geometries: Dictionary = {}
	var combinations: Dictionary = {}
	for effect in Calendar.effects.values():
		geometries[effect.family]=true
		combinations[effect.family+":"+effect.motion]=true
	expect(geometries.size()==20 and combinations.size()==200,"200 geometry-motion combinations, not color duplicates")
	for year in [2026,2028]:
		var date := "%d-01-01" % year
		var count := 0
		while date.begins_with(str(year)):
			var program := Events.program(data,date)
			expect(not program.title.is_empty() and not program.actions.is_empty(),"daily program "+date)
			for id in program.effect_ids: expect(not Calendar.effect(id).is_empty(),"effect resolves "+date)
			count+=1
			date=Calendar.shift(date,1)
		expect(count==(366 if year==2028 else 365),"full Gregorian year "+str(year))
	expect(has_event(data,"2026-02-16","new_year_eve"),"29-day lunar New Year eve")
	expect(has_event(data,"2026-02-17","spring_festival"),"2026 Spring Festival")
	expect(has_event(data,"2027-02-06","spring_festival"),"Spring Festival moves in 2027")
	expect(has_event(data,"2026-06-19","dragon_boat"),"2026 Dragon Boat")
	expect(has_event(data,"2026-09-25","mid_autumn"),"2026 Mid Autumn")
	expect(has_event(data,"2026-04-05","term_6"),"Qingming is a calculated solar term")
	expect(has_event(data,"2026-05-10","mother_day"),"second Sunday in May")
	expect(has_event(data,"2026-06-21","father_day"),"third Sunday in June")
	var normal := {"id":"birthday","title":"生日","caption":"一起记住","lunar_day":"06-01","days":1,"actions":["celebrate_wave"],"effect":"heart_garland","priority":100,"kind":"anniversary"}
	expect(Events.valid_event(normal),"personal lunar anniversary")
	expect(Events.program(data,"2025-06-25",[normal]).matches.any(func(e): return e.id=="birthday"),"regular lunar month birthday")
	expect(not Events.program(data,"2025-07-25",[normal]).matches.any(func(e): return e.id=="birthday"),"leap month does not duplicate birthday")
	normal.leap_month=true
	expect(Events.program(data,"2025-07-25",[normal]).matches.any(func(e): return e.id=="birthday"),"explicit leap month anniversary")
	var birthday := {"id":"birthday","title":"生日","caption":"记得今天","month_day":"12-13","days":1,"actions":["celebrate_cheer"],"effect":"heart_burst","priority":100,"kind":"anniversary"}
	var solemn := Events.program(data,"2026-12-13",[birthday])
	expect(solemn.tone=="solemn" and solemn.actions==["idle","notice"],"memorial suppresses celebrations including birthdays")
	expect(solemn.matches.size()>=2,"simultaneous events retained")
	var w = World.new()
	w.set_festival(Events.program(data,"2026-10-01"))
	w.set_environment(Catalog.preset("rain"))
	for i in range(100): w.step(0.05)
	expect(w.activity=="umbrella" and not w.festival.effect_ids.is_empty(),"weather and date remain combined")
	var unsupported := Events.program(data,"2040-08-15")
	expect(unsupported.lunar.is_empty() and not unsupported.daily_title.is_empty(),"out-of-range calendar is explicit, daily content remains")
	if failures.is_empty(): push_warning("PASS test_year_program: 731 daily programs, 200 recipes, lunar leap/eve, moving festivals, memorial conflicts, weather layering")
	else:
		for failure in failures: push_error("FAIL "+failure)
	quit(0 if failures.is_empty() else 1)
