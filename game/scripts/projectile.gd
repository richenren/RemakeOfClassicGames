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
	age += delta
	if age >= lifetime or not is_instance_valid(target) or target.hp <= 0.0:
		alive = false
		return
	var start_position := position
	var offset: Vector2 = target.position - start_position
	var distance := offset.length()
	var direction := offset / distance if distance > 0.001 else Vector2.ZERO
	var travel_distance := minf(speed * delta, distance)
	var end_position := start_position + direction * travel_distance
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	var candidates: Array = collision_targets.duplicate()
	if is_instance_valid(target) and not candidates.has(target):
		candidates.append(target)
	var first_target = null
	var first_progress := 2.0
	var first_position := end_position
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.hp <= 0.0:
			continue
		var combined_radius: float = float(candidate.collision_radius) + PROJECTILE_HIT_RADIUS
		var progress := 0.0
		if segment_length_squared > 0.001:
			progress = clampf((candidate.position - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest_point: Vector2 = start_position + segment * progress
		if closest_point.distance_squared_to(candidate.position) <= combined_radius * combined_radius and progress < first_progress:
			first_target = candidate
			first_progress = progress
			first_position = closest_point
	if first_target != null:
		position = first_position
		impact_target = first_target
		impacted = true
		alive = false
		if direction.length_squared() > 0.001:
			rotation = direction.angle() + PI * 0.5
		queue_redraw()
		return
	position = end_position
	if direction.length_squared() > 0.001:
		rotation = direction.angle() + PI * 0.5
	queue_redraw()


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
			draw_circle(Vector2.ZERO, 9.0, Color(primary.r, primary.g, primary.b, 0.2))
			draw_circle(Vector2.ZERO, 7.2, primary)
			draw_arc(Vector2.ZERO, 7.2, 0.0, TAU, 32, core, 1.7, true)
			draw_circle(Vector2.ZERO, 4.7, Color("#8d5b2b"))
			draw_rect(Rect2(-2.1, -2.1, 4.2, 4.2), core)
			draw_line(Vector2(-10.0, -7.0), Vector2(-7.0, -10.0), core, 1.2, true)
			draw_line(Vector2(7.0, 10.0), Vector2(10.0, 7.0), core, 1.2, true)
		"peachwood_sword":
			draw_circle(Vector2.ZERO, 8.5, Color(primary.r, primary.g, primary.b, 0.18))
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -12.0), Vector2(3.2, -3.0), Vector2(2.0, 7.0), Vector2(-2.0, 7.0), Vector2(-3.2, -3.0)]), primary)
			draw_line(Vector2(0.0, -9.0), Vector2(0.0, 5.0), core, 1.4, true)
			draw_line(Vector2(-5.0, 2.0), Vector2(5.0, 2.0), Color("#8b5b36"), 2.0, true)
			draw_line(Vector2(0.0, 7.0), Vector2(0.0, 11.0), Color("#8b5b36"), 2.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-5.0, -3.0), Vector2(-10.0, -5.0), Vector2(-7.0, 0.0)]), Color("#a3e5a0"))
			draw_colored_polygon(PackedVector2Array([Vector2(5.0, 3.0), Vector2(10.0, 1.0), Vector2(7.0, 6.0)]), Color("#a3e5a0"))
		_:
			draw_circle(Vector2.ZERO, 8.0, Color(primary.r, primary.g, primary.b, 0.2))
			draw_rect(Rect2(-4.0, -8.5, 8.0, 17.0), Color("#f2d8a0"))
			draw_rect(Rect2(-4.0, -8.5, 8.0, 17.0), primary, false, 1.2)
			draw_line(Vector2(0.0, -5.5), Vector2(0.0, 5.5), Color("#a6322b"), 1.4, true)
			draw_line(Vector2(-2.0, -2.0), Vector2(2.0, 1.0), Color("#a6322b"), 1.0, true)
			draw_circle(Vector2.ZERO, 1.6, core)
