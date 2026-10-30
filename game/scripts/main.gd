extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
const XP_ORB_SCRIPT = preload("res://scripts/xp_orb.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const GRAVEYARD_BACKGROUND: Texture2D = preload("res://assets/sprites/graveyard_background.svg")

const WORLD_SIZE := Vector2(2400.0, 1600.0)
const MAX_ENEMIES := 100
const BOSS_PHASE_ENEMY_CAP := 18

var player
var hud
var gameplay_camera: Camera2D
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
const BASIC_ATTACK_RANGE := 420.0
const AUTO_SKILL_RANGE := 460.0
const BASIC_PROJECTILE_MAX_RANGE := 500.0
const AUTO_SKILL_PROJECTILE_MAX_RANGE := 540.0
const CHAIN_HOP_RANGE := 150.0
const MAX_CHAIN_DISTANCE_FROM_PLAYER := 520.0
const SECONDARY_CHASE_RANGE := 180.0
const MAX_AUTO_SKILL_SLOTS := 4
const MAX_ARTIFACT_SLOTS := 3
const MIN_PRIMARY_BREAKTHROUGH_PLAYER_LEVEL := 6

const AUTO_SKILL_DEFS := {
	"fire_talisman": {"name": "火符", "desc": "自动索敌投射火符，命中附加灼烧", "upgrade_desc": "火符伤害与灼烧效果提升", "damage": 15.0, "cooldown": 1.65},
	"thunder_talisman": {"name": "雷符", "desc": "雷符爆发，可对附近尸群传导", "upgrade_desc": "雷符伤害提升，传导更强", "damage": 22.0, "cooldown": 2.15},
	"copper_coin_sword": {"name": "铜钱剑", "desc": "御使铜钱剑追击敌人，强化贯穿或回旋", "upgrade_desc": "铜钱剑伤害与出手频率提升", "damage": 17.0, "cooldown": 1.8},
	"peachwood_sword": {"name": "桃木剑", "desc": "御剑驱邪，可追击或环身护主", "upgrade_desc": "桃木剑伤害与护身范围提升", "damage": 16.0, "cooldown": 1.9},
	"water_array": {"name": "寒潮阵", "desc": "寒潮席卷指定区域，造成伤害并持续减速", "upgrade_desc": "扩大寒潮阵范围，强化冰霜伤害与减速", "damage": 10.0, "cooldown": 3.0},
	"earth_formation": {"name": "地脉阵", "desc": "震动地脉压制一片区域，适合群体清场", "upgrade_desc": "地脉阵范围与伤害提升", "damage": 21.0, "cooldown": 2.8}
}

const ARTIFACT_DEFS := {
	"cold_relic": {"name": "寒魄法器", "desc": "强化水/冰控制；水阵主修 Lv5 时解锁冰魄阵", "icon": "cold_relic"},
	"thunder_seal": {"name": "天雷法印", "desc": "强化雷系伤害；雷符主修 Lv5 时解锁五雷敕令", "icon": "thunder_seal"},
	"talisman_scroll": {"name": "符箓秘卷", "desc": "强化火符；火符主修 Lv5 时解锁焚天符阵", "icon": "talisman_scroll"},
	"sword_manual": {"name": "御剑诀", "desc": "强化金系剑意；铜钱剑主修 Lv5 时解锁金锋剑阵", "icon": "sword_manual"},
	"formation_manual": {"name": "阵法真解", "desc": "强化地脉阵；地脉阵主修 Lv5 时解锁镇岳神印", "icon": "formation_manual"},
	"body_jade": {"name": "护身玉", "desc": "受到的接触伤害降低 8%；桃木剑主修 Lv5 时解锁青木护身剑", "icon": "body_jade"}
}

const GENERAL_UPGRADE_DEFS := {
	"swift_step": {"name": "身法", "desc": "移动速度提高 8%", "icon": "swift_step"},
	"spirit_gain": {"name": "纳气", "desc": "灵气获取效率提高 15%", "icon": "spirit_gain"},
	"spirit_sense": {"name": "广纳", "desc": "灵气拾取范围提高 25%", "icon": "spirit_sense"},
	"vitality": {"name": "强身", "desc": "最大生命 +20，并恢复 20 生命", "icon": "vitality"}
}

const SKILL_BRANCHES := {
	"fire_talisman": [
		{"id": "flame", "name": "烈焰", "desc": "灼烧持续更久，持续伤害显著提高"},
		{"id": "spread", "name": "散符", "desc": "每次出手额外追击一名敌人"}
	],
	"thunder_talisman": [
		{"id": "chain", "name": "连锁", "desc": "雷击可向更多附近敌人传导"},
		{"id": "heaven", "name": "天罚", "desc": "大幅提高单次雷击伤害，减少传导"}
	],
	"copper_coin_sword": [
		{"id": "pierce", "name": "贯穿", "desc": "命中后穿透效果波及附近敌人"},
		{"id": "return", "name": "回旋", "desc": "命中后追加一次回旋伤害"}
	],
	"peachwood_sword": [
		{"id": "guardian", "name": "护身", "desc": "剑气环身击退近处敌人"},
		{"id": "chase", "name": "追邪", "desc": "飞剑命中后追击另一名敌人"}
	],
	"water_array": [
		{"id": "cold", "name": "寒流", "desc": "大幅延长减速，为冰系进化铺路"},
		{"id": "tide", "name": "潮涌", "desc": "扩大水阵范围，覆盖更多敌人"}
	],
	"earth_formation": [
		{"id": "mountain", "name": "镇岳", "desc": "扩大镇压范围并击退敌人"},
		{"id": "earthspike", "name": "地刺", "desc": "牺牲部分控制，换取更高爆发伤害"}
	]
}

const ELEMENT_DEFS := {
	"metal": {"name": "金", "skill_id": "copper_coin_sword", "cultivation_name": "剑意凝锋", "cultivation_desc": "铜钱剑伤害提高 8%，强化贯穿与剑气", "icon": "cultivation_metal", "artifact_id": "sword_manual", "evolution_id": "golden_sword_array", "evolution_name": "金锋剑阵", "evolution_desc": "铜钱剑命中后追加两段金色剑气，斩击附近敌人", "effect": "slash"},
	"wood": {"name": "木", "skill_id": "peachwood_sword", "cultivation_name": "青木回生", "cultivation_desc": "击杀敌人时恢复少量生命，每级提高恢复量", "icon": "cultivation_wood", "artifact_id": "body_jade", "evolution_id": "greenwood_guardian", "evolution_name": "青木护身剑", "evolution_desc": "桃木剑攻击时额外释放护身剑气，击退近身邪祟", "effect": "wood"},
	"water": {"name": "水", "skill_id": "water_array", "cultivation_name": "清泉回元", "cultivation_desc": "每秒恢复少量生命；主修时可继续强化续航", "icon": "cultivation_water", "artifact_id": "cold_relic", "evolution_id": "ice_array", "evolution_name": "冰魄阵", "evolution_desc": "水阵进化为冰魄阵，强化范围减速与短暂冻结", "effect": "water"},
	"fire": {"name": "火", "skill_id": "fire_talisman", "cultivation_name": "余烬续燃", "cultivation_desc": "延长火焰区域并提高灼烧伤害", "icon": "cultivation_fire", "artifact_id": "talisman_scroll", "evolution_id": "heavenfire_array", "evolution_name": "焚天符阵", "evolution_desc": "火符命中后留下持续燃烧的火场，强化范围压制", "effect": "fire"},
	"earth": {"name": "土", "skill_id": "earth_formation", "cultivation_name": "地脉回响", "cultivation_desc": "扩大地脉阵范围并强化击退", "icon": "cultivation_earth", "artifact_id": "formation_manual", "evolution_id": "earth_seal", "evolution_name": "镇岳神印", "evolution_desc": "地脉阵召出更大范围的镇岳震波，强化压制与击退", "effect": "earth"},
	"thunder": {"name": "雷", "skill_id": "thunder_talisman", "cultivation_name": "引雷蓄势", "cultivation_desc": "雷符连锁伤害提高，水系湿润目标更易传导", "icon": "cultivation_thunder", "artifact_id": "thunder_seal", "evolution_id": "five_thunder", "evolution_name": "五雷敕令", "evolution_desc": "雷击爆发与连锁清场强化，传导目标数仍有上限", "effect": "lightning"}
}

var primary_element: String = ""
var element_cultivation_levels: Dictionary = {"metal": 0, "wood": 0, "water": 0, "fire": 0, "earth": 0, "thunder": 0}
var water_recovery_accumulator: float = 0.0
var heal_charges: int = 2
var boss_spawned: bool = false
var level_cards: Array[Dictionary] = []
var skills: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var artifacts: Dictionary = {}
var general_upgrade_levels: Dictionary = {"swift_step": 0, "spirit_gain": 0, "spirit_sense": 0, "vitality": 0}
var active_skill_level: int = 1
var skill_effects: Array[Dictionary] = []
var fire_zones: Array[Dictionary] = []
var pending_area_attacks: Array[Dictionary] = []
var fire_zone_timer: float = 3.5

var joystick_touch_id: int = -1


func _ready() -> void:
	randomize()
	queue_redraw()

	player = PLAYER_SCRIPT.new()
	player.main_ref = self
	player.position = WORLD_SIZE * 0.5
	player.visible = true
	player.z_as_relative = false
	player.z_index = 20
	add_child(player)

	# Create the screen-space UI and opening wave before activating the camera.
	# This keeps the game playable even if a camera API behaves differently on a local engine build.
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.follow_viewport_enabled = false
	add_child(canvas)
	hud = HUD_SCRIPT.new()
	hud.main_ref = self
	hud.visible = true
	hud.z_as_relative = false
	hud.z_index = 100
	canvas.add_child(hud)

	for i in range(7):
		spawn_enemy(_random_enemy_kind())

	# Keep the camera as a sibling of the player and explicitly track global position.
	# Parenting the camera to a custom-drawn actor can make initial canvas transforms
	# harder to diagnose on some editor/runtime combinations.
	gameplay_camera = Camera2D.new()
	gameplay_camera.name = "GameplayCamera"
	gameplay_camera.enabled = true
	gameplay_camera.position_smoothing_enabled = false
	gameplay_camera.limit_left = 0
	gameplay_camera.limit_top = 0
	gameplay_camera.limit_right = int(WORLD_SIZE.x)
	gameplay_camera.limit_bottom = int(WORLD_SIZE.y)
	gameplay_camera.position = player.position
	add_child(gameplay_camera)
	gameplay_camera.make_current()
	gameplay_camera.zoom = Vector2.ONE * _camera_zoom_for_size(get_viewport_rect().size)


func _process(delta: float) -> void:
	# Reassert the gameplay camera each frame so a stale or replaced current camera
	# cannot leave the player and opening enemies outside the visible world.
	if is_instance_valid(gameplay_camera) and is_instance_valid(player):
		gameplay_camera.global_position = player.global_position
		if get_viewport().get_camera_2d() != gameplay_camera:
			gameplay_camera.make_current()
		var desired_zoom := Vector2.ONE * _camera_zoom_for_size(get_viewport_rect().size)
		if not gameplay_camera.zoom.is_equal_approx(desired_zoom):
			gameplay_camera.zoom = desired_zoom

	if active_skill_effect_time > 0.0:
		active_skill_effect_time = maxf(0.0, active_skill_effect_time - delta)
		queue_redraw()
	if state == "playing":
		elapsed_seconds += delta
		active_skill_cooldown = maxf(0.0, active_skill_cooldown - delta)
		player.tick(delta)
		player.z_index = 20 + roundi(clampf(player.position.y / WORLD_SIZE.y, 0.0, 1.0) * 8.0)

		attack_timer -= delta
		if attack_timer <= 0.0:
			_auto_attack()
			attack_timer = player.attack_interval

		spawn_timer -= delta
		if spawn_timer <= 0.0 and _count_live_ordinary_enemies() < _ordinary_enemy_cap():
			_spawn_wave()
			spawn_timer = _spawn_interval()

		if not boss_spawned and elapsed_seconds >= 480.0:
			boss_spawned = true
			_trim_regular_enemies_for_boss_phase(BOSS_PHASE_ENEMY_CAP)
			spawn_enemy("boss")

		_tick_combat_skills(delta)
		_tick_pending_area_attacks(delta)
		_tick_fire_zones(delta)
		_tick_element_cultivation(delta)
		_tick_enemies(delta)
		_tick_projectiles(delta)
		_remove_dead_enemies()
		_tick_xp_orbs(delta)
		_tick_skill_effects(delta)

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
		var touch: Dictionary = hud._touch_layout(view)
		if event.position.distance_to(touch["skill_center"]) <= float(touch["skill_hit_radius"]):
			cast_active_skill()
		elif event.position.distance_to(touch["heal_center"]) <= float(touch["heal_hit_radius"]):
			use_heal()
		elif event.position.x < view.x * 0.42 and event.position.y > view.y * 0.52 and joystick_touch_id == -1:
			joystick_touch_id = event.index
			_update_mobile_move(event.position)
	else:
		if event.index == joystick_touch_id:
			joystick_touch_id = -1
			player.mobile_move = Vector2.ZERO


func _update_mobile_move(screen_position: Vector2) -> void:
	var touch: Dictionary = hud._touch_layout(get_viewport_rect().size)
	var center: Vector2 = touch["joystick_center"]
	var move_radius: float = touch["joystick_move_radius"]
	var offset := screen_position - center
	player.mobile_move = offset.limit_length(move_radius) / maxf(1.0, move_radius)
	if offset.length() < 12.0 * float(touch["scale"]):
		player.mobile_move = Vector2.ZERO


func _camera_zoom_for_size(view_size: Vector2) -> float:
	return clampf(minf(view_size.x / 1280.0, view_size.y / 720.0), 0.5, 1.0)

func _random_enemy_kind() -> String:
	var roll := randf()
	if roll < 0.25:
		return "jumper"
	if roll < 0.36:
		return "armored"
	return "walker"


func _ordinary_enemy_cap() -> int:
		if boss_spawned:
			return BOSS_PHASE_ENEMY_CAP
		if elapsed_seconds < 120.0:
			return 24
		if elapsed_seconds < 300.0:
			return 34
		return 46


func _spawn_interval() -> float:
	if boss_spawned:
		return 1.7
	if elapsed_seconds < 120.0:
		return 2.05
	if elapsed_seconds < 300.0:
		return 1.55
	return 1.15


func _count_live_ordinary_enemies() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.hp > 0.0 and not enemy.is_boss:
			count += 1
	return count


func _trim_regular_enemies_for_boss_phase(max_count: int) -> void:
	while _count_live_ordinary_enemies() > max_count:
		var farthest = null
		var farthest_distance := -1.0
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.hp <= 0.0 or enemy.is_boss:
				continue
			var distance: float = player.position.distance_squared_to(enemy.position)
			if distance > farthest_distance:
				farthest_distance = distance
				farthest = enemy
		if farthest == null:
			break
		enemies.erase(farthest)
		farthest.queue_free()


func _spawn_wave() -> void:
	var amount := 1
	if elapsed_seconds > 90.0 and randf() < 0.24:
		amount = 2
	for i in range(amount):
		if enemies.size() >= MAX_ENEMIES or _count_live_ordinary_enemies() >= _ordinary_enemy_cap():
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
	enemy.visible = true
	enemy.z_as_relative = false
	enemy.z_index = 24 if kind == "boss" else 20
	add_child(enemy)
	enemies.append(enemy)


func _auto_attack() -> void:
	# Once the boss is within attack range, basic attacks help finish the encounter
	# instead of being swallowed by the nearest crowd member.
	var target = _find_combat_target(player.position, BASIC_ATTACK_RANGE)
	if target == null:
		return

	var projectile = PROJECTILE_SCRIPT.new()
	projectile.setup(target, player.damage)
	projectile.visible = true
	projectile.z_as_relative = false
	projectile.z_index = 30
	var direction: Vector2 = (target.position - player.position).normalized()
	player.trigger_attack(direction)
	projectile.position = player.position + direction * 18.0
	projectile.max_travel_distance = BASIC_PROJECTILE_MAX_RANGE
	add_child(projectile)
	projectiles.append(projectile)
	player.queue_redraw()


func _tick_enemies(delta: float) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0:
			continue
		var separation := _get_separation(enemy)
		enemy.tick(delta, player.position, separation)
		enemy.z_index = 20 + roundi(clampf(enemy.position.y / WORLD_SIZE.y, 0.0, 1.0) * 8.0) + (1 if enemy.is_boss else 0)
		if enemy.is_boss and not str(enemy.boss_attack_event).is_empty():
			_resolve_boss_attack(enemy, str(enemy.boss_attack_event))
			enemy.boss_attack_event = ""
		var collision_distance: float = enemy.collision_radius + player.collision_radius
		if enemy.position.distance_squared_to(player.position) <= collision_distance * collision_distance:
			if enemy.hp <= 0.0:
				continue
			if player.invuln_time <= 0.0:
				var jade_level := 0
				if artifacts.has("body_jade"):
					var jade_data: Dictionary = artifacts["body_jade"]
					jade_level = int(jade_data.get("level", 1))
				var contact_multiplier := maxf(0.65, 1.0 - float(jade_level) * 0.08)
				player.take_damage(enemy.contact_damage * contact_multiplier)
				if player.hp <= 0.0:
					state = "game_over"


func _get_separation(enemy) -> Vector2:
	var result := Vector2.ZERO
	for other in enemies:
		if other == enemy or not is_instance_valid(other) or other.hp <= 0.0:
			continue
		var offset: Vector2 = enemy.position - other.position
		var distance := offset.length()
		var desired_distance := 58.0 if enemy.is_boss or other.is_boss else 36.0
		if distance > 0.001 and distance < desired_distance:
			result += offset.normalized() * ((desired_distance - distance) / desired_distance)
	return result


func _resolve_boss_attack(boss, attack_kind: String) -> void:
	var target_position: Vector2 = boss.position if attack_kind == "slam" else boss.boss_attack_target
	var radius := 148.0 if attack_kind == "slam" else 104.0
	_spawn_skill_effect("boss_slam" if attack_kind == "slam" else "boss_zone", target_position, radius, 0.42)
	if player.position.distance_to(target_position) > radius:
		return
	var damage_multiplier := 1.25 if attack_kind == "slam" else 1.4
	player.take_damage(boss.contact_damage * damage_multiplier)
	var push_direction: Vector2 = player.position - target_position
	if push_direction.length_squared() < 0.001:
		push_direction = Vector2.UP
	player.position += push_direction.normalized() * (58.0 if attack_kind == "slam" else 34.0)


func _tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile = projectiles[i]
		projectile.tick(delta, enemies)
		if projectile.impacted and is_instance_valid(projectile.impact_target) and enemies.has(projectile.impact_target):
			_resolve_projectile_hit(projectile)
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
			var wood_cultivation := _cultivation_level("wood")
			if wood_cultivation > 0:
				var hp_before: float = player.hp
				player.heal(0.45 * float(wood_cultivation))
				if player.hp > hp_before:
					_spawn_cultivation_feedback("wood", player.position, 24.0)
			var xp_value := 1
			if enemy.kind == "jumper":
				xp_value = 2
			elif enemy.kind == "armored":
				xp_value = 3
			_spawn_xp_orb(enemy.position, xp_value)
		enemies.remove_at(i)
		enemy.queue_free()

func _spawn_xp_orb(spawn_position: Vector2, amount: int) -> void:
	var orb = XP_ORB_SCRIPT.new()
	orb.setup(amount)
	orb.visible = true
	orb.z_as_relative = false
	orb.z_index = 25
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
	player.xp_to_next = ceili(float(player.xp_to_next) * 1.14 + 1.0)
	_open_upgrade_choices()


func _open_upgrade_choices() -> void:
	level_cards.clear()

	# A Lv3 branch is a real fork in the build. Do not let a relic card bypass it.
	var branchable := _collect_branchable_skills()
	if not branchable.is_empty():
		branchable.shuffle()
		var branch_skill := branchable[0]
		for branch_data in SKILL_BRANCHES.get(branch_skill, []):
			level_cards.append(_branch_card(branch_skill, branch_data))
		level_cards.append(_branch_required_info_card(branch_skill))
		state = "level_up"
		return

	# Mainline commitment is deliberately delayed until character Lv6 and then
	# guaranteed as one clear choice. Earlier levels build skills and branches only.
	if primary_element.is_empty():
		var breakthroughs := _collect_primary_breakthrough_candidates()
		if not breakthroughs.is_empty():
			breakthroughs.shuffle()
			level_cards.append(breakthroughs[0])
			_fill_level_cards(_collect_core_candidates(), _collect_general_candidates(), 3)
			state = "level_up"
			return
	else:
		# Once a mainline is chosen, guarantee its matching core relic before random relics.
		var core_artifact_id := str(ELEMENT_DEFS[primary_element]["artifact_id"])
		if not artifacts.has(core_artifact_id) and artifacts.size() < MAX_ARTIFACT_SLOTS:
			level_cards.append(_artifact_card(core_artifact_id, "artifact_acquire"))

		var evolutions := _collect_evolution_candidates()
		if not evolutions.is_empty():
			evolutions.shuffle()
			_append_card_if_new(evolutions[0])

	_fill_level_cards(_collect_core_candidates(), _collect_general_candidates(), 3)
	state = "level_up"


func _collect_branchable_skills() -> Array[String]:
	var result: Array[String] = []
	for skill_variant in skills.keys():
		var skill_id := str(skill_variant)
		var skill_data: Dictionary = skills[skill_id]
		if int(skill_data.get("level", 1)) == 2 and str(skill_data.get("branch", "")).is_empty():
			result.append(skill_id)
	return result


func _branch_required_info_card(skill_id: String) -> Dictionary:
	var skill_name := str(AUTO_SKILL_DEFS.get(skill_id, {}).get("name", "该技能"))
	return {
		"id": "branch_required_info",
		"kind": "branch_required_info",
		"skill_id": skill_id,
		"name": "必须选择一条分支",
		"desc": "先从前两张卡中选择%s的关键分支；其他强化会在下次升级恢复。" % skill_name,
		"category": "系统提示 · 不可选",
		"icon": skill_id
	}


func _collect_primary_breakthrough_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not primary_element.is_empty() or player == null or player.level < MIN_PRIMARY_BREAKTHROUGH_PLAYER_LEVEL:
		return result
	for skill_variant in skills.keys():
		var skill_id := str(skill_variant)
		if _can_commit_primary(skill_id):
			result.append(_skill_card(skill_id, "skill_level"))
	return result


func _collect_core_candidates() -> Array[Dictionary]:
	var skill_acquisitions: Array[Dictionary] = []
	var skill_upgrades: Array[Dictionary] = []
	var artifact_candidates: Array[Dictionary] = []

	for skill_variant in AUTO_SKILL_DEFS.keys():
		var skill_id := str(skill_variant)
		if skills.has(skill_id):
			var skill_data: Dictionary = skills[skill_id]
			var skill_level := int(skill_data.get("level", 1))
			var branch_pending := skill_level == 2 and str(skill_data.get("branch", "")).is_empty()
			var is_uncommitted_lv3 := primary_element.is_empty() and skill_level >= 3
			if not is_uncommitted_lv3 and skill_level < _skill_level_cap(skill_id) and not branch_pending:
				skill_upgrades.append(_skill_card(skill_id, "skill_level"))
		elif skills.size() < MAX_AUTO_SKILL_SLOTS:
			skill_acquisitions.append(_skill_card(skill_id, "skill_acquire"))

	for artifact_variant in ARTIFACT_DEFS.keys():
		var artifact_id := str(artifact_variant)
		if artifacts.has(artifact_id):
			var artifact_data: Dictionary = artifacts[artifact_id]
			if int(artifact_data.get("level", 1)) < 3:
				artifact_candidates.append(_artifact_card(artifact_id, "artifact_level"))
		elif not primary_element.is_empty() and artifacts.size() < _artifact_slot_cap():
			artifact_candidates.append(_artifact_card(artifact_id, "artifact_acquire"))

	var result: Array[Dictionary] = []
	if skills.size() < MAX_AUTO_SKILL_SLOTS and not skill_acquisitions.is_empty():
		skill_acquisitions.shuffle()
		result.append(skill_acquisitions.pop_back())
	elif not skill_upgrades.is_empty():
		skill_upgrades.shuffle()
		result.append(skill_upgrades.pop_back())
	elif not artifact_candidates.is_empty():
		artifact_candidates.shuffle()
		result.append(artifact_candidates.pop_back())

	for card in skill_acquisitions:
		result.append(card)
	for card in skill_upgrades:
		result.append(card)
	for card in artifact_candidates:
		result.append(card)

	for cultivation_card in _collect_element_cultivation_candidates():
		result.append(cultivation_card)

	if active_skill_level < 3 and (randf() < 0.28 or result.is_empty()):
		result.append(_active_skill_card())
	return result


func _collect_general_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade_variant in GENERAL_UPGRADE_DEFS.keys():
		var upgrade_id := str(upgrade_variant)
		if int(general_upgrade_levels.get(upgrade_id, 0)) < 3:
			result.append(_general_card(upgrade_id))
	return result


func _collect_evolution_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if primary_element.is_empty():
		return result
	for element_variant in ELEMENT_DEFS.keys():
		var element_id := str(element_variant)
		if element_id != primary_element:
			continue
		var definition: Dictionary = ELEMENT_DEFS[element_id]
		var skill_id := str(definition["skill_id"])
		var artifact_id := str(definition["artifact_id"])
		if not skills.has(skill_id) or not artifacts.has(artifact_id):
			continue
		var skill_data: Dictionary = skills[skill_id]
		if int(skill_data.get("level", 1)) < 5 or str(skill_data.get("branch", "")).is_empty() or not str(skill_data.get("evolved", "")).is_empty():
			continue
		var evolution_id := str(definition["evolution_id"])
		result.append({
			"id": "evolve_" + evolution_id,
			"kind": "skill_evolution",
			"skill_id": skill_id,
			"element_id": element_id,
			"artifact_id": artifact_id,
			"evolution_id": evolution_id,
			"name": str(definition["evolution_name"]),
			"desc": str(definition["evolution_desc"]),
			"category": "专属法宝进化",
			"icon": skill_id
		})
	return result


func _element_for_skill(skill_id: String) -> String:
	for element_variant in ELEMENT_DEFS.keys():
		var element_id := str(element_variant)
		if str(ELEMENT_DEFS[element_id].get("skill_id", "")) == skill_id:
			return element_id
	return ""


func _element_name(element_id: String) -> String:
	return str(ELEMENT_DEFS.get(element_id, {}).get("name", "未知"))


func _element_for_artifact(artifact_id: String) -> String:
	for element_variant in ELEMENT_DEFS.keys():
		var element_id := str(element_variant)
		if str(ELEMENT_DEFS[element_id].get("artifact_id", "")) == artifact_id:
			return element_id
	return ""


func _can_commit_primary(skill_id: String) -> bool:
	if not primary_element.is_empty() or player == null or player.level < MIN_PRIMARY_BREAKTHROUGH_PLAYER_LEVEL or not skills.has(skill_id):
		return false
	var skill_data: Dictionary = skills[skill_id]
	return int(skill_data.get("level", 1)) == 3 and not str(skill_data.get("branch", "")).is_empty() and not _element_for_skill(skill_id).is_empty()


func _skill_level_cap(skill_id: String) -> int:
	if primary_element.is_empty():
		return 4 if player != null and player.level >= MIN_PRIMARY_BREAKTHROUGH_PLAYER_LEVEL else 3
	return 5 if _element_for_skill(skill_id) == primary_element else 3


func _element_cultivation_cap(element_id: String) -> int:
	if primary_element.is_empty():
		return 0
	return 3 if element_id == primary_element else 1


func _artifact_slot_cap() -> int:
	return MAX_ARTIFACT_SLOTS if not primary_element.is_empty() else MAX_ARTIFACT_SLOTS - 1


func _cultivation_level(element_id: String) -> int:
	return int(element_cultivation_levels.get(element_id, 0))


func _collect_element_cultivation_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if primary_element.is_empty():
		return result
	for element_variant in ELEMENT_DEFS.keys():
		var element_id := str(element_variant)
		var definition: Dictionary = ELEMENT_DEFS[element_id]
		if not skills.has(str(definition["skill_id"])):
			continue
		if _cultivation_level(element_id) < _element_cultivation_cap(element_id):
			result.append(_element_cultivation_card(element_id))
	return result


func _element_cultivation_card(element_id: String) -> Dictionary:
	var definition: Dictionary = ELEMENT_DEFS[element_id]
	var next_level := _cultivation_level(element_id) + 1
	var description := str(definition["cultivation_desc"])
	if primary_element.is_empty():
		description += "；此项不会锁定主修，主修突破需角色达到 Lv6"
	elif primary_element == element_id:
		description += "；主修专精效果"
	else:
		description += "；兼修仅可提升一次"
	return {
		"id": "cultivation_" + element_id,
		"kind": "element_cultivation",
		"element_id": element_id,
		"target_id": element_id,
		"name": "%s系修炼 · %s Lv%d" % [_element_name(element_id), str(definition["cultivation_name"]), next_level],
		"desc": description,
		"category": "元素修炼",
		"icon": str(definition["icon"])
	}


func _skill_card(skill_id: String, card_kind: String) -> Dictionary:
	var definition: Dictionary = AUTO_SKILL_DEFS[skill_id]
	var card_name := str(definition["name"])
	var description := str(definition["desc"])
	var card_id := "acquire_" + skill_id
	if card_kind == "skill_level":
		var current_data: Dictionary = skills[skill_id]
		var current_level := int(current_data.get("level", 1))
		var element_id := _element_for_skill(skill_id)
		card_id = "upgrade_" + skill_id
		if primary_element.is_empty() and current_level >= 3:
			if _can_commit_primary(skill_id):
				card_name = "立道突破 · %s Lv4" % str(definition["name"])
				description = "角色已达 Lv%d，确定%s系为本局主修；该系可升至 Lv5，其他元素最高 Lv3。" % [player.level, _element_name(element_id)]
			else:
				card_name = "立道未开 · %s" % str(definition["name"])
				description = "角色达到 Lv%d 后，才可将此技能突破至 Lv4 并确定主修方向。" % MIN_PRIMARY_BREAKTHROUGH_PLAYER_LEVEL
		else:
			card_name += "精进 · Lv%d" % (current_level + 1)
			description = str(definition["upgrade_desc"])
			if element_id == primary_element and current_level == 4:
				description += "；Lv5 后需配合专属法宝才能最终进化"
	return {"id": card_id, "kind": card_kind, "skill_id": skill_id, "name": card_name, "desc": description, "category": "攻击技能" if card_kind == "skill_acquire" else ("立道突破" if card_name.begins_with("立道突破") else "技能精进"), "icon": skill_id}


func _branch_card(skill_id: String, branch_data: Dictionary) -> Dictionary:
	return {
		"id": "branch_%s_%s" % [skill_id, str(branch_data["id"])],
		"kind": "skill_branch",
		"skill_id": skill_id,
		"branch_id": str(branch_data["id"]),
		"name": "%s · %s" % [str(AUTO_SKILL_DEFS[skill_id]["name"]), str(branch_data["name"])],
		"desc": str(branch_data["desc"]),
		"category": "Lv3 关键分支",
		"icon": "%s_%s" % [skill_id, str(branch_data["id"])]
	}


func _artifact_card(artifact_id: String, card_kind: String) -> Dictionary:
	var definition: Dictionary = ARTIFACT_DEFS[artifact_id]
	var card_name := str(definition["name"])
	var description := str(definition["desc"])
	var card_id := "acquire_" + artifact_id
	if card_kind == "artifact_level":
		var current_data: Dictionary = artifacts[artifact_id]
		card_id = "upgrade_" + artifact_id
		card_name += " · Lv%d" % (int(current_data.get("level", 1)) + 1)
		description = "法器效果提升一级"
	elif card_kind == "artifact_acquire":
		var artifact_element := _element_for_artifact(artifact_id)
		if primary_element.is_empty():
			description = "提供被动效果；不会锁定主修方向。"
		elif artifact_element == primary_element:
			description += "；匹配当前主修，可作为最终进化条件"
		else:
			description += "；不满足当前主修的最终进化条件"
	return {"id": card_id, "kind": card_kind, "artifact_id": artifact_id, "name": card_name, "desc": description, "category": "被动法器", "icon": str(definition["icon"])}


func _general_card(upgrade_id: String) -> Dictionary:
	var definition: Dictionary = GENERAL_UPGRADE_DEFS[upgrade_id]
	var next_level := int(general_upgrade_levels.get(upgrade_id, 0)) + 1
	return {"id": "general_" + upgrade_id, "kind": "general_upgrade", "target_id": upgrade_id, "name": "%s · Lv%d" % [str(definition["name"]), next_level], "desc": str(definition["desc"]), "category": "通用强化", "icon": str(definition["icon"])}


func _active_skill_card() -> Dictionary:
	return {"id": "active_skill_upgrade", "kind": "active_skill_upgrade", "name": "镇尸诀精进 · Lv%d" % (active_skill_level + 1), "desc": "道术范围与伤害提高，冷却略微缩短", "category": "主动道术", "icon": "control_art"}


func _fill_level_cards(core: Array[Dictionary], general: Array[Dictionary], desired_count: int) -> void:
	if level_cards.size() >= desired_count:
		return

	var acquisitions: Array[Dictionary] = []
	var preferred: Array[Dictionary] = []
	for card in core:
		if str(card.get("kind", "")) == "skill_acquire":
			acquisitions.append(card)
		else:
			preferred.append(card)
	acquisitions.shuffle()
	preferred.shuffle()
	general.shuffle()

	# The first level-up always teaches a real attack skill. After that, new
	# skills become progressively less common so a build can mature.
	if skills.is_empty() and level_cards.is_empty() and not acquisitions.is_empty():
		_append_card_if_new(acquisitions.pop_back())

	var acquisition_chance := 0.68 if skills.size() < 2 else (0.28 if skills.size() < MAX_AUTO_SKILL_SLOTS else 0.0)
	if level_cards.size() < desired_count and not acquisitions.is_empty() and not _has_new_skill_acquisition() and randf() < acquisition_chance:
		_append_card_if_new(acquisitions.pop_back())

	while level_cards.size() < desired_count:
		var candidates: Array[Dictionary] = []
		for card in preferred:
			candidates.append(card)
		if not _has_general_card():
			for card in general:
				candidates.append(card)
		if candidates.is_empty():
			if not acquisitions.is_empty() and _count_skill_acquisition_cards() < 2:
				_append_card_if_new(acquisitions.pop_back())
				continue
			break

		var selected := _take_weighted_upgrade(candidates)
		if selected.is_empty():
			break
		var selected_id := str(selected.get("id", ""))
		if str(selected.get("kind", "")) == "general_upgrade":
			for i in range(general.size() - 1, -1, -1):
				if str(general[i].get("id", "")) == selected_id:
					general.remove_at(i)
					break
		else:
			for i in range(preferred.size() - 1, -1, -1):
				if str(preferred[i].get("id", "")) == selected_id:
					preferred.remove_at(i)
					break
		_append_card_if_new(selected)


func _count_skill_acquisition_cards() -> int:
	var count := 0
	for card in level_cards:
		if str(card.get("kind", "")) == "skill_acquire":
			count += 1
	return count


func _has_new_skill_acquisition() -> bool:
	for card in level_cards:
		if str(card.get("kind", "")) == "skill_acquire":
			return true
	return false


func _upgrade_weight(card: Dictionary) -> float:
	match str(card.get("kind", "")):
		"skill_level":
			return 5.0
		"element_cultivation":
			return 2.6
		"artifact_level":
			return 3.8
		"artifact_acquire":
			return 2.7
		"active_skill_upgrade":
			return 1.2
		"general_upgrade":
			return 0.85
		_:
			return 1.0


func _take_weighted_upgrade(candidates: Array[Dictionary]) -> Dictionary:
	var total_weight := 0.0
	for card in candidates:
		total_weight += _upgrade_weight(card)
	if total_weight <= 0.0:
		return {}
	var roll := randf() * total_weight
	for card in candidates:
		roll -= _upgrade_weight(card)
		if roll <= 0.0:
			return card
	return candidates.back()


func _append_card_if_new(card: Dictionary) -> void:
	var card_id := str(card.get("id", ""))
	for existing in level_cards:
		if str(existing.get("id", "")) == card_id:
			return
	level_cards.append(card)


func _has_general_card() -> bool:
	for card in level_cards:
		if str(card.get("kind", "")) == "general_upgrade":
			return true
	return false


func _select_upgrade(index: int) -> void:
	if state != "level_up" or index < 0 or index >= level_cards.size():
		return
	var upgrade: Dictionary = level_cards[index]
	if str(upgrade.get("kind", "")) == "branch_required_info":
		return
	_apply_upgrade(upgrade)
	state = "playing"
	_maybe_level_up()


func _apply_upgrade(upgrade: Dictionary) -> void:
	var kind := str(upgrade.get("kind", ""))
	var skill_id := str(upgrade.get("skill_id", ""))
	var artifact_id := str(upgrade.get("artifact_id", ""))
	match kind:
		"skill_acquire":
			if not AUTO_SKILL_DEFS.has(skill_id) or skills.has(skill_id) or skills.size() >= MAX_AUTO_SKILL_SLOTS:
				return
			skills[skill_id] = {"level": 1, "branch": "", "evolved": ""}
			skill_cooldowns[skill_id] = 0.0
		"skill_level":
			if not skills.has(skill_id):
				return
			var skill_data: Dictionary = skills[skill_id]
			var current_level := int(skill_data.get("level", 1))
			if current_level >= _skill_level_cap(skill_id):
				return
			if primary_element.is_empty() and current_level >= 3:
				if not _can_commit_primary(skill_id):
					return
				primary_element = _element_for_skill(skill_id)
				if primary_element.is_empty():
					return
			var level_cap := _skill_level_cap(skill_id)
			if current_level >= level_cap:
				return
			skill_data["level"] = current_level + 1
			skills[skill_id] = skill_data
		"skill_branch":
			if not skills.has(skill_id):
				return
			var branch_skill: Dictionary = skills[skill_id]
			if int(branch_skill.get("level", 1)) != 2 or not str(branch_skill.get("branch", "")).is_empty():
				return
			var branch_id := str(upgrade.get("branch_id", ""))
			var valid_branch := false
			for branch_option in SKILL_BRANCHES.get(skill_id, []):
				if str(branch_option.get("id", "")) == branch_id:
					valid_branch = true
					break
			if not valid_branch:
				return
			branch_skill["level"] = 3
			branch_skill["branch"] = branch_id
			skills[skill_id] = branch_skill
		"skill_evolution":
			var element_id := str(upgrade.get("element_id", ""))
			var evolution_id := str(upgrade.get("evolution_id", ""))
			if primary_element != element_id or not ELEMENT_DEFS.has(element_id) or not skills.has(skill_id) or not artifacts.has(artifact_id):
				return
			var evolution_skill: Dictionary = skills[skill_id]
			var element_definition: Dictionary = ELEMENT_DEFS[element_id]
			if str(element_definition.get("skill_id", "")) != skill_id or str(element_definition.get("artifact_id", "")) != artifact_id or str(element_definition.get("evolution_id", "")) != evolution_id:
				return
			if int(evolution_skill.get("level", 1)) < 5 or str(evolution_skill.get("branch", "")).is_empty() or not str(evolution_skill.get("evolved", "")).is_empty():
				return
			evolution_skill["evolved"] = evolution_id
			skills[skill_id] = evolution_skill
			var effect_kind := str(element_definition.get("effect", "lightning"))
			_spawn_skill_effect(effect_kind, player.position, 115.0, 0.55)
		"artifact_acquire":
			if primary_element.is_empty() or not ARTIFACT_DEFS.has(artifact_id) or artifacts.has(artifact_id) or artifacts.size() >= _artifact_slot_cap():
				return
			artifacts[artifact_id] = {"level": 1}
		"artifact_level":
			if not artifacts.has(artifact_id):
				return
			var artifact_data: Dictionary = artifacts[artifact_id]
			var current_artifact_level := int(artifact_data.get("level", 1))
			if current_artifact_level >= 3:
				return
			artifact_data["level"] = current_artifact_level + 1
			artifacts[artifact_id] = artifact_data
		"element_cultivation":
			var element_id := str(upgrade.get("element_id", ""))
			if primary_element.is_empty() or not ELEMENT_DEFS.has(element_id):
				return
			var element_definition: Dictionary = ELEMENT_DEFS[element_id]
			if not skills.has(str(element_definition.get("skill_id", ""))):
				return
			var current_cultivation := _cultivation_level(element_id)
			var cultivation_cap := _element_cultivation_cap(element_id)
			if current_cultivation >= cultivation_cap:
				return
			element_cultivation_levels[element_id] = current_cultivation + 1
			var effect_kind := str(element_definition.get("effect", "hit"))
			_spawn_skill_effect(effect_kind, player.position, 58.0, 0.42)
		"general_upgrade":
			var general_id := str(upgrade.get("target_id", ""))
			if not GENERAL_UPGRADE_DEFS.has(general_id):
				return
			var current_general_level := int(general_upgrade_levels.get(general_id, 0))
			if current_general_level >= 3:
				return
			var new_level := current_general_level + 1
			general_upgrade_levels[general_id] = new_level
			match general_id:
				"swift_step":
					player.move_speed *= 1.08
				"spirit_gain":
					player.xp_gain_multiplier += 0.15
				"spirit_sense":
					player.pickup_radius *= 1.25
				"vitality":
					player.max_hp += 20.0
					player.heal(20.0)
		"active_skill_upgrade":
			if active_skill_level >= 3:
				return
			active_skill_level += 1
			active_skill_base_cooldown = maxf(8.0, active_skill_base_cooldown * 0.92)


func _artifact_level(artifact_id: String) -> int:
	if not artifacts.has(artifact_id):
		return 0
	var data: Dictionary = artifacts[artifact_id]
	return int(data.get("level", 1))


func _spawn_cultivation_feedback(element_id: String, center: Vector2, radius: float = 26.0) -> void:
	if _cultivation_level(element_id) <= 0:
		return
	_spawn_skill_effect("cultivation_" + element_id, center, radius, 0.28)



func _tick_element_cultivation(delta: float) -> void:
	var water_level := _cultivation_level("water")
	if water_level <= 0 or player == null:
		water_recovery_accumulator = 0.0
		return
	water_recovery_accumulator += delta
	while water_recovery_accumulator >= 1.0:
		water_recovery_accumulator -= 1.0
		var hp_before: float = player.hp
		player.heal(0.35 * float(water_level))
		if player.hp > hp_before:
			_spawn_cultivation_feedback("water", player.position, 26.0)

func _skill_damage(skill_id: String, base_damage: float) -> float:
	var skill_data: Dictionary = skills.get(skill_id, {})
	var skill_level := int(skill_data.get("level", 1))
	var multiplier := 1.0 + float(skill_level - 1) * 0.18
	if skill_id == "copper_coin_sword":
		multiplier *= 1.0 + 0.08 * float(_cultivation_level("metal"))
	if _artifact_level("talisman_scroll") > 0 and skill_id == "fire_talisman":
		multiplier *= 1.0 + 0.12 * float(_artifact_level("talisman_scroll"))
	if _artifact_level("thunder_seal") > 0 and skill_id == "thunder_talisman":
		multiplier *= 1.0 + 0.15 * float(_artifact_level("thunder_seal"))
	if _artifact_level("cold_relic") > 0 and skill_id == "water_array":
		multiplier *= 1.0 + 0.12 * float(_artifact_level("cold_relic"))
	if _artifact_level("sword_manual") > 0 and skill_id == "copper_coin_sword":
		multiplier *= 1.0 + 0.12 * float(_artifact_level("sword_manual"))
	if _artifact_level("formation_manual") > 0 and skill_id == "earth_formation":
		multiplier *= 1.0 + 0.12 * float(_artifact_level("formation_manual"))
	var evolved := str(skill_data.get("evolved", ""))
	if not evolved.is_empty():
		multiplier *= 1.3
	return base_damage * multiplier


func _skill_cooldown(skill_id: String, base_cooldown: float) -> float:
	var skill_data: Dictionary = skills.get(skill_id, {})
	var skill_level := int(skill_data.get("level", 1))
	return maxf(0.82, base_cooldown * (1.0 - float(skill_level - 1) * 0.035))


func _find_nearest_enemy(origin: Vector2, max_distance: float, excluded: Array = []):
	var nearest = null
	var best_distance := max_distance
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0 or excluded.has(enemy):
			continue
		var distance: float = origin.distance_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			nearest = enemy
	return nearest


func _find_combat_target(origin: Vector2, max_distance: float, excluded: Array = []):
	var boss = get_boss()
	if boss != null and is_instance_valid(boss) and boss.hp > 0.0 and not excluded.has(boss):
		if origin.distance_to(boss.position) <= max_distance:
			return boss
	return _find_nearest_enemy(origin, max_distance, excluded)


func _find_nearest_targets(origin: Vector2, max_distance: float, limit: int) -> Array:
	var targets: Array = []
	while targets.size() < limit:
		var target = _find_combat_target(origin, max_distance, targets)
		if target == null:
			break
		targets.append(target)
	return targets


func _find_nearest_chain_target(origin: Vector2, max_hop_distance: float, excluded: Array = []):
	var nearest = null
	var best_distance := max_hop_distance
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0 or excluded.has(enemy):
			continue
		if player.position.distance_to(enemy.position) > MAX_CHAIN_DISTANCE_FROM_PLAYER:
			continue
		var distance: float = origin.distance_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			nearest = enemy
	return nearest


func _spawn_skill_projectile(target, skill_id: String, damage: float):
	var projectile = PROJECTILE_SCRIPT.new()
	projectile.setup(target, damage, skill_id)
	projectile.visible = true
	projectile.z_as_relative = false
	projectile.z_index = 30
	var direction: Vector2 = (target.position - player.position).normalized()
	player.facing = direction
	projectile.position = player.position + direction * 18.0
	projectile.max_travel_distance = AUTO_SKILL_PROJECTILE_MAX_RANGE
	add_child(projectile)
	projectiles.append(projectile)
	player.queue_redraw()
	return projectile

func _tick_combat_skills(delta: float) -> void:
	for skill_variant in skills.keys():
		var skill_id := str(skill_variant)
		skill_cooldowns[skill_id] = maxf(0.0, float(skill_cooldowns.get(skill_id, 0.0)) - delta)
		if float(skill_cooldowns[skill_id]) > 0.0:
			continue
		var target = _find_combat_target(player.position, AUTO_SKILL_RANGE)
		if target == null:
			skill_cooldowns[skill_id] = 0.25
			continue
		_cast_auto_skill(skill_id, target)


func _cast_auto_skill(skill_id: String, target) -> void:
	if not is_instance_valid(target) or target.hp <= 0.0:
		return
	if player.position.distance_to(target.position) > AUTO_SKILL_RANGE:
		return
	var skill_data: Dictionary = skills[skill_id]
	var skill_level := int(skill_data.get("level", 1))
	var branch := str(skill_data.get("branch", ""))
	var evolved := str(skill_data.get("evolved", ""))
	var definition: Dictionary = AUTO_SKILL_DEFS[skill_id]
	var damage := _skill_damage(skill_id, float(definition["damage"]))
	var cooldown := _skill_cooldown(skill_id, float(definition["cooldown"]))
	var cast_direction: Vector2 = (target.position - player.position).normalized()
	player.trigger_cast(cast_direction, PLAYER_SCRIPT.CAST_DURATION, PLAYER_SCRIPT.cast_element_for_skill(skill_id))
	match skill_id:
		"fire_talisman":
			var target_count := 2 if branch == "spread" else 1
			var targets := _find_nearest_targets(player.position, AUTO_SKILL_RANGE, target_count)
			for i in range(targets.size()):
				var fireball = _spawn_skill_projectile(targets[i], skill_id, damage * (0.78 if i > 0 else 1.0))
				fireball.splash_radius = 46.0 + float(skill_level - 1) * 2.0
				fireball.splash_damage_ratio = 0.38
			if branch == "spread":
				cooldown *= 1.12
		"thunder_talisman":
			if branch == "heaven":
				damage *= 1.8
				cooldown *= 1.38
			_cast_thunder_strike(target, damage, branch, evolved)
		"copper_coin_sword":
			var sword = _spawn_skill_projectile(target, skill_id, damage)
			if branch == "pierce":
				sword.behavior = "pierce"
				sword.pierce_remaining = 2
				sword.lifetime = 0.8
			elif branch == "return":
				sword.behavior = "return"
				sword.return_damage_multiplier = 0.55
				sword.lifetime = 1.4
		"peachwood_sword":
			if branch == "guardian":
				var guardian_radius := 52.0 + float(skill_level) * 7.0
				_apply_area_damage(player.position, guardian_radius, damage * 0.72, "wood", 0.0, false, 20.0)
				_spawn_skill_effect("wood_guardian", player.position, guardian_radius, 0.34)
			else:
				_spawn_skill_projectile(target, skill_id, damage)
			if evolved == "greenwood_guardian":
				var evolved_guardian_radius := 68.0 + float(skill_level) * 3.0
				_apply_area_damage(player.position, evolved_guardian_radius, damage * 0.45, "wood", 0.0, false, 18.0)
				_spawn_skill_effect("greenwood_guardian", player.position, evolved_guardian_radius, 0.42)
				if _artifact_level("body_jade") > 0:
					_spawn_skill_effect("body_jade", player.position, evolved_guardian_radius * 0.72, 0.34)
		"water_array":
			var water_radius := 76.0 + float(skill_level) * 9.0
			var slow_duration := 1.2 + float(skill_level - 1) * 0.12
			if branch == "tide":
				water_radius += 34.0
			if branch == "cold":
				slow_duration *= 1.7
			var cold_relic_level := _artifact_level("cold_relic")
			if cold_relic_level > 0:
				slow_duration *= 1.0 + float(cold_relic_level) * 0.12
			if evolved == "ice_array":
				water_radius += 12.0
				slow_duration = 2.25
			var water_orb = _spawn_skill_projectile(target, skill_id, damage)
			water_orb.splash_radius = water_radius
			water_orb.slow_duration = slow_duration
			water_orb.applies_wet = true
			water_orb.applies_freeze = evolved == "ice_array"
		"earth_formation":
			var earth_cultivation := _cultivation_level("earth")
			var earth_radius := (66.0 + float(skill_level) * 8.0) * (1.0 + 0.06 * float(earth_cultivation))
			var knockback := 8.0 * float(earth_cultivation)
			if branch == "mountain":
				earth_radius += 16.0
				knockback += 22.0
			if branch == "earthspike":
				damage *= 1.6
			if evolved == "earth_seal":
				earth_radius += 30.0
				damage *= 1.25
				knockback += 12.0
			_schedule_area_attack(target.position, earth_radius, damage, knockback, evolved == "earth_seal")
	skill_cooldowns[skill_id] = cooldown

func _first_enemy_on_segment(start_position: Vector2, end_position: Vector2):
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared < 0.001:
		return null
	var first_target = null
	var first_progress := 2.0
	for candidate in enemies:
		if not is_instance_valid(candidate) or candidate.hp <= 0.0:
			continue
		var progress := clampf((candidate.position - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest_point: Vector2 = start_position + segment * progress
		var hit_radius := float(candidate.collision_radius) + 3.0
		if closest_point.distance_squared_to(candidate.position) <= hit_radius * hit_radius and progress < first_progress:
			first_target = candidate
			first_progress = progress
	return first_target


func _cast_thunder_strike(target, damage: float, branch: String, evolved: String) -> void:
	var strike_target = _first_enemy_on_segment(player.position, target.position)
	if strike_target == null:
		strike_target = target
	if not is_instance_valid(strike_target) or not enemies.has(strike_target):
		return
	var was_wet: bool = strike_target.wet_timer > 0.0
	strike_target.take_damage(damage * (1.35 if was_wet else 1.0))
	if was_wet:
		strike_target.wet_timer = 0.0
	var direction: Vector2 = (strike_target.position - player.position).normalized()
	_spawn_chain_effect(player.position + direction * 10.0, strike_target.position, 0.16)
	if evolved == "five_thunder":
		_spawn_skill_effect("five_thunder", strike_target.position, 44.0, 0.36)
		if _artifact_level("thunder_seal") > 0:
			_spawn_skill_effect("thunder_seal", player.position, 42.0, 0.32)
	else:
		_spawn_skill_effect("lightning", strike_target.position, 32.0, 0.25)
	if _cultivation_level("thunder") > 0:
		_spawn_cultivation_feedback("thunder", strike_target.position, 26.0)
	var chain_count := 0
	if branch == "chain":
		chain_count = 3
	if evolved == "five_thunder":
		chain_count = 4
	if was_wet:
		chain_count += 1
	if branch == "heaven" and evolved != "five_thunder":
		chain_count = 0
	var chain_multiplier := 0.58 * (1.0 + 0.1 * float(_cultivation_level("thunder")))
	_apply_chain_damage(strike_target, damage * chain_multiplier, chain_count)

func _schedule_area_attack(center: Vector2, radius: float, damage: float, knockback: float, evolved: bool = false) -> void:
	if pending_area_attacks.size() >= 24:
		pending_area_attacks.remove_at(0)
	pending_area_attacks.append({
		"position": center,
		"radius": radius,
		"damage": damage,
		"knockback": knockback,
		"timer": 0.18,
		"evolved": evolved
	})
	_spawn_skill_effect("earth_telegraph", center, radius, 0.2)


func _tick_pending_area_attacks(delta: float) -> void:
	for i in range(pending_area_attacks.size() - 1, -1, -1):
		var attack: Dictionary = pending_area_attacks[i]
		attack["timer"] = float(attack.get("timer", 0.0)) - delta
		if float(attack["timer"]) <= 0.0:
			var center: Vector2 = attack.get("position", Vector2.ZERO)
			var radius := float(attack.get("radius", 70.0))
			var damage := float(attack.get("damage", 0.0))
			var knockback := float(attack.get("knockback", 0.0))
			var evolved := bool(attack.get("evolved", false))
			_apply_area_damage(center, radius, damage, "earth", 0.0, false, knockback)
			_spawn_skill_effect("earth_seal" if evolved else "earth_spike", center, radius, 0.38)
			if evolved and _artifact_level("formation_manual") > 0:
				_spawn_skill_effect("formation_seal", center, radius * 0.78, 0.32)
			if _cultivation_level("earth") > 0:
				_spawn_cultivation_feedback("earth", center, minf(30.0, radius * 0.42))
			pending_area_attacks.remove_at(i)
		else:
			pending_area_attacks[i] = attack

func _apply_area_damage(center: Vector2, radius: float, damage: float, effect_kind: String, slow_duration: float = 0.0, apply_wet: bool = false, knockback: float = 0.0) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0:
			continue
		if enemy.position.distance_to(center) > radius:
			continue
		enemy.take_damage(damage)
		if slow_duration > 0.0:
			enemy.apply_slow(slow_duration, 0.68)
		if apply_wet:
			if enemy.burn_timer > 0.0:
				enemy.burn_timer = 0.0
				enemy.burn_dps = 0.0
				enemy.take_damage(damage * 0.25)
				_spawn_skill_effect("steam", enemy.position, 30.0, 0.24)
			enemy.apply_wet(3.2)
		if knockback > 0.0:
			var push_direction: Vector2 = enemy.position - center
			if push_direction.length_squared() < 0.001:
				push_direction = enemy.position - player.position
			if push_direction.length_squared() < 0.001:
				push_direction = Vector2.UP
			enemy.position += push_direction.normalized() * knockback
	_spawn_skill_effect(effect_kind, center, radius, 0.48)


func _resolve_projectile_hit(projectile) -> void:
	var target = projectile.impact_target
	if not is_instance_valid(target) or not enemies.has(target):
		return
	var skill_id := str(projectile.skill_id)
	var damage := float(projectile.damage)
	var skill_data: Dictionary = skills.get(skill_id, {})
	var branch := str(skill_data.get("branch", ""))
	var evolved := str(skill_data.get("evolved", ""))
	if skill_id == "copper_coin_sword" and projectile.impact_is_return:
		target.take_damage(damage * float(projectile.return_damage_multiplier))
		_spawn_skill_effect("slash", target.position, 24.0, 0.18)
		return
	match skill_id:
		"fire_talisman":
			var splash_radius := float(projectile.splash_radius) if float(projectile.splash_radius) > 0.0 else 46.0
			target.take_damage(damage)
			var target_was_wet: bool = target.wet_timer > 0.0
			if target_was_wet:
				target.wet_timer = 0.0
				_apply_area_damage(target.position, splash_radius, damage * 0.35, "steam")
				_spawn_skill_effect("steam", target.position, splash_radius, 0.28)
			else:
				for splash_target in enemies:
					if not is_instance_valid(splash_target) or splash_target.hp <= 0.0 or splash_target == target:
						continue
					if splash_target.position.distance_to(target.position) <= splash_radius:
						splash_target.take_damage(damage * float(projectile.splash_damage_ratio))
				_spawn_skill_effect("fire", target.position, splash_radius, 0.3)
				if branch == "flame":
					target.apply_burn(2.8 + 0.2 * float(_cultivation_level("fire")), 2.8 + float(skill_data.get("level", 1)) * 0.55 + 0.35 * float(_cultivation_level("fire")))
				else:
					target.apply_burn(1.35 + 0.15 * float(_cultivation_level("fire")), 1.7 + 0.3 * float(_cultivation_level("fire")))
			if evolved == "heavenfire_array":
				_spawn_fire_zone(target.position, int(skill_data.get("level", 5)), true)
				_spawn_skill_effect("heavenfire_impact", target.position, splash_radius, 0.36)
				if _artifact_level("talisman_scroll") > 0:
					_spawn_skill_effect("talisman_seal", target.position, splash_radius * 0.72, 0.32)
			if _cultivation_level("fire") > 0:
				_spawn_cultivation_feedback("fire", target.position, 24.0)
		"water_array":
			var splash_radius := float(projectile.splash_radius) if float(projectile.splash_radius) > 0.0 else 85.0
			var slow_duration := float(projectile.slow_duration) if float(projectile.slow_duration) > 0.0 else 1.2
			var frozen := bool(projectile.applies_freeze)
			_apply_area_damage(target.position, splash_radius, damage, "water_splash", slow_duration, bool(projectile.applies_wet), 0.0)
			if frozen:
				for splash_target in enemies:
					if not is_instance_valid(splash_target) or splash_target.hp <= 0.0:
						continue
					if splash_target.position.distance_to(target.position) <= splash_radius:
						splash_target.apply_freeze(0.55)
				_spawn_skill_effect("ice_splash", target.position, splash_radius, 0.38)
				if _artifact_level("cold_relic") > 0:
					_spawn_skill_effect("cold_relic", target.position, splash_radius * 0.68, 0.34)
			if _cultivation_level("water") > 0:
				_spawn_cultivation_feedback("water", target.position, 24.0)
		"copper_coin_sword":
			var hit_damage := damage
			if branch == "pierce" and int(projectile.pierce_hit_count) > 1:
				hit_damage *= float(projectile.pierce_damage_multiplier)
			target.take_damage(hit_damage)
			_spawn_skill_effect("metal_impact", target.position, 25.0, 0.18)
			if branch == "return":
				projectile.begin_return(player)
			if evolved == "golden_sword_array":
				_apply_chain_damage(target, damage * 0.42, 2, "metal")
				_spawn_skill_effect("golden_sword_array", target.position, 38.0, 0.28)
				if _artifact_level("sword_manual") > 0:
					_spawn_skill_effect("sword_manual", target.position, 42.0, 0.3)
			if _cultivation_level("metal") > 0:
				_spawn_cultivation_feedback("metal", target.position, 24.0)
		"peachwood_sword":
			target.take_damage(damage)
			if branch == "chase" and bool(projectile.allow_secondary_chase):
				var chase_target = _find_nearest_chain_target(target.position, SECONDARY_CHASE_RANGE, [target])
				if chase_target != null:
					var chase_projectile = _spawn_skill_projectile(chase_target, skill_id, damage * 0.52)
					chase_projectile.position = target.position
					chase_projectile.hit_targets.append(target)
					var chase_direction: Vector2 = (chase_target.position - target.position).normalized()
					if chase_direction.length_squared() > 0.001:
						chase_projectile.rotation = chase_direction.angle() + PI * 0.5
					chase_projectile.allow_secondary_chase = false
					chase_projectile.is_secondary = true
					chase_projectile.speed = 520.0
			_spawn_skill_effect("wood", target.position, 18.0, 0.2)
		_:
			target.take_damage(damage)
			_spawn_skill_effect("hit", target.position, 18.0, 0.16)

func _apply_chain_damage(origin_enemy, damage: float, max_targets: int, chain_style: String = "lightning") -> void:
	if max_targets <= 0 or not is_instance_valid(origin_enemy):
		return
	var hit_targets: Array = [origin_enemy]
	for i in range(max_targets):
		var next_target = _find_nearest_chain_target(origin_enemy.position, CHAIN_HOP_RANGE, hit_targets)
		if next_target == null:
			break
		next_target.take_damage(damage)
		hit_targets.append(next_target)
		if chain_style == "metal":
			_spawn_chain_effect(origin_enemy.position, next_target.position, 0.2, "metal_chain")
			_spawn_skill_effect("slash", next_target.position, 26.0, 0.18)
		elif chain_style == "wood":
			_spawn_chain_effect(origin_enemy.position, next_target.position, 0.22, "wood_chain")
			_spawn_skill_effect("wood", next_target.position, 22.0, 0.2)
		else:
			_spawn_chain_effect(origin_enemy.position, next_target.position, 0.26)
			_spawn_skill_effect("lightning", next_target.position, 28.0, 0.24)

func _spawn_skill_effect(effect_kind: String, center: Vector2, radius: float, duration: float) -> void:
	# Cap transient particles so dense late-game combat cannot grow the effect list without bound.
	if skill_effects.size() >= 80:
		skill_effects.remove_at(0)
	skill_effects.append({"kind": effect_kind, "position": center, "radius": radius, "time": duration, "duration": duration})
	queue_redraw()


func _spawn_chain_effect(start_position: Vector2, end_position: Vector2, duration: float = 0.26, effect_kind: String = "lightning_chain") -> void:
	if skill_effects.size() >= 80:
		skill_effects.remove_at(0)
	skill_effects.append({
		"kind": effect_kind,
		"position": start_position,
		"from": start_position,
		"to": end_position,
		"radius": start_position.distance_to(end_position),
		"time": duration,
		"duration": duration
	})
	queue_redraw()

func _tick_fire_zones(delta: float) -> void:
	if skills.has("fire_talisman"):
		fire_zone_timer -= delta
		if fire_zone_timer <= 0.0:
			var target = _find_combat_target(player.position, AUTO_SKILL_RANGE)
			if target != null:
				var skill_data: Dictionary = skills["fire_talisman"]
				var level := int(skill_data.get("level", 1))
				_spawn_fire_zone(target.position, level, false)
				fire_zone_timer = maxf(3.8, 5.0 - float(level - 1) * 0.22 - 0.08 * float(_cultivation_level("fire")))
			else:
				fire_zone_timer = 0.6

	for i in range(fire_zones.size() - 1, -1, -1):
		var zone: Dictionary = fire_zones[i]
		zone["time"] = float(zone.get("time", 0.0)) - delta
		zone["tick_timer"] = float(zone.get("tick_timer", 0.0)) - delta
		if float(zone["time"]) <= 0.0:
			fire_zones.remove_at(i)
			continue
		if float(zone["tick_timer"]) <= 0.0:
			var center: Vector2 = zone.get("position", Vector2.ZERO)
			var radius := float(zone.get("radius", 78.0))
			var tick_damage := float(zone.get("damage", 3.0))
			for enemy in enemies:
				if not is_instance_valid(enemy) or enemy.hp <= 0.0:
					continue
				if enemy.position.distance_to(center) <= radius:
					enemy.take_damage(tick_damage)
					enemy.apply_burn(0.7, tick_damage * 0.3)
			zone["tick_timer"] = 0.5
		fire_zones[i] = zone
	if not fire_zones.is_empty():
		queue_redraw()


func _spawn_fire_zone(center: Vector2, skill_level: int, evolved_burst: bool = false) -> void:
	var cultivation_level := _cultivation_level("fire")
	var radius := 78.0 + float(skill_level - 1) * 7.0 + float(cultivation_level) * 3.0
	var duration := 3.0 + float(cultivation_level) * 0.28
	var damage := 2.8 + float(skill_level) * 0.9 + float(cultivation_level) * 0.45
	if evolved_burst:
		radius += 14.0
		duration += 0.7
		damage += 1.0
	fire_zones.append({
		"position": center,
		"radius": radius,
		"time": duration,
		"duration": duration,
		"tick_timer": 0.25,
		"damage": damage
	})
	if fire_zones.size() > 4:
		fire_zones.remove_at(0)
	_spawn_skill_effect("fire", center, 42.0 if evolved_burst else 34.0, 0.36)


func _tick_skill_effects(delta: float) -> void:
	var had_effects := not skill_effects.is_empty()
	for i in range(skill_effects.size() - 1, -1, -1):
		var effect: Dictionary = skill_effects[i]
		effect["time"] = float(effect.get("time", 0.0)) - delta
		if float(effect["time"]) <= 0.0:
			skill_effects.remove_at(i)
		else:
			skill_effects[i] = effect
	if had_effects or not skill_effects.is_empty():
		queue_redraw()


func _draw_skill_effects() -> void:
	for effect in skill_effects:
		var center: Vector2 = effect.get("position", Vector2.ZERO)
		var duration := maxf(0.01, float(effect.get("duration", 0.4)))
		var life := clampf(float(effect.get("time", 0.0)) / duration, 0.0, 1.0)
		var progress := 1.0 - life
		var radius := float(effect.get("radius", 32.0)) * (0.82 + progress * 0.18)
		var kind := str(effect.get("kind", ""))
		match kind:
			"water":
				_draw_water_formation_effect(center, radius, life, progress, false)
			"ice":
				_draw_water_formation_effect(center, radius, life, progress, true)
			"water_splash":
				_draw_water_splash(center, radius, life, progress, false)
			"ice_splash":
				_draw_water_splash(center, radius, life, progress, true)
			"earth":
				draw_arc(center, radius, 0.0, TAU, 48, Color(0.72, 0.61, 0.39, life * 0.8), 3.0)
				draw_arc(center, radius * 0.58, 0.0, TAU, 40, Color(0.54, 0.48, 0.32, life * 0.55), 2.0)
				for i in range(8):
					var angle := TAU * float(i) / 8.0
					draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.76, center + Vector2(cos(angle), sin(angle)) * radius, Color(0.78, 0.68, 0.44, life * 0.7), 2.0)
			"earth_telegraph":
				draw_circle(center, radius * 0.58, Color(0.05, 0.045, 0.035, life * 0.24))
				draw_arc(center, radius * (0.82 + progress * 0.08), 0.0, TAU, 48, Color(0.82, 0.68, 0.42, life * 0.82), 2.4)
				for i in range(7):
					var angle := TAU * float(i) / 7.0
					var direction := Vector2(cos(angle), sin(angle))
					var crack_start := center + direction * radius * 0.18
					var crack_end := center + direction * radius * 0.78
					draw_line(crack_start, crack_end, Color(0.66, 0.54, 0.35, life * 0.82), 2.0, true)
					draw_line(crack_start.lerp(crack_end, 0.55), crack_start.lerp(crack_end, 0.55) + Vector2(-direction.y, direction.x) * radius * 0.12, Color(0.52, 0.45, 0.32, life * 0.72), 1.3, true)
			"earth_spike", "earth_seal":
				draw_circle(center, radius * 0.42, Color(0.04, 0.035, 0.028, life * 0.22))
				draw_arc(center, radius * 0.86, 0.0, TAU, 48, Color(0.72, 0.59, 0.37, life * 0.72), 2.0)
				if kind == "earth_seal":
					var seal_points := PackedVector2Array()
					for seal_index in range(7):
						var seal_angle := TAU * float(seal_index) / 6.0 - PI * 0.5
						seal_points.append(center + Vector2(cos(seal_angle), sin(seal_angle)) * radius * 0.31)
					draw_colored_polygon(PackedVector2Array([seal_points[0], seal_points[1], seal_points[2], seal_points[3], seal_points[4], seal_points[5]]), Color(0.45, 0.34, 0.19, life * 0.24))
					draw_polyline(seal_points, Color(0.91, 0.74, 0.43, life * 0.92), 1.8, true)
					draw_circle(center, radius * 0.12, Color(0.91, 0.74, 0.43, life * 0.65))
				var spike_count := 9 if kind == "earth_seal" else 7
				for i in range(spike_count):
					var angle := TAU * float(i) / float(spike_count) + (0.08 if kind == "earth_seal" else 0.0)
					var direction := Vector2(cos(angle), sin(angle))
					var tangent := Vector2(-direction.y, direction.x)
					var base := center + direction * radius * 0.27
					var width := radius * (0.07 if kind == "earth_seal" else 0.085)
					var left := base - tangent * width
					var right := base + tangent * width
					var tip := center + direction * radius * (0.55 + 0.08 * sin(float(i) * 2.3 + progress * 5.0))
					draw_colored_polygon(PackedVector2Array([left, tip, right]), Color(0.23, 0.22, 0.18, life * 0.95))
					draw_line(left, tip, Color(0.76, 0.63, 0.41, life * 0.82), 1.7, true)
					draw_line(tip, right, Color(0.10, 0.11, 0.10, life * 0.9), 1.7, true)
			"steam":
				draw_circle(center, radius * (0.65 + progress * 0.35), Color(0.82, 0.83, 0.76, life * 0.16))
				draw_arc(center, radius, 0.0, TAU, 40, Color(0.8, 0.82, 0.78, life * 0.4), 1.5)
			"fire":
				var burst_radius := radius * (0.25 + progress * 1.0)
				draw_circle(center, burst_radius * 0.62, Color(0.94, 0.24, 0.06, life * 0.3))
				draw_arc(center, burst_radius, 0.0, TAU, 36, Color(1.0, 0.48, 0.14, life * 0.78), 2.6)
				for i in range(7):
					var angle := TAU * float(i) / 7.0 + progress * 0.42
					var direction := Vector2(cos(angle), sin(angle))
					var tangent := Vector2(-direction.y, direction.x)
					var inner := radius * (0.12 + progress * 0.12)
					var outer := radius * (0.45 + progress * 0.68)
					draw_line(center + direction * inner, center + direction * outer, Color(1.0, 0.72, 0.32, life), 2.2, true)
					var flame_base := center + direction * burst_radius * 0.42
					var flame_tip := center + direction * (burst_radius * 0.42 + radius * (0.14 + 0.12 * sin(progress * 12.0 + float(i))))
					draw_colored_polygon(PackedVector2Array([flame_base - tangent * 4.0, flame_tip, flame_base + tangent * 4.0]), Color(1.0, 0.34, 0.06, life * 0.82))
					draw_line(flame_base, flame_tip, Color(1.0, 0.84, 0.42, life * 0.88), 1.4, true)
			"heavenfire_impact":
				var flame_radius := radius * (0.3 + progress * 0.7)
				draw_circle(center, flame_radius * 0.52, Color(0.8, 0.12, 0.025, life * 0.26))
				draw_arc(center, flame_radius * 0.88, 0.0, TAU, 48, Color(1.0, 0.42, 0.08, life * 0.9), 3.0)
				for i in range(9):
					var angle := TAU * float(i) / 9.0 + progress * 0.25
					var direction := Vector2(cos(angle), sin(angle))
					var tangent := Vector2(-direction.y, direction.x)
					var base := center + direction * flame_radius * 0.42
					var tip := center + direction * flame_radius * (0.78 + 0.14 * sin(elapsed_seconds * 8.0 + float(i)))
					draw_colored_polygon(PackedVector2Array([base - tangent * 4.0, tip, base + tangent * 4.0]), Color(1.0, 0.34, 0.04, life * 0.78))
					draw_line(base, tip, Color(1.0, 0.84, 0.42, life * 0.9), 1.5, true)
			"metal_impact":
				var blade_angle := -0.62 + sin(elapsed_seconds * 24.0) * 0.08
				var blade_direction := Vector2(cos(blade_angle), sin(blade_angle))
				var blade_side := Vector2(-blade_direction.y, blade_direction.x)
				draw_line(center - blade_direction * radius * 0.82, center + blade_direction * radius * 0.82, Color("#f6d98d", life * 0.92), 3.2, true)
				draw_line(center - blade_direction * radius * 0.62 + blade_side * 2.0, center + blade_direction * radius * 0.58 + blade_side * 2.0, Color("#fff2c8", life * 0.8), 1.2, true)
				for spark_index in range(4):
					var spark_angle := TAU * float(spark_index) / 4.0 + elapsed_seconds * 7.0
					var spark_direction := Vector2(cos(spark_angle), sin(spark_angle))
					draw_line(center + spark_direction * radius * 0.24, center + spark_direction * radius * 0.52, Color("#e9bd58", life * 0.82), 1.6, true)
			"slash", "golden_sword_array":
				draw_line(center + Vector2(-radius * 0.75, radius * 0.55), center + Vector2(radius * 0.72, -radius * 0.55), Color(0.98, 0.86, 0.58, life), 3.2)
				draw_line(center + Vector2(-radius * 0.38, radius * 0.72), center + Vector2(radius * 0.48, -radius * 0.25), Color(0.78, 0.63, 0.36, life * 0.75), 1.8)
				if kind == "golden_sword_array":
					draw_line(center + Vector2(-radius * 0.65, -radius * 0.4), center + Vector2(radius * 0.58, radius * 0.35), Color(0.98, 0.78, 0.35, life * 0.9), 2.8)
			"hit":
				draw_circle(center, radius * (0.25 + progress * 0.45), Color(1.0, 0.88, 0.62, life * 0.35))
				draw_arc(center, radius * (0.35 + progress * 0.55), 0.0, TAU, 24, Color(1.0, 0.78, 0.45, life * 0.75), 1.6)
			"boss_slam":
				var slam_radius := radius * (0.18 + progress * 0.82)
				draw_circle(center, slam_radius, Color(0.58, 0.08, 0.06, life * 0.16))
				draw_arc(center, slam_radius, 0.0, TAU, 48, Color(0.92, 0.28, 0.16, life * 0.86), 4.0)
				for i in range(8):
					var angle := TAU * float(i) / 8.0
					draw_line(center + Vector2(cos(angle), sin(angle)) * slam_radius * 0.65, center + Vector2(cos(angle), sin(angle)) * slam_radius, Color(0.92, 0.44, 0.24, life * 0.7), 2.0)
			"boss_zone":
				draw_circle(center, radius, Color(0.72, 0.08, 0.07, life * 0.12))
				draw_arc(center, radius, 0.0, TAU, 48, Color(0.98, 0.22, 0.12, life * 0.9), 3.0)
			"wood":
				draw_arc(center, radius, 0.0, TAU, 40, Color(0.7, 0.73, 0.5, life * 0.7), 2.0)
			"wood_guardian":
				for i in range(3):
					var angle := elapsed_seconds * 2.8 + TAU * float(i) / 3.0
					var direction := Vector2(cos(angle), sin(angle))
					var tangent := Vector2(-direction.y, direction.x)
					var sword_base := center + direction * radius * 0.48
					var sword_tip := center + direction * radius * 0.9
					draw_line(sword_base, sword_tip, Color(0.2, 0.75, 0.43, life * 0.8), 5.0, true)
					draw_line(sword_base, sword_tip, Color(0.8, 1.0, 0.74, life * 0.9), 1.6, true)
					draw_line(sword_base + tangent * 4.0, sword_base - tangent * 4.0, Color(0.62, 0.43, 0.24, life * 0.8), 1.8, true)
			"five_thunder":
				draw_circle(center, radius * 0.54, Color(0.34, 0.1, 0.72, life * 0.2))
				draw_arc(center, radius * 0.92, 0.0, TAU, 56, Color(0.68, 0.4, 1.0, life * 0.88), 2.5)
				draw_arc(center, radius * 0.58, 0.0, TAU, 44, Color(0.9, 0.78, 1.0, life * 0.82), 1.4)
				for i in range(5):
					var angle := TAU * float(i) / 5.0 + elapsed_seconds * 0.18
					var direction := Vector2(cos(angle), sin(angle))
					_draw_lightning_bolt(center + direction * radius * 0.95, center + direction * radius * 0.16, life, elapsed_seconds * 3.0 + float(i) * 1.2)
			"greenwood_guardian":
				draw_arc(center, radius * 0.82, 0.0, TAU, 48, Color(0.24, 0.72, 0.39, life * 0.62), 2.0)
				draw_arc(center, radius * 0.62, 0.0, TAU, 40, Color(0.65, 0.91, 0.54, life * 0.38), 1.2)
				for i in range(4):
					var angle := elapsed_seconds * 2.4 + TAU * float(i) / 4.0
					var direction := Vector2(cos(angle), sin(angle))
					var tangent := Vector2(-direction.y, direction.x)
					var sword_base := center + direction * radius * 0.38
					var sword_tip := center + direction * radius * 0.88
					draw_line(sword_base, sword_tip, Color(0.14, 0.56, 0.31, life * 0.82), 5.0, true)
					draw_line(sword_base, sword_tip, Color(0.8, 1.0, 0.7, life * 0.92), 1.6, true)
					draw_colored_polygon(PackedVector2Array([sword_tip, sword_tip - direction * 8.0 + tangent * 3.0, sword_tip - direction * 8.0 - tangent * 3.0]), Color(0.82, 1.0, 0.65, life * 0.9))
					var leaf_center := center + direction * radius * 0.64 + tangent * 5.0
					draw_colored_polygon(PackedVector2Array([leaf_center - tangent * 3.0, leaf_center + direction * 5.0, leaf_center + tangent * 3.0]), Color(0.36, 0.82, 0.42, life * 0.78))
			"lightning":
				draw_circle(center, radius * 0.58, Color(0.42, 0.14, 0.86, life * 0.25))
				draw_arc(center, radius, 0.0, TAU, 36, Color(0.67, 0.36, 1.0, life * 0.86), 2.5)
				draw_arc(center, radius * 0.56, 0.0, TAU, 28, Color(0.91, 0.78, 1.0, life * 0.82), 1.6)
				_draw_lightning_bolt(center + Vector2(-radius * 0.28, -radius * 1.15), center + Vector2(-radius * 0.06, radius * 0.12), life, 0.7)
				_draw_lightning_bolt(center + Vector2(radius * 0.26, -radius * 1.08), center + Vector2(radius * 0.08, radius * 0.12), life, 2.1)
				_draw_lightning_bolt(center + Vector2(-radius * 0.05, -radius * 0.7), center + Vector2(radius * 0.18, radius * 0.16), life * 0.8, 3.8)
			"lightning_chain", "metal_chain", "wood_chain":
				var chain_start: Vector2 = effect.get("from", center)
				var chain_end: Vector2 = effect.get("to", center)
				if kind == "metal_chain":
					draw_line(chain_start, chain_end, Color(0.82, 0.56, 0.19, life * 0.8), 5.0, true)
					draw_line(chain_start, chain_end, Color(1.0, 0.88, 0.53, life), 1.8, true)
				elif kind == "wood_chain":
					draw_line(chain_start, chain_end, Color(0.14, 0.52, 0.29, life * 0.78), 4.0, true)
					draw_line(chain_start, chain_end, Color(0.72, 0.96, 0.61, life), 1.4, true)
				else:
					_draw_lightning_bolt(chain_start, chain_end, life, progress * 4.0)
					var chain_mid := chain_start.lerp(chain_end, 0.55)
					var chain_side := Vector2(-(chain_end - chain_start).y, (chain_end - chain_start).x).normalized()
					_draw_lightning_bolt(chain_mid, chain_mid + chain_side * minf(20.0, radius * 0.12), life * 0.58, progress * 7.0)
			"talisman_seal", "thunder_seal", "sword_manual", "body_jade", "cold_relic", "formation_seal":
				_draw_artifact_sigil(center, radius, life, kind)
			"cultivation_metal", "cultivation_wood", "cultivation_water", "cultivation_fire", "cultivation_earth", "cultivation_thunder":
				_draw_cultivation_feedback(center, radius, life, kind.trim_prefix("cultivation_"))
			"control":
				draw_arc(center, radius, 0.0, TAU, 64, Color(0.92, 0.76, 0.38, life * 0.85), 3.0)
				draw_arc(center, radius * 0.78, 0.0, TAU, 56, Color(0.74, 0.56, 0.3, life * 0.55), 1.5)

func _draw_artifact_sigil(center: Vector2, radius: float, life: float, kind: String) -> void:
	var gold := Color(0.9, 0.7, 0.35, life * 0.82)
	var pale := Color(1.0, 0.9, 0.62, life * 0.9)
	draw_circle(center, radius * 0.42, Color(0.5, 0.32, 0.12, life * 0.1))
	draw_arc(center, radius * 0.76, 0.0, TAU, 48, gold, 1.8)
	draw_arc(center, radius * 0.54, 0.0, TAU, 40, Color(0.74, 0.55, 0.27, life * 0.58), 1.1)
	var points := PackedVector2Array()
	for i in range(7):
		var angle := TAU * float(i) / 6.0 - PI * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.48)
	draw_polyline(points, gold, 1.2, true)
	match kind:
		"thunder_seal":
			_draw_lightning_bolt(center + Vector2(0.0, -radius * 0.52), center + Vector2(0.0, radius * 0.52), life, elapsed_seconds * 4.0)
		"talisman_seal":
			draw_rect(Rect2(center + Vector2(-radius * 0.15, -radius * 0.42), Vector2(radius * 0.3, radius * 0.84)), gold, false, 1.8)
			draw_line(center + Vector2(0.0, -radius * 0.3), center + Vector2(0.0, radius * 0.3), pale, 1.5, true)
			draw_line(center + Vector2(-radius * 0.1, -radius * 0.05), center + Vector2(radius * 0.1, radius * 0.08), pale, 1.2, true)
		"sword_manual":
			draw_line(center + Vector2(-radius * 0.42, radius * 0.28), center + Vector2(radius * 0.38, -radius * 0.4), pale, 3.0, true)
			draw_line(center + Vector2(-radius * 0.1, radius * 0.42), center + Vector2(radius * 0.46, -radius * 0.12), gold, 1.8, true)
		"body_jade":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -radius * 0.42), center + Vector2(radius * 0.28, 0.0), center + Vector2(0.0, radius * 0.42), center + Vector2(-radius * 0.28, 0.0)]), Color(0.3, 0.72, 0.43, life * 0.26))
			draw_polyline(PackedVector2Array([center + Vector2(0.0, -radius * 0.42), center + Vector2(radius * 0.28, 0.0), center + Vector2(0.0, radius * 0.42), center + Vector2(-radius * 0.28, 0.0), center + Vector2(0.0, -radius * 0.42)]), Color(0.67, 0.95, 0.62, life * 0.92), 1.8, true)
		"cold_relic":
			for i in range(6):
				var angle := TAU * float(i) / 6.0
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(center + direction * radius * 0.12, center + direction * radius * 0.44, pale, 1.5, true)
				var tip := center + direction * radius * 0.5
				var tangent := Vector2(-direction.y, direction.x)
				draw_colored_polygon(PackedVector2Array([tip, tip - direction * 6.0 + tangent * 2.5, tip - direction * 6.0 - tangent * 2.5]), Color(0.65, 0.9, 1.0, life * 0.9))
		"formation_seal":
			for i in range(4):
				var angle := TAU * float(i) / 4.0 + PI * 0.25
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(center, center + direction * radius * 0.42, gold, 1.2, true)
			draw_circle(center, radius * 0.12, pale)


