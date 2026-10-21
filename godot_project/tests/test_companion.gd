extends SceneTree
const Catalog = preload("res://companion/catalog.gd")
const World = preload("res://companion/world.gd")
const Source = preload("res://companion/weather_source.gd")
var failures: Array[String] = []

func expect(ok: bool, name: String) -> void:
	if not ok: failures.append(name)

func tick(w: RefCounted, seconds: float) -> void:
	for i in range(roundi(seconds*20)): w.step(0.05)

func _init() -> void:
	var w = World.new()
	w.rng.seed = 1
	w.set_environment(Catalog.preset("rain"))
	expect(w.activity == "notice", "rain starts with notice")
	tick(w,2.0)
	expect(w.activity == "take_umbrella", "notice then take umbrella")
	tick(w,2.0)
	expect(w.activity == "umbrella", "opening completes")
	var wet: float = w.wetness
	tick(w,10)
	expect(w.wetness-wet < 0.04, "umbrella mitigates wetting")
	w.interact("drink")
	expect(w.activity == "umbrella", "care cannot drop umbrella")
	w.set_environment(Catalog.preset("clear"))
	expect(w.wetness>0, "rain stop preserves wetness")
	tick(w,2.1)
	expect(w.activity == "shake", "rain stop closes and shakes umbrella")
	tick(w,20)
	expect(w.wetness < wet, "wetness gradually dries")
	w.set_environment(Catalog.preset("rain"))
	w.set_environment(Catalog.preset("night"))
	tick(w,8)
	expect(w.activity == "sleep", "weather interruption cancels stale rain queue")
	var energy: float = w.energy
	tick(w,10)
	expect(w.energy>energy, "sleep restores energy")
	w.interact("pet")
	expect(w.activity == "blink", "sleep touch is gentle wake")
	tick(w,2)
	expect(w.activity == "sleep", "returns to sleep")
	expect(not w.interact("pet"), "care cooldown prevents spam")
	for id in Catalog.IDS:
		w.set_environment(Catalog.preset(id))
		tick(w,20)
		expect(w.activity != "", "activity for " + id)
		expect(w.wetness>=0 and w.wetness<=1, "wetness bounds " + id)
	expect(w.discovered.size() == 16, "all scenarios discovered once")
	var saved: Dictionary = w.save_data()
	var restored = World.new()
	restored.restore(saved)
	expect(restored.bond == w.bond and restored.discovered.size()==16, "persistence round trip")
	expect(Catalog.from_wmo(95,36,40)=="thunderstorm", "storm priority over heat and wind")
	expect(Catalog.from_wmo(75,-4,30)=="heavy_snow", "WMO snow")
	expect(Catalog.from_wmo(61,5,10)=="rain", "WMO rain")
	expect(Catalog.from_wmo(0,35,3)=="hot", "thermal heat fallback")
	expect(Catalog.from_wmo(45,10,2)=="fog", "WMO fog")
	var solar := {"utc_offset":28800,"sunrise":"2026-09-05T05:35","sunset":"2026-09-05T18:20"}
	var midnight: float = Time.get_unix_time_from_datetime_string("2026-09-05T00:00:00") - 28800
	expect(Source.clock_state(solar,midnight+23*3600).phase=="night","actual local late night")
	expect(Source.clock_state(solar,midnight+5*3600+35*60).phase=="dawn","actual local sunrise")
	expect(Source.clock_state(solar,midnight+12*3600).phase=="day","actual local noon")
	expect(Source.clock_state(solar,midnight+18*3600+20*60).phase=="dusk","actual local sunset")
	expect(Source.clock_state(solar,midnight+20*3600).hour==20,"timezone clock conversion")
	if failures.is_empty():
		push_warning("PASS test_companion: weather chains, interruption, care, sleep, persistence, 16 scenarios, WMO")
	else:
		for failure in failures: push_error("FAIL "+failure)
	quit(0 if failures.is_empty() else 1)
