extends Node2D

var target
var damage: float = 18.0
var speed: float = 470.0
var lifetime: float = 2.0
var age: float = 0.0
var alive: bool = true
var impacted: bool = false


func setup(target_node, hit_damage: float) -> void:
	target = target_node
	damage = hit_damage


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
	var points := PackedVector2Array([
		Vector2(0.0, -8.0),
		Vector2(4.0, 0.0),
		Vector2(0.0, 8.0),
		Vector2(-4.0, 0.0)
	])
	draw_colored_polygon(points, Color("#e9c65d"))
	draw_line(Vector2(0.0, -5.0), Vector2(0.0, 5.0), Color("#a94a32"), 1.5)
	draw_circle(Vector2.ZERO, 1.5, Color("#fff0b0"))
