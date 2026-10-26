extends Node2D

const WORLD_MIN := Vector2(48.0, 48.0)
const WORLD_MAX := Vector2(2352.0, 1552.0)

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
	if move_vector.length_squared() > 0.01:
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
	draw_circle(Vector2(0.0, 7.0), 17.0, Color(0.03, 0.03, 0.025, 0.35))

	var robe_color := Color("#b18b52")
	var robe_shadow := Color("#393b3a")
	var robe_light := Color("#d1b47c")
	if hit_flash > 0.0 or (invuln_time > 0.0 and int(Time.get_ticks_msec() / 80) % 2 == 0):
		robe_color = Color("#f4e5c5")
		robe_shadow = Color("#d8cdb7")
		robe_light = Color("#fff5dd")

	var robe := PackedVector2Array([
		Vector2(0.0, -13.0),
		Vector2(-11.0, -7.0),
		Vector2(-14.0, 8.0),
		Vector2(-8.0, 15.0),
		Vector2(8.0, 15.0),
		Vector2(14.0, 8.0),
		Vector2(11.0, -7.0)
	])
	draw_colored_polygon(robe, robe_color)
	draw_line(Vector2(-10.0, -5.0), Vector2(-6.0, 11.0), robe_shadow, 3.0)
	draw_line(Vector2(10.0, -5.0), Vector2(6.0, 11.0), robe_light, 2.0)
	draw_line(Vector2(-8.0, 1.0), Vector2(8.0, 1.0), Color("#7c382d"), 3.0)
	draw_circle(Vector2(0.0, -12.0), 7.0, Color("#d5b18c"))
	draw_arc(Vector2(0.0, -13.0), 7.0, PI, TAU, 16, Color("#211e1b"), 4.0)
	draw_line(Vector2(-4.0, -18.0), Vector2(4.0, -18.0), Color("#211e1b"), 3.0)

	var talisman_tip := facing.normalized() * 22.0
	draw_line(facing * 9.0, talisman_tip, Color("#49382b"), 3.0)
	draw_line(facing * 10.0, talisman_tip, Color("#d7ad4c"), 2.0)
	draw_circle(talisman_tip, 4.0, Color("#e6bd55"))
	draw_circle(talisman_tip, 1.6, Color("#a9432d"))
