extends Node2D

const WORLD_MIN := Vector2(48.0, 48.0)
const WORLD_MAX := Vector2(2352.0, 1552.0)
const PLAYER_FRONT_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_front.tres")
const PLAYER_SIDE_LEFT_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_side_left.tres")
const PLAYER_BACK_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_back.tres")
const PLAYER_SIDE_RIGHT_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_side_right.tres")
const PLAYER_IDLE_TEXTURE: Texture2D = PLAYER_FRONT_TEXTURE
const PLAYER_WALK_TEXTURE: Texture2D = PLAYER_SIDE_RIGHT_TEXTURE
const PLAYER_WALK_ATLASES = [
	preload("res://assets/sprites/player_taoist_walk_front_8f.png"),
	preload("res://assets/sprites/player_taoist_walk_side_left_8f.png"),
	preload("res://assets/sprites/player_taoist_walk_back_8f.png"),
	preload("res://assets/sprites/player_taoist_walk_side_right_8f.png")
]
const PLAYER_WALK_FRAME_SIZE := Vector2(48.0, 64.0)
const PLAYER_WALK_DRAW_SIZE := Vector2(52.0, 72.0)
const PLAYER_DRAW_SIZE := Vector2(52.0, 72.0)
const PLAYER_DEATH_DRAW_SIZE := Vector2(58.0, 48.0)
const CAST_DURATION := 0.40
const CAST_TALISMAN_REACH := 7.0
const PLAYER_CAST_FRAMES = [0, 1, 2, 3, 4, 5]

# Idle/attack/hit currently use the approved directional stills. Walking uses four dedicated
# 8-frame row atlases in front/left/back/right order; all views keep the sheathed sword visible.
const PLAYER_IDLE_FRAMES = [PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE, PLAYER_FRONT_TEXTURE]
const PLAYER_WALK_FRAMES = [0, 1, 2, 3, 4, 5, 6, 7]
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
var cast_animation_timer: float = 0.0
var cast_direction: Vector2 = Vector2.DOWN
var cast_element: String = "neutral"
var hit_animation_timer: float = 0.0


