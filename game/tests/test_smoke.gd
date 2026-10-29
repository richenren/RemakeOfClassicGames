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
	_test_responsive_layout()
	_test_compact_hud_layout()
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
	_check(is_equal_approx(main._camera_zoom_for_size(Vector2(1280.0, 720.0)), 1.0), "基准窗口保持 1:1 战斗镜头")
	_check(is_equal_approx(main._camera_zoom_for_size(Vector2(800.0, 600.0)), 0.625), "800×600 窗口自动缩小镜头以扩大可见战场")
	_check(is_equal_approx(main._camera_zoom_for_size(Vector2(640.0, 360.0)), 0.5), "640×360 窗口按比例缩小镜头，保留基准战场视野比例")
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
	_check(hud._upgrade_category("cultivation_water") == "元素修炼", "元素修炼卡显示独立类别")


func _test_sprite_assets(main: Variant) -> void:
	var background := load("res://assets/sprites/graveyard_background.svg") as Texture2D
	var portrait := load("res://assets/sprites/player_portrait.svg") as Texture2D
	var creatures_atlas := load("res://assets/sprites/creatures_atlas.png") as Texture2D
	_check(background != null and background.get_size() == Vector2(2400.0, 1600.0), "义庄背景以 2400×1600 原生画布加载，避免放大模糊")
	var background_source := FileAccess.get_file_as_string("res://assets/sprites/graveyard_background.svg")
	_check(background_source.contains("id=\"ruined-yizhuang-hall\"") and background_source.contains("id=\"ground-ritual-marks\""), "义庄背景包含灵堂建筑与低对比地面符纹细节")
	_check(portrait != null and portrait.get_size().x >= 96.0, "道士专属头像可加载")
	_check(creatures_atlas != null and creatures_atlas.get_size() == Vector2(384.0, 256.0), "最新国风角色/怪物透明图集可加载")
	_check(main.player.CREATURES_ATLAS != null, "玩家脚本实际引用最新角色图集，而非旧版 SVG")
	_check(main.player.PLAYER_DRAW_SIZE.x <= 56.0 and main.player.PLAYER_DRAW_SIZE.y <= 102.0, "主角采用更修长的 54×100 世界像素比例")
	var player_source: Rect2 = main.player._player_source_rect()
	_check(player_source.position.x >= 0.0 and player_source.position.y >= 0.0 and player_source.end.x <= 384.0 and player_source.end.y <= 256.0, "主角方向姿态裁切区域不越出图集")
	var walker: Variant = ENEMY_SCRIPT.new()
	root.add_child(walker)
	walker.setup("walker")
	_check(walker.CREATURES_ATLAS != null, "敌人脚本实际引用最新角色图集")
	_check(walker._sprite_draw_size_for_kind("walker").y <= 80.0, "普通行尸绘制高度降低，避免占据过多屏幕")
	_check(walker._sprite_draw_size_for_kind("armored").y <= 84.0, "铁甲尸绘制比例独立控制")
	_check(walker._sprite_draw_size_for_kind("boss").y > walker._sprite_draw_size_for_kind("walker").y, "尸王仍保持独立的精英体型")
	var walker_source: Rect2 = walker._sprite_source_rect_for_kind("walker")
	_check(walker_source.position.x >= 0.0 and walker_source.position.y >= 0.0 and walker_source.end.x <= 384.0 and walker_source.end.y <= 256.0, "普通敌人图集裁切区域不越界")
	walker.queue_free()


