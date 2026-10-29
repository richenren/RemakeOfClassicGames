extends Node2D

const WORLD_MIN := Vector2(48.0, 48.0)
const WORLD_MAX := Vector2(2352.0, 1552.0)
const PLAYER_FRONT_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_front.tres")
const PLAYER_SIDE_LEFT_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_side_left.tres")
const PLAYER_BACK_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_back.tres")
const PLAYER_SIDE_RIGHT_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_side_right.tres")
const PLAYER_IDLE_TEXTURE: Texture2D = PLAYER_FRONT_TEXTURE
const PLAYER_WALK_TEXTURE: Texture2D = PLAYER_SIDE_RIGHT_TEXTURE
const PLAYER_DRAW_SIZE := Vector2(96.0, 171.0)
const PLAYER_DEATH_DRAW_SIZE := Vector2(115.2, 96.0)

# First integration pass: approved static four-direction artwork.
# State timing and movement feedback remain; matched action poses will be authored next.
const PLAYER_IDLE_FRAMES = [PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE]
const PLAYER_WALK_FRAMES = [PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE]
const PLAYER_ATTACK_FRAMES = [PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE]
const PLAYER_HIT_FRAMES = [PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE]
const PLAYER_DEATH_FRAMES = [
	preload("res://assets/sprites/player_frames/player_death_01.svg"),
	preload("res://assets/sprites/player_frames/player_death_02.svg"),
	preload("res://assets/sprites/player_frames/player_death_03.svg"),
	preload("res://assets/sprites/player_frames/player_death_04.svg"),
	preload("res://assets/sprites/player_frames/player_death_05.svg"),
	preload("res://assets/sprites/player_frames/player_death_06.svg")
]

const MOVE_ACCELERATION := 1500.0
const MOVE_DECELERATION := 1900.0

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
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var collision_radius: float = 13.0
var hit_flash: float = 0.0
var is_moving: bool = false
var animation_time: float = 0.0
var gait_phase: float = 0.0
var footstep_flash: float = 0.0
var footstep_side: float = 1.0
var attack_pulse: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT
var animation_state: String = "idle"
var animation_frame_index: int = 0
var animation_frame_elapsed: float = 0.0
var attack_animation_timer: float = 0.0
var hit_animation_timer: float = 0.0


