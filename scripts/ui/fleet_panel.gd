class_name FleetPanel
extends PanelContainer
## 船舶管理・艦隊管理・捕虜（仕様30, 28, 36）

var session: GameSession
var _list: VBoxContainer
var _detail: VBoxContainer
var _selected := ""
var _mission := "scout"
var _target := ""


func setup(s: GameSession) -> void:
	session = s
	ScreenLayout.fit(self, Vector2(1060, 620))
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.11, 0.16, 0.97), UiTheme.C_PANEL_BORDER, 14))
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label("船団", 26, UiTheme.C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := UiTheme.button("閉じる", Vector2(120, 56))
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)
	var h := BoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var lsc := ScrollContainer.new()
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(_list)
	h.add_child(lsc)
	var dsc := ScrollContainer.new()
	dsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 6)
	dsc.add_child(_detail)
	h.add_child(dsc)
	ScreenLayout.split(h, lsc, 240.0)
	session.fleet.changed.connect(func(): if visible: refresh())


func open() -> void:
	visible = true
	if _selected == "" or (not session.fleet.ships.has(_selected) and _selected != "__build" and _selected != "__prisoners"):
		_selected = session.fleet.ships.keys()[0] if not session.fleet.ships.is_empty() else "__build"
	refresh()


func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


func refresh() -> void:
	_clear(_list)
	_clear(_detail)
	_list.add_child(UiTheme.label("貝貨 %d／待機船員 %d人" % [int(session.money), session.fleet.sailors_pool], 16, UiTheme.C_GOLD))
	for uid in session.fleet.ships:
		var sh: Dictionary = session.fleet.ships[uid]
		var tag := "（任務中）" if sh["location"] == "mission" else ""
		_list.add_child(_nav_button("%s%s" % [sh["name"], tag], uid))
	_list.add_child(_nav_button("＋ 船を建造", "__build"))
	_list.add_child(_nav_button("捕虜（%d人）" % session.prisoners.size(), "__prisoners"))
	match _selected:
		"__build":
			_show_build()
		"__prisoners":
			_show_prisoners()
		_:
			if session.fleet.ships.has(_selected):
				_show_ship(_selected)


func _nav_button(text: String, id: String) -> Button:
	var b := UiTheme.button(text, Vector2(220, 54))
	b.toggle_mode = true
	b.button_pressed = id == _selected
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func():
		_selected = id
		refresh())
	return b


