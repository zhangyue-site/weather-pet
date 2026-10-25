extends Node2D
var duet: RefCounted
var actor: Node2D
var fish: Node2D
var was_active := false
var cup_style := StyleBoxFlat.new()
var cake_outline := PackedVector2Array()
func _ready() -> void:
	cup_style.bg_color=Color("fff5db"); cup_style.set_corner_radius_all(4)
	for i in range(48):
		var angle := TAU*float(i)/48
		cake_outline.append(Vector2(cos(angle),sin(angle))*(12.0+sin(angle*12.0)*0.8))
func _process(_delta: float) -> void:
	if duet == null: return
	if duet.active or was_active: queue_redraw()
	was_active = duet.active
func _cup(p: Vector2) -> void:
	draw_style_box(cup_style,Rect2(p-Vector2(8,7),Vector2(16,17)))
	draw_arc(p+Vector2(8,1),5,-PI/2,PI/2,10,Color("fff5db"),2,true)
	draw_line(p+Vector2(-5,-7),p+Vector2(5,-7),Color("825b40"),2,true)
func _cake(p: Vector2, bitten: bool) -> void:
	draw_set_transform(p)
	draw_colored_polygon(cake_outline,Color("b96b2d"))
	draw_circle(Vector2(0,-1),10,Color("e5ac56"))
	draw_arc(Vector2(0,-1),7,0,TAU,24,Color("ad632b"),1.3,true)
	draw_line(Vector2(-4,-4),Vector2(4,3),Color("ad632b"),1.4,true)
	draw_line(Vector2(-4,3),Vector2(4,-4),Color("ad632b"),1.4,true)
	if bitten:
		# A smaller held piece after tasting; crumbs make the hand-off consequence visible.
		draw_circle(Vector2(14,-9),1.5,Color("edc780"));draw_circle(Vector2(17,-5),1.0,Color("edc780"))
	draw_set_transform(Vector2.ZERO)
func _draw() -> void:
	if duet == null or not duet.active: return
	var prop := String(duet.current.get("prop",""))
	if prop.is_empty(): return
	var hand: Vector2 = actor.hand_point()
	var fish_hand: Vector2 = fish.hand_point()
	var t := smoothstep(0.0,1.0,clampf((duet.elapsed-1.0)/0.8,0,1))
	if prop == "drum":
		var center: Vector2 = actor.foot+Vector2(actor.world.look_direction*58,-58)
		draw_line(center+Vector2(-15,8),center+Vector2(-22,44),Color("6e3f29"),4,true)
		draw_line(center+Vector2(15,8),center+Vector2(22,44),Color("6e3f29"),4,true)
		draw_rect(Rect2(center-Vector2(23,2),Vector2(46,23)),Color("b84739"))
		draw_set_transform(center,0,Vector2(1,0.35));draw_circle(Vector2.ZERO,25,Color("efcb8a"));draw_set_transform(Vector2.ZERO)
		if actor.world.activity == "drum":
			var strike := absf(sin(duet.shared_time*5.0))
			var tip := center+Vector2(0,-5-strike*17)
			draw_line(hand,tip,Color("70452c"),3,true);draw_circle(tip,3,Color("b84739"))
	elif prop == "cup_offer":
		if duet.elapsed>=1.0: _cup(hand.lerp(fish_hand,t)+Vector2(0,-sin(t*PI)*8))
	elif prop == "shared_drink":
		pass # The received cup is held in the dedicated sipping pose.
	elif prop.ends_with("_offer"):
		if duet.elapsed>=1.0 and duet.elapsed<1.8: _cake(fish_hand.lerp(hand,t)+Vector2(0,-sin(t*PI)*8),false)
	elif prop.ends_with("_eat"):
		pass # The tasting pose holds the cake at the mouth; no floating overlay.
