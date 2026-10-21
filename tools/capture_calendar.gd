extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://companion/main.tscn").instantiate()
	root.add_child(app)
	app.capture_mode = true
	app.source.stop()
	app.set_process(false)
	app.set_demo("clear")
	app._update_background()
	app.background_mix = 1.0
	app.actor.foot = Vector2(310,768)
	app.actor.body_height = 245
	var output := ProjectSettings.globalize_path("res://../docs/screenshots/calendar")
	DirAccess.make_dir_recursive_absolute(output)
	var Calendar = load("res://companion/calendar_data.gd")
	Calendar.ensure_loaded()
	var atlas := Image.create(1080,1920,false,Image.FORMAT_RGB8)
	var hashes: Dictionary = {}
	for i in range(200):
		app.calendar_effects.override_id = Calendar.effect_order[i]
		app.world.total_time = 3.0
		app.world.activity = "idle"
		app.world.festival = {"title":Calendar.effect(Calendar.effect_order[i]).title,"tone":"joyful","actions":["idle"]}
		app._refresh_labels()
		app.actor.queue_redraw()
		app.calendar_effects.queue_redraw()
		app.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		hashes[img.get_region(Rect2i(0,290,540,450)).get_data().hex_encode().sha256_text()] = true
		if i%10==0:
			img.convert(Image.FORMAT_RGB8)
			img.resize(216,384)
			atlas.blit_rect(img,Rect2i(0,0,216,384),Vector2i((i/10)%5*216,(i/50)*384))
	atlas.save_png(output+"/motifs.png")
	for date in ["2026-02-17","2026-06-19","2026-09-25","2026-10-01","2026-12-13","2028-02-29"]:
		app._preview_date(date)
		app.world.total_time = 3.0
		app.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+date+".png")
	app._open_sheet("anniversaries")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/anniversaries.png")
	print("RENDERED_EFFECTS 200 UNIQUE_SCREENSHOTS ",hashes.size())
	quit(0 if hashes.size()==200 else 1)
