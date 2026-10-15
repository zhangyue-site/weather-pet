## skeleton_character.gd
## 从零构建的 2D 骨骼动画 Q 版小人。
## 零 PNG / 零 GLB 依赖：所有部件代码绘制。
## 骨架 = Node2D 树（旋转父骨头，子骨头跟随）。
## 动画 = 程序化生成 Animation 资源，由 AnimationPlayer 播放。
extends Node2D
class_name SkeletonCharacter

# ---- 部件颜色 ----
const COL_SKIN   := Color(0.957, 0.784, 0.659)   # #F4C8A8
const COL_HAIR   := Color(0.227, 0.165, 0.102)   # #3A2A1A
const COL_SHIRT  := Color(0.290, 0.565, 0.851)   # #4A90D9
const COL_PANTS  := Color(0.173, 0.243, 0.314)   # #2C3E50
const COL_SHOE   := Color(0.118, 0.137, 0.157)
const COL_CHEEK  := Color(0.980, 0.510, 0.549)
const COL_EYE    := Color(0.110, 0.110, 0.137)
const COL_FAN    := Color(0.961, 0.902, 0.800)   # #F5E6CC
const COL_FAN_EDGE := Color(0.820, 0.180, 0.180)
const COL_FAN_BONE := Color(0.502, 0.376, 0.251)

# ---- 几何尺寸 ----
const HEAD_R       := 26.0
const TORSO_W      := 38.0
const TORSO_H      := 46.0
const ARM_LEN      := 22.0
const ARM_W        := 9.0
const LEG_LEN      := 26.0
const LEG_W        := 11.0
const FOOT_W       := 22.0
const FOOT_H       := 10.0

# ---- 骨头节点引用 ----
var hip: Node2D
var torso: Node2D
var head: Node2D
var upper_arm_r: Node2D
var forearm_r: Node2D
var hand_r: Node2D
var upper_arm_l: Node2D
var forearm_l: Node2D
var hand_l: Node2D
var thigh_r: Node2D
var shin_r: Node2D
var foot_r: Node2D
var thigh_l: Node2D
var shin_l: Node2D
var foot_l: Node2D

var anim_player: AnimationPlayer
# 各动画的"中性姿态"快照，用于在不同动画间平滑切换
var _rest_poses: Dictionary = {}

# 全局缩放（外部调 set_base_position 后由父级 scale 控制）
func _ready() -> void:
	_build_skeleton()
	_build_animations()
	# 默认中性姿态
	_apply_rest_pose()
	# 用动画播放器切动作
	if anim_player.has_animation("idle"):
		anim_player.play("idle")


# ============================================================
# 骨架构建
# ============================================================

