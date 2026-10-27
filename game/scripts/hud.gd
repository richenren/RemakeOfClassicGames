extends Node2D

var main_ref
const TEXT_COLOR := Color("#efe6d2")
const MUTED_COLOR := Color("#b8ad99")
const PANEL_COLOR := Color(0.08, 0.075, 0.065, 0.92)
const PANEL_EDGE := Color("#8b7758")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main_ref == null:
		return
	var view := get_viewport_rect().size
	_draw_hud(view)
	if main_ref.state == "level_up":
		_draw_level_up(view)
	elif main_ref.state == "paused":
		_draw_pause(view)
	elif main_ref.state == "game_over" or main_ref.state == "victory":
		_draw_end_screen(view)
	if _is_mobile():
		_draw_touch_controls(view)


func _draw_hud(view: Vector2) -> void:
	var player = main_ref.player
	if player == null:
		return

	draw_rect(Rect2(18.0, 18.0, 280.0, 84.0), PANEL_COLOR)
	draw_rect(Rect2(18.0, 18.0, 280.0, 84.0), Color("#5d5444"), false, 1.0)
	_text(Vector2(30.0, 39.0), "镇邪录 · 原型战斗", 17, TEXT_COLOR)
	_text(Vector2(30.0, 60.0), "生命  %d / %d" % [roundi(player.hp), roundi(player.max_hp)], 14, TEXT_COLOR)
	_bar(Rect2(30.0, 67.0, 250.0, 8.0), player.hp / maxf(1.0, player.max_hp), Color("#b65343"))
	_text(Vector2(30.0, 94.0), "等级 %d   击杀 %d" % [player.level, main_ref.kills], 13, MUTED_COLOR)

	draw_rect(Rect2(view.x * 0.5 - 150.0, 18.0, 300.0, 48.0), PANEL_COLOR)
	_text(Vector2(view.x * 0.5 - 136.0, 39.0), "生存时间  %s" % _format_time(main_ref.elapsed_seconds), 16, TEXT_COLOR)
	if _is_mobile():
		_text(Vector2(view.x * 0.5 + 112.0, 39.0), "Ⅱ", 18, Color("#e8c86c"))
	_text(Vector2(view.x * 0.5 - 136.0, 57.0), "灵气 %d / %d" % [player.xp, player.xp_to_next], 12, MUTED_COLOR)
	_bar(Rect2(view.x * 0.5 + 10.0, 47.0, 124.0, 7.0), float(player.xp) / maxf(1.0, float(player.xp_to_next)), Color("#6ebba0"))

	var skill_panel := Rect2(view.x - 248.0, 18.0, 230.0, 144.0)
	draw_rect(skill_panel, PANEL_COLOR)
	draw_rect(skill_panel, Color("#5d5444"), false, 1.0)
	_text(Vector2(view.x - 234.0, 39.0), "基础符箓", 15, TEXT_COLOR)
	_text(Vector2(view.x - 234.0, 60.0), "伤害 %d" % roundi(player.damage), 13, MUTED_COLOR)
	_text(Vector2(view.x - 234.0, 80.0), "攻击间隔 %.2fs" % player.attack_interval, 13, MUTED_COLOR)

	var skill_ready: bool = main_ref.active_skill_cooldown <= 0.0
	var skill_color := Color("#e8c86c") if skill_ready else Color("#9e8b6a")
	_draw_skill_emblem(Vector2(view.x - 42.0, 103.0), skill_ready, skill_color)
	_text(Vector2(view.x - 234.0, 103.0), "主动道术 · 镇尸诀", 13, skill_color)
	_text(Vector2(view.x - 234.0, 122.0), "就绪" if skill_ready else "冷却 %ds" % ceili(main_ref.active_skill_cooldown), 12, TEXT_COLOR)
	var skill_ratio := 1.0 if skill_ready else 1.0 - clampf(main_ref.active_skill_cooldown / maxf(0.1, main_ref.active_skill_base_cooldown), 0.0, 1.0)
	_bar(Rect2(view.x - 234.0, 130.0, 132.0, 6.0), skill_ratio, Color("#d1a84e"))
	_text(Vector2(view.x - 94.0, 140.0), "SPACE", 10, MUTED_COLOR)
	_text(Vector2(view.x - 234.0, 156.0), "治疗次数 %d/2" % main_ref.heal_charges, 12, MUTED_COLOR)

	if main_ref.state != "game_over" and main_ref.state != "victory":
		_draw_objective_panel(view)

	var boss = main_ref.get_boss()
	if boss != null:
		var boss_width := minf(500.0, view.x * 0.48)
		var boss_x := (view.x - boss_width) * 0.5
		_text(Vector2(boss_x, 93.0), "尸王" + (" · 暴走" if boss.hp / boss.max_hp <= 0.5 else ""), 15, Color("#e7c88a"))
		_bar(Rect2(boss_x, 101.0, boss_width, 11.0), boss.hp / maxf(1.0, boss.max_hp), Color("#a44439"), true)

	if not _is_mobile():
		_text(Vector2(view.x * 0.5 - 260.0, view.y - 18.0), "WASD / 方向键移动    SPACE 镇尸诀    E 治疗    ESC 暂停", 14, MUTED_COLOR)
	else:
		_text(Vector2(view.x * 0.5 - 120.0, view.y - 18.0), "左侧移动 · 右侧技能 / 治疗", 13, MUTED_COLOR)


