extends Node2D

const CREATURES_ATLAS: Texture2D = preload("res://assets/sprites/creatures_atlas.png")
const WALKER_REGION := Rect2(300.0, 29.0, 40.0, 70.0)
const JUMPER_REGION := Rect2(43.0, 158.0, 42.0, 68.0)
const ARMORED_REGION := Rect2(166.0, 157.0, 51.0, 70.0)
const BOSS_REGION := Rect2(280.0, 146.0, 80.0, 91.0)

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
	var sprite_region: Rect2 = WALKER_REGION
	var sprite_rect := Rect2(-21.0, -30.0, 42.0, 59.0)
	var bar_width := 40.0
	match kind:
		"jumper":
			sprite_region = JUMPER_REGION
			sprite_rect = Rect2(-22.0, -29.0, 44.0, 57.0)
			bar_width = 40.0
		"armored":
			sprite_region = ARMORED_REGION
			sprite_rect = Rect2(-27.0, -34.0, 54.0, 67.0)
			bar_width = 46.0
		"boss":
			sprite_region = BOSS_REGION
			sprite_rect = Rect2(-49.0, -57.0, 98.0, 112.0)

	# Grounding shadows preserve readability when sprites overlap.
	var shadow_radius := 18.0 if not is_boss else 42.0
	draw_set_transform(Vector2(0.0, 13.0 if not is_boss else 23.0), 0.0, Vector2(1.45, 0.46))
	draw_circle(Vector2.ZERO, shadow_radius, Color(0.01, 0.012, 0.01, 0.46))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_boss:
		draw_circle(Vector2(0.0, 16.0), 48.0, Color(0.36, 0.08, 0.07, 0.13))
	elif kind == "armored":
		draw_circle(Vector2(0.0, 12.0), 21.0, Color(0.45, 0.40, 0.29, 0.10))

	if slow_timer > 0.0:
		draw_arc(Vector2(0.0, 9.0), collision_radius + 7.0, 0.0, TAU, 36, Color(0.45, 0.74, 0.62, 0.72), 2.0)

	var tint := Color("#fff0d0") if hit_flash > 0.0 else Color.WHITE
	draw_texture_rect_region(CREATURES_ATLAS, sprite_rect, sprite_region, tint, false)

	# Ordinary enemies keep compact health bars above the sprite; the boss uses the dedicated HUD bar.
	if not is_boss:
		var bar_y := sprite_rect.position.y - 6.0
		var bar_rect := Rect2(-bar_width * 0.5, bar_y, bar_width, 4.0)
		draw_rect(bar_rect, Color("#171612"))
		var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		var hp_color := Color("#b45b4a") if ratio >= 0.3 else Color("#d17a4e")
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), hp_color)
		draw_rect(bar_rect, Color(0.72, 0.60, 0.42, 0.72), false, 1.0)
