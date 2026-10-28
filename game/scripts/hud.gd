extends Node2D

const SKILL_ART_ATLAS: Texture2D = preload("res://assets/sprites/skill_art_atlas.svg")
const ELEMENT_CULTIVATION_ATLAS: Texture2D = preload("res://assets/sprites/element_cultivation_atlas.svg")

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

	var status_rect := Rect2(18.0, 18.0, 286.0, 88.0)
	_draw_ornate_panel(status_rect, Color("#c6a566"))
	_text(Vector2(30.0, 39.0), "镇邪录 · 破败义庄", 16, Color("#e7cf98"))
	_draw_seal(Vector2(status_rect.end.x - 20.0, status_rect.position.y + 21.0), "令", Color("#b34a3d"))
	_text(Vector2(30.0, 60.0), "生命  %d / %d" % [roundi(player.hp), roundi(player.max_hp)], 14, TEXT_COLOR)
	_bar(Rect2(30.0, 68.0, 250.0, 8.0), player.hp / maxf(1.0, player.max_hp), Color("#b65343"), true)
	_text(Vector2(30.0, 94.0), "等级 %d   ·   击杀 %d" % [player.level, main_ref.kills], 12, MUTED_COLOR)

	var time_rect := Rect2(view.x * 0.5 - 160.0, 18.0, 320.0, 56.0)
	_draw_ornate_panel(time_rect, Color("#b69a62"))
	_text(Vector2(time_rect.position.x + 14.0, 39.0), "生存时间  %s" % _format_time(main_ref.elapsed_seconds), 16, TEXT_COLOR)
	if _is_mobile():
		_text(Vector2(time_rect.end.x - 28.0, 39.0), "Ⅱ", 18, Color("#e8c86c"))
	_text(Vector2(time_rect.position.x + 14.0, 57.0), "灵气 %d / %d" % [player.xp, player.xp_to_next], 12, MUTED_COLOR)
	_bar(Rect2(time_rect.position.x + 150.0, 47.0, 152.0, 7.0), float(player.xp) / maxf(1.0, float(player.xp_to_next)), Color("#6ebba0"))

	var skill_panel := Rect2(view.x - 258.0, 18.0, 240.0, 150.0)
	_draw_ornate_panel(skill_panel, Color("#c6a566"))
	_text(Vector2(skill_panel.position.x + 14.0, 39.0), "基础符箓", 15, TEXT_COLOR)
	_text(Vector2(skill_panel.position.x + 14.0, 60.0), "伤害  %d" % roundi(player.damage), 13, MUTED_COLOR)
	_text(Vector2(skill_panel.position.x + 14.0, 80.0), "攻击间隔  %.2fs" % player.attack_interval, 13, MUTED_COLOR)

	var skill_ready: bool = main_ref.active_skill_cooldown <= 0.0
	var skill_color := Color("#e8c86c") if skill_ready else Color("#9e8b6a")
	_draw_skill_emblem(Vector2(skill_panel.end.x - 24.0, skill_panel.position.y + 86.0), skill_ready, skill_color)
	_text(Vector2(skill_panel.position.x + 14.0, 103.0), "主动道术 · 镇尸诀 Lv%d" % main_ref.active_skill_level, 13, skill_color)
	_text(Vector2(skill_panel.position.x + 14.0, 122.0), "就绪" if skill_ready else "冷却 %ds" % ceili(main_ref.active_skill_cooldown), 12, TEXT_COLOR)
	var skill_ratio := 1.0 if skill_ready else 1.0 - clampf(main_ref.active_skill_cooldown / maxf(0.1, main_ref.active_skill_base_cooldown), 0.0, 1.0)
	_bar(Rect2(skill_panel.position.x + 14.0, 130.0, 132.0, 6.0), skill_ratio, Color("#d1a84e"))
	_text(Vector2(skill_panel.position.x + 154.0, 140.0), "触发" if _is_mobile() else "SPACE", 10, MUTED_COLOR)
	_text(Vector2(skill_panel.position.x + 14.0, 156.0), "治疗次数  %d/2" % main_ref.heal_charges, 12, MUTED_COLOR)

	if main_ref.state != "game_over" and main_ref.state != "victory":
		_draw_objective_panel(view)
	_draw_build_strip(view)

	var boss = main_ref.get_boss()
	if boss != null:
		var boss_width := minf(500.0, view.x * 0.48)
		var boss_rect := Rect2((view.x - boss_width) * 0.5, 84.0, boss_width, 39.0)
		_draw_ornate_panel(boss_rect, Color("#a84b3c"))
		_text(boss_rect.position + Vector2(14.0, 16.0), "尸王" + (" · 暴走" if boss.hp / boss.max_hp <= 0.5 else ""), 13, Color("#e7c88a"))
		_bar(Rect2(boss_rect.position.x + 14.0, boss_rect.position.y + 23.0, boss_rect.size.x - 28.0, 7.0), boss.hp / maxf(1.0, boss.max_hp), Color("#a44439"), true)

	var controls_rect := Rect2(view.x * 0.5 - (270.0 if not _is_mobile() else 155.0), view.y - 43.0, 540.0 if not _is_mobile() else 310.0, 28.0)
	_draw_ornate_panel(controls_rect, Color("#8f805d"))
	if not _is_mobile():
		_text(Vector2(controls_rect.position.x + 17.0, controls_rect.position.y + 19.0), "WASD / 方向键  移动     ·     SPACE  镇尸诀     ·     E  治疗     ·     ESC  暂停", 12, MUTED_COLOR)
	else:
		_text(Vector2(controls_rect.position.x + 16.0, controls_rect.position.y + 19.0), "左侧移动   ·   右侧道术 / 治疗", 12, MUTED_COLOR)