func _draw_level_up(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.015, 0.014, 0.012, 0.84))
	_text(Vector2(view.x * 0.5 - 160.0, view.y * 0.5 - 145.0), "修为精进 · 选择一项", 28, Color("#f0d79b"))
	_text(Vector2(view.x * 0.5 - 125.0, view.y * 0.5 - 112.0), "选择期间战斗与计时暂停", 15, MUTED_COLOR)
	var card_width := minf(270.0, (view.x - 48.0) / 3.0 - 12.0)
	var card_height := 154.0
	var gap := 16.0
	var total_width := card_width * 3.0 + gap * 2.0
	var start_x := (view.x - total_width) * 0.5
	var y := view.y * 0.5 - 75.0
	for i in range(mini(3, main_ref.level_cards.size())):
		var card: Dictionary = main_ref.level_cards[i]
		var rect := Rect2(start_x + i * (card_width + gap), y, card_width, card_height)
		var accent := _upgrade_color(str(card.get("id", "")))
		draw_rect(rect, Color("#24251f"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), accent)
		draw_rect(rect, accent.darkened(0.25), false, 2.0)
		_draw_upgrade_emblem(rect.position + Vector2(30.0, 38.0), str(card.get("id", "")), accent)
		_text(rect.position + Vector2(56.0, 30.0), "%d  %s" % [i + 1, str(card.get("name", "未知强化"))], 17, Color("#f1d58f"))
		_text(rect.position + Vector2(56.0, 52.0), _upgrade_category(str(card.get("id", ""))), 11, accent)
		_text(rect.position + Vector2(16.0, 91.0), str(card.get("desc", "")), 14, TEXT_COLOR)
		draw_line(rect.position + Vector2(14.0, 111.0), rect.position + Vector2(rect.size.x - 14.0, 111.0), Color("#4d493e"), 1.0)
		_text(rect.position + Vector2(16.0, card_height - 18.0), "按 %d 选择  ·  点击卡片" % (i + 1), 12, MUTED_COLOR)


func _draw_objective_panel(view: Vector2) -> void:
	var objective := objective_data()
	if objective.is_empty():
		return
	var rect := Rect2(18.0, 112.0, 280.0, 66.0)
	var accent: Color = Color("#c9a65b") if objective["kind"] == "boss" else Color("#8fba9b")
	draw_rect(rect, PANEL_COLOR)
	draw_rect(rect, Color("#5d5444"), false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(4.0, rect.size.y)), accent)
	_text(rect.position + Vector2(14.0, 22.0), str(objective["title"]), 14, accent)
	_text(rect.position + Vector2(14.0, 43.0), str(objective["detail"]), 12, TEXT_COLOR)
	_bar(Rect2(rect.position.x + 14.0, rect.position.y + 52.0, rect.size.x - 28.0, 5.0), float(objective["progress"]), accent)