func _draw_cultivation_feedback(center: Vector2, radius: float, life: float, element_id: String) -> void:
	match element_id:
		"metal":
			draw_line(center + Vector2(-radius * 0.7, radius * 0.4), center + Vector2(radius * 0.68, -radius * 0.5), Color(1.0, 0.82, 0.42, life * 0.92), 2.4, true)
			draw_line(center + Vector2(-radius * 0.25, radius * 0.7), center + Vector2(radius * 0.45, radius * 0.08), Color(0.86, 0.66, 0.31, life * 0.72), 1.3, true)
		"wood":
			for i in range(3):
				var angle := TAU * float(i) / 3.0 + elapsed_seconds
				var direction := Vector2(cos(angle), sin(angle))
				var tangent := Vector2(-direction.y, direction.x)
				var leaf_center := center + direction * radius * 0.48
				draw_colored_polygon(PackedVector2Array([leaf_center - tangent * 3.0, leaf_center + direction * 7.0, leaf_center + tangent * 3.0]), Color(0.38, 0.86, 0.47, life * 0.84))
		"water":
			draw_arc(center, radius * 0.68, 0.0, TAU, 32, Color(0.34, 0.82, 1.0, life * 0.78), 1.8)
			for i in range(4):
				var angle := TAU * float(i) / 4.0 + elapsed_seconds * 0.7
				draw_circle(center + Vector2(cos(angle), sin(angle)) * radius * 0.45, 1.8, Color(0.82, 0.97, 1.0, life * 0.9))
		"fire":
			for i in range(5):
				var angle := TAU * float(i) / 5.0 + elapsed_seconds * 0.4
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(center + direction * radius * 0.18, center + direction * radius * 0.58, Color(1.0, 0.52, 0.16, life * 0.9), 1.8, true)
		"earth":
			draw_arc(center, radius * 0.68, 0.0, TAU, 32, Color(0.76, 0.64, 0.42, life * 0.8), 1.6)
			for i in range(4):
				var angle := TAU * float(i) / 4.0
				draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius * 0.58, Color(0.68, 0.56, 0.36, life * 0.85), 1.6, true)
		"thunder":
			_draw_lightning_bolt(center + Vector2(-radius * 0.35, -radius * 0.5), center + Vector2(radius * 0.12, radius * 0.42), life, elapsed_seconds * 3.0)
			draw_arc(center, radius * 0.62, 0.0, TAU, 28, Color(0.7, 0.46, 1.0, life * 0.72), 1.4)