func _draw_level_up(view: Vector2) -> void:
	# Keep the arena visible, but give the upgrade cards the visual weight of
	# collectible talismans rather than plain stat boxes.
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.008, 0.009, 0.008, 0.72))
	var panel_width := minf(1080.0, view.x - 28.0)
	var panel_height := minf(440.0, view.y - 24.0)
	var panel_rect := Rect2((view.x - panel_width) * 0.5, (view.y - panel_height) * 0.5, panel_width, panel_height)
	draw_rect(panel_rect, Color(0.035, 0.032, 0.027, 0.92))
	draw_rect(panel_rect, Color(0.55, 0.44, 0.28, 0.72), false, 1.2)
	draw_rect(panel_rect.grow(-7.0), Color(0.72, 0.59, 0.36, 0.12), false, 1.0)
	for corner in [panel_rect.position, Vector2(panel_rect.end.x, panel_rect.position.y), Vector2(panel_rect.position.x, panel_rect.end.y), panel_rect.end]:
		var sx := 1.0 if corner.x < view.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < view.y * 0.5 else -1.0
		draw_line(corner + Vector2(sx * 10.0, 0.0), corner + Vector2(sx * 28.0, 0.0), Color("#b69a62"), 1.0)
		draw_line(corner + Vector2(0.0, sy * 10.0), corner + Vector2(0.0, sy * 25.0), Color("#b69a62"), 1.0)
	_text(Vector2(view.x * 0.5 - 150.0, panel_rect.position.y + 49.0), "修为精进 · 选择一项", 28, Color("#f0d79b"))
	_text(Vector2(view.x * 0.5 - 210.0, panel_rect.position.y + 78.0), "择一术法，改变本局构筑方向  ·  选择期间战斗与计时暂停", 14, Color("#c7b99d"))
	draw_line(panel_rect.position + Vector2(28.0, 96.0), panel_rect.position + Vector2(panel_rect.size.x - 28.0, 96.0), Color(0.66, 0.53, 0.33, 0.58), 1.0)

	var card_width := minf(320.0, (view.x - 90.0) / 3.0 - 18.0)
	var card_height := minf(220.0, panel_height - 132.0)
	var gap := 18.0
	var total_width := card_width * 3.0 + gap * 2.0
	var start_x := (view.x - total_width) * 0.5
	var y := panel_rect.position.y + 114.0
	for i in range(mini(3, main_ref.level_cards.size())):
		var card: Dictionary = main_ref.level_cards[i]
		var rect := Rect2(start_x + i * (card_width + gap), y, card_width, card_height)
		var card_id := str(card.get("id", ""))
		var accent := _upgrade_color(card_id)
		var hovered := rect.has_point(get_viewport().get_mouse_position())
		draw_rect(rect, Color(0.055, 0.05, 0.043, 0.99))
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.95 if hovered else 0.72), false, 1.5 if hovered else 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), accent)
		draw_rect(Rect2(rect.position + Vector2(8.0, 10.0), rect.size - Vector2(16.0, 20.0)), Color(accent.r, accent.g, accent.b, 0.07 if not hovered else 0.13), false, 1.0)
		# Four short corner strokes echo the borders of a paper talisman.
		for corner in [rect.position + Vector2(8.0, 10.0), rect.position + Vector2(rect.size.x - 8.0, 10.0), rect.position + Vector2(8.0, rect.size.y - 10.0), rect.position + rect.size - Vector2(8.0, 10.0)]:
			var sx := 1.0 if corner.x < rect.position.x + rect.size.x * 0.5 else -1.0
			var sy := 1.0 if corner.y < rect.position.y + rect.size.y * 0.5 else -1.0
			draw_line(corner, corner + Vector2(sx * 9.0, 0.0), Color(accent.r, accent.g, accent.b, 0.65), 1.0)
			draw_line(corner, corner + Vector2(0.0, sy * 9.0), Color(accent.r, accent.g, accent.b, 0.65), 1.0)
		var card_kind := str(card.get("kind", ""))
		var icon_id := str(card.get("icon", card_id))
		var has_skill_illustration := card_kind in ["skill_acquire", "skill_level", "skill_branch", "skill_evolution", "element_cultivation"]
		if has_skill_illustration:
			_draw_skill_card_illustration(rect, icon_id, accent)
			_center_text(Rect2(rect.position.x + 10.0, rect.position.y + 88.0, rect.size.x - 20.0, 24.0), str(card.get("name", "未知术法")), 18, Color("#f1dba4"))
			_center_text(Rect2(rect.position.x + 10.0, rect.position.y + 109.0, rect.size.x - 20.0, 18.0), str(card.get("category", _upgrade_category(card_id))), 11, accent)
			var tag := ""
			if card_kind == "skill_evolution":
				tag = "进化"
			elif card_kind == "skill_branch":
				tag = "分支"
			elif card_kind == "element_cultivation":
				tag = "修炼"
			elif card_kind == "skill_level" and str(card.get("name", "")).begins_with("立道突破"):
				tag = "立道"
			if not tag.is_empty():
				var tag_rect := Rect2(rect.end.x - 52.0, rect.position.y + 14.0, 38.0, 16.0)
				draw_rect(tag_rect, Color(accent.r, accent.g, accent.b, 0.18))
				draw_rect(tag_rect, Color(accent.r, accent.g, accent.b, 0.75), false, 1.0)
				_center_text(tag_rect, tag, 10, accent)
			var divider_y := rect.size.y - 39.0
			var desc_rect := Rect2(rect.position.x + 17.0, rect.position.y + 132.0, rect.size.x - 34.0, divider_y - 139.0)
			_draw_wrapped_text(desc_rect, str(card.get("desc", "")), 12, TEXT_COLOR, 2)
			draw_line(rect.position + Vector2(16.0, divider_y), rect.position + Vector2(rect.size.x - 16.0, divider_y), Color("#756344", 0.8), 1.0)
			_text(Vector2(rect.position.x + 18.0, rect.end.y - 16.0), "按 %d 选择  ·  点击卡片" % (i + 1), 11, Color("#d0c1a4") if hovered else MUTED_COLOR)
		else:
			_draw_card_art(rect.position + Vector2(47.0, 62.0), icon_id, accent, 31.0)
			_text(rect.position + Vector2(88.0, 37.0), str(card.get("name", "未知强化")), 17, Color("#f1dba4"))
			_text(rect.position + Vector2(88.0, 61.0), str(card.get("category", _upgrade_category(card_id))), 12, accent)
			_draw_wrapped_text(Rect2(rect.position.x + 18.0, rect.position.y + 113.0, rect.size.x - 36.0, 45.0), str(card.get("desc", "")), 12, TEXT_COLOR, 2)
			draw_line(rect.position + Vector2(16.0, 169.0), rect.position + Vector2(rect.size.x - 16.0, 169.0), Color("#5b5140"), 1.0)
			_text(rect.position + Vector2(18.0, 198.0), "按 %d 选择  ·  点击卡片" % (i + 1), 12, Color("#d0c1a4") if hovered else MUTED_COLOR)
		if hovered:
			draw_rect(rect.grow(2.0), Color(accent.r, accent.g, accent.b, 0.42), false, 2.0)

