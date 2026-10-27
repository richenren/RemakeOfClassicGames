extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
const XP_ORB_SCRIPT = preload("res://scripts/xp_orb.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")

const WORLD_SIZE := Vector2(2400.0, 1600.0)
const MAX_ENEMIES := 100

var player
var hud
var enemies: Array = []
var projectiles: Array = []
var xp_orbs: Array = []

var state: String = "playing"
var elapsed_seconds: float = 0.0
var kills: int = 0
var spawn_timer: float = 0.6
var attack_timer: float = 0.4
var active_skill_cooldown: float = 0.0
var active_skill_base_cooldown: float = 12.0
var active_skill_effect_time: float = 0.0
const ACTIVE_SKILL_EFFECT_DURATION := 0.34
const ACTIVE_SKILL_RADIUS := 155.0
var heal_charges: int = 2
var boss_spawned: bool = false
var level_cards: Array[Dictionary] = []

var joystick_touch_id: int = -1


func _ready() -> void:
	randomize()
	queue_redraw()

	player = PLAYER_SCRIPT.new()
	player.main_ref = self
	player.position = WORLD_SIZE * 0.5
	add_child(player)

	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	camera.make_current()

	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = HUD_SCRIPT.new()
	hud.main_ref = self
	canvas.add_child(hud)

	for i in range(7):
		spawn_enemy(_random_enemy_kind())


func _process(delta: float) -> void:
	if active_skill_effect_time > 0.0:
		active_skill_effect_time = maxf(0.0, active_skill_effect_time - delta)
		queue_redraw()
	if state == "playing":
		elapsed_seconds += delta
		active_skill_cooldown = maxf(0.0, active_skill_cooldown - delta)
		player.tick(delta)

		attack_timer -= delta
		if attack_timer <= 0.0:
			_auto_attack()
			attack_timer = player.attack_interval

		spawn_timer -= delta
		if spawn_timer <= 0.0 and enemies.size() < MAX_ENEMIES:
			_spawn_wave()
			spawn_timer = maxf(0.72, 2.5 - elapsed_seconds / 260.0)

		if not boss_spawned and elapsed_seconds >= 480.0:
			boss_spawned = true
			spawn_enemy("boss")

		_tick_enemies(delta)
		_tick_projectiles(delta)
		_remove_dead_enemies()
		_tick_xp_orbs(delta)

		if player.hp <= 0.0 and state == "playing":
			state = "game_over"

	if hud != null:
		hud.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if state == "playing":
				state = "paused"
			elif state == "paused":
				state = "playing"
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_SPACE and state == "playing":
			cast_active_skill()
			return
		if event.keycode == KEY_E and state == "playing":
			use_heal()
			return
		if event.keycode == KEY_R and (state == "game_over" or state == "victory"):
			get_tree().reload_current_scene()
			return
		if state == "level_up" and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_select_upgrade(int(event.keycode - KEY_1))
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == "level_up":
			_select_upgrade(hud.card_index_at(event.position))
		elif state == "paused":
			state = "playing"
		elif state == "game_over" or state == "victory":
			get_tree().reload_current_scene()

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch_id and state == "playing":
			_update_mobile_move(event.position)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if state == "level_up":
			_select_upgrade(hud.card_index_at(event.position))
			return
		if state == "paused":
			state = "playing"
			return
		if state == "game_over" or state == "victory":
			get_tree().reload_current_scene()
			return
		if state != "playing":
			return

		var view := get_viewport_rect().size
		if event.position.y < 70.0 and absf(event.position.x - view.x * 0.5) < 150.0:
			state = "paused"
			return
		var skill_center := Vector2(view.x - 82.0, view.y - 122.0)
		var heal_center := Vector2(view.x - 51.0, view.y - 61.0)
		if event.position.distance_to(skill_center) <= 58.0:
			cast_active_skill()
		elif event.position.distance_to(heal_center) <= 42.0:
			use_heal()
		elif event.position.x < view.x * 0.42 and event.position.y > view.y * 0.52 and joystick_touch_id == -1:
			joystick_touch_id = event.index
			_update_mobile_move(event.position)
	else:
		if event.index == joystick_touch_id:
			joystick_touch_id = -1
			player.mobile_move = Vector2.ZERO


func _update_mobile_move(screen_position: Vector2) -> void:
	var center := Vector2(94.0, get_viewport_rect().size.y - 105.0)
	var offset := screen_position - center
	player.mobile_move = offset.limit_length(52.0) / 52.0
	if offset.length() < 12.0:
		player.mobile_move = Vector2.ZERO


