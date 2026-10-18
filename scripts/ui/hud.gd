class_name Hud
extends CanvasLayer
## 探索画面のUI。生存値・時刻・メッセージ・操作ボタン・インベントリ/クラフト・建築・メニュー。
## 行動の可否は ActionSystem に問い合わせ、不足理由を具体的に表示する（仕様38）。

signal collect_pressed
signal build_mode_changed(on: bool, type: String)
signal build_confirmed(action_id: String, params: Dictionary)

const NO_TILE := Vector2i(999999, 999999)

var session: GameSession
var joystick: VirtualJoystick
var root: Control
var _bars := {}
var _time_label: Label
var _weight_label: Label
var _toasts: VBoxContainer
var _jobs_box: VBoxContainer
var collect_button: Button
var build_button: Button
var bag_button: Button
var crew_button: Button
var crew_panel: CrewPanel
var combat_panel: CombatPanel
var map_panel: MapPanel
var map_button: Button
var fleet_panel: FleetPanel
var faction_panel: FactionPanel
var fleet_button: Button
var quest_panel: QuestPanel
var quest_button: Button
var faction_button: Button
var inspect_button: Button
var _site_panel: PanelContainer
var _site_info: VBoxContainer
var _site_id := ""
var _nav_label: Label
var _top_row: HBoxContainer
var dialogue_panel: DialoguePanel
var menu_button: Button
var _inventory_panel: PanelContainer
var _inv_list: VBoxContainer
var _craft_list: VBoxContainer
var _inv_tabs: TabContainer
var _build_panel: PanelContainer
var _build_info: VBoxContainer
var _build_tile := NO_TILE
var build_type := "tile"
var _building_panel: PanelContainer
var _building_info: VBoxContainer
var _building_uid := ""
var _sleep_overlay: ColorRect
var _sleep_label: Label
var _menu_panel: PanelContainer
var _quality_buttons := {}
var build_mode := false
var _refresh_pending := false
var _panel_timer := 0.0


func setup(s: GameSession) -> void:
	session = s
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_build_status()
	_build_toasts()
	_build_controls()
	_build_jobs()
	_build_inventory()
	_build_build_panel()
	_build_building_panel()
	_build_menu()
	_build_sleep_overlay()
	crew_panel = CrewPanel.new()
	root.add_child(crew_panel)
	crew_panel.setup(session)
	crew_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	crew_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crew_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	crew_panel.talk_requested.connect(_on_talk)
	session.crew.changed.connect(func(): if crew_panel.visible: crew_panel.refresh())
	map_panel = MapPanel.new()
	root.add_child(map_panel)
	map_panel.setup(session)
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	map_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	map_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	for pn in ["fleet_panel", "faction_panel", "quest_panel"]:
		var panel: PanelContainer = {"fleet_panel": FleetPanel, "faction_panel": FactionPanel, "quest_panel": QuestPanel}[pn].new()
		root.add_child(panel)
		panel.setup(session)
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		set(pn, panel)
	_site_panel = PanelContainer.new()
	ScreenLayout.fit(_site_panel, Vector2(500, 0), Control.PRESET_CENTER_BOTTOM, 24)
	_site_panel.visible = false
	_site_info = VBoxContainer.new()
	_site_panel.add_child(_site_info)
	root.add_child(_site_panel)
	_site_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_site_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_site_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shift_left(_site_panel)
	dialogue_panel = DialoguePanel.new()
	root.add_child(dialogue_panel)
	dialogue_panel.setup(session)
	combat_panel = CombatPanel.new()
	root.add_child(combat_panel)
	combat_panel.setup(session)
	combat_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	combat_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	combat_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	session.inventory.changed.connect(_queue_refresh)
	session.actions.job_completed.connect(func(_j, _r): _queue_refresh())
	session.raft.changed.connect(_queue_refresh)
	Game.message.connect(_on_message)
	Game.layout_changed.connect(func(_p): _apply_layout.call_deferred())
	_apply_layout.call_deferred()


