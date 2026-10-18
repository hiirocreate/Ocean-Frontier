extends Control
## 主人公作成画面（基本情報・外見・過去の背景・初期特性・最終確認）。
## Game.creation_edit_mode が true のときは、作成後に変更できる項目（名前・外見）だけを編集する。

var data: GameData
var profile: PlayerProfile
var edit_mode := false
var _tabs: TabContainer
var _portrait: PortraitView
var _model_root: Node3D
var _model: CharacterModel
var _name_edit: LineEdit
var _age_spin: SpinBox
var _age_slider: HSlider
var _age_info: Label
var _gender_buttons := {}
var _appearance_opts := {}
var _bg_detail: VBoxContainer
var _bg_buttons := {}
var _trait_checks := {}
var _trait_msg: Label
var _confirm: VBoxContainer
var _start_button: Button
var _err: Label
var _syncing := false
var _root_box: BoxContainer


func _ready() -> void:
	data = Game.data
	theme = UiTheme.get_theme()
	edit_mode = Game.creation_edit_mode
	if edit_mode and Game.session:
		profile = PlayerProfile.from_dict(Game.session.profile.to_dict(), data)["profile"]
	else:
		profile = PlayerProfile.create_default(data)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("08202e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := BoxContainer.new()  # 横画面は左右、縦画面は上下に並べる
	_root_box = root
	root.add_theme_constant_override("separation", 20)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	# 上／左：プレビュー（縦画面では立ち絵と3Dを横に並べる）
	var outer := VBoxContainer.new()
	root.add_child(outer)
	outer.add_child(UiTheme.label("主人公の編集" if edit_mode else "主人公の作成", 28, UiTheme.C_GOLD))
	var left := BoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	outer.add_child(left)
	_portrait = PortraitView.new()
	_portrait.custom_minimum_size = Vector2(300, 300)
	left.add_child(_portrait)
	left.add_child(_build_3d_preview())
	# 下／右：手順
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var relayout := func(p: bool):
		root.vertical = p
		left.vertical = not p
	relayout.call(Game.portrait)
	Game.layout_changed.connect(relayout)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_tabs)
	_tabs.add_child(_scroll("基本情報", _build_basic()))
	_tabs.add_child(_scroll("外見", _build_appearance()))
	if not edit_mode:
		_tabs.add_child(_scroll("過去", _build_backgrounds()))
		_tabs.add_child(_scroll("特性", _build_traits()))
	_confirm = VBoxContainer.new()
	_tabs.add_child(_scroll("確認", _confirm))
	_tabs.tab_changed.connect(func(_i): _refresh())
	_err = UiTheme.label("", 17, UiTheme.C_WARN)
	right.add_child(_err)
	var nav := HFlowContainer.new()  # 縦画面で幅が足りないときは折り返す
	nav.add_theme_constant_override("h_separation", 12)
	nav.add_theme_constant_override("v_separation", 10)
	if not edit_mode:
		var skip := UiTheme.button("おまかせで開始", Vector2(220, 60))
		skip.pressed.connect(func(): Game.start_new_game(null))
		nav.add_child(skip)
	var back := UiTheme.button("戻る", Vector2(140, 60))
	back.pressed.connect(func(): Game.creation_back())
	nav.add_child(back)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(sp)
	var nxt := UiTheme.button("次へ ▶", Vector2(160, 60))
	nxt.pressed.connect(func(): _tabs.current_tab = mini(_tabs.current_tab + 1, _tabs.get_tab_count() - 1))
	nav.add_child(nxt)
	_start_button = UiTheme.button("変更を保存" if edit_mode else "この主人公で始める", Vector2(280, 60))
	_start_button.pressed.connect(_on_start)
	nav.add_child(_start_button)
	right.add_child(nav)
	_refresh()


