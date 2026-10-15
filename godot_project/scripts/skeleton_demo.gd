## skeleton_demo.gd
## 2D 骨骼动画演示场景控制器。
## 按键切换角色动作，底部显示提示。
extends Node2D

const SkeletonCharacter = preload("res://scripts/skeleton_character.gd")

var character: SkeletonCharacter
var _hint_label: Label
var _title_label: Label
var _current_action := "idle"
var _auto_cycle := false
var _cycle_timer := 0.0
const _ACTIONS := ["idle", "fan", "squat"]
const _ACTION_NAMES := {
	"idle": "待机呼吸",
	"fan": "扇扇子",
	"squat": "蹲起",
}
const _ACTION_DESC := {
	"idle": "idle · 待机呼吸（3.0s 循环）",
	"fan": "fan · 扇扇子（1.2s 循环）",
	"squat": "squat · 蹲起（1.5s 循环）",
}


func _ready() -> void:
	# 深色背景让浅色角色更突出
	var vp := get_viewport()
	vp.size = Vector2i(540, 960)

	# 角色居中偏下
	character = SkeletonCharacter.new()
	character.position = Vector2(vp.size.x * 0.5, vp.size.y * 0.65)
	character.scale = Vector2.ONE * 1.6
	add_child(character)

	# UI
	_title_label = Label.new()
	_title_label.text = "2D 骨骼动画 · 零素材依赖"
	_title_label.position = Vector2(20, 24)
	_title_label.add_theme_font_size_override("font_size", 22)
	add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.text = _build_hint()
	_hint_label.position = Vector2(20, vp.size.y - 90)
	_hint_label.add_theme_font_size_override("font_size", 16)
	add_child(_hint_label)

	# 默认播 idle
	_switch("idle")

	# 命令行带 --auto-shot 时自动截图三种动作（验证用）
	if OS.get_cmdline_args().has("--auto-shot"):
		_auto_screenshot_cycle()


func _build_hint() -> String:
	var lines := [
		"[1] 待机呼吸   [2] 扇扇子   [3] 蹲起",
		"[空格] 自动循环三种   [ESC] 退出",
		"当前: %s" % _ACTION_DESC[_current_action],
	]
	return "\n".join(lines)


func _switch(action: String) -> void:
	if action not in _ACTIONS:
		return
	_current_action = action
	character.play_anim(action)
	if _hint_label:
		_hint_label.text = _build_hint()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_auto_cycle = false
				_switch("idle")
			KEY_2:
				_auto_cycle = false
				_switch("fan")
			KEY_3:
				_auto_cycle = false
				_switch("squat")
			KEY_SPACE:
				_auto_cycle = not _auto_cycle
				_cycle_timer = 0.0
				if _hint_label:
					_hint_label.text = _build_hint() + "\n[自动循环: %s]" % ("开启" if _auto_cycle else "关闭")
			KEY_ESCAPE:
				get_tree().quit(0)
			KEY_F12:
				# 调试用：保存当前帧截图
				var img := get_viewport().get_texture().get_image()
				var err := img.save_png("/tmp/skeleton_demo_shot.png")
				print("screenshot saved: err=", err, " path=/tmp/skeleton_demo_shot.png")
			KEY_F5:
				# 自动截图三种动作（demo 用）
				_auto_screenshot_cycle()


var _shot_pending := ""
var _shot_delay := 0.0

func _auto_screenshot_cycle() -> void:
	# 依次切到三个动作，每个动作等 0.6s 后截图
	_states_to_shoot = ["idle", "fan", "squat"].duplicate()
	_advance_shot()

var _states_to_shoot: Array = []
func _advance_shot() -> void:
	if _states_to_shoot.is_empty():
		return
	var s: String = _states_to_shoot.pop_front()
	_switch(s)
	_shot_pending = s
	_shot_delay = 0.6

func _process(delta: float) -> void:
	if _shot_pending != "":
		_shot_delay -= delta
		if _shot_delay <= 0:
			var img := get_viewport().get_texture().get_image()
			img.save_png("/tmp/skeleton_shot_%s.png" % _shot_pending)
			print("shot saved: ", _shot_pending)
			_shot_pending = ""
			# 下一张
			if not _states_to_shoot.is_empty():
				_advance_shot()
			else:
				print("ALL_SHOTS_DONE")
				if OS.get_cmdline_args().has("--auto-shot"):
					await get_tree().create_timer(0.2).timeout
					get_tree().quit(0)
		return
	if _auto_cycle:
		_cycle_timer += delta
		# 每个动作展示约 3 个循环（取最长动画 3s × 3 ≈ 9s）
		if _cycle_timer >= 4.0:
			_cycle_timer = 0.0
			var idx := _ACTIONS.find(_current_action)
			idx = (idx + 1) % _ACTIONS.size()
			_switch(_ACTIONS[idx])


func _draw() -> void:
	# 背景渐变
	var vp: Vector2 = get_viewport().size
	for i in range(30):
		var t := float(i) / 29.0
		var col := Color(0.18, 0.20, 0.26).lerp(Color(0.32, 0.36, 0.46), t)
		draw_rect(Rect2(0, i * vp.y / 30.0, vp.x, vp.y / 30.0 + 1), col, true)
	# 地面线
	draw_line(Vector2(0, character.position.y + 8), Vector2(vp.x, character.position.y + 8),
		Color(1, 1, 1, 0.08), 2.0)
