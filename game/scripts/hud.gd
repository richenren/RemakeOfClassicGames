extends Node2D

const SKILL_ART_ATLAS: Texture2D = preload("res://assets/sprites/skill_art_atlas.svg")
const SKILL_CARD_ART_ATLAS: Texture2D = preload("res://assets/sprites/skill_card_art_atlas.svg")
const WATER_COLD_TIDE_CARD_TEXTURE: Texture2D = preload("res://assets/sprites/water_cold_tide_card.svg")
const ELEMENT_CULTIVATION_ATLAS: Texture2D = preload("res://assets/sprites/element_cultivation_atlas.svg")
const PLAYER_PORTRAIT_TEXTURE: Texture2D = preload("res://assets/sprites/player_taoist_portrait.tres")
const BOSS_UI_PORTRAIT_DEFAULT: Texture2D = preload("res://assets/sprites/enemy_boss.svg")
const HEAL_CELADON_TEXTURE: Texture2D = preload("res://assets/sprites/heal_celadon_flask.svg")

var main_ref
const MOUSE_TOOLTIP_DELAY := 0.40
const TOUCH_TOOLTIP_DELAY := 0.52
var hovered_tooltip_key: String = ""
var hover_tooltip_elapsed: float = 0.0
var pressed_tooltip_key: String = ""
var pressed_touch_index: int = -1
var pressed_touch_position: Vector2 = Vector2.ZERO
var touch_tooltip_elapsed: float = 0.0
var touch_tooltip_long: bool = false
var pressed_touch_action: String = ""
const TEXT_COLOR := Color("#efe6d2")
const MUTED_COLOR := Color("#b8ad99")
const PANEL_COLOR := Color(0.08, 0.075, 0.065, 0.92)
const PANEL_EDGE := Color("#8b7758")


func _process(delta: float) -> void:
	_advance_tooltips(delta)
	queue_redraw()


func _draw() -> void:
	if main_ref == null:
		return
	var view := get_viewport_rect().size
	_draw_reference_hud(view)
	if main_ref.state == "playing":
		_draw_reference_tooltip(view)
	if main_ref.state == "level_up":
		_draw_level_up(view)
	elif main_ref.state == "paused":
		_draw_pause(view)
	elif main_ref.state == "game_over" or main_ref.state == "victory":
		_draw_end_screen(view)
	# The reference HUD owns action/joystick visuals for keyboard and touch alike.


# The approved 1303x609 reference is a thin, edge-anchored gameplay HUD.
# Only layout and presentation change: all combat, upgrade and fire effects remain intact.
func _reference_hud_layout(view: Vector2) -> Dictionary:
	# Approved 1672x941 reference artboard; scale uniformly and center for other aspect ratios.
	var unit := clampf(minf(view.x / 1672.0, view.y / 941.0), 0.36, 1.5)
	var canvas_size := Vector2(1672.0, 941.0) * unit
	var offset := (view - canvas_size) * 0.5
	var status_rect := Rect2(offset + Vector2(28.0, 78.0) * unit, Vector2(480.0, 136.0) * unit)
	var kills_rect := Rect2(offset + Vector2(145.0, 220.0) * unit, Vector2(350.0, 66.0) * unit)
	var objective_rect := Rect2(Vector2(view.x - 572.0 * unit, offset.y + 78.0 * unit), Vector2(480.0, 142.0) * unit)
	var slots_rect := Rect2(Vector2(view.x - 126.0 * unit, offset.y + 228.0 * unit), Vector2(82.0, 354.0) * unit)
	var xp_rect := Rect2(offset + Vector2(550.0, 858.0) * unit, Vector2(570.0, 32.0) * unit)
	var boss_rect := Rect2(offset + Vector2(590.0, 14.0) * unit, Vector2(492.0, 46.0) * unit)
	var pause_center := Vector2(view.x - 66.0 * unit, offset.y + 101.0 * unit)
	return {
		"scale": unit, "offset": offset, "status": status_rect, "kills": kills_rect,
		"objective": objective_rect, "time": Rect2(), "slots": slots_rect,
		"xp": xp_rect, "objective_marker": Rect2(), "pause_center": pause_center, "boss": boss_rect
	}


func reference_action_at(screen_position: Vector2) -> String:
	var view := get_viewport_rect().size
	var layout := _reference_hud_layout(view)
	var unit: float = layout["scale"]
	var pause_center: Vector2 = layout["pause_center"]
	if screen_position.distance_to(pause_center) <= 23.0 * unit:
		return "pause"
	var touch := _touch_layout(view)
	if screen_position.distance_to(touch["skill_center"]) <= float(touch["skill_hit_radius"]):
		return "cast"
	if screen_position.distance_to(touch["heal_center"]) <= float(touch["heal_hit_radius"]):
		return "heal"
	return ""


func _reference_panel(rect: Rect2, accent: Color, unit: float) -> void:
	draw_rect(rect, Color(0.024, 0.030, 0.032, 0.88))
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.72), false, maxf(0.7, unit))
	var corner := 12.0 * unit
	for i in range(4):
		var x := rect.position.x if i % 2 == 0 else rect.end.x
		var y := rect.position.y if i < 2 else rect.end.y
		var x_sign := 1.0 if i % 2 == 0 else -1.0
		var y_sign := 1.0 if i < 2 else -1.0
		draw_line(Vector2(x + x_sign * 3.0 * unit, y), Vector2(x + x_sign * corner, y), accent, maxf(0.8, 1.5 * unit))
		draw_line(Vector2(x, y + y_sign * 3.0 * unit), Vector2(x, y + y_sign * corner), accent, maxf(0.8, 1.5 * unit))


func _draw_ornate_game_card(rect: Rect2, accent: Color, unit: float, red_trim: bool = true) -> void:
	draw_rect(rect, Color(0.018, 0.022, 0.026, 0.91))
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.92), false, maxf(0.9, 1.45 * unit))
	draw_rect(rect.grow(-4.0 * unit), Color(accent.r, accent.g, accent.b, 0.22), false, maxf(0.6, 0.8 * unit))
	var x := rect.position.x
	var y := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var corner := 22.0 * unit
	for side in [1.0, -1.0]:
		var cx := x + 5.0 * unit if side > 0.0 else right - 5.0 * unit
		var dx := 1.0 if side > 0.0 else -1.0
		draw_line(Vector2(cx, y + corner), Vector2(cx + dx * corner, y + 5.0 * unit), accent, 1.5 * unit, true)
		draw_line(Vector2(cx + dx * corner, y + 5.0 * unit), Vector2(cx + dx * 2.0 * corner, y + 5.0 * unit), accent, 1.1 * unit, true)
		draw_line(Vector2(cx, bottom - corner), Vector2(cx + dx * corner, bottom - 5.0 * unit), accent, 1.5 * unit, true)
		draw_line(Vector2(cx + dx * corner, bottom - 5.0 * unit), Vector2(cx + dx * 2.0 * corner, bottom - 5.0 * unit), accent, 1.1 * unit, true)
	var top_diamond := rect.position + Vector2(rect.size.x * 0.5, 2.0 * unit)
	var bottom_diamond := Vector2(rect.get_center().x, rect.end.y - 2.0 * unit)
	for center in [top_diamond, bottom_diamond]:
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -5.0 * unit), center + Vector2(6.0 * unit, 0.0),
			center + Vector2(0.0, 5.0 * unit), center + Vector2(-6.0 * unit, 0.0),
			center + Vector2(0.0, -5.0 * unit)
		])
		draw_colored_polygon(diamond, Color(accent.r, accent.g, accent.b, 0.86))
	if red_trim:
		var red := Color("#a83b32", 0.82)
		draw_arc(rect.position + Vector2(39.0, rect.size.y - 4.0) * unit, 34.0 * unit, PI * 1.10, PI * 1.78, 28, red, 2.2 * unit, true)
		draw_arc(Vector2(rect.end.x - 39.0 * unit, rect.position.y + 4.0 * unit), 34.0 * unit, PI * 0.10, PI * 0.82, 28, red, 2.2 * unit, true)