func objective_data() -> Dictionary:
	if main_ref == null:
		return {}
	if main_ref.state == "victory":
		return {"title": "任务完成 · 尸王伏诛", "detail": "本局目标已达成", "progress": 1.0, "kind": "success"}
	if main_ref.state == "game_over":
		return {"title": "本局结束 · 阳寿已尽", "detail": "整备后可重新挑战", "progress": 0.0, "kind": "failed"}
	if main_ref.boss_spawned:
		var boss = main_ref.get_boss()
		if boss != null:
			var progress := 1.0 - clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)
			return {"title": "当前目标 · 击败尸王", "detail": "持续走位，抓住输出时机", "progress": progress, "kind": "boss"}
		return {"title": "当前目标 · 清理战场", "detail": "尸王战斗正在收尾", "progress": 0.9, "kind": "boss"}
	var remaining := maxi(0, ceili(480.0 - main_ref.elapsed_seconds))
	return {
		"title": "当前目标 · 镇压尸潮",
		"detail": "尸王现身倒计时 %02d:%02d" % [remaining / 60, remaining % 60],
		"progress": clampf(main_ref.elapsed_seconds / 480.0, 0.0, 1.0),
		"kind": "survival"
	}


func _draw_skill_emblem(center: Vector2, ready: bool, color: Color) -> void:
	draw_circle(center, 12.0, Color(0.08, 0.07, 0.05, 0.95))
	draw_arc(center, 12.0, 0.0, TAU, 32, color, 2.0 if ready else 1.0)
	draw_line(center + Vector2(0.0, -7.0), center + Vector2(0.0, 7.0), color, 1.5)
	draw_line(center + Vector2(-5.0, -3.0), center + Vector2(5.0, 3.0), color, 1.5)
	draw_line(center + Vector2(-5.0, 3.0), center + Vector2(5.0, -3.0), color, 1.5)


func _draw_upgrade_emblem(center: Vector2, upgrade_id: String, color: Color) -> void:
	draw_circle(center, 17.0, Color(0.08, 0.07, 0.05, 0.95))
	draw_arc(center, 17.0, 0.0, TAU, 32, color, 2.0)
	match upgrade_id:
		"talisman_power", "rapid_talisman":
			draw_line(center + Vector2(-7.0, -9.0), center + Vector2(5.0, 8.0), color, 3.0)
			draw_line(center + Vector2(5.0, -8.0), center + Vector2(-4.0, 8.0), color, 2.0)
		"swift_step":
			draw_line(center + Vector2(-9.0, 5.0), center + Vector2(7.0, -5.0), color, 3.0)
			draw_line(center + Vector2(-3.0, 8.0), center + Vector2(10.0, -3.0), color, 2.0)
		"vitality":
			draw_circle(center, 6.0, color)
		"spirit_sense":
			draw_arc(center, 8.0, PI, TAU, 20, color, 2.0)
			draw_circle(center, 3.0, color)
		"control_art":
			draw_line(center + Vector2(-7.0, -7.0), center + Vector2(7.0, 7.0), color, 2.5)
			draw_line(center + Vector2(-7.0, 7.0), center + Vector2(7.0, -7.0), color, 2.5)


func _upgrade_color(upgrade_id: String) -> Color:
	match upgrade_id:
		"talisman_power", "rapid_talisman":
			return Color("#d9b65f")
		"swift_step", "vitality":
			return Color("#c17a65")
		"spirit_sense":
			return Color("#6ebba0")
		"control_art":
			return Color("#a995d0")
		_:
			return PANEL_EDGE