func _test_skill_build_system(main: Variant) -> void:
	var original_player_level: int = int(main.player.level)
	_check(main.AUTO_SKILL_DEFS.size() == 6, "首版配置六种自动攻击技能")
	_check(main.ARTIFACT_DEFS.size() == 6, "首版配置六种被动法器")
	_check(main.ELEMENT_DEFS.size() == 6, "六大元素各自拥有攻击、修炼与法宝进化配置")
	_check(main.GENERAL_UPGRADE_DEFS.size() == 4, "通用强化池只包含四项设计内容")
	_check(main._ordinary_enemy_cap() == 24, "前期尸潮存在明确存活上限")
	main.elapsed_seconds = 400.0
	_check(main._ordinary_enemy_cap() == 46, "中后期尸潮压力按阶段提升")
	main.elapsed_seconds = 0.0
	main.player.level = 1
	main.primary_element = ""
	main.artifacts.clear()
	main.skills.clear()
	main.skill_cooldowns.clear()
	main.level_cards.clear()
	main.state = "playing"

	main._open_upgrade_choices()
	var skill_card_index := -1
	var general_count := 0
	var early_artifact_count := 0
	var early_cultivation_count := 0
	for i in range(main.level_cards.size()):
		var card: Dictionary = main.level_cards[i]
		if str(card.get("kind", "")) == "skill_acquire":
			skill_card_index = i
		if str(card.get("kind", "")) == "general_upgrade":
			general_count += 1
		if str(card.get("kind", "")) == "artifact_acquire":
			early_artifact_count += 1
		if str(card.get("kind", "")) == "element_cultivation":
			early_cultivation_count += 1
	_check(skill_card_index >= 0, "早期升级候选优先提供正式攻击技能")
	_check(general_count <= 1, "每次升级最多出现一张通用强化卡")
	_check(early_artifact_count == 0 and early_cultivation_count == 0, "主修未确定前不出现流派法器或元素修炼卡")
	if skill_card_index >= 0:
		main._select_upgrade(skill_card_index)
	_check(main.skills.size() == 1, "选择攻击技能后正式技能进入构筑")
	main.skills.clear()
	main.skill_cooldowns.clear()
	main.level_cards.clear()
	main.state = "playing"

	main.player.level = 3
	main.skills["fire_talisman"] = {"level": 2, "branch": "", "evolved": ""}
	main._open_upgrade_choices()
	var branch_count := 0
	var branch_info_count := 0
	for card in main.level_cards:
		if str(card.get("kind", "")) == "skill_branch" and str(card.get("skill_id", "")) == "fire_talisman":
			branch_count += 1
		if str(card.get("kind", "")) == "branch_required_info":
			branch_info_count += 1
	_check(branch_count == 2 and branch_info_count == 1, "Lv3 关键分支只提供两条有效路线和一张不可选提示")
	main._select_upgrade(2)
	_check(main.state == "level_up" and str(main.skills["fire_talisman"]["branch"]).is_empty(), "点击分支提示卡不会跳过关键分支")
	main._select_upgrade(0)
	_check(main.state == "playing" and int(main.skills["fire_talisman"]["level"]) == 3 and not str(main.skills["fire_talisman"]["branch"]).is_empty(), "选择分支后技能升至 Lv3 并锁定分支")
	main.skills.clear()
	main.level_cards.clear()
	main.state = "playing"

	main.player.level = 4
	main.primary_element = ""
	main.skills["water_array"] = {"level": 3, "branch": "cold", "evolved": ""}
	_check(main._skill_level_cap("water_array") == 3, "角色等级不足 Lv6 时主修技能暂时封顶 Lv3")
	main._open_upgrade_choices()
	var early_breakthrough := false
	var early_water_upgrade := false
	var early_artifact := false
	var early_cultivation := false
	for card in main.level_cards:
		if str(card.get("name", "")).begins_with("立道突破"):
			early_breakthrough = true
		if str(card.get("kind", "")) == "skill_level" and str(card.get("skill_id", "")) == "water_array":
			early_water_upgrade = true
		if str(card.get("kind", "")) == "artifact_acquire":
			early_artifact = true
		if str(card.get("kind", "")) == "element_cultivation":
			early_cultivation = true
	_check(not early_breakthrough and not early_water_upgrade, "角色 Lv4 不会出现确定主修的突破选项")
	_check(not early_artifact and not early_cultivation, "角色 Lv4 不会提前出现核心法器或元素修炼")
	_check(main._collect_element_cultivation_candidates().is_empty(), "主修未确定时元素修炼候选池为空")
	main.level_cards.clear()
	main.state = "playing"

	main.player.level = 6
	main._open_upgrade_choices()
	var breakthrough_index := -1
	for i in range(main.level_cards.size()):
		var card: Dictionary = main.level_cards[i]
		if str(card.get("kind", "")) == "skill_level" and str(card.get("skill_id", "")) == "water_array" and str(card.get("name", "")).begins_with("立道突破"):
			breakthrough_index = i
	_check(breakthrough_index >= 0, "角色达到 Lv6 后保证出现明确的立道突破卡")
	if breakthrough_index >= 0:
		main._select_upgrade(breakthrough_index)
	_check(main.primary_element == "water" and int(main.skills["water_array"]["level"]) == 4, "确认突破后锁定水系主修并将技能升至 Lv4")
	_check(main._skill_level_cap("water_array") == 5 and main._skill_level_cap("fire_talisman") == 3, "主修可升 Lv5，兼修最高 Lv3")

	main.skills["fire_talisman"] = {"level": 3, "branch": "flame", "evolved": ""}
	var core_candidates: Array[Dictionary] = main._collect_core_candidates()
	var secondary_can_breakthrough := false
	for card in core_candidates:
		if str(card.get("kind", "")) == "skill_level" and str(card.get("skill_id", "")) == "fire_talisman":
			secondary_can_breakthrough = true
	_check(not secondary_can_breakthrough, "主修锁定后兼修元素不会再出现 Lv4 突破卡")

	main.element_cultivation_levels = {"metal": 0, "wood": 0, "water": 0, "fire": 0, "earth": 0, "thunder": 0}
	_check(main._element_cultivation_cap("water") == 3 and main._element_cultivation_cap("fire") == 1, "主修修炼可到 Lv3，兼修修炼仅 Lv1")
	var cultivation_candidates: Array[Dictionary] = main._collect_element_cultivation_candidates()
	var has_water_cultivation := false
	var has_fire_cultivation := false
	for card in cultivation_candidates:
		if str(card.get("element_id", "")) == "water":
			has_water_cultivation = true
		if str(card.get("element_id", "")) == "fire":
			has_fire_cultivation = true
	_check(has_water_cultivation and has_fire_cultivation, "主修确定后可选择已获取攻击技能对应的元素修炼")
	main._apply_upgrade(main._element_cultivation_card("fire"))
	_check(main._cultivation_level("fire") == 1, "兼修元素修炼可获得一次辅助效果")
	var secondary_cultivation_available := false
	for card in main._collect_element_cultivation_candidates():
		if str(card.get("element_id", "")) == "fire":
			secondary_cultivation_available = true
	_check(not secondary_cultivation_available, "兼修元素修炼达到 Lv1 后退出候选池")
	main._apply_upgrade(main._element_cultivation_card("water"))
	main._apply_upgrade(main._element_cultivation_card("water"))
	_check(main._cultivation_level("water") == 2, "主修元素修炼可持续强化")
	main.player.hp = 50.0
	main.water_recovery_accumulator = 0.0
	main._tick_element_cultivation(1.0)
	_check(is_equal_approx(main.player.hp, 50.7), "水系清泉回元按修炼等级持续恢复生命")
	main.player.hp = main.player.max_hp
	main.water_recovery_accumulator = 0.0

	main.primary_element = ""
	main.skills.clear()
	main.skills["water_array"] = {"level": 3, "branch": "cold", "evolved": ""}
	main.artifacts.clear()
	main.player.level = 4
	_check(main._artifact_slot_cap() == 2, "立道前保留法器槽位上限，但不提前提供法器获取卡")
	var pre_mainline_candidates: Array[Dictionary] = main._collect_core_candidates()
	var pre_mainline_artifact := false
	for card in pre_mainline_candidates:
		if str(card.get("kind", "")) == "artifact_acquire":
			pre_mainline_artifact = true
	_check(not pre_mainline_artifact, "立道前候选池不出现会误导流派选择的核心法器")
	main.primary_element = "water"
	main.player.level = 6
	main.skills["water_array"] = {"level": 4, "branch": "cold", "evolved": ""}
	main.artifacts.clear()
	main._open_upgrade_choices()
	var core_artifact_guaranteed := false
	for card in main.level_cards:
		if str(card.get("kind", "")) == "artifact_acquire" and str(card.get("artifact_id", "")) == "cold_relic":
			core_artifact_guaranteed = true
	_check(core_artifact_guaranteed, "立道后优先提供主修元素对应的核心法宝")
	main.level_cards.clear()
	main.state = "playing"

	for element_variant in main.ELEMENT_DEFS.keys():
		var element_id := str(element_variant)
		var element_def: Dictionary = main.ELEMENT_DEFS[element_id]
		var skill_id := str(element_def["skill_id"])
		var artifact_id := str(element_def["artifact_id"])
		main.primary_element = element_id
		main.skills.clear()
		main.artifacts.clear()
		var branch_options: Array = main.SKILL_BRANCHES[skill_id]
		main.skills[skill_id] = {"level": 5, "branch": str(branch_options[0]["id"]), "evolved": ""}
		main.artifacts[artifact_id] = {"level": 1}
		var element_evolutions: Array[Dictionary] = main._collect_evolution_candidates()
		var found_evolution := false
		for card in element_evolutions:
			if str(card.get("evolution_id", "")) == str(element_def["evolution_id"]):
				found_evolution = true
		_check(found_evolution, "%s系主修 Lv5 配合专属法宝可解锁最终进化" % str(element_def["name"]))
	main.primary_element = "fire"
	main.skills.clear()
	main.artifacts.clear()
	main.skills["water_array"] = {"level": 5, "branch": "cold", "evolved": ""}
	main.artifacts["cold_relic"] = {"level": 1}
	_check(main._collect_evolution_candidates().is_empty(), "非主修元素即使 Lv5 持有法宝也不能进化")
	main.skills.clear()
	main.artifacts.clear()
	main.primary_element = ""
	main.element_cultivation_levels = {"metal": 0, "wood": 0, "water": 0, "fire": 0, "earth": 0, "thunder": 0}
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

	main.player.level = original_player_level