func tick(delta: float) -> void:
	animation_time += delta
	invuln_time = maxf(0.0, invuln_time - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	footstep_flash = maxf(0.0, footstep_flash - delta)
	attack_pulse = maxf(0.0, attack_pulse - delta)
	attack_animation_timer = maxf(0.0, attack_animation_timer - delta)
	cast_animation_timer = maxf(0.0, cast_animation_timer - delta)
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
		var target_facing := cast_direction if cast_animation_timer > 0.0 else (attack_direction if attack_pulse > 0.0 else velocity.normalized())
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


static func cast_element_for_skill(skill_id: String) -> String:
	match skill_id:
		"copper_coin_sword":
			return "metal"
		"water_array":
			return "water"
		"fire_talisman":
			return "fire"
		"thunder_talisman", "five_thunder":
			return "lightning"
		_:
			return "neutral"


func _cast_hand_anchor_local(direction: Vector2) -> Vector2:
	# The seal sits at the leading hand for the selected four-way facing.
	if absf(direction.x) >= absf(direction.y) * 1.05:
		return Vector2(signf(direction.x) * 8.0, -6.5)
	if direction.y >= 0.0:
		return Vector2(7.0, -2.5)
	return Vector2(-7.0, -8.0)


func cast_hand_world_position(direction: Vector2) -> Vector2:
	var aim := direction.normalized() if direction.length_squared() > 0.001 else facing.normalized()
	return global_position + _cast_hand_anchor_local(aim) + aim * CAST_TALISMAN_REACH


func trigger_cast(direction: Vector2, duration: float = CAST_DURATION, element: String = "neutral") -> void:
	if direction.length_squared() > 0.001:
		cast_direction = direction.normalized()
		facing = cast_direction
	cast_element = element if element in ["metal", "water", "fire", "lightning"] else "neutral"
	cast_animation_timer = maxf(cast_animation_timer, duration)
	animation_frame_index = 0
	animation_frame_elapsed = 0.0
	queue_redraw()


func trigger_attack(direction: Vector2) -> void:
	if direction.length_squared() > 0.001:
		attack_direction = direction.normalized()
	trigger_cast(attack_direction, CAST_DURATION)
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


func _walk_direction_row() -> int:
	if absf(facing.y) >= absf(facing.x) * 1.15:
		return 2 if facing.y < 0.0 else 0
	return 1 if facing.x < 0.0 else 3


func _walk_frame_region() -> Rect2:
	var frame_index := clampi(animation_frame_index, 0, PLAYER_WALK_FRAMES.size() - 1)
	return Rect2(float(frame_index) * PLAYER_WALK_FRAME_SIZE.x, 0.0, PLAYER_WALK_FRAME_SIZE.x, PLAYER_WALK_FRAME_SIZE.y)


func _walk_atlas_for_direction() -> Texture2D:
	return PLAYER_WALK_ATLASES[_walk_direction_row()] as Texture2D


func _animation_frames_for_state(state: String) -> Array:
	match state:
		"walk":
			return PLAYER_WALK_FRAMES
		"cast":
			return PLAYER_CAST_FRAMES
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
			# Keep the sprite cadence in phase with gait_phase.
			var speed_ratio := clampf(velocity.length() / maxf(1.0, move_speed), 0.0, 1.0)
			var gait_speed := lerpf(4.5, 11.0, speed_ratio)
			return TAU / (gait_speed * float(PLAYER_WALK_FRAMES.size()))
		"cast":
			return CAST_DURATION / float(PLAYER_CAST_FRAMES.size())
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
	elif cast_animation_timer > 0.0:
		next_state = "cast"
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


func _draw_cast_pose() -> void:
	# Keep the seal close to the palm and body silhouette. The character artwork already
	# contains its arm; drawing another long arm here created a detached torch-like shape.
	var progress := 1.0 - clampf(cast_animation_timer / CAST_DURATION, 0.0, 1.0)
	var direction := cast_direction.normalized()
	var side := Vector2(-direction.y, direction.x)
	var hand_anchor := _cast_hand_anchor_local(direction)
	var reach := lerpf(1.0, CAST_TALISMAN_REACH, smoothstep(0.08, 0.62, progress))
	var talisman_center := hand_anchor + direction * reach
	var pulse := sin(progress * PI)
	var paper_alpha := 0.9 - progress * 0.08

	# Keep the seal visibly attached to the leading hand; no detached arm/torch geometry.
	draw_circle(talisman_center, 5.0 + pulse * 2.0, Color(0.88, 0.61, 0.25, 0.06 + pulse * 0.14))
	draw_set_transform(talisman_center, direction.angle() + PI * 0.5, Vector2.ONE)
	draw_rect(Rect2(-2.6, -4.8, 5.2, 9.6), Color("#e7d4a6", paper_alpha))
	draw_rect(Rect2(-2.6, -4.8, 5.2, 9.6), Color("#8f382d", 0.96), false, 0.85)
	if cast_element == "lightning":
		var seal_bolt := PackedVector2Array([Vector2(-0.8, -3.0), Vector2(0.8, -1.0), Vector2(-0.7, 0.7), Vector2(0.8, 3.0)])
		draw_polyline(seal_bolt, Color("#7043bd", 0.98), 1.15, true)
	else:
		draw_line(Vector2(0.0, -3.0), Vector2(0.0, 3.0), Color("#a22d26", 0.92), 0.85, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if progress > 0.18:
		var arc_radius := 7.0 + pulse * 1.5
		draw_arc(talisman_center, arc_radius, direction.angle() - 0.72, direction.angle() + 0.72, 12, Color("#e3bd75", 0.22 * pulse), 0.8, true)
		_draw_cast_element_effect(talisman_center, direction, progress, pulse)


func _draw_cast_element_effect(center: Vector2, direction: Vector2, progress: float, pulse: float) -> void:
	# Element accents stay small and close to the held seal; they never form a large aura.
	var side := Vector2(-direction.y, direction.x)
	match cast_element:
		"metal":
			var gold := Color("#f0c56a", 0.78 * pulse)
			draw_arc(center, 5.8 + pulse * 1.2, 0.0, TAU, 16, gold, 1.0, true)
			for i in range(3):
				var offset := side * (float(i) - 1.0) * 5.0 - direction * (2.0 + float(i % 2) * 2.0)
				draw_line(center + offset + Vector2(-1.2, 0.0), center + offset + Vector2(1.2, 0.0), gold, 1.0, true)
				draw_line(center + offset + Vector2(0.0, -1.2), center + offset + Vector2(0.0, 1.2), gold, 1.0, true)
		"water":
			var cyan := Color("#69d9ef", 0.72 * pulse)
			draw_arc(center, 6.0 + pulse, -0.9, 1.0, 14, cyan, 1.2, true)
			draw_circle(center + side * 6.0 - direction * 2.0, 1.35, Color("#d5faff", 0.82 * pulse))
			draw_circle(center - side * 5.0 + direction * 1.0, 1.0, cyan)
		"fire":
			var ember := Color("#ff8a43", 0.78 * pulse)
			for i in range(3):
				var offset := side * (float(i) - 1.0) * 4.0 - direction * (3.0 + float(i % 2) * 2.0)
				draw_circle(center + offset, 1.0 + pulse * 0.45, ember)
				draw_circle(center + offset - direction * 1.2, 0.55, Color("#ffe7a6", 0.76 * pulse))
		"lightning":
			var electric := Color("#a98aff", 0.9 * pulse)
			var bolt := PackedVector2Array([center - direction * 6.0 - side * 2.5, center - direction * 2.0 + side * 2.0, center + direction * 1.0 - side * 1.8, center + direction * 5.0 + side * 2.5])
			draw_arc(center, 8.0 + pulse * 2.0, direction.angle() - 1.05, direction.angle() + 1.05, 18, Color("#9d70ff", 0.72 * pulse), 1.45, true)
			draw_polyline(bolt, electric, 2.0, true)
			draw_circle(center + direction * 5.0 + side * 2.5, 1.35, Color("#f5efff", 0.98 * pulse))
			draw_circle(center - direction * 5.0 - side * 1.5, 1.0, Color("#d4c0ff", 0.86 * pulse))
		_:
			pass


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
	# Walking is driven by real leg/robe frames. Keep the torso at a stable height instead
	# of adding the old sine-wave bob, squash and lean that made the character look airborne.
	var bob := 0.0 if is_moving else sin(animation_time * 2.1) * 0.28
	if animation_state == "death":
		bob = 0.0
	var sprite_tilt := 0.0 if is_moving else sin(animation_time * 0.8) * 0.004
	var attack_ratio := clampf(attack_pulse / 0.18, 0.0, 1.0)
	var attack_offset := attack_direction * attack_ratio * 2.4 if animation_state == "attack" else Vector2.ZERO
	var sprite_size := PLAYER_DEATH_DRAW_SIZE if animation_state == "death" else (PLAYER_WALK_DRAW_SIZE if animation_state == "walk" else PLAYER_DRAW_SIZE)
	var sprite_rect := Rect2(-sprite_size * 0.5, sprite_size)
	var tint := Color("#eee5d0")
	if hit_flash > 0.0:
		tint = Color("#fff0d0")
	elif invuln_time > 0.0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		tint = Color(1.0, 1.0, 1.0, 0.62)

	# Layered soft shadow + warm floor bounce prevent the larger full-body sprite from reading as a flat sticker.
	var shadow_y := PLAYER_DRAW_SIZE.y * 0.47
	draw_set_transform(Vector2(0.0, shadow_y + absf(bob) * 0.12), 0.0, Vector2(1.46 + gait * 0.03, 0.34 - gait * 0.012))
	draw_circle(Vector2.ZERO, 16.0, Color(0.015, 0.014, 0.012, 0.40))
	draw_circle(Vector2.ZERO, 10.0, Color(0.015, 0.014, 0.012, 0.23))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0.0, shadow_y + 3.0), 0.0, Vector2(1.4, 0.34))
	draw_circle(Vector2.ZERO, 12.0, Color(0.66, 0.49, 0.23, 0.065))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0.0, shadow_y + 4.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 10.0, Color(0.015, 0.014, 0.012, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_moving and footstep_flash > 0.0:
		var dust_alpha := footstep_flash / 0.13 * 0.2
		draw_circle(Vector2(-8.0 * footstep_side, PLAYER_DRAW_SIZE.y * 0.40), 2.6, Color(0.70, 0.62, 0.43, dust_alpha))
		draw_circle(Vector2(-10.0 * footstep_side, PLAYER_DRAW_SIZE.y * 0.42), 1.6, Color(0.70, 0.62, 0.43, dust_alpha * 0.7))

	# Directional artwork is already oriented; never mirror the sword onto the wrong shoulder.
	draw_set_transform(attack_offset + Vector2(0.0, bob), sprite_tilt, Vector2.ONE)
	if animation_state == "walk":
		draw_texture_rect_region(_walk_atlas_for_direction(), sprite_rect, _walk_frame_region(), tint, false)
	else:
		draw_texture_rect(_current_animation_texture(), sprite_rect, false, tint)
	if animation_state == "cast":
		_draw_cast_pose()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if attack_ratio > 0.0:
		var attack_angle := attack_direction.angle()
		draw_arc(Vector2(0.0, 5.0), 23.0, attack_angle - 0.52, attack_angle + 0.52, 14, Color("#f0d89c", attack_ratio * 0.72), 2.0, true)