func _row(parent: Node, widgets: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for w in widgets:
		h.add_child(w)
	parent.add_child(h)
	return h


func _small_button(text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := UiTheme.button(text, Vector2(0, 46))
	b.add_theme_font_size_override("font_size", 17)
	b.disabled = disabled
	b.pressed.connect(cb)
	return b


func _show_ship(uid: String) -> void:
	var fl := session.fleet
	var sh: Dictionary = fl.ships[uid]
	var d := fl.ship_def(uid)
	_detail.add_child(UiTheme.label("%s（%s）" % [sh["name"], d.get("name", "")], 24, UiTheme.C_GOLD))
	_detail.add_child(UiTheme.label("耐久 %d/%d　速度 %.1f　積載 %d　武装 %d　防御 %d　士気 %d　戦力 %d" % [int(sh["hp"]), int(d.get("hp", 0)), float(d.get("speed", 1)), int(d.get("cargo", 0)), int(d.get("armament", 0)), int(d.get("defense", 0)), int(sh["morale"]), int(fl.power(uid, session))], 16))
	_detail.add_child(UiTheme.label("乗組員 %d/%d（最低%d）" % [fl.crew_count(uid), int(d.get("crew_max", 1)), int(d.get("crew_min", 1))], 17))
	var home := fl.at_home(uid)
	for m in session.crew.aboard_ids():
		var on: bool = m in sh["crew"]
		var label := "%s %s" % ["✓" if on else "　", session.crew.display_name(m)]
		var b := _small_button(label, func():
			if on:
				fl.unassign_member(uid, m)
			else:
				var p := fl.assign_member(uid, m, session)
				if p != "":
					Game.message.emit(p)
			refresh(), not home)
		_detail.add_child(b)
	_row(_detail, [UiTheme.label("雇った船員 %d人" % int(sh["sailors"]), 16),
		_small_button("＋", func(): _msg(fl.add_sailors(uid, 1)), not home),
		_small_button("－", func(): _msg(fl.add_sailors(uid, -1)), not home)])
	if not home:
		var m: Dictionary = sh["mission"]
		_detail.add_child(UiTheme.label("任務中: %s" % session.data.missions.get(m.get("id", ""), {}).get("name", ""), 18, UiTheme.C_GOLD))
		for j in session.actions.jobs:
			if j["action"] == "fleet_mission" and str(j["params"].get("ship", "")) == uid:
				_detail.add_child(UiTheme.label("残り%d分" % int(ceil(float(j["duration"]) - float(j["elapsed"]))), 16))
		_row(_detail, [_small_button("帰還させる", func(): _start("return", "")), _small_button("退却させる", func(): _start("retreat", ""))])
	else:
		_detail.add_child(UiTheme.label("── 任務 ──", 18, UiTheme.C_GOLD))
		var mo := OptionButton.new()
		var idx := 0
		for mid in session.data.missions:
			if mid in ["return", "retreat"]:
				continue
			mo.add_item(str(session.data.missions[mid]["name"]))
			mo.set_item_metadata(idx, mid)
			if mid == _mission:
				mo.select(idx)
			idx += 1
		mo.item_selected.connect(func(i):
			_mission = str(mo.get_item_metadata(i))
			_target = ""
			refresh())
		var targets := _targets_for(_mission)
		var to := OptionButton.new()
		if targets.is_empty():
			to.add_item("（対象なし）")
			_target = ""
		else:
			var found := false
			for i in targets.size():
				to.add_item(targets[i][1])
				to.set_item_metadata(i, targets[i][0])
				if targets[i][0] == _target:
					to.select(i)
					found = true
			if not found:
				_target = targets[0][0]
		to.item_selected.connect(func(i):
			_target = str(to.get_item_metadata(i))
			refresh())
		_row(_detail, [mo, to])
		var md: Dictionary = session.data.missions.get(_mission, {})
		var desc := UiTheme.label("%s（%d時間）" % [md.get("description", ""), int(md.get("hours", 0))], 15, Color(0.8, 0.86, 0.88))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(desc)
		var sup := fl.mission_supplies(uid, _mission)
		if not sup.is_empty():
			var parts: Array = []
			for item in sup:
				parts.append("%s %d/%d" % [session.data.item_name(item), session.inventory.count(item), int(sup[item])])
			_detail.add_child(UiTheme.label("補給: " + "  ".join(parts), 16))
		var params := {"ship": uid, "mission": _mission, "target": _target, "inputs": sup, "duration_minutes": float(md.get("hours", 0)) * 60.0}
		var problems := session.actions.check("fleet_mission", params)
		for p in problems:
			_detail.add_child(UiTheme.label("・" + str(p["message"]), 16, UiTheme.C_WARN))
		var go := UiTheme.button("出航", Vector2(200, 60))
		go.disabled = not problems.is_empty()
		go.pressed.connect(func(): _start(_mission, _target))
		_detail.add_child(go)
		if float(sh["hp"]) < float(d.get("hp", 1)):
			var rp := session.actions.check("repair_ship", {"ship": uid})
			_row(_detail, [_small_button("船舶修理台で修理（修理用消耗品×2）", func():
				var r := session.actions.start("repair_ship", {"ship": uid})
				if not r["ok"]:
					Game.message.emit(str(r["problems"][0]["message"]))
				refresh(), not rp.is_empty())])
	var hist: Array = sh.get("history", [])
	if not hist.is_empty():
		_detail.add_child(UiTheme.label("航海日誌", 18, UiTheme.C_GOLD))
		for i in range(maxi(0, hist.size() - 5), hist.size()):
			var l := UiTheme.label("%d日目: %s" % [int(hist[i]["day"]), hist[i]["text"]], 15)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail.add_child(l)


func _targets_for(mission_id: String) -> Array:
	var out: Array = []
	match str(session.data.missions.get(mission_id, {}).get("target", "none")):
		"raid_target":
			for t in session.data.raid_targets:
				var known := "（偵察済み）" if session.flags.get("scouted_" + t, false) else ""
				out.append([t, str(session.data.raid_targets[t]["name"]) + known])
		"faction":
			for f in session.factions.alive_ids():
				if session.data.factions[f].get("base_site", "") != "":
					out.append([f, session.factions.name_of(f)])
		"zone":
			for z in session.data.zones:
				out.append([z, str(session.data.zones[z]["name"])])
	return out


func _start(mission_id: String, target: String) -> void:
	var r := session.start_fleet_mission(_selected, mission_id, target)
	if not r["ok"]:
		Game.message.emit(str(r["problems"][0]["message"]))
	else:
		Game.message.emit("［艦隊］%sが「%s」に出発した" % [session.fleet.ships[_selected]["name"], session.data.missions[mission_id]["name"]] if not (mission_id in ["return", "retreat"]) else "［艦隊］船を呼び戻した")
	refresh()


func _msg(p: String) -> void:
	if p != "":
		Game.message.emit(p)
	refresh()


func _show_build() -> void:
	_detail.add_child(UiTheme.label("船の建造（船舶修理台が必要）", 22, UiTheme.C_GOLD))
	for sid in session.data.ships:
		var d: Dictionary = session.data.ships[sid]
		var aid := str(d.get("build_action", ""))
		var a := session.data.action(aid)
		var box := VBoxContainer.new()
		box.add_child(UiTheme.label("%s（%d時間）— %s" % [d["name"], int(a.get("duration_minutes", 0)) / 60, d.get("description", "")], 18))
		var parts: Array = []
		for item in a.get("inputs", {}):
			parts.append("%s %d/%d" % [session.data.item_name(item), session.inventory.count(item), int(a["inputs"][item])])
		box.add_child(UiTheme.label("必要: " + "  ".join(parts), 15))
		var problems := session.actions.check(aid)
		for p in problems:
			if p["code"] != "missing_item":
				box.add_child(UiTheme.label("・" + str(p["message"]), 15, UiTheme.C_WARN))
		var b := _small_button("建造する", func():
			var r := session.actions.start(aid)
			if not r["ok"]:
				Game.message.emit(str(r["problems"][0]["message"]))
			refresh(), not problems.is_empty())
		box.add_child(b)
		_detail.add_child(box)


func _show_prisoners() -> void:
	_detail.add_child(UiTheme.label("捕虜（収容 %d/%d）" % [session.prisoners.size(), session.prison_capacity()], 22, UiTheme.C_GOLD))
	if session.prisoners.is_empty():
		_detail.add_child(UiTheme.label("捕虜はいない。捕虜の檻があれば、降伏した敵を収容できる。", 16))
		return
	_detail.add_child(UiTheme.label("捕虜は毎日、保存食などの食料1と飲料水1を消費する。足りないと逃げ出す。", 15, Color(0.8, 0.86, 0.88)))
	for i in session.prisoners.size():
		var p: Dictionary = session.prisoners[i]
		var who := str(session.data.enemies.get(p.get("from", ""), session.data.raid_targets.get(p.get("from", ""), {})).get("name", "捕虜"))
		var fac := session.factions.name_of(str(p.get("faction", ""))) if str(p.get("faction", "")) != "" else "所属なし"
		_detail.add_child(UiTheme.label("%s（%s・%d日目に捕らえた）" % [who, fac, int(p.get("day", 0))], 17))
		var rp := Piracy.ransom_problem(session, i)
		_row(_detail, [
			_small_button("解放する", func(): _msg(Piracy.release_prisoner(session, i))),
			_small_button("身代金を取る", func():
				var r := Piracy.ransom_prisoner(session, i)
				_msg("" if r["ok"] else str(r["error"]))
				if r["ok"]:
					Game.message.emit("身代金%d貝貨を受け取った" % r["coins"]), rp != ""),
			_small_button("仲間に誘う", func():
				var r := Piracy.recruit_prisoner(session, i)
				_msg("捕虜が船員として加わった" if r["ok"] else str(r["error"]))),
		])
		if rp != "":
			_detail.add_child(UiTheme.label("　身代金: " + rp, 14, Color(0.8, 0.8, 0.8)))