func _random_enemy_kind() -> String:
	var roll := randf()
	if roll < 0.25:
		return "jumper"
	if roll < 0.36:
		return "armored"
	return "walker"


func _spawn_wave() -> void:
	var amount := 1
	if elapsed_seconds > 90.0 and randf() < 0.24:
		amount = 2
	for i in range(amount):
		if enemies.size() >= MAX_ENEMIES:
			break
		spawn_enemy(_random_enemy_kind())


func spawn_enemy(kind: String = "walker") -> void:
	var enemy = ENEMY_SCRIPT.new()
	enemy.setup(kind)
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(760.0, 850.0) if kind != "boss" else 820.0
	var spawn_position: Vector2 = player.position + Vector2(cos(angle), sin(angle)) * distance
	spawn_position.x = clampf(spawn_position.x, 40.0, WORLD_SIZE.x - 40.0)
	spawn_position.y = clampf(spawn_position.y, 40.0, WORLD_SIZE.y - 40.0)
	enemy.position = spawn_position
	add_child(enemy)
	enemies.append(enemy)


func _auto_attack() -> void:
	var target = null
	var best_distance := 620.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0:
			continue
		var distance: float = player.position.distance_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			target = enemy
	if target == null:
		return

	var projectile = PROJECTILE_SCRIPT.new()
	projectile.setup(target, player.damage)
	var direction: Vector2 = (target.position - player.position).normalized()
	player.facing = direction
	projectile.position = player.position + direction * 18.0
	add_child(projectile)
	projectiles.append(projectile)
	player.queue_redraw()


func _tick_enemies(delta: float) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0:
			continue
		var separation := _get_separation(enemy)
		enemy.tick(delta, player.position, separation)
		var collision_distance: float = enemy.collision_radius + player.collision_radius
		if enemy.position.distance_squared_to(player.position) <= collision_distance * collision_distance:
			if player.invuln_time <= 0.0:
				player.take_damage(enemy.contact_damage)
				if player.hp <= 0.0:
					state = "game_over"


func _get_separation(enemy) -> Vector2:
	var result := Vector2.ZERO
	for other in enemies:
		if other == enemy or not is_instance_valid(other) or other.hp <= 0.0:
			continue
		var offset: Vector2 = enemy.position - other.position
		var distance := offset.length()
		if distance > 0.001 and distance < 36.0:
			result += offset.normalized() * ((36.0 - distance) / 36.0)
	return result


func _tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile = projectiles[i]
		projectile.tick(delta)
		if projectile.impacted and is_instance_valid(projectile.target) and enemies.has(projectile.target):
			projectile.target.take_damage(projectile.damage)
		if not projectile.alive:
			projectiles.remove_at(i)
			projectile.queue_free()


func _remove_dead_enemies() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		if not is_instance_valid(enemy):
			enemies.remove_at(i)
			continue
		if enemy.hp > 0.0:
			continue
		if enemy.is_boss:
			state = "victory"
		else:
			kills += 1
			_spawn_xp_orb(enemy.position, 1)
		enemies.remove_at(i)
		enemy.queue_free()


func _spawn_xp_orb(spawn_position: Vector2, amount: int) -> void:
	var orb = XP_ORB_SCRIPT.new()
	orb.setup(amount)
	orb.position = spawn_position
	add_child(orb)
	xp_orbs.append(orb)


func _tick_xp_orbs(delta: float) -> void:
	for i in range(xp_orbs.size() - 1, -1, -1):
		var orb = xp_orbs[i]
		if orb.tick(delta, player.position, player.pickup_radius):
			player.gain_xp(orb.value)
			xp_orbs.remove_at(i)
			orb.queue_free()
			_maybe_level_up()
			if state != "playing":
				return


func _maybe_level_up() -> void:
	if player.xp < player.xp_to_next or state != "playing":
		return
	player.xp -= player.xp_to_next
	player.level += 1
	player.xp_to_next = ceili(float(player.xp_to_next) * 1.24 + 2.0)
	_open_upgrade_choices()


func _open_upgrade_choices() -> void:
	var pool: Array[Dictionary] = [
		{"id": "talisman_power", "name": "符箓精进", "desc": "基础符箓伤害提高 25%"},
		{"id": "swift_step", "name": "身法", "desc": "移动速度提高 12%"},
		{"id": "vitality", "name": "强身", "desc": "最大生命 +20，并恢复 20 生命"},
		{"id": "spirit_sense", "name": "广纳", "desc": "灵气吸收范围提高 25%"},
		{"id": "rapid_talisman", "name": "符箓连发", "desc": "自动攻击间隔缩短 10%"},
		{"id": "control_art", "name": "镇邪诀精进", "desc": "主动道术冷却缩短 10%"}
	]
	pool.shuffle()
	level_cards.clear()
	for i in range(mini(3, pool.size())):
		level_cards.append(pool[i])
	state = "level_up"


