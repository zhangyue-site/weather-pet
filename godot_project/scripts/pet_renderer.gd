class_name PetRenderer
extends Node2D
# ============================================================
#  小人渲染器 (3D 版)
#  用 SubViewport 渲染 Godot Plush 3D 模型, 显示在 2D 场景
#  替代原矢量绘制, 大幅提升可爱度
#  模型: Godot Plush Character (MIT, by Tibo)
# ============================================================

# 兼容旧接口 (pet_fsm 调用, 内部映射到 3D 动画)
enum FaceExpr { SMILE, HAPPY, SLEEP, SLEEPY, OPEN, SCARED, SAD, ANGRY, SURPRISE, LAUGH, WINK, BLUSH }

var _scale_factor: float = 1.0
var _is_walking: bool = false
var _base_position: Vector2 = Vector2.ZERO
var _current_anim: String = "idle"

# 3D 渲染相关
var _viewport: SubViewport = null
var _sprite: Sprite2D = null
var _model_root: Node3D = null
var _anim_player: AnimationPlayer = null
var _model_ready: bool = false
var _target_rotation_y: float = 0.0
var _current_rotation_y: float = 0.0

func _ready():
	_build_3d_viewport()
	queue_redraw()

func _build_3d_viewport():
	# SubViewport: 离屏渲染 3D 场景
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(400, 400)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	# 3D 世界: 相机
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 4.5)
	cam.fov = 35.0
	_viewport.add_child(cam)
	# 进树后再 look_at (避免 "Node not inside tree" 报错)
	cam.look_at(Vector3(0, 0.9, 0))

	# 环境光 (SubViewport 已设 transparent_bg, 这里只管光照)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1, 0.6)
	env.ambient_light_energy = 0.8
	# 轻微辉光让模型更柔和
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 0.8
	world_env.environment = env
	_viewport.add_child(world_env)

	# 主光源 (太阳光, 暖色)
	var dir_light := DirectionalLight3D.new()
	dir_light.position = Vector3(2, 3, 2)
	dir_light.rotation = Vector3(deg_to_rad(-35), deg_to_rad(30), 0)
	dir_light.light_color = Color(1.0, 0.96, 0.88, 1)
	dir_light.light_energy = 1.1
	dir_light.shadow_enabled = true
	_viewport.add_child(dir_light)

	# 补光 (冷色, 从另一侧)
	var fill_light := DirectionalLight3D.new()
	fill_light.position = Vector3(-2, 1.5, 1)
	fill_light.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-40), 0)
	fill_light.light_color = Color(0.7, 0.8, 1.0, 1)
	fill_light.light_energy = 0.4
	_viewport.add_child(fill_light)

	# 加载 3D 模型
	_load_model()

	# Sprite2D: 显示 SubViewport 渲染结果
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture = _viewport.get_texture()
	_sprite.scale = Vector2.ONE * 0.9
	add_child(_sprite)

func _load_model():
	var glb_path := "res://models/godot_plush_model.glb"
	if not ResourceLoader.exists(glb_path):
		push_warning("PetRenderer: 未找到 3D 模型 " + glb_path)
		return
	var glb_scene: PackedScene = load(glb_path)
	if glb_scene == null:
		push_warning("PetRenderer: 加载 glb 失败")
		return
	_model_root = glb_scene.instantiate()
	_viewport.add_child(_model_root)
	# 稍微下移, 让模型居中
	_model_root.position = Vector3(0, 0.15, 0)
	# 形象差异化: 调色 + 装饰物
	_customize_appearance(_model_root)
	# 找到 AnimationPlayer
	_anim_player = _find_anim_player(_model_root)
	if _anim_player:
		play_anim("idle")
	_model_ready = true

# ============================================================
#  形象差异化 (基于原模型, 不改 glb)
# ============================================================

func _customize_appearance(root: Node3D):
	# 1. 调色: 把原版 Godot 蓝 调成更柔和的晴天蓝
	_apply_tint_to_materials(root)
	# 2. 3D 装饰物: 腮红 + 天气胸章
	_add_blush_decal(root)
	_add_weather_badge(root)

func _apply_tint_to_materials(node: Node):
	# 遍历所有 MeshInstance3D, 给材质加色相微调 (让蓝色偏青绿一点, 更"晴天")
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			for i in range(mi.get_surface_override_material_count()):
				var mat = mi.get_active_material(i)
				if mat is StandardMaterial3D:
					var smat: StandardMaterial3D = mat.duplicate()
					# 微调: 增加饱和度感 (albedo_color 颜色混合)
					smat.albedo_color = smat.albedo_color.lerp(Color(0.5, 0.75, 0.95), 0.25)
					mi.set_surface_override_material(i, smat)
				elif mat is ShaderMaterial:
					var smat2: ShaderMaterial = mat.duplicate()
					# 着色器材质: 注入色调偏移 (如果有 albedo_texture)
					smat2.set_shader_parameter("tint_color", Color(0.6, 0.82, 1.0, 0.0))
					mi.set_surface_override_material(i, smat2)
		_apply_tint_to_materials(child)