func _scroll(title: String, content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


func _build_3d_preview() -> Control:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(300, 280)
	svc.stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	svc.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.position = Vector3(0, 1.05, 4.4)
	cam.look_at_from_position(cam.position, Vector3(0, 0.9, 0))
	vp.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8fb4c4")
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	_model_root = Node3D.new()
	vp.add_child(_model_root)
	return svc


func _process(delta: float) -> void:
	if _model_root:
		_model_root.rotation.y += delta * 0.6


# ---------- 基本情報 ----------
func _build_basic() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(UiTheme.label("名前（12文字まで）", 18))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 12
	_name_edit.text = profile.name
	_name_edit.custom_minimum_size = Vector2(320, 56)
	_name_edit.text_changed.connect(func(t): profile.name = t; _refresh())
	v.add_child(_name_edit)
	v.add_child(UiTheme.label("性別" + ("（変更できません）" if edit_mode else ""), 18))
	var gh := HBoxContainer.new()
	for g in [["male", "男性"], ["female", "女性"]]:
		var b := UiTheme.button(g[1], Vector2(160, 56))
		b.toggle_mode = true
		b.disabled = edit_mode
		b.pressed.connect(func():
			profile.gender = g[0]
			_refresh())
		gh.add_child(b)
		_gender_buttons[g[0]] = b
	v.add_child(gh)
	v.add_child(UiTheme.label("年齢（%d〜%d歳）%s" % [PlayerProfile.AGE_MIN, PlayerProfile.AGE_MAX, "（変更できません）" if edit_mode else ""], 18))
	var ah := HBoxContainer.new()
	_age_spin = SpinBox.new()
	_age_spin.min_value = PlayerProfile.AGE_MIN
	_age_spin.max_value = PlayerProfile.AGE_MAX
	_age_spin.step = 1
	_age_spin.rounded = true
	_age_spin.value = profile.age
	_age_spin.editable = not edit_mode
	_age_spin.custom_minimum_size = Vector2(140, 56)
	_age_slider = HSlider.new()
	_age_slider.min_value = PlayerProfile.AGE_MIN
	_age_slider.max_value = PlayerProfile.AGE_MAX
	_age_slider.step = 1
	_age_slider.value = profile.age
	_age_slider.editable = not edit_mode
	_age_slider.custom_minimum_size = Vector2(360, 56)
	_age_spin.value_changed.connect(func(val): set_age(int(val)))
	_age_slider.value_changed.connect(func(val): set_age(int(val)))
	ah.add_child(_age_spin)
	ah.add_child(_age_slider)
	v.add_child(ah)
	_age_info = UiTheme.label("", 16, Color(0.8, 0.86, 0.88))
	_age_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_age_info)
	return v


## 年齢を設定（範囲外は拒否してメッセージを出す）
func set_age(a: int) -> bool:
	if _syncing:
		return true
	var err := PlayerProfile.validate_age(a)
	if err != "":
		_err.text = err
		return false
	profile.age = a
	_syncing = true
	_age_spin.value = a
	_age_slider.value = a
	_syncing = false
	_refresh()
	return true


# ---------- 外見 ----------
func _build_appearance() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	for spec in [["art_mode", "art_modes", "表示スタイル"], ["hair_style", "hair_styles", "髪型"], ["hair_color", "hair_colors", "髪色"], ["skin_color", "skin_colors", "肌の色"], ["face", "faces", "顔の特徴"], ["outfit", "outfits", "衣装"], ["accessory", "accessories", "アクセサリー"]]:
		var h := HBoxContainer.new()
		var l := UiTheme.label(spec[2], 18)
		l.custom_minimum_size = Vector2(160, 0)
		h.add_child(l)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(300, 52)
		var opts: Array = data.appearance.get(spec[1], [])
		for i in opts.size():
			ob.add_item(str(opts[i]["name"]))
			ob.set_item_metadata(i, opts[i]["id"])
		ob.item_selected.connect(func(i):
			profile.appearance[spec[0]] = str(ob.get_item_metadata(i))
			_refresh())
		h.add_child(ob)
		v.add_child(h)
		_appearance_opts[spec[0]] = ob
	var note := UiTheme.label("イラスト表示では髪色・肌の色が立ち絵と3Dモデルに反映されます。髪型・顔・衣装・アクセサリーはシンプル表示で反映されます。", 15, Color(0.8, 0.86, 0.88))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var rnd := UiTheme.button("ランダム", Vector2(200, 56))
	rnd.pressed.connect(func():
		for k in _appearance_opts:
			if k == "art_mode":
				continue
			var ob: OptionButton = _appearance_opts[k]
			var i := randi() % ob.item_count
			ob.select(i)
			profile.appearance[k] = str(ob.get_item_metadata(i))
		_refresh())
	v.add_child(rnd)
	return v


# ---------- 過去の背景 ----------
func _build_backgrounds() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var list := VBoxContainer.new()
	for bid in data.backgrounds:
		var b := UiTheme.button(str(data.backgrounds[bid]["name"]), Vector2(280, 54))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			profile.background_id = bid
			_refresh())
		list.add_child(b)
		_bg_buttons[bid] = b
	h.add_child(list)
	_bg_detail = VBoxContainer.new()
	_bg_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_bg_detail)
	return h


# ---------- 初期特性 ----------
func _build_traits() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(UiTheme.label("初期特性を1〜2個選べます（選ばなくても始められます）", 17))
	for tid in data.player_traits:
		var t: Dictionary = data.player_traits[tid]
		var cb := CheckBox.new()
		cb.text = "%s — %s" % [t["name"], t.get("description", "")]
		cb.add_theme_font_size_override("font_size", 18)
		cb.toggled.connect(func(on):
			if on and not (tid in profile.traits):
				profile.traits.append(tid)
			elif not on:
				profile.traits.erase(tid)
			_refresh())
		v.add_child(cb)
		_trait_checks[tid] = cb
	_trait_msg = UiTheme.label("", 16, UiTheme.C_WARN)
	_trait_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_trait_msg)
	return v