func _draw_objective_panel(_view: Vector2) -> void:
	var objective := objective_data()
	if objective.is_empty():
		return
	var rect := Rect2(18.0, 116.0, 286.0, 70.0)
	var accent: Color = Color("#c9a65b") if objective["kind"] == "boss" else Color("#8fba9b")
	if objective["kind"] == "failed":
		accent = Color("#b45b4a")
	_draw_ornate_panel(rect, accent)
	_draw_seal(rect.position + Vector2(23.0, 25.0), "战" if objective["kind"] == "boss" else "令", accent)
	_text(rect.position + Vector2(43.0, 22.0), str(objective["title"]), 14, accent)
	_text(rect.position + Vector2(43.0, 42.0), str(objective["detail"]), 12, TEXT_COLOR)
	_bar(Rect2(rect.position.x + 14.0, rect.position.y + 56.0, rect.size.x - 28.0, 5.0), float(objective["progress"]), accent)


func _draw_build_strip(view: Vector2) -> void:
	var rect := Rect2(view.x - 258.0, 178.0, 240.0, 166.0)
	_draw_ornate_panel(rect, Color("#8b7758"))
	var build_title := "当前构筑 · 待立道"
	if not main_ref.primary_element.is_empty():
		build_title = "当前构筑 · 主修%s" % main_ref._element_name(main_ref.primary_element)
	_text(rect.position + Vector2(12.0, 17.0), build_title, 12, Color("#e7cf98"))

	var owned_skill_ids: Array = main_ref.skills.keys()
	owned_skill_ids.sort()
	for i in range(4):
		var center := rect.position + Vector2(31.0 + float(i) * 59.0, 43.0)
		if i < owned_skill_ids.size():
			var skill_id := str(owned_skill_ids[i])
			var skill_data: Dictionary = main_ref.skills[skill_id]
			var shown_id := str(skill_data.get("evolved", "")) if not str(skill_data.get("evolved", "")).is_empty() else skill_id
			_draw_card_art(center, shown_id, _upgrade_color(shown_id), 15.0)
			_text(center + Vector2(11.0, 5.0), str(skill_data.get("level", 1)), 9, TEXT_COLOR)
			_text(center + Vector2(-18.0, 25.0), _short_skill_label(skill_id, shown_id), 8, MUTED_COLOR)
		else:
			draw_circle(center, 14.0, Color(0.08, 0.075, 0.065, 0.85))
			draw_arc(center, 14.0, 0.0, TAU, 24, Color(0.55, 0.49, 0.38, 0.35), 1.0)
			draw_line(center + Vector2(-4.0, 0.0), center + Vector2(4.0, 0.0), Color(0.55, 0.49, 0.38, 0.3), 1.0)

	var artifact_ids: Array = main_ref.artifacts.keys()
	artifact_ids.sort()
	for i in range(3):
		var center := rect.position + Vector2(48.0 + float(i) * 72.0, 88.0)
		if i < artifact_ids.size():
			var artifact_id := str(artifact_ids[i])
			var artifact_data: Dictionary = main_ref.artifacts[artifact_id]
			_draw_card_art(center, artifact_id, _upgrade_color(artifact_id), 13.0)
			_text(center + Vector2(10.0, 4.0), str(artifact_data.get("level", 1)), 8, TEXT_COLOR)
		else:
			draw_circle(center, 12.0, Color(0.08, 0.075, 0.065, 0.65))
			draw_arc(center, 12.0, 0.0, TAU, 24, Color(0.55, 0.49, 0.38, 0.3), 1.0)

	var cultivation_text := "立道后主修可深修至 Lv3" if main_ref.primary_element.is_empty() else "元素修炼 Lv%d / 3" % int(main_ref.element_cultivation_levels.get(main_ref.primary_element, 0))
	_text(rect.position + Vector2(12.0, 130.0), cultivation_text, 9, _upgrade_color("cultivation_" + main_ref.primary_element) if not main_ref.primary_element.is_empty() else MUTED_COLOR)
	var general_text := "身法 %d  纳气 %d  广纳 %d  强身 %d" % [
		int(main_ref.general_upgrade_levels.get("swift_step", 0)),
		int(main_ref.general_upgrade_levels.get("spirit_gain", 0)),
		int(main_ref.general_upgrade_levels.get("spirit_sense", 0)),
		int(main_ref.general_upgrade_levels.get("vitality", 0))
	]
	_text(rect.position + Vector2(12.0, 148.0), general_text, 8, MUTED_COLOR)


