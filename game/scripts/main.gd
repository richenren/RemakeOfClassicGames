extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
const XP_ORB_SCRIPT = preload("res://scripts/xp_orb.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")

const WORLD_SIZE := Vector2(2400.0, 1600.0)
const MAX_ENEMIES := 100
const BOSS_PHASE_ENEMY_CAP := 18

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
const MAX_AUTO_SKILL_SLOTS := 4
const MAX_ARTIFACT_SLOTS := 3

const AUTO_SKILL_DEFS := {
	"fire_talisman": {"name": "火符", "desc": "自动索敌投射火符，命中附加灼烧", "upgrade_desc": "火符伤害与灼烧效果提升", "damage": 15.0, "cooldown": 1.65},
	"thunder_talisman": {"name": "雷符", "desc": "雷符爆发，可对附近尸群传导", "upgrade_desc": "雷符伤害提升，传导更强", "damage": 22.0, "cooldown": 2.15},
	"copper_coin_sword": {"name": "铜钱剑", "desc": "御使铜钱剑追击敌人，强化贯穿或回旋", "upgrade_desc": "铜钱剑伤害与出手频率提升", "damage": 17.0, "cooldown": 1.8},
	"peachwood_sword": {"name": "桃木剑", "desc": "御剑驱邪，可追击或环身护主", "upgrade_desc": "桃木剑伤害与护身范围提升", "damage": 16.0, "cooldown": 1.9},
	"water_array": {"name": "水阵", "desc": "在敌群脚下展开水阵，造成伤害并施加湿润", "upgrade_desc": "水阵范围、伤害与控制提升", "damage": 10.0, "cooldown": 3.0},
	"earth_formation": {"name": "地脉阵", "desc": "震动地脉压制一片区域，适合群体清场", "upgrade_desc": "地脉阵范围与伤害提升", "damage": 21.0, "cooldown": 2.8}
}