## 横画面／縦画面で HUD の配置を切り替える（パネルの大きさは ScreenLayout.fit が画面に合わせる）
func _apply_layout() -> void:
	var portrait := ScreenLayout.portrait(root)
	ScreenLayout.apply_all(get_tree())
	# 上部のボタン列: 横画面は右上、縦画面は状態表示の下に右寄せ
	_top_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_top_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if portrait:
		_top_row.offset_top += 210
		_top_row.offset_bottom += 210
	_jobs_box.offset_top = 300.0 if portrait else 100.0
	# 通知: 横画面は上部中央、縦画面は画面の中ほど
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = 520.0 if portrait else 96.0
	_nav_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	_nav_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if portrait:
		_nav_label.offset_top += 280
		_nav_label.offset_bottom += 280
	else:
		_shift_left(_toasts)
		_shift_left(_nav_label)
	# 下部のパネル: 横画面は右下のボタンを避けて左寄せ、縦画面は操作ボタンの上に置く
	for c in [_site_panel, _build_panel, _building_panel]:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		if portrait:
			c.offset_top -= 230
			c.offset_bottom -= 230
		else:
			_shift_left(c)
	dialogue_panel.apply_layout(portrait)


# ---------- レイアウト ----------
func _build_status() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	_time_label = UiTheme.label("", 22, UiTheme.C_GOLD)
	v.add_child(_time_label)
	for spec in [["health", "体力", Color("e0605a")], ["hunger", "空腹", Color("e8a64f")],
			["thirst", "水分", Color("4fb8e8")], ["fatigue", "元気", Color("8fd47a")]]:
		var row := HBoxContainer.new()
		var l := UiTheme.label(spec[1], 16)
		l.custom_minimum_size = Vector2(48, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(210, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", UiTheme.box(spec[2], Color(0, 0, 0, 0), 6, 2))
		row.add_child(bar)
		v.add_child(row)
		_bars[spec[0]] = bar
	_weight_label = UiTheme.label("", 16)
	v.add_child(_weight_label)
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.custom_minimum_size = Vector2(400, 0)
	root.add_child(_toasts)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = 96  # 上部のボタン列と重ならないよう少し下・左寄せ
	_shift_left(_toasts)


func _build_controls() -> void:
	joystick = VirtualJoystick.new()
	root.add_child(joystick)
	var js := joystick.custom_minimum_size
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 36
	joystick.offset_right = 36 + js.x
	joystick.offset_top = -36 - js.y
	joystick.offset_bottom = -36

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	bag_button = UiTheme.button("持ち物", Vector2(116, 84))
	build_button = UiTheme.button("建築", Vector2(116, 84))
	crew_button = UiTheme.button("仲間", Vector2(116, 84))
	collect_button = UiTheme.button("回収", Vector2(380, 96))
	collect_button.add_theme_font_size_override("font_size", 28)
	grid.add_child(bag_button)
	grid.add_child(build_button)
	grid.add_child(crew_button)
	inspect_button = UiTheme.button("調べる", Vector2(380, 76))
	inspect_button.visible = false
	inspect_button.pressed.connect(func(): show_site_panel(_site_id))
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 16)
	wrap.add_child(grid)
	wrap.add_child(inspect_button)
	wrap.add_child(collect_button)
	root.add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 36)
	wrap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	collect_button.pressed.connect(func(): collect_pressed.emit())
	build_button.pressed.connect(func(): set_build_mode(not build_mode))
	bag_button.pressed.connect(toggle_inventory)
	crew_button.pressed.connect(toggle_crew)

	menu_button = UiTheme.button("メニュー", Vector2(110, 64))
	var top := HBoxContainer.new()
	_top_row = top
	top.add_theme_constant_override("separation", 12)
	map_button = UiTheme.button("海図", Vector2(92, 64))
	map_button.pressed.connect(toggle_map)
	top.add_child(map_button)
	faction_button = UiTheme.button("勢力", Vector2(92, 64))
	faction_button.pressed.connect(func():
		var show := not faction_panel.visible
		_close_modals()
		if show:
			faction_panel.open_info())
	top.add_child(faction_button)
	fleet_button = UiTheme.button("船団", Vector2(92, 64))
	fleet_button.pressed.connect(func():
		var show := not fleet_panel.visible
		_close_modals()
		if show:
			fleet_panel.open())
	top.add_child(fleet_button)
	quest_button = UiTheme.button("記録", Vector2(92, 64))
	quest_button.pressed.connect(func():
		var show := not quest_panel.visible
		_close_modals()
		if show:
			quest_panel.open())
	top.add_child(quest_button)
	top.add_child(menu_button)
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_button.pressed.connect(toggle_menu)
	_nav_label = UiTheme.label("", 20, UiTheme.C_GOLD)
	_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_nav_label)
	_nav_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	_nav_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shift_left(_nav_label)


