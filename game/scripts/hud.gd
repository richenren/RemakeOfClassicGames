extends Node2D

const SKILL_ART_ATLAS: Texture2D = preload("res://assets/sprites/skill_art_atlas.svg")
const ELEMENT_CULTIVATION_ATLAS: Texture2D = preload("res://assets/sprites/element_cultivation_atlas.svg")
const PLAYER_PORTRAIT_TEXTURE: Texture2D = preload("res://assets/sprites/player_portrait.svg")

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

	var layout := _hud_layout(view)
	var scale: float = layout["scale"]
	var status_rect: Rect2 = layout["status"]
	_draw_ornate_panel(status_rect, Color("#c6a566"))

	# Character portrait anchors the HUD and makes the actual player identity visible.
	var portrait_size := clampf(54.0 * scale, 38.0, 54.0)
	var portrait_center := status_rect.position + Vector2(12.0 * scale + portrait_size * 0.5, status_rect.size.y * 0.5)
	draw_circle(portrait_center, portrait_size * 0.54, Color("#0b0e10"))
	draw_arc(portrait_center, portrait_size * 0.55, 0.0, TAU, 48, Color("#d5ad61"), 2.0 * scale)
	draw_texture_rect(PLAYER_PORTRAIT_TEXTURE, Rect2(portrait_center - Vector2(portrait_size, portrait_size) * 0.5, Vector2(portrait_size, portrait_size)), false)
	var info_x := status_rect.position.x + portrait_size + 22.0 * scale
	_text(Vector2(info_x, status_rect.position.y + 22.0 * scale), "镇邪录 · 破败义庄", maxi(11, roundi(16.0 * scale)), Color("#e7cf98"))
	_draw_seal(Vector2(status_rect.end.x - 15.0 * scale, status_rect.position.y + 19.0 * scale), "令", Color("#b34a3d"))
	_text(Vector2(info_x, status_rect.position.y + 43.0 * scale), "生命  %d / %d" % [roundi(player.hp), roundi(player.max_hp)], maxi(10, roundi(13.0 * scale)), TEXT_COLOR)
	var hp_bar_width := maxf(50.0, status_rect.end.x - info_x - 12.0 * scale)
	_bar(Rect2(info_x, status_rect.position.y + 51.0 * scale, hp_bar_width, 7.0 * scale), player.hp / maxf(1.0, player.max_hp), Color("#c54e42"), true)
	_text(Vector2(info_x, status_rect.position.y + 76.0 * scale), "等级 %d   ·   击杀 %d" % [player.level, main_ref.kills], maxi(9, roundi(12.0 * scale)), MUTED_COLOR)

	var time_rect: Rect2 = layout["time"]
	_draw_ornate_panel(time_rect, Color("#b69a62"))
	_text(Vector2(time_rect.position.x + 12.0 * scale, time_rect.position.y + 21.0 * scale), "生存时间  %s" % _format_time(main_ref.elapsed_seconds), maxi(10, roundi(16.0 * scale)), TEXT_COLOR)
	if _is_mobile():
		_text(Vector2(time_rect.end.x - 20.0 * scale, time_rect.position.y + 21.0 * scale), "Ⅱ", maxi(12, roundi(18.0 * scale)), Color("#e8c86c"))
	_text(Vector2(time_rect.position.x + 12.0 * scale, time_rect.position.y + 41.0 * scale), "灵气 %d / %d" % [player.xp, player.xp_to_next], maxi(9, roundi(12.0 * scale)), MUTED_COLOR)
	var xp_bar_x := time_rect.position.x + time_rect.size.x * 0.48
	_bar(Rect2(xp_bar_x, time_rect.position.y + 31.0 * scale, maxf(28.0, time_rect.end.x - xp_bar_x - 12.0 * scale), 6.0 * scale), float(player.xp) / maxf(1.0, float(player.xp_to_next)), Color("#6ebba0"))

	var skill_panel: Rect2 = layout["skill"]
	_draw_ornate_panel(skill_panel, Color("#c6a566"))
	_text(skill_panel.position + Vector2(12.0 * scale, 19.0 * scale), "基础符箓", maxi(10, roundi(15.0 * scale)), TEXT_COLOR)
	_text(skill_panel.position + Vector2(12.0 * scale, 39.0 * scale), "伤害  %d" % roundi(player.damage), maxi(9, roundi(12.5 * scale)), MUTED_COLOR)
	_text(skill_panel.position + Vector2(12.0 * scale, 57.0 * scale), "攻击间隔  %.2fs" % player.attack_interval, maxi(9, roundi(12.5 * scale)), MUTED_COLOR)
	var skill_ready: bool = main_ref.active_skill_cooldown <= 0.0
	var skill_color := Color("#e8c86c") if skill_ready else Color("#9e8b6a")
	_draw_skill_emblem(Vector2(skill_panel.end.x - 21.0 * scale, skill_panel.position.y + 80.0 * scale), skill_ready, skill_color)
	_text(skill_panel.position + Vector2(12.0 * scale, 78.0 * scale), "主动道术 · 镇尸诀 Lv%d" % main_ref.active_skill_level, maxi(9, roundi(12.0 * scale)), skill_color)
	_text(skill_panel.position + Vector2(12.0 * scale, 96.0 * scale), "就绪" if skill_ready else "冷却 %ds" % ceili(main_ref.active_skill_cooldown), maxi(9, roundi(11.0 * scale)), TEXT_COLOR)
	var skill_ratio := 1.0 if skill_ready else 1.0 - clampf(main_ref.active_skill_cooldown / maxf(0.1, main_ref.active_skill_base_cooldown), 0.0, 1.0)
	_bar(Rect2(skill_panel.position.x + 12.0 * scale, skill_panel.position.y + 103.0 * scale, skill_panel.size.x * 0.58, 5.0 * scale), skill_ratio, Color("#d1a84e"))
	_text(skill_panel.position + Vector2(12.0 * scale, 121.0 * scale), "治疗次数  %d/2" % main_ref.heal_charges, maxi(9, roundi(11.0 * scale)), MUTED_COLOR)

	if main_ref.state != "game_over" and main_ref.state != "victory":
		_draw_objective_panel(view)
	_draw_build_strip(view)

	var boss = main_ref.get_boss()
	if boss != null:
		var boss_rect: Rect2 = layout["boss"]
		_draw_ornate_panel(boss_rect, Color("#a84b3c"))
		_text(boss_rect.position + Vector2(12.0 * scale, 16.0 * scale), "尸王" + (" · 暴走" if boss.hp / boss.max_hp <= 0.5 else ""), maxi(10, roundi(13.0 * scale)), Color("#e7c88a"))
		_bar(Rect2(boss_rect.position.x + 12.0 * scale, boss_rect.position.y + 23.0 * scale, boss_rect.size.x - 24.0 * scale, 6.0 * scale), boss.hp / maxf(1.0, boss.max_hp), Color("#a44439"), true)

	var controls_rect: Rect2 = layout["controls"]
	_draw_ornate_panel(controls_rect, Color("#8f805d"))
	if not _is_mobile():
		_center_text(controls_rect, "WASD / 方向键 移动   ·   SPACE 镇尸诀   ·   E 治疗   ·   ESC 暂停", maxi(8, roundi(11.0 * scale)), MUTED_COLOR)
	else:
		_center_text(controls_rect, "左侧移动   ·   右侧道术 / 治疗", maxi(8, roundi(11.0 * scale)), MUTED_COLOR)