func _draw_water_splash(center: Vector2, radius: float, life: float, progress: float, frozen: bool) -> void:
	var cyan := Color(0.25, 0.82, 1.0, life * 0.82)
	var pale := Color(0.84, 0.97, 1.0, life * 0.92)
	var burst_radius := radius * (0.24 + progress * 0.76)
	draw_circle(center, burst_radius * 0.38, Color(0.04, 0.27, 0.39, life * 0.18))
	draw_arc(center, burst_radius * 0.82, 0.0, TAU, 48, cyan, 2.8)
	draw_arc(center, burst_radius * 0.56, 0.0, TAU, 40, pale, 1.3)
	for i in range(10):
		var angle := TAU * float(i) / 10.0 + progress * 0.18
		var direction := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-direction.y, direction.x)
		var inner := center + direction * burst_radius * 0.42
		var outer := center + direction * burst_radius * (0.82 + 0.12 * sin(progress * 7.0 + float(i)))
		draw_line(inner, outer, cyan, 2.0, true)
		draw_circle(outer, 1.8 if frozen else 1.4, pale)
		if frozen:
			var tip := center + direction * burst_radius * (0.98 + 0.04 * sin(elapsed_seconds * 5.0 + float(i)))
			draw_colored_polygon(PackedVector2Array([outer - tangent * 3.0, tip, outer + tangent * 3.0]), Color(0.69, 0.91, 1.0, life * 0.8))
			draw_line(outer, tip, pale, 1.2, true)