func _build_jobs() -> void:
	_jobs_box = VBoxContainer.new()
	_jobs_box.custom_minimum_size = Vector2(340, 0)
	root.add_child(_jobs_box)
	_jobs_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_jobs_box.offset_top = 100
	_jobs_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _modal(size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	ScreenLayout.fit(p, size)
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.11, 0.16, 0.96), UiTheme.C_PANEL_BORDER, 14))
	p.visible = false
	root.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return p


func _build_inventory() -> void:
	_inventory_panel = _modal(Vector2(760, 560))
	var v := VBoxContainer.new()
	_inventory_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label("持ち物とクラフト", 26, UiTheme.C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := UiTheme.button("閉じる", Vector2(120, 56))
	close.pressed.connect(toggle_inventory)
	head.add_child(close)
	v.add_child(head)
	_inv_tabs = TabContainer.new()
	_inv_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_inv_tabs)
	_inv_list = _scroll_tab("所持品")
	_craft_list = _scroll_tab("クラフト")


func _scroll_tab(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	_inv_tabs.add_child(sc)
	return list


func _build_build_panel() -> void:
	_build_panel = PanelContainer.new()
	ScreenLayout.fit(_build_panel, Vector2(500, 0), Control.PRESET_CENTER_BOTTOM, 24)
	_build_panel.visible = false
	_build_info = VBoxContainer.new()
	_build_panel.add_child(_build_info)
	root.add_child(_build_panel)
	_build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shift_left(_build_panel)


## 画面下中央のパネルを右下のボタン群と重ならないよう左に寄せる
func _shift_left(c: Control) -> void:
	c.offset_left -= 110
	c.offset_right -= 110


func _build_building_panel() -> void:
	_building_panel = PanelContainer.new()
	ScreenLayout.fit(_building_panel, Vector2(500, 0), Control.PRESET_CENTER_BOTTOM, 24)
	_building_panel.visible = false
	_building_info = VBoxContainer.new()
	_building_panel.add_child(_building_info)
	root.add_child(_building_panel)
	_building_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_building_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_building_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shift_left(_building_panel)


func _build_menu() -> void:
	_menu_panel = _modal(Vector2(460, 650))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_menu_panel.add_child(v)
	v.add_child(UiTheme.label("メニュー", 28, UiTheme.C_GOLD))
	var save_b := UiTheme.button("セーブ")
	save_b.pressed.connect(func(): Game.save_game())
	v.add_child(save_b)
	var load_b := UiTheme.button("ロード")
	load_b.pressed.connect(func(): Game.load_game())
	v.add_child(load_b)
	v.add_child(UiTheme.label("画質", 18))
	var q := HBoxContainer.new()
	for spec in [["low", "低"], ["medium", "中"], ["high", "高"]]:
		var b := UiTheme.button(spec[1], Vector2(130, 56))
		b.toggle_mode = true
		b.pressed.connect(_set_quality.bind(spec[0]))
		q.add_child(b)
		_quality_buttons[spec[0]] = b
	v.add_child(q)
	var vol := HBoxContainer.new()
	vol.add_child(UiTheme.label("音量 ", 18))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(Game.settings.get("master_volume", 1.0))
	sl.custom_minimum_size = Vector2(260, 40)
	sl.value_changed.connect(func(val):
		Game.settings["master_volume"] = val
		Game.save_settings())
	vol.add_child(sl)
	v.add_child(vol)
	var edit_b := UiTheme.button("主人公の名前・外見を変更")
	edit_b.pressed.connect(func(): Game.save_game(); Game.open_creation(true))
	v.add_child(edit_b)
	var title_b := UiTheme.button("タイトルへ戻る（自動セーブ）")
	title_b.pressed.connect(func(): Game.save_game(); Game.return_to_menu())
	v.add_child(title_b)
	var close := UiTheme.button("閉じる")
	close.pressed.connect(toggle_menu)
	v.add_child(close)
	_update_quality_buttons()


# ---------- 表示更新 ----------
func _process(_delta: float) -> void:
	if session == null:
		return
	var sv := session.survival
	_bars["health"].value = sv.health
	_bars["hunger"].value = sv.hunger
	_bars["thirst"].value = sv.thirst
	_bars["fatigue"].value = 100.0 - sv.fatigue
	var wname: String = {"clear": "", "rain": "　雨", "storm": "　嵐", "fog": "　霧"}.get(session.weather_type(), "")
	_time_label.text = "%s%s　第%d章" % [session.clock.label(), wname, session.story.chapter]
	var rc := session.raft_condition()
	_weight_label.text = "重量 %.1f/%.0f  効率%d%%  貝貨 %d%s" % [session.inventory.total_weight(), session.inventory.max_weight, int(sv.efficiency() * 100), int(session.money), ("  筏%d%%" % int(rc)) if rc < 99.0 else ""]
	_update_jobs()
	_update_sleep_overlay()
	_update_nav()
	_panel_timer += _delta
	if _panel_timer > 1.0 and (_building_panel.visible or _site_panel.visible):
		_panel_timer = 0.0
		_refresh_pending = true
	if _refresh_pending:
		_refresh_pending = false
		if _inventory_panel.visible:
			_refresh_inventory()
		if _build_panel.visible:
			_refresh_build_panel()
		if _building_panel.visible:
			_refresh_building_panel()
		if _site_panel.visible:
			_refresh_site_panel()


func _queue_refresh() -> void:
	_refresh_pending = true


func _update_jobs() -> void:
	var jobs := session.actions.jobs
	while _jobs_box.get_child_count() < jobs.size():
		var row := PanelContainer.new()
		var v := VBoxContainer.new()
		row.add_child(v)
		var h := HBoxContainer.new()
		var l := UiTheme.label("", 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var cb := UiTheme.button("中止", Vector2(80, 44))
		cb.add_theme_font_size_override("font_size", 16)
		h.add_child(cb)
		v.add_child(h)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		v.add_child(bar)
		_jobs_box.add_child(row)
	while _jobs_box.get_child_count() > jobs.size():
		var c := _jobs_box.get_child(_jobs_box.get_child_count() - 1)
		_jobs_box.remove_child(c)
		c.queue_free()
	for i in jobs.size():
		var job: Dictionary = jobs[i]
		var row := _jobs_box.get_child(i)
		var v := row.get_child(0)
		var l: Label = v.get_child(0).get_child(0)
		var cb: Button = v.get_child(0).get_child(1)
		var bar: ProgressBar = v.get_child(1)
		var a := session.data.action(job["action"])
		var remain := maxf(0.0, float(job["duration"]) - float(job["elapsed"]))
		if job["state"] == "blocked":
			l.text = "%s：%s" % [a.get("name", ""), job["problems"][0]["message"] if not job["problems"].is_empty() else "待機中"]
			l.add_theme_color_override("font_color", UiTheme.C_WARN)
		else:
			l.text = "%s（残り%d分）" % [a.get("name", ""), int(ceil(remain))]
			l.add_theme_color_override("font_color", UiTheme.C_TEXT)
		bar.value = 100.0 * float(job["elapsed"]) / maxf(0.01, float(job["duration"]))
		var jid := int(job["id"])
		if cb.has_meta("jid") and int(cb.get_meta("jid")) == jid:
			continue
		for conn in cb.pressed.get_connections():
			cb.pressed.disconnect(conn["callable"])
		cb.set_meta("jid", jid)
		cb.pressed.connect(func(): session.actions.cancel(jid); _queue_refresh())


func _on_message(text: String) -> void:
	if text == "__toggle_menu__":
		toggle_menu()
		return
	show_toast(text)


func show_toast(text: String, color: Color = UiTheme.C_TEXT) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.08, 0.12, 0.78), Color(0, 0, 0, 0), 10, 10))
	var l := UiTheme.label(text, 18, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := p.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


func set_collect_available(available: bool, label: String = "回収") -> void:
	collect_button.disabled = not available
	collect_button.text = label


# ---------- インベントリ / クラフト ----------
# ---------- 海図・目的地 ----------
func toggle_map() -> void:
	var show := not map_panel.visible
	_close_modals()
	if show:
		map_panel.open()


func _close_modals() -> void:
	_inventory_panel.visible = false
	_menu_panel.visible = false
	crew_panel.visible = false
	map_panel.visible = false
	fleet_panel.visible = false
	faction_panel.visible = false
	quest_panel.visible = false


func _update_nav() -> void:
	var t := str(session.flags.get("nav_target", ""))
	if t == "" or not session.data.sites.has(t):
		_nav_label.text = ""
		return
	var d := session.site_distance(t)
	var to := session.site_position(t) - session.raft_position
	var cam_yaw: float = get_parent().camera_rig.yaw if get_parent() and "camera_rig" in get_parent() else 0.0
	# カメラ基準での方向（画面上が前方）
	var ang := atan2(to.x, to.z) - cam_yaw
	var arrows := ["↓", "↘", "→", "↗", "↑", "↖", "←", "↙"]
	var idx := int(round(wrapf(ang, 0.0, TAU) / (TAU / 8.0))) % 8
	_nav_label.text = "%s %s  %dm" % [arrows[idx], session.data.sites[t]["name"], int(d)]


# ---------- 探索地点 ----------
## 近くの地点（world から毎フレーム通知）
func set_nearby_site(site_id: String) -> void:
	_site_id = site_id
	inspect_button.visible = site_id != ""
	if site_id != "":
		inspect_button.text = "調べる: %s" % session.data.sites[site_id].get("name", site_id)
	elif _site_panel.visible:
		_site_panel.visible = false


func show_site_panel(site_id: String) -> void:
	if site_id == "":
		return
	_site_id = site_id
	_site_panel.visible = true
	hide_building_panel()
	_refresh_site_panel()


func _refresh_site_panel() -> void:
	_clear(_site_info)
	var sd: Dictionary = session.data.sites.get(_site_id, {})
	if sd.is_empty():
		_site_panel.visible = false
		return
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label(str(sd.get("name", _site_id)), 24, UiTheme.C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := UiTheme.button("×", Vector2(56, 52))
	close.pressed.connect(func(): _site_panel.visible = false)
	head.add_child(close)
	_site_info.add_child(head)
	var desc := UiTheme.label(str(sd.get("description", "")), 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_site_info.add_child(desc)
	var aid := str(sd.get("explore_action", ""))
	if aid == "":
		var fac := str(sd.get("faction", ""))
		if fac == "":
			_site_info.add_child(UiTheme.label("ここで探索できるものはない。", 16, Color(0.8, 0.85, 0.88)))
			return
		session.flags["known_faction_" + fac] = true
		var st := session.factions.standing(fac)
		_site_info.add_child(UiTheme.label("%s の拠点（あなたへの態度 %d）" % [session.factions.name_of(fac), int(st)], 17))
		var tb := UiTheme.button("交易・外交", Vector2(220, 64))
		tb.pressed.connect(func():
			_site_panel.visible = false
			_close_modals()
			faction_panel.open_trade(fac))
		_site_info.add_child(tb)
		return
	var left := session.site_explorations_left(_site_id)
	_site_info.add_child(UiTheme.label("探索できる回数: 残り%d回" % left, 16))
	var a := session.data.action(aid)
	_site_info.add_child(UiTheme.label("%s（%d分）" % [a.get("name", aid), int(a.get("duration_minutes", 0))], 19))
	if not a.get("inputs", {}).is_empty() or not a.get("tools", []).is_empty() or not a.get("keep_items", {}).is_empty():
		_site_info.add_child(_requirements_label(aid))
	var problems := session.actions.check(aid, {"site": _site_id})
	for p in problems:
		_site_info.add_child(UiTheme.label("・" + str(p["message"]), 17, UiTheme.C_WARN))
	var b := UiTheme.button("探索する", Vector2(220, 64))
	b.disabled = not problems.is_empty()
	b.pressed.connect(func():
		var r := session.actions.start(aid, {"site": _site_id})
		if not r["ok"]:
			show_toast(str(r["problems"][0]["message"]), UiTheme.C_WARN)
		else:
			show_toast("「%s」を開始しました" % a.get("name", aid), UiTheme.C_OK)
		_refresh_site_panel())
	_site_info.add_child(b)


func toggle_crew() -> void:
	var show := not crew_panel.visible
	_close_modals()
	if show:
		crew_panel.open()
	else:
		crew_panel.visible = false


func _on_talk(member_id: String) -> void:
	crew_panel.visible = false
	var did := session.talk_dialogue_for(member_id)
	if did != "":
		dialogue_panel.open(did)
	else:
		var m: Dictionary = session.crew.members[member_id]
		var expr := "smile" if float(m["satisfaction"]) > 65.0 else ("sad" if float(m["satisfaction"]) < 35.0 else "normal")
		dialogue_panel.open_inline("smalltalk", {"start": {"speaker": member_id, "expression": expr, "text": session.small_talk(member_id), "next": "end"}})


func toggle_inventory() -> void:
	_inventory_panel.visible = not _inventory_panel.visible
	_menu_panel.visible = false
	crew_panel.visible = false
	if _inventory_panel.visible:
		_refresh_inventory()


func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


func _refresh_inventory() -> void:
	_clear(_inv_list)
	var inv := session.inventory
	var ids: Array = inv.stacks.keys()
	for inst in inv.instances:
		if not (inst["id"] in ids):
			ids.append(inst["id"])
	ids.sort_custom(func(a, b): return str(session.data.item(a).get("category")) + a < str(session.data.item(b).get("category")) + b)
	if ids.is_empty():
		_inv_list.add_child(UiTheme.label("何も持っていない", 20))
	for id in ids:
		var def := session.data.item(id)
		var row := HBoxContainer.new()
		var icon := session.data.item_icon(id)
		if icon:
			var tr := TextureRect.new()
			tr.texture = icon
			tr.custom_minimum_size = Vector2(52, 52)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := "%s ×%d" % [def.get("name", id), inv.count(id)]
		if not inv.is_stackable(id):
			var durs: Array = inv.instances.filter(func(i): return i["id"] == id).map(func(i): return "%d/%d" % [int(i["durability"]), int(inv.max_durability(id))])
			title += "  耐久 " + ", ".join(durs)
		info.add_child(UiTheme.label(title, 20))
		var desc := UiTheme.label(str(def.get("description", "")), 15, Color(0.75, 0.82, 0.84))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
		row.add_child(info)
		if not def.get("use_effects", {}).is_empty():
			var b := UiTheme.button("使う", Vector2(100, 56))
			b.pressed.connect(func(): session.use_item(id); _refresh_inventory())
			row.add_child(b)
		_inv_list.add_child(row)
	_refresh_craft()


func _refresh_craft() -> void:
	_clear(_craft_list)
	for id in session.data.actions:
		var a: Dictionary = session.data.actions[id]
		if not (a.get("category") in ["craft", "repair"]) or id in ["repair_building", "repair_ship"]:
			continue  # 対象を選ぶ修理は設備・船団の画面から行う
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.2, 0.26, 0.9), Color(0, 0, 0, 0), 10, 10))
		var row := HBoxContainer.new()
		panel.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var outs: Dictionary = a.get("outputs", {})
		var head := str(a.get("name", id))
		if not outs.is_empty():
			head += " → " + session.describe_items(outs)
		head += "（%d分）" % int(a.get("duration_minutes", 0))
		info.add_child(UiTheme.label(head, 20))
		info.add_child(_requirements_label(id))
		var problems := session.actions.check(id)
		for p in problems:
			if p["code"] != "missing_item":
				info.add_child(UiTheme.label("・" + str(p["message"]), 16, UiTheme.C_WARN))
		row.add_child(info)
		var b := UiTheme.button("作る" if a.get("category") == "craft" else "修理", Vector2(100, 56))
		b.disabled = not problems.is_empty()
		b.pressed.connect(func():
			var r := session.actions.start(id)
			if not r["ok"]:
				show_toast(str(r["problems"][0]["message"]), UiTheme.C_WARN)
			_refresh_inventory())
		row.add_child(b)
		_craft_list.add_child(panel)