func _test_responsive_layout() -> void:
	var hud: Variant = HUD_SCRIPT.new()
	root.add_child(hud)
	var view_sizes: Array[Vector2] = [Vector2(1280.0, 720.0), Vector2(1067.0, 744.0), Vector2(800.0, 600.0), Vector2(640.0, 360.0)]
	for view in view_sizes:
		var layout: Dictionary = hud._level_up_layout(view)
		var panel: Rect2 = layout["panel"]
		var cards: Array = layout["cards"]
		_check(panel.position.x >= 0.0 and panel.position.y >= 0.0 and panel.end.x <= view.x + 0.1 and panel.end.y <= view.y + 0.1, "升级面板适配视口 %dx%d" % [roundi(view.x), roundi(view.y)])
		_check(cards.size() == 3, "升级面板始终保留三张可选卡片")
		var all_inside := true
		var no_overlap := true
		for i in range(cards.size()):
			var card_rect: Rect2 = cards[i]
			if not panel.has_point(card_rect.position) or not panel.has_point(card_rect.end - Vector2(1.0, 1.0)):
				all_inside = false
			if i > 0:
				var previous: Rect2 = cards[i - 1]
				if previous.end.x > card_rect.position.x:
					no_overlap = false
		_check(all_inside, "三张升级卡均位于面板内")
		_check(no_overlap, "三张升级卡之间不重叠")
	hud.queue_free()