## 构建骨架树。每个 Node2D = 一根骨头，子节点 = 下级骨头 + 部件。
## 局部坐标系约定：骨头原点在关节处，骨头沿 +y 向下延伸。
func _build_skeleton() -> void:
	# 根（角色脚底世界锚点；外部设置 position 定位整人）
	# hip 是身体重心，origin 在髋关节中央
	hip = Node2D.new()
	hip.name = "Hip"
	hip.position = Vector2(0, -LEG_LEN * 2 - 8)  # 站立时脚底在 y=0
	add_child(hip)

	# 躯干（髋上方）
	torso = _add_bone(hip, "Torso", Vector2(0, 0))
	# 头（躯干顶端）
	head = _add_bone(torso, "Head", Vector2(0, -TORSO_H * 0.5 - HEAD_R * 0.6))
	# 右臂（躯干右上）
	upper_arm_r = _add_bone(torso, "UpperArmR", Vector2(TORSO_W * 0.42, -TORSO_H * 0.42))
	forearm_r = _add_bone(upper_arm_r, "ForearmR", Vector2(0, ARM_LEN))
	hand_r = _add_bone(forearm_r, "HandR", Vector2(0, ARM_LEN))
	# 左臂（躯干左上）
	upper_arm_l = _add_bone(torso, "UpperArmL", Vector2(-TORSO_W * 0.42, -TORSO_H * 0.42))
	forearm_l = _add_bone(upper_arm_l, "ForearmL", Vector2(0, ARM_LEN))
	hand_l = _add_bone(forearm_l, "HandL", Vector2(0, ARM_LEN))
	# 右腿（髋右下）
	thigh_r = _add_bone(hip, "ThighR", Vector2(TORSO_W * 0.22, 0))
	shin_r = _add_bone(thigh_r, "ShinR", Vector2(0, LEG_LEN))
	foot_r = _add_bone(shin_r, "FootR", Vector2(0, LEG_LEN))
	# 左腿（髋左下）
	thigh_l = _add_bone(hip, "ThighL", Vector2(-TORSO_W * 0.22, 0))
	shin_l = _add_bone(thigh_l, "ShinL", Vector2(0, LEG_LEN))
	foot_l = _add_bone(shin_l, "FootL", Vector2(0, LEG_LEN))

	# 给每根骨头挂自绘部件
	_attach_part(head, _draw_head)
	_attach_part(torso, _draw_torso)
	_attach_part(upper_arm_r, _draw_upper_arm.bind(true))
	_attach_part(forearm_r, _draw_forearm.bind(true))
	_attach_part(hand_r, _draw_hand.bind(true))
	_attach_part(upper_arm_l, _draw_upper_arm.bind(false))
	_attach_part(forearm_l, _draw_forearm.bind(false))
	_attach_part(hand_l, _draw_hand.bind(false))
	_attach_part(thigh_r, _draw_thigh.bind(true))
	_attach_part(shin_r, _draw_shin.bind(true))
	_attach_part(foot_r, _draw_foot.bind(true))
	_attach_part(thigh_l, _draw_thigh.bind(false))
	_attach_part(shin_l, _draw_shin.bind(false))
	_attach_part(foot_l, _draw_foot.bind(false))

	# 扇子挂在右手末端
	_attach_part(hand_r, _draw_fan, true)

	# 站立中性姿态：双臂自然下垂、腿笔直
	_apply_rest_pose()

	# 阴影：画在角色脚底（根节点直接子，不跟骨骼动）
	var shadow := _Part.new()
	shadow.draw_fn = _draw_shadow
	add_child(shadow)
	shadow.z_index = -1


## 在 parent 下创建一根骨头 Node2D，名字 + 相对父关节的位置。
func _add_bone(parent: Node2D, bone_name: String, joint_pos: Vector2) -> Node2D:
	var b := Node2D.new()
	b.name = bone_name
	b.position = joint_pos
	parent.add_child(b)
	return b


## 给骨头挂一个自绘部件。部件 = Node2D 子节点，重写 _draw()。
func _attach_part(bone: Node2D, draw_fn: Callable, attach_at_end: bool = false) -> void:
	var part := _Part.new()
	part.draw_fn = draw_fn
	if attach_at_end:
		bone.add_child(part)
	else:
		# 插在骨头之前，让后续子骨头层级在上
		var idx := bone.get_child_count()
		bone.add_child(part)
		bone.move_child(part, 0)


## 记录并应用中性站立姿态（动画从这里出发、回到这里）
func _apply_rest_pose() -> void:
	_rest_poses = {
		"hip": hip.position,
		"torso": torso.position, "torso_rot": torso.rotation_degrees,
		"head": head.position, "head_rot": head.rotation_degrees,
		"uar": upper_arm_r.rotation_degrees, "far": forearm_r.rotation_degrees,
		"ual": upper_arm_l.rotation_degrees, "fal": forearm_l.rotation_degrees,
		"thr": thigh_r.rotation_degrees, "shr": shin_r.rotation_degrees,
		"thl": thigh_l.rotation_degrees, "shl": shin_l.rotation_degrees,
	}
	hip.position = _rest_poses["hip"]
	torso.position = _rest_poses["torso"]
	torso.rotation_degrees = 0.0
	head.position = _rest_poses["head"]
	head.rotation_degrees = 0.0
	# 双臂稍外撇，避免贴身体
	upper_arm_r.rotation_degrees = 8.0
	forearm_r.rotation_degrees = -4.0
	upper_arm_l.rotation_degrees = -8.0
	forearm_l.rotation_degrees = 4.0
	# 腿笔直
	for b in [thigh_r, shin_r, thigh_l, shin_l]:
		b.rotation_degrees = 0.0


