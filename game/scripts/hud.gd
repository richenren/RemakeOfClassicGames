extends Node2D

var main_ref: Node
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
	_text(Vector2(view.x * 0.5 - 136.0, 57.0), "灵气 %d / %d" % [player.xp, player.xp_to_next], 12, MUTED_COLOR)
	_bar(Rect2(view.x * 0.5 + 10.0, 47.0, 124.0, 7.0), float(player.xp) / maxf(1.0, float(player.xp_to_next)), Color("#6ebba0"))

	draw_rect(Rect2(view.x - 218.0, 18.0, 200.0, 88.0), PANEL_COLOR)
	_text(Vector2(view.x - 204.0, 39.0), "基础符箓", 15, TEXT_COLOR)
	_text(Vector2(view.x - 204.0, 60.0), "伤害 %d" % roundi(player.damage), 13, MUTED_COLOR)
	_text(Vector2(view.x - 204.0, 80.0), "攻击间隔 %.2fs" % player.attack_interval, 13, MUTED_COLOR)
	_text(Vector2(view.x - 204.0, 98.0), "镇尸诀  %s" % ("就绪" if main_ref.active_skill_cooldown <= 0.0 else "%ds" % ceili(main_ref.active_skill_cooldown)), 13, Color("#e8c86c"))

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
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.015, 0.014, 0.012, 0.78))
	_text(Vector2(view.x * 0.5 - 160.0, view.y * 0.5 - 145.0), "修为精进 · 选择一项", 28, Color("#f0d79b"))
	_text(Vector2(view.x * 0.5 - 125.0, view.y * 0.5 - 112.0), "选择期间战斗与计时暂停", 15, MUTED_COLOR)
	var card_width := minf(270.0, (view.x - 48.0) / 3.0 - 12.0)
	var card_height := 154.0
	var gap := 16.0
	var total_width := card_width * 3.0 + gap * 2.0
	var start_x := (view.x - total_width) * 0.5
	var y := view.y * 0.5 - 75.0
	for i in range(mini(3, main_ref.level_cards.size())):
		var rect := Rect2(start_x + i * (card_width + gap), y, card_width, card_height)
		draw_rect(rect, Color("#24251f"))
		draw_rect(rect, PANEL_EDGE, false, 2.0)
		_text(rect.position + Vector2(18.0, 30.0), "%d  %s" % [i + 1, main_ref.level_cards[i].name], 19, Color("#f1d58f"))
		_text(rect.position + Vector2(18.0, 64.0), main_ref.level_cards[i].desc, 14, TEXT_COLOR)
		_text(rect.position + Vector2(18.0, card_height - 18.0), "点击选择", 12, MUTED_COLOR)


func _draw_pause(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.01, 0.01, 0.72))
	_text(Vector2(view.x * 0.5 - 60.0, view.y * 0.5 - 45.0), "游戏暂停", 30, Color("#f0d79b"))
	_text(Vector2(view.x * 0.5 - 125.0, view.y * 0.5), "按 ESC 继续；点击屏幕中央也可继续", 15, TEXT_COLOR)


func _draw_end_screen(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.01, 0.01, 0.78))
	var title := "尸王伏诛 · 胜利" if main_ref.state == "victory" else "阳寿已尽 · 本局结束"
	_text(Vector2(view.x * 0.5 - 150.0, view.y * 0.5 - 65.0), title, 30, Color("#f0d79b"))
	_text(Vector2(view.x * 0.5 - 145.0, view.y * 0.5 - 20.0), "生存 %s    击杀 %d    等级 %d" % [_format_time(main_ref.elapsed_seconds), main_ref.kills, main_ref.player.level], 16, TEXT_COLOR)
	_text(Vector2(view.x * 0.5 - 120.0, view.y * 0.5 + 28.0), "按 R 重新开始", 18, MUTED_COLOR)


func _draw_touch_controls(view: Vector2) -> void:
	var joystick_center := Vector2(94.0, view.y - 105.0)
	draw_circle(joystick_center, 58.0, Color(0.06, 0.06, 0.05, 0.3))
	draw_arc(Rect2(joystick_center - Vector2(58.0, 58.0), Vector2(116.0, 116.0)), 0.0, TAU, 40, Color(0.85, 0.78, 0.62, 0.65), 2.0)
	var knob_offset: Vector2 = main_ref.player.mobile_move * 28.0
	draw_circle(joystick_center + knob_offset, 24.0, Color(0.78, 0.68, 0.48, 0.35))
	draw_arc(Rect2(view.x - 126.0, view.y - 166.0, 88.0, 88.0), 0.0, TAU, 40, Color("#d9b65f"), 3.0)
	_text(Vector2(view.x - 115.0, view.y - 115.0), "镇尸", 16, Color("#f0d79b"))
	draw_arc(Rect2(view.x - 78.0, view.y - 88.0, 54.0, 54.0), 0.0, TAU, 32, Color("#c16b55"), 2.0)
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