func _select_upgrade(index: int) -> void:
	if state != "level_up" or index < 0 or index >= level_cards.size():
		return
	var upgrade: Dictionary = level_cards[index]
	match upgrade.id:
		"talisman_power":
			player.damage *= 1.25
		"swift_step":
			player.move_speed *= 1.12
		"vitality":
			player.max_hp += 20.0
			player.heal(20.0)
		"spirit_sense":
			player.pickup_radius *= 1.25
		"rapid_talisman":
			player.attack_interval = maxf(0.32, player.attack_interval * 0.9)
		"control_art":
			active_skill_base_cooldown = maxf(7.0, active_skill_base_cooldown * 0.9)
	state = "playing"
	_maybe_level_up()


func cast_active_skill() -> void:
	if state != "playing" or active_skill_cooldown > 0.0:
		return
	active_skill_cooldown = active_skill_base_cooldown
	active_skill_effect_time = ACTIVE_SKILL_EFFECT_DURATION
	queue_redraw()
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0:
			continue
		if enemy.position.distance_to(player.position) <= ACTIVE_SKILL_RADIUS:
			enemy.apply_slow(2.0, 0.35)
			enemy.take_damage(8.0)
			if enemy.is_boss:
				enemy.apply_slow(1.2, 0.72)


func use_heal() -> void:
	if state != "playing" or heal_charges <= 0 or player.hp >= player.max_hp:
		return
	heal_charges -= 1
	player.heal(player.max_hp * 0.3)