# ============================================================
# 部件绘制（代码画几何体）
# ============================================================

func _draw_head(c: CanvasItem) -> void:
	# 头部：圆头 + 头发 + 眼睛 + 嘴 + 腮红
	# 中心在 (0,0)
	# 脸
	c.draw_circle(Vector2.ZERO, HEAD_R, COL_SKIN)
	# 头发（上半圆遮挡）
	c.draw_circle(Vector2(0, -HEAD_R * 0.25), HEAD_R * 0.95, COL_HAIR)
	# 脸覆盖头发下半，露出脸
	c.draw_circle(Vector2(0, HEAD_R * 0.05), HEAD_R * 0.82, COL_SKIN)
	# 眼睛
	var eye_y := -HEAD_R * 0.05
	var eye_dx := HEAD_R * 0.32
	c.draw_circle(Vector2(-eye_dx, eye_y), 3.2, COL_EYE)
	c.draw_circle(Vector2(eye_dx, eye_y), 3.2, COL_EYE)
	# 眼神高光
	c.draw_circle(Vector2(-eye_dx + 1.0, eye_y - 1.0), 1.0, Color.WHITE)
	c.draw_circle(Vector2(eye_dx + 1.0, eye_y - 1.0), 1.0, Color.WHITE)
	# 腮红
	c.draw_circle(Vector2(-HEAD_R * 0.55, HEAD_R * 0.25), 4.0, COL_CHEEK)
	c.draw_circle(Vector2(HEAD_R * 0.55, HEAD_R * 0.25), 4.0, COL_CHEEK)
	# 嘴（小弧）
	var mouth_pts := PackedVector2Array([
		Vector2(-4, HEAD_R * 0.45),
		Vector2(0, HEAD_R * 0.55),
		Vector2(4, HEAD_R * 0.45),
	])
	c.draw_polyline(mouth_pts, COL_EYE, 1.8, true)


func _draw_torso(c: CanvasItem) -> void:
	# 胶囊躯干，中心在骨头原点，向上延伸
	var rect := Rect2(-TORSO_W * 0.5, -TORSO_H * 0.5, TORSO_W, TORSO_H)
	c.draw_rect(rect, COL_SHIRT, true)
	# 圆角效果：上下两端画半圆
	c.draw_circle(Vector2(0, -TORSO_H * 0.5), TORSO_W * 0.5, COL_SHIRT)
	c.draw_circle(Vector2(0, TORSO_H * 0.5), TORSO_W * 0.5, COL_SHIRT)
	# 腰带高光
	c.draw_rect(Rect2(-TORSO_W * 0.5, TORSO_H * 0.3, TORSO_W, 4), COL_PANTS, true)
	# 衣领 V
	var collar := PackedVector2Array([
		Vector2(-8, -TORSO_H * 0.5),
		Vector2(0, -TORSO_H * 0.5 + 10),
		Vector2(8, -TORSO_H * 0.5),
	])
	c.draw_colored_polygon(collar, Color(0.95, 0.95, 0.95))


func _draw_upper_arm(c: CanvasItem, is_right: bool) -> void:
	# 上臂：从骨头原点向下延伸的胶囊
	var w := ARM_W
	var rect := Rect2(-w * 0.5, -w * 0.3, w, ARM_LEN + w * 0.3)
	c.draw_rect(rect, COL_SHIRT, true)
	c.draw_circle(Vector2.ZERO, w * 0.5, COL_SHIRT)
	# 肘关节小圆
	c.draw_circle(Vector2(0, ARM_LEN), w * 0.5, COL_SHIRT)


func _draw_forearm(c: CanvasItem, is_right: bool) -> void:
	var w := ARM_W * 0.85
	var rect := Rect2(-w * 0.5, -w * 0.3, w, ARM_LEN + w * 0.3)
	c.draw_rect(rect, COL_SKIN, true)
	c.draw_circle(Vector2.ZERO, w * 0.5, COL_SKIN)