func _short_skill_label(skill_id: String, shown_id: String) -> String:
	if shown_id == "ice_array":
		return "冰魄阵"
	if shown_id == "five_thunder":
		return "五雷敕令"
	match skill_id:
		"fire_talisman":
			return "火符"
		"thunder_talisman":
			return "雷符"
		"copper_coin_sword":
			return "铜剑"
		"peachwood_sword":
			return "桃剑"
		"water_array":
			return "水阵"
		"earth_formation":
			return "地脉"
	return "术法"


func _draw_ornate_panel(rect: Rect2, accent: Color) -> void:
	draw_rect(rect, Color(0.055, 0.052, 0.045, 0.94))
	draw_rect(rect, Color("#64563e"), false, 1.0)
	draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), rect.size - Vector2(6.0, 6.0)), Color(0.72, 0.60, 0.39, 0.10), false, 1.0)
	draw_line(rect.position + Vector2(8.0, 1.0), rect.position + Vector2(29.0, 1.0), accent, 2.0)
	var x := rect.position.x
	var y := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var corner := 9.0
	draw_line(Vector2(x + 4.0, y + corner), Vector2(x + 4.0, y + 4.0), accent, 1.0)
	draw_line(Vector2(x + 4.0, y + 4.0), Vector2(x + corner, y + 4.0), accent, 1.0)
	draw_line(Vector2(right - corner, y + 4.0), Vector2(right - 4.0, y + 4.0), accent, 1.0)
	draw_line(Vector2(right - 4.0, y + 4.0), Vector2(right - 4.0, y + corner), accent, 1.0)
	draw_line(Vector2(x + 4.0, bottom - corner), Vector2(x + 4.0, bottom - 4.0), accent, 1.0)
	draw_line(Vector2(x + 4.0, bottom - 4.0), Vector2(x + corner, bottom - 4.0), accent, 1.0)
	draw_line(Vector2(right - corner, bottom - 4.0), Vector2(right - 4.0, bottom - 4.0), accent, 1.0)
	draw_line(Vector2(right - 4.0, bottom - corner), Vector2(right - 4.0, bottom - 4.0), accent, 1.0)


