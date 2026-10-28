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
var wet_timer: float = 0.0
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var animation_time: float = 0.0
var gait_phase: float = 0.0
var facing_direction: Vector2 = Vector2.LEFT
var is_moving: bool = false
var hop_height: float = 0.0
var footstep_flash: float = 0.0
var footstep_side: float = 1.0
var boss_phase: int = 1
var boss_action: String = "idle"
var boss_action_timer: float = 0.0
var boss_cooldown: float = 2.4
var boss_last_action: String = ""
var boss_charge_direction: Vector2 = Vector2.LEFT
var boss_attack_target: Vector2 = Vector2.ZERO
var boss_attack_event: String = ""


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
	animation_time += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	footstep_flash = maxf(0.0, footstep_flash - delta)
	wet_timer = maxf(0.0, wet_timer - delta)
	if burn_timer > 0.0:
		burn_timer = maxf(0.0, burn_timer - delta)
		hp = maxf(0.0, hp - burn_dps * delta)
		if burn_timer <= 0.0:
			burn_dps = 0.0
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - delta)
		if slow_timer <= 0.0:
			slow_multiplier = 1.0

	if is_boss:
		_tick_boss(delta, player_position)
		position.x = clampf(position.x, 30.0, 2370.0)
		position.y = clampf(position.y, 30.0, 1570.0)
		queue_redraw()
		return

	var direction := player_position - position
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	else:
		direction = Vector2.ZERO

	if separation.length_squared() > 0.001:
		direction = (direction + separation * 0.75).normalized()

	is_moving = direction.length_squared() > 0.001
	if is_moving:
		facing_direction = direction
		position += direction * move_speed * slow_multiplier * delta

	var cadence := 14.0 if kind == "jumper" else (4.0 if kind == "armored" else 7.2)
	var old_phase := gait_phase
	gait_phase += delta * (cadence if is_moving else 1.4)
	if is_moving and floori(gait_phase / PI) > floori(old_phase / PI):
		footstep_flash = 0.12 if kind != "armored" else 0.16
		footstep_side *= -1.0
	hop_height = pow(maxf(0.0, sin(gait_phase)), 2.0) * 6.0 if kind == "jumper" and is_moving else 0.0

	position.x = clampf(position.x, 30.0, 2370.0)
	position.y = clampf(position.y, 30.0, 1570.0)
	queue_redraw()


func _tick_boss(delta: float, player_position: Vector2) -> void:
	boss_attack_event = ""
	if boss_phase == 1 and hp <= max_hp * 0.5:
		boss_phase = 2
		boss_action = "phase_shift"
		boss_action_timer = 0.9
		boss_cooldown = 1.0
		return

	if boss_action == "phase_shift":
		is_moving = false
		boss_action_timer -= delta
		if boss_action_timer <= 0.0:
			boss_action = "idle"
			boss_cooldown = 0.8
		return

	if boss_action in ["charge_windup", "slam_windup", "zone_windup"]:
		boss_action_timer -= delta
		if boss_action_timer <= 0.0:
			match boss_action:
				"charge_windup":
					boss_charge_direction = (boss_attack_target - position).normalized()
					if boss_charge_direction.length_squared() < 0.001:
						boss_charge_direction = facing_direction
					boss_action = "charge"
					boss_action_timer = 0.5 if boss_phase == 2 else 0.42
				"slam_windup":
					boss_attack_event = "slam"
					boss_action = "recovery"
					boss_action_timer = 0.42 if boss_phase == 2 else 0.58
				"zone_windup":
					boss_attack_event = "zone"
					boss_action = "recovery"
					boss_action_timer = 0.42 if boss_phase == 2 else 0.58
		return

	if boss_action == "charge":
		is_moving = true
		facing_direction = boss_charge_direction
		var charge_speed := 390.0 if boss_phase == 2 else 330.0
		position += boss_charge_direction * charge_speed * delta
		gait_phase += delta * 15.0
		boss_action_timer -= delta
		if boss_action_timer <= 0.0:
			boss_action = "recovery"
			boss_action_timer = 0.38 if boss_phase == 2 else 0.52
		return

	if boss_action == "recovery":
		is_moving = false
		boss_action_timer -= delta
		if boss_action_timer <= 0.0:
			boss_action = "idle"
			boss_cooldown = randf_range(2.0, 2.8) if boss_phase == 2 else randf_range(3.0, 4.0)
		return

	var to_player: Vector2 = player_position - position
	var distance := to_player.length()
	is_moving = distance > 112.0
	if is_moving:
		facing_direction = to_player.normalized()
		var walk_speed := 64.0 if boss_phase == 2 else move_speed
		position += facing_direction * walk_speed * slow_multiplier * delta
	var old_phase := gait_phase
	gait_phase += delta * (5.0 if is_moving else 1.5)
	if is_moving and floori(gait_phase / PI) > floori(old_phase / PI):
		footstep_flash = 0.16
		footstep_side *= -1.0

	boss_cooldown -= delta
	if boss_cooldown > 0.0:
		return
	var choices: Array[String] = ["charge", "slam", "zone"]
	if distance < 180.0:
		choices.erase("charge")
	elif distance > 300.0:
		choices.erase("slam")
	if choices.is_empty():
		choices = ["zone"]
	if choices.size() > 1 and choices.has(boss_last_action):
		choices.erase(boss_last_action)
	var chosen: String = choices[randi_range(0, choices.size() - 1)]
	boss_last_action = chosen
	boss_attack_target = player_position
	boss_action = chosen + "_windup"
	boss_action_timer = 0.52 if boss_phase == 2 else 0.72
	is_moving = false


