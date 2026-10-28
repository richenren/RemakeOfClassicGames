extends SceneTree

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const XP_ORB_SCRIPT = preload("res://scripts/xp_orb.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const MAIN_SCENE = preload("res://scenes/main.tscn")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=== 镇邪录 Godot 原型自动化测试 ===")
	_test_player()
	_test_enemy_variants()
	_test_xp_orb()
	_test_end_screen_layout()
	_test_skill_art_assets()

	var main: Variant = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	_check(main.player != null, "主场景创建玩家")
	_check(main.enemies.size() == 7, "开局生成 7 个普通敌人")
	_test_camera_follow(main)
	_test_render_hierarchy(main)
	_test_hud_presentation(main)
	_test_sprite_assets(main)
	_test_skill_build_system(main)

	if main.player != null and not main.enemies.is_empty():
		_test_combat_and_progression(main)
	_test_combat_visuals(main)

	main.queue_free()
	await process_frame
	print("=== 测试汇总：%d 通过，%d 失败 ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_camera_follow(main: Variant) -> void:
	var camera := main.get_node_or_null("GameplayCamera") as Camera2D
	_check(camera != null, "主场景创建独立 GameplayCamera")
	if camera == null or main.player == null:
		return
	_check(main.get_viewport().get_camera_2d() == camera, "GameplayCamera 成为当前活动相机")
	_check(camera.global_position.is_equal_approx(main.player.global_position), "启动时相机中心对准主角")
	var original_position: Vector2 = main.player.position
	main.player.position = original_position + Vector2(25.0, 10.0)
	main._process(0.0)
	_check(camera.global_position.is_equal_approx(main.player.global_position), "主角移动后相机同步跟随")
	main.player.position = original_position
	main._process(0.0)


func _test_render_hierarchy(main: Variant) -> void:
	_check(main.player.visible and main.player.z_index >= 20, "主角位于背景上方且可见")
	_check(not main.player.z_as_relative, "主角使用明确的世界绘制层级")
	if not main.enemies.is_empty():
		_check(main.enemies[0].visible and main.enemies[0].z_index >= 20, "怪物位于背景上方且可见")
	var canvas_layer := main.hud.get_parent() as CanvasLayer
	_check(canvas_layer != null, "HUD 挂载在 CanvasLayer 上")
	if canvas_layer != null:
		_check(canvas_layer.layer >= 10 and not canvas_layer.follow_viewport_enabled, "HUD 使用独立屏幕空间图层")
	_check(main.hud.visible and main.hud.z_index >= 100, "HUD 可见且位于 UI 图层前景")


func _test_hud_presentation(main: Variant) -> void:
	var hud: Variant = main.hud
	var objective: Dictionary = hud.objective_data()
	_check(objective.get("title", "").contains("镇压尸潮"), "战斗 HUD 显示当前阶段目标")
	_check(objective.get("detail", "").contains("倒计时"), "战斗 HUD 显示尸王登场倒计时")
	_check(float(objective.get("progress", -1.0)) >= 0.0 and float(objective.get("progress", 2.0)) <= 1.0, "任务进度条比例限制在 0 到 1")
	_check(hud._upgrade_category("fire_talisman") == "攻击技能", "攻击技能卡显示正确类别")
	_check(hud._upgrade_category("general_swift_step") == "通用强化", "通用强化卡显示正确类别")
	_check(hud._upgrade_category("active_skill_upgrade") == "主动道术", "主动道术升级卡显示正确类别")


func _test_sprite_assets(main: Variant) -> void:
	var player_idle := load("res://assets/sprites/player_taoist.svg") as Texture2D
	var player_walk := load("res://assets/sprites/player_taoist_walk.svg") as Texture2D
	var walker := load("res://assets/sprites/enemy_walker.svg") as Texture2D
	var walker_walk := load("res://assets/sprites/enemy_walker_walk.svg") as Texture2D
	var jumper := load("res://assets/sprites/enemy_jumper.svg") as Texture2D
	var armored := load("res://assets/sprites/enemy_armored.svg") as Texture2D
	var boss := load("res://assets/sprites/enemy_boss.svg") as Texture2D
	var boss_phase2 := load("res://assets/sprites/enemy_boss_phase2.svg") as Texture2D
	_check(player_idle != null and player_walk != null, "道士待机与行走高清透明 SVG 可加载")
	_check(walker != null and walker_walk != null and jumper != null and armored != null, "三类僵尸独立美术资源可加载")
	_check(boss != null and boss_phase2 != null, "尸王一阶段与二阶段独立美术资源可加载")
	if player_idle != null:
		_check(player_idle.get_size() == Vector2(128.0, 160.0), "道士资源采用 128×160 高清角色画布")
	if boss != null:
		_check(boss.get_size() == Vector2(192.0, 224.0), "尸王资源使用更大画布以保证面部与服饰细节")
	_check(main.player.is_moving == false, "玩家初始使用待机贴图状态")


func _test_skill_build_system(main: Variant) -> void:
	_check(main.AUTO_SKILL_DEFS.size() == 6, "首版配置六种自动攻击技能")
	_check(main.ARTIFACT_DEFS.size() == 6, "首版配置六种被动法器")
	_check(main.GENERAL_UPGRADE_DEFS.size() == 4, "通用强化池只包含四项设计内容")
	_check(main._ordinary_enemy_cap() == 24, "前期尸潮存在明确存活上限")
	main.elapsed_seconds = 400.0
	_check(main._ordinary_enemy_cap() == 46, "中后期尸潮压力按阶段提升")
	main.elapsed_seconds = 0.0

	main._open_upgrade_choices()
	var skill_card_index := -1
	var general_count := 0
	for i in range(main.level_cards.size()):
		var card: Dictionary = main.level_cards[i]
		if str(card.get("kind", "")) == "skill_acquire":
			skill_card_index = i
		if str(card.get("kind", "")) == "general_upgrade":
			general_count += 1
	_check(skill_card_index >= 0, "早期升级候选优先提供正式攻击技能")
	_check(general_count <= 1, "每次升级最多出现一张通用强化卡")
	if skill_card_index >= 0:
		main._select_upgrade(skill_card_index)
	_check(main.skills.size() == 1, "选择攻击技能后正式技能进入构筑")
	main.skills.clear()
	main.skill_cooldowns.clear()
	main.level_cards.clear()
	main.state = "playing"

	main.skills["fire_talisman"] = {"level": 2, "branch": "", "evolved": ""}
	main._open_upgrade_choices()
	var branch_count := 0
	for card in main.level_cards:
		if str(card.get("kind", "")) == "skill_branch" and str(card.get("skill_id", "")) == "fire_talisman":
			branch_count += 1
	_check(branch_count == 2, "技能达到 Lv3 时同时提供两个关键分支")
	main.skills.clear()
	main.level_cards.clear()
	main.state = "playing"

	main.skills["water_array"] = {"level": 5, "branch": "cold", "evolved": ""}
	main.artifacts["cold_relic"] = {"level": 1}
	var evolutions: Array[Dictionary] = main._collect_evolution_candidates()
	var has_ice_evolution := false
	for card in evolutions:
		if str(card.get("evolution_id", "")) == "ice_array":
			has_ice_evolution = true
	_check(has_ice_evolution, "水阵 Lv5 持有寒魄法器时解锁冰魄阵进化")
	main.skills.clear()
	main.artifacts.clear()
	main.skills["thunder_talisman"] = {"level": 5, "branch": "chain", "evolved": ""}
	main.artifacts["thunder_seal"] = {"level": 1}
	var thunder_evolutions: Array[Dictionary] = main._collect_evolution_candidates()
	var has_five_thunder := false
	for card in thunder_evolutions:
		if str(card.get("evolution_id", "")) == "five_thunder":
			has_five_thunder = true
	_check(has_five_thunder, "雷符 Lv5 持有天雷法印时解锁五雷敕令进化")
	main.skills.clear()
	main.artifacts.clear()
	main.level_cards.clear()
	main.state = "playing"

	if not main.enemies.is_empty():
		var target: Variant = main.enemies[0]
		target.position = main.player.position + Vector2(100.0, 0.0)
		var projectile_skills: Array[String] = ["fire_talisman", "thunder_talisman", "copper_coin_sword", "peachwood_sword"]
		for skill_variant in main.AUTO_SKILL_DEFS.keys():
			var skill_id := str(skill_variant)
			main.skills.clear()
			main.skill_cooldowns.clear()
			main.skills[skill_id] = {"level": 1, "branch": "", "evolved": ""}
			target.hp = target.max_hp
			var projectile_count: int = int(main.projectiles.size())
			var hp_before: float = target.hp
			main._cast_auto_skill(skill_id, target)
			if skill_id in projectile_skills:
				_check(main.projectiles.size() > projectile_count, "%s 会发射独立技能投射物" % str(main.AUTO_SKILL_DEFS[skill_id]["name"]))
			else:
				_check(target.hp < hp_before, "%s 会对范围内敌人造成伤害" % str(main.AUTO_SKILL_DEFS[skill_id]["name"]))
			for projectile in main.projectiles:
				projectile.queue_free()
			main.projectiles.clear()
		main.skills.clear()
		main.skill_cooldowns.clear()


func _test_skill_art_assets() -> void:
	var atlas := load("res://assets/sprites/skill_art_atlas.svg") as Texture2D
	_check(atlas != null, "国风技能插画图集可加载")
	if atlas != null:
		_check(atlas.get_size() == Vector2(768.0, 128.0), "六种技能插画共享 768×128 图集")
	var hud: Variant = HUD_SCRIPT.new()
	root.add_child(hud)
	_check(hud._skill_art_region("fire_talisman").position.x == 0.0, "火符使用专属插画帧")
	_check(hud._skill_art_region("thunder_talisman").position.x == 128.0, "雷符使用专属插画帧")
	_check(hud._skill_art_region("copper_coin_sword").position.x == 256.0, "铜钱剑使用独立武器插画帧")
	_check(hud._skill_art_region("peachwood_sword").position.x == 384.0, "桃木剑使用独立武器插画帧")
	_check(hud._skill_art_region("water_array").position.x == 512.0, "水阵使用专属插画帧")
	_check(hud._skill_art_region("earth_formation").position.x == 640.0, "地脉阵使用专属插画帧")
	_check(hud.has_method("_center_text") and hud.has_method("_draw_wrapped_text"), "升级卡支持居中标题与多行技能说明")
	hud.queue_free()


func _test_end_screen_layout() -> void:
	var hud: Variant = HUD_SCRIPT.new()
	root.add_child(hud)
	var view := Vector2(1280.0, 720.0)
	var panel: Rect2 = hud.end_panel_rect(view)
	_check(panel.has_point(Vector2(view.x * 0.5 - 150.0, view.y * 0.5 - 65.0)), "结算面板覆盖标题区域")
	_check(panel.has_point(Vector2(view.x * 0.5 - 145.0, view.y * 0.5 - 20.0)), "结算面板覆盖统计文字区域")
	_check(panel.has_point(Vector2(view.x * 0.5 - 120.0, view.y * 0.5 + 28.0)), "结算面板覆盖重新开始提示区域")
	hud.queue_free()


func _test_player() -> void:
	var player: Variant = PLAYER_SCRIPT.new()
	root.add_child(player)
	player.position = Vector2(100.0, 100.0)
	player.mobile_move = Vector2.RIGHT
	player.tick(0.1)
	_check(player.position.x > 100.0, "玩家触屏移动输入可驱动位移")
	_check(player.is_moving, "玩家移动时切换为移动贴图状态")
	_check(player.gait_phase > 0.0, "玩家移动时更新步态动画相位")

	player.hp = 100.0
	player.invuln_time = 0.0
	player.take_damage(20.0)
	_check(is_equal_approx(player.hp, 80.0), "玩家受伤正确扣除生命")
	player.take_damage(20.0)
	_check(is_equal_approx(player.hp, 80.0), "受击无敌窗口阻止连续伤害")
	player.heal(50.0)
	_check(is_equal_approx(player.hp, 100.0), "治疗不会超过最大生命")
	player.queue_free()


func _test_enemy_variants() -> void:
	var walker: Variant = ENEMY_SCRIPT.new()
	root.add_child(walker)
	walker.setup("walker")
	_check(is_equal_approx(walker.max_hp, 34.0), "行尸基础属性正确")
	var old_x: float = walker.position.x
	walker.tick(0.5, Vector2(100.0, 0.0), Vector2.ZERO)
	_check(walker.position.x > old_x, "普通敌人会追踪玩家")
	_check(walker.gait_phase > 0.0, "普通敌人追踪时更新步态动画")
	_check(walker.footstep_flash > 0.0, "普通敌人移动时产生交替步态反馈")
	walker.queue_free()

	var jumper: Variant = ENEMY_SCRIPT.new()
	root.add_child(jumper)
	jumper.setup("jumper")
	_check(jumper.move_speed > 100.0 and jumper.contact_damage == 10.0, "跳僵具备独立速度和伤害")
	jumper.queue_free()

	var armored: Variant = ENEMY_SCRIPT.new()
	root.add_child(armored)
	armored.setup("armored")
	_check(armored.max_hp > 2.0 * 34.0, "铁甲尸具有更高生命值")
	armored.queue_free()

	var boss: Variant = ENEMY_SCRIPT.new()
	root.add_child(boss)
	boss.setup("boss")
	boss.apply_slow(2.0, 0.35)
	_check(boss.is_boss and boss.max_hp >= 1000.0, "尸王具备 Boss 标识和独立生命值")
	_check(is_equal_approx(boss.slow_multiplier, 0.72), "Boss 对减速效果具有抗性")
	_check(is_equal_approx(boss.slow_timer, 0.7), "Boss 减速持续时间受到抗性缩短")
	boss.hp = boss.max_hp * 0.5
	boss.tick(0.016, Vector2(180.0, 0.0), Vector2.ZERO)
	_check(boss.boss_phase == 2 and boss.boss_action == "phase_shift", "尸王生命降至一半后进入暴走转阶段")
	boss.boss_phase = 1
	boss.hp = boss.max_hp
	boss.boss_action = "slam_windup"
	boss.boss_action_timer = 0.01
	boss.tick(0.02, Vector2(180.0, 0.0), Vector2.ZERO)
	_check(boss.boss_attack_event == "slam", "尸王震地预警结束后触发攻击事件")
	boss.queue_free()


func _test_xp_orb() -> void:
	var orb: Variant = XP_ORB_SCRIPT.new()
	root.add_child(orb)
	orb.setup(1)
	orb.position = Vector2.ZERO
	_check(orb.tick(0.016, Vector2.ZERO, 92.0), "玩家接触灵气球时可拾取")
	orb.queue_free()


func _test_combat_visuals(main: Variant) -> void:
	var temp_enemy: Variant = ENEMY_SCRIPT.new()
	temp_enemy.setup("walker")
	temp_enemy.position = main.player.position + Vector2(50.0, 0.0)
	main.add_child(temp_enemy)
	main.enemies.append(temp_enemy)
	main.skills.clear()
	main.skills["fire_talisman"] = {"level": 1, "branch": "", "evolved": ""}
	main.fire_zone_timer = 0.01
	main.fire_zones.clear()
	main._tick_fire_zones(0.02)
	_check(main.fire_zones.size() == 1, "火符按固定间隔自动生成持续火焰区域")
	var hp_before: float = temp_enemy.hp
	main._tick_fire_zones(0.3)
	_check(temp_enemy.hp < hp_before, "持续火焰区域周期性灼烧范围内敌人")
	main._spawn_chain_effect(Vector2.ZERO, Vector2(80.0, 0.0), 0.24)
	_check(str(main.skill_effects.back().get("kind", "")) == "lightning_chain", "雷符连锁伤害会生成可见的连接闪电")
	main.fire_zones.clear()
	main.skill_effects.clear()
	main.skills.clear()
	main.enemies.erase(temp_enemy)
	temp_enemy.queue_free()


func _test_combat_and_progression(main: Variant) -> void:
	var player: Variant = main.player
	var target: Variant = main.enemies[0]
	target.position = player.position + Vector2(100.0, 0.0)
	target.hp = target.max_hp

	main._auto_attack()
	_check(main.projectiles.size() == 1, "基础符箓会自动锁定射程内敌人")
	if not main.projectiles.is_empty():
		var projectile: Variant = main.projectiles[0]
		projectile.speed = 10000.0
		main._tick_projectiles(0.1)
		_check(target.hp < target.max_hp, "符箓命中后正确造成伤害")
	else:
		_check(false, "符箓命中后正确造成伤害（未生成投射物）")

	target.hp = target.max_hp
	target.position = player.position + Vector2(100.0, 0.0)
	main.active_skill_cooldown = 0.0
	main.cast_active_skill()
	_check(target.hp < target.max_hp, "镇尸诀对范围内敌人造成伤害")
	_check(main.active_skill_cooldown > 0.0, "镇尸诀施放后进入冷却")
	_check(main.active_skill_effect_time > 0.0, "镇尸诀施放后触发范围视觉反馈")

	player.hp = 100.0
	player.invuln_time = 0.0
	target.position = player.position + Vector2(1.0, 0.0)
	target.move_speed = 0.0
	main.enemies.clear()
	main.enemies.append(target)
	var hp_before_contact: float = player.hp
	main._tick_enemies(0.016)
	_check(player.hp < hp_before_contact, "敌人接触玩家时实际造成伤害")
	_check(player.invuln_time > 0.0, "接触伤害触发受击无敌窗口")

	var kills_before: int = main.kills
	target.hp = 0.0
	main._remove_dead_enemies()
	_check(main.kills == kills_before + 1, "普通敌人死亡后击杀数增加")
	_check(main.xp_orbs.size() == 1, "普通敌人死亡后掉落灵气球")

	player.xp = 0
	player.xp_to_next = 100
	main._tick_xp_orbs(0.016)
	var expected_xp := 1 if target.kind == "walker" else (2 if target.kind == "jumper" else 3)
	_check(player.xp == expected_xp and main.xp_orbs.is_empty(), "不同敌人按威胁等级提供对应经验")

	player.hp = 50.0
	main.heal_charges = 2
	main.use_heal()
	_check(is_equal_approx(player.hp, 80.0), "治疗恢复最大生命的 30%")
	_check(main.heal_charges == 1, "治疗消耗一次库存")

	player.xp = player.xp_to_next
	main.state = "playing"
	main._maybe_level_up()
	_check(main.state == "level_up" and main.level_cards.size() == 3, "经验达到阈值后进入三选一升级")
	if main.state == "level_up":
		main.level_cards.clear()
		main.level_cards.append({"id": "acquire_fire_talisman", "kind": "skill_acquire", "skill_id": "fire_talisman", "name": "火符", "desc": "测试技能"})
		main._select_upgrade(0)
		_check(main.skills.has("fire_talisman"), "选择正式技能后写入局内技能构筑")
		_check(main.state == "playing", "选择升级后恢复战斗")

	var pause_event := InputEventKey.new()
	pause_event.pressed = true
	pause_event.keycode = KEY_ESCAPE
	main._input(pause_event)
	_check(main.state == "paused", "Esc 可暂停游戏")
	main._input(pause_event)
	_check(main.state == "playing", "再次按 Esc 可继续游戏")

	main.elapsed_seconds = 479.99
	main.boss_spawned = false
	main._process(0.02)
	_check(main.get_boss() != null, "达到约 8 分钟后生成尸王")
	_check(main.state == "playing", "Boss 出场后游戏仍处于战斗状态")
	var boss_objective: Dictionary = main.hud.objective_data()
	_check(boss_objective.get("title", "").contains("击败尸王"), "尸王出现后当前目标切换为击败尸王")
	var boss: Variant = main.get_boss()
	boss.position = player.position + Vector2(250.0, 0.0)
	var nearby_mob: Variant = ENEMY_SCRIPT.new()
	nearby_mob.setup("walker")
	nearby_mob.position = player.position + Vector2(80.0, 0.0)
	main.add_child(nearby_mob)
	main.enemies.append(nearby_mob)
	_check(main._find_combat_target(player.position, 620.0) == boss, "尸王进入攻击范围后优先成为自动攻击目标")
	main.enemies.erase(nearby_mob)
	nearby_mob.queue_free()
	boss.hp = 0.0
	main._remove_dead_enemies()
	_check(main.state == "victory", "尸王死亡后进入胜利结算")
	var victory_objective: Dictionary = main.hud.objective_data()
	_check(victory_objective.get("title", "").contains("任务完成"), "胜利后任务提示切换为已完成")
	for i in range(100):
		main._spawn_skill_effect("fire", Vector2.ZERO, 22.0, 0.2)
	_check(main.skill_effects.size() <= 80, "密集战斗的短时特效数量保持有界")
	main.skill_effects.clear()


func _check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		push_error("FAIL: " + description)