func _center_text_outline(rect: Rect2, value: String, size: int, color: Color, outline_size: int = 1) -> void:
	var font: Font = ThemeDB.fallback_font
	var origin := _center_text_origin(rect, value, size)
	draw_string_outline(font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, outline_size, Color(0.015, 0.012, 0.01, 0.94))
	draw_string(font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _fit_font_size(value: String, max_width: float, desired: int, minimum: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var size := maxi(minimum, desired)
	while size > minimum and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > max_width:
		size -= 1
	return size


func _format_kill_count(value: int) -> String:
	var count := maxi(0, value)
	if count < 10000:
		return str(count)
	if count < 100000:
		return "%.1f万" % (float(count) / 10000.0)
	if count < 10000000:
		return "%.0f万" % (float(count) / 10000.0)
	return "%.1f千万" % (float(count) / 10000000.0)


func _draw_reference_frame(view: Vector2, layout: Dictionary) -> void:
	var unit: float = layout["scale"]
	var offset: Vector2 = layout["offset"]
	var frame := Rect2(offset + Vector2(7.0, 70.0) * unit, Vector2(1658.0, 832.0) * unit)
	draw_rect(frame, Color("#bd914d", 0.82), false, 1.35 * unit)
	draw_rect(frame.grow(-4.0 * unit), Color("#bd914d", 0.22), false, 0.7 * unit)
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			var corner := Vector2(frame.position.x if sx > 0.0 else frame.end.x, frame.position.y if sy > 0.0 else frame.end.y)
			draw_line(corner + Vector2(0.0, sy * 30.0 * unit), corner + Vector2(0.0, sy * 8.0 * unit), Color("#e0b765", 0.92), 1.6 * unit, true)
			draw_line(corner + Vector2(sx * 30.0 * unit, 0.0), corner + Vector2(sx * 8.0 * unit, 0.0), Color("#e0b765", 0.92), 1.6 * unit, true)
			draw_arc(corner + Vector2(sx * 9.0, sy * 9.0) * unit, 8.0 * unit, 0.0, TAU, 20, Color("#e0b765", 0.78), 1.0 * unit)
	_draw_cloud_motif(offset + Vector2(76.0, 30.0) * unit, unit, Color("#a43b32", 0.72))
	_draw_cloud_motif(offset + Vector2(1515.0, 30.0) * unit, unit, Color("#a43b32", 0.72))
	_draw_cloud_motif(offset + Vector2(72.0, 900.0) * unit, unit, Color("#a43b32", 0.66))
	_draw_cloud_motif(offset + Vector2(1510.0, 900.0) * unit, unit, Color("#a43b32", 0.66))


func _draw_player_card(player, rect: Rect2, unit: float) -> void:
	_draw_ornate_game_card(rect, Color("#d2aa63"), unit, true)
	var portrait_center := rect.position + Vector2(86.0, 68.0) * unit
	var portrait_size := 122.0 * unit
	draw_circle(portrait_center, 65.0 * unit, Color("#090b0d", 0.98))
	draw_arc(portrait_center, 64.0 * unit, 0.0, TAU, 64, Color("#f0ce82"), 2.4 * unit, true)
	draw_arc(portrait_center, 58.0 * unit, 0.0, TAU, 64, Color("#946c39", 0.9), 1.2 * unit, true)
	var portrait: Texture2D = player.character_portrait if player.character_portrait != null else PLAYER_PORTRAIT_TEXTURE
	draw_texture_rect(portrait, Rect2(portrait_center - Vector2.ONE * portrait_size * 0.5, Vector2.ONE * portrait_size), false)
	var name_text := str(player.character_display_name)
	var name_rect := Rect2(rect.position + Vector2(158.0, 14.0) * unit, Vector2(300.0, 48.0) * unit)
	var name_size := _fit_font_size(name_text, name_rect.size.x - 12.0 * unit, maxi(16, roundi(36.0 * unit)), maxi(12, roundi(23.0 * unit)))
	_center_text_outline(name_rect, name_text, name_size, Color("#f4d99f"), 1)
	var hp_rect := Rect2(rect.position + Vector2(171.0, 76.0) * unit, Vector2(284.0, 26.0) * unit)
	_draw_health_pill(hp_rect, player.hp / maxf(1.0, player.max_hp), Color("#d34b43"), true)
	_center_text_outline(hp_rect.grow(2.0 * unit), "%d / %d" % [roundi(player.hp), roundi(player.max_hp)], maxi(10, roundi(19.0 * unit)), Color("#fff1df"), 1)


func _draw_kill_card(rect: Rect2, unit: float) -> void:
	_draw_ornate_game_card(rect, Color("#d6a85d"), unit, true)
	var label_rect := Rect2(rect.position + Vector2(35.0, 9.0) * unit, Vector2(105.0, 47.0) * unit)
	var count_rect := Rect2(rect.position + Vector2(137.0, 5.0) * unit, Vector2(196.0, 54.0) * unit)
	var count_text := _format_kill_count(main_ref.kills)
	var count_size := _fit_font_size(count_text, count_rect.size.x - 8.0 * unit, maxi(22, roundi(47.0 * unit)), maxi(17, roundi(26.0 * unit)))
	_center_text_outline(label_rect, "击杀", maxi(14, roundi(27.0 * unit)), Color("#e7c47c"), 1)
	_center_text_outline(count_rect, count_text, count_size, Color("#ffd889"), 1)


func _draw_boss_card(rect: Rect2, unit: float) -> void:
	_draw_ornate_game_card(rect, Color("#c75b45"), unit, true)
	var portrait_center := rect.position + Vector2(77.0, 71.0) * unit
	draw_circle(portrait_center, 65.0 * unit, Color("#120d0d", 0.98))
	draw_arc(portrait_center, 64.0 * unit, 0.0, TAU, 64, Color("#e4b86b"), 2.5 * unit, true)
	draw_arc(portrait_center, 58.0 * unit, 0.0, TAU, 64, Color("#a84035", 0.88), 1.4 * unit, true)
	var portrait_rect := Rect2(portrait_center - Vector2(59.0, 62.0) * unit, Vector2(118.0, 124.0) * unit)
	draw_texture_rect_region(_boss_profile_portrait(), portrait_rect, Rect2(54.0, 9.0, 84.0, 90.0), Color.WHITE, false)
	var objective := objective_data()
	var boss_title := str(objective.get("boss_name", main_ref.get_boss_ui_profile().get("name", "尸王")))
	var title_rect := Rect2(rect.position + Vector2(145.0, 16.0) * unit, Vector2(315.0, 43.0) * unit)
	var title_text := "镇邪令 · " + boss_title
	_center_text_outline(title_rect, title_text, _fit_font_size(title_text, title_rect.size.x - 8.0 * unit, maxi(15, roundi(31.0 * unit)), maxi(12, roundi(20.0 * unit))), Color("#f0d49a"), 1)
	var spawning := str(objective.get("kind", "")) == "survival"
	var countdown_label := "现身倒计时" if spawning else "尸王已降临"
	var countdown_rect := Rect2(rect.position + Vector2(145.0, 76.0) * unit, Vector2(175.0, 42.0) * unit)
	_center_text_outline(countdown_rect, countdown_label, maxi(12, roundi(22.0 * unit)), Color("#e9c889"), 1)
	if spawning:
		var remaining := int(objective.get("remaining_seconds", 0))
		var countdown := "%02d:%02d" % [remaining / 60, remaining % 60]
		var pulse := 1.0 if remaining > 10 else 0.74 + 0.26 * sin(main_ref.elapsed_seconds * 13.0)
		var time_rect := Rect2(rect.position + Vector2(315.0, 66.0) * unit, Vector2(135.0, 53.0) * unit)
		_center_text_outline(time_rect, countdown, maxi(18, roundi(43.0 * unit)), Color("#ffd17c", pulse), 1)
	else:
		var boss = main_ref.get_boss()
		var status_text := "正在交战" if boss != null else "战场清理中"
		var status_rect := Rect2(rect.position + Vector2(315.0, 70.0) * unit, Vector2(135.0, 43.0) * unit)
		_center_text_outline(status_rect, status_text, maxi(13, roundi(22.0 * unit)), Color("#ffd17c"), 1)
		var progress := float(objective.get("progress", 0.0))
		_bar(Rect2(rect.position + Vector2(150.0, 127.0) * unit, Vector2(294.0, 4.0) * unit), progress, Color("#c85b46"))


func _draw_boss_health_lane(rect: Rect2, unit: float) -> void:
	var boss = main_ref.get_boss()
	if boss == null:
		return
	_draw_ornate_game_card(rect, Color("#bd7657"), unit, false)
	var title := str(main_ref.get_boss_ui_profile().get("name", "尸王"))
	_center_text_outline(Rect2(rect.position + Vector2(8.0, 0.0) * unit, Vector2(rect.size.x - 16.0 * unit, 18.0 * unit)), title, maxi(9, roundi(12.0 * unit)), Color("#f0d49a"), 1)
	_draw_health_pill(Rect2(rect.position + Vector2(16.0, 25.0) * unit, Vector2(rect.size.x / unit - 32.0, 7.0) * unit), boss.hp / maxf(1.0, boss.max_hp), Color("#b84d42"), true)


func _draw_xp_footer(rect: Rect2, player, unit: float) -> void:
	var level_center := rect.position + Vector2(37.0, 16.0) * unit
	draw_circle(level_center, 29.0 * unit, Color("#100f0d", 0.98))
	draw_arc(level_center, 29.0 * unit, 0.0, TAU, 48, Color("#d9ad60"), 2.1 * unit, true)
	draw_arc(level_center, 24.0 * unit, 0.0, TAU, 48, Color("#8c6938", 0.72), 0.9 * unit, true)
	_center_text_outline(Rect2(level_center - Vector2(25.0, 15.0) * unit, Vector2(50.0, 30.0) * unit), "Lv%d" % player.level, maxi(11, roundi(19.0 * unit)), Color("#f3d18b"), 1)
	var xp_bar := Rect2(rect.position + Vector2(82.0, 8.0) * unit, Vector2(410.0, 12.0) * unit)
	draw_rect(xp_bar, Color("#080a0b", 0.9))
	draw_rect(xp_bar, Color("#b38b4c", 0.9), false, 1.0 * unit)
	_bar(xp_bar.grow(-1.0 * unit), float(player.xp) / maxf(1.0, float(player.xp_to_next)), Color("#e1a944"))
	_center_text_outline(Rect2(rect.position + Vector2(503.0, 1.0) * unit, Vector2(64.0, 28.0) * unit), "%d/%d" % [player.xp, player.xp_to_next], maxi(10, roundi(17.0 * unit)), Color("#f0dfbb"), 1)


func _draw_auto_skill_rail(rect: Rect2, unit: float) -> void:
	_draw_ornate_game_card(rect, Color("#bd9957"), unit, false)
	var owned := _equipped_skill_ids()
	var offsets := [55.0, 145.0, 215.0, 285.0]
	for i in range(4):
		var center := rect.position + Vector2(rect.size.x / (2.0 * unit), float(offsets[i])) * unit
		var radius := 29.0 * unit
		if i < owned.size():
			var skill_id := owned[i]
			var data: Dictionary = main_ref.skills[skill_id]
			var evolved := str(data.get("evolved", ""))
			var icon := skill_id if evolved.is_empty() else evolved
			_draw_card_art(center, icon, _upgrade_color(icon), radius)
			var label := "自动" if i == 0 else "Lv%d" % int(data.get("level", 1))
			_center_text_outline(Rect2(center.x - 30.0 * unit, center.y + 27.0 * unit, 60.0 * unit, 18.0 * unit), label, maxi(8, roundi(12.0 * unit)), Color("#f0d49a"), 1)
		elif i == 0:
			_draw_card_art(center, "control_art", Color("#d4ad69"), radius)
			_center_text_outline(Rect2(center.x - 30.0 * unit, center.y + 27.0 * unit, 60.0 * unit, 18.0 * unit), "自动", maxi(8, roundi(12.0 * unit)), Color("#f0d49a"), 1)
		else:
			draw_circle(center, radius * 0.82, Color("#0b0e0f", 0.82))
			draw_arc(center, radius * 0.82, 0.0, TAU, 36, Color("#bd9957", 0.76), 1.4 * unit, true)
			_center_text_outline(Rect2(center.x - 16.0 * unit, center.y - 15.0 * unit, 32.0 * unit, 30.0 * unit), "+", maxi(18, roundi(29.0 * unit)), Color("#d3b476"), 1)


func _draw_reference_hud(view: Vector2) -> void:
	var player = main_ref.player
	if player == null:
		return
	var layout := _reference_hud_layout(view)
	var unit: float = layout["scale"]
	_draw_reference_frame(view, layout)
	_draw_player_card(player, layout["status"], unit)
	_draw_kill_card(layout["kills"], unit)
	if main_ref.state != "victory" and main_ref.state != "game_over":
		_draw_boss_card(layout["objective"], unit)
	_draw_boss_health_lane(layout["boss"], unit)
	_draw_xp_footer(layout["xp"], player, unit)

	var pause: Vector2 = layout["pause_center"]
	draw_circle(pause, 23.0 * unit, Color("#090b0d", 0.96))
	draw_arc(pause, 23.0 * unit, 0.0, TAU, 48, Color("#e1b45f"), 2.0 * unit, true)
	draw_line(pause + Vector2(-5.0, -8.0) * unit, pause + Vector2(-5.0, 8.0) * unit, Color("#f4d99f"), 3.0 * unit, true)
	draw_line(pause + Vector2(5.0, -8.0) * unit, pause + Vector2(5.0, 8.0) * unit, Color("#f4d99f"), 3.0 * unit, true)

	_draw_auto_skill_rail(layout["slots"], unit)
	_draw_reference_controls(view, unit)


func _draw_reference_controls(view: Vector2, unit: float) -> void:
	var touch := _touch_layout(view)
	var joy: Vector2 = touch["joystick_center"]
	var joy_r: float = touch["joystick_radius"]
	draw_circle(joy, joy_r, Color("#0d1011", 0.34))
	draw_arc(joy, joy_r, 0.0, TAU, 56, Color("#d2aa63", 0.9), 2.0 * unit, true)
	draw_arc(joy, joy_r - 7.0 * unit, PI * 0.1, PI * 0.9, 28, Color("#8c6938", 0.7), 1.0 * unit, true)
	if _is_mobile():
		var offset: Vector2 = main_ref.player.mobile_move * joy_r * 0.45
		draw_circle(joy + offset, 25.0 * unit, Color("#c6a464", 0.48))
		draw_arc(joy + offset, 25.0 * unit, 0.0, TAU, 32, Color("#f0d49a"), 1.5 * unit)
	else:
		for item in [{"letter":"W","offset":Vector2(0,-52)}, {"letter":"A","offset":Vector2(-52,0)}, {"letter":"S","offset":Vector2(0,52)}, {"letter":"D","offset":Vector2(52,0)}]:
			var center: Vector2 = joy + item["offset"] * unit
			draw_circle(center, 23.0 * unit, Color("#171512", 0.88))
			draw_arc(center, 23.0 * unit, 0.0, TAU, 36, Color("#d5ad70", 0.9), 1.5 * unit, true)
			_center_text_outline(Rect2(center - Vector2(18.0, 17.0) * unit, Vector2(36.0, 34.0) * unit), str(item["letter"]), maxi(11, roundi(21.0 * unit)), Color("#f0dfbd"), 1)

	var heal: Vector2 = touch["heal_center"]
	var skill: Vector2 = touch["skill_center"]
	var reserved: Vector2 = touch["secondary_center"]
	var heal_r: float = touch["heal_radius"]
	var skill_r: float = touch["skill_radius"]
	var reserved_r: float = touch["secondary_radius"]
	var skill_ready: bool = main_ref.active_skill_cooldown <= 0.0

	# E: healing flask, with the remaining count as a small corner badge.
	draw_circle(heal, heal_r + 8.0 * unit, Color("#080b0c", 0.9))
	draw_arc(heal, heal_r + 5.0 * unit, 0.0, TAU, 56, Color("#d5ad70"), 2.0 * unit, true)
	draw_circle(heal, heal_r - 5.0 * unit, Color("#151711", 0.96))
	var potion_alpha := 1.0 if main_ref.heal_charges > 0 else 0.4
	draw_texture_rect(HEAL_CELADON_TEXTURE, Rect2(heal - Vector2.ONE * 33.0 * unit, Vector2.ONE * 66.0 * unit), false, Color(1.0, 1.0, 1.0, potion_alpha))
	draw_circle(heal + Vector2(28.0, 27.0) * unit, 12.0 * unit, Color("#17120d", 0.96))
	draw_arc(heal + Vector2(28.0, 27.0) * unit, 12.0 * unit, 0.0, TAU, 24, Color("#d6b06a"), 1.1 * unit)
	_center_text_outline(Rect2(heal.x - 10.0 * unit, heal.y + 18.0 * unit, 20.0 * unit, 18.0 * unit), str(main_ref.heal_charges), maxi(8, roundi(12.0 * unit)), Color("#fff0d1"), 1)
	_draw_action_keycap(heal, heal_r, "E", unit)

	# R: reserved second active-skill socket. It is visual-only until its gameplay is implemented.
	draw_circle(reserved, reserved_r + 8.0 * unit, Color("#080b0c", 0.88))
	draw_arc(reserved, reserved_r + 5.0 * unit, 0.0, TAU, 56, Color("#b18b50", 0.86), 2.0 * unit, true)
	draw_circle(reserved, reserved_r - 5.0 * unit, Color("#17130e", 0.94))
	var scroll := PackedVector2Array([
		reserved + Vector2(-18.0, -27.0) * unit,
		reserved + Vector2(18.0, -23.0) * unit,
		reserved + Vector2(15.0, 26.0) * unit,
		reserved + Vector2(0.0, 31.0) * unit,
		reserved + Vector2(-17.0, 22.0) * unit
	])
	draw_colored_polygon(scroll, Color("#d6b36e", 0.86))
	draw_polyline(PackedVector2Array([scroll[0], scroll[1], scroll[2], scroll[3], scroll[4], scroll[0]]), Color("#f2d18a", 0.9), 1.4 * unit, true)
	draw_line(reserved + Vector2(-7.0, -12.0) * unit, reserved + Vector2(7.0, 12.0) * unit, Color("#a43b32", 0.95), 2.5 * unit, true)
	draw_line(reserved + Vector2(7.0, -12.0) * unit, reserved + Vector2(-7.0, 12.0) * unit, Color("#a43b32", 0.95), 2.5 * unit, true)
	_draw_action_keycap(reserved, reserved_r, "R", unit)

	# Q: current active skill. The outer arc communicates cooldown without adding another panel.
	draw_circle(skill, skill_r + 8.0 * unit, Color("#080b0c", 0.94))
	draw_arc(skill, skill_r + 5.0 * unit, 0.0, TAU, 64, Color("#e5bd69") if skill_ready else Color("#8c795c"), 2.6 * unit, true)
	draw_circle(skill, skill_r - 5.0 * unit, Color("#1a130a", 0.98))
	draw_arc(skill, skill_r * 0.48, -PI * 0.82, PI * 1.32, 48, Color("#f2c66e"), 4.0 * unit, true)
	draw_arc(skill + Vector2(4.0, -3.0) * unit, skill_r * 0.25, PI * 0.08, PI * 1.7, 36, Color("#fff0b5"), 2.4 * unit, true)
	draw_line(skill + Vector2(17.0, -19.0) * unit, skill + Vector2(27.0, -27.0) * unit, Color("#ffe7a2"), 2.5 * unit, true)
	if not skill_ready:
		var ratio := clampf(main_ref.active_skill_cooldown / maxf(0.1, main_ref.active_skill_base_cooldown), 0.0, 1.0)
		draw_arc(skill, skill_r + 8.0 * unit, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - ratio), 48, Color("#67c8b3"), 3.0 * unit, true)
		_center_text_outline(Rect2(skill - Vector2(24.0, 12.0) * unit, Vector2(48.0, 24.0) * unit), str(ceili(main_ref.active_skill_cooldown)), maxi(10, roundi(17.0 * unit)), Color("#ffffff"), 1)
	_draw_action_keycap(skill, skill_r, "Q", unit)


func _draw_action_keycap(center: Vector2, radius: float, key: String, unit: float) -> void:
	var rect := Rect2(Vector2(center.x - 22.0 * unit, center.y + radius + 3.0 * unit), Vector2(44.0, 25.0) * unit)
	draw_rect(rect, Color("#100e0b", 0.96))
	draw_rect(rect, Color("#d5ad70", 0.95), false, 1.1 * unit)
	_center_text_outline(rect, key, maxi(10, roundi(17.0 * unit)), Color("#f5d99a"), 1)


func _boss_profile_portrait() -> Texture2D:
	var profile: Dictionary = main_ref.get_boss_ui_profile()
	var path := str(profile.get("portrait_path", ""))
	# When future chapters define their own portrait, load once through the engine's
	# resource cache rather than hard-coding a new boss face in the HUD.
	if path.is_empty() or path == "res://assets/sprites/enemy_boss.svg":
		return BOSS_UI_PORTRAIT_DEFAULT
	var resource := load(path) as Texture2D
	return resource if resource != null else BOSS_UI_PORTRAIT_DEFAULT


func _equipped_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for skill_variant in main_ref.AUTO_SKILL_DEFS.keys():
		var sid := str(skill_variant)
		if main_ref.skills.has(sid):
			ids.append(sid)
	return ids


func reference_tooltip_at(position: Vector2) -> String:
	if main_ref == null or main_ref.state != "playing":
		return ""
	var view := get_viewport_rect().size
	var touch := _touch_layout(view)
	if position.distance_to(touch["heal_center"]) <= float(touch["heal_radius"]):
		return "heal"
	if position.distance_to(touch["skill_center"]) <= float(touch["skill_radius"]):
		return "active"
	if position.distance_to(touch["secondary_center"]) <= float(touch["secondary_radius"]):
		return "reserved_active"
	var layout := _reference_hud_layout(view)
	var slots: Rect2 = layout["slots"]
	var unit: float = layout["scale"]
	var owned := _equipped_skill_ids()
	var offsets := [55.0, 145.0, 215.0, 285.0]
	for i in range(mini(4, owned.size())):
		var center := slots.position + Vector2(slots.size.x * 0.5, offsets[i]) * unit
		if position.distance_to(center) <= 32.0 * unit:
			return "skill:" + owned[i]
	if slots.has_point(position) and owned.is_empty():
		return "basic"
	return ""


func begin_touch_inspect(index: int, position: Vector2) -> bool:
	var key := reference_tooltip_at(position)
	if key.is_empty() or pressed_touch_index >= 0:
		return false
	pressed_touch_index = index
	pressed_touch_position = position
	pressed_tooltip_key = key
	pressed_touch_action = reference_action_at(position)
	touch_tooltip_elapsed = 0.0
	touch_tooltip_long = false
	return true


func end_touch_inspect(index: int, position: Vector2) -> String:
	if index != pressed_touch_index:
		return ""
	var action := pressed_touch_action
	var was_long := touch_tooltip_long
	var travelled := position.distance_to(pressed_touch_position)
	pressed_touch_index = -1
	pressed_tooltip_key = ""
	pressed_touch_action = ""
	touch_tooltip_elapsed = 0.0
	touch_tooltip_long = false
	if was_long or travelled > 30.0 * _reference_hud_layout(get_viewport_rect().size)["scale"]:
		return ""
	return action


func _advance_tooltips(delta: float) -> void:
	if main_ref == null or main_ref.state != "playing":
		hovered_tooltip_key = ""
		hover_tooltip_elapsed = 0.0
		pressed_touch_index = -1
		pressed_tooltip_key = ""
		return
	if pressed_touch_index >= 0:
		touch_tooltip_elapsed += maxf(0.0, delta)
		if touch_tooltip_elapsed >= TOUCH_TOOLTIP_DELAY:
			touch_tooltip_long = true
		return
	if _is_mobile():
		return
	var key := reference_tooltip_at(get_viewport().get_mouse_position())
	if key != hovered_tooltip_key:
		hovered_tooltip_key = key
		hover_tooltip_elapsed = 0.0
	else:
		hover_tooltip_elapsed += maxf(0.0, delta)


func tooltip_details(key: String) -> Dictionary:
	if key == "reserved_active":
		return {"name":"第二主动道术", "level":"R · 预留技能槽", "detail":"为第二个主动技能保留的位置，当前版本尚未开放，不会触发技能。", "stat":"后续章节开发时接入"}
	if key == "heal":
		return {"name":"回春丹", "level":"治疗道具", "detail":"恢复最大生命值的 30%，满血时无法使用。", "stat":"剩余 %d 次 · E 使用" % main_ref.heal_charges}
	if key == "active":
		var lvl: int = main_ref.active_skill_level
		var ready_text := "就绪" if main_ref.active_skill_cooldown <= 0.0 else "冷却剩余 %.1f 秒" % main_ref.active_skill_cooldown
		return {"name":"镇尸诀", "level":"Lv%d · 主动道术" % lvl, "detail":"对周围邪祟造成伤害和减速，等级越高作用范围越大。", "stat":"%s · Q / Space 使用" % ready_text}
	if key == "basic":
		return {"name":"基础符箓", "level":"自动攻击", "detail":"自动攻击附近邪祟，伤害和攻击间隔受角色属性影响。", "stat":"伤害 %d · 间隔 %.2f 秒" % [roundi(main_ref.player.damage), main_ref.player.attack_interval]}
	if key.begins_with("skill:"):
		var skill_id := key.trim_prefix("skill:")
		if not main_ref.skills.has(skill_id) or not main_ref.AUTO_SKILL_DEFS.has(skill_id):
			return {}
		var data: Dictionary = main_ref.skills[skill_id]
		var def: Dictionary = main_ref.AUTO_SKILL_DEFS[skill_id]
		var name := str(def.get("name", skill_id))
		var evolved := str(data.get("evolved", ""))
		if not evolved.is_empty():
			name += " · 已进化"
		var branch := str(data.get("branch", ""))
		var branch_name := ""
		for item in main_ref.SKILL_BRANCHES.get(skill_id, []):
			if str(item.get("id", "")) == branch:
				branch_name = str(item.get("name", ""))
		var stat := "基础冷却 %.2f 秒" % float(def.get("cooldown", 0.0))
		if not branch_name.is_empty():
			stat += " · " + branch_name
		return {"name":name, "level":"Lv%d · 自动技能" % int(data.get("level", 1)), "detail":str(def.get("desc", "")), "stat":stat}
	return {}


func _draw_reference_tooltip(view: Vector2) -> void:
	var key := ""
	var unit: float = _reference_hud_layout(view)["scale"]
	if pressed_touch_index >= 0:
		if touch_tooltip_long:
			key = pressed_tooltip_key
	elif hover_tooltip_elapsed >= MOUSE_TOOLTIP_DELAY:
		key = hovered_tooltip_key
	if key.is_empty():
		return
	var detail := tooltip_details(key)
	if detail.is_empty():
		return
	var size := Vector2(302.0, 137.0) * unit
	var anchor := Vector2.ZERO
	if key.begins_with("skill:") or key == "basic":
		var layout := _reference_hud_layout(view)
		var slots: Rect2 = layout["slots"]
		anchor = Vector2(slots.position.x - size.x - 10.0 * unit, slots.position.y + 22.0 * unit)
	else:
		var touch := _touch_layout(view)
		var center: Vector2 = touch["skill_center"] if key == "active" else (touch["secondary_center"] if key == "reserved_active" else touch["heal_center"])
		anchor = Vector2(center.x - size.x * 0.5, center.y - size.y - 57.0 * unit)
	anchor.x = clampf(anchor.x, 5.0 * unit, maxf(5.0 * unit, view.x - size.x - 5.0 * unit))
	anchor.y = clampf(anchor.y, 5.0 * unit, maxf(5.0 * unit, view.y - size.y - 5.0 * unit))
	var panel := Rect2(anchor, size)
	_reference_panel(panel, Color("#d3ab65"), unit)
	_text(panel.position + Vector2(13.0, 26.0) * unit, str(detail["name"]), maxi(9, roundi(17.0 * unit)), Color("#f6d99e"))
	_text(panel.position + Vector2(13.0, 47.0) * unit, str(detail["level"]), maxi(8, roundi(12.0 * unit)), Color("#b9e1cf"))
	_draw_wrapped_text(Rect2(panel.position + Vector2(13.0, 53.0) * unit, Vector2(size.x - 26.0 * unit, 52.0 * unit)), str(detail["detail"]), maxi(8, roundi(11.0 * unit)), TEXT_COLOR, 2)
	draw_line(panel.position + Vector2(12.0, 113.0) * unit, panel.position + Vector2(290.0, 113.0) * unit, Color("#9b7746", 0.72), unit)
	_text(panel.position + Vector2(13.0, 129.0) * unit, str(detail["stat"]), maxi(8, roundi(10.0 * unit)), Color("#f2cb85"))


func _draw_hud(view: Vector2) -> void:
	var player = main_ref.player
	if player == null:
		return

	var layout := _hud_layout(view)
	if bool(layout.get("compact", false)):
		_draw_compact_hud(view, layout)
		return
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
	_text(Vector2(info_x, status_rect.position.y + 22.0 * scale), str(player.character_display_name), maxi(11, roundi(16.0 * scale)), Color("#e7cf98"))
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

func _draw_compact_hud(view: Vector2, layout: Dictionary) -> void:
	var player = main_ref.player
	if player == null:
		return
	var status_rect: Rect2 = layout["status"]
	var time_rect: Rect2 = layout["time"]
	var skill_rect: Rect2 = layout["skill"]
	var objective_rect: Rect2 = layout["objective"]
	var build_rect: Rect2 = layout["build"]
	var controls_rect: Rect2 = layout["controls"]
	var ultra_compact := bool(layout.get("ultra_compact", false))

	_draw_ornate_panel(status_rect, Color("#c6a566"))
	var portrait_size := 29.0 if ultra_compact else 34.0
	var portrait_center := Vector2(status_rect.position.x + (22.0 if ultra_compact else 25.0), status_rect.position.y + status_rect.size.y * 0.5)
	draw_circle(portrait_center, portrait_size * 0.55, Color("#0b0e10"))
	draw_arc(portrait_center, portrait_size * 0.56, 0.0, TAU, 36, Color("#d5ad61"), 1.5)
	draw_texture_rect(PLAYER_PORTRAIT_TEXTURE, Rect2(portrait_center - Vector2.ONE * portrait_size * 0.5, Vector2.ONE * portrait_size), false)
	var info_x := status_rect.position.x + (42.0 if ultra_compact else 47.0)
	_text(Vector2(info_x, status_rect.position.y + (14.0 if ultra_compact else 17.0)), "镇邪录", 10 if ultra_compact else 11, Color("#e7cf98"))
	_text(Vector2(info_x, status_rect.position.y + (26.0 if ultra_compact else 31.0)), "生命 %d/%d" % [roundi(player.hp), roundi(player.max_hp)], 8 if ultra_compact else 9, TEXT_COLOR)
	var hp_width := maxf(28.0, status_rect.end.x - info_x - 8.0)
	_bar(Rect2(info_x, status_rect.position.y + (30.0 if ultra_compact else 36.0), hp_width, 3.5 if ultra_compact else 4.0), player.hp / maxf(1.0, player.max_hp), Color("#c54e42"), true)
	_text(Vector2(info_x, status_rect.position.y + (43.0 if ultra_compact else 53.0)), "Lv%d · 击杀%d" % [player.level, main_ref.kills], 8 if ultra_compact else 9, MUTED_COLOR)

	_draw_ornate_panel(time_rect, Color("#b69a62"))
	_text(Vector2(time_rect.position.x + 9.0, time_rect.position.y + (14.0 if ultra_compact else 17.0)), "生存 " + _format_time(main_ref.elapsed_seconds), 10 if ultra_compact else 11, TEXT_COLOR)
	if _is_mobile():
		_text(Vector2(time_rect.end.x - 18.0, time_rect.position.y + (14.0 if ultra_compact else 17.0)), "Ⅱ", 11 if ultra_compact else 12, Color("#e8c86c"))
	_text(Vector2(time_rect.position.x + 9.0, time_rect.position.y + (26.0 if ultra_compact else 32.0)), "灵气 %d/%d" % [player.xp, player.xp_to_next], 8 if ultra_compact else 9, MUTED_COLOR)
	_bar(Rect2(time_rect.position.x + 8.0, time_rect.position.y + (31.0 if ultra_compact else 37.0), time_rect.size.x - 16.0, 2.5 if ultra_compact else 3.0), float(player.xp) / maxf(1.0, float(player.xp_to_next)), Color("#6ebba0"))

	_draw_ornate_panel(skill_rect, Color("#c6a566"))
	var skill_ready: bool = main_ref.active_skill_cooldown <= 0.0
	var skill_color := Color("#e8c86c") if skill_ready else Color("#9e8b6a")
	_text(Vector2(skill_rect.position.x + 8.0, skill_rect.position.y + (14.0 if ultra_compact else 17.0)), "镇尸诀 Lv%d" % main_ref.active_skill_level, 9 if ultra_compact else 10, skill_color)
	_text(Vector2(skill_rect.position.x + 8.0, skill_rect.position.y + (26.0 if ultra_compact else 31.0)), "就绪" if skill_ready else "冷却 %ds" % ceili(main_ref.active_skill_cooldown), 8 if ultra_compact else 9, TEXT_COLOR)
	var skill_ratio := 1.0 if skill_ready else 1.0 - clampf(main_ref.active_skill_cooldown / maxf(0.1, main_ref.active_skill_base_cooldown), 0.0, 1.0)
	_bar(Rect2(skill_rect.position.x + 8.0, skill_rect.position.y + (31.0 if ultra_compact else 36.0), skill_rect.size.x - 16.0, 2.5 if ultra_compact else 4.0), skill_ratio, Color("#d1a84e"))
	_text(Vector2(skill_rect.position.x + 8.0, skill_rect.position.y + (43.0 if ultra_compact else 52.0)), "治疗 %d/2 · 伤害%d" % [main_ref.heal_charges, roundi(player.damage)], 8 if ultra_compact else 9, MUTED_COLOR)

	if main_ref.state != "game_over" and main_ref.state != "victory":
		_draw_ornate_panel(objective_rect, Color("#c9a65b") if main_ref.boss_spawned else Color("#8fba9b"))
		var objective := objective_data()
		_text(Vector2(objective_rect.position.x + 8.0, objective_rect.position.y + (9.0 if ultra_compact else 12.0)), str(objective.get("title", "当前目标")), 8 if ultra_compact else 9, Color("#e7cf98"))
		_text(Vector2(objective_rect.position.x + 8.0, objective_rect.position.y + (19.0 if ultra_compact else 23.0)), str(objective.get("detail", "")), 8 if ultra_compact else 9, TEXT_COLOR)
		if not ultra_compact:
			_bar(Rect2(objective_rect.position.x + 8.0, objective_rect.end.y - 4.0, objective_rect.size.x - 16.0, 2.0), float(objective.get("progress", 0.0)), Color("#c9a65b"))

	var boss = main_ref.get_boss()
	if boss != null:
		var boss_rect: Rect2 = layout["boss"]
		_draw_ornate_panel(boss_rect, Color("#a84b3c"))
		_text(Vector2(boss_rect.position.x + 8.0, boss_rect.position.y + (14.0 if ultra_compact else 17.0)), "尸王" + (" · 暴走" if boss.hp / boss.max_hp <= 0.5 else ""), 9 if ultra_compact else 10, Color("#e7c88a"))
		_bar(Rect2(boss_rect.position.x + 72.0, boss_rect.position.y + (8.0 if ultra_compact else 11.0), boss_rect.size.x - 82.0, 4.0 if ultra_compact else 5.0), boss.hp / maxf(1.0, boss.max_hp), Color("#a44439"), true)

	# One-row build strip: four skill slots and three artifact slots, with no overlapping labels.
	_draw_ornate_panel(build_rect, Color("#8b7758"))
	var primary_text := "待立道" if main_ref.primary_element.is_empty() else "主修%s" % main_ref._element_name(main_ref.primary_element)
	_text(Vector2(build_rect.position.x + 8.0, build_rect.position.y + (10.0 if ultra_compact else 12.0)), "构筑 · " + primary_text, 8 if ultra_compact else 9, Color("#e7cf98"))
	var owned_skill_ids: Array = []
	for skill_variant in main_ref.AUTO_SKILL_DEFS.keys():
		var skill_id := str(skill_variant)
		if main_ref.skills.has(skill_id):
			owned_skill_ids.append(skill_id)
	var artifact_ids: Array = []
	for artifact_variant in main_ref.ARTIFACT_DEFS.keys():
		var artifact_id := str(artifact_variant)
		if main_ref.artifacts.has(artifact_id):
			artifact_ids.append(artifact_id)
	var slot_width := (build_rect.size.x - 20.0) / 7.0
	var icon_radius := minf(9.0 if ultra_compact else 10.0, slot_width * 0.22)
	var icon_y := build_rect.position.y + (23.0 if ultra_compact else 29.0)
	for i in range(7):
		var center := Vector2(build_rect.position.x + 10.0 + (float(i) + 0.5) * slot_width, icon_y)
		var has_item := false
		var shown_id := ""
		var item_level := 0
		if i < 4 and i < owned_skill_ids.size():
			var owned_skill_id := str(owned_skill_ids[i])
			var skill_data: Dictionary = main_ref.skills[owned_skill_id]
			shown_id = str(skill_data.get("evolved", "")) if not str(skill_data.get("evolved", "")).is_empty() else owned_skill_id
			item_level = int(skill_data.get("level", 1))
			has_item = true
		elif i >= 4 and i - 4 < artifact_ids.size():
			var owned_artifact_id := str(artifact_ids[i - 4])
			var artifact_data: Dictionary = main_ref.artifacts[owned_artifact_id]
			shown_id = owned_artifact_id
			item_level = int(artifact_data.get("level", 1))
			has_item = true
		if has_item:
			_draw_card_art(center, shown_id, _upgrade_color(shown_id), icon_radius)
			if not ultra_compact:
				_text(center + Vector2(icon_radius * 0.72, -icon_radius * 0.58), str(item_level), 7, TEXT_COLOR)
		else:
			draw_circle(center, icon_radius * 0.78, Color(0.08, 0.075, 0.065, 0.82))
			draw_arc(center, icon_radius * 0.78, 0.0, TAU, 20, Color(0.55, 0.49, 0.38, 0.35), 0.8)

	_draw_ornate_panel(controls_rect, Color("#8f805d"))
	if not _is_mobile():
		_center_text(controls_rect, "WASD 移动 · SPACE 镇尸诀 · E 治疗 · ESC 暂停", 7 if ultra_compact else 9, MUTED_COLOR)
	else:
		_center_text(controls_rect, "左侧移动 · 右侧道术 / 治疗", 7 if ultra_compact else 9, MUTED_COLOR)


func _compact_artifact_label(artifact_id: String) -> String:
	match artifact_id:
		"cold_relic":
			return "寒魄"
		"thunder_seal":
			return "天雷"
		"talisman_scroll":
			return "秘卷"
		"sword_manual":
			return "御剑"
		"formation_manual":
			return "镇岳"
		"body_jade":
			return "护身"
		_:
			return "法宝"

func _draw_level_up(view: Vector2) -> void:
	var layout := _level_up_layout(view)
	var panel_rect: Rect2 = layout["panel"]
	var card_rects: Array = layout["cards"]
	var scale: float = layout["scale"]
	var header_title_size := maxi(16, roundi(28.0 * scale))
	var subtitle_size := maxi(9, roundi(14.0 * scale))

	# Dim the live battle without hiding the cemetery scene and player silhouette.
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.006, 0.009, 0.014, 0.48))
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
	# Keep the refresh button below the existing panel, outside the card artwork.
	var reroll_rect: Rect2 = layout["reroll"]
	var can_reroll: bool = main_ref.can_reroll_level_cards()
	var reroll_hovered := can_reroll and reroll_rect.has_point(get_viewport().get_mouse_position())
	var reroll_tint := Color("#f2d18e") if can_reroll else Color("#817564")
	draw_rect(reroll_rect, Color("#23190e", 0.98) if can_reroll else Color("#181715", 0.94))
	draw_rect(reroll_rect, reroll_tint, false, 1.7 * scale if reroll_hovered else 1.05 * scale)
	var reroll_label := "刷新选项  %d/%d  ·  F" % [main_ref.rerolls_remaining, main_ref.REROLLS_PER_STAGE] if can_reroll else "刷新不可用  ·  剩余 %d" % main_ref.rerolls_remaining
	_center_text(reroll_rect, reroll_label, maxi(9, roundi(13.0 * scale)), reroll_tint)
	var divider_y := panel_rect.position.y + float(layout["header_height"]) - 8.0 * scale
	draw_line(Vector2(panel_rect.position.x + 28.0 * scale, divider_y), Vector2(panel_rect.end.x - 28.0 * scale, divider_y), Color("#b08d50", 0.78), 1.1 * scale)
	draw_circle(Vector2(panel_rect.get_center().x, divider_y), 3.0 * scale, Color("#e6c779"))

	for i in range(mini(3, main_ref.level_cards.size())):
		var card: Dictionary = main_ref.level_cards[i]
		var rect: Rect2 = card_rects[i]
		var card_id := str(card.get("id", ""))
		var card_kind := str(card.get("kind", ""))
		var icon_id := str(card.get("icon", card_id))
		var locked_info := card_kind == "branch_required_info"
		var accent := Color("#756d5e") if locked_info else _upgrade_color(card_id)
		var hovered := not locked_info and rect.has_point(get_viewport().get_mouse_position())
		var border_alpha := 1.0 if hovered else 0.78
		draw_rect(rect, Color("#100d0b", 0.99))
		draw_rect(rect, Color(accent.r, accent.g, accent.b, border_alpha), false, 1.6 * scale if hovered else 1.1 * scale)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0 * scale)), accent)
		draw_rect(rect.grow(-6.0 * scale), Color(accent.r, accent.g, accent.b, 0.07), false, 1.0 * scale)
		for corner in [rect.position + Vector2(8.0, 10.0) * scale, Vector2(rect.end.x - 8.0 * scale, rect.position.y + 10.0 * scale), Vector2(rect.position.x + 8.0 * scale, rect.end.y - 10.0 * scale), rect.end - Vector2(8.0, 10.0) * scale]:
			var sx := 1.0 if corner.x < rect.get_center().x else -1.0
			var sy := 1.0 if corner.y < rect.get_center().y else -1.0
			draw_line(corner, corner + Vector2(sx * 10.0 * scale, 0.0), Color(accent.r, accent.g, accent.b, 0.85), 1.1 * scale)
			draw_line(corner, corner + Vector2(0.0, sy * 10.0 * scale), Color(accent.r, accent.g, accent.b, 0.85), 1.1 * scale)

		var art_height := minf(206.0 * scale, rect.size.y * 0.52)
		var art_rect := Rect2(rect.position + Vector2(8.0, 8.0) * scale, Vector2(rect.size.x - 16.0 * scale, art_height))
		_draw_skill_card_illustration(art_rect, icon_id, accent)
		if locked_info:
			draw_rect(art_rect, Color("#070809", 0.38))

		var tag := "攻击"
		if card_kind == "branch_required_info":
			tag = "提示"
		elif card_kind == "skill_evolution":
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
		_center_text(Rect2(rect.position.x + 12.0 * scale, title_y, rect.size.x - 24.0 * scale, 23.0 * scale), title_text, title_size, Color("#b8ad99") if locked_info else Color("#f0d79b"))
		_center_text(Rect2(rect.position.x + 12.0 * scale, title_y + 22.0 * scale, rect.size.x - 24.0 * scale, 17.0 * scale), str(card.get("category", _upgrade_category(card_id))), maxi(8, roundi(11.0 * scale)), accent)

		var footer_y := rect.end.y - 14.0 * scale
		var divider_y_card := rect.end.y - 58.0 * scale
		var desc_y := title_y + 42.0 * scale
		var desc_height := maxf(20.0 * scale, divider_y_card - desc_y - 8.0 * scale)
		_draw_wrapped_text(Rect2(rect.position.x + 15.0 * scale, desc_y, rect.size.x - 30.0 * scale, desc_height), str(card.get("desc", "")), maxi(9, roundi(12.0 * scale)), MUTED_COLOR if locked_info else TEXT_COLOR, 2)
		draw_line(Vector2(rect.position.x + 14.0 * scale, divider_y_card), Vector2(rect.end.x - 14.0 * scale, divider_y_card), Color("#8e7449", 0.75), 1.0 * scale)
		draw_colored_polygon(PackedVector2Array([
			Vector2(rect.position.x + 18.0 * scale, divider_y_card + 17.0 * scale),
			Vector2(rect.position.x + 23.0 * scale, divider_y_card + 12.0 * scale),
			Vector2(rect.position.x + 28.0 * scale, divider_y_card + 17.0 * scale),
			Vector2(rect.position.x + 23.0 * scale, divider_y_card + 22.0 * scale)
		]), Color("#e5bd70"))
		_text(Vector2(rect.position.x + 34.0 * scale, divider_y_card + 21.0 * scale), _card_effect_line(card), maxi(8, roundi(11.0 * scale)), Color("#d9c59d"))
		var footer_text := "先选择前两项" if locked_info else "按 %d 选择  ·  点击卡片" % (i + 1)
		_center_text(Rect2(rect.position.x + 8.0 * scale, footer_y - 2.0 * scale, rect.size.x - 16.0 * scale, 13.0 * scale), footer_text, maxi(8, roundi(10.5 * scale)), Color("#c8b99a") if hovered else MUTED_COLOR)
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
			return "寒潮"
		"earth_formation":
			return "地脉"
	return "术法"