func take_damage(amount: float) -> void:
	if is_boss and boss_action == "phase_shift":
		return
	hp = maxf(0.0, hp - amount)
	hit_flash = 0.12
	queue_redraw()


func apply_slow(duration: float, multiplier: float) -> void:
	if is_boss:
		duration *= 0.35
		multiplier = maxf(multiplier, 0.72)
	slow_timer = maxf(slow_timer, duration)
	slow_multiplier = minf(slow_multiplier, multiplier)
	queue_redraw()


func apply_wet(duration: float) -> void:
	wet_timer = maxf(wet_timer, duration)
	queue_redraw()


func apply_burn(duration: float, damage_per_second: float) -> void:
	burn_timer = maxf(burn_timer, duration)
	burn_dps = maxf(burn_dps, damage_per_second)
	queue_redraw()


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

	var stride := sin(gait_phase) if is_moving else 0.0
	var bob := -hop_height
	var tilt_scale := 1.0
	if kind == "walker":
		bob += absf(stride) * 0.65
		tilt_scale = 1.0 + absf(stride) * 0.012
	elif kind == "armored":
		bob += absf(stride) * 0.42
		tilt_scale = 1.0 + absf(stride) * 0.008
	elif is_boss:
		bob += absf(stride) * 0.9
		tilt_scale = 1.0 + absf(stride) * 0.018

	# Jumper shadows contract during a hop; the body uses a different gait per enemy type.
	var shadow_x := 1.45 - hop_height * 0.018
	var shadow_y := 0.46 - hop_height * 0.012
	draw_set_transform(Vector2(0.0, 13.0 if not is_boss else 23.0), 0.0, Vector2(maxf(0.9, shadow_x), maxf(0.18, shadow_y)))
	draw_circle(Vector2.ZERO, 18.0 if not is_boss else 42.0, Color(0.01, 0.012, 0.01, 0.46))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_boss:
		draw_circle(Vector2(0.0, 16.0), 48.0, Color(0.36, 0.08, 0.07, 0.13 if boss_phase == 1 else 0.24))
		if boss_phase == 2:
			draw_arc(Vector2(0.0, 20.0), 58.0 + sin(animation_time * 5.0) * 3.0, 0.0, TAU, 48, Color(0.72, 0.16, 0.10, 0.62), 2.2)
		if boss_action == "charge_windup":
			var charge_offset: Vector2 = boss_attack_target - position
			draw_line(Vector2(0.0, 20.0), charge_offset, Color(0.95, 0.18, 0.12, 0.22), 12.0)
			draw_line(Vector2(0.0, 20.0), charge_offset, Color(1.0, 0.55, 0.28, 0.82), 3.0)
		elif boss_action == "slam_windup":
			var warning_alpha := 0.35 + (1.0 - clampf(boss_action_timer / 0.72, 0.0, 1.0)) * 0.55
			draw_circle(Vector2(0.0, 20.0), 148.0, Color(0.72, 0.08, 0.06, warning_alpha * 0.14))
			draw_arc(Vector2(0.0, 20.0), 148.0, 0.0, TAU, 56, Color(0.98, 0.28, 0.16, warning_alpha), 3.0)
		elif boss_action == "zone_windup":
			var zone_center: Vector2 = boss_attack_target - position
			var zone_alpha := 0.35 + (1.0 - clampf(boss_action_timer / 0.72, 0.0, 1.0)) * 0.55
			draw_circle(zone_center, 104.0, Color(0.76, 0.08, 0.07, zone_alpha * 0.18))
			draw_arc(zone_center, 104.0, 0.0, TAU, 48, Color(1.0, 0.28, 0.18, zone_alpha), 3.0)
		elif boss_action == "phase_shift":
			draw_circle(Vector2.ZERO, 74.0, Color(0.92, 0.14, 0.08, 0.18))
	elif kind == "armored":
		draw_circle(Vector2(0.0, 12.0), 21.0, Color(0.45, 0.40, 0.29, 0.10))

	if slow_timer > 0.0:
		draw_arc(Vector2(0.0, 9.0), collision_radius + 7.0, 0.0, TAU, 36, Color(0.45, 0.74, 0.62, 0.72), 2.0)
	if wet_timer > 0.0:
		draw_arc(Vector2(0.0, 12.0), collision_radius + 5.0, PI * 0.1, PI * 0.9, 24, Color(0.35, 0.72, 0.88, 0.65), 1.8)
	if burn_timer > 0.0:
		draw_circle(Vector2(0.0, 4.0), collision_radius * 0.72, Color(0.95, 0.36, 0.12, 0.12))

	var tint := Color("#fff0d0") if hit_flash > 0.0 else Color.WHITE
	var flip_x := -1.0 if facing_direction.x < -0.1 else 1.0
	var gait_lean := sin(gait_phase) * 0.028 if is_moving else 0.0
	var sprite_tilt := clampf(facing_direction.x * 0.055, -0.055, 0.055) + gait_lean if is_moving else sin(animation_time) * 0.006
	var stretch_y := 1.0 + absf(sin(gait_phase)) * 0.008 if is_moving else 1.0
	draw_set_transform(Vector2(0.0, bob), sprite_tilt, Vector2(flip_x * tilt_scale, stretch_y))
	draw_texture_rect_region(CREATURES_ATLAS, sprite_rect, sprite_region, tint, false)
	# Tiny alternating footfalls and dust give the single-pose creature sprites a readable stride.
	if is_moving:
		var foot_y := 47.0 if is_boss else (29.0 if kind == "armored" else 25.0)
		var stride_offset := sin(gait_phase) * 4.0
		var foot_color := Color("#30271f") if kind != "armored" else Color("#25221d")
		draw_line(Vector2(-6.0, foot_y - 4.0), Vector2(-6.0 + stride_offset, foot_y), foot_color, 3.2)
		draw_line(Vector2(6.0, foot_y - 4.0), Vector2(6.0 - stride_offset, foot_y), foot_color, 3.2)
		draw_line(Vector2(-6.0 + stride_offset, foot_y), Vector2(-2.0 + stride_offset, foot_y + 0.8), Color("#514031"), 2.5)
		draw_line(Vector2(6.0 - stride_offset, foot_y), Vector2(2.0 - stride_offset, foot_y + 0.8), Color("#514031"), 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if footstep_flash > 0.0 and is_moving:
		var dust_alpha := footstep_flash / 0.16 * 0.18
		draw_circle(Vector2(-8.0 * footstep_side, 31.0), 3.0, Color(0.70, 0.62, 0.43, dust_alpha))
		draw_circle(Vector2(-11.0 * footstep_side, 32.0), 2.0, Color(0.70, 0.62, 0.43, dust_alpha * 0.7))

	# Ordinary enemies keep compact health bars above the animated sprite.
	if not is_boss:
		var bar_y := sprite_rect.position.y - 6.0 + bob
		var bar_rect := Rect2(-bar_width * 0.5, bar_y, bar_width, 4.0)
		draw_rect(bar_rect, Color("#171612"))
		var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		var hp_color := Color("#b45b4a") if ratio >= 0.3 else Color("#d17a4e")
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), hp_color)
		draw_rect(bar_rect, Color(0.72, 0.60, 0.42, 0.72), false, 1.0)