func _draw_water_formation_effect(center: Vector2, radius: float, life: float, progress: float, frozen: bool) -> void:
	var cyan := Color(0.32, 0.82, 1.0, life * 0.82)
	var pale := Color(0.78, 0.95, 1.0, life * 0.92)
	var deep := Color(0.04, 0.22, 0.38, life * 0.2)
	var spin := elapsed_seconds * (-1.15 if frozen else 0.9)
	draw_circle(center, radius * (0.68 + progress * 0.08), deep)
	for ring_index in range(3):
		var ring_radius := radius * (0.96 - float(ring_index) * 0.22)
		var ring_spin := spin * (1.0 if ring_index % 2 == 0 else -0.72)
		draw_arc(center, ring_radius, ring_spin, ring_spin + TAU * 0.86, 72, cyan if ring_index == 0 else Color(0.48, 0.82, 1.0, life * 0.56), 2.8 if ring_index == 0 else 1.5)
	for i in range(12):
		var angle := TAU * float(i) / 12.0 + spin * 0.42
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * radius * 0.76, center + direction * radius * (0.93 if frozen else 0.88), pale, 1.7 if frozen else 1.2, true)
		draw_circle(center + direction * radius * 0.95, 1.6 if frozen else 1.2, cyan)
	for arm in range(2):
		var points := PackedVector2Array()
		for step in range(28):
			var t := float(step) / 27.0
			var angle := spin + float(arm) * PI + t * TAU * 1.55
			var spiral_radius := radius * (0.12 + t * 0.64)
			points.append(center + Vector2(cos(angle), sin(angle)) * spiral_radius)
		draw_polyline(points, Color(0.48, 0.84, 1.0, life * 0.72), 2.4 if frozen else 1.8, true)
	if frozen:
		for i in range(8):
			var angle := TAU * float(i) / 8.0 + progress * 0.24
			var direction := Vector2(cos(angle), sin(angle))
			var tangent := Vector2(-direction.y, direction.x)
			var base := center + direction * radius * 0.78
			var tip := center + direction * radius * (1.02 + 0.04 * sin(elapsed_seconds * 4.0 + float(i)))
			draw_colored_polygon(PackedVector2Array([base - tangent * 4.0, tip, base + tangent * 4.0]), Color(0.66, 0.9, 1.0, life * 0.8))
			draw_line(base, tip, pale, 1.2, true)
	var core_radius := maxf(5.0, radius * 0.12)
	draw_circle(center, core_radius, Color(0.04, 0.13, 0.23, life * 0.92))
	draw_arc(center, core_radius, 0.0, TAU, 36, pale, 1.5)
	draw_circle(center + Vector2(0.0, -core_radius * 0.42), core_radius * 0.42, pale)
	draw_circle(center + Vector2(0.0, core_radius * 0.42), core_radius * 0.42, Color(0.04, 0.13, 0.23, life * 0.95))
	draw_circle(center + Vector2(0.0, -core_radius * 0.42), core_radius * 0.12, Color(0.04, 0.13, 0.23, life))
	draw_circle(center + Vector2(0.0, core_radius * 0.42), core_radius * 0.12, pale)