func tick(delta: float) -> void:
	animation_time += delta
	invuln_time = maxf(0.0, invuln_time - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	footstep_flash = maxf(0.0, footstep_flash - delta)
	attack_pulse = maxf(0.0, attack_pulse - delta)
	attack_animation_timer = maxf(0.0, attack_animation_timer - delta)
	hit_animation_timer = maxf(0.0, hit_animation_timer - delta)

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
	var desired_velocity := move_vector * move_speed
	var acceleration := MOVE_ACCELERATION if move_vector.length_squared() > 0.001 else MOVE_DECELERATION
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	if velocity.length_squared() < 1.0 and move_vector.length_squared() < 0.001:
		velocity = Vector2.ZERO

	is_moving = velocity.length_squared() > 36.0
	if is_moving:
		var target_facing := attack_direction if attack_pulse > 0.0 else velocity.normalized()
		facing = facing.lerp(target_facing, clampf(delta * 13.0, 0.0, 1.0)).normalized()
		position += velocity * delta
		var old_phase := gait_phase
		var speed_ratio := clampf(velocity.length() / maxf(1.0, move_speed), 0.0, 1.0)
		gait_phase += delta * lerpf(4.5, 11.0, speed_ratio)
		if floori(gait_phase / PI) > floori(old_phase / PI):
			footstep_flash = 0.13
			footstep_side *= -1.0
	else:
		gait_phase += delta * 1.8

	position.x = clampf(position.x, WORLD_MIN.x, WORLD_MAX.x)
	position.y = clampf(position.y, WORLD_MIN.y, WORLD_MAX.y)
	_update_animation(delta)
	queue_redraw()


func trigger_attack(direction: Vector2) -> void:
	if direction.length_squared() > 0.001:
		attack_direction = direction.normalized()
		facing = attack_direction
	attack_pulse = 0.18
	attack_animation_timer = 0.30
	queue_redraw()


func _player_sprite_texture() -> Texture2D:
	return _directional_texture()


func _directional_texture() -> Texture2D:
	# Vertical movement uses front/back views; horizontal movement uses the matching profile.
	if absf(facing.y) >= absf(facing.x) * 1.15:
		return PLAYER_BACK_TEXTURE if facing.y < 0.0 else PLAYER_FRONT_TEXTURE
	return PLAYER_SIDE_LEFT_TEXTURE if facing.x < 0.0 else PLAYER_SIDE_RIGHT_TEXTURE


func _animation_frames_for_state(state: String) -> Array:
	match state:
		"walk":
			return PLAYER_WALK_FRAMES
		"attack":
			return PLAYER_ATTACK_FRAMES
		"hit":
			return PLAYER_HIT_FRAMES
		"death":
			return PLAYER_DEATH_FRAMES
		_:
			return PLAYER_IDLE_FRAMES


func _animation_frame_duration(state: String) -> float:
	match state:
		"walk":
			return 0.095
		"attack":
			return 0.065
		"hit":
			return 0.075
		"death":
			return 0.09
		_:
			return 0.18


func _current_animation_texture() -> Texture2D:
	if animation_state == "death":
		return PLAYER_DEATH_FRAMES[clampi(animation_frame_index, 0, PLAYER_DEATH_FRAMES.size() - 1)] as Texture2D
	return _directional_texture()


func _update_animation(delta: float) -> void:
	var next_state := "idle"
	if hp <= 0.0:
		next_state = "death"
	elif hit_animation_timer > 0.0:
		next_state = "hit"
	elif attack_animation_timer > 0.0:
		next_state = "attack"
	elif is_moving:
		next_state = "walk"

	if next_state != animation_state:
		animation_state = next_state
		animation_frame_index = 0
		animation_frame_elapsed = 0.0

	var frames: Array = _animation_frames_for_state(animation_state)
	if frames.is_empty() or (animation_state == "death" and animation_frame_index >= frames.size() - 1):
		return
	animation_frame_elapsed += delta
	var frame_duration := _animation_frame_duration(animation_state)
	while animation_frame_elapsed >= frame_duration:
		animation_frame_elapsed -= frame_duration
		if animation_state == "death":
			animation_frame_index = mini(animation_frame_index + 1, frames.size() - 1)
			if animation_frame_index >= frames.size() - 1:
				break
		else:
			animation_frame_index = (animation_frame_index + 1) % frames.size()


func take_damage(amount: float) -> void:
	if invuln_time > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	invuln_time = 0.82
	hit_flash = 0.16
	hit_animation_timer = 0.22
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
	var speed_ratio := clampf(velocity.length() / maxf(1.0, move_speed), 0.0, 1.0)
	var bob := sin(gait_phase * 2.0) * 1.45 * speed_ratio if is_moving else sin(animation_time * 2.1) * 0.55
	if animation_state == "death":
		bob = 0.0
	var squash_x := 1.0 + (gait * 0.028 * speed_ratio if is_moving else 0.0)
	var stretch_y := 1.0 - (gait * 0.018 * speed_ratio if is_moving else 0.0)
	var gait_lean := sin(gait_phase) * 0.035 * speed_ratio if is_moving else 0.0
	var sprite_tilt := clampf(facing.x * 0.075, -0.075, 0.075) + gait_lean if is_moving else sin(animation_time * 0.8) * 0.01
	var attack_ratio := clampf(attack_pulse / 0.18, 0.0, 1.0)
	var attack_offset := attack_direction * attack_ratio * 2.4 if animation_state == "attack" else Vector2.ZERO
	var sprite_size := PLAYER_DEATH_DRAW_SIZE if animation_state == "death" else PLAYER_DRAW_SIZE
	var sprite_rect := Rect2(-sprite_size * 0.5, sprite_size)
	var tint := Color("#eee5d0")
	if hit_flash > 0.0:
		tint = Color("#fff0d0")
	elif invuln_time > 0.0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		tint = Color(1.0, 1.0, 1.0, 0.62)

	# Layered soft shadow + warm floor bounce prevent the larger full-body sprite from reading as a flat sticker.
	var shadow_y := PLAYER_DRAW_SIZE.y * 0.47
	draw_set_transform(Vector2(0.0, shadow_y + absf(bob) * 0.12), 0.0, Vector2(1.46 + gait * 0.03, 0.34 - gait * 0.012))
	draw_circle(Vector2.ZERO, 25.0, Color(0.015, 0.014, 0.012, 0.40))
	draw_circle(Vector2.ZERO, 15.0, Color(0.015, 0.014, 0.012, 0.23))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0.0, shadow_y + 3.0), 0.0, Vector2(1.4, 0.34))
	draw_circle(Vector2.ZERO, 18.0, Color(0.66, 0.49, 0.23, 0.065))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0.0, shadow_y + 4.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 15.0, Color(0.015, 0.014, 0.012, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_moving and footstep_flash > 0.0:
		var dust_alpha := footstep_flash / 0.13 * 0.2
		draw_circle(Vector2(-10.0 * footstep_side, PLAYER_DRAW_SIZE.y * 0.40), 3.2, Color(0.70, 0.62, 0.43, dust_alpha))
		draw_circle(Vector2(-13.0 * footstep_side, PLAYER_DRAW_SIZE.y * 0.42), 2.0, Color(0.70, 0.62, 0.43, dust_alpha * 0.7))

	# Directional artwork is already oriented; never mirror the sword onto the wrong shoulder.
	draw_set_transform(attack_offset + Vector2(0.0, bob), sprite_tilt, Vector2(squash_x, stretch_y))
	draw_texture_rect(_current_animation_texture(), sprite_rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if attack_ratio > 0.0:
		var attack_angle := attack_direction.angle()
		draw_arc(Vector2(0.0, 5.0), 23.0, attack_angle - 0.52, attack_angle + 0.52, 14, Color("#f0d89c", attack_ratio * 0.72), 2.0, true)
