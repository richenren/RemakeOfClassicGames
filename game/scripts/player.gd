extends Node2D

const WORLD_MIN := Vector2(48.0, 48.0)
const WORLD_MAX := Vector2(2352.0, 1552.0)
const PLAYER_IDLE_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist.svg")
const PLAYER_WALK_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_walk.svg")
const PLAYER_DRAW_SIZE := Vector2(104.0, 136.0)

var main_ref: Node
var max_hp: float = 100.0
var hp: float = 100.0
var move_speed: float = 215.0
var damage: float = 18.0
var attack_interval: float = 0.82
var pickup_radius: float = 92.0
var xp_gain_multiplier: float = 1.0
var xp_fractional: float = 0.0
var invuln_time: float = 0.0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 6
var mobile_move: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.UP
var collision_radius: float = 13.0
var hit_flash: float = 0.0
var is_moving: bool = false
var animation_time: float = 0.0
var gait_phase: float = 0.0
var footstep_flash: float = 0.0
var footstep_side: float = 1.0


func tick(delta: float) -> void:
	animation_time += delta
	invuln_time = maxf(0.0, invuln_time - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	footstep_flash = maxf(0.0, footstep_flash - delta)

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
		var old_phase := gait_phase
		gait_phase += delta * 11.0
		if floori(gait_phase / PI) > floori(old_phase / PI):
			footstep_flash = 0.13
			footstep_side *= -1.0
	else:
		gait_phase += delta * 2.0

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
	var total_xp := float(amount) * xp_gain_multiplier + xp_fractional
	var whole_xp := floori(total_xp)
	xp_fractional = total_xp - float(whole_xp)
	xp += whole_xp


func _draw() -> void:
	var gait := absf(sin(gait_phase))
	# Keep the torso grounded; step changes are carried by the two existing poses,
	# alternating footfall dust and a subtle side-to-side weight shift.
	var bob := gait * 0.65 if is_moving else sin(animation_time * 2.1) * 0.45
	var squash_x := 1.0 + (gait * 0.018 if is_moving else 0.0)
	var stretch_y := 1.0 - (gait * 0.012 if is_moving else 0.0)
	var gait_lean := sin(gait_phase) * 0.028 if is_moving else 0.0
	var sprite_tilt := clampf(facing.x * 0.06, -0.06, 0.06) + gait_lean if is_moving else sin(animation_time * 0.8) * 0.008
	# Use two hand-detailed, transparent poses rather than rotating one static atlas cell.
	# The walk frame changes with the footfall cadence, so robe and arms visibly follow the stride.
	var sprite_texture: Texture2D = PLAYER_IDLE_TEXTURE
	if is_moving and floori(gait_phase / PI) % 2 == 0:
		sprite_texture = PLAYER_WALK_TEXTURE
	var sprite_rect := Rect2(-PLAYER_DRAW_SIZE * 0.5, PLAYER_DRAW_SIZE)
	var tint := Color.WHITE
	if hit_flash > 0.0:
		tint = Color("#fff0d0")
	elif invuln_time > 0.0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		tint = Color(1.0, 1.0, 1.0, 0.62)

	# The shadow stays on the ground while the body bobs and leans during each step.
	draw_set_transform(Vector2(0.0, 36.0 + absf(bob) * 0.15), 0.0, Vector2(1.45 + gait * 0.04, 0.48 - gait * 0.015))
	draw_circle(Vector2.ZERO, 15.0, Color(0.015, 0.014, 0.012, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0.0, 35.0), 19.0, Color(0.66, 0.49, 0.23, 0.12))

	if is_moving and footstep_flash > 0.0:
		var dust_alpha := footstep_flash / 0.13 * 0.22
		draw_circle(Vector2(-11.0 * footstep_side, 59.0), 4.0, Color(0.70, 0.62, 0.43, dust_alpha))
		draw_circle(Vector2(-14.0 * footstep_side, 61.0), 2.5, Color(0.70, 0.62, 0.43, dust_alpha * 0.75))

	var flip_x := -1.0 if facing.x < -0.1 else 1.0
	draw_set_transform(Vector2(0.0, bob), sprite_tilt, Vector2(flip_x * squash_x, stretch_y))
	draw_texture_rect(sprite_texture, sprite_rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
