extends Node2D

const PROJECTILE_HIT_RADIUS := 4.0

var target
var impact_target
var damage: float = 18.0
var speed: float = 470.0
var lifetime: float = 2.0
var age: float = 0.0
var alive: bool = true
var impacted: bool = false
var skill_id: String = "basic_talisman"
var splash_radius: float = 0.0
var splash_damage_ratio: float = 0.38
var slow_duration: float = 0.0
var applies_wet: bool = false
var applies_freeze: bool = false
var behavior: String = "homing"
var travel_direction: Vector2 = Vector2.ZERO
var pierce_remaining: int = 0
var pierce_damage_multiplier: float = 0.52
var pierce_hit_count: int = 0
var hit_targets: Array = []
var is_returning: bool = false
var impact_is_return: bool = false
var return_target
var return_damage_multiplier: float = 0.55
var return_start_position: Vector2 = Vector2.ZERO
var return_control_offset: Vector2 = Vector2.ZERO
var return_age: float = 0.0
var return_duration: float = 0.42
var allow_secondary_chase: bool = true
var is_secondary: bool = false


func setup(target_node, hit_damage: float, attack_skill_id: String = "basic_talisman") -> void:
	target = target_node
	impact_target = null
	impacted = false
	alive = true
	age = 0.0
	damage = hit_damage
	skill_id = attack_skill_id
	splash_radius = 0.0
	splash_damage_ratio = 0.38
	slow_duration = 0.0
	applies_wet = false
	applies_freeze = false
	behavior = "homing"
	travel_direction = Vector2.ZERO
	pierce_remaining = 0
	pierce_damage_multiplier = 0.52
	pierce_hit_count = 0
	hit_targets.clear()
	is_returning = false
	impact_is_return = false
	return_target = null
	return_damage_multiplier = 0.55
	return_start_position = Vector2.ZERO
	return_control_offset = Vector2.ZERO
	return_age = 0.0
	return_duration = 0.42
	allow_secondary_chase = true
	is_secondary = false
	match skill_id:
		"thunder_talisman", "five_thunder":
			speed = 560.0
		"copper_coin_sword":
			speed = 520.0
		"peachwood_sword":
			speed = 500.0
		"water_array":
			speed = 390.0
		"fire_talisman":
			speed = 450.0
		_:
			speed = 470.0