func _draw_hand(c: CanvasItem, is_right: bool) -> void:
	c.draw_circle(Vector2.ZERO, 7.0, COL_SKIN)


func _draw_thigh(c: CanvasItem, is_right: bool) -> void:
	var w := LEG_W
	var rect := Rect2(-w * 0.5, -w * 0.3, w, LEG_LEN + w * 0.3)
	c.draw_rect(rect, COL_PANTS, true)
	c.draw_circle(Vector2.ZERO, w * 0.5, COL_PANTS)
	c.draw_circle(Vector2(0, LEG_LEN), w * 0.5, COL_PANTS)


func _draw_shin(c: CanvasItem, is_right: bool) -> void:
	var w := LEG_W * 0.85
	var rect := Rect2(-w * 0.5, -w * 0.3, w, LEG_LEN + w * 0.3)
	c.draw_rect(rect, COL_PANTS, true)
	c.draw_circle(Vector2.ZERO, w * 0.5, COL_PANTS)


func _draw_foot(c: CanvasItem, is_right: bool) -> void:
	# 椭圆脚（用多段圆近似，避免 draw_ellipse 在 4.6 的坑）
	var dir := 1.0 if is_right else -1.0
	for i in range(4):
		var t := float(i) / 3.0
		var x: float = lerp(-FOOT_W * 0.5, FOOT_W * 0.5, t)
		c.draw_circle(Vector2(x, FOOT_H * 0.3), FOOT_H * 0.55, COL_SHOE)
	c.draw_rect(Rect2(-FOOT_W * 0.5, -FOOT_H * 0.2, FOOT_W, FOOT_H), COL_SHOE, true)


func _draw_fan(c: CanvasItem) -> void:
	# 扇子挂在手心，扇柄向下、扇面朝上展开
	# 把扇面画在骨头局部坐标 +y 方向（远离手）
	# 扇骨从原点向 +y 发散
	var radius := 30.0
	var half_angle := deg_to_rad(45.0)  # 扇面展开 90°
	var n_ribs := 6
	# 扇面填充（三角形组合）
	var fan_pts := PackedVector2Array()
	fan_pts.append(Vector2.ZERO)  # 扇柄交点
	for i in range(n_ribs + 1):
		var t := float(i) / n_ribs
		var a: float = lerp(-half_angle, half_angle, t)
		fan_pts.append(Vector2(sin(a) * radius, -cos(a) * radius))
	# 用多个三角形拼扇面
	for i in range(n_ribs):
		var t0 := float(i) / n_ribs
		var t1 := float(i + 1) / n_ribs
		var a0: float = lerp(-half_angle, half_angle, t0)
		var a1: float = lerp(-half_angle, half_angle, t1)
		var p0 := Vector2.ZERO
		var p1 := Vector2(sin(a0) * radius, -cos(a0) * radius)
		var p2 := Vector2(sin(a1) * radius, -cos(a1) * radius)
		c.draw_colored_polygon(PackedVector2Array([p0, p1, p2]), COL_FAN)
	# 扇骨线
	for i in range(n_ribs + 1):
		var t := float(i) / n_ribs
		var a: float = lerp(-half_angle, half_angle, t)
		var p := Vector2(sin(a) * radius, -cos(a) * radius)
		c.draw_line(Vector2.ZERO, p, COL_FAN_BONE, 1.2)
	# 扇面外缘弧线（红边）
	var arc_pts := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		var a: float = lerp(-half_angle, half_angle, t)
		arc_pts.append(Vector2(sin(a) * radius, -cos(a) * radius))
	c.draw_polyline(arc_pts, COL_FAN_EDGE, 2.0, true)
	# 扇柄（短圆柱）
	c.draw_rect(Rect2(-2.5, 2, 5, 12), COL_FAN_BONE, true)


