extends Control
## タイトル画面：はじめから / つづきから / 画質設定 / 終了

var _continue: Button
var _status: Label
var _update_box: PanelContainer
var _menu: VBoxContainer


func _ready() -> void:
	theme = UiTheme.get_theme()
	Audio.set_music("bgm_day", 0.4)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.material = _bg_material()
	add_child(bg)
	var v := VBoxContainer.new()
	_menu = v
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
	var b := UpdateChecker.local_build()
	var ver := UiTheme.label("v%s%s  オフラインでプレイできます" % [ProjectSettings.get_setting("application/config/version"), " (#%d)" % b if b > 0 else ""], 16, Color(1, 1, 1, 0.6))
	add_child(ver)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	# 新しいバージョンの確認（通信できなければ何も表示しない）
	var checker := UpdateChecker.new()
	add_child(checker)
	checker.update_available.connect(show_update)
	checker.check()


## 新しいバージョンがあることを知らせ、ダウンロードできるようにする
func show_update(info: Dictionary) -> void:
	if _update_box:
		_update_box.queue_free()
	_update_box = PanelContainer.new()
	_update_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.16, 0.2, 0.96), UiTheme.C_GOLD, 14, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_update_box.add_child(v)
	v.add_child(UiTheme.label("新しいバージョン（#%d）があります" % int(info["build"]), 22, UiTheme.C_GOLD))
	if str(info.get("notes", "")) != "":
		var n := UiTheme.label(str(info["notes"]), 16)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size = Vector2(380, 0)
		v.add_child(n)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var dl := UiTheme.button("ダウンロード", Vector2(200, 56))
	dl.pressed.connect(func(): OS.shell_open(str(info["apk_url"])))
	h.add_child(dl)
	var later := UiTheme.button("あとで", Vector2(120, 56))
	later.pressed.connect(func():
		_update_box.visible = false
		_menu.set_anchors_and_offsets_preset.call_deferred(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE))
	h.add_child(later)
	v.add_child(h)
	var hint := UiTheme.label("ダウンロード後、ファイルを開くと上書きでインストールできます（セーブデータは残ります）", 14, Color(0.8, 0.86, 0.88))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(380, 0)
	v.add_child(hint)
	# タイトルの下（メニューの先頭）に差し込み、メニュー全体を中央に置き直す
	_menu.add_child(_update_box)
	_menu.move_child(_update_box, 2)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


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
	Game.open_creation(false)


func _on_continue() -> void:
	var r := Game.continue_game()
	if not r["ok"]:
		_status.text = "ロードできませんでした: %s" % r["error"]
