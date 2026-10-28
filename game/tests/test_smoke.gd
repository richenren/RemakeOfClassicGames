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

	var main: Variant = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	_check(main.player != null, "主场景创建玩家")
	_check(main.enemies.size() == 7, "开局生成 7 个普通敌人")
	_test_render_hierarchy(main)
	_test_hud_presentation(main)
	_test_sprite_assets(main)
	_test_skill_build_system(main)

	if main.player != null and not main.enemies.is_empty():
		_test_combat_and_progression(main)

	main.queue_free()
	await process_frame
	print("=== 测试汇总：%d 通过，%d 失败 ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


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
	var atlas := load("res://assets/sprites/creatures_atlas.png") as Texture2D
	_check(atlas != null, "原创道士与僵尸贴图图集可加载")
	if atlas != null:
		_check(atlas.get_size() == Vector2(384.0, 256.0), "贴图图集尺寸与角色/怪物区域一致")
	_check(main.player.is_moving == false, "玩家初始使用待机贴图状态")


func _test_skill_build_system(main: Variant) -> void:
	_check(main.AUTO_SKILL_DEFS.size() == 6, "首版配置六种自动攻击技能")
	_check(main.ARTIFACT_DEFS.size() == 6, "首版配置六种被动法器")
	_check(main.GENERAL_UPGRADE_DEFS.size() == 4, "通用强化池只包含四项设计内容")

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
	main.level_cards.clear()
	main.state = "playing"

	if not main.enemies.is_empty():
		var target: Variant = main.enemies[0]
		target.position = main.player.position + Vector2(100.0, 0.0)
		main.skills["fire_talisman"] = {"level": 1, "branch": "", "evolved": ""}
		main.skill_cooldowns["fire_talisman"] = 0.0
		var projectile_count := main.projectiles.size()
		main._cast_auto_skill("fire_talisman", target)
		_check(main.projectiles.size() > projectile_count, "已获得的火符会实际发射独立技能投射物")
		for projectile in main.projectiles:
			projectile.queue_free()
		main.projectiles.clear()
		main.skills.clear()
		main.skill_cooldowns.clear()


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
	boss.queue_free()


func _test_xp_orb() -> void:
	var orb: Variant = XP_ORB_SCRIPT.new()
	root.add_child(orb)
	orb.setup(1)
	orb.position = Vector2.ZERO
	_check(orb.tick(0.016, Vector2.ZERO, 92.0), "玩家接触灵气球时可拾取")
	orb.queue_free()


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
	_check(player.xp == 1 and main.xp_orbs.is_empty(), "战斗掉落的灵气球可转化为经验")

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
	boss.hp = 0.0
	main._remove_dead_enemies()
	_check(main.state == "victory", "尸王死亡后进入胜利结算")
	var victory_objective: Dictionary = main.hud.objective_data()
	_check(victory_objective.get("title", "").contains("任务完成"), "胜利后任务提示切换为已完成")


func _check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		push_error("FAIL: " + description)