func _draw_level_up(view: Vector2) -> void:
	var layout := _level_up_layout(view)
	var panel_rect: Rect2 = layout["panel"]
	var card_rects: Array = layout["cards"]
	var scale: float = layout["scale"]
	var header_title_size := maxi(16, roundi(28.0 * scale))
	var subtitle_size := maxi(9, roundi(14.0 * scale))

	# Dim the live battle without hiding the cemetery scene and player silhouette.
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.006, 0.009, 0.014, 0.61))
	draw_rect(panel_rect, Color("#0b0a09", 0.96))
	draw_rect(panel_rect, Color("#c6a15b", 0.92), false, 1.6 * scale)
	draw_rect(panel_rect.grow(-7.0 * scale), Color("#8d7145", 0.24), false, 1.0 * scale)
	draw_rect(Rect2(panel_rect.position + Vector2(12.0 * scale, 12.0 * scale), panel_rect.size - Vector2(24.0 * scale, 24.0 * scale)), Color("#2a2015", 0.18), false, 1.0 * scale)

	# Ornate corner brackets and cloud curls reproduce the approved Chinese-fantasy frame.
	for corner in [panel_rect.position, Vector2(panel_rect.end.x, panel_rect.position.y), Vector2(panel_rect.position.x, panel_rect.end.y), panel_rect.end]:
		var sx := 1.0 if corner.x < view.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < view.y * 0.5 else -1.0
		draw_line(corner + Vector2(sx * 8.0 * scale, 0.0), corner + Vector2(sx * 29.0 * scale, 0.0), Color("#e4bd70"), 1.4 * scale)
		draw_line(corner + Vector2(0.0, sy * 8.0 * scale), corner + Vector2(0.0, sy * 27.0 * scale), Color("#e4bd70"), 1.4 * scale)
		draw_arc(corner + Vector2(sx * 13.0 * scale, sy * 13.0 * scale), 7.0 * scale, 0.0, TAU, 20, Color("#a9834c", 0.8), 1.0 * scale)

	_draw_cloud_motif(panel_rect.position + Vector2(74.0 * scale, 49.0 * scale), scale, Color("#b39a6b", 0.45))
	_draw_cloud_motif(Vector2(panel_rect.end.x - 74.0 * scale, panel_rect.position.y + 49.0 * scale), scale, Color("#b39a6b", 0.45))
	_center_text(Rect2(panel_rect.position.x + 24.0 * scale, panel_rect.position.y + 17.0 * scale, panel_rect.size.x - 48.0 * scale, 42.0 * scale), "修为精进 · 选择一项", header_title_size, Color("#f3d99a"))
	_center_text(Rect2(panel_rect.position.x + 20.0 * scale, panel_rect.position.y + 59.0 * scale, panel_rect.size.x - 40.0 * scale, 25.0 * scale), "择一道法，改变本局构筑方向  ·  选择期间战斗与计时暂停", subtitle_size, Color("#cbbd9e"))
	var divider_y := panel_rect.position.y + float(layout["header_height"]) - 8.0 * scale
	draw_line(Vector2(panel_rect.position.x + 28.0 * scale, divider_y), Vector2(panel_rect.end.x - 28.0 * scale, divider_y), Color("#b08d50", 0.78), 1.1 * scale)
	draw_circle(Vector2(panel_rect.get_center().x, divider_y), 3.0 * scale, Color("#e6c779"))

	for i in range(mini(3, main_ref.level_cards.size())):
		var card: Dictionary = main_ref.level_cards[i]
		var rect: Rect2 = card_rects[i]
		var card_id := str(card.get("id", ""))
		var card_kind := str(card.get("kind", ""))
		var icon_id := str(card.get("icon", card_id))
		var accent := _upgrade_color(card_id)
		var hovered := rect.has_point(get_viewport().get_mouse_position())
		var border_alpha := 1.0 if hovered else 0.88
		draw_rect(rect, Color("#100d0b", 0.99))
		draw_rect(rect, Color(accent.r, accent.g, accent.b, border_alpha), false, 1.6 * scale if hovered else 1.1 * scale)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0 * scale)), accent)
		draw_rect(rect.grow(-6.0 * scale), Color(accent.r, accent.g, accent.b, 0.07), false, 1.0 * scale)
		for corner in [rect.position + Vector2(8.0, 10.0) * scale, Vector2(rect.end.x - 8.0 * scale, rect.position.y + 10.0 * scale), Vector2(rect.position.x + 8.0 * scale, rect.end.y - 10.0 * scale), rect.end - Vector2(8.0, 10.0) * scale]:
			var sx := 1.0 if corner.x < rect.get_center().x else -1.0
			var sy := 1.0 if corner.y < rect.get_center().y else -1.0
			draw_line(corner, corner + Vector2(sx * 10.0 * scale, 0.0), Color(accent.r, accent.g, accent.b, 0.85), 1.1 * scale)
			draw_line(corner, corner + Vector2(0.0, sy * 10.0 * scale), Color(accent.r, accent.g, accent.b, 0.85), 1.1 * scale)

		var art_height := minf(176.0 * scale, rect.size.y * 0.45)
		var art_rect := Rect2(rect.position + Vector2(8.0, 8.0) * scale, Vector2(rect.size.x - 16.0 * scale, art_height))
		_draw_skill_card_illustration(art_rect, icon_id, accent)

		var tag := "攻击"
		if card_kind == "skill_evolution":
			tag = "进化"
		elif card_kind == "skill_branch":
			tag = "分支"
		elif card_kind == "element_cultivation":
			tag = "修炼"
		elif card_kind in ["artifact_acquire", "artifact_level"]:
			tag = "法宝"
		elif card_kind in ["general_upgrade", "active_skill_upgrade"]:
			tag = "强化"
		var tag_rect := Rect2(art_rect.end.x - 23.0 * scale, art_rect.position.y + 12.0 * scale, 17.0 * scale, 62.0 * scale)
		draw_rect(tag_rect, Color("#1b120c", 0.86))
		draw_rect(tag_rect, Color(accent.r, accent.g, accent.b, 0.92), false, 1.0 * scale)
		for char_index in range(tag.length()):
			_center_text(Rect2(tag_rect.position.x, tag_rect.position.y + (5.0 + char_index * 14.0) * scale, tag_rect.size.x, 13.0 * scale), tag.substr(char_index, 1), maxi(8, roundi(10.0 * scale)), accent)

		var title_text := str(card.get("name", "未知术法"))
		var title_size := maxi(11, roundi(18.0 * scale))
		while title_size > 10 and ThemeDB.fallback_font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size).x > rect.size.x - 26.0 * scale:
			title_size -= 1
		var title_y := art_rect.end.y + 6.0 * scale
		_center_text(Rect2(rect.position.x + 12.0 * scale, title_y, rect.size.x - 24.0 * scale, 23.0 * scale), title_text, title_size, Color("#f0d79b"))
		_center_text(Rect2(rect.position.x + 12.0 * scale, title_y + 22.0 * scale, rect.size.x - 24.0 * scale, 17.0 * scale), str(card.get("category", _upgrade_category(card_id))), maxi(8, roundi(11.0 * scale)), accent)

		var footer_y := rect.end.y - 14.0 * scale
		var divider_y_card := rect.end.y - 58.0 * scale
		var desc_y := title_y + 42.0 * scale
		var desc_height := maxf(20.0 * scale, divider_y_card - desc_y - 8.0 * scale)
		_draw_wrapped_text(Rect2(rect.position.x + 15.0 * scale, desc_y, rect.size.x - 30.0 * scale, desc_height), str(card.get("desc", "")), maxi(9, roundi(12.0 * scale)), TEXT_COLOR, 2)
		draw_line(Vector2(rect.position.x + 14.0 * scale, divider_y_card), Vector2(rect.end.x - 14.0 * scale, divider_y_card), Color("#8e7449", 0.75), 1.0 * scale)
		draw_colored_polygon(PackedVector2Array([
			Vector2(rect.position.x + 18.0 * scale, divider_y_card + 17.0 * scale),
			Vector2(rect.position.x + 23.0 * scale, divider_y_card + 12.0 * scale),
			Vector2(rect.position.x + 28.0 * scale, divider_y_card + 17.0 * scale),
			Vector2(rect.position.x + 23.0 * scale, divider_y_card + 22.0 * scale)
		]), Color("#e5bd70"))
		_text(Vector2(rect.position.x + 34.0 * scale, divider_y_card + 21.0 * scale), _card_effect_line(card), maxi(8, roundi(11.0 * scale)), Color("#d9c59d"))
		_center_text(Rect2(rect.position.x + 8.0 * scale, footer_y - 2.0 * scale, rect.size.x - 16.0 * scale, 13.0 * scale), "按 %d 选择  ·  点击卡片" % (i + 1), maxi(8, roundi(10.5 * scale)), Color("#c8b99a") if hovered else MUTED_COLOR)
		if hovered:
			draw_rect(rect.grow(2.0 * scale), Color(accent.r, accent.g, accent.b, 0.45), false, 2.0 * scale)