func get_boss():
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_boss:
			return enemy
	return null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#242720"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 829104

	# Subtle moss, worn earth and scattered stone texture keep the battlefield readable.
	for i in range(250):
		var p := Vector2(rng.randf_range(20.0, WORLD_SIZE.x - 20.0), rng.randf_range(20.0, WORLD_SIZE.y - 20.0))
		var radius := rng.randf_range(4.0, 17.0)
		var shade := rng.randf_range(0.0, 1.0)
		var patch_color := Color("#2d3028") if shade > 0.58 else Color("#20231e")
		draw_circle(p, radius, patch_color)
	for i in range(125):
		var p := Vector2(rng.randf_range(24.0, WORLD_SIZE.x - 24.0), rng.randf_range(24.0, WORLD_SIZE.y - 24.0))
		var length := rng.randf_range(5.0, 16.0)
		var drift := rng.randf_range(-4.0, 4.0)
		draw_line(p, p + Vector2(length, drift), Color(0.42, 0.40, 0.31, 0.16), 1.0)

	# The old stone path has broken edges and uneven paving instead of a uniform strip.
	draw_line(Vector2(0.0, 800.0), Vector2(WORLD_SIZE.x, 800.0), Color("#191b16"), 112.0, true)
	draw_line(Vector2(0.0, 800.0), Vector2(WORLD_SIZE.x, 800.0), Color("#35362c"), 88.0, true)
	draw_line(Vector2(0.0, 800.0), Vector2(WORLD_SIZE.x, 800.0), Color("#3d3b30"), 72.0, true)
	for i in range(19):
		var tile_x := float(i) * 136.0 - 20.0
		var tile_y := 800.0 + rng.randf_range(-11.0, 11.0)
		var tile_width := rng.randf_range(62.0, 118.0)
		var tile_height := rng.randf_range(42.0, 59.0)
		var tile_rect := Rect2(tile_x, tile_y - tile_height * 0.5, tile_width, tile_height)
		draw_rect(tile_rect, Color("#424033"), false, 1.0)
		if i % 3 == 0:
			draw_line(tile_rect.position + Vector2(12.0, 8.0), tile_rect.position + Vector2(22.0, 19.0), Color("#24251f"), 1.0)
			draw_line(tile_rect.position + Vector2(tile_width - 20.0, tile_height - 12.0), tile_rect.position + Vector2(tile_width - 9.0, tile_height - 18.0), Color("#292a23"), 1.0)
	for i in range(42):
		var edge_x := rng.randf_range(0.0, WORLD_SIZE.x)
		var edge_y := 800.0 + rng.randf_range(-65.0, 65.0)
		var size := rng.randf_range(4.0, 12.0)
		draw_circle(Vector2(edge_x, edge_y), size, Color("#34342a"))
		draw_circle(Vector2(edge_x - 1.0, edge_y - 1.0), size * 0.45, Color("#474536"))

	# Original grave markers and dead trees are drawn as quiet silhouettes, not UI-like boxes.
	var grave_positions: Array[Vector2] = [
		Vector2(610, 690), Vector2(760, 970), Vector2(880, 610), Vector2(1010, 1015),
		Vector2(1160, 650), Vector2(1370, 980), Vector2(1510, 625), Vector2(1690, 960),
		Vector2(1810, 670), Vector2(680, 1080), Vector2(1280, 560), Vector2(1590, 1085),
		Vector2(930, 1130), Vector2(1750, 1110)
	]
	for p in grave_positions:
		draw_set_transform(p + Vector2(0.0, 13.0), 0.0, Vector2(1.25, 0.42))
		draw_circle(Vector2.ZERO, 16.0, Color(0.01, 0.012, 0.01, 0.42))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var stone := PackedVector2Array([
			p + Vector2(-12.0, 10.0), p + Vector2(-10.0, -7.0),
			p + Vector2(-6.0, -15.0), p + Vector2(5.0, -17.0),
			p + Vector2(10.0, -9.0), p + Vector2(12.0, 10.0)
		])
		draw_colored_polygon(stone, Color("#45483d"))
		draw_polyline(PackedVector2Array([
			p + Vector2(-12.0, 10.0), p + Vector2(-10.0, -7.0),
			p + Vector2(-6.0, -15.0), p + Vector2(5.0, -17.0),
			p + Vector2(10.0, -9.0), p + Vector2(12.0, 10.0),
			p + Vector2(-12.0, 10.0)
		]), Color("#666451"), 1.2, true)
		draw_line(p + Vector2(-4.0, -4.0), p + Vector2(4.0, -4.0), Color("#8b7d5c", 0.72), 1.2)
		draw_line(p + Vector2(-3.0, 1.0), p + Vector2(3.0, 1.0), Color("#8b7d5c", 0.52), 1.0)

	var dead_trees: Array[Vector2] = [Vector2(560, 565), Vector2(1870, 560), Vector2(590, 1115), Vector2(1810, 1090), Vector2(1420, 530)]
	for p in dead_trees:
		draw_circle(p + Vector2(0.0, 20.0), 22.0, Color(0.01, 0.01, 0.01, 0.28))
		draw_line(p, p + Vector2(0.0, -44.0), Color("#34362d"), 5.0, true)
		draw_line(p + Vector2(0.0, -19.0), p + Vector2(-19.0, -38.0), Color("#34362d"), 3.0, true)
		draw_line(p + Vector2(-12.0, -31.0), p + Vector2(-26.0, -31.0), Color("#34362d"), 2.0, true)
		draw_line(p + Vector2(0.0, -29.0), p + Vector2(18.0, -48.0), Color("#34362d"), 3.0, true)
		draw_line(p + Vector2(11.0, -41.0), p + Vector2(27.0, -43.0), Color("#34362d"), 2.0, true)

	var torch_positions: Array[Vector2] = [Vector2(730, 755), Vector2(1665, 850), Vector2(1020, 705), Vector2(1450, 895)]
	for p in torch_positions:
		draw_circle(p, 34.0, Color(0.76, 0.43, 0.16, 0.07))
		draw_circle(p, 19.0, Color(0.76, 0.43, 0.16, 0.05))
		draw_line(p + Vector2(0.0, 10.0), p + Vector2(0.0, -8.0), Color("#4c4432"), 3.0)
		draw_circle(p + Vector2(0.0, -10.0), 4.0, Color("#d5a04d"))
		draw_circle(p + Vector2(0.0, -10.0), 1.8, Color("#f0d18a"))

	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#11120f"), false, 8.0)

	if active_skill_effect_time > 0.0 and player != null:
		var progress := 1.0 - active_skill_effect_time / ACTIVE_SKILL_EFFECT_DURATION
		var alpha := clampf(active_skill_effect_time / ACTIVE_SKILL_EFFECT_DURATION, 0.0, 1.0)
		var radius := ACTIVE_SKILL_RADIUS * (0.88 + progress * 0.12)
		draw_arc(player.position, radius, 0.0, TAU, 72, Color(0.88, 0.72, 0.36, alpha * 0.9), 4.0)
		draw_arc(player.position, radius * 0.82, 0.0, TAU, 64, Color(0.65, 0.48, 0.28, alpha * 0.55), 2.0)
		for i in range(8):
			var angle := TAU * float(i) / 8.0
			var inner := Vector2(cos(angle), sin(angle)) * radius * 0.9
			var outer := Vector2(cos(angle), sin(angle)) * radius
			draw_line(player.position + inner, player.position + outer, Color(0.93, 0.81, 0.5, alpha * 0.8), 2.0)