func _draw_seal(center: Vector2, label: String, accent: Color) -> void:
	draw_circle(center, 11.0, Color("#211c16"))
	draw_arc(center, 11.0, 0.0, TAU, 32, accent, 1.3)
	draw_arc(center, 7.5, 0.0, TAU, 24, Color(accent.r, accent.g, accent.b, 0.45), 1.0)
	_text(center + Vector2(-5.0, 4.0), label, 10, accent)


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
	draw_circle(center, 13.0, Color("#211c16"))
	draw_arc(center, 13.0, 0.0, TAU, 32, color, 2.0 if ready else 1.0)
	var talisman := PackedVector2Array([
		center + Vector2(-5.0, -8.0), center + Vector2(5.0, -8.0),
		center + Vector2(6.0, 7.0), center + Vector2(-6.0, 7.0)
	])
	draw_colored_polygon(talisman, Color("#d7b86c"))
	draw_line(center + Vector2(-3.0, -4.0), center + Vector2(3.0, -1.0), Color("#6b352b"), 1.0)
	draw_line(center + Vector2(-3.0, 1.0), center + Vector2(3.0, 4.0), Color("#6b352b"), 1.0)


func _draw_skill_card_illustration(card_rect: Rect2, icon_id: String, accent: Color) -> void:
	# A skill card is an illustrated talisman / weapon vignette, never a character portrait.
	var art_height := minf(80.0, card_rect.size.y * 0.37)
	var art_rect := Rect2(card_rect.position + Vector2(12.0, 9.0), Vector2(card_rect.size.x - 24.0, art_height))
	var center := art_rect.get_center()
	draw_rect(art_rect, Color(0.018, 0.016, 0.014, 0.96))
	draw_rect(art_rect, Color(accent.r, accent.g, accent.b, 0.32), false, 1.0)
	draw_rect(art_rect.grow(-4.0), Color(accent.r, accent.g, accent.b, 0.08), false, 1.0)
	# Layered rings and fine strokes create the restrained glow seen in the approved concept.
	draw_circle(center, art_height * 0.39, Color(accent.r, accent.g, accent.b, 0.08))
	draw_arc(center, art_height * 0.43, PI * 0.08, PI * 0.92, 40, Color(accent.r, accent.g, accent.b, 0.7), 1.0)
	draw_arc(center, art_height * 0.43, PI * 1.08, PI * 1.92, 40, Color("#d6b56c", 0.48), 1.0)
	for i in range(5):
		var px := art_rect.position.x + 12.0 + float(i) * (art_rect.size.x - 24.0) / 4.0
		draw_circle(Vector2(px, art_rect.position.y + 7.0), 1.0, Color(accent.r, accent.g, accent.b, 0.62))
	var art_region := _skill_art_region(icon_id)
	var art_texture: Texture2D = SKILL_ART_ATLAS
	if icon_id.begins_with("cultivation_"):
		art_region = _cultivation_art_region(icon_id)
		art_texture = ELEMENT_CULTIVATION_ATLAS
	var icon_size := minf(78.0, art_height + 5.0)
	if art_region.size.x > 0.0:
		draw_texture_rect_region(art_texture, Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), art_region, Color.WHITE, false)
	else:
		_draw_card_art(center, icon_id, accent, 28.0)
	# Thin gold rules and seal-like corner marks make each art panel feel collectible.
	for corner in [art_rect.position + Vector2(5.0, 5.0), Vector2(art_rect.end.x - 5.0, art_rect.position.y + 5.0), Vector2(art_rect.position.x + 5.0, art_rect.end.y - 5.0), art_rect.end - Vector2(5.0, 5.0)]:
		var sx := 1.0 if corner.x < center.x else -1.0
		var sy := 1.0 if corner.y < center.y else -1.0
		draw_line(corner, corner + Vector2(7.0 * sx, 0.0), Color("#d7b76f", 0.72), 1.0)
		draw_line(corner, corner + Vector2(0.0, 7.0 * sy), Color("#d7b76f", 0.72), 1.0)