func tick(delta: float, collision_targets: Array = []) -> void:
	if not alive:
		return
	impacted = false
	impact_target = null
	impact_is_return = false
	age += delta
	if age >= lifetime:
		alive = false
		return

	var start_position := position
	var direction := Vector2.ZERO
	var distance := 0.0
	var travel_distance := 0.0
	var end_position := position

	if is_returning:
		if not is_instance_valid(return_target):
			alive = false
			return
		return_age += delta
		var progress := clampf(return_age / maxf(0.01, return_duration), 0.0, 1.0)
		var control_point := return_start_position.lerp(return_target.position, 0.5) + return_control_offset
		var one_minus_t := 1.0 - progress
		end_position = return_start_position * one_minus_t * one_minus_t + control_point * (2.0 * one_minus_t * progress) + return_target.position * progress * progress
		var return_segment := end_position - start_position
		distance = return_segment.length()
		direction = return_segment.normalized() if distance > 0.001 else Vector2.ZERO
		travel_distance = distance
	elif behavior == "pierce":
		if travel_direction.length_squared() < 0.001:
			if not is_instance_valid(target):
				alive = false
				return
			travel_direction = (target.position - start_position).normalized()
		direction = travel_direction
		travel_distance = speed * delta
		end_position = start_position + direction * travel_distance
	else:
		if not is_instance_valid(target) or target.hp <= 0.0:
			alive = false
			return
		var offset: Vector2 = target.position - start_position
		distance = offset.length()
		direction = offset / distance if distance > 0.001 else Vector2.ZERO
		travel_distance = minf(speed * delta, distance)
		end_position = start_position + direction * travel_distance

	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	var candidates: Array = collision_targets.duplicate()
	if is_instance_valid(target) and not candidates.has(target) and not is_returning:
		candidates.append(target)
	var first_target = null
	var first_progress := 2.0
	var first_position := end_position
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.hp <= 0.0 or hit_targets.has(candidate):
			continue
		var combined_radius: float = float(candidate.collision_radius) + PROJECTILE_HIT_RADIUS
		var progress_on_segment := 0.0
		if segment_length_squared > 0.001:
			progress_on_segment = clampf((candidate.position - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest_point: Vector2 = start_position + segment * progress_on_segment
		if closest_point.distance_squared_to(candidate.position) <= combined_radius * combined_radius and progress_on_segment < first_progress:
			first_target = candidate
			first_progress = progress_on_segment
			first_position = closest_point

	if first_target != null:
		position = first_position
		impact_target = first_target
		impacted = true
		hit_targets.append(first_target)
		if behavior == "pierce":
			pierce_hit_count += 1
			if pierce_remaining > 0:
				pierce_remaining -= 1
				alive = true
			else:
				alive = false
		elif is_returning:
			impact_is_return = true
			alive = false
		else:
			alive = false
		if direction.length_squared() > 0.001:
			rotation = direction.angle() + PI * 0.5
		queue_redraw()
		return

	position = end_position
	if direction.length_squared() > 0.001:
		rotation = direction.angle() + PI * 0.5
	if is_returning and return_age >= return_duration:
		alive = false
	queue_redraw()


func begin_return(owner_node) -> void:
	if is_returning:
		return
	is_returning = true
	return_target = owner_node
	target = owner_node
	return_start_position = position
	return_age = 0.0
	var to_owner: Vector2 = (owner_node.position - position).normalized()
	var return_normal := Vector2(-to_owner.y, to_owner.x)
	return_control_offset = return_normal * 48.0
	alive = true
	impact_is_return = false
	if not hit_targets.has(impact_target):
		hit_targets.append(impact_target)

static func visual_profile_for_skill(attack_skill_id: String) -> Dictionary:
	match attack_skill_id:
		"fire_talisman":
			return {"element": "fire", "primary": Color("#ff542f"), "core": Color("#fff0bd")}
		"thunder_talisman", "five_thunder":
			return {"element": "thunder", "primary": Color("#b56cff"), "core": Color("#f5e8ff")}
		"water_array":
			return {"element": "water", "primary": Color("#38c9e8"), "core": Color("#e3fbff")}
		"copper_coin_sword":
			return {"element": "metal", "primary": Color("#e9bd58"), "core": Color("#fff0b5")}
		"peachwood_sword":
			return {"element": "wood", "primary": Color("#52c982"), "core": Color("#e1ffd5")}
		_:
			return {"element": "talisman", "primary": Color("#e9c65d"), "core": Color("#fff0b0")}


func _draw() -> void:
	var profile: Dictionary = visual_profile_for_skill(skill_id)
	var primary: Color = profile["primary"]
	var core: Color = profile["core"]
	match skill_id:
		"fire_talisman":
			draw_line(Vector2(0.0, 7.0), Vector2(0.0, 18.0), Color(1.0, 0.28, 0.05, 0.55), 5.0, true)
			draw_line(Vector2(-2.0, 10.0), Vector2(-6.0, 17.0), Color(1.0, 0.58, 0.12, 0.68), 2.2, true)
			draw_line(Vector2(2.0, 9.0), Vector2(6.0, 15.0), Color(1.0, 0.44, 0.08, 0.55), 1.8, true)
			draw_circle(Vector2.ZERO, 10.5, Color(primary.r, primary.g, primary.b, 0.22))
			draw_circle(Vector2.ZERO, 8.0, primary)
			draw_circle(Vector2(-1.6, -1.8), 4.8, core)
			draw_arc(Vector2.ZERO, 8.5, -2.8, 1.1, 24, Color("#ffb64f"), 1.3, true)
			draw_circle(Vector2(4.8, 4.5), 1.4, Color("#fff0bd"))
		"water_array":
			draw_line(Vector2(-2.0, 8.0), Vector2(-5.0, 16.0), Color(0.23, 0.77, 1.0, 0.48), 2.0, true)
			draw_line(Vector2(2.0, 8.0), Vector2(6.0, 14.0), Color(0.23, 0.77, 1.0, 0.42), 1.7, true)
			draw_circle(Vector2.ZERO, 10.0, Color(primary.r, primary.g, primary.b, 0.18))
			draw_circle(Vector2.ZERO, 7.8, Color(0.08, 0.48, 0.72, 0.92))
			draw_arc(Vector2.ZERO, 7.8, 0.3, 4.8, 28, primary, 2.1, true)
			draw_arc(Vector2(-1.0, -1.0), 5.2, 3.5, 5.7, 18, core, 1.8, true)
			draw_circle(Vector2(-2.6, -3.0), 1.9, core)
			draw_circle(Vector2(4.4, 3.2), 1.1, Color("#8cecff"))
		"thunder_talisman", "five_thunder":
			draw_circle(Vector2.ZERO, 9.0, Color(primary.r, primary.g, primary.b, 0.24))
			draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 28, Color(primary.r, primary.g, primary.b, 0.9), 1.6, true)
			var bolt := PackedVector2Array([Vector2(2.8, -12.0), Vector2(-5.5, -1.0), Vector2(-1.2, -1.0), Vector2(-4.0, 10.0), Vector2(6.2, -3.0), Vector2(1.7, -3.0)])
			draw_colored_polygon(bolt, primary)
			draw_polyline(PackedVector2Array([Vector2(2.8, -12.0), Vector2(-5.5, -1.0), Vector2(-1.2, -1.0), Vector2(-4.0, 10.0)]), core, 1.8, true)
		"copper_coin_sword":
			# A visible coin-chain blade rather than a lone floating coin.
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -20.0), Vector2(3.5, -11.0), Vector2(2.8, 7.0), Vector2(-2.8, 7.0), Vector2(-3.5, -11.0)]), Color("#6f5027"))
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -18.0), Vector2(2.0, -10.0), Vector2(1.7, 5.0), Vector2(-1.7, 5.0), Vector2(-2.0, -10.0)]), primary)
			for coin_index in range(4):
				var coin_y := -9.0 + float(coin_index) * 4.2
				draw_circle(Vector2(0.0, coin_y), 3.0, Color("#b17a32"))
				draw_arc(Vector2(0.0, coin_y), 3.0, 0.0, TAU, 16, core, 0.8, true)
				draw_rect(Rect2(-0.9, coin_y - 0.9, 1.8, 1.8), Color("#34271a"))
			draw_line(Vector2(-5.0, 5.0), Vector2(5.0, 5.0), core, 2.2, true)
			draw_line(Vector2(0.0, 7.0), Vector2(0.0, 13.0), Color("#8d5b2b"), 2.2, true)
			draw_circle(Vector2(0.0, 14.0), 2.0, primary)
		"peachwood_sword":
			# A full wooden talisman sword with grain, guard and a small jade charm.
			draw_circle(Vector2.ZERO, 11.0, Color(primary.r, primary.g, primary.b, 0.14))
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -21.0), Vector2(3.0, -10.0), Vector2(2.2, 7.0), Vector2(-2.2, 7.0), Vector2(-3.0, -10.0)]), Color("#6b4a2c"))
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -19.0), Vector2(1.9, -9.0), Vector2(1.4, 5.0), Vector2(-1.4, 5.0), Vector2(-1.9, -9.0)]), primary)
			draw_line(Vector2(-0.6, -14.0), Vector2(-0.4, 3.0), core, 0.9, true)
			draw_line(Vector2(-5.0, 4.0), Vector2(5.0, 4.0), Color("#8b5b36"), 2.2, true)
			draw_line(Vector2(0.0, 7.0), Vector2(0.0, 12.0), Color("#8b5b36"), 2.0, true)
			draw_circle(Vector2(0.0, 14.0), 2.3, Color("#a3e5a0"))
			draw_line(Vector2(-7.0, -7.0), Vector2(-3.0, -4.0), Color("#a3e5a0"), 1.2, true)
			draw_line(Vector2(7.0, -1.0), Vector2(3.0, 2.0), Color("#a3e5a0"), 1.2, true)
		_:
			draw_circle(Vector2.ZERO, 8.0, Color(primary.r, primary.g, primary.b, 0.2))
			draw_rect(Rect2(-4.0, -8.5, 8.0, 17.0), Color("#f2d8a0"))
			draw_rect(Rect2(-4.0, -8.5, 8.0, 17.0), primary, false, 1.2)
			draw_line(Vector2(0.0, -5.5), Vector2(0.0, 5.5), Color("#a6322b"), 1.4, true)
			draw_line(Vector2(-2.0, -2.0), Vector2(2.0, 1.0), Color("#a6322b"), 1.0, true)
			draw_circle(Vector2.ZERO, 1.6, core)