func _hud_layout(view: Vector2) -> Dictionary:
	var compact := view.x <= 1120.0 or view.y <= 640.0
	if compact:
		var ultra_compact := view.y <= 400.0
		var scale := clampf(minf(view.x / 1280.0, view.y / 720.0), 0.56 if ultra_compact else 0.62, 0.85)
		var margin := 8.0
		var left_width := minf(184.0 if ultra_compact else 194.0, view.x * 0.30)
		var right_width := minf(148.0 if ultra_compact else 160.0, view.x * 0.25)
		var time_width := minf(150.0 if ultra_compact else 170.0, view.x * 0.28)
		var status_rect := Rect2(margin, margin, left_width, 50.0 if ultra_compact else 60.0)
		var skill_rect := Rect2(view.x - margin - right_width, margin, right_width, 50.0 if ultra_compact else 60.0)
		var time_rect := Rect2((view.x - time_width) * 0.5, margin, time_width, 38.0 if ultra_compact else 44.0)
		var objective_width := minf(220.0, maxf(165.0, view.x - left_width - right_width - margin * 2.0 - 16.0))
		var objective_rect := Rect2((view.x - objective_width) * 0.5, margin + (43.0 if ultra_compact else 52.0), objective_width, 24.0 if ultra_compact else 30.0)
		var boss_width := minf(300.0 if ultra_compact else 340.0, view.x * 0.56)
		var boss_rect := Rect2((view.x - boss_width) * 0.5, objective_rect.end.y + 3.0, boss_width, 22.0 if ultra_compact else 27.0)
		var controls_width := minf(320.0, minf(view.x - margin * 2.0, view.x * 0.52))
		var controls_height := 16.0 if ultra_compact else 20.0
		var controls_rect := Rect2((view.x - controls_width) * 0.5, view.y - (56.0 if ultra_compact else 76.0), controls_width, controls_height)
		var build_width := minf(380.0 if ultra_compact else 420.0, minf(view.x - margin * 2.0, view.x * (0.78 if ultra_compact else 0.58)))
		var build_height := 32.0 if ultra_compact else 42.0
		var build_rect := Rect2((view.x - build_width) * 0.5, view.y - (36.0 if ultra_compact else 48.0), build_width, build_height)
		return {"scale": scale, "compact": true, "ultra_compact": ultra_compact, "status": status_rect, "objective": objective_rect, "time": time_rect, "skill": skill_rect, "build": build_rect, "controls": controls_rect, "boss": boss_rect}
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
	return {"scale": scale, "compact": false, "status": status_rect, "objective": objective_rect, "time": time_rect, "skill": skill_rect, "build": build_rect, "controls": controls_rect, "boss": boss_rect}