func _draw_shadow(c: CanvasItem) -> void:
	# 地面阴影：椭圆，画在 SkeletonCharacter 根节点的本地坐标 y=0（脚底）
	# 注意：此部件是 root 的直接子节点，不跟随骨骼；y 取角色站立的脚底高度
	# hip.position.y 已经把脚底放在 root 的 y≈0
	for i in range(5):
		var t := float(i) / 4.0
		var rx: float = lerp(34, 38, t)
		var ry: float = lerp(8, 11, t)
		var col := Color(0, 0, 0, 0.04 + 0.02 * (1.0 - t))
		_draw_ellipse_shape(c, Vector2(0, 4), rx, ry, col)


## 用多段圆画椭圆（避开 4.6 的 draw_ellipse 行为差异）
func _draw_ellipse_shape(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var segs := 24
	var prev := center + Vector2(rx, 0)
	for i in range(1, segs + 1):
		var a := TAU * float(i) / segs
		var p := center + Vector2(cos(a) * rx, sin(a) * ry)
		c.draw_line(prev, p, col, 2.0)
		prev = p


# ============================================================
# 动画系统（程序化生成 Animation）
# ============================================================

func _build_animations() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimPlayer"
	add_child(anim_player)
	_add_idle_anim()
	_add_fan_anim()
	_add_squat_anim()


## 通用：给动画添加一条 :rotation_degrees 轨道
func _add_rot_track(anim: Animation, bone: Node2D, keys: Array) -> int:
	var path := String(bone.get_path()) + ":rotation_degrees"
	var tid := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tid, path)
	# keys = [[time, value], ...]
	for k in keys:
		anim.track_insert_key(tid, float(k[0]), float(k[1]))
	return tid


## 通用：给动画添加一条 :position 轨道
func _add_pos_track(anim: Animation, bone: Node2D, keys: Array, axis: String = "y") -> int:
	var path := String(bone.get_path()) + ":position:" + axis
	var tid := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tid, path)
	for k in keys:
		var v: float = float(k[1])
		var base: float = bone.position.y if axis == "y" else bone.position.x
		# 对于 hip，position 是绝对值；对其它骨头用相对位移基线
		if bone == hip:
			anim.track_insert_key(tid, float(k[0]), v)
		else:
			anim.track_insert_key(tid, float(k[0]), base + v)
	return tid


func _finalize_anim(anim: Animation, name: String, length: float) -> void:
	anim.resource_name = name
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	anim_player.add_animation_library("", AnimationLibrary.new()) if not anim_player.has_animation_library("") else null
	# 注意：AnimationPlayer 在 4.x 必须用库；空字符串库为默认
	var lib: AnimationLibrary = anim_player.get_animation_library("")
	if not lib.has_animation(name):
		lib.add_animation(name, anim)


## idle：呼吸 + 微小摆动
func _add_idle_anim() -> void:
	var a := Animation.new()
	var dur := 3.0
	# 躯干轻微缩放呼吸（用 rotation 制造轻微摆动更稳）
	_add_rot_track(a, torso, [[0.0, 0.0], [dur * 0.5, 1.5], [dur, 0.0]])
	_add_rot_track(a, head, [[0.0, 0.0], [dur * 0.5, -1.0], [dur, 0.0]])
	_add_rot_track(a, upper_arm_r, [[0.0, 8.0], [dur * 0.5, 5.0], [dur, 8.0]])
	_add_rot_track(a, upper_arm_l, [[0.0, -8.0], [dur * 0.5, -5.0], [dur, -8.0]])
	# 头微微上下点头
	var head_y_path := String(head.get_path()) + ":position:y"
	var head_base_y: float = head.position.y
	var tid := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tid, head_y_path)
	a.track_insert_key(tid, 0.0, head_base_y)
	a.track_insert_key(tid, dur * 0.5, head_base_y + 1.0)
	a.track_insert_key(tid, dur, head_base_y)
	_finalize_anim(a, "idle", dur)