func _add_blush_decal(root: Node3D):
	# 用两个半透明红色 SphereMesh 当腮红, 贴在脸颊位置
	# 找到头部 (模型根名 Rig, 头部骨骼约在 DEF-head)
	var head: Node3D = _find_bone(root, "DEF-head")
	if head == null:
		head = root  # 找不到骨骼就挂在根上
	for sign in [-1, 1]:
		var sphere := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.035
		m.height = 0.07
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.45, 0.5, 0.55)  # 粉色半透明
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 贴花不参与光照
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.45, 1.0)
		mat.emission_energy_multiplier = 0.3
		m.material = mat
		sphere.mesh = m
		# 腮红位置: 脸颊两侧, 略前略下
		sphere.position = Vector3(sign * 0.13, -0.05, 0.28)
		sphere.scale = Vector3(1.0, 0.6, 0.3)  # 压扁成椭圆
		head.add_child(sphere)

func _add_weather_badge(root: Node3D):
	# 胸前小太阳胸章: 一个发光的小圆盘
	var body: Node3D = _find_bone(root, "DEF-spine")
	if body == null:
		body = root
	var badge := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.06
	m.bottom_radius = 0.06
	m.height = 0.01
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.3, 0.9)  # 暖黄
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.2)
	mat.emission_energy_multiplier = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	badge.mesh = m
	# 胸前位置
	badge.position = Vector3(0, 0.0, 0.18)
	badge.rotation = Vector3(deg_to_rad(90), 0, 0)
	body.add_child(badge)
	# 太阳光芒 (4 条小射线)
	for i in range(4):
		var ray := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.015, 0.04, 0.005)
		rm.material = mat
		ray.mesh = rm
		var ang := i * PI / 2
		ray.position = Vector3(cos(ang) * 0.085, sin(ang) * 0.085, 0)
		ray.rotation = Vector3(deg_to_rad(90), 0, -ang)
		badge.add_child(ray)

func _find_bone(node: Node, name: String) -> Node3D:
	if node is Node3D and node.name.find(name) >= 0:
		return node
	for c in node.get_children():
		var found := _find_bone(c, name)
		if found:
			return found
	return null

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null

func _process(delta: float):
	if not _model_ready:
		return
	# 平滑旋转 (转向目标方向)
	_current_rotation_y = _lerp_angle(_current_rotation_y, _target_rotation_y, delta * 5.0)
	if _model_root:
		_model_root.rotation.y = _current_rotation_y
	# 行走时轻微上下浮动
	if _is_walking and _model_root:
		var bob := sin(Time.get_ticks_msec() * 0.008) * 0.03
		_model_root.position.y = 0.15 + bob
	queue_redraw()

func _lerp_angle(a: float, b: float, t: float) -> float:
	return a + angle_difference(a, b) * t

# ============================================================
#  动画控制 (核心)
# ============================================================

## 播放指定动画 (带过渡)
func play_anim(anim_name: String):
	if not _model_ready:
		_current_anim = anim_name
		return
	if _anim_player == null:
		return
	if not _anim_player.has_animation(anim_name):
		anim_name = "idle"  # 退回 idle
	if anim_name == _current_anim:
		return
	_current_anim = anim_name
	# 0.25 秒平滑过渡
	_anim_player.play(anim_name, 0.25)

func get_current_anim() -> String:
	return _current_anim

# ============================================================
#  兼容旧接口 (pet_fsm 调用)
#  原矢量版用 set_arms/set_expression/set_walking 手动摆姿势
#  3D 版忽略这些, 由 play_anim() 统一驱动
# ============================================================

func set_arms(_la: float, _ra: float, _lao: float = 0.0, _rao: float = 0.0):
	# 兼容: 3D 模型动画自动处理手臂
	pass

func set_expression(_expr: int, _persistent: bool = false):
	# 兼容: 3D 模型表情随动画, 忽略手动设置
	pass

func set_walking(w: bool):
	_is_walking = w
	if w:
		play_anim("walk")
	elif _current_anim == "walk":
		play_anim("idle")

func set_color(_c: Color):
	# 兼容: 3D 模型用贴图, 忽略
	pass

func set_base_position(pos: Vector2):
	_base_position = pos
	position = pos

func face_left():
	_target_rotation_y = deg_to_rad(-90)

func face_right():
	_target_rotation_y = deg_to_rad(90)

func face_front():
	_target_rotation_y = deg_to_rad(0)
