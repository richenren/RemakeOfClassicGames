extends Node2D

var target
var damage: float = 18.0
var speed: float = 470.0
var lifetime: float = 2.0
var age: float = 0.0
var alive: bool = true
var impacted: bool = false
var skill_id: String = "basic_talisman"


func setup(target_node, hit_damage: float, attack_skill_id: String = "basic_talisman") -> void:
	target = target_node
	damage = hit_damage
	skill_id = attack_skill_id
	match skill_id:
		"thunder_talisman", "five_thunder":
			speed = 560.0
		"copper_coin_sword":
			speed = 520.0
		"peachwood_sword":
			speed = 500.0
		"fire_talisman":
			speed = 450.0
		_:
			speed = 470.0


func tick(delta: float) -> void:
	if not alive:
		return
	age += delta
	if age >= lifetime or not is_instance_valid(target):
		alive = false
		return

	var offset: Vector2 = target.position - position
	var distance := offset.length()
	if distance <= speed * delta + target.collision_radius:
		position = target.position
		impacted = true
		alive = false
		queue_redraw()
		return

	if distance > 0.001:
		var direction := offset / distance
		position += direction * speed * delta
		rotation = direction.angle() + PI * 0.5
	queue_redraw()


func _draw() -> void:
	match skill_id:
		"fire_talisman":
			var flame := PackedVector2Array([
				Vector2(0.0, -10.0), Vector2(5.0, -2.0), Vector2(4.0, 5.0),
				Vector2(0.0, 9.0), Vector2(-4.0, 4.0), Vector2(-5.0, -2.0)
			])
			draw_colored_polygon(flame, Color("#e87545"))
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -5.0), Vector2(2.0, 1.0), Vector2(0.0, 5.0), Vector2(-2.0, 1.0)]), Color("#ffd27b"))
		"thunder_talisman", "five_thunder":
			var bolt := PackedVector2Array([
				Vector2(2.0, -10.0), Vector2(-5.0, 0.0), Vector2(-1.0, 0.0),
				Vector2(-3.0, 9.0), Vector2(6.0, -2.0), Vector2(2.0, -2.0)
			])
			draw_colored_polygon(bolt, Color("#f0d66d"))
			draw_polyline(PackedVector2Array([Vector2(2.0, -10.0), Vector2(-5.0, 0.0), Vector2(-1.0, 0.0), Vector2(-3.0, 9.0)]), Color("#fff3b0"), 1.2, true)
		"copper_coin_sword":
			draw_circle(Vector2.ZERO, 7.0, Color("#c99b4e"))
			draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 28, Color("#f4d68b"), 1.5)
			draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), Color("#473725"))
		"peachwood_sword":
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -11.0), Vector2(3.0, -3.0), Vector2(2.0, 7.0), Vector2(-2.0, 7.0), Vector2(-3.0, -3.0)]), Color("#d8c7a1"))
			draw_line(Vector2(-4.0, 2.0), Vector2(4.0, 2.0), Color("#9d5b42"), 2.0)
			draw_line(Vector2(0.0, 7.0), Vector2(0.0, 11.0), Color("#7a4c36"), 2.0)
		_:
			var talisman := PackedVector2Array([
				Vector2(0.0, -8.0), Vector2(4.0, 0.0),
				Vector2(0.0, 8.0), Vector2(-4.0, 0.0)
			])
			draw_colored_polygon(talisman, Color("#e9c65d"))
			draw_line(Vector2(0.0, -5.0), Vector2(0.0, 5.0), Color("#a94a32"), 1.5)
			draw_circle(Vector2.ZERO, 1.5, Color("#fff0b0"))
