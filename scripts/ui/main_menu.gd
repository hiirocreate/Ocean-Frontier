extends Control
## タイトル画面：はじめから / つづきから / 画質設定 / 終了

var _continue: Button
var _status: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.material = _bg_material()
	add_child(bg)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var t := UiTheme.label("Ocean Frontier", 64, Color(0.95, 0.98, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := UiTheme.label("LAST TIDE ― 最後の潮流", 30, UiTheme.C_GOLD)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	v.add_child(Control.new())
	var new_b := UiTheme.button("はじめから", Vector2(0, 76))
	new_b.pressed.connect(_on_new)
	v.add_child(new_b)
	_continue = UiTheme.button("つづきから", Vector2(0, 76))
	_continue.disabled = not SaveManager.has_save()
	_continue.pressed.connect(_on_continue)
	v.add_child(_continue)
	var q := HBoxContainer.new()
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	q.add_child(UiTheme.label("画質 ", 20))
	for spec in [["low", "低"], ["medium", "中"], ["high", "高"]]:
		var b := UiTheme.button(spec[1], Vector2(110, 60))
		b.toggle_mode = true
		b.button_pressed = Game.settings["quality"] == spec[0]
		b.pressed.connect(func():
			Game.settings["quality"] = spec[0]
			Game.save_settings()
			for c in q.get_children():
				if c is Button:
					c.button_pressed = c == b)
		q.add_child(b)
	v.add_child(q)
	_status = UiTheme.label("", 18, UiTheme.C_WARN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	if not Game.data_errors.is_empty():
		_status.text = "データに%d件の問題があります（ログ参照）" % Game.data_errors.size()
	var ver := UiTheme.label("v%s  オフラインでプレイできます" % ProjectSettings.get_setting("application/config/version"), 16, Color(1, 1, 1, 0.6))
	add_child(ver)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)


func _bg_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float wave = sin(uv.x * 18.0 + TIME * 0.8) * 0.012 + sin(uv.x * 7.0 - TIME * 0.5) * 0.02;
	vec3 sky = mix(vec3(0.98, 0.72, 0.45), vec3(0.18, 0.42, 0.62), smoothstep(0.0, 0.55, 0.62 - uv.y));
	vec3 sea = mix(vec3(0.07, 0.45, 0.52), vec3(0.02, 0.14, 0.25), smoothstep(0.62, 1.0, uv.y));
	float horizon = step(0.62 + wave, uv.y);
	vec3 col = mix(sky, sea, horizon);
	float sun = smoothstep(0.09, 0.08, distance(uv * vec2(1.7, 1.0), vec2(1.15, 0.52)));
	col = mix(col, vec3(1.0, 0.85, 0.6), sun * (1.0 - horizon));
	COLOR = vec4(col, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _on_new() -> void:
	Game.start_new_game()


func _on_continue() -> void:
	var r := Game.continue_game()
	if not r["ok"]:
		_status.text = "ロードできませんでした: %s" % r["error"]
