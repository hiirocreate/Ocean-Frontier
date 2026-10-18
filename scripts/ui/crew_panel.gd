class_name CrewPanel
extends PanelContainer
## 仲間管理画面：状態・作業の割り当て・技能・性格・人間関係・履歴・会話（仕様23〜26, 36）

signal talk_requested(member_id: String)

const STAT_LABELS := [["health", "体力"], ["hunger", "空腹"], ["thirst", "水分"], ["fatigue", "疲労"],
	["stress", "ストレス"], ["satisfaction", "満足度"], ["loyalty", "忠誠"], ["trust", "信頼"]]
const SKILL_NAMES := {"construction": "建築", "repair": "修理", "gathering": "回収", "cooking": "調理", "fishing": "漁業",
	"farming": "農業", "research": "研究", "guard": "警備", "navigation": "航海", "exploration": "探索", "trade": "交易", "command": "指揮"}
const RELATION_NAMES := {"trust": "信頼", "friendship": "友情", "hostility": "敵意", "respect": "尊敬", "jealousy": "嫉妬", "fear": "恐怖", "intimacy": "親密"}

var session: GameSession
var _list: VBoxContainer
var _detail: VBoxContainer
var _selected := ""


func setup(s: GameSession) -> void:
	session = s
	ScreenLayout.fit(self, Vector2(980, 600))
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.11, 0.16, 0.97), UiTheme.C_PANEL_BORDER, 14))
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label("仲間", 26, UiTheme.C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := UiTheme.button("閉じる", Vector2(120, 56))
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var lsc := ScrollContainer.new()
	lsc.custom_minimum_size = Vector2(230, 0)
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(_list)
	h.add_child(lsc)
	var dsc := ScrollContainer.new()
	dsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.add_child(_detail)
	h.add_child(dsc)


func open() -> void:
	visible = true
	if _selected == "" or not session.crew.members.has(_selected):
		var ids := session.crew.aboard_ids()
		_selected = ids[0] if not ids.is_empty() else ""
	refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for c in _detail.get_children():
		c.queue_free()
	var aboard := session.crew.aboard_ids()
	var departed := session.crew.departed_ids()
	if (_selected == "" or not session.crew.members.has(_selected)) and not aboard.is_empty():
		_selected = aboard[0]
	if aboard.is_empty() and departed.is_empty():
		_detail.add_child(UiTheme.label("まだ仲間はいない。漂流者を探して救助しよう。", 20))
		return
	for id in aboard:
		_list.add_child(_member_button(id, ""))
	if not departed.is_empty():
		_list.add_child(UiTheme.label("── 去った仲間 ──", 16, Color(0.7, 0.75, 0.78)))
		for id in departed:
			_list.add_child(_member_button(id, "（離脱）"))
	if _selected != "":
		_show_detail(_selected)


func _member_button(id: String, suffix: String) -> Button:
	var b := UiTheme.button(session.crew.display_name(id) + suffix, Vector2(210, 56))
	b.toggle_mode = true
	b.button_pressed = id == _selected
	b.pressed.connect(func():
		_selected = id
		refresh())
	return b


func _show_detail(id: String) -> void:
	var crew := session.crew
	var d := crew.def(id)
	var m: Dictionary = crew.members[id]
	var top := HBoxContainer.new()
	var pv := PortraitView.new()
	pv.custom_minimum_size = Vector2(150, 190)
	pv.set_character(id, d, "smile" if float(m["satisfaction"]) > 65.0 else ("sad" if float(m["satisfaction"]) < 30.0 else "normal"))
	top.add_child(pv)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiTheme.label("%s（%s・%d歳）" % [d.get("name", id), d.get("role", ""), int(d.get("age", 0))], 22, UiTheme.C_GOLD))
	var traits: Array = d.get("personality", []).map(func(t): return str(session.data.traits.get(t, {}).get("name", t)))
	info.add_child(UiTheme.label("性格: " + "・".join(traits), 16))
	var skills: Array = []
	var sk: Dictionary = d.get("skills", {})
	for k in sk:
		skills.append("%s%d" % [SKILL_NAMES.get(k, k), int(sk[k])])
	info.add_child(UiTheme.label("技能: " + " ".join(skills), 16))
	var goal := UiTheme.label("目標: " + str(d.get("personal_goal", "")), 15, Color(0.8, 0.86, 0.88))
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(goal)
	top.add_child(info)
	_detail.add_child(top)
	if m["status"] == "departed":
		_detail.add_child(UiTheme.label("%d日目に去った（理由: %s／行き先: %s）" % [int(m["departed_day"]), Crew.REASONS.get(m["departed_reason"], m["departed_reason"]), crew.destination_name(str(m["location"]))], 18, UiTheme.C_WARN))
		var rp := crew.rejoin_problem(id, session.clock.day())
		_detail.add_child(UiTheme.label("再会すれば戻ってくれるかもしれない" if rp == "" else rp, 16))
	else:
		var grid := GridContainer.new()
		grid.columns = 4
		for st in STAT_LABELS:
			grid.add_child(UiTheme.label(st[1], 15))
			var bar := ProgressBar.new()
			bar.max_value = 100
			bar.value = float(m[st[0]])
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(150, 14)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var bad: bool = (st[0] in ["fatigue", "stress"] and bar.value > 70) or (not (st[0] in ["fatigue", "stress"]) and bar.value < 30)
			bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.C_WARN if bad else UiTheme.C_OK, Color(0, 0, 0, 0), 6, 2))
			grid.add_child(bar)
		_detail.add_child(grid)
		if bool(m.get("warned", false)):
			_detail.add_child(UiTheme.label("⚠ 不満が溜まっている。このままでは去ってしまうかもしれない", 17, UiTheme.C_WARN))
		var jobrow := HBoxContainer.new()
		jobrow.add_child(UiTheme.label("作業: ", 18))
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(220, 52)
		var idx := 0
		for jid in session.data.jobs:
			var j: Dictionary = session.data.jobs[jid]
			ob.add_item(str(j.get("name", jid)))
			ob.set_item_metadata(idx, jid)
			var prob := crew.job_problem(id, jid, session)
			if prob != "" and jid != m["job"]:
				ob.set_item_disabled(idx, true)
				ob.set_item_tooltip(idx, prob)
			if jid == m["job"]:
				ob.select(idx)
			idx += 1
		ob.item_selected.connect(func(i):
			var p := crew.assign_job(id, str(ob.get_item_metadata(i)), session)
			if p != "":
				Game.message.emit(p)
			refresh())
		jobrow.add_child(ob)
		jobrow.add_child(UiTheme.label("  効率 %d%%" % int(crew.efficiency(id) * 100), 16))
		var talk := UiTheme.button("話す", Vector2(120, 52))
		talk.pressed.connect(func(): talk_requested.emit(id))
		jobrow.add_child(talk)
		_detail.add_child(jobrow)
	var rels := crew.relations_of(id)
	if not rels.is_empty():
		_detail.add_child(UiTheme.label("人間関係", 18, UiTheme.C_GOLD))
		for other in rels:
			var parts: Array = []
			for kind in rels[other]:
				if absf(float(rels[other][kind])) >= 1.0:
					parts.append("%s %d" % [RELATION_NAMES.get(kind, kind), int(rels[other][kind])])
			if not parts.is_empty():
				_detail.add_child(UiTheme.label("→ %s: %s" % [crew.display_name(other), "、".join(parts)], 15))
	var hist: Array = m.get("history", [])
	if not hist.is_empty():
		_detail.add_child(UiTheme.label("これまで", 18, UiTheme.C_GOLD))
		for i in range(maxi(0, hist.size() - 5), hist.size()):
			_detail.add_child(UiTheme.label("%d日目: %s" % [int(hist[i]["day"]), hist[i]["text"]], 15))