const ARTIFACT_DEFS := {
	"cold_relic": {"name": "寒魄法器", "desc": "强化水/冰控制，并解锁水阵进化", "icon": "cold_relic"},
	"thunder_seal": {"name": "天雷法印", "desc": "强化雷系伤害，并解锁雷符进化", "icon": "thunder_seal"},
	"talisman_scroll": {"name": "符箓秘卷", "desc": "火符与雷符伤害提高 12%", "icon": "talisman_scroll"},
	"sword_manual": {"name": "御剑诀", "desc": "铜钱剑与桃木剑伤害提高 12%", "icon": "sword_manual"},
	"formation_manual": {"name": "阵法真解", "desc": "水阵与地脉阵伤害提高 12%", "icon": "formation_manual"},
	"body_jade": {"name": "护身玉", "desc": "每级受到的接触伤害降低 8%", "icon": "body_jade"}
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

	var camera := Camera2D.new()
	camera.position = Vector2.ZERO
	camera.enabled = true
	# Avoid an initial camera lag that can leave the centered player outside the first frame.
	camera.position_smoothing_enabled = false
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	camera.make_current()
	camera.reset_smoothing()

	# Keep screen-space UI on an explicit layer above the world canvas.
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
		if spawn_timer <= 0.0 and _count_live_ordinary_enemies() < _ordinary_enemy_cap():
			_spawn_wave()
			spawn_timer = _spawn_interval()

		if not boss_spawned and elapsed_seconds >= 480.0:
			boss_spawned = true
			_trim_regular_enemies_for_boss_phase(BOSS_PHASE_ENEMY_CAP)
			spawn_enemy("boss")

		_tick_combat_skills(delta)
		_tick_fire_zones(delta)
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
	var target = _find_combat_target(player.position, 620.0)
	if target == null:
		return

	var projectile = PROJECTILE_SCRIPT.new()
	projectile.setup(target, player.damage)
	projectile.visible = true
	projectile.z_as_relative = false
	projectile.z_index = 30
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
		projectile.tick(delta)
		if projectile.impacted and is_instance_valid(projectile.target) and enemies.has(projectile.target):
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

	# A skill's Lv3 branch is a mandatory two-way decision, not a random generic buff.
	var branchable: Array[String] = []
	for skill_variant in skills.keys():
		var skill_id := str(skill_variant)
		var skill_data: Dictionary = skills[skill_id]
		if int(skill_data.get("level", 1)) == 2 and str(skill_data.get("branch", "")).is_empty():
			branchable.append(skill_id)
	if not branchable.is_empty():
		branchable.shuffle()
		var branch_skill := branchable[0]
		for branch_data in SKILL_BRANCHES.get(branch_skill, []):
			level_cards.append(_branch_card(branch_skill, branch_data))
		_fill_level_cards(_collect_core_candidates(), _collect_general_candidates(), 3)
		state = "level_up"
		return

	# Evolution is offered explicitly once its skill and matching artifact are both ready.
	var evolutions := _collect_evolution_candidates()
	if not evolutions.is_empty():
		evolutions.shuffle()
		level_cards.append(evolutions[0])
	_fill_level_cards(_collect_core_candidates(), _collect_general_candidates(), 3)
	state = "level_up"


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
			if skill_level < 5 and not branch_pending:
				skill_upgrades.append(_skill_card(skill_id, "skill_level"))
		elif skills.size() < MAX_AUTO_SKILL_SLOTS:
			skill_acquisitions.append(_skill_card(skill_id, "skill_acquire"))

	for artifact_variant in ARTIFACT_DEFS.keys():
		var artifact_id := str(artifact_variant)
		if artifacts.has(artifact_id):
			var artifact_data: Dictionary = artifacts[artifact_id]
			if int(artifact_data.get("level", 1)) < 3:
				artifact_candidates.append(_artifact_card(artifact_id, "artifact_level"))
		elif artifacts.size() < MAX_ARTIFACT_SLOTS:
			artifact_candidates.append(_artifact_card(artifact_id, "artifact_acquire"))

	var result: Array[Dictionary] = []
	# Prevent the first several level-ups from being consumed entirely by generic stats.
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

	# Active-art upgrade is deliberately lower-weight than acquiring or improving a build skill.
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
	if skills.has("water_array") and artifacts.has("cold_relic"):
		var water_data: Dictionary = skills["water_array"]
		if int(water_data.get("level", 1)) >= 5 and str(water_data.get("evolved", "")).is_empty():
			result.append({"id": "evolve_ice_array", "kind": "skill_evolution", "skill_id": "water_array", "evolution_id": "ice_array", "name": "冰魄阵", "desc": "水阵进化为冰魄阵，强化范围控制与冻结", "category": "技能进化", "icon": "ice_array"})
	if skills.has("thunder_talisman") and artifacts.has("thunder_seal"):
		var thunder_data: Dictionary = skills["thunder_talisman"]
		if int(thunder_data.get("level", 1)) >= 5 and str(thunder_data.get("evolved", "")).is_empty():
			result.append({"id": "evolve_five_thunder", "kind": "skill_evolution", "skill_id": "thunder_talisman", "evolution_id": "five_thunder", "name": "五雷敕令", "desc": "雷符进化为五雷敕令，强化爆发与连锁清场", "category": "技能进化", "icon": "five_thunder"})
	return result


func _skill_card(skill_id: String, card_kind: String) -> Dictionary:
	var definition: Dictionary = AUTO_SKILL_DEFS[skill_id]
	var card_name := str(definition["name"])
	var description := str(definition["desc"])
	var card_id := "acquire_" + skill_id
	if card_kind == "skill_level":
		var current_data: Dictionary = skills[skill_id]
		card_id = "upgrade_" + skill_id
		card_name += "精进 · Lv%d" % (int(current_data.get("level", 1)) + 1)
		description = str(definition["upgrade_desc"])
	return {"id": card_id, "kind": card_kind, "skill_id": skill_id, "name": card_name, "desc": description, "category": "攻击技能" if card_kind == "skill_acquire" else "技能精进", "icon": skill_id}


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
			if not acquisitions.is_empty() and not _has_new_skill_acquisition():
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


func _has_new_skill_acquisition() -> bool:
	for card in level_cards:
		if str(card.get("kind", "")) == "skill_acquire":
			return true
	return false


func _upgrade_weight(card: Dictionary) -> float:
	match str(card.get("kind", "")):
		"skill_level":
			return 5.0
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
	_apply_upgrade(upgrade)
	state = "playing"
	_maybe_level_up()


func _apply_upgrade(upgrade: Dictionary) -> void:
	var kind := str(upgrade.get("kind", ""))
	var skill_id := str(upgrade.get("skill_id", ""))
	var artifact_id := str(upgrade.get("artifact_id", ""))
	match kind:
		"skill_acquire":
			skills[skill_id] = {"level": 1, "branch": "", "evolved": ""}
			skill_cooldowns[skill_id] = 0.0
		"skill_level":
			var skill_data: Dictionary = skills[skill_id]
			skill_data["level"] = mini(5, int(skill_data.get("level", 1)) + 1)
			skills[skill_id] = skill_data
		"skill_branch":
			var branch_skill: Dictionary = skills[skill_id]
			branch_skill["level"] = 3
			branch_skill["branch"] = str(upgrade.get("branch_id", ""))
			skills[skill_id] = branch_skill
		"skill_evolution":
			var evolution_skill: Dictionary = skills[skill_id]
			evolution_skill["evolved"] = str(upgrade.get("evolution_id", ""))
			skills[skill_id] = evolution_skill
			_spawn_skill_effect("ice" if str(upgrade.get("evolution_id", "")) == "ice_array" else "lightning", player.position, 115.0, 0.55)
		"artifact_acquire":
			artifacts[artifact_id] = {"level": 1}
		"artifact_level":
			var artifact_data: Dictionary = artifacts[artifact_id]
			artifact_data["level"] = mini(3, int(artifact_data.get("level", 1)) + 1)
			artifacts[artifact_id] = artifact_data
		"general_upgrade":
			var general_id := str(upgrade.get("target_id", ""))
			var new_level := int(general_upgrade_levels.get(general_id, 0)) + 1
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
			active_skill_level = mini(3, active_skill_level + 1)
			active_skill_base_cooldown = maxf(8.0, active_skill_base_cooldown * 0.92)


func _artifact_level(artifact_id: String) -> int:
	if not artifacts.has(artifact_id):
		return 0
	var data: Dictionary = artifacts[artifact_id]
	return int(data.get("level", 1))


func _skill_damage(skill_id: String, base_damage: float) -> float:
	var skill_data: Dictionary = skills.get(skill_id, {})
	var skill_level := int(skill_data.get("level", 1))
	var multiplier := 1.0 + float(skill_level - 1) * 0.18
	if _artifact_level("talisman_scroll") > 0 and skill_id in ["fire_talisman", "thunder_talisman"]:
		multiplier *= 1.0 + 0.12 * float(_artifact_level("talisman_scroll"))
	if _artifact_level("thunder_seal") > 0 and skill_id == "thunder_talisman":
		multiplier *= 1.0 + 0.15 * float(_artifact_level("thunder_seal"))
	if _artifact_level("cold_relic") > 0 and skill_id == "water_array":
		multiplier *= 1.0 + 0.12 * float(_artifact_level("cold_relic"))
	if _artifact_level("sword_manual") > 0 and skill_id in ["copper_coin_sword", "peachwood_sword"]:
		multiplier *= 1.0 + 0.12 * float(_artifact_level("sword_manual"))
	if _artifact_level("formation_manual") > 0 and skill_id in ["water_array", "earth_formation"]:
		multiplier *= 1.0 + 0.12 * float(_artifact_level("formation_manual"))
	var evolved := str(skill_data.get("evolved", ""))
	if evolved == "ice_array" or evolved == "five_thunder":
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


func _spawn_skill_projectile(target, skill_id: String, damage: float) -> void:
	var projectile = PROJECTILE_SCRIPT.new()
	projectile.setup(target, damage, skill_id)
	projectile.visible = true
	projectile.z_as_relative = false
	projectile.z_index = 30
	var direction: Vector2 = (target.position - player.position).normalized()
	player.facing = direction
	projectile.position = player.position + direction * 18.0
	add_child(projectile)
	projectiles.append(projectile)
	player.queue_redraw()


func _tick_combat_skills(delta: float) -> void:
	for skill_variant in skills.keys():
		var skill_id := str(skill_variant)
		skill_cooldowns[skill_id] = maxf(0.0, float(skill_cooldowns.get(skill_id, 0.0)) - delta)
		if float(skill_cooldowns[skill_id]) > 0.0:
			continue
		var target = _find_combat_target(player.position, 700.0)
		if target == null:
			skill_cooldowns[skill_id] = 0.25
			continue
		_cast_auto_skill(skill_id, target)


func _cast_auto_skill(skill_id: String, target) -> void:
	var skill_data: Dictionary = skills[skill_id]
	var skill_level := int(skill_data.get("level", 1))
	var branch := str(skill_data.get("branch", ""))
	var evolved := str(skill_data.get("evolved", ""))
	var definition: Dictionary = AUTO_SKILL_DEFS[skill_id]
	var damage := _skill_damage(skill_id, float(definition["damage"]))
	var cooldown := _skill_cooldown(skill_id, float(definition["cooldown"]))

	match skill_id:
		"fire_talisman":
			var target_count := 2 if branch == "spread" else 1
			var targets := _find_nearest_targets(player.position, 700.0, target_count)
			for i in range(targets.size()):
				_spawn_skill_projectile(targets[i], skill_id, damage * (0.78 if i > 0 else 1.0))
			if branch == "spread":
				cooldown *= 1.12
		"thunder_talisman":
			if branch == "heaven":
				damage *= 1.8
				cooldown *= 1.38
			_spawn_skill_projectile(target, skill_id, damage)
		"copper_coin_sword":
			_spawn_skill_projectile(target, skill_id, damage)
		"peachwood_sword":
			if branch == "guardian":
				var guardian_radius := 52.0 + float(skill_level) * 7.0
				_apply_area_damage(player.position, guardian_radius, damage * 0.72, "wood", 0.0, false, 20.0)
			else:
				_spawn_skill_projectile(target, skill_id, damage)
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
			_apply_area_damage(target.position, water_radius, damage, "ice" if evolved == "ice_array" else "water", slow_duration, true, 0.0)
		"earth_formation":
			var earth_radius := 66.0 + float(skill_level) * 8.0
			var knockback := 0.0
			if branch == "mountain":
				earth_radius += 16.0
				knockback = 22.0
			if branch == "earthspike":
				damage *= 1.6
			_apply_area_damage(target.position, earth_radius, damage, "earth", 0.0, false, knockback)

	skill_cooldowns[skill_id] = cooldown


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
	var target = projectile.target
	if not is_instance_valid(target):
		return
	var skill_id := str(projectile.skill_id)
	var damage := float(projectile.damage)
	var skill_data: Dictionary = skills.get(skill_id, {})
	var branch := str(skill_data.get("branch", ""))
	var evolved := str(skill_data.get("evolved", ""))

	match skill_id:
		"fire_talisman":
			target.take_damage(damage)
			if target.wet_timer > 0.0:
				target.wet_timer = 0.0
				_apply_area_damage(target.position, 44.0, damage * 0.35, "steam")
			elif branch == "flame":
				target.apply_burn(2.8, 2.8 + float(skill_data.get("level", 1)) * 0.55)
			else:
				target.apply_burn(1.35, 1.7)
			_spawn_skill_effect("fire", target.position, 22.0, 0.22)
		"thunder_talisman":
			var was_wet: bool = target.wet_timer > 0.0
			target.take_damage(damage * (1.35 if was_wet else 1.0))
			if was_wet:
				target.wet_timer = 0.0
			var chain_count := 0
			if branch == "chain":
				chain_count = 3
			if evolved == "five_thunder":
				chain_count = 4
			if was_wet:
				chain_count += 1
			if branch == "heaven" and evolved != "five_thunder":
				chain_count = 0
			_apply_chain_damage(target, damage * 0.58, chain_count)
			_spawn_skill_effect("lightning", target.position, 32.0, 0.25)
		"copper_coin_sword":
			target.take_damage(damage)
			_spawn_skill_effect("slash", target.position, 25.0, 0.18)
			if branch == "pierce":
				_apply_chain_damage(target, damage * 0.52, 2)
			elif branch == "return":
				target.take_damage(damage * 0.55)
				_spawn_skill_effect("wood", target.position, 25.0, 0.22)
		"peachwood_sword":
			target.take_damage(damage)
			if branch == "chase":
				_apply_chain_damage(target, damage * 0.52, 1)
			_spawn_skill_effect("wood", target.position, 18.0, 0.2)
		_:
			target.take_damage(damage)
			_spawn_skill_effect("hit", target.position, 18.0, 0.16)


func _apply_chain_damage(origin_enemy, damage: float, max_targets: int) -> void:
	if max_targets <= 0 or not is_instance_valid(origin_enemy):
		return
	var hit_targets: Array = [origin_enemy]
	for i in range(max_targets):
		var next_target = _find_nearest_enemy(origin_enemy.position, 190.0, hit_targets)
		if next_target == null:
			break
		next_target.take_damage(damage)
		hit_targets.append(next_target)
		_spawn_chain_effect(origin_enemy.position, next_target.position, 0.26)
		_spawn_skill_effect("lightning", next_target.position, 28.0, 0.24)


func _spawn_skill_effect(effect_kind: String, center: Vector2, radius: float, duration: float) -> void:
	# Cap transient particles so dense late-game combat cannot grow the effect list without bound.
	if skill_effects.size() >= 80:
		skill_effects.remove_at(0)
	skill_effects.append({"kind": effect_kind, "position": center, "radius": radius, "time": duration, "duration": duration})
	queue_redraw()


func _spawn_chain_effect(start_position: Vector2, end_position: Vector2, duration: float = 0.26) -> void:
	if skill_effects.size() >= 80:
		skill_effects.remove_at(0)
	skill_effects.append({
		"kind": "lightning_chain",
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
			var target = _find_combat_target(player.position, 620.0)
			if target != null:
				var skill_data: Dictionary = skills["fire_talisman"]
				var level := int(skill_data.get("level", 1))
				var radius := 78.0 + float(level - 1) * 7.0
				var duration := 3.0
				fire_zones.append({
					"position": target.position,
					"radius": radius,
					"time": duration,
					"duration": duration,
					"tick_timer": 0.25,
					"damage": 2.8 + float(level) * 0.9
				})
				if fire_zones.size() > 4:
					fire_zones.remove_at(0)
				_spawn_skill_effect("fire", target.position, 34.0, 0.32)
				fire_zone_timer = maxf(3.8, 5.0 - float(level - 1) * 0.22)
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
				draw_arc(center, radius, 0.0, TAU, 56, Color(0.34, 0.72, 0.82, life * 0.72), 3.0)
				draw_arc(center, radius * 0.68, 0.0, TAU, 48, Color(0.45, 0.82, 0.88, life * 0.48), 2.0)
			"ice":
				draw_arc(center, radius, 0.0, TAU, 56, Color(0.56, 0.82, 0.94, life * 0.86), 3.0)
				for i in range(6):
					var angle := TAU * float(i) / 6.0
					draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.72, center + Vector2(cos(angle), sin(angle)) * radius, Color(0.72, 0.9, 1.0, life * 0.8), 2.0)
			"earth":
				draw_arc(center, radius, 0.0, TAU, 48, Color(0.72, 0.61, 0.39, life * 0.8), 3.0)
				draw_arc(center, radius * 0.58, 0.0, TAU, 40, Color(0.54, 0.48, 0.32, life * 0.55), 2.0)
				for i in range(8):
					var angle := TAU * float(i) / 8.0
					draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.76, center + Vector2(cos(angle), sin(angle)) * radius, Color(0.78, 0.68, 0.44, life * 0.7), 2.0)
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
			"slash":
				draw_line(center + Vector2(-radius * 0.75, radius * 0.55), center + Vector2(radius * 0.72, -radius * 0.55), Color(0.98, 0.86, 0.58, life), 3.2)
				draw_line(center + Vector2(-radius * 0.38, radius * 0.72), center + Vector2(radius * 0.48, -radius * 0.25), Color(0.78, 0.63, 0.36, life * 0.75), 1.8)
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
			"lightning":
				draw_circle(center, radius * 0.58, Color(0.32, 0.42, 1.0, life * 0.22))
				draw_arc(center, radius, 0.0, TAU, 36, Color(0.52, 0.62, 1.0, life * 0.82), 2.2)
				draw_arc(center, radius * 0.56, 0.0, TAU, 28, Color(0.83, 0.92, 1.0, life * 0.74), 1.5)
				_draw_lightning_bolt(center + Vector2(-radius * 0.28, -radius * 1.15), center + Vector2(-radius * 0.06, radius * 0.12), life, 0.7)
				_draw_lightning_bolt(center + Vector2(radius * 0.26, -radius * 1.08), center + Vector2(radius * 0.08, radius * 0.12), life, 2.1)
				_draw_lightning_bolt(center + Vector2(-radius * 0.05, -radius * 0.7), center + Vector2(radius * 0.18, radius * 0.16), life * 0.8, 3.8)
			"lightning_chain":
				var chain_start: Vector2 = effect.get("from", center)
				var chain_end: Vector2 = effect.get("to", center)
				_draw_lightning_bolt(chain_start, chain_end, life, progress * 4.0)
				var chain_mid := chain_start.lerp(chain_end, 0.55)
				var chain_side := Vector2(-(chain_end - chain_start).y, (chain_end - chain_start).x).normalized()
				_draw_lightning_bolt(chain_mid, chain_mid + chain_side * minf(20.0, radius * 0.12), life * 0.58, progress * 7.0)
			"control":
				draw_arc(center, radius, 0.0, TAU, 64, Color(0.92, 0.76, 0.38, life * 0.85), 3.0)
				draw_arc(center, radius * 0.78, 0.0, TAU, 56, Color(0.74, 0.56, 0.3, life * 0.55), 1.5)


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
		draw_line(points[i], points[i + 1], Color(0.30, 0.38, 1.0, alpha * 0.56), 6.0, true)
		draw_line(points[i], points[i + 1], Color(0.58, 0.78, 1.0, alpha * 0.94), 2.7, true)
		draw_line(points[i], points[i + 1], Color(0.96, 0.99, 1.0, alpha), 1.0, true)


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
		draw_line(p + Vector2(-4.0, -4.0), p + Vector2(4.0, -4.0), Color(0.545, 0.49, 0.36, 0.72), 1.2)
		draw_line(p + Vector2(-3.0, 1.0), p + Vector2(3.0, 1.0), Color(0.545, 0.49, 0.36, 0.52), 1.0)

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

	_draw_skill_effects()
	_draw_fire_zones()
