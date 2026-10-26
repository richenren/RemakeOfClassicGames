extends Node2D

var value: int = 1
var age: float = 0.0
var pulse: float = 0.0


func setup(xp_value: int = 1) -> void:
	value = xp_value


func tick(delta: float, player_position: Vector2, pickup_radius: float) -> bool:
	age += delta
	pulse += delta * 5.0
	var offset := player_position - position
	var distance := offset.length()
	if distance < pickup_radius * 1.8 and distance > 1.0:
		var pull_speed := 170.0 if distance > pickup_radius else 280.0
		position += offset.normalized() * pull_speed * delta
	return distance < 17.0


func _draw() -> void:
	var glow_radius := 5.0 + sin(pulse) * 1.0
	draw_circle(Vector2.ZERO, glow_radius + 3.0, Color(0.2, 0.76, 0.66, 0.14))
	draw_circle(Vector2.ZERO, glow_radius, Color("#59c7a5"))
	draw_circle(Vector2(-1.0, -1.0), 2.0, Color("#d9fff0"))