## fan：扇扇子 —— 右臂抬起，前臂+扇骨周期性扇动
func _add_fan_anim() -> void:
	var a := Animation.new()
	var dur := 1.2
	# 右上臂抬起 -120°（朝头顶外侧）
	_add_rot_track(a, upper_arm_r, [[0.0, -100.0], [dur, -100.0]])
	# 右前臂相对弯曲
	_add_rot_track(a, forearm_r, [[0.0, -30.0], [dur, -30.0]])
	# 右手（持扇）周期性扇动：主轨道
	_add_rot_track(a, hand_r, [
		[0.0, -40.0], [dur * 0.25, 30.0], [dur * 0.5, -40.0],
		[dur * 0.75, 30.0], [dur, -40.0]
	])
	# 身体配合轻微摆
	_add_rot_track(a, torso, [[0.0, 0.0], [dur * 0.5, -2.0], [dur, 0.0]])
	_add_rot_track(a, head, [[0.0, 0.0], [dur * 0.5, 2.0], [dur, 0.0]])
	# 左臂保持自然
	_add_rot_track(a, upper_arm_l, [[0.0, -8.0], [dur, -8.0]])
	_finalize_anim(a, "fan", dur)


## squat：蹲起 —— 髋下沉、膝盖弯曲、双臂前伸
func _add_squat_anim() -> void:
	var a := Animation.new()
	var dur := 1.5
	# 髋部 y 上下（position 是绝对坐标）
	var hip_path := String(hip.get_path()) + ":position:y"
	var hip_base_y: float = hip.position.y
	var tid := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tid, hip_path)
	a.track_insert_key(tid, 0.0, hip_base_y)
	a.track_insert_key(tid, dur * 0.5, hip_base_y + 28.0)
	a.track_insert_key(tid, dur, hip_base_y)
	# 大腿前倾
	_add_rot_track(a, thigh_r, [[0.0, 0.0], [dur * 0.5, 30.0], [dur, 0.0]])
	_add_rot_track(a, thigh_l, [[0.0, 0.0], [dur * 0.5, -30.0], [dur, 0.0]])
	# 小腿后弯（shin rotation 正 = 向后弯）
	_add_rot_track(a, shin_r, [[0.0, 0.0], [dur * 0.5, -45.0], [dur, 0.0]])
	_add_rot_track(a, shin_l, [[0.0, 0.0], [dur * 0.5, -45.0], [dur, 0.0]])
	# 双臂前伸（保持平衡）
	_add_rot_track(a, upper_arm_r, [[0.0, 8.0], [dur * 0.5, -85.0], [dur, 8.0]])
	_add_rot_track(a, upper_arm_l, [[0.0, -8.0], [dur * 0.5, 85.0], [dur, -8.0]])
	_add_rot_track(a, forearm_r, [[0.0, -4.0], [dur * 0.5, -10.0], [dur, -4.0]])
	_add_rot_track(a, forearm_l, [[0.0, 4.0], [dur * 0.5, 10.0], [dur, 4.0]])
	# 躯干微前倾
	_add_rot_track(a, torso, [[0.0, 0.0], [dur * 0.5, 5.0], [dur, 0.0]])
	_finalize_anim(a, "squat", dur)


# ============================================================
# 公共 API
# ============================================================

func play_anim(name: String) -> void:
	if anim_player and anim_player.has_animation(name):
		# 重置到中性姿态再播放，避免叠加
		anim_player.stop(true)
		_apply_rest_pose()
		anim_player.play(name)


func get_current_anim() -> String:
	if anim_player and anim_player.is_playing():
		return anim_player.current_animation
	return ""


func set_base_position(p: Vector2) -> void:
	position = p


func face_left() -> void:
	scale.x = -abs(scale.x)


func face_right() -> void:
	scale.x = abs(scale.x)


func face_front() -> void:
	scale.x = abs(scale.x)


func set_face_offset(_deg: float) -> void:
	pass  # 2D 版无偏航，面向摄像机


# ============================================================
# 自绘部件节点（内部类）
# ============================================================

class _Part:
	extends Node2D
	var draw_fn: Callable
	func _draw() -> void:
		if draw_fn.is_valid():
			draw_fn.call(self)