func _draw_objective_panel(view: Vector2) -> void:
	var objective := objective_data()
	if objective.is_empty():
		return
	var layout := _hud_layout(view)
	var scale: float = layout["scale"]
	var rect: Rect2 = layout["objective"]
	var accent: Color = Color("#c9a65b") if objective["kind"] == "boss" else Color("#8fba9b")
	if objective["kind"] == "failed":
		accent = Color("#b45b4a")
	_draw_ornate_panel(rect, accent)
	_draw_seal(rect.position + Vector2(22.0 * scale, 23.0 * scale), "战" if objective["kind"] == "boss" else "令", accent)
	var text_x := rect.position.x + 42.0 * scale
	_text(Vector2(text_x, rect.position.y + 21.0 * scale), str(objective["title"]), maxi(9, roundi(13.0 * scale)), accent)
	_text(Vector2(text_x, rect.position.y + 40.0 * scale), str(objective["detail"]), maxi(8, roundi(11.0 * scale)), TEXT_COLOR)
	_bar(Rect2(rect.position.x + 13.0 * scale, rect.end.y - 13.0 * scale, rect.size.x - 26.0 * scale, 5.0 * scale), float(objective["progress"]), accent)

func _draw_build_strip(view: Vector2) -> void:
	var layout := _hud_layout(view)
	var scale: float = layout["scale"]
	var rect: Rect2 = layout["build"]
	_draw_ornate_panel(rect, Color("#8b7758"))
	var build_title := "当前构筑 · 待立道"
	if not main_ref.primary_element.is_empty():
		build_title = "当前构筑 · 主修%s" % main_ref._element_name(main_ref.primary_element)
	_text(rect.position + Vector2(11.0 * scale, 17.0 * scale), build_title, maxi(9, roundi(12.0 * scale)), Color("#e7cf98"))

	var owned_skill_ids: Array = []
	for skill_variant in main_ref.AUTO_SKILL_DEFS.keys():
		var skill_id := str(skill_variant)
		if main_ref.skills.has(skill_id):
			owned_skill_ids.append(skill_id)
	var skill_slot_count := 4
	var usable_width := rect.size.x - 44.0 * scale
	for i in range(skill_slot_count):
		var center := rect.position + Vector2(22.0 * scale + float(i) * usable_width / 3.0, 43.0 * scale)
		if i < owned_skill_ids.size():
			var skill_id := str(owned_skill_ids[i])
			var skill_data: Dictionary = main_ref.skills[skill_id]
			var shown_id := str(skill_data.get("evolved", "")) if not str(skill_data.get("evolved", "")).is_empty() else skill_id
			_draw_card_art(center, shown_id, _upgrade_color(shown_id), 14.0 * scale)
			_text(center + Vector2(10.0 * scale, 4.0 * scale), str(skill_data.get("level", 1)), maxi(7, roundi(9.0 * scale)), TEXT_COLOR)
			_center_text(Rect2(center.x - 26.0 * scale, center.y + 17.0 * scale, 52.0 * scale, 13.0 * scale), _short_skill_label(skill_id, shown_id), maxi(7, roundi(8.5 * scale)), MUTED_COLOR)
		else:
			draw_circle(center, 13.0 * scale, Color(0.08, 0.075, 0.065, 0.85))
			draw_arc(center, 13.0 * scale, 0.0, TAU, 24, Color(0.55, 0.49, 0.38, 0.35), 1.0 * scale)

	var artifact_ids: Array = []
	for artifact_variant in main_ref.ARTIFACT_DEFS.keys():
		var artifact_id := str(artifact_variant)
		if main_ref.artifacts.has(artifact_id):
			artifact_ids.append(artifact_id)
	for i in range(3):
		var center := rect.position + Vector2(32.0 * scale + float(i) * (rect.size.x - 64.0 * scale) / 2.0, 82.0 * scale)
		if i < artifact_ids.size():
			var artifact_id := str(artifact_ids[i])
			var artifact_data: Dictionary = main_ref.artifacts[artifact_id]
			_draw_card_art(center, artifact_id, _upgrade_color(artifact_id), 12.0 * scale)
			_text(center + Vector2(8.0 * scale, 4.0 * scale), str(artifact_data.get("level", 1)), maxi(7, roundi(8.0 * scale)), TEXT_COLOR)
		else:
			draw_circle(center, 11.0 * scale, Color(0.08, 0.075, 0.065, 0.65))
			draw_arc(center, 11.0 * scale, 0.0, TAU, 24, Color(0.55, 0.49, 0.38, 0.3), 1.0 * scale)

	var cultivation_text := "未立道" if main_ref.primary_element.is_empty() else "修炼 %d/3" % int(main_ref.element_cultivation_levels.get(main_ref.primary_element, 0))
	var artifact_text := "法器 %d/%d" % [main_ref.artifacts.size(), main_ref._artifact_slot_cap()]
	_text(rect.position + Vector2(11.0 * scale, 108.0 * scale), "%s  ·  %s" % [cultivation_text, artifact_text], maxi(7, roundi(8.5 * scale)), _upgrade_color("cultivation_" + main_ref.primary_element) if not main_ref.primary_element.is_empty() else MUTED_COLOR)
	var general_text := "身法 %d  纳气 %d  广纳 %d  强身 %d" % [
		int(main_ref.general_upgrade_levels.get("swift_step", 0)),
		int(main_ref.general_upgrade_levels.get("spirit_gain", 0)),
		int(main_ref.general_upgrade_levels.get("spirit_sense", 0)),
		int(main_ref.general_upgrade_levels.get("vitality", 0))
	]
	_text(rect.position + Vector2(11.0 * scale, 127.0 * scale), general_text, maxi(7, roundi(8.0 * scale)), MUTED_COLOR)

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