## 必要素材を「木材 4/6」の形式で色分け表示する
func _requirements_label(action_id: String) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.add_theme_font_size_override("normal_font_size", 17)
	var parts: Array[String] = []
	for r in session.actions.requirement_rows(action_id):
		var col := "#8eeba5" if r["ok"] else "#ff8c6b"
		var text: String
		match r["kind"]:
			"item":
				text = "%s %d/%d" % [r["name"], r["have"], r["need"]]
				if not r["ok"]:
					text += "（%d不足）" % (int(r["need"]) - int(r["have"]))
			"tool":
				text = "工具:%s" % r["name"]
			"keep":
				text = "所持:%s" % r["name"]
			_:
				text = "設備:%s" % r["name"]
		parts.append("[color=%s]%s[/color]" % [col, text])
	rt.text = "必要: " + ("  ".join(parts) if not parts.is_empty() else "なし")
	return rt


# ---------- 建築 ----------
func set_build_mode(on: bool) -> void:
	build_mode = on
	build_button.text = "建築終了" if on else "建築"
	_build_tile = NO_TILE
	_build_panel.visible = on
	_inventory_panel.visible = false
	hide_building_panel()
	_refresh_build_panel()
	build_mode_changed.emit(on, build_type)


func set_build_type(t: String) -> void:
	build_type = t
	_build_tile = NO_TILE
	_refresh_build_panel()
	build_mode_changed.emit(build_mode, build_type)