func _level_up_layout(view: Vector2) -> Dictionary:
	var margin := maxf(8.0, minf(18.0, view.x * 0.018))
	var panel_width := maxf(120.0, minf(1080.0, minf(view.x * 0.82, view.x - margin * 2.0)))
	var panel_height := maxf(160.0, minf(520.0, minf(view.y * 0.78, view.y - margin * 2.0)))
	var scale := clampf(minf(view.x / 1280.0, view.y / 720.0), 0.62, 1.0)
	var panel_rect := Rect2((view.x - panel_width) * 0.5, (view.y - panel_height) * 0.5, panel_width, panel_height)
	var header_height := minf(122.0 * scale, panel_height * 0.24)
	var inner_margin := clampf(panel_width * 0.032, 12.0, 30.0)
	var gap := clampf(panel_width * 0.022, 10.0, 24.0)
	var card_width := maxf(40.0, (panel_width - inner_margin * 2.0 - gap * 2.0) / 3.0)
	var card_y := panel_rect.position.y + header_height
	var card_height := maxf(90.0, panel_rect.end.y - card_y - 22.0 * scale)
	var cards: Array = []
	for i in range(3):
		cards.append(Rect2(panel_rect.position.x + inner_margin + float(i) * (card_width + gap), card_y, card_width, card_height))
	var reroll_size := Vector2(minf(235.0 * scale, panel_width * 0.48), 31.0 * scale)
	var reroll_rect := Rect2(Vector2(panel_rect.get_center().x - reroll_size.x * 0.5, panel_rect.end.y + 7.0 * scale), reroll_size)
	return {"panel": panel_rect, "cards": cards, "reroll": reroll_rect, "header_height": header_height, "scale": scale}


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
		"branch_required_info":
			return "前两项为有效选择"
		"skill_evolution":
			return "终极进化 · 战斗表现质变"
		"element_cultivation":
			return "元素修炼 · 强化专属效果"
		"artifact_acquire":
			var artifact_id := str(card.get("artifact_id", ""))
			if main_ref.primary_element.is_empty():
				return "被动法器 · 不锁定主修"
			if main_ref._element_for_artifact(artifact_id) == main_ref.primary_element:
				return "主修法宝 · 满足进化条件"
			return "辅助法器 · 不解锁主修进化"
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
	var profile: Dictionary = main_ref.get_boss_ui_profile()
	var boss_name := str(profile.get("name", "尸王"))
	var appearance := maxf(1.0, float(profile.get("spawn_time", 480.0)))
	if main_ref.state == "victory":
		return {"title":"任务完成 · " + boss_name + "伏诛", "detail":"本局目标已达成", "progress":1.0, "kind":"success", "boss_name":boss_name}
	if main_ref.state == "game_over":
		return {"title":"本局结束 · 阳寿已尽", "detail":"整备后可重新挑战", "progress":0.0, "kind":"failed", "boss_name":boss_name}
	if main_ref.boss_spawned:
		var boss = main_ref.get_boss()
		if boss != null:
			var progress := 1.0 - clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)
			return {"title":"当前目标 · 击败尸王", "detail":"尸王降临 · 抓住输出时机", "progress":progress, "kind":"boss", "boss_name":boss_name}
		return {"title":"当前目标 · 清理战场", "detail":"尸王战斗正在收尾", "progress":0.9, "kind":"boss", "boss_name":boss_name}
	var remaining := maxi(0, ceili(appearance - main_ref.elapsed_seconds))
	return {
		"title":"当前目标 · 镇压尸潮",
		"detail":"尸王现身倒计时 %02d:%02d" % [remaining / 60, remaining % 60],
		"remaining_seconds":remaining,
		"boss_name":boss_name,
		"progress":clampf(main_ref.elapsed_seconds / appearance, 0.0, 1.0),
		"kind":"survival"
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
	var unit := clampf(minf(art_rect.size.x / 320.0, art_rect.size.y / 208.0), 0.42, 1.0)
	draw_rect(art_rect, Color("#080d12"))
	var inset := 4.0 * unit
	var image_rect := Rect2(art_rect.position + Vector2(inset, inset), art_rect.size - Vector2(inset * 2.0, inset * 2.0))
	if _uses_water_formation_card_art(icon_id):
		# The water skill uses a dedicated high-detail vortex illustration; the card frame stays live UI.
		draw_texture_rect(WATER_COLD_TIDE_CARD_TEXTURE, image_rect, false)
		draw_rect(image_rect, Color(0.015, 0.02, 0.025, 0.025))
	else:
		var art_region := _skill_card_art_region(icon_id)
		if art_region.size.x > 0.0:
			draw_texture_rect_region(SKILL_CARD_ART_ATLAS, image_rect, art_region, Color.WHITE, false)
			draw_rect(image_rect, Color(0.015, 0.02, 0.025, 0.08))
		else:
			draw_rect(art_rect, Color(accent.r, accent.g, accent.b, 0.12))
			draw_circle(art_rect.get_center(), minf(art_rect.size.y * 0.38, art_rect.size.x * 0.22), Color(accent.r, accent.g, accent.b, 0.12))
			_draw_card_art(art_rect.get_center(), icon_id, accent, minf(54.0 * unit, art_rect.size.y * 0.3))
			draw_rect(art_rect.grow(-4.0 * unit), Color(accent.r, accent.g, accent.b, 0.1), false, 1.0 * unit)
	draw_rect(art_rect, Color(accent.r, accent.g, accent.b, 0.52), false, 1.0 * unit)
	draw_line(art_rect.position + Vector2(7.0 * unit, 7.0 * unit), art_rect.position + Vector2(27.0 * unit, 7.0 * unit), Color("#e5c579", 0.92), 1.2 * unit)
	draw_line(art_rect.position + Vector2(7.0 * unit, 7.0 * unit), art_rect.position + Vector2(7.0 * unit, 27.0 * unit), Color("#e5c579", 0.92), 1.2 * unit)
	draw_line(Vector2(art_rect.end.x - 7.0 * unit, art_rect.end.y - 7.0 * unit), Vector2(art_rect.end.x - 27.0 * unit, art_rect.end.y - 7.0 * unit), Color("#e5c579", 0.92), 1.2 * unit)
	draw_line(Vector2(art_rect.end.x - 7.0 * unit, art_rect.end.y - 7.0 * unit), Vector2(art_rect.end.x - 7.0 * unit, art_rect.end.y - 27.0 * unit), Color("#e5c579", 0.92), 1.2 * unit)


func _uses_water_formation_card_art(icon_id: String) -> bool:
	return icon_id in ["water_array", "ice_array", "cold_relic"]

func _center_text_origin(rect: Rect2, value: String, size: int) -> Vector2:
	var font: Font = ThemeDB.fallback_font
	var text_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var text_height := font.get_ascent(size) + font.get_descent(size)
	var x := rect.position.x + maxf(0.0, (rect.size.x - text_width) * 0.5)
	var baseline := rect.position.y + (rect.size.y - text_height) * 0.5 + font.get_ascent(size)
	return Vector2(x, baseline)


func _center_text(rect: Rect2, value: String, size: int, color: Color) -> void:
	# draw_string() receives a baseline, not a top-left point. Center by actual font metrics.
	draw_string(ThemeDB.fallback_font, _center_text_origin(rect, value, size), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


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


func _skill_card_art_region(icon_id: String) -> Rect2:
	if icon_id.begins_with("cultivation_"):
		if icon_id.contains("metal"):
			return Rect2(1920.0, 0.0, 320.0, 208.0)
		if icon_id.contains("wood"):
			return Rect2(2240.0, 0.0, 320.0, 208.0)
		if icon_id.contains("water"):
			return Rect2(2560.0, 0.0, 320.0, 208.0)
		if icon_id.contains("fire"):
			return Rect2(2880.0, 0.0, 320.0, 208.0)
		if icon_id.contains("earth"):
			return Rect2(3200.0, 0.0, 320.0, 208.0)
		if icon_id.contains("thunder"):
			return Rect2(3520.0, 0.0, 320.0, 208.0)
	if icon_id.contains("greenwood") or icon_id.contains("body_jade"):
		return Rect2(2240.0, 0.0, 320.0, 208.0)
	if icon_id.contains("peachwood"):
		return Rect2(960.0, 0.0, 320.0, 208.0)
	if icon_id.contains("fire") or icon_id.contains("heavenfire") or icon_id.contains("talisman_scroll"):
		return Rect2(0.0, 0.0, 320.0, 208.0)
	if icon_id.contains("thunder"):
		return Rect2(320.0, 0.0, 320.0, 208.0)
	if icon_id.contains("copper_coin") or icon_id.contains("golden_sword") or icon_id.contains("sword_manual"):
		return Rect2(640.0, 0.0, 320.0, 208.0)
	if icon_id.contains("water") or icon_id.contains("ice") or icon_id.contains("cold_relic"):
		return Rect2(1280.0, 0.0, 320.0, 208.0)
	if icon_id.contains("earth") or icon_id.contains("formation_manual") or icon_id.contains("earth_seal"):
		return Rect2(1600.0, 0.0, 320.0, 208.0)
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
		return Color("#dcefff")
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


func _touch_layout(view: Vector2) -> Dictionary:
	var scale := clampf(minf(view.x / 1672.0, view.y / 941.0), 0.36, 1.5)
	var offset := (view - Vector2(1672.0, 941.0) * scale) * 0.5
	var joystick_center := offset + Vector2(173.0, 782.0) * scale
	# Triangular action cluster: E healing, Q primary active, R reserved second active.
	var heal_center := offset + Vector2(1375.0, 802.0) * scale
	var secondary_center := offset + Vector2(1447.0, 727.0) * scale
	var skill_center := offset + Vector2(1532.0, 802.0) * scale
	var joystick_radius := 85.0 * scale
	var skill_radius := 53.0 * scale
	var heal_radius := 45.0 * scale
	var secondary_radius := 49.0 * scale
	return {
		"scale": scale, "offset": offset,
		"joystick_center": joystick_center, "joystick_radius": joystick_radius,
		"joystick_move_radius": 49.0 * scale,
		"skill_center": skill_center, "skill_radius": skill_radius, "skill_hit_radius": 59.0 * scale,
		"heal_center": heal_center, "heal_radius": heal_radius, "heal_hit_radius": 52.0 * scale,
		"secondary_center": secondary_center, "secondary_radius": secondary_radius
	}


func _draw_touch_controls(view: Vector2) -> void:
	var touch := _touch_layout(view)
	var scale: float = touch["scale"]
	var joystick_center: Vector2 = touch["joystick_center"]
	var joystick_radius: float = touch["joystick_radius"]
	draw_circle(joystick_center, joystick_radius, Color(0.06, 0.06, 0.05, 0.34))
	draw_arc(joystick_center, joystick_radius, 0.0, TAU, 40, Color(0.85, 0.78, 0.62, 0.65), 2.0 * scale)
	var knob_offset: Vector2 = main_ref.player.mobile_move * 28.0 * scale
	draw_circle(joystick_center + knob_offset, 24.0 * scale, Color(0.78, 0.68, 0.48, 0.42))
	draw_arc(joystick_center + knob_offset, 24.0 * scale, 0.0, TAU, 32, Color("#e2c77f", 0.7), 1.2 * scale)
	var skill_center: Vector2 = touch["skill_center"]
	var skill_radius: float = touch["skill_radius"]
	var skill_ready: bool = main_ref.active_skill_cooldown <= 0.0
	var skill_color := Color("#e8c86c") if skill_ready else Color("#9e8b6a")
	draw_circle(skill_center, skill_radius, Color(0.055, 0.05, 0.04, 0.84))
	draw_arc(skill_center, skill_radius, 0.0, TAU, 40, skill_color, 2.4 * scale)
	_draw_skill_emblem(skill_center, skill_ready, skill_color)
	_center_text(Rect2(skill_center.x - 32.0 * scale, skill_center.y + skill_radius * 0.38, 64.0 * scale, 15.0 * scale), "镇尸诀", maxi(9, roundi(10.0 * scale)), TEXT_COLOR)
	var heal_center: Vector2 = touch["heal_center"]
	var heal_radius: float = touch["heal_radius"]
	draw_circle(heal_center, heal_radius, Color(0.055, 0.05, 0.04, 0.84))
	draw_arc(heal_center, heal_radius, 0.0, TAU, 32, Color("#c16b55"), 2.0 * scale)
	_center_text(Rect2(heal_center.x - 20.0 * scale, heal_center.y - 10.0 * scale, 40.0 * scale, 20.0 * scale), "疗 %d" % main_ref.heal_charges, maxi(9, roundi(10.0 * scale)), TEXT_COLOR)

func reroll_button_at(screen_position: Vector2) -> bool:
	var layout := _level_up_layout(get_viewport_rect().size)
	var rect: Rect2 = layout["reroll"]
	return rect.has_point(screen_position)


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



func _draw_health_pill(rect: Rect2, ratio: float, fill_color: Color, outline: bool = true) -> void:
	var background := Color("#170d0b", 0.96)
	var border := Color(0.72, 0.60, 0.42, 0.76)
	var radius := minf(rect.size.y * 0.5, rect.size.x * 0.5)
	var center_y := rect.get_center().y
	var left_center := Vector2(rect.position.x + radius, center_y)
	var right_center := Vector2(rect.end.x - radius, center_y)
	# Full pill-shaped dark track.
	draw_circle(left_center, radius, background)
	draw_circle(right_center, radius, background)
	if right_center.x > left_center.x:
		draw_rect(Rect2(left_center.x, rect.position.y, right_center.x - left_center.x, rect.size.y), background)
	# Keep the filled portion rounded at both ends, including when health is low.
	var fill_width := rect.size.x * clampf(ratio, 0.0, 1.0)
	if fill_width > 0.0:
		var pill_width := minf(rect.size.x, maxf(rect.size.y, fill_width))
		var fill_right := Vector2(rect.position.x + pill_width - radius, center_y)
		draw_circle(left_center, radius, fill_color)
		draw_circle(fill_right, radius, fill_color)
		if fill_right.x > left_center.x:
			draw_rect(Rect2(left_center.x, rect.position.y, fill_right.x - left_center.x, rect.size.y), fill_color)
	if outline:
		draw_line(Vector2(left_center.x, rect.position.y), Vector2(right_center.x, rect.position.y), border, 0.8, true)
		draw_line(Vector2(left_center.x, rect.end.y), Vector2(right_center.x, rect.end.y), border, 0.8, true)
		draw_arc(left_center, radius, PI * 0.5, PI * 1.5, 16, border, 0.8, true)
		draw_arc(right_center, radius, -PI * 0.5, PI * 0.5, 16, border, 0.8, true)


func _text(position: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _format_time(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or DisplayServer.get_name() == "Android"