func _hud_layout(view: Vector2) -> Dictionary:
	var scale := clampf(minf(view.x / 1280.0, view.y / 720.0), 0.72, 1.0)
	var margin := maxf(10.0, 18.0 * scale)
	var left_width := minf(330.0 * scale, view.x * 0.285)
	var right_width := minf(250.0 * scale, view.x * 0.225)
	var time_width := minf(320.0 * scale, maxf(140.0, view.x - left_width - right_width - margin * 4.0 - 24.0 * scale))
	var status_rect := Rect2(margin, margin, left_width, 96.0 * scale)
	var objective_rect := Rect2(margin, status_rect.end.y + 8.0 * scale, left_width, 70.0 * scale)
	var skill_rect := Rect2(view.x - margin - right_width, margin, right_width, 142.0 * scale)
	var build_rect := Rect2(skill_rect.position.x, skill_rect.end.y + 8.0 * scale, right_width, 150.0 * scale)
	var left_limit := status_rect.end.x + 12.0 * scale
	var right_limit := skill_rect.position.x - 12.0 * scale
	time_width = minf(time_width, maxf(120.0 * scale, right_limit - left_limit))
	var time_x := clampf((view.x - time_width) * 0.5, left_limit, maxf(left_limit, right_limit - time_width))
	var time_rect := Rect2(time_x, margin, time_width, 56.0 * scale)
	var controls_width := minf(540.0 * scale, view.x - margin * 2.0)
	var controls_height := 28.0 * scale
	var controls_rect := Rect2((view.x - controls_width) * 0.5, view.y - margin - controls_height, controls_width, controls_height)
	var boss_width := minf(500.0 * scale, view.x * 0.48)
	var boss_rect := Rect2((view.x - boss_width) * 0.5, margin + 62.0 * scale, boss_width, 39.0 * scale)
	return {"scale": scale, "status": status_rect, "objective": objective_rect, "time": time_rect, "skill": skill_rect, "build": build_rect, "controls": controls_rect, "boss": boss_rect}


