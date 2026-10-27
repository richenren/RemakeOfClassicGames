extends Node2D

const WORLD_MIN := Vector2(48.0, 48.0)
const WORLD_MAX := Vector2(2352.0, 1552.0)
const CREATURES_ATLAS: Texture2D = preload("res://assets/sprites/creatures_atlas.png")
const PLAYER_IDLE_REGION := Rect2(37.0, 29.0, 53.0, 70.0)
const PLAYER_MOVE_REGION := Rect2(169.0, 29.0, 46.0, 70.0)

var main_ref: Node
var max_hp: float = 100.0
var hp: float = 100.0
var move_speed: float = 215.0
var damage: float = 18.0
var attack_interval: float = 0.82
var pickup_radius: float = 92.0
var invuln_time: float = 0.0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 6
var mobile_move: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.UP
var collision_radius: float = 13.0
var hit_flash: float = 0.0
var is_moving: bool = false


func tick(delta: float) -> void:
	invuln_time = maxf(0.0, invuln_time - delta)
	hit_flash = maxf(0.0, hit_flash - delta)

	var keyboard_move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard_move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard_move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard_move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard_move.y += 1.0

	var move_vector := keyboard_move if keyboard_move.length_squared() > 0.0 else mobile_move
	if move_vector.length_squared() > 1.0:
		move_vector = move_vector.normalized()
	is_moving = move_vector.length_squared() > 0.01
	if is_moving:
		facing = move_vector.normalized()
		position += move_vector * move_speed * delta

	position.x = clampf(position.x, WORLD_MIN.x, WORLD_MAX.x)
	position.y = clampf(position.y, WORLD_MIN.y, WORLD_MAX.y)
	queue_redraw()


func take_damage(amount: float) -> void:
	if invuln_time > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	invuln_time = 0.82
	hit_flash = 0.16
	queue_redraw()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	queue_redraw()


func gain_xp(amount: int) -> void:
	xp += amount


func _draw() -> void:
	# Soft ground shadow and a restrained talisman-gold rim help the sprite read on dark terrain.
	draw_set_transform(Vector2(0.0, 13.0), 0.0, Vector2(1.45, 0.48))
	draw_circle(Vector2.ZERO, 15.0, Color(0.015, 0.014, 0.012, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0.0, 13.0), 12.0, Color(0.66, 0.49, 0.23, 0.12))

	var sprite_region: Rect2 = PLAYER_MOVE_REGION if is_moving else PLAYER_IDLE_REGION
	var sprite_rect := Rect2(-24.0, -32.0, 48.0, 64.0)
	var tint := Color.WHITE
	if hit_flash > 0.0:
		tint = Color("#fff0d0")
	elif invuln_time > 0.0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		tint = Color(1.0, 1.0, 1.0, 0.62)

	if is_moving and facing.x < -0.1:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(CREATURES_ATLAS, sprite_rect, sprite_region, false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(CREATURES_ATLAS, sprite_rect, sprite_region, false, tint)