func _test_compact_hud_layout() -> void:
	var hud: Variant = HUD_SCRIPT.new()
	root.add_child(hud)
	for view in [Vector2(800.0, 600.0), Vector2(640.0, 360.0)]:
		var layout: Dictionary = hud._hud_layout(view)
		_check(bool(layout.get("compact", false)), "小视口 %dx%d 启用紧凑 HUD" % [roundi(view.x), roundi(view.y)])
		for key in ["status", "time", "skill", "objective", "boss", "controls", "build"]:
			var rect: Rect2 = layout[key]
			_check(rect.position.x >= -0.1 and rect.position.y >= -0.1 and rect.end.x <= view.x + 0.1 and rect.end.y <= view.y + 0.1, "紧凑 HUD 的 %s 面板不越界 (%dx%d)" % [key, roundi(view.x), roundi(view.y)])
		var status_rect: Rect2 = layout["status"]
		var objective_rect: Rect2 = layout["objective"]
		var time_rect: Rect2 = layout["time"]
		var skill_rect: Rect2 = layout["skill"]
		var controls_rect: Rect2 = layout["controls"]
		var build_rect: Rect2 = layout["build"]
		_check(status_rect.end.x < objective_rect.position.x and objective_rect.end.x < skill_rect.position.x, "小视口目标栏避开左右状态面板")
		_check(time_rect.end.y < objective_rect.position.y, "小视口计时与目标栏垂直分离")
		_check(controls_rect.end.y < build_rect.position.y, "小视口操作提示与构筑栏不重叠")
		var touch: Dictionary = hud._touch_layout(view)
		var skill_center: Vector2 = touch["skill_center"]
		var heal_center: Vector2 = touch["heal_center"]
		_check(skill_center.x >= float(touch["skill_radius"]) and skill_center.x + float(touch["skill_radius"]) <= view.x, "小视口道术按钮完整显示")
		_check(heal_center.y + float(touch["heal_radius"]) <= view.y, "小视口治疗按钮完整显示")
		_check(skill_center.distance_to(heal_center) > float(touch["skill_radius"]) + float(touch["heal_radius"]), "小视口道术与治疗按钮视觉上不重叠")
		_check(skill_center.distance_to(heal_center) > float(touch["skill_hit_radius"]) + float(touch["heal_hit_radius"]), "小视口道术与治疗触控热区不重叠")
	hud.queue_free()