func _level_up_layout(view: Vector2) -> Dictionary:
	var margin := maxf(8.0, minf(18.0, view.x * 0.018))
	var panel_width := maxf(120.0, minf(980.0, view.x - margin * 2.0))
	var panel_height := maxf(160.0, minf(520.0, view.y - margin * 2.0))
	var scale := clampf(minf(view.x / 1280.0, view.y / 720.0), 0.62, 1.0)
	var panel_rect := Rect2((view.x - panel_width) * 0.5, (view.y - panel_height) * 0.5, panel_width, panel_height)
	var header_height := minf(122.0 * scale, panel_height * 0.25)
	var inner_margin := clampf(panel_width * 0.032, 12.0, 30.0)
	var gap := clampf(panel_width * 0.018, 8.0, 18.0)
	var card_width := maxf(40.0, (panel_width - inner_margin * 2.0 - gap * 2.0) / 3.0)
	var card_y := panel_rect.position.y + header_height
	var card_height := maxf(90.0, panel_rect.end.y - card_y - 18.0 * scale)
	var cards: Array = []
	for i in range(3):
		cards.append(Rect2(panel_rect.position.x + inner_margin + float(i) * (card_width + gap), card_y, card_width, card_height))
	return {"panel": panel_rect, "cards": cards, "header_height": header_height, "scale": scale}