func select_build_tile(tile: Vector2i) -> void:
	_build_tile = tile
	_refresh_build_panel()


func build_action_id() -> String:
	return "expand_raft" if build_type == "tile" else session.build_action_for(build_type)


func build_params(tile: Vector2i) -> Dictionary:
	var p := {"x": tile.x, "z": tile.y}
	if build_type != "tile":
		p["building"] = build_type
	return p


func _refresh_build_panel() -> void:
	_clear(_build_info)
	if not build_mode:
		return
	# 種類の選択
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 62)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var types := HBoxContainer.new()
	sc.add_child(types)
	var opts := [["tile", "床"]]
	for bid in session.data.buildings:
		if session.data.buildings[bid].get("kind") == "building":
			opts.append([bid, session.data.building_name(bid)])
	for o in opts:
		var b := UiTheme.button(o[1], Vector2(0, 54))
		b.add_theme_font_size_override("font_size", 18)
		b.toggle_mode = true
		b.button_pressed = o[0] == build_type
		b.pressed.connect(set_build_type.bind(o[0]))
		types.add_child(b)
	_build_info.add_child(sc)
	var aid := build_action_id()
	var a := session.data.action(aid)
	var title := "筏の拡張" if build_type == "tile" else session.data.building_name(build_type)
	_build_info.add_child(UiTheme.label("%s（%d分）" % [title, int(a.get("duration_minutes", 0))], 22, UiTheme.C_GOLD))
	if build_type != "tile":
		var desc := UiTheme.label(str(session.data.buildings[build_type].get("description", "")), 15, Color(0.75, 0.82, 0.84))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_build_info.add_child(desc)
	_build_info.add_child(_requirements_label(aid))
	if _build_tile == NO_TILE:
		_build_info.add_child(UiTheme.label("緑の枠をタップして場所を選んでください", 18))
		for p in session.actions.check(aid, build_params(NO_TILE)):
			if p["code"] != "effect":
				_build_info.add_child(UiTheme.label("・" + str(p["message"]), 17, UiTheme.C_WARN))
		return
	var problems := session.actions.check(aid, build_params(_build_tile))
	for p in problems:
		_build_info.add_child(UiTheme.label("・" + str(p["message"]), 17, UiTheme.C_WARN))
	var h := HBoxContainer.new()
	var ok := UiTheme.button("ここに建設", Vector2(220, 64))
	ok.disabled = not problems.is_empty()
	ok.pressed.connect(func(): build_confirmed.emit(aid, build_params(_build_tile)))
	h.add_child(ok)
	var cancel := UiTheme.button("選択解除", Vector2(160, 64))
	cancel.pressed.connect(func(): select_build_tile(NO_TILE))
	h.add_child(cancel)
	_build_info.add_child(h)