# ---------- 表示更新 ----------
func _refresh() -> void:
	profile.finalize(data)
	for g in _gender_buttons:
		_gender_buttons[g].button_pressed = profile.gender == g
	var band: Dictionary = data.age_bands.get(profile.age_band(), {})
	_age_info.text = "%d歳（%s）：%s" % [profile.age, band.get("name", ""), band.get("description", "")]
	for k in _appearance_opts:
		var ob: OptionButton = _appearance_opts[k]
		for i in ob.item_count:
			if str(ob.get_item_metadata(i)) == str(profile.appearance.get(k, "")):
				ob.select(i)
	for bid in _bg_buttons:
		_bg_buttons[bid].button_pressed = bid == profile.background_id
	if _bg_detail:
		_show_background_detail()
	var granted := str(data.backgrounds.get(profile.background_id, {}).get("grants_trait", ""))
	for tid in _trait_checks:
		var cb: CheckBox = _trait_checks[tid]
		cb.set_pressed_no_signal(tid in profile.traits or tid == granted)
		var full: bool = profile.traits.size() >= PlayerProfile.MAX_TRAITS and not (tid in profile.traits)
		var excl := false
		for other in profile.all_traits(data):
			if other != tid and (other in data.player_traits[tid].get("exclusive_with", []) or tid in data.player_traits.get(other, {}).get("exclusive_with", [])):
				excl = true
		cb.disabled = tid == granted or full or (excl and not (tid in profile.traits))
	if _trait_msg:
		var probs := PlayerProfile.trait_problems(data, profile.traits, profile.background_id)
		_trait_msg.text = "\n".join(probs) if not probs.is_empty() else ("背景により「%s」を得ています" % data.player_traits[granted]["name"] if granted != "" else "")
	var look := profile.look(data)
	_portrait.set_character("player", look, "smile")
	for c in _model_root.get_children():
		c.queue_free()
	_model = CharacterModel.new()
	_model.apply_look(look)
	_model_root.add_child(_model)
	_refresh_confirm()
	var errs := profile.validate(data)
	_start_button.disabled = not errs.is_empty()
	_err.text = errs[0] if not errs.is_empty() else ""


func _show_background_detail() -> void:
	for c in _bg_detail.get_children():
		c.queue_free()
	var b: Dictionary = data.backgrounds.get(profile.background_id, {})
	_bg_detail.add_child(UiTheme.label(str(b.get("name", "")), 22, UiTheme.C_GOLD))
	for line in [["", b.get("description", "")], ["初期アイテム: ", _items_text(b.get("initial_items", {}))], ["得意な行動: ", b.get("good_at", "")],
			["関係する人物・依頼: ", b.get("related", "")], ["変化する内容: ", b.get("changes", "")]]:
		var l := UiTheme.label(str(line[0]) + str(line[1]), 17)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bg_detail.add_child(l)


func _items_text(items: Dictionary) -> String:
	var parts: Array = []
	for id in items:
		parts.append("%s×%d" % [data.item_name(id), int(items[id])])
	return "、".join(parts) if not parts.is_empty() else "なし"


const ABILITY_NAMES := {"survival": "生存", "repair": "修理", "perception": "観察", "negotiation": "交渉", "medicine": "医療", "navigation": "航海",
	"combat": "戦闘", "leadership": "指揮", "learning": "学習", "adaptability": "適応"}


func _refresh_confirm() -> void:
	for c in _confirm.get_children():
		c.queue_free()
	var b: Dictionary = data.backgrounds.get(profile.background_id, {})
	var band: Dictionary = data.age_bands.get(profile.age_band(), {})
	var traits: Array = profile.all_traits(data).map(func(t): return str(data.player_traits[t]["name"]))
	var ab: Array = []
	for k in profile.abilities:
		if int(profile.abilities[k]) != 0:
			ab.append("%s+%d" % [ABILITY_NAMES.get(k, k), int(profile.abilities[k])])
	var start_items := profile.initial_inventory.duplicate()
	for k in data.bal("start_inventory", {}):
		start_items[k] = int(start_items.get(k, 0)) + int(data.bal("start_inventory", {})[k])
	var lines := [
		["名前", profile.name], ["性別", "男性" if profile.gender == "male" else "女性"], ["年齢", "%d歳（%s）" % [profile.age, band.get("name", "")]],
		["背景", b.get("name", "")], ["初期特性", "、".join(traits) if not traits.is_empty() else "なし"],
		["初期アイテム", _items_text(start_items)], ["初期能力", "、".join(ab) if not ab.is_empty() else "標準"],
		["導入への影響", "%s／%s" % [b.get("changes", ""), band.get("description", "")]],
	]
	for l in lines:
		var lab := UiTheme.label("%s：%s" % l, 18)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_confirm.add_child(lab)


func _on_start() -> void:
	var errs := profile.validate(data)
	if not errs.is_empty():
		_err.text = errs[0]
		return
	if edit_mode:
		Game.apply_profile_edit(profile)
	else:
		Game.start_new_game(profile)
