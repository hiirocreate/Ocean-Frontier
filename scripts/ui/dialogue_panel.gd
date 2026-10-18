class_name DialoguePanel
extends Control
## 2Dイラストによる会話画面（仕様11・36）。DialogueRunner の進行を表示し、選択肢を受け付ける。

signal closed(dialogue_id: String)

var session: GameSession
var runner: DialogueRunner
var portrait: PortraitView
var _name_label: Label
var _text_label: Label
var _choices: VBoxContainer
var _next_button: Button
var _tween: Tween


func setup(s: GameSession) -> void:
	session = s
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0.03, 0.06, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	portrait = PortraitView.new()
	portrait.custom_minimum_size = Vector2(300, 380)
	add_child(portrait)
	portrait.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	portrait.offset_left = 40
	portrait.offset_right = 340
	portrait.offset_top = -380 - 150
	portrait.offset_bottom = -150
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.03, 0.09, 0.13, 0.95), UiTheme.C_PANEL_BORDER, 16, 18))
	add_child(box)
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 24
	box.offset_right = -24
	box.offset_top = -190
	box.offset_bottom = -20
	var v := VBoxContainer.new()
	box.add_child(v)
	_name_label = UiTheme.label("", 24, UiTheme.C_GOLD)
	v.add_child(_name_label)
	_text_label = UiTheme.label("", 22)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text_label)
	_next_button = UiTheme.button("次へ ▶", Vector2(160, 56))
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next_button.pressed.connect(_on_next)
	v.add_child(_next_button)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 10)
	_choices.custom_minimum_size = Vector2(440, 0)
	add_child(_choices)
	_choices.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_choices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.offset_right = -40
	_choices.offset_bottom = -210
	_choices.offset_left = -480
	_choices.offset_top = -210


## 横画面／縦画面の配置。縦画面では選択肢を全幅にし、立ち絵を選択肢の上に置く
func apply_layout(portrait_mode: bool) -> void:
	if portrait_mode:
		portrait.custom_minimum_size = Vector2(360, 460)
		portrait.offset_left = 24
		portrait.offset_right = 384
		portrait.offset_bottom = -480
		portrait.offset_top = -480 - 460
		_choices.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_choices.offset_left = 24
		_choices.offset_right = -24
		_choices.offset_bottom = -210
		_choices.offset_top = -210
	else:
		portrait.custom_minimum_size = Vector2(300, 380)
		portrait.offset_left = 40
		portrait.offset_right = 340
		portrait.offset_top = -380 - 150
		portrait.offset_bottom = -150
		_choices.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_choices.offset_right = -40
		_choices.offset_bottom = -210
		_choices.offset_left = -480
		_choices.offset_top = -210
	_choices.grow_horizontal = Control.GROW_DIRECTION_BOTH if portrait_mode else Control.GROW_DIRECTION_BEGIN
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN


func open(dialogue_id: String) -> bool:
	runner = DialogueRunner.new(session)
	runner.node_changed.connect(_show_node)
	runner.finished.connect(_on_finished)
	visible = true
	if not runner.start(dialogue_id):
		visible = false
		return false
	return true


func open_inline(id: String, nodes: Dictionary) -> void:
	runner = DialogueRunner.new(session)
	runner.node_changed.connect(_show_node)
	runner.finished.connect(_on_finished)
	visible = true
	runner.start_inline(id, nodes)


func _show_node(n: Dictionary) -> void:
	var sp := str(n.get("speaker", "narrator"))
	match sp:
		"narrator":
			_name_label.text = ""
			portrait.visible = false
		"player":
			_name_label.text = session.profile.name
			portrait.visible = true
			portrait.set_character("player", session.profile.look(session.data), str(n.get("expression", "normal")))
		_:
			_name_label.text = session.crew.display_name(sp)
			portrait.visible = true
			portrait.set_character(sp, session.crew.def(sp), str(n.get("expression", "normal")))
	_text_label.text = str(n.get("text", ""))
	_text_label.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_ratio", 1.0, clampf(_text_label.text.length() * 0.025, 0.2, 1.5))
	for c in _choices.get_children():
		c.queue_free()
	var cs := runner.choices()
	_next_button.visible = cs.is_empty()
	for c in cs:
		var b := UiTheme.button(c["text"], Vector2(440, 60))
		b.pressed.connect(func(): runner.choose(int(c["index"])))
		_choices.add_child(b)


func _on_next() -> void:
	if _text_label.visible_ratio < 1.0:
		_tween.kill()
		_text_label.visible_ratio = 1.0
		return
	runner.advance()


func _on_finished(dialogue_id: String) -> void:
	visible = false
	closed.emit(dialogue_id)


func _gui_input(event: InputEvent) -> void:
	# 選択肢がない場面は画面のどこをタップしても進む
	if event is InputEventMouseButton and event.pressed and _next_button.visible:
		_on_next()
		accept_event()