func _test_skill_art_assets() -> void:
	var atlas := load("res://assets/sprites/skill_art_atlas.svg") as Texture2D
	var cultivation_atlas := load("res://assets/sprites/element_cultivation_atlas.svg") as Texture2D
	var card_atlas := load("res://assets/sprites/skill_card_art_atlas.svg") as Texture2D
	var water_card_art := load("res://assets/sprites/water_cold_tide_card.svg") as Texture2D
	_check(atlas != null, "国风技能插画图集可加载")
	_check(cultivation_atlas != null, "六大元素修炼专属插画图集可加载")
	_check(card_atlas != null, "横向高细节技能卡插画图集可加载")
	_check(water_card_art != null, "寒潮阵专属高细节水冰漩涡插画可加载")
	if water_card_art != null:
		_check(water_card_art.get_size() == Vector2(640.0, 416.0), "寒潮阵插画使用 640×416 横向构图")
	if atlas != null:
		_check(atlas.get_size() == Vector2(768.0, 128.0), "六种技能插画共享 768×128 图集")
	if cultivation_atlas != null:
		_check(cultivation_atlas.get_size() == Vector2(768.0, 128.0), "六种元素修炼插画共享 768×128 图集")
	if card_atlas != null:
		_check(card_atlas.get_size() == Vector2(3840.0, 208.0), "十二种技能/修炼卡插画使用 3840×208 横向图集")
	var hud: Variant = HUD_SCRIPT.new()
	root.add_child(hud)
	_check(hud._uses_water_formation_card_art("water_array"), "寒潮阵升级卡使用独立水系主视觉")
	_check(hud._uses_water_formation_card_art("ice_array"), "冰魄阵进化卡复用水冰主视觉")
	_check(hud._uses_water_formation_card_art("cold_relic"), "寒魄法器卡复用水冰主视觉")
	_check(not hud._uses_water_formation_card_art("fire_talisman"), "火符卡保持火系独立主视觉")
	_check(hud._skill_art_region("fire_talisman").position.x == 0.0, "火符使用专属插画帧")
	_check(hud._skill_art_region("thunder_talisman").position.x == 128.0, "雷符使用专属插画帧")
	_check(hud._skill_art_region("copper_coin_sword").position.x == 256.0, "铜钱剑使用独立武器插画帧")
	_check(hud._skill_art_region("peachwood_sword").position.x == 384.0, "桃木剑使用独立武器插画帧")
	_check(hud._skill_art_region("water_array").position.x == 512.0, "水阵使用专属插画帧")
	_check(hud._skill_art_region("earth_formation").position.x == 640.0, "地脉阵使用专属插画帧")
	_check(hud._skill_card_art_region("fire_talisman").position.x == 0.0, "火符卡使用横向火符主视觉")
	_check(hud._skill_card_art_region("thunder_talisman").position.x == 320.0, "雷符卡使用横向雷符主视觉")
	_check(hud._skill_card_art_region("copper_coin_sword").position.x == 640.0, "铜钱剑卡使用横向御剑主视觉")
	_check(hud._skill_card_art_region("peachwood_sword").position.x == 960.0, "桃木剑卡使用横向青木剑主视觉")
	_check(hud._skill_card_art_region("greenwood_guardian").position.x == 2240.0, "青木守护使用木系灵枝插画")
	_check(hud._skill_card_art_region("body_jade").position.x == 2240.0, "护身玉佩使用灵玉主视觉")
	_check(hud._skill_card_art_region("water_array").position.x == 1280.0, "水阵卡使用横向水阵主视觉")
	_check(hud._skill_card_art_region("earth_formation").position.x == 1600.0, "地脉阵卡使用横向地脉主视觉")
	var card_svg_source := FileAccess.get_file_as_string("res://assets/sprites/skill_card_art_atlas.svg")
	var earth_start := card_svg_source.find('<g transform="translate(1600 0)">')
	var earth_end := card_svg_source.find('<g transform="translate(1920 0)">')
	var earth_art := card_svg_source.substr(earth_start, earth_end - earth_start) if earth_start >= 0 and earth_end > earth_start else ""
	_check(earth_art.contains("<title>土系地脉阵：裂地岩柱与石屑震波</title>"), "土系地脉阵插画明确表达裂地岩柱与石屑震波")
	_check(not earth_art.contains("#ef6529") and not earth_art.contains("#ffd16c"), "土系地脉阵插画不复用火系高饱和火焰配色")
	_check(hud._skill_card_art_region("cultivation_metal").position.x == 1920.0, "金系修炼卡有独立横向插画")
	_check(hud._skill_card_art_region("cultivation_thunder").position.x == 3520.0, "雷系修炼卡有独立横向插画")
	_check(hud._cultivation_art_region("cultivation_metal").position.x == 0.0, "金系修炼使用专属剑意插画")
	_check(hud._cultivation_art_region("cultivation_wood").position.x == 128.0, "木系修炼使用专属青木插画")
	_check(hud._cultivation_art_region("cultivation_water").position.x == 256.0, "水系修炼使用专属清泉插画")
	_check(hud._cultivation_art_region("cultivation_fire").position.x == 384.0, "火系修炼使用专属余烬插画")
	_check(hud._cultivation_art_region("cultivation_earth").position.x == 512.0, "土系修炼使用专属地脉插画")
	_check(hud._cultivation_art_region("cultivation_thunder").position.x == 640.0, "雷系修炼使用专属引雷插画")
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
	_check(player.is_moving, "玩家移动时进入行走动画状态")
	_check(player.gait_phase > 0.0, "玩家移动时更新连续步态动画相位")
	var moving_speed: float = player.velocity.length()
	_check(moving_speed > 0.0 and moving_speed < player.move_speed, "玩家起步采用加速度过渡而非瞬间达到最高速度")
	player.mobile_move = Vector2.ZERO
	player.tick(0.02)
	_check(player.velocity.length() < moving_speed, "玩家松开输入后平滑减速而非瞬间停住")
	player.trigger_attack(Vector2.LEFT)
	_check(player.attack_pulse > 0.0 and player.facing.x < 0.0, "自动攻击触发短促转向/挥击反馈")

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
	walker.tick(0.05, Vector2(100.0, 0.0), Vector2.ZERO)
	_check(walker.position.x > old_x, "普通敌人会追踪玩家")
	_check(walker.velocity.length() < walker.move_speed, "普通敌人起步采用加速度过渡")
	walker.tick(0.45, Vector2(100.0, 0.0), Vector2.ZERO)
	_check(walker.gait_phase > 0.0, "普通敌人追踪时更新连续步态动画")
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

	# Boss targeting remains, but a projectile must stop at the first enemy on its path.
	var saved_enemy_refs: Array = []
	var saved_enemy_positions: Array[Vector2] = []
	for enemy in main.enemies:
		if enemy == boss or enemy == nearby_mob:
			continue
		saved_enemy_refs.append(enemy)
		saved_enemy_positions.append(enemy.position)
		enemy.position = player.position + Vector2(0.0, 500.0 + float(saved_enemy_positions.size()) * 70.0)
	for old_projectile in main.projectiles:
		old_projectile.queue_free()
	main.projectiles.clear()
	boss.hp = boss.max_hp
	nearby_mob.hp = nearby_mob.max_hp
	var boss_hp_before_blocked_shot: float = boss.hp
	var mob_hp_before_blocked_shot: float = nearby_mob.hp
	main._auto_attack()
	_check(main.projectiles.size() == 1 and main.projectiles[0].target == boss, "尸王仍可作为基础攻击的优先锁定目标")
	if not main.projectiles.is_empty():
		main.projectiles[0].speed = 10000.0
		main._tick_projectiles(0.1)
	_check(nearby_mob.hp < mob_hp_before_blocked_shot, "尸王前方的小怪会优先承受弹道伤害")
	_check(is_equal_approx(boss.hp, boss_hp_before_blocked_shot), "弹道命中挡路小怪时不会同时伤害尸王")
	_check(main.projectiles.is_empty(), "弹道命中第一个碰撞目标后销毁")
	for i in range(saved_enemy_refs.size()):
		saved_enemy_refs[i].position = saved_enemy_positions[i]

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
