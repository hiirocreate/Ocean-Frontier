class_name MapPanel
extends PanelContainer
## マップ画面（仕様36）。海域・発見済みの地点・筏の位置を描き、地点をタップすると目的地に設定する。

var session: GameSession
var _canvas: Control
var _info: Label
var view_rect := Rect2(-1300, -1300, 2600, 2600)  # 表示するワールド範囲（x,z）
const SITE_COLORS := {"shipwreck": "c9a070", "drone_ship": "b0b8c0", "underwater_wreck": "6ab0d8", "underwater_city": "cfe8ff",
	"ruin": "a07050", "research_facility": "cfe8ff", "special": "d05a7a", "settlement": "ffb35c", "fortress": "a0a890", "pirate_base": "e04a3a"}


func setup(s: GameSession) -> void:
	session = s
	custom_minimum_size = Vector2(1000, 640)
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.03, 0.08, 0.12, 0.97), UiTheme.C_PANEL_BORDER, 14))
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label("海図", 26, UiTheme.C_GOLD))
	_info = UiTheme.label("地点をタップすると目的地に設定します", 16)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_info)
	var clear := UiTheme.button("目的地を解除", Vector2(160, 52))
	clear.pressed.connect(func():
		session.flags.erase("nav_target")
		_canvas.queue_redraw())
	head.add_child(clear)
	var close := UiTheme.button("閉じる", Vector2(120, 52))
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)
	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_canvas_input)
	v.add_child(_canvas)


func open() -> void:
	visible = true
	_canvas.queue_redraw()


func _scale() -> float:
	return minf(_canvas.size.x / view_rect.size.x, _canvas.size.y / view_rect.size.y)


func world_to_map(p: Vector3) -> Vector2:
	var sc := _scale()
	var off := (_canvas.size - view_rect.size * sc) / 2.0
	return off + (Vector2(p.x, p.z) - view_rect.position) * sc


func _draw_map() -> void:
	var sc := _scale()
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color("0a2236"))
	for zid in session.data.zones:
		var z: Dictionary = session.data.zones[zid]
		var b: Array = z.get("bounds", [])
		if b.size() != 4:
			continue
		var r := Rect2(world_to_map(Vector3(b[0], 0, b[1])), Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])) * sc)
		var visited: bool = zid == session.zone_id or session.flags.get("visited_" + zid, false) or zid == "starting_waters"
		var col := Color(str(z.get("ocean_shallow_color", "#1b9a98")))
		_canvas.draw_rect(r, Color(col, 0.55 if visited else 0.18))
		_canvas.draw_rect(r, Color(1, 1, 1, 0.15), false, 2.0)
		var name: String = z.get("name", zid) if visited else "？？？"
		_canvas.draw_string(UiTheme.get_theme().default_font, r.position + Vector2(10, 26), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.75))
	var target := str(session.flags.get("nav_target", ""))
	for sid in session.data.sites:
		if not session.is_site_discovered(sid):
			continue
		var sd: Dictionary = session.data.sites[sid]
		var mp := world_to_map(session.site_position(sid))
		var col := Color(SITE_COLORS.get(str(sd.get("type", "")), "ffffff"))
		var done := session.site_explorations_left(sid) <= 0 and int(sd.get("max_explorations", 0)) > 0
		_canvas.draw_circle(mp, 9.0, Color(col, 0.45 if done else 1.0))
		if sid == target:
			_canvas.draw_arc(mp, 16.0, 0, TAU, 24, UiTheme.C_GOLD, 3.0)
		_canvas.draw_string(UiTheme.get_theme().default_font, mp + Vector2(12, 6), str(sd.get("name", sid)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.5 if done else 0.95))
	var rp := world_to_map(session.raft_position)
	var yaw := session.raft_rotation
	_canvas.draw_colored_polygon(PackedVector2Array([rp + Vector2(0, -12).rotated(-yaw), rp + Vector2(8, 8).rotated(-yaw), rp + Vector2(-8, 8).rotated(-yaw)]), UiTheme.C_GOLD)
	_canvas.draw_string(UiTheme.get_theme().default_font, rp + Vector2(12, -10), "現在地", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.C_GOLD)


func _on_canvas_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var best := ""
	var best_d := 30.0
	for sid in session.data.sites:
		if not session.is_site_discovered(sid):
			continue
		var d := world_to_map(session.site_position(sid)).distance_to(event.position)
		if d < best_d:
			best_d = d
			best = sid
	if best != "":
		session.flags["nav_target"] = best
		_info.text = "目的地: %s（%dm）" % [session.data.sites[best]["name"], int(session.site_distance(best))]
		_canvas.queue_redraw()
