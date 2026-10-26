extends Node2D

var kind: String = "walker"
var max_hp: float = 30.0
var hp: float = 30.0
var move_speed: float = 65.0
var contact_damage: float = 8.0
var collision_radius: float = 12.0
var is_boss: bool = false
var hit_flash: float = 0.0
var slow_timer: float = 0.0
var slow_multiplier: float = 1.0


func setup(enemy_kind: String) -> void:
	kind = enemy_kind
	match kind:
		"jumper":
			max_hp = 25.0
			move_speed = 108.0
			contact_damage = 10.0
			collision_radius = 11.0
		"armored":
			max_hp = 92.0
			move_speed = 42.0
			contact_damage = 14.0
			collision_radius = 16.0
		"boss":
			is_boss = true
			max_hp = 1200.0
			move_speed = 54.0
			contact_damage = 22.0
			collision_radius = 34.0
		_:
			kind = "walker"
			max_hp = 34.0
			move_speed = 64.0
			contact_damage = 8.0
			collision_radius = 12.0
	hp = max_hp
	queue_redraw()


func tick(delta: float, player_position: Vector2, separation: Vector2) -> void:
	hit_flash = maxf(0.0, hit_flash - delta)
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - delta)
		if slow_timer <= 0.0:
			slow_multiplier = 1.0

	var direction := player_position - position
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	else:
		direction = Vector2.ZERO

	if separation.length_squared() > 0.001:
		direction = (direction + separation * 0.75).normalized()

	if direction != Vector2.ZERO:
		position += direction * move_speed * slow_multiplier * delta

	position.x = clampf(position.x, 30.0, 2370.0)
	position.y = clampf(position.y, 30.0, 1570.0)
	queue_redraw()


func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	hit_flash = 0.12
	queue_redraw()


func apply_slow(duration: float, multiplier: float) -> void:
	if is_boss:
		duration *= 0.35
		multiplier = maxf(multiplier, 0.72)
	slow_timer = maxf(slow_timer, duration)
	slow_multiplier = minf(slow_multiplier, multiplier)


func _draw() -> void:
	var body_color := Color("#73776a")
	var robe_color := Color("#454b43")
	match kind:
		"jumper":
			body_color = Color("#a7a18b")
			robe_color = Color("#55483d")
		"armored":
			body_color = Color("#777d7a")
			robe_color = Color("#353d3e")
		"boss":
			body_color = Color("#8b7866")
			robe_color = Color("#302b2d")

	if hit_flash > 0.0:
		body_color = Color("#eee0bc")
		robe_color = Color("#b9a989")

	var r := collision_radius
	draw_circle(Vector2(0.0, 4.0), r + 3.0, Color(0.02, 0.02, 0.02, 0.3))
	var torso := PackedVector2Array([
		Vector2(0.0, -r * 0.78),
		Vector2(r * 0.72, -r * 0.25),
		Vector2(r * 0.82, r * 0.52),
		Vector2(0.0, r * 0.86),
		Vector2(-r * 0.82, r * 0.52),
		Vector2(-r * 0.72, -r * 0.25)
	])
	draw_colored_polygon(torso, robe_color)
	draw_circle(Vector2(0.0, -r * 0.42), r * 0.48, body_color)
	draw_circle(Vector2(-r * 0.2, -r * 0.45), maxf(1.5, r * 0.08), Color("#b94e3b"))
	draw_circle(Vector2(r * 0.2, -r * 0.45), maxf(1.5, r * 0.08), Color("#b94e3b"))

	if kind == "armored" or kind == "boss":
		draw_line(Vector2(-r * 0.65, -r * 0.05), Vector2(r * 0.65, -r * 0.05), Color("#a08a60"), maxf(2.0, r * 0.12))
		draw_line(Vector2(-r * 0.58, r * 0.3), Vector2(r * 0.58, r * 0.3), Color("#a08a60"), maxf(2.0, r * 0.1))
	if kind == "boss":
		draw_line(Vector2(-r * 0.7, -r * 0.65), Vector2(-r * 1.0, -r * 1.1), Color("#b39a69"), 4.0)
		draw_line(Vector2(r * 0.7, -r * 0.65), Vector2(r * 1.0, -r * 1.1), Color("#b39a69"), 4.0)

	var bar_width := 72.0 if is_boss else 30.0
	var bar_height := 5.0 if is_boss else 3.0
	var bar_y := -r - (19.0 if is_boss else 11.0)
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, bar_height), Color("#191715"))
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var hp_color := Color("#a84c3e") if is_boss else Color("#9d5144")
	if ratio < 0.3:
		hp_color = Color("#d06b48")
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * ratio, bar_height), hp_color)
	if is_boss:
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, bar_height), Color("#c0a36e"), false, 1.0)