# ---------- 建築物の操作 ----------
func show_building_panel(uid: String) -> void:
	_building_uid = uid
	_building_panel.visible = true
	_refresh_building_panel()


func hide_building_panel() -> void:
	_building_uid = ""
	if _building_panel:
		_building_panel.visible = false


func _refresh_building_panel() -> void:
	_clear(_building_info)
	if _building_uid == "" or not session.raft.buildings.has(_building_uid):
		_building_panel.visible = false
		return
	var b: Dictionary = session.raft.buildings[_building_uid]
	var def: Dictionary = session.data.buildings.get(b["id"], {})
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label(str(def.get("name", b["id"])), 24, UiTheme.C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := UiTheme.button("×", Vector2(56, 52))
	close.pressed.connect(hide_building_panel)
	head.add_child(close)
	_building_info.add_child(head)
	var maxd := int(def.get("max_durability", 0))
	_building_info.add_child(UiTheme.label("耐久 %d/%d%s" % [int(b["durability"]), maxd, "（壊れていて使えない）" if float(b["durability"]) <= 0.0 else ""], 16, UiTheme.C_WARN if float(b["durability"]) < maxd * 0.3 else UiTheme.C_TEXT))
	if float(b["durability"]) < maxd:
		var rp := session.actions.check("repair_building", {"building_uid": _building_uid})
		var rrow := HBoxContainer.new()
		var rl := _requirements_label("repair_building")
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rrow.add_child(rl)
		var rb := UiTheme.button("修理", Vector2(110, 52))
		rb.disabled = not rp.is_empty()
		rb.pressed.connect(func():
			var r := session.actions.start("repair_building", {"building_uid": _building_uid})
			if not r["ok"]:
				show_toast(str(r["problems"][0]["message"]), UiTheme.C_WARN)
			_refresh_building_panel())
		rrow.add_child(rb)
		_building_info.add_child(rrow)
	var prod: Dictionary = def.get("production", {})
	if not prod.is_empty():
		var remain := maxf(0.0, float(prod["minutes"]) - float(b["progress"]))
		var txt := "%s %d/%d" % [session.data.item_name(prod["item"]), int(b["stored"]), int(prod["max_stored"])]
		txt += "（満杯）" if int(b["stored"]) >= int(prod["max_stored"]) else "（次まで%d分）" % int(ceil(remain))
		_building_info.add_child(UiTheme.label(txt, 18))
		var hb := UiTheme.button("収穫", Vector2(160, 60))
		hb.disabled = int(b["stored"]) <= 0
		hb.pressed.connect(func(): session.harvest(_building_uid); _refresh_building_panel())
		_building_info.add_child(hb)
	for aid in session.data.actions:
		var a: Dictionary = session.data.actions[aid]
		if not (b["id"] in a.get("facilities", [])):
			continue
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(str(a.get("name", aid)), 19))
		if not a.get("inputs", {}).is_empty() or not a.get("tools", []).is_empty():
			info.add_child(_requirements_label(aid))
		row.add_child(info)
		var problems := session.actions.check(aid)
		var btn := UiTheme.button("実行", Vector2(110, 56))
		btn.disabled = not problems.is_empty()
		btn.pressed.connect(func():
			var r := session.actions.start(aid)
			if not r["ok"]:
				show_toast(str(r["problems"][0]["message"]), UiTheme.C_WARN)
			_refresh_building_panel())
		row.add_child(btn)
		_building_info.add_child(row)