func _upgrade_category(upgrade_id: String) -> String:
	match upgrade_id:
		"talisman_power", "rapid_talisman":
			return "攻击强化"
		"swift_step":
			return "身法强化"
		"vitality":
			return "生存强化"
		"spirit_sense":
			return "灵气强化"
		"control_art":
			return "道术强化"
		_:
			return "通用强化"


func _draw_pause(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.01, 0.01, 0.72))
	_text(Vector2(view.x * 0.5 - 60.0, view.y * 0.5 - 45.0), "游戏暂停", 30, Color("#f0d79b"))
	_text(Vector2(view.x * 0.5 - 125.0, view.y * 0.5), "按 ESC 继续；点击屏幕中央也可继续", 15, TEXT_COLOR)


func _draw_end_screen(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.01, 0.01, 0.78))

	# Keep the result text readable even when the player or enemies remain behind the HUD.
	var panel_rect := end_panel_rect(view)
	draw_rect(panel_rect, Color(0.055, 0.05, 0.04, 0.99))
	draw_rect(panel_rect, PANEL_EDGE, false, 2.0)

	var title := "尸王伏诛 · 胜利" if main_ref.state == "victory" else "阳寿已尽 · 本局结束"
	_text(Vector2(view.x * 0.5 - 150.0, view.y * 0.5 - 65.0), title, 30, Color("#f0d79b"))
	_text(Vector2(view.x * 0.5 - 145.0, view.y * 0.5 - 20.0), "生存 %s    击杀 %d    等级 %d" % [_format_time(main_ref.elapsed_seconds), main_ref.kills, main_ref.player.level], 16, TEXT_COLOR)
	_text(Vector2(view.x * 0.5 - 120.0, view.y * 0.5 + 28.0), "按 R 重新开始", 18, MUTED_COLOR)


func end_panel_rect(view: Vector2) -> Rect2:
	var panel_width := minf(560.0, view.x - 32.0)
	var panel_height := 250.0
	return Rect2(
		Vector2((view.x - panel_width) * 0.5, (view.y - panel_height) * 0.5),
		Vector2(panel_width, panel_height)
	)


func _draw_touch_controls(view: Vector2) -> void:
	var joystick_center := Vector2(94.0, view.y - 105.0)
	draw_circle(joystick_center, 58.0, Color(0.06, 0.06, 0.05, 0.3))
	draw_arc(joystick_center, 58.0, 0.0, TAU, 40, Color(0.85, 0.78, 0.62, 0.65), 2.0)
	var knob_offset: Vector2 = main_ref.player.mobile_move * 28.0
	draw_circle(joystick_center + knob_offset, 24.0, Color(0.78, 0.68, 0.48, 0.35))
	draw_arc(Vector2(view.x - 82.0, view.y - 122.0), 44.0, 0.0, TAU, 40, Color("#d9b65f"), 3.0)
	_text(Vector2(view.x - 115.0, view.y - 115.0), "镇尸", 16, Color("#f0d79b"))
	draw_arc(Vector2(view.x - 51.0, view.y - 61.0), 27.0, 0.0, TAU, 32, Color("#c16b55"), 2.0)
	_text(Vector2(view.x - 72.0, view.y - 55.0), "疗", 15, TEXT_COLOR)


func card_index_at(screen_position: Vector2) -> int:
	var view := get_viewport_rect().size
	var card_width := minf(270.0, (view.x - 48.0) / 3.0 - 12.0)
	var card_height := 154.0
	var gap := 16.0
	var total_width := card_width * 3.0 + gap * 2.0
	var start_x := (view.x - total_width) * 0.5
	var y := view.y * 0.5 - 75.0
	for i in range(3):
		var rect := Rect2(start_x + i * (card_width + gap), y, card_width, card_height)
		if rect.has_point(screen_position):
			return i
	return -1


func _bar(rect: Rect2, ratio: float, color: Color, outline: bool = false) -> void:
	draw_rect(rect, Color("#211f1a"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)
	if outline:
		draw_rect(rect, PANEL_EDGE, false, 1.0)


func _text(position: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _format_time(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or DisplayServer.get_name() == "Android"