func _draw_lightning_bolt(start_position: Vector2, end_position: Vector2, alpha: float, seed_offset: float = 0.0) -> void:
	var axis := end_position - start_position
	if axis.length_squared() < 1.0:
		return
	var normal := Vector2(-axis.y, axis.x).normalized()
	var points: Array[Vector2] = [start_position]
	for i in range(1, 6):
		var t := float(i) / 6.0
		var jitter := sin(float(i) * 8.7 + seed_offset + elapsed_seconds * 35.0) * minf(12.0, axis.length() * 0.07)
		points.append(start_position + axis * t + normal * jitter)
	points.append(end_position)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(0.34, 0.10, 0.78, alpha * 0.62), 6.0, true)
		draw_line(points[i], points[i + 1], Color(0.72, 0.46, 1.0, alpha * 0.96), 2.7, true)
		draw_line(points[i], points[i + 1], Color(0.98, 0.95, 1.0, alpha), 1.1, true)


func _draw_fire_zones() -> void:
	for zone in fire_zones:
		var center: Vector2 = zone.get("position", Vector2.ZERO)
		var radius := float(zone.get("radius", 78.0))
		var duration := maxf(0.01, float(zone.get("duration", 3.0)))
		var life := clampf(float(zone.get("time", 0.0)) / duration, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(elapsed_seconds * 7.0)
		draw_circle(center, radius * 0.78, Color(0.72, 0.12, 0.025, 0.12 * life))
		draw_arc(center, radius * (0.9 + pulse * 0.04), 0.0, TAU, 56, Color(1.0, 0.26, 0.035, life * 0.78), 3.0)
		draw_arc(center, radius * 0.64, 0.0, TAU, 48, Color(1.0, 0.52, 0.12, life * 0.48), 1.8)
		for i in range(9):
			var angle := TAU * float(i) / 9.0 + elapsed_seconds * 0.38
			var direction := Vector2(cos(angle), sin(angle))
			var tangent := Vector2(-direction.y, direction.x)
			var base := center + direction * radius * 0.66
			var flame_length := radius * (0.15 + 0.07 * (0.5 + 0.5 * sin(elapsed_seconds * 8.0 + float(i) * 1.9)))
			var tip := base + direction * flame_length
			draw_colored_polygon(PackedVector2Array([base - tangent * 5.0, tip, base + tangent * 5.0]), Color(1.0, 0.30, 0.025, life * 0.68))
			draw_line(base, tip, Color(1.0, 0.78, 0.24, life * 0.9), 1.7, true)
		for i in range(8):
			var rune_angle := TAU * float(i) / 8.0
			var rune_start := center + Vector2(cos(rune_angle), sin(rune_angle)) * radius * 0.48
			var rune_end := center + Vector2(cos(rune_angle), sin(rune_angle)) * radius * 0.55
			draw_line(rune_start, rune_end, Color(1.0, 0.68, 0.2, life * 0.55), 1.6, true)


func cast_active_skill() -> void:
	if state != "playing" or active_skill_cooldown > 0.0:
		return
	active_skill_cooldown = active_skill_base_cooldown
	active_skill_effect_time = ACTIVE_SKILL_EFFECT_DURATION
	player.trigger_cast(player.facing, 0.52)
	var skill_level_bonus := float(active_skill_level - 1)
	var skill_radius := ACTIVE_SKILL_RADIUS + skill_level_bonus * 18.0
	var skill_damage := 8.0 + skill_level_bonus * 4.0
	queue_redraw()
	_spawn_skill_effect("control", player.position, skill_radius, ACTIVE_SKILL_EFFECT_DURATION)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0:
			continue
		if enemy.position.distance_to(player.position) <= skill_radius:
			enemy.apply_slow(2.0 + skill_level_bonus * 0.35, 0.35)
			enemy.take_damage(skill_damage)
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
	# A dedicated illustrated graveyard texture replaces the old flat moss dots and
	# horizontal road. The world remains live: actors, projectiles and effects draw
	# above this background and continue to use their real collision/gameplay logic.
	draw_texture_rect(GRAVEYARD_BACKGROUND, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#080d11", 0.18), false, 8.0)

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

	_draw_skill_effects()
	_draw_fire_zones()