func _center_text(rect: Rect2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + size), value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


func _draw_wrapped_text(rect: Rect2, value: String, size: int, color: Color, max_lines: int = 2) -> void:
	var lines: Array[String] = []
	var current := ""
	for character in value:
		var candidate := current + character
		if not current.is_empty() and ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > rect.size.x:
			lines.append(current)
			current = character
			if lines.size() >= max_lines:
				break
		else:
			current = candidate
	if lines.size() < max_lines and not current.is_empty():
		lines.append(current)
	for i in range(lines.size()):
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + size + float(i) * (size + 3)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, color)


func _draw_card_art(center: Vector2, icon_id: String, accent: Color, radius: float = 24.0) -> void:
	var scale_factor := radius / 24.0
	draw_set_transform(center, 0.0, Vector2(scale_factor, scale_factor))
	draw_circle(Vector2.ZERO, 24.0, Color(0.055, 0.05, 0.042, 0.98))
	draw_circle(Vector2.ZERO, 20.5, Color(accent.r, accent.g, accent.b, 0.10))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, 0.92), 1.7)
	var art_region := _skill_art_region(icon_id)
	if art_region.size.x > 0.0:
		draw_texture_rect_region(SKILL_ART_ATLAS, Rect2(-20.0, -20.0, 40.0, 40.0), art_region, Color.WHITE, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	if icon_id.contains("fire"):
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -15.0), Vector2(9.0, -3.0), Vector2(7.0, 9.0), Vector2(0.0, 15.0), Vector2(-7.0, 8.0), Vector2(-8.0, -2.0)]), Color("#d9784d"))
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -6.0), Vector2(4.0, 2.0), Vector2(0.0, 9.0), Vector2(-3.0, 2.0)]), Color("#f2d18a"))
	elif icon_id.contains("thunder_seal"):
		draw_circle(Vector2.ZERO, 15.0, Color("#9c7947"))
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color("#e5ca77"), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(3.0, -11.0), Vector2(-5.0, 1.0), Vector2(0.0, 1.0), Vector2(-2.0, 10.0), Vector2(6.0, -3.0), Vector2(2.0, -3.0)]), Color("#f5e19a"))
	elif icon_id.contains("thunder") or icon_id.contains("five_thunder"):
		draw_colored_polygon(PackedVector2Array([Vector2(4.0, -17.0), Vector2(-8.0, 1.0), Vector2(-2.0, 1.0), Vector2(-5.0, 16.0), Vector2(9.0, -4.0), Vector2(3.0, -4.0)]), Color("#e7cf69"))
		draw_line(Vector2(4.0, -17.0), Vector2(-8.0, 1.0), Color("#fff3b0"), 1.0)
	elif icon_id.contains("copper_coin") or icon_id.contains("coin"):
		draw_circle(Vector2.ZERO, 14.0, Color("#bd8b43"))
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 36, Color("#f1d18a"), 2.0)
		draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), Color("#3b3021"))
		draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 28, Color("#8d6736"), 1.0)
	elif icon_id.contains("peachwood") or icon_id.contains("sword_manual"):
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -17.0), Vector2(4.0, -5.0), Vector2(2.0, 10.0), Vector2(-2.0, 10.0), Vector2(-4.0, -5.0)]), Color("#d7c7a2"))
		draw_line(Vector2(-8.0, 3.0), Vector2(8.0, 3.0), Color("#a65d40"), 3.0)
		draw_line(Vector2(0.0, 10.0), Vector2(0.0, 16.0), Color("#a65d40"), 3.0)
	elif icon_id.contains("water_array") or icon_id.contains("ice_array") or icon_id.contains("cold_relic"):
		if icon_id.contains("ice") or icon_id.contains("cold"):
			for i in range(6):
				var angle := TAU * float(i) / 6.0
				draw_line(Vector2(cos(angle), sin(angle)) * 3.0, Vector2(cos(angle), sin(angle)) * 15.0, Color("#8fd4eb"), 2.0)
			draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color("#c6eff7"), 1.3)
		else:
			draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 36, Color("#62b7d1"), 2.0)
			draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 32, Color("#8ad8e6"), 1.7)
			draw_line(Vector2(-12.0, 4.0), Vector2(12.0, 4.0), Color("#8ad8e6"), 1.5)
	elif icon_id.contains("earth") or icon_id.contains("formation_manual"):
		draw_colored_polygon(PackedVector2Array([Vector2(-17.0, 11.0), Vector2(-8.0, -4.0), Vector2(-1.0, 4.0), Vector2(7.0, -12.0), Vector2(17.0, 11.0)]), Color("#93845a"))
		draw_line(Vector2(-17.0, 13.0), Vector2(17.0, 13.0), Color("#d0b979"), 2.0)
		draw_arc(Vector2.ZERO, 18.0, PI * 0.12, PI * 0.88, 28, Color("#c4ad70"), 1.2)
	elif icon_id.contains("talisman_scroll") or icon_id.contains("control_art") or icon_id.contains("active_skill"):
		draw_colored_polygon(PackedVector2Array([Vector2(-9.0, -16.0), Vector2(9.0, -16.0), Vector2(8.0, 15.0), Vector2(-8.0, 15.0)]), Color("#d6b968"))
		draw_line(Vector2(-4.0, -8.0), Vector2(4.0, -4.0), Color("#813d30"), 2.0)
		draw_line(Vector2(-4.0, 0.0), Vector2(4.0, 4.0), Color("#813d30"), 2.0)
		draw_line(Vector2(-3.0, 8.0), Vector2(3.0, 6.0), Color("#813d30"), 1.5)
	elif icon_id.contains("body_jade") or icon_id.contains("vitality"):
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -15.0), Vector2(12.0, -7.0), Vector2(10.0, 8.0), Vector2(0.0, 16.0), Vector2(-10.0, 8.0), Vector2(-12.0, -7.0)]), Color("#c17a65") if icon_id.contains("vitality") else Color("#6ebba0"))
		draw_polyline(PackedVector2Array([Vector2(0.0, -15.0), Vector2(12.0, -7.0), Vector2(10.0, 8.0), Vector2(0.0, 16.0), Vector2(-10.0, 8.0), Vector2(-12.0, -7.0), Vector2(0.0, -15.0)]), Color("#e3d4a0"), 1.0, true)
	elif icon_id.contains("swift_step"):
		draw_line(Vector2(-13.0, 8.0), Vector2(4.0, -5.0), Color("#c17a65"), 4.0)
		draw_line(Vector2(-4.0, 11.0), Vector2(13.0, -2.0), Color("#e7b48a"), 3.0)
		draw_line(Vector2(1.0, -11.0), Vector2(13.0, -2.0), Color("#e7b48a"), 2.0)
	elif icon_id.contains("spirit_gain"):
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -16.0), Vector2(10.0, -2.0), Vector2(8.0, 8.0), Vector2(0.0, 14.0), Vector2(-8.0, 8.0), Vector2(-10.0, -2.0)]), Color("#6ebba0"))
		draw_arc(Vector2(0.0, 3.0), 5.0, 0.0, TAU, 24, Color("#d3f3df"), 1.4)
	elif icon_id.contains("spirit_sense"):
		draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 28, Color("#6ebba0"), 2.0)
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, Color("#8dd4ba"), 1.5)
		draw_circle(Vector2.ZERO, 2.5, Color("#d3f3df"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -14.0), Vector2(4.0, -5.0), Vector2(14.0, -4.0), Vector2(6.0, 3.0), Vector2(9.0, 13.0), Vector2(0.0, 7.0), Vector2(-9.0, 13.0), Vector2(-6.0, 3.0), Vector2(-14.0, -4.0), Vector2(-4.0, -5.0)]), accent)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _skill_art_region(icon_id: String) -> Rect2:
	if icon_id.contains("fire"):
		return Rect2(0.0, 0.0, 128.0, 128.0)
	if icon_id.contains("thunder"):
		return Rect2(128.0, 0.0, 128.0, 128.0)
	if icon_id.contains("copper_coin") or icon_id.contains("coin"):
		return Rect2(256.0, 0.0, 128.0, 128.0)
	if icon_id.contains("peachwood") or icon_id.contains("sword_manual"):
		return Rect2(384.0, 0.0, 128.0, 128.0)
	if icon_id.contains("water") or icon_id.contains("ice") or icon_id.contains("cold_relic"):
		return Rect2(512.0, 0.0, 128.0, 128.0)
	if icon_id.contains("earth") or icon_id.contains("formation_manual"):
		return Rect2(640.0, 0.0, 128.0, 128.0)
	return Rect2()


