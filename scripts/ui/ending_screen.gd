extends Control
## エンディング画面（仕様35）。選んだ結末の文章と、旅の記録（行動履歴）を表示する。

var _text: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float t = clamp(TIME * 0.05, 0.0, 1.0);
	vec3 top = mix(vec3(0.03, 0.06, 0.12), vec3(0.20, 0.35, 0.55), t);
	vec3 hor = mix(vec3(0.10, 0.10, 0.20), vec3(0.98, 0.70, 0.45), t);
	vec3 col = mix(top, hor, smoothstep(0.0, 0.65, UV.y));
	float sea = step(0.68 + sin(UV.x * 20.0 + TIME) * 0.004, UV.y);
	col = mix(col, mix(vec3(0.04, 0.20, 0.30), vec3(0.02, 0.08, 0.14), (UV.y - 0.68) * 3.0), sea);
	COLOR = vec4(col, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	bg.material = m
	add_child(bg)
	var s: GameSession = Game.session
	var id := str(s.story.ending) if s else ""
	var e: Dictionary = Game.data.endings.get(id, {})
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(minf(900.0, get_viewport_rect().size.x - 40.0) if is_inside_tree() else 900.0, 0)
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	var t := UiTheme.label(str(e.get("name", "終わり")), 48, UiTheme.C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UiTheme.label("— %s —" % e.get("description", ""), 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_text = UiTheme.label(str(e.get("text", "")), 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_ratio = 0.0
	v.add_child(_text)
	create_tween().tween_property(_text, "visible_ratio", 1.0, 6.0)
	if s:
		var lines := [
			"漂流した日数: %d日" % s.clock.day(),
			"筏の床: %d枚　設備: %d　船: %d隻" % [s.raft.tiles.size(), s.raft.buildings.size(), s.fleet.ships.size()],
			"共に生きた仲間: %d人（去った仲間 %d人）" % [s.crew.aboard_ids().size(), s.crew.departed_ids().size()],
			"名声 %d　恐怖 %d　信頼 %d　悪名 %d" % [int(s.reputation["fame"]), int(s.reputation["fear"]), int(s.reputation["trust"]), int(s.reputation["infamy"])],
			"探索した地点: %d　戦いの勝利: %d　手がかり: %d種" % [int(s.stats.get("sites_explored", 0)), int(s.stats.get("battles_won", 0)), s.clue_count()],
		]
		var rec := UiTheme.label("\n".join(lines), 18, Color(0.85, 0.9, 0.92))
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rec)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 20)
	var cont := UiTheme.button("この世界で旅を続ける", Vector2(320, 70))
	cont.pressed.connect(func(): Game.continue_after_ending())
	h.add_child(cont)
	var title := UiTheme.button("タイトルへ", Vector2(220, 70))
	title.pressed.connect(func(): Game.return_to_menu())
	h.add_child(title)
	v.add_child(h)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