func _update_sleep_overlay() -> void:
	var sleeping := session.is_sleeping()
	_sleep_overlay.visible = sleeping
	if sleeping:
		for j in session.actions.jobs:
			if session.data.action(j["action"]).get("category") == "rest":
				_sleep_label.text = "眠っています……（残り%d分）" % int(ceil(float(j["duration"]) - float(j["elapsed"])))


func _build_sleep_overlay() -> void:
	_sleep_overlay = ColorRect.new()
	_sleep_overlay.color = Color(0.0, 0.02, 0.06, 0.55)
	_sleep_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sleep_overlay.visible = false
	root.add_child(_sleep_overlay)
	var v := VBoxContainer.new()
	_sleep_overlay.add_child(v)
	_sleep_label = UiTheme.label("", 30, UiTheme.C_GOLD)
	v.add_child(_sleep_label)
	var wake := UiTheme.button("起きる", Vector2(220, 70))
	wake.pressed.connect(func():
		for j in session.actions.jobs.duplicate():
			if session.data.action(j["action"]).get("category") == "rest":
				session.actions.cancel(int(j["id"])))
	v.add_child(wake)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH


# ---------- メニュー ----------
func toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible
	_inventory_panel.visible = false
	_update_quality_buttons()


func _set_quality(q: String) -> void:
	Game.settings["quality"] = q
	Game.save_settings()
	_update_quality_buttons()
	Game.message.emit("画質を「%s」に変更しました" % {"low": "低", "medium": "中", "high": "高"}[q])
	Game.quality_changed()


func _update_quality_buttons() -> void:
	for q in _quality_buttons:
		_quality_buttons[q].button_pressed = Game.settings["quality"] == q


func is_modal_open() -> bool:
	return _inventory_panel.visible or _menu_panel.visible or crew_panel.visible or dialogue_panel.visible or map_panel.visible \
		or combat_panel.visible or fleet_panel.visible or faction_panel.visible or quest_panel.visible


## 画面上の点がUI部品の上にあるか（カメラ操作やタップ選択と競合させないため）
func is_point_on_ui(pos: Vector2) -> bool:
	if is_modal_open():
		return true
	if _sleep_overlay.visible:
		return true
	for c in [joystick, collect_button, build_button, bag_button, crew_button, menu_button, map_button, fleet_button, faction_button, quest_button, inspect_button, _build_panel, _building_panel, _site_panel, _jobs_box]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false