func _cultivation_art_region(icon_id: String) -> Rect2:
	if icon_id.contains("metal"):
		return Rect2(0.0, 0.0, 128.0, 128.0)
	if icon_id.contains("wood"):
		return Rect2(128.0, 0.0, 128.0, 128.0)
	if icon_id.contains("water"):
		return Rect2(256.0, 0.0, 128.0, 128.0)
	if icon_id.contains("fire"):
		return Rect2(384.0, 0.0, 128.0, 128.0)
	if icon_id.contains("earth"):
		return Rect2(512.0, 0.0, 128.0, 128.0)
	if icon_id.contains("thunder"):
		return Rect2(640.0, 0.0, 128.0, 128.0)
	return Rect2()


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
	var normalized := upgrade_id
	normalized = normalized.trim_prefix("acquire_").trim_prefix("upgrade_").trim_prefix("general_")
	normalized = normalized.trim_prefix("branch_")
	if normalized.contains("fire"):
		return Color("#d9784d")
	if normalized.contains("metal"):
		return Color("#d7b76f")
	if normalized.contains("wood"):
		return Color("#80b98a")
	if normalized.contains("thunder") or normalized.contains("five_thunder"):
		return Color("#7988ff")
	if normalized.contains("copper_coin") or normalized.contains("peachwood") or normalized.contains("sword_manual"):
		return Color("#c9a66a")
	if normalized.contains("water") or normalized.contains("ice") or normalized.contains("cold_relic"):
		return Color("#69b9d0")
	if normalized.contains("earth") or normalized.contains("formation_manual"):
		return Color("#b2a071")
	if normalized.contains("body_jade") or normalized.contains("vitality"):
		return Color("#c17a65")
	if normalized.contains("swift_step"):
		return Color("#c17a65")
	if normalized.contains("spirit"):
		return Color("#6ebba0")
	if normalized.contains("control") or normalized.contains("active_skill"):
		return Color("#a995d0")
	if normalized.contains("talisman_scroll"):
		return Color("#d9b65f")
	return PANEL_EDGE