func _draw_cloud_motif(origin: Vector2, scale: float, color: Color) -> void:
	draw_arc(origin, 11.0 * scale, PI * 0.08, PI * 1.72, 24, color, 1.4 * scale)
	draw_arc(origin + Vector2(14.0 * scale, -5.0 * scale), 8.0 * scale, PI * 0.9, PI * 2.1, 20, color, 1.2 * scale)
	draw_arc(origin + Vector2(27.0 * scale, 1.0 * scale), 10.0 * scale, PI * 1.1, PI * 2.2, 20, color, 1.2 * scale)
	draw_line(origin + Vector2(-13.0 * scale, 8.0 * scale), origin + Vector2(34.0 * scale, 8.0 * scale), color, 1.0 * scale)


func _card_effect_line(card: Dictionary) -> String:
	match str(card.get("kind", "")):
		"skill_acquire":
			return "纳入构筑 · 后续可继续精进"
		"skill_level":
			return "术法威能提升"
		"skill_branch":
			return "关键分支 · 改变战斗方式"
		"skill_evolution":
			return "终极进化 · 战斗表现质变"
		"element_cultivation":
			return "元素修炼 · 强化专属效果"
		"artifact_acquire":
			return "核心法宝 · 解锁进化条件"
		"artifact_level":
			return "法器效果进一步强化"
		"active_skill_upgrade":
			return "主动道术 · 威力与冷却强化"
		"general_upgrade":
			return "修为强化 · 即时生效"
		_:
			return "选择后立即生效"

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