func _upgrade_category(upgrade_id: String) -> String:
	if upgrade_id.begins_with("cultivation_"):
		return "元素修炼"
	if upgrade_id.begins_with("branch_"):
		return "Lv3 关键分支"
	if upgrade_id.begins_with("evolve_"):
		return "技能进化"
	if upgrade_id.begins_with("active_skill"):
		return "主动道术"
	if upgrade_id.begins_with("general_") or upgrade_id in ["swift_step", "spirit_gain", "spirit_sense", "vitality"]:
		return "通用强化"
	if upgrade_id.contains("relic") or upgrade_id.contains("seal") or upgrade_id.contains("manual") or upgrade_id.contains("scroll") or upgrade_id.contains("body_jade"):
		return "被动法器"
	if upgrade_id.contains("fire") or upgrade_id.contains("thunder") or upgrade_id.contains("sword") or upgrade_id.contains("water") or upgrade_id.contains("earth") or upgrade_id.contains("peachwood") or upgrade_id.contains("copper_coin"):
		return "攻击技能"
	if upgrade_id == "control_art":
		return "主动道术"
	return "修行强化"


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
	var panel_height := minf(440.0, view.y - 24.0)
	var card_width := minf(320.0, (view.x - 90.0) / 3.0 - 18.0)
	var card_height := minf(220.0, panel_height - 132.0)
	var gap := 18.0
	var total_width := card_width * 3.0 + gap * 2.0
	var start_x := (view.x - total_width) * 0.5
	var y := (view.y - panel_height) * 0.5 + 114.0
	for i in range(mini(3, main_ref.level_cards.size())):
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