func _draw_skill_card_illustration(art_rect: Rect2, icon_id: String, accent: Color) -> void:
	# Rich, elemental artwork sits in a dedicated vignette area; no character portraits
	# are repeated across cards. Everything is drawn from original vector assets.
	var center := art_rect.get_center()
	var unit := clampf(minf(art_rect.size.x / 270.0, art_rect.size.y / 170.0), 0.42, 1.0)
	draw_rect(art_rect, Color("#090d12"))
	draw_rect(art_rect, Color(accent.r, accent.g, accent.b, 0.18), false, 1.2 * unit)
	draw_rect(art_rect.grow(-4.0 * unit), Color(accent.r, accent.g, accent.b, 0.08), false, 1.0 * unit)
	draw_circle(center, minf(art_rect.size.y * 0.43, art_rect.size.x * 0.25), Color(accent.r, accent.g, accent.b, 0.12))
	for i in range(10):
		var angle := TAU * float(i) / 10.0
		var inner := center + Vector2(cos(angle), sin(angle)) * art_rect.size.y * 0.28
		var outer := center + Vector2(cos(angle), sin(angle)) * art_rect.size.y * 0.43
		draw_line(inner, outer, Color(accent.r, accent.g, accent.b, 0.28), 1.0 * unit)

	if icon_id.contains("fire"):
		for i in range(7):
			var fx := art_rect.position.x + art_rect.size.x * (0.16 + float(i) * 0.105)
			var base_y := art_rect.end.y - 7.0 * unit
			var flame_h := art_rect.size.y * (0.18 + float((i * 3) % 4) * 0.045)
			var flame := PackedVector2Array([Vector2(fx - 7.0 * unit, base_y), Vector2(fx - 2.0 * unit, base_y - flame_h * 0.55), Vector2(fx, base_y - flame_h), Vector2(fx + 3.0 * unit, base_y - flame_h * 0.45), Vector2(fx + 7.0 * unit, base_y)])
			draw_colored_polygon(flame, Color("#e85c26", 0.56))
	elif icon_id.contains("thunder") or icon_id.contains("five_thunder"):
		var bolt := PackedVector2Array([
			Vector2(art_rect.position.x + art_rect.size.x * 0.12, center.y - 20.0 * unit),
			Vector2(art_rect.position.x + art_rect.size.x * 0.27, center.y - 4.0 * unit),
			Vector2(art_rect.position.x + art_rect.size.x * 0.22, center.y + 7.0 * unit),
			Vector2(art_rect.position.x + art_rect.size.x * 0.40, center.y + 18.0 * unit),
			Vector2(art_rect.position.x + art_rect.size.x * 0.36, center.y + 31.0 * unit)
		])
		draw_polyline(bolt, Color("#3e72ff", 0.72), 4.0 * unit, true)
		draw_polyline(bolt, Color("#c6e8ff", 0.92), 1.4 * unit, true)
		draw_polyline(PackedVector2Array([Vector2(center.x + 48.0 * unit, center.y - 32.0 * unit), Vector2(center.x + 31.0 * unit, center.y - 11.0 * unit), Vector2(center.x + 40.0 * unit, center.y + 2.0 * unit), Vector2(center.x + 25.0 * unit, center.y + 24.0 * unit)]), Color("#7d89ff", 0.82), 2.0 * unit, true)
	elif icon_id.contains("sword") or icon_id.contains("peachwood") or icon_id.contains("coin"):
		draw_arc(center, art_rect.size.y * 0.38, PI * 1.05, PI * 1.86, 40, Color("#f0c875", 0.82), 2.0 * unit)
		draw_arc(center, art_rect.size.y * 0.31, PI * 0.1, PI * 0.9, 40, Color("#f4e0a0", 0.55), 1.3 * unit)
		draw_line(center + Vector2(-art_rect.size.y * 0.25, art_rect.size.y * 0.2), center + Vector2(art_rect.size.y * 0.22, -art_rect.size.y * 0.25), Color("#fff0c3", 0.46), 2.0 * unit)
	elif icon_id.contains("water") or icon_id.contains("ice") or icon_id.contains("cold"):
		for ring in range(3):
			draw_arc(center, art_rect.size.y * (0.20 + float(ring) * 0.105), 0.0, TAU, 44, Color("#6ad5f0", 0.66 - float(ring) * 0.13), 1.5 * unit)
		draw_line(center + Vector2(-art_rect.size.x * 0.32, art_rect.size.y * 0.26), center + Vector2(art_rect.size.x * 0.32, art_rect.size.y * 0.26), Color("#a7efff", 0.7), 1.5 * unit)
	elif icon_id.contains("earth") or icon_id.contains("formation"):
		draw_colored_polygon(PackedVector2Array([Vector2(center.x - 48.0 * unit, art_rect.end.y - 8.0 * unit), Vector2(center.x - 25.0 * unit, center.y + 8.0 * unit), Vector2(center.x - 6.0 * unit, art_rect.end.y - 8.0 * unit)]), Color("#756344", 0.68))
		draw_colored_polygon(PackedVector2Array([Vector2(center.x + 2.0 * unit, art_rect.end.y - 8.0 * unit), Vector2(center.x + 24.0 * unit, center.y - 2.0 * unit), Vector2(center.x + 47.0 * unit, art_rect.end.y - 8.0 * unit)]), Color("#9e8150", 0.7))

	var art_region := _skill_art_region(icon_id)
	var art_texture: Texture2D = SKILL_ART_ATLAS
	if icon_id.begins_with("cultivation_"):
		art_region = _cultivation_art_region(icon_id)
		art_texture = ELEMENT_CULTIVATION_ATLAS
	var icon_size := minf(art_rect.size.y * 0.9, art_rect.size.x * 0.60)
	var icon_center := center
	if art_region.size.x > 0.0:
		draw_texture_rect_region(art_texture, Rect2(icon_center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), art_region, Color.WHITE, false)
	else:
		_draw_card_art(icon_center, icon_id, accent, minf(33.0 * unit, art_rect.size.y * 0.24))

	# Fine gold corner marks and a low horizon line make the image read as a framed illustration.
	draw_line(art_rect.position + Vector2(7.0 * unit, 7.0 * unit), art_rect.position + Vector2(24.0 * unit, 7.0 * unit), Color("#e5c579", 0.88), 1.2 * unit)
	draw_line(art_rect.position + Vector2(7.0 * unit, 7.0 * unit), art_rect.position + Vector2(7.0 * unit, 24.0 * unit), Color("#e5c579", 0.88), 1.2 * unit)
	draw_line(Vector2(art_rect.end.x - 7.0 * unit, art_rect.end.y - 7.0 * unit), Vector2(art_rect.end.x - 24.0 * unit, art_rect.end.y - 7.0 * unit), Color("#e5c579", 0.88), 1.2 * unit)
	draw_line(Vector2(art_rect.end.x - 7.0 * unit, art_rect.end.y - 7.0 * unit), Vector2(art_rect.end.x - 7.0 * unit, art_rect.end.y - 24.0 * unit), Color("#e5c579", 0.88), 1.2 * unit)

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
	var scale := clampf(minf(view.x / 1280.0, view.y / 720.0), 0.72, 1.0)
	var joystick_center := Vector2(94.0 * scale, view.y - 105.0 * scale)
	draw_circle(joystick_center, 58.0 * scale, Color(0.06, 0.06, 0.05, 0.3))
	draw_arc(joystick_center, 58.0 * scale, 0.0, TAU, 40, Color(0.85, 0.78, 0.62, 0.65), 2.0 * scale)
	var knob_offset: Vector2 = main_ref.player.mobile_move * 28.0 * scale
	draw_circle(joystick_center + knob_offset, 24.0 * scale, Color(0.78, 0.68, 0.48, 0.35))
	draw_arc(Vector2(view.x - 82.0 * scale, view.y - 122.0 * scale), 44.0 * scale, 0.0, TAU, 40, Color("#d9b65f"), 3.0 * scale)
	_center_text(Rect2(view.x - 115.0 * scale, view.y - 128.0 * scale, 66.0 * scale, 26.0 * scale), "镇尸", maxi(10, roundi(16.0 * scale)), Color("#f0d79b"))
	draw_arc(Vector2(view.x - 51.0 * scale, view.y - 61.0 * scale), 27.0 * scale, 0.0, TAU, 32, Color("#c16b55"), 2.0 * scale)
	_center_text(Rect2(view.x - 72.0 * scale, view.y - 68.0 * scale, 42.0 * scale, 25.0 * scale), "疗", maxi(10, roundi(15.0 * scale)), TEXT_COLOR)

func card_index_at(screen_position: Vector2) -> int:
	var view := get_viewport_rect().size
	var layout := _level_up_layout(view)
	var card_rects: Array = layout["cards"]
	for i in range(mini(3, main_ref.level_cards.size())):
		if card_rects[i].has_point(screen_position):
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
